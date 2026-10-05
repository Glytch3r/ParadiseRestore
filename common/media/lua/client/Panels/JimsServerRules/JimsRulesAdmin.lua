require "ISUI/ISCollapsableWindow"
require "ISUI/ISTextEntryBox"
require "ISUI/ISButton"

JimsRulesAdmin = JimsRulesAdmin or {}
JimsRulesAdmin.Panel = ISCollapsableWindow:derive("JimsRulesAdminPanel")

function JimsRulesAdmin.send(command, args)
    local pl = getPlayer()
    if not pl then return end
    sendClientCommand(pl, JimsServerRules.MODULE, command, args or {})
end

function JimsRulesAdmin.requestRules()
    JimsRulesAdmin.send(JimsServerRules.COMMAND_ADMIN_REQUEST)
end

function JimsRulesAdmin.Panel:createChildren()
    ISCollapsableWindow.createChildren(self)
    local pad = 10
    local buttonHeight = 28
    local buttonY = self.height - buttonHeight - pad
    self.editor = ISTextEntryBox:new("", pad, self:titleBarHeight() + pad, self.width - pad * 2, buttonY - self:titleBarHeight() - pad * 2)
    self.editor:initialise()
    self.editor:instantiate()
    self.editor:setMultipleLine(true)
    self.editor:setMaxLines(1000)
    self:addChild(self.editor)

    self.saveButton = ISButton:new(pad, buttonY, 100, buttonHeight, "SAVE", self, JimsRulesAdmin.Panel.onSave)
    self.saveButton:initialise()
    self:addChild(self.saveButton)

    self.reloadButton = ISButton:new(120, buttonY, 100, buttonHeight, "RELOAD", self, JimsRulesAdmin.Panel.onReload)
    self.reloadButton:initialise()
    self:addChild(self.reloadButton)

    self.resetButton = ISButton:new(230, buttonY, 140, buttonHeight, "RESTORE DEFAULT", self, JimsRulesAdmin.Panel.onReset)
    self.resetButton:initialise()
    self:addChild(self.resetButton)
end

function JimsRulesAdmin.Panel:onSave()
    JimsRulesAdmin.send(JimsServerRules.COMMAND_ADMIN_SAVE, { rules = self.editor:getText() })
end

function JimsRulesAdmin.Panel:onReload()
    JimsRulesAdmin.requestRules()
end

function JimsRulesAdmin.Panel:onReset()
    JimsRulesAdmin.send(JimsServerRules.COMMAND_ADMIN_RESET)
end

function JimsRulesAdmin.Panel:setRules(rules, message)
    self.editor:setText(tostring(rules or ""))
    if message and message ~= "" then
        local pl = getPlayer()
        if pl then pl:setHaloNote(message, 150, 250, 150, 300) end
    end
end

function JimsRulesAdmin.Panel:close()
    JimsRulesAdmin.ClosePanel()
end

function JimsRulesAdmin.Panel:new(x, y, width, height)
    local panel = ISCollapsableWindow.new(self, x, y, width, height)
    panel.title = "Server Rules Editor"
    panel.resizable = false
    return panel
end

function JimsRulesAdmin.sync(module, command, args)
    if module ~= JimsServerRules.MODULE then return end
    if command == JimsServerRules.COMMAND_ADMIN_DATA and JimsRulesAdmin.instance then
        JimsRulesAdmin.instance:setRules(args and args.rules, args and args.message)
    elseif command == JimsServerRules.COMMAND_ADMIN_ERROR and JimsRulesAdmin.instance and args and args.message then
        local pl = getPlayer()
        if pl then pl:setHaloNote(tostring(args.message), 255, 100, 100, 300) end
    end
end
Events.OnServerCommand.Remove(JimsRulesAdmin.sync)
Events.OnServerCommand.Add(JimsRulesAdmin.sync)
