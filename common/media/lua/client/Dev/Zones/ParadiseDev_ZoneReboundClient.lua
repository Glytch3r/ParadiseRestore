ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.ReboundClient = ParadiseDev.Zones.ReboundClient or {}
local Client = ParadiseDev.Zones.ReboundClient
Client.correctionState = {}

local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function validStamp(args)
    return type(args) == "table" and type(args.session) == "string"
        and finite(args.sessionOrder) and finite(args.stateRevision)
end

function Client.observeActor(pl, ended)
    if not pl then return end
    if Client.actor and (Client.actor ~= pl or ended) then
        Client.minimumSessionOrder = math.max(Client.minimumSessionOrder or 0,Client.correctionState.sessionOrder or 0)
        Client.correctionState = {}
        if ParadiseDev.Zones.Border then
            ParadiseDev.Zones.Border.stateReceivedAt = nil
            ParadiseDev.Zones.Border.requestFreshState(pl)
        end
    end
    Client.actor = pl
end

-- A correlation stamp for one local ride, never a source of server permission.
function Client.observeRide(pl, changed)
    if not pl then return nil end
    local vehicle = pl:getVehicle()
    local seat = vehicle and vehicle:getSeat(pl) or -1
    local driver = vehicle and vehicle:getCharacter(0) or nil
    local driverId = driver and driver:getOnlineID() or -1
    local vehicleId = vehicle and vehicle:getId() or -1
    local ride = Client.ride
    if changed or not ride or ride.player ~= pl or ride.vehicle ~= vehicle or ride.vehicleId ~= vehicleId
        or ride.seat ~= seat or ride.driverId ~= driverId then
        Client.rideSerial = (Client.rideSerial or 0)+1
        ride = {player=pl,vehicle=vehicle,vehicleId=vehicleId,seat=seat,driverId=driverId,token=Client.rideSerial}
        Client.ride = ride
    end
    return ride
end

function Client.onRideChanged(pl)
    if pl and pl == getPlayer() then Client.observeRide(pl,true) end
end

function Client.acceptSession(args)
    if not validStamp(args) then return false end
    local pl = getPlayer()
    if not pl then return false end
    Client.observeActor(pl)
    if Client.minimumSessionOrder and args.sessionOrder <= Client.minimumSessionOrder then return false end
    local state = Client.correctionState
    if state.sessionOrder and args.sessionOrder < state.sessionOrder then return false end
    if state.sessionOrder == args.sessionOrder and state.session ~= args.session then return false end
    if state.session ~= args.session then
        Client.correctionState = {session=args.session,sessionOrder=args.sessionOrder,lastSeq=0}
        if ParadiseDev.Zones.Border then ParadiseDev.Zones.Border.stateReceivedAt = nil end
    end
    return true
end

function Client.acceptState(args)
    if not Client.acceptSession(args) then return false end
    local state = Client.correctionState
    if state.revision and args.stateRevision < state.revision then return false end
    state.revision = args.stateRevision
    return true
end

function Client.applyFoot(pl, x, y, z)
    if not pl or not finite(x) or not finite(y) or not finite(z) then return false end
    pl:setX(x); pl:setY(y); pl:setZ(z)
    pl:setLastX(x); pl:setLastY(y); pl:setLastZ(z)
    pl:setCurrentSquareFromPosition()
    return true
end

-- Read current Bullet/world coordinates; object getX/getY can lag until native update.
function Client.vehiclePosition(vehicle)
    local vector = BaseVehicle.allocVector3f()
    vehicle:getWorldPos(0,0,0,vector)
    local x,y = vector:x(), vector:y()
    BaseVehicle.releaseVector3f(vector)
    return x,y
end

