ParadiseDev = ParadiseDev or {}
ParadiseDev.PlayerMapMaxZoom = ParadiseDev.PlayerMapMaxZoom or 18
ParadiseDev.Map = ParadiseDev.Map or {}
ParadiseDev.Map.zoneVisuals = ParadiseDev.Map.zoneVisuals ~= false
ParadiseDev.Map.coordinates = ParadiseDev.Map.coordinates ~= false

require "ISUI/Maps/ISMiniMap"

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
    local mapText = ParadiseDev.Zones and ParadiseDev.Zones.MapText
    local color = mapText and mapText.getZoneColor and mapText.getZoneColor(zone)
    if color then return color.r, color.g, color.b end
    return 0.03, 0.55, 0.03
end

local function drawMinimapZoneBorders(minimap)
    if not minimap or not minimap.mapAPI then return end
    local visuals = ParadiseDev.Zones and ParadiseDev.Zones.Visualization
    if not visuals or not visuals.zones then return end
    local pl = getSpecificPlayer and getSpecificPlayer(minimap.playerNum) or getPlayer()
    if not pl then return end
    local z = math.floor(pl:getZ())
    for _, zone in ipairs(visuals.zones) do
        if visuals.zoneOnLevel(zone, z) then
            for _, region in ipairs(zone.regions or {}) do
                if visuals.regionNearPlayer(region, pl, visuals.VISIBLE_RADIUS) then
                    local r, g, b = mapZoneColor(zone)
                    local function line(x1, y1, x2, y2)
                        local sx1, sy1 = minimap.mapAPI:worldToUIX(x1, y1), minimap.mapAPI:worldToUIY(x1, y1)
                        local sx2, sy2 = minimap.mapAPI:worldToUIX(x2, y2), minimap.mapAPI:worldToUIY(x2, y2)
                        if sx1 and sy1 and sx2 and sy2 then
                            local dx, dy = sx2 - sx1, sy2 - sy1
                            local length = math.sqrt(dx * dx + dy * dy)
                            if length > 0 then
                                local half = 1.0
                                local nx, ny = -dy / length * half, dx / length * half
                                getRenderer():renderPoly(sx1 + nx, sy1 + ny, sx2 + nx, sy2 + ny,
                                    sx2 - nx, sy2 - ny, sx1 - nx, sy1 - ny, r, g, b, 0.75)
                            end
                        end
                    end
                    line(region.xMin, region.yMin, region.xMax, region.yMin)
                    line(region.xMax, region.yMin, region.xMax, region.yMax)
                    line(region.xMax, region.yMax, region.xMin, region.yMax)
                    line(region.xMin, region.yMax, region.xMin, region.yMin)
                end
            end
        end
    end
end

local function isSuspectMarkerViewer()
    local pl = getPlayer and getPlayer() or nil
    return ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(pl) or false
end

local function getSuspectPlayers()
    local result = {}
    local cell = getCell and getCell() or nil
    local objects = cell and cell:getObjectListForLua() or nil
    if not objects then return result end
    for index = 0, objects:size() - 1 do
        local target = objects:get(index)
        local role = target and target.getRole and target:getRole() or nil
        if target and instanceof(target, "IsoPlayer") and role and string.lower(tostring(role:getName())) == "suspect" then
            result[#result + 1] = target
        end
    end
    return result
end

local function drawSuspectCircle(api, target, radius, alpha)
    local function line(x1, y1, x2, y2)
        local dx, dy = x2 - x1, y2 - y1
        local length = math.sqrt(dx * dx + dy * dy)
        if length <= 0 then return end
        local half = 1.5
        local nx, ny = -dy / length * half, dx / length * half
        getRenderer():renderPoly(x1 + nx, y1 + ny, x2 + nx, y2 + ny,
            x2 - nx, y2 - ny, x1 - nx, y1 - ny, 1, 0, 0, alpha)
    end
    local x, y = target:getX(), target:getY()
    local cx, cy = api:worldToUIX(x, y), api:worldToUIY(x, y)
    local px = api:worldToUIX(x + radius, y)
    if not cx or not cy or not px then return end
    local screenRadius = math.abs(px - cx)
    if screenRadius < 2 then screenRadius = 2 end
    local lastX, lastY = cx + screenRadius, cy
    for index = 1, 24 do
        local angle = (math.pi * 2 * index) / 24
        local nextX = cx + math.cos(angle) * screenRadius
        local nextY = cy + math.sin(angle) * screenRadius
        line(lastX, lastY, nextX, nextY)
        lastX, lastY = nextX, nextY
    end
end

local function drawSuspectMarkers(map)
    if not map or not map.mapAPI or not isSuspectMarkerViewer() then return end
    for _, target in ipairs(getSuspectPlayers()) do
        drawSuspectCircle(map.mapAPI, target, 4, 0.9)
    end
end

if ISMiniMapOuter and not ParadiseDev.Map.miniMapHooked then
    ParadiseDev.Map.miniMapHooked = true
    ParadiseDev.Map.miniMapRender = ISMiniMapOuter.render
    function ISMiniMapOuter:render(...)
        ParadiseDev.Map.miniMapRender(self, ...)
        drawMinimapZoneBorders(self)
        drawSuspectMarkers(self)
    end
end

local function drawMapLine(self, x1, y1, x2, y2, r, g, b, a)
    local dx, dy = x2 - x1, y2 - y1
    local length = math.sqrt(dx * dx + dy * dy)
    if length <= 0 then return end
    local half = 1.5
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
            local a = (zone == hoveredZone) and 0.95 or 0.50
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

function ParadiseDev.Map.hookWorldMap()
    if ParadiseDev.Map.worldMapHooked then return end
    ParadiseDev.Map.worldMapHooked = true

    local vanillaMapRender = ISWorldMap.render
    ISWorldMap.render = function(self, ...)
        vanillaMapRender(self, ...)
        ParadiseDev.Map.drawZoneBorders(self)
        ParadiseDev.Map.drawCoordinates(self)
        drawSuspectMarkers(self)
    end

    local vanillaMapRightMouseUp = ISWorldMap.onRightMouseUp
    function ISWorldMap:onRightMouseUp(x, y)
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
end

Events.OnCreatePlayer.Remove(ParadiseDev.Map.hookWorldMap)
Events.OnCreatePlayer.Add(ParadiseDev.Map.hookWorldMap)
