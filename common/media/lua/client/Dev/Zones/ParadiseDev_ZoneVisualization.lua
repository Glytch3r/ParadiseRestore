ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.Visualization = ParadiseDev.Zones.Visualization or {}

ParadiseDev.Zones.Visualization.enabled = ParadiseDev.Zones.Visualization.enabled ~= false
ParadiseDev.Zones.Visualization.zones = ParadiseDev.Zones.Visualization.zones or {}
ParadiseDev.Zones.Visualization.boundaryStateReceived = ParadiseDev.Zones.Visualization.boundaryStateReceived or false
ParadiseDev.Zones.Visualization.boundaryStateRequestTick = 0
ParadiseDev.Zones.Visualization.VISIBLE_RADIUS = 80
ParadiseDev.Zones.Visualization.cagedZoneId = ParadiseDev.Zones.Visualization.cagedZoneId or nil

ParadiseDev.Zones.Visualization.MODDATA_KEY = "ParadiseZShowWorldZoneVisuals"
ParadiseDev.Zones.Visualization.FILL_ALPHA = 0.12
ParadiseDev.Zones.Visualization.STANDING_ALPHA = 0.22
ParadiseDev.Zones.Visualization.BORDER_ALPHA = 0.95

function ParadiseDev.Zones.Visualization.isEnabledForPlayer(pl)
    if not pl or not pl.getModData then return false end
    local value = pl:getModData()[ParadiseDev.Zones.Visualization.MODDATA_KEY]
    if value == nil then return true end
    return value == true
end

function ParadiseDev.Zones.Visualization.canRenderWorld(pl)
    if not ParadiseDev.Zones.Visualization.isEnabledForPlayer(pl) then return false end
    return ParadiseRestore.isAdm and ParadiseRestore.isAdm(pl) or false
end

function ParadiseDev.Zones.Visualization.canRenderMap(pl)
    -- Map zone overlays are available to every player. Personal map preferences
    -- control drawing; world highlights and zone access rules stay separate.
    return pl ~= nil
end

function ParadiseDev.Zones.Visualization.zoneOnLevel(zone, z)
    return zone.zMode == "all" or (z >= zone.zMin and z < zone.zMaxExclusive)
end

function ParadiseDev.Zones.Visualization.regionNearPlayer(region, pl, radius)
    local x, y = pl:getX(), pl:getY()
    return x >= region.xMin - radius and x <= region.xMax + radius and
        y >= region.yMin - radius and y <= region.yMax + radius
end

function ParadiseDev.Zones.Visualization.regionContains(region, x, y)
    return x >= region.xMin and x < region.xMax and y >= region.yMin and y < region.yMax
end

function ParadiseDev.Zones.Visualization.getRegionColors(zone, region, pl)
    local mapText = ParadiseDev.Zones.MapText
    local base = mapText and mapText.getZoneColor and mapText.getZoneColor(zone) or { r = 1.0, g = 0.9, b = 0.10 }
    local standing = ParadiseDev.Zones.Visualization.regionContains(region, pl:getX(), pl:getY())
    local alpha = standing and ParadiseDev.Zones.Visualization.STANDING_ALPHA or ParadiseDev.Zones.Visualization.FILL_ALPHA
    return { r = base.r, g = base.g, b = base.b, a = alpha },
        { r = base.r, g = base.g, b = base.b, a = ParadiseDev.Zones.Visualization.BORDER_ALPHA }
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

function ParadiseDev.Zones.Visualization.drawWorldArea(plNum, x1, y1, x2, y2, z, fill, border)
    if not fill and not border then return end
    local offsetX, offsetY = -getPlayerScreenLeft(plNum), -getPlayerScreenTop(plNum)
    local sx1, sy1 = isoToScreenX(plNum, x1, y1, z) + offsetX, isoToScreenY(plNum, x1, y1, z) + offsetY
    local sx2, sy2 = isoToScreenX(plNum, x2, y1, z) + offsetX, isoToScreenY(plNum, x2, y1, z) + offsetY
    local sx3, sy3 = isoToScreenX(plNum, x2, y2, z) + offsetX, isoToScreenY(plNum, x2, y2, z) + offsetY
    local sx4, sy4 = isoToScreenX(plNum, x1, y2, z) + offsetX, isoToScreenY(plNum, x1, y2, z) + offsetY
    local renderer = getRenderer()
    if fill then
        renderer:renderPoly(sx1, sy1, sx2, sy2, sx3, sy3, sx4, sy4, fill.r, fill.g, fill.b, fill.a)
    end
    if border then
        ParadiseDev.Zones.Visualization.drawThinLine(sx1, sy1, sx2, sy2, border)
        ParadiseDev.Zones.Visualization.drawThinLine(sx2, sy2, sx3, sy3, border)
        ParadiseDev.Zones.Visualization.drawThinLine(sx3, sy3, sx4, sy4, border)
        ParadiseDev.Zones.Visualization.drawThinLine(sx4, sy4, sx1, sy1, border)
    end
