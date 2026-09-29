package.preload["ISUI/ISCollapsableWindow"] = function() return true end
package.preload["ISUI/ISScrollingListBox"] = function() return true end

ISCollapsableWindow = {}
function ISCollapsableWindow:derive()
    local derived = {}
    derived.__index = derived
    setmetatable(derived, { __index = self })
    return derived
end

UIManager = { getUI = function() return nil end }

dofile("common/media/lua/client/Dev/DBG/ParadiseDev_UIInspector.lua")

assert(ParadiseDev.UI.Panel, "inspector must derive an ISCollapsableWindow panel")

local width
local height
local panel = {
    width = 700,
    height = 500,
    list = {
        setX = function() end,
        setY = function() end,
        setWidth = function(_, value) width = value end,
        setHeight = function(_, value) height = value end,
    },
    titleBarHeight = function() return 20 end,
    resizeWidgetHeight = function() return 10 end,
}

ParadiseDev.UI.layoutPanel(panel)

assert(width == 676, "list width must follow the panel width")
assert(height == 446, "list height must follow the panel height")
