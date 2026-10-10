-- Server-owned admission and recovery decisions. Never accepts a client context.
if isClient and isClient() then return end
ParadiseDev = ParadiseDev or {}
ParadiseDev.SafePlacement = ParadiseDev.SafePlacement or {}
local S = ParadiseDev.SafePlacement
S.SEARCH_BUDGET = 128
S.SEARCH_RADIUS = 6

local function finite(n)
    return type(n)=="number" and n==n and n>-math.huge and n<math.huge
end
local function savedPosition(p)
    return type(p)=="table" and finite(p.x) and finite(p.y) and finite(p.z)
        and math.abs(p.x)<10000000 and math.abs(p.y)<10000000
        and p.z>=-32 and p.z<32
end
local function valid(p)
    return savedPosition(p) and p.z==math.floor(p.z)
end
local function engine() return ParadiseDev.Zones and ParadiseDev.Zones.Engine end
local function decision(status,reason,p,zone)
    local e=engine()
    return {status=status,reason=reason,location=p and {x=p.x,y=p.y,z=p.z} or nil,
        zoneId=zone and zone.id,zoneRevision=e and e.zoneRevision,phase="policy"}
end
local function terrainDecision(status,reason,p)
    local result=decision(status,reason,p)
    result.phase="terrain"
    return result
end

-- Trusted contexts are built from authenticated server actors/account profiles by
-- the caller. Explicit per-profile PvE replaces the old account-wide pve tag;
-- all other access tags and the existing zone priority/overlap rules are retained.
function S.deniedReason(zone,context)
    if not zone then return nil end
    local tags=context.tags or {}
    local features,policy=zone.features or {},zone.policy or {}
    if features.isBlocked then return "Blocked zone" end
    if features.isKos and context.pve then return "PvE profile cannot enter a KoS zone" end
    local reason
    if features.isHunt and not tags.range_staff and not tags.can_hunt then reason="Hunt authorization required" end
    for tag in pairs(policy.denyTags or {}) do
        if (tag=="pve" and context.pve) or (tag~="pve" and tags[tag]) then reason=reason or "Player profile is denied" end
    end
    local required,matched=false,false
    for tag in pairs(policy.requireAnyTags or {}) do
        required=true
        if (tag=="pve" and context.pve) or (tag~="pve" and tags[tag]) then matched=true end
    end
    if required and not matched then reason=reason or "Required zone authorization missing" end
    if reason and context.admin and context.adminBypass and policy.adminBypass~=false then return nil end
    return reason
end

function S.fromPlayer(pl,profileContext)
    if not pl then return {ready=false} end
    local e=engine()
    local profile=e and e.profiles[e.userName(pl)]
    local profiles=ParadiseDev.LifeProfilesServer
    local source=profileContext or (profiles and profiles.getPvEContext and profiles.getPvEContext(pl)) or {ready=false}
    local context={}
    for key,value in pairs(source) do context[key]=value end
    context.actor=pl
    context.tags={}
    for key,value in pairs(profile and profile.tags or {}) do context.tags[key]=value end
    context.tags.pve=context.pve
    context.admin=ParadiseRestore.isAdm(pl)==true
    context.adminBypass=e and e.adminBypassEnabled()==true or false
    local cage=ParadiseDev.Cage
    local caged=cage and cage.isCaged and cage.isCaged(pl)==true
    -- Offline release is authoritative even before native trait synchronization.
    local store=cage and cage.getStore and cage.getStore()
    local usernameKey=cage and cage.getUsernameKey and cage.getUsernameKey(pl:getUsername())
    if store and usernameKey and store.released and store.released[usernameKey] then caged=false end
    context.caged=caged==true
    if context.caged then
        local key=e and e.playerSteamId(pl)
        local id=key and e.cageAssignments[key]
        local zone=id and e.zones[id] or nil
        if not id and e and e.nearestCageZone then zone=e.nearestCageZone(pl) end
        if not zone or not zone.features or not zone.features.isCage then
            context.ready=false
            context.confinementError="A valid cage must be assigned before this character can enter"
            context.reason=context.confinementError
        else context.requiredZoneId=zone.id end
    end
    return context
