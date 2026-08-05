-- Test-only visualization for server-published zone geometry.
PZZoneHarnessVisualization = PZZoneHarnessVisualization or {}
local V = PZZoneHarnessVisualization

V.enabled = V.enabled ~= false
V.zones = V.zones or {}
V.highlightedFloors = V.highlightedFloors or {}
V.lastRefreshX = V.lastRefreshX or nil
V.lastRefreshY = V.lastRefreshY or nil
V.lastRefreshZ = V.lastRefreshZ or nil
V.VISIBLE_RADIUS = 80
V.BAND_WIDTH = 2
V.OUTSIDE_COLOR = { r = 0.15, g = 0.55, b = 1.0, a = 0.35 }
V.INSIDE_COLOR = { r = 1.0, g = 0.35, b = 0.10, a = 0.35 }
V.BORDER_COLOR = { r = 1.0, g = 1.0, b = 0.20, a = 0.95 }

local function zoneOnLevel(zone, z)
    return zone.zMode == "all" or (z >= zone.zMin and z < zone.zMaxExclusive)
end

local function regionNearPlayer(region, player, radius)
    local x, y = player:getX(), player:getY()
    return x >= region.xMin - radius and x <= region.xMax + radius and
        y >= region.yMin - radius and y <= region.yMax + radius
end

local function clearHighlights()
    for _, floor in pairs(V.highlightedFloors) do
        if floor then floor:setHighlighted(false, false) end
    end
    V.highlightedFloors = {}
end

local function highlightSquare(x, y, z, color)
    local key = tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z)
    if V.highlightedFloors[key] then return end
    local square = getCell():getGridSquare(x, y, z)
    local floor = square and square:getFloor() or nil
    if not floor then return end
    floor:setHighlightColor(color.r, color.g, color.b, color.a)
    floor:setHighlighted(true, false)
    V.highlightedFloors[key] = floor
end

local function highlightHorizontal(x1, x2, y1, y2, z, color)
    if x2 < x1 or y2 < y1 then return end
    for x = x1, x2 do
        for y = y1, y2 do highlightSquare(x, y, z, color) end
    end
end

local function highlightVertical(x1, x2, y1, y2, z, color)
    if x2 < x1 or y2 < y1 then return end
    for x = x1, x2 do
        for y = y1, y2 do highlightSquare(x, y, z, color) end
    end
end

local function highlightRegion(region, z)
    local x1, y1 = math.floor(region.xMin), math.floor(region.yMin)
    local x2, y2 = math.floor(region.xMax) - 1, math.floor(region.yMax) - 1
    local width = V.BAND_WIDTH

    highlightHorizontal(x1 - width, x2 + width, y1 - width, y1 - 1, z, V.OUTSIDE_COLOR)
    highlightHorizontal(x1 - width, x2 + width, y2 + 1, y2 + width, z, V.OUTSIDE_COLOR)
    highlightVertical(x1 - width, x1 - 1, y1, y2, z, V.OUTSIDE_COLOR)
    highlightVertical(x2 + 1, x2 + width, y1, y2, z, V.OUTSIDE_COLOR)

    local insideWidth = math.min(width, math.floor((x2 - x1 + 1) / 2), math.floor((y2 - y1 + 1) / 2))
    if insideWidth < 1 then insideWidth = 1 end
    highlightHorizontal(x1, x2, y1, math.min(y2, y1 + insideWidth - 1), z, V.INSIDE_COLOR)
    highlightHorizontal(x1, x2, math.max(y1, y2 - insideWidth + 1), y2, z, V.INSIDE_COLOR)
    highlightVertical(x1, math.min(x2, x1 + insideWidth - 1), y1 + insideWidth, y2 - insideWidth, z, V.INSIDE_COLOR)
    highlightVertical(math.max(x1, x2 - insideWidth + 1), x2, y1 + insideWidth, y2 - insideWidth, z, V.INSIDE_COLOR)
end

function V.refreshHighlights(force)
    local player = getPlayer()
    if not player then return end
    local px, py, pz = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    if not force and V.lastRefreshZ == pz and V.lastRefreshX and
        math.abs(px - V.lastRefreshX) < 5 and math.abs(py - V.lastRefreshY) < 5 then
        return
    end
    V.lastRefreshX, V.lastRefreshY, V.lastRefreshZ = px, py, pz
    clearHighlights()
    if not V.enabled then return end

    for _, zone in ipairs(V.zones) do
        if zoneOnLevel(zone, pz) then
            for _, region in ipairs(zone.regions or {}) do
                if regionNearPlayer(region, player, V.VISIBLE_RADIUS) then
                    highlightRegion(region, pz)
                end
            end
        end
    end
end

function V.setEnabled(enabled)
    V.enabled = enabled == true
    V.refreshHighlights(true)
end

local function drawThinLine(x1, y1, x2, y2, color)
    local dx, dy = x2 - x1, y2 - y1
    local length = math.sqrt(dx * dx + dy * dy)
    if length <= 0 then return end
    local half = 0.75
    local nx, ny = -dy / length * half, dx / length * half
    getRenderer():renderPoly(
        x1 + nx, y1 + ny, x2 + nx, y2 + ny,
        x2 - nx, y2 - ny, x1 - nx, y1 - ny,
        color.r, color.g, color.b, color.a
    )
end

local function drawRegionBorder(region, z, color)
    local playerNum = 0
    local offsetX, offsetY = -getPlayerScreenLeft(playerNum), -getPlayerScreenTop(playerNum)
    local function screen(x, y)
        return isoToScreenX(playerNum, x, y, z) + offsetX,
            isoToScreenY(playerNum, x, y, z) + offsetY
    end
    local x1, y1 = screen(region.xMin, region.yMin)
    local x2, y2 = screen(region.xMax, region.yMin)
    local x3, y3 = screen(region.xMax, region.yMax)
    local x4, y4 = screen(region.xMin, region.yMax)
    drawThinLine(x1, y1, x2, y2, color)
    drawThinLine(x2, y2, x3, y3, color)
    drawThinLine(x3, y3, x4, y4, color)
    drawThinLine(x4, y4, x1, y1, color)
end

function V.renderBorders()
    if not V.enabled then return end
    local player = getPlayer()
    if not player then return end
    local z = math.floor(player:getZ())
    for _, zone in ipairs(V.zones) do
        if zoneOnLevel(zone, z) then
            for _, region in ipairs(zone.regions or {}) do
                if regionNearPlayer(region, player, V.VISIBLE_RADIUS) then
                    drawRegionBorder(region, z, V.BORDER_COLOR)
                end
            end
        end
    end
end

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= "PZZoneEngine" or command ~= "boundaryState" or not args then return end
    V.zones = args.zones or {}
    V.BAND_WIDTH = tonumber(args.borderWidth) or 2
    V.refreshHighlights(true)
end)

Events.OnPlayerMove.Add(function(player)
    if player == getPlayer() then V.refreshHighlights(false) end
end)
Events.OnPreUIDraw.Add(V.renderBorders)