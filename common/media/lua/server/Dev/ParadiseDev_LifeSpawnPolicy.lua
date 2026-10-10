-- Server-owned destination choices. No client coordinates are accepted here.
if isClient and isClient() then return end
require "Dev/ParadiseDev_Reincarnate"
require "Dev/Zones/ParadiseDev_SafePlacement"

ParadiseDev = ParadiseDev or {}
ParadiseDev.LifeSpawnPolicy = ParadiseDev.LifeSpawnPolicy or {}
local P = ParadiseDev.LifeSpawnPolicy
local R = ParadiseDev.Reincarnate

local function finite(value)
    return type(value)=="number" and value==value and value>-math.huge and value<math.huge
end
local function location(x,y,z)
    if not finite(x) or not finite(y) or not finite(z) then return nil end
    return {x=x,y=y,z=z}
end
local function copyLocation(value)
    return type(value)=="table" and location(value.x,value.y,value.z) or nil
end
local function nativePoint(point)
    if type(point)~="table" then return nil end
    local x,y,z=point.posX,point.posY,point.posZ or 0
    if not finite(x) or not finite(y) then return nil end
    if point.worldX~=nil or point.worldY~=nil then
        if not finite(point.worldX) or not finite(point.worldY) then return nil end
        x=point.worldX*300+x;y=point.worldY*300+y
    end
    return location(x,y,z)
end
local function samePoint(a,b)
    return a and b and a.x==b.x and a.y==b.y and a.z==b.z
end

