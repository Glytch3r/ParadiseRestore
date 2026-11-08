require "ISUI/ISPanel"
require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISScrollingListBox"

ParadiseMail = ParadiseMail or {}
ParadiseMail_Player_Panel = ISCollapsableWindow:derive("ParadiseMail_Player_Panel")

local function fmtTime(t)
    t = tonumber(t)
    if not t then return "" end
    local ok, str = pcall(os.date, "%m/%d %H:%M", t)
    return ok and str or ""
end

local function wrapMessage(text, maxWidth, font)
    local words = {}
    for word in tostring(text or ""):gmatch("%S+") do words[#words + 1] = word end
    local lines, current = {}, ""
    for _, word in ipairs(words) do
        local candidate = current == "" and word or (current .. " " .. word)
        if current ~= "" and getTextManager():MeasureStringX(font, candidate) > maxWidth then
            lines[#lines + 1] = current
            current = word
        else
            current = candidate
        end
    end
    if current ~= "" then lines[#lines + 1] = current end
    return lines
end

function ParadiseMail_Player_Panel:new(x, y, width, height)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o.title = "Your Mail"
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.85 }
    o.borderColor = { r = 0.35, g = 0.35, b = 0.35, a = 1 }
    o.moveWithMouse = true
    return o
end

function ParadiseMail_Player_Panel:initialise()
    ISCollapsableWindow.initialise(self)
    self.anchorLeft = true
    self.anchorRight = false
    self.anchorTop = true
    self.anchorBottom = false
    self.drawBackground = true
    self.drawBorder = true
    self.resizable = false
end

function ParadiseMail_Player_Panel:createChildren()
    ISCollapsableWindow.createChildren(self)

    local th = self:titleBarHeight()

    self.mailList = ISScrollingListBox:new(12, th + 36, self.width - 24, self.height - 170 - th)
    self.mailList:initialise()
    self.mailList:instantiate()
    self.mailList.itemheight = 34
    self.mailList.font = UIFont.Small
    self.mailList.selected = 0
    self.mailList.drawBorder = true
    self.mailList.doDrawItem = function(self, rowY, item, alt)
        if rowY + self:getYScroll() + self.itemheight < 0 or rowY + self:getYScroll() >= self.height then
            return rowY + self.itemheight
        end
        if self.selected == item.index then
            self:drawRect(0, rowY, self:getWidth(), self.itemheight, 0.25, 0.75, 0.35, 0.45)
        elseif alt then
            self:drawRect(0, rowY, self:getWidth(), self.itemheight, 0.13, 0.30, 0.32, 0.32)
        end
        local msg = item.item or {}
        self:drawText(ParadiseZ.fitText(tostring(msg.title or ""), self.width - 20, self.font), 6, rowY + 3, 1, 1, 1, 1, self.font)
        local copies = 0
        for _, entry in ipairs(msg.items or {}) do copies = copies + (tonumber(entry.qty) or 0) end
        local money = msg.money or {}
        local second = "from " .. tostring(msg.from or "?") .. "  " .. fmtTime(msg.sentAt)
            .. "  " .. tostring(#(msg.items or {})) .. " lines (" .. tostring(copies) .. " items)"
        local jimoleon = tonumber(money.jimoleon) or 0
        local paradisium = tonumber(money.paradisium) or 0
        if jimoleon > 0 then second = second .. ", " .. tostring(jimoleon) .. " jim" end
        if paradisium > 0 then second = second .. ", " .. tostring(paradisium) .. " para" end
        self:drawText(ParadiseZ.fitText(second, self.width - 20, self.font), 6, rowY + 18, 0.7, 0.7, 0.7, 1, self.font)
        return rowY + self.itemheight
    end
    self.mailList.onmousedown = function(target, item)
        if self.claimButton then
            self.claimButton:setEnable(self.mailList.selected > 0)
        end
    end
    self:addChild(self.mailList)

    local buttonY = self.height - 74
    local half = (self.width - 24) / 2 - 110
    self.claimButton = self:addButton("Claim selected", 12, buttonY, half, 26, "CLAIM")
    self.claimAllButton = self:addButton("Claim all", 12 + half + 8, buttonY, half, 26, "CLAIM_ALL")
    self.refreshButton = self:addButton("Refresh", 12 + 2 * (half + 8), buttonY, 100, 26, "REFRESH")
    self.exitButton = self:addButton("Exit", self.width - 92, buttonY, 80, 26, "EXIT")

    self.msgY = self.height - 130
    self.msgH = 44

    self.statusLabel = ISLabel:new(12, self.height - 34, 18, "", 0.6, 0.9, 0.6, 1, UIFont.Small, true)
    self.statusLabel:initialise()
    self:addChild(self.statusLabel)

    self:refreshFromData()
end

function ParadiseMail_Player_Panel:addButton(label, x, y, w, h, internal)
    local button = ISButton:new(x, y, w, h, label, self, ParadiseMail_Player_Panel.onButtonClick)
    button.internal = internal
    button:initialise()
    button:instantiate()
    self:addChild(button)
    return button
end

function ParadiseMail_Player_Panel:prerender()
    ISCollapsableWindow.prerender(self)
    if not self.mailList then return end
    self:drawRect(12, self.msgY, self.width - 24, self.msgH, 0.35, 0.1, 0.1, 0.1)
    self:drawRectBorder(12, self.msgY, self.width - 24, self.msgH, 0.5, 0.35, 0.35, 0.35)
    local msgItem = self.mailList.selected > 0 and self.mailList.items[self.mailList.selected] or nil
    local text = msgItem and type(msgItem.item) == "table" and tostring(msgItem.item.message or "") or ""
    if text == "" then
        self:drawText("No message", 18, self.msgY + 4, 0.6, 0.6, 0.6, 1, UIFont.Small)
        return
    end
    local lines = wrapMessage(text, self.width - 44, UIFont.Small)
    for i = 1, math.min(#lines, 3) do
        self:drawText(lines[i], 18, self.msgY + 4 + (i - 1) * 14, 1, 1, 1, 1, UIFont.Small)
    end
end

function ParadiseMail_Player_Panel:refreshFromData()
    if not self.mailList then return end
    self.mailList:clear()
    for _, msg in ipairs(ParadiseMail.mailData or {}) do self.mailList:addItem("", msg) end
    if self.mailList.selected > #self.mailList.items then self.mailList.selected = 0 end
    local count = #self.mailList.items
    self.claimButton:setEnable(count > 0 and self.mailList.selected > 0)
    self.claimAllButton:setEnable(count > 0)
end

function ParadiseMail_Player_Panel:setStatus(message, ok)
    if not self.statusLabel then return end
    self.statusLabel:setName(tostring(message or ""))
    if ok == nil then ok = true end
    if ok then self.statusLabel:setColor(0.6, 0.9, 0.6, 1) else self.statusLabel:setColor(1, 0.4, 0.4, 1) end
end

function ParadiseMail_Player_Panel:onButtonClick(button)
    local pl = getSpecificPlayer(0)
    if not pl then return end

    if button.internal == "CLAIM" then
        local item = self.mailList.selected > 0 and self.mailList.items[self.mailList.selected] or nil
        if not item then self:setStatus("Select a package first", false) return end
        sendClientCommand(pl, ParadiseMail.module, "claim", { id = item.item.id })

    elseif button.internal == "CLAIM_ALL" then
        sendClientCommand(pl, ParadiseMail.module, "claimAll", {})

    elseif button.internal == "REFRESH" then
        ParadiseMail.send("requestMailbox")

    elseif button.internal == "EXIT" then
        self:close()
    end
end

function ParadiseMail_Player_Panel:close()
    ParadiseMail.PlayerPanel.ClosePanel()
end

function ParadiseMail_Player_Panel:onDestroy()
    ISPanel.onDestroy(self)
    if ParadiseMail.playerInstance then ParadiseMail.PlayerPanel.ClosePanel() end
end
