FactionManager = FactionManager or {}
if not FactionManager.isB41 then require "FactionManager/FactionManager_Shared" end
if FactionManager.isB41() then return end

require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISComboBox"
require "ISUI/ISTextEntryBox"
require "ISUI/ISTextBox"
require "ISUI/ISModalDialog"
require "ISUI/ISColorPicker"

FactionManager.fontSmall = getTextManager():getFontHeight(UIFont.Small)
FactionManager.entryHeight = FactionManager.fontSmall + 8
FactionManager.gap = 8
FactionManager.Panel = ISCollapsableWindow:derive("FactionManager.Panel")

function FactionManager.formatTime(int)
    if not int or tonumber(int) == nil then return "Unknown" end
    return os.date("%Y-%m-%d %H:%M:%S", tonumber(int))
end

function FactionManager.addLabel(parent, str, x, y, font)
    local label = ISLabel:new(x, y, FactionManager.entryHeight, str, 0.85, 0.85, 0.85, 1, font or UIFont.Small, true)
    label:initialise()
    label:instantiate()
    parent:addChild(label)
    return label
end

function FactionManager.addButton(parent, str, x, y, width, internal)
    local button = ISButton:new(x, y, width, FactionManager.entryHeight, str, parent, FactionManager.Panel.onClick)
    button.internal = internal
    button:initialise()
    button:instantiate()
    parent:addChild(button)
    return button
end

function FactionManager.Panel:createChildren()
    ISCollapsableWindow.createChildren(self)
    self:setResizable(true)
    local top = self:titleBarHeight() + FactionManager.gap
    FactionManager.addLabel(self, "Filter", 12, top)
    self.filter = ISComboBox:new(58, top, 220, FactionManager.entryHeight, self, FactionManager.Panel.onFilterChanged)
    self.filter:initialise()
    self:addChild(self.filter)
    self.refreshButton = FactionManager.addButton(self, "Refresh", 286, top, 80, "REFRESH")
    self.totalLabel = FactionManager.addLabel(self, "Factions: 0", 378, top)

    local listTop = top + FactionManager.entryHeight + FactionManager.gap
    self.factionList = ISScrollingListBox:new(12, listTop, 410, self.height - listTop - 50)
    self.factionList:initialise()
    self.factionList:instantiate()
    self.factionList.itemheight = FactionManager.entryHeight + 18
    self.factionList.doDrawItem = FactionManager.Panel.drawFaction
    self.factionList.onmousedown = FactionManager.Panel.onFactionSelected
    self.factionList.drawBorder = true
    self:addChild(self.factionList)

    local rightX = 434
    self.nameLabel = FactionManager.addLabel(self, "Select a faction", rightX, listTop, UIFont.Medium)
    self.ownerLabel = FactionManager.addLabel(self, "Leader: -", rightX, listTop + 30)
    self.createdLabel = FactionManager.addLabel(self, "Created: Unknown", rightX, listTop + 54)
    self.activityLabel = FactionManager.addLabel(self, "Last Activity: Unknown", rightX, listTop + 78)
    self.stateLabel = FactionManager.addLabel(self, "State: -", rightX, listTop + 102)
    self.tagLabel = FactionManager.addLabel(self, "Vanilla Tag: -", rightX, listTop + 126)
    self.labelsLabel = FactionManager.addLabel(self, "Labels: -", rightX, listTop + 150)
    FactionManager.addLabel(self, "Members", rightX, listTop + 180)
    self.memberList = ISScrollingListBox:new(rightX, listTop + 204, self.width - rightX - 12, 150)
    self.memberList:initialise()
    self.memberList:instantiate()
    self.memberList.itemheight = FactionManager.entryHeight
    self.memberList.drawBorder = true
    self:addChild(self.memberList)

    FactionManager.addLabel(self, "Admin Notes", rightX, listTop + 364)
    self.note = ISTextEntryBox:new("", rightX, listTop + 388, self.width - rightX - 12, 92)
    self.note:initialise()
    self.note:instantiate()
    self.note:setMultipleLine(true)
    self:addChild(self.note)
    self.saveNote = FactionManager.addButton(self, "Save Note", rightX, listTop + 488, 100, "NOTE")

    FactionManager.addLabel(self, "Custom Labels", rightX + 112, listTop + 488)
    self.groupCombo = ISComboBox:new(rightX + 205, listTop + 488, self.width - rightX - 217, FactionManager.entryHeight, self)
    self.groupCombo:initialise()
    self:addChild(self.groupCombo)
    self.addLabelButton = FactionManager.addButton(self, "Add Label", rightX, listTop + 522, 100, "ADDLABEL")
    self.removeLabelButton = FactionManager.addButton(self, "Remove Label", rightX + 108, listTop + 522, 110, "REMOVELABEL")
    self.createGroupButton = FactionManager.addButton(self, "Create Group", rightX + 226, listTop + 522, 110, "CREATEGROUP")
    self.renameGroupButton = FactionManager.addButton(self, "Rename Group", rightX + 344, listTop + 522, 110, "RENAMEGROUP")
    self.deleteGroupButton = FactionManager.addButton(self, "Delete Group", rightX + 462, listTop + 522, 110, "DELETEGROUP")

    local bottom = self.height - 38
    self.renameButton = FactionManager.addButton(self, "Rename", 12, bottom, 82, "RENAME")
    self.deleteButton = FactionManager.addButton(self, "Delete", 102, bottom, 82, "DELETE")
    self.ownerButton = FactionManager.addButton(self, "Set Leader", 192, bottom, 90, "OWNER")
    self.addButton = FactionManager.addButton(self, "Add Player", 290, bottom, 90, "ADD")
    self.removeButton = FactionManager.addButton(self, "Remove Player", 388, bottom, 100, "REMOVE")
    self.tagButton = FactionManager.addButton(self, "Set Tag", 496, bottom, 82, "TAG")
    self.colorButton = FactionManager.addButton(self, "Color", 586, bottom, 82, "COLOR")
    self.closeButton = FactionManager.addButton(self, "Close", self.width - 94, bottom, 82, "CLOSE")
    self:refresh()
