if isClient and isClient() then return end
ParadiseRestore = ParadiseRestore or {}
ParadiseMail = ParadiseMail or {}

local function copyDeep(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, child in pairs(value) do copy[copyDeep(key)] = copyDeep(child) end
    return copy
end

function ParadiseMail.getStore()
    local store = ModData.getOrCreate(ParadiseMail.storeName)
    store.templates = store.templates or {}
    store.nextMailId = tonumber(store.nextMailId) or 1
    return store
end

function ParadiseMail.getBoxes()
    local data = ModData.getOrCreate(ParadiseMail.boxStoreName)
    data.boxes = data.boxes or {}
    return data.boxes
end

function ParadiseMail.getBox(user)
    local key = ParadiseMail.userKey(user)
    if not key then return nil end
    local boxes = ParadiseMail.getBoxes()
    boxes[key] = boxes[key] or {}
    return boxes[key]
end

function ParadiseMail.transmitAll()
    if ModData.transmit then
        ModData.transmit(ParadiseMail.storeName)
        ModData.transmit(ParadiseMail.boxStoreName)
    end
end

function ParadiseMail.describeMsg(msg)
    local copies = 0
    for _, entry in ipairs(msg.items or {}) do copies = copies + (tonumber(entry.qty) or 0) end
    local money = msg.money or {}
    return {
        id = msg.id,
        title = msg.title,
        from = msg.from,
        sentAt = msg.sentAt,
        lines = #(msg.items or {}),
        copies = copies,
        jimoleon = tonumber(money.jimoleon) or 0,
        paradisium = tonumber(money.paradisium) or 0,
    }
end

local function findOnline(user)
    local key = ParadiseMail.userKey(user)
    if not key then return nil end
    local online = getOnlinePlayers()
    for i = 0, online:size() - 1 do
        local pl = online:get(i)
        if pl and pl.getUsername and ParadiseMail.userKey(pl:getUsername()) == key then return pl end
    end
    return nil
end

local function creditMoney(user, money, title, actor)
    if type(money) ~= "table" then return end
    if not (ParadiseEconomy and ParadiseEconomy.addAccountBalance) then return end
    local personal = ParadiseEconomy.getPersonalAccount(user, true)
    if not personal then return end
    for _, currency in ipairs({ "jimoleon", "paradisium" }) do
        local amount = tonumber(money[currency]) or 0
        if amount > 0 then
            ParadiseEconomy.addAccountBalance(personal, currency, amount, "digital")
            ParadiseEconomy.record(nil, "mail grant", currency, amount, "mail", user,
                tostring(title or "") .. " from " .. tostring(actor or ""), { accountId = personal.id, bucket = "digital" })
        end
    end
end

local function deliverItems(pl, msg)
    if not (ParadiseEconomy and ParadiseEconomy.spawnItemData) then return false end
    local inv = pl:getInventory()
    local added = {}
    for _, entry in ipairs(msg.items or {}) do
        local qty = math.floor(tonumber(entry.qty) or 1)
        for _ = 1, qty do
            local item = ParadiseEconomy.spawnItemData(pl, entry.data)
            if not item then
                for _, done in ipairs(added) do
                    inv:Remove(done)
                    sendRemoveItemFromContainer(inv, done)
                end
                return false
            end
            added[#added + 1] = item
        end
    end
    return true
end

-- queues the message under user and returns "queued"; returns "delivered" for online full delivery
local function deliverOrQueue(user, msg)
    local pl = findOnline(user)
    if pl then
        if deliverItems(pl, msg) then
            creditMoney(pl:getUsername(), msg.money, msg.title, msg.from)
            sendServerCommand(pl, ParadiseMail.module, "notify", { count = #(ParadiseMail.getBox(pl:getUsername()) or {}) })
            return "delivered"
        end
    end
    local box = ParadiseMail.getBox(user)
    if not box then return nil end
    local store = ParadiseMail.getStore()
    local queued = copyDeep(msg)
    queued.id = store.nextMailId
    store.nextMailId = store.nextMailId + 1
    queued.sentAt = os.time()
    box[#box + 1] = queued
    if pl then
        sendServerCommand(pl, ParadiseMail.module, "notify", { count = #box })
    end
    return "queued"
end

local function onlineUsers()
    local list = {}
    local online = getOnlinePlayers()
    for i = 0, online:size() - 1 do
        local pl = online:get(i)
        if pl and pl.getUsername then list[#list + 1] = pl:getUsername() end
    end
    return list
end

local function knownUsers()
    local list = {}
    local seen = {}
    local online = getOnlinePlayers()
    for i = 0, online:size() - 1 do
        local pl = online:get(i)
        local user = pl and pl.getUsername and pl:getUsername() or nil
        local key = ParadiseMail.userKey(user)
        if key and not seen[key] then
            seen[key] = true
            list[#list + 1] = user
        end
    end
    if ParadiseEconomy and ParadiseEconomy.getStore then
        for _, account in pairs(ParadiseEconomy.getStore().accounts or {}) do
            if account.type == "personal" and account.owner then
                local key = ParadiseMail.userKey(account.owner)
                if key and not seen[key] then
                    seen[key] = true
                    list[#list + 1] = account.owner
                end
            end
        end
    end
    for key in pairs(ParadiseMail.getBoxes()) do
        if not seen[key] then
            seen[key] = true
            list[#list + 1] = key
        end
    end
    table.sort(list, function(a, b) return ParadiseMail.userKey(a) < ParadiseMail.userKey(b) end)
    if #list > 1000 then
        local trimmed = {}
        for i = 1, 1000 do trimmed[i] = list[i] end
        return trimmed
    end
    return list
end

function ParadiseMail.sendAdminState(pl)
    local boxes = ParadiseMail.getBoxes()
    local summaries = {}
    for user, box in pairs(boxes) do
        if #box > 0 then
            local messages = {}
            for _, msg in ipairs(box) do messages[#messages + 1] = ParadiseMail.describeMsg(msg) end
            summaries[#summaries + 1] = { user = user, count = #box, messages = messages }
        end
    end
    table.sort(summaries, function(a, b) return a.user < b.user end)
    sendServerCommand(pl, ParadiseMail.module, "adminState", {
        templates = ParadiseMail.getStore().templates,
        boxes = summaries,
        users = knownUsers(),
        online = onlineUsers(),
    })
end

function ParadiseMail.handleSaveTemplate(pl, args)
    local name = ParadiseMail.normalizeTemplateName(args.name)
    if not name then ParadiseMail.replySaved(pl, false, "Invalid template name") return true end
    local ok, err = ParadiseMail.validateSet(args.set)
    if not ok then ParadiseMail.replySaved(pl, false, err) return true end
    ParadiseMail.getStore().templates[name] = {
        items = copyDeep(args.set.items or {}),
        money = copyDeep(args.set.money or {}),
        createdBy = pl:getUsername(),
        createdAt = os.time(),
    }
    ParadiseMail.transmitAll()
    ParadiseMail.replySaved(pl, true, "Template saved: " .. name)
    return true
end

function ParadiseMail.replySaved(pl, ok, message)
    sendServerCommand(pl, ParadiseMail.module, ok and "saved" or "sendResult", { message = tostring(message or ""), ok = ok == true })
end

function ParadiseMail.handleDeleteTemplate(pl, args)
    local name = ParadiseMail.normalizeTemplateName(args.name)
    local store = ParadiseMail.getStore()
    if name and store.templates[name] then
        store.templates[name] = nil
        ParadiseMail.transmitAll()
        ParadiseMail.replySaved(pl, true, "Template deleted: " .. name)
    else
        ParadiseMail.replySaved(pl, false, "Template not found")
    end
    return true
end

function ParadiseMail.handleSend(pl, args)
    local title = ParadiseMail.normalizeTitle(args.title)
    if not title then ParadiseMail.replySaved(pl, false, "Invalid mail title") return true end
    local set = args.set
    if type(set) ~= "table" and type(args.template) == "string" then
        local template = ParadiseMail.getStore().templates[ParadiseMail.normalizeTemplateName(args.template) or ""]
        if template then
            set = { items = copyDeep(template.items or {}), money = copyDeep(template.money or {}) }
        end
    end
    local ok, err = ParadiseMail.validateSet(set)
    if not ok then ParadiseMail.replySaved(pl, false, err) return true end
    if type(args.recipients) ~= "table" or #args.recipients == 0 then
        ParadiseMail.replySaved(pl, false, "No recipients")
        return true
    end
    if #args.recipients > ParadiseMail.maxRecipients then
        ParadiseMail.replySaved(pl, false, "Too many recipients")
        return true
    end
    local base = {
        from = pl:getUsername(),
        title = title,
        items = copyDeep(set.items or {}),
        money = copyDeep(set.money or {}),
    }
    local delivered, queued, failed = 0, 0, 0
    for _, recipient in ipairs(args.recipients) do
        local user = ParadiseMail.userKey(recipient) and tostring(recipient):match("^%s*(.-)%s*$") or nil
        if user then
            local result = deliverOrQueue(user, base)
            if result == "delivered" then delivered = delivered + 1
            elseif result == "queued" then queued = queued + 1
            else failed = failed + 1 end
        else
            failed = failed + 1
        end
    end
    ParadiseMail.transmitAll()
    local message = "Mail sent: " .. tostring(delivered) .. " delivered, " .. tostring(queued) .. " queued"
    if failed > 0 then message = message .. ", " .. tostring(failed) .. " invalid" end
    ParadiseMail.replySaved(pl, true, message)
    return true
end

function ParadiseMail.handleDeleteMail(pl, args)
    local box = ParadiseMail.getBox(args.user)
    if not box then ParadiseMail.replySaved(pl, false, "Mailbox not found") return true end
    local id = tonumber(args.id)
    if id then
        for index, msg in ipairs(box) do
            if tonumber(msg.id) == id then
                table.remove(box, index)
                ParadiseMail.transmitAll()
                ParadiseMail.replySaved(pl, true, "Queued mail deleted")
                return true
            end
        end
        ParadiseMail.replySaved(pl, false, "Package expired")
        return true
    end
    if args.all then
        local key = ParadiseMail.userKey(args.user)
        if key then
            ParadiseMail.getBoxes()[key] = nil
            ParadiseMail.transmitAll()
            ParadiseMail.replySaved(pl, true, "Mailbox cleared")
        end
    end
    return true
end

function ParadiseMail.deliverOne(pl, box, index)
    local msg = box[index]
    if not msg then return nil end
    creditMoney(pl:getUsername(), msg.money, msg.title, msg.from)
    local moneyOnly = true
    for _, entry in ipairs(msg.items or {}) do
        if (tonumber(entry.qty) or 0) > 0 then moneyOnly = false break end
    end
    if not moneyOnly and not deliverItems(pl, msg) then
        -- money already granted; requeue without it so nothing doubles
        local leftover = copyDeep(msg)
        leftover.money = { jimoleon = 0, paradisium = 0 }
        table.remove(box, index)
        box[index] = leftover
        return false
    end
    table.remove(box, index)
    return true
end

function ParadiseMail.handleClaim(pl, args)
    local box = ParadiseMail.getBox(pl:getUsername())
    if not box or #box == 0 then
        sendServerCommand(pl, ParadiseMail.module, "claimResult", { ok = false, message = "No pending mail" })
        return true
    end
    local id = tonumber(args.id)
    local index = nil
    if id then
        for i, msg in ipairs(box) do
            if tonumber(msg.id) == id then index = i break end
        end
    end
    if not index then
        sendServerCommand(pl, ParadiseMail.module, "claimResult", { ok = false, message = "Package expired" })
        ParadiseMail.transmitAll()
        return true
    end
    local result = ParadiseMail.deliverOne(pl, box, index)
    ParadiseMail.transmitAll()
    sendServerCommand(pl, ParadiseMail.module, "mailbox", { messages = box })
    if result == true then
        sendServerCommand(pl, ParadiseMail.module, "claimResult", { ok = true, message = "Package received" })
    else
        sendServerCommand(pl, ParadiseMail.module, "claimResult", { ok = false, message = "Inventory full, money credited - try again later" })
    end
    return true
end

function ParadiseMail.handleClaimAll(pl)
    local box = ParadiseMail.getBox(pl:getUsername())
    if not box or #box == 0 then
        sendServerCommand(pl, ParadiseMail.module, "claimResult", { ok = false, message = "No pending mail" })
        return true
    end
    local claimed, pending = 0, 0
    local index = 1
    while index <= #box do
        local result = ParadiseMail.deliverOne(pl, box, index)
        if result == true then claimed = claimed + 1
        else pending = pending + 1; index = index + 1 end
    end
    ParadiseMail.transmitAll()
    sendServerCommand(pl, ParadiseMail.module, "mailbox", { messages = box })
    sendServerCommand(pl, ParadiseMail.module, "claimResult", {
        ok = claimed > 0,
        message = "Claimed " .. tostring(claimed) .. (pending > 0 and (" (" .. tostring(pending) .. " waiting for inventory space)") or ""),
    })
    return true
end

function ParadiseMail.onClientCommand(module, command, pl, args)
    if module ~= ParadiseMail.module or not pl then return end
    args = args or {}
    local isAdm = ParadiseRestore.isAdm and ParadiseRestore.isAdm(pl) or false

    if command == "requestAdminState" then
        if isAdm then ParadiseMail.sendAdminState(pl) end
        return
    end
    if command == "requestMailbox" then
        sendServerCommand(pl, ParadiseMail.module, "mailbox", { messages = ParadiseMail.getBox(pl:getUsername()) or {} })
        return
    end
    if command == "claim" then return ParadiseMail.handleClaim(pl, args) end
    if command == "claimAll" then return ParadiseMail.handleClaimAll(pl) end
    if not isAdm then return end
    if command == "saveTemplate" then return ParadiseMail.handleSaveTemplate(pl, args) end
    if command == "deleteTemplate" then return ParadiseMail.handleDeleteTemplate(pl, args) end
    if command == "send" then return ParadiseMail.handleSend(pl, args) end
    if command == "deleteMail" then return ParadiseMail.handleDeleteMail(pl, args) end
end
Events.OnClientCommand.Remove(ParadiseMail.onClientCommand)
Events.OnClientCommand.Add(ParadiseMail.onClientCommand)

function ParadiseMail.onCreatePlayer(plNum, pl)
    if not pl then return end
    local box = ParadiseMail.getBox(pl:getUsername())
    if box and #box > 0 then
        sendServerCommand(pl, ParadiseMail.module, "notify", { count = #box })
    end
end
Events.OnCreatePlayer.Remove(ParadiseMail.onCreatePlayer)
Events.OnCreatePlayer.Add(ParadiseMail.onCreatePlayer)