end

function ParadiseDev.Zones.Visualization.renderAreas()
    if not ParadiseDev.Zones.Visualization.enabled then return end
    local pl = getPlayer()
    if not pl then return end
    if not ParadiseDev.Zones.Visualization.canRenderWorld(pl) then return end
    local plNum, z = pl:getPlayerNum(), math.floor(pl:getZ())
    for _, zone in ipairs(ParadiseDev.Zones.Visualization.zones) do
        if ParadiseDev.Zones.Visualization.zoneOnLevel(zone, z) then
            for _, region in ipairs(zone.regions or {}) do
                if ParadiseDev.Zones.Visualization.regionNearPlayer(region, pl, ParadiseDev.Zones.Visualization.VISIBLE_RADIUS) then
                    local fill, border = ParadiseDev.Zones.Visualization.getRegionColors(zone, region, pl)
                    ParadiseDev.Zones.Visualization.drawWorldArea(plNum, region.xMin, region.yMin, region.xMax, region.yMax, z, fill, border)
                end
            end
        end
    end
end

function ParadiseDev.Zones.Visualization.setEnabled(enabled)
    ParadiseDev.Zones.Visualization.enabled = enabled == true
end

function ParadiseDev.Zones.Visualization.setPlayerEnabled(pl, enabled)
    if not pl or not ParadiseRestore.isAdm or not ParadiseRestore.isAdm(pl) then return end
    local modData = pl:getModData()
    modData[ParadiseDev.Zones.Visualization.MODDATA_KEY] = enabled == true
    if pl.transmitModData then pl:transmitModData() end
end

function ParadiseDev.Zones.Visualization.onServerCommand(module, command, args)
    if module ~= "PZZoneEngine" or command ~= "boundaryState" or not args then return end
    ParadiseDev.Zones.Visualization.boundaryStateReceived = true
    ParadiseDev.Zones.Visualization.zones = args.zones or {}
    ParadiseDev.Zones.Visualization.cagedZoneId = args.cagedZoneId
end

function ParadiseDev.Zones.Visualization.onPlayerUpdate(pl)
    if pl ~= getPlayer() then return end
    if isClient() and not ParadiseDev.Zones.Visualization.boundaryStateReceived then
        ParadiseDev.Zones.Visualization.boundaryStateRequestTick = ParadiseDev.Zones.Visualization.boundaryStateRequestTick + 1
        if ParadiseDev.Zones.Visualization.boundaryStateRequestTick >= 30 then
            ParadiseDev.Zones.Visualization.boundaryStateRequestTick = 0
            sendClientCommand("PZZoneEngine", "requestBoundaryState", {})
        end
    end
end

function ParadiseDev.Zones.Visualization.onGameStart()
    local pl = getPlayer()
    if pl then
        local modData = pl:getModData()
        if modData[ParadiseDev.Zones.Visualization.MODDATA_KEY] == nil then
            modData[ParadiseDev.Zones.Visualization.MODDATA_KEY] = true
            if pl.transmitModData then pl:transmitModData() end
        end
    end
    if isClient() then sendClientCommand("PZZoneEngine", "requestBoundaryState", {}) end
end

Events.OnServerCommand.Remove(ParadiseDev.Zones.Visualization.onServerCommand)
Events.OnServerCommand.Add(ParadiseDev.Zones.Visualization.onServerCommand)
--[[ Events.OnPlayerMove.Remove(ParadiseDev.Zones.Visualization.onPlayerMove)
Events.OnPlayerMove.Add(ParadiseDev.Zones.Visualization.onPlayerMove) ]]
Events.OnPlayerUpdate.Remove(ParadiseDev.Zones.Visualization.onPlayerUpdate)
Events.OnPlayerUpdate.Add(ParadiseDev.Zones.Visualization.onPlayerUpdate)
Events.OnGameStart.Remove(ParadiseDev.Zones.Visualization.onGameStart)
Events.OnGameStart.Add(ParadiseDev.Zones.Visualization.onGameStart)
Events.OnPreUIDraw.Remove(ParadiseDev.Zones.Visualization.renderAreas)
Events.OnPreUIDraw.Add(ParadiseDev.Zones.Visualization.renderAreas)
