ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.MapText = ParadiseDev.Zones.MapText or {}

require "ISUI/Maps/ISWorldMap"

ParadiseDev.Zones.MapText.enabled = ParadiseDev.Zones.MapText.enabled ~= false
ParadiseDev.Zones.MapText.layer = "text-place"
ParadiseDev.Zones.MapText.scale = 0.6
ParadiseDev.Zones.MapText.minZoom = 0
ParadiseDev.Zones.MapText.maxZoom = 24
ParadiseDev.Zones.MapText.refreshTicks = 30
ParadiseDev.Zones.MapText.zones = ParadiseDev.Zones.MapText.zones or {}
ParadiseDev.Zones.MapText.labels = ParadiseDev.Zones.MapText.labels or {}
ParadiseDev.Zones.MapText.api = ParadiseDev.Zones.MapText.api or nil
ParadiseDev.Zones.MapText.dirty = true
ParadiseDev.Zones.MapText.tick = 0
ParadiseDev.Zones.MapText.hoveredZone = nil

ParadiseDev.Zones.MapText.featureColors = {
    isKos = { r = 0.9, g = 0.2, b = 0.2 },
    isPvE = { r = 0.0, g = 1.0, b = 0.0 },
    isBlocked = { r = 0.13, g = 0.13, b = 0.13 },
    isSafe = { r = 0.84, g = 0.76, b = 0.67 },
    isRad = { r = 1.0, g = 1.0, b = 1.0 },
    isHunt = { r = 1.0, g = 0.0, b = 0.0 },
    isBlaze = { r = 1.0, g = 0.0, b = 0.0 },
    isFrost = { r = 0.5, g = 0.4, b = 1.0 },
    isBomb = { r = 1.0, g = 0.0, b = 0.0 },
    isMine = { r = 1.0, g = 0.0, b = 0.0 },
    isNoCamp = { r = 0.7, g = 0.7, b = 0.7 },
    isNoFire = { r = 0.8, g = 0.8, b = 0.8 },
    isCage = { r = 0.7, g = 0.7, b = 0.7 },
    isParty = { r = 1.0, g = 1.0, b = 0.6 },
    isRally = { r = 0.0, g = 1.0, b = 0.0 },
    isSpecial = { r = 0.9, g = 0.4, b = 0.9 },
    isTrade = { r = 0.0, g = 1.0, b = 0.0 },
    isSprint = { r = 1.0, g = 0.7, b = 0.7 },
}
ParadiseDev.Zones.MapText.hoverColor = { r = 0.2, g = 0.85, b = 1.0 }

ParadiseDev.Zones.MapText.featureOrder = {
    "isKos", "isPvE", "isBlocked", "isSafe", "isRad", "isHunt", "isBlaze", "isFrost", "isBomb", "isMine",
    "isNoCamp", "isNoFire", "isCage", "isParty", "isRally", "isSpecial", "isTrade", "isSprint",
}

function ParadiseDev.Zones.MapText.getZoneColor(zone)
    for _, key in ipairs(ParadiseDev.Zones.MapText.featureOrder) do
        if zone.features and zone.features[key] then return ParadiseDev.Zones.MapText.featureColors[key] end
    end
    return { r = 1.0, g = 0.9, b = 0.1 }
end

