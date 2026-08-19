ParadiseDev = ParadiseDev or {}
ParadiseDev.TheRange = ParadiseDev.TheRange or {}
ParadiseDev.TheRange.Context = ParadiseDev.TheRange.Context or {}

require "ISUI/ISTextBox"

ParadiseDev.TheRange.Context.vendorSprites = {
    ParadiseTiles_12 = true,
    ParadiseTiles_13 = true,
    ParadiseTiles_14 = true,
    ParadiseTiles_15 = true,
}

function ParadiseDev.TheRange.Context.getSpriteName(obj)
    if not obj or not obj.getSprite then return nil end
    local sprite = obj:getSprite()
    return sprite and sprite:getName() or nil
end

function ParadiseDev.TheRange.Context.isVendor(obj)
    return ParadiseDev.TheRange.Context.vendorSprites[ParadiseDev.TheRange.Context.getSpriteName(obj)] == true
end

function ParadiseDev.TheRange.Context.getClickedSquare()
    if ISWorldObjectContextMenu and ISWorldObjectContextMenu.fetchVars then
        return ISWorldObjectContextMenu.fetchVars.clickedSquare
    end
    return clickedSquare
end

function ParadiseDev.TheRange.Context.findVendor()
    local sq = ParadiseDev.TheRange.Context.getClickedSquare()
    if not sq then return nil end
    local objects = sq:getObjects()
    for index = 0, objects:size() - 1 do
        local obj = objects:get(index)
        if ParadiseDev.TheRange.Context.isVendor(obj) then return obj end
    end
    return nil
end

function ParadiseDev.TheRange.Context.getVendorArgs(obj)
    if not obj or not obj.getSquare then return nil end
    local sq = obj:getSquare()
    if not sq then return nil end
    return { x = sq:getX(), y = sq:getY(), z = sq:getZ() }
end

function ParadiseDev.TheRange.Context.getEarnings(obj)
    if not obj or not obj.getModData then return 0 end
    return math.max(0, tonumber(obj:getModData().TheRangeEarnings) or 0)
end

function ParadiseDev.TheRange.Context.close(context)
    if context and context.hideAndChildren then context:hideAndChildren() end
end

function ParadiseDev.TheRange.Context.onWithdrawAmount(target, button, vendor)
    if not button or button.internal ~= "OK" or not button.parent or not button.parent.entry or not vendor then return end
    local value = math.floor(tonumber(button.parent.entry:getText()) or 0)
    if value <= 0 then return end
    ParadiseDev.TheRange.request("withdraw", { x = vendor.x, y = vendor.y, z = vendor.z, amount = value })
end

function ParadiseDev.TheRange.Context.onExchangeAmount(target, button, args)
    if not button or button.internal ~= "OK" or not button.parent or not button.parent.entry or not args then return end
    local value = math.floor(tonumber(button.parent.entry:getText()) or 0)
    if value <= 0 then return end
    ParadiseDev.TheRange.request("exchange", {
        cardId = args.cardId,
        x = args.x,
        y = args.y,
        z = args.z,
        amount = value,
    })
end

function ParadiseDev.TheRange.Context.withdrawPrompt(pl, obj)
    local vendor = ParadiseDev.TheRange.Context.getVendorArgs(obj)
    local earnings = ParadiseDev.TheRange.Context.getEarnings(obj)
    if not pl or not vendor or earnings <= 0 then return end
    local modal = ISTextBox:new(0, 0, 300, 150, "Withdraw Amount", tostring(earnings), ParadiseDev.TheRange.Context, ParadiseDev.TheRange.Context.onWithdrawAmount, pl:getPlayerNum(), vendor)
    modal:initialise()
    modal:setOnlyNumbers(true)
    modal:addToUIManager()
end

function ParadiseDev.TheRange.Context.exchangePrompt(pl, obj)
    local card = ParadiseDev.TheRange.getCard(pl)
    local vendor = ParadiseDev.TheRange.Context.getVendorArgs(obj)
    local points = ParadiseDev.TheRange.getPoints(card)
    if not pl or not card or not vendor or points <= 0 then return end
    local args = { cardId = ParadiseDev.TheRange.getCardId(card), x = vendor.x, y = vendor.y, z = vendor.z }
    local modal = ISTextBox:new(0, 0, 300, 150, "Points Exchange", tostring(points), ParadiseDev.TheRange.Context, ParadiseDev.TheRange.Context.onExchangeAmount, pl:getPlayerNum(), args)
    modal:initialise()
    modal:setOnlyNumbers(true)
    modal:addToUIManager()
