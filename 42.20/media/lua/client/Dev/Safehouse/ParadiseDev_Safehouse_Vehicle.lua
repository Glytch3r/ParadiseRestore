ParadiseDev = ParadiseDev or {}
ParadiseDev.Safehouse = ParadiseDev.Safehouse or {}
ParadiseDev.Safehouse.Vehicle = ParadiseDev.Safehouse.Vehicle or {}

local vehicleState = ParadiseDev.Safehouse.Vehicle

function vehicleState.isEnabled()
    return SandboxVars and SandboxVars.ParadiseZ and SandboxVars.ParadiseZ.BlockSafehouseVehicles == true
end

function vehicleState.getSafehouse(obj)
    if not SafeHouse or not SafeHouse.getSafeHouse or not obj then return nil end
    local sq = obj:getCurrentSquare()
    return sq and SafeHouse.getSafeHouse(sq) or nil
end

function vehicleState.canEnter(safehouse, pl)
    return safehouse and pl and safehouse:playerAllowed(pl) or false
end

function vehicleState.moveVehicle(vehicle, x, y)
    if not vehicle or not x or not y then return false end
    local fromX, fromY = vehicle:getX(), vehicle:getY()
    local transform = BaseVehicle.allocTransform()
    vehicle:getWorldTransform(transform)
    local origin = transform:getOrigin()
    origin:set(origin:x() + (x - fromX), origin:y(), origin:z() + (y - fromY))
    vehicle:setWorldTransform(transform)
    BaseVehicle.releaseTransform(transform)
    pcall(vehicle.update, vehicle)
    pcall(vehicle.updateControls, vehicle)
    pcall(vehicle.updateBulletStats, vehicle)
    pcall(vehicle.updatePhysics, vehicle)
    pcall(vehicle.updatePhysicsNetwork, vehicle)
    return true
end

function vehicleState.outside(safehouse, x, y)
    local left, top = safehouse:getX(), safehouse:getY()
    local right, bottom = left + safehouse:getW(), top + safehouse:getH()
    local edge = math.min(math.abs(x - left), math.abs(x - right), math.abs(y - top), math.abs(y - bottom))
    if edge == math.abs(x - left) then return left - 2, y end
    if edge == math.abs(x - right) then return right + 2, y end
    if edge == math.abs(y - top) then return x, top - 2 end
    return x, bottom + 2
end

function vehicleState.rebound(pl, vehicle, x, y)
    if not vehicleState.moveVehicle(vehicle, x, y) then return end
    if pl.teleportTo then pl:teleportTo(x, y, pl:getZ()) end
end

function vehicleState.onPlayerUpdate(pl)
    if not vehicleState.isEnabled() or not pl or not pl:isAlive() then return end
    local vehicle = pl:getVehicle()
    local x, y = vehicle and vehicle:getX() or pl:getX(), vehicle and vehicle:getY() or pl:getY()
    local safehouse = vehicleState.getSafehouse(vehicle or pl)
    local state = pl:getModData().ParadiseDevSafehouseVehicle or {}
    pl:getModData().ParadiseDevSafehouseVehicle = state

    if vehicle and vehicleState.canEnter(safehouse, pl) then
        state.safehouse = safehouse
        state.x, state.y = x, y
        state.vehicle = vehicle
        return
    end

    if vehicle and safehouse and state.vehicle ~= vehicle then
        local outX, outY = vehicleState.outside(safehouse, x, y)
        vehicleState.rebound(pl, vehicle, outX, outY)
        state.safehouse = nil
        state.x, state.y = outX, outY
        state.vehicle = vehicle
        return
    end

    if vehicle and state.safehouse ~= safehouse and state.x and state.y then
        vehicleState.rebound(pl, vehicle, state.x, state.y)
        state.safehouse = vehicleState.getSafehouse(pl)
        state.x, state.y = state.x, state.y
        state.vehicle = vehicle
        return
    end

    state.safehouse = safehouse
    state.x, state.y = x, y
    state.vehicle = vehicle
end

Events.OnPlayerUpdate.Remove(vehicleState.onPlayerUpdate)
Events.OnPlayerUpdate.Add(vehicleState.onPlayerUpdate)
