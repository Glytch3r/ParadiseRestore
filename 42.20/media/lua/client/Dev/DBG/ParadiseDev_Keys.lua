ParadiseDev = ParadiseDev or {}
ParadiseDev.Keys = ParadiseDev.Keys or {}

function ParadiseDev.Keys.teleportVehicle(pl, x, y)
    local vehicle = pl and pl:getVehicle() or nil
    if not vehicle then return false end

    if isClient() then
        sendClientCommand(ParadiseDev.TP.module, "teleportVehicle", { x = x, y = y })
        return true
    end

    local transform = BaseVehicle.allocTransform()
    vehicle:getWorldTransform(transform)
    local origin = transform:getOrigin()
    origin:set(origin:x() + (x - vehicle:getX()), origin:y(), origin:z() + (y - vehicle:getY()))
    vehicle:setWorldTransform(transform)
    BaseVehicle.releaseTransform(transform)
    pcall(vehicle.update, vehicle)
    pcall(vehicle.updateControls, vehicle)
    pcall(vehicle.updateBulletStats, vehicle)
    pcall(vehicle.updatePhysics, vehicle)
    pcall(vehicle.updatePhysicsNetwork, vehicle)
    return true
end

function ParadiseDev.Keys.flashlightTeleport(key)
    if not ParadiseDev.isAdm() then return key end
    if not ISFastTeleportMove.cheat then return end

    if not getCore():isKey("Equip/Turn On/Off Light Source", key) then return key end

    local pl = getPlayer()
    local sq = ParadiseZ and ParadiseZ.getPointer and ParadiseZ.getPointer() or nil
    if not pl or not sq or not sq:getFloor() then return key end

    sq:getFloor():setHighlighted(true)
    --pl:faceLocation(sq:getX(), sq:getY())

    if pl:getVehicle() then
        ParadiseDev.Keys.teleportVehicle(pl, sq:getX(), sq:getY())
    elseif ParadiseDev.TP then
        ParadiseDev.TP.requestTeleport(sq:getX(), sq:getY(), sq:getZ())
    end

    pl:getCell():addLamppost(IsoLightSource.new(
        sq:getX(), sq:getY(), sq:getZ(), 255, 255, 255, 255
    ))
    return key
end

ParadiseZ = ParadiseZ or {}
ParadiseZ.dbgKeys = ParadiseDev.Keys.flashlightTeleport

Events.OnKeyPressed.Remove(ParadiseDev.Keys.flashlightTeleport)
Events.OnKeyPressed.Add(ParadiseDev.Keys.flashlightTeleport)
