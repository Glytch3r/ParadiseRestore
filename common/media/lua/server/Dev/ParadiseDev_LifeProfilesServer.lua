-- Private, server-owned lifecycle. Never accept XP, identity or another user's
-- name from a client. The durable model is the authority for every transition.
if isClient and isClient() then return end
require "Dev/ParadiseDev_Reincarnate"
require "Dev/ParadiseDev_LifeProfiles"
require "Dev/ParadiseDev_LifeProfileStore"
require "Dev/ParadiseDev_LifeProfileNative"
require "Dev/ParadiseDev_LifeSpawnPolicy"
require "Dev/ParadiseDev_LifeAmbitions"
require "Dev/ParadiseDev_LifeStartingOutfit"
ParadiseDev.LifeProfilesServer = ParadiseDev.LifeProfilesServer or {}
local S = ParadiseDev.LifeProfilesServer
local M, N = ParadiseDev.LifeProfiles, ParadiseDev.LifeProfileNative
local D, R = M.Store, ParadiseDev.Reincarnate
local P = ParadiseDev.LifeSpawnPolicy
local O = ParadiseDev.LifeStartingOutfit
S.accounts, S.sessions, S.routes = {}, {}, {}
S.sequence = 0
S.MARKER = "ParadiseLifeProfileCharacterKey"
local function now() return getTimestampMs() end
local function enabled() return R.isShouldReincarnate() end
local function settings() return SandboxVars and SandboxVars.ParadiseZ or {} end
local function slots() return math.floor(math.max(1,math.min(M.MAX_SLOTS,tonumber(settings().LifeProfileCount) or 3))) end
local function interval() return math.max(10,math.min(300,tonumber(settings().LifeProfileSaveSeconds) or 30))*1000 end
local CHECKPOINT_RETRY_MS = 5000
local function dead(pl) return pl and pl:isDead() end
local function text(value) return type(value)=="string" and #value>0 and #value<=256 end
local function uid(prefix)
    S.sequence=S.sequence+1
    return prefix..":"..tostring(now())..":"..tostring(S.sequence)..":"..tostring(ZombRand(1000000000))
end

function S.accountKey(pl)
    if not pl or not pl.getUsername then return nil,"Authenticated player required" end
    local user=pl:getUsername()
    if type(user)~="string" or #user<1 or #user>64 then return nil,"Unsupported account name" end
    local key="user:"..string.lower(user)
    if getSteamModeActive and getSteamModeActive() then
        local steam=pl.getSteamID and tostring(pl:getSteamID()) or "0"
        if steam=="0" or steam=="" then return nil,"Steam account identity is not ready" end
        key=steam..":"..key
    end
    if #key>96 then return nil,"Account identity is too long" end
    return key
end

local function emit(pl,command,args)
    args=args or {}
    args.playerIndex=S.routes[pl] or (pl.getPlayerNum and pl:getPlayerNum()) or 0
    if isServer and isServer() then sendServerCommand(pl,M.module,command,args)
    elseif ParadiseDev.LifeProfilesClient then ParadiseDev.LifeProfilesClient.onServerCommand(M.module,command,args) end
end
local function failure(pl,message,requestId)
    emit(pl,"error",{message=tostring(message),requestId=requestId})
end
local function account(pl)
    local key,err=S.accountKey(pl)
    if not key then return nil,err end
    local entry=S.accounts[key]
    if not entry or entry.unavailable then
        local value,meta=D.load(key)
        if not value then return nil,"Profile storage could not be read: "..tostring(meta) end
        entry=entry or {key=key}
        entry.value,entry.meta,entry.unavailable=value,meta,nil;entry.pveMigrated=nil;S.accounts[key]=entry
    end
    entry.username=tostring(pl:getUsername())
    if S.ensurePvEMigration then
        local ok,why=S.ensurePvEMigration(entry)
        if not ok then return nil,why end
    end
    return entry
end

-- A writer may finish before a close/readback failure. Reload and compare the
-- intended revision/content before reporting failure or attempting another write.
local function persist(entry,value)
    if not value then return nil,"No profile update to save" end
    if value.revision==entry.value.revision then
        if D.encode(value)==D.encode(entry.value) then return true end
        return nil,"Profile content changed without a new revision"
    end
    local ok,err=D.save(entry.key,value,entry.value.revision)
    if ok then entry.value=value;return true end
    local actual,meta=D.load(entry.key)
    if actual then
        entry.value,entry.meta=actual,meta
        if actual.revision==value.revision and D.encode(actual)==D.encode(value) then return true end
    end
    if not actual then entry.unavailable=true end
    return nil,"Profile save failed; "..(actual and "saved state was reloaded: " or "storage is unavailable: ")..tostring(err)
end
S.persist=persist

S.loadAccount=account

local function currentSlot(entry) return entry.value.slots[entry.value.activeSlot] end
local function isFailedBody(pending,key)
    if not pending or pending.status~="prepared" or not text(key) then return false end
    for _,failedKey in ipairs(pending.failedBodies or {}) do
        if failedKey==key then return true end
    end
    return false
end
local function session(pl,entry)
    local state=S.sessions[pl]
    if state then return state end
    local slot=currentSlot(entry)
    local marker=pl:getModData()[S.MARKER]
    local pending=entry.value.pending
    local expected=slot and (slot.phase=="alive" and slot.checkpoint.characterKey or slot.death.characterKey)
        or entry.value.deletedDeath and entry.value.deletedDeath.characterKey
    local key=expected or uid("body")
    if pending and marker==pending.sourceCharacterKey then key=marker end
    if pending and pending.status=="applying" and marker==pending.newCharacterKey then key=marker end
    local failedBody=dead(pl) and isFailedBody(pending,marker)
    if failedBody then key=marker end
    state={key=key,entry=entry,lastSave=now(),lastSeen=now(),bornObserved=now()}
    if entry.birth and entry.birth.key==marker then
        state.nativeNew=true;state.key=marker;state.birth=entry.birth
    end
    S.sessions[pl]=state
    -- A pending transaction's body must be bound explicitly by ready(); a
    -- client-provided mod-data marker is only a consistency hint, never authority.
    if not entry.value.pending and (slot or entry.value.deletedDeath) and marker~=key then
        state.creationError="This character does not match the active profile. Saved progress is retained for review"
    elseif pending and not state.nativeNew then
        local sourceBody=dead(pl) and marker==pending.sourceCharacterKey
        local replacementBody=pending.status=="applying" and marker==pending.newCharacterKey
        if not sourceBody and not replacementBody and not failedBody then
            -- Refuse before claim() can retire the current connected owner.
            state.creationError="This character does not match the pending profile. Saved progress is retained for review"
        end
    end
    return state
end

-- Native creation uses a temporary player object; the subsequent connection
-- loads another object from the server database. Only the connected owner may
-- checkpoint. A retired connection can never overwrite a newer incarnation.
local function claim(pl,entry)
    local st=session(pl,entry)
    -- A rejected object cannot retire the legitimate connected owner.
    if st.creationError then return st end
    if entry.owner~=pl then
        local previous=entry.owner and S.sessions[entry.owner]
        if previous then previous.superseded=true end
        entry.owner=pl
    end
    st.wasOnline=true;st.disconnected=nil;st.superseded=nil
    local slot=currentSlot(entry)
    if not st.ambitionsSeeded and not entry.value.pending and slot and slot.phase=="alive"
            and pl:getModData()[S.MARKER]==slot.checkpoint.characterKey then
        if N.seedAmbitions and slot.checkpoint.modData and slot.checkpoint.modData.Ambitions then
            N.seedAmbitions(pl,{version=1,ambitions=slot.checkpoint.modData.Ambitions})
        end
        st.ambitionsSeeded=true
    end
    return st
