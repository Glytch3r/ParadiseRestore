ParadiseDev = ParadiseDev or {}
ParadiseDev.TP = ParadiseDev.TP or {}

ParadiseDev.TP.module = "ParadiseDevTP"

function ParadiseDev.TP.validCoordinates(x, y, z)
    return tonumber(x) ~= nil and tonumber(y) ~= nil and tonumber(z) ~= nil
end

function ParadiseDev.TP.applyTeleport(pl, x, y, z)
    if not pl or not ParadiseDev.TP.validCoordinates(x, y, z) then return false end
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    pl:setX(x)
    pl:setY(y)
    pl:setZ(z)
    pl:setLastX(x)
    pl:setLastY(y)
    pl:setLastZ(z)
    pl:setCurrentSquareFromPosition()
    return true
end

function ParadiseDev.TP.requestTeleport(x, y, z)
    local pl = getPlayer()
    if not pl or not ParadiseDev.TP.validCoordinates(x, y, z) then return false end
    if isClient() then
        sendClientCommand(ParadiseDev.TP.module, "teleport", { x = x, y = y, z = z })
        return true
    end
    return ParadiseDev.TP.applyTeleport(pl, x, y, z)
end

function ParadiseDev.TP.saveRebound(pl, name)
    pl = pl or getPlayer()
    if not pl then return nil end
    local point = { x = pl:getX(), y = pl:getY(), z = pl:getZ(), name = name or "Rebound" }
    local modData = pl:getModData()
    modData.ParadiseZRebound = point
    modData.Rebound = point
    return point
end

function ParadiseDev.TP.getRebound(pl)
    pl = pl or getPlayer()
    local modData = pl and pl:getModData() or nil
    local point = modData and (modData.ParadiseZRebound or modData.Rebound) or nil
    return point and ParadiseDev.TP.validCoordinates(point.x, point.y, point.z) and point or nil
end

function ParadiseDev.TP.getReboundXYZ(pl)
    local point = ParadiseDev.TP.getRebound(pl)
    if not point then return nil end
    return point.x, point.y, point.z
end

function ParadiseDev.TP.rebound(pl)
    local point = ParadiseDev.TP.getRebound(pl)
    return point and ParadiseDev.TP.requestTeleport(point.x, point.y, point.z) or false
end

function ParadiseDev.TP.onServerCommand(module, command, args)
    if module == ParadiseDev.TP.module and command == "teleport" and args then ParadiseDev.TP.applyTeleport(getPlayer(), args.x, args.y, args.z) end
end

ParadiseZ = ParadiseZ or {}
ParadiseZ.saveRebound = ParadiseDev.TP.saveRebound
ParadiseZ.getReboundXYZ = ParadiseDev.TP.getReboundXYZ
ParadiseZ.doRebound = ParadiseDev.TP.rebound

function ParadiseDev.TP.doRegularTp(pl, x, y, z)
    if pl and pl ~= getPlayer() then return false end
    return ParadiseDev.TP.requestTeleport(x, y, z)
end

function ParadiseDev.TP.forceExitCar()
    local pl = getPlayer()
    return pl and ParadiseDev.TP.requestTeleport(pl:getX(), pl:getY(), pl:getZ()) or false
end

ParadiseZ.doRegularTp = ParadiseDev.TP.doRegularTp
ParadiseZ.forceExitCar = ParadiseDev.TP.forceExitCar

Events.OnServerCommand.Remove(ParadiseDev.TP.onServerCommand)
Events.OnServerCommand.Add(ParadiseDev.TP.onServerCommand)
