if getCore():getGameVersion():getMajor() == 41 then return end
require "Dev/Zones/ParadiseDev_ZoneBomb"
ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.Bomb = ParadiseDev.Zones.Bomb or {}

local Bomb = ParadiseDev.Zones.Bomb
Bomb.MODULE = Bomb.MODULE or "PZZoneBomb"

function Bomb.onServerCommand(module, command, args)
    if module ~= Bomb.MODULE or command ~= "blast" then return end
    Bomb.onBlast(args)
end
Events.OnServerCommand.Remove(Bomb.onServerCommand)
Events.OnServerCommand.Add(Bomb.onServerCommand)
