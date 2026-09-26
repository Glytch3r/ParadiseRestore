ParadiseDev = ParadiseDev or {}
ParadiseDev.Panels = ParadiseDev.Panels or {}

require "ISUI/ISTextEntryBox"

ParadiseDev.Panels.ModActiveCheck = ISCollapsableWindow:derive("ParadiseDev.Panels.ModActiveCheck")

function ParadiseDev.Panels.ModActiveCheck:checkActive()
    local id = self.entry:getText() or ""
    local active = ParadiseZ.isModActive(id)
    self.result:setName(active and "Active" or "Not active")
    self.result:setColor(active and 0.3 or 1, active and 1 or 0.3, 0.3, 1)
end

function ParadiseDev.Panels.ModActiveCheck:onClick(button)
    if button.internal == "CHECK" then self:checkActive() end
end

function ParadiseDev.Panels.ModActiveCheck:createChildren()
    ISCollapsableWindow.createChildren(self)
    local top = self:titleBarHeight() + 12
    self.label = ISLabel:new(12, top, 18, "Mod ID or Workshop ID", 0.85, 0.9, 1, 1, UIFont.Small, true)
    self.label:initialise()
    self:addChild(self.label)
    self.entry = ISTextEntryBox:new("", 12, top + 24, self.width - 24, 24)
    self.entry:initialise()
    self.entry:instantiate()
    self:addChild(self.entry)
    self.checkButton = ISButton:new(12, top + 58, 110, 26, "Check", self, ParadiseDev.Panels.ModActiveCheck.onClick)
    self.checkButton.internal = "CHECK"
    self.checkButton:initialise()
    self.checkButton:instantiate()
    self:addChild(self.checkButton)
    self.result = ISLabel:new(132, top + 63, 18, "", 0.85, 0.9, 1, 1, UIFont.Small, true)
    self.result:initialise()
    self:addChild(self.result)
end

function ParadiseDev.Panels.ModActiveCheck:close()
    ISCollapsableWindow.close(self)
    if ParadiseDev.Panels.modActiveCheck == self then ParadiseDev.Panels.modActiveCheck = nil end
end

function ParadiseDev.Panels.ModActiveCheck:new(x, y, width, height)
    local panel = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(panel, self)
    self.__index = self
    panel.title = "ParadiseZ Mod Active Check"
    panel.resizable = false
    return panel
end

function ParadiseDev.Panels.openModActiveCheck()
    if not ParadiseDev.isAdm() then return end
    if ParadiseDev.Panels.modActiveCheck then
        ParadiseDev.Panels.modActiveCheck:setVisible(true)
        ParadiseDev.Panels.modActiveCheck:bringToTop()
        return
    end
    local panel = ParadiseDev.Panels.ModActiveCheck:new(250, 180, 360, 150)
    panel:initialise()
    panel:addToUIManager()
    panel:setVisible(true)
    ParadiseDev.Panels.modActiveCheck = panel
end
