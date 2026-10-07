-- Shared zone colors for the HUD, world borders and map overlays.
-- Zone names are deliberately not added to map symbols or hover tooltips.
-- Old generated symbols were non-user-defined and are discarded on a full
-- client restart. Do not scan/delete player notes or recycled symbol handles.
ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.MapText = ParadiseDev.Zones.MapText or {}

ParadiseDev.Zones.MapText.featureColors = {
    isKos = { r = 0.9, g = 0.2, b = 0.2 },
    isBlocked = { r = 0.9, g = 0.2, b = 0.2 },
    isCage = { r = 0.45, g = 0.2, b = 0.75 },
    isSafe = { r = 0.15, g = 0.45, b = 0.95 },
    isPvE = { r = 0.1, g = 0.8, b = 0.25 },
    isRad = { r = 1.0, g = 1.0, b = 1.0 },
    isHunt = { r = 1.0, g = 0.0, b = 0.0 },
    isBlaze = { r = 1.0, g = 0.0, b = 0.0 },
    isFrost = { r = 0.5, g = 0.4, b = 1.0 },
    isBomb = { r = 1.0, g = 0.0, b = 0.0 },
    isMine = { r = 1.0, g = 0.0, b = 0.0 },
    isNoCamp = { r = 0.7, g = 0.7, b = 0.7 },
    isNoFire = { r = 0.8, g = 0.8, b = 0.8 },
    isParty = { r = 1.0, g = 1.0, b = 0.6 },
    isRally = { r = 0.0, g = 1.0, b = 0.0 },
    isSpecial = { r = 0.9, g = 0.4, b = 0.9 },
    isTrade = { r = 0.0, g = 1.0, b = 0.0 },
    isSprint = { r = 1.0, g = 0.7, b = 0.7 },
}

ParadiseDev.Zones.MapText.featureOrder = {
    "isKos", "isBlocked", "isCage", "isSafe", "isPvE", "isRad", "isHunt", "isBlaze", "isFrost", "isBomb", "isMine",
    "isNoCamp", "isNoFire", "isParty", "isRally", "isSpecial", "isTrade", "isSprint",
}

function ParadiseDev.Zones.MapText.getZoneColor(zone)
    local features = zone and type(zone.features) == "table" and zone.features or nil
    for _, key in ipairs(ParadiseDev.Zones.MapText.featureOrder) do
        if features and features[key] then return ParadiseDev.Zones.MapText.featureColors[key] end
    end
    return { r = 1.0, g = 0.9, b = 0.1 }
end

