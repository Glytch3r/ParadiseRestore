
ParadiseDev = ParadiseDev or {}
ParadiseDev.Sniffer = ParadiseDev.Sniffer or {}

local Sniffer = ParadiseDev.Sniffer

Sniffer.window = Sniffer.window or nil
Sniffer.picker = Sniffer.picker or nil
Sniffer.maxDepth = 4
Sniffer.maxRows = 400
Sniffer.categories = {
    { key = "square", label = "Square" },
    { key = "tiles", label = "Tiles" },
    { key = "objects", label = "Objects" },
    { key = "items", label = "Items" },
    { key = "cars", label = "Cars" },
    { key = "players", label = "Players" },
    { key = "zombies", label = "Zombies" },
    { key = "animals", label = "Animals" },
    { key = "corpses", label = "Corpses" },
}
Sniffer.classes = {
    "IsoPlayer",
    "IsoZombie",
    "IsoAnimal",
    "IsoDeadBody",
    "BaseVehicle",
    "IsoWorldInventoryObject",
    "IsoThumpable",
    "IsoWindow",
    "IsoDoor",
    "IsoTree",
    "InventoryItem",
    "IsoGridSquare",
    "IsoSprite",
    "IsoMovingObject",
    "IsoObject",
}

function Sniffer.isType(obj, className)
    if not obj or not instanceof then return false end
    local ok, result = pcall(instanceof, obj, className)
    return ok and result or false
end

function Sniffer.call(obj, method, ...)
    if not obj or not method then return nil end
    local fn = obj[method]
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, obj, ...)
    if not ok then return nil end
    return result
end

function Sniffer.classOf(obj)
    for _, className in ipairs(Sniffer.classes) do
        if Sniffer.isType(obj, className) then return className end
    end
    return "unknown"
end

function Sniffer.labelFor(key)
    for _, definition in ipairs(Sniffer.categories) do
        if definition.key == key then return definition.label end
    end
    return tostring(key)
end

function Sniffer.categoryOrder(key)
    for index, definition in ipairs(Sniffer.categories) do
        if definition.key == key then return index end
    end
    return #Sniffer.categories + 1
end

function Sniffer.getSpriteName(obj)
    if not obj then return nil end
    local spr = Sniffer.call(obj, "getSprite")
    local name = spr and Sniffer.call(spr, "getName")
    if name and tostring(name) ~= "" then return tostring(name) end
    name = Sniffer.call(obj, "getSpriteName")
    if name and tostring(name) ~= "" then return tostring(name) end
    return nil
end

function Sniffer.describe(obj)
    if not obj then return "nil" end
    if Sniffer.isType(obj, "InventoryItem") then
        local fullType = Sniffer.call(obj, "getFullType")
        if fullType and tostring(fullType) ~= "" then return tostring(fullType) end
    end
    if Sniffer.isType(obj, "BaseVehicle") then
        local script = Sniffer.call(obj, "getScript")
        local fullName = script and Sniffer.call(script, "getFullName")
        if fullName and tostring(fullName) ~= "" then return tostring(fullName) end
        local scriptName = Sniffer.call(obj, "getScriptName")
        if scriptName and tostring(scriptName) ~= "" then return tostring(scriptName) end
    end
    if Sniffer.isType(obj, "IsoPlayer") then
        local user = Sniffer.call(obj, "getUsername")
        if user and tostring(user) ~= "" then return tostring(user) end
    end
    if Sniffer.isType(obj, "IsoZombie") then
        local outfit = Sniffer.call(obj, "getOutfitName")
        if outfit and tostring(outfit) ~= "" then return tostring(outfit) end
    end
    local spriteName = Sniffer.getSpriteName(obj)
    if spriteName then return spriteName end
    local display = Sniffer.call(obj, "getDisplayName")
    if display and tostring(display) ~= "" then return tostring(display) end
    return tostring(obj)
end

function Sniffer.coordsText(sq)
    if not sq then return "-,-,-" end
    return tostring(Sniffer.call(sq, "getX") or "-")
        .. "," .. tostring(Sniffer.call(sq, "getY") or "-")
        .. "," .. tostring(Sniffer.call(sq, "getZ") or "-")
end

function Sniffer.squareOf(obj)
    if not obj then return nil end
    if Sniffer.isType(obj, "IsoGridSquare") then return obj end
    return Sniffer.call(obj, "getSquare")
end

function Sniffer.vehicleOnSquare(car, sq)
    if not car or not sq then return false end
    if Sniffer.call(car, "getSquare") == sq then return true end
    local x = Sniffer.call(sq, "getX")
    local y = Sniffer.call(sq, "getY")
    if not x or not y then return false end
    local ok, inside = pcall(function() return car:isInBounds(x + 0.5, y + 0.5) end)
    return ok and inside or false
end

