require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
require "ISUI/ISLabel"
require "ParadiseDev_PlayerCleanup"

ParadiseDev = ParadiseDev or {}
ParadiseDev.PlayerCleanup = ParadiseDev.PlayerCleanup or {}

local cleanup = ParadiseDev.PlayerCleanup

cleanup.pendingUsers = false

cleanup.toggles = {
    protectAdmins = true,
    allowUnknownAge = true,
    safehouses = true,
    economy = true,
    records = true,
}

cleanup.columns = {
    { label = "SELECT", x = 8, width = 60 },
    { label = "USERNAME", x = 68, width = 170 },
    { label = "STATE", x = 238, width = 60 },
    { label = "LAST CONNECTION", x = 298, width = 150 },
    { label = "IDLE", x = 448, width = 70 },
    { label = "KNOWN SINCE", x = 518, width = 110 },
    { label = "AGE", x = 628, width = 70 },
    { label = "PLAYTIME", x = 698, width = 90 },
    { label = "RANK", x = 788, width = 60 },
    { label = "STEAM ID", x = 848, width = 160 },
}

cleanup.toggleNames = {
    protectAdmins = "Protect ranks",
    allowUnknownAge = "Unknown age OK",
    safehouses = "Safehouses",
    economy = "Economy",
    records = "Records",
}

cleanup.Panel = ISCollapsableWindow:derive("ParadiseDev.PlayerCleanup.Panel")

cleanup.listOffset = 126

function cleanup.canOpen()
    if not isClient or not isClient() then return false end
    return ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(getPlayer()) or false
end

function cleanup.getSize()
    return math.min(1080, getCore():getScreenWidth() - 40), math.min(720, getCore():getScreenHeight() - 40)
end

function cleanup.send(command, args)
    local pl = getPlayer()
    if not pl or not sendClientCommand then return end
    sendClientCommand(pl, cleanup.module, command, args or {})
end

function cleanup.requestState()
    cleanup.send("requestState")
end

function cleanup.requestUsers()
    if not requestUsers then return end
    cleanup.pendingUsers = true
    requestUsers()
end

function cleanup.readUsers()
    if not getUsers then return {} end
    local list = getUsers()
    if not list then return {} end
    local rows = {}
    for index = 0, list:size() - 1 do
        local user = list:get(index)
        if user and user.getUsername then
            local steamId = tostring(user.getSteamid and user:getSteamid() or "")
            if steamId == "0" then steamId = "" end
            rows[#rows + 1] = {
                username = cleanup.isValidName(user:getUsername()),
                steamId = steamId,
                lastConnection = tostring(user.getLastConnection and user:getLastConnection() or ""),
                online = user:isOnline() == true,
                position = (user:getRole() and user:getRole():getPosition()) or -999,
            }
        end
    end
    return rows
end

function cleanup.indexRoster(accounts)
    local bySteam, byName = {}, {}
    for _, entry in ipairs(accounts or {}) do
        if entry.steamId and entry.steamId ~= "" then bySteam[entry.steamId] = entry end
        byName[cleanup.lowerName(entry.username)] = entry
    end
    return bySteam, byName
end

function cleanup.getSenderPosition()
    local pl = getPlayer()
    if not pl or not pl.getRole then return -999 end
    local role = pl:getRole()
    if not role or not role.getPosition then return -999 end
    return tonumber(role:getPosition()) or -999
end

function cleanup.findRoster(panel, row)
    return panel.bySteam[row.steamId] or panel.byName[cleanup.lowerName(row.username)]
end

function cleanup.idleDays(panel, row)
    local last = cleanup.parseConnection(row.lastConnection)
    if not last or not panel.todayDays then return nil end
    return panel.todayDays - last
end

function cleanup.ageDays(panel, row)
    local firstSeen = row.roster and tonumber(row.roster.firstSeenMs) or 0
    if firstSeen <= 0 then return nil end
    return math.floor(((tonumber(panel.nowMs) or 0) - firstSeen) / cleanup.dayMs)
end