end

-- One authorization boundary for every save/death entry point, including
-- OnSave and disconnected-object cleanup. A native object is not authorized
-- merely because its account name matches a durable profile.
function S.authorizeLifecycle(pl,entry)
    local st=session(pl,entry)
    if st.creationError then return nil,st.creationError end
    if not st.wasOnline or st.superseded or entry.owner~=pl then
        return nil,"Only the current connected character can change this profile"
    end
    local a,p=entry.value,entry.value.pending
    local slot=currentSlot(entry)
    local expected=p and (p.status=="applying" and p.newCharacterKey or p.sourceCharacterKey)
        or slot and (slot.phase=="alive" and slot.checkpoint.characterKey or slot.death.characterKey)
        or a.deletedDeath and a.deletedDeath.characterKey
    if p and st.key==p.sourceCharacterKey and dead(pl) then expected=p.sourceCharacterKey end
    if dead(pl) and isFailedBody(p,st.key) then expected=st.key end
    if expected and (st.key~=expected or pl:getModData()[S.MARKER]~=expected) then
        return nil,"This body is not authorized to change the saved profile"
    end
    return true
end

-- Account names locate the private store; profile IDs own combat choices.
-- The old username assignment remains evidence, never an effective override.
S.pveBodies=setmetatable({}, {__mode="k"})
function S.ensurePvEMigration(entry)
    if entry.pveMigrated then return true end
    local syncer=ParadiseDev.TraitSyncer
    local legacy,ambiguous
    if syncer and syncer.getStoredRecord then
        local record,_,conflict=syncer.getStoredRecord(entry.username)
        ambiguous=conflict
        legacy=record and record["ParadiseDev:PvE"]
    end
    if ambiguous then return nil,"Conflicting account spellings require administrator review" end
    local value,changed=M.migratePvE(entry.value,legacy)
    if not value then return nil,changed end
    if changed then
        local ok,why=persist(entry,value)
        if not ok then return nil,why end
    end
    entry.pveMigrated=true
    return true
end

local function nativePvE(pl)
    return ParadiseDev.hasTrait and ParadiseDev.hasTrait(pl,"ParadiseDev:PvE")==true or false
end
function S.getPvEContext(pl,pendingOverride,actualBirth)
    local entry,err=account(pl)
    if not entry then return {ready=false,pve=nativePvE(pl),reason=err} end
    local a=entry.value
    local existing=S.sessions[pl]
    if existing and (existing.superseded or existing.creationError) then
        return {ready=false,pve=nativePvE(pl),reason="This body is no longer the active profile"}
    end
    local pending=pendingOverride
    if not pending and a.pending and a.pending.status=="applying" then
        local st=S.sessions[pl]
        if st and st.key==a.pending.newCharacterKey then pending=a.pending
        elseif not st and pl.getModData and pl:getModData()[S.MARKER]==a.pending.newCharacterKey then
            -- Pre-entry lookup deserializes a temporary server-saved body. It
            -- has no connected session yet, but must use the selected profile.
            local frozen=a.pending.targetSnapshot or a.pending.creationSnapshot
            local desc=pl.getDescriptor and pl:getDescriptor()
            if not frozen or not desc or desc:getForename()~=frozen.identity.forename
                    or desc:getSurname()~=frozen.identity.surname
                    or tostring(desc:getCharacterProfession())~=frozen.identity.profession then
                return {ready=false,pve=nativePvE(pl),reason="Saved replacement identity does not match the pending profile"}
            end
            pending=a.pending
        end
    end
    local slot=pending and pending.kind=="restore" and a.slots[pending.slot] or not pending and currentSlot(entry)
    if actualBirth and not pending then slot=nil end
    local profileId=slot and slot.id or pending and pending.profileId or nil
    local st=S.sessions[pl]
    local bodyKey=st and st.key or pending and pending.newCharacterKey or slot and slot.checkpoint.characterKey or nil
    local pve,ready,reason,scope
    if slot then
        pve=slot.pve;ready=type(pve)=="boolean" and not slot.pveConflict
        if not ready then
            reason="An administrator must resolve this profile's PvE setting"
            pve=nativePvE(pl) -- Do not silently remove a living body's protection.
        end
        scope="profile"
    elseif pending and pending.kind=="create" then
        local frozen=pending.creationSnapshot or a.creationIntent and a.creationIntent.snapshot
        if frozen then
            pve=frozen.pve
            if pve==nil then pve=M.identityPvE(frozen.identity) end
            profileId=pending.profileId or a.creationIntent and a.creationIntent.profileId
        elseif actualBirth then pve=nativePvE(pl)
        else pve=false end -- New creation revalidates its chosen native trait before save.
        ready=true;scope="creation"
    elseif actualBirth then
        pve=nativePvE(pl);ready=true;scope="creation"
    else
        scope="legacy-body";ready=not dead(pl)
        if not ready then reason="This legacy character has died; choose a new profile" end
    end
    local record=S.pveBodies[pl]
    if not record or record.profileId~=profileId or record.scope~=scope or record.bodyKey~=bodyKey then
        record={contextId=uid("pve-body"),profileId=profileId,scope=scope,bodyKey=bodyKey,
            pve=nativePvE(pl),revision=1}
        S.pveBodies[pl]=record
    end
    if scope=="legacy-body" then pve=record.pve end
    return {ready=ready==true,pve=pve==true,reason=reason,profileId=profileId,bodyKey=bodyKey or record.contextId,
        contextId=record.contextId,pveRevision=slot and slot.pveRevision or record.revision,scope=scope,
        accountRevision=a.revision,profileRevision=slot and slot.revision or nil,
        onlineId=pl.getOnlineID and pl:getOnlineID() or nil}
end

-- The loaded native body may predate an offline administrator's profile choice.
-- Correct only this status trait before registration; no XP, inventory, save
-- serialization or connected-player lease is touched by this pre-admission gate.
function S.applyAdmissionPvE(pl)
    local context=S.getPvEContext(pl)
    if not context.ready then return nil,context.reason or "Profile PvE policy is not ready" end
    local ok,applied=pcall(function()
        local trait=ParadiseDev.getTrait and ParadiseDev.getTrait("ParadiseDev:PvE")
        local traits=pl and pl.getCharacterTraits and pl:getCharacterTraits()
        if not trait or not traits or not pl.hasTrait then return false end
        if pl:hasTrait(trait)~=context.pve then
            if context.pve then traits:add(trait) else traits:remove(trait) end
        end
        return pl:hasTrait(trait)==context.pve
    end)
    if not ok or not applied then return nil,"The saved character's PvE policy could not be applied safely" end
    return true,context
end

local function onlineOwner(entry)
    local owner=entry.owner
    local players=getOnlinePlayers and getOnlinePlayers() or nil
    if not owner or not players then return nil end
    for i=0,players:size()-1 do if players:get(i)==owner then return owner end end
end
local function profileAdminContext(entry,slot)
    local owner=onlineOwner(entry)
    if owner and entry.value.activeSlot==slot.slot and not dead(owner) then return S.getPvEContext(owner),owner end
    entry.pveAdminToken=entry.pveAdminToken or uid("pve-account")
    return {scope="profile",profileId=slot.id,bodyKey="offline",contextId=entry.pveAdminToken..":"..slot.id,
        pveRevision=slot.pveRevision,pve=slot.pve==true,ready=not slot.pveConflict,
        reason=slot.pveConflict and "Choose this profile's PvE setting to resolve its legacy assignment" or nil}
