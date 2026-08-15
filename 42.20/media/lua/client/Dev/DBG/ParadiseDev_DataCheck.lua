ParadiseDev = ParadiseDev or {}
ParadiseDev.DataCheck = ParadiseDev.DataCheck or {}


ParadiseDev.DataCheck.entries = ParadiseDev.DataCheck.entries or {}
ParadiseDev.DataCheck.window = ParadiseDev.DataCheck.window or nil
ParadiseDev.DataCheck.maxDepth = 4
ParadiseDev.DataCheck.maxRows = 300

function ParadiseDev.DataCheck.isType(obj, className)
    if not obj or not instanceof then return false end
    local ok, result = pcall(instanceof, obj, className)
    return ok and result or false
end

function ParadiseDev.DataCheck.getSpriteName(obj)
    if not obj then return nil end
    if obj.getSprite then
        local okSprite, spr = pcall(obj.getSprite, obj)
        if okSprite and spr and spr.getName then
            local okName, name = pcall(spr.getName, spr)
            if okName and name and tostring(name) ~= "" then return tostring(name) end
        end
    end
    if obj.getSpriteName then
        local ok, name = pcall(obj.getSpriteName, obj)
        if ok and name and tostring(name) ~= "" then return tostring(name) end
    end
    return nil
end

function ParadiseDev.DataCheck.getVehicleName(obj)
    if not obj or not obj.getScript then return nil end
    local okScript, script = pcall(obj.getScript, obj)
    if not okScript or not script then return nil end
    if script.getFullName then
        local okName, name = pcall(script.getFullName, script)
        if okName and name and tostring(name) ~= "" then return tostring(name) end
    end
    if script.getName then
        local okName, name = pcall(script.getName, script)
        if okName and name and tostring(name) ~= "" then return tostring(name) end
    end
    return nil
end

function ParadiseDev.DataCheck.getInventoryItem(obj)
    if ParadiseDev.DataCheck.isType(obj, "InventoryItem") then return obj end
    if not obj or not obj.getItem then return nil end
    local ok, item = pcall(obj.getItem, obj)
    if ok and ParadiseDev.DataCheck.isType(item, "InventoryItem") then return item end
    return nil
end

function ParadiseDev.DataCheck.getObjectTexture(obj)
    if not obj or not getTexture then return nil end
    local spriteName = ParadiseDev.DataCheck.getSpriteName(obj)
    if spriteName then
        local ok, texture = pcall(getTexture, spriteName)
        if ok and texture then return texture end
    end
    if obj.getTexture then
        local ok, texture = pcall(obj.getTexture, obj)
        if ok and texture then return texture end
    end
    return nil
end

function ParadiseDev.DataCheck.setOptionIcon(option, obj)
    if not option or not obj then return end
    local item = ParadiseDev.DataCheck.getInventoryItem(obj)
    if item then
        option.itemForTexture = item
        return
    end
    local texture = ParadiseDev.DataCheck.getObjectTexture(obj)
    if texture then option.iconTexture = texture end
end

function ParadiseDev.DataCheck.objectName(obj, name)
    if name and name ~= "" then return tostring(name) end
    local item = ParadiseDev.DataCheck.getInventoryItem(obj)
    if item and item.getFullType then
        local ok, value = pcall(item.getFullType, item)
        if ok and value and tostring(value) ~= "" then return tostring(value) end
    end
    if ParadiseDev.DataCheck.isType(obj, "IsoZombie") and obj.getOutfitName then
        local ok, value = pcall(obj.getOutfitName, obj)
        if ok and value and tostring(value) ~= "" then return tostring(value) end
    end
    if ParadiseDev.DataCheck.isType(obj, "BaseVehicle") then
        local value = ParadiseDev.DataCheck.getVehicleName(obj)
        if value then return value end
    end
    local spriteName = ParadiseDev.DataCheck.getSpriteName(obj)
    if spriteName then return spriteName end
    if obj and obj.getDisplayName then
        local ok, value = pcall(obj.getDisplayName, obj)
        if ok and value then return tostring(value) end
    end
    if obj and obj.getObjectName then
        local ok, value = pcall(obj.getObjectName, obj)
        if ok and value then return tostring(value) end
    end
    return tostring(obj)
end

function ParadiseDev.DataCheck.find(obj)
    for index, entry in ipairs(ParadiseDev.DataCheck.entries) do
        if entry.obj == obj then return index end
    end
    return nil
