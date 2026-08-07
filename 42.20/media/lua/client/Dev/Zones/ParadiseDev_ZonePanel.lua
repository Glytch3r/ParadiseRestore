ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
require "Dev/ParadiseDev_Players"
require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISScrollingListBox"
require "ISUI/ISTextEntryBox"
require "ISUI/ISTickBox"
require "ISUI/ISComboBox"
require "ISUI/ISModalDialog"

ParadiseDev.Zones.MODULE = ParadiseDev.Zones.MODULE or "PZZoneHarness"
ParadiseDev.Zones.adminZones = ParadiseDev.Zones.adminZones or {}
ParadiseDev.Zones.window = ParadiseDev.Zones.window or nil
ParadiseDev.Zones.editorWindow = ParadiseDev.Zones.editorWindow or nil
ParadiseDev.Zones.testWindow = ParadiseDev.Zones.testWindow or nil
ParadiseDev.Zones.serverVehicleMode = ParadiseDev.Zones.serverVehicleMode or "observe"

local FONT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local ENTRY_HGT = FONT_SMALL + 8
local GAP = 8
local UI_PATH = "media/ui/Paradise/"
local FEATURE_PATH = "media/textures/zone/"

local FEATURE_DEFS = {
    { key = "isRad", label = "Rad", texture = "ParadiseZ_Zone_Rad", tooltip = "Radiation zone" },
    { key = "isHunt", label = "Hunt", texture = "ParadiseZ_Zone_Hunt", tooltip = "Hunt zone: range staff or hunt-authorized players may enter" },
    { key = "isBlaze", label = "Blaze", texture = "ParadiseZ_Zone_Blaze", tooltip = "Blaze / hot-temperature zone" },
    { key = "isFrost", label = "Frost", texture = "ParadiseZ_Zone_Frost", tooltip = "Frost / cold-temperature zone" },
    { key = "isBomb", label = "Bomb", texture = "ParadiseZ_Zone_Bomb", tooltip = "Bomb hazard zone" },
    { key = "isMine", label = "Mine", texture = "ParadiseZ_Zone_MineField", tooltip = "Minefield zone" },
    { key = "isKos", label = "KoS", texture = "ParadiseZ_Zone_PvP", tooltip = "KoS zone: PvE-tagged players may not enter" },
    { key = "isPvE", label = "PvE", texture = "ParadiseZ_Zone_NonPvP", tooltip = "PvE / non-PvP zone" },
    { key = "isSafe", label = "Safe", texture = "ParadiseZ_Zone_Protected", tooltip = "Protected / safe zone" },
    { key = "isNoCamp", label = "NoCamp", texture = "ParadiseZ_Zone_NoCamp", tooltip = "No-camping zone" },
    { key = "isNoFire", label = "NoFire", texture = "ParadiseZ_Zone_NoFire", tooltip = "No-fire zone" },
    { key = "isCage", label = "Cage", texture = "ParadiseZ_Zone_Cage", tooltip = "Cage zone" },
    { key = "isParty", label = "Party", texture = "ParadiseZ_Zone_Party", tooltip = "Party zone" },
    { key = "isRally", label = "Rally", texture = "ParadiseZ_Zone_Rally", tooltip = "Rally zone" },
    { key = "isSpecial", label = "Special", texture = "ParadiseZ_Zone_Special", tooltip = "Special zone" },
    { key = "isTrade", label = "Trade", texture = "ParadiseZ_Zone_Trade", tooltip = "Trade zone" },
    { key = "isSprint", label = "Sprint", texture = "ParadiseZ_Zone_Sprint", tooltip = "Sprinter-zombie zone" },
    { key = "isBlocked", label = "Blocked", texture = "ParadiseZ_Zone_Blocked", tooltip = "Blocked zone: nobody may enter unless admin bypass applies" },
}
local FEATURE_BY_KEY = {}
for _, def in ipairs(FEATURE_DEFS) do
    def.onTexture = getTexture(FEATURE_PATH .. def.texture .. ".png")
    def.offTexture = getTexture(FEATURE_PATH .. def.texture .. "_off.png")
    FEATURE_BY_KEY[def.key] = def
end

local PANEL_TEXTURES = {
    point1 = getTexture(UI_PATH .. "Point1.png"),
    point2 = getTexture(UI_PATH .. "Point2.png"),
    sync = getTexture(UI_PATH .. "sync.png"),
    syncOn = getTexture(UI_PATH .. "sync_on.png"),
    backup = getTexture(UI_PATH .. "backup.png"),
    reset = getTexture(UI_PATH .. "reset.png"),
    add = getTexture(UI_PATH .. "add.png"),
    delete = getTexture(UI_PATH .. "delete.png"),
    deleteOff = getTexture(UI_PATH .. "delete_off.png"),
    teleport = getTexture(UI_PATH .. "TP.png"),
    teleportOff = getTexture(UI_PATH .. "TP_off.png"),
    background = getTexture(UI_PATH .. "bg.png"),
}

function ParadiseDev.Zones.send(command, args)
    sendClientCommand(ParadiseDev.Zones.MODULE, command, args or {})
end

function ParadiseDev.Zones.addLabel(parent, text, x, y, color, font)
    color = color or { r = 0.85, g = 0.85, b = 0.85 }
    local label = ISLabel:new(x, y, ENTRY_HGT, text, color.r, color.g, color.b, 1, font or UIFont.Small, true)
    label:initialise()
    label:instantiate()
    parent:addChild(label)
    return label
end

function ParadiseDev.Zones.addEntry(parent, text, x, y, width)
    local entry = ISTextEntryBox:new(tostring(text or ""), x, y, width, ENTRY_HGT)
    entry:initialise()
    entry:instantiate()
    parent:addChild(entry)
    return entry
end

function ParadiseDev.Zones.addButton(parent, text, x, y, width, target, callback)
    local button = ISButton:new(x, y, width, ENTRY_HGT, text, target, callback)
    button:initialise()
    button:instantiate()
    parent:addChild(button)
    return button
end

function ParadiseDev.Zones.addImageButton(parent, x, y, width, height, image, internal, tooltip, callback)
    local button = ISButton:new(x, y, width, height, "", parent, callback)
    button.internal = internal
    button.tooltip = tooltip
    button:initialise()
    button:instantiate()
    button:setImage(image)
    button.borderColor = { r = 0.35, g = 0.55, b = 0.75, a = 0.75 }
    parent:addChild(button)
    return button
end

function ParadiseDev.Zones.layoutWindowChrome(window)
    local buttonHeight = window:titleBarHeight() - 2
    local rightX = window.width - 1 - buttonHeight
    if window.pinButton then window.pinButton:setX(rightX) end
    if window.collapseButton then window.collapseButton:setX(rightX) end
    local rh = window:resizeWidgetHeight()
    if window.resizeWidget then
        window.resizeWidget:setX(window.width - rh)
        window.resizeWidget:setY(window.height - rh)
    end
    if window.resizeWidget2 then
        window.resizeWidget2:setY(window.height - rh)
        window.resizeWidget2:setWidth(window.width - rh)
    end
end

