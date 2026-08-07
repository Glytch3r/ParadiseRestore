ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.MapText = ParadiseDev.Zones.MapText or {}

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
    ParadiseDev.Zones.MapText.requestState()
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
