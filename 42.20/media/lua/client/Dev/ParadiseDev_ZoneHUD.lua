ParadiseDev = ParadiseDev or {}
ParadiseDev.ZoneHUD = ParadiseDev.ZoneHUD or {}
ParadiseDev.ZoneHUD.width = 250
ParadiseDev.ZoneHUD.defaultX = 68 + ParadiseDev.ZoneHUD.width
ParadiseDev.ZoneHUD.defaultY = 73

require "ISUI/ISPanel"
require "ISUI/ISLabel"
require "ISUI/ISButton"
require "ISUI/ISComboBox"
require "ISUI/ISTickBox"
require "RadioCom/ISUIRadio/ISSliderPanel"
require "ISUI/UserPanel/ISUserPanelUI"
require "Dev/ParadiseEconomy/ParadiseEconomy_Client"

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

ParadiseDev.ZoneHUD.fonts = {
    Small = { header = UIFont.Medium, text = UIFont.Small, detail = UIFont.Small },
    Medium = { header = UIFont.Large, text = UIFont.Medium, detail = UIFont.Small },
    Large = { header = UIFont.Large, text = UIFont.Large, detail = UIFont.Medium },
    ["Extra Large"] = { header = UIFont.Massive, text = UIFont.Large, detail = UIFont.Medium },
    Massive = { header = UIFont.Massive, text = UIFont.Massive, detail = UIFont.Large },
    Title = { header = UIFont.Title, text = UIFont.Massive, detail = UIFont.Large },
}

function ParadiseDev.ZoneHUD.getSettings(pl)
    local modData = pl:getModData()
    local settings = modData.HUDSettings or modData.ParadiseZHUDSettings or { x = ParadiseDev.ZoneHUD.defaultX, y = ParadiseDev.ZoneHUD.defaultY, fontSize = "Medium" }
    settings.zoneX = tonumber(settings.zoneX) or tonumber(settings.x) or ParadiseDev.ZoneHUD.defaultX
    settings.zoneY = tonumber(settings.zoneY) or tonumber(settings.y) or ParadiseDev.ZoneHUD.defaultY
    settings.hpX = tonumber(settings.hpX) or settings.zoneX
    settings.hpY = tonumber(settings.hpY) or settings.zoneY + 100
    settings.zoneFontSize = ParadiseDev.ZoneHUD.fonts[settings.zoneFontSize] and settings.zoneFontSize or (ParadiseDev.ZoneHUD.fonts[settings.fontSize] and settings.fontSize or "Medium")
    if settings.zoneVisible == nil then settings.zoneVisible = settings.visible ~= false end
    if settings.hpVisible == nil then settings.hpVisible = true end
    if settings.mapZoneVisuals == nil then settings.mapZoneVisuals = true end
    if settings.worldZoneVisuals == nil then settings.worldZoneVisuals = true end
    modData.HUDSettings = settings
    modData.ParadiseZHUDSettings = settings
    return settings
end

function ParadiseDev.ZoneHUD.saveSettings(pl, settings)
    pl:getModData().HUDSettings = settings
    pl:getModData().ParadiseZHUDSettings = settings
    if pl.transmitModData then pl:transmitModData() end
end

function ParadiseDev.ZoneHUD.applyVisualSettings(settings)
    if ParadiseDev.Zones and ParadiseDev.Zones.MapText and ParadiseDev.Zones.MapText.setEnabled then
        ParadiseDev.Zones.MapText.setEnabled(settings.mapZoneVisuals)
    end
    if ParadiseDev.Zones and ParadiseDev.Zones.Visualization and ParadiseDev.Zones.Visualization.setEnabled then
        ParadiseDev.Zones.Visualization.setEnabled(settings.worldZoneVisuals)
    end
