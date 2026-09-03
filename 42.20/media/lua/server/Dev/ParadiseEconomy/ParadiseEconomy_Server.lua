if isClient and isClient() then return end

require "Dev/ParadiseEconomy/ParadiseEconomy_Shared"

local economy = ParadiseEconomy

local function accountId(pl)
    return tostring(pl:getUsername() or pl:getOnlineID() or "")
end

local function store()
    local data = ModData.getOrCreate(economy.storeName)
    data.players = data.players or {}
    return data
end

local function account(pl)
    local data = store()
    local id = accountId(pl)
    data.players[id] = data.players[id] or { gold = 0, silver = 0 }
    return data.players[id]
end

local function sendBalance(pl)
    local data = account(pl)
    sendServerCommand(pl, economy.module, "balance", { gold = economy.getBalance(data, "gold"), silver = economy.getBalance(data, "silver") })
end

local function syncItem(item)
    if item and item.getContainer and item:getContainer() and sendItemStats then sendItemStats(item) end
end

local function removeItem(item)
    local worldItem = item and item.getWorldItem and item:getWorldItem() or nil
    if worldItem then
        local sq = worldItem:getSquare()
        if sq then sq:transmitRemoveItemFromSquare(worldItem) end
        worldItem:removeFromWorld(); worldItem:removeFromSquare(); worldItem:setSquare(nil)
        return
    end
    local container = item and item.getContainer and item:getContainer() or nil
    if container then
        container:DoRemoveItem(item)
        if sendRemoveItemFromContainer then sendRemoveItemFromContainer(container, item) end
    end
end

local function collect(container, list)
    if not container then return end
    local items = container:getItems()
    for index = 0, items:size() - 1 do
        local item = items:get(index)
        list[#list + 1] = item
        if item.getInventory then collect(item:getInventory(), list) end
    end
end

local function findPlayerItem(pl, id)
    local items = {}
    collect(pl:getInventory(), items)
    for _, item in ipairs(items) do if item.getID and item:getID() == id then return item end end
    return nil
end

local function getCoin(pl, id)
    local item = findPlayerItem(pl, tonumber(id))
    return economy.getCoin(item) and item or nil
end

local function halo(pl, verb, count, item)
    local coin = economy.getCoin(item)
    if coin then sendServerCommand(pl, economy.module, "halo", { text = verb .. " " .. tostring(count) .. " " .. coin.label .. (count == 1 and "" or "s") }) end
end

local function addCoin(pl, typeName, count)
    local item = pl:getInventory():AddItem(typeName)
    if item then
        economy.setCount(item, count)
        if item.SynchSpawn then item:SynchSpawn() end
        sendAddItemToContainer(pl:getInventory(), item)
    end
    return item
end

local function merge(target, source)
    if not target or not source or target == source or target:getFullType() ~= source:getFullType() then return 0 end
    local total = economy.getCount(target) + economy.getCount(source)
    economy.setCount(target, total)
    syncItem(target)
    removeItem(source)
    return total
end

local function onCommand(module, command, pl, args)
    if module ~= economy.module or not pl then return end
    args = args or {}
    if command == "requestBalance" then sendBalance(pl); return end
    if command == "deposit" then
        local item = getCoin(pl, args.itemID)
        if not item then return end
        local coin, count = economy.getCoin(item), economy.getCount(item)
        local data = account(pl); data[coin.key] = economy.getBalance(data, coin.key) + count
        ModData.transmit(economy.storeName); removeItem(item); sendBalance(pl)
    elseif command == "withdraw" then
        local key, count = tostring(args.key or ""), math.max(1, math.floor(tonumber(args.count) or 0))
        local typeName
        for name, coin in pairs(economy.coinTypes) do if coin.key == key then typeName = name end end
        local data = account(pl)
        if not typeName or economy.getBalance(data, key) < count then return end
        data[key] = data[key] - count
        local item = addCoin(pl, typeName, count)
        ModData.transmit(economy.storeName); sendBalance(pl); halo(pl, "Withdrew", count, item)
    elseif command == "split" then
        local item, count = getCoin(pl, args.itemID), math.floor(tonumber(args.count) or 0)
        if not item or count < 1 or count >= economy.getCount(item) then return end
        local container = item:getContainer() or pl:getInventory()
        economy.setCount(item, economy.getCount(item) - count); syncItem(item)
        local split = container:AddItem(item:getFullType())
        if split then economy.setCount(split, count); if split.SynchSpawn then split:SynchSpawn() end; sendAddItemToContainer(container, split); halo(pl, "Split", count, split) end
    elseif command == "merge" then
        local target, source = getCoin(pl, args.targetID), getCoin(pl, args.sourceID)
        local total = merge(target, source)
        if total > 0 then halo(pl, "Stacked", total, target) end
    elseif command == "mergeAll" then
        local target = getCoin(pl, args.targetID)
        if not target then return end
        local items, changed = {}, false
        collect(pl:getInventory(), items)
        for _, source in ipairs(items) do
            if source ~= target and source:getFullType() == target:getFullType() then
                if merge(target, source) > 0 then changed = true end
            end
        end
        if changed then halo(pl, "Stacked", economy.getCount(target), target) end
    elseif command == "autoStack" then
        local target, source = getCoin(pl, args.targetID), getCoin(pl, args.sourceID)
        merge(target, source)
    end
end

Events.OnInitGlobalModData.Add(store)
Events.OnClientCommand.Remove(onCommand)
Events.OnClientCommand.Add(onCommand)
