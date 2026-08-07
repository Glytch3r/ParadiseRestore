ParadiseDev = ParadiseDev or {}
ParadiseDev.PlayerMapMaxZoom = ParadiseDev.PlayerMapMaxZoom or 18
ParadiseDev.Map = ParadiseDev.Map or {}

require "Dev/ParadiseDev_Players"

ParadiseDev.Map.vanillaInstantiate = ParadiseDev.Map.vanillaInstantiate or ISWorldMap.instantiate

function ParadiseDev.Map.instantiate(self)
    ParadiseDev.Map.vanillaInstantiate(self)

    if not ParadiseDev.isAdm() then
        self.mapAPI:setMaxZoom(tonumber(ParadiseDev.PlayerMapMaxZoom) or 18)
    end
end

function ISWorldMap:instantiate()
    ParadiseDev.Map.instantiate(self)
end