function Sniffer.itemKey(item)
    local id = tonumber(Sniffer.call(item, "getID"))
    if id and id > 0 then return "items|" .. tostring(id) end
    return "items|" .. tostring(item)
end

function Sniffer.addItemContainer(list, seen, cont, ownerName)
    if not cont then return end
    local items = Sniffer.call(cont, "getItems")
    if not items then return end
    for index = 0, items:size() - 1 do
        local item = items:get(index)
        if item then
            local key = Sniffer.itemKey(item)
            if not seen[key] then
                seen[key] = true
                local name = Sniffer.describe(item)
                if ownerName then name = name .. " (" .. ownerName .. ")" end
                list[#list + 1] = {
                    obj = item,
                    category = "items",
                    name = name,
                    containerName = ownerName,
                }
            end
        end
    end
end

function Sniffer.addWorldItem(list, seen, item, ownerName)
    if not item then return end
    local key = Sniffer.itemKey(item)
    if seen[key] then return end
    seen[key] = true
    local name = Sniffer.describe(item)
    if ownerName then name = name .. " (" .. ownerName .. ")" end
    list[#list + 1] = {
        obj = item,
        category = "items",
        name = name,
        containerName = ownerName,
    }
end

function Sniffer.scanSquare(sq)
    local list, seen = {}, {}
    if not sq then return list end

    list[#list + 1] = {
        obj = sq,
        category = "square",
        name = "Square " .. Sniffer.coordsText(sq),
    }

    local tileSeen = {}
    local function addTile(obj)
        if not obj then return end
        local spriteName = Sniffer.getSpriteName(obj)
        if not spriteName or tileSeen[spriteName] then return end
        tileSeen[spriteName] = true
        list[#list + 1] = {
            obj = obj,
            category = "tiles",
            name = spriteName,
            tileName = spriteName,
        }
    end

    local floor = Sniffer.call(sq, "getFloor")
    if floor then
        addTile(floor)
        Sniffer.addItemContainer(list, seen, Sniffer.call(floor, "getContainer"), "Floor Container")
    end

    local objects = Sniffer.call(sq, "getObjects")
    if objects then
        for index = 0, objects:size() - 1 do
            local obj = objects:get(index)
            if obj then
                addTile(obj)
                local key = "objects|" .. tostring(obj)
                if not seen[key] then
                    seen[key] = true
                    list[#list + 1] = {
                        obj = obj,
                        category = "objects",
                        name = Sniffer.describe(obj),
                        objectIndex = index,
                    }
                end
                if Sniffer.isType(obj, "IsoWorldInventoryObject") then
                    Sniffer.addWorldItem(list, seen, Sniffer.call(obj, "getItem"), "World Item")
                end
                local cont = Sniffer.call(obj, "getContainer")
                if cont then
                    local contType = tostring(Sniffer.call(cont, "getType") or "container")
                    Sniffer.addItemContainer(list, seen, cont, "Container: " .. contType)
                end
            end
        end
    end

    local worldObjects = Sniffer.call(sq, "getWorldObjects")
    if worldObjects then
        for index = 0, worldObjects:size() - 1 do
            local worldObj = worldObjects:get(index)
            if worldObj then
                Sniffer.addWorldItem(list, seen, Sniffer.call(worldObj, "getItem"), "World Item")
            end
        end
    end

    local cell = getCell and getCell() or nil
    local vehicles = cell and Sniffer.call(cell, "getVehicles")
    if vehicles then
        for index = 0, vehicles:size() - 1 do
            local car = vehicles:get(index)
            if car and Sniffer.vehicleOnSquare(car, sq) then
                local key = "cars|" .. tostring(car)
                if not seen[key] then
                    seen[key] = true
                    list[#list + 1] = {
                        obj = car,
                        category = "cars",
                        name = Sniffer.describe(car),
                    }
                    local partCount = Sniffer.call(car, "getPartCount")
                    if partCount then
                        for partIndex = 0, partCount - 1 do
                            local part = Sniffer.call(car, "getPartByIndex", partIndex)
                            local cont = part and Sniffer.call(part, "getItemContainer")
                            if cont then
                                local partId = tostring(Sniffer.call(part, "getId") or partIndex)
                                Sniffer.addItemContainer(list, seen, cont, "Car: " .. partId)
                            end
                        end
                    end
                end
            end
        end
    end

    local function addMoving(collection)
        if not collection then return end
        for index = 0, collection:size() - 1 do
            local moving = collection:get(index)
            if moving then
                local category = "objects"
                if Sniffer.isType(moving, "IsoPlayer") then
                    category = "players"
                elseif Sniffer.isType(moving, "IsoZombie") then
                    category = "zombies"
                elseif Sniffer.isType(moving, "IsoDeadBody") then
                    category = "corpses"
                elseif Sniffer.isType(moving, "IsoAnimal") then
                    category = "animals"
                end
                local key = category .. "|" .. tostring(moving)
                if not seen[key] then
                    seen[key] = true
                    list[#list + 1] = {
                        obj = moving,
                        category = category,
                        name = Sniffer.describe(moving),
                    }
                end
            end
        end
    end
    addMoving(Sniffer.call(sq, "getMovingObjects"))
    addMoving(Sniffer.call(sq, "getStaticMovingObjects"))

    local online = getOnlinePlayers and getOnlinePlayers() or nil
    if online then
        for index = 0, online:size() - 1 do
            local other = online:get(index)
            if other and Sniffer.squareOf(other) == sq then
                local key = "players|" .. tostring(other)
                if not seen[key] then
                    seen[key] = true
                    list[#list + 1] = {
                        obj = other,
                        category = "players",
                        name = Sniffer.describe(other),
                    }
                end
            end
        end
    end

    local localPlayer = getPlayer and getPlayer() or nil
    if localPlayer and Sniffer.squareOf(localPlayer) == sq then
        local key = "players|" .. tostring(localPlayer)
        if not seen[key] then
            seen[key] = true
            list[#list + 1] = {
                obj = localPlayer,
                category = "players",
                name = Sniffer.describe(localPlayer),
            }
        end
    end

    table.sort(list, function(left, right)
        local leftOrder = Sniffer.categoryOrder(left.category)
        local rightOrder = Sniffer.categoryOrder(right.category)
        if leftOrder ~= rightOrder then return leftOrder < rightOrder end
        return tostring(left.name) < tostring(right.name)
    end)

    return list
