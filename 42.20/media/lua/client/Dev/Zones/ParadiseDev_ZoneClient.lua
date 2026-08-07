ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
local H = ParadiseDev.Zones
H.MODULE = "PZZoneHarness"

function H.request(command, args)
    sendClientCommand(H.MODULE, command, args or {})
end

function H.demoHere() H.request("demoHere") end
function H.clear() H.request("clear") end
function H.status() H.request("status") end
function H.vehicleObserve() H.request("vehicleMode", { mode = "observe" }) end
function H.vehicleRebound() H.request("vehicleMode", { mode = "rebound" }) end
function H.profileNone(username) H.request("profile", { username = username, profile = "none" }) end
function H.profilePve(username) H.request("profile", { username = username, profile = "pve" }) end
function H.profileRangeStaff(username) H.request("profile", { username = username, profile = "range_staff" }) end
function H.profileBoth(username) H.request("profile", { username = username, profile = "both" }) end

Events.OnServerCommand.Add(function(module, command, args)
    if module == H.MODULE and command == "result" then
        print("[PZZoneHarness] " .. tostring(args and args.text))
    end
end)

