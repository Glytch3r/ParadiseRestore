ParadisePromo_Admin_Manager = ISPanel:derive("ParadisePromo_Admin_Manager")

function ParadisePromo.openAdminPanel()
    if not ParadiseDev.isAdm() then return end
    if ParadisePromo.adminInstance then
        ParadisePromo.adminInstance:setVisible(true)
        ParadisePromo.adminInstance:bringToTop()
        ParadisePromo.adminInstance:addToUIManager()
        sendClientCommand(getPlayer(), "ParadisePromo", "requestSync", {})
        return
    end

    local width = 700
    local height = 460
    local x = (getCore():getScreenWidth() / 2) - (width / 2)
    local y = (getCore():getScreenHeight() / 2) - (height / 2)

    local panel = ParadisePromo_Admin_Manager:new(x, y, width, height)
    panel:initialise()
    panel:addToUIManager()

    ParadisePromo.adminInstance = panel
    sendClientCommand(getPlayer(), "ParadisePromo", "requestSync", {})
end

function ParadisePromo.closeAdminPanel()
    if ParadisePromo.adminInstance then
        ParadisePromo.adminInstance:close()
    end
end

function ParadisePromo_Admin_Manager:new(x, y, width, height)
    local o = ISPanel.new(self, x, y, width, height)
    o.backgroundColor = {r=0, g=0, b=0, a=0.8}
    o.borderColor = {r=0.35, g=0.35, b=0.35, a=1}
    o.moveWithMouse = true
    return o
end

function ParadisePromo_Admin_Manager:close()
    self:setVisible(false)
    self:removeFromUIManager()
    ParadisePromo.adminInstance = nil
end

function ParadisePromo_Admin_Manager:onDestroy()
    ISPanel.onDestroy(self)
    if ParadisePromo.adminInstance == self then
        ParadisePromo.adminInstance = nil
    end
end

function ParadisePromo_Admin_Manager:initialise()
    ISPanel.initialise(self)
    self.anchorLeft = true
    self.anchorRight = false
    self.anchorTop = true
    self.anchorBottom = false
    self.drawBackground = true
    self.drawBorder = true
    self.resizable = false
end

