-- Multiplayer clients also load server-directory Lua. Trait assignment and
-- native replication must remain on the authoritative server.
if isClient and isClient() then return end
ParadiseDev = ParadiseDev or {}
ParadiseDev.TraitSyncer = ParadiseDev.TraitSyncer or {}
local Syncer = ParadiseDev.TraitSyncer
Syncer.stateRevision = Syncer.stateRevision or 0
Syncer.pveSent = setmetatable({}, {__mode="k"})
Syncer.StoreName = "ParadiseDev_TraitSyncer"
Syncer.Traits = {"ParadiseDev:TheRangeStaff", "ParadiseDev:Caged", "ParadiseDev:InjuredPvP", "ParadiseDev:PvE"}
function Syncer.getStore()
    local store = ModData.getOrCreate(Syncer.StoreName); store.players = store.players or {}; return store
end
function Syncer.findPlayer(username)
    if not username or not getOnlinePlayers then return nil end
    local players = getOnlinePlayers()
    for i = 0, players:size() - 1 do
        if string.lower(tostring(players:get(i):getUsername())) == string.lower(tostring(username)) then return players:get(i) end
    end
    return nil
end
function Syncer.getStateRecord(pl, record, cageEntry)
    local state = {}
    for _, traitId in ipairs(Syncer.Traits) do
        if traitId == "ParadiseDev:Caged" then
            state[traitId] = cageEntry and cageEntry.isCaged == true or false
        elseif record and record[traitId] ~= nil then
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
    local cageEntries = ParadiseDev.Cage and ParadiseDev.Cage.getEntries and ParadiseDev.Cage.getEntries() or {}
    local cages = {}
    for _, entry in ipairs(cageEntries) do
        if entry.username then cages[string.lower(tostring(entry.username))] = entry end
    end
    local pls = getOnlinePlayers and getOnlinePlayers() or nil
    if pls then
        for i = 0, pls:size() - 1 do
            local pl = pls:get(i)
            local user = pl and pl.getUsername and tostring(pl:getUsername()) or nil
            if user then
                entries[#entries + 1] = {username = user, traits = Syncer.getStateRecord(pl, store.players[user], cages[string.lower(user)])}
                seen[string.lower(user)] = true
            end
        end
    end
    for user, record in pairs(store.players) do
        if not seen[string.lower(tostring(user))] then
            local traits = {}
            for traitId, enabled in pairs(record) do traits[traitId] = enabled end
            local cageEntry = cages[string.lower(tostring(user))]
            traits["ParadiseDev:Caged"] = cageEntry and cageEntry.isCaged == true or false
            entries[#entries + 1] = {username = user, traits = traits}
            seen[string.lower(tostring(user))] = true
        end
    end
    for _, entry in ipairs(cageEntries) do
        local user = entry.username
        if user and not seen[string.lower(tostring(user))] then
            entries[#entries + 1] = {username = user, traits = Syncer.getStateRecord(nil, nil, entry)}
            seen[string.lower(tostring(user))] = true
        end
    end
    return entries
end
function Syncer.sendState(player)
    sendServerCommand(player, "ParadiseDevTraitSyncer", "state", {entries = Syncer.getStateEntries(), revision = Syncer.stateRevision})
end
function Syncer.sendAdminStates(requester)
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    local sent = false
    if players then
        local state = {entries = Syncer.getStateEntries(), revision = Syncer.stateRevision}
        for i = 0, players:size() - 1 do
            local player = players:get(i)
            if ParadiseRestore.isAdm(player) then
                sendServerCommand(player, "ParadiseDevTraitSyncer", "state", state)
                if player == requester then sent = true end
            end
        end
    end
    if requester and not sent then Syncer.sendState(requester) end
end

function Syncer.getStoredRecord(username)
    local players = Syncer.getStore().players
    if players[username] then return players[username], username end
    local found, key
    for name, record in pairs(players) do
        if string.lower(tostring(name)) == string.lower(tostring(username)) then
            -- Do not guess if old data contains conflicting account spellings.
            if found then return nil, nil, true end
            found, key = record, name
        end
    end
    return found, key, false
end
function Syncer.applyOnline(username, traitId, enabled)
    local target = Syncer.findPlayer(username)
    if not target then return true end
    if traitId == "ParadiseDev:Caged" and ParadiseDev.Cage and ParadiseDev.Cage.set then
        ParadiseDev.Cage.set(target, enabled)
        return
    end
    if not target:getCharacterTraits() or not ParadiseDev.hasTrait then return false end
    if traitId == "ParadiseDev:PvE" then
        -- This status trait has no XP boosts. Resolve its registered B42 type
        -- directly; neither display-label lookup nor the admin SyncXp path is needed.
        local trait = ParadiseDev.getTrait and ParadiseDev.getTrait(traitId)
        if not trait then return false end
        if target:hasTrait(trait) ~= enabled then
            if enabled then target:getCharacterTraits():add(trait)
            else target:getCharacterTraits():remove(trait) end
        end
    elseif ParadiseDev.hasTrait(target, traitId) ~= enabled then
        if not ParadiseDev.setTrait then return false end
        ParadiseDev.setTrait(traitId, enabled, target)
    end
    if ParadiseDev.hasTrait(target, traitId) ~= enabled then return false end
    if sendSyncPlayerFields then sendSyncPlayerFields(target, 2) end
    if traitId == "ParadiseDev:PvE" then
        Syncer.stateRevision = Syncer.stateRevision + 1
        Syncer.pveSent[target] = enabled
        -- Native trait fields go only to their owner, not other administrators.
        -- Confirm the current assignment as well, without asking the owner to
        -- send a capability-restricted XP packet back to the server.
        sendServerCommand(target, "ParadiseDevTraitSyncer", "pve", {
            username = tostring(target:getUsername()), enabled = enabled, revision = Syncer.stateRevision,
        })
    end
    if traitId == "ParadiseDev:PvE" and ParadiseDev.PvEPolicy and ParadiseDev.PvEPolicy.refreshPlayer then
        ParadiseDev.PvEPolicy.refreshPlayer(target)
    end
    return true
end
function Syncer.onClientCommand(module, command, player, args)
    if module ~= "ParadiseDevTraitSyncer" or not ParadiseRestore.isAdm(player) then return end
    local store = Syncer.getStore()
    if command == "list" then Syncer.sendState(player); return end
    if command ~= "set" or type(args) ~= "table" or not args.username or not args.trait then return end
    local allowed = false; for _, traitId in ipairs(Syncer.Traits) do if traitId == args.trait then allowed = true; break end end
    if not allowed then return end
    if type(args.username) ~= "string" or args.username == "" or #args.username > 128
        or args.username:find("[%c]") or type(args.enabled) ~= "boolean" then return end
    if args.trait == "ParadiseDev:Caged" then
        local cage = ParadiseDev.Cage
        if not cage or not cage.onClientCommand or not cage.getEntries then return end
        local request = {username = tostring(args.username), isCaged = args.enabled == true}
        for _, entry in ipairs(cage.getEntries()) do
            if string.lower(tostring(entry.username or "")) == string.lower(request.username) then
                request.key = entry.key
                break
            end
        end
        cage.onClientCommand("ParadiseDevCage", "set", player, request)
        Syncer.sendState(player)
        return
    end
    local target = Syncer.findPlayer(args.username)
    local username = target and tostring(target:getUsername()) or args.username
    local record, recordKey, ambiguous = Syncer.getStoredRecord(username)
    if ambiguous then
        sendServerCommand(player, "ParadiseDevTraitSyncer", "error", {message="Conflicting stored usernames; review trait assignments."})
        return
    end
    if not Syncer.applyOnline(username, args.trait, args.enabled) then
        sendServerCommand(player, "ParadiseDevTraitSyncer", "error", {message="Trait change was not applied; refresh and retry."})
        return
    end
    record = record or {}
    if recordKey and recordKey ~= username then store.players[recordKey] = nil end
    store.players[username] = record
    record[args.trait] = args.enabled
    if not target then Syncer.stateRevision = Syncer.stateRevision + 1 end
    ModData.transmit(Syncer.StoreName); Syncer.sendAdminStates(player)
end
-- Replay server-owned PvE assignments after reconnect. The client must not
-- replay an old local record over a newer native server trait packet.
Syncer.playerSync = setmetatable({}, {__mode="k"})
function Syncer.onPlayerUpdate(player)
    if not player or not player.getUsername then return end
    local now = getTimestampMs and getTimestampMs() or 0
    local last = Syncer.playerSync[player]
    if last and now >= last and now - last < 1000 then return end
    Syncer.playerSync[player] = now
    local record = Syncer.getStoredRecord(tostring(player:getUsername()))
    local enabled = record and record["ParadiseDev:PvE"]
    if type(enabled) ~= "boolean" or not ParadiseDev.hasTrait then return end
    if Syncer.pveSent[player] ~= enabled or ParadiseDev.hasTrait(player, "ParadiseDev:PvE") ~= enabled then
        if Syncer.applyOnline(tostring(player:getUsername()), "ParadiseDev:PvE", enabled) then Syncer.sendAdminStates() end
    end
end
-- Dedicated-server remote players do not emit OnPlayerUpdate. Reconcile the
-- authoritative online roster from the server tick instead, once per second.
if Syncer.reconcileOnline then Events.OnTick.Remove(Syncer.reconcileOnline) end
Syncer.lastSweep = nil
function Syncer.reconcileOnline()
    local now = getTimestampMs()
    if Syncer.lastSweep and now >= Syncer.lastSweep and now - Syncer.lastSweep < 1000 then return end
    Syncer.lastSweep = now
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players then return end
    for i = 0, players:size() - 1 do Syncer.onPlayerUpdate(players:get(i)) end
end
function Syncer.onInitGlobalModData() Syncer.getStore() end
Events.OnInitGlobalModData.Remove(Syncer.onInitGlobalModData)
Events.OnInitGlobalModData.Add(Syncer.onInitGlobalModData)
Events.OnClientCommand.Remove(Syncer.onClientCommand)
Events.OnClientCommand.Add(Syncer.onClientCommand)
Events.OnPlayerUpdate.Remove(Syncer.onPlayerUpdate)
Events.OnTick.Remove(Syncer.reconcileOnline)
Events.OnTick.Add(Syncer.reconcileOnline)
