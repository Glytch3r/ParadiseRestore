if isClient() then return end

SoulCatcher = SoulCatcher or {}
SoulCatcher.dir = "SoulCatcher"
SoulCatcher.StoreName = "ParadiseSoulCatcher"

function SoulCatcher.isSteamMode()
    return getSteamModeActive and getSteamModeActive() or false
end

function SoulCatcher.getUsername(pl)
    local user = pl and pl.getUsername and pl:getUsername() or nil
    if not user or tostring(user) == "" then return nil end
    return tostring(user)
end

function SoulCatcher.getSteamIdOrUser(pl)
    if not pl then return nil end
    if SoulCatcher.isSteamMode() and pl.getSteamID then
        local id = tostring(pl:getSteamID() or "")
        if id ~= "" and id ~= "0" then return id end
    end
    local user = SoulCatcher.getUsername(pl)
    return user and string.lower(user) or nil
end

function SoulCatcher.getIdentity(pl)
    local idOrUser = SoulCatcher.getSteamIdOrUser(pl)
    local user = SoulCatcher.getUsername(pl)
    local desc = pl and pl.getDescriptor and pl:getDescriptor() or nil
    if not idOrUser or not user or not desc then return nil end
    local prof = desc.getCharacterProfession and desc:getCharacterProfession() or nil
    return {
        idOrUser = idOrUser,
        username = user,
        firstname = desc.getForename and tostring(desc:getForename() or "") or "",
        surname = desc.getSurname and tostring(desc:getSurname() or "") or "",
        profKey = prof and prof.getName and tostring(prof:getName() or "")
            or (desc.getProfession and tostring(desc:getProfession() or "") or ""),
    }
end

function SoulCatcher.clean(var)
    return tostring(var or ""):gsub("[%c|]", "_")
end

function SoulCatcher.getStore()
    local store = ModData.getOrCreate(SoulCatcher.StoreName)
    store.players = store.players or {}
    store.souls = store.souls or {}
    store.nextSoulID = tonumber(store.nextSoulID) or 0
    return store
end

function SoulCatcher.transmit()
    if ModData.transmit then ModData.transmit(SoulCatcher.StoreName) end
end

function SoulCatcher.updateIdentity(soul, identity)
    if not soul or not identity then return false end
    soul.idOrUser = identity.idOrUser
    soul.username = identity.username
    soul.firstname = identity.firstname
    soul.surname = identity.surname
    soul.profKey = identity.profKey
    soul.updatedTimestamp = getTimestamp()
    return true
end

function SoulCatcher.createSoul(pl)
    local identity = SoulCatcher.getIdentity(pl)
    if not identity then return nil end
    local store = SoulCatcher.getStore()
    store.nextSoulID = store.nextSoulID + 1
    local soulKey = SoulCatcher.clean(identity.idOrUser) .. "_" .. tostring(getTimestamp()) .. "_" .. tostring(store.nextSoulID)
    local soul = {
        soulKey = soulKey,
        reincarnatedTimes = 0,
        lifeHours = 0,
        totalHours = 0,
        lastRecordedHours = 0,
        createdTimestamp = getTimestamp(),
    }
    SoulCatcher.updateIdentity(soul, identity)
    store.souls[soulKey] = soul
    store.players[identity.idOrUser] = { username = identity.username, currentSoulKey = soulKey }
    return soul
end

function SoulCatcher.getCurrentSoul(pl)
    local identity = SoulCatcher.getIdentity(pl)
    if not identity then return nil end
    local store = SoulCatcher.getStore()
    local playerRecord = store.players[identity.idOrUser]
    return playerRecord and store.souls[playerRecord.currentSoulKey] or nil
end

function SoulCatcher.isReincarnating(pl)
    local user = SoulCatcher.getUsername(pl)
    local tab = ParadiseDev and ParadiseDev.Reincarnate and ParadiseDev.Reincarnate.serverReincarnating or nil
    return user and tab and tab[user] == true or false
end