end

function FactionManager.Panel:getSelectedRecord()
    local item = self.factionList.items[self.factionList.selected]
    return item and item.item or nil
end

function FactionManager.Panel:getSelectedGroup()
    if not self.groupCombo or self.groupCombo.selected <= 0 then return nil end
    return self.groupCombo.options[self.groupCombo.selected]
end

function FactionManager.Panel:matches(record, filter)
    if filter == "All" then return true end
    if filter == "Active" then return record.state == "active" end
    if filter == "Inactive" then return record.state == "inactive" end
    if filter == "Deleted" then return record.state == "deleted" end
    return FactionManager.listHas(record.labels, filter)
end

function FactionManager.Panel:refreshFilters()
    local selected = self.filter.options[self.filter.selected] or "All"
    self.filter:clear()
    self.filter:addOption("All")
    self.filter:addOption("Active")
    self.filter:addOption("Inactive")
    self.filter:addOption("Deleted")
    for _, group in ipairs(FactionManager.clientState.groups or {}) do self.filter:addOption(group) end
    self.filter:select(selected)
    if self.filter.selected <= 0 then self.filter.selected = 1 end
    self.groupCombo:clear()
    for _, group in ipairs(FactionManager.clientState.groups or {}) do self.groupCombo:addOption(group) end
end

