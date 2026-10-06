if isClient() then return end

LimboTracker = LimboTracker or {}
LimboTracker.Module = "ParadiseLimbo"
LimboTracker.StoreName = "ParadiseLimboTracker"

function LimboTracker.getStore()
    local store = ModData.getOrCreate(LimboTracker.StoreName)
    store.players = store.players or {}
    return store
end

function LimboTracker.getUsername(pl)
    local username = pl and pl.getUsername and pl:getUsername() or nil
    if not username or tostring(username) == "" then return nil end
    return tostring(username)
end

function LimboTracker.getIdOrUser(pl)
    if not pl then return nil end
    if getSteamModeActive and getSteamModeActive() and pl.getSteamID then
        local steamID = tostring(pl:getSteamID() or "")
        if steamID ~= "" and steamID ~= "0" then return steamID end
    end
    local username = LimboTracker.getUsername(pl)
    return username and string.lower(username) or nil
end

function LimboTracker.getPing(pl, args)
    local ping = args and tonumber(args.ping) or 0
    return math.max(0, math.floor(ping or 0))
end

function LimboTracker.getFPS(args)
    local fps = args and tonumber(args.fps) or 0
    return math.max(0, math.floor(fps or 0))
end

function LimboTracker.getRecord(pl)
    local idOrUser = LimboTracker.getIdOrUser(pl)
    if not idOrUser then return nil end
    local store = LimboTracker.getStore()
    local record = store.players[idOrUser]
    if not record then
        record = {
            idOrUser = idOrUser,
            username = LimboTracker.getUsername(pl),
            fps = 0,
            ping = 0,
            serverTimestamp = getTimestamp(),
            exitMode = -1,
            restrict = false,
            limboCage = false,
            wasCaged = false,
            limboActive = false,
            initialized = false,
            deathTimestamp = nil,
        }
        store.players[idOrUser] = record
    end
    return record
end

function LimboTracker.clean(value)
    return tostring(value or ""):gsub("[%c%s]+", "_")
end

function LimboTracker.writeLog(record)
    if not record then return false end
    local path = "ParadiseLimboTracker/" .. os.date("%Y-%m-%d") .. ".log"
    local writer = getFileWriter(path, true, true)
    if not writer then return false end
    local line = os.date("%H:%M:%S") .. " "
        .. LimboTracker.clean(record.idOrUser) .. " "
        .. tostring(tonumber(record.fps) or 0) .. " "
        .. tostring(tonumber(record.ping) or 0) .. " "
        .. tostring(tonumber(record.exitMode) or -1) .. "\n"
    writer:write(line)
    writer:close()
    return true
end

function LimboTracker.save(record)
    if ModData.transmit then ModData.transmit(LimboTracker.StoreName) end
    LimboTracker.writeLog(record)
end

function LimboTracker.setState(pl, args)
    local exitMode = args and tonumber(args.exitMode) or nil
    if not exitMode or exitMode ~= math.floor(exitMode) or exitMode < 0 or exitMode > 5 then return false end
    local record = LimboTracker.getRecord(pl)
    if not record then return false end
    record.username = LimboTracker.getUsername(pl)
    record.fps = LimboTracker.getFPS(args)
    record.ping = LimboTracker.getPing(pl, args)
    record.serverTimestamp = getTimestamp()
    record.exitMode = exitMode
    record.limboActive = true
    if exitMode == 0 then record.deathTimestamp = record.serverTimestamp end
    LimboTracker.save(record)
    return true
end

function LimboTracker.getCooldownSeconds()
    local mins = SandboxVars and SandboxVars.ParadiseZ and tonumber(SandboxVars.ParadiseZ.reloginDelayMins) or 0
    return math.max(0, math.floor(mins or 0)) * 60
end

function LimboTracker.isRestrictedMode(exitMode)
    return exitMode == -1 or exitMode == 0 or exitMode == 3 or exitMode == 4
end

function LimboTracker.release(pl, record)
    if not pl or not record or not record.limboCage then return false end
    if not ParadiseDev or not ParadiseDev.Cage or not ParadiseDev.Cage.set then return false end
    ParadiseDev.Cage.set(pl, false)
    record.restrict = false
    record.limboCage = false
    record.releaseTimestamp = nil
    record.serverTimestamp = getTimestamp()
    LimboTracker.save(record)
    return true
end

function LimboTracker.releaseExpired(pl, record, now)
    if not record or not record.limboCage or not record.releaseTimestamp then return false end
    if now < record.releaseTimestamp then return false end
    return LimboTracker.release(pl, record)
end

function LimboTracker.onCreatePlayer(_, pl)
    if not pl then return end
    local record = LimboTracker.getRecord(pl)
    if not record then return end
    local now = getTimestamp()
    LimboTracker.releaseExpired(pl, record, now)
    local exitMode = tonumber(record.exitMode)
    local cooldown = LimboTracker.getCooldownSeconds()
    local shouldRestrict = record.initialized and exitMode == -1
        or record.limboActive and LimboTracker.isRestrictedMode(exitMode)
    if shouldRestrict and cooldown > 0 then
        local startedAt = exitMode == 0 and tonumber(record.deathTimestamp) or tonumber(record.serverTimestamp)
        if exitMode == -1 then startedAt = now end
        local releaseTimestamp = (startedAt or now) + cooldown
        if releaseTimestamp > now then
            local isCaged = ParadiseDev and ParadiseDev.Cage and ParadiseDev.Cage.isCaged and ParadiseDev.Cage.isCaged(pl) or false
            record.wasCaged = isCaged == true
            if not isCaged and ParadiseDev and ParadiseDev.Cage and ParadiseDev.Cage.set then
                ParadiseDev.Cage.set(pl, true)
                record.restrict = true
                record.limboCage = true
                record.releaseTimestamp = releaseTimestamp
            end
        end
    end
    record.exitMode = -1
    record.limboActive = false
    record.initialized = true
    record.serverTimestamp = now
    LimboTracker.save(record)
end

function LimboTracker.checkExpired()
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players then return end
    local now = getTimestamp()
    for index = 0, players:size() - 1 do
        local pl = players:get(index)
        local record = LimboTracker.getRecord(pl)
        LimboTracker.releaseExpired(pl, record, now)
    end
end

function LimboTracker.onClientCommand(module, command, pl, args)
    if module ~= LimboTracker.Module or command ~= "state" then return end
    LimboTracker.setState(pl, args)
end

function LimboTracker.onInitGlobalModData()
    LimboTracker.getStore()
end

Events.OnClientCommand.Remove(LimboTracker.onClientCommand)
Events.OnClientCommand.Add(LimboTracker.onClientCommand)
Events.OnInitGlobalModData.Remove(LimboTracker.onInitGlobalModData)
Events.OnInitGlobalModData.Add(LimboTracker.onInitGlobalModData)
Events.OnCreatePlayer.Remove(LimboTracker.onCreatePlayer)
Events.OnCreatePlayer.Add(LimboTracker.onCreatePlayer)
Events.EveryOneMinute.Remove(LimboTracker.checkExpired)
Events.EveryOneMinute.Add(LimboTracker.checkExpired)
