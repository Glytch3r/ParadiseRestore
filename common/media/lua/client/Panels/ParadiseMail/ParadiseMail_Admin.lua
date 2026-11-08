require "ISUI/ISPanel"
require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISTextEntryBox"
require "ISUI/ISScrollingListBox"
require "ISUI/ISComboBox"

ParadiseMail = ParadiseMail or {}
ParadiseMail_Admin_Panel = ISCollapsableWindow:derive("ParadiseMail_Admin_Panel")

local function fmtTime(t)
    t = tonumber(t)
    if not t then return "" end
    local ok, str = pcall(os.date, "%m/%d %H:%M", t)
    return ok and str or ""
end

local function addButton(panel, label, x, y, w, h, internal)
    local button = ISButton:new(x, y, w, h, label, panel, ParadiseMail_Admin_Panel.onButtonClick)
    button.internal = internal
    button:initialise()
    button:instantiate()
    panel:addChild(button)
    return button
end

local function addLabel(panel, text, x, y, w)
    local label = ISLabel:new(x, y, 18, text, 1, 1, 1, 1, UIFont.Small, true)
    label:initialise()
    panel:addChild(label)
    return label
end

local function addList(panel, x, y, w, h, onSelect)
    local list = ISScrollingListBox:new(x, y, w, h)
    list:initialise()
    list:instantiate()
    list.itemheight = 24
    list.font = UIFont.Small
    list.selected = 0
    list.drawBorder = true
    list.doDrawItem = function(self, rowY, item, alt)
        if rowY + self:getYScroll() + self.itemheight < 0 or rowY + self:getYScroll() >= self.height then
            return rowY + self.itemheight
        end
        if self.selected == item.index then
            self:drawRect(0, rowY, self:getWidth(), self.itemheight, 0.25, 0.75, 0.35, 0.45)
        elseif alt then
            self:drawRect(0, rowY, self:getWidth(), self.itemheight, 0.13, 0.30, 0.32, 0.32)
        end
        self:drawText(ParadiseZ.fitText and ParadiseZ.fitText(item.text or "", self.width - 12, self.font) or item.text or "",
            4, rowY + 4, 1, 1, 1, 1, self.font)
        return rowY + self.itemheight
    end
    list.onmousedown = function(target, item)
        if panel.onListSelect then panel:onListSelect(list, list.selected) end
    end
    panel:addChild(list)
    return list
end

function ParadiseMail_Admin_Panel:new(x, y, width, height)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o.title = "Paradise Mail - Admin"
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.85 }
    o.borderColor = { r = 0.35, g = 0.35, b = 0.35, a = 1 }
    o.moveWithMouse = true
    return o
end

function ParadiseMail_Admin_Panel:initialise()
    ISCollapsableWindow.initialise(self)
    self.anchorLeft = true
    self.anchorRight = false
    self.anchorTop = true
    self.anchorBottom = false
    self.drawBackground = true
    self.drawBorder = true
    self.resizable = false
end

