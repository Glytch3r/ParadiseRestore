ParadiseDev = ParadiseDev or {}
ParadiseDev.PlayerMapMaxZoom = ParadiseDev.PlayerMapMaxZoom or 18

-- B42 lets the world map keep zooming out far beyond useful gameplay space.
-- Leave admin maps unchanged, while players use the cap above.
local function isMapAdmin()
    if type(isAdmin) == "function" and isAdmin() then
        return true
    end

    return type(getAccessLevel) == "function" and getAccessLevel() == "admin"
end

local vanillaISWorldMapInstantiate = ISWorldMap.instantiate

function ISWorldMap:instantiate()
    vanillaISWorldMapInstantiate(self)

    if not isMapAdmin() then
        self.mapAPI:setMaxZoom(tonumber(ParadiseDev.PlayerMapMaxZoom) or 18)
    end
end
