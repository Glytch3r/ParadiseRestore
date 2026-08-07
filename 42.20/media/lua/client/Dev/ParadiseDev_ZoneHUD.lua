ParadiseDev = ParadiseDev or {}
ParadiseDev.ZoneHUD = ParadiseDev.ZoneHUD or {}

ParadiseDev.ZoneHUD.featureLabels = {
    isKos = "PvP", isPvE = "PvE", isSafe = "Safe", isBlocked = "Blocked",
    isRad = "Radiation", isHunt = "Hunt", isBlaze = "Blaze", isFrost = "Frost",
    isBomb = "Bomb", isMine = "Minefield", isNoCamp = "No Camping",
    isNoFire = "No Fire", isCage = "Cage", isParty = "Party", isRally = "Rally",
    isSpecial = "Special", isTrade = "Trade", isSprint = "Sprint",
}

function ParadiseDev.ZoneHUD.featureText(zone)
    local labels = {}
    for key, label in pairs(ParadiseDev.ZoneHUD.featureLabels) do
        if zone.features and zone.features[key] then labels[#labels + 1] = label end
    end
    table.sort(labels)
    return table.concat(labels, "  |  ")
end

function ParadiseDev.ZoneHUD.getCurrentZone(pl)
    local border = ParadiseDev and ParadiseDev.Zones and ParadiseDev.Zones.Border
    return border and border.getZoneFor and border.getZoneFor(pl) or nil
end

function ParadiseDev.ZoneHUD.draw()
    if not isIngameState() then return end
    local pl = getPlayer()
    if not pl or not pl:isAlive() then return end

    local zone = ParadiseDev.ZoneHUD.getCurrentZone(pl)
    if not zone then return end

    local modData = pl:getModData()
    modData.ParadiseZHUDSettings = modData.ParadiseZHUDSettings or { x = 68, y = 73 }
    local settings = modData.ParadiseZHUDSettings
    local x, y = tonumber(settings.x) or 68, tonumber(settings.y) or 73
    local allowed = zone.allowed ~= false
    local r, g, b = allowed and 0.65 or 1.0, allowed and 0.9 or 0.35, allowed and 1.0 or 0.35

    getTextManager():DrawString(UIFont.Large, x, y, "ZONE: " .. tostring(zone.name or zone.id), r, g, b, 0.9)

    local flags = ParadiseDev.ZoneHUD.featureText(zone)
    if flags ~= "" then
        getTextManager():DrawString(UIFont.Small, x, y + 28, flags, 1, 1, 1, 0.8)
    end
    if not allowed then
        getTextManager():DrawString(UIFont.Small, x, y + 44, "ACCESS DENIED", 1, 0.35, 0.35, 0.9)
    end
end

function ParadiseDev.ZoneHUD.onGameStart()
    if isClient() then sendClientCommand("PZZoneEngine", "requestBoundaryState", {}) end
end

Events.OnPostUIDraw.Remove(ParadiseDev.ZoneHUD.draw)
Events.OnPostUIDraw.Add(ParadiseDev.ZoneHUD.draw)
Events.OnGameStart.Remove(ParadiseDev.ZoneHUD.onGameStart)
Events.OnGameStart.Add(ParadiseDev.ZoneHUD.onGameStart)
