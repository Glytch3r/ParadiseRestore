ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.Engine = ParadiseDev.Zones.Engine or {}


ParadiseDev.Zones.Engine.CELL_SIZE = 100
ParadiseDev.Zones.Engine.zones = ParadiseDev.Zones.Engine.zones or {}
ParadiseDev.Zones.Engine.cellIndex = ParadiseDev.Zones.Engine.cellIndex or {}
ParadiseDev.Zones.Engine.profiles = ParadiseDev.Zones.Engine.profiles or {}
ParadiseDev.Zones.Engine.lastValid = ParadiseDev.Zones.Engine.lastValid or {}
ParadiseDev.Zones.Engine.eventLog = ParadiseDev.Zones.Engine.eventLog or {}
ParadiseDev.Zones.Engine.cageAssignments = ParadiseDev.Zones.Engine.cageAssignments or {}

ParadiseDev.Zones.Engine.BORDER_WIDTH = 2

ParadiseDev.Zones.Engine.FEATURE_KEYS = {
    "isKos", "isPvE", "isSafe", "isBlocked", "isRad", "isHunt",
    "isBlaze", "isFrost", "isBomb", "isMine", "isNoCamp", "isNoFire",
    "isCage", "isParty", "isRally", "isSpecial", "isTrade", "isSprint",
}

ParadiseDev.Zones.Engine.featureKeySet = {}
for _, key in ipairs(ParadiseDev.Zones.Engine.FEATURE_KEYS) do ParadiseDev.Zones.Engine.featureKeySet[key] = true end

ParadiseDev.Zones.Engine.vehicleMode = ParadiseDev.Zones.Engine.vehicleMode or "rebound"

function ParadiseDev.Zones.Engine.userName(pl)
    return pl and pl:getUsername() or nil
end

function ParadiseDev.Zones.Engine.playerCageKey(pl)
    if ParadiseDev and ParadiseDev.Cage and ParadiseDev.Cage.getKey then
        return ParadiseDev.Cage.getKey(pl)
    end
    if ParadiseDev and ParadiseDev.Cage and ParadiseDev.Cage.getSteamId then
        return ParadiseDev.Cage.getSteamId(pl)
    end
    return nil
end

function ParadiseDev.Zones.Engine.playerSteamId(pl)
    return ParadiseDev.Zones.Engine.playerCageKey(pl)
end

function ParadiseDev.Zones.Engine.cellCoord(value)
    return math.floor(value / ParadiseDev.Zones.Engine.CELL_SIZE)
end

function ParadiseDev.Zones.Engine.cellKey(cx, cy)
    return tostring(cx) .. ":" .. tostring(cy)
end

function ParadiseDev.Zones.Engine.copyTags(tags)
    local result = {}
    for tag, value in pairs(tags or {}) do
        if value == true then result[tag] = true end
    end
    return result
end

function ParadiseDev.Zones.Engine.copyFeatures(features)
    local result = {}
    for _, key in ipairs(ParadiseDev.Zones.Engine.FEATURE_KEYS) do
        result[key] = features and features[key] == true or false
    end
    return result
end

function ParadiseDev.Zones.Engine.setZoneFeature(id, key, enabled)
    local zone = ParadiseDev.Zones.Engine.zones[id]
    if not zone then return false, "zone not found" end
    if not ParadiseDev.Zones.Engine.featureKeySet[key] then return false, "unknown zone feature" end
    zone.features = zone.features or ParadiseDev.Zones.Engine.copyFeatures(nil)
    zone.features[key] = enabled == true
    if key == "isCage" and enabled ~= true then
        for steamId, cageId in pairs(ParadiseDev.Zones.Engine.cageAssignments) do
            if cageId == id then ParadiseDev.Zones.Engine.cageAssignments[steamId] = nil end
        end
    end
    return true
end

function ParadiseDev.Zones.Engine.area(region)
    return (region.xMax - region.xMin) * (region.yMax - region.yMin)
end

