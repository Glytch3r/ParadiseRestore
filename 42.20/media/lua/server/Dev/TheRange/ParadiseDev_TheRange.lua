ParadiseDev = ParadiseDev or {}
ParadiseDev.TheRange = ParadiseDev.TheRange or {}



ParadiseDev.TheRange.module = "ParadiseDevTheRange"
ParadiseDev.TheRange.cardType = "ParadiseZ.TheRangeCard"
ParadiseDev.TheRange.vendorSprites = {
    ParadiseTiles_12 = true,
    ParadiseTiles_13 = true,
    ParadiseTiles_14 = true,
    ParadiseTiles_15 = true,
}
ParadiseDev.TheRange.lastHourly = ParadiseDev.TheRange.lastHourly or {}

function ParadiseDev.TheRange.isCard(card)
    return card and instanceof(card, "InventoryItem") and card:getFullType() == ParadiseDev.TheRange.cardType
end

function ParadiseDev.TheRange.getOwner(card)
    if not ParadiseDev.TheRange.isCard(card) then return "" end
    return tostring(card:getModData().CardOwner or "")
end

function ParadiseDev.TheRange.getCredits(card)
    if not ParadiseDev.TheRange.isCard(card) then return 0 end
    return math.max(0, tonumber(card:getModData().CardCredits) or 0)
end

function ParadiseDev.TheRange.getPoints(card)
    if not ParadiseDev.TheRange.isCard(card) then return 0 end
    return math.max(0, tonumber(card:getModData().CardPoints) or 0)
end

function ParadiseDev.TheRange.setCredits(card, amount)
    if not ParadiseDev.TheRange.isCard(card) then return end
    card:getModData().CardCredits = math.max(0, math.floor(tonumber(amount) or 0))
end

function ParadiseDev.TheRange.setPoints(card, amount)
    if not ParadiseDev.TheRange.isCard(card) then return end
    card:getModData().CardPoints = math.max(0, math.floor(tonumber(amount) or 0))
end

function ParadiseDev.TheRange.normalizeCard(card)
    if not ParadiseDev.TheRange.isCard(card) then return false end
    local modData = card:getModData()
    local changed = false
    if modData.CardOwner == nil then
        modData.CardOwner = ""
        changed = true
    end
    if modData.CardCredits == nil then
        modData.CardCredits = 0
        changed = true
    end
    if modData.CardPoints == nil then
        modData.CardPoints = 0
        changed = true
    end
    return changed
end

function ParadiseDev.TheRange.getCard(pl, cardId)
    if not pl or not cardId then return nil end
    local card = pl:getInventory():getItemById(tonumber(cardId))
    if ParadiseDev.TheRange.isCard(card) then return card end
    return nil
end

function ParadiseDev.TheRange.getMemberCard(pl)
    if not pl then return nil end
    local username = pl:getUsername()
    local items = pl:getInventory():getItems()
    for index = 0, items:size() - 1 do
        local card = items:get(index)
        if ParadiseDev.TheRange.isCard(card) and ParadiseDev.TheRange.getOwner(card) == username then return card end
    end
    return nil
end

function ParadiseDev.TheRange.isStaff(pl)
    if not pl then return false end
    if ParadiseDev.isAdm(pl) then return true end
    local staff = SandboxVars and SandboxVars.TheRange and SandboxVars.TheRange.Staff or ""
    for username in string.gmatch(tostring(staff), "[^;]+") do
        if username == pl:getUsername() then return true end
    end
    return ParadiseDev.hasTrait(pl, "ParadiseDev:TheRangeStaff") or ParadiseDev.hasTrait(pl, "TheRangeStaff")
end

function ParadiseDev.TheRange.canHunt(pl)
    if ParadiseDev.TheRange.isStaff(pl) then return true end
    local card = ParadiseDev.TheRange.getMemberCard(pl)
    return card and ParadiseDev.TheRange.getCredits(card) > 0 or false
