-- Debug-console API for PZZoneHarness_Test.
PZZoneHarness = PZZoneHarness or {}
local H = PZZoneHarness
H.MODULE = "PZZoneHarness"

local function request(command, args)
    sendClientCommand(H.MODULE, command, args or {})
end

function H.demoHere() request("demoHere") end
function H.clear() request("clear") end
function H.status() request("status") end
function H.vehicleObserve() request("vehicleMode", { mode = "observe" }) end
function H.vehicleRebound() request("vehicleMode", { mode = "rebound" }) end
function H.profileNone(username) request("profile", { username = username, profile = "none" }) end
function H.profilePve(username) request("profile", { username = username, profile = "pve" }) end
function H.profileRangeStaff(username) request("profile", { username = username, profile = "range_staff" }) end
function H.profileBoth(username) request("profile", { username = username, profile = "both" }) end

Events.OnServerCommand.Add(function(module, command, args)
    if module == H.MODULE and command == "result" then
        print("[PZZoneHarness] " .. tostring(args and args.text))
    end
end)

