ParadiseDev = ParadiseDev or {}
ParadiseDev.Cage = ParadiseDev.Cage or {}



ParadiseDev.Cage.StoreName = "ParadiseDev_IsCaged"
ParadiseDev.Cage.trait = "ParadiseDev:Caged"

function ParadiseDev.Cage.getStore()
    local store = ModData.getOrCreate("ParadiseDev_IsCaged")
    store.players = store.players or {}
    store.names = store.names or {}
    store.pending = store.pending or {}
    store.pendingNames = store.pendingNames or {}
    return store
end

function ParadiseDev.Cage.isSteamMode()
    return getSteamModeActive and getSteamModeActive() or false
end

function ParadiseDev.Cage.getUsername(pl)
    if not pl or not pl.getUsername then return nil end
    local username = pl:getUsername()
    if not username or tostring(username) == "" then return nil end
    return tostring(username)
end

function ParadiseDev.Cage.getSteamId(pl)
    if not pl or not pl.getSteamID then return nil end
    local steamId = tostring(pl:getSteamID())
    if steamId == "" or steamId == "0" then return nil end
    return steamId
end

function ParadiseDev.Cage.getKey(pl)
    if ParadiseDev.Cage.isSteamMode() then return ParadiseDev.Cage.getUsername(pl) end
    return ParadiseDev.Cage.getSteamId(pl)
end

function ParadiseDev.Cage.getUsernameKey(username)
    if not username or tostring(username) == "" then return nil end
    return string.lower(tostring(username))
end

function ParadiseDev.Cage.setPending(username, isCaged)
    local usernameKey = ParadiseDev.Cage.getUsernameKey(username)
    if not usernameKey then return false end
    local store = ParadiseDev.Cage.getStore()
    if isCaged then
        store.pending[usernameKey] = true
        store.pendingNames[usernameKey] = tostring(username)
    else
        store.pending[usernameKey] = nil
        store.pendingNames[usernameKey] = nil
    end
    ModData.transmit("ParadiseDev_IsCaged")
    return true
end

function ParadiseDev.Cage.setStored(key, username, isCaged)
    if not key or tostring(key) == "" then return false end
    key = tostring(key)
    local store = ParadiseDev.Cage.getStore()
    if isCaged then
        store.players[key] = true
        if username and tostring(username) ~= "" then store.names[key] = tostring(username) end
    else
        store.players[key] = nil
        store.names[key] = nil
    end
    ModData.transmit("ParadiseDev_IsCaged")
    return true
end


function ParadiseDev.Cage.findPlayer(username)
    if not username or username == "" then return nil end
    local usernameKey = ParadiseDev.Cage.getUsernameKey(username)
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players then return nil end
    for index = 0, players:size() - 1 do
        local pl = players:get(index)
        if pl and ParadiseDev.Cage.getUsernameKey(pl:getUsername()) == usernameKey then return pl end
    end
    return nil
end

function ParadiseDev.Cage.isCaged(pl)
    local key = ParadiseDev.Cage.getKey(pl)
    local usernameKey = ParadiseDev.Cage.getUsernameKey(ParadiseDev.Cage.getUsername(pl))
    local store = ParadiseDev.Cage.getStore()
    return (key and store.players[key] == true) or (usernameKey and store.pending[usernameKey] == true) or false
end

function ParadiseDev.Cage.setTrait(pl, isCaged)
    if not pl then return end
    local trait = ParadiseDev.getTrait(ParadiseDev.Cage.trait)
    if not trait then return end
    local changed = false
    if isCaged then
        if not ParadiseDev.hasTrait(pl, trait) then
            pl:getCharacterTraits():add(trait)
            changed = true
        end
    elseif ParadiseDev.hasTrait(pl, trait) then
        pl:getCharacterTraits():remove(trait)
        changed = true
    end
    if changed and sendSyncPlayerFields then sendSyncPlayerFields(pl, 2) end
    return changed
end

