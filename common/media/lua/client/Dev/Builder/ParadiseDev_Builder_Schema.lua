ParadiseDev = ParadiseDev or {}
ParadiseDev.Builder = ParadiseDev.Builder or {}
local Builder = ParadiseDev.Builder

if not Builder.isB41 then
    function Builder.isB41()
        return getCore():getGameVersion():getMajor() == 41
    end
end
if Builder.isB41() then return end

Builder.Schema = Builder.Schema or {}
local Schema = Builder.Schema

Schema.skipFields = {
    Type = true, SuperType = true, children = true, childrenInOrder = true, ID = true,
    javaObject = true, parent = true, vscroll = true, hscroll = true, removed = true,
    creationCallStack = true, downX = true, downY = true, moving = true,
}

Schema.fonts = { "Small", "Medium", "Large", "NewSmall", "NewMedium", "NewLarge", "Code", "Handwritten", "DebugConsole" }

Schema.order = {
    "ISCollapsableWindow", "ISPanel", "ISWindow", "ISTabPanel",
    "ISButton", "ISLabel", "ISImage", "ISRichTextPanel", "ISScrollingListBox",
    "ISTextEntryBox", "ISComboBox", "ISTickBox", "ISRadioButtons",
    "ISSliderPanel", "ISProgressBar", "ISVolumeControl",
}

Schema.elements = {}

local function define(type, spec)
    spec.class = spec.class or type
    spec.requires = spec.requires or { "ISUI/" .. type }
    spec.acceptsChildren = spec.acceptsChildren or false
    spec.ctor = spec.ctor or { "x", "y", "width", "height" }
    spec.readOnly = spec.readOnly or {}
    spec.call = spec.call or {}
    spec.defaults = spec.defaults or {}
    Schema.elements[type] = spec
end

define("ISCollapsableWindow", {
    acceptsChildren = true,
    textProp = "title",
    rootOnly = true,
    defaults = { title = "My Panel", width = 560, height = 420, resizable = true },
})

define("ISPanel", {
    acceptsChildren = true,
    defaults = { width = 200, height = 120 },
})

define("ISWindow", {
    acceptsChildren = true,
    ctor = { "title", "x", "y", "width", "height" },
    textProp = "title",
    defaults = { title = "Window", width = 240, height = 160 },
})

define("ISTabPanel", {
    acceptsChildren = true,
    special = "tabView",
    defaults = { width = 400, height = 300, tabs = "First,Second" },
})

define("ISButton", {
    ctor = { "x", "y", "width", "height", "title", "@self", "@handler" },
    textProp = "title",
    handlerProp = "onClick",
    handlerName = "onButton",
    tooltipField = true,
    defaults = { width = 120, height = 30, title = "Button" },
})

define("ISLabel", {
    ctor = { "x", "y", "height", "name", "r", "g", "b", "a", "font", "bLeft" },
    textProp = "name",
    readOnly = { width = true },
    tooltipField = true,
    defaults = { height = 16, name = "Label", r = 1, g = 1, b = 1, a = 1, font = "Small", bLeft = true },
})

define("ISImage", {
    ctor = { "x", "y", "width", "height", "@texture" },
    wrapProp = { texture = 'getTexture("%s")' },
    textProp = "texture",
    defaults = { width = 32, height = 32, texture = "" },
})

define("ISRichTextPanel", {
    special = "richText",
    textProp = "text",
    defaults = { width = 300, height = 160, text = "Text", scrollBars = true },
    call = { { m = "setText", str = "text" } },
})

define("ISScrollingListBox", {
    special = "listBox",
    handlerProp = "onSelect",
    handlerName = "onSelect",
    defaults = { width = 260, height = 200, items = "One,Two,Three" },
    call = { { m = "addItem", list = "items" } },
})

define("ISTextEntryBox", {
    ctor = { "title", "x", "y", "width", "height" },
    special = "entryBox",
    textProp = "title",
    defaults = { title = "", width = 160, height = 26, multipleLine = false, editable = true },
})

define("ISComboBox", {
    ctor = { "x", "y", "width", "height", "@self", "@handler" },
    handlerProp = "onChange",
    handlerName = "onChange",
    tooltipField = true,
    defaults = { width = 160, height = 26, options = "One,Two,Three" },
    call = { { m = "addOption", list = "options" } },
})

define("ISTickBox", {
    ctor = { "x", "y", "width", "height", "name", "@self", "@handler" },
    special = "tickBox",
    handlerProp = "onChange",
    handlerName = "onChange",
    tooltipField = true,
    textProp = "name",
    defaults = { width = 160, height = 26, name = "Option", options = "", selected = false },
    call = { { m = "addOption", list = "options" } },
})

define("ISRadioButtons", {
    ctor = { "x", "y", "width", "height", "@self", "@handler" },
    handlerProp = "onChange",
    handlerName = "onChange",
    tooltipField = true,
    defaults = { width = 160, height = 60, options = "One,Two", selected = 0 },
    call = { { m = "addOption", list = "options" }, { m = "setSelected", num = "selected", min = 1 } },
})

define("ISSliderPanel", {
    class = "ISSliderPanel",
    requires = { "RadioCom/ISUIRadio/ISSliderPanel" },
    ctor = { "x", "y", "width", "height", "@self", "@handler" },
    special = "slider",
    handlerProp = "onChange",
    handlerName = "onChange",
    defaults = { width = 180, height = 24, min = 0, max = 100, step = 1, value = 50 },
})

define("ISProgressBar", {
    ctor = { "x", "y", "width", "height", "text", "font" },
    textProp = "text",
    defaults = { width = 200, height = 20, text = "", font = "Small", value = 0 },
    call = { { m = "setProgress", num = "value" } },
})

define("ISVolumeControl", {
    ctor = { "x", "y", "width", "height", "@self", "@handler" },
    handlerProp = "onChange",
    handlerName = "onChange",
    defaults = { width = 30, height = 120, volume = 5 },
    call = { { m = "setVolume", num = "volume", clamp = { 0, 10 } } },
})

function Schema.get(type)
    return Schema.elements[type]
end

function Schema.isKnown(type)
    return Schema.elements[type] ~= nil
end

function Schema.newProps(type)
    local spec = Schema.elements[type]
    if not spec then return {} end
    local props = { x = 0, y = 0, width = 100, height = 24 }
    for key, value in pairs(spec.defaults) do
        props[key] = value
    end
    return props
end

function Schema.acceptsChildren(type)
    local spec = Schema.elements[type]
    return spec ~= nil and spec.acceptsChildren
end

function Schema.requireLines(doc_types)
    local seen = {}
    local lines = {}
    for _, type in ipairs(doc_types) do
        local spec = Schema.elements[type]
        if spec then
            for _, path in ipairs(spec.requires) do
                if not seen[path] then
                    seen[path] = true
                    lines[#lines + 1] = 'require "' .. path .. '"'
                end
            end
        end
    end
    table.sort(lines)
    return lines
end

function Schema.skipField(key)
    return Schema.skipFields[key] == true
end

function Schema.isFontField(key)
    return key == "font" or key == "defaultFont" or key == "titleFont"
end

function Builder.collectTypes(doc)
    local types = {}
    for _, element in pairs(doc and doc.elements or {}) do
        types[#types + 1] = element.type
    end
    return types
end