end

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
    if not isIngameState() then
        if ParadiseDev.LifeBar and ParadiseDev.LifeBar.hide then ParadiseDev.LifeBar.hide() end
        return
    end
    local pl = getPlayer()
    if not pl or not pl:isAlive() then
        if ParadiseDev.LifeBar and ParadiseDev.LifeBar.hide then ParadiseDev.LifeBar.hide() end
        return
    end

    local settings = ParadiseDev.ZoneHUD.getSettings(pl)
    if not settings.zoneVisible then
        if ParadiseDev.LifeBar and ParadiseDev.LifeBar.hide then ParadiseDev.LifeBar.hide() end
    end
    local zone = ParadiseDev.ZoneHUD.getCurrentZone(pl)
    local baseX, baseY = settings.zoneX, settings.zoneY
    local fonts = ParadiseDev.ZoneHUD.fonts[settings.zoneFontSize]
    local zoneName = zone and tostring(zone.name or zone.id) or "Outside"
    local mapLabel = ParadiseDev.ZoneHUD.getMapLabel(pl)
    local header = (mapLabel and mapLabel .. "\n" or "") .. zoneName .. "\nX: " .. tostring(math.floor(pl:getX() + 0.5)) .. "    Y: " .. tostring(math.floor(pl:getY() + 0.5)) .. "    Z: " .. tostring(math.floor(pl:getZ() + 0.5))
    local allowed = not zone or zone.allowed ~= false
    local alpha = zone and 0.8 or (ParadiseDev.isAdm and ParadiseDev.isAdm(pl) and 1 or 0.4)
    local r, g, b = allowed and 1 or 1, allowed and 1 or 0.35, allowed and 1 or 0.35
    if settings.zoneVisible then getTextManager():DrawString(fonts.header, baseX, baseY, header, r, g, b, alpha) end

    if not settings.zoneVisible then
        if ParadiseDev.LifeBar and ParadiseDev.LifeBar.placeInZoneHUD then
            ParadiseDev.LifeBar.placeInZoneHUD(pl, settings.hpX, settings.hpY, settings.hpVisible)
        end
        return
    end
    local headerHeight = getTextManager():getFontHeight(fonts.header)
    local currentY = baseY + headerHeight * (mapLabel and 3 or 2)
    local iconY = currentY
    local icons = ParadiseDev.ZoneHUD.getZoneIcons(zone)
    if #icons == 0 then
        local outside = getTexture("media/textures/zone/ParadiseZ_Zone_Outside.png")
        if outside then UIManager.DrawTexture(outside, baseX, currentY, 24, 24, 0.8) end
        getTextManager():DrawString(fonts.text, baseX + 48, currentY, "Outside", 1, 1, 1, alpha)
        currentY = currentY + math.max(26, getTextManager():getFontHeight(fonts.text) + 4)
    else
        for _, icon in ipairs(icons) do
            if icon.texture then UIManager.DrawTexture(icon.texture, baseX, currentY, 24, 24, 0.8) end
            getTextManager():DrawString(fonts.text, baseX + 48, currentY, icon.label, 1, 1, 1, alpha)
            currentY = currentY + math.max(26, getTextManager():getFontHeight(fonts.text) + 4)
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
        getTextManager():DrawString(fonts.detail, baseX, currentY + 8, label .. restriction, 1, 0.35, 0.35, alpha)
        currentY = currentY + getTextManager():getFontHeight(fonts.detail) + 10
    end
    local rebound = ParadiseDev.ZoneHUD.getReboundText(pl)
    if rebound ~= "" then
        getTextManager():DrawString(fonts.detail, baseX, currentY + 8, rebound, 1, 1, 1, alpha)
        currentY = currentY + getTextManager():getFontHeight(fonts.detail) * 2 + 10
    end
    if ParadiseDev.LifeBar and ParadiseDev.LifeBar.placeInZoneHUD then
        ParadiseDev.LifeBar.placeInZoneHUD(pl, settings.hpX, settings.hpY, settings.hpVisible)
    end
end

ParadiseDev.ZoneHUD.SettingsPanel = ISPanel:derive("ParadiseDev.ZoneHUD.SettingsPanel")