function ParadisePromo_Admin_Manager:createChildren()
    ISPanel.createChildren(self)

    self.titleLabel = ISLabel:new(16, 10, 20, "Promo Code Manager", 1, 1, 1, 1, UIFont.Medium, true)
    self.titleLabel:initialise()
    self:addChild(self.titleLabel)

    self.codeLabel = ISLabel:new(16, 35, 20, "Code", 1, 1, 1, 1, UIFont.Small, true)
    self.codeLabel:initialise()
    self:addChild(self.codeLabel)

    self.code = ISTextEntryBox:new("", 16, 55, 232, 25)
    self.code:initialise()
    self.code:instantiate()
    self.code.onTextChange = ParadisePromo_Admin_Manager.onEntryChanged
    self.code.target = self
    self:addChild(self.code)

    self.activeTick = ISTickBox:new(16, 90, 150, 20, "", self, self.onToggleActive)
    self.activeTick:initialise()
    self.activeTick:instantiate()
    self.activeTick:addOption("Active")
    self:addChild(self.activeTick)

    self.randomTick = ISTickBox:new(16, 112, 150, 20, "", self, self.onToggleRandomized)
    self.randomTick:initialise()
    self.randomTick:instantiate()
    self.randomTick:addOption("Randomized")
    self.randomTick:setSelected(1, false)
    self:addChild(self.randomTick)

    self.modeLabel = ISLabel:new(16, 138, 20, "Mode", 1, 1, 1, 1, UIFont.Small, true)
    self.modeLabel:initialise()
    self:addChild(self.modeLabel)

    self.modeRadio = ISRadioButtons:new(16, 158, 232, 100, self, ParadisePromo_Admin_Manager.onToggleMode)
    self.modeRadio:initialise()
    self.modeRadio:instantiate()
    self.modeRadio:addOption("Once Lifetime")
    self.modeRadio:addOption("Once Per Character")
    self.modeRadio:addOption("Unlimited")
    self.modeRadio:addOption("Daily")
    self.modeRadio:setSelected(1)
    self.modeRadio.modeTooltips = {
        [1] = "Will only trigger once per player.",
        [2] = "Refreshes for each character creation.",
        [3] = "Can use the code as much as you want.",
        [4] = "Refreshes every midnight."
    }
    self.modeRadio.prerender = function(radio)
        ISRadioButtons.prerender(radio)
        radio.tooltip = radio.modeTooltips[radio.mouseOverIndex]
    end
    self:addChild(self.modeRadio)


    self.itemsLabel = ISLabel:new(16, 268, 20, "Items (Base.Apple:5;Base.Pistol:1;)", 1, 1, 1, 1, UIFont.Small, true)
    self.itemsLabel:initialise()
    self:addChild(self.itemsLabel)

     self.itemsBox = ISTextEntryBox:new("", 16, 288, 232, 110)
    self.itemsBox:initialise()
    self.itemsBox:instantiate()
    self.itemsBox:setMultipleLine(true)
    self.itemsBox.onTextChange = ParadisePromo_Admin_Manager.onEntryChanged
    self.itemsBox.target = self
    self:addChild(self.itemsBox)

    self.listHeaders = {
        { text = "Code", x = 270 },
        { text = "Active", x = 400 },
        { text = "Mode", x = 470 },
        { text = "Items", x = 570 },
    }
    for _, header in ipairs(self.listHeaders) do
        local label = ISLabel:new(header.x, 35, 18, header.text, 1, 1, 1, 1, UIFont.Small, true)
        label:initialise()
        self:addChild(label)
    end

    self.codeList = ISScrollingListBox:new(266, 55, 418, 330)
    self.codeList:initialise()
    self.codeList:instantiate()
    self.codeList.itemheight = 30
    self.codeList.font = UIFont.Small
    self.codeList.selected = 0
    self.codeList.onmousedown = self.onSelectCode
    self.codeList.doDrawItem = ParadisePromo_Admin_Manager.doDrawItem
    self.codeList.target = self
    self.codeList.drawBorder = true
    self.codeList.borderColor = { r = 0.35, g = 1, b = 0.45, a = 0.9 }
    self:addChild(self.codeList)

    self.btnAdd = ISButton:new(16, 415, 232, 25, "Add / Update", self, self.onButtonClick)
    self.btnAdd.internal = "ADD"
    self.btnAdd:initialise()
    self.btnAdd:instantiate()
    self:addChild(self.btnAdd)

    self.btnDelete = ISButton:new(266, 415, 200, 25, "Delete Selected", self, self.onButtonClick)
    self.btnDelete.internal = "DELETE"
    self.btnDelete:initialise()
    self.btnDelete:instantiate()
    self:addChild(self.btnDelete)

    self.btnExit = ISButton:new(484, 415, 200, 25, "Exit", self, self.onButtonClick)
    self.btnExit.internal = "EXIT"
    self.btnExit:initialise()
    self.btnExit:instantiate()
    self:addChild(self.btnExit)

    self:refreshCodeList()
    self:updateButtonStates()
end

function ParadisePromo_Admin_Manager:onToggleActive()
end

function ParadisePromo_Admin_Manager:onToggleRandomized()
end

function ParadisePromo_Admin_Manager:onToggleMode(radio, selected)
end

function ParadisePromo_Admin_Manager:onEntryChanged()
    local target = self.target or self
    if target.updateButtonStates then target:updateButtonStates() end
end

function ParadisePromo_Admin_Manager:updateButtonStates()
    if not self.btnAdd then return end
    local code = tostring(self.code:getText() or ""):gsub("^%s*(.-)%s*$", "%1")
    local items = tostring(self.itemsBox:getText() or ""):gsub("^%s*(.-)%s*$", "%1")
    local selected = self.codeList.selected and self.codeList.selected > 0 and self.codeList.items[self.codeList.selected]
    self.btnAdd.enable = code ~= "" and items ~= ""
    self.btnDelete.enable = selected ~= nil
end

