ParadiseDev = ParadiseDev or {}
ParadiseDev.ZoneHUD = ParadiseDev.ZoneHUD or {}

ParadiseDev.ZoneHUD.mapLabels = {
    { key = "MapLabel_Brandenburg", x = 2056, y = 6070 },
    { key = "MapLabel_Ekron", x = 634, y = 9746 },
    { key = "MapLabel_EchoCreek", x = 3589, y = 10952 },
    { key = "MapLabel_Riverside", x = 6450, y = 5430 },
    { key = "MapLabel_FallasLake", x = 7253, y = 8279 },
    { key = "MapLabel_Rosewood", x = 8159, y = 11661 },
    { key = "MapLabel_MarchRidge", x = 10130, y = 12801 },
    { key = "MapLabel_Muldraugh", x = 10754, y = 9926 },
    { key = "MapLabel_WestPoint", x = 11654, y = 6864 },
    { key = "MapLabel_Louisville", x = 13077, y = 2238 },
    { key = "MapLabel_Irvington", x = 2427, y = 14185 },
}

ParadiseDev.ZoneHUD.featureVisuals = {
    isKos = { label = "PvP", texture = "ParadiseZ_Zone_PvP.png" },
    isPvE = { label = "PvE", texture = "ParadiseZ_Zone_NonPvP.png" },
    isBlocked = { label = "Blocked", texture = "ParadiseZ_Zone_Blocked.png" },
    isSafe = { label = "Protected", texture = "ParadiseZ_Zone_Protected.png" },
    isRad = { label = "Radiation", texture = "ParadiseZ_Zone_Rad.png" },
    isHunt = { label = "Hunt", texture = "ParadiseZ_Zone_Hunt.png" },
    isBlaze = { label = "Blaze", texture = "ParadiseZ_Zone_Blaze.png" },
    isFrost = { label = "Frost", texture = "ParadiseZ_Zone_Frost.png" },
    isBomb = { label = "Bomb", texture = "ParadiseZ_Zone_Bomb.png" },
    isMine = { label = "MineField", texture = "ParadiseZ_Zone_MineField.png" },
    isNoCamp = { label = "NoCamp", texture = "ParadiseZ_Zone_NoCamp.png" },
    isNoFire = { label = "NoFire", texture = "ParadiseZ_Zone_NoFire.png" },
    isCage = { label = "Cage", texture = "ParadiseZ_Zone_Cage.png" },
    isParty = { label = "Party", texture = "ParadiseZ_Zone_Party.png" },
    isRally = { label = "Rally", texture = "ParadiseZ_Zone_Rally.png" },
    isSpecial = { label = "Special", texture = "ParadiseZ_Zone_Special.png" },
    isTrade = { label = "Trade", texture = "ParadiseZ_Zone_Trade.png" },
    isSprint = { label = "Sprint", texture = "ParadiseZ_Zone_Sprint.png" },
}

ParadiseDev.ZoneHUD.featureOrder = {
    "isKos", "isPvE", "isBlocked", "isSafe", "isRad", "isHunt", "isBlaze", "isFrost", "isBomb", "isMine",
    "isNoCamp", "isNoFire", "isCage", "isParty", "isRally", "isSpecial", "isTrade", "isSprint",
}

function ParadiseDev.ZoneHUD.getCurrentZone(pl)
    local border = ParadiseDev and ParadiseDev.Zones and ParadiseDev.Zones.Border
    return border and border.getZoneFor and border.getZoneFor(pl) or nil
end

function ParadiseDev.ZoneHUD.getMapLabel(pl)
    local nearest, distance
    for _, label in ipairs(ParadiseDev.ZoneHUD.mapLabels) do
        local dx, dy = pl:getX() - label.x, pl:getY() - label.y
        local candidate = dx * dx + dy * dy
        if not distance or candidate < distance then
            nearest, distance = label, candidate
        end
    end
    if nearest and distance <= 6250000 then return getText(nearest.key) end
    return nil
end