function ParadiseDev.ZoneHUD.SettingsPanel:new(pl)
    local width, height = 360, 380
    local panel = ISPanel:new((getCore():getScreenWidth() - width) / 2, (getCore():getScreenHeight() - height) / 2, width, height)
    setmetatable(panel, self)
    self.__index = self
    panel.player = pl
    panel.moveWithMouse = true
    panel.backgroundColor = { r = 0, g = 0, b = 0, a = 0.85 }
    panel.borderColor = { r = 0.5, g = 0.5, b = 0.5, a = 1 }
    return panel
end

function ParadiseDev.ZoneHUD.SettingsPanel:updatePosition(axis, value)
    local settings = ParadiseDev.ZoneHUD.getSettings(self.player)
    settings[axis] = math.floor(value)
    ParadiseDev.ZoneHUD.saveSettings(self.player, settings)
    local labels = {
        zoneX = { control = "xValue", title = "X" },
        zoneY = { control = "yValue", title = "Y" },
        hpX = { control = "hpXValue", title = "HP X" },
        hpY = { control = "hpYValue", title = "HP Y" },
    }
    local label = labels[axis]
    if label and self[label.control] then
        self[label.control]:setName(label.title .. ": " .. tostring(settings[axis]))
    end
end

function ParadiseDev.ZoneHUD.SettingsPanel:onXChanged(value)
    self:updatePosition("zoneX", value)
end

function ParadiseDev.ZoneHUD.SettingsPanel:onYChanged(value)
    self:updatePosition("zoneY", value)
end

function ParadiseDev.ZoneHUD.SettingsPanel:onHPXChanged(value)
    self:updatePosition("hpX", value)
end

function ParadiseDev.ZoneHUD.SettingsPanel:onHPYChanged(value)
    self:updatePosition("hpY", value)
end

function ParadiseDev.ZoneHUD.SettingsPanel:onFontSizeChanged(combo)
    local settings = ParadiseDev.ZoneHUD.getSettings(self.player)
    settings.zoneFontSize = combo:getSelectedData()
    ParadiseDev.ZoneHUD.saveSettings(self.player, settings)
end

function ParadiseDev.ZoneHUD.SettingsPanel:onZoneVisibleChanged(option, enabled)
    local settings = ParadiseDev.ZoneHUD.getSettings(self.player)
    settings.zoneVisible = enabled
    ParadiseDev.ZoneHUD.saveSettings(self.player, settings)
end

function ParadiseDev.ZoneHUD.SettingsPanel:onHPVisibleChanged(option, enabled)
    local settings = ParadiseDev.ZoneHUD.getSettings(self.player)
    settings.hpVisible = enabled
    ParadiseDev.ZoneHUD.saveSettings(self.player, settings)
end

function ParadiseDev.ZoneHUD.SettingsPanel:onMapZoneVisualsChanged(option, enabled)
    local settings = ParadiseDev.ZoneHUD.getSettings(self.player)
    settings.mapZoneVisuals = enabled
    ParadiseDev.ZoneHUD.saveSettings(self.player, settings)
    ParadiseDev.ZoneHUD.applyVisualSettings(settings)
end

function ParadiseDev.ZoneHUD.SettingsPanel:onWorldZoneVisualsChanged(option, enabled)
    local settings = ParadiseDev.ZoneHUD.getSettings(self.player)
    settings.worldZoneVisuals = enabled
    ParadiseDev.ZoneHUD.saveSettings(self.player, settings)
    ParadiseDev.ZoneHUD.applyVisualSettings(settings)
end

