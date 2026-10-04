ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.ReboundClient = ParadiseDev.Zones.ReboundClient or {}

function ParadiseDev.Zones.ReboundClient.onPlayerUpdate(pl)
    if not pl or not isClient or not isClient() or not sendClientCommand then return end
    -- Request pacing only: the server still performs every authority check.
    -- Weak player keys avoid retaining disconnected/replaced player objects.
    local state = ParadiseDev.Zones.ReboundClient
    state.requestTimes = state.requestTimes or setmetatable({}, { __mode = "k" })
    local now = getTimestampMs()
    local vehicle = pl:getVehicle()
    local x = vehicle and vehicle:getX() or pl:getX()
    local y = vehicle and vehicle:getY() or pl:getY()
    local z = pl:getZ()
    local last = state.requestTimes[pl]
    if last then
        local dx, dy = x - last.x, y - last.y
        if now >= last.time and now - last.time < 50 and
            vehicle == last.vehicle and z == last.z and dx * dx + dy * dy < 0.25 then return end
    end
    sendClientCommand(pl, "PZZoneEngine", "boundaryCheck", {})
    -- Reuse the entry; record only after the send succeeds.
    last = last or {}
    last.time, last.x, last.y, last.z, last.vehicle = now, x, y, z, vehicle
    state.requestTimes[pl] = last
end

function ParadiseDev.Zones.ReboundClient.onServerCommand(module, command, args)
    if module ~= "PZZoneEngine" or command ~= "rebound" or not args then return end
    if ParadiseDev and ParadiseDev.TP then ParadiseDev.TP.applyTeleport(getPlayer(), args.x, args.y, args.z) end
end

Events.OnServerCommand.Remove(ParadiseDev.Zones.ReboundClient.onServerCommand)
Events.OnServerCommand.Add(ParadiseDev.Zones.ReboundClient.onServerCommand)
Events.OnPlayerUpdate.Remove(ParadiseDev.Zones.ReboundClient.onPlayerUpdate)
Events.OnPlayerUpdate.Add(ParadiseDev.Zones.ReboundClient.onPlayerUpdate)
