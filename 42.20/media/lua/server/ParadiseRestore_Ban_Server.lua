ParadiseBan = ParadiseBan or {}
ParadiseBan.MODULE = "ParadiseBan"
ParadiseBan.pending = ParadiseBan.pending or {}

local function getTarget(username)
    return username and getPlayerByUserName(username) or nil
end

local function persistentBan(username, steamID)
    if steamID and steamID ~= "" and steamID ~= "-1" and BanSystem and BanSystem.BanUserBySteamID then
        return BanSystem.BanUserBySteamID(steamID, nil, "ParadiseBan", true)
    end
    if BanSystem and BanSystem.BanUser then
        return BanSystem.BanUser(username, nil, "ParadiseBan", true)
    end
    if serverCommand then
        serverCommand("banuser " .. tostring(username) .. " -r ParadiseBan")
        return true
    end
    return false
end

function ParadiseBan.onClientCommand(module, command, sender, args)
    if module ~= ParadiseBan.MODULE or command ~= "start" then return end
    if not sender or not ParadiseDev.isAdm(sender) or type(args) ~= "table" then return end
    local target = getTarget(args.targUser)
    if not target or target == sender or ParadiseDev.isAdm(target) then return end
    local choice = ParadiseBan.animChoices[args.animStr]
    if not choice then return end
    local delay = math.max(1, math.min(30000, tonumber(args.banDelay) or choice.banDelay or 1000))
    persistentBan(args.targUser, args.targSteamID)
    sendServerCommand(target, ParadiseBan.MODULE, "disable", {})
    ParadiseBan.pending[args.targUser] = {
        target = target,
        releaseAt = os.time() * 1000 + delay,
    }
end

Events.OnClientCommand.Add(ParadiseBan.onClientCommand)

function ParadiseBan.onTick()
    local now = os.time() * 1000
    for username, entry in pairs(ParadiseBan.pending) do
        if now >= entry.releaseAt then
            if entry.target then sendServerCommand(entry.target, ParadiseBan.MODULE, "release", {}) end
            ParadiseBan.pending[username] = nil
        end
    end
end

Events.OnTick.Add(ParadiseBan.onTick)
