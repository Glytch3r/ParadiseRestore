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
    return zone.zMode == "all" or (z >= zone.zMin and z < zone.zMaxExclusive)
end

function ParadiseDev.Zones.Border.contains(region, x, y, padding)
    return x >= region.xMin - padding and x < region.xMax + padding and
        y >= region.yMin - padding and y < region.yMax + padding
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
            (not winner or zone.priority > winner.priority or
            (zone.priority == winner.priority and ParadiseDev.Zones.Border.area(region) < ParadiseDev.Zones.Border.area(winnerRegion)) or
            (zone.priority == winner.priority and ParadiseDev.Zones.Border.area(region) == ParadiseDev.Zones.Border.area(winnerRegion) and zone.id < winner.id)) then
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

function ParadiseDev.Zones.Border.onPlayerUpdate(pl)
    if not pl or pl ~= getPlayer() or not pl:isAlive() then return end
    local vehicle = pl:getVehicle()
    local x, y = pl:getX(), pl:getY()
    if vehicle then x, y = vehicle:getX(), vehicle:getY() end

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
end
function ParadiseDev.Zones.Border.onServerCommand(module, command, args)
    if module ~= "PZZoneEngine" or command ~= "boundaryState" or not args then return end
    ParadiseDev.Zones.Border.zones = args.zones or {}
    ParadiseDev.Zones.Border.borderWidth = tonumber(args.borderWidth) or 2
    ParadiseDev.Zones.Border.vehicleMode = args.vehicleMode or "observe"
    ParadiseDev.Zones.Border.cagedZoneId = args.cagedZoneId
    ParadiseDev.Zones.Border.rebuildIndex()
end

Events.OnServerCommand.Remove(ParadiseDev.Zones.Border.onServerCommand)
Events.OnServerCommand.Add(ParadiseDev.Zones.Border.onServerCommand)
Events.OnPlayerUpdate.Remove(ParadiseDev.Zones.Border.onPlayerUpdate)
Events.OnPlayerUpdate.Add(ParadiseDev.Zones.Border.onPlayerUpdate)
