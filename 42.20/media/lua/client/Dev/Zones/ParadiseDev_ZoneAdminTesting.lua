ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.AdminTesting = ParadiseDev.Zones.AdminTesting or {}
ParadiseDev.Zones.AdminTesting.module = "PZZoneHarness"

function ParadiseDev.Zones.AdminTesting.enable()
    sendClientCommand(ParadiseDev.Zones.AdminTesting.module, "disableDemoAdminBypass", {})
end

ParadiseDev.Zones.enableAdminTesting = ParadiseDev.Zones.AdminTesting.enable
