require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISTextEntryBox"
require "ISUI/ISButton"

ParadiseLimboRecords = ParadiseLimboRecords or {}
ParadiseLimboRecords.module = "ParadiseLimboRecords"
ParadiseLimboRecords.Panel = ISCollapsableWindow:derive("ParadiseLimboRecordsPanel")

function ParadiseLimboRecords.send(command, args)
    local pl = getPlayer()
    if not pl then return end
    sendClientCommand(pl, ParadiseLimboRecords.module, command, args or {})
end

function ParadiseLimboRecords.requestDates()
    local panel = ParadiseLimboRecords.instance
    if not panel then return end
    ParadiseLimboRecords.send("requestDates", {
        year = panel.yearEntry:getText(),
        month = panel.monthEntry:getText(),
        day = panel.dayEntry:getText(),
    })
end

function ParadiseLimboRecords.Panel:createFilterEntry(text, x, width)
    local entry = ISTextEntryBox:new(text, x, self:titleBarHeight() + 27, width, 24)
    entry:initialise()
    entry:instantiate()
    entry:setOnlyNumbers(true)
    self:addChild(entry)
    return entry
end

function ParadiseLimboRecords.Panel:createChildren()
    ISCollapsableWindow.createChildren(self)
    local top = self:titleBarHeight() + 8
    self.yearEntry = self:createFilterEntry("", 12, 72)
    self.monthEntry = self:createFilterEntry("", 92, 52)
    self.dayEntry = self:createFilterEntry("", 152, 52)
    self.refreshButton = ISButton:new(212, top + 19, 90, 24, "REFRESH", self, ParadiseLimboRecords.Panel.onRefresh)
    self.refreshButton:initialise()
    self:addChild(self.refreshButton)

    self.dateList = ISScrollingListBox:new(12, top + 51, 200, self.height - top - 63)
    self.dateList:initialise()
    self.dateList:instantiate()
    self.dateList.itemheight = 24
    self.dateList.target = self
    self.dateList.onmousedown = ParadiseLimboRecords.Panel.onDateSelected
    self:addChild(self.dateList)

    self.logText = ISTextEntryBox:new("Select a date to read its limbo log.", 220, top + 51, self.width - 232, self.height - top - 63)
    self.logText:initialise()
    self.logText:instantiate()
    self.logText:setMultipleLine(true)
    self.logText:setEditable(false)
    self.logText:setMaxLines(100000)
    self:addChild(self.logText)
end

function ParadiseLimboRecords.Panel:onRefresh()
    ParadiseLimboRecords.requestDates()
end

function ParadiseLimboRecords.Panel:onDateSelected(item)
    if not item then return end
    ParadiseLimboRecords.send("requestLog", { date = item })
end

function ParadiseLimboRecords.Panel:setDates(dates)
    self.dateList:clear()
    for _, date in ipairs(dates or {}) do self.dateList:addItem(date, date) end
    if #self.dateList.items == 0 then self.logText:setText("No matching limbo logs.") end
end

function ParadiseLimboRecords.Panel:setLog(date, text)
    self.logText:setText(tostring(text or ""))
    self.title = "Paradise Limbo Records - " .. tostring(date or "")
end

function ParadiseLimboRecords.Panel:prerender()
    ISCollapsableWindow.prerender(self)
    local top = self:titleBarHeight() + 8
    self:drawText("YEAR", 12, top, 0.8, 0.8, 0.8, 1, UIFont.Small)
    self:drawText("MONTH", 92, top, 0.8, 0.8, 0.8, 1, UIFont.Small)
    self:drawText("DAY", 152, top, 0.8, 0.8, 0.8, 1, UIFont.Small)
end

function ParadiseLimboRecords.Panel:close()
    ParadiseLimboRecords.ClosePanel()
end

function ParadiseLimboRecords.Panel:new(x, y, width, height)
    local panel = ISCollapsableWindow.new(self, x, y, width, height)
    panel.title = "Paradise Limbo Records"
    panel.resizable = false
    return panel
end

function ParadiseLimboRecords.sync(module, command, args)
    if module ~= ParadiseLimboRecords.module then return end
    local panel = ParadiseLimboRecords.instance
    if not panel then return end
    if command == "dates" then
        panel:setDates(args and args.dates)
    elseif command == "log" then
        panel:setLog(args and args.date, args and args.text)
    elseif command == "error" then
        panel.logText:setText(tostring(args and args.message or "Unable to read limbo records."))
    end
end
Events.OnServerCommand.Remove(ParadiseLimboRecords.sync)
Events.OnServerCommand.Add(ParadiseLimboRecords.sync)
