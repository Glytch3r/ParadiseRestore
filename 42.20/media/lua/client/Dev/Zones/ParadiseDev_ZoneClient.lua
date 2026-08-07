ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.MODULE = "PZZoneHarness"

function ParadiseDev.Zones.request(command, args)
    sendClientCommand(ParadiseDev.Zones.MODULE, command, args or {})
end

function ParadiseDev.Zones.demoHere() ParadiseDev.Zones.request("demoHere") end
function ParadiseDev.Zones.clear() ParadiseDev.Zones.request("clear") end
function ParadiseDev.Zones.status() ParadiseDev.Zones.request("status") end
function ParadiseDev.Zones.vehicleObserve() ParadiseDev.Zones.request("vehicleMode", { mode = "observe" }) end
function ParadiseDev.Zones.vehicleRebound() ParadiseDev.Zones.request("vehicleMode", { mode = "rebound" }) end
function ParadiseDev.Zones.profileNone(username) ParadiseDev.Zones.request("profile", { username = username, profile = "none" }) end
function ParadiseDev.Zones.profilePve(username) ParadiseDev.Zones.request("profile", { username = username, profile = "pve" }) end
function ParadiseDev.Zones.profileRangeStaff(username) ParadiseDev.Zones.request("profile", { username = username, profile = "range_staff" }) end
function ParadiseDev.Zones.profileBoth(username) ParadiseDev.Zones.request("profile", { username = username, profile = "both" }) end

function ParadiseDev.Zones.onServerCommand(module, command, args)
    if module == ParadiseDev.Zones.MODULE and command == "result" then
        print("[PZZoneHarness] " .. tostring(args and args.text))
    end
end

Events.OnServerCommand.Remove(ParadiseDev.Zones.onServerCommand)
Events.OnServerCommand.Add(ParadiseDev.Zones.onServerCommand)
