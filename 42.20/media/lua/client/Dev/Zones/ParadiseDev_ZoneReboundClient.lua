ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.ReboundClient = ParadiseDev.Zones.ReboundClient or {}

function ParadiseDev.Zones.ReboundClient.onServerCommand(module, command, args)
    if module ~= "PZZoneEngine" or command ~= "rebound" or not args then return end
    if ParadiseDev and ParadiseDev.TP then ParadiseDev.TP.applyTeleport(getPlayer(), args.x, args.y, args.z) end
end

Events.OnServerCommand.Remove(ParadiseDev.Zones.ReboundClient.onServerCommand)
Events.OnServerCommand.Add(ParadiseDev.Zones.ReboundClient.onServerCommand)
