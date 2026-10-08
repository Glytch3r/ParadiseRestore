-- Pre-entry requests arrive only through the native connection-bound bridge.
-- Never register this module on the player-supplied OnClientCommand event.
if isClient and isClient() then return end
require "Dev/ParadiseDev_LifeProfiles"
require "Dev/ParadiseDev_LifeProfileStore"
require "Dev/ParadiseDev_LifeProfileNative"
require "Dev/ParadiseDev_LifeSpawnPolicy"
ParadiseDev.LifeProfilesServer=ParadiseDev.LifeProfilesServer or {}
local S=ParadiseDev.LifeProfilesServer
local M=ParadiseDev.LifeProfiles
local P=ParadiseDev.LifeSpawnPolicy
local N=ParadiseDev.LifeProfileNative
local function text(v)return type(v)=="string" and #v>0 and #v<=256 end
local function limit()
    local v=SandboxVars and SandboxVars.ParadiseZ
    return math.floor(math.max(1,math.min(M.MAX_SLOTS,tonumber(v and v.LifeProfileCount) or 3)))
end
local function response(status,message)return {status=status,message=message} end
local function emptySlots(value)for _ in pairs(value)do return false end;return true end

local function actor(ctx)
    if type(ctx)~="table" or ctx.playerIndex~=0 or not text(ctx.username)
            or type(ctx.steamId)~="string" then return nil,"Authenticated primary-player connection required" end
    if ctx.nativePlayer then
        if ctx.nativePlayer:getUsername()~=ctx.username then return nil,"Native account identity does not match" end
        -- The bridge compares Steam IDs as Java longs before creating this
        -- context. Kahlua converts getSteamID() to a double; comparing its text
        -- with an exact 17-digit string would reject legitimate connections.
        if ctx.nativePlayerIdentityVerified~=true then return nil,"Native account identity was not verified" end
        return ctx.nativePlayer
    end
    -- Identity comes from UdpConnection, never from request arguments. This
    -- policy-only facade cannot be passed to capture, save, death or ready.
    return {getUsername=function()return ctx.username end,getSteamID=function()return tonumber(ctx.steamId) or 0 end,
        getModData=function()return {} end,getPlayerNum=function()return 0 end,
        getCharacterTraits=function()return {contains=function()return false end} end,
        HasTrait=function()return false end,isDead=function()return ctx.nativeStatus=="dead" end}
end

local function ledger(ctx)
    local pl,err=actor(ctx)
    if not pl then return nil,nil,err end
    if not S.loadAccount or S.unsupportedReason then return nil,nil,S.unsupportedReason or "Profile service is starting" end
    local entry;entry,err=S.loadAccount(pl)
    return pl,entry,err
end

local function profiles(pl,entry)
    local a=entry.value
    local max=limit()
    for i in pairs(a.slots)do max=math.max(max,i)end
    local result={revision=a.revision,activeSlot=a.activeSlot,maxSlots=max,slots={},
        canSelect=M.deathToken(a)~=nil and not a.pending,deathToken=M.deathToken(a),
        enrollmentRequired=not a.activeSlot and not a.deletedDeath}
    for i=1,max do result.slots[i]=S.summarizeSlot(a.slots[i],i)end
    result.pending=S.acceptance(pl,entry)
    return result
end

local function reconcileDeath(ctx,entry)
    local pl=ctx.nativePlayer
    if ctx.nativeStatus~="dead" or not pl or not pl:isDead() then return true end
    local a=entry.value
    local slot=a.slots[a.activeSlot]
    local marker=pl:getModData()[S.MARKER]
    local updated,err
    if a.pending then
        if a.pending.status=="applying" and marker==a.pending.newCharacterKey then
            updated,err=M.retryAfterBodyDeath(a,a.pending.id,marker)
        else return true end
    elseif slot and slot.phase=="alive" and marker==slot.checkpoint.characterKey then
        local observed=entry.owner and S.sessions[entry.owner]
        local snapshot
        if observed and observed.key==marker and observed.deathObservation then
            snapshot=M.copy(observed.deathObservation.snapshot)
        else
            if N.seedAmbitions and slot.checkpoint.modData and slot.checkpoint.modData.Ambitions then
                N.seedAmbitions(pl,{version=1,ambitions=slot.checkpoint.modData.Ambitions})
            end
            snapshot,err=N.capture(pl,"death",marker,slot.creationXP)
        end
        if not snapshot then
            snapshot=M.copy(slot.checkpoint);snapshot.kind="death";snapshot.provenance="checkpoint"
            snapshot.deathObservedAt=getTimestampMs();snapshot.fallbackReason=tostring(err)
        end
        updated,err=M.recordDeath(a,a.activeSlot,snapshot)
    elseif a.deletedDeath then
        if marker~=a.deletedDeath.characterKey then return nil,"The saved body does not match the deleted profile's death" end
        return true
    elseif not slot and not a.enrollmentDeath then
        local key="login-death:"..tostring(getTimestampMs())..":"..ctx.username
        local snapshot;snapshot,err=N.capture(pl,"death",key)
        if snapshot then updated,err=M.recordUnenrolledDeath(a,snapshot)end
    else return true end
    if not updated then return nil,err or "The verified death could not be recorded" end
    return S.persist(entry,updated)
end

