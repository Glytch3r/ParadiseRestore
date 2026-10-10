require "Dev/ParadiseDev_PvEPolicy"
require "Dev/Zones/ParadiseDev_SafePlacement"
require "ParadiseProductionDiagnostics"
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
ParadiseDev.Zones.Engine.storeName = "ParadiseDev_Zones"

ParadiseDev.Zones.Engine.BORDER_WIDTH = 2

-- Boundary-only transport. Shared TP remains the admin/cage path.
local Engine = ParadiseDev.Zones.Engine
Engine.boundaryActors = setmetatable({}, { __mode = "k" })
Engine.boundarySessionOrder = Engine.boundarySessionOrder or 0
Engine.boundaryRevision = Engine.boundaryRevision or 0
Engine.zoneRevision = Engine.zoneRevision or 0
Engine.BOUNDARY_RETRY_MS = 250
Engine.BOUNDARY_ATTEMPTS = 4
Engine.BOUNDARY_REISSUE_MS = 1000

local function boundaryNow()
    return getTimestampMs()
end

-- One revision also fences the ride-specific prediction permission. Refreshing a
-- ride timestamp alone does not invalidate or resend the full zone snapshot.
function Engine.invalidateBoundaryState(state)
    Engine.boundaryRevision = Engine.boundaryRevision + 1
    state.stateRevision = Engine.boundaryRevision
    state.pending, state.episode, state.stateSent, state.recoveryAt = nil, nil, false, nil
end

function Engine.boundarySignature(pl)
    -- setProfile/zone edits call save(); reference changes also invalidate. Avoid
    -- sorting/copying every profile tag for every boundary request.
    local profile = Engine.profiles[Engine.userName(pl)]
    local context=ParadiseDev.SafePlacement.fromPlayer(pl)
    local pve = ParadiseDev.getTrait and ParadiseDev.getTrait("ParadiseDev:PvE") or "ParadiseDev:PvE"
    local signature = tostring(Engine.zoneRevision) .. "|" .. tostring(profile) .. "|" ..
        tostring(ParadiseDev.hasTrait and ParadiseDev.hasTrait(pl, pve) or false) .. "|" ..
        tostring(ParadiseRestore.isAdm(pl)) .. "|" .. tostring(Engine.adminBypassEnabled()) .. "|" ..
        tostring(Engine.cageAssignments[Engine.playerSteamId(pl)]) .. "|" ..
        tostring(ParadiseDev.Cage and ParadiseDev.Cage.isCaged(pl) or false) .. "|" ..
        tostring(context.contextId) .. "|" .. tostring(context.pveRevision) .. "|" .. tostring(context.ready)
    local vehicle = pl:getVehicle()
    local driver = vehicle and vehicle:getCharacter(0) or nil
    if driver and driver ~= pl then
        -- A passenger directive also depends on the driver's permission. Track
        -- its cheap scalar/reference inputs without recursively scanning zones.
        signature = signature .. "|driver:" .. tostring(driver) .. "|" .. tostring(driver:isAlive()) .. "|" ..
            tostring(Engine.profiles[Engine.userName(driver)]) .. "|" ..
            tostring(ParadiseDev.hasTrait and ParadiseDev.hasTrait(driver, pve) or false) .. "|" ..
            tostring(ParadiseRestore.isAdm(driver)) .. "|" ..
            tostring(Engine.cageAssignments[Engine.playerSteamId(driver)]) .. "|" ..
            tostring(ParadiseDev.Cage and ParadiseDev.Cage.isCaged(driver) or false)
    end
    return signature
end

function Engine.boundaryActor(pl)
    local state = Engine.boundaryActors[pl]
    if not state then
        Engine.boundarySessionOrder = math.max(Engine.boundarySessionOrder + 1, boundaryNow())
        state = { session = "zone:" .. tostring(Engine.boundarySessionOrder),
            sessionOrder = Engine.boundarySessionOrder, seq = 0 }
        Engine.boundaryActors[pl] = state
        -- A reconnect must not inherit a previous character's safe location.
        Engine.lastValid[Engine.userName(pl)] = nil
    end
    local signature = Engine.boundarySignature(pl)
    if state.signature ~= signature then
        state.signature = signature
        Engine.invalidateBoundaryState(state)
    end
    return state
end

-- This stamp correlates a directive to the owner's current ride. It never grants
-- zone access: vehicle/seat/driver and both permissions are read on the server.
local function boundedInteger(value, minimum)
    return type(value) == "number" and value == value and value >= minimum and
        value <= 2147483647 and value == math.floor(value)
end

function Engine.clearBoundaryRide(state)
    if state.ride then
        state.ride = nil
        Engine.invalidateBoundaryState(state)
    elseif state.pending and state.pending.args.kind == "passenger" then
        state.pending, state.episode = nil, nil
    end
end

function Engine.observeBoundaryRide(pl, state)
    local ride = state.ride
    if not ride then return nil end
    local vehicle = pl:getVehicle()
    local driver = vehicle and vehicle:getCharacter(0) or nil
    local now = boundaryNow()
    if vehicle ~= ride.vehicle or not driver or not driver:isAlive() or driver ~= ride.driver or
        vehicle:getSeat(pl) ~= ride.seat or vehicle:getId() ~= ride.vehicleId or
        driver:getOnlineID() ~= ride.driverId or now < ride.seenAt or now - ride.seenAt > 2000 then
        Engine.clearBoundaryRide(state)
        return nil
    end
    return ride
