if isClient and isClient() then return end

ParadiseRestore = ParadiseRestore or {}
ParadiseRestore.ItemEditorServer = ParadiseRestore.ItemEditorServer or {}
local ItemEditorServer = ParadiseRestore.ItemEditorServer

ItemEditorServer.module = "ParadiseRestore.ItemEditor"
ItemEditorServer.command = "saveItem"

ItemEditorServer.setters = {
    getName = "setName",
    getActualWeight = "setActualWeight",
    getCondition = "setCondition",
    getHeadCondition = "setHeadCondition",
    getKeyId = "setKeyId",
    getBloodLevel = "setBloodLevel",
    getDirtiness = "setDirtiness",
    getSharpness = "setSharpness",
    getMinDamage = "setMinDamage",
    getMaxDamage = "setMaxDamage",
    getMinAngle = "setMinAngle",
    getMinRange = "setMinRange",
    getMinRangeRanged = "setMinRangeRanged",
    getMaxRange = "setMaxRange",
    getAimingTime = "setAimingTime",
    getRecoilDelay = "setRecoilDelay",
    getReloadTime = "setReloadTime",
    getClipSize = "setClipSize",
    getAge = "setAge",
    getBaseHunger = "setBaseHunger",
    getUnhappyChange = "setUnhappyChange",
    getBoredomChange = "setBoredomChange",
    getPoisonPower = "setPoisonPower",
    getOffAge = "setOffAge",
    getOffAgeMax = "setOffAgeMax",
    getCalories = "setCalories",
    getProteins = "setProteins",
    getLipids = "setLipids",
    getCarbohydrates = "setCarbohydrates",
    getCurrentUsesFloat = "setUsedDelta",
}

function ItemEditorServer.findInContainer(cont, itemId, fullType)
    if not cont then return nil end
    local item = cont:getItemWithID(itemId)
    if item and item:getFullType() == fullType then return cont, item end
    local items = cont:getItems()
    if not items then return nil end
    for i = 0, items:size() - 1 do
        local child = items:get(i)
        if instanceof(child, "InventoryContainer") then
            local foundCont, foundItem = ItemEditorServer.findInContainer(child:getInventory(), itemId, fullType)
            if foundItem then return foundCont, foundItem end
        end
    end
    return nil
end

function ItemEditorServer.findOnSquare(sq, itemId, fullType)
    if not sq then return nil end

    local wobs = sq:getWorldObjects()
    if wobs then
        for i = 0, wobs:size() - 1 do
            local item = wobs:get(i):getItem()
            if item then
                if item:getID() == itemId and item:getFullType() == fullType then
                    return item:getContainer(), item
                end
                if instanceof(item, "InventoryContainer") then
                    local cont, found = ItemEditorServer.findInContainer(item:getInventory(), itemId, fullType)
                    if found then return cont, found end
                end
            end
        end
    end

    local sobs = sq:getStaticMovingObjects()
    if sobs then
        for i = 0, sobs:size() - 1 do
            local cont, found = ItemEditorServer.findInContainer(sobs:get(i):getContainer(), itemId, fullType)
            if found then return cont, found end
        end
    end

    local objs = sq:getObjects()
    if objs then
        for i = 0, objs:size() - 1 do
            local obj = objs:get(i)
            for index = 1, obj:getContainerCount() do
                local cont, found = ItemEditorServer.findInContainer(obj:getContainerByIndex(index - 1), itemId, fullType)
                if found then return cont, found end
            end
        end
    end

    local vehicle = sq:getVehicleContainer()
    if vehicle then
        for i = 1, vehicle:getPartCount() do
            local part = vehicle:getPartByIndex(i - 1)
            local cont, found = ItemEditorServer.findInContainer(part:getItemContainer(), itemId, fullType)
            if found then return cont, found end
        end
    end

    return nil
end

function ItemEditorServer.findOnPlayer(pl, itemId, fullType)
    local cont, found = ItemEditorServer.findInContainer(pl:getInventory(), itemId, fullType)
    if found then return cont, found end
    local worn = pl:getWornItems()
    if worn then
        for i = 0, worn:size() - 1 do
            local bag = worn:get(i):getItem()
            if bag and instanceof(bag, "InventoryContainer") then
                if bag:getID() == itemId and bag:getFullType() == fullType then return bag:getContainer(), bag end
                cont, found = ItemEditorServer.findInContainer(bag:getInventory(), itemId, fullType)
                if found then return cont, found end
            end
        end
    end
    local pr = pl:getPrimaryHandItem()
    if pr then
        if pr:getID() == itemId and pr:getFullType() == fullType then return pr:getContainer(), pr end
        if instanceof(pr, "InventoryContainer") then
            cont, found = ItemEditorServer.findInContainer(pr:getInventory(), itemId, fullType)
            if found then return cont, found end
        end
    end
    local sr = pl:getSecondaryHandItem()
    if sr then
        if sr:getID() == itemId and sr:getFullType() == fullType then return sr:getContainer(), sr end
        if instanceof(sr, "InventoryContainer") then
            cont, found = ItemEditorServer.findInContainer(sr:getInventory(), itemId, fullType)
            if found then return cont, found end
        end
    end
    return nil
