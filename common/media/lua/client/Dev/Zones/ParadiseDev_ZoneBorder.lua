require "Dev/ParadiseDev_PvEPolicy"
ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.Border = ParadiseDev.Zones.Border or {}
ParadiseDev.Zones.Border.CELL_SIZE = 100
ParadiseDev.Zones.Border.zones = ParadiseDev.Zones.Border.zones or {}
ParadiseDev.Zones.Border.cellIndex = ParadiseDev.Zones.Border.cellIndex or {}
ParadiseDev.Zones.Border.borderWidth = ParadiseDev.Zones.Border.borderWidth or 2
ParadiseDev.Zones.Border.vehicleMode = ParadiseDev.Zones.Border.vehicleMode or "observe"
ParadiseDev.Zones.Border.cagedZoneId = ParadiseDev.Zones.Border.cagedZoneId or nil
ParadiseDev.Zones.Border.noticeZoneId = ParadiseDev.Zones.Border.noticeZoneId or nil
ParadiseDev.Zones.Border.noticeAt = ParadiseDev.Zones.Border.noticeAt or 0
ParadiseDev.Zones.Border.vehicleReboundAt = ParadiseDev.Zones.Border.vehicleReboundAt or 0
ParadiseDev.Zones.Border.stateReceivedAt = nil
ParadiseDev.Zones.Border.CACHE_TTL_MS = 3000

function ParadiseDev.Zones.Border.isFresh(revision)
    local border = ParadiseDev.Zones.Border
    local now = getTimestampMs()
    return border.stateReceivedAt ~= nil and now >= border.stateReceivedAt
        and now - border.stateReceivedAt <= border.CACHE_TTL_MS
        and (revision == nil or revision == border.stateRevision)
end

function ParadiseDev.Zones.Border.requestFreshState(pl)
    local border = ParadiseDev.Zones.Border
    local now = getTimestampMs()
    if border.stateRequestedAt and now >= border.stateRequestedAt and now - border.stateRequestedAt < 1000 then return end
    if pl and sendClientCommand then
        sendClientCommand(pl, "PZZoneEngine", "requestBoundaryState", {})
        border.stateRequestedAt = now
    end
end

function ParadiseDev.Zones.Border.cellCoord(value)
    return math.floor(value / ParadiseDev.Zones.Border.CELL_SIZE)
end

function ParadiseDev.Zones.Border.cellKey(cx, cy)
    return tostring(cx) .. ":" .. tostring(cy)
end

function ParadiseDev.Zones.Border.area(region)
    return (region.xMax - region.xMin) * (region.yMax - region.yMin)
end

function ParadiseDev.Zones.Border.onLevel(zone, z)
    return ParadiseDev.PvEPolicy.onLevel(zone,z)
end

function ParadiseDev.Zones.Border.contains(region, x, y, padding)
    return ParadiseDev.PvEPolicy.contains(region,x,y,padding)
end