function SoulCatcher.formatLog(pl, soul, reportMsg)
    local identity = SoulCatcher.getIdentity(pl)
    if not identity or not soul or type(reportMsg) ~= "string" then return nil end
    return "[SoulCatcher]|serverTimestamp:" .. tostring(getTimestamp())
        .. "|key:" .. SoulCatcher.clean(identity.idOrUser)
        .. "|username:" .. SoulCatcher.clean(identity.username)
        .. "|firstname:" .. SoulCatcher.clean(identity.firstname)
        .. "|surname:" .. SoulCatcher.clean(identity.surname)
        .. "|profKey:" .. SoulCatcher.clean(identity.profKey)
        .. "|soulKey:" .. SoulCatcher.clean(soul.soulKey)
        .. "|reportMsg:" .. SoulCatcher.clean(reportMsg)
        .. "|reincarnatedTimes:" .. tostring(tonumber(soul.reincarnatedTimes) or 0)
        .. "|lifeHours:" .. tostring(tonumber(soul.lifeHours) or 0)
        .. "|totalHours:" .. tostring(tonumber(soul.totalHours) or 0)
        .. "|x:" .. tostring(pl:getX())
        .. "|y:" .. tostring(pl:getY())
        .. "|z:" .. tostring(pl:getZ()) .. "\n"
end

function SoulCatcher.writeLog(pl, soul, reportMsg)
    local line = SoulCatcher.formatLog(pl, soul, reportMsg)
    if not line then return false end
    local writer = getFileWriter(SoulCatcher.dir .. "/" .. os.date("%Y-%m-%d") .. ".log", true, true)
    if not writer then return false end
    writer:write(line)
    writer:close()
    return true
end

function SoulCatcher.recordSpawn(pl)
    local reincarnating = SoulCatcher.isReincarnating(pl)
    local soul = reincarnating and SoulCatcher.getCurrentSoul(pl) or nil
    if not soul then soul = SoulCatcher.createSoul(pl) end
    if not soul then return false end
    if reincarnating then soul.reincarnatedTimes = (tonumber(soul.reincarnatedTimes) or 0) + 1 end
    SoulCatcher.updateIdentity(soul, SoulCatcher.getIdentity(pl))
    SoulCatcher.transmit()
    return SoulCatcher.writeLog(pl, soul, reincarnating and "Reincarnate Spawned" or "New Character Spawned")
end

function SoulCatcher.recordDeath(pl)
    local soul = SoulCatcher.getCurrentSoul(pl) or SoulCatcher.createSoul(pl)
    if not soul then return false end
    local hours = pl and pl.getHoursSurvived and tonumber(pl:getHoursSurvived()) or 0
    hours = math.max(0, hours or 0)
    local keepTime = SandboxVars and SandboxVars.ParadiseZ and SandboxVars.ParadiseZ.ReincarnateKeepSurvivalTime == true
    local lifeHours = keepTime and math.max(0, hours - (tonumber(soul.lastRecordedHours) or 0)) or hours
    soul.lifeHours = lifeHours
    soul.totalHours = (tonumber(soul.totalHours) or 0) + lifeHours
    soul.lastRecordedHours = hours
    SoulCatcher.updateIdentity(soul, SoulCatcher.getIdentity(pl))
    SoulCatcher.transmit()
    return true
end

function SoulCatcher.onInitGlobalModData()
    SoulCatcher.getStore()
end
Events.OnInitGlobalModData.Remove(SoulCatcher.onInitGlobalModData)
Events.OnInitGlobalModData.Add(SoulCatcher.onInitGlobalModData)

function SoulCatcher.onPlayerDeath(pl)
    SoulCatcher.recordDeath(pl)
end
Events.OnPlayerDeath.Remove(SoulCatcher.onPlayerDeath)
Events.OnPlayerDeath.Add(SoulCatcher.onPlayerDeath)

function SoulCatcher.onCreatePlayer(_, pl)
    SoulCatcher.recordSpawn(pl)
end
Events.OnCreatePlayer.Remove(SoulCatcher.onCreatePlayer)
Events.OnCreatePlayer.Add(SoulCatcher.onCreatePlayer)