end

function ParadiseDev.TheRange.syncCard(pl, card)
    if not pl or not card then return end
    if syncItemModData then syncItemModData(pl, card) end
    if syncItemFields then syncItemFields(pl, card) end
end

function ParadiseDev.TheRange.reply(pl, text)
    if pl then sendServerCommand(pl, ParadiseDev.TheRange.module, "result", { text = text }) end
end

function ParadiseDev.TheRange.sendPayout(pl, amount, reason)
    if not pl or amount <= 0 then return end
    sendServerCommand(pl, ParadiseDev.TheRange.module, "payout", {
        targetUsername = pl:getUsername(),
        currency = "cash_primary",
        amount = amount,
        accountCurrency = "primary",
        reason = reason,
    })
end

function ParadiseDev.TheRange.updateAccess(pl, sync)
    if not pl or not ParadiseDev.Zones or not ParadiseDev.Zones.Engine then return end
    local engine = ParadiseDev.Zones.Engine
    local username = pl:getUsername()
    if not username or username == "" then return end
    local profile = engine.profiles[username] or { tags = {} }
    profile.tags = profile.tags or {}
    if ParadiseDev.TheRange.isStaff(pl) then profile.tags.range_staff = true end
    if ParadiseDev.TheRange.canHunt(pl) then
        profile.tags.can_hunt = true
    else
        profile.tags.can_hunt = nil
    end
    engine.profiles[username] = profile
    if sync then engine.syncBoundaryState(pl) end
end

function ParadiseDev.TheRange.getHuntZone(pl)
    if not pl or not ParadiseDev.Zones or not ParadiseDev.Zones.Engine then return nil, nil end
    local engine = ParadiseDev.Zones.Engine
    local zone, region = engine.getAuthority(pl:getX(), pl:getY(), pl:getZ(), 0)
    if zone and zone.features and zone.features.isHunt == true then return zone, region end
    return nil, nil
end

function ParadiseDev.TheRange.rebound(pl, zone, region)
    if not pl or not zone or not region or not ParadiseDev.Zones or not ParadiseDev.Zones.Engine then return end
    ParadiseDev.Zones.Engine.reboundPlayer(pl, zone, region, pl:getX(), pl:getY(), pl:getZ())
end

function ParadiseDev.TheRange.getSpriteName(obj)
    if not obj or not obj.getSprite then return nil end
    local sprite = obj:getSprite()
    return sprite and sprite:getName() or nil
end

function ParadiseDev.TheRange.getVendor(args)
    local x = math.floor(tonumber(args and args.x) or -1)
    local y = math.floor(tonumber(args and args.y) or -1)
    local z = math.floor(tonumber(args and args.z) or -1)
    if x < 0 or y < 0 or z < 0 then return nil end
    local sq = getCell():getGridSquare(x, y, z)
    if not sq then return nil end
    local objects = sq:getObjects()
    for index = 0, objects:size() - 1 do
        local obj = objects:get(index)
        if ParadiseDev.TheRange.vendorSprites[ParadiseDev.TheRange.getSpriteName(obj)] then return obj end
    end
    return nil
end

function ParadiseDev.TheRange.isNear(pl, obj)
    if not pl or not obj or not obj.getSquare then return false end
    local sq = obj:getSquare()
    if not sq then return false end
    local dx = pl:getX() - sq:getX()
    local dy = pl:getY() - sq:getY()
    return dx * dx + dy * dy <= 9
end

function ParadiseDev.TheRange.getEarnings(obj)
    if not obj then return 0 end
    return math.max(0, tonumber(obj:getModData().TheRangeEarnings) or 0)
end

function ParadiseDev.TheRange.setEarnings(obj, amount)
    if not obj then return end
    obj:getModData().TheRangeEarnings = math.max(0, math.floor(tonumber(amount) or 0))
    obj:transmitModData()
end

