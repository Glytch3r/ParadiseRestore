ParadiseRestore = ParadiseRestore or {}
ParadiseCloner = ParadiseCloner or {}

ParadiseCloner.module = "ParadiseRestore.ItemCloner"
ParadiseCloner.modDataName = "ParadiseRestore.ItemCloner"

function ParadiseCloner.ownerKey(player)
    if type(player) == "string" then return player end
    local steamID = player and player.getSteamID and tostring(player:getSteamID() or "") or ""
    if steamID ~= "" and steamID ~= "0" then return "steam:" .. steamID end
    return "user:" .. tostring(player and player.getUsername and player:getUsername() or "unknown")
end

local function esc(value)
    if type(value) == "string" then return string.format("%q", value) end
    if type(value) == "number" or type(value) == "boolean" then return tostring(value) end
    if value == nil then return "nil" end
    local out = { "{" }
    for key, child in pairs(value) do out[#out + 1] = "[" .. esc(key) .. "]=" .. esc(child) .. "," end
    out[#out + 1] = "}"
    return table.concat(out)
end

function ParadiseCloner.serialize(value) return esc(value) end

function ParadiseCloner.deserialize(value)
    if type(value) ~= "string" then return value end
    local fn = loadstring("return " .. value)
    if not fn then return nil end
    local ok, result = pcall(fn)
    return ok and result or nil
end

function ParadiseCloner.getRecords(owner)
    local data = ModData.getOrCreate(ParadiseCloner.modDataName .. "." .. ParadiseCloner.ownerKey(owner or getPlayer()))
    data.records = data.records or {}
    return data.records
end

local function call(item, getter)
    if not item or not item[getter] then return nil end
    local ok, value = pcall(item[getter], item)
    return ok and value or nil
end

local function copyData(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, child in pairs(value) do copy[copyData(key, seen)] = copyData(child, seen) end
    return copy
end

local function itemData(item, location, parent)
    local data = {
        fullType = item:getFullType(), name = item:getName(), location = location, parent = parent,
        condition = call(item, "getCondition"), repaired = call(item, "getHaveBeenRepaired"),
        broken = call(item, "isBroken"), wetness = call(item, "getWetness"), usedDelta = call(item, "getUsedDelta"),
        modData = item:hasModData() and copyData(item:getModData()) or nil, children = {}
    }
    if item.getFoodType then
        for _, key in ipairs({"Age", "OffAge", "OffAgeMax", "Cooked", "Burnt", "Calories", "Carbohydrates", "Lipids", "Proteins", "HungerChange", "BaseHunger", "ThirstChange", "UnhappyChange", "BoredomChange", "FoodSickness", "Heat"}) do data[key:sub(1,1):lower() .. key:sub(2)] = call(item, "get" .. key) end
    end
    if item.getClothingItem and item:getClothingItem() then
        data.bloodLevel, data.dirtyness = call(item, "getBloodLevel"), call(item, "getDirtyness")
    end
    if item.getInventory then
        local inv = item:getInventory()
        if inv then
            local list = inv:getItems()
            for i = 0, list:size() - 1 do data.children[#data.children + 1] = itemData(list:get(i), "bag", true) end
        end
    end
    return data
end

function ParadiseCloner.recordItem(item, location)
    if not item then return nil end
    return ParadiseCloner.serialize(itemData(item, location or "inventory"))
end

function ParadiseCloner.RecordItemData(shouldDespawnItem)
    local player = getPlayer()
    if not player or not ParadiseRestore.isAdm or not ParadiseRestore.isAdm(player) then return false end
    local selected = ParadiseCloner.pendingItems or {}
    if #selected == 0 then return false end
    local records = {}
    for _, entry in ipairs(selected) do records[#records + 1] = ParadiseCloner.recordItem(entry.item, entry.location) end
    sendClientCommand(player, ParadiseCloner.module, "record", { records = records, despawn = shouldDespawnItem == true })
    ParadiseCloner.pendingItems = nil
    return true
end

function ParadiseCloner.submitRecord(label, shouldDespawnItem)
    local player = getPlayer()
    if not player or not label or label == "" then return false end
    local records = {}
    for _, entry in ipairs(ParadiseCloner.pendingItems or {}) do records[#records + 1] = ParadiseCloner.recordItem(entry.item, entry.location) end
    sendClientCommand(player, ParadiseCloner.module, "record", { owner = ParadiseCloner.ownerKey(player), key = label, records = records, despawn = shouldDespawnItem == true })
    ParadiseCloner.pendingItems = nil
    return true
end

function ParadiseCloner.cloneRecord(recordkey, owner, targetUsername)
    local player = getPlayer()
    if not player or not recordkey then return false end
    sendClientCommand(player, ParadiseCloner.module, "spawn", { owner = owner or ParadiseCloner.ownerKey(player), recordkey = recordkey, targetUsername = targetUsername })
    return true
end
