ParadiseDev = ParadiseDev or {}
ParadiseDev.Scoreboard = ParadiseDev.Scoreboard or {}

ParadiseDev.Scoreboard.UI = ISMiniScoreboardUI:derive("ParadiseDev.Scoreboard.UI")

function ParadiseDev.Scoreboard.getCounts(data)
    local total, adm = 0, 0
    if data and data.usernames then
        total = data.usernames:size()
        for i = 0, total - 1 do
            local user = data.usernames:get(i)
            local pl = user and ParadiseRestore.getTarg(user) or nil
            if pl and pl.getAccessLevel and string.lower(tostring(pl:getAccessLevel())) == "admin" then
                adm = adm + 1
            end
        end
    end
    return total, adm
end

function ParadiseDev.Scoreboard.resizeHeight(panel, w, h)
    if not panel then return end
    local maxH = math.max(160, getCore():getScreenHeight() - panel:getY())
    panel:setHeight(math.max(160, math.min(h, maxH)))
end

function ParadiseDev.Scoreboard.UI:new(x, y, width, height, admin)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
    o.backgroundColor = {r=0, g=0, b=0, a=0.8}
    o.width = width
    o.height = height
    o.admin = admin or getPlayer()
    o.moveWithMouse = true
    o.scoreboard = nil
    return o
end

function ParadiseDev.Scoreboard.UI:initialise()
    ISPanel.initialise(self)
    local spacing = 10
    local btnWid = 100
    local fontHgt = getTextManager():getFontHeight(UIFont.Small)
    local btnHgt = fontHgt + 6

    self.no = ISButton:new(self.width - spacing - btnWid - 1, self.height - spacing - btnHgt - 1, btnWid, btnHgt, getText("UI_btn_close"), self, ISMiniScoreboardUI.onClick)
    self.no.internal = "CLOSE"
    self.no.anchorLeft = false
    self.no.anchorRight = true
    self.no.anchorTop = false
    self.no.anchorBottom = true
    self.no:initialise()
    self.no:instantiate()
    self.no:enableCancelColor()
    self:addChild(self.no)

    local y = spacing * 2 + 1 + fontHgt * 3
    self.playerList = ISScrollingListBox:new(spacing + 1, y, self.width - (spacing + 1) * 2, self.no.y - y - spacing - 1)
    self.playerList:initialise()
    self.playerList:instantiate()
    self.playerList.itemheight = btnHgt
    self.playerList.selected = 0
    self.playerList.joypadParent = self
    self.playerList.font = UIFont.NewSmall
    self.playerList.doDrawItem = self.drawPlayers
    self.playerList.drawBorder = true
    self.playerList.onRightMouseUp = ISMiniScoreboardUI.onRightMousePlayerList
    self.playerList.anchorRight = true
    self.playerList.anchorBottom = true
    self:addChild(self.playerList)

    self.minimumHeight = 160
    local rh = 16
    local grip = ISResizeWidget:new(self.width - rh, self.height - rh, rh, rh, self, true)
    grip.resizeFunction = ParadiseDev.Scoreboard.resizeHeight
    grip:initialise()
    self:addChild(grip)
    self.resizeWidget = grip

    scoreboardUpdate()
end

function ParadiseDev.Scoreboard.UI:prerender()
    self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    local fontHgt = getTextManager():getFontHeight(UIFont.Small)
    local title = "Paradise Scoreboard"
    self:drawText(title, self.width / 2 - (getTextManager():MeasureStringX(UIFont.Small, title) / 2), 10, 1, 1, 1, 1, UIFont.Small)
    local total, adm = ParadiseDev.Scoreboard.getCounts(self.scoreboard)
    self:drawText("Players online: " .. total, 10, 10 + fontHgt + 2, 1, 1, 1, 0.9, UIFont.Small)
    self:drawText("Admins Online: " .. adm, 10, 10 + (fontHgt + 2) * 2, 1, 1, 1, 0.9, UIFont.Small)
    if self.resizeWidget then
        local rh = 16
        self:drawTextureScaled(getTexture("media/ui/ResizeIcon.png"), self.width - rh + 1, self.height - rh + 1, rh - 2, rh - 2, 1, 1, 1, 1)
    end
end

function ParadiseDev.Scoreboard.UI:close()
    ISMiniScoreboardUI.close(self)
    ParadiseDev.Scoreboard.instance = nil
end

function ParadiseDev.Scoreboard.onScoreboardUpdate(usernames, displayNames, steamIDs)
    ParadiseDev.Scoreboard.data = { usernames = usernames, displayNames = displayNames, steamIDs = steamIDs }
    local inst = ParadiseDev.Scoreboard.instance
    if inst then
        inst.scoreboard = ParadiseDev.Scoreboard.data
        inst:populateList()
    end
end
Events.OnScoreboardUpdate.Remove(ParadiseDev.Scoreboard.onScoreboardUpdate)
Events.OnScoreboardUpdate.Add(ParadiseDev.Scoreboard.onScoreboardUpdate)

ParadiseDev.Scoreboard.HUD = ISPanel:derive("ParadiseDev.Scoreboard.HUD")

function ParadiseDev.Scoreboard.HUD:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = {r=0, g=0, b=0, a=0}
    o.borderColor = {r=0, g=0, b=0, a=0}
    return o
end

function ParadiseDev.Scoreboard.HUD:initialise()
    ISPanel.initialise(self)
end

function ParadiseDev.Scoreboard.HUD:render()
    local fontHgt = getTextManager():getFontHeight(UIFont.Small)
    local total, adm = ParadiseDev.Scoreboard.getCounts(ParadiseDev.Scoreboard.data)
    getTextManager():DrawString(UIFont.Small, 0, 0, "Paradise Scoreboard", 1, 0.9, 0.4, 0.9)
    getTextManager():DrawString(UIFont.Small, 0, fontHgt + 2, "Players online: " .. total, 1, 1, 1, 0.8)
    getTextManager():DrawString(UIFont.Small, 0, (fontHgt + 2) * 2, "Admins Online: " .. adm, 1, 1, 1, 0.8)
end

function ParadiseDev.Scoreboard.HUD:onMouseDown(x, y)
    if ParadiseDev.Scoreboard.OpenPanel then
        ParadiseDev.Scoreboard.OpenPanel()
    end
    return true
end

function ParadiseDev.Scoreboard.placeInHUD(pl, x, y)
    if not pl or not ParadiseRestore.isAdm(pl) then
        ParadiseDev.Scoreboard.hideHUD()
        return
    end
    if not ParadiseDev.Scoreboard.hud then
        local fontHgt = getTextManager():getFontHeight(UIFont.Small)
        local hud = ParadiseDev.Scoreboard.HUD:new(x, y, 220, (fontHgt + 2) * 3)
        hud:initialise()
        hud:addToUIManager()
        ParadiseDev.Scoreboard.hud = hud
        scoreboardUpdate()
    end
    ParadiseDev.Scoreboard.hud:setX(x)
    ParadiseDev.Scoreboard.hud:setY(y)
    ParadiseDev.Scoreboard.hud:setVisible(true)
end

function ParadiseDev.Scoreboard.hideHUD()
    if ParadiseDev.Scoreboard.hud then
        ParadiseDev.Scoreboard.hud:setVisible(false)
    end
end