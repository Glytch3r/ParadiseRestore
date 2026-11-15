if not isClient() then return end

ParadiseRestore = ParadiseRestore or {}
ParadiseRestore.ItemEditor = ParadiseRestore.ItemEditor or {}
local ItemEditor = ParadiseRestore.ItemEditor

ItemEditor.module = "ParadiseRestore.ItemEditor"
ItemEditor.command = "saveItem"

local TYPE_COLOR = 3

function ItemEditor.getSquare(item)
    local cont = item:getContainer()
    if cont then
        local sq = cont:getSquare()
        if sq then return sq end
        local worldItem = cont.getWorldItem and cont:getWorldItem() or nil
        if worldItem and worldItem.getSquare then
            sq = worldItem:getSquare()
            if sq then return sq end
        end
    end
    local worldItem = item.getWorldItem and item:getWorldItem() or nil
    if worldItem and worldItem.getSquare then return worldItem:getSquare() end
    return nil
end

function ItemEditor.getOwnerId(item)
    local pl = item:getPlayer()
    if pl then return pl:getOnlineID() end
    return nil
end

function ItemEditor.collectAttribute(data, elem)
    local attr = elem.attribute
    local kind = elem.attributeType:getValueType()
    if AttributeValueType.IsNumeric(kind) then
        data.attributes[#data.attributes + 1] = { id = elem.attributeType:id(), k = "n", v = attr:getFloatValue() }
    elseif kind == AttributeValueType.String then
        data.attributes[#data.attributes + 1] = { id = elem.attributeType:id(), k = "s", v = attr:getValue() }
    elseif kind == AttributeValueType.Boolean then
        data.attributes[#data.attributes + 1] = { id = elem.attributeType:id(), k = "b", v = attr:getValue() }
    end
end

function ItemEditor.collectColor(data, item, elem)
    local col = item[elem.funcGet](item)
    if not col then return end
    data.color = { r = col:getRedFloat(), g = col:getGreenFloat(), b = col:getBlueFloat() }
end

function ItemEditor.collect(panel)
    local item = panel and panel.item or nil
    local elems = panel and panel.usedElems or nil
    if not item or not elems then return nil end
    local sq = ItemEditor.getSquare(item)
    local data = {
        id = item:getID(),
        fullType = item:getFullType(),
        ownerId = ItemEditor.getOwnerId(item),
        x = sq and sq:getX() or nil,
        y = sq and sq:getY() or nil,
        z = sq and sq:getZ() or nil,
        values = {},
        attributes = {},
    }
    for i = 1, #elems do
        local elem = elems[i]
        if elem.editable then
            if elem.isAttribute then
                ItemEditor.collectAttribute(data, elem)
            elseif elem.type == TYPE_COLOR then
                ItemEditor.collectColor(data, item, elem)
            elseif elem.funcGet and elem.funcSet and item[elem.funcGet] then
                local val = item[elem.funcGet](item)
                if type(val) == "number" or type(val) == "string" or type(val) == "boolean" then
                    data.values[elem.funcGet] = val
                end
            end
        end
    end
    return data
end

function ItemEditor.send(data)
    local pl = getPlayer()
    if not pl or not data then return end
    sendClientCommand(pl, ItemEditor.module, ItemEditor.command, data)
end

function ItemEditor.shimAttr(key, attr)
    return setmetatable({
        getValueFloat = function() return attr:getFloatValue() end,
        getValueString = function() return attr:getValue() end,
        setValueFloat = function(_, val) return attr:setValue(val) end,
        getIsReadOnly = function() return attr:isReadOnly() end,
        hasBounds = function() return key.hasBounds and key:hasBounds() or false end,
        getMin = function() return key:getMin() end,
        getMax = function() return key:getMax() end,
    }, { __index = function(_, name)
        local func = attr[name]
        if type(func) == "function" then
            return function(_, ...) return func(attr, ...) end
        end
        return func
    end })
end

function ItemEditor.shimAttrType(key)
    return setmetatable({
        getTooltipName = function() return key:getNameUI() end,
    }, { __index = function(_, name)
        local func = key[name]
        if type(func) == "function" then
            return function(_, ...) return func(key, ...) end
        end
        return func
    end })
end

function ItemEditor.patchVanilla()
    local sand = SandboxVars and SandboxVars.ParadiseZ
    if sand and sand.ApplyItemEditorPatch == false then return end
    local class = ISItemEditPanel
    if type(class) ~= "table" or type(class.registerAttributeNumber) ~= "function" then return end
    if ItemEditor.registerAttributeNumber == class.registerAttributeNumber then return end
    local names = { "registerAttributeNumber", "registerAttributeString", "registerAttributeBool" }
    for i = 1, #names do
        local name = names[i]
        local orig = class[name]
        ItemEditor["orig_" .. name] = orig
        ItemEditor[name] = function(self, key, attr)
            return orig(self, ItemEditor.shimAttrType(key), ItemEditor.shimAttr(key, attr))
        end
        class[name] = ItemEditor[name]
    end
end

function ItemEditor.install()
    ItemEditor.patchVanilla()
    local class = ISItemEditPanel
    if type(class) ~= "table" or type(class.saveAll) ~= "function" then return end
    if ItemEditor.saveAll == class.saveAll then return end
    local orig = class.saveAll
    ItemEditor.origSaveAll = orig
    ItemEditor.saveAll = function(self, ...)
        local result = orig(self, ...)
        ItemEditor.send(ItemEditor.collect(self))
        return result
    end
    class.saveAll = ItemEditor.saveAll
end
Events.OnGameStart.Remove(ItemEditor.install)
Events.OnGameStart.Add(ItemEditor.install)
