ParadiseDev = ParadiseDev or {}
ParadiseDev.TP = ParadiseDev.TP or {}
ParadiseDev.Debug = ParadiseDev.Debug or {}



ParadiseDev.TP.module = "ParadiseDevTP"
ParadiseDev.Debug.module = "ParadiseDevDebug"

function ParadiseDev.Debug.onClientCommand(module, command, pl, args)
    if module ~= ParadiseDev.Debug.module or command ~= "testDmg" then return end
    if not pl or string.lower(pl:getAccessLevel()) ~= "admin" then return end
    local targ = args and getPlayerByOnlineID(args.targId) or nil
    if not targ then return end
    local dmg = math.min(100, math.max(0, tonumber(args.dmg) or 15))
    sendServerCommand(targ, ParadiseDev.Debug.module, "testDmg", { dmg = dmg, pushedDir = args.pushedDir })
end

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

function ParadiseDev.TP.parseFallbackRebound()
    local options = SandboxVars and SandboxVars.ParadiseZ
    local value = options and options.Coords
    local x, y, z = type(value) == "string" and value:match("^%s*(-?%d+)%s*[;:]%s*(-?%d+)%s*[;:]%s*(-?%d+)%s*$")
    return tonumber(x), tonumber(y), tonumber(z)
end

function ParadiseDev.TP.getReboundXYZ(pl)
    local modData = pl and pl:getModData()
    local point = modData and (modData.ParadiseZRebound or modData.Rebound)
    if point and ParadiseDev.TP.validCoordinates(point.x, point.y, point.z) then return point.x, point.y, point.z end
    return ParadiseDev.TP.parseFallbackRebound()
end

function ParadiseDev.TP.isInKosZone(pl)
    local engine = ParadiseDev.Zones and ParadiseDev.Zones.Engine
    local zone = engine and engine.getAuthority and engine.getAuthority(pl:getX(), pl:getY(), pl:getZ())
    return zone and zone.features and zone.features.isKos == true
end

function ParadiseDev.TP.reboundPlayer(pl)
    local x, y, z = ParadiseDev.TP.getReboundXYZ(pl)
    if not ParadiseDev.TP.validCoordinates(x, y, z) then return false end
    return ParadiseDev.TP.exitVehicleAndTeleport(pl, x, y, z, false)
end

function ParadiseDev.TP.findPlayer(username, fallback)
    if not username or username == "" then return fallback end
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if players then
        for index = 0, players:size() - 1 do
            local player = players:get(index)
            if player and player:getUsername() == username then return player end
        end
    end
    if fallback and fallback:getUsername() == username then return fallback end
    return nil
end

function ParadiseDev.TP.reply(pl, message)
    sendServerCommand(pl, ParadiseDev.TP.module, "message", { text = message })
end

function ParadiseDev.TP.onClientCommand(module, command, pl, args)
    if module ~= ParadiseDev.TP.module then return end
    if command == "rebound" then
        if ParadiseDev.TP.isInKosZone(pl) then
            ParadiseDev.TP.reply(pl, "Cannot use /stuck inside a KoS zone.")
            return
        end
        ParadiseDev.TP.reboundPlayer(pl)
    elseif command == "adminRebound" and ParadiseDev.isAdm(pl) then
        local target = ParadiseDev.TP.findPlayer(args and args.username, pl)
        if target then
            ParadiseDev.TP.reboundPlayer(target)
        else
            ParadiseDev.TP.reply(pl, "Player not found.")
        end
    elseif command == "teleport" and ParadiseDev.isAdm(pl) then
        ParadiseDev.TP.exitVehicleAndTeleport(pl, args and args.x, args and args.y, args and args.z, false)
    elseif command == "teleportVehicle" and ParadiseDev.isAdm(pl) then
        local vehicle = pl:getVehicle()
        if vehicle then
            ParadiseDev.TP.reboundVehicle(vehicle, vehicle:getX(), vehicle:getY(), args and args.x, args and args.y)
        end
    elseif command == "die" and pl and pl:isAlive() then
        pl:getBodyDamage():ReduceGeneralHealth(110)
    end
end

Events.OnClientCommand.Remove(ParadiseDev.TP.onClientCommand)
Events.OnClientCommand.Add(ParadiseDev.TP.onClientCommand)
Events.OnClientCommand.Remove(ParadiseDev.Debug.onClientCommand)
Events.OnClientCommand.Add(ParadiseDev.Debug.onClientCommand)