end

function ParadiseDev.DataCheck.add(obj, name)
    if not obj then return nil end
    local index = ParadiseDev.DataCheck.find(obj)
    if index then return index end
    ParadiseDev.DataCheck.entries[#ParadiseDev.DataCheck.entries + 1] = {
        obj = obj,
        name = ParadiseDev.DataCheck.objectName(obj, name),
    }
    return #ParadiseDev.DataCheck.entries
end

function ParadiseDev.DataCheck.remove(index)
    if not index or index < 1 then return end
    table.remove(ParadiseDev.DataCheck.entries, index)
end

function ParadiseDev.DataCheck.clear()
    ParadiseDev.DataCheck.entries = {}
end

function ParadiseDev.DataCheck.open(obj, name)
    if not ParadiseDev.isAdm() then return end
    local index = ParadiseDev.DataCheck.add(obj, name) or 1
    if ParadiseDev.DataCheck.window then
        ParadiseDev.DataCheck.window:setVisible(true)
        ParadiseDev.DataCheck.window:bringToTop()
        ParadiseDev.DataCheck.window:refresh(index)
        return ParadiseDev.DataCheck.window
    end
    local window = ParadiseDev.DataCheck.Panel:new(60, 60, 980, 620)
    window:initialise()
    window:addToUIManager()
    window:setVisible(true)
    ParadiseDev.DataCheck.window = window
    window:refresh(index)
    return window
end

function ParadiseDev.DataCheck.close()
    local window = ParadiseDev.DataCheck.window
    if not window then return end
    window:setVisible(false)
    window:removeFromUIManager()
    ParadiseDev.DataCheck.window = nil
end

function ParadiseDev.DataCheck.getClickedSquare()
    if ISWorldObjectContextMenu and ISWorldObjectContextMenu.fetchVars then
        return ISWorldObjectContextMenu.fetchVars.clickedSquare
    end
    return clickedSquare
end

function ParadiseDev.DataCheck.addWorldObjectOption(menu, obj, name)
    if not menu or not obj then return end
    name = ParadiseDev.DataCheck.objectName(obj, name)
    local option = menu:addOption(name, obj, ParadiseDev.DataCheck.openSelected, name)
    ParadiseDev.DataCheck.setOptionIcon(option, obj)
    return option
end

function ParadiseDev.DataCheck.getInventoryItems(items)
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

function ParadiseDev.DataCheck.openSelected(obj, name)
    ParadiseDev.DataCheck.open(obj, name)
end

function ParadiseDev.DataCheck.addWorldContext(plNum, context, worldobjects, test)
    if test then return end
    if not getCore():getDebug() then return end

    local root = context:addOptionOnTop("Data")
    local submenu = ISContextMenu:getNew(context)
    context:addSubMenu(root, submenu)
    local pl = getSpecificPlayer(plNum)
    if pl then
        ParadiseDev.DataCheck.addWorldObjectOption(submenu, pl, pl:getUsername())
    end
    if clickedPlayer then
        ParadiseDev.DataCheck.addWorldObjectOption(submenu, clickedPlayer, clickedPlayer:getUsername())
    end
    local sq = ParadiseDev.DataCheck.getClickedSquare()
    if not sq then return end
    local objects = sq:getObjects()
    for index = 0, objects:size() - 1 do
        ParadiseDev.DataCheck.addWorldObjectOption(submenu, objects:get(index))
    end
    local movingObjects = sq:getMovingObjects()
    for index = 0, movingObjects:size() - 1 do
        ParadiseDev.DataCheck.addWorldObjectOption(submenu, movingObjects:get(index))
    end
end

function ParadiseDev.DataCheck.addInventoryContext(plNum, context, items)
    if not ParadiseDev.isAdm() then return end
    local selected = ParadiseDev.DataCheck.getInventoryItems(items)
    if #selected == 0 then return end
    local root = context:addOption("Add to Data Inspector")
    local submenu = ISContextMenu:getNew(context)
    context:addSubMenu(root, submenu)
    for _, item in ipairs(selected) do
        local name = ParadiseDev.DataCheck.objectName(item)
        local option = submenu:addOption(name, item, ParadiseDev.DataCheck.openSelected, name)
        ParadiseDev.DataCheck.setOptionIcon(option, item)
    end
end