function cleanup.evaluate(panel, row)
    if not row.username then return false, "invalid username" end
    if row.online then return false, "online now" end
    if cleanup.toggles.protectAdmins and tonumber(row.position) and tonumber(row.position) > cleanup.getSenderPosition() then
        return false, "rank above yours"
    end
    local idle = cleanup.idleDays(panel, row)
    if not idle then return false, "no last connection" end
    if idle < panel.config.inactiveDays then
        return false, "idle " .. tostring(idle) .. "d under " .. tostring(panel.config.inactiveDays) .. "d"
    end
    local age = cleanup.ageDays(panel, row)
    if age then
        if age < panel.config.accountDays then
            return false, "account " .. tostring(age) .. "d under " .. tostring(panel.config.accountDays) .. "d"
        end
    elseif not cleanup.toggles.allowUnknownAge then
        return false, "account age unknown"
    end
    return true, ""
end

function cleanup.buildRows(panel)
    panel.rows = {}
    panel.matchCount = 0
    for _, row in ipairs(panel.users or {}) do
        row.roster = cleanup.findRoster(panel, row)
        row.eligible, row.reason = cleanup.evaluate(panel, row)
        if not row.eligible then row.selected = false end
        if row.eligible then panel.matchCount = panel.matchCount + 1 end
        panel.rows[#panel.rows + 1] = row
    end
    table.sort(panel.rows, function(left, right)
        if left.eligible ~= right.eligible then return left.eligible end
        return tostring(left.username or ""):upper() < tostring(right.username or ""):upper()
    end)
end

function cleanup.filterRows(panel)
    local search = tostring(panel.searchEntry:getText() or ""):lower()
    local filtered = {}
    for _, row in ipairs(panel.rows or {}) do
        local passScope = panel.showAll or row.eligible
        local passSearch = search == ""
            or tostring(row.username or ""):lower():find(search, 1, true) ~= nil
            or tostring(row.steamId or ""):lower():find(search, 1, true) ~= nil
        if passScope and passSearch then filtered[#filtered + 1] = row end
    end
    return filtered
end

function cleanup.populate(panel)
    panel.list:clear()
    for _, row in ipairs(cleanup.filterRows(panel)) do
        local mark = row.selected and "[x]" or (row.eligible and "[ ]" or " - ")
        panel.list:addItem(mark .. " " .. tostring(row.username or ""), row)
    end
    panel:updateStatus()
end

function cleanup.getSelCount(panel)
    local count = 0
    for _, row in ipairs(panel.rows or {}) do
        if row.eligible and row.selected then count = count + 1 end
    end
    return count
end

function cleanup.trimValue(value, width, font)
    if ParadiseZ and ParadiseZ.fitText then return ParadiseZ.fitText(value, width - 6, font) end
    return tostring(value)
end

function cleanup.drawRow(list, y, item)
    if y + list:getYScroll() + item.height < 0 or y + list:getYScroll() >= list.height then return y + item.height end
    local row = item.item
    if list.selected == item.index then list:drawSelection(0, y, list:getWidth(), item.height - 1) end
    if row.selected then list:drawRect(0, y, list:getWidth(), item.height - 1, 0.22, 0.42, 0.28, 0.55) end
    list:drawRectBorder(0, y, list:getWidth(), item.height, 0.3, 0.35, 0.4, 0.4)
    local alpha = row.eligible and 1.0 or 0.42
    local firstSeen = row.roster and tonumber(row.roster.firstSeenMs) or 0
    local idle = cleanup.idleDays(cleanup.instance, row)
    local age = cleanup.ageDays(cleanup.instance, row)
    local playtime = cleanup.instance and cleanup.instance.playtime[cleanup.lowerName(row.username)] or nil
    local values = {
        row.selected and "[x]" or (row.eligible and "[ ]" or " - "),
        tostring(row.username or ""),
        row.online and "ONLINE" or "offline",
        tostring(row.lastConnection or ""),
        idle and (tostring(idle) .. "d") or "-",
        firstSeen > 0 and cleanup.formatDate(firstSeen) or "unknown",
        age and (tostring(age) .. "d") or "-",
        playtime and cleanup.formatDuration(playtime) or "-",
        tostring(row.position or ""),
        tostring(row.steamId or ""),
    }
    for index, column in ipairs(cleanup.columns) do
        local r, g, b = 0.9, 0.9, 0.9
        if index == 3 and row.online then r, g, b = 0.45, 0.85, 0.45 end
        if not row.eligible then r, g, b = 0.55, 0.55, 0.58 end
        list:drawText(cleanup.trimValue(values[index], column.width, list.font), column.x, y + 4, r, g, b, alpha, list.font)
    end
    if not row.eligible and row.reason and row.reason ~= "" then
        local last = cleanup.columns[#cleanup.columns]
        list:drawText(tostring(row.reason), last.x + last.width + 6, y + 4, 0.85, 0.6, 0.45, 1, list.font)
    end
    return y + item.height
end

function cleanup.setStatus(message)
    local panel = cleanup.instance
    if not panel then return end
    panel.status = tostring(message or "")
    panel:updateStatus()
end

function cleanup.toggleLabel(button)
    return tostring(cleanup.toggleNames[button.internal] or button.internal) .. ": " .. (cleanup.toggles[button.internal] and "ON" or "OFF")
end

function cleanup.readThresholds(panel)
    local inactive = math.floor(tonumber(panel.inactiveEntry:getText()) or 0)
    local age = math.floor(tonumber(panel.accountEntry:getText()) or 0)
    if inactive < 1 or inactive > 3650 then return nil, nil, "Idle-days threshold must be 1-3650." end
    if age < 1 or age > 3650 then return nil, nil, "Account-age threshold must be 1-3650." end
    return inactive, age
end

function cleanup.saveThresholds(panel)
    local inactive, age, error = cleanup.readThresholds(panel)
    if not inactive then cleanup.setStatus(error) return end
    panel.config.inactiveDays = inactive
    panel.config.accountDays = age
    cleanup.send("setConfig", { inactiveDays = inactive, accountDays = age })
    cleanup.buildRows(panel)
    cleanup.populate(panel)
    cleanup.setStatus("Thresholds sent to server: idle " .. tostring(inactive) .. "d, account " .. tostring(age) .. "d.")
end

function cleanup.refresh(panel)
    cleanup.buildRows(panel)
    cleanup.populate(panel)
    cleanup.requestState()
    cleanup.requestUsers()
end

function cleanup.selectMatching(panel)
    local count = 0
    for _, row in ipairs(panel.rows or {}) do
        if row.eligible then row.selected = true; count = count + 1 end
    end
    cleanup.populate(panel)
    cleanup.setStatus("Selected " .. tostring(count) .. " deletable account(s).")
end

function cleanup.clearSelection(panel)
    for _, row in ipairs(panel.rows or {}) do row.selected = false end
    panel.confirmEntry:setText("")
    cleanup.populate(panel)
end

function cleanup.deleteSelected(panel)
    local targets = {}
    for _, row in ipairs(panel.rows or {}) do
        if row.eligible and row.selected then
            targets[#targets + 1] = {
                username = row.username,
                steamId = row.steamId,
                lastConnection = row.lastConnection,
            }
        end
    end
    if #targets == 0 then cleanup.setStatus("Nothing selected to delete.") return end
    if panel.confirmEntry:getText() ~= "DELETE" then
        cleanup.setStatus("Type DELETE to remove " .. tostring(#targets) .. " account(s).")
        return
    end
    cleanup.send("delete", {
        targets = targets,
        config = { inactiveDays = panel.config.inactiveDays, accountDays = panel.config.accountDays },
        purge = {
            economy = cleanup.toggles.economy,
            records = cleanup.toggles.records,
            safehouses = cleanup.toggles.safehouses,
        },
        opts = {
            ignoreAdminProtect = not cleanup.toggles.protectAdmins,
            allowUnknownAge = cleanup.toggles.allowUnknownAge,
        },
    })
    cleanup.setStatus("Delete request sent for " .. tostring(#targets) .. " account(s)...")
end

function cleanup.Panel:createEntry(x, y, width)
    local entry = ISTextEntryBox:new("", x, y, width, 24)
    entry:initialise()
    entry:instantiate()
    entry:setOnlyNumbers(true)
    self:addChild(entry)
    return entry
end

function cleanup.Panel:createChildren()
    ISCollapsableWindow.createChildren(self)
    local top = self:titleBarHeight() + 8
    self.refreshButton = ISButton:new(12, top, 96, 26, "REFRESH", self, cleanup.Panel.onButton)
    self.refreshButton.internal = "REFRESH"
    self.refreshButton:initialise()
    self:addChild(self.refreshButton)
    self.idleLabel = ISLabel:new(118, top + 4, 18, "IDLE DAYS", 0.8, 0.8, 0.8, 1, UIFont.Small, true)
    self.idleLabel:initialise()
    self:addChild(self.idleLabel)
    self.inactiveEntry = self:createEntry(196, top, 56)
    self.ageLabel = ISLabel:new(262, top + 4, 18, "AGE DAYS", 0.8, 0.8, 0.8, 1, UIFont.Small, true)
    self.ageLabel:initialise()
    self:addChild(self.ageLabel)
    self.accountEntry = self:createEntry(326, top, 56)
    self.saveButton = ISButton:new(390, top, 140, 26, "SAVE THRESHOLDS", self, cleanup.Panel.onButton)
    self.saveButton.internal = "SAVE"
    self.saveButton:initialise()
    self:addChild(self.saveButton)
    self.showAllButton = ISButton:new(538, top, 150, 26, "SHOW ALL: OFF", self, cleanup.Panel.onButton)
    self.showAllButton.internal = "SHOWALL"
    self.showAllButton:initialise()
    self:addChild(self.showAllButton)

    local toggleX = 12
    for _, name in ipairs({ "protectAdmins", "allowUnknownAge", "safehouses", "economy", "records" }) do
        local button = ISButton:new(toggleX, top + 34, 178, 24, "", self, cleanup.Panel.onButton)
        button.internal = name
        button:initialise()
        button:setTitle(cleanup.toggleLabel(button))
        self:addChild(button)
        toggleX = toggleX + 184
    end

    self.searchEntry = ISTextEntryBox:new("", 12, top + 66, 320, 24)
    self.searchEntry:initialise()
    self.searchEntry:instantiate()
    self:addChild(self.searchEntry)
    self.selectButton = ISButton:new(340, top + 66, 156, 24, "SELECT DELETABLE", self, cleanup.Panel.onButton)
    self.selectButton.internal = "SELECT"
    self.selectButton:initialise()
    self:addChild(self.selectButton)
    self.clearButton = ISButton:new(504, top + 66, 140, 24, "CLEAR SELECTION", self, cleanup.Panel.onButton)
    self.clearButton.internal = "CLEAR"
    self.clearButton:initialise()
    self:addChild(self.clearButton)

    local listY = self:titleBarHeight() + cleanup.listOffset
    self.list = ISScrollingListBox:new(12, listY, self.width - 24, self.height - listY - 96)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = 24
    self.list.doDrawItem = cleanup.drawRow
    self.list:setOnMouseDownFunction(self, cleanup.Panel.onRowClick)
    self:addChild(self.list)

    self.confirmEntry = ISTextEntryBox:new("", 12, self.height - 62, 120, 24)
    self.confirmEntry:initialise()
    self.confirmEntry:instantiate()
    self:addChild(self.confirmEntry)
    self.deleteButton = ISButton:new(140, self.height - 62, 190, 24, "DELETE SELECTED", self, cleanup.Panel.onButton)
    self.deleteButton.internal = "DELETE"
    self.deleteButton:initialise()
    self:addChild(self.deleteButton)
    self.statusLabel = ISLabel:new(340, self.height - 58, 18, "", 0.8, 0.85, 0.9, 1, UIFont.Small, true)
    self.statusLabel:initialise()
    self:addChild(self.statusLabel)
end

function cleanup.Panel:onButton(button)
    local panel = cleanup.instance
    if not panel then return end
    if button.internal == "REFRESH" then
        cleanup.refresh(panel)
    elseif button.internal == "SAVE" then
        cleanup.saveThresholds(panel)
    elseif button.internal == "SELECT" then
        cleanup.selectMatching(panel)
    elseif button.internal == "CLEAR" then
        cleanup.clearSelection(panel)
    elseif button.internal == "DELETE" then
        cleanup.deleteSelected(panel)
    elseif button.internal == "SHOWALL" then
        panel.showAll = not panel.showAll
        button:setTitle("SHOW ALL: " .. (panel.showAll and "ON" or "OFF"))
        cleanup.populate(panel)
    else
        cleanup.toggles[button.internal] = not cleanup.toggles[button.internal]
        button:setTitle(cleanup.toggleLabel(button))
        cleanup.refresh(panel)
    end
end

function cleanup.Panel:onRowClick(row)
    local panel = cleanup.instance
    if not panel or not row then return end
    if not row.eligible then
        cleanup.setStatus(tostring(row.username or "") .. " is not deletable: " .. tostring(row.reason or ""))
        return
    end
    row.selected = not row.selected
    cleanup.populate(panel)
end

function cleanup.Panel:updateStatus()
    local summary = "Accounts " .. tostring(self.totalCount or 0) .. " | deletable " .. tostring(self.matchCount or 0)
        .. " | selected " .. tostring(cleanup.getSelCount(self))
        .. " | session " .. tostring((self.session and self.session.deletes) or 0) .. "/" .. tostring((self.session and self.session.max) or cleanup.maxSessionDeletes)
    if tostring(self.world or "") ~= "" then summary = summary .. " | world " .. tostring(self.world) end
    if tostring(self.status or "") ~= "" then summary = summary .. "  " .. tostring(self.status) end
    self.statusLabel:setName(summary)
end

function cleanup.Panel:prerender()
    ISCollapsableWindow.prerender(self)
    local listY = self:titleBarHeight() + cleanup.listOffset
    for _, column in ipairs(cleanup.columns) do
        self:drawText(column.label, 12 + column.x, listY - 18, 0.5, 0.75, 0.95, 1, UIFont.Small)
    end
end

function cleanup.Panel:close()
    cleanup.ClosePanel()
end

function cleanup.Panel:new(x, y, width, height)
    local panel = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(panel, self)
    self.__index = self
    panel.title = "Paradise Player Cleanup"
    panel.resizable = false
    panel.users = {}
    panel.rows = {}
    panel.config = { inactiveDays = cleanup.defaultInactiveDays, accountDays = cleanup.defaultAccountDays }
    panel.nowMs = 0
    panel.todayDays = 0
    panel.bySteam = {}
    panel.byName = {}
    panel.playtime = {}
    panel.session = { deletes = 0, max = cleanup.maxSessionDeletes }
    panel.matchCount = 0
    panel.totalCount = 0
    panel.showAll = false
    panel.status = ""
    return panel
end

function cleanup.applyState(args)
    local panel = cleanup.instance
    if not panel or not args then return end
    panel.nowMs = tonumber(args.nowMs) or 0
    panel.todayDays = tonumber(args.todayDays) or 0
    panel.world = tostring(args.world or "")
    if args.config then
        panel.config.inactiveDays = cleanup.normalizeDays(args.config.inactiveDays, panel.config.inactiveDays)
        panel.config.accountDays = cleanup.normalizeDays(args.config.accountDays, panel.config.accountDays)
    end
    panel.bySteam, panel.byName = cleanup.indexRoster(args.accounts)
    panel.playtime = {}
    for _, entry in ipairs(args.playtime or {}) do
        panel.playtime[cleanup.lowerName(entry.username)] = tonumber(entry.seconds) or 0
    end
    if args.session then panel.session = args.session end
    panel.inactiveEntry:setText(tostring(panel.config.inactiveDays))
    panel.accountEntry:setText(tostring(panel.config.accountDays))
    cleanup.buildRows(panel)
    cleanup.populate(panel)
end

function cleanup.applyResults(args)
    local panel = cleanup.instance
    if not panel or not args then return end
    local deleted, skipped, partial = 0, 0, 0
    local notes = {}
    for _, result in ipairs(args.results or {}) do
        if result.status == "deleted" then deleted = deleted + 1
        elseif result.status == "partial" then partial = partial + 1
        else skipped = skipped + 1 end
        if result.status ~= "deleted" and #notes < 4 then
            notes[#notes + 1] = tostring(result.username or "") .. ": " .. tostring(result.reason or "")
        end
    end
    if args.session then panel.session = args.session end
    local message = "Deleted " .. tostring(deleted) .. ", skipped " .. tostring(skipped)
    if partial > 0 then message = message .. ", still present " .. tostring(partial) end
    if #notes > 0 then message = message .. " (" .. table.concat(notes, "; ") .. ")" end
    panel.confirmEntry:setText("")
    cleanup.setStatus(message)
end

function cleanup.onNetworkUsersReceived()
    local panel = cleanup.instance
    if not panel or not cleanup.pendingUsers then return end
    cleanup.pendingUsers = false
    panel.users = cleanup.readUsers()
    panel.totalCount = #(panel.users or {})
    cleanup.buildRows(panel)
    cleanup.populate(panel)
end
Events.OnNetworkUsersReceived.Remove(cleanup.onNetworkUsersReceived)
Events.OnNetworkUsersReceived.Add(cleanup.onNetworkUsersReceived)

function cleanup.onServerCommand(module, command, args)
    if module ~= cleanup.module then return end
    if command == "state" then cleanup.applyState(args); return end
    if command == "results" then cleanup.applyResults(args); cleanup.requestUsers(); return end
end
Events.OnServerCommand.Remove(cleanup.onServerCommand)
Events.OnServerCommand.Add(cleanup.onServerCommand)

function cleanup.open(panel)
    if not panel then return end
    cleanup.refresh(panel)
end
