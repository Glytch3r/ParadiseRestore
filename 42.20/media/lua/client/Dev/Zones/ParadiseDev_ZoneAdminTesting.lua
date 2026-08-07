ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
local H = ParadiseDev.Zones
if H then
    function H.enableAdminTesting()
        sendClientCommand(H.MODULE, "disableDemoAdminBypass", {})
    end
end

