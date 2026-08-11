ParadiseDev = ParadiseDev or {}
ParadiseDev.Cage = ParadiseDev.Cage or {}



ParadiseDev.Cage.StoreName = "ParadiseDev_IsCaged"
ParadiseDev.Cage.trait = "ParadiseDev:Caged"

function ParadiseDev.Cage.getStore()
    local store = ModData.getOrCreate("ParadiseDev_IsCaged")
    store.players = store.players or {}
    store.names = store.names or {}
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
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players then return nil end
    for index = 0, players:size() - 1 do
        local pl = players:get(index)
        if pl and pl:getUsername() == username then return pl end
    end
    return nil
end

function ParadiseDev.Cage.isCaged(pl)
    local key = ParadiseDev.Cage.getKey(pl)
    return key and ParadiseDev.Cage.getStore().players[key] == true or false
end

function ParadiseDev.Cage.setTrait(pl, isCaged)
    if not pl then return end
    local trait = ParadiseDev.getTrait(ParadiseDev.Cage.trait)
    if not trait then return end
    if isCaged then
        if not ParadiseDev.hasTrait(pl, trait) then pl:getCharacterTraits():add(trait) end
    elseif ParadiseDev.hasTrait(pl, trait) then
        pl:getCharacterTraits():remove(trait)
    end
    if sendSyncPlayerFields then sendSyncPlayerFields(pl, 2) end
end

function ParadiseDev.Cage.syncPlayer(pl)
    if not pl then return false end
    local isCaged = ParadiseDev.Cage.isCaged(pl)
    ParadiseDev.Cage.setTrait(pl, isCaged)
    return isCaged
end

function ParadiseDev.Cage.getEntries()
    local entries = {}
    local included = {}
    local store = ParadiseDev.Cage.getStore()
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if players then
        for index = 0, players:size() - 1 do
            local pl = players:get(index)
            local key = ParadiseDev.Cage.getKey(pl)
            if key then
                local username = ParadiseDev.Cage.getUsername(pl) or ""
                included[key] = true
                entries[#entries + 1] = {
                    key = key,
                    steamId = ParadiseDev.Cage.getSteamId(pl) or "",
                    username = username,
                    displayName = pl:getDisplayName() or username,
                    isCaged = ParadiseDev.Cage.isCaged(pl),
                    online = true,
                }
            end
        end
    end
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
    table.sort(entries, function(a, b)
        return tostring(a.username or a.key) < tostring(b.username or b.key)
    end)
    return entries
end

function ParadiseDev.Cage.sendState(pl)
    if not pl then return end
    sendServerCommand(pl, "ParadiseDevCage", "state", { entries = ParadiseDev.Cage.getEntries() })
end

function ParadiseDev.Cage.set(pl, isCaged)
    local key = ParadiseDev.Cage.getKey(pl)
    if not key then return false, "The target player has no cage identity." end
    ParadiseDev.Cage.setStored(key, ParadiseDev.Cage.getUsername(pl), isCaged)
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
    if target then
        ParadiseDev.Cage.set(target, args.isCaged == true)
    elseif ParadiseDev.Cage.isSteamMode() and username and username ~= "" then
        ParadiseDev.Cage.setStored(username, username, args.isCaged == true)
    end
    ParadiseDev.Cage.sendState(pl)
end

function ParadiseDev.Cage.onInitGlobalModData()
    ParadiseDev.Cage.getStore()
end

Events.OnInitGlobalModData.Add(ParadiseDev.Cage.onInitGlobalModData)
Events.OnClientCommand.Add(ParadiseDev.Cage.onClientCommand)
