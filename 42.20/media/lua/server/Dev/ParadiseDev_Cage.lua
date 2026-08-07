ParadiseDev = ParadiseDev or {}
ParadiseDev.Cage = ParadiseDev.Cage or {}

ParadiseDev.Cage.StoreName = "ParadiseDev_IsCaged"

function ParadiseDev.Cage.getStore()
    local store = ModData.getOrCreate("ParadiseDev_IsCaged")
    store.players = store.players or {}
    return store
end

function ParadiseDev.Cage.getSteamId(player)
    if not player or not player.getSteamID then return nil end
    local steamId = tostring(player:getSteamID())
    if steamId == "" or steamId == "0" then return nil end
    return steamId
end

function ParadiseDev.Cage.isAdmin(player)
    return player and string.lower(tostring(player:getAccessLevel())) == "admin"
end

function ParadiseDev.Cage.findPlayer(username)
    if not username or username == "" then return nil end
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players then return nil end
    for index = 0, players:size() - 1 do
        local player = players:get(index)
        if player and player:getUsername() == username then return player end
    end
    return nil
end

function ParadiseDev.Cage.isCaged(player)
    local steamId = ParadiseDev.Cage.getSteamId(player)
    return steamId and ParadiseDev.Cage.getStore().players[steamId] == true or false
end

function ParadiseDev.Cage.setTrait(player, isCaged)
    if not player then return end
    if isCaged then
        if not player:hasTrait("Caged") then player:getCharacterTraits():add("Caged") end
    elseif player:hasTrait("Caged") then
        player:getCharacterTraits():remove("Caged")
    end
    if sendSyncPlayerFields then sendSyncPlayerFields(player, 2) end
end

function ParadiseDev.Cage.syncPlayer(player)
    if not player then return false end
    local isCaged = ParadiseDev.Cage.isCaged(player)
    ParadiseDev.Cage.setTrait(player, isCaged)
    return isCaged
end

function ParadiseDev.Cage.getEntries()
    local entries = {}
    local included = {}
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if players then
        for index = 0, players:size() - 1 do
            local player = players:get(index)
            local steamId = ParadiseDev.Cage.getSteamId(player)
            if steamId then
                included[steamId] = true
                entries[#entries + 1] = {
                    steamId = steamId,
                    username = player:getUsername(),
                    displayName = player:getDisplayName(),
                    isCaged = ParadiseDev.Cage.isCaged(player),
                    online = true,
                }
            end
        end
    end
    for steamId, isCaged in pairs(ParadiseDev.Cage.getStore().players) do
        if isCaged == true and not included[steamId] then
            entries[#entries + 1] = {
                steamId = steamId,
                username = "",
                displayName = "",
                isCaged = true,
                online = false,
            }
        end
    end
    table.sort(entries, function(a, b)
        return tostring(a.username or a.steamId) < tostring(b.username or b.steamId)
    end)
    return entries
end

function ParadiseDev.Cage.sendState(player)
    if not player then return end
    sendServerCommand(player, "ParadiseDevCage", "state", { entries = ParadiseDev.Cage.getEntries() })
end

function ParadiseDev.Cage.set(player, isCaged)
    local steamId = ParadiseDev.Cage.getSteamId(player)
    if not steamId then return false, "The target player has no Steam ID." end
    local store = ParadiseDev.Cage.getStore()
    if isCaged then
        store.players[steamId] = true
    else
        store.players[steamId] = nil
    end
    ModData.transmit("ParadiseDev_IsCaged")
    ParadiseDev.Cage.setTrait(player, isCaged)

    local engine = ParadiseDev.Zones and ParadiseDev.Zones.Engine or nil
    if not engine then return true end
    if isCaged then
        engine.captureCageReturn(player)
        local zone = engine.nearestCageZone(player)
        if zone then engine.assignCage(player, zone) end
    else
        engine.releaseCage(player)
        engine.restoreCageReturn(player)
    end
    return true
end

function ParadiseDev.Cage.onClientCommand(module, command, player, args)
    if module ~= "ParadiseDevCage" or not ParadiseDev.Cage.isAdmin(player) then return end
    if command == "list" then
        ParadiseDev.Cage.sendState(player)
        return
    end
    if command ~= "set" then return end
    if args and args.steamId and args.isCaged ~= true then
        ParadiseDev.Cage.getStore().players[tostring(args.steamId)] = nil
        ModData.transmit("ParadiseDev_IsCaged")
        ParadiseDev.Cage.sendState(player)
        return
    end
    local target = ParadiseDev.Cage.findPlayer(args and args.username)
    if not target then
        ParadiseDev.Cage.sendState(player)
        return
    end
    ParadiseDev.Cage.set(target, args.isCaged == true)
    ParadiseDev.Cage.sendState(player)
end

function ParadiseDev.Cage.onInitGlobalModData()
    ParadiseDev.Cage.getStore()
end

Events.OnInitGlobalModData.Add(ParadiseDev.Cage.onInitGlobalModData)
Events.OnClientCommand.Add(ParadiseDev.Cage.onClientCommand)