end

function Engine.receiveBoundaryRide(pl, args)
    if not pl or not pl:isAlive() then return end
    local state = Engine.boundaryActor(pl)
    local vehicle = pl:getVehicle()
    local driver = vehicle and vehicle:getCharacter(0) or nil
    if type(args) ~= "table" or not boundedInteger(args.rideToken, 1) or
        not boundedInteger(args.vehicleId, 0) or not boundedInteger(args.seat, 1) or
        not boundedInteger(args.driverId, 0) then
        Engine.observeBoundaryRide(pl, state)
        return
    end
    -- Unordered old boundary requests cannot replace a newer ride stamp.
    if state.latestRideToken and args.rideToken < state.latestRideToken then return end
    if not vehicle or not driver or driver == pl or not driver:isAlive() or
        vehicle:getId() ~= args.vehicleId or vehicle:getSeat(pl) ~= args.seat or
        driver:getOnlineID() ~= args.driverId then
        Engine.observeBoundaryRide(pl, state)
        return
    end
    local ride = Engine.observeBoundaryRide(pl, state)
    local changed = not ride or ride.token ~= args.rideToken or ride.vehicle ~= vehicle or
        ride.seat ~= args.seat or ride.driver ~= driver or ride.driverId ~= args.driverId
    if changed then Engine.invalidateBoundaryState(state) end
    state.latestRideToken = args.rideToken
    state.ride = {token=args.rideToken,vehicle=vehicle,vehicleId=args.vehicleId,
        seat=args.seat,driver=driver,driverId=args.driverId,seenAt=boundaryNow()}
end

function Engine.ensureBoundaryState(pl)
    local state = Engine.boundaryActor(pl)
    -- Never renew a prediction lease for a departed or expired ride.
    Engine.observeBoundaryRide(pl, state)
    local now = boundaryNow()
    if not state.stateSent then
        Engine.syncBoundaryState(pl)
    elseif not state.leaseAt or now < state.leaseAt or now - state.leaseAt >= 1000 then
        sendServerCommand(pl, "PZZoneEngine", "boundaryLease", {
            session = state.session, sessionOrder = state.sessionOrder, stateRevision = state.stateRevision,
        })
        state.leaseAt = now
    end
    return state
end

function Engine.clearBoundaryCorrection(pl)
    local state = Engine.boundaryActors[pl]
    if state then state.pending, state.episode = nil, nil end
end

-- Only server-observed location/permissions end an enforcement episode. No ACK
-- or coordinates supplied by a client are accepted as proof of permission.
function Engine.sendBoundaryCorrection(pl, kind, zone, vehicle, fromX, fromY, fromZ, x, y, z, apply, ride)
    local state = Engine.ensureBoundaryState(pl)
    local now = boundaryNow()
    local vehicleId = vehicle and vehicle:getId() or nil
    local episode = kind .. ":" .. tostring(zone.id) .. ":" .. tostring(vehicleId)
    if ride then episode = episode .. ":" .. tostring(ride.token) .. ":" .. tostring(ride.seat) .. ":" .. tostring(ride.driverId) end
    local pending = state.pending
    local same = pending and pending.episode == episode and
        (kind == "passenger" or (math.abs(pending.args.x - x) < 0.25 and
        math.abs(pending.args.y - y) < 0.25 and pending.args.z == z))
    -- Even movement along the same edge must not create one correction per request.
    if pending and pending.episode == episode and now >= pending.sent and
        now - pending.created < Engine.BOUNDARY_REISSUE_MS and now - pending.sent < Engine.BOUNDARY_RETRY_MS then
        return true, false
    end
    if same and now >= pending.created and now - pending.created < Engine.BOUNDARY_REISSUE_MS then
        if pending.attempts >= Engine.BOUNDARY_ATTEMPTS or now - pending.sent < Engine.BOUNDARY_RETRY_MS then
            return true, false
        end
        pending.sent, pending.attempts = now, pending.attempts + 1
        sendServerCommand(pl, "PZZoneEngine", "boundaryCorrection", pending.args)
        return true, false
    end
    if apply and not apply() then return false, false end
    state.seq = state.seq + 1
    local args = { session = state.session, sessionOrder = state.sessionOrder,
        seq = state.seq, stateRevision = state.stateRevision,
        kind = kind, zoneId = zone.id, vehicleId = vehicleId,
        fromX = fromX, fromY = fromY, fromZ = fromZ, x = x, y = y, z = z }
    if ride then args.rideToken, args.seat, args.driverId = ride.token, ride.seat, ride.driverId end
    state.pending = { episode = episode, vehicle = vehicle, args = args, created = now, sent = now, attempts = 1 }
    local first = state.episode ~= episode
    state.episode = episode
    sendServerCommand(pl, "PZZoneEngine", "boundaryCorrection", args)
    return true, first
end

