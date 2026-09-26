ParadiseDev = ParadiseDev or {}
ParadiseDev.Panels = ParadiseDev.Panels or {}

require "ISUI/ISTextEntryBox"

ParadiseDev.Panels.PlaytimeCheck = ISCollapsableWindow:derive("ParadiseDev.Panels.PlaytimeCheck")

function ParadiseDev.Panels.PlaytimeCheck:requestCheck()
    local query = tostring(self.entry:getText() or ""):gsub("^%s*(.-)%s*$", "%1")
    if query == "" then
        self.result:setName("Enter a username or Steam ID.")
        return
    end
    if not (isClient and isClient()) or not sendClientCommand then
        self.result:setName("This panel requires a multiplayer server.")
        return
    end
    self.result:setName("Checking...")
    sendClientCommand("ParadiseDevPlaytime", "check", { query = query })
end

function ParadiseDev.Panels.PlaytimeCheck:onClick(button)
    if button.internal == "CHECK" then self:requestCheck() end
end

function ParadiseDev.Panels.PlaytimeCheck:createChildren()
    ISCollapsableWindow.createChildren(self)
    local top = self:titleBarHeight() + 12
    self.label = ISLabel:new(12, top, 18, "Username or Steam ID", 0.85, 0.9, 1, 1, UIFont.Small, true)
    self.label:initialise()
    self:addChild(self.label)
    self.entry = ISTextEntryBox:new("", 12, top + 24, self.width - 24, 24)
    self.entry:initialise()
    self.entry:instantiate()
    self:addChild(self.entry)
    self.checkButton = ISButton:new(12, top + 58, 110, 26, "Check", self, ParadiseDev.Panels.PlaytimeCheck.onClick)
    self.checkButton.internal = "CHECK"
    self.checkButton:initialise()
    self.checkButton:instantiate()
    self:addChild(self.checkButton)
    self.result = ISLabel:new(12, top + 94, 18, "", 0.85, 0.9, 1, 1, UIFont.Small, true)
    self.result:initialise()
    self:addChild(self.result)
end

function ParadiseDev.Panels.PlaytimeCheck:close()
    ISCollapsableWindow.close(self)
    if ParadiseDev.Panels.playtimeCheck == self then ParadiseDev.Panels.playtimeCheck = nil end
end

function ParadiseDev.Panels.PlaytimeCheck:new(x, y, width, height)
    local panel = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(panel, self)
    self.__index = self
    panel.title = "Paradise Playtime Checker"
    panel.resizable = false
    return panel
end

function ParadiseDev.Panels.openPlaytimeCheck()
    if not ParadiseDev.isAdm() then return end
    if ParadiseDev.Panels.playtimeCheck then
        ParadiseDev.Panels.playtimeCheck:setVisible(true)
        ParadiseDev.Panels.playtimeCheck:bringToTop()
        return
    end
    local panel = ParadiseDev.Panels.PlaytimeCheck:new(250, 180, 400, 180)
    panel:initialise()
    panel:addToUIManager()
    panel:setVisible(true)
    ParadiseDev.Panels.playtimeCheck = panel
end

function ParadiseDev.Panels.formatPlaytime(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    return string.format("%dh %dm", hours, minutes)
end

function ParadiseDev.Panels.onPlaytimeServerCommand(module, command, args)
    if module ~= "ParadiseDevPlaytime" or command ~= "result" then return end
    local panel = ParadiseDev.Panels.playtimeCheck
    if not panel then return end
    if args and args.error then
        panel.result:setName(args.error)
        return
    end
    panel.result:setName(tostring(args and args.username or "Unknown") .. ": " .. ParadiseDev.Panels.formatPlaytime(args and args.seconds or 0))
end

Events.OnServerCommand.Remove(ParadiseDev.Panels.onPlaytimeServerCommand)
Events.OnServerCommand.Add(ParadiseDev.Panels.onPlaytimeServerCommand)
