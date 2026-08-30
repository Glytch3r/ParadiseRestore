ParadiseDev = ParadiseDev or {}
ParadiseDev.Panels = ParadiseDev.Panels or {}

--[[ require "ISUI/AdminPanel/ISMiniScoreboardUI"
require "ISUI/AdminPanel/ISUsersList"
require "DebugUIs/DebugMenu/ISDebugUtils"
require "DebugUIs/DebugMenu/GlobalModData/GlobalModData"
require "ISUI/ISTextEntryBox" ]]

ParadiseDev.Panels.GlobalModData = GlobalModDataDebug:derive("ParadiseDev.Panels.GlobalModData")

function ParadiseDev.Panels.isAdmin(player)
    return ParadiseDev.isAdm(player)
end
--[[ 
function ParadiseDev.Panels.addMissingScoreboardOptions(panel, player, x, y)
    if not ParadiseDev.Panels.isAdmin(panel.admin) then return end
    local role = panel.admin:getRole()
    local context = ISContextMenu.get(panel.admin:getPlayerNum(), x + panel:getAbsoluteX(), y + panel:getAbsoluteY())
    local function hasCapability(capability)
        return role and role.hasCapability and role:hasCapability(capability)
    end
    if not hasCapability(Capability.TeleportToPlayer) then
        context:addOption(getText("UI_Scoreboard_Teleport"), panel, ISMiniScoreboardUI.onCommand, player, "TELEPORT")
    end
    if not hasCapability(Capability.TeleportPlayerToAnotherPlayer) then
        context:addOption(getText("UI_Scoreboard_TeleportToYou"), panel, ISMiniScoreboardUI.onCommand, player, "TELEPORTTOYOU")
    end
    if not hasCapability(Capability.ToggleInvisibleEveryone) then
        context:addOption(getText("UI_Scoreboard_Invisible"), panel, ISMiniScoreboardUI.onCommand, player, "INVISIBLE")
    end
    if not hasCapability(Capability.ToggleGodModEveryone) then
        context:addOption(getText("UI_Scoreboard_GodMod"), panel, ISMiniScoreboardUI.onCommand, player, "GODMOD")
    end
    if not hasCapability(Capability.CanSeePlayersStats) then
        context:addOption("Check Stats", panel, ISMiniScoreboardUI.onCommand, player, "STATS")
    end
end

function ParadiseDev.Panels.addScoreboardOptions(panel, player, x, y)
    local context = ISContextMenu.get(panel.admin:getPlayerNum(), x + panel:getAbsoluteX(), y + panel:getAbsoluteY())
    if ParadiseZ and ParadiseZ.Oversight and ParadiseZ.Oversight.addScoreboardOptions then
        ParadiseZ.Oversight.addScoreboardOptions(panel, player, x, y)
    end
    if ParadiseDev.Cage and ParadiseDev.Cage.addTargetOptions then
        ParadiseDev.Cage.addTargetOptions(context, player)
    end
end
 ]]
function ParadiseDev.Panels.GlobalModData:new(x, y, width, height, title)
    local panel = ISPanel:new(x, y, width, height)
    setmetatable(panel, self)
    self.__index = self
    panel.variableColor = { r = 0.9, g = 0.55, b = 0.1, a = 1 }
    panel.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    panel.backgroundColor = { r = 0, g = 0, b = 0, a = 0.8 }
    panel.buttonBorderColor = { r = 0.7, g = 0.7, b = 0.7, a = 0.5 }
    panel.zOffsetSmallFont = 25
    panel.moveWithMouse = true
    panel.panelTitle = title
    return panel
end

function ParadiseDev.Panels.GlobalModData:close()
    self:setVisible(false)
    self:removeFromUIManager()
    ParadiseDev.Panels.globalModData = nil
end

