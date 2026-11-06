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

ParadiseDev.Zones.MovementProbe.moveWatch = ParadiseDev.Zones.MovementProbe.moveWatch or {}

function ParadiseDev.Zones.MovementProbe.onTick()
    if isClient and isClient() and not (isServer and isServer()) then return end
    if not ParadiseProductionDiagnostics.isEnabled() then return end
    local now = getTimestampMs()
    if ParadiseDev.Zones.MovementProbe.tickAt and now >= ParadiseDev.Zones.MovementProbe.tickAt
        and now - ParadiseDev.Zones.MovementProbe.tickAt < 250 then return end
    ParadiseDev.Zones.MovementProbe.tickAt = now
    ParadiseRestore.forEachMovedPlayer(ParadiseDev.Zones.MovementProbe.moveWatch,
        ParadiseDev.Zones.MovementProbe.onPlayerMove)
end
Events.OnTick.Remove(ParadiseDev.Zones.MovementProbe.onTick)
Events.OnTick.Add(ParadiseDev.Zones.MovementProbe.onTick)

-- Sandbox settings are available by server start; no movement hook by default.
if ParadiseDev.Zones.MovementProbe.configure then
    Events.OnServerStarted.Remove(ParadiseDev.Zones.MovementProbe.configure)
end
function ParadiseDev.Zones.MovementProbe.configure()
    Events.OnPlayerMove.Remove(ParadiseDev.Zones.MovementProbe.onPlayerMove)
    ParadiseDev.Zones.MovementProbe.moveWatch = {}
    ParadiseDev.Zones.MovementProbe.tickAt = nil
end
Events.OnServerStarted.Remove(ParadiseDev.Zones.MovementProbe.configure)
Events.OnServerStarted.Add(ParadiseDev.Zones.MovementProbe.configure)
