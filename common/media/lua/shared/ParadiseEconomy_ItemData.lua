ParadiseEconomy = ParadiseEconomy or {}
ParadiseEconomy.ItemData = ParadiseEconomy.ItemData or {}

ParadiseEconomy.ItemData.genericProperties = {
    { "condition", "getCondition", "setCondition" },
    { "conditionMax", "getConditionMax", nil },
    { "haveBeenRepaired", "getHaveBeenRepaired", "setHaveBeenRepaired" },
    { "broken", "isBroken", "setBroken" },
    { "tooltip", "getTooltip", "setTooltip" },
    { "wetness", "getWetness", "setWetness" },
    { "usedDelta", "getUsedDelta", "setUsedDelta" },
    { "keyId", "getKeyId", "setKeyId" },
    { "bloodLevel", "getBloodLevel", "setBloodLevel" },
    { "dirtyness", "getDirtyness", "setDirtyness" },
}

ParadiseEconomy.ItemData.foodProperties = {
    { "cooked", "isCooked", "setCooked" },
    { "rotten", "isRotten", "setRotten" },
    { "burnt", "isBurnt", "setBurnt" },
    { "age", "getAge", "setAge" },
    { "offAge", "getOffAge", "setOffAge" },
    { "offAgeMax", "getOffAgeMax", "setOffAgeMax" },
    { "hungerChange", "getHungChange", "setHungChange" },
    { "baseHunger", "getBaseHunger", "setBaseHunger" },
    { "thirstChange", "getThirstChangeUnmodified", "setThirstChange" },
    { "poisonDetectionLevel", "getPoisonDetectionLevel", "setPoisonDetectionLevel" },
    { "poisonPower", "getPoisonPower", "setPoisonPower" },
    { "carbohydrates", "getCarbohydrates", "setCarbohydrates" },
    { "lipids", "getLipids", "setLipids" },
    { "proteins", "getProteins", "setProteins" },
    { "calories", "getCalories", "setCalories" },
    { "taintedWater", "isTaintedWater", "setTaintedWater" },
    { "actualWeight", "getActualWeight", "setActualWeight" },
    { "weight", "getWeight", "setWeight" },
    { "customWeight", "isCustomWeight", "setCustomWeight" },
    { "heat", "getHeat", "setHeat" },
    { "freezingTime", "getFreezingTime", "setFreezingTime" },
    { "frozen", "isFrozen", "setFrozen" },
    { "boredomChange", "getBoredomChangeUnmodified", "setBoredomChange" },
    { "unhappyChange", "getUnhappyChangeUnmodified", "setUnhappyChange" },
    { "foodSickness", "getFoodSicknessChange", "setFoodSicknessChange" },
}

ParadiseEconomy.ItemData.weaponParts = { "Scope", "Clip", "Sling", "Stock", "Canon", "Recoilpad" }

function ParadiseEconomy.ItemData.call(obj, method)
    if not obj or not obj[method] then return nil end
    local ok, value = pcall(obj[method], obj)
    return ok and value or nil
end

function ParadiseEconomy.ItemData.copyValue(value, seen)
    local valueType = type(value)
    if valueType == "string" or valueType == "number" or valueType == "boolean" or value == nil then return value end
    if valueType ~= "table" then return nil end
    seen = seen or {}
    if seen[value] then return nil end
    seen[value] = true
    local copy = {}
    for key, child in pairs(value) do
        local copiedKey = ParadiseEconomy.ItemData.copyValue(key, seen)
        local copiedValue = ParadiseEconomy.ItemData.copyValue(child, seen)
        if copiedKey ~= nil and copiedValue ~= nil then copy[copiedKey] = copiedValue end
    end
    seen[value] = nil
    return copy
end

function ParadiseEconomy.ItemData.readProperties(item, data, properties)
    for _, prop in ipairs(properties) do
        local value = ParadiseEconomy.ItemData.call(item, prop[2])
        if value ~= nil then data[prop[1]] = value end
    end
end

function ParadiseEconomy.ItemData.readWeapon(item, data)
    data.ammoCount = ParadiseEconomy.ItemData.call(item, "getCurrentAmmoCount")
    data.roundChambered = ParadiseEconomy.ItemData.call(item, "isRoundChambered")
    data.containsClip = ParadiseEconomy.ItemData.call(item, "isContainsClip")
    data.fireMode = ParadiseEconomy.ItemData.call(item, "getFireMode")
    data.weaponParts = {}
    for _, name in ipairs(ParadiseEconomy.ItemData.weaponParts) do
        local part = ParadiseEconomy.ItemData.call(item, "get" .. name)
        if part and part.getFullType then data.weaponParts[string.lower(name)] = ParadiseEconomy.ItemData.toData(part, true) end
    end