function ParadiseDev.TheRange.register(pl, args)
    local card = ParadiseDev.TheRange.getCard(pl, args and args.cardId)
    if not card then return ParadiseDev.TheRange.reply(pl, "The Range card was not found.") end
    ParadiseDev.TheRange.normalizeCard(card)
    local owner = ParadiseDev.TheRange.getOwner(card)
    if owner ~= "" and owner ~= pl:getUsername() then return ParadiseDev.TheRange.reply(pl, "That card belongs to another player.") end
    card:getModData().CardOwner = pl:getUsername()
    ParadiseDev.TheRange.syncCard(pl, card)
    ParadiseDev.TheRange.updateAccess(pl, true)
    ParadiseDev.TheRange.reply(pl, "The Range card registered.")
end

function ParadiseDev.TheRange.credit(pl, args)
    if not ParadiseDev.isAdm(pl) then return end
    local card = ParadiseDev.TheRange.getCard(pl, args and args.cardId)
    if not card then return ParadiseDev.TheRange.reply(pl, "The Range card was not found.") end
    ParadiseDev.TheRange.normalizeCard(card)
    local amount = math.floor(tonumber(args and args.amount) or 0)
    if amount == 0 then return end
    ParadiseDev.TheRange.setCredits(card, ParadiseDev.TheRange.getCredits(card) + amount)
    ParadiseDev.TheRange.syncCard(pl, card)
    ParadiseDev.TheRange.updateAccess(pl, true)
end

function ParadiseDev.TheRange.points(pl, args)
    if not ParadiseDev.isAdm(pl) then return end
    local card = ParadiseDev.TheRange.getCard(pl, args and args.cardId)
    if not card then return ParadiseDev.TheRange.reply(pl, "The Range card was not found.") end
    ParadiseDev.TheRange.normalizeCard(card)
    local amount = math.floor(tonumber(args and args.amount) or 0)
    if amount == 0 then return end
    ParadiseDev.TheRange.setPoints(card, ParadiseDev.TheRange.getPoints(card) + amount)
    ParadiseDev.TheRange.syncCard(pl, card)
end

function ParadiseDev.TheRange.hourly(pl, args)
    local card = ParadiseDev.TheRange.getCard(pl, args and args.cardId)
    if not card or ParadiseDev.TheRange.getOwner(card) ~= pl:getUsername() then return end
    local zone, region = ParadiseDev.TheRange.getHuntZone(pl)
    if not zone then return end
    local hour = math.floor(getGameTime():getWorldAgeHours())
    if ParadiseDev.TheRange.lastHourly[pl:getUsername()] == hour then return end
    ParadiseDev.TheRange.lastHourly[pl:getUsername()] = hour
    ParadiseDev.TheRange.setCredits(card, ParadiseDev.TheRange.getCredits(card) - 1)
    ParadiseDev.TheRange.syncCard(pl, card)
    ParadiseDev.TheRange.updateAccess(pl, true)
    if ParadiseDev.TheRange.getCredits(card) <= 0 then
        ParadiseDev.TheRange.rebound(pl, zone, region)
        ParadiseDev.TheRange.reply(pl, "The Range credit expired.")
    end
end

function ParadiseDev.TheRange.prey(pl, args)
    local card = ParadiseDev.TheRange.getCard(pl, args and args.cardId)
    if not card or ParadiseDev.TheRange.getOwner(card) ~= pl:getUsername() then return end
    if not ParadiseDev.TheRange.getHuntZone(pl) or ParadiseDev.TheRange.getCredits(card) <= 0 then return end
    local amount = math.floor(tonumber(SandboxVars and SandboxVars.TheRange and SandboxVars.TheRange.PointsPerKill) or 3)
    if amount <= 0 then return end
    ParadiseDev.TheRange.setPoints(card, ParadiseDev.TheRange.getPoints(card) + amount)
    ParadiseDev.TheRange.syncCard(pl, card)
    ParadiseDev.TheRange.reply(pl, "The Range points: " .. tostring(ParadiseDev.TheRange.getPoints(card)))
