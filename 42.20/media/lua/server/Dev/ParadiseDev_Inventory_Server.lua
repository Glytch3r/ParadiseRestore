if isClient and isClient() then return end

ParadiseDev = ParadiseDev or {}
ParadiseDev.InventoryServer = ParadiseDev.InventoryServer or {}

local cloner = ParadiseDev.InventoryServer
cloner.module = "ParadiseDevItemCloner"

local genericProperties = {
    { "getCondition", "setCondition" }, { "getHaveBeenRepaired", "setHaveBeenRepaired" },
    { "isBroken", "setBroken" }, { "getTooltip", "setTooltip" }, { "getKeyId", "setKeyId" },
    { "getWetness", "setWetness" }, { "getUsedDelta", "setUsedDelta" },
}

local foodProperties = {
    { "getAge", "setAge" }, { "getOffAge", "setOffAge" }, { "getOffAgeMax", "setOffAgeMax" },
    { "isCooked", "setCooked" }, { "isBurnt", "setBurnt" }, { "getCalories", "setCalories" },
    { "getCarbohydrates", "setCarbohydrates" }, { "getLipids", "setLipids" }, { "getProteins", "setProteins" },
    { "getHungerChange", "setHungerChange" }, { "getBaseHunger", "setBaseHunger" }, { "getThirstChange", "setThirstChange" },
    { "getUnhappyChange", "setUnhappyChange" }, { "getBoredomChange", "setBoredomChange" }, { "getFoodSickness", "setFoodSickness" }, { "getHeat", "setHeat" },
}

local clothingProperties = { { "getBloodLevel", "setBloodLevel" }, { "getDirtyness", "setDirtyness" } }
local attachmentNames = { "Scope", "Clip", "Sling", "Stock", "Canon", "Recoilpad" }

local function copyValue(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, child in pairs(value) do copy[copyValue(key, seen)] = copyValue(child, seen) end
    return copy
end

local function copyProperties(source, target, properties)
    for _, pair in ipairs(properties) do
        if source[pair[1]] and target[pair[2]] then
            local ok, value = pcall(source[pair[1]], source)
            if ok and value ~= nil then pcall(target[pair[2]], target, value) end
        end
    end
end

local function copyModData(source, target)
    if not source:hasModData() then return end
    for key, value in pairs(source:getModData()) do target:getModData()[key] = copyValue(value) end
end

local function copyWeapon(source, target)
    copyProperties(source, target, { { "getCurrentAmmoCount", "setCurrentAmmoCount" }, { "isRoundChambered", "setRoundChambered" }, { "isContainsClip", "setContainsClip" } })
    if not target.attachWeaponPart then return end
    for _, name in ipairs(attachmentNames) do
        local getter = source["get" .. name]
        local part = getter and getter(source) or nil
        if part then
            local clone = InventoryItemFactory.CreateItem(part:getFullType())
            if clone then
                copyProperties(part, clone, genericProperties)
                copyModData(part, clone)
                target:attachWeaponPart(clone)
            end
        end
    end
end

local function copyClothing(source, target)
    copyProperties(source, target, clothingProperties)
    local sourceVisual = source.getVisual and source:getVisual() or nil
    local targetVisual = target.getVisual and target:getVisual() or nil
    if not sourceVisual or not targetVisual then return end
    if sourceVisual.getTextureChoice and targetVisual.setTextureChoice then targetVisual:setTextureChoice(sourceVisual:getTextureChoice()) end
    if sourceVisual.getTint and targetVisual.setTint then targetVisual:setTint(sourceVisual:getTint()) end
    if target.synchWithVisual then target:synchWithVisual() end
end

function cloner.clone(source, destination)
    if not source or not destination then return nil end
    local clone = destination:AddItem(source:getFullType())
    if not clone then return nil end
    clone:setName(source:getDisplayName())
    copyProperties(source, clone, genericProperties)
    copyModData(source, clone)
    if instanceof(source, "HandWeapon") then copyWeapon(source, clone) end
    if source.getFoodType then copyProperties(source, clone, foodProperties) end
    if source.getClothingItem and source:getClothingItem() then copyClothing(source, clone) end
    if instanceof(source, "InventoryContainer") or (source.getCategory and source:getCategory() == "Container") then
        local items, target = source:getInventory():getItems(), clone:getInventory()
        for index = 0, items:size() - 1 do cloner.clone(items:get(index), target) end
    end
    if clone.SynchSpawn then clone:SynchSpawn() end
    sendAddItemToContainer(destination, clone)
    return clone
end

function cloner.onClientCommand(module, command, player, args)
    if module ~= cloner.module or command ~= "clone" or not ParadiseDev.isAdm(player) then return end
    local itemID, count = args and tonumber(args.itemID), args and tonumber(args.count)
    if not itemID or not count then return end
    count = math.floor(count)
    if count < 1 or count > 10 then return end
    local source = player:getInventory():getItemWithID(itemID)
    if not source then return end
    for index = 1, count do cloner.clone(source, player:getInventory()) end
end

Events.OnClientCommand.Remove(cloner.onClientCommand)
Events.OnClientCommand.Add(cloner.onClientCommand)