function ParadiseDev.Cage.syncPlayer(pl)
    if not pl then return false end
    local username = ParadiseDev.Cage.getUsername(pl)
    local usernameKey = ParadiseDev.Cage.getUsernameKey(username)
    local key = ParadiseDev.Cage.getKey(pl)
    local store = ParadiseDev.Cage.getStore()
    if usernameKey and key and store.pending[usernameKey] == true then
        ParadiseDev.Cage.setStored(key, username, true)
        ParadiseDev.Cage.setPending(username, false)
    end
    local isCaged = ParadiseDev.Cage.isCaged(pl)
    ParadiseDev.Cage.setTrait(pl, isCaged)
    return isCaged
end

function ParadiseDev.Cage.getEntries(extraPlayer)
    local entries = {}
    local included = {}
    local includedUsernames = {}
    local store = ParadiseDev.Cage.getStore()
    local function addPlayer(pl)
        local key = ParadiseDev.Cage.getKey(pl)
        if not key or included[key] then return end
        local username = ParadiseDev.Cage.getUsername(pl) or ""
        included[key] = true
        local usernameKey = ParadiseDev.Cage.getUsernameKey(username)
        if usernameKey then includedUsernames[usernameKey] = true end
        entries[#entries + 1] = {
            key = key,
            steamId = ParadiseDev.Cage.getSteamId(pl) or "",
            username = username,
            displayName = pl:getDisplayName() or username,
            isCaged = ParadiseDev.Cage.isCaged(pl),
            online = true,
        }
    end
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if players then
        for index = 0, players:size() - 1 do
            addPlayer(players:get(index))
        end
    end
    addPlayer(extraPlayer)
    for key, isCaged in pairs(store.players) do
        if isCaged == true and not included[key] then
            entries[#entries + 1] = {
                key = key,
                steamId = ParadiseDev.Cage.isSteamMode() and "" or key,
                username = store.names[key] or (ParadiseDev.Cage.isSteamMode() and key or ""),
                displayName = "",
                isCaged = true,
                online = false,
            }
        end
    end
    for usernameKey, isCaged in pairs(store.pending) do
        if isCaged == true and not includedUsernames[usernameKey] then
            entries[#entries + 1] = {
                key = "username:" .. usernameKey,
                steamId = "",
                username = store.pendingNames[usernameKey] or usernameKey,
                displayName = "",
                isCaged = true,
                online = false,
            }
        end
    end
    table.sort(entries, function(a, b)
        return tostring(a.username or a.key) < tostring(b.username or b.key)
    end)
    return entries
end

function ParadiseDev.Cage.sendState(pl)
    if not pl then return end
    sendServerCommand(pl, "ParadiseDevCage", "state", { entries = ParadiseDev.Cage.getEntries(pl) })
end

function ParadiseDev.Cage.set(pl, isCaged)
    local key = ParadiseDev.Cage.getKey(pl)
    if not key then return false, "The target player has no cage identity." end
    ParadiseDev.Cage.setStored(key, ParadiseDev.Cage.getUsername(pl), isCaged)
    ParadiseDev.Cage.setPending(ParadiseDev.Cage.getUsername(pl), false)
    ParadiseDev.Cage.setTrait(pl, isCaged)

    local engine = ParadiseDev.Zones and ParadiseDev.Zones.Engine or nil
    if not engine then return true end
    if isCaged then
        engine.captureCageReturn(pl)
        local zone = engine.nearestCageZone(pl)
        if zone then engine.assignCage(pl, zone) end
    else
        engine.releaseCage(pl)
        engine.restoreCageReturn(pl)
    end
    return true
end

