require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISTextEntryBox"
require "ISUI/ISButton"

RecordsPanel = RecordsPanel or {}
RecordsPanel.module = "RecordsPanel"
RecordsPanel.loggerOrder = { "LimboTracker", "SoulCatcher" }
RecordsPanel.loggers = {
    LimboTracker = {
        title = "Limbo Tracker",
        columns = {
            { key = "time", label = "Time", width = 76 },
            { key = "key", label = "Steam ID / Key", width = 150 },
            { key = "username", label = "Username", width = 115 },
            { key = "firstname", label = "First Name", width = 95 },
            { key = "surname", label = "Surname", width = 95 },
            { key = "profKey", label = "Profession", width = 110 },
            { key = "fps", label = "FPS", width = 48 },
            { key = "ping", label = "Ping", width = 48 },
            { key = "exitMode", label = "Mode", width = 52 },
            { key = "exitLabel", label = "Exit Label", width = 190 },
        },
    },
    SoulCatcher = {
        title = "Soul Catcher",
        columns = {
            { key = "time", label = "Time", width = 65 },
            { key = "key", label = "Steam ID / Key", width = 120 },
            { key = "username", label = "Username", width = 90 },
            { key = "firstname", label = "First Name", width = 75 },
            { key = "surname", label = "Surname", width = 75 },
            { key = "profKey", label = "Profession", width = 90 },
            { key = "reportMsg", label = "Spawn Type", width = 135 },
            { key = "reincarnatedTimes", label = "Reincarnations", width = 75 },
            { key = "lifeHours", label = "Last Life", width = 70, hours = true },
            { key = "totalHours", label = "Total Time", width = 75, hours = true },
            { key = "x", label = "X", width = 55 },
            { key = "y", label = "Y", width = 55 },
            { key = "z", label = "Z", width = 35 },
        },
    },
}
RecordsPanel.Panel = ISCollapsableWindow:derive("RecordsPanelWindow")

function RecordsPanel.send(command, args)
    local pl = getPlayer()
    if not pl then return end
    sendClientCommand(pl, RecordsPanel.module, command, args or {})
end

function RecordsPanel.getFilterArgs(panel)
    return {
        loggerTag = panel.loggerTag,
        year = panel.yearEntry:getText(),
        month = panel.monthEntry:getText(),
        day = panel.dayEntry:getText(),
    }
end

function RecordsPanel.requestDates()
    local panel = RecordsPanel.instance
    if not panel then return end
    RecordsPanel.send("requestDates", RecordsPanel.getFilterArgs(panel))
end

function RecordsPanel.requestRecords(date)
    local panel = RecordsPanel.instance
    if not panel or not date then return end
    RecordsPanel.send("requestRecords", {
        loggerTag = panel.loggerTag,
        date = date,
        search = panel.searchEntry:getText(),
    })
end

function RecordsPanel.formatHours(hours)
    hours = math.max(0, tonumber(hours) or 0)
    local days = math.floor(hours / 24)
    local hrs = math.floor(hours % 24)
    return tostring(days) .. "d " .. tostring(hrs) .. "h"
end