function ParadiseMail_Admin_Panel:createChildren()
    ISCollapsableWindow.createChildren(self)

    local th = self:titleBarHeight()

    addLabel(self, "Templates", 12, th + 32, 100)
    self.tmplList = addList(self, 12, th + 52, 240, 120)
    addButton(self, "Load set", 258, th + 52, 130, 22, "LOAD_TEMPLATE")
    addButton(self, "Delete template", 258, th + 78, 130, 22, "DELETE_TEMPLATE")
    self.tmplName = ISTextEntryBox:new("", 258, th + 104, 130, 22)
    self.tmplName:initialise()
    self.tmplName:instantiate()
    self:addChild(self.tmplName)
    addButton(self, "Save template", 258, th + 130, 130, 22, "SAVE_TEMPLATE")

    addLabel(self, "Working set", 12, th + 180, 100)
    self.workList = addList(self, 12, th + 200, 240, 160)
    addButton(self, "Qty +", 258, th + 200, 130, 22, "QTY_UP")
    addButton(self, "Qty -", 258, th + 226, 130, 22, "QTY_DOWN")
    addButton(self, "Remove line", 258, th + 252, 130, 22, "REMOVE_LINE")
    addButton(self, "Clear set", 258, th + 278, 130, 22, "CLEAR_SET")
    addButton(self, "Capture inventory", 258, th + 304, 130, 24, "CAPTURE_INV")

    self.moneyAmt = ISTextEntryBox:new("", 12, th + 370, 110, 24)
    self.moneyAmt:initialise()
    self.moneyAmt:instantiate()
    self:addChild(self.moneyAmt)
    self.moneyCur = ISComboBox:new(130, th + 370, 120, 24, self, function() end)
    self.moneyCur:initialise()
    self:addChild(self.moneyCur)
    self.moneyCur:addOption("Jimoleon")
    self.moneyCur:addOption("Paradisium")
    self.moneyCur:setSelected(1)
    addButton(self, "Add money", 258, th + 370, 130, 24, "ADD_MONEY")
    self.moneyLabel = addLabel(self, "Money: -", 12, th + 398, 240)

    local rightX = math.min(420, self.width - 400)
    addLabel(self, "Recipients", rightX, th + 32, 100)
    self.usersCombo = ISComboBox:new(rightX, th + 52, 200, 24, self, function() end)
    self.usersCombo:initialise()
    self:addChild(self.usersCombo)
    addButton(self, "Add user", rightX + 206, th + 52, 100, 22, "ADD_USER")
    self.userEntry = ISTextEntryBox:new("username", rightX, th + 80, 140, 24)
    self.userEntry:initialise()
    self.userEntry:instantiate()
    self:addChild(self.userEntry)
    addButton(self, "Add", rightX + 146, th + 80, 60, 22, "ADD_MANUAL")
    addButton(self, "All online", rightX + 212, th + 80, 94, 22, "ADD_ONLINE")
    self.recList = addList(self, rightX, th + 108, 306, 120)
    addButton(self, "Remove sel", rightX + 206, th + 232, 100, 22, "REMOVE_REC")

    addLabel(self, "Subject", rightX, th + 260, 100)
    self.subject = ISTextEntryBox:new("Reward", rightX, th + 280, 306, 24)
    self.subject:initialise()
    self.subject:instantiate()
    self:addChild(self.subject)
    addLabel(self, "Message", rightX, th + 340, 100)
    self.message = ISTextEntryBox:new("", rightX, th + 358, 306, 24)
    self.message:initialise()
    self.message:instantiate()
    self:addChild(self.message)
    addButton(self, "Send working set", rightX, th + 392, 150, 26, "SEND_SET")
    addButton(self, "Send template", rightX + 158, th + 392, 148, 26, "SEND_TEMPLATE")

    addLabel(self, "Mailboxes", 12, th + 430, 100)
    self.boxList = addList(self, 12, th + 450, 240, 150 - th)
    addLabel(self, "Messages", 258, th + 430, 100)
    self.msgList = addList(self, 258, th + 450, 400, 150 - th)
    addButton(self, "Delete mail", 664, th + 450, 110, 22, "DELETE_MAIL")
    addButton(self, "Clear box", 664, th + 476, 110, 22, "CLEAR_BOX")
    addButton(self, "Refresh", 664, th + 502, 110, 22, "REFRESH")

    self.statusLabel = addLabel(self, "", 12, self.height - 30, math.max(400, self.width - 110))
    self.statusLabel:setColor(0.6, 0.9, 0.6, 1)
    addButton(self, "Exit", self.width - 88, self.height - 34, 76, 24, "EXIT")

    self:refreshFromData()
end

function ParadiseMail_Admin_Panel:onListSelect(list, row)
    if list == self.boxList then
        self:refreshMessages()
    elseif list == self.workList then
        -- selection kept for qty buttons
    end
end

function ParadiseMail_Admin_Panel:setStatus(message)
    if not self.statusLabel then return end
    self.statusLabel:setName(tostring(message or ""))
end

function ParadiseMail_Admin_Panel:refreshFromData()
    if not self.workList then return end
    local data = ParadiseMail.adminData or {}

    self.tmplList:clear()
    for name in pairs(data.templates or {}) do self.tmplList:addItem(name, name) end

    self.usersCombo:clear()
    for _, user in ipairs(data.users or {}) do self.usersCombo:addOption(user) end

    self.boxList:clear()
    for _, box in ipairs(data.boxes or {}) do
        self.boxList:addItem(box.user .. " (" .. tostring(box.count) .. ")", box)
    end
    if self.boxList.selected > #self.boxList.items then self.boxList.selected = 0 end
    self:refreshMessages()
    self:refreshWorking()
