require "ParadiseProductionDiagnostics"
ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.MovementProbe = ParadiseDev.Zones.MovementProbe or {}
ParadiseDev.Zones.Engine.moveProbe = ParadiseDev.Zones.Engine.moveProbe or {}

if ParadiseDev.Zones.MovementProbe.onPlayerMove then
    Events.OnPlayerMove.Remove(ParadiseDev.Zones.MovementProbe.onPlayerMove)
end

function ParadiseDev.Zones.MovementProbe.onPlayerMove(pl)
    if not ParadiseProductionDiagnostics.isEnabled() or not pl then return end
    local username = pl:getUsername()
    ParadiseDev.Zones.Engine.moveProbe[username] = {
        count = (ParadiseDev.Zones.Engine.moveProbe[username] and ParadiseDev.Zones.Engine.moveProbe[username].count or 0) + 1,
        x = pl:getX(),
        y = pl:getY(),
        z = pl:getZ(),
    }
end

-- Sandbox settings are available by server start; no movement hook by default.
if ParadiseDev.Zones.MovementProbe.configure then
    Events.OnServerStarted.Remove(ParadiseDev.Zones.MovementProbe.configure)
end
function ParadiseDev.Zones.MovementProbe.configure()
    Events.OnPlayerMove.Remove(ParadiseDev.Zones.MovementProbe.onPlayerMove)
    if ParadiseProductionDiagnostics.isEnabled() then
        Events.OnPlayerMove.Add(ParadiseDev.Zones.MovementProbe.onPlayerMove)
    end
end
Events.OnServerStarted.Add(ParadiseDev.Zones.MovementProbe.configure)
