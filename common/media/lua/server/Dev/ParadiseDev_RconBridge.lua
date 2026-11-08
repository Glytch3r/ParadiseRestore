-- external command bridge: an outside tool drops a request file, the server reads it on OnTick
-- and runs the same char handlers an admin would use in game. server-only (lives under media/lua/server)

ParadiseRestore = ParadiseRestore or {}
ParadiseDev = ParadiseDev or {}
ParadiseRestore.Rcon = ParadiseRestore.Rcon or {}

local R = ParadiseRestore.Rcon

R.module = "ParadiseRcon"
R.reqFile = "ParadiseRcon_req.txt"
R.respFile = "ParadiseRcon_resp.txt"
R.tokenFile = "ParadiseRcon_token.txt"
R.pollMs = 1000

R.token = nil
R.lastSeq = nil
R.lastPoll = 0
R.cmds = {}

-- the game never routes native RCON/console text into Lua, so this custom event is fired by the bridge
-- itself. modules subscribe with Events.OnRconCommand.Add(fn); fn(name, ctx, reply) may set
-- reply.handled = true plus reply.status and reply.result to claim a command before the built-ins run
R.event = "OnRconCommand"
if LuaEventManager and LuaEventManager.AddEvent and not Events[R.event] then
    LuaEventManager.AddEvent(R.event)
end

local function trim(s)
    if s == nil then return "" end
    return tostring(s):match("^%s*(.-)%s*$")
end

