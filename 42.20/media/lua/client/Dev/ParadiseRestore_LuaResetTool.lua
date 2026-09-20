--r* reset* lua* resetlua*
require "ISUI/ISCollapsableWindow"

LuaResetTool = LuaResetTool or {}
LuaResetTool.files = LuaResetTool.files or {}

local function normalizePath(path)
    if not path then
        return nil
    end

    path = string.gsub(path, "\\", "/")

    local luaStart = string.find(string.lower(path), "lua/", 1, true)

    if luaStart then
        return string.sub(path, luaStart + 4)
    end

    return path
end

local function resolveLoadedPath(path)
    if not getLoadedLuaCount or not getLoadedLua then
        return path
    end

    local wanted = normalizePath(path)

    for i = 0, getLoadedLuaCount() - 1 do
        local loaded = getLoadedLua(i)

        if loaded and normalizePath(loaded) == wanted then
            return loaded
        end
    end

    return path
end

local ResetList = ISScrollingListBox:derive("LuaResetToolList")

function ResetList:doDrawItem(y, item, alt)
    if self.selected == item.index then
        self:drawRect(0, y, self:getWidth(), self.itemheight - 1, 0.35, 0.20, 0.55, 0.90)
    end

    self:drawRectBorder(0, y, self:getWidth(), self.itemheight, 0.50, 0.40, 0.40, 0.40)
    self:drawText(item.text, 8, y + (item.height - self.fontHgt) / 2, 0.90, 0.90, 0.90, 1.00, UIFont.Small)

    return y + self.itemheight
end

LuaResetWindow = ISCollapsableWindow:derive("LuaResetWindow")

function LuaResetWindow:new(x, y, width, height)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o.title = "Reset Lua Files"
    o.resizable = true
    o:setAlwaysOnTop(true)
    return o
end

function LuaResetWindow:createList(x, y, width, height)
    local list = ResetList:new(x, y, width, height)
    list:initialise()
    list:instantiate()
    list:setFont(UIFont.Small, 0)
    self:addChild(list)
    return list
end

function LuaResetWindow:createChildren()
    ISCollapsableWindow.createChildren(self)

    self.filter = ISTextEntryBox:new("", 15, 25, self.width - 20, 25)
    self.filter:initialise()
    self.filter:instantiate()
    self.filter:setClearButton(true)
    self.filter.onTextChange = function()
        self:fillAvailable()
        self:fillSaved()
    end
    self:addChild(self.filter)

    local listY = 55
    local listHeight = self.height - 125
    local listWidth = math.floor((self.width - 45) / 2)

    self.availableList = self:createList(8, listY, listWidth, listHeight)
    self.savedList = self:createList(40 + listWidth, listY, listWidth, listHeight)

    self.addButton = ISButton:new(math.floor(self.width / 2) - 15+5, listY + 40, 25, 25, ">", self, LuaResetWindow.addSelected)
    self.addButton:initialise()
    self.addButton:instantiate()
    self:addChild(self.addButton)

    self.removeButton = ISButton:new(math.floor(self.width / 2) - 15+5, listY + 75, 25, 25, "<", self, LuaResetWindow.removeSelected)
    self.removeButton:initialise()
    self.removeButton:instantiate()
    self:addChild(self.removeButton)

    listY = listY - 25

    self.resetButton = ISButton:new(10, self.height - 55, 70, 25, "Reset", self, LuaResetWindow.resetSelected)
    self.resetButton:initialise()
    self.resetButton:instantiate()
    self:addChild(self.resetButton)

    self.resetAllButton = ISButton:new(85, self.height - 55, 80, 25, "Reset All", self, LuaResetWindow.resetAll)
    self.resetAllButton:initialise()
    self.resetAllButton:instantiate()
    self:addChild(self.resetAllButton)

    self.refreshButton = ISButton:new(self.width - 175, self.height - 55, 75, 25, "Refresh", self, LuaResetWindow.refresh)
    self.refreshButton:initialise()
    self.refreshButton:instantiate()
    self:addChild(self.refreshButton)

    self.closeButton = ISButton:new(self.width - 90, self.height - 55, 80, 25, "Close", self, LuaResetWindow.closePanel)
    self.closeButton:initialise()
    self.closeButton:instantiate()
    self:addChild(self.closeButton)

    self:loadSaved()
    self:fillAvailable()
    self:fillSaved()
end

function LuaResetWindow:loadSaved()
    LuaResetTool.files = {}

    local reader = getFileReader("LuaResetToolFiles.txt", true)

    if not reader then
        return
    end

    local line = reader:readLine()

    while line do
        line = normalizePath(string.trim(line))

        if line and line ~= "" then
            LuaResetTool.addUnique(line)
        end

        line = reader:readLine()
    end

    reader:close()