function ParadiseDev.DataCheck.addTableRows(list, value, path, depth, seen, rowCount)
    if rowCount[1] >= ParadiseDev.DataCheck.maxRows then return end
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
    if depth >= ParadiseDev.DataCheck.maxDepth then
        list:addItem(path .. " = <max depth>")
        rowCount[1] = rowCount[1] + 1
        return
    end
    seen[value] = true
    for key, child in pairs(value) do
        if rowCount[1] >= ParadiseDev.DataCheck.maxRows then break end
        ParadiseDev.DataCheck.addTableRows(list, child, path .. "[" .. tostring(key) .. "]", depth + 1, seen, rowCount)
    end
    seen[value] = nil
end

function ParadiseDev.DataCheck.addModDataRows(list, obj)
    if not obj or not obj.hasModData or not obj:hasModData() then
        list:addItem("No ModData found.")
        return
    end
    local ok, modData = pcall(obj.getModData, obj)
    if not ok or not modData then
        list:addItem("ModData could not be read.")
        return
    end
    ParadiseDev.DataCheck.addTableRows(list, modData, "ModData", 0, {}, { 0 })
end

function ParadiseDev.DataCheck.addFieldRows(list, obj)
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
            local valueText = okValue and tostring(value) or "<unreadable>"
            list:addItem(tostring(okName and name or index) .. " = " .. valueText)
        end
    end
end