function ParadiseDev.ZoneHUD.SettingsPanel:onReset()
    local settings = ParadiseDev.ZoneHUD.getSettings(self.player)
    settings.zoneX, settings.zoneY, settings.zoneFontSize, settings.zoneVisible = ParadiseDev.ZoneHUD.defaultX, ParadiseDev.ZoneHUD.defaultY, "Medium", true
    settings.hpX, settings.hpY, settings.hpVisible = settings.zoneX, settings.zoneY + 100, true
    settings.mapZoneVisuals, settings.worldZoneVisuals = true, true
    ParadiseDev.ZoneHUD.saveSettings(self.player, settings)
    ParadiseDev.ZoneHUD.applyVisualSettings(settings)
    self.xSlider:setCurrentValue(settings.zoneX, true)
    self.ySlider:setCurrentValue(settings.zoneY, true)
    self.hpXSlider:setCurrentValue(settings.hpX, true)
    self.hpYSlider:setCurrentValue(settings.hpY, true)
    self.xValue:setName("X: " .. tostring(settings.zoneX))
    self.yValue:setName("Y: " .. tostring(settings.zoneY))
    self.hpXValue:setName("HP X: " .. tostring(settings.hpX))
    self.hpYValue:setName("HP Y: " .. tostring(settings.hpY))
    self.fontSize:setSelectedData(settings.zoneFontSize)
    self.zoneVisible.selected[1] = true
    self.hpVisible.selected[1] = true
    self.mapZoneVisuals.selected[1] = true
    self.worldZoneVisuals.selected[1] = true
end

function ParadiseDev.ZoneHUD.SettingsPanel:onClose()
    self:removeFromUIManager()
    ParadiseDev.ZoneHUD.settingsPanel = nil
end

