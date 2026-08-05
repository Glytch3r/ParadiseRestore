-- Compatibility route for pre-refactor PZZoneEngine responses.
Events.OnServerCommand.Add(function(module, command, args)
    if module ~= "PZZoneEngine" or command ~= "rebound" or not args then return end
    if ParadiseDev and ParadiseDev.TP then ParadiseDev.TP.applyTeleport(getPlayer(), args.x, args.y, args.z) end
end)