end

function Sniffer.addInfoRow(list, label, value)
    if value == nil then return end
    local text = tostring(value)
    if text == "" then return end
    list:addItem(tostring(label) .. " = " .. text)
end

function Sniffer.addPropertyRows(list, props, title)
    if not props then return end
    local names = Sniffer.call(props, "getPropertyNames")
    if names and names:size() > 0 then
        list:addItem("--- " .. tostring(title) .. " Properties ---")
        for index = 0, names:size() - 1 do
            local name = names:get(index)
            Sniffer.addInfoRow(list, " " .. tostring(name), Sniffer.call(props, "get", tostring(name)))
        end
    end
    local flags = Sniffer.call(props, "getFlagsList")
    if flags and flags:size() > 0 then
        list:addItem("--- " .. tostring(title) .. " Flags ---")
        for index = 0, flags:size() - 1 do
            local flag = flags:get(index)
            list:addItem(" " .. tostring(Sniffer.call(flag, "toString") or flag))
        end
    end
end

function Sniffer.addSpriteRows(list, obj)
    local spr = Sniffer.call(obj, "getSprite")
    if not spr then return end
    Sniffer.addInfoRow(list, "Sprite", Sniffer.call(spr, "getName"))
    local tileType = Sniffer.call(spr, "getTileType")
    if tileType then
        Sniffer.addInfoRow(list, "Sprite Type", Sniffer.call(tileType, "toString") or tileType)
    end
    Sniffer.addInfoRow(list, "Sprite ID", Sniffer.call(spr, "getID"))
    Sniffer.addPropertyRows(list, Sniffer.call(spr, "getProperties"), "Sprite")
end

function Sniffer.addItemRows(list, item)
    if not item then return end
    Sniffer.addInfoRow(list, "ID", Sniffer.call(item, "getID"))
    Sniffer.addInfoRow(list, "Full Type", Sniffer.call(item, "getFullType"))
    Sniffer.addInfoRow(list, "Name", Sniffer.call(item, "getName"))
    Sniffer.addInfoRow(list, "Display Name", Sniffer.call(item, "getDisplayName"))
    Sniffer.addInfoRow(list, "Item Category", Sniffer.call(item, "getCategory"))
    Sniffer.addInfoRow(list, "Weight", Sniffer.call(item, "getWeight"))
    local condition = Sniffer.call(item, "getCondition")
    if condition ~= nil then
        Sniffer.addInfoRow(list, "Condition", tostring(condition) .. "/" .. tostring(Sniffer.call(item, "getConditionMax")))
    end
    local scriptItem = Sniffer.call(item, "getScriptItem")
    if scriptItem then
        Sniffer.addInfoRow(list, "Script Type", Sniffer.call(scriptItem, "getFullName") or Sniffer.call(scriptItem, "getName"))
    end
end

function Sniffer.addVehicleRows(list, car)
    if not car then return end
    local script = Sniffer.call(car, "getScript")
    if script then Sniffer.addInfoRow(list, "Script", Sniffer.call(script, "getFullName")) end
    Sniffer.addInfoRow(list, "Script Name", Sniffer.call(car, "getScriptName"))
    Sniffer.addInfoRow(list, "Vehicle Type", Sniffer.call(car, "getVehicleType"))
    Sniffer.addInfoRow(list, "SQL ID", Sniffer.call(car, "getSqlId"))
    Sniffer.addInfoRow(list, "Part Count", Sniffer.call(car, "getPartCount"))
