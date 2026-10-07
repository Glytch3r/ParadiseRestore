-- Private, server-owned lifecycle. Never accept XP, identity or another user's
-- name from a client. The durable model is the authority for every transition.
if isClient and isClient() then return end
require "Dev/ParadiseDev_Reincarnate"
require "Dev/ParadiseDev_LifeProfiles"
require "Dev/ParadiseDev_LifeProfileStore"
require "Dev/ParadiseDev_LifeProfileNative"
ParadiseDev.LifeProfilesServer = ParadiseDev.LifeProfilesServer or {}
local S = ParadiseDev.LifeProfilesServer
local M, N = ParadiseDev.LifeProfiles, ParadiseDev.LifeProfileNative
local D, R = M.Store, ParadiseDev.Reincarnate
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

local function currentSlot(entry) return entry.value.slots[entry.value.activeSlot] end
local function session(pl,entry)
    local state=S.sessions[pl]
    if state then return state end
    local slot=currentSlot(entry)
    local marker=pl:getModData()[S.MARKER]
    local pending=entry.value.pending
    local key=slot and slot.phase=="alive" and slot.checkpoint.characterKey or uid("body")
    if pending and pending.status=="applying" and marker==pending.newCharacterKey then key=marker end
    state={key=key,entry=entry,lastSave=now(),lastSeen=now(),bornObserved=now()}
    if entry.birth and entry.birth.key==marker then
        state.nativeNew=true;state.key=marker;state.birth=entry.birth
    end
    S.sessions[pl]=state
    -- A pending transaction's body must be bound explicitly by ready(); a
    -- client-provided mod-data marker is only a consistency hint, never authority.
    if not entry.value.pending and slot and slot.phase=="alive" and marker~=key then
        state.creationError="This character does not match the active profile. Saved progress is retained for review"
    end
    return state
end

-- Native creation uses a temporary player object; the subsequent connection
-- loads another object from the server database. Only the connected owner may
-- checkpoint. A retired connection can never overwrite a newer incarnation.
local function claim(pl,entry)
    local st=session(pl,entry)
    if entry.owner~=pl then
        local previous=entry.owner and S.sessions[entry.owner]
        if previous then previous.superseded=true end
        entry.owner=pl
    end
    st.wasOnline=true;st.disconnected=nil;st.superseded=nil
    return st
end

