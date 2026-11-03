ParadiseRestore = ParadiseRestore or {}
ParadiseMail = ParadiseMail or {}

ParadiseMail.module = "ParadiseMail"
ParadiseMail.storeName = "ParadiseMail"
ParadiseMail.boxStoreName = "ParadiseMail_Boxes"
ParadiseMail.maxRows = 200
ParadiseMail.maxQty = 99
ParadiseMail.maxRecipients = 300
ParadiseMail.maxTitleLength = 48
ParadiseMail.maxTemplateName = 40

function ParadiseMail.userKey(user)
    user = tostring(user or ""):match("^%s*(.-)%s*$")
    if user == "" or #user > 64 then return nil end
    return string.lower(user)
end

function ParadiseMail.normalizeTitle(title)
    title = tostring(title or ""):gsub("[%c]", ""):match("^%s*(.-)%s*$")
    if title == "" then return nil end
    if #title > ParadiseMail.maxTitleLength then title = title:sub(1, ParadiseMail.maxTitleLength) end
    return title
end

function ParadiseMail.normalizeTemplateName(name)
    name = tostring(name or ""):gsub("[%c%[%]\"']", ""):match("^%s*(.-)%s*$")
    if name == "" then return nil end
    if #name > ParadiseMail.maxTemplateName then return nil end
    return name
end

function ParadiseMail.trimAmount(amount)
    amount = tostring(amount or ""):match("^%s*(.-)%s*$")
    if not amount:match("^%d+$") then return nil end
    return tonumber(amount)
end

