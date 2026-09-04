ParadiseDev = ParadiseDev or {}
ParadiseDev.Inventory = ParadiseDev.Inventory or {}


ParadiseDev.Inventory.genericProperties = {
    { "getCondition", "setCondition" },
    { "getHaveBeenRepaired", "setHaveBeenRepaired" },
    { "isBroken", "setBroken" },
    { "getTooltip", "setTooltip" },
    { "getKeyId", "setKeyId" },
    { "getWetness", "setWetness" },
    { "getUsedDelta", "setUsedDelta" },
}

ParadiseDev.Inventory.foodProperties = {
    { "getAge", "setAge" },
    { "getOffAge", "setOffAge" },
    { "getOffAgeMax", "setOffAgeMax" },
    { "isCooked", "setCooked" },
    { "isBurnt", "setBurnt" },
    { "getCalories", "setCalories" },
    { "getCarbohydrates", "setCarbohydrates" },
    { "getLipids", "setLipids" },
    { "getProteins", "setProteins" },
    { "getHungerChange", "setHungerChange" },
    { "getBaseHunger", "setBaseHunger" },
    { "getThirstChange", "setThirstChange" },
    { "getUnhappyChange", "setUnhappyChange" },
    { "getBoredomChange", "setBoredomChange" },
    { "getFoodSickness", "setFoodSickness" },
    { "getHeat", "setHeat" },
}

ParadiseDev.Inventory.clothingProperties = {
    { "getBloodLevel", "setBloodLevel" },
    { "getDirtyness", "setDirtyness" },
}

ParadiseDev.Inventory.attachmentNames = { "Scope", "Clip", "Sling", "Stock", "Canon", "Recoilpad" }