-- Boundary-only movement. The regular native loop advances simulation and networking.
function Client.moveVehicle(vehicle, x, y)
    if not vehicle or not finite(x) or not finite(y) then return false end
    local cell = vehicle:getCell()
    local square = cell and cell:getGridSquare(math.floor(x),math.floor(y),vehicle:getZ())
    if not square then return false end
    local other = square:getVehicleContainer()
    if (other and other ~= vehicle) or square:has(IsoFlagType.collideN) or square:has(IsoFlagType.collideW) then return false end
    local fromX, fromY = Client.vehiclePosition(vehicle)
    if not finite(fromX) or not finite(fromY) then return false end
    if x == fromX and y == fromY then return true end
    local transform = BaseVehicle.allocTransform()
    vehicle:getWorldTransform(transform)
    local origin = transform:getOrigin()
    origin:set(origin:x() + x-fromX,origin:y(),origin:z() + y-fromY)
    vehicle:setWorldTransform(transform)
    BaseVehicle.releaseTransform(transform)
    return true
end

-- Both prediction and directed corrections use the same native owner exit.
-- The native VehicleExit packet, not a custom ACK, synchronizes the server/peers.
function Client.exitPassenger(pl, vehicle, args, state, predicted)
    local border = ParadiseDev.Zones.Border
    local seat = vehicle:getSeat(pl)
    local function currentPermission()
        if pl ~= getPlayer() or not pl:isAlive() or Client.correctionState ~= state
            or not border or not border.isFresh(args.stateRevision) then return false end
        local ride = Client.observeRide(pl)
        local driver = vehicle:getCharacter(0)
        if pl:getVehicle() ~= vehicle or not ride or ride.token ~= args.rideToken
            or ride.vehicleId ~= args.vehicleId or ride.seat ~= args.seat or ride.seat < 1
            or ride.driverId ~= args.driverId or not driver or not driver:isAlive() or driver == pl then return false end
        local x,y = Client.vehiclePosition(vehicle)
        local zone = border.authorityAt(x,y,pl:getZ(),2)
        if not zone or zone.allowed ~= false or zone.id ~= args.zoneId then return false end
        if predicted then
            local stamp = border.passengerRide
            if border.cagedZoneId or zone.driverAllowed ~= true or type(stamp) ~= "table"
                or stamp.rideToken ~= args.rideToken or stamp.vehicleId ~= args.vehicleId
                or stamp.seat ~= args.seat or stamp.driverId ~= args.driverId then return false end
        end
        return true
    end
    if not currentPermission() then return false end
    local beforeX,beforeY,beforeZ = pl:getX(),pl:getY(),pl:getZ()
    local beforeRide = Client.ride
    -- Stop handlers can exit, change seats, or replace the local actor. Recheck
    -- after cancelling; never enqueue the animated/door-gated ordinary exit.
    if ISTimedActionQueue and ISTimedActionQueue.clear then ISTimedActionQueue.clear(pl) end
    if pl ~= getPlayer() or not pl:isAlive() or Client.correctionState ~= state then return false end
    local currentVehicle = pl:getVehicle()
    if currentVehicle then
        if currentVehicle ~= vehicle or not currentPermission() then return false end
        vehicle:exit(pl)
        if pl:getVehicle() then return false end
    elseif pl:getX() ~= beforeX or pl:getY() ~= beforeY or pl:getZ() ~= beforeZ
        or Client.ride ~= beforeRide then
        -- A stop handler completed its own exit or relocated the actor. Leave
        -- that transition alone instead of placing them beside the old car.
        return false
    end
    -- Place at the current car position, never an old correction destination.
    vehicle:setCharacterPosition(pl,seat,"outside")
    pl:PlayAnim("Idle")
    triggerEvent("OnExitVehicle",pl)
    vehicle:updateHasExtendOffsetForExitEnd(pl)
    return true
end

function Client.predictPassengerExit(pl, zone)
    local border, state = ParadiseDev.Zones.Border, Client.correctionState
    local stamp = border and border.passengerRide
    if not state.revision or not border or not border.isFresh(state.revision)
        or not zone or zone.allowed ~= false or zone.driverAllowed ~= true
        or border.cagedZoneId or type(stamp) ~= "table" then return false end
    local vehicle, ride = pl:getVehicle(), Client.observeRide(pl)
    if not vehicle or not ride or ride.token ~= stamp.rideToken or ride.vehicleId ~= stamp.vehicleId
        or ride.seat ~= stamp.seat or ride.seat < 1 or ride.driverId ~= stamp.driverId then return false end
    return Client.exitPassenger(pl,vehicle,{rideToken=stamp.rideToken,vehicleId=stamp.vehicleId,
        seat=stamp.seat,driverId=stamp.driverId,stateRevision=state.revision,zoneId=zone.id},state,true)