end

function ParadiseDev.TheRange.exchange(pl, args)
    local card = ParadiseDev.TheRange.getCard(pl, args and args.cardId)
    local vendor = ParadiseDev.TheRange.getVendor(args)
    local amount = math.floor(tonumber(args and args.amount) or 0)
    if not card or ParadiseDev.TheRange.getOwner(card) ~= pl:getUsername() or not vendor or not ParadiseDev.TheRange.isNear(pl, vendor) or amount <= 0 then return end
    if amount > ParadiseDev.TheRange.getPoints(card) then return ParadiseDev.TheRange.reply(pl, "Not enough The Range points.") end
    local price = tonumber(SandboxVars and SandboxVars.TheRange and SandboxVars.TheRange.CreditPrice) or 1
    local percent = tonumber(SandboxVars and SandboxVars.TheRange and SandboxVars.TheRange.ExchangePercent) or 0
    percent = math.max(0, math.min(1, percent))
    local gross = amount * math.max(0, price)
    local tax = math.floor(gross * percent)
    local payout = math.floor(gross - tax)
    if payout <= 0 then return ParadiseDev.TheRange.reply(pl, "The exchange value is zero.") end
    ParadiseDev.TheRange.setPoints(card, ParadiseDev.TheRange.getPoints(card) - amount)
    ParadiseDev.TheRange.setEarnings(vendor, ParadiseDev.TheRange.getEarnings(vendor) + tax)
    ParadiseDev.TheRange.syncCard(pl, card)
    ParadiseDev.TheRange.sendPayout(pl, payout, "points_exchange")
end

function ParadiseDev.TheRange.withdraw(pl, args)
    local vendor = ParadiseDev.TheRange.getVendor(args)
    local amount = math.floor(tonumber(args and args.amount) or 0)
    if not ParadiseDev.TheRange.isStaff(pl) or not vendor or not ParadiseDev.TheRange.isNear(pl, vendor) or amount <= 0 then return end
    local earnings = ParadiseDev.TheRange.getEarnings(vendor)
    if earnings <= 0 then return ParadiseDev.TheRange.reply(pl, "No The Range earnings are available.") end
    amount = math.min(amount, earnings)
    ParadiseDev.TheRange.setEarnings(vendor, earnings - amount)
    ParadiseDev.TheRange.sendPayout(pl, amount, "paycheck")
end

function ParadiseDev.TheRange.sync(pl)
    ParadiseDev.TheRange.updateAccess(pl, true)
end

function ParadiseDev.TheRange.onClientCommand(module, command, pl, args)
    if module ~= ParadiseDev.TheRange.module or not pl then return end
    if command == "register" then
        ParadiseDev.TheRange.register(pl, args)
    elseif command == "credit" then
        ParadiseDev.TheRange.credit(pl, args)
    elseif command == "points" then
        ParadiseDev.TheRange.points(pl, args)
    elseif command == "hourly" then
        ParadiseDev.TheRange.hourly(pl, args)
    elseif command == "prey" then
        ParadiseDev.TheRange.prey(pl, args)
    elseif command == "exchange" then
        ParadiseDev.TheRange.exchange(pl, args)
    elseif command == "withdraw" then
        ParadiseDev.TheRange.withdraw(pl, args)
    elseif command == "sync" then
        ParadiseDev.TheRange.sync(pl)
    end
end

function ParadiseDev.TheRange.onPlayerMove(pl)
    ParadiseDev.TheRange.updateAccess(pl, false)
end

Events.OnClientCommand.Remove(ParadiseDev.TheRange.onClientCommand)
Events.OnClientCommand.Add(ParadiseDev.TheRange.onClientCommand)
Events.OnPlayerMove.Remove(ParadiseDev.TheRange.onPlayerMove)
Events.OnPlayerMove.Add(ParadiseDev.TheRange.onPlayerMove)
