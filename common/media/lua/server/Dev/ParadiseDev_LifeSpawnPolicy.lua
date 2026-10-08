-- Server-owned destination choices. No client coordinates are accepted here.
if isClient and isClient() then return end
require "Dev/ParadiseDev_Reincarnate"

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
    -- native CreatePlayerPacket before OnNewGame enforces the final location.
    choice.regionName=name
    return choice
end
local function forced(pl)
    local username=R.getUsername(pl)
    local cage=ParadiseDev.Cage
    if cage and cage.isCaged and cage.isCaged(pl) then
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

function P.options(pl,pending,account)
    local preferred,err=forced(pl)
    if err then return nil,err end
    if preferred then
        preferred,err=withNativeRegion(preferred,pl,pending,false)
        if not preferred then return nil,err end
        return {forced=true,options={preferred}}
    end
    if not P.regionsLoaded then return nil,"Server spawn regions are not loaded" end
    local result={forced=false,options={}}
    local key=profession(pl,pending,false)
    for _,entry in ipairs(P.regions or {}) do
        if pointsFor(entry,key) then
            result.options[#result.options+1]={id=entry.id,name=entry.name,regionName=entry.regionName}
        end
    end
    local body=bodyLocation(pending,account)
    if body then
        local option;option,err=withNativeRegion({id="body",name="Last death location",location=body},pl,pending,false)
        if not option then return nil,err end
        result.options[#result.options+1]=option
    end
    if #result.options==0 then return nil,"No compatible server spawn locations are available" end
    return result
end

function P.resolve(pl,pending,account,spawnId,actualBirth)
    local preferred,err=forced(pl)
    if err then return nil,err end
    -- Current cage/safehouse/fixed policy also prevails if it changed after the
    -- menu was shown. A previously allowed region cannot bypass a new cage.
    if preferred then return withNativeRegion(preferred,pl,pending,actualBirth==true) end
    if type(spawnId)~="string" or #spawnId==0 or #spawnId>256 then return nil,"Choose a valid server spawn location" end
    if not P.regionsLoaded then return nil,"Server spawn regions are not loaded" end
    if spawnId=="body" then
        local point=bodyLocation(pending,account)
        if not point then return nil,"The selected death location is no longer available" end
        return withNativeRegion({id="body",name="Last death location",location=point},pl,pending,actualBirth==true)
    end
    local key=profession(pl,pending,actualBirth==true)
    for _,entry in ipairs(P.regions or {}) do
        if entry.id==spawnId then
            local points=pointsFor(entry,key)
            if not points then return nil,"The selected region has no compatible spawn point" end
            local previous=pending and pending.spawnSelection
            if previous and previous.id==spawnId then
                for _,point in ipairs(points) do
                    if samePoint(point,previous.location) then
                        return {id=entry.id,name=entry.name,regionName=entry.regionName,location=copyLocation(point)}
                    end
                end
            end
            local point=points[ZombRand(#points)+1]
            return {id=entry.id,name=entry.name,regionName=entry.regionName,location=copyLocation(point)}
        end
    end
    return nil,"The selected spawn region is no longer available"
end

Events.OnSpawnRegionsLoaded.Add(P.onSpawnRegionsLoaded)