-- Reuse the previously validated destination during a short unchanged denial.
-- Callers have already made a fresh server position/driver/permission decision.
-- This avoids edge searches and transforms on each coalesced request.
function Engine.retryBoundaryCorrection(pl, kind, zone, vehicle, x, y, z)
    local state = Engine.ensureBoundaryState(pl)
    local pending = state.pending
    local now = boundaryNow()
    if not pending or pending.args.kind ~= kind or pending.args.zoneId ~= zone.id or
        pending.vehicle ~= vehicle or pending.args.fromZ ~= z or now < pending.created or
        now - pending.created >= Engine.BOUNDARY_REISSUE_MS then return false end
    local dx, dy = x - pending.args.fromX, y - pending.args.fromY
    if dx * dx + dy * dy > 4 then return false end
    Engine.sendBoundaryCorrection(pl, kind, zone, vehicle, x, y, z, pending.args.x, pending.args.y, pending.args.z)
    return true
end

function Engine.boundaryOutside(pl, region, x, y, z, padding)
    if padding and padding~=0 then return nil,nil end
    local safe=ParadiseDev.SafePlacement
    local result=safe.find({x=x,y=y,z=z},safe.fromPlayer(pl),{allowFallback=false})
    if result.status=="safe" then return result.location.x,result.location.y end
    return nil,nil
end

ParadiseDev.Zones.Engine.FEATURE_KEYS = {
    "isKos", "isPvE", "isSafe", "isBlocked", "isRad", "isHunt",
    "isBlaze", "isFrost", "isBomb", "isMine", "isNoCamp", "isNoFire",
    "isCage", "isParty", "isRally", "isSpecial", "isTrade", "isSprint",
}

ParadiseDev.Zones.Engine.featureKeySet = {}
for _, key in ipairs(ParadiseDev.Zones.Engine.FEATURE_KEYS) do ParadiseDev.Zones.Engine.featureKeySet[key] = true end

ParadiseDev.Zones.Engine.vehicleMode = "rebound"

function ParadiseDev.Zones.Engine.getStore()
    local store = ModData.getOrCreate(ParadiseDev.Zones.Engine.storeName)
    store.zones = store.zones or {}
    store.profiles = store.profiles or {}
    store.vehicleMode = "rebound"
    return store
end

function ParadiseDev.Zones.Engine.save()
    Engine.zoneRevision = Engine.zoneRevision + 1
    local store = ParadiseDev.Zones.Engine.getStore()
    store.zones = ParadiseDev.Zones.Engine.zones
    store.profiles = ParadiseDev.Zones.Engine.profiles
    store.vehicleMode = ParadiseDev.Zones.Engine.vehicleMode
    ModData.transmit(ParadiseDev.Zones.Engine.storeName)
    ParadiseDev.PvEPolicy.onZonesChanged()
end

function ParadiseDev.Zones.Engine.load()
    Engine.zoneRevision = Engine.zoneRevision + 1
    local store = ParadiseDev.Zones.Engine.getStore()
    ParadiseDev.Zones.Engine.zones = store.zones
    for _, zone in pairs(ParadiseDev.Zones.Engine.zones) do
        zone.features = ParadiseDev.Zones.Engine.copyFeatures(zone.features)
    end
    ParadiseDev.Zones.Engine.profiles = store.profiles
    ParadiseDev.Zones.Engine.vehicleMode = "rebound"
    ParadiseDev.Zones.Engine.rebuildIndex()
    ParadiseDev.PvEPolicy.onZonesChanged()
end

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
    -- Prefer PvE when loading legacy data or receiving conflicting bulk settings.
    if result.isPvE then result.isKos = false end
    return result
end

function ParadiseDev.Zones.Engine.setZoneFeature(id, key, enabled)
    local zone = ParadiseDev.Zones.Engine.zones[id]
    if not zone then return false, "zone not found" end
    if not ParadiseDev.Zones.Engine.featureKeySet[key] then return false, "unknown zone feature" end
    local proposed=Engine.copyFeatures(zone.features)
    proposed[key]=enabled==true
    if enabled==true and key=="isPvE" then proposed.isKos=false end
    if enabled==true and key=="isKos" then proposed.isPvE=false end
    if proposed.isCage and (proposed.isKos or proposed.isBlocked) then
        return false,"Cage zones cannot also be KoS or Blocked. Keep a safe confinement destination for every profile."
    end
    zone.features = zone.features or ParadiseDev.Zones.Engine.copyFeatures(nil)
    zone.features[key] = enabled == true
    if enabled == true then
        if key == "isPvE" then zone.features.isKos = false end
        if key == "isKos" then zone.features.isPvE = false end
    end
    if key == "isCage" and enabled ~= true then
        for steamId, cageId in pairs(ParadiseDev.Zones.Engine.cageAssignments) do
            if cageId == id then ParadiseDev.Zones.Engine.cageAssignments[steamId] = nil end
        end
    end
    ParadiseDev.Zones.Engine.save()
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
    ParadiseDev.Zones.Engine.save()
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
    if options.features and options.features.isCage and (options.features.isKos or options.features.isBlocked) then
        return nil,"Cage zones cannot also be KoS or Blocked."
    end
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
    ParadiseDev.Zones.Engine.save()
    return zone
end

