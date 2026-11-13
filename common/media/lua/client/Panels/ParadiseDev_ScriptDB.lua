require "ISUI/ISCollapsableWindow"
require "ISUI/ISPanel"
require "ISUI/ISTabPanel"
require "ISUI/ISScrollingListBox"
require "ISUI/ISTextEntryBox"
require "ISUI/ISButton"
require "ISUI/ISLabel"

ParadiseDev = ParadiseDev or {}
ParadiseDev.ScriptDB = ParadiseDev.ScriptDB or {}
ParadiseDev.ScriptDB.window = ParadiseDev.ScriptDB.window or nil

function ParadiseDev.ScriptDB.isB41()
    return getCore():getGameVersion():getMajor() == 41
end
if ParadiseDev.ScriptDB.isB41() then return end

local ScriptDB = ParadiseDev.ScriptDB

ScriptDB.tabDefs = {
    { key = "vehicles", label = "Vehicles" },
    { key = "items", label = "Items" },
    { key = "zombies", label = "Zombies" },
    { key = "recipes", label = "Recipes" },
}

ScriptDB.data = ScriptDB.data or {}

function ScriptDB.read(obj, name, ...)
    if not obj or not obj[name] then return nil end
    local ok, val = pcall(obj[name], obj, ...)
    if ok then return val end
    return nil
end

function ScriptDB.fmt(val)
    if val == nil then return "" end
    if type(val) == "number" then
        if val ~= math.floor(val) then
            return string.format("%.2f", val)
        end
        return tostring(val)
    end
    if type(val) == "boolean" then
        return val and "true" or "false"
    end
    return tostring(val)
end