function ParadiseMail.itemLabel(data)
    if type(data) ~= "table" or not data.fullType then return "?" end
    local label = (data.name and data.name ~= "") and data.name or tostring(data.fullType)
    if data.containedItems and #data.containedItems > 0 then
        label = label .. " [" .. tostring(#data.containedItems) .. "]"
    end
    return label
end

function ParadiseMail.describeSet(set)
    if type(set) ~= "table" then return "empty" end
    local parts = {}
    local money = set.money or {}
    local jimoleon = tonumber(money.jimoleon) or 0
    local paradisium = tonumber(money.paradisium) or 0
    if #set.items > 0 then parts[#parts + 1] = tostring(#set.items) .. " lines" end
    if jimoleon > 0 then parts[#parts + 1] = tostring(jimoleon) .. " jim" end
    if paradisium > 0 then parts[#parts + 1] = tostring(paradisium) .. " para" end
    if #parts == 0 then return "empty" end
    return table.concat(parts, ", ")
end

function ParadiseMail.validateSet(set)
    if type(set) ~= "table" then return false, "No item set" end
    local items = set.items
    if type(items) ~= "table" then return false, "No item set" end
    if #items > ParadiseMail.maxRows then return false, "Too many lines in the set" end
    local copies = 0
    for _, entry in ipairs(items) do
        if type(entry) ~= "table" or type(entry.data) ~= "table" or not entry.data.fullType then
            return false, "Invalid item line"
        end
        local qty = math.floor(tonumber(entry.qty) or 0)
        if qty < 1 or qty > ParadiseMail.maxQty then return false, "Quantity must be between 1 and " .. ParadiseMail.maxQty end
        copies = copies + qty
    end
    if copies > ParadiseMail.maxRows * ParadiseMail.maxQty then return false, "Set is too large" end
    local money = set.money
    if type(money) == "table" then
        local jimoleon = tonumber(money.jimoleon) or 0
        local paradisium = tonumber(money.paradisium) or 0
        if jimoleon < 0 or paradisium < 0 or jimoleon > ParadiseEconomy.maxBalance or paradisium > ParadiseEconomy.maxBalance then
            return false, "Invalid money amount"
        end
    end
    if #items == 0 and (type(money) ~= "table" or ((tonumber(money.jimoleon) or 0) + (tonumber(money.paradisium) or 0)) == 0) then
        return false, "Set has no items or money"
    end
    return true
end

-- client only below

ParadiseMail.working = nil
ParadiseMail.workingMoney = nil
ParadiseMail.adminData = nil
ParadiseMail.mailData = nil
ParadiseMail.pendingCount = 0
ParadiseMail.AdminPanel = ParadiseMail.AdminPanel or {}
ParadiseMail.PlayerPanel = ParadiseMail.PlayerPanel or {}

function ParadiseMail.resetWorking()
    ParadiseMail.working = {}
    ParadiseMail.workingMoney = { jimoleon = 0, paradisium = 0 }
end
ParadiseMail.resetWorking()

function ParadiseMail.addCapturedData(data)
    if not data then return false end
    if #ParadiseMail.working >= ParadiseMail.maxRows then return false end
    ParadiseMail.working[#ParadiseMail.working + 1] = { data = data, qty = 1 }
    return true
end

function ParadiseMail.captureInventory()
    local pl = getPlayer()
    if not pl or not ParadiseEconomy or not ParadiseEconomy.ItemData then return 0 end
    local added = 0
    local inv = pl:getInventory()
    local list = inv:getItems()
    for i = 0, list:size() - 1 do
        local data = ParadiseEconomy.ItemData.toData(list:get(i))
        if data and ParadiseMail.addCapturedData(data) then added = added + 1 end
    end
    return added
end

function ParadiseMail.captureFromInventoryContext(items)
    local added = 0
    for _, entry in ipairs(items or {}) do
        local item = entry.items and entry.items[1] or entry
        if instanceof(item, "InventoryItem") and ParadiseEconomy and ParadiseEconomy.ItemData then
            local data = ParadiseEconomy.ItemData.toData(item)
            if data and ParadiseMail.addCapturedData(data) then added = added + 1 end
        end
    end
    return added
end

function ParadiseMail.buildSet()
    return { items = ParadiseMail.working, money = ParadiseMail.workingMoney }
end

function ParadiseMail.send(command, args)
    local pl = getPlayer()
    if not pl then return false end
    sendClientCommand(pl, ParadiseMail.module, command, args or {})
    return true
end

function ParadiseMail.halo(text, bad)
    local pl = getPlayer()
    if not pl then return end
    if bad then
        pl:setHaloNote(tostring(text), 250, 60, 60, 900)
    else
        pl:setHaloNote(tostring(text), 150, 250, 150, 900)
    end
end

function ParadiseMail.notifyPending(count)
    if not getPlayer() then
        ParadiseMail.pendingNotify = count
        return
    end
    ParadiseMail.pendingNotify = nil
    if count and count > 0 then
        ParadiseMail.halo("New mail: " .. tostring(count) .. " (type /mail)")
    else
        ParadiseMail.halo("Package delivered")
    end
end

function ParadiseMail.flushPendingNotify()
    if not ParadiseMail.pendingNotify then return end
    local count = ParadiseMail.pendingNotify
    ParadiseMail.pendingNotify = nil
    ParadiseMail.notifyPending(count)
    ParadiseMail.send("requestMailbox")
end

function ParadiseMail.installAlertIcon(button)
    if not button or button._paradiseMailAlert then return end
    button._paradiseMailAlert = true
    local base = button.prerender
    button.prerender = function(self)
        base(self)
        local count = ParadiseMail.pendingCount or 0
        if count <= 0 then return end
        local t = (getTimestampMs and getTimestampMs() or 0) / 1000
        local pulse = 0.5 + 0.5 * math.sin(t * 4.5)
        local bw, bh = 36, 15
        local bx = self.width - bw - 4
        local by = 3
        self:drawRect(bx, by, bw, bh, 0.75 + 0.25 * pulse, 0.85, 0.15 + 0.25 * pulse, 0.1)
        self:drawRectBorder(bx, by, bw, bh, 0.9, 0.1, 0.1, 0.1)
        self:drawTextCentre("!" .. tostring(count), bx + bw / 2, by + 2, 1, 1, 1, 0.85 + 0.15 * pulse, UIFont.Small)
    end
end

function ParadiseMail.onServerCommand(module, command, args)
    if module ~= ParadiseMail.module or type(args) ~= "table" then return end

    if command == "adminState" then
        ParadiseMail.adminData = args
        local panel = ParadiseMail.adminInstance
        if panel and panel.refreshFromData then panel:refreshFromData() end

    elseif command == "mailbox" then
        ParadiseMail.mailData = args.messages or {}
        ParadiseMail.pendingCount = #ParadiseMail.mailData
        local panel = ParadiseMail.playerInstance
        if panel and panel.refreshFromData then panel:refreshFromData() end

    elseif command == "notify" then
        ParadiseMail.pendingCount = tonumber(args.count) or 0
        ParadiseMail.notifyPending(ParadiseMail.pendingCount)
        ParadiseMail.send("requestMailbox")
        local panel = ParadiseMail.playerInstance
        if panel and panel.refreshFromData then panel:refreshFromData() end

    elseif command == "sendResult" or command == "saved" or command == "deleted" then
        local message = tostring(args.message or "Done")
        local pl = getPlayer()
        if pl then pl:setHaloNote(message, args.ok == false and 250 or 150, args.ok == false and 60 or 250, args.ok == false and 60 or 150, 900) end
        local panel = ParadiseMail.adminInstance
        if panel and panel.setStatus then panel:setStatus(message) end
        if panel then ParadiseMail.send("requestAdminState") end

    elseif command == "claimResult" then
        local ok = args.ok == true
        local message = tostring(args.message or "")
        local panel = ParadiseMail.playerInstance
        if panel and panel.setStatus then panel:setStatus(message, ok) end
        ParadiseMail.halo(message, not ok)
    end
end
Events.OnServerCommand.Remove(ParadiseMail.onServerCommand)
Events.OnServerCommand.Add(ParadiseMail.onServerCommand)

if isClient and isClient() then
    function ParadiseMail.onClientCreatePlayer()
        ParadiseMail.flushPendingNotify()
    end
    Events.OnCreatePlayer.Remove(ParadiseMail.onClientCreatePlayer)
    Events.OnCreatePlayer.Add(ParadiseMail.onClientCreatePlayer)
end