function ParadiseDev.Zones.Engine.updateZone(id, options)
    local zone = ParadiseDev.Zones.Engine.zones[id]
    if not zone then return false, "zone not found" end
    options = options or {}
    if options.features and options.features.isCage and (options.features.isKos or options.features.isBlocked) then
        return false,"Cage zones cannot also be KoS or Blocked. Keep a safe confinement destination for every profile."
    end
    if options.name ~= nil then zone.name = tostring(options.name) end
    if options.priority ~= nil then zone.priority = tonumber(options.priority) or zone.priority end
    if options.zMode ~= nil then zone.zMode = options.zMode == "floor" and "floor" or "all" end
    if options.zMin ~= nil then zone.zMin = tonumber(options.zMin) or zone.zMin end
    if options.zMaxExclusive ~= nil then
        zone.zMaxExclusive = tonumber(options.zMaxExclusive) or zone.zMaxExclusive
    end
    if options.policy ~= nil then zone.policy = options.policy end
    if options.features ~= nil then zone.features = ParadiseDev.Zones.Engine.copyFeatures(options.features) end
    ParadiseDev.Zones.Engine.save()
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
    ParadiseDev.Zones.Engine.save()
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
    ParadiseDev.Zones.Engine.save()
    return true
end

function ParadiseDev.Zones.Engine.removeZone(id)
    if not ParadiseDev.Zones.Engine.zones[id] then return false, "zone not found" end
    ParadiseDev.Zones.Engine.zones[id] = nil
    for steamId, cageId in pairs(ParadiseDev.Zones.Engine.cageAssignments) do
        if cageId == id then ParadiseDev.Zones.Engine.cageAssignments[steamId] = nil end
    end
    ParadiseDev.Zones.Engine.rebuildIndex()
    ParadiseDev.Zones.Engine.save()
    return true
end
function ParadiseDev.Zones.Engine.setProfile(username, tags)
    if not username or username == "" then return false end
    ParadiseDev.Zones.Engine.profiles[username] = { tags = ParadiseDev.Zones.Engine.copyTags(tags) }
    ParadiseDev.Zones.Engine.save()
    return true
end

function ParadiseDev.Zones.Engine.getProfile(pl)
    local profile = ParadiseDev.Zones.Engine.profiles[ParadiseDev.Zones.Engine.userName(pl)]
    return profile or { tags = {} }
end

function ParadiseDev.Zones.Engine.isOnZoneLevel(zone, z)
    return ParadiseDev.PvEPolicy.onLevel(zone,z)
end

function ParadiseDev.Zones.Engine.regionContains(region, x, y, padding)
    return ParadiseDev.PvEPolicy.contains(region,x,y,padding)
end

function ParadiseDev.Zones.Engine.zoneContains(zone, x, y, z, padding)
    local region=ParadiseDev.PvEPolicy.containingRegion(zone,x,y,z,padding)
    return region ~= nil,region
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
    local context=ParadiseDev.SafePlacement.fromPlayer(pl)
    if not context.ready then return context.reason or "Character permissions are not ready" end
    -- Diagnostics retain the rule reason even when an administrator may bypass.
    context.admin=false
    return ParadiseDev.SafePlacement.deniedReason(zone,context)
end

function ParadiseDev.Zones.Engine.isCanEnterZone(zone, pl)
    if not zone or not pl then return true end
    local context=ParadiseDev.SafePlacement.fromPlayer(pl)
    return context.ready==true and ParadiseDev.SafePlacement.deniedReason(zone,context)==nil
end

function ParadiseDev.Zones.Engine.adminBypassEnabled()
    return SandboxVars and SandboxVars.ParadiseZ and SandboxVars.ParadiseZ.AdminBypassZoneRestrictions == true
end

function ParadiseDev.Zones.Engine.isAllowed(zone, pl)
    return ParadiseDev.Zones.Engine.isCanEnterZone(zone, pl)
end

function ParadiseDev.Zones.Engine.syncBoundaryState(pl)
    if not pl then return end
    local state = Engine.boundaryActor(pl)
    local ride = Engine.observeBoundaryRide(pl, state)
    local riderCaged = ParadiseDev.Cage and ParadiseDev.Cage.isCaged(pl)
    local passengerRide = not riderCaged and ride and {rideToken=ride.token,vehicleId=ride.vehicleId,
        seat=ride.seat,driverId=ride.driverId} or nil
    -- A cage has its own enforcement. It must never authorize ordinary passenger
    -- prediction, including the brief interval before a cage zone is assigned.
    local driverCaged = ride and ParadiseDev.Cage and ParadiseDev.Cage.isCaged(ride.driver)
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
            driverAllowed = ride ~= nil and not driverCaged and Engine.isAllowed(zone, ride.driver) == true,
            restricted = deniedReason ~= nil,
            deniedReason = deniedReason,
            features = ParadiseDev.Zones.Engine.copyFeatures(zone.features),
            regions = regions,
        }
    end
    sendServerCommand(pl, "PZZoneEngine", "boundaryState", {
        session = state.session, sessionOrder = state.sessionOrder, stateRevision = state.stateRevision,
        borderWidth = ParadiseDev.Zones.Engine.BORDER_WIDTH,
        vehicleMode = ParadiseDev.Zones.Engine.vehicleMode,
        passengerRide = passengerRide,
        cagedZoneId = ParadiseDev.Zones.Engine.cageAssignments[ParadiseDev.Zones.Engine.playerSteamId(pl)],
        zones = zones,
    })
    state.stateSent, state.leaseAt, state.fullAt = true, boundaryNow(), boundaryNow()
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
            if ParadiseDev.PvEPolicy.better(zone,region,winner,winnerRegion) then
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

