require "ISUI/ISCollapsableWindow"
require "ISUI/ISTextEntryBox"
require "ISUI/ISButton"

JimsRulesAdmin = JimsRulesAdmin or {}
JimsRulesAdmin.Panel = ISCollapsableWindow:derive("JimsRulesAdminPanel")

-- UITextBox2's keyboard input stops at 2,000 characters independently of
-- setMaxTextLength. Keep editable pages smaller; never truncate the document.
local PAGE_CHARACTERS = 1600
local REQUEST_TIMEOUT_MS = 30000

local function splitRules(text)
    local pages = {}
    local first = 1
    while #text - first + 1 > PAGE_CHARACTERS do
        local last = first + PAGE_CHARACTERS - 1
        -- Kahlua strings use Java UTF-16 units; keep surrogate pairs together.
        local nextCharacter = string.byte(text, last + 1)
        if nextCharacter >= 0xDC00 and nextCharacter <= 0xDFFF then
            last = last - 1
        end
        local newline = nil
        for index = first, last do
            if string.byte(text, index) == 10 then newline = index end
        end
        if newline and newline >= first + PAGE_CHARACTERS / 2 then last = newline end
        pages[#pages + 1] = string.sub(text, first, last)
        first = last + 1
    end
    pages[#pages + 1] = string.sub(text, first)
    return pages
end

function JimsRulesAdmin.send(command, args)
    local pl = getPlayer()
    if not pl then return false end
    sendClientCommand(pl, JimsServerRules.MODULE, command, args or {})
    return true
end

function JimsRulesAdmin.requestRules()
    local panel = JimsRulesAdmin.instance
    if panel then panel:sendRequest(JimsServerRules.COMMAND_ADMIN_REQUEST) end
end

function JimsRulesAdmin.Panel:createChildren()
    ISCollapsableWindow.createChildren(self)
    local pad = 10
    local buttonHeight = 28
    local buttonY = self.height - buttonHeight - pad
    local pageY = self:titleBarHeight() + pad
    local editorY = pageY + buttonHeight + pad
    self.previousButton = ISButton:new(pad, pageY, 100, buttonHeight, "PREVIOUS", self, JimsRulesAdmin.Panel.onPrevious)
    self.previousButton:initialise()
    self:addChild(self.previousButton)
    self.nextButton = ISButton:new(120, pageY, 100, buttonHeight, "NEXT", self, JimsRulesAdmin.Panel.onNext)
    self.nextButton:initialise()
    self:addChild(self.nextButton)
    self.addPageButton = ISButton:new(230, pageY, 100, buttonHeight, "ADD PAGE", self, JimsRulesAdmin.Panel.onAddPage)
    self.addPageButton:initialise()
    self:addChild(self.addPageButton)

    self.editor = ISTextEntryBox:new("", pad, editorY, self.width - pad * 2, buttonY - editorY - 30)
    self.editor:initialise()
    self.editor:instantiate()
    self.editor:setMultipleLine(true)
    self.editor:setMaxLines(2000)
    self.editor:setSelectable(true)
    self.editor:setEditable(false)
    self.editor:addScrollBars()
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
    self.copyButton = ISButton:new(380, buttonY, 110, buttonHeight, "COPY ALL", self, JimsRulesAdmin.Panel.onCopyAll)
    self.copyButton:initialise()
    self:addChild(self.copyButton)
    self:setWaiting(false)
end

function JimsRulesAdmin.Panel:setWaiting(waiting)
    self.waitingForServer = waiting
    local ready = self.loaded and not waiting
    self.editor:setEditable(ready == true)
    self.saveButton:setEnable(ready == true and not self.needsReload)
    self.reloadButton:setEnable(not waiting)
    self.resetButton:setEnable(not waiting and not self.needsReload)
    self.previousButton:setEnable(ready and self.pageNumber > 1 or false)
    self.nextButton:setEnable(ready and self.pageNumber < #self.pages or false)
    self.addPageButton:setEnable(ready == true)
    self.copyButton:setEnable(self.loaded == true)
end

function JimsRulesAdmin.Panel:sendRequest(command, args)
    if self.waitingForServer then return end
    if self.needsReload and command ~= JimsServerRules.COMMAND_ADMIN_REQUEST then return end
    self.pendingCommand = command
    self.requestStarted = getTimestampMs()
    self:setWaiting(true)
    if not JimsRulesAdmin.send(command, args) then
        self.pendingCommand = nil
        self:setWaiting(false)
    end
end

function JimsRulesAdmin.Panel:storePage()
    -- Clipboard paste can exceed the native typing limit. Preserve every byte,
    -- and split that page on navigation/save so it remains editable afterwards.
    local parts = splitRules(self.editor:getInternalText())
    table.remove(self.pages, self.pageNumber)
    for index = #parts, 1, -1 do
        table.insert(self.pages, self.pageNumber, parts[index])
    end
    return #parts
end

function JimsRulesAdmin.Panel:showPage(number)
    self.pageNumber = math.max(1, math.min(number, #self.pages))
    self.editor:setText(self.pages[self.pageNumber])
    self.editor:setCursorPos(0)
    self.editor:setYScroll(0)
    self:setWaiting(false)
end

function JimsRulesAdmin.Panel:onPrevious()
    if not self.loaded or self.waitingForServer or self.pageNumber <= 1 then return end
    self:storePage()
    self:showPage(self.pageNumber - 1)
    self.editor:focus()
end

function JimsRulesAdmin.Panel:onNext()
    if not self.loaded or self.waitingForServer or self.pageNumber >= #self.pages then return end
    self:storePage()
    self:showPage(self.pageNumber + 1)
    self.editor:focus()
end

function JimsRulesAdmin.Panel:onAddPage()
    if not self.loaded or self.waitingForServer then return end
    local count = self:storePage()
    local nextPage = self.pageNumber + count
    table.insert(self.pages, nextPage, "")
    self:showPage(nextPage)
    self.editor:focus()
end

function JimsRulesAdmin.Panel:onSave()
    if not self.loaded or self.waitingForServer or self.needsReload then return end
    self:storePage()
    local rules = table.concat(self.pages)
    self:showPage(self.pageNumber)
    self:sendRequest(JimsServerRules.COMMAND_ADMIN_SAVE, { rules = rules })
end

function JimsRulesAdmin.Panel:onReload()
    JimsRulesAdmin.requestRules()
end

function JimsRulesAdmin.Panel:onReset()
    self:sendRequest(JimsServerRules.COMMAND_ADMIN_RESET)
end

function JimsRulesAdmin.Panel:onCopyAll()
    if not self.loaded then return end
    local pages = {}
    for index, page in ipairs(self.pages) do
        pages[index] = index == self.pageNumber and self.editor:getInternalText() or page
    end
    Clipboard.setClipboard(table.concat(pages))
end

function JimsRulesAdmin.Panel:setRules(rules, message)
    self.pendingCommand = nil
    self.needsReload = false
    self.pages = splitRules(tostring(rules or ""))
    self.loaded = true
    -- Server replies must not take keyboard focus from another window.
    self:showPage(1)
    if message and message ~= "" then
        local pl = getPlayer()
        if pl then pl:setHaloNote(message, 150, 250, 150, 300) end
    end
end

function JimsRulesAdmin.Panel:update()
    ISCollapsableWindow.update(self)
    if self.waitingForServer and getTimestampMs() - self.requestStarted >= REQUEST_TIMEOUT_MS then
        self.pendingCommand = nil
        self.needsReload = true
        self:setWaiting(false)
    end
end

function JimsRulesAdmin.Panel:prerender()
    ISCollapsableWindow.prerender(self)
    self:drawText("Page " .. self.pageNumber .. " of " .. #self.pages, 345, self:titleBarHeight() + 16, 1, 1, 1, 1, UIFont.Small)
    local status = "SAVE saves all pages. Page breaks do not add text."
    if self.waitingForServer then
        status = "Waiting for server..."
    elseif self.needsReload then
        status = "No reply. Edits kept; COPY ALL backs up your draft before RELOAD."
    elseif not self.loaded then
        status = "Load the server rules before editing."
    elseif self.editor.javaObject:isTextLimit() then
        status = "Page full - use ADD PAGE to continue. All text is kept."
    end
    self:drawText(status, 10, self.height - 60, 0.8, 0.8, 0.8, 1, UIFont.Small)
end

function JimsRulesAdmin.Panel:removeFromUIManager()
    -- The panel registry can remove us directly (including Close All Panels).
    if self.editor then self.editor:unfocus() end
    ISCollapsableWindow.removeFromUIManager(self)
end

function JimsRulesAdmin.Panel:close()
    JimsRulesAdmin.ClosePanel()
end

function JimsRulesAdmin.Panel:new(x, y, width, height)
    local panel = ISCollapsableWindow.new(self, x, y, width, height)
    panel.title = "Server Rules Editor"
    panel.resizable = false
    panel.pages = { "" }
    panel.pageNumber = 1
    panel.loaded = false
    panel.waitingForServer = false
    return panel
end

function JimsRulesAdmin.sync(module, command, args)
    if module ~= JimsServerRules.MODULE then return end
    local panel = JimsRulesAdmin.instance
    if not panel or not panel.waitingForServer then return end
    if command == JimsServerRules.COMMAND_ADMIN_DATA then
        local message = args and args.message
        local responseCommand = JimsServerRules.COMMAND_ADMIN_REQUEST
        if message == "Server rules saved." then responseCommand = JimsServerRules.COMMAND_ADMIN_SAVE end
        if message == "Default server rules restored." then responseCommand = JimsServerRules.COMMAND_ADMIN_RESET end
        if responseCommand ~= panel.pendingCommand then return end
        panel:setRules(args and args.rules, message)
    elseif command == JimsServerRules.COMMAND_ADMIN_ERROR and args and args.message then
        panel.pendingCommand = nil
        panel.needsReload = false
        panel:setWaiting(false)
        local pl = getPlayer()
        if pl then pl:setHaloNote(tostring(args.message), 255, 100, 100, 300) end
    end
end
Events.OnServerCommand.Remove(JimsRulesAdmin.sync)
Events.OnServerCommand.Add(JimsRulesAdmin.sync)