end
function S.getAdminPvEProfiles()
    local entries={}
    for _,entry in pairs(S.accounts) do
        if entry.username and not entry.unavailable then
            local ok=S.ensurePvEMigration(entry)
            if ok then
                for _,slot in pairs(entry.value.slots) do
                    local context=profileAdminContext(entry,slot)
                    local identity=slot.creationIdentity or {}
                    entries[#entries+1]={username=entry.username,profileId=slot.id,slot=slot.slot,
                        name=tostring(identity.forename or "").." "..tostring(identity.surname or ""),context=context}
                end
            end
        end
    end
    return entries
end
local function sameContext(a,b)
    return type(a)=="table" and type(b)=="table" and a.contextId==b.contextId and a.bodyKey==b.bodyKey
        and a.profileId==b.profileId and a.pveRevision==b.pveRevision and a.scope==b.scope
end
function S.setTargetPvE(username,expected,enabled)
    if type(username)~="string" or type(expected)~="table" or type(enabled)~="boolean" then return nil,"Invalid profile assignment" end
    local found
    for _,entry in pairs(S.accounts) do
        if string.lower(tostring(entry.username))==string.lower(username) then
            if found then return nil,"Account identity is ambiguous; refresh the current player" end
            found=entry
        end
    end
    if not found then return nil,"This account has not been authenticated during this server session" end
    if found.unavailable then return nil,"Profile storage is unavailable" end
    if expected.profileId then
        local slot
        for _,candidate in pairs(found.value.slots) do if candidate.id==expected.profileId then slot=candidate;break end end
        if not slot then return nil,"The profile no longer exists" end
        local actual,owner=profileAdminContext(found,slot)
        if not sameContext(actual,expected) then return nil,"Player or profile changed; refresh before applying" end
        local value,err=M.setProfilePvE(found.value,slot.id,expected.pveRevision,enabled)
        if not value then return nil,err end
        local ok;ok,err=persist(found,value)
        if not ok then return nil,err end
        return true,owner
    end
    local owner=onlineOwner(found)
    if not owner or dead(owner) then return nil,"The legacy character is no longer online" end
    local actual=S.getPvEContext(owner)
    if actual.scope~="legacy-body" or not sameContext(actual,expected) then return nil,"Character changed; refresh before applying" end
    local record=S.pveBodies[owner]
    record.pve=enabled;record.revision=record.revision+1
    return true,owner
end

local function summary(slot,index)
    if not slot then return {slot=index,phase="empty"} end
    local snapshot=slot.phase=="dead" and slot.death or slot.checkpoint
    local result={slot=index,id=slot.id,phase=slot.phase,revision=slot.revision,
        pve=slot.pve,pveConflict=slot.pveConflict==true,identity=M.copy(snapshot.identity),recipes=M.copy(snapshot.recipes),startingOutfit=O.forProfile(slot.startingOutfit),
        name=snapshot.identity.forename.." "..snapshot.identity.surname,
        hoursSurvived=snapshot.hoursSurvived,zombieKills=snapshot.zombieKills,
        incarnations=slot.incarnations+1,skills=M.copy(snapshot.skills),creationXP=M.copy(slot.creationXP),
        capturedAt=snapshot.capturedAt,snapshotKind=snapshot.provenance or snapshot.kind,loss={},postXP={}}
    local after=slot.phase=="dead" and not slot.pveConflict and M.penalizedSnapshot(slot) or snapshot
    for perk,value in pairs(snapshot.skills) do
        result.postXP[perk]=after.skills[perk];result.loss[perk]=value-after.skills[perk]
    end
    return result
end

S.summarizeSlot=summary

local function acceptance(pl,entry)
    local a,p=entry.value,entry.value.pending
    if not p then return nil end
    local result={transactionId=p.id,requestId=p.id,kind=p.kind,profile=summary(a.slots[p.slot],p.slot),
        revision=a.revision,status=p.status,canCancel=p.status=="prepared" and not a.creationIntent}
    result.creationIntentId=a.creationIntent and a.creationIntent.creationId
    local creationSnapshot=p.creationSnapshot or a.creationIntent and a.creationIntent.snapshot
    if p.kind=="create" and creationSnapshot then
        -- Retry a failed new-profile body using its already-frozen creation
        -- identity. Do not invite a different profession/trait selection.
        local snapshot=creationSnapshot
        result.kind="restore"
        result.profile={slot=p.slot,id=p.profileId or a.creationIntent and a.creationIntent.profileId,phase="dead",identity=M.copy(snapshot.identity),
            skills=M.copy(snapshot.skills),hoursSurvived=snapshot.hoursSurvived,zombieKills=snapshot.zombieKills,
            pve=snapshot.pve,creationRetry=true,
            startingOutfit=O.forProfile(p.creationStartingOutfit or a.creationIntent and a.creationIntent.startingOutfit)}
    end
    local options,err=P.options(pl,p,a)
    result.spawnOptions=options
    result.spawnError=err
    if p.spawnSelection then
        result.spawnId=p.spawnSelection.id
        result.spawn=M.copy(p.spawnSelection.location)
        result.spawnRegion=p.spawnSelection.regionName
    end
    return result
end

S.acceptance=acceptance

function S.chooseSpawn(pl,entry,id,spawnId)
    if not dead(pl) then return nil,"Spawn destinations can only be selected after death" end
    local a,p=entry.value,entry.value.pending
    if not p or p.id~=id or not text(spawnId) then return nil,"No matching spawn selection" end
    local options,err=P.options(pl,p,a)
    if not options then return nil,err end
    -- The list is server-owned. A forced destination cannot be bypassed with
    -- a remembered body/region ID or coordinates supplied by a client.
    local permitted=false
    for _,option in ipairs(options.options or {}) do if option.id==spawnId then permitted=true end end
    if not permitted then return nil,"Spawn destinations changed. Cancel and select your profile again" end
    local resolved;resolved,err=P.resolve(pl,p,a,spawnId)
    if not resolved then return nil,err end
    local nextAccount;nextAccount,err=M.chooseSpawn(a,id,resolved)
    if not nextAccount then return nil,err end
    local ok;ok,err=persist(entry,nextAccount)
    if not ok then return nil,err end
    emit(pl,"spawnAccepted",acceptance(pl,entry))
    return true
end

local function audit(pl,slot,kind)
    if SoulCatcher and SoulCatcher.recordLifeProfile then
        local ok,err=pcall(SoulCatcher.recordLifeProfile,pl,slot,kind)
        if not ok then print("[LifeProfiles] Audit mirror failed: "..tostring(err)) end
    end
end

local function freezeDeath(pl,entry,state,slot)
    if state.deathObservation then return state.deathObservation end
    local snapshot,err
    if slot then snapshot,err=N.capture(pl,"death",state.key,slot.creationXP)
    else snapshot,err=N.captureEnrollmentDeath(pl,state.key) end
    if not snapshot and slot and slot.checkpoint then
        snapshot=M.copy(slot.checkpoint)
        snapshot.kind="death";snapshot.provenance="checkpoint"
        snapshot.deathObservedAt=now();snapshot.fallbackReason=tostring(err)
    end
    if not snapshot then return nil,"Final character state could not be saved: "..tostring(err) end
    -- Freeze the enrolled profile, or the legacy creation-only death receipt.
    -- Only enrolled profiles accept final Lifestyle progress during this short
    -- window; the rest of the death observation is never recaptured.
    state.deathObservation={snapshot=M.copy(snapshot),deadline=now()+1000}
    return state.deathObservation
