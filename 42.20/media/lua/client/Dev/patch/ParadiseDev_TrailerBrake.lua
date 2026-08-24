ParadiseDev = ParadiseDev or {}
ParadiseDev.TrailerBrake = ParadiseDev.TrailerBrake or {}
ParadiseDev.TrailerBrake.distanceByVehicle = ParadiseDev.TrailerBrake.distanceByVehicle or {}

function ParadiseDev.TrailerBrake.moveVehicle(vehicle, x, y, z)
    if not vehicle or not x or not y or not z then return false end
    local transform = BaseVehicle.allocTransform()
    vehicle:getWorldTransform(transform)
    local origin = transform:getOrigin()
    origin:set(origin:x() + (x - vehicle:getX()), origin:y() + (z - vehicle:getZ()), origin:z() + (y - vehicle:getY()))
    vehicle:setWorldTransform(transform)
    BaseVehicle.releaseTransform(transform)
    pcall(vehicle.update, vehicle)
    pcall(vehicle.updateControls, vehicle)
    pcall(vehicle.updateBulletStats, vehicle)
    pcall(vehicle.updatePhysics, vehicle)
    pcall(vehicle.updatePhysicsNetwork, vehicle)
    return true
end

function ParadiseDev.TrailerBrake.onTick()
    local pl = getPlayer()
    local car = pl and pl:getVehicle() or nil
    if not car or car:getDriver() ~= pl then return end

    local car2 = car:getVehicleTowing()
    local controller = car:getController()
    if not car2 or not controller then return end

    local dx = car2:getX() - car:getX()
    local dy = car2:getY() - car:getY()
    local dz = car2:getZ() - car:getZ()
    local distance = dx * dx + dy * dy + dz * dz
    local carId = car:getId()
    local previousDistance = ParadiseDev.TrailerBrake.distanceByVehicle[carId]
    local fix = SandboxVars and SandboxVars.ParadiseZ and SandboxVars.ParadiseZ.TrailerBrakeFix or 1

    if controller:isBrakePedalPressed() and fix == 2 and car2.getController then
        car2:setForceBrake()
    elseif controller:isBrakePedalPressed() and fix == 3 and previousDistance and distance < previousDistance.distance then
        ParadiseDev.TrailerBrake.moveVehicle(car2, car:getX() + previousDistance.x, car:getY() + previousDistance.y, car:getZ() + previousDistance.z)
        return
    end

    ParadiseDev.TrailerBrake.distanceByVehicle[carId] = { x = dx, y = dy, z = dz, distance = distance }
end

Events.OnTick.Remove(ParadiseDev.TrailerBrake.onTick)
Events.OnTick.Add(ParadiseDev.TrailerBrake.onTick)


--[[ 
ParadiseDev = ParadiseDev or {}
ParadiseDev.TrailerBrake = ParadiseDev.TrailerBrake or {}

function ParadiseDev.TrailerBrake.onTick()
    local pl = getPlayer()
    local car = pl and pl:getVehicle() or nil
    if not car or car:getDriver() ~= pl then return end

    local car2 = car:getVehicleTowing()
    local controller = car:getController()
    if not car2 or not controller or not controller:isBrakePedalPressed() then return end
    if car2.getController then
        car2:setForceBrake()
    end
end

Events.OnTick.Remove(ParadiseDev.TrailerBrake.onTick)
Events.OnTick.Add(ParadiseDev.TrailerBrake.onTick)
 ]]