function ParadiseDev.Panels.GlobalModData:createChildren()
    ISPanel.createChildren(self)

    local spacing = 10
    local buttonHeight = getTextManager():getFontHeight(UIFont.Small) + 6
    local title = self.panelTitle or "ParadiseZ Global ModData"
    ISDebugUtils.addLabel(self, {}, (self.width - getTextManager():MeasureStringX(UIFont.Medium, title)) / 2, spacing + 1, title, UIFont.Medium, true)

    local top = spacing * 2 + getTextManager():getFontHeight(UIFont.Medium) + 1
    local editorTop = self.height - (buttonHeight * 4 + spacing * 5)
    self.tableNamesList = ISScrollingListBox:new(spacing + 1, top, 200, editorTop - top - spacing)
    self.tableNamesList:initialise()
    self.tableNamesList:instantiate()
    self.tableNamesList.itemheight = buttonHeight
    self.tableNamesList.selected = 0
    self.tableNamesList.joypadParent = self
    self.tableNamesList.font = UIFont.NewSmall
    self.tableNamesList.doDrawItem = self.drawTableNameList
    self.tableNamesList.drawBorder = true
    self.tableNamesList.onmousedown = ParadiseDev.Panels.GlobalModData.OnTableNamesListMouseDown
    self.tableNamesList.target = self
    self:addChild(self.tableNamesList)

    self.infoList = ISScrollingListBox:new(self.tableNamesList:getRight() + spacing, top, self.width - self.tableNamesList:getRight() - spacing * 2 - 1, self.tableNamesList.height)
    self.infoList:initialise()
    self.infoList:instantiate()
    self.infoList.itemheight = buttonHeight
    self.infoList.selected = 0
    self.infoList.joypadParent = self
    self.infoList.font = UIFont.NewSmall
    self.infoList.doDrawItem = self.drawInfoList
    self.infoList.drawBorder = true
    self.infoList.onmousedown = ParadiseDev.Panels.GlobalModData.OnInfoListMouseDown
    self.infoList.target = self
    self:addChild(self.infoList)

    local labelWidth = 52
    local fieldY = editorTop
    ISDebugUtils.addLabel(self, {}, spacing, fieldY + 3, "Table", UIFont.Small, true)
    self.tableEntry = ISTextEntryBox:new("", spacing + labelWidth, fieldY, 180, buttonHeight)
    self.tableEntry:initialise()
    self.tableEntry:instantiate()
    self:addChild(self.tableEntry)
    ISDebugUtils.addLabel(self, {}, 250, fieldY + 3, "Key", UIFont.Small, true)
    self.keyEntry = ISTextEntryBox:new("", 285, fieldY, 160, buttonHeight)
    self.keyEntry:initialise()
    self.keyEntry:instantiate()
    self:addChild(self.keyEntry)
    ISDebugUtils.addLabel(self, {}, 455, fieldY + 3, "Value", UIFont.Small, true)
    self.valueEntry = ISTextEntryBox:new("", 500, fieldY, 200, buttonHeight)
    self.valueEntry:initialise()
    self.valueEntry:instantiate()
    self:addChild(self.valueEntry)
    self.valueType = ISComboBox:new(710, fieldY, self.width - 720, buttonHeight, self, nil)
    self.valueType:initialise()
    self.valueType:instantiate()
    self.valueType:addOption("String")
    self.valueType:addOption("Number")
    self.valueType:addOption("Boolean")
    self.valueType:addOption("Table")
    self.valueType:setSelected(1)
    self:addChild(self.valueType)

    local y = fieldY + buttonHeight + spacing
    local _, button = ISDebugUtils.addButton(self, "addTable", spacing, y, 140, buttonHeight, "Add Table", ParadiseDev.Panels.GlobalModData.onClickAddTable)
    button:enableAcceptColor()
    _, button = ISDebugUtils.addButton(self, "setValue", 160, y, 140, buttonHeight, "Set Value", ParadiseDev.Panels.GlobalModData.onClickSetValue)
    button:enableAcceptColor()
    _, button = ISDebugUtils.addButton(self, "deleteValue", 310, y, 140, buttonHeight, "Delete Value", ParadiseDev.Panels.GlobalModData.onClickDeleteValue)
    button:enableCancelColor()
    _, button = ISDebugUtils.addButton(self, "deleteTable", 460, y, 140, buttonHeight, "Delete Table", ParadiseDev.Panels.GlobalModData.onClickDeleteTable)
    button:enableCancelColor()
    _, button = ISDebugUtils.addButton(self, "refresh", self.width - 290, y, 130, buttonHeight, "Refresh", ParadiseDev.Panels.GlobalModData.onClickRefresh)
    button:enableAcceptColor()
    _, button = ISDebugUtils.addButton(self, "close", self.width - 150, y, 140, buttonHeight, "Close", ParadiseDev.Panels.GlobalModData.onClickClose)
    button:enableCancelColor()

    self:populateList()