end

function ParadiseMail_Admin_Panel:refreshWorking()
    if not self.workList then return end
    self.workList:clear()
    for index, entry in ipairs(ParadiseMail.working or {}) do
        self.workList:addItem(tostring(entry.qty) .. "x " .. ParadiseMail.itemLabel(entry.data), index)
    end
    if self.workList.selected > #self.workList.items then self.workList.selected = 0 end
    local money = ParadiseMail.workingMoney or {}
    self.moneyLabel:setName("Money: " .. tostring(tonumber(money.jimoleon) or 0)
        .. " jim, " .. tostring(tonumber(money.paradisium) or 0) .. " para")
end

function ParadiseMail_Admin_Panel:refreshMessages()
    if not self.msgList then return end
    self.msgList:clear()
    self.selBoxUser = nil
    local boxItem = self.boxList.selected > 0 and self.boxList.items[self.boxList.selected] or nil
    if not boxItem then return end
    self.selBoxUser = boxItem.item.user
    for _, msg in ipairs(boxItem.item.messages or {}) do
        local line = tostring(msg.id) .. " | " .. tostring(msg.title) .. " | from " .. tostring(msg.from)
            .. " | " .. fmtTime(msg.sentAt)
            .. " | " .. tostring(msg.lines) .. " lines, " .. tostring(msg.jimoleon) .. "j " .. tostring(msg.paradisium) .. "p"
            .. " | " .. tostring(msg.message or "")
        self.msgList:addItem(line, msg)
    end
    if self.msgList.selected > #self.msgList.items then self.msgList.selected = 0 end
end

function ParadiseMail_Admin_Panel:workingMoneyTotal(currency)
    return tonumber((ParadiseMail.workingMoney or {})[currency]) or 0
end

