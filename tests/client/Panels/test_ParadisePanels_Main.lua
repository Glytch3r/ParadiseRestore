local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertTrue(value, message)
    if value ~= true then error(message or "expected true", 2) end
end

local function assertNil(value, message)
    if value ~= nil then error((message or "expected nil") .. ", got " .. tostring(value), 2) end
end

local eventHandlers = {}
Events = {
    OnGameStart = {
        Add = function(callback) eventHandlers[callback] = true end,
        Remove = function(callback) eventHandlers[callback] = nil end,
    },
}

ParadiseRestore = { isAdm = function() return true end }
ParadisePanels = { table = {} }

local originalRequire = require
require = function(module)
    if module == "Panels/ParadisePanels_table" then return true end
    return originalRequire(module)
end

dofile("42.20/media/lua/client/Panels/ParadisePanels_Main.lua")

local instance
local module = {}
local creates = 0
local opens = 0
local closes = 0
local receivedA
local receivedB

local function newInstance()
    return {
        visible = false,
        added = 0,
        removed = 0,
        brought = 0,
        setVisible = function(self, visible) self.visible = visible end,
        addToUIManager = function(self) self.added = self.added + 1 end,
        removeFromUIManager = function(self) self.removed = self.removed + 1 end,
        bringToTop = function(self) self.brought = self.brought + 1 end,
    }
end

local entry = {
    key = "sample",
    isAdmOnly = true,
    getModule = function() return module end,
    getInstance = function() return instance end,
    setInstance = function(value) instance = value end,
    create = function(a, b)
        creates = creates + 1
        receivedA, receivedB = a, b
        return newInstance()
    end,
    onOpen = function(_, a, b)
        opens = opens + 1
        receivedA, receivedB = a, b
    end,
    onClose = function() closes = closes + 1 end,
}
ParadisePanels.table = { entry }

assertEqual(ParadisePanels.Install(), 1, "one entry installs")
assertTrue(type(module.OpenPanel) == "function", "OpenPanel installed")
assertTrue(type(module.ClosePanel) == "function", "ClosePanel installed")
assertTrue(type(module.TogglePanel) == "function", "TogglePanel installed")

local opened = module.OpenPanel("first", 42)
assertEqual(creates, 1, "open creates once")
assertEqual(opens, 1, "open hook runs")
assertEqual(receivedA, "first", "first argument forwarded")
assertEqual(receivedB, 42, "second argument forwarded")
assertTrue(opened.visible, "opened instance visible")
assertEqual(opened.added, 1, "opened instance added")

local reopened = module.OpenPanel("second", 84)
assertEqual(reopened, opened, "open reuses instance")
assertEqual(creates, 1, "repeat open does not create")
assertEqual(opens, 2, "repeat open refreshes")
assertEqual(receivedA, "second", "repeat argument forwarded")
assertEqual(receivedB, 84, "repeat second argument forwarded")

module.ClosePanel()
assertEqual(closes, 1, "close hook runs once")
assertEqual(opened.removed, 1, "instance removed")
assertNil(instance, "instance cleared")
module.ClosePanel()
assertEqual(closes, 1, "repeat close is idempotent")

local toggled = module.TogglePanel("toggle", 7)
assertTrue(toggled ~= nil, "toggle opens missing panel")
module.TogglePanel()
assertNil(instance, "toggle closes existing panel")

ParadiseRestore.isAdm = function() return false end
assertNil(module.OpenPanel("denied"), "admin panel denied")
assertEqual(creates, 2, "denied open does not create")
ParadiseRestore.isAdm = function() return true end

local lateModule
local lateEntry = {
    key = "late",
    isAdmOnly = false,
    getModule = function() return lateModule end,
    getInstance = function() return nil end,
    setInstance = function() end,
    create = function() return newInstance() end,
}
ParadisePanels.table = { lateEntry }
assertEqual(ParadisePanels.Install(), 0, "missing module skipped")
lateModule = {}
assertEqual(ParadisePanels.Install(), 1, "late module installs on retry")
assertTrue(type(lateModule.OpenPanel) == "function", "late module receives API")

ParadisePanels.table = {
    entry,
    {
        key = "sample",
        isAdmOnly = false,
        getModule = function() return {} end,
        getInstance = function() return nil end,
        setInstance = function() end,
        create = function() return newInstance() end,
    },
    {
        isAdmOnly = false,
        getModule = function() return {} end,
        getInstance = function() return nil end,
        setInstance = function() end,
        create = function() return newInstance() end,
    },
}
assertEqual(ParadisePanels.Install(), 1, "duplicate and missing keys rejected")
assertEqual(ParadisePanels.Install(), 1, "repeat installation remains safe")

local eventCount = 0
for _ in pairs(eventHandlers) do eventCount = eventCount + 1 end
assertEqual(eventCount, 1, "install event registered once")

print("PASS test_ParadisePanels_Main")
