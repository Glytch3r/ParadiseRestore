ParadiseDev = ParadiseDev or {}
ParadiseDev.TP = ParadiseDev.TP or {}

require "Dev/ParadiseDev_Players"

ParadiseDev.TP.module = "ParadiseDevTP"

function ParadiseDev.TP.validCoordinates(x, y, z)
    return tonumber(x) ~= nil and tonumber(y) ~= nil and tonumber(z) ~= nil
end

function ParadiseDev.TP.teleportPlayer(pl, x, y, z)
    if not pl or not ParadiseDev.TP.validCoordinates(x, y, z) then return false end
    sendServerCommand(pl, ParadiseDev.TP.module, "teleport", { x = tonumber(x), y = tonumber(y), z = tonumber(z) })
    return true
end

function ParadiseDev.TP.reboundVehicle(vehicle, fromX, fromY, toX, toY)
    if not vehicle or not fromX or not fromY or not toX or not toY then return false end
    local transform = BaseVehicle.allocTransform()
    vehicle:getWorldTransform(transform)
    local origin = transform:getOrigin()
    origin:set(origin:x() + (toX - fromX), origin:y(), origin:z() + (toY - fromY))
    vehicle:setWorldTransform(transform)
    BaseVehicle.releaseTransform(transform)
    return true
end

function ParadiseDev.TP.exitVehicleAndTeleport(pl, x, y, z, passengerOnly)
    if not pl then return false end
    local vehicle = pl:getVehicle()
    if not vehicle then return ParadiseDev.TP.teleportPlayer(pl, x, y, z) end
    local seat = vehicle:getSeat(pl)
    if seat < 0 or (passengerOnly and seat <= 0) then return false end
    vehicle:exit(pl)
    vehicle:setCharacterPosition(pl, seat, "outside")
    vehicle:transmitCharacterPosition(seat, "outside")
    triggerEvent("OnExitVehicle", pl)
    return ParadiseDev.TP.teleportPlayer(pl, x, y, z)
end

function ParadiseDev.TP.onClientCommand(module, command, pl, args)
    if module ~= ParadiseDev.TP.module or command ~= "teleport" or not ParadiseDev.isAdm(pl) then return end
    ParadiseDev.TP.exitVehicleAndTeleport(pl, args and args.x, args and args.y, args and args.z, false)
end

Events.OnClientCommand.Remove(ParadiseDev.TP.onClientCommand)
Events.OnClientCommand.Add(ParadiseDev.TP.onClientCommand)
