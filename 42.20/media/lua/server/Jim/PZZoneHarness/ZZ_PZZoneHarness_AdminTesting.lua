-- Admins normally bypass test-zone policy.  This separate test-only command
-- disables that bypass on the current demo zones so the admin can exercise
-- simulated PvE/range-staff profiles on their own character.
local MODULE = "PZZoneHarness"

local function reply(player, text)
    sendServerCommand(player, MODULE, "result", { text = text })
end

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= MODULE or command ~= "disableDemoAdminBypass" then return end
    if not player or player:getAccessLevel() ~= "admin" then return end

    local E = rawget(_G, "PZZoneEngine")
    if not E then
        reply(player, "PZZoneEngine_Test is not loaded.")
        return
    end

    local count = 0
    for _, zone in pairs(E.zones) do
        zone.policy.adminBypass = false
        count = count + 1
    end
    E.syncAllBoundaryStates()
    reply(player, "Admin bypass disabled for " .. tostring(count) .. " current test zones.")
end)