function ParadiseDev.Zones.MapText.drawZone(map, zone, region, worldX, worldY)
    local xMin, yMin = tonumber(region.xMin), tonumber(region.yMin)
    local xMax, yMax = tonumber(region.xMax), tonumber(region.yMax)
    if not xMin or not yMin or not xMax or not yMax or xMax <= xMin or yMax <= yMin then return end
    local color = ParadiseDev.Zones.MapText.getZoneColor(zone)
    local hovered = worldX and worldY and worldX >= xMin and worldX < xMax and worldY >= yMin and worldY < yMax
    if hovered then color = ParadiseDev.Zones.MapText.hoverColor end
    local fillAlpha = 0.05
    local borderAlpha = 0.4
    local borderWidth = 1
    if map.mapAPI:getBoolean("Isometric") then
        local x1y1x = map.mapAPI:worldToUIX(xMin, yMin)
        local x1y1y = map.mapAPI:worldToUIY(xMin, yMin)
        local x2y1x = map.mapAPI:worldToUIX(xMax, yMin)
        local x2y1y = map.mapAPI:worldToUIY(xMax, yMin)
        local x1y2x = map.mapAPI:worldToUIX(xMin, yMax)
        local x1y2y = map.mapAPI:worldToUIY(xMin, yMax)
        local x2y2x = map.mapAPI:worldToUIX(xMax, yMax)
        local x2y2y = map.mapAPI:worldToUIY(xMax, yMax)
        if not x1y1x or not x1y1y or not x2y1x or not x2y1y or not x1y2x or not x1y2y or not x2y2x or not x2y2y then return end
        getRenderer():renderPoly(x1y1x, x1y1y, x2y1x, x2y1y, x2y2x, x2y2y, x1y2x, x1y2y, color.r, color.g, color.b, fillAlpha)
        for index = 1, borderWidth do
            local offset = index * 0.5
            getRenderer():renderPoly(x1y1x - offset, x1y1y - offset, x2y1x + offset, x2y1y - offset, x2y2x + offset, x2y2y + offset, x1y2x - offset, x1y2y + offset, color.r, color.g, color.b, borderAlpha)
        end
    else
        local x1 = map.mapAPI:worldToUIX(xMin, yMin)
        local y1 = map.mapAPI:worldToUIY(xMin, yMin)
        local x2 = map.mapAPI:worldToUIX(xMax, yMax)
        local y2 = map.mapAPI:worldToUIY(xMax, yMax)
        if not x1 or not y1 or not x2 or not y2 then return end
        map:drawRect(x1, y1, x2 - x1, y2 - y1, fillAlpha, color.r, color.g, color.b)
        for index = 1, borderWidth do
            map:drawRectBorder(x1 - index, y1 - index, x2 - x1 + index * 2, y2 - y1 + index * 2, borderAlpha, color.r, color.g, color.b)
        end
    end
    if hovered then ParadiseDev.Zones.MapText.hoveredZone = zone.name or zone.id end
end

function ParadiseDev.Zones.MapText.drawWorldMap(map)
    if not ParadiseDev.Zones.MapText.enabled or not map or not map.mapAPI then return end
    local mouseX, mouseY = map:getMouseX(), map:getMouseY()
    local worldX = map.mapAPI:uiToWorldX(mouseX, mouseY)
    local worldY = map.mapAPI:uiToWorldY(mouseX, mouseY)
    ParadiseDev.Zones.MapText.hoveredZone = nil
    for _, zone in ipairs(ParadiseDev.Zones.MapText.zones) do
        for _, region in ipairs(zone.regions or {}) do
            ParadiseDev.Zones.MapText.drawZone(map, zone, region, worldX, worldY)
        end
    end
    if ParadiseDev.Zones.MapText.hoveredZone then
        map:drawText(ParadiseDev.Zones.MapText.hoveredZone, mouseX + 12, mouseY + 12, 1, 1, 1, 1, UIFont.Medium)
    end
end

if not ParadiseDev.Zones.MapText.worldMapHooked then
    ParadiseDev.Zones.MapText.worldMapHooked = true
    ParadiseDev.Zones.MapText.worldMapRender = ISWorldMap.render
    function ISWorldMap:render(...)
        ParadiseDev.Zones.MapText.worldMapRender(self, ...)
        ParadiseDev.Zones.MapText.drawWorldMap(self)
    end
end

function ParadiseDev.Zones.MapText.getSymbolsAPI()
    local map = ISWorldMap_instance
    local mapAPI = map and map.mapAPI or nil
    if not mapAPI and map and map.javaObject and map.javaObject.getAPIv3 then mapAPI = map.javaObject:getAPIv3() end
    if not mapAPI or not mapAPI.getSymbolsAPIv2 then return nil end
    return mapAPI:getSymbolsAPIv2()
end

function ParadiseDev.Zones.MapText.getLabelKey(zone, index)
    return tostring(zone.id or zone.name or "Zone") .. ":" .. tostring(index)
end

function ParadiseDev.Zones.MapText.clear()
    local api = ParadiseDev.Zones.MapText.api
    if api then
        for _, label in pairs(ParadiseDev.Zones.MapText.labels) do
            api:removeSymbol(label)
        end
        if api.invalidateLayout then api:invalidateLayout() end
    end
    ParadiseDev.Zones.MapText.labels = {}
end