function ParadiseDev.Zones.Engine.nearestInside(region, x, y, padding)
    padding = padding or 1
    local left, right = region.xMin + padding, region.xMax - padding
    local top, bottom = region.yMin + padding, region.yMax - padding
    if left > right then left, right = region.xMin, region.xMax - 1 end
    if top > bottom then top, bottom = region.yMin, region.yMax - 1 end
    local west, east = math.abs(x - region.xMin), math.abs(region.xMax - x)
    local north, south = math.abs(y - region.yMin), math.abs(region.yMax - y)
    if west <= east and west <= north and west <= south then return left, math.max(top, math.min(y, bottom)) end
    if east <= north and east <= south then return right, math.max(top, math.min(y, bottom)) end
    if north <= south then return math.max(left, math.min(x, right)), top end
    return math.max(left, math.min(x, right)), bottom
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

function ParadiseDev.Zones.Engine.teleportPlayer(pl, x, y, z, onArrive)
    return ParadiseDev and ParadiseDev.TP and ParadiseDev.TP.teleportPlayer(pl, x, y, z, onArrive,{recovery=true}) or false
end

function ParadiseDev.Zones.Engine.reboundPlayer(pl, zone, region, x, y, z)
    local state=Engine.ensureBoundaryState(pl)
    local now=boundaryNow()
    if state.recoveryAt and now>=state.recoveryAt and now-state.recoveryAt<1000 then return false end
    state.recoveryAt=now
    local safe=ParadiseDev.SafePlacement
    local context=safe.fromPlayer(pl)
    local result=safe.find({x=x,y=y,z=z},context,{previous=Engine.lastValid[Engine.userName(pl)]})
    if result.status~="safe" then
        if result.status=="pending" then safe.prepare(result) end
        if not state.recoveryNotice or now-state.recoveryNotice>=10000 then
            state.recoveryNotice=now
            sendServerCommand(pl,"ParadiseDevTP","message",{text=result.reason or "Waiting for a safe recovery location"})
        end
        return false
    end
    local point=result.location
    -- Re-read permission/terrain immediately before issuing the movement. Long
    -- recovery uses native chunk-aware transfer, never direct client coordinates.
    if safe.evaluate(point,safe.fromPlayer(pl)).status~="safe" then return false end
    Engine.clearBoundaryCorrection(pl)
    local distance=(point.x-x)^2+(point.y-y)^2
    if not result.fallback and point.z==z and distance<=16 then
        local ok,first=Engine.sendBoundaryCorrection(pl,"foot",zone,nil,x,y,z,point.x,point.y,point.z)
        if first then Engine.log("rebound-boundary",pl,zone) end
        return ok
    end
    local ok,sent=Engine.teleportPlayer(pl,point.x,point.y,point.z)
    if sent then Engine.log("recovery-safe-ground",pl,zone) end
    return ok
end

function Engine.reboundBoundaryVehicle(driver, vehicle, zone, region, x, y, z)
    if not driver or driver:getVehicle()~=vehicle or vehicle:getCharacter(0)~=driver or Engine.isAllowed(zone,driver) then return false end
    -- No center-only geometric teleport: it cannot establish the safety of the
    -- entire car or attached trailer. Preserve seats and hold for on-foot recovery.
    vehicle:setForceBrake()
    Engine.clearBoundaryCorrection(driver)
    local state=Engine.ensureBoundaryState(driver)
    local now=boundaryNow()
    if not state.vehicleNotice or now-state.vehicleNotice>=10000 then
        state.vehicleNotice=now
        sendServerCommand(driver,"ParadiseDevTP","message",{text="This vehicle cannot enter the zone. Leave the vehicle for verified safe-ground recovery."})
    end
    return false
end

function Engine.ejectBoundaryPassenger(pl, vehicle, zone, region, x, y, z)
    local driver = vehicle and vehicle:getCharacter(0) or nil
    if not driver or not driver:isAlive() or driver == pl or pl:getVehicle() ~= vehicle or
        not Engine.isAllowed(zone, driver) or Engine.isAllowed(zone, pl) then return false end
    -- A denied passenger must not be dropped onto water or inside a newly
    -- forbidden area. The owner checks the exact native outside-seat point.
    vehicle:setForceBrake()
    local state = Engine.ensureBoundaryState(pl)
    local ride = Engine.observeBoundaryRide(pl, state)
    -- A driver callback can precede the passenger's first boundary request. Wait
    -- for that existing request to supply the current ride stamp; do not guess.
    if not ride or ride.vehicle ~= vehicle or ride.driver ~= driver then return false end
    -- Owner-first native exit is replicated by the game's VehicleExit packet.
    -- Server-side BaseVehicle.exit alone leaves the owning client seated. Keep
    -- server state intact so retries remain live until a native exit is observed.
    -- This directive is exit-only; foot enforcement handles the actual current
    -- position afterward, avoiding teleporting a moving passenger to an old edge.
    local ok, first = Engine.sendBoundaryCorrection(pl, "passenger", zone, vehicle,
        x, y, z, x, y, z, nil, ride)
    if first then Engine.log("passenger-exit-requested", pl, zone, "seat=" .. tostring(ride.seat)) end
    return ok