end

function S.recordDeath(pl,entry,force)
    if not dead(pl) then return nil,"Death has not been confirmed by the server" end
    entry=entry or account(pl)
    if not entry then return nil,"Profile storage unavailable" end
    local state=session(pl,entry)
    local authorized,authorizationError=S.authorizeLifecycle(pl,entry)
    if not authorized then return nil,authorizationError end
    local a=entry.value
    if state.superseded or (entry.owner and entry.owner~=pl) then return nil,"Superseded character cannot change this profile" end
    if a.pending then
        local pending=a.pending
        if pending.status=="applying" and state.key==pending.newCharacterKey then
            local updated,err=M.retryAfterBodyDeath(a,pending.id,state.key)
            if not updated then return nil,err end
            local ok;ok,err=persist(entry,updated)
            if ok then state.deathHandled=true end
            return ok,err
        end
        -- The source corpse remains dead while its selection is in progress.
        if state.key==pending.sourceCharacterKey then return true end
        if isFailedBody(pending,state.key) then return true end
        return nil,"Saved restoration belongs to another character"
    end
    local slot=currentSlot(entry)
    if slot and slot.phase=="dead" then return true end
    if a.enrollmentDeath or a.deletedDeath then return true end
    local observation,err=freezeDeath(pl,entry,state,slot)
    if not observation then return nil,err end
    if not force and now()<observation.deadline then return true end
    local snapshot=M.copy(observation.snapshot)
    local updated
    if slot then updated,err=M.recordDeath(a,a.activeSlot,snapshot)
    else updated,err=M.recordUnenrolledDeath(a,snapshot) end
    if not updated then return nil,err end
    local ok;ok,err=persist(entry,updated)
    if not ok then return nil,err end
    state.deathHandled=true
    if slot then audit(pl,currentSlot(entry),"death") end
    return true
end

function S.list(pl,entry,observationId)
    entry=entry or account(pl)
    if not entry then return end
    if dead(pl) then S.recordDeath(pl,entry) end
    local a=entry.value
    local maxSlots=slots()
    for i in pairs(a.slots) do maxSlots=math.max(maxSlots,i) end
    local result={revision=a.revision,deathToken=M.deathToken(a),activeSlot=a.activeSlot,maxSlots=maxSlots,slots={},
        canSelect=dead(pl) and M.deathToken(a)~=nil and a.pending==nil,
        enrollmentRequired=a.activeSlot==nil and a.deletedDeath==nil,
        enrollmentMessage="One-time transition: your current character finishes this life. Your next new character starts a profile; old progress is not restored."}
    for i=1,maxSlots do result.slots[i]=summary(a.slots[i],i) end
    result.pending=acceptance(pl,entry)
    local st=session(pl,entry)
    if S.authorizeLifecycle(pl,entry) then
        result.characterKey=st.key;result.ambitionSeq=st.ambitionSeq or 0
        if text(observationId) then
            result.observationId=observationId
            local slot=currentSlot(entry)
            if not a.pending and slot and slot.phase=="alive" and slot.checkpoint.modData then
                result.ambitionBootstrap=M.copy(slot.checkpoint.modData.Ambitions)
                result.ambitionCarryWeight=N.carryWeight and N.carryWeight(pl) or nil
            end
        end
    end
    -- Lost completion acknowledgement: resend only the latest transition, never
    -- apply XP again. The client asks ready and verifies native XP replication.
    local last=a.lastCompletion
    local slot=currentSlot(entry)
    if not result.pending and last and not dead(pl) and a.activeSlot==last.slot
            and slot and slot.phase=="alive" and st.key==last.characterKey
            and S.authorizeLifecycle(pl,entry) then
        -- Completion recovery belongs to the living body, never to the next
        -- death's spawn picker (the final-death grace can leave the slot alive).
        if not st.observed then result.pending={transactionId=last.id,requestId=last.id,kind="restore",
            profile=summary(slot,last.slot),revision=a.revision,status="complete",
            completionReplay=true,canCancel=false} end
    end
    emit(pl,"profiles",result)
end

function S.resume(pl,entry,id)
    if not dead(pl) then return nil,"Profiles can only be resumed after death" end
    local authorized,err=S.authorizeLifecycle(pl,entry)
    if not authorized then return nil,err end
    if not text(id) then return nil,"Invalid selection identifier" end
    local pending=entry.value.pending
    if not pending or pending.id~=id then
        -- A cached completion or cancelled reservation must never allocate a
        -- new transition. Return authoritative state so the menu can recover.
        S.list(pl,entry)
        return true
    end
    if pending.status~="prepared" then return nil,"Restoration has already started. Refresh your profile status." end
    emit(pl,"selectionAccepted",acceptance(pl,entry))
    return true
end

function S.deleteProfile(pl,entry,args)
    if not dead(pl) then return nil,"Profiles can only be deleted after death" end
    -- A delete request identifies an existing server record. It can never
    -- supply an account name, filename, replacement snapshot or progress.
    local fields={playerIndex=true,slot=true,profileId=true,profileRevision=true,revision=true,deathToken=true,requestId=true}
    for key in pairs(args) do if not fields[key] then return nil,"Unsupported profile deletion field" end end
    local disk,meta=D.load(entry.key)
    if not disk then entry.unavailable=true;return nil,"Profile storage is unreadable. Deletion is paused" end
    entry.value,entry.meta=disk,meta
    local authorized,err=S.authorizeLifecycle(pl,entry)
    if not authorized then return nil,err end
    local value,receipt=M.deleteProfile(entry.value,args.slot,args.profileId,args.profileRevision,
        args.revision,args.deathToken,args.requestId)
    if not value then return nil,receipt end
    local changed=value.revision~=entry.value.revision
    local ok;ok,err=persist(entry,value)
    if not ok then return nil,err end
    if changed then
        local st=session(pl,entry)
        st.deathObservation=nil
        -- Log identifiers only. Deleted character progress is not copied into
        -- a player-restorable archive or the next profile.
        print("[LifeProfiles] profile_deleted account="..entry.key.." slot="..tostring(receipt.slot)
            .." profile="..receipt.profileId.." revision="..tostring(receipt.revision))
    end
    -- Acknowledged deletion must survive either recovery bank being lost.
    -- Keep this separate from persist(): one readable new generation alone
    -- is not enough to prove that the old playable profile cannot reappear.
    ok,err=D.mirrorCurrent(entry.key,entry.value)
    if not ok then
        emit(pl,"error",{requestId=receipt.id,retryableDeletion=true,
            message="Deletion was saved, but its recovery copy could not be confirmed. Retry deletion: "..tostring(err)})
        return true
    end
    emit(pl,"profileDeleted",{requestId=receipt.id,slot=receipt.slot,profileId=receipt.profileId,revision=receipt.revision})
    S.list(pl,entry)
    return true
end

local function restored(pl,entry,transactionId)
    local slot=currentSlot(entry)
    -- Acknowledgement replay must reflect the current living body; the player
    -- may have progressed since the completed transaction or last checkpoint.
    local actual,err=N.capture(pl,"checkpoint",slot.checkpoint.characterKey,slot.creationXP)
    if not actual then return nil,err end
    local mirror;mirror,err=N.mirror(actual)
    if not mirror then return nil,err end
    mirror.transactionId=transactionId;mirror.slot=slot.slot
    mirror.characterKey=slot.checkpoint.characterKey
    mirror.revision=entry.value.revision
    mirror.expectedSkills=M.copy(actual.skills)
    emit(pl,"restored",mirror)
    return true
end

