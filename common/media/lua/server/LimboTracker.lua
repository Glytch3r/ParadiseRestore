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

function LimboTracker.getIdentity(pl)
    local idOrUser = LimboTracker.getIdOrUser(pl)
    local username = LimboTracker.getUsername(pl)
    local desc = pl and pl.getDescriptor and pl:getDescriptor() or nil
    if not idOrUser or not username or not desc then return nil end
    local prof = desc.getCharacterProfession and desc:getCharacterProfession() or nil
    return {
        idOrUser = idOrUser,
        username = username,
        firstname = desc.getForename and tostring(desc:getForename() or "") or "",
        surname = desc.getSurname and tostring(desc:getSurname() or "") or "",
        profKey = prof and prof.getName and tostring(prof:getName() or "")
            or (desc.getProfession and tostring(desc:getProfession() or "") or ""),
    }
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
    local identity = LimboTracker.getIdentity(pl)
    if not identity then return nil end
    local store = LimboTracker.getStore()
    local record = store.players[identity.idOrUser]
    if not record then
        record = {
            idOrUser = identity.idOrUser,
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
        store.players[identity.idOrUser] = record
    end
    record.username = identity.username
    record.firstname = identity.firstname
    record.surname = identity.surname
    record.profKey = identity.profKey
    return record
end

function LimboTracker.clean(value)
    return tostring(value or ""):gsub("[%c|]", "_")
end

function LimboTracker.getExitModeLabel(exitMode)
    local labels = {
        [-1] = "Possible Force Exit or Crash",
        [0] = "Character Died",
        [1] = "Reincarnate Selected",
        [2] = "New Character Selected",
        [3] = "Exit to Main Menu",
        [4] = "Quit to Desktop",
        [5] = "Event Respawn Selected",
    }
    return labels[tonumber(exitMode)]
end

function LimboTracker.formatLog(record)
    if not record then return nil end
    local exitMode = tonumber(record.exitMode) or -1
    local exitLabel = LimboTracker.getExitModeLabel(exitMode)
    if not exitLabel then return nil end
    return "[LimboTracker]|time:" .. os.date("%H:%M:%S")
        .. "|key:" .. LimboTracker.clean(record.idOrUser)
        .. "|username:" .. LimboTracker.clean(record.username)
        .. "|firstname:" .. LimboTracker.clean(record.firstname)
        .. "|surname:" .. LimboTracker.clean(record.surname)
        .. "|profKey:" .. LimboTracker.clean(record.profKey)
        .. "|fps:" .. tostring(tonumber(record.fps) or 0)
        .. "|ping:" .. tostring(tonumber(record.ping) or 0)
        .. "|exitmode:" .. tostring(exitMode) .. ":" .. exitLabel .. "\n"
end

function LimboTracker.writeLog(record)
    if not record then return false end
    local path = "ParadiseLimboTracker/" .. os.date("%Y-%m-%d") .. ".log"
    local writer = getFileWriter(path, true, true)
    if not writer then return false end
    local line = LimboTracker.formatLog(record)
    if not line then writer:close() return false end
    writer:write(line)
    writer:close()
    return true
end

function LimboTracker.persist()
    if ModData.transmit then ModData.transmit(LimboTracker.StoreName) end
end

function LimboTracker.save(record)
    LimboTracker.persist()
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
    LimboTracker.persist()
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
    local wasInitialized = record.initialized == true
    local previousExitMode = tonumber(record.exitMode)
    if wasInitialized and previousExitMode == -1 then LimboTracker.writeLog(record) end
    LimboTracker.releaseExpired(pl, record, now)
    local exitMode = previousExitMode
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
    LimboTracker.persist()
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