function RecordsPanel.trimText(value, width, font)
    local str = tostring(value or "")
    local textManager = getTextManager()
    if textManager:MeasureStringX(font, str) <= width then return str end
    while #str > 1 and textManager:MeasureStringX(font, str .. "...") > width do
        str = str:sub(1, #str - 1)
    end
    return str .. "..."
end

function RecordsPanel.drawDateItem(list, y, item)
    if y + list:getYScroll() + item.height < 0 or y + list:getYScroll() >= list.height then return y + item.height end
    if list.selected == item.index then list:drawSelection(0, y, list:getWidth(), item.height - 1) end
    list:drawRectBorder(0, y, list:getWidth(), item.height, 0.4, 0.4, 0.4, 0.4)
    list:drawText(tostring(item.item.date), 8, y + 4, 1, 1, 1, 1, list.font)
    list:drawTextRight(tostring(item.item.count or 0), list:getWidth() - 10, y + 4, 0.7, 0.8, 0.9, 1, list.font)
    return y + item.height
end

function RecordsPanel.drawRecordItem(list, y, item)
    if y + list:getYScroll() + item.height < 0 or y + list:getYScroll() >= list.height then return y + item.height end
    if list.selected == item.index then list:drawSelection(0, y, list:getWidth(), item.height - 1) end
    list:drawRectBorder(0, y, list:getWidth(), item.height, 0.3, 0.35, 0.4, 0.4)
    local row = item.item
    local logger = RecordsPanel.loggers[list.parent.loggerTag]
    for index, column in ipairs(logger.columns) do
        local value = column.hours and RecordsPanel.formatHours(row[column.key]) or tostring(row[column.key] or "")
        local x = list.columns[index].size + 5
        list:drawText(RecordsPanel.trimText(value, column.width - 10, list.font), x, y + 4, 0.9, 0.9, 0.9, 1, list.font)
    end
    return y + item.height
end

function RecordsPanel.Panel:createFilterEntry(x, width)
    local entry = ISTextEntryBox:new("", x, self:titleBarHeight() + 75, width, 24)
    entry:initialise()
    entry:instantiate()
    entry:setOnlyNumbers(true)
    self:addChild(entry)
    return entry
end

function RecordsPanel.Panel:createChildren()
    ISCollapsableWindow.createChildren(self)
    local top = self:titleBarHeight() + 8
    self.limboButton = ISButton:new(12, top, 140, 28, "Limbo Tracker", self, RecordsPanel.Panel.onLoggerButton)
    self.limboButton.internal = "LimboTracker"
    self.limboButton:initialise()
    self:addChild(self.limboButton)
    self.soulButton = ISButton:new(160, top, 140, 28, "Soul Catcher", self, RecordsPanel.Panel.onLoggerButton)
    self.soulButton.internal = "SoulCatcher"
    self.soulButton:initialise()
    self:addChild(self.soulButton)
    self.yearEntry = self:createFilterEntry(12, 72)
    self.monthEntry = self:createFilterEntry(92, 52)
    self.dayEntry = self:createFilterEntry(152, 52)
    self.searchEntry = ISTextEntryBox:new("", 212, top + 48, self.width - 442, 24)
    self.searchEntry:initialise()
    self.searchEntry:instantiate()
    self:addChild(self.searchEntry)
    self.refreshButton = ISButton:new(self.width - 222, top + 48, 100, 24, "REFRESH", self, RecordsPanel.Panel.onRefresh)
    self.refreshButton:initialise()
    self:addChild(self.refreshButton)
    self.clearButton = ISButton:new(self.width - 114, top + 48, 100, 24, "CLEAR", self, RecordsPanel.Panel.onClear)
    self.clearButton:initialise()
    self:addChild(self.clearButton)
    local listY = top + 84
    self.dateList = ISScrollingListBox:new(12, listY, 190, self.height - listY - 36)
    self.dateList:initialise()
    self.dateList:instantiate()
    self.dateList.itemheight = 24
    self.dateList.doDrawItem = RecordsPanel.drawDateItem
    self.dateList:setOnMouseDownFunction(self, RecordsPanel.Panel.onDateSelected)
    self:addChild(self.dateList)
    self.recordList = ISScrollingListBox:new(210, listY, self.width - 222, self.height - listY - 36)
    self.recordList:initialise()
    self.recordList:instantiate()
    self.recordList.itemheight = 24
    self.recordList.parent = self
    self.recordList.doDrawItem = RecordsPanel.drawRecordItem
    self:addChild(self.recordList)
    self.loggerTag = "LimboTracker"
    self.selectedDate = nil
    self.recordCount = 0
    self:setLoggerColumns()
    self:updateTabButtons()
    self:updateTitle()
end

function RecordsPanel.Panel:setLoggerColumns()
    self.recordList.columns = {}
    local x = 0
    for _, column in ipairs(RecordsPanel.loggers[self.loggerTag].columns) do
        self.recordList:addColumn(column.label, x)
        x = x + column.width
    end
end

function RecordsPanel.Panel:updateTitle()
    self.title = "Paradise Records - " .. RecordsPanel.loggers[self.loggerTag].title
    if self.selectedDate then self.title = self.title .. " - " .. self.selectedDate end
end

function RecordsPanel.Panel:updateTabButtons()
    local active = { r = 0.20, g = 0.42, b = 0.58, a = 1 }
    local inactive = { r = 0.10, g = 0.10, b = 0.10, a = 1 }
    self.limboButton.backgroundColor = self.loggerTag == "LimboTracker" and active or inactive
    self.soulButton.backgroundColor = self.loggerTag == "SoulCatcher" and active or inactive
end

function RecordsPanel.Panel:onLoggerButton(button)
    RecordsPanel.setLogger(button.internal)
end

function RecordsPanel.setLogger(loggerTag)
    local panel = RecordsPanel.instance
    if not panel or not RecordsPanel.loggers[loggerTag] then return false end
    panel.loggerTag = loggerTag
    panel.selectedDate = nil
    panel.recordCount = 0
    panel.dateList:clear()
    panel.recordList:clear()
    panel:setLoggerColumns()
    panel:updateTabButtons()
    panel:updateTitle()
    RecordsPanel.requestDates()
    return true
end

function RecordsPanel.Panel:onDateSelected(dateRecord)
    if not dateRecord or not dateRecord.date then return end
    self.selectedDate = dateRecord.date
    self:updateTitle()
    RecordsPanel.requestRecords(self.selectedDate)
end

function RecordsPanel.Panel:onRefresh()
    RecordsPanel.requestDates()
    if self.selectedDate then RecordsPanel.requestRecords(self.selectedDate) end
end

function RecordsPanel.Panel:onClear()
    self.yearEntry:setText("")
    self.monthEntry:setText("")
    self.dayEntry:setText("")
    self.searchEntry:setText("")
    self.selectedDate = nil
    self.recordList:clear()
    self:updateTitle()
    RecordsPanel.requestDates()
end

function RecordsPanel.Panel:setDates(loggerTag, dates)
    if loggerTag ~= self.loggerTag then return end
    self.dateList:clear()
    for _, dateRecord in ipairs(dates or {}) do
        self.dateList:addItem(dateRecord.date, dateRecord)
    end
end

function RecordsPanel.Panel:setRecords(loggerTag, date, rows)
    if loggerTag ~= self.loggerTag or date ~= self.selectedDate then return end
    self.recordList:clear()
    for _, row in ipairs(rows or {}) do self.recordList:addItem("", row) end
    self.recordCount = #(rows or {})
end

function RecordsPanel.Panel:prerender()
    ISCollapsableWindow.prerender(self)
    local top = self:titleBarHeight() + 56
    self:drawText("YEAR", 12, top, 0.8, 0.8, 0.8, 1, UIFont.Small)
    self:drawText("MONTH", 92, top, 0.8, 0.8, 0.8, 1, UIFont.Small)
    self:drawText("DAY", 152, top, 0.8, 0.8, 0.8, 1, UIFont.Small)
    self:drawText("FIND PLAYER / VALUE", 212, top, 0.8, 0.8, 0.8, 1, UIFont.Small)
    self:drawText("AVAILABLE DATES", 12, top + 55, 0.5, 0.75, 0.95, 1, UIFont.Small)
    self:drawText(tostring(self.recordCount) .. " records - " .. self.loggerTag .. " - newest first", 210, self.height - 28, 0.65, 0.7, 0.75, 1, UIFont.Small)
end

function RecordsPanel.Panel:close()
    RecordsPanel.ClosePanel()
end

function RecordsPanel.Panel:new(x, y, width, height)
    local panel = ISCollapsableWindow.new(self, x, y, width, height)
    panel.title = "Paradise Records"
    panel.resizable = false
    return panel
end

function RecordsPanel.sync(module, command, args)
    if module ~= RecordsPanel.module then return end
    local panel = RecordsPanel.instance
    if not panel then return end
    if command == "dates" then
        panel:setDates(args and args.loggerTag, args and args.dates)
    elseif command == "records" then
        panel:setRecords(args and args.loggerTag, args and args.date, args and args.rows)
    elseif command == "error" then
        panel.recordList:clear()
        panel.recordCount = 0
        panel.recordList:addItem("", { time = tostring(args and args.message or "Unable to read records.") })
    end
end
Events.OnServerCommand.Remove(RecordsPanel.sync)
Events.OnServerCommand.Add(RecordsPanel.sync)