function ParadiseDev.Zones.MapText.addLabel(api, zone, index, region)
    local xMin = tonumber(region and region.xMin)
    local yMin = tonumber(region and region.yMin)
    local xMax = tonumber(region and region.xMax)
    local yMax = tonumber(region and region.yMax)
    if not xMin or not yMin or not xMax or not yMax or xMax <= xMin or yMax <= yMin then return false end
    local text = tostring(zone.name or zone.id or "")
    if text == "" then return false end
    local x = (xMin + xMax - 1) / 2
    local y = (yMin + yMax - 1) / 2
    local label = api:addUntranslatedText(text, ParadiseDev.Zones.MapText.layer, x, y)
    if not label then return false end
    label:setRGBA(1, 0.85, 0.2, 1)
    label:setScale(ParadiseDev.Zones.MapText.scale)
    label:setAnchor(0.5, 0.5)
    label:setRotation(0)
    label:setMatchPerspective(true)
    label:setApplyZoom(true)
    label:setMinZoom(ParadiseDev.Zones.MapText.minZoom)
    label:setMaxZoom(ParadiseDev.Zones.MapText.maxZoom)
    label:setUserDefined(false)
    ParadiseDev.Zones.MapText.labels[ParadiseDev.Zones.MapText.getLabelKey(zone, index)] = label
    return true
end

function ParadiseDev.Zones.MapText.sync()
    local api = ParadiseDev.Zones.MapText.getSymbolsAPI()
    if not api then return false end
    if api ~= ParadiseDev.Zones.MapText.api then
        ParadiseDev.Zones.MapText.api = api
        ParadiseDev.Zones.MapText.labels = {}
        ParadiseDev.Zones.MapText.dirty = true
    end
    if not ParadiseDev.Zones.MapText.dirty then return true end
    ParadiseDev.Zones.MapText.clear()
    if ParadiseDev.Zones.MapText.enabled then
        for _, zone in ipairs(ParadiseDev.Zones.MapText.zones) do
            for index, region in ipairs(zone.regions or {}) do
                ParadiseDev.Zones.MapText.addLabel(api, zone, index, region)
            end
        end
    end
    if api.invalidateLayout then api:invalidateLayout() end
    ParadiseDev.Zones.MapText.dirty = false
    return true
end

function ParadiseDev.Zones.MapText.setEnabled(enabled)
    ParadiseDev.Zones.MapText.enabled = enabled == true
    ParadiseDev.Zones.MapText.dirty = true
    ParadiseDev.Zones.MapText.sync()
end

function ParadiseDev.Zones.MapText.loadLocalState()
    local store = ModData and ModData.get and ModData.get("ParadiseDev_Zones") or nil
    if not store or type(store.zones) ~= "table" then return false end
    local zones = {}
    for _, zone in pairs(store.zones) do
        zones[#zones + 1] = {
            id = zone.id,
            name = zone.name,
            priority = zone.priority,
            zMode = zone.zMode,
            zMin = zone.zMin,
            zMaxExclusive = zone.zMaxExclusive,
            features = zone.features,
            regions = zone.regions,
        }
    end
    ParadiseDev.Zones.MapText.zones = zones
    ParadiseDev.Zones.MapText.dirty = true
    ParadiseDev.Zones.MapText.sync()
    return true
end

function ParadiseDev.Zones.MapText.requestState()
    if isClient and isClient() then sendClientCommand("PZZoneEngine", "requestBoundaryState", {}) end
end

function ParadiseDev.Zones.MapText.onServerCommand(module, command, args)
    if module ~= "PZZoneEngine" or command ~= "boundaryState" or not args then return end
    ParadiseDev.Zones.MapText.zones = args.zones or {}
    ParadiseDev.Zones.MapText.dirty = true
    ParadiseDev.Zones.MapText.sync()
end

function ParadiseDev.Zones.MapText.onGameStart()
    if isClient and isClient() then
        ParadiseDev.Zones.MapText.requestState()
    else
        ParadiseDev.Zones.MapText.loadLocalState()
    end
end

function ParadiseDev.Zones.MapText.onTick()
    ParadiseDev.Zones.MapText.tick = ParadiseDev.Zones.MapText.tick + 1
    if ParadiseDev.Zones.MapText.tick < ParadiseDev.Zones.MapText.refreshTicks then return end
    ParadiseDev.Zones.MapText.tick = 0
    ParadiseDev.Zones.MapText.sync()
end

Events.OnServerCommand.Remove(ParadiseDev.Zones.MapText.onServerCommand)
Events.OnServerCommand.Add(ParadiseDev.Zones.MapText.onServerCommand)
Events.OnGameStart.Remove(ParadiseDev.Zones.MapText.onGameStart)
Events.OnGameStart.Add(ParadiseDev.Zones.MapText.onGameStart)
Events.OnTick.Remove(ParadiseDev.Zones.MapText.onTick)
Events.OnTick.Add(ParadiseDev.Zones.MapText.onTick)