end

function ParadiseDev.TheRange.Context.requestRegister(cards, context)
    for _, card in ipairs(cards) do ParadiseDev.TheRange.requestRegister(card) end
    ParadiseDev.TheRange.Context.close(context)
end

function ParadiseDev.TheRange.Context.requestCredit(cards, amount, context)
    for _, card in ipairs(cards) do ParadiseDev.TheRange.requestCredit(card, amount) end
    ParadiseDev.TheRange.Context.close(context)
end

function ParadiseDev.TheRange.Context.requestPoints(cards, amount, context)
    for _, card in ipairs(cards) do ParadiseDev.TheRange.requestPoints(card, amount) end
    ParadiseDev.TheRange.Context.close(context)
end

function ParadiseDev.TheRange.Context.addCardContext(plNum, context, items)
    local pl = getSpecificPlayer(plNum)
    local cards = ParadiseDev.TheRange.getCards(items)
    if not pl or #cards == 0 then return end
    local root = context:addOption("The Range")
    root.iconTexture = getTexture("media/textures/TheRange.png")
    local submenu = ISContextMenu:getNew(context)
    context:addSubMenu(root, submenu)
    local card = cards[1]
    local owner = ParadiseDev.TheRange.getOwner(card)
    local info = submenu:addOption(card:getDisplayName() .. " | Owner: " .. (owner ~= "" and owner or "None"))
    info.notAvailable = true
    local register = submenu:addOption("Register", cards, ParadiseDev.TheRange.Context.requestRegister, context)
    register.notAvailable = owner ~= "" and owner ~= pl:getUsername()
    if ParadiseDev.isAdm(pl) then
        submenu:addOption("Add Credit", cards, ParadiseDev.TheRange.Context.requestCredit, 1, context)
        submenu:addOption("Reduce Credit", cards, ParadiseDev.TheRange.Context.requestCredit, -1, context)
        submenu:addOption("Add Points", cards, ParadiseDev.TheRange.Context.requestPoints, 1, context)
        submenu:addOption("Reduce Points", cards, ParadiseDev.TheRange.Context.requestPoints, -1, context)
    end
    local credit = submenu:addOption("Credits: " .. tostring(ParadiseDev.TheRange.getCredits(card)))
    credit.notAvailable = true
    local points = submenu:addOption("Points: " .. tostring(ParadiseDev.TheRange.getPoints(card)))
    points.notAvailable = true
end

function ParadiseDev.TheRange.Context.withdraw(pl, obj, context)
    ParadiseDev.TheRange.Context.withdrawPrompt(pl, obj)
    ParadiseDev.TheRange.Context.close(context)
end

function ParadiseDev.TheRange.Context.exchange(pl, obj, context)
    ParadiseDev.TheRange.Context.exchangePrompt(pl, obj)
    ParadiseDev.TheRange.Context.close(context)
end

function ParadiseDev.TheRange.Context.addWorldContext(plNum, context, worldobjects, test)
    if test then return end
    local pl = getSpecificPlayer(plNum)
    local obj = ParadiseDev.TheRange.Context.findVendor()
    if not pl or not obj then return end
    local root = context:addOptionOnTop("The Range")
    root.iconTexture = getTexture("media/ui/TheRangeMachine.png")
    local submenu = ISContextMenu:getNew(context)
    context:addSubMenu(root, submenu)
    if ParadiseDev.TheRange.isStaff(pl) then
        local earnings = submenu:addOption("Earnings: " .. tostring(ParadiseDev.TheRange.Context.getEarnings(obj)))
        earnings.notAvailable = true
        submenu:addOption("Withdraw", pl, ParadiseDev.TheRange.Context.withdraw, obj, context)
    end
    local card = ParadiseDev.TheRange.getCard(pl)
    if card then
        local points = submenu:addOption("Points: " .. tostring(ParadiseDev.TheRange.getPoints(card)))
        points.notAvailable = true
        submenu:addOption("Points Exchange", pl, ParadiseDev.TheRange.Context.exchange, obj, context)
    end
end

Events.OnFillInventoryObjectContextMenu.Remove(ParadiseDev.TheRange.Context.addCardContext)
Events.OnFillInventoryObjectContextMenu.Add(ParadiseDev.TheRange.Context.addCardContext)
Events.OnFillWorldObjectContextMenu.Remove(ParadiseDev.TheRange.Context.addWorldContext)
Events.OnFillWorldObjectContextMenu.Add(ParadiseDev.TheRange.Context.addWorldContext)