function ParadiseDev.Cage.onClientCommand(module, command, pl, args)
    if module ~= "ParadiseDevCage" or not ParadiseDev.isAdm(pl) then return end
    if command == "list" then
        ParadiseDev.Cage.sendState(pl)
        return
    end
    if command == "chatSet" then
        local username = args and args.username or ParadiseDev.Cage.getUsername(pl)
        local target = ParadiseDev.Cage.findPlayer(username)
        if not target and ParadiseDev.Cage.getUsername(pl) == username then target = pl end
        local isCaged = args and args.isCaged
        if isCaged == nil then
            isCaged = target and not ParadiseDev.Cage.isCaged(target) or not ParadiseDev.Cage.getStore().pending[ParadiseDev.Cage.getUsernameKey(username)]
        end
        if target then
            ParadiseDev.Cage.set(target, isCaged)
        else
            ParadiseDev.Cage.setPending(username, isCaged)
        end
        ParadiseDev.Cage.sendState(pl)
        return
    end
    if command ~= "set" then return end
    if args and args.key then
        ParadiseDev.Cage.setStored(args.key, args.username, args.isCaged == true)
        ParadiseDev.Cage.sendState(pl)
        return
    end
    if args and args.steamId then
        ParadiseDev.Cage.setStored(args.steamId, args.username, args.isCaged == true)
        ParadiseDev.Cage.sendState(pl)
        return
    end
    local username = args and args.username or nil
    local target = ParadiseDev.Cage.findPlayer(username)
    if not target and ParadiseDev.Cage.getUsername(pl) == username then target = pl end
    if target then
        ParadiseDev.Cage.set(target, args.isCaged == true)
    elseif username and username ~= "" then
        ParadiseDev.Cage.setPending(username, args.isCaged == true)
    end
    ParadiseDev.Cage.sendState(pl)
end

function ParadiseDev.Cage.onInitGlobalModData()
    ParadiseDev.Cage.getStore()
end

function ParadiseDev.Cage.onPlayerUpdate(pl)
    if not pl then return end
    local now = getGameTime():getWorldAgeHours()
    local key = ParadiseDev.Cage.getKey(pl) or ParadiseDev.Cage.getUsername(pl)
    if not key then return end
    ParadiseDev.Cage.traitSyncTimes = ParadiseDev.Cage.traitSyncTimes or {}
    if ParadiseDev.Cage.traitSyncTimes[key] and now - ParadiseDev.Cage.traitSyncTimes[key] < 0.01 then return end
    ParadiseDev.Cage.traitSyncTimes[key] = now
    ParadiseDev.Cage.syncPlayer(pl)
end

Events.OnInitGlobalModData.Add(ParadiseDev.Cage.onInitGlobalModData)
Events.OnClientCommand.Add(ParadiseDev.Cage.onClientCommand)
Events.OnPlayerUpdate.Add(ParadiseDev.Cage.onPlayerUpdate)

ParadiseDev.GlobalModData = ParadiseDev.GlobalModData or {}
ParadiseDev.GlobalModData.module = "ParadiseDevGlobalModData"

function ParadiseDev.GlobalModData.resolveParent(data, path)
    if type(path) ~= "table" or #path == 0 then return data, nil end
    local target = data
    for index = 1, #path - 1 do
        target = target[path[index]]
        if type(target) ~= "table" then return nil, nil end
    end
    return target, path[#path]
end

function ParadiseDev.GlobalModData.sync(pl, name, removed)
    if removed then
        sendServerCommand(pl, ParadiseDev.GlobalModData.module, "removed", { name = name })
        return
    end
    ModData.transmit(name)
    sendServerCommand(pl, ParadiseDev.GlobalModData.module, "updated", { name = name })
end

function ParadiseDev.GlobalModData.onClientCommand(module, command, pl, args)
    if module ~= ParadiseDev.GlobalModData.module or not pl or not ParadiseDev.isAdm(pl) then return end
    local name = args and tostring(args.name or "") or ""
    if name == "" then return end
    if command == "addTable" then
        ModData.getOrCreate(name)
        ParadiseDev.GlobalModData.sync(pl, name)
        return
    end
    if command == "deleteTable" then
        ModData.remove(name)
        ParadiseDev.GlobalModData.sync(pl, name, true)
        return
    end
    local data = ModData.get(name)
    if not data then return end
    local target, key = ParadiseDev.GlobalModData.resolveParent(data, args.path)
    if not target then target, key = data, args.key end
    if key == nil or tostring(key) == "" then return end
    if command == "setValue" then
        target[key] = args.value
    elseif command == "deleteValue" then
        target[key] = nil
    else
        return
    end
    ParadiseDev.GlobalModData.sync(pl, name)
end

Events.OnClientCommand.Remove(ParadiseDev.GlobalModData.onClientCommand)
Events.OnClientCommand.Add(ParadiseDev.GlobalModData.onClientCommand)