end

local function evaluatePolicy(p,context,unchangedSaved)
    if not (unchangedSaved and savedPosition(p) or valid(p)) then return decision("denied","Invalid destination",nil) end
    local e=engine()
    if not e or not ParadiseDev.PvEPolicy or not ParadiseDev.PvEPolicy.zonesReady
        or type(context)~="table" or context.ready~=true or type(context.pve)~="boolean" then
        return decision("pending","Character or zone policy is not ready",p)
    end
    -- Confinement adds an account restriction; it does not bypass trait/zone
    -- policy. A conflicting cage requires admin attention, never public escape.
    if context.requiredZoneId then
        local cage=e.zones[context.requiredZoneId]
        if not cage or not cage.features or not cage.features.isCage
            or not e.zoneContains(cage,p.x,p.y,p.z,0) then
            return decision("denied","Destination must remain inside the assigned cage",p,cage)
        end
    end
    local zone=e.getAuthority(p.x,p.y,p.z,0)
    local reason=S.deniedReason(zone,context)
    return decision(reason and "denied" or "safe",reason,p,zone)
end

function S.evaluatePolicy(p,context)
    return evaluatePolicy(p,context,false)
end

-- A saved body already owns its native position/vehicle. Only current access
-- rules decide whether that unchanged life needs relocation. Preserve exact Z:
-- both the Lua and native zone policies use the same half-open height interval.
function S.evaluateSavedPolicy(p,context)
    return evaluatePolicy(p,context,true)
end

