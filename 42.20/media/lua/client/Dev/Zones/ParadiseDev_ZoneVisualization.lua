ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.Visualization = ParadiseDev.Zones.Visualization or {}

ParadiseDev.Zones.Visualization.enabled = ParadiseDev.Zones.Visualization.enabled ~= false
ParadiseDev.Zones.Visualization.zones = ParadiseDev.Zones.Visualization.zones or {}
ParadiseDev.Zones.Visualization.highlightedFloors = ParadiseDev.Zones.Visualization.highlightedFloors or {}
ParadiseDev.Zones.Visualization.lastRefreshX = ParadiseDev.Zones.Visualization.lastRefreshX or nil
ParadiseDev.Zones.Visualization.lastRefreshY = ParadiseDev.Zones.Visualization.lastRefreshY or nil
ParadiseDev.Zones.Visualization.lastRefreshZ = ParadiseDev.Zones.Visualization.lastRefreshZ or nil
ParadiseDev.Zones.Visualization.VISIBLE_RADIUS = 80
ParadiseDev.Zones.Visualization.BAND_WIDTH = 2
ParadiseDev.Zones.Visualization.OUTSIDE_COLOR = { r = 0.15, g = 0.55, b = 1.0, a = 0.35 }
ParadiseDev.Zones.Visualization.INSIDE_COLOR = { r = 1.0, g = 0.35, b = 0.10, a = 0.35 }
ParadiseDev.Zones.Visualization.BORDER_COLOR = { r = 1.0, g = 1.0, b = 0.20, a = 0.95 }

function ParadiseDev.Zones.Visualization.zoneOnLevel(zone, z)
    return zone.zMode == "all" or (z >= zone.zMin and z < zone.zMaxExclusive)
end

function ParadiseDev.Zones.Visualization.regionNearPlayer(region, pl, radius)
    local x, y = pl:getX(), pl:getY()
    return x >= region.xMin - radius and x <= region.xMax + radius and
        y >= region.yMin - radius and y <= region.yMax + radius
end

function ParadiseDev.Zones.Visualization.clearHighlights()
    for _, floor in pairs(ParadiseDev.Zones.Visualization.highlightedFloors) do
        if floor then floor:setHighlighted(false, false) end
    end
    ParadiseDev.Zones.Visualization.highlightedFloors = {}
end

function ParadiseDev.Zones.Visualization.highlightSquare(x, y, z, color)
    local key = tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z)
    if ParadiseDev.Zones.Visualization.highlightedFloors[key] then return end
    local sq = getCell():getGridSquare(x, y, z)
    local floor = sq and sq:getFloor() or nil
    if not floor then return end
    floor:setHighlightColor(color.r, color.g, color.b, color.a)
    floor:setHighlighted(true, false)
    ParadiseDev.Zones.Visualization.highlightedFloors[key] = floor
end

function ParadiseDev.Zones.Visualization.highlightHorizontal(x1, x2, y1, y2, z, color)
    if x2 < x1 or y2 < y1 then return end
    for x = x1, x2 do
        for y = y1, y2 do ParadiseDev.Zones.Visualization.highlightSquare(x, y, z, color) end
    end
end

function ParadiseDev.Zones.Visualization.highlightVertical(x1, x2, y1, y2, z, color)
    if x2 < x1 or y2 < y1 then return end
    for x = x1, x2 do
        for y = y1, y2 do ParadiseDev.Zones.Visualization.highlightSquare(x, y, z, color) end
    end
end

function ParadiseDev.Zones.Visualization.highlightRegion(region, z)
    local x1, y1 = math.floor(region.xMin), math.floor(region.yMin)
    local x2, y2 = math.floor(region.xMax) - 1, math.floor(region.yMax) - 1
    local width = ParadiseDev.Zones.Visualization.BAND_WIDTH

    ParadiseDev.Zones.Visualization.highlightHorizontal(x1 - width, x2 + width, y1 - width, y1 - 1, z, ParadiseDev.Zones.Visualization.OUTSIDE_COLOR)
    ParadiseDev.Zones.Visualization.highlightHorizontal(x1 - width, x2 + width, y2 + 1, y2 + width, z, ParadiseDev.Zones.Visualization.OUTSIDE_COLOR)
    ParadiseDev.Zones.Visualization.highlightVertical(x1 - width, x1 - 1, y1, y2, z, ParadiseDev.Zones.Visualization.OUTSIDE_COLOR)
    ParadiseDev.Zones.Visualization.highlightVertical(x2 + 1, x2 + width, y1, y2, z, ParadiseDev.Zones.Visualization.OUTSIDE_COLOR)

    local insideWidth = math.min(width, math.floor((x2 - x1 + 1) / 2), math.floor((y2 - y1 + 1) / 2))
    if insideWidth < 1 then insideWidth = 1 end
    ParadiseDev.Zones.Visualization.highlightHorizontal(x1, x2, y1, math.min(y2, y1 + insideWidth - 1), z, ParadiseDev.Zones.Visualization.INSIDE_COLOR)
    ParadiseDev.Zones.Visualization.highlightHorizontal(x1, x2, math.max(y1, y2 - insideWidth + 1), y2, z, ParadiseDev.Zones.Visualization.INSIDE_COLOR)
    ParadiseDev.Zones.Visualization.highlightVertical(x1, math.min(x2, x1 + insideWidth - 1), y1 + insideWidth, y2 - insideWidth, z, ParadiseDev.Zones.Visualization.INSIDE_COLOR)
    ParadiseDev.Zones.Visualization.highlightVertical(math.max(x1, x2 - insideWidth + 1), x2, y1 + insideWidth, y2 - insideWidth, z, ParadiseDev.Zones.Visualization.INSIDE_COLOR)
