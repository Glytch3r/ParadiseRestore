ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}

function ParadiseDev.Zones.probe()
    sendClientCommand(ParadiseDev.Zones.MODULE, "probe", {})
end
