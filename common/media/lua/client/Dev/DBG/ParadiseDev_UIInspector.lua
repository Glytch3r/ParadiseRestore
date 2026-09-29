require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"

ParadiseDev = ParadiseDev or {}
ParadiseDev.UI = ParadiseDev.UI or {}

local UI = ParadiseDev.UI

local function call(element, method, fallback)
    if not element or not element[method] then return fallback end
    local ok, value = pcall(element[method], element)
    return ok and value or fallback
end

function UI.describe(element, rootIndex, parent, childIndex, depth)
    return {
        element = element,
        rootIndex = rootIndex,
        parent = parent,
        childIndex = childIndex,
        depth = depth or 0,
        name = call(element, "getUIName", tostring(element)),
        visible = call(element, "isVisible", false),
        x = call(element, "getAbsoluteX", call(element, "getX", 0)),
        y = call(element, "getAbsoluteY", call(element, "getY", 0)),
        width = call(element, "getWidth", 0),
        height = call(element, "getHeight", 0),
    }
end

function UI.collectChildren(results, element, rootIndex, includeHidden, depth)
    local controls = call(element, "getControls", nil)
    if not controls or not controls.size or not controls.get then return end

    for index = 0, controls:size() - 1 do
        local child = controls:get(index)
        if child and (includeHidden or call(child, "isVisible", false)) then
            results[#results + 1] = UI.describe(child, rootIndex, element, index, depth)
            UI.collectChildren(results, child, rootIndex, includeHidden, depth + 1)
        end
    end
end

function UI.getOpen(includeHidden)
    local results = {}
    if not UIManager or not UIManager.getUI then return results end

    local roots = UIManager.getUI()
    if not roots or not roots.size or not roots.get then return results end

    for index = 0, roots:size() - 1 do
        local element = roots:get(index)
        if element and (includeHidden or call(element, "isVisible", false)) then
            results[#results + 1] = UI.describe(element, index, nil, nil, 0)
            UI.collectChildren(results, element, index, includeHidden, 1)
        end
    end

    return results
end

UI.Panel = ISCollapsableWindow:derive("ParadiseDev.UI.Panel")

function UI.getEntryText(entry)
    return string.format(
        "%s%s | x=%s y=%s width=%s height=%s | visible=%s",
        string.rep("  ", entry.depth or 0),
        tostring(entry.name),
        tostring(entry.x),
        tostring(entry.y),
        tostring(entry.width),
        tostring(entry.height),
        tostring(entry.visible)
    )
end

function UI.layoutPanel(panel)
    if not panel or not panel.list then return end
    local gap = 12
    local listY = panel:titleBarHeight() + gap
    local resizeHeight = panel:resizeWidgetHeight()
    panel.list:setX(gap)
    panel.list:setY(listY)
    panel.list:setWidth(math.max(100, panel.width - gap * 2))
    panel.list:setHeight(math.max(100, panel.height - listY - gap - resizeHeight))
end

function UI.resizePanel(panel, width, height)
    if not panel then return end
    panel:setWidth(math.max(width, panel.minimumWidth or 0))
    panel:setHeight(math.max(height, panel.minimumHeight or 0))
    UI.layoutPanel(panel)
end

function UI.Panel:createChildren()
    ISCollapsableWindow.createChildren(self)
    self:setResizable(true)
    if self.resizeWidget then self.resizeWidget.resizeFunction = UI.resizePanel end
    if self.resizeWidget2 then self.resizeWidget2.resizeFunction = UI.resizePanel end
    self.list = ISScrollingListBox:new(12, self:titleBarHeight() + 12, self.width - 24, self.height - 54)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = 22
    self.list.font = UIFont.Small
    self:addChild(self.list)
    UI.layoutPanel(self)
    self:refresh()
end

function UI.Panel:refresh()
    if not self.list then return end
    self.list:clear()
    local scrollWidth = self.list:getWidth()
    for _, entry in ipairs(UI.getOpen(self.includeHidden)) do
        if entry.element ~= self and entry.parent ~= self then
            local text = UI.getEntryText(entry)
            self.list:addItem(text, entry)
            scrollWidth = math.max(scrollWidth, getTextManager():MeasureStringX(self.list.font, text) + 30)
        end
    end
    self.list:setScrollWidth(scrollWidth)
end

function UI.Panel:close()
    UI.ClosePanel()
end

function UI.Panel:new(x, y, width, height)
    local panel = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(panel, self)
    self.__index = self
    panel.title = "Paradise UI Inspector"
    panel.minimumWidth = 500
    panel.minimumHeight = 260
    panel.resizable = true
    panel.includeHidden = true
    return panel
end

function UI.ClosePanel()
    if UI.instance then
        UI.instance:setVisible(false)
        UI.instance:removeFromUIManager()
        UI.instance = nil
    end
end

function UI.OpenPanel()
    if UI.instance == nil then
        local width = math.min(900, getCore():getScreenWidth() - 80)
        local height = math.min(650, getCore():getScreenHeight() - 80)
        local x = (getCore():getScreenWidth() - width) / 2
        local y = (getCore():getScreenHeight() - height) / 2
        UI.instance = UI.Panel:new(x, y, width, height)
        UI.instance:initialise()
        UI.instance:instantiate()
    end
    UI.instance:addToUIManager()
    UI.instance:setVisible(true)
    UI.instance:refresh()
end

function UI.TogglePanel()
    if UI.instance then
        UI.ClosePanel()
        return
    end
    UI.OpenPanel()
end

function UI.printOpen(includeHidden)
    for _, entry in ipairs(UI.getOpen(includeHidden)) do
        print(string.format(
            "[ParadiseDev.UI] root=%d child=%s %s visible=%s x=%s y=%s w=%s h=%s",
            entry.rootIndex,
            tostring(entry.childIndex),
            tostring(entry.name),
            tostring(entry.visible),
            tostring(entry.x), tostring(entry.y),
            tostring(entry.width), tostring(entry.height)
        ))
    end
end