end

function Sniffer.addSquareRows(list, sq, includeProperties)
    if not sq then return end
    Sniffer.addInfoRow(list, "x,y,z", Sniffer.coordsText(sq))
    Sniffer.addInfoRow(list, "Outside", Sniffer.call(sq, "isOutside"))
    local zone = Sniffer.call(sq, "getZone")
    if zone then
        Sniffer.addInfoRow(list, "Zone", tostring(Sniffer.call(zone, "getName") or "?")
            .. " / " .. tostring(Sniffer.call(zone, "getType") or "?"))
    end
    local room = Sniffer.call(sq, "getRoom")
    if room then
        local roomDef = Sniffer.call(room, "getRoomDef")
        if roomDef then Sniffer.addInfoRow(list, "Room", Sniffer.call(roomDef, "getName")) end
        Sniffer.addInfoRow(list, "Room ID", Sniffer.call(sq, "getRoomIDString"))
    end
    local building = Sniffer.call(sq, "getBuilding")
    if building then Sniffer.addInfoRow(list, "Building ID", Sniffer.call(building, "getID")) end
    if includeProperties then
        Sniffer.addPropertyRows(list, Sniffer.call(sq, "getProperties"), "Square")
    end
end

function Sniffer.addDetailRows(list, entry, sq)
    if not entry then
        list:addItem("No entry selected.")
        return
    end
    local obj = entry.obj
    Sniffer.addInfoRow(list, "Category", Sniffer.labelFor(entry.category))
    Sniffer.addInfoRow(list, "Class", Sniffer.classOf(obj))
    Sniffer.addInfoRow(list, "Object", tostring(obj))
    if not Sniffer.isType(obj, "InventoryItem") then
        Sniffer.addInfoRow(list, "World X", Sniffer.call(obj, "getX"))
        Sniffer.addInfoRow(list, "World Y", Sniffer.call(obj, "getY"))
        Sniffer.addInfoRow(list, "World Z", Sniffer.call(obj, "getZ"))
    end
    if entry.tileName then Sniffer.addInfoRow(list, "Tile", entry.tileName) end
    if entry.containerName then Sniffer.addInfoRow(list, "Container", entry.containerName) end

    if Sniffer.isType(obj, "InventoryItem") then
        Sniffer.addItemRows(list, obj)
    elseif Sniffer.isType(obj, "BaseVehicle") then
        Sniffer.addVehicleRows(list, obj)
    elseif Sniffer.isType(obj, "IsoPlayer") then
        Sniffer.addInfoRow(list, "Username", Sniffer.call(obj, "getUsername"))
        Sniffer.addInfoRow(list, "Display Name", Sniffer.call(obj, "getDisplayName"))
        Sniffer.addInfoRow(list, "Online ID", Sniffer.call(obj, "getOnlineID"))
        Sniffer.addInfoRow(list, "Alive", Sniffer.call(obj, "isAlive"))
    elseif Sniffer.isType(obj, "IsoWorldInventoryObject") then
        Sniffer.addItemRows(list, Sniffer.call(obj, "getItem"))
    end

    if Sniffer.isType(obj, "IsoObject") then
        Sniffer.addInfoRow(list, "Object Index", Sniffer.call(obj, "getObjectIndex"))
        Sniffer.addInfoRow(list, "Render Y Offset", Sniffer.call(obj, "getRenderYOffset"))
        local cont = Sniffer.call(obj, "getContainer")
        if cont then
            Sniffer.addInfoRow(list, "Container Type", Sniffer.call(cont, "getType"))
            Sniffer.addInfoRow(list, "Container Capacity", Sniffer.call(cont, "getCapacity"))
            local items = Sniffer.call(cont, "getItems")
            if items then Sniffer.addInfoRow(list, "Container Items", items:size()) end
        end
        Sniffer.addSpriteRows(list, obj)
    end

    if Sniffer.isType(obj, "IsoSprite") then
        Sniffer.addInfoRow(list, "Sprite", Sniffer.call(obj, "getName"))
        Sniffer.addInfoRow(list, "Sprite ID", Sniffer.call(obj, "getID"))
        Sniffer.addPropertyRows(list, Sniffer.call(obj, "getProperties"), "Sprite")
    end

    Sniffer.addSquareRows(list, sq, entry.category == "square")
end

function Sniffer.addFieldRows(list, obj)
    if not obj then
        list:addItem("No object selected.")
        return
    end
    local okCount, count = pcall(getNumClassFields, obj)
    if not okCount or not count or count <= 0 then
        list:addItem("No readable Java fields.")
        return
    end
    for index = 0, count - 1 do
        local okField, field = pcall(getClassField, obj, index)
        if okField and field then
            local okName, name = pcall(field.getName, field)
            local okValue, value = pcall(field.get, field, obj)
            list:addItem(tostring(okName and name or index) .. " = " .. (okValue and tostring(value) or "<unreadable>"))
        end
    end
