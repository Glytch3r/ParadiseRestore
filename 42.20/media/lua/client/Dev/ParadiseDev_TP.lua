-- Central B42.20 client transport API. The server authorizes destinations;
-- this file only applies destinations that the server has approved.
ParadiseDev = ParadiseDev or {}
ParadiseDev.TP = ParadiseDev.TP or {}

local TP = ParadiseDev.TP
local MODULE = "ParadiseDevTP"

local function validCoordinates(x, y, z)
    return tonumber(x) ~= nil and tonumber(y) ~= nil and tonumber(z) ~= nil
end

function TP.applyTeleport(player, x, y, z)
    if not player or not validCoordinates(x, y, z) then return false end
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    player:setX(x)
    player:setY(y)
    player:setZ(z)
    player:setLastX(x)
    player:setLastY(y)
    player:setLastZ(z)
    player:setCurrentSquareFromPosition()
    return true
end

function TP.requestTeleport(x, y, z)
    local player = getPlayer()
    if not player or not validCoordinates(x, y, z) then return false end
    if isClient() then
        sendClientCommand(MODULE, "teleport", { x = x, y = y, z = z })
        return true
    end
    return TP.applyTeleport(player, x, y, z)
end

function TP.saveRebound(player, name)
    player = player or getPlayer()
    if not player then return nil end
    local point = { x = player:getX(), y = player:getY(), z = player:getZ(), name = name or "Rebound" }
    local modData = player:getModData()
    modData.ParadiseZRebound = point
    -- Preserve B41 rebound saves and scripts while the mod moves to the Dev API.
    modData.Rebound = point
    return point
end

function TP.getRebound(player)
    player = player or getPlayer()
    local modData = player and player:getModData() or nil
    local point = modData and (modData.ParadiseZRebound or modData.Rebound) or nil
    return point and validCoordinates(point.x, point.y, point.z) and point or nil
end

function TP.getReboundXYZ(player)
    local point = TP.getRebound(player)
    if not point then return nil end
    return point.x, point.y, point.z
end

function TP.rebound(player)
    local point = TP.getRebound(player)
    return point and TP.requestTeleport(point.x, point.y, point.z) or false
end

Events.OnServerCommand.Add(function(module, command, args)
    if module == MODULE and command == "teleport" and args then
        TP.applyTeleport(getPlayer(), args.x, args.y, args.z)
    end
end)

-- B41-compatible names for scripts still being transferred out of Z/Jim.
ParadiseZ = ParadiseZ or {}
ParadiseZ.saveRebound = TP.saveRebound
ParadiseZ.getReboundXYZ = TP.getReboundXYZ
ParadiseZ.doRebound = TP.rebound
ParadiseZ.doRegularTp = function(player, x, y, z)
    if player and player ~= getPlayer() then return false end
    return TP.requestTeleport(x, y, z)
end
ParadiseZ.forceExitCar = function()
    local player = getPlayer()
    return player and TP.requestTeleport(player:getX(), player:getY(), player:getZ()) or false
end
