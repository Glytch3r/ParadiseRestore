require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISTextEntryBox"
require "ISUI/ISButton"
require "ISUI/UserPanel/ISSafehouseUI"
require "Panels/ParadiseDev_SafehouseAdmin_Utils"

ParadiseDev = ParadiseDev or {}
ParadiseDev.SafehouseAdmin = ParadiseDev.SafehouseAdmin or {}
ParadiseDev.SafehouseAdmin.instance = ParadiseDev.SafehouseAdmin.instance or nil

function ParadiseDev.SafehouseAdmin.isB41()
    return getCore():getGameVersion():getMajor() == 41
end
if ParadiseDev.SafehouseAdmin.isB41() then return end

ParadiseDev.SafehouseAdmin.Panel = ISCollapsableWindow:derive("ParadiseDev.SafehouseAdmin.Panel")

function ParadiseDev.SafehouseAdmin.Panel:getSelectedPlayerRecord()
    local item = self.playerList.items[self.playerList.selected]
    return item and item.item or nil
end

function ParadiseDev.SafehouseAdmin.Panel:getSelectedSafehouseEntry()
    local item = self.safehouseList.items[self.safehouseList.selected]
    return item and item.item or nil
end

function ParadiseDev.SafehouseAdmin.Panel:updateButtons()
    local entry = self:getSelectedSafehouseEntry()
    self.openButton:setEnable(entry ~= nil)
    local canTeleport = entry ~= nil and self.pl and self.pl.getRole and self.pl:getRole():hasCapability(Capability.TeleportToCoordinates)
    self.teleportButton:setEnable(canTeleport == true)
end

function ParadiseDev.SafehouseAdmin.Panel:populateSafehouses(record)
    self.safehouseList:clear()
    self.selectedUser = record and record.username or nil
    for _, entry in ipairs(record and record.safehouses or {}) do
        local safehouse = entry.safehouse
        local label = entry.role .. " | " .. tostring(safehouse:getTitle()) .. " | Owner: " .. tostring(safehouse:getOwner())
            .. " | " .. tostring(safehouse:getX()) .. ", " .. tostring(safehouse:getY())
        self.safehouseList:addItem(label, entry)
    end
    self.safehouseList.selected = #self.safehouseList.items > 0 and 1 or 0
    self:updateButtons()
end