end

function ParadiseDev.Panels.GlobalModData:getSelectedTableName()
    local name = self.tableEntry:getInternalText()
    if name == "" then return nil end
    return name
end

function ParadiseDev.Panels.GlobalModData:transmitTable(name)
    if ModData.request and name then ModData.request(name) end
end

function ParadiseDev.Panels.GlobalModData:requestMutation(command, args)
    if isClient() then
        sendClientCommand("ParadiseDevGlobalModData", command, args)
        return true
    end
    return false
end

function ParadiseDev.Panels.GlobalModData:populateList()
    local currentName = self.selectedTableName or self:getSelectedTableName()
    local tableNames = ModData.getTableNames()
    self.tableNamesList:clear()
    self.selectedTableName = nil

    if tableNames:size() == 0 then
        self:populateInfoList(nil)
        return
    end

    for i = 0, tableNames:size() - 1 do
        local name = tableNames:get(i)
        self.tableNamesList:addItem(name, name)
        if name == currentName then
            self.selectedTableName = name
            self.tableNamesList.selected = i + 1
        end
    end
    self.selectedTableName = self.selectedTableName or tableNames:get(0)
    self.tableEntry:setText(self.selectedTableName)
    self:populateInfoList(self.selectedTableName)
end

function ParadiseDev.Panels.GlobalModData:OnTableNamesListMouseDown(item)
    self.selectedTableName = item
    self.tableEntry:setText(item)
    self:populateInfoList(item)
end

