-- B42 zone HUD.  It reads PZZoneEngine's server-published cache and never
-- attempts to decide zone policy itself.
ParadiseDev = ParadiseDev or {}
ParadiseDev.ZoneHUD = ParadiseDev.ZoneHUD or {}

local HUD = ParadiseDev.ZoneHUD

local FEATURE_LABELS = {
    isKos = "PvP", isPvE = "PvE", isSafe = "Safe", isBlocked = "Blocked",
    isRad = "Radiation", isHunt = "Hunt", isBlaze = "Blaze", isFrost = "Frost",
    isBomb = "Bomb", isMine = "Minefield", isNoCamp = "No Camping",
    isNoFire = "No Fire", isCage = "Cage", isParty = "Party", isRally = "Rally",
    isSpecial = "Special", isTrade = "Trade", isSprint = "Sprint",
}

local function featureText(zone)
    local labels = {}
    for key, label in pairs(FEATURE_LABELS) do
        if zone.features and zone.features[key] then labels[#labels + 1] = label end
    end
    table.sort(labels)
    return table.concat(labels, "  |  ")
end

function HUD.getCurrentZone(player)
    local border = rawget(_G, "PZZoneEngineClientBorder")
    return border and border.getZoneFor and border.getZoneFor(player) or nil
end

function HUD.draw()
    if not isIngameState() then return end
    local player = getPlayer()
    if not player or not player:isAlive() then return end

    local zone = HUD.getCurrentZone(player)
    if not zone then return end

    local modData = player:getModData()
    modData.ParadiseZHUDSettings = modData.ParadiseZHUDSettings or { x = 68, y = 73 }
    local settings = modData.ParadiseZHUDSettings
    local x, y = tonumber(settings.x) or 68, tonumber(settings.y) or 73
    local allowed = zone.allowed ~= false
    local r, g, b = allowed and 0.65 or 1.0, allowed and 0.9 or 0.35, allowed and 1.0 or 0.35

    getTextManager():DrawString(UIFont.Large, x, y, "ZONE: " .. tostring(zone.name or zone.id), r, g, b, 0.9)

    local flags = featureText(zone)
    if flags ~= "" then
        getTextManager():DrawString(UIFont.Small, x, y + 28, flags, 1, 1, 1, 0.8)
    end
    if not allowed then
        getTextManager():DrawString(UIFont.Small, x, y + 44, "ACCESS DENIED", 1, 0.35, 0.35, 0.9)
    end
end

Events.OnPostUIDraw.Remove(HUD.draw)
Events.OnPostUIDraw.Add(HUD.draw)

-- A regular player needs the same read-only zone cache as an administrator;
-- otherwise the HUD would remain empty until someone edited a zone.
Events.OnGameStart.Add(function()
    if isClient() then sendClientCommand("PZZoneEngine", "requestBoundaryState", {}) end
end)