end

function Sniffer.addTableRows(list, value, path, depth, seen, rowCount)
    if rowCount[1] >= Sniffer.maxRows then return end
    if type(value) ~= "table" then
        list:addItem(path .. " = " .. tostring(value))
        rowCount[1] = rowCount[1] + 1
        return
    end
    if seen[value] then
        list:addItem(path .. " = <recursive>")
        rowCount[1] = rowCount[1] + 1
        return
    end
    if depth >= Sniffer.maxDepth then
        list:addItem(path .. " = <max depth>")
        rowCount[1] = rowCount[1] + 1
        return
    end
    seen[value] = true
    for key, child in pairs(value) do
        if rowCount[1] >= Sniffer.maxRows then break end
        Sniffer.addTableRows(list, child, path .. "[" .. tostring(key) .. "]", depth + 1, seen, rowCount)
    end
    seen[value] = nil
end

function Sniffer.addModDataRows(list, obj)
    if not obj then
        list:addItem("No object selected.")
        return
    end
    if not Sniffer.call(obj, "hasModData") then
        list:addItem("No ModData found.")
        return
    end
    local modData = Sniffer.call(obj, "getModData")
    if not modData then
        list:addItem("ModData could not be read.")
        return
    end
    Sniffer.addTableRows(list, modData, "ModData", 0, {}, { 0 })
end

