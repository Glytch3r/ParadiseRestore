if isClient and isClient() then return end
ParadiseRestore = ParadiseRestore or {}
ParadiseCloner = ParadiseCloner or {}

local function copyValue(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}; seen[value] = copy
    for key, child in pairs(value) do copy[copyValue(key, seen)] = copyValue(child, seen) end
    return copy
end

local function apply(item, data)
    if data.name then item:setName(data.name) end
    if data.condition and item.setCondition then item:setCondition(data.condition) end
    if data.repaired ~= nil and item.setHaveBeenRepaired then item:setHaveBeenRepaired(data.repaired) end
    if data.broken ~= nil and item.setBroken then item:setBroken(data.broken) end
    if data.wetness and item.setWetness then item:setWetness(data.wetness) end
    if data.usedDelta and item.setUsedDelta then item:setUsedDelta(data.usedDelta) end
    if data.modData then for key, value in pairs(data.modData) do item:getModData()[key] = copyValue(value) end end
    local pairsToCopy = {{"age","setAge"},{"offAge","setOffAge"},{"offAgeMax","setOffAgeMax"},{"cooked","setCooked"},{"burnt","setBurnt"},{"calories","setCalories"},{"carbohydrates","setCarbohydrates"},{"lipids","setLipids"},{"proteins","setProteins"},{"hungerChange","setHungerChange"},{"baseHunger","setBaseHunger"},{"thirstChange","setThirstChange"},{"unhappyChange","setUnhappyChange"},{"boredomChange","setBoredomChange"},{"foodSickness","setFoodSickness"},{"heat","setHeat"},{"bloodLevel","setBloodLevel"},{"dirtyness","setDirtyness"}}
    for _, pair in ipairs(pairsToCopy) do if data[pair[1]] ~= nil and item[pair[2]] then pcall(item[pair[2]], item, data[pair[1]]) end end
end

local function make(destination, data)
    local item = destination:AddItem(data.fullType)
    if not item then return nil end
    apply(item, data)
    for _, child in ipairs(data.children or {}) do make(item:getInventory(), child) end
    if item.SynchSpawn then item:SynchSpawn() end
    sendAddItemToContainer(destination, item)
    return item
end

local function clearEquipment(player)
    local inv = player:getInventory()
    local primary, secondary = player:getPrimaryHandItem(), player:getSecondaryHandItem()
    if primary then inv:AddItem(primary); player:setPrimaryHandItem(nil) end
    if secondary and secondary ~= primary then inv:AddItem(secondary); player:setSecondaryHandItem(nil) end
    local worn = player:getWornItems()
    for i = 0, worn:size() - 1 do
        local entry = worn:get(i)
        local item = entry:getItem()
        if item then inv:AddItem(item); player:setWornItem(entry:getLocation(), nil) end
    end
    if player.onWornItemsChanged then player:onWornItemsChanged() end
    if player.resetModelNextFrame then player:resetModelNextFrame() end
end

local function allInventoryItems(player)
    local result = {}
    local inv = player:getInventory(); local list = inv:getItems()
    for i = 0, list:size() - 1 do result[#result + 1] = { item = list:get(i), location = "inventory" } end
    local worn = player:getWornItems()
    for i = 0, worn:size() - 1 do
        local entry = worn:get(i)
        result[#result + 1] = { item = entry:getItem(), location = "worn:" .. tostring(entry:getLocation()) }
    end
    if player:getPrimaryHandItem() then result[#result + 1] = { item = player:getPrimaryHandItem(), location = "hand:primary" } end
    if player:getSecondaryHandItem() then result[#result + 1] = { item = player:getSecondaryHandItem(), location = "hand:secondary" } end
    return result
end

local function recordPlayer(player, encoded)
    local records = ParadiseCloner.getRecords(encoded.owner or ParadiseCloner.ownerKey(player))
    local key = encoded.key
    if not key or key == "" then return end
    records[key] = { items = encoded.records, createdBy = player:getUsername() }
    if encoded.despawn then for _, entry in ipairs(allInventoryItems(player)) do player:getInventory():Remove(entry.item) end end
    ModData.transmit(ParadiseCloner.modDataName .. "." .. (encoded.owner or ParadiseCloner.ownerKey(player)))
end

local function spawnRecord(player, record)
    if not record then return end
    clearEquipment(player)
    local equipped = {}
    for _, encoded in ipairs(record.items or {}) do
        local data = ParadiseCloner.deserialize(encoded)
        if data then
            local destination = player:getInventory()
            local item = make(destination, data)
            if item and type(data.location) == "string" and data.location ~= "inventory" then equipped[#equipped + 1] = { item = item, location = data.location } end
        end
    end
    for _, entry in ipairs(equipped) do
        local kind, value = entry.location:match("^(%w+):(.+)$")
        if kind == "hand" and value == "primary" then player:setPrimaryHandItem(entry.item)
        elseif kind == "hand" and value == "secondary" then player:setSecondaryHandItem(entry.item)
        elseif kind == "worn" then player:setWornItem(value, entry.item) end
    end
    if player.onWornItemsChanged then player:onWornItemsChanged() end
    if player.resetModelNextFrame then player:resetModelNextFrame() end
end

local function onCommand(module, command, player, args)
    if module ~= ParadiseCloner.module or not ParadiseRestore.isAdm or not ParadiseRestore.isAdm(player) then return end
    if command == "record" then return recordPlayer(player, args or {}) end
    if command == "recordTarget" and args and args.username and args.key then
        for i = 0, getOnlinePlayers():size() - 1 do
            local target = getOnlinePlayers():get(i)
            if target:getUsername() == args.username then
                local encoded = { owner = ParadiseCloner.ownerKey(target), key = args.key, records = {} }
                for _, entry in ipairs(allInventoryItems(target)) do encoded.records[#encoded.records + 1] = ParadiseCloner.recordItem(entry.item, entry.location) end
                return recordPlayer(player, encoded)
            end
        end
        return
    end
    if command == "spawn" and args then
        local receiver = player
        for i = 0, getOnlinePlayers():size() - 1 do
            local candidate = getOnlinePlayers():get(i)
            if candidate:getUsername() == args.targetUsername then receiver = candidate; break end
        end
        return spawnRecord(receiver, ParadiseCloner.getRecords(args.owner)[args.recordkey])
    end
    if command == "delete" and args and args.recordkey and args.owner then
        local records = ParadiseCloner.getRecords(args.owner); records[args.recordkey] = nil
        ModData.transmit(ParadiseCloner.modDataName .. "." .. args.owner)
    end
    if command == "fetch" and args and args.owner then
        sendServerCommand(player, ParadiseCloner.module, "records", { owner = args.owner, records = ParadiseCloner.getRecords(args.owner) })
    end
end

Events.OnClientCommand.Remove(onCommand)
Events.OnClientCommand.Add(onCommand)