local function classify(ctx,pl,entry)
    local a=entry.value
    local active=a.slots[a.activeSlot]
    if ctx.nativeStatus=="unknown" or (ctx.nativeStatus~="alive" and ctx.nativeStatus~="dead" and ctx.nativeStatus~="missing") then
        return response("retry","Your saved character has not been verified. Retry shortly; no character will be replaced.")
    end
    if ctx.nativeStatus=="alive" then
        local marker=ctx.nativePlayer and ctx.nativePlayer:getModData()[S.MARKER]
        if a.pending then
            if a.pending.status=="applying" and marker==a.pending.newCharacterKey then
                local r=response("resume","Resuming your interrupted restoration.")
                r.accepted=S.acceptance(pl,entry)
                return r
            end
            return response("recovery","A living character and an unfinished profile selection disagree. Your saved records are preserved.")
        end
        if active then
            if active.phase~="alive" or not marker or marker~=active.checkpoint.characterKey then
                return response("recovery","Your saved character does not match the active profile. No replacement has been created.")
            end
        elseif a.enrollmentDeath or a.deletedDeath then
            return response("recovery","A recorded death conflicts with the saved living character. Your progress is preserved.")
        end
        return response("resume","Resuming your existing character.")
    end
    if active and active.phase=="alive" and not a.pending then
        -- A missing native body is not a death. Do not seal a checkpoint, charge
        -- XP or convert an alive profile merely because login could not load it.
        return response("recovery","The active profile is alive but its saved character is unavailable. Your progress is preserved for recovery.")
    end
    if a.pending and a.pending.status=="applying" then
        return response("recovery","An interrupted restoration has no verified living body. Your saved transition is preserved for recovery.")
    end
    if M.deathToken(a) then
        local r=response("choose","Choose a saved life or an empty profile.")
        r.profiles=profiles(pl,entry)
        return r
    end
    if ctx.nativeStatus=="missing" and not active and not a.enrollmentDeath and not a.deletedDeath and emptySlots(a.slots) and not a.pending then
        return response("new","Create your first character.")
    end
    return response("recovery","The saved character and profile death record disagree. No character has been replaced.")
end

function S.loginCommand(ctx,command,args)
    args=type(args)=="table" and args or {}
    local function finish(r)r.requestId=args.requestId;return r end
    if not text(args.requestId) then return finish(response("retry","Invalid login request")) end
    local pl,entry,err=ledger(ctx)
    if not entry then return finish(response("retry",err or "Profile storage is unavailable")) end
    if command=="query" then
        local ok;ok,err=reconcileDeath(ctx,entry)
        if not ok then return finish(response("retry",err))end
    end
    local current=classify(ctx,pl,entry)
    if command=="query" then return finish(current) end
    if current.status~="choose" then return finish(current) end
    local a=entry.value
    local updated
    if command=="select" then
        if not text(args.selectionId) then return finish(response("choose","Invalid profile selection")) end
        if not a.pending and args.revision~=a.revision then
            current.message="Profiles changed. Review the refreshed list before selecting.";return finish(current)
        end
        updated,err=M.select(a,args.slot,args.deathToken,args.selectionId,limit())
    elseif command=="chooseSpawn" then
        local p=a.pending
        if not p or p.id~=args.transactionId or not text(args.spawnId) then err="No matching spawn selection"
        else
            local options;options,err=P.options(pl,p,a)
            local allowed=false
            for _,option in ipairs(options and options.options or {})do if option.id==args.spawnId then allowed=true end end
            if not allowed then err=err or "Spawn destinations changed. Cancel and choose again."
            else
                local chosen;chosen,err=P.resolve(pl,p,a,args.spawnId)
                if chosen then updated,err=M.chooseSpawn(a,p.id,chosen)end
            end
        end
    elseif command=="cancel" then updated,err=M.cancel(a,args.transactionId)
    else return finish(response("retry","Unsupported login operation")) end
    if updated then
        local ok;ok,err=S.persist(entry,updated)
        if ok then
            current=classify(ctx,pl,entry)
            if command=="select" or command=="chooseSpawn" then
                current.action=command=="select" and "selectionAccepted" or "spawnAccepted"
                current.accepted=S.acceptance(pl,entry)
            end
        end
    end
    if err then current.message=err;current.action=nil end
    return finish(current)
end

-- Called by the native bridge before CreatePlayer performs any world/DB work.
-- Its independent native check rejects unknown/currently-living bodies too.
function S.allowCreate(ctx)
    if ctx.nativeStatus~="missing" and ctx.nativeStatus~="dead" then return false end
    if not ParadiseDev.Reincarnate.isShouldReincarnate() then return true end
    local pl,entry=ledger(ctx)
    if not entry then return false end
    local disk=M.Store.load(entry.key)
    if not disk then entry.unavailable=true;return false end
    entry.value=disk
    local state=classify(ctx,pl,entry)
    if state.status=="new" then return true end
    if state.status~="choose" then return false end
    local p=entry.value.pending
    if not p or p.status~="prepared" or not p.spawnSelection then return false end
    local frozen=p.targetSnapshot or p.creationSnapshot
    if frozen then
        local desc=ctx.creationDescriptor
        local identity=frozen.identity
        if not desc or desc:getForename()~=identity.forename or desc:getSurname()~=identity.surname
                or tostring(desc:getCharacterProfession())~=identity.profession then return false end
    end
    return true
end

return S
