ParadiseDev = ParadiseDev or {}
ParadiseZ = ParadiseZ or {}

ParadiseDev.TP = ParadiseDev.TP or {}

ParadiseDev.TP.module = "ParadiseDevTP"



function ParadiseDev.TP.parseCoords()
    if ParadiseZ.coords then
        return ParadiseZ.coords[1], ParadiseZ.coords[2], ParadiseZ.coords[3]
    end

    local strList = SandboxVars.ParadiseZ.Coords
    local tx, ty, tz = strList:match("^(-?%d+)[;:](-?%d+)[;:](-?%d+)")
    tx, ty, tz = tonumber(tx), tonumber(ty), tonumber(tz)

    ParadiseZ.coords = { tx, ty, tz }
    return tx, ty, tz
end


function ParadiseDev.TP.validCoordinates(x, y, z)
    return tonumber(x) ~= nil and tonumber(y) ~= nil and tonumber(z) ~= nil
end

function ParadiseDev.TP.applyTeleport(pl, x, y, z)
    if not pl or not ParadiseDev.TP.validCoordinates(x, y, z) then return false end
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if pl.teleportTo then
        pl:teleportTo(x, y, z)
        return true
    end
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
        return ParadiseDev.TP.applyTeleport(pl, x, y, z)
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
    if not point then return false end
    ParadiseDev.TP.forceExitCar(pl)
    return ParadiseDev.TP.requestTeleport(point.x, point.y, point.z)
end

function ParadiseDev.TP.spawnRebound(_, pl)
    pl = pl or getPlayer()
    local options = SandboxVars and SandboxVars.ParadiseZ or nil
    if not pl or not options or options.ReboundSystem == false or ParadiseDev.TP.getRebound(pl) then return end
    ParadiseDev.TP.saveRebound(pl, "Spawn")
end

function ParadiseDev.TP.reboundCountdown(isChat)
    local pl = getPlayer()
    if not pl then return false end

    isChat = isChat or false
    if timer:Exists("countdown") then
        return ParadiseDev.TP.rebound(pl)
    end

    timer:Create("countdown", 1, 10, function()
        local remaining = timer:RepsLeft("countdown")
        if remaining and remaining > 0 then
            pl:setHaloNote("Rebound " .. tostring(remaining), 150, 250, 150, 180)
        else
            ParadiseDev.TP.rebound(pl, isChat)
        end
    end)
    return true
end

function ParadiseDev.TP.onServerCommand(module, command, args)
    if module == ParadiseDev.TP.module and command == "teleport" and args then ParadiseDev.TP.applyTeleport(getPlayer(), args.x, args.y, args.z) end
end

ParadiseZ.saveRebound = ParadiseDev.TP.saveRebound
ParadiseZ.getReboundXYZ = ParadiseDev.TP.getReboundXYZ
ParadiseZ.doRebound = ParadiseDev.TP.rebound
ParadiseDev.reboundCountdown = ParadiseDev.TP.reboundCountdown
ParadiseZ.reboundCountdown = ParadiseDev.TP.reboundCountdown

function ParadiseDev.TP.doRegularTp(pl, x, y, z)
    if pl and pl ~= getPlayer() then return false end
    ParadiseDev.TP.forceExitCar(pl)
    return ParadiseDev.TP.requestTeleport(x, y, z)
end

function ParadiseDev.TP.forceExitCar(pl)
    pl = pl or getPlayer()
    if not pl then return false end
    if not pl:getVehicle() then return true end
    if ISVehicleMenu and ISVehicleMenu.onExit then ISVehicleMenu.onExit(pl) end
    local vehicle = pl:getVehicle()
    if not vehicle then return true end
    local seat = vehicle:getSeat(pl)
    vehicle:exit(pl)
    if seat and seat >= 0 then
        vehicle:setCharacterPosition(pl, seat, "outside")
        vehicle:transmitCharacterPosition(seat, "outside")
    end
    pl:PlayAnim("Idle")
    triggerEvent("OnExitVehicle", pl)
    vehicle:updateHasExtendOffsetForExitEnd(pl)
    return true
end

ParadiseZ.doRegularTp = ParadiseDev.TP.doRegularTp
ParadiseZ.forceExitCar = ParadiseDev.TP.forceExitCar

Events.OnServerCommand.Remove(ParadiseDev.TP.onServerCommand)
Events.OnServerCommand.Add(ParadiseDev.TP.onServerCommand)
Events.OnCreatePlayer.Remove(ParadiseDev.TP.spawnRebound)
Events.OnCreatePlayer.Add(ParadiseDev.TP.spawnRebound)