function ParadiseMail_Admin_Panel:onButtonClick(button)
    local internal = button.internal

    if internal == "EXIT" then
        self:close()

    elseif internal == "CAPTURE_INV" then
        local added = ParadiseMail.captureInventory()
        self:setStatus("Captured " .. tostring(added) .. " lines from inventory")
        self:refreshWorking()

    elseif internal == "CLEAR_SET" then
        ParadiseMail.resetWorking()
        self:refreshWorking()

    elseif internal == "REMOVE_LINE" then
        local sel = self.workList.selected
        if sel > 0 and ParadiseMail.working[sel] then
            table.remove(ParadiseMail.working, sel)
            self.workList.selected = 0
            self:refreshWorking()
        end

    elseif internal == "QTY_UP" or internal == "QTY_DOWN" then
        local sel = self.workList.selected
        local entry = sel > 0 and ParadiseMail.working[sel] or nil
        if entry then
            local qty = math.floor(tonumber(entry.qty) or 1)
            if internal == "QTY_UP" then qty = math.min(ParadiseMail.maxQty, qty + 1) else qty = math.max(1, qty - 1) end
            entry.qty = qty
            self:refreshWorking()
        end

    elseif internal == "ADD_MONEY" then
        local amount = ParadiseMail.trimAmount(self.moneyAmt:getText())
        if not amount or amount < 1 then self:setStatus("Enter a positive amount") return end
        local option = self.moneyCur.options[self.moneyCur.selected]
        local currency = option == "Paradisium" and "paradisium" or "jimoleon"
        ParadiseMail.workingMoney[currency] = self:workingMoneyTotal(currency) + amount
        self.moneyAmt:setText("")
        self:refreshWorking()

    elseif internal == "SAVE_TEMPLATE" then
        local name = ParadiseMail.normalizeTemplateName(self.tmplName:getText())
        if not name then self:setStatus("Enter a template name") return end
        ParadiseMail.send("saveTemplate", { name = name, set = ParadiseMail.buildSet() })

    elseif internal == "LOAD_TEMPLATE" then
        local item = self.tmplList.selected > 0 and self.tmplList.items[self.tmplList.selected] or nil
        if not item then self:setStatus("Select a template") return end
        local template = (ParadiseMail.adminData or {}).templates and ParadiseMail.adminData.templates[item.text]
        if not template then self:setStatus("Template not found") return end
        ParadiseMail.resetWorking()
        for _, entry in ipairs(template.items or {}) do
            ParadiseMail.working[#ParadiseMail.working + 1] = { data = entry.data, qty = tonumber(entry.qty) or 1 }
        end
        local money = template.money or {}
        ParadiseMail.workingMoney = { jimoleon = tonumber(money.jimoleon) or 0, paradisium = tonumber(money.paradisium) or 0 }
        self.tmplName:setText(item.text)
        self:refreshWorking()

    elseif internal == "DELETE_TEMPLATE" then
        local item = self.tmplList.selected > 0 and self.tmplList.items[self.tmplList.selected] or nil
        if not item then self:setStatus("Select a template") return end
        ParadiseMail.send("deleteTemplate", { name = item.text })

    elseif internal == "ADD_USER" then
        local option = self.usersCombo.options[self.usersCombo.selected]
        if option then self:addRecipient(option) end

    elseif internal == "ADD_MANUAL" then
        self:addRecipient(self.userEntry:getText())
        self.userEntry:setText("")

    elseif internal == "ADD_ONLINE" then
        for _, user in ipairs((ParadiseMail.adminData or {}).online or {}) do self:addRecipient(user) end
        self:setStatus("All online players added")

    elseif internal == "REMOVE_REC" then
        local sel = self.recList.selected
        if sel > 0 then
            table.remove(self.recipients, sel)
            self:refreshRecipients()
        end

    elseif internal == "SEND_SET" then
        self:doSend(false)

    elseif internal == "SEND_TEMPLATE" then
        self:doSend(true)

    elseif internal == "DELETE_MAIL" then
        local item = self.msgList.selected > 0 and self.msgList.items[self.msgList.selected] or nil
        if not item or not self.selBoxUser then self:setStatus("Select a queued message") return end
        ParadiseMail.send("deleteMail", { user = self.selBoxUser, id = item.item.id })

    elseif internal == "CLEAR_BOX" then
        if not self.selBoxUser then self:setStatus("Select a mailbox") return end
        ParadiseMail.send("deleteMail", { user = self.selBoxUser, all = true })

    elseif internal == "REFRESH" then
        ParadiseMail.send("requestAdminState")
    end
end

function ParadiseMail_Admin_Panel:addRecipient(user)
    user = tostring(user or ""):match("^%s*(.-)%s*$")
    local key = ParadiseMail.userKey(user)
    if not key then return end
    self.recipients = self.recipients or {}
    for _, existing in ipairs(self.recipients) do
        if ParadiseMail.userKey(existing) == key then return end
    end
    self.recipients[#self.recipients + 1] = user
    self:refreshRecipients()
end

function ParadiseMail_Admin_Panel:refreshRecipients()
    if not self.recList then return end
    self.recList:clear()
    for _, user in ipairs(self.recipients or {}) do self.recList:addItem(user, user) end
    if self.recList.selected > #self.recList.items then self.recList.selected = 0 end
end

function ParadiseMail_Admin_Panel:doSend(useTemplate)
    self.recipients = self.recipients or {}
    if #self.recipients == 0 then self:setStatus("Add recipients first") return end
    local title = ParadiseMail.normalizeTitle(self.subject:getText())
    if not title then self:setStatus("Enter a subject") return end
    local args = { title = title, recipients = self.recipients, message = ParadiseMail.normalizeMessage(self.message:getText()) }
    if useTemplate then
        local item = self.tmplList.selected > 0 and self.tmplList.items[self.tmplList.selected] or nil
        if not item then self:setStatus("Select a template to send") return end
        args.template = item.text
    else
        args.set = ParadiseMail.buildSet()
    end
    ParadiseMail.send("send", args)
    self:setStatus("Sending...")
end

function ParadiseMail_Admin_Panel:close()
    ParadiseMail.AdminPanel.ClosePanel()
end

function ParadiseMail_Admin_Panel:onDestroy()
    ISPanel.onDestroy(self)
    if ParadiseMail.adminInstance then ParadiseMail.AdminPanel.ClosePanel() end
end
