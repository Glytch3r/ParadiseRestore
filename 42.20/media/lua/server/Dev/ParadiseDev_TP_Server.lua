-- Shared server-side B42.20 player, rebound, and vehicle transport API.
ParadiseDev = ParadiseDev or {}
ParadiseDev.TP = ParadiseDev.TP or {}

local TP = ParadiseDev.TP
local MODULE = "ParadiseDevTP"

local function validCoordinates(x, y, z)
    return tonumber(x) ~= nil and tonumber(y) ~= nil and tonumber(z) ~= nil
end

local function canUseAdminTeleport(player)
    return player and string.lower(tostring(player:getAccessLevel())) == "admin"
end

function TP.teleportPlayer(player, x, y, z)
    if not player or not validCoordinates(x, y, z) then return false end
    sendServerCommand(player, MODULE, "teleport", { x = tonumber(x), y = tonumber(y), z = tonumber(z) })
    return true
end

function TP.reboundVehicle(vehicle, fromX, fromY, toX, toY)
    if not vehicle or not fromX or not fromY or not toX or not toY then return false end
    local transform = BaseVehicle.allocTransform()
    vehicle:getWorldTransform(transform)
    local origin = transform:getOrigin()
    origin:set(origin:x() + (toX - fromX), origin:y(), origin:z() + (toY - fromY))
    vehicle:setWorldTransform(transform)
    BaseVehicle.releaseTransform(transform)
    return true
end

function TP.exitVehicleAndTeleport(player, x, y, z, passengerOnly)
    if not player then return false end
    local vehicle = player:getVehicle()
    if not vehicle then return TP.teleportPlayer(player, x, y, z) end
    local seat = vehicle:getSeat(player)
    if seat < 0 or (passengerOnly and seat <= 0) then return false end
    vehicle:exit(player)
    vehicle:setCharacterPosition(player, seat, "outside")
    vehicle:transmitCharacterPosition(seat, "outside")
    triggerEvent("OnExitVehicle", player)
    return TP.teleportPlayer(player, x, y, z)
end

-- Manual callers (such as an admin Force Rebound button) can only move
-- themselves. Zone and spectate systems call the API above directly.
Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= MODULE or command ~= "teleport" or not canUseAdminTeleport(player) then return end
    TP.exitVehicleAndTeleport(player, args and args.x, args and args.y, args and args.z, false)
end)