function ScriptDB.loadVehicles()
    local list = {}
    local manager = getScriptManager and getScriptManager() or nil
    local scripts = manager and ScriptDB.read(manager, "getAllVehicleScripts") or nil
    if scripts then
        for index = 0, scripts:size() - 1 do
            local scr = scripts:get(index)
            local name = ScriptDB.read(scr, "getFullName")
            if name then
                list[#list + 1] = { name = tostring(name), scr = scr }
            end
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

function ScriptDB.loadItems()
    local list = {}
    local manager = getScriptManager and getScriptManager() or nil
    local scripts = manager and ScriptDB.read(manager, "getAllItems") or nil
    if scripts then
        for index = 0, scripts:size() - 1 do
            local scr = scripts:get(index)
            local name = ScriptDB.read(scr, "getFullName")
            if name then
                list[#list + 1] = { name = tostring(name), scr = scr }
            end
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

function ScriptDB.loadZombies()
    local list = {}
    if not getAllOutfits then return list end
    local genders = { { female = false, label = "Male" }, { female = true, label = "Female" } }
    for _, gender in ipairs(genders) do
        local ok, outfits = pcall(getAllOutfits, gender.female)
        if ok and outfits then
            for index = 0, outfits:size() - 1 do
                local name = outfits:get(index)
                if name then
                    list[#list + 1] = { name = tostring(name), gender = gender.label }
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.name == b.name then return a.gender < b.gender end
        return a.name < b.name
    end)
    return list
end

function ScriptDB.loadRecipes()
    local list = {}
    local manager = getScriptManager and getScriptManager() or nil
    local scripts = manager and ScriptDB.read(manager, "getAllCraftRecipes") or nil
    if scripts then
        for index = 0, scripts:size() - 1 do
            local scr = scripts:get(index)
            local name = ScriptDB.read(scr, "getName")
            if name then
                list[#list + 1] = { name = tostring(name), scr = scr }
            end
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

ScriptDB.loaders = {
    vehicles = ScriptDB.loadVehicles,
    items = ScriptDB.loadItems,
    zombies = ScriptDB.loadZombies,
    recipes = ScriptDB.loadRecipes,
}

function ScriptDB.getVehicleRows(entry)
    local scr = entry.scr
    return {
        { "FullType", ScriptDB.read(scr, "getFullName") },
        { "Name", ScriptDB.read(scr, "getName") },
        { "Mass", ScriptDB.read(scr, "getMass") },
        { "Seats", ScriptDB.read(scr, "getSeats") },
        { "EngineForce", ScriptDB.read(scr, "getEngineForce") },
        { "EngineLoudness", ScriptDB.read(scr, "getEngineLoudness") },
        { "EngineQuality", ScriptDB.read(scr, "getEngineQuality") },
        { "WheelCount", ScriptDB.read(scr, "getWheelCount") },
        { "PassengerCount", ScriptDB.read(scr, "getPassengerCount") },
        { "PartCount", ScriptDB.read(scr, "getPartCount") },
        { "AreaCount", ScriptDB.read(scr, "getAreaCount") },
        { "ModelCount", ScriptDB.read(scr, "getModelCount") },
        { "HasSiren", ScriptDB.read(scr, "getHasSiren") },
        { "File", ScriptDB.read(scr, "getFileName") },
    }
end

function ScriptDB.getItemRows(entry)
    local scr = entry.scr
    return {
        { "FullType", ScriptDB.read(scr, "getFullName") },
        { "DisplayName", ScriptDB.read(scr, "getDisplayName") },
        { "DisplayCategory", ScriptDB.read(scr, "getDisplayCategory") },
        { "Weight", ScriptDB.read(scr, "getActualWeight") },
        { "Icon", ScriptDB.read(scr, "getIcon") },
        { "ConditionMax", ScriptDB.read(scr, "getConditionMax") },
        { "HungerChange", ScriptDB.read(scr, "getHungerChange") },
        { "ThirstChange", ScriptDB.read(scr, "getThirstChange") },
        { "ClothingItem", ScriptDB.read(scr, "getClothingItem") },
        { "StaticModel", ScriptDB.read(scr, "getStaticModel") },
        { "WorldStaticModel", ScriptDB.read(scr, "getWorldStaticModel") },
        { "Obsolete", ScriptDB.read(scr, "getObsolete") },
    }
end

function ScriptDB.getZombieRows(entry)
    return {
        { "Outfit", entry.name },
        { "Gender", entry.gender },
    }
end

function ScriptDB.getRecipeRows(entry)
    local scr = entry.scr
    local rows = {
        { "Name", ScriptDB.read(scr, "getName") },
        { "Category", ScriptDB.read(scr, "getCategory") },
        { "Time", ScriptDB.read(scr, "getTime") },
    }
    local inputs = ScriptDB.read(scr, "getInputs")
    if inputs then
        for index = 0, inputs:size() - 1 do
            local input = inputs:get(index)
            local line = ScriptDB.read(input, "getOriginalLine")
            if line then
                rows[#rows + 1] = { "Input " .. (index + 1), line }
            end
        end
    end
    local outputs = ScriptDB.read(scr, "getOutputs")
    if outputs then
        for index = 0, outputs:size() - 1 do
            local output = outputs:get(index)
            local line = ScriptDB.read(output, "getOriginalLine")
            if line then
                rows[#rows + 1] = { "Output " .. (index + 1), line }
            end
        end
    end
    return rows
end

ScriptDB.rowBuilders = {
    vehicles = ScriptDB.getVehicleRows,
    items = ScriptDB.getItemRows,
    zombies = ScriptDB.getZombieRows,
    recipes = ScriptDB.getRecipeRows,
}

function ScriptDB.fillList(view)
    local list = view.list
    list:clear()
    local filter = ""
    if view.search and view.search.getText then
        filter = string.lower(tostring(view.search:getText() or ""))
    end
    local count = 0
    for _, entry in ipairs(ScriptDB.data[view.key] or {}) do
        if filter == "" or string.find(string.lower(entry.name), filter, 1, true) then
            list:addItem(entry.name, entry)
            count = count + 1
        end
    end
    view.count = count
    if view.countLabel then
        view.countLabel:setName(tostring(count) .. " entries")
    end
    ScriptDB.updateScrollWidth(list)
end

function ScriptDB.showDetail(view, entry)
    local detail = view.detail
    detail:clear()
    if not entry then
        detail:addItem("Select an entry.")
        return
    end
    local builder = ScriptDB.rowBuilders[view.key]
    local rows = builder and builder(entry) or {}
    for _, row in ipairs(rows) do
        detail:addItem(row[1] .. " = " .. ScriptDB.fmt(row[2]))
    end
    ScriptDB.updateScrollWidth(detail)
end

function ScriptDB.onEntrySelected(view, entry)
    ScriptDB.showDetail(view, entry)
end

function ScriptDB.onSearchChanged(view)
    ScriptDB.fillList(view)
    ScriptDB.showDetail(view, nil)
end

function ScriptDB.updateScrollWidth(list)
    if not list then return end
    local width = list:getWidth()
    for _, row in ipairs(list.items or {}) do
        width = math.max(width, getTextManager():MeasureStringX(list.font, tostring(row.text or "")) + 30)
    end
    list:setScrollWidth(width)
end

function ScriptDB.getColumnText(list)
    local lines = {}
    for _, row in ipairs((list and list.items) or {}) do
        lines[#lines + 1] = tostring(row.text or "")
    end
    return table.concat(lines, "\n")
end

function ScriptDB.copyDetails(panel)
    if not panel or not Clipboard or not Clipboard.setClipboard then return end
    local view = panel.tabs and panel.tabs:getActiveView()
    if not view then return end
    Clipboard.setClipboard(ScriptDB.getColumnText(view.detail))
end

ScriptDB.Panel = ISCollapsableWindow:derive("ParadiseDev.ScriptDB.Panel")

function ScriptDB.resizeWindow(panel, newWidth, newHeight)
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

function ScriptDB.Panel:createChildren()
    ISCollapsableWindow.createChildren(self)
    self:setResizable(true)
    if self.resizeWidget then self.resizeWidget.resizeFunction = ScriptDB.resizeWindow end
    if self.resizeWidget2 then self.resizeWidget2.resizeFunction = ScriptDB.resizeWindow end
    local top = self:titleBarHeight() + 8
    self.titleLabel = ISLabel:new(12, top, 18, "Script Database", 0.85, 0.9, 1, 1, UIFont.Medium, true)
    self.titleLabel:initialise()
    self.titleLabel:instantiate()
    self:addChild(self.titleLabel)
    self.tabs = ISTabPanel:new(12, top + 26, self.width - 24, self.height - top - 78)
    self.tabs:initialise()
    self:addChild(self.tabs)
    self.views = {}
    for _, def in ipairs(ScriptDB.tabDefs) do
        local view = ISPanel:new(0, 0, self.tabs.width, self.tabs.height - self.tabs.tabHeight)
        view:initialise()
        view.key = def.key
        view.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
        view.borderColor = { r = 0, g = 0, b = 0, a = 0 }
        view.search = ISTextEntryBox:new("", 8, 6, view.width - 16, 24)
        view.search:initialise()
        view.search:instantiate()
        view.search.target = view
        view.search.onTextChangeFunction = ScriptDB.onSearchChanged
        view:addChild(view.search)
        local listWidth = math.floor(view.width * 0.38)
        view.list = ISScrollingListBox:new(8, 36, listWidth, view.height - 62)
        view.list:initialise()
        view.list:instantiate()
        view.list:addScrollBars(true)
        view.list.itemheight = 22
        view.list.font = UIFont.Small
        view.list.drawBorder = true
        view.list:setOnMouseDownFunction(view, ScriptDB.onEntrySelected)
        view:addChild(view.list)
        view.detail = ISScrollingListBox:new(listWidth + 16, 36, view.width - listWidth - 24, view.height - 62)
        view.detail:initialise()
        view.detail:instantiate()
        view.detail:addScrollBars(true)
        view.detail.itemheight = 22
        view.detail.font = UIFont.Small
        view.detail.drawBorder = true
        view:addChild(view.detail)
        view.countLabel = ISLabel:new(8, view.height - 22, 16, "", 0.7, 0.7, 0.7, 1, UIFont.Small, true)
        view.countLabel:initialise()
        view.countLabel:instantiate()
        view:addChild(view.countLabel)
        self.tabs:addView(def.label, view)
        self.views[#self.views + 1] = view
    end
    self.refreshButton = ISButton:new(12, self.height - 40, 80, 26, "Refresh", self, ScriptDB.Panel.onClick)
    self.refreshButton.internal = "REFRESH"
    self.refreshButton:initialise()
    self.refreshButton:instantiate()
    self:addChild(self.refreshButton)
    self.clipButton = ISButton:new(100, self.height - 40, 80, 26, "Clip", self, ScriptDB.Panel.onClick)
    self.clipButton.internal = "CLIP"
    self.clipButton:initialise()
    self.clipButton:instantiate()
    self:addChild(self.clipButton)
    self:layoutChildren()
end

function ScriptDB.Panel:layoutChildren()
    local top = self:titleBarHeight() + 8
    self.titleLabel:setX(12)
    self.titleLabel:setY(top)
    self.tabs:setX(12)
    self.tabs:setY(top + 26)
    self.tabs:setWidth(self.width - 24)
    self.tabs:setHeight(self.height - top - 78)
    for _, view in ipairs(self.views) do
        view:setWidth(self.tabs.width)
        view:setHeight(self.tabs.height - self.tabs.tabHeight)
        view.search:setWidth(view.width - 16)
        local listWidth = math.floor(view.width * 0.38)
        view.list:setWidth(listWidth)
        view.list:setHeight(view.height - 62)
        view.detail:setX(listWidth + 16)
        view.detail:setWidth(view.width - listWidth - 24)
        view.detail:setHeight(view.height - 62)
        view.countLabel:setY(view.height - 22)
    end
    self.refreshButton:setY(self.height - 40)
    self.clipButton:setY(self.height - 40)
end

function ScriptDB.Panel:onClick(button)
    if button.internal == "REFRESH" then
        self:refresh()
    elseif button.internal == "CLIP" then
        ScriptDB.copyDetails(self)
    end
end

function ScriptDB.Panel:refresh()
    for key, loader in pairs(ScriptDB.loaders) do
        ScriptDB.data[key] = loader()
    end
    for _, view in ipairs(self.views) do
        ScriptDB.fillList(view)
        ScriptDB.showDetail(view, nil)
    end
end

function ScriptDB.Panel:close()
    ScriptDB.ClosePanel()
end

function ScriptDB.Panel:new(x, y, width, height)
    local obj = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(obj, self)
    self.__index = self
    obj.title = "ParadiseZ Script DB"
    obj.minimumWidth = 720
    obj.minimumHeight = 420
    obj.resizable = true
    return obj
end