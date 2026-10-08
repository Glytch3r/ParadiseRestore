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
        entry.value,entry.meta,entry.unavailable=value,meta,nil;S.accounts[key]=entry
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

local function summary(slot,index)
    if not slot then return {slot=index,phase="empty"} end
    local snapshot=slot.phase=="dead" and slot.death or slot.checkpoint
    local result={slot=index,id=slot.id,phase=slot.phase,revision=slot.revision,
        identity=M.copy(snapshot.identity),recipes=M.copy(snapshot.recipes),startingOutfit=O.forProfile(slot.startingOutfit),
        name=snapshot.identity.forename.." "..snapshot.identity.surname,
        hoursSurvived=snapshot.hoursSurvived,zombieKills=snapshot.zombieKills,
        incarnations=slot.incarnations+1,skills=M.copy(snapshot.skills),creationXP=M.copy(slot.creationXP),
        capturedAt=snapshot.capturedAt,snapshotKind=snapshot.provenance or snapshot.kind,loss={},postXP={}}
    local after=slot.phase=="dead" and M.penalizedSnapshot(slot) or snapshot
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
        revision=a.revision,status=p.status,canCancel=p.status=="prepared"}
    if p.kind=="create" and p.creationSnapshot then
        -- Retry a failed new-profile body using its already-frozen creation
        -- identity. Do not invite a different profession/trait selection.
        local snapshot=p.creationSnapshot
        result.kind="restore"
        result.profile={slot=p.slot,id=p.profileId,phase="dead",identity=M.copy(snapshot.identity),
            skills=M.copy(snapshot.skills),hoursSurvived=snapshot.hoursSurvived,zombieKills=snapshot.zombieKills,
            startingOutfit=O.forProfile(p.creationStartingOutfit)}
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
    local snapshot,err=N.capture(pl,"death",state.key,slot and slot.creationXP)
    if not snapshot and slot and slot.checkpoint then
        snapshot=M.copy(slot.checkpoint)
        snapshot.kind="death";snapshot.provenance="checkpoint"
        snapshot.deathObservedAt=now();snapshot.fallbackReason=tostring(err)
    end
    if not snapshot then return nil,"Final character state could not be saved: "..tostring(err) end
    -- Freeze native identity/XP/traits/counters at the first observed death.
    -- Only the bounded final Lifestyle payload may replace Ambitions during
    -- this short window; the rest of the snapshot is never recaptured.
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
    local a,p=entry.value,entry.value.pending
    local st=session(pl,entry)
    if st.creationError or st.superseded then return nil,st.creationError or "Superseded character" end
    if not p then return nil,"No matching profile selection" end
    if p.status=="prepared" then
        if not st.nativeNew then return nil,"Waiting for server-confirmed character creation" end
        if st.key==p.sourceCharacterKey or st.deathHandled then return nil,"The previous character cannot receive this restoration" end
        local frozen=p.targetSnapshot or p.creationSnapshot
        if frozen and not matchingBody(pl,frozen) then return nil,"Replacement identity does not match the selected profile" end
        local nextAccount,err=M.markApplying(a,p.id,uid("life"))
        if not nextAccount then return nil,err end
        -- Freeze first-created identity/baseline before any later retry, including
        -- a server crash. Retry must not reconstruct it from subsequently acquired traits.
        if p.kind=="create" and not p.creationSnapshot then
            local birth=st.birth
            if not birth then return nil,"Original server creation snapshot is unavailable; no baseline was inferred" end
            local first=M.copy(birth.snapshot);first.characterKey=nextAccount.pending.newCharacterKey
            nextAccount.pending.creationXP=M.copy(birth.xp);nextAccount.pending.creationSource=birth.source
            nextAccount.pending.creationSnapshot=first;nextAccount.pending.profileId=birth.profileId
            nextAccount.pending.creationStartingOutfit=M.copy(birth.startingOutfit)
        end
        local ok;ok,err=persist(entry,nextAccount)
        if not ok then return nil,err end
        p=entry.value.pending
        st.key=p.newCharacterKey;pl:getModData()[S.MARKER]=st.key
    end
    return true
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
    local target=p.targetSnapshot or p.creationSnapshot
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

function S.birthSpawn(pl,pending,a)
    local options,err=P.options(pl,pending,a)
    if not options then return nil,err end
    local id=options.forced and options.options[1] and options.options[1].id
        or pending and pending.spawnSelection and pending.spawnSelection.id
    -- Native first-time creation has already chosen a configured region. Only
    -- forced policy may replace that destination. Reincarnation needs a choice.
    if not id then
        if pending then return nil,"Choose a spawn destination before creating this character" end
        return nil
    end
    local resolved;resolved,err=P.resolve(pl,pending,a,id,true)
    if not resolved then return nil,err end
    return resolved.location
end