function ParadiseDev.SafehouseAdmin.Panel:populatePlayers(targetUser)
    local selectedUser = targetUser or self.selectedUser
    self.playerList:clear()
    local filter = self.searchEntry and self.searchEntry:getText() or ""
    local filtered = ParadiseDev.SafehouseAdmin.filterPlayerRecords(self.records, filter)
    local selectedIndex = 0
    for _, record in ipairs(filtered) do
        local index = #self.playerList.items + 1
        self.playerList:addItem(record.username .. " (" .. tostring(#record.safehouses) .. ")", record)
        if selectedUser and ParadiseDev.SafehouseAdmin.normalizeUser(record.username) == ParadiseDev.SafehouseAdmin.normalizeUser(selectedUser) then
            selectedIndex = index
        end
    end
    if selectedIndex == 0 and #self.playerList.items > 0 then selectedIndex = 1 end
    self.playerList.selected = selectedIndex
    local item = self.playerList.items[selectedIndex]
    self:populateSafehouses(item and item.item or nil)
end

function ParadiseDev.SafehouseAdmin.Panel:refresh(targetUser)
    local safehouses = SafeHouse and SafeHouse.getSafehouseList and SafeHouse.getSafehouseList() or nil
    self.records = ParadiseDev.SafehouseAdmin.buildPlayerRecords(safehouses)
    if targetUser and self.searchEntry then self.searchEntry:setText(tostring(targetUser)) end
    self:populatePlayers(targetUser)
end

function ParadiseDev.SafehouseAdmin.Panel.onSearchChanged(entry)
    if entry and entry.target then entry.target:populatePlayers() end
end

function ParadiseDev.SafehouseAdmin.Panel:onPlayerSelected(record)
    self:populateSafehouses(record)
end

function ParadiseDev.SafehouseAdmin.Panel:onSafehouseSelected()
    self:updateButtons()
end

function ParadiseDev.SafehouseAdmin.Panel:openSelectedSafehouse()
    local entry = self:getSelectedSafehouseEntry()
    if not entry then return end
    if ISSafehouseUI.instance then ISSafehouseUI.instance:close() end
    local width = 500 + getCore():getOptionFontSizeReal() * 30
    local panel = ISSafehouseUI:new((getCore():getScreenWidth() - width) / 2,
        getCore():getScreenHeight() / 2 - 225, width, 450, entry.safehouse, self.pl)
    panel:initialise()
    panel:addToUIManager()
end

function ParadiseDev.SafehouseAdmin.Panel:teleportToSelectedSafehouse()
    local entry = self:getSelectedSafehouseEntry()
    local x, y, z = entry and ParadiseDev.SafehouseAdmin.getTeleportCoordinates(entry.safehouse) or nil
    if not x or not self.pl then return end
    self.pl:teleportTo(x, y, z)
    if isClient and isClient() then SendCommandToServer("/teleportto " .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(z)) end
end

function ParadiseDev.SafehouseAdmin.Panel:onClick(button)
    if button.internal == "OPEN" then
        self:openSelectedSafehouse()
    elseif button.internal == "TELEPORT" then
        self:teleportToSelectedSafehouse()
    elseif button.internal == "REFRESH" then
        self:refresh()
    elseif button.internal == "CLOSE" then
        self:close()
    end
end

function ParadiseDev.SafehouseAdmin.Panel:drawPlayer(y, item, alt)
    if self.selected == item.index then self:drawRect(0, y, self.width, self.itemheight - 1, 0.3, 0.7, 0.35, 0.15) end
    self:drawRectBorder(0, y, self.width, self.itemheight - 1, 0.7, 0.4, 0.4, 0.4)
    self:drawText(item.text, 8, y + 3, 1, 1, 1, 0.9, self.font)
    return y + self.itemheight
end

function ParadiseDev.SafehouseAdmin.Panel:drawSafehouse(y, item, alt)
    if self.selected == item.index then self:drawRect(0, y, self.width, self.itemheight - 1, 0.3, 0.7, 0.35, 0.15) end
    self:drawRectBorder(0, y, self.width, self.itemheight - 1, 0.7, 0.4, 0.4, 0.4)
    self:drawText(item.text, 8, y + 3, 1, 1, 1, 0.9, self.font)
    return y + self.itemheight
end

function ParadiseDev.SafehouseAdmin.Panel:createChildren()
    ISCollapsableWindow.createChildren(self)
    local top = self:titleBarHeight() + 10
    local pad = 12
    local leftWidth = 250
    local buttonY = self.height - 42
    self.searchEntry = ISTextEntryBox:new("", pad, top + 22, leftWidth, 24)
    self.searchEntry.target = self
    self.searchEntry.onTextChange = ParadiseDev.SafehouseAdmin.Panel.onSearchChanged
    self.searchEntry:initialise()
    self.searchEntry:instantiate()
    self:addChild(self.searchEntry)
    self.playerList = ISScrollingListBox:new(pad, top + 54, leftWidth, buttonY - top - 64)
    self.playerList.target = self
    self.playerList.onmousedown = ParadiseDev.SafehouseAdmin.Panel.onPlayerSelected
    self.playerList.doDrawItem = ParadiseDev.SafehouseAdmin.Panel.drawPlayer
    self.playerList.itemheight = 24
    self.playerList.font = UIFont.Small
    self.playerList.drawBorder = true
    self.playerList:initialise()
    self.playerList:instantiate()
    self:addChild(self.playerList)
    local rightX = pad + leftWidth + pad
    self.safehouseList = ISScrollingListBox:new(rightX, top + 22, self.width - rightX - pad, buttonY - top - 32)
    self.safehouseList.target = self
    self.safehouseList.onmousedown = ParadiseDev.SafehouseAdmin.Panel.onSafehouseSelected
    self.safehouseList.doDrawItem = ParadiseDev.SafehouseAdmin.Panel.drawSafehouse
    self.safehouseList.itemheight = 24
    self.safehouseList.font = UIFont.Small
    self.safehouseList.drawBorder = true
    self.safehouseList:initialise()
    self.safehouseList:instantiate()
    self:addChild(self.safehouseList)
    self.closeButton = ISButton:new(pad, buttonY, 100, 26, "Close", self, ParadiseDev.SafehouseAdmin.Panel.onClick)
    self.closeButton.internal = "CLOSE"
    self.closeButton:initialise()
    self.closeButton:instantiate()
    self:addChild(self.closeButton)
    self.refreshButton = ISButton:new(120, buttonY, 100, 26, "Refresh", self, ParadiseDev.SafehouseAdmin.Panel.onClick)
    self.refreshButton.internal = "REFRESH"
    self.refreshButton:initialise()
    self.refreshButton:instantiate()
    self:addChild(self.refreshButton)
    self.teleportButton = ISButton:new(self.width - 226, buttonY, 104, 26, "Teleport", self, ParadiseDev.SafehouseAdmin.Panel.onClick)
    self.teleportButton.internal = "TELEPORT"
    self.teleportButton:initialise()
    self.teleportButton:instantiate()
    self:addChild(self.teleportButton)
    self.openButton = ISButton:new(self.width - 116, buttonY, 104, 26, "Open Panel", self, ParadiseDev.SafehouseAdmin.Panel.onClick)
    self.openButton.internal = "OPEN"
    self.openButton:initialise()
    self.openButton:instantiate()
    self:addChild(self.openButton)
    self:refresh()
end

function ParadiseDev.SafehouseAdmin.Panel:prerender()
    ISCollapsableWindow.prerender(self)
    local top = self:titleBarHeight() + 10
    self:drawText("Search players", 12, top + 2, 0.85, 0.9, 1, 1, UIFont.Small)
    self:drawText("Safehouses", 274, top + 2, 0.85, 0.9, 1, 1, UIFont.Small)
end

function ParadiseDev.SafehouseAdmin.Panel:close()
    ParadiseDev.SafehouseAdmin.ClosePanel()
end

function ParadiseDev.SafehouseAdmin.Panel:new(x, y, width, height, pl)
    local panel = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(panel, self)
    self.__index = self
    panel.title = "ParadiseZ Safehouse Records"
    panel.pl = pl or getPlayer()
    panel.records = {}
    panel.resizable = false
    return panel
end

function ParadiseDev.SafehouseAdmin.onSafehousesChanged()
    local panel = ParadiseDev.SafehouseAdmin.instance
    if panel then panel:refresh() end
end
Events.OnSafehousesChanged.Remove(ParadiseDev.SafehouseAdmin.onSafehousesChanged)
Events.OnSafehousesChanged.Add(ParadiseDev.SafehouseAdmin.onSafehousesChanged)