local function readFile(path)
    local reader = getFileReader(path, false)
    if not reader then return nil end
    local lines = {}
    while true do
        local line = reader:readLine()
        if line == nil then break end
        lines[#lines + 1] = line
    end
    reader:close()
    return table.concat(lines, "\n")
end

local function writeFile(path, text)
    local writer = getFileWriter(path, true, false)
    if not writer then return false end
    if text and text ~= "" then writer:write(text) end
    writer:close()
    return true
end

function R.loadToken(force)
    if R.token and not force then return R.token end
    local raw = readFile(R.tokenFile)
    if not raw or trim(raw) == "" then
        R.token = ""
        return ""
    end
    R.token = trim(raw:match("^[^\r\n]*") or raw)
    return R.token
end

local function parseRequest(raw)
    local req = {}
    for line in string.gmatch(raw or "", "[^\r\n]+") do
        local k, v = line:match("^%s*([%a_][%w_]*)%s*=%s*(.-)%s*$")
        if k then req[string.lower(k)] = v end
    end
    return req
end

-- resolve an online character by username; returns nil when they are logged out
function R.online(user)
    if not user or user == "" then return nil end
    return getPlayerFromUsername(user) or nil
end

function R.cmds.ping(ctx)
    return true, "pong"
end

function R.cmds.help(ctx)
    return true, "commands: ping | help | die <user> | cage <user> | uncage <user> | scare <user> | rebound <user>"
end

function R.cmds.die(ctx)
    local user = trim(ctx.user)
    if user == "" then return false, "die needs a target username" end
    local pl = R.online(user)
    if not pl then return false, "target offline: " .. user end
    if pl:isGodMod() then pl:setGodMod(false) end
    pl:getBodyDamage():ReduceGeneralHealth(110)
    return true, "killed " .. user
end

function R.cmds.scare(ctx)
    local user = trim(ctx.user)
    if user == "" then return false, "scare needs a target username" end
    local pl = R.online(user)
    if not pl then return false, "target offline: " .. user end
    getSoundManager():PlayWorldSound("ZombieSurprisedPlayer", pl:getSquare(), 0, 5, 5, false)
    return true, "scared " .. user
end

function R.cmds.rebound(ctx)
    local user = trim(ctx.user)
    if user == "" then return false, "rebound needs a target username" end
    local pl = R.online(user)
    if not pl then return false, "target offline: " .. user end
    if not (ParadiseDev.TP and ParadiseDev.TP.reboundPlayer) then return false, "rebound unavailable" end
    ParadiseDev.TP.reboundPlayer(pl)
    return true, "rebound " .. user
end

-- cage and uncage share this; setByKey with a username: key handles online and offline pending
local function setCage(ctx, isCaged)
    local user = trim(ctx.user)
    if user == "" then return false, "cage needs a target username" end
    if not (ParadiseDev.Cage and ParadiseDev.Cage.setByKey) then return false, "cage module unavailable" end
    local key = "username:" .. (ParadiseDev.Cage.getUsernameKey(user) or user:lower())
    ParadiseDev.Cage.setByKey(key, user, isCaged)
    local online = R.online(user) and true or false
    return true, (isCaged and "caged " or "uncaged ") .. user .. (online and " (online)" or " (pending)")
end

function R.cmds.cage(ctx) return setCage(ctx, true) end
function R.cmds.uncage(ctx) return setCage(ctx, false) end

function R.run(cmd, ctx)
    local name = string.lower(trim(cmd))
    local handler = R.cmds[name]
    if not handler then return false, "unknown command: " .. name end
    ctx = ctx or {}
    local ok, a, b = pcall(handler, ctx)
    if not ok then return false, "error: " .. tostring(a) end
    return a and true or false, tostring(b)
end

-- fire the OnRconCommand bus so other modules can add or override commands, then fall back to the
-- built-in registry if nobody claimed it. returns {status=ok|error, result=text}
function R.dispatch(name, ctx)
    local reply = { handled = false, status = "error", result = "unknown command: " .. tostring(name) }
    if triggerEvent then
        triggerEvent(R.event, name, ctx or {}, reply)
    end
    if not reply.handled then
        local ok, msg = R.run(name, ctx)
        reply.handled = ok
        reply.status = ok and "ok" or "error"
        reply.result = tostring(msg)
    end
    return reply
end

function R.poll()
    local now = getTimestampMs()
    if R.lastPoll and now - R.lastPoll < R.pollMs then return end
    R.lastPoll = now

    local raw = readFile(R.reqFile)
    if not raw or trim(raw) == "" then return end

    local req = parseRequest(raw)
    local seq = tostring(req.seq or "")
    if seq ~= "" and seq == R.lastSeq then return end
    R.lastSeq = seq

    local token = R.loadToken()
    if not token or token == "" then
        writeFile(R.respFile, "seq=" .. seq .. "\nstatus=error\nresult=bridge disabled, no token file\n")
        writeFile(R.reqFile, "")
        return
    end
    if trim(req.token) ~= token then
        log("ParadiseRcon: rejected request with bad token")
        writeFile(R.respFile, "seq=" .. seq .. "\nstatus=error\nresult=bad token\n")
        writeFile(R.reqFile, "")
        return
    end

    local reply = R.dispatch(string.lower(trim(req.cmd)), { user = req.user, args = req.args, requester = "rcon" })
    writeFile(R.respFile, "seq=" .. seq .. "\nstatus=" .. reply.status .. "\nresult=" .. reply.result .. "\n")
    writeFile(R.reqFile, "")
end

function R.onTick()
    local ok, err = pcall(R.poll)
    if not ok then log("ParadiseRcon poll error: " .. tostring(err)) end
end

function R.onServerStart()
    R.token = nil
    R.loadToken(true)
    if R.token == "" then
        log("ParadiseRcon: bridge inactive, create " .. R.tokenFile .. " in the server Zomboid/Lua dir to enable")
    else
        log("ParadiseRcon: bridge armed")
    end
end

-- lets an in game admin run the same handlers over a client command, single source of truth
function R.onClientCommand(module, command, player, args)
    if module ~= R.module or command ~= "run" then return end
    if not ParadiseRestore.isAdm(player) then return end
    args = args or {}
    local reply = R.dispatch(string.lower(trim(args.cmd)), { user = args.user, args = args.args, requester = player })
    log("ParadiseRcon: admin " .. tostring(player and player:getUsername()) .. " ran " .. tostring(args.cmd) .. " -> " .. reply.status .. ": " .. reply.result)
end

Events.OnServerStart.Remove(R.onServerStart)
Events.OnServerStart.Add(R.onServerStart)
Events.OnClientCommand.Remove(R.onClientCommand)
Events.OnClientCommand.Add(R.onClientCommand)
Events.OnTick.Remove(R.onTick)
Events.OnTick.Add(R.onTick)
