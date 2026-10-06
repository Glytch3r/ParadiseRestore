ParadiseDev = ParadiseDev or {}
ParadiseDev.TraitSyncer = ParadiseDev.TraitSyncer or {}
local Syncer = ParadiseDev.TraitSyncer
Syncer.StoreName = "ParadiseDev_TraitSyncer"
Syncer.Traits = {"ParadiseDev:TheRangeStaff", "ParadiseDev:Caged", "ParadiseDev:InjuredPvP", "ParadiseDev:PvE"}
function Syncer.getStore()
    local store = ModData.getOrCreate(Syncer.StoreName); store.players = store.players or {}; return store
end
function Syncer.findPlayer(username)
    if not username or not getOnlinePlayers then return nil end
    local players = getOnlinePlayers()
    for i = 0, players:size() - 1 do if tostring(players:get(i):getUsername()) == tostring(username) then return players:get(i) end end
    return nil
end
function Syncer.getStateRecord(pl, record)
    local state = {}
    for _, traitId in ipairs(Syncer.Traits) do
        if record and record[traitId] ~= nil then
            state[traitId] = record[traitId] == true
        else
            state[traitId] = ParadiseDev.hasTrait and ParadiseDev.hasTrait(pl, traitId) or false
        end
    end
    return state
end
function Syncer.getStateEntries()
    local entries = {}
    local seen = {}
    local store = Syncer.getStore()
    local pls = getOnlinePlayers and getOnlinePlayers() or nil
    if pls then
        for i = 0, pls:size() - 1 do
            local pl = pls:get(i)
            local user = pl and pl.getUsername and tostring(pl:getUsername()) or nil
            if user then
                entries[#entries + 1] = {username = user, traits = Syncer.getStateRecord(pl, store.players[user])}
                seen[string.lower(user)] = true
            end
        end
    end
    for user, record in pairs(store.players) do
        if not seen[string.lower(tostring(user))] then
            entries[#entries + 1] = {username = user, traits = record}
        end
    end
    return entries
end
function Syncer.sendState(player)
    sendServerCommand(player, "ParadiseDevTraitSyncer", "state", {entries = Syncer.getStateEntries()})
end
function Syncer.applyOnline(username, traitId, enabled)
    local target = Syncer.findPlayer(username)
    if not target then return end
    if traitId == "ParadiseDev:Caged" and ParadiseDev.Cage and ParadiseDev.Cage.set then
        ParadiseDev.Cage.set(target, enabled)
        return
    end
    if not target:getCharacterTraits() then return end
    ParadiseDev.setTrait(traitId, enabled, target)
    if sendSyncPlayerFields then sendSyncPlayerFields(target, 2) end
end
function Syncer.onClientCommand(module, command, player, args)
    if module ~= "ParadiseDevTraitSyncer" or not ParadiseRestore.isAdm(player) then return end
    local store = Syncer.getStore()
    if command == "list" then Syncer.sendState(player); return end
    if command ~= "set" or not args or not args.username or not args.trait then return end
    local allowed = false; for _, traitId in ipairs(Syncer.Traits) do if traitId == args.trait then allowed = true; break end end
    if not allowed then return end
    store.players[tostring(args.username)] = store.players[tostring(args.username)] or {}
    store.players[tostring(args.username)][args.trait] = args.enabled == true
    Syncer.applyOnline(tostring(args.username), args.trait, args.enabled == true)
    ModData.transmit(Syncer.StoreName); Syncer.sendState(player)
end
function Syncer.onInitGlobalModData() Syncer.getStore() end
Events.OnInitGlobalModData.Remove(Syncer.onInitGlobalModData)
Events.OnInitGlobalModData.Add(Syncer.onInitGlobalModData)
Events.OnClientCommand.Remove(Syncer.onClientCommand)
Events.OnClientCommand.Add(Syncer.onClientCommand)
