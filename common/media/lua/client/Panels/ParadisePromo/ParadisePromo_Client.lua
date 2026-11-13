require "ISUI/ISCollapsableWindow"

ParadisePromo_Player_Panel = ISCollapsableWindow:derive("ParadisePromo_Player_Panel")
ParadisePromo = ParadisePromo or {}



function ParadisePromo_Player_Panel:new(x, y, width, height)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o.title = "Redeem Promo Code"
    o.backgroundColor = {r=0, g=0, b=0, a=0.8}
    o.borderColor = {r=0.35, g=0.35, b=0.35, a=1}
    o.moveWithMouse = true
    return o
end

function ParadisePromo_Player_Panel:close()
    ParadisePromo.PlayerPanel.ClosePanel()
end

function ParadisePromo_Player_Panel:initialise()
    ISCollapsableWindow.initialise(self)
    self.anchorLeft = true
    self.anchorRight = false
    self.anchorTop = true
    self.anchorBottom = false
    self.drawBackground = true
    self.drawBorder = true
    self.resizable = false
end

function ParadisePromo_Player_Panel:createChildren()
    ISCollapsableWindow.createChildren(self)

    local th = self:titleBarHeight()

    self.code = ISTextEntryBox:new("", 16, th + 22, self.width - 32, 25)
    self.code:initialise()
    self.code:instantiate()
    self.code.onCommandEntered = function() self:onButtonClick(self.btnRedeem) end
    self:addChild(self.code)

    self.statusLabel = ISLabel:new(16, th + 52, 20, "", 1, 1, 1, 1, UIFont.Small, true)
    self.statusLabel:initialise()
    self:addChild(self.statusLabel)

    self.btnRedeem = ISButton:new(16, self.height - 40, (self.width - 48) / 2, 25, "Redeem", self, self.onButtonClick)
    self.btnRedeem.internal = "REDEEM"
    self.btnRedeem:initialise()
    self.btnRedeem:instantiate()
    self:addChild(self.btnRedeem)

    self.btnExit = ISButton:new(16 + (self.width - 48) / 2 + 16, self.height - 40, (self.width - 48) / 2, 25, "Exit", self, self.onButtonClick)
    self.btnExit.internal = "EXIT"
    self.btnExit:initialise()
    self.btnExit:instantiate()
    self:addChild(self.btnExit)
end

function ParadisePromo_Player_Panel:onButtonClick(button)
    local player = getSpecificPlayer(0)
    if not player then return end

    if button.internal == "REDEEM" then
        local code = tostring(self.code:getText() or ""):gsub("^%s*(.-)%s*$", "%1")
        if code == "" then return end
        sendClientCommand(player, "ParadisePromo", "redeem", { code = code })

    elseif button.internal == "EXIT" then
        self:close()
    end
end

function ParadisePromo_Player_Panel:onRedeemResult(success, message)
    if not self.statusLabel then return end
    if success then
        self.statusLabel:setColor(0.2, 1, 0.2, 1)
    else
        self.statusLabel:setColor(1, 0.2, 0.2, 1)
    end
    self.statusLabel:setName(tostring(message or ""))
    if success then
        self.code:setText("")
    end
end

function ParadisePromo_Player_Panel:render()
    ISCollapsableWindow.render(self)
end
