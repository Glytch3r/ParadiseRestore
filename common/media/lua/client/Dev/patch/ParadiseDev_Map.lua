ParadiseDev = ParadiseDev or {}
ParadiseDev.PlayerMapMaxZoom = ParadiseDev.PlayerMapMaxZoom or 18
ParadiseDev.Map = ParadiseDev.Map or {}

require "ISUI/Maps/ISMiniMap"
require "Dev/patch/ParadiseDev_MapPreferences"
require "ISUI/ISToolTip"

ParadiseDev.Map.vanillaInstantiate = ParadiseDev.Map.vanillaInstantiate or ISWorldMap.instantiate

function ParadiseDev.Map.instantiate(self)
    ParadiseDev.Map.vanillaInstantiate(self)

    if not ParadiseRestore.isAdm() then
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

local function mapPlayer(map)
    local playerNum = map.playerNum or 0
    return getSpecificPlayer and getSpecificPlayer(playerNum) or getPlayer()
end

local function drawMapLine(map, x1, y1, x2, y2, r, g, b, a, half)
    local dx, dy = x2 - x1, y2 - y1
    local length = math.sqrt(dx * dx + dy * dy)
    if length <= 0 then return end
    local nx, ny = -dy / length * half, dx / length * half
    map:drawPolygon(nil, x1 + nx, y1 + ny, x2 + nx, y2 + ny,
        x2 - nx, y2 - ny, x1 - nx, y1 - ny, r, g, b, a)
end

-- Resolve overlapping map regions consistently: priority, segment area, then id.
-- Full-map selection spans its drawn floors; this is display, not access authority.
-- The tooltip name and bright border use the same winner.
function ParadiseDev.Map.getHoveredZone(wx, wy, pl, mini)
    local visuals = ParadiseDev.Zones and ParadiseDev.Zones.Visualization
    if not visuals or not visuals.zones or not wx or not wy or not pl then return nil end
    local winner, winnerPriority, winnerArea, winnerId
    local z = math.floor(pl:getZ())
    for _, zone in ipairs(visuals.zones) do
        if not mini or visuals.zoneOnLevel(zone, z) then
            for _, region in ipairs(zone.regions or {}) do
                if (not mini or visuals.regionNearPlayer(region, pl, visuals.VISIBLE_RADIUS))
                    and visuals.regionContains(region, wx, wy) then
                    local priority = tonumber(zone.priority) or 0
                    local area = (region.xMax - region.xMin) * (region.yMax - region.yMin)
                    local id = tostring(zone.id or "")
                    if not winner or priority > winnerPriority
                        or (priority == winnerPriority and area < winnerArea)
                        or (priority == winnerPriority and area == winnerArea and id < winnerId) then
                        winner, winnerPriority, winnerArea, winnerId = zone, priority, area, id
                    end
                end
            end
        end
    end
    return winner
end