function ParadiseDev.ZoneHUD.SettingsPanel:createChildren()
    ISPanel.createChildren(self)
    local settings = ParadiseDev.ZoneHUD.getSettings(self.player)
    local maxX = math.max(0, getCore():getScreenWidth() - 1)
    local maxY = math.max(0, getCore():getScreenHeight() - 1)
    self.title = ISLabel:new(12, 12, 20, "Zone HUD Settings", 1, 1, 1, 1, UIFont.Medium, true)
    self.title:initialise()
    self.title:instantiate()
    self:addChild(self.title)
    self.xValue = ISLabel:new(12, 53, 20, "X: " .. tostring(settings.zoneX), 1, 1, 1, 1, UIFont.Small, true)
    self.xValue:initialise()
    self.xValue:instantiate()
    self:addChild(self.xValue)
    self.xSlider = ISSliderPanel:new(55, 48, self.width - 67, 20, self, ParadiseDev.ZoneHUD.SettingsPanel.onXChanged)
    self.xSlider:initialise()
    self.xSlider:instantiate()
    self.xSlider:setValues(0, maxX, 1, 25, true)
    self.xSlider:setCurrentValue(settings.zoneX, true)
    self:addChild(self.xSlider)
    self.yValue = ISLabel:new(12, 93, 20, "Y: " .. tostring(settings.zoneY), 1, 1, 1, 1, UIFont.Small, true)
    self.yValue:initialise()
    self.yValue:instantiate()
    self:addChild(self.yValue)
    self.ySlider = ISSliderPanel:new(55, 88, self.width - 67, 20, self, ParadiseDev.ZoneHUD.SettingsPanel.onYChanged)
    self.ySlider:initialise()
    self.ySlider:instantiate()
    self.ySlider:setValues(0, maxY, 1, 25, true)
    self.ySlider:setCurrentValue(settings.zoneY, true)
    self:addChild(self.ySlider)
    self.hpXValue = ISLabel:new(12, 133, 20, "HP X: " .. tostring(settings.hpX), 1, 1, 1, 1, UIFont.Small, true)
    self.hpXValue:initialise()
    self.hpXValue:instantiate()
    self:addChild(self.hpXValue)
    self.hpXSlider = ISSliderPanel:new(65, 128, self.width - 77, 20, self, ParadiseDev.ZoneHUD.SettingsPanel.onHPXChanged)
    self.hpXSlider:initialise()
    self.hpXSlider:instantiate()
    self.hpXSlider:setValues(0, maxX, 1, 25, true)
    self.hpXSlider:setCurrentValue(settings.hpX, true)
    self:addChild(self.hpXSlider)
    self.hpYValue = ISLabel:new(12, 173, 20, "HP Y: " .. tostring(settings.hpY), 1, 1, 1, 1, UIFont.Small, true)
    self.hpYValue:initialise()
    self.hpYValue:instantiate()
    self:addChild(self.hpYValue)
    self.hpYSlider = ISSliderPanel:new(65, 168, self.width - 77, 20, self, ParadiseDev.ZoneHUD.SettingsPanel.onHPYChanged)
    self.hpYSlider:initialise()
    self.hpYSlider:instantiate()
    self.hpYSlider:setValues(0, maxY, 1, 25, true)
    self.hpYSlider:setCurrentValue(settings.hpY, true)
    self:addChild(self.hpYSlider)
    self.fontSizeLabel = ISLabel:new(12, 210, 20, "Zone font size", 1, 1, 1, 1, UIFont.Small, true)
    self.fontSizeLabel:initialise()
    self.fontSizeLabel:instantiate()
    self:addChild(self.fontSizeLabel)
    self.fontSize = ISComboBox:new(125, 205, 150, 24, self, ParadiseDev.ZoneHUD.SettingsPanel.onFontSizeChanged)
    self.fontSize:initialise()
    self.fontSize:instantiate()
    self.fontSize:addOptionWithData("Small", "Small")
    self.fontSize:addOptionWithData("Medium", "Medium")
    self.fontSize:addOptionWithData("Large", "Large")
    self.fontSize:addOptionWithData("Extra Large", "Extra Large")
    self.fontSize:addOptionWithData("Massive", "Massive")
    self.fontSize:addOptionWithData("Title", "Title")
    self.fontSize:setSelectedData(settings.zoneFontSize)
    self:addChild(self.fontSize)
    self.zoneVisible = ISTickBox:new(12, 240, self.width - 24, 22, "", self, ParadiseDev.ZoneHUD.SettingsPanel.onZoneVisibleChanged)
    self.zoneVisible:initialise()
    self.zoneVisible:instantiate()
    self.zoneVisible:addOption("Show Zone Info")
    self.zoneVisible.selected[1] = settings.zoneVisible
    self:addChild(self.zoneVisible)
    self.hpVisible = ISTickBox:new(12, 265, self.width - 24, 22, "", self, ParadiseDev.ZoneHUD.SettingsPanel.onHPVisibleChanged)
    self.hpVisible:initialise()
    self.hpVisible:instantiate()
    self.hpVisible:addOption("Show HP Bar")
    self.hpVisible.selected[1] = settings.hpVisible
    self:addChild(self.hpVisible)
    self.mapZoneVisuals = ISTickBox:new(12, 290, self.width - 24, 22, "", self, ParadiseDev.ZoneHUD.SettingsPanel.onMapZoneVisualsChanged)
    self.mapZoneVisuals:initialise()
    self.mapZoneVisuals:instantiate()
    self.mapZoneVisuals:addOption("Show Map Zone Visuals")
    self.mapZoneVisuals.selected[1] = settings.mapZoneVisuals
    self:addChild(self.mapZoneVisuals)
    self.worldZoneVisuals = ISTickBox:new(12, 315, self.width - 24, 22, "", self, ParadiseDev.ZoneHUD.SettingsPanel.onWorldZoneVisualsChanged)
    self.worldZoneVisuals:initialise()
    self.worldZoneVisuals:instantiate()
    self.worldZoneVisuals:addOption("Show World Zone Visuals")
    self.worldZoneVisuals.selected[1] = settings.worldZoneVisuals
    self:addChild(self.worldZoneVisuals)
    self.resetButton = ISButton:new(12, 340, 120, 26, "Reset", self, ParadiseDev.ZoneHUD.SettingsPanel.onReset)
    self.resetButton:initialise()
    self.resetButton:instantiate()
    self:addChild(self.resetButton)
    self.closeButton = ISButton:new(self.width - 132, 340, 120, 26, "Close", self, ParadiseDev.ZoneHUD.SettingsPanel.onClose)
    self.closeButton:initialise()
    self.closeButton:instantiate()
    self:addChild(self.closeButton)
end