function ParadiseDev.ZoneHUD.getZoneIcons(zone)
    local icons = {}
    for _, key in ipairs(ParadiseDev.ZoneHUD.featureOrder) do
        local visual = ParadiseDev.ZoneHUD.featureVisuals[key]
        if zone and zone.features and zone.features[key] then
            icons[#icons + 1] = { label = visual.label, texture = getTexture("media/textures/zone/" .. visual.texture) }
        end
    end
    return icons
end

function ParadiseDev.ZoneHUD.getStatusIcons(pl)
    local icons = {}
    if ParadiseDev.hasTrait and ParadiseDev.hasTrait(pl, "InjuredPvP") then
        icons[#icons + 1] = getTexture("media/ui/Traits/trait_InjuredPvP.png")
    end
    if ParadiseDev.hasTrait and ParadiseDev.hasTrait(pl, "ParadiseDev:Caged") then
        icons[#icons + 1] = getTexture("media/ui/Traits/trait_Caged.png")
    end
    return icons
end

function ParadiseDev.ZoneHUD.getReboundText(pl)
    pl = pl or getPlayer()
    if not pl then return end
    if not getCore():getDebug() then return "" end
    local point = ParadiseDev.TP and ParadiseDev.TP.getRebound and ParadiseDev.TP.getRebound(pl)
    if not point then return "" end
    return "REBOUND:\n" .. tostring(math.floor(point.x + 0.5)) .. ", " .. tostring(math.floor(point.y + 0.5)) .. ", " .. tostring(point.z)
end

function ParadiseDev.ZoneHUD.draw()
    if not isIngameState() then return end
    local pl = getPlayer()
    if not pl or not pl:isAlive() then return end

    local zone = ParadiseDev.ZoneHUD.getCurrentZone(pl)
    local modData = pl:getModData()
    local settings = modData.HUDSettings or modData.ParadiseZHUDSettings or { x = 68, y = 73 }
    modData.HUDSettings = settings
    modData.ParadiseZHUDSettings = settings
    local baseX, baseY = tonumber(settings.x) or 68, tonumber(settings.y) or 73
    local zoneName = zone and tostring(zone.name or zone.id) or "Outside"
    local mapLabel = ParadiseDev.ZoneHUD.getMapLabel(pl)
    local header = (mapLabel and mapLabel .. "\n" or "") .. zoneName .. "\nX: " .. tostring(math.floor(pl:getX() + 0.5)) .. "    Y: " .. tostring(math.floor(pl:getY() + 0.5))
    local allowed = not zone or zone.allowed ~= false
    local alpha = zone and 0.8 or (ParadiseDev.isAdm and ParadiseDev.isAdm(pl) and 1 or 0.4)
    local r, g, b = allowed and 1 or 1, allowed and 1 or 0.35, allowed and 1 or 0.35
    getTextManager():DrawString(UIFont.Large, baseX, baseY, header, r, g, b, alpha)

    local currentY = baseY + (mapLabel and 75 or 50)
    local iconY = currentY
    local icons = ParadiseDev.ZoneHUD.getZoneIcons(zone)
    if #icons == 0 then
        local outside = getTexture("media/textures/zone/ParadiseZ_Zone_Outside.png")
        if outside then UIManager.DrawTexture(outside, baseX, currentY, 24, 24, 0.8) end
        getTextManager():DrawString(UIFont.Medium, baseX + 48, currentY, "Outside", 1, 1, 1, alpha)
        currentY = currentY + 26
    else
        for _, icon in ipairs(icons) do
            if icon.texture then UIManager.DrawTexture(icon.texture, baseX, currentY, 24, 24, 0.8) end
            getTextManager():DrawString(UIFont.Medium, baseX + 48, currentY, icon.label, 1, 1, 1, alpha)
            currentY = currentY + 26
        end
    end

    local statusX = baseX + 162
    for _, texture in ipairs(ParadiseDev.ZoneHUD.getStatusIcons(pl)) do
        if texture then UIManager.DrawTexture(texture, statusX, iconY, 24, 24, 1) end
        statusX = statusX + 26
    end

    if zone and zone.restricted then
        local restriction = tostring(zone.deniedReason or "Restricted zone")
        local label = allowed and "RESTRICTION: " or "ACCESS DENIED: "
        getTextManager():DrawString(UIFont.Small, baseX, currentY + 8, label .. restriction, 1, 0.35, 0.35, alpha)
        currentY = currentY + 24
    end
    local rebound = ParadiseDev.ZoneHUD.getReboundText(pl)
    if rebound ~= "" then getTextManager():DrawString(UIFont.Small, baseX, currentY + 8, rebound, 1, 1, 1, alpha) end
end

function ParadiseDev.ZoneHUD.onGameStart()
    if isClient() then sendClientCommand("PZZoneEngine", "requestBoundaryState", {}) end
end

Events.OnPostUIDraw.Remove(ParadiseDev.ZoneHUD.draw)
Events.OnPostUIDraw.Add(ParadiseDev.ZoneHUD.draw)
Events.OnGameStart.Remove(ParadiseDev.ZoneHUD.onGameStart)
Events.OnGameStart.Add(ParadiseDev.ZoneHUD.onGameStart)
