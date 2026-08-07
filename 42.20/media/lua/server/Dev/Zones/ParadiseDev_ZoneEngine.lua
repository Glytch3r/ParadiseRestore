ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.Engine = ParadiseDev.Zones.Engine or {}
local E = ParadiseDev.Zones.Engine

E.CELL_SIZE = 100
E.zones = E.zones or {}
E.cellIndex = E.cellIndex or {}
E.profiles = E.profiles or {}
E.lastValid = E.lastValid or {}
E.eventLog = E.eventLog or {}
E.cageAssignments = E.cageAssignments or {}

E.BORDER_WIDTH = 2

E.FEATURE_KEYS = {
    "isKos", "isPvE", "isSafe", "isBlocked", "isRad", "isHunt",
    "isBlaze", "isFrost", "isBomb", "isMine", "isNoCamp", "isNoFire",
    "isCage", "isParty", "isRally", "isSpecial", "isTrade", "isSprint",
}

local FEATURE_KEY_SET = {}
for _, key in ipairs(E.FEATURE_KEYS) do FEATURE_KEY_SET[key] = true end

E.vehicleMode = E.vehicleMode or "observe"

function E.userName(player)
    return player and player:getUsername() or nil
end

function E.playerSteamId(player)
    if ParadiseDev and ParadiseDev.Cage and ParadiseDev.Cage.getSteamId then
        return ParadiseDev.Cage.getSteamId(player)
    end
    return nil
end

function E.cellCoord(value)
    return math.floor(value / E.CELL_SIZE)
end

function E.cellKey(cx, cy)
    return tostring(cx) .. ":" .. tostring(cy)
end

function E.copyTags(tags)
    local result = {}
    for tag, value in pairs(tags or {}) do
        if value == true then result[tag] = true end
    end
    return result
end

function E.copyFeatures(features)
    local result = {}
    for _, key in ipairs(E.FEATURE_KEYS) do
        result[key] = features and features[key] == true or false
    end
    return result
end

function E.setZoneFeature(id, key, enabled)
    local zone = E.zones[id]
    if not zone then return false, "zone not found" end
    if not FEATURE_KEY_SET[key] then return false, "unknown zone feature" end
    zone.features = zone.features or E.copyFeatures(nil)
    zone.features[key] = enabled == true
    if key == "isCage" and enabled ~= true then
        for steamId, cageId in pairs(E.cageAssignments) do
            if cageId == id then E.cageAssignments[steamId] = nil end
        end
    end
    return true
end

function E.area(region)
    return (region.xMax - region.xMin) * (region.yMax - region.yMin)
end

