-- High-resolution local border using only server-issued zone state. This
-- processes one local player and a spatial bucket near the 2-tile border;
-- it is not a global OnTick scan.
PZZoneEngineClientBorder = PZZoneEngineClientBorder or {}
local B = PZZoneEngineClientBorder
B.CELL_SIZE = 100
B.zones = B.zones or {}
B.cellIndex = B.cellIndex or {}
B.borderWidth = B.borderWidth or 2
B.vehicleMode = B.vehicleMode or "observe"
B.cagedZoneId = B.cagedZoneId or nil
B.noticeZoneId = B.noticeZoneId or nil
B.noticeAt = B.noticeAt or 0

local function cellCoord(value)
    return math.floor(value / B.CELL_SIZE)
end

local function cellKey(cx, cy)
    return tostring(cx) .. ":" .. tostring(cy)
end

local function area(region)
    return (region.xMax - region.xMin) * (region.yMax - region.yMin)
end

local function onLevel(zone, z)
    return zone.zMode == "all" or (z >= zone.zMin and z < zone.zMaxExclusive)
end

local function contains(region, x, y, padding)
    return x >= region.xMin - padding and x < region.xMax + padding and
        y >= region.yMin - padding and y < region.yMax + padding
end

function B.rebuildIndex()
    B.cellIndex = {}
    for _, zone in ipairs(B.zones) do
        for _, region in ipairs(zone.regions) do
            local minCX = cellCoord(region.xMin - B.borderWidth)
            local maxCX = cellCoord(region.xMax + B.borderWidth - 0.001)
            local minCY = cellCoord(region.yMin - B.borderWidth)
            local maxCY = cellCoord(region.yMax + B.borderWidth - 0.001)
            for cx = minCX, maxCX do
                for cy = minCY, maxCY do
                    local key = cellKey(cx, cy)
                    local bucket = B.cellIndex[key]
                    if not bucket then
                        bucket = {}
                        B.cellIndex[key] = bucket
                    end
                    bucket[#bucket + 1] = { zone = zone, region = region }
                end
            end
        end
    end
end

local function authorityAt(x, y, z, padding)
    local bucket = B.cellIndex[cellKey(cellCoord(x), cellCoord(y))]
    if not bucket then return nil, nil end
    local winner, winnerRegion
    for _, candidate in ipairs(bucket) do
        local zone, region = candidate.zone, candidate.region
        if onLevel(zone, z) and contains(region, x, y, padding) and
            (not winner or zone.priority > winner.priority or
            (zone.priority == winner.priority and area(region) < area(winnerRegion)) or
            (zone.priority == winner.priority and area(region) == area(winnerRegion) and zone.id < winner.id)) then
            winner, winnerRegion = zone, region
        end
    end
    return winner, winnerRegion
end

local function zoneById(id)
    if not id then return nil end
    for _, zone in ipairs(B.zones) do
        if zone.id == id then return zone end
    end
    return nil
end

local function zoneContains(zone, x, y, z)
    if not zone or not onLevel(zone, z) then return false end
    for _, region in ipairs(zone.regions or {}) do
        if contains(region, x, y, 0) then return true end
    end
    return false
end

local function nearestRegionCenter(zone, x, y)
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

local function inBoundaryBand(region, x, y, width)
    if not region or not contains(region, x, y, width) then return false end
    if not contains(region, x, y, 0) then return true end
    local edgeDistance = math.min(x - region.xMin, region.xMax - x, y - region.yMin, region.yMax - y)
    return edgeDistance <= width
end
-- Shared query seam for later ParadiseZ behavior modules. These queries use
-- the same server-published spatial cache and priority rules as rebound.
function B.getAuthorityAt(x, y, z, padding)
    return authorityAt(x, y, z, padding or 0)
end

function B.getZoneFor(player)
    player = player or getPlayer()
    if not player then return nil, nil end
    local vehicle = player:getVehicle()
    local x, y = player:getX(), player:getY()
    if vehicle then x, y = vehicle:getX(), vehicle:getY() end
    return authorityAt(x, y, player:getZ(), vehicle and 2.0 or 0)
end

function B.hasFeatureAt(x, y, z, feature)
    local zone = authorityAt(x, y, z, 0)
    return zone ~= nil and zone.features ~= nil and zone.features[feature] == true
end

function B.localPlayerHasFeature(feature)
    local zone = B.getZoneFor(getPlayer())
    return zone ~= nil and zone.features ~= nil and zone.features[feature] == true
end

local function nearestOutside(region, x, y, padding)
    local left, right = region.xMin - padding, region.xMax + padding
    local top, bottom = region.yMin - padding, region.yMax + padding
    local west, east = x - left, right - x
    local north, south = y - top, bottom - y
    if west <= east and west <= north and west <= south then return left - 0.05, y end
    if east <= north and east <= south then return right + 0.05, y end
    if north <= south then return x, top - 0.05 end
    return x, bottom + 0.05
end

function B.onPlayerUpdate(player)
    if not player or player ~= getPlayer() or not player:isAlive() then return end
    local vehicle = player:getVehicle()
    local x, y = player:getX(), player:getY()
    if vehicle then x, y = vehicle:getX(), vehicle:getY() end

    local cageZone = zoneById(B.cagedZoneId)
    if cageZone and (not cageZone.features or not cageZone.features.isCage) then cageZone = nil end
    if cageZone and not zoneContains(cageZone, x, y, player:getZ()) then
        -- The server owns cage and vehicle rebound movement.  The client keeps
        -- this cached state only for immediate border feedback.
        return
    end

    local padding = vehicle and 2.0 or 0
    local zone, region = authorityAt(x, y, player:getZ(), padding)
    local noticeZone, noticeRegion = authorityAt(x, y, player:getZ(), padding + B.borderWidth)
    if noticeZone and not noticeZone.allowed and inBoundaryBand(noticeRegion, x, y, padding + B.borderWidth) then
        local now = getTimestampMs()
        if B.noticeZoneId ~= noticeZone.id or now - B.noticeAt >= 1800 then
            player:setHaloNote("You cannot enter this zone", 255, 90, 60, 160.0)
            B.noticeZoneId = noticeZone.id
            B.noticeAt = now
        end
    elseif B.noticeZoneId then
        B.noticeZoneId = nil
    end
    if not zone or zone.allowed then return end
end
Events.OnServerCommand.Add(function(module, command, args)
    if module ~= "PZZoneEngine" or command ~= "boundaryState" or not args then return end
    B.zones = args.zones or {}
    B.borderWidth = tonumber(args.borderWidth) or 2
    B.vehicleMode = args.vehicleMode or "observe"
    B.cagedZoneId = args.cagedZoneId
    B.rebuildIndex()
end)

Events.OnPlayerUpdate.Add(B.onPlayerUpdate)
