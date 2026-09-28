ParadiseDev = ParadiseDev or {}
ParadiseDev.Panels = ParadiseDev.Panels or {}


ParadiseDev.Panels.MediaSpawner = ISCollapsableWindow:derive("ParadiseDev.Panels.MediaSpawner")

function ParadiseDev.Panels.MediaSpawner:getSelectedCategory()
    return self.category and self.category:getSelectedText() or nil
end

function ParadiseDev.Panels.MediaSpawner:populateCategories()
    local recordedMedia = getZomboidRadio and getZomboidRadio() and getZomboidRadio():getRecordedMedia() or nil
    if not recordedMedia then return end
    self.category:clear()
    local categories = recordedMedia:getCategories()
    for index = 0, categories:size() - 1 do self.category:addOption(categories:get(index)) end
end

function ParadiseDev.Panels.MediaSpawner:getMediaTitle(media)
    if media:hasTitle() then
        local title = media:getTranslatedTitle()
        if media:hasSubTitle() and media:getSubtitleEN() ~= "Home VHS" then title = title .. " " .. media:getTranslatedSubTitle() end
        return title
    end
    if media:hasSubTitle() then return media:getTranslatedSubTitle() end
    return media:getTranslatedItemDisplayName()
end

function ParadiseDev.Panels.MediaSpawner:populateList()
    self.list:clear()
    local category = self:getSelectedCategory()
    local recordedMedia = category and getZomboidRadio and getZomboidRadio() and getZomboidRadio():getRecordedMedia() or nil
    if not recordedMedia then return end
    local filter = string.lower(self.search:getText() or "")
    local entries = recordedMedia:getAllMediaForCategory(category)
    for index = 0, entries:size() - 1 do
        local media = entries:get(index)
        local title = self:getMediaTitle(media)
        if filter == "" or string.find(string.lower(title), filter, 1, true) then self.list:addItem(title, media) end
    end
end

function ParadiseDev.Panels.MediaSpawner:onCategoryChanged()
    self:populateList()
end

function ParadiseDev.Panels.MediaSpawner.onSearchChanged(box)
    if box and box.target then box.target:populateList() end
end

function ParadiseDev.Panels.MediaSpawner:spawnSelected()
    local entry = self.list.items[self.list.selected]
    local media = entry and entry.item or nil
    local category = self:getSelectedCategory()
    if not media or not category then return end
    local args = { category = category, mediaIndex = media:getIndexForLua() }
    if isClient and isClient() then
        sendClientCommand("ParadiseDevMediaSpawn", "spawn", args)
        return
    end
    local itemType = category == "CDs" and "Base.Disc_Retail" or category == "Retail-VHS" and "Base.VHS_Retail" or category == "Home-VHS" and "Base.VHS_Home" or nil
    local player = getPlayer()
    local inventory = player and player:getInventory() or nil
    local item = itemType and inventory and inventory:AddItem(itemType) or nil
    if not item then return end
    item:setRecordedMediaData(media)
    if ParadiseDev.Inventory and ParadiseDev.Inventory.syncAddedItem then ParadiseDev.Inventory.syncAddedItem(inventory, item) end
end

function ParadiseDev.Panels.MediaSpawner:onClick(button)
    if button.internal == "SPAWN" then self:spawnSelected() end
end

function ParadiseDev.Panels.MediaSpawner:createChildren()
    ISCollapsableWindow.createChildren(self)
    local top = self:titleBarHeight() + 10
    self.category = ISComboBox:new(12, top, self.width - 24, 24, self, ParadiseDev.Panels.MediaSpawner.onCategoryChanged)
    self.category:initialise()
    self.category:instantiate()
    self:addChild(self.category)
    self.search = ISTextEntryBox:new("", 12, top + 32, self.width - 24, 24)
    self.search.onTextChange = ParadiseDev.Panels.MediaSpawner.onSearchChanged
    self.search.target = self
    self.search:initialise()
    self.search:instantiate()
    self:addChild(self.search)
    self.list = ISScrollingListBox:new(12, top + 64, self.width - 24, self.height - top - 112)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = 22
    self.list.font = UIFont.Small
    self.list.drawBorder = true
    self:addChild(self.list)
    self.spawnButton = ISButton:new(self.width - 132, self.height - 38, 120, 26, "Spawn Selected", self, ParadiseDev.Panels.MediaSpawner.onClick)
    self.spawnButton.internal = "SPAWN"
    self.spawnButton:initialise()
    self.spawnButton:instantiate()
    self:addChild(self.spawnButton)
    self:populateCategories()
    self:populateList()
end

function ParadiseDev.Panels.MediaSpawner:close()
    ISCollapsableWindow.close(self)
    if ParadiseDev.Panels.mediaSpawner == self then ParadiseDev.Panels.mediaSpawner = nil end
end

function ParadiseDev.Panels.MediaSpawner:new(x, y, width, height)
    local panel = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(panel, self)
    self.__index = self
    panel.title = "ParadiseZ Media Spawner"
    panel.resizable = true
    panel.minimumWidth = 420
    panel.minimumHeight = 360
    return panel
end

function ParadiseDev.Panels.openMediaSpawner()
    if not ParadiseRestore.isAdm() then return end
    if ParadiseDev.Panels.mediaSpawner then
        ParadiseDev.Panels.mediaSpawner:setVisible(true)
        ParadiseDev.Panels.mediaSpawner:bringToTop()
        ParadiseDev.Panels.mediaSpawner:populateCategories()
        ParadiseDev.Panels.mediaSpawner:populateList()
        return
    end
    local panel = ParadiseDev.Panels.MediaSpawner:new(250, 180, 620, 500)
    panel:initialise()
    panel:addToUIManager()
    panel:setVisible(true)
    ParadiseDev.Panels.mediaSpawner = panel
end
