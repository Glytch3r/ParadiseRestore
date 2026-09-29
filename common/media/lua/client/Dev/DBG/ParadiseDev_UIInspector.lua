require "ISUI/ISButton"
require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"

ParadiseDev = ParadiseDev or {}
ParadiseDev.UI = ParadiseDev.UI or {}

local UI = ParadiseDev.UI

function UI.call(element, method, fallback)
    if not element or not element[method] then return fallback end
    local ok, value = pcall(element[method], element)
    if not ok then return fallback end
    return value
end

function UI.describe(element, rootIndex, parent, childIndex, depth)
    return {
        element = element,
        rootIndex = rootIndex,
        parent = parent,
        childIndex = childIndex,
        depth = depth or 0,
        name = UI.call(element, "getUIName", tostring(element)),
        visible = UI.call(element, "isVisible", false),
        x = UI.call(element, "getAbsoluteX", UI.call(element, "getX", 0)),
        y = UI.call(element, "getAbsoluteY", UI.call(element, "getY", 0)),
        width = UI.call(element, "getWidth", 0),
        height = UI.call(element, "getHeight", 0),
    }
end

function UI.collectChildren(results, element, rootIndex, includeHidden, depth, excluded, visited)
    if not element or element == excluded or visited[element] then return end
    visited[element] = true
    local controls = UI.call(element, "getControls", nil)
    if not controls or not controls.size or not controls.get then return end
    for index = 0, controls:size() - 1 do
        local child = controls:get(index)
        if child and child ~= excluded and (includeHidden or UI.call(child, "isVisible", false)) then
            results[#results + 1] = UI.describe(child, rootIndex, element, index, depth)
            UI.collectChildren(results, child, rootIndex, includeHidden, depth + 1, excluded, visited)
        end
    end
end

function UI.getOpen(includeHidden, excluded)
    local results = {}
    if not UIManager or not UIManager.getUI then return results end
    local roots = UIManager.getUI()
    if not roots or not roots.size or not roots.get then return results end
    local visited = {}
    for index = 0, roots:size() - 1 do
        local element = roots:get(index)
        if element and element ~= excluded and (includeHidden or UI.call(element, "isVisible", false)) then
            results[#results + 1] = UI.describe(element, index, nil, nil, 0)
            UI.collectChildren(results, element, index, includeHidden, 1, excluded, visited)
        end
    end
    return results
end

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

function UI.getPanelBounds(screenWidth, screenHeight)
    return {
        x = 20,
        y = 20,
        width = math.max(420, math.min(900, screenWidth - 40)),
        height = math.max(260, screenHeight - 40),
    }
end

function UI.printOpen(includeHidden)
    for _, entry in ipairs(UI.getOpen(includeHidden)) do
        print(string.format(
            "[ParadiseDev.UI] root=%d child=%s %s visible=%s x=%s y=%s width=%s height=%s",
            entry.rootIndex,
            tostring(entry.childIndex),
            tostring(entry.name),
            tostring(entry.visible),
            tostring(entry.x),
            tostring(entry.y),
            tostring(entry.width),
            tostring(entry.height)
        ))
    end
end

UI.Panel = ISCollapsableWindow:derive("ParadiseDev.UI.Panel")

function UI.layoutPanel(panel)
    if not panel or not panel.list then return end
    local gap = 10
    local buttonHeight = 24
    local top = panel:titleBarHeight() + gap
    local listY = top + buttonHeight + gap
    local listHeight = panel.height - listY - panel:resizeWidgetHeight() - gap
    panel.refreshButton:setX(gap)
    panel.refreshButton:setY(top)
    panel.hiddenButton:setX(panel.refreshButton:getRight() + gap)
    panel.hiddenButton:setY(top)
    panel.list:setX(gap)
    panel.list:setY(listY)
    panel.list:setWidth(math.max(100, panel.width - gap * 2))
    panel.list:setHeight(math.max(100, listHeight))
end

function UI.Panel:createChildren()
    ISCollapsableWindow.createChildren(self)
    self.refreshButton = ISButton:new(10, 0, 100, 24, "Refresh", self, UI.Panel.onButton)
    self.refreshButton:initialise()
    self.refreshButton:instantiate()
    self.refreshButton.internal = "REFRESH"
    self:addChild(self.refreshButton)
    self.hiddenButton = ISButton:new(120, 0, 130, 24, "Hidden: On", self, UI.Panel.onButton)
    self.hiddenButton:initialise()
    self.hiddenButton:instantiate()
    self.hiddenButton.internal = "HIDDEN"
    self:addChild(self.hiddenButton)
    self.list = ISScrollingListBox:new(10, 0, self.width - 20, self.height - 70)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = 22
    self.list.font = UIFont.Small
    self.list.anchorLeft = true
    self.list.anchorRight = true
    self.list.anchorTop = true
    self.list.anchorBottom = true
    self:addChild(self.list)
    self:setResizable(true)
    UI.layoutPanel(self)
    self:refresh()
end

function UI.Panel:onResize()
    ISCollapsableWindow.onResize(self)
    UI.layoutPanel(self)
end

function UI.Panel:onButton(button)
    if button.internal == "HIDDEN" then
        self.includeHidden = not self.includeHidden
        button:setTitle(self.includeHidden and "Hidden: On" or "Hidden: Off")
    end
    self:refresh()
end

function UI.Panel:refresh()
    if not self.list then return end
    self.list:clear()
    local scrollWidth = self.list:getWidth()
    for _, entry in ipairs(UI.getOpen(self.includeHidden, self.javaObject)) do
        local text = UI.getEntryText(entry)
        self.list:addItem(text, entry)
        scrollWidth = math.max(scrollWidth, getTextManager():MeasureStringX(self.list.font, text) + 30)
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
    panel.minimumWidth = 420
    panel.minimumHeight = 260
    panel.resizable = true
    panel.includeHidden = true
    return panel
end

function UI.ClosePanel()
    if not UI.instance then return end
    UI.instance:setVisible(false)
    UI.instance:removeFromUIManager()
    UI.instance = nil
end

function UI.OpenPanel()
    if not UI.instance then
        local screenWidth = getCore():getScreenWidth()
        local screenHeight = getCore():getScreenHeight()
        local bounds = UI.getPanelBounds(screenWidth, screenHeight)
        UI.instance = UI.Panel:new(bounds.x, bounds.y, bounds.width, bounds.height)
        UI.instance:initialise()
        UI.instance:addToUIManager()
    else
        UI.instance:setVisible(true)
        UI.instance:addToUIManager()
    end
    UI.instance:refresh()
    UI.instance:bringToTop()
end

function UI.TogglePanel()
    if UI.instance then
        UI.ClosePanel()
        return
    end
    UI.OpenPanel()
end
