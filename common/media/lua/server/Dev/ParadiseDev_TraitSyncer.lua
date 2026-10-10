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
local function life() return ParadiseDev.LifeProfilesServer end
local function pveContext(pl)
    local service=life()
    return service and service.getPvEContext and service.getPvEContext(pl) or {ready=false,reason="Profile policy is not ready"}
end
local function contextSignature(context)
    return tostring(context.contextId)..":"..tostring(context.pveRevision)..":"..tostring(context.pve)
end
function Syncer.getStateRecord(pl, record, cageEntry)
    local state = {}
    for _, traitId in ipairs(Syncer.Traits) do
        if traitId == "ParadiseDev:Caged" then
            state[traitId] = cageEntry and cageEntry.isCaged == true or false
        elseif traitId == "ParadiseDev:PvE" then
            local context=pl and pveContext(pl)
            if context and context.ready then state[traitId]=context.pve end
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
                entries[#entries + 1] = {username = user, traits = Syncer.getStateRecord(pl, store.players[user], cages[string.lower(user)]), context=pveContext(pl)}
                seen[string.lower(user)] = true
            end
        end
    end
    for user, record in pairs(store.players) do
        if not seen[string.lower(tostring(user))] then
            local traits = {}
            for traitId, enabled in pairs(record) do if traitId~="ParadiseDev:PvE" then traits[traitId] = enabled end end
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
function Syncer.sendState(player,requestId)
    local service=life()
    sendServerCommand(player, "ParadiseDevTraitSyncer", "state", {
        entries=Syncer.getStateEntries(), profiles=service and service.getAdminPvEProfiles and service.getAdminPvEProfiles() or {},
        revision=Syncer.stateRevision,requestId=requestId,
    })
end
function Syncer.sendAdminStates(requester)
    -- A push invalidates observations. Only a correlated fresh request may
    -- supply an actionable body/profile token to an administrator's UI.
    local players=getOnlinePlayers and getOnlinePlayers()
    if players then for i=0,players:size()-1 do
        local player=players:get(i)
        if ParadiseRestore.isAdm(player) then
            sendServerCommand(player,"ParadiseDevTraitSyncer","invalidate",{revision=Syncer.stateRevision})
        end
    end end
end
Syncer.ownerRequests=setmetatable({}, {__mode="k"})
function Syncer.sendOwner(player,requestId)
    local context=pveContext(player)
    if not context.ready then return end
    local token=requestId or Syncer.ownerRequests[player]
    if not token then return end
    sendServerCommand(player,"ParadiseDevTraitSyncer","pve",{context=context,requestId=token,revision=Syncer.stateRevision})
end

function Syncer.getStoredRecord(username)
    local players = Syncer.getStore().players
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
function Syncer.applyOnline(username, traitId, enabled, exactTarget)
    local target = exactTarget or Syncer.findPlayer(username)
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
        local context=pveContext(target)
        Syncer.pveSent[target]=contextSignature(context)
        Syncer.sendOwner(target)
    end
    if traitId == "ParadiseDev:PvE" and ParadiseDev.PvEPolicy and ParadiseDev.PvEPolicy.refreshPlayer then
        ParadiseDev.PvEPolicy.refreshPlayer(target)
    end
    return true
end
function Syncer.onClientCommand(module, command, player, args)
    if module ~= "ParadiseDevTraitSyncer" then return end
    if command=="owner" then
        -- The transport supplies player. Never accept an account or body from
        -- this request; its bounded nonce only correlates the owner's reply.
        if type(args)=="table" and type(args.requestId)=="string" and #args.requestId<=96 then
            local now=getTimestampMs();local previous=Syncer.ownerRequests[player]
            local last=Syncer.ownerRequestTime and Syncer.ownerRequestTime[player]
            if last and now>=last and now-last<500 then return end
            Syncer.ownerRequestTime=Syncer.ownerRequestTime or setmetatable({}, {__mode="k"})
            Syncer.ownerRequestTime[player]=now;Syncer.ownerRequests[player]=args.requestId
            Syncer.sendOwner(player,args.requestId)
        end
        return
    end
    if not ParadiseRestore.isAdm(player) then return end
    local store = Syncer.getStore()
    if command == "list" then
        if type(args)=="table" and type(args.requestId)=="string" and #args.requestId<=96 then Syncer.sendState(player,args.requestId) end
        return
    end
    if command ~= "set" or type(args) ~= "table" or not args.username or not args.trait then return end
    local allowed = false; for _, traitId in ipairs(Syncer.Traits) do if traitId == args.trait then allowed = true; break end end
    if not allowed then return end
    if type(args.username) ~= "string" or args.username == "" or #args.username > 128
        or args.username:find("[%c]") or type(args.enabled) ~= "boolean" then return end
    if args.trait=="ParadiseDev:PvE" then
        local service=life()
        local ok,target
        if service and service.setTargetPvE then ok,target=service.setTargetPvE(args.username,args.context,args.enabled) end
        if not ok then
            sendServerCommand(player,"ParadiseDevTraitSyncer","error",{message=tostring(target or "Profile policy is unavailable")})
            return
        end
        local applied=true
        if target then
            local context=pveContext(target)
            applied=context.ready and Syncer.applyOnline(args.username,args.trait,context.pve,target)==true
        end
        Syncer.stateRevision=Syncer.stateRevision+1
        if applied then
            sendServerCommand(player,"ParadiseDevTraitSyncer","result",{message="PvE "..(args.enabled and "enabled" or "disabled").." for "..args.username.."'s selected profile/character."})
        else
            sendServerCommand(player,"ParadiseDevTraitSyncer","error",{message="The PvE choice was saved, but the active character could not be updated yet. The server will retry automatically."})
        end
        Syncer.sendAdminStates(player)
        return
    end
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
    if player.isDead and player:isDead() then return end
    local context=pveContext(player)
    if not context.ready or not ParadiseDev.hasTrait then return end
    local enabled=context.pve
    if Syncer.pveSent[player]~=contextSignature(context) or ParadiseDev.hasTrait(player,"ParadiseDev:PvE")~=enabled then
        if Syncer.applyOnline(tostring(player:getUsername()),"ParadiseDev:PvE",enabled,player) then Syncer.sendAdminStates() end
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
