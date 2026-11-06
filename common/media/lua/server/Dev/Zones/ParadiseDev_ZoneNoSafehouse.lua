require "Dev/Zones/ParadiseDev_ZoneNoSafehouse"
ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}

function ParadiseDev.Zones.NoSafe.onSafehousesChanged()
    local NoSafe = ParadiseDev.Zones.NoSafe
    if not NoSafe.authorityActive() or NoSafe.sweeping then return end
    local engine = ParadiseDev.Zones.Engine
    if not engine then return end
    NoSafe.lastSweep.zoneRevision = nil
    NoSafe.runSweep("safehouse change", engine, true)
end
Events.OnSafehousesChanged.Remove(ParadiseDev.Zones.NoSafe.onSafehousesChanged)
Events.OnSafehousesChanged.Add(ParadiseDev.Zones.NoSafe.onSafehousesChanged)

if ParadiseDev.Zones.Engine.save ~= ParadiseDev.Zones.NoSafe.wrappedSave then
    ParadiseDev.Zones.NoSafe.engineSaveHook = ParadiseDev.Zones.Engine.save
    function ParadiseDev.Zones.Engine.save()
        ParadiseDev.Zones.NoSafe.engineSaveHook()
        ParadiseDev.Zones.NoSafe.sweepOnZoneEdit()
    end
    ParadiseDev.Zones.NoSafe.wrappedSave = ParadiseDev.Zones.Engine.save
end
