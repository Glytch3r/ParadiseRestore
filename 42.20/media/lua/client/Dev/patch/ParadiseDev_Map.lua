ParadiseDev = ParadiseDev or {}
ParadiseDev.PlayerMapMaxZoom = ParadiseDev.PlayerMapMaxZoom or 18
ParadiseDev.Map = ParadiseDev.Map or {}
ParadiseDev.Map.zoneVisuals = ParadiseDev.Map.zoneVisuals ~= false
ParadiseDev.Map.coordinates = ParadiseDev.Map.coordinates ~= false


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

local function mapZoneColor(zone)
    if zone.features and zone.features.isKos then return 1.0, 0.15, 0.10 end
    if zone.restricted then return 1.0, 0.9, 0.10 end
    return 0.20, 1.0, 0.20
end

local function drawMapLine(self, x1, y1, x2, y2, r, g, b, a)
    local dx, dy = x2 - x1, y2 - y1
    local length = math.sqrt(dx * dx + dy * dy)
    if length <= 0 then return end
    local half = 1.0
    local nx, ny = -dy / length * half, dx / length * half
    getRenderer():renderPoly(x1 + nx, y1 + ny, x2 + nx, y2 + ny,
        x2 - nx, y2 - ny, x1 - nx, y1 - ny, r, g, b, a)
end

function ParadiseDev.Map.drawZoneBorders(self)
    if not ParadiseDev.Map.zoneVisuals then return end
    local visuals = ParadiseDev.Zones and ParadiseDev.Zones.Visualization
    if not visuals or not visuals.canRender(getSpecificPlayer(0)) then return end
    local mx, my = self:getMouseX(), self:getMouseY()
    local wx, wy = self.mapAPI:uiToWorldX(mx, my), self.mapAPI:uiToWorldY(mx, my)
    if not wx or not wy then return end
    local hoveredZone
    for _, zone in ipairs(visuals.zones or {}) do
        for _, region in ipairs(zone.regions or {}) do
            if visuals.regionContains(region, wx, wy) then hoveredZone = zone end
        end
    end

    for _, zone in ipairs(visuals.zones or {}) do
        for _, region in ipairs(zone.regions or {}) do
            local r, g, b = mapZoneColor(zone)
            local a = (zone == hoveredZone) and 0.85 or 0.30
            local x1 = self.mapAPI:worldToUIX(region.xMin, region.yMin)
            local y1 = self.mapAPI:worldToUIY(region.xMin, region.yMin)
            local x2 = self.mapAPI:worldToUIX(region.xMax, region.yMin)
            local y2 = self.mapAPI:worldToUIY(region.xMax, region.yMin)
            local x3 = self.mapAPI:worldToUIX(region.xMax, region.yMax)
            local y3 = self.mapAPI:worldToUIY(region.xMax, region.yMax)
            local x4 = self.mapAPI:worldToUIX(region.xMin, region.yMax)
            local y4 = self.mapAPI:worldToUIY(region.xMin, region.yMax)
            if x1 and y1 and x2 and y2 and x3 and y3 and x4 and y4 then
                drawMapLine(self, x1, y1, x2, y2, r, g, b, a)
                drawMapLine(self, x2, y2, x3, y3, r, g, b, a)
                drawMapLine(self, x3, y3, x4, y4, r, g, b, a)
                drawMapLine(self, x4, y4, x1, y1, r, g, b, a)
            end
        end
    end
end

function ParadiseDev.Map.drawCoordinates(self)
    if not ParadiseDev.Map.coordinates then return end
    local mx, my = self:getMouseX(), self:getMouseY()
    local wx, wy = self.mapAPI:uiToWorldX(mx, my), self.mapAPI:uiToWorldY(mx, my)
    if not wx or not wy then return end
    self:drawText("X: " .. tostring(math.floor(wx)) .. "  |  Y: " .. tostring(math.floor(wy)),
        mx + 14, my + 38, 1, 1, 1, 1, UIFont.Small)
end

local vanillaMapRender = ISWorldMap.render
ISWorldMap.render = function(self, ...)
    vanillaMapRender(self, ...)
    ParadiseDev.Map.drawZoneBorders(self)
    ParadiseDev.Map.drawCoordinates(self)
end

local vanillaMapRightMouseUp = ISWorldMap.onRightMouseUp
function ISWorldMap:onRightMouseUp(x, y)
    if self.symbolsUI and self.symbolsUI:onRightMouseUpMap(x, y) then return true end
    if vanillaMapRightMouseUp and vanillaMapRightMouseUp(self, x, y) == true then return true end
    local context = ISContextMenu.get(0, x + self:getAbsoluteX(), y + self:getAbsoluteY())
    if not context then return true end
    local option = context:addOption("Hide Zone Visuals", self, function()
        ParadiseDev.Map.zoneVisuals = not ParadiseDev.Map.zoneVisuals
    end)
    context:setOptionChecked(option, not ParadiseDev.Map.zoneVisuals)
    option = context:addOption("Hide Coordinates", self, function()
        ParadiseDev.Map.coordinates = not ParadiseDev.Map.coordinates
    end)
    context:setOptionChecked(option, not ParadiseDev.Map.coordinates)
    return true
end
