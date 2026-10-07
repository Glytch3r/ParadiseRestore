require "Dev/ParadiseDev_TraitUtils"
ParadiseDev = ParadiseDev or {}
ParadiseDev.PvEPolicy = ParadiseDev.PvEPolicy or {}
local Policy = ParadiseDev.PvEPolicy

-- The same half-open geometry and tie rule is used on both sides. Evaluate
-- every containing segment: insertion order must not select a different rule.
function Policy.area(region)
    return (region.xMax-region.xMin)*(region.yMax-region.yMin)
end
function Policy.onLevel(zone,z)
    return zone.zMode == "all" or (z >= zone.zMin and z < zone.zMaxExclusive)
end
function Policy.contains(region,x,y,padding)
    padding = padding or 0
    return x >= region.xMin-padding and x < region.xMax+padding and
        y >= region.yMin-padding and y < region.yMax+padding
end
function Policy.better(zone,region,winner,winnerRegion)
    return not winner or zone.priority > winner.priority or
        (zone.priority == winner.priority and Policy.area(region) < Policy.area(winnerRegion)) or
        (zone.priority == winner.priority and Policy.area(region) == Policy.area(winnerRegion) and zone.id < winner.id)
end
function Policy.containingRegion(zone,x,y,z,padding)
    if not Policy.onLevel(zone,z) then return nil end
    local best
    for _,region in ipairs(zone.regions) do
        if Policy.contains(region,x,y,padding) and (not best or Policy.area(region) < Policy.area(best)) then best=region end
    end
    return best
end
function Policy.zoneFor(pl)
    if not pl or not pl.getX or not pl.getY or not pl.getZ then return nil end
    local zones=ParadiseDev.Zones
    if not zones then return nil end
    -- Combat membership is the actor's actual position, never the vehicle's
    -- two-tile entry/rebound margin. Client snapshots are display/prevention;
    -- dedicated-server damage checks use their own authoritative geometry.
    if isClient and isClient() then
        local border=zones.Border
        return border and border.authorityAt and border.authorityAt(pl:getX(),pl:getY(),pl:getZ(),0) or nil
    end
    local engine=zones.Engine
    return engine and engine.getAuthority and engine.getAuthority(pl:getX(),pl:getY(),pl:getZ(),0) or nil
end
function Policy.hasPvETrait(pl)
    return pl ~= nil and ParadiseDev.hasTrait and ParadiseDev.hasTrait(pl,"ParadiseDev:PvE") == true or false
end
function Policy.inNativeZone(pl)
    return pl ~= nil and NonPvpZone and NonPvpZone.getNonPvpZone and
        NonPvpZone.getNonPvpZone(math.floor(pl:getX()),math.floor(pl:getY())) ~= nil or false
end
function Policy.isPvEZone(pl)
    local zone=Policy.zoneFor(pl)
    return (zone and zone.features and zone.features.isPvE == true) or Policy.inNativeZone(pl)
end
function Policy.isProtected(pl)
    return Policy.hasPvETrait(pl) or Policy.isPvEZone(pl)
end
function Policy.isHitProtected(attacker,victim)
    return Policy.isProtected(attacker) or Policy.isProtected(victim)
end
function Policy.safetyState(pl)
    if not pl then return false,nil,nil end
    if Policy.hasPvETrait(pl) then return true,true,"PvE character" end
    if Policy.inNativeZone(pl) then return true,true,"Safe zone" end
    local zone=Policy.zoneFor(pl)
    if zone and zone.features then
        if zone.features.isPvE == true then return true,true,"PvE zone",zone end
        if zone.features.isKos == true then return true,false,"KoS zone",zone end
    end
    return false,nil,nil
end

-- Publication only runs on the server's Lua thread after authoritative load or
-- edits. The bridge copies/validates the payload into an immutable Java index;
-- native damage threads never call back into this Lua table.
function Policy.publishZones()
    if isClient and isClient() then return false end
    local engine=ParadiseDev.Zones and ParadiseDev.Zones.Engine
    if not engine or not Policy.zonesReady then return false end
    if Policy.publishedRevision == engine.zoneRevision then return true end
    if Policy.failedRevision == engine.zoneRevision then return false end
    if not ParadisePvEBridge then
        Policy.readyAnnounced=nil
        if not Policy.bridgeWarning then print("[ParadisePvE] Protection bridge unavailable; native protection verification required.");Policy.bridgeWarning=true end
        return false
    end
    local ids,zones={},{}
    for id in pairs(engine.zones) do ids[#ids+1]=id end
    table.sort(ids)
    for _,id in ipairs(ids) do
        local zone=engine.zones[id]
        local entry={id=zone.id,priority=zone.priority,pve=zone.features and zone.features.isPvE == true or false,
            kos=zone.features and zone.features.isKos == true or false,allFloors=zone.zMode == "all",segments={}}
        for _,region in ipairs(zone.regions) do
            entry.segments[#entry.segments+1]={x1=region.xMin,y1=region.yMin,x2=region.xMax,y2=region.yMax,
                z1=zone.zMin,z2=zone.zMaxExclusive}
        end
        zones[#zones+1]=entry
    end
    local ok,result=pcall(ParadisePvEBridge,"publish",engine.zoneRevision,zones)
    if not ok or result ~= true then
        Policy.failedRevision=engine.zoneRevision
        Policy.readyAnnounced=nil
        if not Policy.publishWarning then print("[ParadisePvE] Zone publication failed; native protection verification required.");Policy.publishWarning=true end
        return false
    end
    Policy.publishedRevision=engine.zoneRevision
    Policy.failedRevision=nil
    Policy.bridgeWarning,Policy.publishWarning=nil,nil
    if not Policy.readyAnnounced then
        print("[ParadisePvE] policy ready; revision="..tostring(engine.zoneRevision).."; zones="..tostring(#zones))
        Policy.readyAnnounced=true
    end
    return true
end
function Policy.onZonesChanged()
    if isClient and isClient() then return end
    Policy.zonesReady=true
    Policy.publishZones()
end
function Policy.refreshPlayer(pl)
    if not pl or (isClient and isClient()) or not Policy.publishZones() then return false end
    return ParadisePvEBridge("refreshPlayer",pl) == true
end