end

function LuaResetWindow:saveSaved()
    local writer = getFileWriter("LuaResetToolFiles.txt", true, false)

    if not writer then
        return
    end

    for i = 1, #LuaResetTool.files do
        writer:write(normalizePath(LuaResetTool.files[i]) .. "\r\n")
    end

    writer:close()
end

function LuaResetWindow:getFilter()
    local filter = self.filter:getInternalText()
    return filter and string.lower(string.trim(filter)) or ""
end

function LuaResetWindow:isSaved(path)
    path = normalizePath(path)

    for i = 1, #LuaResetTool.files do
        if normalizePath(LuaResetTool.files[i]) == path then
            return true
        end
    end

    return false
end

function LuaResetWindow:fillAvailable()
    self.availableList:clear()

    if not getLoadedLuaCount or not getLoadedLua then
        return
    end

    local filter = self:getFilter()

    for i = 0, getLoadedLuaCount() - 1 do
        local rawPath = getLoadedLua(i)
        local path = normalizePath(rawPath)

        if path and not self:isSaved(path) then
            local name = string.lower(path)

            if filter == "" or string.find(name, filter, 1, true) then
                self.availableList:addItem(path, rawPath)
            end
        end
    end
end

function LuaResetWindow:fillSaved()
    self.savedList:clear()

    local filter = self:getFilter()

    for i = 1, #LuaResetTool.files do
        local path = normalizePath(LuaResetTool.files[i])
        local name = string.lower(path)

        if filter == "" or string.find(name, filter, 1, true) then
            self.savedList:addItem(path, path)
        end
    end
end

function LuaResetWindow:addSelected()
    if not self.availableList.selected then
        return
    end

    local item = self.availableList.items[self.availableList.selected]

    if not item or not item.item then
        return
    end

    LuaResetTool.addUnique(normalizePath(item.item))
    self:saveSaved()
    self:fillAvailable()
    self:fillSaved()
end

function LuaResetWindow:removeSelected()
    if not self.savedList.selected then
        return
    end

    local item = self.savedList.items[self.savedList.selected]

    if not item or not item.item then
        return
    end

    local path = normalizePath(item.item)

    for i = #LuaResetTool.files, 1, -1 do
        if normalizePath(LuaResetTool.files[i]) == path then
            table.remove(LuaResetTool.files, i)
        end
    end

    self:saveSaved()
    self:fillAvailable()
    self:fillSaved()
end

function LuaResetWindow:resetSelected()
    if not self.savedList.selected then
        return
    end

    local item = self.savedList.items[self.savedList.selected]

    if item and item.item then
        LuaResetTool.reset(item.item)
    end
end

function LuaResetWindow:resetAll()
    for i = 1, #LuaResetTool.files do
        LuaResetTool.reset(LuaResetTool.files[i])
    end
end

function LuaResetWindow:refresh()
    self:fillAvailable()
    self:fillSaved()
end

function LuaResetWindow:closePanel()
    LuaResetTool.close()
end

function LuaResetTool.addUnique(path)
    path = normalizePath(path)

    if not path or path == "" then
        return
    end

    for i = 1, #LuaResetTool.files do
        if normalizePath(LuaResetTool.files[i]) == path then
            return
        end
    end

    table.insert(LuaResetTool.files, path)
end

function LuaResetTool.removeExisting()
    if not LuaResetTool.window then
        return
    end

    if UIManager.getUI():contains(LuaResetTool.window) then
        UIManager.getUI():removeChild(LuaResetTool.window)
    end

    LuaResetTool.window:setVisible(false)
    LuaResetTool.window = nil
end

function LuaResetTool.close()
    LuaResetTool.removeExisting()
end

function LuaResetTool.reset(path)
    path = normalizePath(path)

    if not path or path == "" then
        return
    end

    if isClient and isClient() and not (isServer and isServer()) then
        if processSayMessage then
            processSayMessage("/reloadlua " .. path)
        end

        return
    end

    local resolvedPath = resolveLoadedPath(path)

    if reloadLuaFile then
        reloadLuaFile(resolvedPath)
        return
    end

    if getCore and getCore():getDebug() then
        getCore():ResetLua("default", "Force")
    end
end

function LuaResetTool.open()
    LuaResetTool.removeExisting()

    local width = 770
    local height = 560
    local x = math.floor((getCore():getScreenWidth() - width) / 2)
    local y = math.floor((getCore():getScreenHeight() - height) / 2)

    local window = LuaResetWindow:new(x, y, width, height)
    window:initialise()
    window:addToUIManager()
    window:setVisible(true)
    window:setAlwaysOnTop(true)

    if window.bringToTop then
        window:bringToTop()
    end

    LuaResetTool.window = window

    return window
end

--LuaResetTool.open()