-- A cage must never use the public bunker fallback. Probe at most 128 loaded
-- tiles, starting at a previously verified point and then bounded interior
-- anchors; request terrain only for one unverified interior anchor afterward.
function S.findCage(pl,zone,origin,previous)
    local e=engine()
    if not e or not zone or not zone.features or not zone.features.isCage then
        return decision("denied","A valid assigned cage is required",nil)
    end
    local context=S.fromPlayer(pl)
    context.requiredZoneId=zone.id
    local points={}
    if valid(previous) then points[#points+1]=previous end
    if valid(origin) and e.zoneContains(zone,origin.x,origin.y,origin.z,0) then points[#points+1]=origin end
    local z=zone.zMode=="floor" and zone.zMin or origin and origin.z
    for index,region in ipairs(zone.regions or {}) do
        if index>4 then break end
        local x,y=e.nearestInside(region,origin and origin.x or region.xMin,origin and origin.y or region.yMin,1)
        points[#points+1]={x=x,y=y,z=z}
        points[#points+1]={x=(region.xMin+region.xMax)/2,y=(region.yMin+region.yMax)/2,z=z}
    end
    local pending,tested=nil,0
    for _,point in ipairs(points) do
        local result=S.evaluate(point,context)
        tested=tested+1
        if result.status=="safe" then return result end
        if result.status=="pending" and not pending then pending=result end
        if result.phase=="terrain" and tested<128 then
            local nearby=S.find(point,context,{radius=3,budget=math.min(25,128-tested),allowFallback=false})
            tested=tested+(nearby.tested or 0)
            if nearby.status=="safe" then return nearby end
        end
        if tested>=128 then break end
    end
    return pending or decision("denied","No verified safe ground exists inside the assigned cage",nil,zone)
end

function S.evaluate(p,context)
    local result=S.evaluatePolicy(p,context)
    if result.status~="safe" then return result end
    local cell=getCell()
    local square=cell and cell:getGridSquare(math.floor(p.x),math.floor(p.y),p.z)
    if not square or not square:getChunk() then
        return terrainDecision("pending","Destination terrain is not loaded",p)
    end
    if square:isWaterSquare() or square:has(IsoFlagType.water) then return terrainDecision("denied","Destination is water",p) end
    if not square:hasFloor() or square:HasStairs() or square:isSolid() or square:isSolidTrans()
        or not square:isFree(false) then return terrainDecision("denied","Destination has no clear supporting floor",p) end
    if square:haveFire() or square:hasLitCampfire() then return terrainDecision("denied","Destination has fire",p) end
    if square:isVehicleIntersecting() then return terrainDecision("denied","Destination is occupied by a vehicle",p) end
    local moving=square:getMovingObjects()
    for i=0,moving:size()-1 do
        if moving:get(i)~=context.actor then return terrainDecision("denied","Destination is occupied",p) end
    end
    result.phase="terrain"
    return result
end

-- Only bounded loaded terrain is explored. An unloaded nearby candidate does
-- not become a destination merely because it falls outside a restricted zone.
function S.find(origin,context,options)
    options=options or {}
    if not valid(origin) then return decision("denied","Invalid recovery origin",nil) end
    local start=S.evaluatePolicy(origin,context)
    if start.status=="pending" then return start end
    local tested=0
    local budget=type(options.budget)=="number" and options.budget==options.budget
        and math.max(1,math.min(S.SEARCH_BUDGET,math.floor(options.budget))) or S.SEARCH_BUDGET
    local function test(p)
        tested=tested+1
        local result=S.evaluate(p,context)
        if result.status=="safe" then result.tested=tested; return result end
    end
    if options.previous and valid(options.previous) then
        local dx,dy=options.previous.x-origin.x,options.previous.y-origin.y
        if options.previous.z==origin.z and dx*dx+dy*dy<=64 then
            local previous=test(options.previous)
            if previous then return previous end
        end
    end
    local ox,oy=math.floor(origin.x),math.floor(origin.y)
    local limit=type(options.radius)=="number" and options.radius==options.radius
        and math.max(0,math.min(S.SEARCH_RADIUS,math.floor(options.radius))) or S.SEARCH_RADIUS
    for radius=0,limit do
        for dx=-radius,radius do
            for dy=-radius,radius do
                if (math.abs(dx)==radius or math.abs(dy)==radius) and tested<budget then
                    local result=test({x=ox+dx+0.5,y=oy+dy+0.5,z=origin.z})
                    if result then return result end
                end
            end
        end
        if tested>=budget then break end
    end
    if options.allowFallback~=false and S.fallbackProvider then
        local points=S.fallbackProvider(context) or {}
        local pending,fallbackBudget=nil,64
        for index,p in ipairs(points) do
            if index>32 then break end
            local result=S.evaluate(p,context)
            result.fallback=true
            if result.status=="safe" then result.tested=tested; return result end
            if result.status=="denied" and result.phase=="terrain" and fallbackBudget>0 then
                local nearby=S.find(p,context,{radius=3,allowFallback=false,budget=math.min(49,fallbackBudget)})
                fallbackBudget=fallbackBudget-(nearby.tested or 0)
                if nearby.status=="safe" then nearby.fallback=true;nearby.tested=tested+(64-fallbackBudget);return nearby end
            end
            if result.status=="pending" and not pending then pending=result end
        end
        if pending then pending.tested=tested; return pending end
    end
    local result=decision("denied","No verified safe destination is available",nil)
    result.tested=tested
    return result
end

-- Accepted means loading was requested, never that terrain is safe. One global
-- timestamp bounds attempts; no growing coordinate cache and no client input.
function S.prepare(result)
    if not result or result.status~="pending" or result.phase~="terrain" or not valid(result.location)
        or type(ParadiseLifeBridge)~="function" then return false end
    local now=getTimestampMs()
    if S.prepareAt and now>=S.prepareAt and now-S.prepareAt<1000 then return false end
    S.prepareAt=now
    return ParadiseLifeBridge("prepareLocation",result.location.x,result.location.y,result.location.z)==true
end