function ParadiseDev.Zones.Engine.log(kind, pl, zone, detail)
    local entry = {
        kind = kind,
        user = ParadiseDev.Zones.Engine.userName(pl),
        zone = zone and zone.id or nil,
        detail = detail,
    }
    ParadiseDev.Zones.Engine.eventLog[#ParadiseDev.Zones.Engine.eventLog + 1] = entry
    if #ParadiseDev.Zones.Engine.eventLog > 100 then table.remove(ParadiseDev.Zones.Engine.eventLog, 1) end
    print("[PZZoneEngine] " .. tostring(kind) .. " user=" .. tostring(entry.user) ..
        " zone=" .. tostring(entry.zone) .. " " .. tostring(detail or ""))
end

function ParadiseDev.Zones.Engine.clear()
    ParadiseDev.Zones.Engine.zones = {}
    ParadiseDev.Zones.Engine.cellIndex = {}
    ParadiseDev.Zones.Engine.lastValid = {}
    ParadiseDev.Zones.Engine.eventLog = {}
    ParadiseDev.Zones.Engine.cageAssignments = {}
end

function ParadiseDev.Zones.Engine.rebuildIndex()
    ParadiseDev.Zones.Engine.cellIndex = {}
    for id, zone in pairs(ParadiseDev.Zones.Engine.zones) do
        for _, region in ipairs(zone.regions) do
            local minCX, maxCX = ParadiseDev.Zones.Engine.cellCoord(region.xMin), ParadiseDev.Zones.Engine.cellCoord(region.xMax - 0.001)
            local minCY, maxCY = ParadiseDev.Zones.Engine.cellCoord(region.yMin), ParadiseDev.Zones.Engine.cellCoord(region.yMax - 0.001)
            for cx = minCX, maxCX do
                for cy = minCY, maxCY do
                    local key = ParadiseDev.Zones.Engine.cellKey(cx, cy)
                    local bucket = ParadiseDev.Zones.Engine.cellIndex[key]
                    if not bucket then
                        bucket = {}
                        ParadiseDev.Zones.Engine.cellIndex[key] = bucket
                    end
                    bucket[id] = true
                end
            end
        end
    end
end

function ParadiseDev.Zones.Engine.addRegion(id, x1, y1, x2, y2, options)
    options = options or {}
    local xMin, xMax = math.min(x1, x2), math.max(x1, x2)
    local yMin, yMax = math.min(y1, y2), math.max(y1, y2)
    if xMin == xMax or yMin == yMax then return nil, "region has no area" end

    local zone = ParadiseDev.Zones.Engine.zones[id]
    if not zone then
        zone = {
            id = id,
            name = options.name or id,
            priority = tonumber(options.priority) or 0,
            zMode = options.zMode or "all",
            zMin = tonumber(options.zMin) or 0,
            zMaxExclusive = tonumber(options.zMaxExclusive) or 1,
            policy = options.policy or { denyTags = {}, requireAnyTags = {} },
            features = ParadiseDev.Zones.Engine.copyFeatures(options.features),
            regions = {},
        }
        ParadiseDev.Zones.Engine.zones[id] = zone
    end

    zone.regions[#zone.regions + 1] = {
        xMin = xMin,
        yMin = yMin,
        xMax = xMax + 1,
        yMax = yMax + 1,
    }
    ParadiseDev.Zones.Engine.rebuildIndex()
    return zone
end

function ParadiseDev.Zones.Engine.updateZone(id, options)
    local zone = ParadiseDev.Zones.Engine.zones[id]
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
    if options.features ~= nil then zone.features = ParadiseDev.Zones.Engine.copyFeatures(options.features) end
    return true
end

function ParadiseDev.Zones.Engine.updateRegion(id, regionIndex, x1, y1, x2, y2)
    local zone = ParadiseDev.Zones.Engine.zones[id]
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
    ParadiseDev.Zones.Engine.rebuildIndex()
    return true
end
function ParadiseDev.Zones.Engine.removeRegion(id, regionIndex)
    local zone = ParadiseDev.Zones.Engine.zones[id]
    regionIndex = tonumber(regionIndex)
    if not zone or not regionIndex or not zone.regions[regionIndex] then
        return false, "segment not found"
    end
    table.remove(zone.regions, regionIndex)
    if #zone.regions == 0 then
        ParadiseDev.Zones.Engine.zones[id] = nil
        for steamId, cageId in pairs(ParadiseDev.Zones.Engine.cageAssignments) do
            if cageId == id then ParadiseDev.Zones.Engine.cageAssignments[steamId] = nil end
        end
    end
    ParadiseDev.Zones.Engine.rebuildIndex()
    return true
end

function ParadiseDev.Zones.Engine.removeZone(id)
    if not ParadiseDev.Zones.Engine.zones[id] then return false, "zone not found" end
    ParadiseDev.Zones.Engine.zones[id] = nil
    for steamId, cageId in pairs(ParadiseDev.Zones.Engine.cageAssignments) do
        if cageId == id then ParadiseDev.Zones.Engine.cageAssignments[steamId] = nil end
    end
    ParadiseDev.Zones.Engine.rebuildIndex()
    return true
end
function ParadiseDev.Zones.Engine.setProfile(username, tags)
    if not username or username == "" then return false end
    ParadiseDev.Zones.Engine.profiles[username] = { tags = ParadiseDev.Zones.Engine.copyTags(tags) }
    return true
end

function ParadiseDev.Zones.Engine.getProfile(pl)
    local profile = ParadiseDev.Zones.Engine.profiles[ParadiseDev.Zones.Engine.userName(pl)]
    return profile or { tags = {} }
end

function ParadiseDev.Zones.Engine.isOnZoneLevel(zone, z)
    return zone.zMode == "all" or (z >= zone.zMin and z < zone.zMaxExclusive)
end

function ParadiseDev.Zones.Engine.regionContains(region, x, y, padding)
    padding = padding or 0
    return x >= region.xMin - padding and x < region.xMax + padding and
        y >= region.yMin - padding and y < region.yMax + padding
end

function ParadiseDev.Zones.Engine.zoneContains(zone, x, y, z, padding)
    if not ParadiseDev.Zones.Engine.isOnZoneLevel(zone, z) then return false end
    for _, region in ipairs(zone.regions) do
        if ParadiseDev.Zones.Engine.regionContains(region, x, y, padding) then return true, region end
    end
    return false, nil
end

function ParadiseDev.Zones.Engine.getCandidateZones(x, y, padding)
    padding = padding or 0
    local result, seen = {}, {}
    local minCX, maxCX = ParadiseDev.Zones.Engine.cellCoord(x - padding), ParadiseDev.Zones.Engine.cellCoord(x + padding)
    local minCY, maxCY = ParadiseDev.Zones.Engine.cellCoord(y - padding), ParadiseDev.Zones.Engine.cellCoord(y + padding)
    for cx = minCX, maxCX do
        for cy = minCY, maxCY do
            local bucket = ParadiseDev.Zones.Engine.cellIndex[ParadiseDev.Zones.Engine.cellKey(cx, cy)]
            if bucket then
                for id in pairs(bucket) do
                    if not seen[id] then
                        seen[id] = true
                        result[#result + 1] = ParadiseDev.Zones.Engine.zones[id]
                    end
                end
            end
        end
    end
    return result
end

function ParadiseDev.Zones.Engine.getDeniedReason(zone, pl)
    local profile = ParadiseDev.Zones.Engine.getProfile(pl)
    local tags = profile.tags
    local features = zone.features or {}
    if features.isBlocked then return "Blocked zone" end
    if features.isKos and tags.pve then return "PvE profile cannot enter a KoS zone" end
    if features.isHunt and not tags.range_staff and not tags.can_hunt then return "Hunt authorization required" end
    for tag in pairs(zone.policy.denyTags or {}) do
        if tags[tag] then return "Player profile is denied" end
    end

    local required = zone.policy.requireAnyTags or {}
    local hasRequirement = false
    for tag in pairs(required) do
        hasRequirement = true
        if tags[tag] then return nil end
    end
    if hasRequirement then return "Required zone authorization missing" end
    return nil
end

function ParadiseDev.Zones.Engine.adminBypassEnabled()
    return SandboxVars and SandboxVars.ParadiseZ and SandboxVars.ParadiseZ.AdminBypassZoneRestrictions == true
end

function ParadiseDev.Zones.Engine.isAllowed(zone, pl)
    local deniedReason = ParadiseDev.Zones.Engine.getDeniedReason(zone, pl)
    if not deniedReason then return true end
    return ParadiseDev.isAdm(pl) and ParadiseDev.Zones.Engine.adminBypassEnabled() and zone.policy.adminBypass ~= false
end

function ParadiseDev.Zones.Engine.syncBoundaryState(pl)
    if not pl then return end
    local zones = {}
    for _, zone in pairs(ParadiseDev.Zones.Engine.zones) do
        local regions = {}
        for _, region in ipairs(zone.regions) do
            regions[#regions + 1] = {
                xMin = region.xMin, yMin = region.yMin,
                xMax = region.xMax, yMax = region.yMax,
            }
        end
        local deniedReason = ParadiseDev.Zones.Engine.getDeniedReason(zone, pl)
        zones[#zones + 1] = {
            id = zone.id,
            name = zone.name,
            priority = zone.priority,
            zMode = zone.zMode,
            zMin = zone.zMin,
            zMaxExclusive = zone.zMaxExclusive,
            allowed = ParadiseDev.Zones.Engine.isAllowed(zone, pl),
            restricted = deniedReason ~= nil,
            deniedReason = deniedReason,
            features = ParadiseDev.Zones.Engine.copyFeatures(zone.features),
            regions = regions,
        }
    end
    sendServerCommand(pl, "PZZoneEngine", "boundaryState", {
        borderWidth = ParadiseDev.Zones.Engine.BORDER_WIDTH,
        vehicleMode = ParadiseDev.Zones.Engine.vehicleMode,
        cagedZoneId = ParadiseDev.Zones.Engine.cageAssignments[ParadiseDev.Zones.Engine.playerSteamId(pl)],
        zones = zones,
    })
end
function ParadiseDev.Zones.Engine.syncAllBoundaryStates()
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players then return end
    for index = 0, players:size() - 1 do
        ParadiseDev.Zones.Engine.syncBoundaryState(players:get(index))
    end
end

function ParadiseDev.Zones.Engine.getAuthority(x, y, z, padding)
    local winner, winnerRegion
    for _, zone in ipairs(ParadiseDev.Zones.Engine.getCandidateZones(x, y, padding)) do
        local inside, region = ParadiseDev.Zones.Engine.zoneContains(zone, x, y, z, padding)
        if inside then
            if not winner or zone.priority > winner.priority or
                (zone.priority == winner.priority and ParadiseDev.Zones.Engine.area(region) < ParadiseDev.Zones.Engine.area(winnerRegion)) or
                (zone.priority == winner.priority and ParadiseDev.Zones.Engine.area(region) == ParadiseDev.Zones.Engine.area(winnerRegion) and zone.id < winner.id) then
                winner, winnerRegion = zone, region
            end
        end
    end
    return winner, winnerRegion
end

function ParadiseDev.Zones.Engine.nearestOutside(region, x, y, padding)
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

function ParadiseDev.Zones.Engine.regionCenter(region)
    return (region.xMin + region.xMax - 1) / 2, (region.yMin + region.yMax - 1) / 2
end

function ParadiseDev.Zones.Engine.nearestRegion(zone, x, y)
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

function ParadiseDev.Zones.Engine.nearestCageZone(pl)
    if not pl then return nil end
    local winner, winnerDistance
    for _, zone in pairs(ParadiseDev.Zones.Engine.zones) do
        if zone.features and zone.features.isCage then
            local _, distance = ParadiseDev.Zones.Engine.nearestRegion(zone, pl:getX(), pl:getY())
            if distance and (not winner or distance < winnerDistance) then
                winner, winnerDistance = zone, distance
            end
        end
    end
    return winner
end

function ParadiseDev.Zones.Engine.teleportPlayer(pl, x, y, z)
    return ParadiseDev and ParadiseDev.TP and ParadiseDev.TP.teleportPlayer(pl, x, y, z) or false
end

function ParadiseDev.Zones.Engine.reboundPlayer(pl, zone, region, x, y, z)
    local last = ParadiseDev.Zones.Engine.lastValid[ParadiseDev.Zones.Engine.userName(pl)]
    if last and not ParadiseDev.Zones.Engine.zoneContains(zone, last.x, last.y, last.z) then
        ParadiseDev.Zones.Engine.teleportPlayer(pl, last.x, last.y, last.z)
        ParadiseDev.Zones.Engine.log("rebound-last-valid", pl, zone)
        return
    end
    local outX, outY = ParadiseDev.Zones.Engine.nearestOutside(region, x, y, 0)
    ParadiseDev.Zones.Engine.teleportPlayer(pl, outX, outY, z)
    ParadiseDev.Zones.Engine.log("rebound-edge", pl, zone)
end

function ParadiseDev.Zones.Engine.reboundVehicle(vehicle, x, y, outX, outY)
    return ParadiseDev and ParadiseDev.TP and ParadiseDev.TP.reboundVehicle(vehicle, x, y, outX, outY) or false
end

function ParadiseDev.Zones.Engine.forcePassengerOut(pl, x, y, z)
    return ParadiseDev and ParadiseDev.TP and ParadiseDev.TP.exitVehicleAndTeleport(pl, x, y, z, true) or false
end

function ParadiseDev.Zones.Engine.forceVehicleExit(pl, x, y, z)
    return ParadiseDev and ParadiseDev.TP and ParadiseDev.TP.exitVehicleAndTeleport(pl, x, y, z, false) or false
end

function ParadiseDev.Zones.Engine.captureCageReturn(pl)
    if not pl then return end
    local modData = pl:getModData()
    if modData.ParadiseDevCageReturn then return end
    modData.ParadiseDevCageReturn = {
        x = pl:getX(),
        y = pl:getY(),
        z = pl:getZ(),
    }
end

function ParadiseDev.Zones.Engine.restoreCageReturn(pl)
    if not pl then return false end
    local modData = pl:getModData()
    local returnPoint = modData.ParadiseDevCageReturn
    modData.ParadiseDevCageReturn = nil
    if not returnPoint then return false end
    return ParadiseDev.Zones.Engine.teleportPlayer(pl, returnPoint.x, returnPoint.y, returnPoint.z)
end

function ParadiseDev.Zones.Engine.assignCage(pl, zone)
    if not pl or not zone or not zone.features or not zone.features.isCage then
        return false, "A valid Cage zone is required."
    end
    local steamId = ParadiseDev.Zones.Engine.playerSteamId(pl)
    if not steamId then return false, "The target player has no Steam ID." end
    local region = ParadiseDev.Zones.Engine.nearestRegion(zone, pl:getX(), pl:getY())
    if not region then return false, "The Cage zone has no segments." end
    local x, y = ParadiseDev.Zones.Engine.regionCenter(region)
    local z = zone.zMode == "floor" and zone.zMin or pl:getZ()
    ParadiseDev.Zones.Engine.cageAssignments[steamId] = zone.id
    ParadiseDev.Zones.Engine.lastValid[ParadiseDev.Zones.Engine.userName(pl)] = nil
    ParadiseDev.Zones.Engine.forceVehicleExit(pl, x, y, z)
    ParadiseDev.Zones.Engine.syncBoundaryState(pl)
    ParadiseDev.Zones.Engine.log("caged", pl, zone)
    return true
end

function ParadiseDev.Zones.Engine.releaseCage(pl)
    local steamId = ParadiseDev.Zones.Engine.playerSteamId(pl)
    if not steamId or not ParadiseDev.Zones.Engine.cageAssignments[steamId] then return false end
    local zone = ParadiseDev.Zones.Engine.zones[ParadiseDev.Zones.Engine.cageAssignments[steamId]]
    ParadiseDev.Zones.Engine.cageAssignments[steamId] = nil
    ParadiseDev.Zones.Engine.lastValid[ParadiseDev.Zones.Engine.userName(pl)] = nil
    ParadiseDev.Zones.Engine.syncBoundaryState(pl)
    ParadiseDev.Zones.Engine.log("uncaged", pl, zone)
    return true
end

function ParadiseDev.Zones.Engine.enforceCage(pl, zone, x, y, z)
    local inside = ParadiseDev.Zones.Engine.zoneContains(zone, x, y, z, 0)
    if inside then
        ParadiseDev.Zones.Engine.lastValid[ParadiseDev.Zones.Engine.userName(pl)] = { x = x, y = y, z = z }
        return true
    end
    local region = ParadiseDev.Zones.Engine.nearestRegion(zone, x, y)
    if not region then return false end
    local cageX, cageY = ParadiseDev.Zones.Engine.regionCenter(region)
    local cageZ = zone.zMode == "floor" and zone.zMin or z
    ParadiseDev.Zones.Engine.forceVehicleExit(pl, cageX, cageY, cageZ)
    ParadiseDev.Zones.Engine.log("cage-rebound", pl, zone)
    return true
end

function ParadiseDev.Zones.Engine.onPlayerMove(pl)
    if not pl or not pl:isAlive() then return end
    if ParadiseDev and ParadiseDev.Cage then ParadiseDev.Cage.syncPlayer(pl) end
    local vehicle = pl:getVehicle()
    local x, y = pl:getX(), pl:getY()
    if vehicle then x, y = vehicle:getX(), vehicle:getY() end
    local z = pl:getZ()

    local steamId = ParadiseDev.Zones.Engine.playerSteamId(pl)
    local cageId = steamId and ParadiseDev.Zones.Engine.cageAssignments[steamId] or nil
    local isCaged = ParadiseDev and ParadiseDev.Cage and ParadiseDev.Cage.isCaged(pl)
    if isCaged and not cageId then
        local nearestCage = ParadiseDev.Zones.Engine.nearestCageZone(pl)
        if nearestCage then
            ParadiseDev.Zones.Engine.captureCageReturn(pl)
            ParadiseDev.Zones.Engine.assignCage(pl, nearestCage)
            return
        end
    end
    if cageId and ParadiseDev.Cage.isCaged(pl) then
        local cageZone = ParadiseDev.Zones.Engine.zones[cageId]
        if cageZone and cageZone.features and cageZone.features.isCage then
            ParadiseDev.Zones.Engine.enforceCage(pl, cageZone, x, y, z)
            return
        end
        ParadiseDev.Zones.Engine.cageAssignments[steamId] = nil
        ParadiseDev.Zones.Engine.syncBoundaryState(pl)
    end

    local zone, region = ParadiseDev.Zones.Engine.getAuthority(x, y, z, vehicle and 2.0 or 0)
    if not zone or ParadiseDev.Zones.Engine.isAllowed(zone, pl) then
        ParadiseDev.Zones.Engine.lastValid[ParadiseDev.Zones.Engine.userName(pl)] = { x = x, y = y, z = z }
        return
    end

    if not vehicle then
        ParadiseDev.Zones.Engine.reboundPlayer(pl, zone, region, x, y, z)
        return
    end

    local driver = vehicle:getCharacter(0)
    if driver ~= pl then
        local outX, outY = ParadiseDev.Zones.Engine.nearestOutside(region, x, y, 2.0)
        if ParadiseDev.Zones.Engine.forcePassengerOut(pl, outX, outY, z) then
            ParadiseDev.Zones.Engine.log("passenger-ejected", pl, zone)
        end
        return
    end

    if ParadiseDev.Zones.Engine.vehicleMode == "rebound" then
        local outX, outY = ParadiseDev.Zones.Engine.nearestOutside(region, x, y, 2.0)
        ParadiseDev.Zones.Engine.reboundVehicle(vehicle, x, y, outX, outY)
        ParadiseDev.Zones.Engine.log("vehicle-rebounded", pl, zone)
    else
        ParadiseDev.Zones.Engine.log("vehicle-denied-observe", pl, zone, "Set vehicleMode=rebound to test server vehicle movement")
    end
end

Events.OnPlayerMove.Remove(ParadiseDev.Zones.Engine.onPlayerMove)
Events.OnPlayerMove.Add(ParadiseDev.Zones.Engine.onPlayerMove)

function ParadiseDev.Zones.Engine.onClientCommand(module, command, pl)
    if module == "PZZoneEngine" and command == "requestBoundaryState" then
        ParadiseDev.Zones.Engine.syncBoundaryState(pl)
    end
end

Events.OnClientCommand.Remove(ParadiseDev.Zones.Engine.onClientCommand)
Events.OnClientCommand.Add(ParadiseDev.Zones.Engine.onClientCommand)