local function matchingBody(pl,snapshot)
    local desc=pl:getDescriptor()
    return desc and desc:getForename()==snapshot.identity.forename and desc:getSurname()==snapshot.identity.surname
        and tostring(desc:getCharacterProfession())==snapshot.identity.profession
end

function S.prepareNewBody(pl,entry)
    -- Only the native persistence acknowledgement may bind a prepared body.
    -- A client ready/retry command is never evidence that the DB write worked.
    local p=entry.value.pending
    if p and p.status=="applying" then return true end
    return nil,"Waiting for the server to confirm the new character was saved"
end

function S.ready(pl,entry,id)
    -- Re-read before any native mutation. An unreadable or replaced pending
    -- record must not authorize an award from an old in-memory copy.
    local disk,meta=D.load(entry.key)
    if not disk then entry.unavailable=true;return nil,"Saved profile is unreadable; restoration is paused" end
    entry.value,entry.meta=disk,meta
    local a,p=entry.value,entry.value.pending
    if dead(pl) then return nil,"A living replacement character is required" end
    local st=session(pl,entry)
    if st.creationError or st.superseded or not st.wasOnline or entry.owner~=pl then return nil,st.creationError or "Unauthorized restoration body" end
    if not p then
        local authorized,authorizationError=S.authorizeLifecycle(pl,entry)
        if not authorized then return nil,authorizationError end
        local last=a.lastCompletion
        if last and last.id==id and a.activeSlot==last.slot and currentSlot(entry).phase=="alive" then return restored(pl,entry,id) end
        return nil,"No matching profile selection" end
    if p.id~=id then return nil,"Profile selection changed; refresh the death screen" end
    local marker=pl:getModData()[S.MARKER]
    if marker==p.sourceCharacterKey or marker==p.targetCharacterKey then return nil,"The previous character cannot receive this restoration" end
    if p.status=="prepared" then
        local ok,err=S.prepareNewBody(pl,entry)
        if not ok then return nil,err end
        p=entry.value.pending
    end
    if st.key~=p.newCharacterKey then
        local frozen=p.targetSnapshot or p.creationSnapshot
        -- A marker is not enough: the durable, server-owned target identity must
        -- agree too. This path only exists after an already confirmed death.
        if not frozen or not matchingBody(pl,frozen) or marker~=p.newCharacterKey then
            return nil,"Interrupted restoration belongs to another character; saved progress is retained" end
        st.key=p.newCharacterKey;pl:getModData()[S.MARKER]=st.key
    end
    local target=M.copy(p.targetSnapshot or p.creationSnapshot)
    local pveContext=S.getPvEContext(pl,p,true)
    if not pveContext.ready then return nil,pveContext.reason end
    target.pve=pveContext.pve
    local placement=ParadiseDev.SafePlacement
    local destination=placement.evaluate({x=pl:getX(),y=pl:getY(),z=pl:getZ()},P.context(pl,p,true))
    if destination.status~="safe" then
        if destination.status=="pending" then placement.prepare(destination) end
        return nil,"Restoration is saved. Your arrival point needs review: "..tostring(destination.reason)..". Reconnect to choose safe ground."
    end
    -- A connected player may arrive before its native square registration.
    -- Keep the durable restoration pending; the client already retries ready.
    if not pl:isExistInTheWorld() then
        return nil,"Waiting for your character to finish entering the world. Your restoration is saved."
    end
    local ok,err=N.apply(pl,target)
    if not ok then return nil,"Restoration is saved for retry: "..tostring(err) end
    local snapshot;snapshot,err=N.capture(pl,"checkpoint",p.newCharacterKey,p.creationXP)
    if not snapshot then return nil,err end
    local nextAccount;nextAccount,err=M.complete(entry.value,p.id,snapshot,p.creationXP,p.profileId)
    if not nextAccount then return nil,err end
    ok,err=persist(entry,nextAccount)
    if not ok then return nil,err end
    st.key=snapshot.characterKey;st.lastSave=now();st.observed=false
    entry.birth=nil
    audit(pl,currentSlot(entry),"spawn")
    return restored(pl,entry,id)
end

S.CREATION_MARKER="ParadiseLifeProfileCreationId"
S.birthRequests=setmetatable({}, {__mode="k"})

local function birthDecision(status,reason,location)
    return {status=status,reason=reason,location=location}
end
local function nativeBirthContext(ctx)
    if type(ctx)~="table" or ctx.playerIndex~=0 or ctx.nativePlayerIdentityVerified~=true
            or ctx.nativeStatus~="alive" or not text(ctx.nativeCreationId) then
        return nil,"Native creation identity is not verified"
    end
    local pl=ctx.nativePlayer
    if not pl or dead(pl) or pl:getUsername()~=ctx.username then return nil,"Native creation account does not match" end
    return pl
end

-- Repeated placement checks use a supplied durable account and never allocate
-- body/profile IDs, capture progress, dress the player or write the profile bank.
function S.birthPvEContext(pl,pending,a)
    local intent=a and a.creationIntent
    local slot=pending and pending.kind=="restore" and a.slots[pending.slot]
    local frozen=pending and pending.creationSnapshot or intent and intent.snapshot
    local pve,scope
    if slot then
        if type(slot.pve)~="boolean" or slot.pveConflict then
            return {ready=false,reason="An administrator must resolve this profile's PvE setting"}
        end
        pve=slot.pve;scope="profile"
    elseif frozen then
        pve=frozen.pve
        if pve==nil then pve=M.identityPvE(frozen.identity) end
        scope="creation"
    else pve=nativePvE(pl);scope="creation" end
    return {ready=true,pve=pve==true,scope=scope,profileId=slot and slot.id or intent and intent.profileId,
        accountRevision=a and a.revision,profileRevision=slot and slot.revision,pveRevision=slot and slot.pveRevision}
end

function S.creationPolicyToken(a,requestId)
    if type(a)~="table" or type(requestId)~="string" or #requestId>256 then return nil end
    local pending,intent=a.pending,a.creationIntent
    return table.concat({tostring(a.revision),tostring(pending and pending.id or intent and intent.creationId or "first"),
        tostring(P.regionRevision or 0),requestId},":")
end