local function drawZoneOverlay(map, mini)
    if not map or not map.mapAPI then return end
    local visuals = ParadiseDev.Zones and ParadiseDev.Zones.Visualization
    if not visuals or not visuals.zones then return end
    local pl = mapPlayer(map)
    if not pl then return end
    local prefs = ParadiseDev.MapPreferences.get(pl)
    if mini and not prefs.applyToMinimap then return end
    if not prefs.zoneVisibility and not prefs.zoneHighlight then return end
    if not visuals.canRenderMap or not visuals.canRenderMap(pl) then return end
    local width, height = map:getWidth(), map:getHeight()
    local mx, my = map:getMouseX(), map:getMouseY()
    local wx, wy, hoveredZone
    if mx >= 0 and my >= 0 and mx <= width and my <= height then
        wx, wy = map.mapAPI:uiToWorldX(mx, my), map.mapAPI:uiToWorldY(mx, my)
    end
    local z = math.floor(pl:getZ())
    local function visibleRegion(zone, region)
        return not mini or (visuals.zoneOnLevel(zone, z)
            and visuals.regionNearPlayer(region, pl, visuals.VISIBLE_RADIUS))
    end
    if prefs.zoneHighlight and wx and wy then
        hoveredZone = ParadiseDev.Map.getHoveredZone(wx, wy, pl, mini)
    end
    for _, zone in ipairs(visuals.zones) do
        for _, region in ipairs(zone.regions or {}) do
            if visibleRegion(zone, region) then
                local api = map.mapAPI
                local x1, y1 = api:worldToUIX(region.xMin, region.yMin), api:worldToUIY(region.xMin, region.yMin)
                local x2, y2 = api:worldToUIX(region.xMax, region.yMin), api:worldToUIY(region.xMax, region.yMin)
                local x3, y3 = api:worldToUIX(region.xMax, region.yMax), api:worldToUIY(region.xMax, region.yMax)
                local x4, y4 = api:worldToUIX(region.xMin, region.yMax), api:worldToUIY(region.xMin, region.yMax)
                if x1 and y1 and x2 and y2 and x3 and y3 and x4 and y4
                    and math.max(x1, x2, x3, x4) >= -2 and math.min(x1, x2, x3, x4) <= width + 2
                    and math.max(y1, y2, y3, y4) >= -2 and math.min(y1, y2, y3, y4) <= height + 2 then
                    local r, g, b = mapZoneColor(zone)
                    if prefs.zoneVisibility then
                        map:drawPolygon(nil, x1, y1, x2, y2, x3, y3, x4, y4, r, g, b, 0.11)
                    end
                    if prefs.zoneHighlight then
                        local a, half = zone == hoveredZone and 0.95 or 0.50, mini and 1.0 or 1.5
                        drawMapLine(map, x1, y1, x2, y2, r, g, b, a, half)
                        drawMapLine(map, x2, y2, x3, y3, r, g, b, a, half)
                        drawMapLine(map, x3, y3, x4, y4, r, g, b, a, half)
                        drawMapLine(map, x4, y4, x1, y1, r, g, b, a, half)
                    end
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

local function drawMinimapOverlays(map)
    drawZoneOverlay(map, true)
    drawSuspectMarkers(map)
    if ParadiseRestore and ParadiseRestore.DeadTracker then
        ParadiseRestore.DeadTracker.drawMapMarkers(map)
    end
end

local function withMapStencil(map, draw)
    local cx, cy, cw, ch = map:clampStencilRectToParent(0, 0, map:getWidth(), map:getHeight())
    local ok, err = pcall(draw, map)
    -- This stencil is shared with parent panels; restore it even if an overlay fails.
    map:clearStencilRect()
    map:repaintStencilRect(cx, cy, cw, ch)
    if not ok then error(err) end
end

if ISMiniMapInner and not ParadiseDev.Map.miniMapHooked then
    ParadiseDev.Map.miniMapHooked = true
    ParadiseDev.Map.miniMapRender = ISMiniMapInner.render
    function ISMiniMapInner:render(...)
        ParadiseDev.Map.miniMapRender(self, ...)
        withMapStencil(self, drawMinimapOverlays)
    end

end

function ParadiseDev.Map.drawZoneBorders(self)
    drawZoneOverlay(self, false)
end

function ParadiseDev.Map.drawCoordinates(self)
    if not ParadiseDev.MapPreferences.get(mapPlayer(self)).coordinates then return end
    local mx, my = self:getMouseX(), self:getMouseY()
    if mx < 0 or my < 0 or mx > self:getWidth() or my > self:getHeight() then return end
    local wx, wy = self.mapAPI:uiToWorldX(mx, my), self.mapAPI:uiToWorldY(mx, my)
    if not wx or not wy then return end
    local text = "X: " .. tostring(math.floor(wx)) .. "  |  Y: " .. tostring(math.floor(wy))
    local zone = ParadiseDev.Map.getHoveredZone(wx, wy, mapPlayer(self), false)
    if zone then
        -- Zone names are plain tooltip text, never map annotations/rich text.
        local name = tostring(zone.name or zone.id or ""):gsub("%c", " ")
        if name ~= "" then text = name .. "  |  " .. text end
    end
    self:drawText(text, mx + 14, my + 38, 1, 1, 1, 1, UIFont.Small)
