ParadiseDev = ParadiseDev or {}
ParadiseDev.TheRange = ParadiseDev.TheRange or {}


ParadiseDev.TheRange.module = "ParadiseDevTheRange"
ParadiseDev.TheRange.cardType = "ParadiseZ.TheRangeCard"
ParadiseDev.TheRange.staffTrait = "ParadiseDev:TheRangeStaff"

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

function ParadiseDev.TheRange.getCardId(card)
    if not ParadiseDev.TheRange.isCard(card) then return nil end
    return card:getID()
end

function ParadiseDev.TheRange.getCards(items)
    local cards = {}
    local found = {}
    local function addCard(card)
        if not ParadiseDev.TheRange.isCard(card) then return end
        local id = card:getID()
        if found[id] then return end
        found[id] = true
        cards[#cards + 1] = card
    end
    if ParadiseDev.TheRange.isCard(items) then
        addCard(items)
        return cards
    end
    for _, entry in ipairs(items or {}) do
        if ParadiseDev.TheRange.isCard(entry) then
            addCard(entry)
        elseif type(entry) == "table" and entry.items then
            for _, item in ipairs(entry.items) do
                addCard(item)
            end
        end
    end
    return cards
end

function ParadiseDev.TheRange.getCard(pl)
    pl = pl or getPlayer()
    if not pl then return nil end
    local username = pl:getUsername()
    local inventory = pl:getInventory()
    if not inventory then return nil end
    local items = inventory:getItems()
    for index = 0, items:size() - 1 do
        local card = items:get(index)
        if ParadiseDev.TheRange.isCard(card) and ParadiseDev.TheRange.getOwner(card) == username then return card end
    end
    return nil
end

function ParadiseDev.TheRange.getTotalsString(pl)
    local card = ParadiseDev.TheRange.getCard(pl)
    if not card then return "Credits: 0\nPoints: 0" end
    return "Credits: " .. tostring(ParadiseDev.TheRange.getCredits(card)) .. "\nPoints: " .. tostring(ParadiseDev.TheRange.getPoints(card))
end

function ParadiseDev.TheRange.isStaff(pl)
    pl = pl or getPlayer()
    if not pl then return false end
    if ParadiseDev.isAdm(pl) then return true end
    if ParadiseDev.hasTrait(pl, ParadiseDev.TheRange.staffTrait) or ParadiseDev.hasTrait(pl, "TheRangeStaff") then return true end
    local staff = SandboxVars.TheRange and SandboxVars.TheRange.Staff or ""
    for username in string.gmatch(tostring(staff), "[^;]+") do
        if username == pl:getUsername() then return true end
    end
    return false
end

function ParadiseDev.TheRange.isMember(pl)
    return ParadiseDev.TheRange.getCard(pl) ~= nil
end

function ParadiseDev.TheRange.isHuntZone(pl)
    if not pl or not ParadiseDev.Zones or not ParadiseDev.Zones.Border or not ParadiseDev.Zones.Border.getAuthorityAt then return false end
    local zone = ParadiseDev.Zones.Border.getAuthorityAt(pl:getX(), pl:getY(), pl:getZ(), 0)
    return zone and zone.features and zone.features.isHunt == true or false
end

function ParadiseDev.TheRange.request(command, args)
    if not sendClientCommand then return end
    sendClientCommand(ParadiseDev.TheRange.module, command, args or {})
end

function ParadiseDev.TheRange.requestRegister(card)
    local cardId = ParadiseDev.TheRange.getCardId(card)
    if not cardId then return end
    ParadiseDev.TheRange.request("register", { cardId = cardId })
end

function ParadiseDev.TheRange.requestCredit(card, amount)
    local cardId = ParadiseDev.TheRange.getCardId(card)
    if not cardId then return end
    ParadiseDev.TheRange.request("credit", { cardId = cardId, amount = amount })
end

function ParadiseDev.TheRange.requestPoints(card, amount)
    local cardId = ParadiseDev.TheRange.getCardId(card)
    if not cardId then return end
    ParadiseDev.TheRange.request("points", { cardId = cardId, amount = amount })
end

function ParadiseDev.TheRange.requestHourly()
    local pl = getPlayer()
    local card = ParadiseDev.TheRange.getCard(pl)
    if not card or not ParadiseDev.TheRange.isHuntZone(pl) then return end
    ParadiseDev.TheRange.request("hourly", { cardId = ParadiseDev.TheRange.getCardId(card) })
end

function ParadiseDev.TheRange.requestPreyReward(zed)
    local pl = getPlayer()
    local card = ParadiseDev.TheRange.getCard(pl)
    if not card or not zed or not ParadiseDev.TheRange.isHuntZone(pl) then return end
    ParadiseDev.TheRange.request("prey", { cardId = ParadiseDev.TheRange.getCardId(card) })
end

function ParadiseDev.TheRange.requestSync()
    ParadiseDev.TheRange.request("sync", {})
end

function ParadiseDev.TheRange.onServerCommand(module, command, args)
    if module ~= ParadiseDev.TheRange.module then return end
    if command == "result" and args and args.text then
        local pl = getPlayer()
        if pl then pl:setHaloNote(tostring(args.text), 150, 250, 150, 900) end
    elseif command == "payout" and args and sendClientCommand then
        sendClientCommand("btse_economy", "sendPayment", args)
    end
end

Events.OnServerCommand.Remove(ParadiseDev.TheRange.onServerCommand)
Events.OnServerCommand.Add(ParadiseDev.TheRange.onServerCommand)
Events.OnCreatePlayer.Remove(ParadiseDev.TheRange.requestSync)
Events.OnCreatePlayer.Add(ParadiseDev.TheRange.requestSync)
Events.EveryHours.Remove(ParadiseDev.TheRange.requestHourly)
Events.EveryHours.Add(ParadiseDev.TheRange.requestHourly)