-- Native SpawnPoints.initServer1 runs after server Lua loads, calls the shared
-- SpawnRegionMgr and raises this event. Keep a private normalized snapshot;
-- per-player requests never reload spawn files or scan map squares.
function P.onSpawnRegionsLoaded(regions)
    P.regionRevision=(P.regionRevision or 0)+1
    P.regions={}
    P.regionsLoaded=type(regions)=="table"
    if not P.regionsLoaded then return end
    for index,region in ipairs(regions) do
        if type(region)=="table" and type(region.name)=="string" and #region.name>0
                and #region.name<=192 and not region.name:find("[%z\1-\31\127]") and type(region.points)=="table" then
            local entry={id="region:"..index..":"..region.name,name=region.name,regionName=region.name,points={}}
            for profession,points in pairs(region.points) do
                if type(profession)=="string" and type(points)=="table" then
                    local normalized={}
                    for _,point in ipairs(points) do
                        local valid=nativePoint(point)
                        if valid then normalized[#normalized+1]=valid end
                    end
                    entry.points[string.lower(profession)]=normalized
                end
            end
            P.regions[#P.regions+1]=entry
        end
    end
end

local function profession(pl,pending,actualBirth)
    local snapshot=pending and (pending.targetSnapshot or pending.creationSnapshot)
    if snapshot and snapshot.identity and snapshot.identity.profession then
        return string.lower(tostring(snapshot.identity.profession))
    end
    if actualBirth and pl and pl.getDescriptor then
        local descriptor=pl:getDescriptor()
        local kind=descriptor and descriptor.getCharacterProfession and descriptor:getCharacterProfession()
        if kind then return string.lower(tostring(kind)) end
    end
    return "base:unemployed"
end
local function pointsFor(entry,key)
    local bare=key:match("^[^:]+:(.+)$") or key
    local points=entry.points[key] or entry.points[bare]
    if not points or #points==0 then points=entry.points["base:unemployed"] or entry.points.unemployed end
    return points and #points>0 and points or nil
end
local function nativeRegionName(pl,pending,actualBirth)
    if not P.regionsLoaded then return nil,"Server spawn regions are not loaded" end
    local key=profession(pl,pending,actualBirth)
    local first
    for _,entry in ipairs(P.regions or {}) do
        if pointsFor(entry,key) then
            first=first or entry.regionName
            if string.lower(entry.regionName):find("bunker",1,true) then return entry.regionName end
        end
    end
    if first then return first end
    return nil,"No compatible native region is available for character creation"
end
local function withNativeRegion(choice,pl,pending,actualBirth)
    local name,err=nativeRegionName(pl,pending,actualBirth)
    if not name then return nil,err end
    -- Even a forced absolute destination needs a real configured region in
    -- native CreatePlayerPacket before the guarded birth continuation.
    choice.regionName=name
    return choice
end
local function forced(pl,context)
    local username=R.getUsername(pl)
    local cage=ParadiseDev.Cage
    local caged=context and context.caged
    if caged==nil then caged=cage and cage.isCaged and cage.isCaged(pl) end
    if caged then
        local x,y,z=R.getCagedRespawnLoc(username,pl)
        local point=location(x,y,z)
        if not point then
            local sand=SandboxVars and SandboxVars.ParadiseZ or {}
            local sx,sy,sz=tostring(sand.DefaultCageCoords or ""):match("^%s*([^;,]+)[;,]([^;,]+)[;,]([^;,]+)%s*$")
            point=location(tonumber(sx),tonumber(sy),tonumber(sz))
        end
        if not point then return nil,"No valid authoritative cage spawn is available" end
        return {id="cage",name="Cage",location=point}
    end
    local x,y,z=R.getSafehouseRespawnLoc(username)
    local point=location(x,y,z)
    if point then return {id="safehouse",name="Safehouse",location=point} end
    x,y,z=R.getServerRespawnLoc()
    point=location(x,y,z)
    if point then return {id="fixed",name="Server spawn point",location=point} end
end
local function bodyLocation(pending,account)
    local sand=SandboxVars and SandboxVars.ParadiseZ or {}
    if sand.isSpawnAtDeathLoc~=true or not pending then return nil end
    if pending.kind=="restore" then return copyLocation(pending.targetSnapshot and pending.targetSnapshot.location) end
    if pending.kind~="create" or type(account)~="table" then return nil end
    local snapshot
    if pending.sourceKind=="enrollment" then snapshot=account.enrollmentDeath
    elseif pending.sourceKind=="deleted" then snapshot=account.deletedDeath
    else
        local source=account.slots and account.slots[pending.sourceSlot]
        snapshot=source and source.phase=="dead" and source.death
    end
    if snapshot and snapshot.characterKey==pending.sourceCharacterKey then return copyLocation(snapshot.location) end
end

local function placement() return ParadiseDev.SafePlacement end

-- This context is assembled only from authenticated server objects and the
-- private profile ledger. The request packet supplies an option ID, never tags.
function P.context(pl,pending,actualBirth,profileContext)
    local safe=placement()
    local ctx=safe.fromPlayer(pl,profileContext)
    local server=ParadiseDev.LifeProfilesServer
    local state=profileContext or (server and server.getPvEContext and server.getPvEContext(pl,pending,actualBirth==true))
    if type(state)~="table" then
        ctx.ready=false;ctx.reason="Profile permissions are not ready. Retry shortly."
    else
        ctx.ready=state.ready==true and not ctx.confinementError
        ctx.reason=ctx.confinementError or state.reason
        ctx.pve=state.pve==true;ctx.profileId=state.profileId;ctx.bodyKey=state.bodyKey
        ctx.accountRevision=state.accountRevision;ctx.profileRevision=state.profileRevision
        ctx.pveRevision=state.pveRevision
        ctx.contextId=state.contextId;ctx.scope=state.scope
        local tags={};for k,v in pairs(ctx.tags or {}) do tags[k]=v end
        ctx.tags=tags;ctx.tags.pve=ctx.pve
    end
    ctx.profession=profession(pl,pending,actualBirth==true or pending==nil)
    return ctx
end

function P.bunkerPoints(key)
    local result={}
    if not P.regionsLoaded then return result end
    for _,entry in ipairs(P.regions or {}) do
        if string.lower(entry.regionName)=="bunker" then
            for _,point in ipairs(pointsFor(entry,key or "base:unemployed") or {}) do
                result[#result+1]={x=math.floor(point.x)+0.5,y=math.floor(point.y)+0.5,z=point.z}
                if #result>=32 then return result end
            end
        end
    end
    return result
end
placement().fallbackProvider=function(ctx)return P.bunkerPoints(ctx and ctx.profession)end

local function evaluate(point,ctx)
    if ctx.ready==false then return {status="denied",reason=ctx.reason or "Profile permissions need review"} end
    return placement().evaluate(point,ctx)
end
local function requestGround(point)
    -- Bounded native preparation is not a safety verdict. A subsequent fresh
    -- evaluation must confirm the floor before any location is returned.
    local decision={status="pending",phase="terrain",location=point}
    if placement().prepare then placement().prepare(decision) end
end
local function summary(reason,name)
    return tostring(name)..": "..tostring(reason or "Unavailable for this profile")
end
local function inspectPoints(points,ctx)
    local safe,pending,reason={},{},nil
    for index,anchor in ipairs(points or {}) do
        if index>32 then break end
        local point={x=math.floor(anchor.x)+0.5,y=math.floor(anchor.y)+0.5,z=anchor.z}
        local decision=evaluate(point,ctx)
        if decision.status=="denied" and placement().evaluatePolicy(point,ctx).status=="safe" then
            -- A person or object on the configured tile should not invalidate
            -- the whole Bunker. The bounded adjacent search applies the same
            -- profile and ground checks to every candidate.
            local nearby=placement().find(point,ctx,{radius=3,allowFallback=false})
            if nearby.status=="safe" then decision=nearby;point=nearby.location end
        end
        if decision.status=="safe" then safe[#safe+1]=point
        elseif decision.status=="pending" then pending[#pending+1]=point
        else reason=reason or decision.reason end
    end
    return safe,pending,reason
end
local function optionsFor(pl,pending,account,ctx,login)
    if ctx.ready==false then return nil,ctx.reason or "Profile permissions need review" end
    if not P.regionsLoaded then return nil,"Server spawn regions are not loaded" end
    local result={forced=false,options={},unavailable={},zoneRevision=placement().zoneRevision and placement().zoneRevision() or nil}
    local preferred,err=forced(pl,ctx)
    if err then return nil,err end
    if preferred then
        local decision=evaluate(preferred.location,ctx)
        if decision.status~="denied" then
            preferred,err=withNativeRegion(preferred,pl,pending,login==true)
            if not preferred then return nil,err end
            preferred.verificationPending=decision.status=="pending"
            preferred.description=preferred.verificationPending and "Ground will be verified before arrival." or "This location is permitted for this profile."
            result.forced=not login;result.options={preferred}
            return result
        end
        if preferred.id=="cage" then return nil,"Cage recovery requires administrator attention: "..tostring(decision.reason) end
        result.unavailable[#result.unavailable+1]=summary(decision.reason,preferred.name)
    end
    for _,entry in ipairs(P.regions or {}) do
        local points=pointsFor(entry,ctx.profession)
        if points then
            local safe,waiting,reason=inspectPoints(points,ctx)
            if #safe>0 or #waiting>0 then
                result.options[#result.options+1]={id=entry.id,name=entry.name,regionName=entry.regionName,
                    verificationPending=#safe==0,description="Only locations permitted for this profile can be used. Ground is checked before arrival."}
            else result.unavailable[#result.unavailable+1]=summary(reason,entry.name) end
        end
    end
    local body=not login and bodyLocation(pending,account)
    if body then
        local decision=evaluate(body,ctx)
        if decision.status~="denied" then
            local option;option,err=withNativeRegion({id="body",name="Last death location",location=body,
                verificationPending=decision.status=="pending",description="Return only if this profile is allowed here and the ground is safe."},pl,pending,false)
            if not option then return nil,err end
            result.options[#result.options+1]=option
        else result.unavailable[#result.unavailable+1]=summary(decision.reason,"Last death location") end
    end
    if #result.options==0 then return nil,"No safe spawn is currently available. "..table.concat(result.unavailable,"; ") end
    if #result.unavailable>0 then result.warning=table.concat(result.unavailable,"; ") end
    return result
end

function P.options(pl,pending,account)
    return optionsFor(pl,pending,account,P.context(pl,pending,false),false)
end

local function refusal(reason,status,phase,point)
    return nil,reason,{status=status or "denied",reason=reason,phase=phase or "policy",location=copyLocation(point)}
end
local function resolveFor(pl,pending,account,spawnId,actualBirth,ctx,login,pinned,pure)
    if ctx.ready~=true then return refusal(ctx.reason or "Profile permissions need review",ctx.confinementError and "denied" or "pending") end
    if type(spawnId)~="string" or #spawnId==0 or #spawnId>256 then return refusal("Choose a valid server spawn location") end
    if not P.regionsLoaded then return refusal("Server spawn regions are not loaded","pending") end
    local function chosen(choice)
        if pinned and not samePoint(pinned,choice.location) then return refusal("The approved arrival point changed. Refresh the choices.") end
        local decision=evaluate(choice.location,ctx)
        if decision.status=="pending" then
            if not pure and decision.phase=="terrain" then requestGround(choice.location) end
            return refusal(decision.reason or "Loading and checking safe ground. Retry this destination shortly.","pending",decision.phase,choice.location)
        end
        if decision.status~="safe" then return refusal(decision.reason or "This destination is no longer safe for this profile","denied",decision.phase,choice.location) end
        choice.zoneRevision=decision.zoneRevision;choice.profileRevision=ctx.profileRevision
        local resolved,err=withNativeRegion(choice,pl,pending,actualBirth==true or login==true)
        if not resolved then return refusal(err) end
        return resolved,nil,decision
    end
    local preferred,err=forced(pl,ctx)
    if err then return refusal(err) end
    if preferred then
        local decision=evaluate(preferred.location,ctx)
        if preferred.id=="cage" or decision.status~="denied" then
            -- Never quietly move to a newly forced destination the owner did
            -- not choose. The fresh menu will show the new cage/safehouse policy.
            if spawnId~=preferred.id then return refusal("Spawn policy changed. Refresh and choose the current destination.") end
            return chosen(preferred)
        end
    end
    if spawnId=="body" and not login then
        local point=bodyLocation(pending,account)
        if not point then return refusal("The selected death location is no longer available") end
        return chosen({id="body",name="Last death location",location=point})
    end
    for _,entry in ipairs(P.regions or {}) do
        if entry.id==spawnId then
            local points=pointsFor(entry,ctx.profession)
            if not points then return refusal("The selected region has no compatible spawn point") end
            local safe,waiting,reason=inspectPoints(points,ctx)
            if #safe==0 then
                if #waiting>0 then
                    local decision=evaluate(waiting[1],ctx)
                    if not pure and decision.phase=="terrain" then requestGround(waiting[1]) end
                    return refusal(decision.reason or "Loading and checking safe ground. Retry this destination shortly.","pending",decision.phase,waiting[1])
                end
                return refusal(reason or "The selected region has no safe point for this profile")
            end
            local previous=pending and pending.spawnSelection
            local point
            if pinned then
                for _,candidate in ipairs(safe) do if samePoint(candidate,pinned) then point=candidate;break end end
                if not point then return refusal("The approved arrival point is no longer safe. Choose a destination again.") end
            end
            if previous and previous.id==spawnId then
                for _,candidate in ipairs(safe) do if samePoint(candidate,previous.location) then point=candidate;break end end
            end
            point=point or safe[ZombRand(#safe)+1]
            return chosen({id=entry.id,name=entry.name,regionName=entry.regionName,location=copyLocation(point)})
        end
    end
    return refusal("The selected spawn region is no longer available. Refresh the choices.")
end
function P.resolve(pl,pending,account,spawnId,actualBirth)
    return resolveFor(pl,pending,account,spawnId,actualBirth,P.context(pl,pending,actualBirth),false)
end
function P.loginOptions(pl,ctx)
    return optionsFor(pl,nil,nil,P.context(pl,nil,false),true)
end
function P.loginResolve(pl,ctx,spawnId)
    -- ctx is supplied by the native authenticated login bridge, never by the
    -- client command. Transfer and admission must use the exact approved tile.
    local pinned=ctx and ctx.loginLocation
    if pinned~=nil and not copyLocation(pinned) then return nil,"Invalid approved arrival point" end
    return resolveFor(pl,nil,nil,spawnId,false,P.context(pl,nil,false),true,pinned)
end
function P.loginAllowed(pl,ctx,point)
    return evaluate(point,P.context(pl,nil,false))
end
function P.loginPolicyAllowed(pl,ctx,point)
    local context=P.context(pl,nil,false)
    if context.ready==false then return {status="denied",reason=context.reason} end
    return placement().evaluateSavedPolicy(point,context)
end

-- Stable across the lookup body, transfer body and final native admission.
-- Length framing prevents delimiter collisions; this is a freshness stamp,
-- not an authorization secret. Native connection/body identity is bound too.
function P.loginPolicyToken(pl,ctx)
    local context=P.context(pl,nil,false)
    if context.ready~=true then return nil,context.reason or "Profile permissions are not ready" end
    local preferred,err=forced(pl,context)
    if err then return nil,err end
    local engine=ParadiseDev.Zones and ParadiseDev.Zones.Engine
    local values={}
    local function add(value)
        local text=tostring(value==nil and "" or value)
        values[#values+1]=tostring(#text)..":"..text
    end
    add(context.scope);add(context.profileId);add(context.accountRevision)
    add(context.profileRevision);add(context.pveRevision);add(context.pve)
    add(context.admin);add(context.adminBypass);add(context.requiredZoneId);add(engine and engine.zoneRevision)
    add(P.regionRevision or 0);add(context.profession)
    local keys={};for key,value in pairs(context.tags or {}) do if value then keys[#keys+1]=tostring(key) end end
    table.sort(keys);for _,key in ipairs(keys) do add(key) end
    add("preferred");add(preferred and preferred.id)
    if preferred then add(preferred.location.x);add(preferred.location.y);add(preferred.location.z) end
    return table.concat(values,"|")
end

-- A first native character has selected its profession/traits only now. A
-- creation that changed its effective access must never enter at an unchecked
-- vanilla point. The same approved Bunker fallback is available on this path.
local function birthContext(pl,pending,account,profileContext)
    local server=ParadiseDev.LifeProfilesServer
    if not profileContext and server and server.birthPvEContext then
        profileContext=server.birthPvEContext(pl,pending,account)
    end
    local context=P.context(pl,pending,true,profileContext)
    if context.ready~=true then
        return nil,{status=context.confinementError and "denied" or "pending",phase="policy",reason=context.reason or "Profile permissions are not ready"}
    end
    return context
end
local function birthResolved(choice,err,result)
    if not choice then return result or {status="denied",phase="policy",reason=err} end
    return {status="safe",phase="terrain",location=copyLocation(choice.location),regionName=choice.regionName,
        spawnId=choice.id,zoneRevision=choice.zoneRevision,profileRevision=choice.profileRevision}
end

-- These helpers inspect supplied server state only. They do not enroll a life,
-- mutate a body or prepare chunks. A caller may retain the same provisional
-- body while pending, request bounded preparation separately, and check again.
function P.checkBirthPlacement(pl,pending,account,profileContext,point)
    local context,err=birthContext(pl,pending,account,profileContext)
    if not context then return err end
    local preferred,why=forced(pl,context)
    if why then return {status="denied",phase="policy",reason=why} end
    if preferred and (preferred.id=="cage" or evaluate(preferred.location,context).status~="denied")
        and not samePoint(point,preferred.location) then
        return {status="denied",phase="policy",reason="Required spawn destination changed. Choose the current destination again."}
    end
    return evaluate(point,context)
end
function P.prepareBirthPlacement(result)
    return placement().prepare and placement().prepare(result)==true or false
end
function P.preBirthPlacement(pl,pending,account,profileContext,preparedPoint)
    local context,notReady=birthContext(pl,pending,account,profileContext)
    if not context then return notReady end
    local preferred,err=forced(pl,context)
    if err then return {status="denied",phase="policy",reason=err} end
    local usePreferred=preferred and (preferred.id=="cage" or evaluate(preferred.location,context).status~="denied")
    if preparedPoint then
        if usePreferred and not samePoint(preparedPoint,preferred.location) then
            return {status="denied",phase="policy",reason="Required spawn destination changed. Choose the current destination again."}
        end
        local prepared=evaluate(preparedPoint,context)
        if prepared.status=="safe" or prepared.status=="pending" then return prepared end
    end
    local id=usePreferred and preferred.id or pending and pending.spawnSelection and pending.spawnSelection.id
    if id then
        return birthResolved(resolveFor(pl,pending,account,id,true,context,false,nil,true))
    end
    if pending then return {status="denied",phase="policy",reason="Choose a spawn destination before creating this character"} end
    -- A refused server lease must never fall through to a different position
    -- supplied by the native creation packet. Only configured fallback points
    -- remain eligible; legacy requests without a prepared point retain their
    -- existing native-position validation.
    local current=not preparedPoint and location(pl:getX(),pl:getY(),pl:getZ())
    local checked=current and evaluate(current,context)
    if checked and (checked.status=="safe" or checked.status=="pending") then return checked end
    local safe,waiting,reason=inspectPoints(P.bunkerPoints(context.profession),context)
    if #safe>0 then return evaluate(safe[1],context) end
    if #waiting>0 then return evaluate(waiting[1],context) end
    return {status="denied",phase="terrain",reason=reason or "No safe starting ground is currently available. Choose another permitted spawn."}
end

-- The visible creation screen sends names and advisory trait/profession hints,
-- never coordinates. Actual native body traits are rechecked by preBirthPlacement.
function P.previewBirth(pl,pending,account,regionName,professionHint,pveHint,profileContext)
    local context,notReady=birthContext(pl,pending,account,profileContext)
    if not context then return notReady end
    local intent=account and account.creationIntent
    local snapshot=pending and (pending.targetSnapshot or pending.creationSnapshot) or intent and intent.snapshot
    local frozen=(pending and pending.kind=="restore") or snapshot~=nil
    if frozen and snapshot and snapshot.identity and type(snapshot.identity.profession)=="string" then
        context.profession=string.lower(snapshot.identity.profession)
    end
    if not frozen then
        if type(pveHint)~="boolean" or type(professionHint)~="string" or #professionHint==0 or #professionHint>128
            or professionHint:find("[%z\1-\31\127]") then
            return {status="denied",phase="policy",reason="Choose valid character traits and a profession"}
        end
        context.pve=pveHint;context.tags.pve=pveHint;context.profession=string.lower(professionHint)
    end
    local preferred,err=forced(pl,context)
    if err then return {status="denied",phase="policy",reason=err} end
    local id
    if preferred and (preferred.id=="cage" or evaluate(preferred.location,context).status~="denied") then id=preferred.id
    elseif pending and pending.spawnSelection then id=pending.spawnSelection.id
    else
        -- A retained first-creation journal can outlive the native menu's
        -- selectedRegion. Recover only from configured Bunker points, using
        -- its frozen profile; an arbitrary fresh request cannot omit a region.
        if intent and (regionName==nil or regionName=="") then
            for _,entry in ipairs(P.regions or {}) do
                if string.lower(entry.regionName)=="bunker" and pointsFor(entry,context.profession) then id=entry.id;break end
            end
        end
        if id then return birthResolved(resolveFor(pl,pending,account,id,true,context,false,nil,true)) end
        if type(regionName)~="string" or #regionName==0 or #regionName>192 then
            return {status="denied",phase="policy",reason="Choose a configured spawn region"}
        end
        for _,entry in ipairs(P.regions or {}) do if entry.regionName==regionName then id=entry.id;break end end
    end
    if not id then return {status=P.regionsLoaded and "denied" or "pending",phase="policy",reason="The selected spawn region is unavailable"} end
    return birthResolved(resolveFor(pl,pending,account,id,true,context,false,nil,true))
end

function P.birthLocation(pl,pending,account)
    local result=P.preBirthPlacement(pl,pending,account)
    if result.status=="safe" then return result.location end
    if result.status=="pending" then P.prepareBirthPlacement(result) end
    return nil,result.reason or "Safe starting ground is being checked. Retry this destination shortly."
end

Events.OnSpawnRegionsLoaded.Add(P.onSpawnRegionsLoaded)