function ParadiseDev.Inventory.copyValue(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, child in pairs(value) do
        copy[ParadiseDev.Inventory.copyValue(key, seen)] = ParadiseDev.Inventory.copyValue(child, seen)
    end
    return copy
end

function ParadiseDev.Inventory.copyProperty(source, target, getter, setter)
    if not source or not target or not source[getter] or not target[setter] then return end
    local ok, value = pcall(source[getter], source)
    if ok and value ~= nil then pcall(target[setter], target, value) end
end

function ParadiseDev.Inventory.copyProperties(source, target, properties)
    for _, pair in ipairs(properties) do
        ParadiseDev.Inventory.copyProperty(source, target, pair[1], pair[2])
    end
end

function ParadiseDev.Inventory.copyModData(source, target)
    if not source or not target or not source.hasModData or not source:hasModData() then return end
    local sourceData = source:getModData()
    local targetData = target:getModData()
    for key, value in pairs(sourceData) do
        targetData[key] = ParadiseDev.Inventory.copyValue(value)
    end
end

function ParadiseDev.Inventory.copyWeapon(source, target)
    ParadiseDev.Inventory.copyProperty(source, target, "getCurrentAmmoCount", "setCurrentAmmoCount")
    ParadiseDev.Inventory.copyProperty(source, target, "isRoundChambered", "setRoundChambered")
    ParadiseDev.Inventory.copyProperty(source, target, "isContainsClip", "setContainsClip")
    if not target.attachWeaponPart then return end
    for _, name in ipairs(ParadiseDev.Inventory.attachmentNames) do
        local getter = source["get" .. name]
        if getter then
            local ok, part = pcall(getter, source)
            if ok and part then
                local clone = InventoryItemFactory.CreateItem(part:getFullType())
                if clone then
                    ParadiseDev.Inventory.copyProperties(part, clone, ParadiseDev.Inventory.genericProperties)
                    ParadiseDev.Inventory.copyModData(part, clone)
                    pcall(target.attachWeaponPart, target, clone)
                end
            end
        end
    end
end

function ParadiseDev.Inventory.copyClothing(source, target)
    ParadiseDev.Inventory.copyProperties(source, target, ParadiseDev.Inventory.clothingProperties)
    if not source.getVisual or not target.getVisual then return end
    local visual = source:getVisual()
    local cloneVisual = target:getVisual()
    if not visual or not cloneVisual then return end
    if visual.getTextureChoice and cloneVisual.setTextureChoice then
        local texture = visual:getTextureChoice()
        if texture then cloneVisual:setTextureChoice(texture) end
    end
    if visual.getTint and cloneVisual.setTint then
        local tint = visual:getTint()
        if tint then cloneVisual:setTint(tint) end
    end
end

function ParadiseDev.Inventory.syncAddedItem(container, item)
    if not container or not item then return false end
    if item.SynchSpawn then item:SynchSpawn() end
    sendAddItemToContainer(container, item)
    triggerEvent("OnContainerUpdate")
    return true
end

function ParadiseDev.Inventory.clone(item, destination)
    if not item or not destination then return nil end
    if type(item) == "string" then
        local added = destination:AddItem(item)
        ParadiseDev.Inventory.syncAddedItem(destination, added)
        return added
    end
    if not instanceof(item, "InventoryItem") then return nil end
    local clone = destination:AddItem(item:getFullType())
    if not clone then return nil end
    clone:setName(item:getDisplayName())
    ParadiseDev.Inventory.copyProperties(item, clone, ParadiseDev.Inventory.genericProperties)
    ParadiseDev.Inventory.copyModData(item, clone)
    if instanceof(item, "HandWeapon") then ParadiseDev.Inventory.copyWeapon(item, clone) end
    if item.getFoodType then ParadiseDev.Inventory.copyProperties(item, clone, ParadiseDev.Inventory.foodProperties) end
    if item.getClothingItem and item:getClothingItem() then ParadiseDev.Inventory.copyClothing(item, clone) end
    if instanceof(item, "InventoryContainer") or (item.getCategory and item:getCategory() == "Container") then
        local sourceItems = item:getInventory():getItems()
        local targetInventory = clone:getInventory()
        for index = 0, sourceItems:size() - 1 do
            ParadiseDev.Inventory.clone(sourceItems:get(index), targetInventory)
        end
    end
    ParadiseDev.Inventory.syncAddedItem(destination, clone)
    return clone
end

function ParadiseDev.Inventory.cloneMultiple(item, count)
    local pl = getPlayer()
    if not pl then return end
    if isClient and isClient() then
        if sendClientCommand and item and item.getID then
            sendClientCommand(pl, "ParadiseDevItemCloner", "clone", { itemID = item:getID(), count = count })
        end
        return
    end
    for index = 1, count or 1 do
        ParadiseDev.Inventory.clone(item, pl:getInventory())
    end
    pl:resetModelNextFrame()
    triggerEvent("OnClothingUpdated", pl)
end

function ParadiseDev.Inventory.getItems(items)
    local result = {}
    if instanceof(items, "InventoryItem") then
        result[#result + 1] = items
        return result
    end
    for _, entry in ipairs(items or {}) do
        if instanceof(entry, "InventoryItem") then
            result[#result + 1] = entry
        elseif type(entry) == "table" and entry.items then
            for _, item in ipairs(entry.items) do
                if instanceof(item, "InventoryItem") then result[#result + 1] = item end
            end
        end
    end
    return result
end

function ParadiseDev.Inventory.getTexture(item)
    if item and item.getTexture then
        local texture = item:getTexture()
        if texture then return texture end
    end
    return nil
end

function ParadiseDev.Inventory.inventoryContext(plNum, context, items)
    local pl = getSpecificPlayer(plNum)
    if not ParadiseDev.isAdm(pl) then return end
    local selected = ParadiseDev.Inventory.getItems(items)
    if #selected == 0 then return end
    local root = context:addOption("Paradise Item Cloner: ")
    root.iconTexture = getTexture("media/ui/Paradise/cloner.png")
    local submenu = ISContextMenu:getNew(context)
    context:addSubMenu(root, submenu)
    for _, item in ipairs(selected) do
        local name = item:getDisplayName()
        local texture = ParadiseDev.Inventory.getTexture(item)
        local once = submenu:addOption(name, item, ParadiseDev.Inventory.cloneMultiple, 1)
        once.iconTexture = texture
        local five = submenu:addOption(name .. " x5", item, ParadiseDev.Inventory.cloneMultiple, 5)
        five.iconTexture = texture
        local ten = submenu:addOption(name .. " x10", item, ParadiseDev.Inventory.cloneMultiple, 10)
        ten.iconTexture = texture
    end
end

Events.OnFillInventoryObjectContextMenu.Remove(ParadiseDev.Inventory.inventoryContext)
Events.OnFillInventoryObjectContextMenu.Add(ParadiseDev.Inventory.inventoryContext)
