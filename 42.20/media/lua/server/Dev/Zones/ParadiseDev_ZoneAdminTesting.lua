ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.AdminTesting = ParadiseDev.Zones.AdminTesting or {}


ParadiseDev.Zones.AdminTesting.module = "PZZoneHarness"

function ParadiseDev.Zones.AdminTesting.reply(pl, text)
    sendServerCommand(pl, ParadiseDev.Zones.AdminTesting.module, "result", { text = text })
end

function ParadiseDev.Zones.AdminTesting.onClientCommand(module, command, pl, args)
    if module ~= ParadiseDev.Zones.AdminTesting.module or command ~= "disableDemoAdminBypass" then return end
    if not pl or not ParadiseDev.isAdm(pl) then return end

    if not ParadiseDev.Zones.Engine then
        ParadiseDev.Zones.AdminTesting.reply(pl, "PZZoneEngine_Test is not loaded.")
        return
    end

    local count = 0
    for _, zone in pairs(ParadiseDev.Zones.Engine.zones) do
        zone.policy.adminBypass = false
        count = count + 1
    end
    ParadiseDev.Zones.Engine.syncAllBoundaryStates()
    ParadiseDev.Zones.AdminTesting.reply(pl, "Admin bypass disabled for " .. tostring(count) .. " current test zones.")
end

Events.OnClientCommand.Remove(ParadiseDev.Zones.AdminTesting.onClientCommand)
Events.OnClientCommand.Add(ParadiseDev.Zones.AdminTesting.onClientCommand)
