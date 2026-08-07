ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.MovementProbe = ParadiseDev.Zones.MovementProbe or {}
local P = ParadiseDev.Zones.MovementProbe
local E = ParadiseDev.Zones.Engine
E.moveProbe = E.moveProbe or {}

Events.OnPlayerMove.Add(function(player)
    if not player then return end
    local username = player:getUsername()
    E.moveProbe[username] = {
        count = (E.moveProbe[username] and E.moveProbe[username].count or 0) + 1,
        x = player:getX(),
        y = player:getY(),
        z = player:getZ(),
    }
end)

