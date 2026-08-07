ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.AdminTesting = ParadiseDev.Zones.AdminTesting or {}
local H = ParadiseDev.Zones.AdminTesting
local MODULE = "PZZoneHarness"

function H.reply(player, text)
    sendServerCommand(player, MODULE, "result", { text = text })
end

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= MODULE or command ~= "disableDemoAdminBypass" then return end
    if not player or player:getAccessLevel() ~= "admin" then return end

    local E = ParadiseDev.Zones.Engine
    if not E then
        H.reply(player, "PZZoneEngine_Test is not loaded.")
        return
    end

    local count = 0
    for _, zone in pairs(E.zones) do
        zone.policy.adminBypass = false
        count = count + 1
    end
    E.syncAllBoundaryStates()
    H.reply(player, "Admin bypass disabled for " .. tostring(count) .. " current test zones.")
end)