end

function ParadiseDev.Zones.Engine.reboundVehicle(vehicle, x, y, outX, outY, pl)
    return ParadiseDev and ParadiseDev.TP and ParadiseDev.TP.reboundVehicle(vehicle, x, y, outX, outY, pl) or false
end

function ParadiseDev.Zones.Engine.forcePassengerOut(pl, x, y, z)
    return ParadiseDev and ParadiseDev.TP and ParadiseDev.TP.exitVehicleAndTeleport(pl, x, y, z, true) or false
end

function ParadiseDev.Zones.Engine.forceVehicleExit(pl, x, y, z, onArrive, requiredZoneId)
    return ParadiseDev and ParadiseDev.TP and ParadiseDev.TP.exitVehicleAndTeleport(pl, x, y, z, false, onArrive,
        {recovery=true,requiredZoneId=requiredZoneId}) or false
end

function ParadiseDev.Zones.Engine.captureCageReturn(pl)
    if not pl then return end
    local modData = pl:getModData()
    if modData.ParadiseDevCageReturn then return end
    local x, y, z = pl:getX(), pl:getY(), pl:getZ()
    local vehicle = pl:getVehicle()
    if vehicle then
        x, y, z = vehicle:getX(), vehicle:getY(), pl:getZ()
    end
    modData.ParadiseDevCageReturn = {
        x = x,
        y = y,
        z = z,
    }
end

function ParadiseDev.Zones.Engine.saveCageRebound(pl, zone, x, y, z)
    if not pl or not zone or not zone.id then return nil end
    if not ParadiseDev.Zones.Engine.zoneContains(zone, x, y, z, 0) then return nil end
    local point = { zoneId = zone.id, x = x, y = y, z = z }
    pl:getModData().ParadiseDevCageRebound = point
    return point
end

function ParadiseDev.Zones.Engine.getCageRebound(pl, zone)
    local point = pl and pl:getModData().ParadiseDevCageRebound or nil
    if not point or not zone or point.zoneId ~= zone.id then return nil end
    if not ParadiseDev.Zones.Engine.zoneContains(zone, point.x, point.y, point.z, 0) then return nil end
    return point
end

function ParadiseDev.Zones.Engine.restoreCageReturn(pl)
    if not pl then return false end
    local modData = pl:getModData()
    local returnPoint = modData.ParadiseDevCageReturn
    if not returnPoint then return false end
    -- Retain the durable return point until the server sees actual arrival.
    -- A disconnect or a superseded queued transfer must not discard it.
    return ParadiseDev.Zones.Engine.forceVehicleExit(pl, returnPoint.x, returnPoint.y, returnPoint.z, function()
        if modData.ParadiseDevCageReturn == returnPoint then modData.ParadiseDevCageReturn = nil end
    end)
end

function ParadiseDev.Zones.Engine.assignCage(pl, zone)
    if not pl or not zone or not zone.features or not zone.features.isCage then
        return false, "A valid Cage zone is required."
    end
    local steamId = ParadiseDev.Zones.Engine.playerSteamId(pl)
    if not steamId then return false, "The target player has no Steam ID." end
    if ParadiseDev.Zones.Engine.cageAssignments[steamId] then
        return false, "Player is already assigned to a cage."
    end
    local state=Engine.ensureBoundaryState(pl)
    local now=boundaryNow()
    if state.cageRecoveryAt and now>=state.cageRecoveryAt and now-state.cageRecoveryAt<1000 then
        return false,"Safe cage placement is still being checked."
    end
    state.cageRecoveryAt=now
    local safe=ParadiseDev.SafePlacement
    local result=safe.findCage(pl,zone,{x=pl:getX(),y=pl:getY(),z=pl:getZ()})
    if result.status~="safe" then
        if result.status=="pending" then safe.prepare(result) end
        return false,"Cage needs administrator attention: "..tostring(result.reason)
    end
    local x,y,z=result.location.x,result.location.y,result.location.z
    ParadiseDev.Zones.Engine.captureCageReturn(pl)
    if not ParadiseDev.Zones.Engine.forceVehicleExit(pl, x, y, z,nil,zone.id) then
        return false, "The server could not start the cage transfer."
    end
    ParadiseDev.Zones.Engine.cageAssignments[steamId] = zone.id
    ParadiseDev.Zones.Engine.lastValid[ParadiseDev.Zones.Engine.userName(pl)] = nil
    ParadiseDev.Zones.Engine.saveCageRebound(pl, zone, x, y, z)
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
    pl:getModData().ParadiseDevCageRebound = nil
    ParadiseDev.Zones.Engine.syncBoundaryState(pl)
    ParadiseDev.Zones.Engine.restoreCageReturn(pl)
    ParadiseDev.Zones.Engine.log("uncaged", pl, zone)
    return true
end

