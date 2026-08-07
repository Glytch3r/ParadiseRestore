ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
local H = ParadiseDev.Zones
if H then
    function H.probe()
        sendClientCommand(H.MODULE, "probe", {})
    end
end