local function summary(slot,index)
    if not slot then return {slot=index,phase="empty"} end
    local snapshot=slot.phase=="dead" and slot.death or slot.checkpoint
    local result={slot=index,id=slot.id,phase=slot.phase,revision=slot.revision,
        identity=M.copy(snapshot.identity),recipes=M.copy(snapshot.recipes),
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

local function acceptance(pl,entry)
    local a,p=entry.value,entry.value.pending
    if not p then return nil end
    local result={transactionId=p.id,requestId=p.id,kind=p.kind,profile=summary(a.slots[p.slot],p.slot)}
    if p.kind=="create" and p.creationSnapshot then
        -- Retry a failed new-profile body using its already-frozen creation
        -- identity. Do not invite a different profession/trait selection.
        local snapshot=p.creationSnapshot
        result.kind="restore"
        result.profile={slot=p.slot,id=p.profileId,phase="dead",identity=M.copy(snapshot.identity),
            skills=M.copy(snapshot.skills),hoursSurvived=snapshot.hoursSurvived,zombieKills=snapshot.zombieKills}
    end
    -- Restore a profile's own last-death location only if enabled. Cage authority
    -- remains first in the client resolver, and the server boundary guard persists.
    if p.kind=="restore" and settings().isSpawnAtDeathLoc==true then result.spawn=M.copy(p.targetSnapshot.location) end
    return result
end

local function audit(pl,slot,kind)
    if SoulCatcher and SoulCatcher.recordLifeProfile then
        local ok,err=pcall(SoulCatcher.recordLifeProfile,pl,slot,kind)
        if not ok then print("[LifeProfiles] Audit mirror failed: "..tostring(err)) end
    end
end

function S.recordDeath(pl,entry)
    if not dead(pl) then return nil,"Death has not been confirmed by the server" end
    entry=entry or account(pl)
    if not entry then return nil,"Profile storage unavailable" end
    local state=session(pl,entry)
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
        return nil,"Saved restoration belongs to another character"
    end
    local slot=currentSlot(entry)
    if slot and slot.phase=="dead" then return true end
    if a.enrollmentDeath then return true end
    local snapshot,err=N.capture(pl,"death",state.key,slot and slot.creationXP)
    if not snapshot and slot and slot.checkpoint then
        snapshot=M.copy(slot.checkpoint)
        snapshot.kind="death";snapshot.provenance="checkpoint"
        snapshot.deathObservedAt=now();snapshot.fallbackReason=tostring(err)
    end
    if not snapshot then return nil,"Final character state could not be saved: "..tostring(err) end
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

function S.list(pl,entry)
    entry=entry or account(pl)
    if not entry then return end
    if dead(pl) then S.recordDeath(pl,entry) end
    local a=entry.value
    local maxSlots=slots()
    for i in pairs(a.slots) do maxSlots=math.max(maxSlots,i) end
    local result={revision=a.revision,deathToken=M.deathToken(a),activeSlot=a.activeSlot,maxSlots=maxSlots,slots={},
        canSelect=dead(pl) and M.deathToken(a)~=nil and a.pending==nil,
        enrollmentRequired=a.activeSlot==nil,
        enrollmentMessage="One-time transition: your current character finishes this life. Your next new character starts a profile; old progress is not restored."}
    for i=1,maxSlots do result.slots[i]=summary(a.slots[i],i) end
    result.pending=acceptance(pl,entry)
    -- Lost completion acknowledgement: resend only the latest transition, never
    -- apply XP again. The client asks ready and verifies native XP replication.
    local last=a.lastCompletion
    if not result.pending and last and a.activeSlot==last.slot and currentSlot(entry).phase=="alive" then
        local st=session(pl,entry)
        if not st.observed then result.pending={transactionId=last.id,requestId=last.id,kind="restore",profile=summary(currentSlot(entry),last.slot)} end
    end
    emit(pl,"profiles",result)
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
    if not p then
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

function S.birthSpawn(pl,pending)
    local cage=ParadiseDev.Cage
    if cage and cage.isCaged and cage.isCaged(pl) then
        local engine=ParadiseDev.Zones and ParadiseDev.Zones.Engine
        if engine then
            local steam=engine.playerSteamId(pl)
            local id=steam and engine.cageAssignments[steam]
            local zone=id and engine.zones[id] or engine.nearestCageZone(pl)
            local region=zone and engine.nearestRegion(zone,pl:getX(),pl:getY())
            if region then
                local x,y=engine.regionCenter(region)
                return {x=x,y=y,z=zone.zMode=="floor" and zone.zMin or pl:getZ()}
            end
        end
        local point={}
        for value in string.gmatch(tostring(settings().DefaultCageCoords or ""),"[^;,]+") do point[#point+1]=tonumber(value) end
        if #point==3 then return {x=point[1],y=point[2],z=point[3]} end
        return nil,"No valid authoritative cage spawn is available"
    end
    if pending and settings().isSpawnAtDeathLoc==true then
        local saved=pending.targetSnapshot or pending.creationSnapshot
        if saved then return M.copy(saved.location) end
    end
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
    st.nativeNew=true;st.key=uid("birth");st.deathHandled=nil;st.creationError=nil
    pl:getModData()[S.MARKER]=st.key
    local a=entry.value
    -- The B42 server chooses initial spawn independently of client LuaPos.
    -- Set the authoritative temporary body's coordinates before its database
    -- save and creation response; no client-selected teleport is accepted.
    local spawn,spawnError=S.birthSpawn(pl,a.pending)
    if spawnError then st.creationError=spawnError;return end
    if spawn then pl:setX(spawn.x);pl:setY(spawn.y);pl:setZ(spawn.z) end
    -- Freeze creation while the authoritative native event is executing, before
    -- a disk write can fail or the temporary native creation object is replaced.
    local xp,source=N.creationXP(pl)
    if not xp then st.creationError=source;return end
    local first;first,err=N.capture(pl,"checkpoint",st.key,xp)
    if not first then st.creationError=err;return end
    st.birth={key=st.key,xp=xp,source=source,snapshot=first,profileId=uid("profile")}
    entry.birth=st.birth
    if a.pending then
        local ok;ok,err=S.prepareNewBody(pl,entry)
        if not ok then st.lastCreationError=err end
        return
    end
    if a.activeSlot or a.enrollmentDeath then
        st.creationError="Select a profile from the death screen before creating a replacement character"
        return
    end
    S.enrollBirth(pl,entry,st)
end

function S.enrollBirth(pl,entry,st)
    local birth=st.birth
    if not birth then return nil,"Original native creation snapshot is unavailable" end
    local updated,err=M.ensureSlot(entry.value,1,birth.profileId,birth.xp,birth.snapshot)
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
    if not st.wasOnline or st.superseded or st.creationError or entry.owner~=pl then return nil,"Only the current connected character can save this profile" end
    local snapshot,err=N.capture(pl,"checkpoint",st.key,slot.creationXP)
    if not snapshot then return nil,err end
    local updated;updated,err=M.checkpoint(a,a.activeSlot,snapshot)
    if not updated then return nil,err end
    local ok;ok,err=persist(entry,updated)
    if ok then st.lastSave=now() end
    return ok,err
end

function S.onClientCommand(module,command,pl,args)
    if module~=M.module or not enabled() or not pl or type(args)~="table" then return end
    if command~="list" and command~="select" and command~="ready" and command~="cancel" and command~="death" and command~="observed" then return end
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
    if command=="list" then S.list(pl,entry);return
    elseif command=="death" then ok,err=S.recordDeath(pl,entry);if ok then S.list(pl,entry) end
    elseif command=="select" then
        if not dead(pl) then ok,err=nil,"Profiles can only be selected after death"
        elseif not text(args.requestId) then ok,err=nil,"Invalid selection identifier"
        elseif not entry.value.pending and args.revision~=entry.value.revision then ok,err=nil,"Your profiles changed. Refresh before selecting"
        else
            local value;value,err=M.select(entry.value,args.slot,args.deathToken,args.requestId,slots())
            if value then ok,err=persist(entry,value) else ok=nil end
            if ok then emit(pl,"selectionAccepted",acceptance(pl,entry)) end
        end
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
    if not ok then failure(pl,err,args.requestId) end
end

local function pollPlayer(pl,seen)
    local entry,err=account(pl)
    if not entry then return end
    local st=claim(pl,entry)
    st.lastSeen=now();seen[pl]=true
    if st.nativeNew and st.birth and not entry.value.activeSlot and not entry.value.enrollmentDeath and not entry.value.pending then
        local ok;ok,err=S.enrollBirth(pl,entry,st)
        if not ok then return end
    end
    if st.creationError then
        if now()-(st.lastError or 0)>30000 then st.lastError=now();failure(pl,st.creationError) end
        return
    end
    local ok=true
    if dead(pl) and not st.deathHandled then ok,err=S.recordDeath(pl,entry)
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
            if dead(pl) and not st.deathHandled then S.recordDeath(pl,st.entry)
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
            if dead(pl) then S.recordDeath(pl,st.entry) elseif not st.disconnected then S.checkpoint(pl,st.entry) end
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
return S