-- B42 CreatePlayerPacket.processServer raises OnNewGame after native creation
-- traits/profession/recipes and authenticated username/Steam ID are initialized.
-- Loading a saved character does not raise it. Never infer this from playtime,
-- current traits, client requests or a client-supplied mod-data flag.
function S.onNewGame(pl)
    if not enabled() or S.unsupportedReason or not pl then return end
    local entry,err=account(pl)
    if not entry then print("[LifeProfiles] Creation enrollment failed: "..tostring(err));return end
    local st=session(pl,entry)
    if (entry.value.activeSlot or entry.value.enrollmentDeath or entry.value.deletedDeath) and not entry.value.pending then
        st.creationError="Select a profile before creating a replacement character"
        return
    end
    st.nativeNew=true;st.key=uid("birth");st.deathHandled=nil;st.creationError=nil
    pl:getModData()[S.MARKER]=st.key
    local a=entry.value
    -- The B42 server chooses initial spawn independently of client LuaPos.
    -- Set the authoritative temporary body's coordinates before its database
    -- save and creation response; no client-selected teleport is accepted.
    local spawn,spawnError=S.birthSpawn(pl,a.pending,a)
    if spawnError then st.creationError=spawnError;return end
    if spawn then pl:setX(spawn.x);pl:setY(spawn.y);pl:setZ(spawn.z) end
    -- Clothing is issued only on a genuinely new native body, before its
    -- database save/creation response. Network ready/retry never adds items.
    local pending=a.pending
    local startingOutfit
    if pending and (pending.kind=="restore" or pending.creationSnapshot) then
        local saved=pending.kind=="restore" and pending.targetStartingOutfit or pending.creationStartingOutfit
        if pending.kind=="restore" and saved==nil then
            saved=a.slots[pending.slot] and a.slots[pending.slot].startingOutfit
        end
        local dressed;dressed,startingOutfit=N.applyStartingOutfit(pl,saved,st.key)
        if not dressed then st.creationError=startingOutfit;return end
    else
        startingOutfit,err=N.captureStartingOutfit(pl)
        if not startingOutfit then st.creationError=err;return end
    end
    -- Freeze creation while the authoritative native event is executing, before
    -- a disk write can fail or the temporary native creation object is replaced.
    local xp,source=N.creationXP(pl)
    if not xp then st.creationError=source;return end
    local first;first,err=N.capture(pl,"checkpoint",st.key,xp)
    if not first then st.creationError=err;return end
    st.birth={key=st.key,xp=xp,source=source,snapshot=first,profileId=uid("profile"),startingOutfit=startingOutfit}
    entry.birth=st.birth
    if a.pending then
        local ok;ok,err=S.prepareNewBody(pl,entry)
        if not ok then st.lastCreationError=err end
        return
    end
    if a.activeSlot or a.enrollmentDeath or a.deletedDeath then
        st.creationError="Select a profile from the death screen before creating a replacement character"
        return
    end
    S.enrollBirth(pl,entry,st)
end

function S.enrollBirth(pl,entry,st)
    local birth=st.birth
    if not birth then return nil,"Original native creation snapshot is unavailable" end
    local updated,err=M.ensureSlot(entry.value,1,birth.profileId,birth.xp,birth.snapshot,birth.startingOutfit)
    if not updated then st.creationError=err;return end
    updated.slots[1].creationSource=birth.source
    local ok;ok,err=persist(entry,updated)
    if not ok then st.lastCreationError=err;return nil,err end
    pl:getModData()[S.MARKER]=st.key
    st.lastSave=now();st.observed=true
    entry.birth=nil
    audit(pl,currentSlot(entry),"spawn")
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
    if ok then st.lastSave=now() end
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
            emit(pl,"ambitionsSaved",{characterKey=st.key,seq=args.seq});return true
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
        observation.snapshot.modData=observation.snapshot.modData or {}
        observation.snapshot.modData.Ambitions=M.copy(accepted.ambitions)
        observation.final=true
    end
    ok,err=N.acceptAmbitions(pl,accepted)
    if not ok then return nil,err end
    if atDeath then ok,err=S.recordDeath(pl,entry,true) else ok,err=S.checkpoint(pl,entry) end
    if not ok then return nil,err end
    st.ambitionSeq,st.ambitionEncoded,st.lastAmbitionSaved=args.seq,encoded,now()
    emit(pl,"ambitionsSaved",{characterKey=st.key,seq=args.seq})
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
    local entry,err=account(pl)
    if not entry then return end
    local st=claim(pl,entry)
    st.lastSeen=now();seen[pl]=true
    if st.nativeNew and st.birth and not entry.value.activeSlot and not entry.value.enrollmentDeath and not entry.value.deletedDeath and not entry.value.pending then
        local ok;ok,err=S.enrollBirth(pl,entry,st)
        if not ok then return end
    end
    if st.creationError then
        if now()-(st.lastError or 0)>30000 then st.lastError=now();failure(pl,st.creationError) end
        return
    end
    local ok=true
    if dead(pl) and not st.deathHandled then
        ok,err=S.recordDeath(pl,entry)
        if ok and st.deathHandled then S.list(pl,entry) end
    elseif now()-st.lastSave>=interval() then ok,err=S.checkpoint(pl,entry) end
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
