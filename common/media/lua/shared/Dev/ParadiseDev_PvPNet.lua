require "Dev/ParadiseDev_PvEPolicy"

ParadiseDev = ParadiseDev or {}
ParadiseDev.PvPNet = ParadiseDev.PvPNet or {}
local N = ParadiseDev.PvPNet

N.module = "ParadisePvP"
N.aimHit = "aimHit"
N.maxLevelDelta = 4
N.maxDistance = 60
N.minIntervalMs = 220
N.rates = N.rates or {}
N.handled = N.handled or {}

function N.now()
    return getTimestampMs and getTimestampMs() or 0
end

function N.user(pl)
    if not pl or not pl.getUsername then return "" end
    local user = pl:getUsername()
    return user and tostring(user) or ""
end

function N.level(pl)
    if not pl then return nil end
    return math.floor(pl:getZ() + 0.5)
end

function N.distance(left, right)
    local dx = left:getX() - right:getX()
    local dy = left:getY() - right:getY()
    return math.sqrt(dx * dx + dy * dy)
end

function N.isFirearm(item)
    if ParadiseDev.PvP and ParadiseDev.PvP.isFirearm then return ParadiseDev.PvP.isFirearm(item) end
    if not item then return false end
    local scr = item:getScriptItem()
    return scr and scr:isRanged() or false
end

function N.isAllied(left, right)
    if left == "" or right == "" or left == right then return false end
    if not Faction or not Faction.getFactions then return false end
    local factions = Faction.getFactions()
    if not factions then return false end
    for index = 0, factions:size() - 1 do
        local members = factions:get(index):getPlayers()
        if members then
            local hasLeft, hasRight = false, false
            for int = 0, members:size() - 1 do
                local name = tostring(members:get(int))
                if name == left then hasLeft = true end
                if name == right then hasRight = true end
            end
            if hasLeft and hasRight then return true end
        end
    end
    return false
end

function N.canAttack(attacker, victim)
    if not attacker or not victim or attacker == victim then return false end
    if attacker:isDead() or victim:isDead() then return false end
    if ParadiseDev.PvEPolicy.isHitProtected(attacker, victim) then return false end
    return not N.isAllied(N.user(attacker), N.user(victim))
end

function N.allowRate(user)
    local last = N.rates[user]
    local stamp = N.now()
    if last and stamp - last < N.minIntervalMs then return false end
    N.rates[user] = stamp
    return true
end

function N.onClientCommand(module, command, sender, args)
    if module ~= N.module or command ~= N.aimHit then return end
    if not sender or type(args) ~= "table" then return end
    local victim = getPlayerFromUsername(tostring(args.target or ""))
    if not victim or not N.canAttack(sender, victim) then return end
    local level = tonumber(args.level)
    if not level or math.abs(level - N.level(sender)) > N.maxLevelDelta then return end
    if level ~= N.level(victim) then return end
    if not N.isFirearm(sender:getPrimaryHandItem()) then return end
    if not N.allowRate(N.user(sender)) then return end
    local dist = N.distance(sender, victim)
    if dist > N.maxDistance then return end
    sendServerCommand(victim, N.module, N.aimHit, {
        attacker = N.user(sender),
        target = N.user(victim),
        level = level,
        critical = args.critical == true,
        shot = tonumber(args.shot) or 0,
    })
end

function N.onServerCommand(module, command, args)
    if module ~= N.module or command ~= N.aimHit or type(args) ~= "table" then return end
    local pl = getPlayer()
    if not pl or tostring(args.target or "") ~= N.user(pl) then return end
    if not ParadiseDev.PvP or not ParadiseDev.PvP.applyDamage then return end
    local attacker = getPlayerFromUsername(tostring(args.attacker or ""))
    if not attacker or not N.canAttack(attacker, pl) then return end
    local shot = tonumber(args.shot) or 0
    local user = N.user(attacker)
    if N.handled[user] and shot <= N.handled[user] then return end
    N.handled[user] = shot
    local pvp = SandboxVars and SandboxVars.ParadiseZpvp or {}
    local bonus = args.critical == true and ZombRand(0, (tonumber(pvp.pvpDmgMult) or 0) + 1) or 0
    ParadiseDev.PvP.applyDamage(pl, attacker, attacker:getPrimaryHandItem(), bonus)
end

if isClient and isClient() then
    Events.OnServerCommand.Remove(N.onServerCommand)
    Events.OnServerCommand.Add(N.onServerCommand)
end
if isServer and isServer() then
    Events.OnClientCommand.Remove(N.onClientCommand)
    Events.OnClientCommand.Add(N.onClientCommand)
end

function N.sendHit(pl, victim, level, critical)
    if not pl or not victim then return false end
    local args = {
        target = N.user(victim),
        level = level,
        critical = critical == true,
        shot = N.now(),
    }
    if isServer and isServer() then
        N.onClientCommand(N.module, N.aimHit, pl, args)
    elseif isClient and isClient() then
        sendClientCommand(pl, N.module, N.aimHit, args)
    else
        return false
    end
    return true
end