end

function ItemEditorServer.findItem(args)
    local itemId = tonumber(args.id)
    local fullType = args.fullType
    if not itemId or type(fullType) ~= "string" then return nil end

    local ownerId = tonumber(args.ownerId)
    if ownerId then
        local pl = getPlayerByOnlineID(ownerId)
        if pl then
            local cont, found = ItemEditorServer.findOnPlayer(pl, itemId, fullType)
            if found then return cont, found end
        end
    end

    local x, y, z = tonumber(args.x), tonumber(args.y), tonumber(args.z)
    if x and y and z then
        local sq = getCell():getGridSquare(math.floor(x), math.floor(y), math.floor(z))
        local cont, found = ItemEditorServer.findOnSquare(sq, itemId, fullType)
        if found then return cont, found end
    end

    local players = getOnlinePlayers()
    for i = 0, players:size() - 1 do
        local cont, found = ItemEditorServer.findOnPlayer(players:get(i), itemId, fullType)
        if found then return cont, found end
    end
    return nil
end

function ItemEditorServer.applyValue(item, getter, val)
    local setter = ItemEditorServer.setters[getter]
    if not setter or not item[setter] then return end
    if getter == "getName" then
        if type(val) == "string" then pcall(item[setter], item, val) end
        return
    end
    val = tonumber(val)
    if val then pcall(item[setter], item, val) end
end

function ItemEditorServer.applySideEffects(item, vals)
    if vals.getActualWeight ~= nil and item.setCustomWeight then
        pcall(item.setCustomWeight, item, true)
    end
    if vals.getBaseHunger ~= nil and item.setHungChange and item.getBaseHunger then
        pcall(item.setHungChange, item, item:getBaseHunger())
    end
    if vals.getCondition ~= nil and instanceof(item, "Clothing") and item:getCondition() == item:getConditionMax() then
        pcall(item.fullyRestore, item)
    end
end

function ItemEditorServer.applyColor(item, col)
    if type(col) ~= "table" then return end
    local r, g, b = tonumber(col.r), tonumber(col.g), tonumber(col.b)
    if not r or not g or not b then return end
    r = math.max(0, math.min(1, r))
    g = math.max(0, math.min(1, g))
    b = math.max(0, math.min(1, b))
    if item.setColorRed then pcall(item.setColorRed, item, r) end
    if item.setColorGreen then pcall(item.setColorGreen, item, g) end
    if item.setColorBlue then pcall(item.setColorBlue, item, b) end
    if item.setColor then pcall(item.setColor, item, Color.new(r, g, b, 1)) end
    if item.setCustomColor then pcall(item.setCustomColor, item, true) end
end

function ItemEditorServer.applyAttributes(item, attrs)
    if type(attrs) ~= "table" or not item.getAttributes then return end
    local cont = item:getAttributes()
    if not cont then return end
    for i = 1, #attrs do
        local data = attrs[i]
        if type(data) == "table" then
            local id = tonumber(data.id)
            if id then
                for index = 0, cont:size() - 1 do
                    if cont:getKey(index):id() == id then
                        local attr = cont:getAttribute(index)
                        if data.k == "s" then
                            pcall(attr.setValue, attr, tostring(data.v))
                        elseif data.k == "b" then
                            pcall(attr.setValue, attr, data.v == true)
                        else
                            local val = tonumber(data.v)
                            if val then pcall(attr.setValueFloat, attr, val) end
                        end
                        break
                    end
                end
            end
        end
    end
end

function ItemEditorServer.apply(item, args)
    local vals = args.values
    if type(vals) == "table" then
        for getter, val in pairs(vals) do
            ItemEditorServer.applyValue(item, getter, val)
        end
        ItemEditorServer.applySideEffects(item, vals)
    end
    ItemEditorServer.applyColor(item, args.color)
    ItemEditorServer.applyAttributes(item, args.attributes)
end

function ItemEditorServer.broadcast(cont, item)
    if cont then
        local ok = pcall(sendReplaceItemInContainer, cont, item, item)
        if ok then return end
    end
    pcall(item.syncItemFields, item)
end

function ItemEditorServer.onClientCommand(module, command, player, args)
    if module ~= ItemEditorServer.module or command ~= ItemEditorServer.command then return end
    if not player or not args then return end
    local role = player.getRole and player:getRole() or nil
    if not role or not role:hasCapability(Capability.EditItem) then return end
    local cont, item = ItemEditorServer.findItem(args)
    if not item then return end
    ItemEditorServer.apply(item, args)
    ItemEditorServer.broadcast(cont, item)
end

Events.OnClientCommand.Remove(ItemEditorServer.onClientCommand)
Events.OnClientCommand.Add(ItemEditorServer.onClientCommand)