function Sniffer.getColumnText(list)
    local lines = {}
    for _, row in ipairs((list and list.items) or {}) do
        lines[#lines + 1] = tostring(row.text or "")
    end
    return table.concat(lines, "\n")
end

function Sniffer.copyDetails(panel)
    if not panel or not Clipboard or not Clipboard.setClipboard then return end
    local entry = panel:getSelectedEntry()
    local text = "Data Sniffer " .. Sniffer.coordsText(panel.square)
        .. "\nEntry: " .. tostring(entry and entry.name or "None")
        .. "\n\nInfo\n\n" .. Sniffer.getColumnText(panel.info)
        .. "\n\nJava Fields\n\n" .. Sniffer.getColumnText(panel.fields)
        .. "\n\nModData\n\n" .. Sniffer.getColumnText(panel.modData)
    Clipboard.setClipboard(text)
end

function Sniffer.startPick()
    Sniffer.cancelPick()
    local core = getCore()
    local picker = Sniffer.Picker:new(0, 0, core:getScreenWidth(), core:getScreenHeight())
    picker:initialise()
    picker:addToUIManager()
    picker:setAlwaysOnTop(true)
    picker:setWantMouseEvents(true)
    picker:setVisible(true)
    Sniffer.picker = picker
    Sniffer.pickerDown = isMouseButtonDown(0) or isMouseButtonDown(1)
    if ParadiseAdminHub and type(ParadiseAdminHub.ClosePanel) == "function" then
        ParadiseAdminHub.ClosePanel()
    end
end

function Sniffer.cancelPick()
    local picker = Sniffer.picker
    if not picker then return end
    Sniffer.picker = nil
    picker:setVisible(false)
    picker:removeFromUIManager()
end

function Sniffer.squareUnderMouse()
    if IsoObjectPicker and IsoObjectPicker.Instance then
        local okPick, click = pcall(IsoObjectPicker.Instance.ContextPick, IsoObjectPicker.Instance, getMouseX(), getMouseY())
        if okPick and click then
            local okSquare, sq = pcall(function() return click.square end)
            if okSquare and sq then return sq end
        end
    end
    local pl = getPlayer()
    if not pl then return nil end
    local level = math.floor(pl:getZ())
    if not ISCoordConversion then return nil end
    local wx, wy = ISCoordConversion.ToWorld(getMouseXScaled(), getMouseYScaled(), level)
    if not wx or not wy then return nil end
    return getCell():getGridSquare(math.floor(wx), math.floor(wy), level)
end

function Sniffer.sniffUnderMouse()
    if not Sniffer.picker then return end
    local sq = Sniffer.squareUnderMouse()
    if not sq then return end
    Sniffer.cancelPick()
    if type(Sniffer.OpenPanel) == "function" then
        Sniffer.OpenPanel(sq)
    end
end

function Sniffer.onTick()
    if not Sniffer.picker then return end
    if isMouseButtonDown(1) then
        Sniffer.cancelPick()
        return
    end
    local down = isMouseButtonDown(0)
    if down and not Sniffer.pickerDown then
        Sniffer.sniffUnderMouse()
        return
    end
    Sniffer.pickerDown = down
end
Events.OnTick.Remove(Sniffer.onTick)
Events.OnTick.Add(Sniffer.onTick)

function Sniffer.onKeyPressed(key)
    if not Sniffer.picker then return end
    if key == Keyboard.KEY_ESCAPE then
        Sniffer.cancelPick()
    end
end
Events.OnKeyPressed.Remove(Sniffer.onKeyPressed)
Events.OnKeyPressed.Add(Sniffer.onKeyPressed)

Sniffer.Picker = ISPanel:derive("ParadiseDev.Sniffer.Picker")

function Sniffer.Picker:render()
    local text = "Data Sniffer: left-click a square (right-click or Esc to cancel)"
    getTextManager():DrawString(UIFont.Small, getMouseX() + 18, getMouseY() + 18, text, 1, 0.85, 0.25, 0.95)
end

function Sniffer.Picker:onMouseDown(x, y)
    Sniffer.sniffUnderMouse()
    return true
end

function Sniffer.Picker:onRightMouseDown(x, y)
    Sniffer.cancelPick()
    return true
end

function Sniffer.Picker:new(x, y, width, height)
    local panel = ISPanel:new(x, y, width, height)
    setmetatable(panel, self)
    self.__index = self
    panel.background = false
    panel.moveWithMouse = false
    return panel
end

Sniffer.Panel = ISCollapsableWindow:derive("ParadiseDev.Sniffer.Panel")

function Sniffer.updateScrollWidth(list)
    if not list then return end
    local width = list:getWidth()
    for _, row in ipairs(list.items or {}) do
        width = math.max(width, getTextManager():MeasureStringX(list.font, tostring(row.text or "")) + 30)
    end
    list:setScrollWidth(width)
end

function Sniffer.resizeWindow(panel, newWidth, newHeight)
    if not panel then return end
    local core = getCore()
    local maxWidth = math.max(120, core:getScreenWidth() - panel:getX())
    local maxHeight = math.max(120, core:getScreenHeight() - panel:getY())
    local minWidth = math.min(panel.minimumWidth or 120, maxWidth)
    local minHeight = math.min(panel.minimumHeight or 120, maxHeight)
    panel:setWidth(math.max(minWidth, math.min(newWidth, maxWidth)))
    panel:setHeight(math.max(minHeight, math.min(newHeight, maxHeight)))
    if panel.layoutChildren then panel:layoutChildren() end
end

function Sniffer.enableWindowResize(panel)
    panel:setResizable(true)
    if panel.resizeWidget then panel.resizeWidget.resizeFunction = Sniffer.resizeWindow end
    if panel.resizeWidget2 then panel.resizeWidget2.resizeFunction = Sniffer.resizeWindow end
end

function Sniffer.Panel:createChildren()
    ISCollapsableWindow.createChildren(self)
    Sniffer.enableWindowResize(self)
    local top = self:titleBarHeight() + 8
    self.titleLabel = ISLabel:new(12, top, 18, "Data Sniffer", 0.85, 0.9, 1, 1, UIFont.Medium, true)
    self.titleLabel:initialise()
    self.titleLabel:instantiate()
    self:addChild(self.titleLabel)
    self.data = self.data or {}
    self.visibleCategories = {}
    self.typeFilterGroups = {}
    for index, definition in ipairs(Sniffer.categories) do
        self.visibleCategories[definition.key] = true
        local groupIndex = math.ceil(index / 3)
        local filter = self.typeFilterGroups[groupIndex]
        if not filter then
            filter = ISTickBox:new(0, 0, 200, 20, "", self, Sniffer.Panel.onTypeFilterChanged)
            filter:initialise()
            filter:instantiate()
            self.typeFilterGroups[groupIndex] = filter
            self:addChild(filter)
        end
        local optionIndex = filter:addOption(definition.label, definition.key)
        filter:setSelected(optionIndex, true)
    end
    self.entries = ISScrollingListBox:new(12, top + 116, 300, self.height - top - 176)
    self.entries:initialise()
    self.entries:instantiate()
    self.entries:addScrollBars(true)
    self.entries.itemheight = 22
    self.entries.font = UIFont.Small
    self.entries.drawBorder = true
    self.entries:setOnMouseDownFunction(self, Sniffer.Panel.onEntrySelected)
    self:addChild(self.entries)
    self.info = ISScrollingListBox:new(320, top + 116, 330, self.height - top - 176)
    self.info:initialise()
    self.info:instantiate()
    self.info:addScrollBars(true)
    self.info.itemheight = 22
    self.info.font = UIFont.Small
    self.info.drawBorder = true
    self:addChild(self.info)
    self.fields = ISScrollingListBox:new(658, top + 116, 330, self.height - top - 176)
    self.fields:initialise()
    self.fields:instantiate()
    self.fields:addScrollBars(true)
    self.fields.itemheight = 22
    self.fields.font = UIFont.Small
    self.fields.drawBorder = true
    self:addChild(self.fields)
    self.modData = ISScrollingListBox:new(996, top + 116, self.width - 1008, self.height - top - 176)
    self.modData:initialise()
    self.modData:instantiate()
    self.modData:addScrollBars(true)
    self.modData.itemheight = 22
    self.modData.font = UIFont.Small
    self.modData.drawBorder = true
    self:addChild(self.modData)
    self.refreshButton = ISButton:new(12, self.height - 40, 90, 26, "Refresh", self, Sniffer.Panel.onClick)
    self.refreshButton.internal = "REFRESH"
    self.refreshButton:initialise()
    self.refreshButton:instantiate()
    self:addChild(self.refreshButton)
    self.pickButton = ISButton:new(108, self.height - 40, 90, 26, "Pick Square", self, Sniffer.Panel.onClick)
    self.pickButton.internal = "RESCAN"
    self.pickButton:initialise()
    self.pickButton:instantiate()
    self:addChild(self.pickButton)
    self.copyButton = ISButton:new(204, self.height - 40, 80, 26, "Copy", self, Sniffer.Panel.onClick)
    self.copyButton.internal = "COPY"
    self.copyButton:initialise()
    self.copyButton:instantiate()
    self:addChild(self.copyButton)
    self.closeButton = ISButton:new(290, self.height - 40, 80, 26, "Close", self, Sniffer.Panel.onClick)
    self.closeButton.internal = "CLOSE"
    self.closeButton:initialise()
    self.closeButton:instantiate()
    self:addChild(self.closeButton)
    self.moveWButton = ISButton:new(376, self.height - 40, 40, 26, "W", self, Sniffer.Panel.onClick)
    self.moveWButton.internal = "MOVE_W"
    self.moveWButton:initialise()
    self.moveWButton:instantiate()
    self:addChild(self.moveWButton)
    self.moveEButton = ISButton:new(420, self.height - 40, 40, 26, "E", self, Sniffer.Panel.onClick)
    self.moveEButton.internal = "MOVE_E"
    self.moveEButton:initialise()
    self.moveEButton:instantiate()
    self:addChild(self.moveEButton)
    self.moveNButton = ISButton:new(464, self.height - 40, 40, 26, "N", self, Sniffer.Panel.onClick)
    self.moveNButton.internal = "MOVE_N"
    self.moveNButton:initialise()
    self.moveNButton:instantiate()
    self:addChild(self.moveNButton)
    self.moveSButton = ISButton:new(508, self.height - 40, 40, 26, "S", self, Sniffer.Panel.onClick)
    self.moveSButton.internal = "MOVE_S"
    self.moveSButton:initialise()
    self.moveSButton:instantiate()
    self:addChild(self.moveSButton)
    self.moveZMButton = ISButton:new(552, self.height - 40, 40, 26, "Z-", self, Sniffer.Panel.onClick)
    self.moveZMButton.internal = "MOVE_ZM"
    self.moveZMButton:initialise()
    self.moveZMButton:instantiate()
    self:addChild(self.moveZMButton)
    self.moveZPButton = ISButton:new(596, self.height - 40, 40, 26, "Z+", self, Sniffer.Panel.onClick)
    self.moveZPButton.internal = "MOVE_ZP"
    self.moveZPButton:initialise()
    self.moveZPButton:instantiate()
    self:addChild(self.moveZPButton)
    self:layoutChildren()
end

function Sniffer.Panel:layoutChildren()
    local contentX, spacing = 12, 8
    local contentWidth = self.width - contentX * 2
    local top = self:titleBarHeight() + 8
    self.titleLabel:setX(contentX)
    self.titleLabel:setY(top)
    local filtersY = top + 28
    local filterWidth = math.max(180, math.floor((contentWidth - spacing * 2) / 3))
    for index, filter in ipairs(self.typeFilterGroups) do
        filter:setX(contentX + (index - 1) * (filterWidth + spacing))
        filter:setY(filtersY)
        filter:setWidth(filterWidth)
    end
    local listsY = filtersY + 88
    local listsHeight = math.max(120, self.height - listsY - 52)
    local entriesWidth = math.max(230, math.floor(contentWidth * 0.22))
    local infoWidth = math.max(260, math.floor(contentWidth * 0.24))
    local fieldsWidth = math.max(300, math.floor(contentWidth * 0.28))
    local modDataWidth = math.max(200, contentWidth - entriesWidth - infoWidth - fieldsWidth - spacing * 3)
    local entriesX = contentX
    local infoX = entriesX + entriesWidth + spacing
    local fieldsX = infoX + infoWidth + spacing
    local modDataX = fieldsX + fieldsWidth + spacing
    self.entries:setX(entriesX); self.entries:setY(listsY); self.entries:setWidth(entriesWidth); self.entries:setHeight(listsHeight)
    self.info:setX(infoX); self.info:setY(listsY); self.info:setWidth(infoWidth); self.info:setHeight(listsHeight)
    self.fields:setX(fieldsX); self.fields:setY(listsY); self.fields:setWidth(fieldsWidth); self.fields:setHeight(listsHeight)
    self.modData:setX(modDataX); self.modData:setY(listsY); self.modData:setWidth(modDataWidth); self.modData:setHeight(listsHeight)
    local buttonY = self.height - 40
    self.refreshButton:setY(buttonY)
    self.pickButton:setY(buttonY)
    self.copyButton:setY(buttonY)
    self.closeButton:setY(buttonY)
    self.moveWButton:setY(buttonY)
    self.moveEButton:setY(buttonY)
    self.moveNButton:setY(buttonY)
    self.moveSButton:setY(buttonY)
    self.moveZMButton:setY(buttonY)
    self.moveZPButton:setY(buttonY)
    Sniffer.updateScrollWidth(self.entries)
    Sniffer.updateScrollWidth(self.info)
    Sniffer.updateScrollWidth(self.fields)
    Sniffer.updateScrollWidth(self.modData)
end

function Sniffer.Panel:getSelectedEntry()
    local row = self.entries.items[self.entries.selected]
    return row and row.item or nil
end

function Sniffer.Panel:scanSquare(sq)
    self.square = sq
    self.data = Sniffer.scanSquare(sq)
    self:refresh()
end

function Sniffer.Panel:moveSquare(dx, dy, dz)
    if not self.square then return end
    local x = Sniffer.call(self.square, "getX")
    local y = Sniffer.call(self.square, "getY")
    local z = Sniffer.call(self.square, "getZ")
    if not x or not y or not z then return end
    if z + dz < -32 or z + dz > 31 then return end
    local cell = getCell and getCell() or nil
    if not cell then return end
    local ok, sq = pcall(cell.getGridSquare, cell, x + dx, y + dy, z + dz)
    if not ok or not sq then return end
    self:scanSquare(sq)
end

function Sniffer.Panel:refresh(selected)
    local selectedEntry = self:getSelectedEntry()
    if type(selected) == "table" then selectedEntry = selected end
    if not self.entries then return end
    self.entries:clear()
    for _, entry in ipairs(self.data or {}) do
        if self.visibleCategories[entry.category] ~= false then
            self.entries:addItem("[" .. Sniffer.labelFor(entry.category) .. "] " .. entry.name, entry)
        end
    end
    if #self.entries.items == 0 then
        self.entries.selected = 0
    else
        self.entries.selected = 1
        for index, row in ipairs(self.entries.items) do
            if row.item == selectedEntry then
                self.entries.selected = index
                break
            end
        end
    end
    Sniffer.updateScrollWidth(self.entries)
    self:refreshDetails()
end

function Sniffer.Panel:refreshDetails()
    self.info:clear()
    self.fields:clear()
    self.modData:clear()
    local entry = self:getSelectedEntry()
    self.titleLabel:setName("Data Sniffer [" .. Sniffer.coordsText(self.square) .. "]: "
        .. tostring(entry and entry.name or "No selection"))
    Sniffer.addDetailRows(self.info, entry, self.square)
    Sniffer.addFieldRows(self.fields, entry and entry.obj)
    Sniffer.addModDataRows(self.modData, entry and entry.obj)
    Sniffer.updateScrollWidth(self.info)
    Sniffer.updateScrollWidth(self.fields)
    Sniffer.updateScrollWidth(self.modData)
end

function Sniffer.Panel:onEntrySelected()
    self:refreshDetails()
end

function Sniffer.Panel.onTypeFilterChanged(panel, index, selected, _, _, tickBox)
    if not panel or not tickBox then return end
    local category = tickBox:getOptionData(index)
    if not category then return end
    panel.visibleCategories[category] = selected
    panel:refresh(panel:getSelectedEntry())
end

function Sniffer.Panel:onClick(button)
    if button.internal == "REFRESH" then
        if self.square then self:scanSquare(self.square) end
    elseif button.internal == "RESCAN" then
        Sniffer.startPick()
    elseif button.internal == "COPY" then
        Sniffer.copyDetails(self)
    elseif button.internal == "MOVE_W" then
        self:moveSquare(-1, 0, 0)
    elseif button.internal == "MOVE_E" then
        self:moveSquare(1, 0, 0)
    elseif button.internal == "MOVE_N" then
        self:moveSquare(0, -1, 0)
    elseif button.internal == "MOVE_S" then
        self:moveSquare(0, 1, 0)
    elseif button.internal == "MOVE_ZM" then
        self:moveSquare(0, 0, -1)
    elseif button.internal == "MOVE_ZP" then
        self:moveSquare(0, 0, 1)
    elseif button.internal == "CLOSE" then
        Sniffer.ClosePanel()
    end
end

function Sniffer.Panel:close()
    Sniffer.ClosePanel()
end

function Sniffer.Panel:new(x, y, width, height)
    local panel = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(panel, self)
    self.__index = self
    panel.title = "ParadiseZ Data Sniffer"
    panel.minimumWidth = 1100
    panel.minimumHeight = 420
    panel.resizable = true
    return panel
end