function ParadiseDev.Zones.Engine.enforceCage(pl, zone, x, y, z)
    local state=Engine.ensureBoundaryState(pl)
    local now=boundaryNow()
    if state.cageRecoveryAt and now>=state.cageRecoveryAt and now-state.cageRecoveryAt<1000 then return false end
    state.cageRecoveryAt=now
    local safe=ParadiseDev.SafePlacement
    local context=safe.fromPlayer(pl)
    context.requiredZoneId=zone.id
    local inside = ParadiseDev.Zones.Engine.zoneContains(zone, x, y, z, 0)
    -- An already confined occupant needs no placement. Do not force an exit
    -- simply because a foot-only ground check detects their own vehicle.
    if inside and pl:getVehicle() and safe.evaluatePolicy({x=x,y=y,z=z},context).status=="safe" then return true end
    if inside and safe.evaluate({x=x,y=y,z=z},context).status=="safe" then
        ParadiseDev.Zones.Engine.lastValid[ParadiseDev.Zones.Engine.userName(pl)] = { x = x, y = y, z = z }
        ParadiseDev.Zones.Engine.saveCageRebound(pl, zone, x, y, z)
        return true
    end
    local result=safe.findCage(pl,zone,{x=x,y=y,z=z},Engine.getCageRebound(pl,zone))
    if result.status~="safe" then
        if result.status=="pending" then safe.prepare(result) end
        if not state.cageNotice or now-state.cageNotice>=10000 then
            state.cageNotice=now
            sendServerCommand(pl,"ParadiseDevTP","message",{text="Cage needs administrator attention: "..tostring(result.reason)})
        end
        return false
    end
    local point=result.location

    local vehicle = pl:getVehicle()
    if not vehicle then
        local accepted, sent = ParadiseDev.TP.teleportPlayer(pl, point.x, point.y, point.z,nil,{recovery=true,requiredZoneId=zone.id})
        if sent then ParadiseDev.Zones.Engine.log("cage-teleport", pl, zone) end
        return accepted
    end

    local accepted, sent = ParadiseDev.TP.exitVehicleAndTeleport(pl, point.x, point.y, point.z, false,nil,{recovery=true,requiredZoneId=zone.id})
    if sent then ParadiseDev.Zones.Engine.log("cage-occupant-returned", pl, zone) end
    return accepted
end

function ParadiseDev.Zones.Engine.onPlayerUpdate(pl)
    if not pl then return end
    if not pl:isAlive() then
        Engine.boundaryActors[pl] = nil
        return
    end
    if ParadiseDev and ParadiseDev.Cage then ParadiseDev.Cage.syncPlayer(pl) end
    local boundaryState = Engine.ensureBoundaryState(pl)
    Engine.observeBoundaryRide(pl, boundaryState)
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
        if not boundaryState.cageNotice or boundaryNow()-boundaryState.cageNotice>=10000 then
            boundaryState.cageNotice=boundaryNow()
            sendServerCommand(pl,"ParadiseDevTP","message",{text="No valid cage zone is configured. An administrator must correct the cage before recovery."})
        end
        return
    end
    if cageId and ParadiseDev.Cage.isCaged(pl) then
        local cageZone = ParadiseDev.Zones.Engine.zones[cageId]
        if cageZone and cageZone.features and cageZone.features.isCage then
            ParadiseDev.Zones.Engine.enforceCage(pl, cageZone, x, y, z)
            return
        end
        if not boundaryState.cageNotice or boundaryNow()-boundaryState.cageNotice>=10000 then
            boundaryState.cageNotice=boundaryNow()
            sendServerCommand(pl,"ParadiseDevTP","message",{text="The assigned cage zone is unavailable. An administrator must correct it before recovery."})
        end
        return
    end
    local placementContext=ParadiseDev.SafePlacement.fromPlayer(pl)
    if placementContext.ready~=true then
        Engine.clearBoundaryCorrection(pl)
        return
    end

    local zone, region = Engine.getAuthority(x, y, z, vehicle and 2.0 or 0)
    if vehicle and zone then
        local driver = vehicle:getCharacter(0)
        -- Driver denial owns the whole vehicle, even when the passenger callback
        -- arrives first. A driverless vehicle is never passenger-ejected.
        if driver and driver:isAlive() then
            local driverKey = Engine.playerSteamId(driver)
            local driverCageId = driverKey and Engine.cageAssignments[driverKey]
            local driverCage = driverCageId and Engine.zones[driverCageId]
            if driver ~= pl and driverCage and driverCage.features and driverCage.features.isCage and
                ParadiseDev.Cage and ParadiseDev.Cage.isCaged(driver) then
                Engine.enforceCage(driver, driverCage, x, y, driver:getZ())
                return
            end
            if not Engine.isAllowed(zone, driver) then
                Engine.reboundBoundaryVehicle(driver, vehicle, zone, region, x, y, driver:getZ())
                return
            end
            if not Engine.isAllowed(zone, pl) then
                Engine.ejectBoundaryPassenger(pl, vehicle, zone, region, x, y, z)
                return
            end
        elseif not Engine.isAllowed(zone, pl) then
            Engine.clearBoundaryCorrection(pl)
            return
        end
    end
    if not zone or Engine.isAllowed(zone, pl) then
        Engine.clearBoundaryCorrection(pl)
        -- A valid zone is not proof of valid ground. Keep only verified on-foot
        -- tiles, checking once per new tile/revision; always recheck on reuse.
        if not vehicle then
            local prior=Engine.lastValid[Engine.userName(pl)]
            if not prior or math.floor(prior.x)~=math.floor(x) or math.floor(prior.y)~=math.floor(y)
                or prior.z~=z or prior.zoneRevision~=Engine.zoneRevision then
                local point={x=x,y=y,z=z}
                if ParadiseDev.SafePlacement.evaluate(point,placementContext).status=="safe" then
                    point.zoneRevision=Engine.zoneRevision
                    Engine.lastValid[Engine.userName(pl)]=point
                    if ParadiseDev.TP and ParadiseDev.TP.saveRebound then ParadiseDev.TP.saveRebound(pl,"Zone Rebound") end
                end
            end
        end
        if vehicle and vehicle:getCharacter(0) == pl and
            ParadiseDev.Zones.PassengerScan and ParadiseDev.Zones.PassengerScan.ejectDeniedPassengersOnDriverMove then
            ParadiseDev.Zones.PassengerScan.ejectDeniedPassengersOnDriverMove(pl)
        end
        return
    end
    if not vehicle then Engine.reboundPlayer(pl, zone, region, x, y, z) end