function ParadiseDev.ZoneHUD.openSettings(pl)
    pl = pl or getPlayer()
    if not pl then return end
    if ParadiseDev.ZoneHUD.settingsPanel then ParadiseDev.ZoneHUD.settingsPanel:onClose() end
    local panel = ParadiseDev.ZoneHUD.SettingsPanel:new(pl)
    panel:initialise()
    panel:addToUIManager()
    ParadiseDev.ZoneHUD.settingsPanel = panel
end


function ParadiseDev.ZoneHUD.onUserPanelOption(self, button, x, y)
    if button.internal == "PARADISEDEV_ZONEHUD_SETTINGS" then
        ParadiseDev.ZoneHUD.openSettings(self.player)
        return
    end
    if button.internal == "PARADISE_ECONOMY_FINANCE_MANAGER" then
        ParadiseEconomy.openPanel(self.player)
    end
end

function ParadiseDev.ZoneHUD.layoutUserPanel()
    local self = ISUserPanelUI.instance
    if not self or self._ParadiseDevZoneHUDLayoutApplied then return end
    local close = self.cancel
    if not close then return end

    self._ParadiseDevZoneHUDLayoutApplied = true
    local bottom = close.y
    for _, child in pairs(self:getChildren()) do
        if child ~= close then
            bottom = math.max(bottom, child:getBottom())
        end
    end
    local hasBetterSafehouse = ParadiseZ and ParadiseZ.isModActive and ParadiseZ.isModActive("BetterSafehouse")
    local buttonWidth = math.max(close.width, hasBetterSafehouse and 400 or close.width)
    self:setWidth(math.max(self:getWidth(), close.x * 2 + buttonWidth))
    self.zoneHUDSettings = ISButton:new(close.x, bottom + 10, buttonWidth, close.height, "Zone HUD Settings", self, ParadiseDev.ZoneHUD.onUserPanelOption)
        self.zoneHUDSettings.internal = "PARADISEDEV_ZONEHUD_SETTINGS"
        self.zoneHUDSettings:initialise()
        self.zoneHUDSettings:instantiate()
        self.zoneHUDSettings.borderColor = self.buttonBorderColor
        self.zoneHUDSettings.borderColor = self.buttonBorderColor

        self.zoneHUDSettings.backgroundColor.a = 0.7;
        self.zoneHUDSettings.backgroundColor.b = 0.5;

    self:addChild(self.zoneHUDSettings)
    self.financeManager = ISButton:new(close.x, self.zoneHUDSettings:getBottom() + 10, buttonWidth, close.height, "Finance Manager", self, ParadiseDev.ZoneHUD.onUserPanelOption)
        self.financeManager.internal = "PARADISE_ECONOMY_FINANCE_MANAGER"
        self.financeManager:initialise()
        self.financeManager:instantiate()
        self.financeManager.borderColor = self.buttonBorderColor
        self.financeManager.backgroundColor.a = 0.7;
        self.financeManager.backgroundColor.b = 0.5;
    self:addChild(self.financeManager)
    close:setWidth(buttonWidth)
    close:setY(self.financeManager:getBottom() + 10)
    self:setHeight(math.max(close.y + close.height + 11, hasBetterSafehouse and 460 or 0))
end

function ParadiseDev.ZoneHUD.onGameStart()
    local pl = getPlayer()
    if pl then ParadiseDev.ZoneHUD.applyVisualSettings(ParadiseDev.ZoneHUD.getSettings(pl)) end
    if isClient() then sendClientCommand("PZZoneEngine", "requestBoundaryState", {}) end
end

Events.OnPostUIDraw.Remove(ParadiseDev.ZoneHUD.draw)
Events.OnPostUIDraw.Add(ParadiseDev.ZoneHUD.draw)
Events.OnPostUIDraw.Remove(ParadiseDev.ZoneHUD.layoutUserPanel)
Events.OnPostUIDraw.Add(ParadiseDev.ZoneHUD.layoutUserPanel)
Events.OnGameStart.Remove(ParadiseDev.ZoneHUD.onGameStart)
Events.OnGameStart.Add(ParadiseDev.ZoneHUD.onGameStart)