end

function Client.applyCorrection(args)
    if not validStamp(args) or not finite(args.seq) or args.seq < 1 or args.seq ~= math.floor(args.seq)
        or not finite(args.x) or not finite(args.y) or not finite(args.z)
        or not finite(args.fromX) or not finite(args.fromY) or not finite(args.fromZ)
        or (args.kind ~= "foot" and args.kind ~= "vehicle" and args.kind ~= "passenger") then return false end
    if not Client.acceptSession(args) then return false end
    local state, border, pl = Client.correctionState, ParadiseDev.Zones.Border, getPlayer()
    if args.seq <= state.lastSeq or not pl or not pl:isAlive() then return false end
    if state.revision and args.stateRevision < state.revision then state.lastSeq = args.seq; return false end
    local fresh = border and border.isFresh(args.stateRevision)
    if not fresh and border then border.requestFreshState(pl) end
    if not state.revision or args.stateRevision > state.revision then
        state.revision = args.stateRevision
        if border then border.stateReceivedAt = nil end
    end
    -- Full state and correction may arrive out of order. Wait for matching authority;
    -- bounded server retries keep this sequence usable without trusting a stale cache.
    if not fresh then return false end
    local vehicle = pl:getVehicle()
    local x,y,z = pl:getX(),pl:getY(),pl:getZ()
    if vehicle then x,y = Client.vehiclePosition(vehicle) end
    local function obsolete() state.lastSeq = args.seq; return false end
    if z ~= args.fromZ then return obsolete() end
    -- A late reply must not undo an admin teleport, vehicle change, or later journey.
    local fromDistance = (x-args.fromX)^2 + (y-args.fromY)^2
    local targetDistance = (x-args.x)^2 + (y-args.y)^2
    if args.kind ~= "passenger" and math.min(fromDistance,targetDistance) > 16 then return obsolete() end
    if args.kind == "foot" and vehicle then return obsolete() end
    if args.kind == "vehicle" and (not vehicle or vehicle:getId() ~= args.vehicleId or vehicle:getCharacter(0) ~= pl) then return obsolete() end
    if args.kind == "passenger" then
        local ride = Client.observeRide(pl)
        local driver = vehicle and vehicle:getCharacter(0) or nil
        if not vehicle or not ride or not driver or not driver:isAlive() or driver == pl or ride.seat < 1
            or not finite(args.rideToken) or args.rideToken < 1 or args.rideToken > 2147483647
            or args.rideToken ~= math.floor(args.rideToken) or ride.token ~= args.rideToken
            or ride.vehicleId ~= args.vehicleId or ride.seat ~= args.seat or ride.driverId ~= args.driverId then return obsolete() end
    end
    if fresh then
        local zone = border.authorityAt(x,y,z,vehicle and 2 or 0)
        if not zone or zone.allowed or zone.id ~= args.zoneId then return obsolete() end
    end
    local applied = false
    if args.kind == "vehicle" then
        applied = Client.moveVehicle(vehicle,args.x,args.y)
    elseif args.kind == "passenger" then
        applied = Client.exitPassenger(pl,vehicle,args,state,false)
    else
        applied = Client.applyFoot(pl,args.x,args.y,args.z)
    end
    if applied then state.lastSeq = args.seq end
    return applied
end

