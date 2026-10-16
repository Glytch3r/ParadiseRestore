ParadiseDev = ParadiseDev or {}
ParadiseDev.Keys = ParadiseDev.Keys or {}

function ParadiseDev.Keys.isSteamMode()
    return getSteamModeActive and getSteamModeActive() or false
end

function ParadiseDev.Keys.teleportPlayer(pl, x, y, z)
    if not pl or tonumber(x) == nil or tonumber(y) == nil or tonumber(z) == nil then return false end
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

function ParadiseDev.Keys.teleportVehicle(pl, x, y)
    local vehicle = pl and pl:getVehicle() or nil
    if not vehicle then return false end

    if isClient() then
        sendClientCommand(ParadiseDev.TP.module, "teleportVehicle", { x = x, y = y })
        return true
    end

    return ParadiseDev.TP and ParadiseDev.TP.moveVehicle and ParadiseDev.TP.moveVehicle(vehicle, x, y) or false
end

function ParadiseDev.Keys.flashlightTeleport(key)
    if ParadiseDev.Keys.isSteamMode() then return key end
    if not ParadiseRestore.isAdm() then return key end
    if not ISFastTeleportMove.cheat then return end

    if not getCore():isKey("Equip/Turn On/Off Light Source", key) then return key end

    local pl = getPlayer()
    local sq = ParadiseZ and ParadiseZ.getPointer and ParadiseZ.getPointer() or nil
    if not pl or not sq or not sq:getFloor() then return key end

    sq:getFloor():setHighlighted(true)
    --pl:faceLocation(sq:getX(), sq:getY())

    if pl:getVehicle() then
        ParadiseDev.Keys.teleportVehicle(pl, sq:getX(), sq:getY())
    else
        ParadiseDev.Keys.teleportPlayer(pl, sq:getX(), sq:getY(), sq:getZ())
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