end

-- Bounded opt-in diagnostics; no player identifiers or command arguments.
local boundaryPerf = nil
local function newBoundaryPerf()
    return { started = getTimestampMs(), total = 0, boundary = 0, cage = 0, state = 0, other = 0 }
end
local function countBoundaryCommand(module, command)
    if not ParadiseProductionDiagnostics.isEnabled() then return end
    boundaryPerf = boundaryPerf or newBoundaryPerf()
    boundaryPerf.total = boundaryPerf.total + 1
    if module == "PZZoneEngine" then
        if command == "boundaryCheck" then boundaryPerf.boundary = boundaryPerf.boundary + 1
        elseif command == "cageBoundary" then boundaryPerf.cage = boundaryPerf.cage + 1
        elseif command == "requestBoundaryState" then boundaryPerf.state = boundaryPerf.state + 1
        else boundaryPerf.other = boundaryPerf.other + 1 end
    end
end
-- Retain callback identities on the public Engine table for duplicate-free reloads.
if ParadiseDev.Zones.Engine.reportBoundaryCommands then
    Events.OnTick.Remove(ParadiseDev.Zones.Engine.reportBoundaryCommands)
end
function ParadiseDev.Zones.Engine.reportBoundaryCommands()
    if not ParadiseProductionDiagnostics.isEnabled() or not boundaryPerf then return end
    local now = getTimestampMs()
    if now < boundaryPerf.started then boundaryPerf.started = now end
    if now - boundaryPerf.started < 60000 then return end
    print(string.format("[RestoreBoundaryPerf r1] windowMs=%d allCommands=%d boundaryCheck=%d cageBoundary=%d requestBoundaryState=%d otherZone=%d",
        now - boundaryPerf.started, boundaryPerf.total, boundaryPerf.boundary, boundaryPerf.cage, boundaryPerf.state, boundaryPerf.other))
    boundaryPerf.started = now
    boundaryPerf.total, boundaryPerf.boundary, boundaryPerf.cage, boundaryPerf.state, boundaryPerf.other = 0, 0, 0, 0, 0
end
if ParadiseDev.Zones.Engine.configureBoundaryDiagnostics then
    Events.OnServerStarted.Remove(ParadiseDev.Zones.Engine.configureBoundaryDiagnostics)
end
function ParadiseDev.Zones.Engine.configureBoundaryDiagnostics()
    Events.OnTick.Remove(ParadiseDev.Zones.Engine.reportBoundaryCommands)
    boundaryPerf = nil
    if ParadiseProductionDiagnostics.isEnabled() then
        boundaryPerf = newBoundaryPerf()
        Events.OnTick.Add(ParadiseDev.Zones.Engine.reportBoundaryCommands)
    end
end
Events.OnServerStarted.Add(ParadiseDev.Zones.Engine.configureBoundaryDiagnostics)

function ParadiseDev.Zones.Engine.onClientCommand(module, command, pl, args)
    countBoundaryCommand(module, command)
    if module == "PZZoneEngine" and command == "requestBoundaryState" then
        if not pl then return end
        local state = Engine.boundaryActor(pl)
        local now = boundaryNow()
        if not state.stateSent or not state.fullAt or now < state.fullAt or now - state.fullAt >= 1000 then
            Engine.syncBoundaryState(pl)
        else
            Engine.ensureBoundaryState(pl)
        end
    elseif module == "PZZoneEngine" and
        (command == "boundaryCheck" or command == "cageBoundary") then
        if command == "boundaryCheck" then Engine.receiveBoundaryRide(pl, args) end
        ParadiseDev.Zones.Engine.onPlayerUpdate(pl)
    end
end

Events.OnClientCommand.Remove(ParadiseDev.Zones.Engine.onClientCommand)
Events.OnClientCommand.Add(ParadiseDev.Zones.Engine.onClientCommand)
Events.OnInitGlobalModData.Remove(ParadiseDev.Zones.Engine.load)
Events.OnInitGlobalModData.Add(ParadiseDev.Zones.Engine.load)