end

function ParadiseEconomy.ItemData.readClothing(item, data)
    local coveredParts = ParadiseEconomy.ItemData.call(item, "getCoveredParts")
    local visual = ParadiseEconomy.ItemData.call(item, "getVisual")
    if not coveredParts or not visual then return end
    data.visualTexture = ParadiseEconomy.ItemData.call(visual, "getTextureChoice")
    local tint = ParadiseEconomy.ItemData.call(visual, "getTint")
    if tint then
        local r = ParadiseEconomy.ItemData.call(tint, "getRedFloat")
        local g = ParadiseEconomy.ItemData.call(tint, "getGreenFloat")
        local b = ParadiseEconomy.ItemData.call(tint, "getBlueFloat")
        if r and g and b then data.visualTint = { r = r, g = g, b = b } end
    end
    data.clothingParts = {}
    for int = 0, coveredParts:size() - 1 do
        local bp = coveredParts:get(int)
        local entry = { part = tostring(bp) }
        local okHole, hole = pcall(visual.getHole, visual, bp)
        if okHole then entry.hole = hole end
        local patch
        local okPatch, patchValue = pcall(item.getPatchType, item, bp)
        if okPatch then patch = patchValue end
        if patch then
            entry.patch = {
                tailorLvl = tonumber(patch.tailorLvl) or 0,
                fabricType = ParadiseEconomy.ItemData.call(patch, "getFabricType") or tonumber(patch.fabricType) or 0,
                hasHole = patch.hasHole == true,
            }
        end
        data.clothingParts[#data.clothingParts + 1] = entry
    end
end

function ParadiseEconomy.ItemData.toData(item, nested)
    if not item or not item.getFullType then return nil end
    local data = {
        fullType = item:getFullType(),
        name = ParadiseEconomy.ItemData.call(item, "getName"),
        customName = ParadiseEconomy.ItemData.call(item, "isCustomName") == true,
        category = ParadiseEconomy.ItemData.call(item, "getCategory"),
        modData = item.hasModData and item:hasModData() and ParadiseEconomy.ItemData.copyValue(item:getModData()) or nil,
        containedItems = {},
    }
    ParadiseEconomy.ItemData.readProperties(item, data, ParadiseEconomy.ItemData.genericProperties)
    if item.getCurrentAmmoCount or item.getScope then ParadiseEconomy.ItemData.readWeapon(item, data) end
    if item.getFoodType then ParadiseEconomy.ItemData.readProperties(item, data, ParadiseEconomy.ItemData.foodProperties) end
    if item.getClothingItem and ParadiseEconomy.ItemData.call(item, "getClothingItem") then ParadiseEconomy.ItemData.readClothing(item, data) end
    local inv = ParadiseEconomy.ItemData.call(item, "getInventory")
    if inv and inv.getItems then
        local items = inv:getItems()
        for int = 0, items:size() - 1 do
            local child = ParadiseEconomy.ItemData.toData(items:get(int), true)
            if child then data.containedItems[#data.containedItems + 1] = child end
        end
    end
    data.isContainer = #data.containedItems > 0 or inv ~= nil
    return data
end

function ParadiseEconomy.ItemData.set(item, setter, value)
    if value == nil or not item or not setter or not item[setter] then return end
    pcall(item[setter], item, value)
end

function ParadiseEconomy.ItemData.applyProperties(item, data, properties)
    for _, prop in ipairs(properties) do ParadiseEconomy.ItemData.set(item, prop[3], data[prop[1]]) end
end

function ParadiseEconomy.ItemData.applyWeapon(item, data)
    ParadiseEconomy.ItemData.set(item, "setCurrentAmmoCount", data.ammoCount)
    ParadiseEconomy.ItemData.set(item, "setRoundChambered", data.roundChambered)
    ParadiseEconomy.ItemData.set(item, "setContainsClip", data.containsClip)
    ParadiseEconomy.ItemData.set(item, "setFireMode", data.fireMode)
    if not item.attachWeaponPart then return end
    for _, name in ipairs(ParadiseEconomy.ItemData.weaponParts) do
        local partData = data.weaponParts and data.weaponParts[string.lower(name)] or nil
        if partData then
            local part = ParadiseEconomy.ItemData.makeItem(partData)
            if part then pcall(item.attachWeaponPart, item, part) end
        end
    end
end

function ParadiseEconomy.ItemData.applyClothing(item, data)
    if not data.clothingParts or not BloodBodyPartType or not BloodBodyPartType.FromString then return end
    local visual = ParadiseEconomy.ItemData.call(item, "getVisual")
    if not visual then return end
    ParadiseEconomy.ItemData.set(visual, "setTextureChoice", data.visualTexture)
    if data.visualTint and ImmutableColor and ImmutableColor.new and visual.setTint then
        local okTint, tint = pcall(ImmutableColor.new, data.visualTint.r, data.visualTint.g, data.visualTint.b, 1)
        if okTint and tint then pcall(visual.setTint, visual, tint) end
    end
    for _, entry in ipairs(data.clothingParts) do
        local bp = BloodBodyPartType.FromString(entry.part)
        if bp then
            if tonumber(entry.hole) and tonumber(entry.hole) > 0 and visual.setHole then pcall(visual.setHole, visual, bp) end
            if entry.patch and item.addPatchForSync then
                pcall(item.addPatchForSync, item, bp:index(), entry.patch.tailorLvl, entry.patch.fabricType, entry.patch.hasHole)
                if entry.patch.fabricType == 1 and visual.setBasicPatch then pcall(visual.setBasicPatch, visual, bp)
                elseif entry.patch.fabricType == 2 and visual.setDenimPatch then pcall(visual.setDenimPatch, visual, bp)
                elseif entry.patch.fabricType == 3 and visual.setLeatherPatch then pcall(visual.setLeatherPatch, visual, bp) end
            end
        end
    end
    if item.synchWithVisual then pcall(item.synchWithVisual, item) end
end

function ParadiseEconomy.ItemData.apply(item, data)
    if not item or type(data) ~= "table" then return false end
    if data.customName and data.name and item.setName then item:setName(data.name) end
    ParadiseEconomy.ItemData.applyProperties(item, data, ParadiseEconomy.ItemData.genericProperties)
    ParadiseEconomy.ItemData.applyProperties(item, data, ParadiseEconomy.ItemData.foodProperties)
    if data.modData and item.getModData then
        local md = item:getModData()
        for key, value in pairs(data.modData) do md[key] = ParadiseEconomy.ItemData.copyValue(value) end
    end
    ParadiseEconomy.ItemData.applyWeapon(item, data)
    ParadiseEconomy.ItemData.applyClothing(item, data)
    return true
end

function ParadiseEconomy.ItemData.makeItem(data)
    if type(data) ~= "table" or not data.fullType or not instanceItem then return nil end
    local item = instanceItem(data.fullType)
    if not item then return nil end
    ParadiseEconomy.ItemData.apply(item, data)
    local inv = ParadiseEconomy.ItemData.call(item, "getInventory")
    if inv then
        for _, childData in ipairs(data.containedItems or {}) do
            local child = ParadiseEconomy.ItemData.makeItem(childData)
            if child then inv:AddItem(child) end
        end
    end
    return item
end

function ParadiseEconomy.ItemData.getSummary(data)
    if type(data) ~= "table" then return "" end
    local parts = {}
    if data.condition ~= nil then
        local condition = "Condition " .. tostring(data.condition)
        if data.conditionMax then condition = condition .. "/" .. tostring(data.conditionMax) end
        parts[#parts + 1] = condition
    end
    if data.ammoCount ~= nil then parts[#parts + 1] = "Ammo " .. tostring(data.ammoCount) end
    if data.usedDelta ~= nil then parts[#parts + 1] = "Remaining " .. tostring(math.floor((tonumber(data.usedDelta) or 0) * 100)) .. "%" end
    if data.age ~= nil then parts[#parts + 1] = "Age " .. string.format("%.1f", tonumber(data.age) or 0) end
    if data.hungerChange ~= nil then parts[#parts + 1] = "Hunger " .. tostring(math.floor((tonumber(data.hungerChange) or 0) * 100)) end
    if data.thirstChange ~= nil then parts[#parts + 1] = "Thirst " .. tostring(math.floor((tonumber(data.thirstChange) or 0) * 100)) end
    if data.calories ~= nil then parts[#parts + 1] = "Calories " .. tostring(math.floor(tonumber(data.calories) or 0)) end
    if data.cooked then parts[#parts + 1] = "Cooked" end
    if data.rotten then parts[#parts + 1] = "Rotten" end
    if data.burnt then parts[#parts + 1] = "Burnt" end
    if data.frozen then parts[#parts + 1] = "Frozen" end
    if data.broken then parts[#parts + 1] = "Broken" end
    local weaponPartCount = 0
    for _ in pairs(data.weaponParts or {}) do weaponPartCount = weaponPartCount + 1 end
    if weaponPartCount > 0 then parts[#parts + 1] = tostring(weaponPartCount) .. " attachments" end
    if #(data.containedItems or {}) > 0 then parts[#parts + 1] = tostring(#data.containedItems) .. " contained" end
    return table.concat(parts, " | ")
end
