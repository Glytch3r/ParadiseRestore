ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.MovementProbe = ParadiseDev.Zones.MovementProbe or {}
ParadiseDev.Zones.Engine.moveProbe = ParadiseDev.Zones.Engine.moveProbe or {}

function ParadiseDev.Zones.MovementProbe.onPlayerMove(pl)
    if not pl then return end
    local username = pl:getUsername()
    ParadiseDev.Zones.Engine.moveProbe[username] = {
        count = (ParadiseDev.Zones.Engine.moveProbe[username] and ParadiseDev.Zones.Engine.moveProbe[username].count or 0) + 1,
        x = pl:getX(),
        y = pl:getY(),
        z = pl:getZ(),
    }
end

Events.OnPlayerMove.Remove(ParadiseDev.Zones.MovementProbe.onPlayerMove)
Events.OnPlayerMove.Add(ParadiseDev.Zones.MovementProbe.onPlayerMove)