function ParadiseDev.Panels.GlobalModData:parseTable(value, parent, key, indent, path)
    local entryPath = {}
    for index, pathKey in ipairs(path or {}) do entryPath[index] = pathKey end
    entryPath[#entryPath + 1] = key
    local text = tostring(indent) .. "[" .. tostring(key) .. "] -> "
    if type(value) == "table" then
        self.infoList:addItem(text, { parent = parent, key = key, value = value, isTable = true, path = entryPath })
        for childKey, childValue in pairs(value) do
            self:parseTable(childValue, value, childKey, indent .. "    ", entryPath)
        end
    else
        self.infoList:addItem(text .. tostring(value), { parent = parent, key = key, value = value, path = entryPath })
    end
end

function ParadiseDev.Panels.GlobalModData:populateInfoList(name)
    self.infoList:clear()
    self.selectedEntry = nil
    if not name then
        self.infoList:addItem("No data.", nil)
        return
    end
    local modData = ModData.get(name)
    if not modData then
        self.infoList:addItem("Table not found.", nil)
        return
    end
    for key, value in pairs(modData) do
        self:parseTable(value, modData, key, "")
    end
end

function ParadiseDev.Panels.GlobalModData:OnInfoListMouseDown(item)
    local data = item.item
    if not data then return end
    self.selectedEntry = data
    self.keyEntry:setText(tostring(data.key))
    if data.isTable then
        self.valueEntry:setText("")
        self.valueType:setSelected(4)
    else
        self.valueEntry:setText(tostring(data.value))
        if type(data.value) == "number" then
            self.valueType:setSelected(2)
        elseif type(data.value) == "boolean" then
            self.valueType:setSelected(3)
        else
            self.valueType:setSelected(1)
        end
    end
end

function ParadiseDev.Panels.GlobalModData:readValue()
    local value = self.valueEntry:getInternalText()
    if self.valueType.selected == 2 then return tonumber(value) end
    if self.valueType.selected == 3 then return value == "true" or value == "1" end
    if self.valueType.selected == 4 then return {} end
    return value
end

function ParadiseDev.Panels.GlobalModData:onClickAddTable()
    local name = self:getSelectedTableName()
    if not name then return end
    if not self:requestMutation("addTable", { name = name }) then
        ModData.getOrCreate(name)
        self:transmitTable(name)
    end
    self.selectedTableName = name
    self:populateList()
end

function ParadiseDev.Panels.GlobalModData:onClickSetValue()
    local name = self:getSelectedTableName()
    local key = self.keyEntry:getInternalText()
    local value = self:readValue()
    if not name or key == "" or value == nil then return end
    local selected = self.selectedEntry
    local args = { name = name, key = key, value = value }
    if selected and selected.path and tostring(selected.key) == key then
        args.path = selected.path
    end
    if not self:requestMutation("setValue", args) then
        local target = ModData.getOrCreate(name)
        local targetKey = key
        if selected and selected.parent and tostring(selected.key) == key then
            target = selected.parent
            targetKey = selected.key
        end
        target[targetKey] = value
        self:transmitTable(name)
    end
    self.selectedTableName = name
    self:populateList()
end

function ParadiseDev.Panels.GlobalModData:onClickDeleteValue()
    local name = self:getSelectedTableName()
    local key = self.keyEntry:getInternalText()
    if not name or key == "" then return end
    local selected = self.selectedEntry
    local args = { name = name, key = key }
    if selected and selected.path and tostring(selected.key) == key then
        args.path = selected.path
    end
    if not self:requestMutation("deleteValue", args) then
        local target = ModData.get(name)
        local targetKey = key
        if selected and selected.parent and tostring(selected.key) == key then
            target = selected.parent
            targetKey = selected.key
        end
        if not target then return end
        target[targetKey] = nil
        self:transmitTable(name)
    end
    self.selectedTableName = name
    self:populateList()
end

function ParadiseDev.Panels.GlobalModData:onClickDeleteTable()
    local name = self:getSelectedTableName()
    if not name then return end
    if not self:requestMutation("deleteTable", { name = name }) then ModData.remove(name) end
    self.selectedTableName = nil
    self.keyEntry:setText("")
    self.valueEntry:setText("")
    self:populateList()
end 
--[[ 
function ParadiseDev.Panels.openMiniScoreboard()
    if ParadiseDev.Panels.miniScoreboard then
        ParadiseDev.Panels.miniScoreboard:setVisible(true)
        ParadiseDev.Panels.miniScoreboard:bringToTop()
        scoreboardUpdate()
        return
    end
    local panel = ISMiniScoreboardUI:new(0, 0, 420, 500, getPlayer())
    panel.doPlayerListContextMenu = function(self, player, x, y)
        ISMiniScoreboardUI.doPlayerListContextMenu(self, player, x, y)
        ParadiseDev.Panels.addMissingScoreboardOptions(self, player, x, y)
    end
    panel.populateList = function(self)
        ISMiniScoreboardUI.populateList(self)
        local admin = self.admin
        local username = admin and admin:getUsername()
        if not username then return end
        for _, item in ipairs(self.playerList.items) do
            if item.item and item.item.username == username then return end
        end
        local displayName = admin.getDisplayName and admin:getDisplayName() or username
        local item = self.playerList:addItem(displayName, { username = username, displayName = displayName })
        if username ~= displayName then item.tooltip = username end
    end
    panel.close = function(self)
        self:setVisible(false)
        self:removeFromUIManager()
        ISMiniScoreboardUI.instance = nil
        ParadiseDev.Panels.miniScoreboard = nil
    end
    panel:initialise()
    panel:addToUIManager()
    panel:setVisible(true)
    ParadiseDev.Panels.miniScoreboard = panel
end
 ]]
--[[ 
function ParadiseDev.Panels.openUsersList()
    if ParadiseDev.Panels.usersList then
        ParadiseDev.Panels.usersList:setVisible(true)
        ParadiseDev.Panels.usersList:bringToTop()
        ISUsersList.refresh(ParadiseDev.Panels.usersList)
        return
    end
    requestUsers()
    local panel = ISUsersList:new(0, 0, 950, 600, getPlayer())
    panel.doContextMenu = function(self, item, x, y)
        ISUsersList.doContextMenu(self, item, x, y)
        local context = ISContextMenu.get(self.player:getPlayerNum(), x + self:getAbsoluteX(), y + self:getAbsoluteY())
        if ParadiseDev.Cage and ParadiseDev.Cage.addTargetOptions then
            ParadiseDev.Cage.addTargetOptions(context, { username = item:getUsername() })
        end
        local username = item:getUsername()
        if item:isOnline() and username ~= self.player:getUsername() and ParadiseZ and ParadiseZ.setSpectate then
            local role = self.player:getRole()
            if role and role:hasCapability(Capability.TeleportToPlayer) then
                context:addOption("Spectate: " .. username, nil, ParadiseZ.setSpectate, username)
                if ParadiseZ.isSpectating and ParadiseZ.isSpectating(self.player) then
                    context:addOption("Stop Spectating", nil, ParadiseZ.stopSpectate)
                end
            end
        end
    end
    panel.closeModal = function(self)
        self:setVisible(false)
        self:removeFromUIManager()
        ISUsersList.instance = nil
        ParadiseDev.Panels.usersList = nil
    end
    panel:initialise()
    panel:addToUIManager()
    panel:setVisible(true)
    ParadiseDev.Panels.usersList = panel
end
 ]]

function ParadiseDev.Panels.openGlobalModData()
    if ParadiseDev.Panels.globalModData then
        ParadiseDev.Panels.globalModData:setVisible(true)
        ParadiseDev.Panels.globalModData:bringToTop()
        ParadiseDev.Panels.globalModData:populateList()
        return
    end
    local panel = ParadiseDev.Panels.GlobalModData:new(100, 100, 900, 600, "ParadiseZ Global ModData")
    panel:initialise()
    panel:instantiate()
    panel:addToUIManager()
    panel:setVisible(true)
    ParadiseDev.Panels.globalModData = panel
end

function ParadiseDev.Panels.openWaveCaster()
    if WaveCaster and WaveCaster.panel then WaveCaster.panel(true) end
end

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
    if not ParadiseDev.isAdm() then return end
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

function ParadiseDev.Panels.onGlobalModDataServerCommand(module, command, args)
    if module ~= "ParadiseDevGlobalModData" or not args or not args.name then return end
    if command == "removed" and ModData.exists(args.name) then ModData.remove(args.name) end
    if command == "updated" and ModData.request then ModData.request(args.name) end
    local panel = ParadiseDev.Panels.globalModData
    if panel and panel:isVisible() and command == "removed" then panel:populateList() end
end

function ParadiseDev.Panels.onReceiveGlobalModData(name)
    local panel = ParadiseDev.Panels.globalModData
    if panel and panel:isVisible() then panel:populateList() end
end

function ParadiseDev.Panels.onNetworkUsersReceived()
    local panel = ParadiseDev.Panels.usersList
    if panel and panel:isVisible() then panel:populateList() end
end

Events.OnServerCommand.Remove(ParadiseDev.Panels.onGlobalModDataServerCommand)
Events.OnServerCommand.Add(ParadiseDev.Panels.onGlobalModDataServerCommand)
Events.OnReceiveGlobalModData.Remove(ParadiseDev.Panels.onReceiveGlobalModData)
Events.OnReceiveGlobalModData.Add(ParadiseDev.Panels.onReceiveGlobalModData)
Events.OnNetworkUsersReceived.Remove(ParadiseDev.Panels.onNetworkUsersReceived)
Events.OnNetworkUsersReceived.Add(ParadiseDev.Panels.onNetworkUsersReceived)
