-- B42.20 debug key tools transferred from the legacy ParadiseZ_Keys.lua.
ParadiseDev = ParadiseDev or {}
ParadiseDev.Keys = ParadiseDev.Keys or {}

local Keys = ParadiseDev.Keys

function Keys.flashlightTeleport(key)
    if not getCore():getDebug() then return key end
    if key ~= getCore():getKey("Equip/Turn On/Off Light Source") then return key end

    local player = getPlayer()
    local square = ParadiseZ and ParadiseZ.getPointer and ParadiseZ.getPointer() or nil
    if not player or not square or not square:getFloor() then return key end

    square:getFloor():setHighlighted(true)
    player:faceLocation(square:getX(), square:getY())

    if ParadiseDev.TP then
        ParadiseDev.TP.requestTeleport(square:getX(), square:getY(), square:getZ())
    end

    -- Keep the old debug visual, but anchor it at the chosen square. In
    -- multiplayer the actual player move is completed by the server response.
    player:getCell():addLamppost(IsoLightSource.new(
        square:getX(), square:getY(), square:getZ(), 255, 255, 255, 255
    ))
    return key
end

-- Preserve the B41 public name for any scripts that call the handler directly.
ParadiseZ = ParadiseZ or {}
ParadiseZ.dbgKeys = Keys.flashlightTeleport

Events.OnKeyPressed.Remove(Keys.flashlightTeleport)
Events.OnKeyPressed.Add(Keys.flashlightTeleport)