function ParadiseDev.Zones.Border.rebuildIndex()
    ParadiseDev.Zones.Border.cellIndex = {}
    for _, zone in ipairs(ParadiseDev.Zones.Border.zones) do
        for _, region in ipairs(zone.regions) do
            local minCX = ParadiseDev.Zones.Border.cellCoord(region.xMin - ParadiseDev.Zones.Border.borderWidth)
            local maxCX = ParadiseDev.Zones.Border.cellCoord(region.xMax + ParadiseDev.Zones.Border.borderWidth - 0.001)
            local minCY = ParadiseDev.Zones.Border.cellCoord(region.yMin - ParadiseDev.Zones.Border.borderWidth)
            local maxCY = ParadiseDev.Zones.Border.cellCoord(region.yMax + ParadiseDev.Zones.Border.borderWidth - 0.001)
            for cx = minCX, maxCX do
                for cy = minCY, maxCY do
                    local key = ParadiseDev.Zones.Border.cellKey(cx, cy)
                    local bucket = ParadiseDev.Zones.Border.cellIndex[key]
                    if not bucket then
                        bucket = {}
                        ParadiseDev.Zones.Border.cellIndex[key] = bucket
                    end
                    bucket[#bucket + 1] = { zone = zone, region = region }
                end
            end
        end
    end
end

function ParadiseDev.Zones.Border.authorityAt(x, y, z, padding)
    local bucket = ParadiseDev.Zones.Border.cellIndex[ParadiseDev.Zones.Border.cellKey(ParadiseDev.Zones.Border.cellCoord(x), ParadiseDev.Zones.Border.cellCoord(y))]
    if not bucket then return nil, nil end
    local winner, winnerRegion
    for _, candidate in ipairs(bucket) do
        local zone, region = candidate.zone, candidate.region
        if ParadiseDev.Zones.Border.onLevel(zone, z) and ParadiseDev.Zones.Border.contains(region, x, y, padding) and
            ParadiseDev.PvEPolicy.better(zone,region,winner,winnerRegion) then
            winner, winnerRegion = zone, region
        end
    end
    return winner, winnerRegion
end

function ParadiseDev.Zones.Border.zoneById(id)
    if not id then return nil end
    for _, zone in ipairs(ParadiseDev.Zones.Border.zones) do
        if zone.id == id then return zone end
    end
    return nil
end

function ParadiseDev.Zones.Border.zoneContains(zone, x, y, z)
    if not zone or not ParadiseDev.Zones.Border.onLevel(zone, z) then return false end
    for _, region in ipairs(zone.regions or {}) do
        if ParadiseDev.Zones.Border.contains(region, x, y, 0) then return true end
    end
    return false
end

function ParadiseDev.Zones.Border.nearestRegionCenter(zone, x, y)
    local winner, winnerDistance
    for _, region in ipairs(zone and zone.regions or {}) do
        local closestX = math.max(region.xMin, math.min(x, region.xMax - 0.001))
        local closestY = math.max(region.yMin, math.min(y, region.yMax - 0.001))
        local dx, dy = x - closestX, y - closestY
        local distance = dx * dx + dy * dy
        if not winner or distance < winnerDistance then
            winner, winnerDistance = region, distance
        end
    end
    if not winner then return nil, nil end
    return (winner.xMin + winner.xMax - 1) / 2, (winner.yMin + winner.yMax - 1) / 2
end

function ParadiseDev.Zones.Border.inBoundaryBand(region, x, y, width)
    if not region or not ParadiseDev.Zones.Border.contains(region, x, y, width) then return false end
    if not ParadiseDev.Zones.Border.contains(region, x, y, 0) then return true end
    local edgeDistance = math.min(x - region.xMin, region.xMax - x, y - region.yMin, region.yMax - y)
    return edgeDistance <= width
end

function ParadiseDev.Zones.Border.getAuthorityAt(x, y, z, padding)
    return ParadiseDev.Zones.Border.authorityAt(x, y, z, padding or 0)
end

function ParadiseDev.Zones.Border.getZoneFor(pl)
    pl = pl or getPlayer()
    if not pl then return nil, nil end
    local vehicle = pl:getVehicle()
    local x, y = pl:getX(), pl:getY()
    if vehicle then x, y = vehicle:getX(), vehicle:getY() end
    return ParadiseDev.Zones.Border.authorityAt(x, y, pl:getZ(), vehicle and 2.0 or 0)
end

function ParadiseDev.Zones.Border.hasFeatureAt(x, y, z, feature)
    local zone = ParadiseDev.Zones.Border.authorityAt(x, y, z, 0)
    return zone ~= nil and zone.features ~= nil and zone.features[feature] == true
end

function ParadiseDev.Zones.Border.localPlayerHasFeature(feature)
    local zone = ParadiseDev.Zones.Border.getZoneFor(getPlayer())
    return zone ~= nil and zone.features ~= nil and zone.features[feature] == true
end

function ParadiseDev.Zones.Border.nearestOutside(region, x, y, padding)
    local left, right = region.xMin - padding, region.xMax + padding
    local top, bottom = region.yMin - padding, region.yMax + padding
    local west, east = x - left, right - x
    local north, south = y - top, bottom - y
    if west <= east and west <= north and west <= south then return left - 0.05, y end
    if east <= north and east <= south then return right + 0.05, y end
    if north <= south then return x, top - 0.05 end
    return x, bottom + 0.05
end

-- Do not predict a correction from one denied rectangle into another denied authority.
function ParadiseDev.Zones.Border.safeOutside(x, y, z, padding)
    local firstZone, region = ParadiseDev.Zones.Border.authorityAt(x,y,z,padding)
    if not firstZone or firstZone.allowed then return x,y end
    local queue, seen = {region}, {[region]=true}
    local cursor, queries = 1,0
    local bestX,bestY,bestDistance
    while queue[cursor] and queries < 32 do
        local current = queue[cursor]
        cursor = cursor+1
        local left,right = current.xMin-padding,current.xMax+padding
        local top,bottom = current.yMin-padding,current.yMax+padding
        local cx,cy = math.max(left,math.min(x,right)),math.max(top,math.min(y,bottom))
        local points = {{left-0.05,cy},{right+0.05,cy},{cx,top-0.05},{cx,bottom+0.05}}
        for _,point in ipairs(points) do
            if queries >= 32 then break end
            queries = queries+1
            local nextZone,nextRegion = ParadiseDev.Zones.Border.authorityAt(point[1],point[2],z,padding)
            if not nextZone or nextZone.allowed then
                local distance = (point[1]-x)^2+(point[2]-y)^2
                if not bestDistance or distance < bestDistance then
                    bestX,bestY,bestDistance = point[1],point[2],distance
                end
            elseif nextRegion and not seen[nextRegion] then
                seen[nextRegion]=true
                queue[#queue+1]=nextRegion
            end
        end
    end
    return bestX,bestY
end

function ParadiseDev.Zones.Border.onPlayerUpdate(pl)
    if not pl or pl ~= getPlayer() or not pl:isAlive() then return end
    local client = ParadiseDev.Zones.ReboundClient
    if client and client.observeActor then client.observeActor(pl) end
    if not ParadiseDev.Zones.Border.isFresh() then
        ParadiseDev.Zones.Border.requestFreshState(pl)
        return
    end
    local vehicle = pl:getVehicle()
    local x, y = pl:getX(), pl:getY()
    if vehicle then x,y = ParadiseDev.Zones.ReboundClient.vehiclePosition(vehicle) end

    local cageZone = ParadiseDev.Zones.Border.zoneById(ParadiseDev.Zones.Border.cagedZoneId)
    if cageZone and (not cageZone.features or not cageZone.features.isCage) then cageZone = nil end
    if cageZone and not ParadiseDev.Zones.Border.zoneContains(cageZone, x, y, pl:getZ()) then

        return
    end

    local padding = vehicle and 2.0 or 0
    local zone, region = ParadiseDev.Zones.Border.authorityAt(x, y, pl:getZ(), padding)
    local noticeZone, noticeRegion = ParadiseDev.Zones.Border.authorityAt(x, y, pl:getZ(), padding + ParadiseDev.Zones.Border.borderWidth)
    if noticeZone and not noticeZone.allowed and ParadiseDev.Zones.Border.inBoundaryBand(noticeRegion, x, y, padding + ParadiseDev.Zones.Border.borderWidth) then
        local now = getTimestampMs()
        if ParadiseDev.Zones.Border.noticeZoneId ~= noticeZone.id or now - ParadiseDev.Zones.Border.noticeAt >= 1800 then
            pl:setHaloNote("You cannot enter this zone", 255, 90, 60, 160.0)
            ParadiseDev.Zones.Border.noticeZoneId = noticeZone.id
            ParadiseDev.Zones.Border.noticeAt = now
        end
    elseif ParadiseDev.Zones.Border.noticeZoneId then
        ParadiseDev.Zones.Border.noticeZoneId = nil
    end
    if not zone or zone.allowed then return end
    -- A fresh server snapshot already decided both occupants' permissions for
    -- this exact ride. Exit locally on contact; normal VehicleExit synchronizes
    -- everyone. Missing/stale ride authority leaves the server fallback in charge.
    if vehicle and vehicle:getCharacter(0) ~= pl then
        if client and client.predictPassengerExit then client.predictPassengerExit(pl,zone) end
        return
    end

    local outX, outY = ParadiseDev.Zones.Border.safeOutside(x, y, pl:getZ(), padding)
    if not outX then return end
    if not vehicle then
        local client = ParadiseDev.Zones.ReboundClient
        if client and client.applyFoot then client.applyFoot(pl, outX, outY, pl:getZ()) end
    elseif vehicle:getCharacter(0) == pl then
        local client = ParadiseDev.Zones.ReboundClient
        if client and client.moveVehicle then client.moveVehicle(vehicle, outX, outY) end
    end
end
function ParadiseDev.Zones.Border.onServerCommand(module, command, args)
    if module ~= "PZZoneEngine" or command ~= "boundaryState" or not args then return end
    local client = ParadiseDev.Zones.ReboundClient
    if not client or not client.acceptState or not client.acceptState(args) then return end
    ParadiseDev.Zones.Border.zones = args.zones or {}
    ParadiseDev.Zones.Border.borderWidth = tonumber(args.borderWidth) or 2
    ParadiseDev.Zones.Border.vehicleMode = args.vehicleMode or "observe"
    ParadiseDev.Zones.Border.cagedZoneId = args.cagedZoneId
    ParadiseDev.Zones.Border.passengerRide = args.passengerRide
    ParadiseDev.Zones.Border.stateRevision = args.stateRevision
    ParadiseDev.Zones.Border.stateReceivedAt = getTimestampMs()
    ParadiseDev.Zones.Border.rebuildIndex()
end

Events.OnServerCommand.Remove(ParadiseDev.Zones.Border.onServerCommand)
Events.OnServerCommand.Add(ParadiseDev.Zones.Border.onServerCommand)
Events.OnPlayerUpdate.Remove(ParadiseDev.Zones.Border.onPlayerUpdate)
Events.OnPlayerUpdate.Add(ParadiseDev.Zones.Border.onPlayerUpdate)
