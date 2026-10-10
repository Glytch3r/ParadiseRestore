require "OptionScreens/MapSpawnSelect"
require "ISUI/Maps/ISMapDefinitions"

ParadiseDev_MapPreviewReadiness = ParadiseDev_MapPreviewReadiness or {}
if ParadiseDev_MapPreviewReadiness.installed then return end
ParadiseDev_MapPreviewReadiness.installed = true

local function worldBoundsReady()
    local world = getWorld and getWorld()
    local grid = world and world:getMetaGrid()
    return grid and grid:getMinX() <= grid:getMaxX() and grid:getMinY() <= grid:getMaxY()
end

local function ignorePreviewVisitedColor() end

local function forwardingProxy(original, overrides)
    return setmetatable(overrides, {
        __index = function(proxy, key)
            local member = original[key]
            if type(member) ~= "function" then return member end
            local forwarded = function(_, ...)
                return member(original, ...)
            end
            rawset(proxy, key, forwarded)
            return forwarded
        end,
    })
end

local originalStyle = MapUtils.initDefaultStyleV1
function MapUtils.initDefaultStyleV1(mapUI, ...)
    if not mapUI or mapUI.Type ~= "MapSpawnSelectImage"
            or (MainScreen and MainScreen.instance and MainScreen.instance.inGame)
            or worldBoundsReady() then
        return originalStyle(mapUI, ...)
    end

    -- A vector spawn preview exists before the world grid loads. In this build,
    -- its visited-color setters allocate global visited state from sentinel grid
    -- dimensions, even though the preview does not display exploration fog.
    -- Keep all normal style work and API receivers; bypass only those two calls.
    local api = mapUI.javaObject:getAPIv1()
    api:setBoolean("HideUnvisited", false)
    local previewAPI = forwardingProxy(api, {
        setUnvisitedRGBA = ignorePreviewVisitedColor,
        setUnvisitedGridRGBA = ignorePreviewVisitedColor,
    })
    local previewJava = forwardingProxy(mapUI.javaObject, {
        getAPIv1 = function() return previewAPI end,
    })
    local previewUI = setmetatable({javaObject = previewJava}, {
        __index = mapUI,
        __newindex = mapUI,
    })
    return originalStyle(previewUI, ...)
end
