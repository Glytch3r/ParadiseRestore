ParadiseDev = ParadiseDev or {}
ParadiseDev.TraitSyncer = ParadiseDev.TraitSyncer or {}
local Syncer = ParadiseDev.TraitSyncer
Syncer.StoreName = "ParadiseDev_TraitSyncer"
Syncer.Traits = {"ParadiseDev:TheRangeStaff", "ParadiseDev:Caged", "ParadiseDev:InjuredPvP", "ParadiseDev:PvE", "ParadiseDev:Reincarnate"}
function Syncer.getStore()
    local store = ModData.getOrCreate(Syncer.StoreName); store.players = store.players or {}; return store
end
function Syncer.findPlayer(username)
    if not username or not getOnlinePlayers then return nil end
    local players = getOnlinePlayers()
    for i = 0, players:size() - 1 do if tostring(players:get(i):getUsername()) == tostring(username) then return players:get(i) end end
    return nil
end
function Syncer.sendState(player)
    local entries = {}; local store = Syncer.getStore()
    for username, record in pairs(store.players) do entries[#entries + 1] = {username = username, traits = record} end
    sendServerCommand(player, "ParadiseDevTraitSyncer", "state", {entries = entries})
end
function Syncer.applyOnline(username, traitId, enabled)
    local target = Syncer.findPlayer(username)
    if not target then return end
    if traitId == "ParadiseDev:Caged" and ParadiseDev.Cage and ParadiseDev.Cage.set then
        ParadiseDev.Cage.set(target, enabled)
        return
    end
    local trait = ParadiseDev.getTrait and ParadiseDev.getTrait(traitId) or nil
    if not trait or not target:getCharacterTraits() then return end
    local traits = target:getCharacterTraits()
    local has = ParadiseDev.hasTrait and ParadiseDev.hasTrait(target, traitId) or false
    if enabled and not has then traits:add(trait)
    elseif not enabled and has then traits:remove(trait) end
    if sendSyncPlayerFields then sendSyncPlayerFields(target, 2) end
end
function Syncer.onClientCommand(module, command, player, args)
    if module ~= "ParadiseDevTraitSyncer" or not ParadiseDev.isAdm(player) then return end
    local store = Syncer.getStore()
    if command == "list" then Syncer.sendState(player); return end
    if command ~= "set" or not args or not args.username or not args.trait then return end
    local allowed = false; for _, traitId in ipairs(Syncer.Traits) do if traitId == args.trait then allowed = true; break end end
    if not allowed then return end
    store.players[tostring(args.username)] = store.players[tostring(args.username)] or {}
    store.players[tostring(args.username)][args.trait] = args.enabled == true or nil
    Syncer.applyOnline(tostring(args.username), args.trait, args.enabled == true)
    ModData.transmit(Syncer.StoreName); Syncer.sendState(player)
end
function Syncer.onInitGlobalModData() Syncer.getStore() end
Events.OnInitGlobalModData.Add(Syncer.onInitGlobalModData)
Events.OnClientCommand.Add(Syncer.onClientCommand)