function ParadiseDev.Zones.resizeWindow(target, newWidth, newHeight)
    target:setWidth(math.max(newWidth, target.minimumWidth or 0))
    target:setHeight(math.max(newHeight, target.minimumHeight or 0))
    ParadiseDev.Zones.layoutWindowChrome(target)
    if target.layoutChildren then target:layoutChildren() end
end

function ParadiseDev.Zones.enableWindowResize(window)
    window:setResizable(true)
    if window.resizeWidget then window.resizeWidget.resizeFunction = ParadiseDev.Zones.resizeWindow end
    if window.resizeWidget2 then window.resizeWidget2.resizeFunction = ParadiseDev.Zones.resizeWindow end
    ParadiseDev.Zones.layoutWindowChrome(window)
end
function ParadiseDev.Zones.primarySegment(zone)
    return zone and zone.segments and zone.segments[1] or nil
end

function ParadiseDev.Zones.activeFlags(zone)
    local names = {}
    local features = zone and zone.features or {}
    for _, def in ipairs(FEATURE_DEFS) do
        if features[def.key] then names[#names + 1] = def.label end
    end
    return table.concat(names, ", ")
end

function ParadiseDev.Zones.zoneById(id)
    for _, zone in ipairs(ParadiseDev.Zones.adminZones) do
        if zone.id == id then return zone end
    end
    return nil
end

ParadiseDev.Zones.Panel = ISCollapsableWindow:derive("ParadiseDev.Zones.Panel")

function ParadiseDev.Zones.Panel.onFilterChanged(entry)
    local panel = entry and entry.parent or nil
    if panel and panel.populateZones then panel:populateZones(panel:selectedZoneId()) end
end

function ParadiseDev.Zones.Panel:createChildren()
    ISCollapsableWindow.createChildren(self)
    ParadiseDev.Zones.enableWindowResize(self)

    local contentX = 13
    local top = self:titleBarHeight() + 8
    self.totalLabel = ParadiseDev.Zones.addLabel(self, "Total Zones: 0", contentX + 8, top, nil, UIFont.Medium)
    self.infoLabel = ParadiseDev.Zones.addLabel(self, "Double-click a zone for segments, priority, Z levels, and advanced access",
        contentX + 185, top, { r = 0.75, g = 0.88, b = 1.0 }, UIFont.Medium)

    self.zoneList = ISScrollingListBox:new(contentX, top + FONT_MEDIUM + 12 + ENTRY_HGT, self.width - 26, 220)
    self.zoneList:initialise()
    self.zoneList:instantiate()
    self.zoneList.itemheight = 24
    self.zoneList.selected = 0
    self.zoneList.font = UIFont.Small
    self.zoneList.doDrawItem = ParadiseDev.Zones.Panel.drawZoneItem
    self.zoneList.drawBorder = true
    self.zoneList.borderColor = { r = 0.2, g = 0.2, b = 0.5, a = 0.1 }
    self.zoneList.altBgColor = { r = 0.1, g = 0.1, b = 0.7, a = 0.3 }
    self.zoneList.listHeaderColor = { r = 0.0, g = 0.0, b = 0.4, a = 0.1 }
    self.zoneList:addColumn("Name", 4)
    self.zoneList:addColumn("Point 1", 235)
    self.zoneList:addColumn("Point 2 / Segments", 390)
    self.zoneList:addColumn("Pri", 555)
    self.zoneList:addColumn("Flags", 620)
    self.zoneList:setOnMouseDoubleClick(self, ParadiseDev.Zones.Panel.onEditZone)
    self:addChild(self.zoneList)

    local bigW, halfW, iconW, buttonH, spacing = 160, 78, 32, 32, 4
    self.point1Button = ParadiseDev.Zones.addImageButton(self, 0, 0, bigW, buttonH, PANEL_TEXTURES.point1,
        "POINT1", "Set point 1 of the primary segment to your server position", ParadiseDev.Zones.Panel.onPanelButton)
    self.deleteButton = ParadiseDev.Zones.addImageButton(self, 0, 0, bigW, buttonH, PANEL_TEXTURES.deleteOff,
        "DELETE", "Delete the selected zone", ParadiseDev.Zones.Panel.onPanelButton)
    self.restoreButton = ParadiseDev.Zones.addImageButton(self, 0, 0, halfW, buttonH, PANEL_TEXTURES.reset,

        "RESTORE", "Restore the last in-memory server backup", ParadiseDev.Zones.Panel.onPanelButton)
    self.backupButton = ParadiseDev.Zones.addImageButton(self, 0, 0, halfW, buttonH, PANEL_TEXTURES.backup,
        "BACKUP", "Capture an in-memory server backup of all zones", ParadiseDev.Zones.Panel.onPanelButton)

    self.featureButtons = {}
    for index = 1, 9 do
        local def = FEATURE_DEFS[index]
        self.featureButtons[def.key] = ParadiseDev.Zones.addImageButton(self, 0, 0, iconW, buttonH, def.offTexture,
            "FEATURE:" .. def.key, def.tooltip, ParadiseDev.Zones.Panel.onPanelButton)
    end

    self.point2Button = ParadiseDev.Zones.addImageButton(self, 0, 0, bigW, buttonH, PANEL_TEXTURES.point2,
        "POINT2", "Set point 2 of the primary segment to your server position", ParadiseDev.Zones.Panel.onPanelButton)
    self.teleportButton = ParadiseDev.Zones.addImageButton(self, 0, 0, bigW, buttonH, PANEL_TEXTURES.teleportOff,
        "TELEPORT", "Teleport to the center of the selected zone's primary segment", ParadiseDev.Zones.Panel.onPanelButton)
    self.syncButton = ParadiseDev.Zones.addImageButton(self, 0, 0, bigW, buttonH, PANEL_TEXTURES.sync,
        "SYNC", "Gold means zone state changed since the last explicit server re-broadcast", ParadiseDev.Zones.Panel.onPanelButton)

    for index = 10, 18 do
        local def = FEATURE_DEFS[index]
        self.featureButtons[def.key] = ParadiseDev.Zones.addImageButton(self, 0, 0, iconW, buttonH, def.offTexture,
            "FEATURE:" .. def.key, def.tooltip, ParadiseDev.Zones.Panel.onPanelButton)
    end

    self.filtersLabel = ParadiseDev.Zones.addLabel(self, "Filters:", contentX, 0, nil, UIFont.Medium)
    self.nameFilter = ParadiseDev.Zones.addEntry(self, "", contentX, 0, 226)
    self.point1Filter = ParadiseDev.Zones.addEntry(self, "", contentX + 231, 0, 150)
    self.point2Filter = ParadiseDev.Zones.addEntry(self, "", contentX + 386, 0, 160)
    self.flagsFilter = ParadiseDev.Zones.addEntry(self, "", contentX + 551, 0, self.width - 577)
    self.nameFilter.tooltip = "Filter by zone name"
    self.point1Filter.tooltip = "Filter by point 1"
    self.point2Filter.tooltip = "Filter by point 2 or segment count"
    self.flagsFilter.tooltip = "Filter by feature flags"
    self.nameFilter.onTextChange = ParadiseDev.Zones.Panel.onFilterChanged
    self.point1Filter.onTextChange = ParadiseDev.Zones.Panel.onFilterChanged
    self.point2Filter.onTextChange = ParadiseDev.Zones.Panel.onFilterChanged
    self.flagsFilter.onTextChange = ParadiseDev.Zones.Panel.onFilterChanged

    self.newZoneLabel = ParadiseDev.Zones.addLabel(self, "New Zone:", contentX, 0, nil, UIFont.Medium)
    self.newZoneName = ParadiseDev.Zones.addEntry(self, "", contentX, 0, 220)
    self.newZoneName.tooltip = "Zone name (server creates a stable ID)"
    self.newX1 = ParadiseDev.Zones.addEntry(self, "", contentX + 226, 0, 105)
    self.newX1.tooltip = "X1 (blank uses player X - 5)"
    self.newY1 = ParadiseDev.Zones.addEntry(self, "", contentX + 337, 0, 105)
    self.newY1.tooltip = "Y1 (blank uses player Y - 5)"
    self.newX2 = ParadiseDev.Zones.addEntry(self, "", contentX + 448, 0, 105)
    self.newX2.tooltip = "X2 (blank uses player X + 5)"
    self.newY2 = ParadiseDev.Zones.addEntry(self, "", contentX + 559, 0, 105)
    self.newY2.tooltip = "Y2 (blank uses player Y + 5)"
    self.addButton = ParadiseDev.Zones.addImageButton(self, contentX + 670, 0, 125, ENTRY_HGT,
        PANEL_TEXTURES.add, "ADD", "Create the zone on the server", ParadiseDev.Zones.Panel.onPanelButton)
    self.statusLabel = ParadiseDev.Zones.addLabel(self, "Requesting authoritative zone state...", contentX + 810, 0,
        { r = 0.70, g = 0.90, b = 0.70 })

    self:layoutChildren()
    self:populateZones(nil)
    ParadiseDev.Zones.send("requestAdminState")
end

function ParadiseDev.Zones.Panel:layoutChildren()
    local contentX, contentW = 13, self.width - 26
    local top = self:titleBarHeight() + 8
    local listY = top + FONT_MEDIUM + 12 + ENTRY_HGT
    local listHeight = math.max(120, self.height - listY - 246)
    self.zoneList:setX(contentX)
    self.zoneList:setY(listY)
    self.zoneList:setWidth(contentW)
    self.zoneList:setHeight(listHeight)
    self.zoneList.columns[1].size = 4
    self.zoneList.columns[2].size = math.floor(contentW * 0.20)
    self.zoneList.columns[3].size = math.floor(contentW * 0.33)
    self.zoneList.columns[4].size = math.floor(contentW * 0.47)
    self.zoneList.columns[5].size = math.floor(contentW * 0.53)

    local bigW, halfW, iconW, buttonH, spacing = 160, 78, 32, 32, 4
    local buttonY = self.zoneList:getBottom() + 12
    local buttonY2 = buttonY + buttonH + spacing
    local firstRow = { self.point1Button, self.deleteButton, self.restoreButton, self.backupButton }
    local firstX = { contentX, contentX + 164, contentX + 328, contentX + 410 }
    for index, button in ipairs(firstRow) do button:setX(firstX[index]); button:setY(buttonY) end
    local x = contentX + 492
    for index = 1, 9 do
        local button = self.featureButtons[FEATURE_DEFS[index].key]
        button:setX(x); button:setY(buttonY); x = x + iconW + spacing
    end

    self.point2Button:setX(contentX); self.point2Button:setY(buttonY2)
    self.teleportButton:setX(contentX + 164); self.teleportButton:setY(buttonY2)
    self.syncButton:setX(contentX + 328); self.syncButton:setY(buttonY2)
    x = contentX + 495
    for index = 10, 18 do
        local button = self.featureButtons[FEATURE_DEFS[index].key]
        button:setX(x); button:setY(buttonY2); x = x + iconW + spacing
    end

    local filterY = buttonY2 + buttonH + 9
    local entryY = filterY + FONT_MEDIUM + 3
    self.filtersLabel:setX(contentX); self.filtersLabel:setY(filterY)
    local col2 = math.floor(contentW * 0.20)

    local col3 = math.floor(contentW * 0.33)
    local flagsX = math.floor(contentW * 0.47)
    self.nameFilter:setX(contentX); self.nameFilter:setY(entryY); self.nameFilter:setWidth(col2 - 5)
    self.point1Filter:setX(contentX + col2); self.point1Filter:setY(entryY); self.point1Filter:setWidth(col3 - col2 - 5)
    self.point2Filter:setX(contentX + col3); self.point2Filter:setY(entryY); self.point2Filter:setWidth(flagsX - col3 - 5)
    self.flagsFilter:setX(contentX + flagsX); self.flagsFilter:setY(entryY); self.flagsFilter:setWidth(contentW - flagsX)

    local newLabelY = entryY + ENTRY_HGT + 9
    local newY = newLabelY + FONT_MEDIUM + 3
    self.newZoneLabel:setX(contentX); self.newZoneLabel:setY(newLabelY)
    local newControls = { self.newZoneName, self.newX1, self.newY1, self.newX2, self.newY2, self.addButton }
    local newX = { 0, 226, 337, 448, 559, 670 }
    for index, control in ipairs(newControls) do control:setX(contentX + newX[index]); control:setY(newY) end
    self.statusLabel:setX(contentX + 810); self.statusLabel:setY(newY + 2)
    self._lastLayoutW, self._lastLayoutH = self.width, self.height
end
function ParadiseDev.Zones.Panel:selectedZone()
    local item = self.zoneList.items[self.zoneList.selected]
    return item and item.item or nil
end

function ParadiseDev.Zones.Panel:selectedZoneId()
    local zone = self:selectedZone()
    return zone and zone.id or nil
end

function ParadiseDev.Zones.containsPlain(value, filter)
    filter = string.lower(tostring(filter or ""))
    if filter == "" then return true end
    return string.find(string.lower(tostring(value or "")), filter, 1, true) ~= nil
end

function ParadiseDev.Zones.Panel:zoneMatchesFilters(zone)
    local segment = ParadiseDev.Zones.primarySegment(zone)
    local point1 = segment and (tostring(segment.x1) .. "," .. tostring(segment.y1)) or ""
    local point2 = segment and (tostring(segment.x2) .. "," .. tostring(segment.y2)) or ""
    point2 = point2 .. " " .. tostring(#(zone.segments or {}))
    return ParadiseDev.Zones.containsPlain(zone.name, self.nameFilter and self.nameFilter:getText()) and
        ParadiseDev.Zones.containsPlain(point1, self.point1Filter and self.point1Filter:getText()) and
        ParadiseDev.Zones.containsPlain(point2, self.point2Filter and self.point2Filter:getText()) and
        ParadiseDev.Zones.containsPlain(ParadiseDev.Zones.activeFlags(zone), self.flagsFilter and self.flagsFilter:getText())
end

function ParadiseDev.Zones.Panel:populateZones(preferredId)
    self.zoneList:clear()
    local selected, visible = 0, 0
    for _, zone in ipairs(ParadiseDev.Zones.adminZones) do
        if self:zoneMatchesFilters(zone) then
            visible = visible + 1
            self.zoneList:addItem(zone.name or zone.id, zone)
            if preferredId and zone.id == preferredId then selected = visible end
        end
    end
    self.zoneList.selected = selected
    self._lastSelection = -1
    self.totalLabel:setName("Total Zones: " .. tostring(#ParadiseDev.Zones.adminZones) ..
        (visible ~= #ParadiseDev.Zones.adminZones and " (" .. tostring(visible) .. " shown)" or ""))
end

function ParadiseDev.Zones.Panel.drawZoneItem(list, y, item, alt)
    if y + list:getYScroll() + list.itemheight < 0 or y + list:getYScroll() >= list.height then
        return y + list.itemheight
    end
    local zone = item.item
    if list.selected == item.index then
        list:drawRect(0, y, list:getWidth(), list.itemheight, 0.32, 0.70, 0.35, 0.16)
    elseif alt then
        list:drawRect(0, y, list:getWidth(), list.itemheight, 0.13, 0.30, 0.32, 0.32)
    end
    list:drawRectBorder(0, y, list:getWidth(), list.itemheight, 0.45, 0.30, 0.35, 0.45)
    local segment = ParadiseDev.Zones.primarySegment(zone)
    local p1 = segment and (segment.x1 .. "," .. segment.y1) or "-"
    local p2 = segment and (segment.x2 .. "," .. segment.y2) or "-"
    local count = #(zone.segments or {})
    if count > 1 then p2 = p2 .. "  [" .. tostring(count) .. "]" end
    list:drawText(zone.name or zone.id, list.columns[1].size + 10, y + 4, 1, 1, 1, 0.95, list.font)
    list:drawText(p1, list.columns[2].size + 10, y + 4, 0.82, 0.82, 0.82, 0.95, list.font)
    list:drawText(p2, list.columns[3].size + 10, y + 4, 0.82, 0.82, 0.82, 0.95, list.font)
    list:drawText(tostring(zone.priority or 0), list.columns[4].size + 10, y + 4, 0.95, 0.85, 0.45, 0.95, list.font)
    list:drawText(ParadiseDev.Zones.activeFlags(zone), list.columns[5].size + 10, y + 4, 0.70, 0.90, 1.0, 0.95, list.font)
    return y + list.itemheight
end
function ParadiseDev.Zones.Panel:updateSelection()
    local zone = self:selectedZone()
    local hasZone = zone ~= nil
    self.point1Button.enable = hasZone
    self.point2Button.enable = hasZone
    self.deleteButton.enable = hasZone
    self.teleportButton.enable = hasZone
    self.deleteButton:setImage(hasZone and PANEL_TEXTURES.delete or PANEL_TEXTURES.deleteOff)
    self.teleportButton:setImage(hasZone and PANEL_TEXTURES.teleport or PANEL_TEXTURES.teleportOff)
    for key, button in pairs(self.featureButtons) do
        button.enable = hasZone
        local def = FEATURE_BY_KEY[key]
        local active = hasZone and zone.features and zone.features[key] == true
        button:setImage(active and def.onTexture or def.offTexture)
    end
end

function ParadiseDev.Zones.Panel:prerender()

    if self._lastLayoutW ~= self.width or self._lastLayoutH ~= self.height then self:layoutChildren() end
    ParadiseDev.Zones.layoutWindowChrome(self)
    ISCollapsableWindow.prerender(self)
    if PANEL_TEXTURES.background then
        local bgX = (self.width - PANEL_TEXTURES.background:getWidth()) / 2
        self:drawTexture(PANEL_TEXTURES.background, bgX, 45, 0.30, 1, 1, 1)
    end
    self.syncButton:setImage(self.shouldSync and PANEL_TEXTURES.syncOn or PANEL_TEXTURES.sync)
    if self.zoneList.selected ~= self._lastSelection then
        self._lastSelection = self.zoneList.selected
        self:updateSelection()
    end
end
function ParadiseDev.Zones.Panel:onEditZone(zone)
    if not zone then return end
    if ParadiseDev.Zones.editorWindow then ParadiseDev.Zones.editorWindow:close() end
    local width, height = 950, 520
    local x = math.max(0, (getCore():getScreenWidth() - width) / 2 + 220)
    local y = math.max(0, (getCore():getScreenHeight() - height) / 2)
    ParadiseDev.Zones.editorWindow = ParadiseDev.Zones.Editor:new(x, y, width, height, zone.id, self)
    ParadiseDev.Zones.editorWindow:initialise()
    ParadiseDev.Zones.editorWindow:addToUIManager()
end

function ParadiseDev.Zones.Panel:onPanelButton(button)
    local internal = button.internal
    local zone = self:selectedZone()

    if internal == "ADD" then
        self:markDirty()
        ParadiseDev.Zones.send("quickCreateZone", {
            name = self.newZoneName:getText(),
            x1 = self.newX1:getText(), y1 = self.newY1:getText(),
            x2 = self.newX2:getText(), y2 = self.newY2:getText(),
        })
        self.newZoneName:setText("")
        self.newX1:setText("")
        self.newY1:setText("")
        self.newX2:setText("")
        self.newY2:setText("")
        return
    elseif internal == "BACKUP" then
        ParadiseDev.Zones.send("backupZones")
        return
    elseif internal == "RESTORE" then
        local modal = ISModalDialog:new(
            getCore():getScreenWidth() / 2 - 175, getCore():getScreenHeight() / 2 - 75,
            350, 150, "Restore the last in-memory server zone backup?",
            true, self, ParadiseDev.Zones.Panel.onRestoreConfirmed, nil
        )
        modal:initialise()
        modal:addToUIManager()
        return
    elseif internal == "SYNC" then
        self.syncRequested = true
        ParadiseDev.Zones.send("syncZones")
        return
    end

    if not zone then return end
    if string.sub(internal, 1, 8) == "FEATURE:" then
        local key = string.sub(internal, 9)
        self:markDirty()
        ParadiseDev.Zones.send("toggleFeature", {
            id = zone.id,
            feature = key,
            enabled = not (zone.features and zone.features[key] == true),
        })
    elseif internal == "POINT1" then
        self:markDirty()
        ParadiseDev.Zones.send("setPrimaryPoint", { id = zone.id, corner = 1 })
    elseif internal == "POINT2" then
        self:markDirty()
        ParadiseDev.Zones.send("setPrimaryPoint", { id = zone.id, corner = 2 })
    elseif internal == "TELEPORT" then
        ParadiseDev.Zones.send("teleportToZone", { id = zone.id })
    elseif internal == "DELETE" then
        local modal = ISModalDialog:new(
            getCore():getScreenWidth() / 2 - 175, getCore():getScreenHeight() / 2 - 75,
            350, 150, "Delete zone '" .. tostring(zone.name) .. "' and all of its segments?",
            true, self, ParadiseDev.Zones.Panel.onDeleteConfirmed, nil, zone.id
        )
        modal:initialise()
        modal:addToUIManager()
    end
end
function ParadiseDev.Zones.Panel:onDeleteConfirmed(button, id)
    if button.internal == "YES" then
        self:markDirty()
        ParadiseDev.Zones.send("deleteZone", { id = id })
    end
end

function ParadiseDev.Zones.Panel:onRestoreConfirmed(button)
    if button.internal == "YES" then
        self:markDirty()
        ParadiseDev.Zones.send("restoreZones")
    end
end

function ParadiseDev.Zones.Panel:setServerState(args)
    local selectedId = self:selectedZoneId()
    ParadiseDev.Zones.adminZones = args.zones or {}
    ParadiseDev.Zones.serverVehicleMode = args.vehicleMode or "observe"
    self:populateZones(selectedId)
    self.statusLabel:setName("Server: " .. tostring(#ParadiseDev.Zones.adminZones) .. " zones; border " ..
        tostring(args.borderWidth or 2) .. " tiles.")
    if self.syncRequested then
        self.syncRequested = false
        self.shouldSync = false
    end
    if ParadiseDev.Zones.editorWindow then ParadiseDev.Zones.editorWindow:refreshFromState() end
end

function ParadiseDev.Zones.Panel:markDirty()
    self.shouldSync = true
    if self.syncButton then self.syncButton:setImage(PANEL_TEXTURES.syncOn) end
end

function ParadiseDev.Zones.markZoneDirty()
    if ParadiseDev.Zones.window then ParadiseDev.Zones.window:markDirty() end
end
function ParadiseDev.Zones.Panel:setStatus(text)
    if self.statusLabel then self.statusLabel:setName(tostring(text or "")) end
end

function ParadiseDev.Zones.Panel:close()
    if ParadiseDev.Zones.editorWindow then ParadiseDev.Zones.editorWindow:close() end
    self:setVisible(false)
    self:removeFromUIManager()
    if ParadiseDev.Zones.window == self then ParadiseDev.Zones.window = nil end
end

function ParadiseDev.Zones.Panel:new(x, y, width, height)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.title = "ParadiseZ Zone Editor"
    o.resizable = true
    o.minimumWidth = 900
    o.minimumHeight = 480
    o.shouldSync = false
    o.syncRequested = false
    o.borderColor = { r = 0.81, g = 0.92, b = 0.84, a = 0.75 }
    o.backgroundColor = { r = 0.18, g = 0.02, b = 0.22, a = 0.80 }
    o.moveWithMouse = true
    return o
end

function ParadiseDev.Zones.Panel:titleBarHeight()
    return 24
end

ParadiseDev.Zones.Editor = ISCollapsableWindow:derive("ParadiseDev.Zones.Editor")

function ParadiseDev.Zones.Editor:createChildren()
    ISCollapsableWindow.createChildren(self)
    ParadiseDev.Zones.enableWindowResize(self)
    local top = self:titleBarHeight() + GAP
    local leftX, leftW = GAP, 330
    local rightX = leftX + leftW + GAP
    local fieldX = rightX + 108
    local fieldW = self.width - fieldX - GAP

    self.segmentTitle = ParadiseDev.Zones.addLabel(self, "Segments (rectangles sharing this zone ID)", leftX, top)
    self.segmentList = ISScrollingListBox:new(leftX, top + ENTRY_HGT, leftW, 180)
    self.segmentList:initialise()
    self.segmentList:instantiate()
    self.segmentList.itemheight = 24
    self.segmentList.selected = 0
    self.segmentList.font = UIFont.Small
    self.segmentList.doDrawItem = ParadiseDev.Zones.Editor.drawSegmentItem
    self:addChild(self.segmentList)

    self.addSegmentButton = ParadiseDev.Zones.addButton(self, "Add Segment", leftX, 0, 105, self, ParadiseDev.Zones.Editor.onAddSegment)
    self.saveSegmentButton = ParadiseDev.Zones.addButton(self, "Save Segment", leftX + 109, 0, 105, self, ParadiseDev.Zones.Editor.onSaveSegment)
    self.removeSegmentButton = ParadiseDev.Zones.addButton(self, "Remove", leftX + 218, 0, 104, self, ParadiseDev.Zones.Editor.onRemoveSegment)
    self.activeFeaturesTitle = ParadiseDev.Zones.addLabel(self, "Active features", leftX, 0, { r = 1, g = 0.85, b = 0.35 })
    self.featureLine1 = ParadiseDev.Zones.addLabel(self, "", leftX, 0, { r = 0.70, g = 0.90, b = 1.0 })
    self.featureLine2 = ParadiseDev.Zones.addLabel(self, "", leftX, 0, { r = 0.70, g = 0.90, b = 1.0 })

    local y = top
    ParadiseDev.Zones.addLabel(self, "Zone ID", rightX, y)
    self.idEntry = ParadiseDev.Zones.addEntry(self, "", fieldX, y, fieldW)
    self.idEntry:setEditable(false)
    y = y + ENTRY_HGT + GAP
    ParadiseDev.Zones.addLabel(self, "Display name", rightX, y)
    self.nameEntry = ParadiseDev.Zones.addEntry(self, "", fieldX, y, fieldW)
    y = y + ENTRY_HGT + GAP
    ParadiseDev.Zones.addLabel(self, "Priority", rightX, y)
    self.priorityEntry = ParadiseDev.Zones.addEntry(self, "0", fieldX, y, 100)

    y = y + ENTRY_HGT + GAP
    ParadiseDev.Zones.addLabel(self, "Z levels", rightX, y)
    self.zModeCombo = ISComboBox:new(fieldX, y, 155, ENTRY_HGT, self, nil)
    self.zModeCombo:initialise()
    self.zModeCombo:instantiate()
    self.zModeCombo:addOptionWithData("All Z levels", "all")
    self.zModeCombo:addOptionWithData("Floor range", "floor")

    self:addChild(self.zModeCombo)
    ParadiseDev.Zones.addLabel(self, "Min", fieldX + 166, y)
    self.zMinEntry = ParadiseDev.Zones.addEntry(self, "0", fieldX + 198, y, 55)
    ParadiseDev.Zones.addLabel(self, "Max excl.", fieldX + 263, y)
    self.zMaxEntry = ParadiseDev.Zones.addEntry(self, "1", fieldX + 323, y, 55)

    y = y + ENTRY_HGT + GAP
    ParadiseDev.Zones.addLabel(self, "Deny tags", rightX, y)
    self.denyEntry = ParadiseDev.Zones.addEntry(self, "", fieldX, y, fieldW)
    y = y + ENTRY_HGT + GAP
    ParadiseDev.Zones.addLabel(self, "Require any", rightX, y)
    self.requireEntry = ParadiseDev.Zones.addEntry(self, "", fieldX, y, fieldW)

    y = y + ENTRY_HGT + GAP
    self.adminBypass = ISTickBox:new(fieldX, y, 190, ENTRY_HGT, "", self, nil)
    self.adminBypass:initialise()
    self.adminBypass:instantiate()
    self.adminBypass:addOption("Admins bypass policy")
    self:addChild(self.adminBypass)

    y = y + ENTRY_HGT + GAP * 2
    self.cornersTitle = ParadiseDev.Zones.addLabel(self, "Selected segment corners", rightX, y, { r = 1, g = 0.85, b = 0.35 })
    y = y + ENTRY_HGT
    ParadiseDev.Zones.addLabel(self, "Point 1", rightX, y)
    self.x1Entry = ParadiseDev.Zones.addEntry(self, "", fieldX, y, 85)
    self.y1Entry = ParadiseDev.Zones.addEntry(self, "", fieldX + 90, y, 85)
    self.point1Button = ParadiseDev.Zones.addButton(self, "Use Player", fieldX + 180, y, 95, self, ParadiseDev.Zones.Editor.onPoint1)
    y = y + ENTRY_HGT + GAP
    ParadiseDev.Zones.addLabel(self, "Point 2", rightX, y)
    self.x2Entry = ParadiseDev.Zones.addEntry(self, "", fieldX, y, 85)
    self.y2Entry = ParadiseDev.Zones.addEntry(self, "", fieldX + 90, y, 85)
    self.point2Button = ParadiseDev.Zones.addButton(self, "Use Player", fieldX + 180, y, 95, self, ParadiseDev.Zones.Editor.onPoint2)

    y = y + ENTRY_HGT + GAP * 2
    self.saveButton = ParadiseDev.Zones.addButton(self, "Save Zone Settings", rightX, y, 160, self, ParadiseDev.Zones.Editor.onSave)
    self.closeEditorButton = ParadiseDev.Zones.addButton(self, "Close", rightX + 168, y, 90, self, ParadiseDev.Zones.Editor.onCloseButton)
    y = y + ENTRY_HGT + GAP * 2
    self.advancedHelp = ParadiseDev.Zones.addLabel(self,
        "Advanced policy tags are comma-separated. Z maximum is exclusive.", rightX, y,
        { r = 0.65, g = 0.72, b = 0.78 })

    self.statusLabel = ParadiseDev.Zones.addLabel(self, "", GAP, self.height - ENTRY_HGT - GAP - self:resizeWidgetHeight(),
        { r = 0.75, g = 0.9, b = 0.75 })
    self:layoutChildren()
    self:loadZone(ParadiseDev.Zones.zoneById(self.zoneId))
end

function ParadiseDev.Zones.Editor.drawSegmentItem(list, y, item, alt)
    if y + list:getYScroll() + list.itemheight < 0 or y + list:getYScroll() >= list.height then
        return y + list.itemheight
    end
    if list.selected == item.index then
        list:drawRect(0, y, list:getWidth(), list.itemheight, 0.32, 0.70, 0.35, 0.16)
    elseif alt then
        list:drawRect(0, y, list:getWidth(), list.itemheight, 0.13, 0.30, 0.32, 0.32)
    end
    list:drawRectBorder(0, y, list:getWidth(), list.itemheight, 0.45, 0.30, 0.35, 0.45)
    list:drawText(item.text, 10, y + 1, 1, 1, 1, 0.95, list.font)
    return y + list.itemheight
end

function ParadiseDev.Zones.Editor:layoutChildren()
    local top = self:titleBarHeight() + GAP
    local listHeight = math.max(120, self.height - top - 170)
    self.segmentList:setY(top + ENTRY_HGT)
    self.segmentList:setHeight(listHeight)
    local buttonsY = self.segmentList:getBottom() + GAP
    self.addSegmentButton:setY(buttonsY)
    self.saveSegmentButton:setY(buttonsY)
    self.removeSegmentButton:setY(buttonsY)
    local featureY = buttonsY + ENTRY_HGT + GAP * 2
    self.activeFeaturesTitle:setY(featureY)
    self.featureLine1:setY(featureY + ENTRY_HGT)
    self.featureLine2:setY(featureY + ENTRY_HGT + FONT_SMALL)

    local fieldX = GAP + 330 + GAP + 108
    local fieldW = math.max(120, self.width - fieldX - GAP)
    self.idEntry:setWidth(fieldW)
    self.nameEntry:setWidth(fieldW)
    self.denyEntry:setWidth(fieldW)
    self.requireEntry:setWidth(fieldW)
    self.statusLabel:setY(self.height - ENTRY_HGT - GAP - self:resizeWidgetHeight())
    self._lastLayoutW, self._lastLayoutH = self.width, self.height
end
function ParadiseDev.Zones.Editor:selectedSegment()
    local item = self.segmentList.items[self.segmentList.selected]
    return item and item.item or nil
end

function ParadiseDev.Zones.Editor:loadZone(zone)
    if not zone then
        self.statusLabel:setName("Zone no longer exists.")
        self.saveButton.enable = false
        return
    end
    self.zoneId = zone.id
    self.title = "Edit Zone: " .. tostring(zone.name)
    self.idEntry:setText(zone.id)
    self.nameEntry:setText(zone.name or zone.id)
    self.priorityEntry:setText(tostring(zone.priority or 0))

    self.zModeCombo:setSelectedData(zone.zMode or "all")
    self.zMinEntry:setText(tostring(zone.zMin or 0))
    self.zMaxEntry:setText(tostring(zone.zMaxExclusive or 1))
    self.denyEntry:setText(zone.denyTags or "")
    self.requireEntry:setText(zone.requireTags or "")
    self.adminBypass:setSelected(1, zone.adminBypass ~= false)

    local names = {}
    for _, def in ipairs(FEATURE_DEFS) do
        if zone.features and zone.features[def.key] then names[#names + 1] = def.label end
    end
    local first, second = {}, {}
    for index, name in ipairs(names) do
        if index <= 9 then first[#first + 1] = name else second[#second + 1] = name end
    end
    self.featureLine1:setName(#first > 0 and table.concat(first, ", ") or "None")
    self.featureLine2:setName(table.concat(second, ", "))

    local selected = self:selectedSegment()
    local selectedIndex = selected and selected.index or 1
    self.segmentList:clear()
    self.segmentList.selected = 0
    for _, segment in ipairs(zone.segments or {}) do
        self.segmentList:addItem(
            tostring(segment.index) .. ": (" .. segment.x1 .. "," .. segment.y1 .. ") to (" ..
            segment.x2 .. "," .. segment.y2 .. ")", segment
        )
        if segment.index == selectedIndex then self.segmentList.selected = #self.segmentList.items end
    end
    if self.segmentList.selected == 0 and #self.segmentList.items > 0 then self.segmentList.selected = 1 end
    self._lastSegmentSelection = -1
    self.saveButton.enable = true
end

function ParadiseDev.Zones.Editor:refreshFromState()
    local zone = ParadiseDev.Zones.zoneById(self.zoneId)
    if not zone then
        self:close()
        return
    end
    self:loadZone(zone)
end

function ParadiseDev.Zones.Editor:prerender()
    if self._lastLayoutW ~= self.width or self._lastLayoutH ~= self.height then self:layoutChildren() end
    ParadiseDev.Zones.layoutWindowChrome(self)
    ISCollapsableWindow.prerender(self)
    if self.segmentList.selected ~= self._lastSegmentSelection then
        self._lastSegmentSelection = self.segmentList.selected
        local segment = self:selectedSegment()
        if segment then
            self.x1Entry:setText(tostring(segment.x1))
            self.y1Entry:setText(tostring(segment.y1))
            self.x2Entry:setText(tostring(segment.x2))
            self.y2Entry:setText(tostring(segment.y2))
        end
    end
    local hasSegment = self:selectedSegment() ~= nil
    self.saveSegmentButton.enable = hasSegment
    self.removeSegmentButton.enable = hasSegment
end
function ParadiseDev.Zones.Editor:zoneArgs(includeRegion)
    local args = {
        id = self.zoneId,
        name = self.nameEntry:getText(),
        priority = self.priorityEntry:getText(),
        zMode = self.zModeCombo:getOptionData(self.zModeCombo.selected),
        zMin = self.zMinEntry:getText(),
        zMaxExclusive = self.zMaxEntry:getText(),
        denyTags = self.denyEntry:getText(),
        requireTags = self.requireEntry:getText(),
        adminBypass = self.adminBypass:isSelected(1),
    }
    if includeRegion then
        args.x1, args.y1 = self.x1Entry:getText(), self.y1Entry:getText()
        args.x2, args.y2 = self.x2Entry:getText(), self.y2Entry:getText()
    end
    return args
end

function ParadiseDev.Zones.Editor:onSave()
    ParadiseDev.Zones.markZoneDirty()
    ParadiseDev.Zones.send("updateZone", self:zoneArgs(false))
end

function ParadiseDev.Zones.Editor:onAddSegment()
    ParadiseDev.Zones.markZoneDirty()
    ParadiseDev.Zones.send("addSegment", self:zoneArgs(true))
end

function ParadiseDev.Zones.Editor:onSaveSegment()
    local segment = self:selectedSegment()
    if not segment then return end
    ParadiseDev.Zones.markZoneDirty()
    local args = self:zoneArgs(true)
    args.regionIndex = segment.index
    ParadiseDev.Zones.send("updateSegment", args)
end

function ParadiseDev.Zones.Editor:onRemoveSegment()

    local segment = self:selectedSegment()
    if segment then
        ParadiseDev.Zones.markZoneDirty()
        ParadiseDev.Zones.send("removeSegment", { id = self.zoneId, regionIndex = segment.index })
    end
end

function ParadiseDev.Zones.setPoint(xEntry, yEntry)
    local pl = getPlayer()
    if not pl then return end
    xEntry:setText(tostring(math.floor(pl:getX())))
    yEntry:setText(tostring(math.floor(pl:getY())))
end

function ParadiseDev.Zones.Editor:onPoint1() ParadiseDev.Zones.setPoint(self.x1Entry, self.y1Entry) end
function ParadiseDev.Zones.Editor:onPoint2() ParadiseDev.Zones.setPoint(self.x2Entry, self.y2Entry) end

function ParadiseDev.Zones.Editor:onCloseButton()
    self:close()
end

function ParadiseDev.Zones.Editor:setStatus(text)
    if self.statusLabel then self.statusLabel:setName(tostring(text or "")) end
end

function ParadiseDev.Zones.Editor:close()
    self:setVisible(false)
    self:removeFromUIManager()
    if self.parentWindow and self.parentWindow.childEditor == self then
        self.parentWindow.childEditor = nil
    end
    if ParadiseDev.Zones.editorWindow == self then ParadiseDev.Zones.editorWindow = nil end
end

function ParadiseDev.Zones.Editor:new(x, y, width, height, zoneId, parent)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.title = "Edit Zone"
    o.resizable = true
    o.minimumWidth = 800
    o.minimumHeight = 480
    o.zoneId = zoneId
    o.parentWindow = parent
    if parent then parent.childEditor = o end
    return o
end

ParadiseDev.Zones.TestRemote = ISCollapsableWindow:derive("ParadiseDev.Zones.TestRemote")

function ParadiseDev.Zones.TestRemote:createChildren()
    ISCollapsableWindow.createChildren(self)
    ParadiseDev.Zones.enableWindowResize(self)
    local x, y = GAP, self:titleBarHeight() + GAP
    self.showBorders = ISTickBox:new(x, y, 180, ENTRY_HGT, "", self, ParadiseDev.Zones.TestRemote.onShowBorders)
    self.showBorders:initialise()
    self.showBorders:instantiate()
    self.showBorders:addOption("Show zone borders")
    self.showBorders:setSelected(1, ParadiseDev.Zones.Visualization == nil or ParadiseDev.Zones.Visualization.enabled)
    self:addChild(self.showBorders)
    self.borderLegend = ParadiseDev.Zones.addLabel(self, "Blue: 2 outside    Orange: 2 inside", x + 190, y + 2,
        { r = 0.55, g = 0.78, b = 1.0 })

    y = y + ENTRY_HGT + GAP
    self.vehicleLabel = ParadiseDev.Zones.addLabel(self, "Vehicle", x, y + 2)
    self.vehicleCombo = ISComboBox:new(x + 70, y, 180, ENTRY_HGT, self, nil)
    self.vehicleCombo:initialise()
    self.vehicleCombo:instantiate()
    self.vehicleCombo:addOptionWithData("Observe only", "observe")
    self.vehicleCombo:addOptionWithData("Rebound", "rebound")
    self.vehicleCombo:setSelectedData(ParadiseDev.Zones.serverVehicleMode)
    self:addChild(self.vehicleCombo)
    self.applyVehicleButton = ParadiseDev.Zones.addButton(self, "Apply Vehicle Mode", x + 258, y, 155, self, ParadiseDev.Zones.TestRemote.onApplyVehicle)

    y = y + ENTRY_HGT + GAP
    self.targetLabel = ParadiseDev.Zones.addLabel(self, "Target", x, y + 2)
    self.targetUser = ParadiseDev.Zones.addEntry(self, getPlayer() and getPlayer():getUsername() or "Jim", x + 70, y, 180)
    y = y + ENTRY_HGT + GAP
    self.profileLabel = ParadiseDev.Zones.addLabel(self, "Profile", x, y + 2)
    self.profileCombo = ISComboBox:new(x + 70, y, 180, ENTRY_HGT, self, nil)
    self.profileCombo:initialise()
    self.profileCombo:instantiate()
    self.profileCombo:addOptionWithData("No tags", "none")
    self.profileCombo:addOptionWithData("PvE", "pve")
    self.profileCombo:addOptionWithData("Range staff", "range_staff")
    self.profileCombo:addOptionWithData("PvE + range", "both")
    self:addChild(self.profileCombo)
    self.applyProfileButton = ParadiseDev.Zones.addButton(self, "Apply Test Profile", x + 258, y, 155, self, ParadiseDev.Zones.TestRemote.onApplyProfile)

    y = y + ENTRY_HGT + GAP * 2
    self.featureLabel = ParadiseDev.Zones.addLabel(self, "Feature-zone tester (all ParadiseZ zone flags)", x, y,
        { r = 1, g = 0.85, b = 0.35 })
    y = y + ENTRY_HGT
    self.featureCombo = ISComboBox:new(x, y, self.width - GAP * 2, ENTRY_HGT, self, nil)
    self.featureCombo:initialise()
    self.featureCombo:instantiate()
    for _, def in ipairs(FEATURE_DEFS) do
        self.featureCombo:addOptionWithData(def.label .. "  (" .. def.key .. ")", def.key)
    end

    self:addChild(self.featureCombo)
    y = y + ENTRY_HGT + GAP
    self.testFeatureButton = ParadiseDev.Zones.addButton(self, "Move Target to Nearest Feature Zone", x, y, 270, self, ParadiseDev.Zones.TestRemote.onTestFeature)
    self.probeButton = ParadiseDev.Zones.addButton(self, "Probe Target's Current Authority", x + 278, y, 240, self, ParadiseDev.Zones.TestRemote.onProbe)
    y = y + ENTRY_HGT + GAP
    self.cageButton = ParadiseDev.Zones.addButton(self, "Cage Target", x, y, 160, self, ParadiseDev.Zones.TestRemote.onCage)
    self.releaseButton = ParadiseDev.Zones.addButton(self, "Release Target", x + 168, y, 160, self, ParadiseDev.Zones.TestRemote.onRelease)
    y = y + ENTRY_HGT + GAP * 2
    self.testHelp1 = ParadiseDev.Zones.addLabel(self, "Feature tester locates and teleports; it does not fake gameplay effects that are not ported yet.",
        x, y, { r = 0.65, g = 0.72, b = 0.78 })
    self.testHelp2 = ParadiseDev.Zones.addLabel(self, "Cage is server-authoritative and confines the target to the nearest Cage zone.",
        x, y + FONT_SMALL, { r = 0.65, g = 0.72, b = 0.78 })
    self.statusLabel = ParadiseDev.Zones.addLabel(self, "Requesting authoritative test state...", x,
        self.height - ENTRY_HGT - GAP - self:resizeWidgetHeight(), { r = 0.75, g = 0.9, b = 0.75 })
    self:layoutChildren()
    ParadiseDev.Zones.send("requestAdminState")
end

function ParadiseDev.Zones.TestRemote:layoutChildren()
    local contentW = self.width - GAP * 2
    self.featureCombo:setWidth(contentW)
    self.probeButton:setX(GAP + math.floor(contentW / 2) + 4)
    self.probeButton:setWidth(math.max(150, math.floor(contentW / 2) - 4))
    self.testFeatureButton:setWidth(math.max(180, math.floor(contentW / 2) - 4))
    self.statusLabel:setY(self.height - ENTRY_HGT - GAP - self:resizeWidgetHeight())
    self._lastLayoutW, self._lastLayoutH = self.width, self.height
end

function ParadiseDev.Zones.TestRemote:prerender()
    if self._lastLayoutW ~= self.width or self._lastLayoutH ~= self.height then self:layoutChildren() end
    ParadiseDev.Zones.layoutWindowChrome(self)
    ISCollapsableWindow.prerender(self)
end

function ParadiseDev.Zones.TestRemote:onShowBorders(index, selected)
    if ParadiseDev.Zones.Visualization then ParadiseDev.Zones.Visualization.setEnabled(selected) end
end

function ParadiseDev.Zones.TestRemote:onApplyVehicle()
    ParadiseDev.Zones.send("vehicleMode", { mode = self.vehicleCombo:getOptionData(self.vehicleCombo.selected) })
end

function ParadiseDev.Zones.TestRemote:onApplyProfile()
    ParadiseDev.Zones.send("profile", {
        username = self.targetUser:getText(),
        profile = self.profileCombo:getOptionData(self.profileCombo.selected),
    })
end

function ParadiseDev.Zones.TestRemote:onTestFeature()
    ParadiseDev.Zones.send("testFeature", {
        username = self.targetUser:getText(),
        feature = self.featureCombo:getOptionData(self.featureCombo.selected),
    })
end

function ParadiseDev.Zones.TestRemote:onProbe()
    ParadiseDev.Zones.send("probeFeature", { username = self.targetUser:getText() })
end

function ParadiseDev.Zones.TestRemote:onCage()
    ParadiseDev.Zones.send("cagePlayer", { username = self.targetUser:getText() })
end

function ParadiseDev.Zones.TestRemote:onRelease()
    ParadiseDev.Zones.send("uncagePlayer", { username = self.targetUser:getText() })
end

function ParadiseDev.Zones.TestRemote:setServerState(args)
    ParadiseDev.Zones.serverVehicleMode = args.vehicleMode or "observe"
    if self.vehicleCombo then self.vehicleCombo:setSelectedData(ParadiseDev.Zones.serverVehicleMode) end
end

function ParadiseDev.Zones.TestRemote:setStatus(text)
    if self.statusLabel then self.statusLabel:setName(tostring(text or "")) end
end

function ParadiseDev.Zones.TestRemote:close()
    self:setVisible(false)
    self:removeFromUIManager()
    if ParadiseDev.Zones.testWindow == self then ParadiseDev.Zones.testWindow = nil end
end

function ParadiseDev.Zones.TestRemote:new(x, y, width, height)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.title = "ParadiseZ Test Control Remote"
    o.resizable = true
    o.minimumWidth = 520
    o.minimumHeight = 390
    o.moveWithMouse = true
    return o
end

function ParadiseDev.Zones.openTestRemote()
    if not ParadiseDev.isAdm() then
        print("[PZZoneHarness] Admin access is required for the test remote.")
        return
    end

    if ParadiseDev.Zones.testWindow then
        ParadiseDev.Zones.testWindow:setVisible(true)
        ParadiseDev.Zones.testWindow:addToUIManager()
        ParadiseDev.Zones.send("requestAdminState")
        return
    end
    local width, height = 560, 410
    local x = math.max(0, (getCore():getScreenWidth() - width) / 2 + 260)
    local y = math.max(0, (getCore():getScreenHeight() - height) / 2)
    ParadiseDev.Zones.testWindow = ParadiseDev.Zones.TestRemote:new(x, y, width, height)
    ParadiseDev.Zones.testWindow:initialise()
    ParadiseDev.Zones.testWindow:addToUIManager()
end
function ParadiseDev.Zones.openUI()
    if not ParadiseDev.isAdm() then
        print("[PZZoneHarness] Admin access is required for the zone editor.")
        return
    end
    if ParadiseDev.Zones.window then
        ParadiseDev.Zones.window:setVisible(true)
        ParadiseDev.Zones.window:addToUIManager()
        ParadiseDev.Zones.send("requestAdminState")
        return
    end
    local width, height = 1200, 568
    local x = math.max(0, (getCore():getScreenWidth() - width) / 2 - 180)
    local y = math.max(0, (getCore():getScreenHeight() - height) / 2)
    ParadiseDev.Zones.window = ParadiseDev.Zones.Panel:new(x, y, width, height)
    ParadiseDev.Zones.window:initialise()
    ParadiseDev.Zones.window:addToUIManager()
end

function ParadiseDev.Zones.Panel.onServerCommand(module, command, args)
    if module ~= ParadiseDev.Zones.MODULE then return end
    if command == "adminState" then
        ParadiseDev.Zones.adminZones = args and args.zones or {}
        ParadiseDev.Zones.serverVehicleMode = args and args.vehicleMode or "observe"
        if ParadiseDev.Zones.window then ParadiseDev.Zones.window:setServerState(args or {}) end
        if ParadiseDev.Zones.editorWindow and not ParadiseDev.Zones.window then ParadiseDev.Zones.editorWindow:refreshFromState() end
        if ParadiseDev.Zones.testWindow then ParadiseDev.Zones.testWindow:setServerState(args or {}) end
    elseif command == "result" then
        local message = tostring(args and args.text or "")
        if ParadiseDev.Zones.window then ParadiseDev.Zones.window:setStatus(message) end
        if ParadiseDev.Zones.editorWindow then ParadiseDev.Zones.editorWindow:setStatus(message) end
        if ParadiseDev.Zones.testWindow then ParadiseDev.Zones.testWindow:setStatus(message) end
    end
end

Events.OnServerCommand.Remove(ParadiseDev.Zones.Panel.onServerCommand)
Events.OnServerCommand.Add(ParadiseDev.Zones.Panel.onServerCommand)