function ParadiseDev.DataCheck.getColumnText(list)
    local lines = {}
    for _, row in ipairs((list and list.items) or {}) do
        lines[#lines + 1] = tostring(row.text or "")
    end
    return table.concat(lines, "\n")
end

function ParadiseDev.DataCheck.copyDetails(panel)
    if not panel or not Clipboard or not Clipboard.setClipboard then return end
    local text = "ModData\n\n"
        .. ParadiseDev.DataCheck.getColumnText(panel.modData)
        .. "\n\nJava Fields\n\n"
        .. ParadiseDev.DataCheck.getColumnText(panel.fields)
    Clipboard.setClipboard(text)
end

function ParadiseDev.DataCheck.getObjectCoordinates(obj)
    local loc = obj
    for index = 1, 2 do
        if loc and loc.getX and loc.getY and loc.getZ then
            local okX, x = pcall(loc.getX, loc)
            local okY, y = pcall(loc.getY, loc)
            local okZ, z = pcall(loc.getZ, loc)
            if okX and okY and okZ and tonumber(x) and tonumber(y) and tonumber(z) then
                return tonumber(x), tonumber(y), tonumber(z)
            end
        end
        if not loc or not loc.getSquare then return nil end
        local okSquare, sq = pcall(loc.getSquare, loc)
        if not okSquare or not sq or sq == loc then return nil end
        loc = sq
    end
    return nil
end

function ParadiseDev.DataCheck.teleportTo(obj)
    if not ParadiseDev.TP or not ParadiseDev.TP.requestTeleport then return false end
    local x, y, z = ParadiseDev.DataCheck.getObjectCoordinates(obj)
    if not x then return false end
    return ParadiseDev.TP.requestTeleport(x, y, z)
end

ParadiseDev.DataCheck.Panel = ISCollapsableWindow:derive("ParadiseDev.DataCheck.Panel")

function ParadiseDev.DataCheck.Panel:createChildren()
    ISCollapsableWindow.createChildren(self)
    local top = self:titleBarHeight() + 8
    self.titleLabel = ISLabel:new(12, top, 18, "Data Inspector", 0.85, 0.9, 1, 1, UIFont.Medium, true)
    self.titleLabel:initialise()
    self.titleLabel:instantiate()
    self:addChild(self.titleLabel)
    self.objects = ISScrollingListBox:new(12, top + 28, 235, self.height - top - 116)
    self.objects:initialise()
    self.objects:instantiate()
    self.objects.itemheight = 22
    self.objects.font = UIFont.Small
    self.objects.drawBorder = true
    self.objects:setOnMouseDownFunction(self, ParadiseDev.DataCheck.Panel.onObjectSelected)
    self:addChild(self.objects)
    self.modData = ISScrollingListBox:new(255, top + 28, 330, self.height - top - 116)
    self.modData:initialise()
    self.modData:instantiate()
    self.modData.itemheight = 22
    self.modData.font = UIFont.Small
    self.modData.drawBorder = true
    self:addChild(self.modData)
    self.fields = ISScrollingListBox:new(593, top + 28, self.width - 605, self.height - top - 116)
    self.fields:initialise()
    self.fields:instantiate()
    self.fields.itemheight = 22
    self.fields.font = UIFont.Small
    self.fields.drawBorder = true
    self:addChild(self.fields)
    self.refreshButton = ISButton:new(12, self.height - 76, 55, 26, "Refresh", self, ParadiseDev.DataCheck.Panel.onClick)
    self.refreshButton.internal = "REFRESH"
    self.refreshButton:initialise()
    self.refreshButton:instantiate()
    self:addChild(self.refreshButton)
    self.removeButton = ISButton:new(73, self.height - 76, 55, 26, "Remove", self, ParadiseDev.DataCheck.Panel.onClick)
    self.removeButton.internal = "REMOVE"
    self.removeButton:initialise()
    self.removeButton:instantiate()
    self:addChild(self.removeButton)
    self.clearButton = ISButton:new(134, self.height - 76, 55, 26, "Clear", self, ParadiseDev.DataCheck.Panel.onClick)
    self.clearButton.internal = "CLEAR"
    self.clearButton:initialise()
    self.clearButton:instantiate()
    self:addChild(self.clearButton)
    self.clipButton = ISButton:new(195, self.height - 76, 55, 26, "Clip", self, ParadiseDev.DataCheck.Panel.onClick)
    self.clipButton.internal = "CLIP"
    self.clipButton:initialise()
    self.clipButton:instantiate()
    self:addChild(self.clipButton)
    self.tpButton = ISButton:new(12, self.height - 45, 55, 26, "TP", self, ParadiseDev.DataCheck.Panel.onClick)
    self.tpButton.internal = "TP"
    self.tpButton:initialise()
    self.tpButton:instantiate()
    self:addChild(self.tpButton)
end

function ParadiseDev.DataCheck.Panel:refresh(selected)
    if not self.objects then return end
    selected = selected or self.objects.selected
    self.objects:clear()
    for _, entry in ipairs(ParadiseDev.DataCheck.entries) do
        self.objects:addItem(entry.name, entry)
    end
    if #ParadiseDev.DataCheck.entries == 0 then
        self.objects.selected = 0
    else
        self.objects.selected = math.max(1, math.min(selected or 1, #ParadiseDev.DataCheck.entries))
    end
    self:refreshDetails()
end

function ParadiseDev.DataCheck.Panel:refreshDetails()
    self.modData:clear()
    self.fields:clear()
    local row = self.objects.items[self.objects.selected]
    local entry = row and row.item or nil
    self.titleLabel:setName("Data Inspector: " .. tostring(entry and entry.name or "No selection"))
    if not entry then return end
    ParadiseDev.DataCheck.addModDataRows(self.modData, entry.obj)
    ParadiseDev.DataCheck.addFieldRows(self.fields, entry.obj)
end

function ParadiseDev.DataCheck.Panel:onObjectSelected()
    self:refreshDetails()
end

function ParadiseDev.DataCheck.Panel:onClick(button)
    if button.internal == "REFRESH" then
        self:refresh(self.objects.selected)
    elseif button.internal == "REMOVE" then
        ParadiseDev.DataCheck.remove(self.objects.selected)
        self:refresh(self.objects.selected)
    elseif button.internal == "CLEAR" then
        ParadiseDev.DataCheck.clear()
        self:refresh(0)
    elseif button.internal == "CLIP" then
        ParadiseDev.DataCheck.copyDetails(self)
    elseif button.internal == "TP" then
        local row = self.objects.items[self.objects.selected]
        local entry = row and row.item or nil
        ParadiseDev.DataCheck.teleportTo(entry and entry.obj)
    end
end

function ParadiseDev.DataCheck.Panel:close()
    ParadiseDev.DataCheck.close()
end

function ParadiseDev.DataCheck.Panel:new(x, y, width, height)
    local panel = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(panel, self)
    self.__index = self
    panel.title = "ParadiseZ Data Inspector"
    panel.resizable = true
    return panel
end

Events.OnFillWorldObjectContextMenu.Remove(ParadiseDev.DataCheck.addWorldContext)
Events.OnFillWorldObjectContextMenu.Add(ParadiseDev.DataCheck.addWorldContext)
Events.OnFillInventoryObjectContextMenu.Remove(ParadiseDev.DataCheck.addInventoryContext)
Events.OnFillInventoryObjectContextMenu.Add(ParadiseDev.DataCheck.addInventoryContext)
