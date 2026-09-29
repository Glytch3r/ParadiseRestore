ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.ReboundClient = ParadiseDev.Zones.ReboundClient or {}

function ParadiseDev.Zones.ReboundClient.onPlayerUpdate(pl)
    if not pl or not isClient or not isClient() or not sendClientCommand then return end
    local now = getGameTime and getGameTime():getWorldAgeHours() or 0
    if ParadiseDev.Zones.ReboundClient.lastBoundaryUpdate and
        now - ParadiseDev.Zones.ReboundClient.lastBoundaryUpdate < 0.00002 then return end
    ParadiseDev.Zones.ReboundClient.lastBoundaryUpdate = now
    sendClientCommand("PZZoneEngine", "boundaryCheck", {})
end

function ParadiseDev.Zones.ReboundClient.onServerCommand(module, command, args)
    if module ~= "PZZoneEngine" or command ~= "rebound" or not args then return end
    if ParadiseDev and ParadiseDev.TP then ParadiseDev.TP.applyTeleport(getPlayer(), args.x, args.y, args.z) end
end

Events.OnServerCommand.Remove(ParadiseDev.Zones.ReboundClient.onServerCommand)
Events.OnServerCommand.Add(ParadiseDev.Zones.ReboundClient.onServerCommand)
Events.OnPlayerUpdate.Remove(ParadiseDev.Zones.ReboundClient.onPlayerUpdate)
Events.OnPlayerUpdate.Add(ParadiseDev.Zones.ReboundClient.onPlayerUpdate)