function S.preBirth(ctx)
    local pl,why=nativeBirthContext(ctx)
    if not pl then return birthDecision("denied",why) end
    if not enabled() then return birthDecision("safe",nil,{x=pl:getX(),y=pl:getY(),z=pl:getZ()}) end
    if S.unsupportedReason then return birthDecision("pending",S.unsupportedReason) end
    local key;key,why=S.accountKey(pl)
    if not key then return birthDecision("denied",why) end
    local entry=S.accounts[key]
    if not entry or entry.unavailable then
        local value,meta=D.load(key)
        if not value then return birthDecision("pending","Profile storage could not be read: "..tostring(meta)) end
        entry=entry or {key=key};entry.value,entry.meta,entry.unavailable=value,meta,nil
        entry.username=pl:getUsername();S.accounts[key]=entry
    end
    local a=entry.value;local pending=a.pending;local intent=a.creationIntent
    local prefix=S.creationPolicyToken(a,"")
    local token=ctx.creationPolicyToken
    if type(token)~="string" or not prefix or token:sub(1,#prefix)~=prefix
            or #token<=#prefix or #token>#prefix+256 then
        return birthDecision("denied","Creation preparation changed. Refresh the saved destination before continuing")
    end
    if (a.activeSlot or a.enrollmentDeath or a.deletedDeath) and not pending then
        return birthDecision("denied","Select a profile before creating a replacement character")
    end
    if pending and pending.status~="prepared" then return birthDecision("denied","The previous creation must finish saving first") end
    if intent and intent.creationId~=ctx.nativeCreationId and not intent.retryAllowed then
        return birthDecision("pending","The original native creation is still being saved")
    end
    local frozen=pending and (pending.targetSnapshot or pending.creationSnapshot) or intent and intent.snapshot
    if frozen and not matchingBody(pl,frozen) then return birthDecision("denied","Creation identity does not match the saved character choice") end
    local request=S.birthRequests[pl]
    if request and request.creationId~=ctx.nativeCreationId then return birthDecision("denied","Native creation request changed") end
    if not request then
        request={creationId=ctx.nativeCreationId,entry=entry};S.birthRequests[pl]=request
    end
    return P.preBirthPlacement(pl,pending,a,S.birthPvEContext(pl,pending,a),ctx.creationLocation)
end

local function firstDefinitionMatches(a,b)
    if a.identity.forename~=b.identity.forename or a.identity.surname~=b.identity.surname
            or a.identity.profession~=b.identity.profession or a.identity.female~=b.identity.female then return false end
    for id,xp in pairs(a.skills) do if not M.xpEqual(xp,b.skills[id]) then return false end end
    for id in pairs(b.skills) do if a.skills[id]==nil then return false end end
    local function traits(identity)
        local out={}
        for _,id in ipairs(identity.traits) do
            local key=string.lower(tostring(id))
            if key~="paradisedev:caged" and key~="paradisedev:therangestaff" and key~="paradisedev:injuredpvp" then out[key]=true end
        end
        return out
    end
    local left,right=traits(a.identity),traits(b.identity)
    for id in pairs(left) do if not right[id] then return false end end
    for id in pairs(right) do if not left[id] then return false end end
    return true
end

local function prepareCreationRecord(pl,entry,st)
    if st.intentStaged then return true end
    local a,pending=entry.value,entry.value.pending
    local previous=a.creationIntent
    if not st.birth then
        if not st.startingOutfit then
            local outfit,why
            if previous then
                local ok;ok,outfit=N.applyStartingOutfit(pl,previous.startingOutfit,st.key)
                if not ok then return nil,outfit end
            elseif pending and (pending.kind=="restore" or pending.creationSnapshot) then
                local saved=pending.kind=="restore" and pending.targetStartingOutfit or pending.creationStartingOutfit
                if pending.kind=="restore" and saved==nil then saved=a.slots[pending.slot] and a.slots[pending.slot].startingOutfit end
                local ok;ok,outfit=N.applyStartingOutfit(pl,saved,st.key)
                if not ok then return nil,outfit end
            else outfit,why=N.captureStartingOutfit(pl);if not outfit then return nil,why end end
            st.startingOutfit=outfit
        end
        local xp,source=N.creationXP(pl);if not xp then return nil,source end
        local snapshot,why=N.capture(pl,"checkpoint",st.key,xp);if not snapshot then return nil,why end
        local policy=S.birthPvEContext(pl,pending,a)
        if not policy.ready then return nil,policy.reason end
        snapshot.pve=policy.pve
        if previous and previous.kind~="restore" and not firstDefinitionMatches(previous.snapshot,snapshot) then
            return nil,"Retry the original saved character definition; its identity and starting skills are retained"
        end
        if previous then xp=M.copy(previous.xp);source=previous.source end
        st.birth={key=st.key,xp=xp,source=source,snapshot=snapshot,
            profileId=previous and previous.profileId or uid("profile"),startingOutfit=st.startingOutfit}
    end
    local birth=st.birth
    local intent={creationId=st.nativeCreationId,bodyKey=st.key,kind=pending and pending.kind or "first",
        pendingId=pending and pending.id,profileId=birth.profileId,xp=M.copy(birth.xp),source=birth.source,
        snapshot=M.copy(birth.snapshot),startingOutfit=M.copy(birth.startingOutfit),createdAt=now()}
    local updated,why=M.stageCreation(entry.value,intent)
    if not updated then return nil,why end
    local ok;ok,why=persist(entry,updated)
    if not ok then return nil,why end
    st.intentStaged=true;st.lastCreationError=nil
    return true
end

-- Native continuation raises this event exactly once after a safe prebirth
-- decision. Persistent intent is not an alive/applying state or DB acknowledgement.
function S.onNewGame(pl)
    if not enabled() or S.unsupportedReason or not pl then return end
    local request=S.birthRequests[pl]
    if not request then return end
    local entry=request.entry
    local st=session(pl,entry)
    if st.eventObserved then return end
    st.eventObserved=true;st.nativeNew=true;st.nativeCreationId=request.creationId
    st.key=uid("birth");st.deathHandled=nil;st.creationError=nil;st.lastCreationError=nil
    pl:getModData()[S.MARKER]=st.key;pl:getModData()[S.CREATION_MARKER]=request.creationId
    local ok,why=prepareCreationRecord(pl,entry,st)
    if not ok then st.lastCreationError=why end
end

function S.createdState(ctx)
    local pl,why=nativeBirthContext(ctx)
    if not pl then return birthDecision("denied",why) end
    if not enabled() then return birthDecision("safe",nil,{x=pl:getX(),y=pl:getY(),z=pl:getZ()}) end
    local st=S.sessions[pl]
    if not st or not st.eventObserved or not st.nativeNew or st.superseded
            or st.nativeCreationId~=ctx.nativeCreationId or pl:getModData()[S.MARKER]~=st.key
            or pl:getModData()[S.CREATION_MARKER]~=ctx.nativeCreationId then
        return birthDecision("denied","Native creation event or body binding is incomplete")
    end
    local entry=st.entry
    if not entry or entry.unavailable then return birthDecision("pending","Profile storage is unavailable; creation is retained") end
    -- Retrying a failed journal write never repeats OnNewGame or an issued outfit.
    local ok;ok,why=prepareCreationRecord(pl,entry,st)
    if not ok then st.lastCreationError=why;return birthDecision("pending",why) end
    local intent=entry.value.creationIntent
    if not intent or intent.creationId~=ctx.nativeCreationId or intent.bodyKey~=st.key then
        return birthDecision("denied","Durable creation binding changed")
    end
    local point={x=pl:getX(),y=pl:getY(),z=pl:getZ()}
    local decision=P.checkBirthPlacement(pl,entry.value.pending,entry.value,S.birthPvEContext(pl,entry.value.pending,entry.value),point)
    if decision.status=="safe" then
        local updated;updated,why=M.moveCreationIntent(entry.value,ctx.nativeCreationId,st.key,point)
        if not updated then return birthDecision("pending",why) end
        local saved;saved,why=persist(entry,updated)
        if not saved then return birthDecision("pending",why) end
    end
    return decision
end

function S.allowCreated(ctx)
    return S.createdState(ctx).status=="safe"
end

local function commitIntent(pl,entry,creationId,bodyKey)
    local updated,why=M.commitCreation(entry.value,creationId,bodyKey)
    if not updated then return nil,why end
    local ok;ok,why=persist(entry,updated)
    if not ok then return nil,why end
    local st=S.sessions[pl]
    if st then st.nativeCreationPersisted=true;st.creationCommitted=true;st.lastCreationError=nil;st.lastSave=now() end
    entry.birth=nil
    return true
end

function S.commitCreated(ctx)
    local pl,why=nativeBirthContext(ctx)
    if not pl then return nil,why end
    if not enabled() then return true end
    if ctx.nativeCreationPersisted~=true then return nil,"Native body persistence has not been verified" end
    local st=S.sessions[pl]
    if not st or not st.eventObserved or st.superseded or st.nativeCreationId~=ctx.nativeCreationId
            or pl:getModData()[S.MARKER]~=st.key or pl:getModData()[S.CREATION_MARKER]~=ctx.nativeCreationId then
        return nil,"Persisted creation does not match its server event"
    end
    -- Persistence is already proven. A subsequent policy change must relocate
    -- this same saved life; it must not prevent its profile commit.
    return commitIntent(pl,st.entry,ctx.nativeCreationId,st.key)
end

function S.enrollBirth(pl,entry,st)
    return nil,"Enrollment requires the native persistence acknowledgement"
end

function S.creationRecovery(entry)
    local intent=entry and entry.value.creationIntent
    if not intent then return nil end
    return {kind="create",transactionId=intent.creationId,creationIntentId=intent.creationId,
        creationSnapshot=M.copy(intent.snapshot),creationStartingOutfit=M.copy(intent.startingOutfit),
        profileId=intent.profileId,retryAllowed=intent.retryAllowed==true}
end

function S.getCreationIntent(entry)
    local intent=entry and entry.value.creationIntent
    if not intent then return nil end
    local snapshot=M.copy(intent.snapshot)
    local profile=M.copy(snapshot)
    profile.startingOutfit=M.copy(intent.startingOutfit)
    return {id=intent.creationId,creationId=intent.creationId,bodyKey=intent.bodyKey,kind=intent.kind,
        snapshot=snapshot,profile=profile,startingOutfit=M.copy(intent.startingOutfit),
        profileId=intent.profileId,retryAllowed=intent.retryAllowed==true}
end

-- Called only with a fresh authenticated native row result. Missing is distinct
-- from a failed lookup, and cannot be inferred from a client retry/disconnect.
function S.reconcileCreation(ctx)
    if not enabled() then return true end
    if type(ctx)~="table" or ctx.playerIndex~=0 or not text(ctx.username) then
        return nil,"Native account identity has not been verified"
    end
    local pl=ctx.nativePlayer
    if pl and (ctx.nativePlayerIdentityVerified~=true or pl:getUsername()~=ctx.username) then
        return nil,"Native account identity does not match"
    end
    local actor=pl or {getUsername=function()return ctx.username end,getSteamID=function()return tonumber(ctx.steamId) or 0 end}
    local entry,why=account(actor);if not entry then return nil,why end
    local disk,meta=D.load(entry.key);if not disk then return nil,"Saved profile is unreadable" end
    entry.value,entry.meta=disk,meta
    local a=entry.value;local intent=a.creationIntent;local pending=a.pending
    -- Ordinary connected death/creation has no unfinished write to reconcile.
    -- Its native connected-body shortcut is deliberately not DB row evidence.
    if not intent and not (pending and pending.status=="applying") then return true end
    if ctx.nativeRowVerified~=true then return nil,"Native character storage has not been verified" end
    if ctx.nativeStatus=="alive" and pl then
        if intent then
            if pl:getModData()[S.MARKER]~=intent.bodyKey or pl:getModData()[S.CREATION_MARKER]~=intent.creationId
                    or not matchingBody(pl,intent.snapshot) then return nil,"Saved native body does not match the unfinished creation" end
            return commitIntent(pl,entry,intent.creationId,intent.bodyKey)
        end
        return true
    end
    local absent=ctx.nativeStatus=="missing"
    local sourceDead=ctx.nativeStatus=="dead" and pl and dead(pl) and pending
        and pl:getModData()[S.MARKER]==pending.sourceCharacterKey
    if not absent and not sourceDead then return true end
    if ctx.nativeCreationInFlight then return true end
    if intent then
        local updated;updated,why=M.markCreationRetry(a,intent.creationId)
        if not updated then return nil,why end
        return persist(entry,updated)
    end
    if pending and pending.status=="applying" then
        local updated;updated,why=M.retryUnsavedCreation(a,pending.id,pending.newCharacterKey)
        if not updated then return nil,why end
        return persist(entry,updated)
    end
    -- An old alive profile with a missing body is not proof of an r5 first-birth
    -- orphan. Retain it for evidence-bound recovery; never manufacture a death.
    return true
end

function S.checkpoint(pl,entry)
    local a,slot=entry.value,currentSlot(entry)
    if a.pending or not slot or slot.phase~="alive" or dead(pl) then return true end
    local st=session(pl,entry)
    local authorized,authorizationError=S.authorizeLifecycle(pl,entry)
    if not authorized then return nil,authorizationError end
    local snapshot,err=N.capture(pl,"checkpoint",st.key,slot.creationXP)
    if not snapshot then return nil,err end
    local updated;updated,err=M.checkpoint(a,a.activeSlot,snapshot)
    if not updated then return nil,err end
    local ok;ok,err=persist(entry,updated)
    if ok then st.lastSave=now();st.checkpointRetryAt=nil end
    return ok,err
end

-- Lifestyle owns these counters on the local character. Accept only its typed
-- allowlist, bound to this authenticated body; XP and identity remain native.
-- Acknowledgement means the resulting full checkpoint/death is durable.
function S.receiveAmbitions(pl,entry,args,atDeath)
    local ok,err=S.authorizeLifecycle(pl,entry)
    if not ok then return nil,err end
    local st=session(pl,entry)
    local a,slot=entry.value,currentSlot(entry)
    if a.pending or not slot or slot.phase~="alive" or (dead(pl) and not atDeath)
            or (atDeath and not dead(pl)) then return nil,"Ambition progress requires this unsealed current life" end
    if type(args)~="table" or args.characterKey~=st.key or type(args.seq)~="number"
            or args.seq~=math.floor(args.seq) or args.seq<1 or args.seq>2147483647 then
        return nil,"Invalid ambition life or sequence"
    end
    local A=ParadiseDev.LifeAmbitions
    if not A or not N.acceptAmbitions then return nil,"Ambition compatibility is unavailable" end
    local accepted;accepted,err=A.validate(args.payload)
    if not accepted then return nil,err end
    local encoded=D.encode(accepted)
    if args.seq<=(st.ambitionSeq or 0) then
        if args.seq==st.ambitionSeq and encoded==st.ambitionEncoded then
            emit(pl,"ambitionsSaved",{characterKey=st.key,seq=args.seq,revision=entry.value.revision,
                carryWeight=N.carryWeight and N.carryWeight(pl) or nil});return true
        end
        return nil,"Ambition update belongs to an older observation"
    end
    if not atDeath and now()-(st.lastAmbitionSaved or -10000)<5000 then return true end
    local observation
    if atDeath then
        observation,err=freezeDeath(pl,entry,st,slot)
        if not observation then return nil,err end
        if now()>observation.deadline or observation.final then
            S.recordDeath(pl,entry,true)
            return nil,"Final ambition observation arrived after the death window"
        end
    end
    local canonical
    ok,err,canonical=N.acceptAmbitions(pl,accepted)
    if not ok then return nil,err end
    if atDeath then
        observation.snapshot.modData=observation.snapshot.modData or {}
        observation.snapshot.modData.Ambitions=M.copy((canonical or accepted).ambitions)
        observation.final=true
    end
    if atDeath then ok,err=S.recordDeath(pl,entry,true) else ok,err=S.checkpoint(pl,entry) end
    if not ok then return nil,err end
    st.ambitionSeq,st.ambitionEncoded,st.lastAmbitionSaved=args.seq,encoded,now()
    emit(pl,"ambitionsSaved",{characterKey=st.key,seq=args.seq,revision=entry.value.revision,
        carryWeight=N.carryWeight and N.carryWeight(pl) or nil})
    return true
end

function S.onClientCommand(module,command,pl,args)
    if module~=M.module or not enabled() or not pl or type(args)~="table" then return end
    if command~="list" and command~="select" and command~="resume" and command~="chooseSpawn" and command~="ready" and command~="cancel" and command~="death" and command~="observed" and command~="ambitions" and command~="deleteProfile" then return end
    if S.unsupportedReason then failure(pl,S.unsupportedReason,args.requestId);return end
    local index=args.playerIndex
    if type(index)=="number" and index==math.floor(index) and index>=0 and index<=3 then S.routes[pl]=index end
    local entry,err=account(pl)
    if not entry then failure(pl,err,args.requestId);return end
    local st=claim(pl,entry)
    st.rates=st.rates or {}
    if now()-(st.rates[command] or 0)<250 then return end
    st.rates[command]=now()
    if st.creationError then failure(pl,st.creationError,args.requestId);return end
    local ok=true
    if command=="list" then S.list(pl,entry,args.observationId);return
    elseif command=="death" then
        -- Native death replication and the final Lua observation can arrive in
        -- either order. The client retries this same observation briefly.
        if not dead(pl) then return end
        if type(args.ambitions)=="table" then S.receiveAmbitions(pl,entry,args.ambitions,true) end
        ok,err=S.recordDeath(pl,entry);if ok then S.list(pl,entry) end
    elseif command=="ambitions" then ok,err=S.receiveAmbitions(pl,entry,args,false)
    elseif command=="select" then
        if not dead(pl) then ok,err=nil,"Profiles can only be selected after death"
        elseif not text(args.requestId) then ok,err=nil,"Invalid selection identifier"
        elseif not entry.value.pending and args.revision~=entry.value.revision then ok,err=nil,"Your profiles changed. Refresh before selecting"
        else
            local value;value,err=M.select(entry.value,args.slot,args.deathToken,args.requestId,slots())
            if value then ok,err=persist(entry,value) else ok=nil end
            if ok then emit(pl,"selectionAccepted",acceptance(pl,entry)) end
        end
    elseif command=="resume" then
        ok,err=S.resume(pl,entry,args.transactionId)
    elseif command=="deleteProfile" then
        ok,err=S.deleteProfile(pl,entry,args)
    elseif command=="chooseSpawn" then
        ok,err=S.chooseSpawn(pl,entry,args.transactionId,args.spawnId)
    elseif command=="ready" then
        if not text(args.transactionId) then ok,err=nil,"Invalid selection identifier" else ok,err=S.ready(pl,entry,args.transactionId) end
    elseif command=="cancel" then
        if not dead(pl) then ok,err=nil,"A created character cannot cancel restoration"
        else
            local value;value,err=M.cancel(entry.value,args.transactionId)
            if value then ok,err=persist(entry,value) else ok=nil end
            if ok then S.list(pl,entry) end
        end
    elseif command=="observed" then
        local last=entry.value.lastCompletion
        if last and last.id==args.transactionId then st.observed=true end
    end
    if not ok then
        failure(pl,err,args.requestId or args.transactionId)
        if command=="deleteProfile" then S.list(pl,entry) end
    end
end

local function pollPlayer(pl,seen)
    local previous=S.sessions[pl]
    if previous then previous.lastSeen=now();seen[pl]=true end
    if previous and not dead(pl) and previous.checkpointRetryAt and now()<previous.checkpointRetryAt then
        -- Keep liveness current, but do not repeatedly reload failed banks or
        -- recapture the whole profile while a routine save is cooling down.
        -- Death and explicit/final save paths bypass this polling-only delay.
        return
    end
    local entry,err=account(pl)
    if not entry then
        if previous and not dead(pl) and previous.checkpointRetryAt then
            previous.checkpointRetryAt=now()+CHECKPOINT_RETRY_MS
        end
        return
    end
    local st=claim(pl,entry)
    st.lastSeen=now();seen[pl]=true
    -- Native creation is committed before a connected owner is registered.
    -- Polling cannot infer native persistence from the presence of a player.
    if st.creationError then
        if now()-(st.lastError or 0)>30000 then st.lastError=now();failure(pl,st.creationError) end
        return
    end
    local ok=true
    if dead(pl) and not st.deathHandled then
        ok,err=S.recordDeath(pl,entry)
        if ok and st.deathHandled then S.list(pl,entry) end
    elseif now()-st.lastSave>=interval() then
        ok,err=S.checkpoint(pl,entry)
        if not ok then st.checkpointRetryAt=now()+CHECKPOINT_RETRY_MS end
    end
    if not ok and now()-(st.lastError or 0)>30000 then
        st.lastError=now();print("[LifeProfiles] "..tostring(err));failure(pl,err)
    end
end

function S.onTick()
    if not enabled() or S.unsupportedReason or now()-(S.lastPoll or 0)<250 then return end
    S.lastPoll=now()
    local seen={}
    local players=getOnlinePlayers and getOnlinePlayers()
    if players then for i=0,players:size()-1 do pollPlayer(players:get(i),seen) end
    elseif getNumActivePlayers then for i=0,getNumActivePlayers()-1 do local pl=getSpecificPlayer(i);if pl then pollPlayer(pl,seen) end end end
    for pl,st in pairs(S.sessions) do
        if not seen[pl] and st.wasOnline and not st.superseded and st.entry.owner==pl then
            -- Retain the native object briefly: death can remove it from the online
            -- list before the next poll. Never replace a sealed death with a checkpoint.
            if dead(pl) and not st.deathHandled then S.recordDeath(pl,st.entry,true)
            elseif not st.disconnected then S.checkpoint(pl,st.entry) end
            st.disconnected=true
        end
        if not seen[pl] and now()-st.lastSeen>120000 then S.sessions[pl]=nil;S.routes[pl]=nil end
    end
end

function S.onSave()
    if not enabled() or S.unsupportedReason then return end
    for pl,st in pairs(S.sessions) do
        if st.wasOnline and not st.superseded and st.entry.owner==pl then
            if dead(pl) then S.recordDeath(pl,st.entry,true) elseif not st.disconnected then S.checkpoint(pl,st.entry) end
        end
    end
end
function S.onInit()
    if not enabled() then return end
    if isServer and isServer() then
        local ok,status=pcall(function()return ParadiseLifeBridge and ParadiseLifeBridge("status")end)
        if not ok or type(status)~="table" or status.ready~=true
            or status.livingAdmission~=5 or status.safePlacement~=1 or status.creationLifecycle~=1 then
            S.unsupportedReason="Life profiles need the paired creation-lifecycle bridge. Ask the server owner to complete the Test update"
        end
    end
    if isServer and isServer() and getServerOptions then
        local options=getServerOptions()
        if options and tostring(options:getOption("AllowCoop"))=="true" then
            S.unsupportedReason="Life profiles need AllowCoop=false in this version. Ask the server owner to review the configuration"
        end
    end
    if S.unsupportedReason then print("[LifeProfiles v1] NOT ACTIVE: "..S.unsupportedReason)
    else print("[LifeProfiles v1] ACTIVE: slots="..slots().." checkpoint_seconds="..(interval()/1000)) end
end
Events.OnClientCommand.Add(S.onClientCommand)
Events.OnTick.Add(S.onTick)
Events.OnSave.Add(S.onSave)
Events.OnNewGame.Add(S.onNewGame)
if Events.OnInitGlobalModData then Events.OnInitGlobalModData.Add(S.onInit) end
require "Dev/ParadiseDev_LifeLoginServer"
return S