function ParadiseDev.Zones.ReboundClient.onPlayerUpdate(pl)
    if not pl or pl ~= getPlayer() or not isClient or not isClient() or not sendClientCommand then return end
    Client.observeActor(pl)
    -- Request pacing only: the server still performs every authority check.
    -- Weak player keys avoid retaining disconnected/replaced player objects.
    local state = ParadiseDev.Zones.ReboundClient
    state.requestTimes = state.requestTimes or setmetatable({}, { __mode = "k" })
    local now = getTimestampMs()
    local ride = Client.observeRide(pl)
    local vehicle = pl:getVehicle()
    local x = vehicle and vehicle:getX() or pl:getX()
    local y = vehicle and vehicle:getY() or pl:getY()
    local z = pl:getZ()
    local last = state.requestTimes[pl]
    if last then
        local dx, dy = x - last.x, y - last.y
        if now >= last.time and now - last.time < 50 and
            vehicle == last.vehicle and ride.token == last.rideToken and z == last.z and dx * dx + dy * dy < 0.25 then return end
    end
    local args = {}
    if vehicle and ride.token <= 2147483647 then
        args = {rideToken=ride.token,vehicleId=ride.vehicleId,seat=ride.seat,driverId=ride.driverId}
    end
    sendClientCommand(pl, "PZZoneEngine", "boundaryCheck", args)
    -- Reuse the entry; record only after the send succeeds.
    last = last or {}
    last.time, last.x, last.y, last.z, last.vehicle, last.rideToken = now, x, y, z, vehicle, ride.token
    state.requestTimes[pl] = last
end

function ParadiseDev.Zones.ReboundClient.onServerCommand(module, command, args)
    if module == "PZZoneEngine" and command == "boundaryCorrection" then Client.applyCorrection(args); return end
    if module == "PZZoneEngine" and command == "boundaryLease" then
        local border, state = ParadiseDev.Zones.Border, Client.correctionState
        if validStamp(args) and border and state.session == args.session and state.sessionOrder == args.sessionOrder
            and state.revision == args.stateRevision and border.stateRevision == args.stateRevision then
            border.stateReceivedAt = getTimestampMs()
        elseif border then border.requestFreshState(getPlayer()) end
        return
    end
    if module ~= "PZZoneEngine" or command ~= "rebound" or not args then return end
    if ParadiseDev and ParadiseDev.TP then ParadiseDev.TP.applyTeleport(getPlayer(), args.x, args.y, args.z) end
end

function Client.onConnected()
    Client.correctionState = {}
    Client.requestTimes = nil
    Client.ride = nil
    Client.rideSerial = 0
    Client.actor = nil
    Client.minimumSessionOrder = nil
    if ParadiseDev.Zones.Border then
        ParadiseDev.Zones.Border.stateReceivedAt = nil
        ParadiseDev.Zones.Border.stateRequestedAt = nil
        ParadiseDev.Zones.Border.passengerRide = nil
    end
end
function Client.onPlayerDeath(pl)
    if pl and (pl == getPlayer() or pl == Client.actor) then Client.observeActor(pl,true) end
end
function Client.onCreatePlayer(_,pl)
    if pl and pl == getPlayer() then Client.observeActor(pl) end
end
Events.OnEnterVehicle.Remove(Client.onRideChanged)
Events.OnEnterVehicle.Add(Client.onRideChanged)
-- Vanilla's dashboard normally creates this event; retain safe mod load order.
LuaEventManager.AddEvent("OnExitVehicle")
Events.OnExitVehicle.Remove(Client.onRideChanged)
Events.OnExitVehicle.Add(Client.onRideChanged)
Events.OnConnected.Remove(Client.onConnected)
Events.OnConnected.Add(Client.onConnected)
Events.OnPlayerDeath.Remove(Client.onPlayerDeath)
Events.OnPlayerDeath.Add(Client.onPlayerDeath)
Events.OnCreatePlayer.Remove(Client.onCreatePlayer)
Events.OnCreatePlayer.Add(Client.onCreatePlayer)

Events.OnServerCommand.Remove(ParadiseDev.Zones.ReboundClient.onServerCommand)
Events.OnServerCommand.Add(ParadiseDev.Zones.ReboundClient.onServerCommand)
Events.OnPlayerUpdate.Remove(ParadiseDev.Zones.ReboundClient.onPlayerUpdate)
Events.OnPlayerUpdate.Add(ParadiseDev.Zones.ReboundClient.onPlayerUpdate)