function ParadisePromo_Admin_Manager:getSelectedMode()
    return self.modeRadio.selected
end

function ParadisePromo_Admin_Manager:setSelectedMode(mode)
    self.modeRadio:setSelected(mode)
end

function ParadisePromo_Admin_Manager:doDrawItem(y, item, alt)
    local list = self
    if y + list:getYScroll() + list.itemheight < 0 or y + list:getYScroll() >= list.height then
        return y + list.itemheight
    end
    if list.selected == item.index then
        list:drawRect(0, y, list:getWidth(), list.itemheight, 0.25, 0.75, 0.35, 0.45)
    elseif alt then
        list:drawRect(0, y, list:getWidth(), list.itemheight, 0.13, 0.30, 0.32, 0.32)
    end
    list:drawRectBorder(0, y, list:getWidth(), list.itemheight, 0.45, 1, 0.35, 0.45)

    local d = item.item or {}
    local modeNames = { [1] = "Once Lifetime", [2] = "Once Per Char", [3] = "Unlimited", [4] = "Daily" }
    local textY = y + 4
    local columnX = { 4, 134, 204, 304 }
    list:drawText(tostring(item.text or ""), columnX[1], textY, 1, 1, 1, 1, list.font)
    list:drawText(d.active and "Yes" or "No", columnX[2], textY, 0.8, 0.8, 0.8, 1, list.font)
    list:drawText(modeNames[d.mode] or "?", columnX[3], textY, 0.8, 0.8, 0.8, 1, list.font)
    list:drawText((d.randomized and "[R] " or "") .. tostring(d.items or ""), columnX[4], textY, 0.7, 0.7, 0.7, 1, list.font)

    return y + self.itemheight
end

function ParadisePromo_Admin_Manager:refreshCodeList()
    local selectedCode = self.code and self.code:getText() or nil
    self.codeList:clear()
    local data = ParadisePromo.data or {}

    for code, entry in pairs(data) do
        self.codeList:addItem(code, entry)
    end
    if selectedCode and data[selectedCode] then
        for index, item in ipairs(self.codeList.items) do
            if item.text == selectedCode then
                self.codeList.selected = index
                break
            end
        end
    end
    if self.codeList.selected > #self.codeList.items then self.codeList.selected = 0 end
    self:updateButtonStates()
end

function ParadisePromo_Admin_Manager:onSelectCode(x, y)
    local list = self
    local row = list:rowAt(x, y)
    if row <= 0 or row > #list.items then
        list.selected = 0
        list.target:updateButtonStates()
        return
    end
    list.selected = row
    local item = list.items[row]
    local data = item.item or item
    list.target.code:setText(item.text or "")
    list.target.activeTick:setSelected(1, data.active == true)
    list.target.randomTick:setSelected(1, data.randomized == true)
    list.target:setSelectedMode(data.mode or 1)
    list.target.itemsBox:setText(data.items or "")
    list.target:updateButtonStates()
end

function ParadisePromo_Admin_Manager:onButtonClick(button)
    local player = getSpecificPlayer(0)
    if not player then return end

    if button.internal == "ADD" then
        local code = tostring(self.code:getText() or ""):gsub("^%s*(.-)%s*$", "%1")
        local items = tostring(self.itemsBox:getText() or ""):gsub("^%s*(.-)%s*$", "%1")
        if code == "" or items == "" then return end
        local args = {
            code = code,
            active = self.activeTick:isSelected(1) == true,
            randomized = self.randomTick:isSelected(1) == true,
            mode = self:getSelectedMode(),
            items = items
        }
        sendClientCommand(player, "ParadisePromo", "save", args)

    elseif button.internal == "DELETE" then
        local selectedIndex = self.codeList.selected
        if selectedIndex and selectedIndex > 0 then
            local item = self.codeList.items[selectedIndex]
            if item then
                sendClientCommand(player, "ParadisePromo", "delete", { code = item.text })
                self.codeList.selected = 0
                self:updateButtonStates()
            end
        end

    elseif button.internal == "EXIT" then
        self:close()
    end
end

function ParadisePromo_Admin_Manager:render()
    ISPanel.render(self)
end