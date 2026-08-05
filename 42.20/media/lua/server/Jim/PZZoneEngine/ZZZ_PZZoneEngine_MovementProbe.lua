-- Test instrumentation only.  It proves whether the server receives the B42
-- OnPlayerMove callback and records the last position supplied by that event.
local E = PZZoneEngine
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
