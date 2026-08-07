ParadiseDev = ParadiseDev or {}
ParadiseDev.Cage = ParadiseDev.Cage or {}

require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISScrollingListBox"

ParadiseDev.Cage.entries = ParadiseDev.Cage.entries or {}
ParadiseDev.Cage.window = ParadiseDev.Cage.window or nil

function ParadiseDev.Cage.isAdmin()
    local player = getPlayer()
    return player and string.lower(tostring(player:getAccessLevel())) == "admin"
end

function ParadiseDev.Cage.requestState()
    if isClient() then sendClientCommand("ParadiseDevCage", "list", {}) end
end

function ParadiseDev.Cage.requestSet(username, isCaged)
    if not username or username == "" or not isClient() then return end
    sendClientCommand("ParadiseDevCage", "set", { username = username, isCaged = isCaged == true })
end

function ParadiseDev.Cage.requestSteamIdSet(steamId, isCaged)
    if not steamId or steamId == "" or not isClient() then return end
    sendClientCommand("ParadiseDevCage", "set", { steamId = steamId, isCaged = isCaged == true })
end

function ParadiseDev.Cage.addTargetOptions(context, target)
    if not ParadiseDev.Cage.isAdmin() or not context or not target then return end
    local username = target.username or (target.getUsername and target:getUsername())
    if not username or username == "" then return end
    context:addOption("isCaged: [TRUE]", nil, ParadiseDev.Cage.requestSet, username, true)
    context:addOption("isCaged: [FALSE]", nil, ParadiseDev.Cage.requestSet, username, false)
end

function ParadiseDev.Cage.getWorldTarget(context)
    if not context or not context.options then return nil end
    for _, option in ipairs(context.options) do
        local target = option.param4
        if target and instanceof(target, "IsoPlayer") then return target end
    end
    return nil
end

function ParadiseDev.Cage.addWorldContext(playerNum, context, worldobjects, test)
    if test or not ParadiseDev.Cage.isAdmin() then return end
    ParadiseDev.Cage.addTargetOptions(context, ParadiseDev.Cage.getWorldTarget(context))
end

function ParadiseDev.Cage.addScoreboardOptions(scoreboard, target, x, y)
    if not scoreboard or not ParadiseDev.Cage.isAdmin() then return end
    local context = ISContextMenu.get(scoreboard.admin:getPlayerNum(), x + scoreboard:getAbsoluteX(), y + scoreboard:getAbsoluteY())
    ParadiseDev.Cage.addTargetOptions(context, target)
end

function ParadiseDev.Cage.scoreboardContext(scoreboard, target, x, y)
    ParadiseDev.Cage.scoreboardOriginal(scoreboard, target, x, y)
    ParadiseDev.Cage.addScoreboardOptions(scoreboard, target, x, y)
end

function ParadiseDev.Cage.hookScoreboard()
    if ParadiseDev.Cage.scoreboardOriginal or not ISMiniScoreboardUI then return end
    ParadiseDev.Cage.scoreboardOriginal = ISMiniScoreboardUI.doPlayerListContextMenu
    ISMiniScoreboardUI.doPlayerListContextMenu = ParadiseDev.Cage.scoreboardContext
end

ParadiseDev.Cage.Panel = ISCollapsableWindow:derive("ParadiseDev.Cage.Panel")

function ParadiseDev.Cage.Panel:createChildren()
    ISCollapsableWindow.createChildren(self)
    local top = self:titleBarHeight() + 10
    self.info = ISLabel:new(12, top, 18, "Steam-ID cage assignments", 0.85, 0.9, 1, 1, UIFont.Small, true)
    self.info:initialise()
    self.info:instantiate()
    self:addChild(self.info)
    self.list = ISScrollingListBox:new(12, top + 24, self.width - 24, self.height - top - 78)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = 22
    self.list.font = UIFont.Small
    self.list.drawBorder = true
    self:addChild(self.list)
    self.trueButton = ISButton:new(12, self.height - 42, 110, 26, "Set TRUE", self, ParadiseDev.Cage.Panel.onClick)
    self.trueButton.internal = "TRUE"
    self.trueButton:initialise()
    self.trueButton:instantiate()
    self:addChild(self.trueButton)
    self.falseButton = ISButton:new(128, self.height - 42, 110, 26, "Set FALSE", self, ParadiseDev.Cage.Panel.onClick)
    self.falseButton.internal = "FALSE"
    self.falseButton:initialise()
    self.falseButton:instantiate()
    self:addChild(self.falseButton)
    self.refreshButton = ISButton:new(self.width - 122, self.height - 42, 110, 26, "Refresh", self, ParadiseDev.Cage.Panel.onClick)
    self.refreshButton.internal = "REFRESH"
    self.refreshButton:initialise()
    self.refreshButton:instantiate()
    self:addChild(self.refreshButton)
    ParadiseDev.Cage.refreshPanel()
end

function ParadiseDev.Cage.Panel:onClick(button)
    if button.internal == "REFRESH" then
        ParadiseDev.Cage.requestState()
        return
    end
    local item = self.list.items[self.list.selected]
    local entry = item and item.item or nil
    if not entry then return end
    local isCaged = button.internal == "TRUE"
    if entry.online and entry.username ~= "" then
        ParadiseDev.Cage.requestSet(entry.username, isCaged)
    else
        ParadiseDev.Cage.requestSteamIdSet(entry.steamId, isCaged)
    end
end

function ParadiseDev.Cage.Panel:new(x, y, width, height)
    local panel = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(panel, self)
    self.__index = self
    panel.title = "ParadiseZ Cage Administration"
    panel.resizable = true
    return panel
end

function ParadiseDev.Cage.refreshPanel()
    local panel = ParadiseDev.Cage.window
    if not panel or not panel.list then return end
    panel.list:clear()
    for _, entry in ipairs(ParadiseDev.Cage.entries) do
        local name = entry.displayName ~= "" and entry.displayName or entry.username
        if name == "" then name = "Steam ID " .. tostring(entry.steamId) end
        local status = entry.isCaged and "TRUE" or "FALSE"
        local online = entry.online and "online" or "offline"
        panel.list:addItem(name .. " | isCaged: " .. status .. " | " .. online .. " | " .. tostring(entry.steamId), entry)
    end
end

function ParadiseDev.Cage.openPanel()
    if not ParadiseDev.Cage.isAdmin() then return end
    if ParadiseDev.Cage.window then
        ParadiseDev.Cage.window:setVisible(true)
        ParadiseDev.Cage.window:bringToTop()
        ParadiseDev.Cage.requestState()
        return
    end
    local panel = ParadiseDev.Cage.Panel:new(220, 180, 700, 420)
    panel:initialise()
    panel:addToUIManager()
    panel:setVisible(true)
    ParadiseDev.Cage.window = panel
    ParadiseDev.Cage.requestState()
end

function ParadiseDev.Cage.onServerCommand(module, command, args)
    if module ~= "ParadiseDevCage" or command ~= "state" then return end
    ParadiseDev.Cage.entries = args and args.entries or {}
    ParadiseDev.Cage.refreshPanel()
end

Events.OnServerCommand.Add(ParadiseDev.Cage.onServerCommand)
Events.OnFillWorldObjectContextMenu.Add(ParadiseDev.Cage.addWorldContext)
Events.OnGameStart.Add(ParadiseDev.Cage.hookScoreboard)