end

function ParadiseDev.Zones.Visualization.refreshHighlights(force)
    local pl = getPlayer()
    if not pl then return end
    local px, py, pz = math.floor(pl:getX()), math.floor(pl:getY()), math.floor(pl:getZ())
    if not force and ParadiseDev.Zones.Visualization.lastRefreshZ == pz and ParadiseDev.Zones.Visualization.lastRefreshX and
        math.abs(px - ParadiseDev.Zones.Visualization.lastRefreshX) < 5 and math.abs(py - ParadiseDev.Zones.Visualization.lastRefreshY) < 5 then
        return
    end
    ParadiseDev.Zones.Visualization.lastRefreshX, ParadiseDev.Zones.Visualization.lastRefreshY, ParadiseDev.Zones.Visualization.lastRefreshZ = px, py, pz
    ParadiseDev.Zones.Visualization.clearHighlights()
    if not ParadiseDev.Zones.Visualization.enabled then return end

    for _, zone in ipairs(ParadiseDev.Zones.Visualization.zones) do
        if ParadiseDev.Zones.Visualization.zoneOnLevel(zone, pz) then
            for _, region in ipairs(zone.regions or {}) do
                if ParadiseDev.Zones.Visualization.regionNearPlayer(region, pl, ParadiseDev.Zones.Visualization.VISIBLE_RADIUS) then
                    ParadiseDev.Zones.Visualization.highlightRegion(region, pz)
                end
            end
        end
    end
end

function ParadiseDev.Zones.Visualization.setEnabled(enabled)
    ParadiseDev.Zones.Visualization.enabled = enabled == true
    ParadiseDev.Zones.Visualization.refreshHighlights(true)
end

function ParadiseDev.Zones.Visualization.drawThinLine(x1, y1, x2, y2, color)
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

function ParadiseDev.Zones.Visualization.drawRegionBorder(region, z, color)
    local plNum = 0
    local offsetX, offsetY = -getPlayerScreenLeft(plNum), -getPlayerScreenTop(plNum)
    function ParadiseDev.Zones.Visualization.screen(x, y)
        return isoToScreenX(plNum, x, y, z) + offsetX,
            isoToScreenY(plNum, x, y, z) + offsetY
    end
    local x1, y1 = ParadiseDev.Zones.Visualization.screen(region.xMin, region.yMin)
    local x2, y2 = ParadiseDev.Zones.Visualization.screen(region.xMax, region.yMin)
    local x3, y3 = ParadiseDev.Zones.Visualization.screen(region.xMax, region.yMax)
    local x4, y4 = ParadiseDev.Zones.Visualization.screen(region.xMin, region.yMax)
    ParadiseDev.Zones.Visualization.drawThinLine(x1, y1, x2, y2, color)
    ParadiseDev.Zones.Visualization.drawThinLine(x2, y2, x3, y3, color)
    ParadiseDev.Zones.Visualization.drawThinLine(x3, y3, x4, y4, color)
    ParadiseDev.Zones.Visualization.drawThinLine(x4, y4, x1, y1, color)
end

function ParadiseDev.Zones.Visualization.renderBorders()
    if not ParadiseDev.Zones.Visualization.enabled then return end
    local pl = getPlayer()
    if not pl then return end
    local z = math.floor(pl:getZ())
    for _, zone in ipairs(ParadiseDev.Zones.Visualization.zones) do
        if ParadiseDev.Zones.Visualization.zoneOnLevel(zone, z) then
            for _, region in ipairs(zone.regions or {}) do
                if ParadiseDev.Zones.Visualization.regionNearPlayer(region, pl, ParadiseDev.Zones.Visualization.VISIBLE_RADIUS) then
                    ParadiseDev.Zones.Visualization.drawRegionBorder(region, z, ParadiseDev.Zones.Visualization.BORDER_COLOR)
                end
            end
        end
    end
end

function ParadiseDev.Zones.Visualization.onServerCommand(module, command, args)
    if module ~= "PZZoneEngine" or command ~= "boundaryState" or not args then return end
    ParadiseDev.Zones.Visualization.zones = args.zones or {}
    ParadiseDev.Zones.Visualization.BAND_WIDTH = tonumber(args.borderWidth) or 2
    ParadiseDev.Zones.Visualization.refreshHighlights(true)
end

function ParadiseDev.Zones.Visualization.onPlayerMove(pl)
    if pl == getPlayer() then ParadiseDev.Zones.Visualization.refreshHighlights(false) end
end

Events.OnServerCommand.Remove(ParadiseDev.Zones.Visualization.onServerCommand)
Events.OnServerCommand.Add(ParadiseDev.Zones.Visualization.onServerCommand)
Events.OnPlayerMove.Remove(ParadiseDev.Zones.Visualization.onPlayerMove)
Events.OnPlayerMove.Add(ParadiseDev.Zones.Visualization.onPlayerMove)
Events.OnPreUIDraw.Remove(ParadiseDev.Zones.Visualization.renderBorders)
Events.OnPreUIDraw.Add(ParadiseDev.Zones.Visualization.renderBorders)