function E.log(kind, player, zone, detail)
    local entry = {
        kind = kind,
        user = E.userName(player),
        zone = zone and zone.id or nil,
        detail = detail,
    }
    E.eventLog[#E.eventLog + 1] = entry
    if #E.eventLog > 100 then table.remove(E.eventLog, 1) end
    print("[PZZoneEngine] " .. tostring(kind) .. " user=" .. tostring(entry.user) ..
        " zone=" .. tostring(entry.zone) .. " " .. tostring(detail or ""))
end

function E.clear()
    E.zones = {}
    E.cellIndex = {}
    E.lastValid = {}
    E.eventLog = {}
    E.cageAssignments = {}
end

function E.rebuildIndex()
    E.cellIndex = {}
    for id, zone in pairs(E.zones) do
        for _, region in ipairs(zone.regions) do
            local minCX, maxCX = E.cellCoord(region.xMin), E.cellCoord(region.xMax - 0.001)
            local minCY, maxCY = E.cellCoord(region.yMin), E.cellCoord(region.yMax - 0.001)
            for cx = minCX, maxCX do
                for cy = minCY, maxCY do
                    local key = E.cellKey(cx, cy)
                    local bucket = E.cellIndex[key]
                    if not bucket then
                        bucket = {}
                        E.cellIndex[key] = bucket
                    end
                    bucket[id] = true
                end
            end
        end
    end
end

function E.addRegion(id, x1, y1, x2, y2, options)
    options = options or {}
    local xMin, xMax = math.min(x1, x2), math.max(x1, x2)
    local yMin, yMax = math.min(y1, y2), math.max(y1, y2)
    if xMin == xMax or yMin == yMax then return nil, "region has no area" end

    local zone = E.zones[id]
    if not zone then
        zone = {
            id = id,
            name = options.name or id,
            priority = tonumber(options.priority) or 0,
            zMode = options.zMode or "all",
            zMin = tonumber(options.zMin) or 0,
            zMaxExclusive = tonumber(options.zMaxExclusive) or 1,
            policy = options.policy or { denyTags = {}, requireAnyTags = {} },
            features = E.copyFeatures(options.features),
            regions = {},
        }
        E.zones[id] = zone
    end

    zone.regions[#zone.regions + 1] = {
        xMin = xMin,
        yMin = yMin,
        xMax = xMax + 1,
        yMax = yMax + 1,
    }
    E.rebuildIndex()
    return zone
end

function E.updateZone(id, options)
    local zone = E.zones[id]
    if not zone then return false, "zone not found" end
    options = options or {}
    if options.name ~= nil then zone.name = tostring(options.name) end
    if options.priority ~= nil then zone.priority = tonumber(options.priority) or zone.priority end
    if options.zMode ~= nil then zone.zMode = options.zMode == "floor" and "floor" or "all" end
    if options.zMin ~= nil then zone.zMin = tonumber(options.zMin) or zone.zMin end
    if options.zMaxExclusive ~= nil then
        zone.zMaxExclusive = tonumber(options.zMaxExclusive) or zone.zMaxExclusive
    end
    if options.policy ~= nil then zone.policy = options.policy end
    if options.features ~= nil then zone.features = E.copyFeatures(options.features) end
    return true
end

function E.updateRegion(id, regionIndex, x1, y1, x2, y2)
    local zone = E.zones[id]
    regionIndex = tonumber(regionIndex)
    local region = zone and zone.regions[regionIndex] or nil
    x1, y1, x2, y2 = tonumber(x1), tonumber(y1), tonumber(x2), tonumber(y2)
    if not region then return false, "segment not found" end
    if not x1 or not y1 or not x2 or not y2 then return false, "invalid segment coordinates" end
    local xMin, xMax = math.min(x1, x2), math.max(x1, x2)
    local yMin, yMax = math.min(y1, y2), math.max(y1, y2)
    if xMin == xMax or yMin == yMax then return false, "segment has no area" end
    region.xMin, region.yMin = xMin, yMin
    region.xMax, region.yMax = xMax + 1, yMax + 1
    E.rebuildIndex()
    return true
end
function E.removeRegion(id, regionIndex)
    local zone = E.zones[id]
    regionIndex = tonumber(regionIndex)
    if not zone or not regionIndex or not zone.regions[regionIndex] then
        return false, "segment not found"
    end
    table.remove(zone.regions, regionIndex)
    if #zone.regions == 0 then
        E.zones[id] = nil
        for steamId, cageId in pairs(E.cageAssignments) do
            if cageId == id then E.cageAssignments[steamId] = nil end
        end
    end
    E.rebuildIndex()
    return true
end

function E.removeZone(id)
    if not E.zones[id] then return false, "zone not found" end
    E.zones[id] = nil
    for steamId, cageId in pairs(E.cageAssignments) do
        if cageId == id then E.cageAssignments[steamId] = nil end
    end
    E.rebuildIndex()
    return true
end
function E.setProfile(username, tags)
    if not username or username == "" then return false end
    E.profiles[username] = { tags = E.copyTags(tags) }
    return true
end

function E.getProfile(player)
    local profile = E.profiles[E.userName(player)]
    return profile or { tags = {} }
end

function E.isAdmin(player)
    return player and player:getAccessLevel() == "admin"
end

function E.isOnZoneLevel(zone, z)
    return zone.zMode == "all" or (z >= zone.zMin and z < zone.zMaxExclusive)
end

function E.regionContains(region, x, y, padding)
    padding = padding or 0
    return x >= region.xMin - padding and x < region.xMax + padding and
        y >= region.yMin - padding and y < region.yMax + padding
end

function E.zoneContains(zone, x, y, z, padding)
    if not E.isOnZoneLevel(zone, z) then return false end
    for _, region in ipairs(zone.regions) do
        if E.regionContains(region, x, y, padding) then return true, region end
    end
    return false, nil
end

function E.getCandidateZones(x, y, padding)
    padding = padding or 0
    local result, seen = {}, {}
    local minCX, maxCX = E.cellCoord(x - padding), E.cellCoord(x + padding)
    local minCY, maxCY = E.cellCoord(y - padding), E.cellCoord(y + padding)
    for cx = minCX, maxCX do
        for cy = minCY, maxCY do
            local bucket = E.cellIndex[E.cellKey(cx, cy)]
            if bucket then
                for id in pairs(bucket) do
                    if not seen[id] then
                        seen[id] = true
                        result[#result + 1] = E.zones[id]
                    end
                end
            end
        end
    end
    return result
end

function E.isAllowed(zone, player)
    if E.isAdmin(player) and zone.policy.adminBypass ~= false then return true end

    local profile = E.getProfile(player)
    local tags = profile.tags
    local features = zone.features or {}
    if features.isBlocked then return false end
    if features.isKos and tags.pve then return false end
    if features.isHunt and not tags.range_staff and not tags.can_hunt then return false end
    for tag in pairs(zone.policy.denyTags or {}) do
        if tags[tag] then return false end
    end

    local required = zone.policy.requireAnyTags or {}
    local hasRequirement = false
    for tag in pairs(required) do
        hasRequirement = true
        if tags[tag] then return true end
    end
    if hasRequirement then return false end
    return true
end

function E.syncBoundaryState(player)
    if not player then return end
    local zones = {}
    for _, zone in pairs(E.zones) do
        local regions = {}
        for _, region in ipairs(zone.regions) do
            regions[#regions + 1] = {
                xMin = region.xMin, yMin = region.yMin,
                xMax = region.xMax, yMax = region.yMax,
            }
        end
        zones[#zones + 1] = {
            id = zone.id,
            name = zone.name,
            priority = zone.priority,
            zMode = zone.zMode,
            zMin = zone.zMin,
            zMaxExclusive = zone.zMaxExclusive,
            allowed = E.isAllowed(zone, player),
            features = E.copyFeatures(zone.features),
            regions = regions,
        }
    end
    sendServerCommand(player, "PZZoneEngine", "boundaryState", {
        borderWidth = E.BORDER_WIDTH,
        vehicleMode = E.vehicleMode,
        cagedZoneId = E.cageAssignments[E.playerSteamId(player)],
        zones = zones,
    })
end
function E.syncAllBoundaryStates()
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players then return end
    for index = 0, players:size() - 1 do
        E.syncBoundaryState(players:get(index))
    end
end

function E.getAuthority(x, y, z, padding)
    local winner, winnerRegion
    for _, zone in ipairs(E.getCandidateZones(x, y, padding)) do
        local inside, region = E.zoneContains(zone, x, y, z, padding)
        if inside then
            if not winner or zone.priority > winner.priority or
                (zone.priority == winner.priority and E.area(region) < E.area(winnerRegion)) or
                (zone.priority == winner.priority and E.area(region) == E.area(winnerRegion) and zone.id < winner.id) then
                winner, winnerRegion = zone, region
            end
        end
    end
    return winner, winnerRegion
end

function E.nearestOutside(region, x, y, padding)
    padding = padding or 0
    local left, right = region.xMin - padding, region.xMax + padding
    local top, bottom = region.yMin - padding, region.yMax + padding
    local west, east = x - left, right - x
    local north, south = y - top, bottom - y
    if west <= east and west <= north and west <= south then return left - 0.05, y end
    if east <= north and east <= south then return right + 0.05, y end
    if north <= south then return x, top - 0.05 end
    return x, bottom + 0.05
end

function E.regionCenter(region)
    return (region.xMin + region.xMax - 1) / 2, (region.yMin + region.yMax - 1) / 2
end

function E.nearestRegion(zone, x, y)
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
    return winner, winnerDistance
end

function E.nearestCageZone(player)
    if not player then return nil end
    local winner, winnerDistance
    for _, zone in pairs(E.zones) do
        if zone.features and zone.features.isCage then
            local _, distance = E.nearestRegion(zone, player:getX(), player:getY())
            if distance and (not winner or distance < winnerDistance) then
                winner, winnerDistance = zone, distance
            end
        end
    end
    return winner
end

function E.teleportPlayer(player, x, y, z)
    return ParadiseDev and ParadiseDev.TP and ParadiseDev.TP.teleportPlayer(player, x, y, z) or false
end

function E.reboundPlayer(player, zone, region, x, y, z)
    local last = E.lastValid[E.userName(player)]
    if last and not E.zoneContains(zone, last.x, last.y, last.z) then
        E.teleportPlayer(player, last.x, last.y, last.z)
        E.log("rebound-last-valid", player, zone)
        return
    end
    local outX, outY = E.nearestOutside(region, x, y, 0)
    E.teleportPlayer(player, outX, outY, z)
    E.log("rebound-edge", player, zone)
end

function E.reboundVehicle(vehicle, x, y, outX, outY)
    return ParadiseDev and ParadiseDev.TP and ParadiseDev.TP.reboundVehicle(vehicle, x, y, outX, outY) or false
end

function E.forcePassengerOut(player, x, y, z)
    return ParadiseDev and ParadiseDev.TP and ParadiseDev.TP.exitVehicleAndTeleport(player, x, y, z, true) or false
end

function E.forceVehicleExit(player, x, y, z)
    return ParadiseDev and ParadiseDev.TP and ParadiseDev.TP.exitVehicleAndTeleport(player, x, y, z, false) or false
end

function E.captureCageReturn(player)
    if not player then return end
    local modData = player:getModData()
    if modData.ParadiseDevCageReturn then return end
    modData.ParadiseDevCageReturn = {
        x = player:getX(),
        y = player:getY(),
        z = player:getZ(),
    }
end

function E.restoreCageReturn(player)
    if not player then return false end
    local modData = player:getModData()
    local returnPoint = modData.ParadiseDevCageReturn
    modData.ParadiseDevCageReturn = nil
    if not returnPoint then return false end
    return E.teleportPlayer(player, returnPoint.x, returnPoint.y, returnPoint.z)
end

function E.assignCage(player, zone)
    if not player or not zone or not zone.features or not zone.features.isCage then
        return false, "A valid Cage zone is required."
    end
    local steamId = E.playerSteamId(player)
    if not steamId then return false, "The target player has no Steam ID." end
    local region = E.nearestRegion(zone, player:getX(), player:getY())
    if not region then return false, "The Cage zone has no segments." end
    local x, y = E.regionCenter(region)
    local z = zone.zMode == "floor" and zone.zMin or player:getZ()
    E.cageAssignments[steamId] = zone.id
    E.lastValid[E.userName(player)] = nil
    E.forceVehicleExit(player, x, y, z)
    E.syncBoundaryState(player)
    E.log("caged", player, zone)
    return true
end

function E.releaseCage(player)
    local steamId = E.playerSteamId(player)
    if not steamId or not E.cageAssignments[steamId] then return false end
    local zone = E.zones[E.cageAssignments[steamId]]
    E.cageAssignments[steamId] = nil
    E.lastValid[E.userName(player)] = nil
    E.syncBoundaryState(player)
    E.log("uncaged", player, zone)
    return true
end

function E.enforceCage(player, zone, x, y, z)
    local inside = E.zoneContains(zone, x, y, z, 0)
    if inside then
        E.lastValid[E.userName(player)] = { x = x, y = y, z = z }
        return true
    end
    local region = E.nearestRegion(zone, x, y)
    if not region then return false end
    local cageX, cageY = E.regionCenter(region)
    local cageZ = zone.zMode == "floor" and zone.zMin or z
    E.forceVehicleExit(player, cageX, cageY, cageZ)
    E.log("cage-rebound", player, zone)
    return true
end

function E.onPlayerMove(player)
    if not player or not player:isAlive() then return end
    if ParadiseDev and ParadiseDev.Cage then ParadiseDev.Cage.syncPlayer(player) end
    local vehicle = player:getVehicle()
    local x, y = player:getX(), player:getY()
    if vehicle then x, y = vehicle:getX(), vehicle:getY() end
    local z = player:getZ()

    local steamId = E.playerSteamId(player)
    local cageId = steamId and E.cageAssignments[steamId] or nil
    local isCaged = ParadiseDev and ParadiseDev.Cage and ParadiseDev.Cage.isCaged(player)
    if isCaged and not cageId then
        local nearestCage = E.nearestCageZone(player)
        if nearestCage then
            E.captureCageReturn(player)
            E.assignCage(player, nearestCage)
            return
        end
    end
    if cageId and ParadiseDev.Cage.isCaged(player) then
        local cageZone = E.zones[cageId]
        if cageZone and cageZone.features and cageZone.features.isCage then
            E.enforceCage(player, cageZone, x, y, z)
            return
        end
        E.cageAssignments[steamId] = nil
        E.syncBoundaryState(player)
    end

    local zone, region = E.getAuthority(x, y, z, vehicle and 2.0 or 0)
    if not zone or E.isAllowed(zone, player) then
        E.lastValid[E.userName(player)] = { x = x, y = y, z = z }
        return
    end

    if not vehicle then
        E.reboundPlayer(player, zone, region, x, y, z)
        return
    end

    local driver = vehicle:getCharacter(0)
    if driver ~= player then
        local outX, outY = E.nearestOutside(region, x, y, 2.0)
        if E.forcePassengerOut(player, outX, outY, z) then
            E.log("passenger-ejected", player, zone)
        end
        return
    end

    if E.vehicleMode == "rebound" then
        local outX, outY = E.nearestOutside(region, x, y, 2.0)
        E.reboundVehicle(vehicle, x, y, outX, outY)
        E.log("vehicle-rebounded", player, zone)
    else
        E.log("vehicle-denied-observe", player, zone, "Set vehicleMode=rebound to test server vehicle movement")
    end
end

Events.OnPlayerMove.Add(E.onPlayerMove)

Events.OnClientCommand.Add(function(module, command, player)
    if module == "PZZoneEngine" and command == "requestBoundaryState" then
        E.syncBoundaryState(player)
    end
end)