end

function ParadiseDev.Map.addContextOptions(context, pl)
    local prefs = ParadiseDev.MapPreferences.get(pl)
    local function add(label, key, description)
        local option = context:addOption(label, pl, function(player)
            ParadiseDev.MapPreferences.toggle(key, player)
        end)
        context:setOptionChecked(option, prefs[key])
        local tooltip = ISToolTip:new()
        tooltip:initialise()
        tooltip:setDescription(description)
        option.toolTip = tooltip
    end
    add("Coordinate tool-tip", "coordinates", "Show coordinates and the hovered zone name on the full map.")
    add("Zone visibility", "zoneVisibility", "Light fill inside zones.")
    add("Zone highlight", "zoneHighlight", "Zone borders, brighter under the pointer.")
    add("Apply zone settings to mini-map", "applyToMinimap",
        "Show the same zone fill and borders on the mini-map; off hides its zone overlay.")
    if ParadiseRestore and ParadiseRestore.DeadTracker and ParadiseRestore.DeadTracker.isAdminViewer() then
        local option = context:addOption("Hide DeadTracker Dots", nil, ParadiseRestore.DeadTracker.toggleVisibility)
        context:setOptionChecked(option, not ParadiseRestore.DeadTracker.visible)
    end
end

local function callMapRightMouseUp(vanilla, map, x, y)
    -- Vanilla returns true both for a consumed symbols-tool click and an admin menu.
    -- Observe the single native tool dispatch, then restore the instance even if it fails.
    if not vanilla then return nil, false end
    local symbols = map.symbolsUI
    local original = symbols and symbols.onRightMouseUpMap
    if not original then return vanilla(map, x, y), false end
    local ownMethod, consumed = rawget(symbols, "onRightMouseUpMap"), false
    symbols.onRightMouseUpMap = function(self, ...)
        local result = original(self, ...)
        if result then consumed = true end
        return result
    end
    local ok, result = pcall(vanilla, map, x, y)
    symbols.onRightMouseUpMap = ownMethod
    if not ok then error(result) end
    return result, consumed
end

function ParadiseDev.Map.hookWorldMap()
    if ParadiseDev.Map.worldMapHooked then return end
    ParadiseDev.Map.worldMapHooked = true

    local vanillaMapRender = ISWorldMap.render
    ISWorldMap.render = function(self, ...)
        vanillaMapRender(self, ...)
        withMapStencil(self, ParadiseDev.Map.drawZoneBorders)
        ParadiseDev.Map.drawCoordinates(self)
        drawSuspectMarkers(self)
        if ParadiseRestore and ParadiseRestore.DeadTracker then
            ParadiseRestore.DeadTracker.drawMapMarkers(self)
        end
    end

    local vanillaMapRightMouseUp = ISWorldMap.onRightMouseUp
    function ISWorldMap:onRightMouseUp(x, y)
        local result, consumed = callMapRightMouseUp(vanillaMapRightMouseUp, self, x, y)
        if consumed then return result end
        local pl = getSpecificPlayer(0)
        if not pl then return result end
        local context
        if result == true then
            context = getPlayerContextMenu(0)
        else
            context = ISContextMenu.get(0, x + self:getAbsoluteX(), y + self:getAbsoluteY())
        end
        if not context then return result end
        ParadiseDev.Map.addContextOptions(context, pl)
        return true
    end
end

Events.OnCreatePlayer.Remove(ParadiseDev.Map.hookWorldMap)
Events.OnCreatePlayer.Add(ParadiseDev.Map.hookWorldMap)