function FactionManager.Panel:refresh()
    if not self.factionList then return end
    local selectedRecord = self:getSelectedRecord()
    local selectedName = selectedRecord and selectedRecord.name or nil
    self:refreshFilters()
    local filter = self.filter.options[self.filter.selected] or "All"
    self.factionList:clear()
    for _, record in ipairs(FactionManager.clientState.factions or {}) do
        if self:matches(record, filter) then
            self.factionList:addItem(record.name, record)
            if selectedName == record.name then self.factionList.selected = #self.factionList.items end
        end
    end
    self.totalLabel:setName("Factions: " .. tostring(#self.factionList.items))
    self:updateDetails()
end

function FactionManager.Panel:onFilterChanged()
    self:refresh()
end

function FactionManager.Panel.onFactionSelected(self, x, y)
    ISScrollingListBox.onMouseDown(self, x, y)
    if self.parent then self.parent:updateDetails() end
end

function FactionManager.Panel:drawFaction(y, item, alt)
    local record = item.item
    if self.selected == item.index then self:drawRect(0, y, self.width, self.itemheight - 1, 0.35, 0.2, 0.45, 0.7) end
    local stateCol = record.state == "deleted" and { 0.8, 0.2, 0.2 } or record.state == "inactive" and { 0.9, 0.65, 0.15 } or { 0.25, 0.8, 0.35 }
    self:drawText(record.name .. "  [" .. string.upper(record.state or "active") .. "]", 8, y + 3, stateCol[1], stateCol[2], stateCol[3], 1, UIFont.Small)
    self:drawText("Leader: " .. tostring(record.owner or "Unknown") .. " | Members: " .. tostring(#(record.members or {}) + 1), 8, y + 3 + FactionManager.fontSmall, 0.72, 0.72, 0.72, 1, UIFont.Small)
    return y + self.itemheight
end

function FactionManager.Panel:updateDetails()
    local record = self:getSelectedRecord()
    self.memberList:clear()
    if not record then
        self.nameLabel:setName("Select a faction")
        self.ownerLabel:setName("Leader: -")
        self.createdLabel:setName("Created: Unknown")
        self.activityLabel:setName("Last Activity: Unknown")
        self.stateLabel:setName("State: -")
        self.tagLabel:setName("Vanilla Tag: -")
        self.labelsLabel:setName("Labels: -")
        self.note:setText("")
        return
    end
    self.nameLabel:setName(record.name)
    self.ownerLabel:setName("Leader: " .. tostring(record.owner or "Unknown"))
    self.createdLabel:setName("Created: " .. FactionManager.formatTime(record.createdAt))
    self.activityLabel:setName("Last Activity: " .. FactionManager.formatTime(record.lastActivity))
    self.stateLabel:setName("State: " .. string.upper(record.state or "active"))
    self.tagLabel:setName("Vanilla Tag: " .. tostring(record.tag or "None"))
    self.labelsLabel:setName("Labels: " .. (#(record.labels or {}) > 0 and table.concat(record.labels, ", ") or "None"))
    self.note:setText(record.note or "")
    self.memberList:addItem(tostring(record.owner or "Unknown") .. " [Leader]", record.owner)
    for _, user in ipairs(record.members or {}) do self.memberList:addItem(user, user) end
end

function FactionManager.openText(str, value, payload)
    local modal = ISTextBox:new(0, 0, 360, 180, str, tostring(value or ""), FactionManager, FactionManager.onTextEntered, nil, payload)
    modal:initialise()
    modal:addToUIManager()
    modal.moveWithMouse = true
end

function FactionManager.onTextEntered(target, button, payload)
    if button.internal ~= "OK" or type(payload) ~= "table" then return end
    local value = button.parent.entry:getText()
    local args = { faction = payload.faction, value = value, user = value, group = payload.group }
    FactionManager.sendMutation(payload.act, args)
end

function FactionManager.onDeleteConfirmed(target, button, faction)
    if button.internal == "YES" then FactionManager.sendMutation("delete", { faction = faction }) end
end

function FactionManager.onColorPicked(target, col)
    local record = target and target:getSelectedRecord() or nil
    if record and col then FactionManager.sendMutation("setColor", { faction = record.name, r = col.r, g = col.g, b = col.b }) end
end

function FactionManager.Panel:onClick(button)
    local record = self:getSelectedRecord()
    local internal = button.internal
    if internal == "CLOSE" then self:close() return end
    if internal == "REFRESH" then FactionManager.requestState() return end
    if internal == "CREATEGROUP" then FactionManager.openText("Create custom faction filter group", "", { act = "createGroup" }) return end
    local group = self:getSelectedGroup()
    if internal == "RENAMEGROUP" and group then FactionManager.openText("Rename " .. group, group, { act = "renameGroup", group = group }) return end
    if internal == "DELETEGROUP" and group then FactionManager.sendMutation("deleteGroup", { group = group }) return end
    if not record then return end
    if internal == "NOTE" then FactionManager.sendMutation("setNote", { faction = record.name, value = self.note:getText() })
    elseif internal == "ADDLABEL" and group then FactionManager.sendMutation("addLabel", { faction = record.name, group = group })
    elseif internal == "REMOVELABEL" and group then FactionManager.sendMutation("removeLabel", { faction = record.name, group = group })
    elseif internal == "RENAME" then FactionManager.openText("Rename faction", record.name, { act = "rename", faction = record.name })
    elseif internal == "DELETE" then
        local modal = ISModalDialog:new(0, 0, 360, 160, "Delete faction " .. record.name .. "?", true, FactionManager, FactionManager.onDeleteConfirmed, nil, record.name)
        modal:initialise()
        modal:addToUIManager()
    elseif internal == "OWNER" then FactionManager.openText("Set faction leader username", record.owner, { act = "setOwner", faction = record.name })
    elseif internal == "ADD" then FactionManager.openText("Add online player username", "", { act = "addPlayer", faction = record.name })
    elseif internal == "REMOVE" then
        local item = self.memberList.items[self.memberList.selected]
        if item and item.item ~= record.owner then FactionManager.sendMutation("removePlayer", { faction = record.name, user = item.item }) end
    elseif internal == "TAG" then FactionManager.openText("Set vanilla faction tag", record.tag or "", { act = "setTag", faction = record.name })
    elseif internal == "COLOR" then
        local picker = ISColorPicker:new(getMouseX(), getMouseY())
        picker:setPickedFunc(FactionManager.onColorPicked, self)
        picker:initialise()
        picker:addToUIManager()
    end
end

function FactionManager.Panel:close()
    FactionManager.ClosePanel()
end

function FactionManager.Panel:new(x, y, width, height)
    local obj = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(obj, self)
    self.__index = self
    obj.title = "Paradise Faction Manager"
    obj.minimumWidth = 900
    obj.minimumHeight = 650
    obj.resizable = true
    return obj
end

function FactionManager.ClosePanel()
    if not FactionManager.instance then return end
    FactionManager.instance:setVisible(false)
    FactionManager.instance:removeFromUIManager()
    FactionManager.instance = nil
end

function FactionManager.OpenPanel()
    if not ParadiseRestore or not ParadiseRestore.isAdm or not ParadiseRestore.isAdm() then return end
    if not FactionManager.instance then
        local width = math.min(1120, getCore():getScreenWidth() - 40)
        local height = math.min(720, getCore():getScreenHeight() - 40)
        local x = math.max(20, (getCore():getScreenWidth() - width) / 2)
        local y = math.max(20, (getCore():getScreenHeight() - height) / 2)
        FactionManager.instance = FactionManager.Panel:new(x, y, width, height)
        FactionManager.instance:initialise()
    end
    FactionManager.instance:addToUIManager()
    FactionManager.instance:setVisible(true)
    FactionManager.requestState()
end

function FactionManager.TogglePanel()
    if FactionManager.instance then FactionManager.ClosePanel() else FactionManager.OpenPanel() end
end
