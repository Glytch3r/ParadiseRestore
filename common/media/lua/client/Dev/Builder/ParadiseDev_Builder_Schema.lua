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
    dock = true, contentHorizontalAlignment = true, style = true, gameOption = true,
    controller = true, joypadFocused = true, joyfocus = true, autoAddJoypadButton = true,
    mouseOver = true, isMouseOver = true, mouseDown = true, isMouseDown = true,
    doubleClick = true, hasKeyboardFocus = true, keyDown = true, dragged = true,
    grabbed = true, lastMouseX2 = true, lastMouseY2 = true, lastActiveX = true,
    lastActiveY = true, oldX = true, oldY = true, oldWidth = true, oldHeight = true,
    oldAbsoluteX = true, oldAbsoluteY = true, initialWidth = true, initialHeight = true,
    resizeWidget = true, resizeWidgetY = true, textPrinted = true,
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
    tabContainer = true,
    defaults = { width = 400, height = 300 },
})

define("ISButton", {
    ctor = { "x", "y", "width", "height", "title", "@self", "@handler" },
    textProp = "title",
    handlerProp = "onClick",
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
    textProp = "text",
    defaults = { width = 300, height = 160, text = "Text" },
    call = { { m = "setText", prop = "text" } },
})

define("ISScrollingListBox", {
    handlerProp = "onmousedown",
    handlerTarget = "target",
    doDrawItem = true,
    defaults = { width = 260, height = 200, items = "One,Two,Three", font = "Small", itemheight = 22 },
    call = { { m = "addItem", list = "items" } },
})

define("ISTextEntryBox", {
    ctor = { "title", "x", "y", "width", "height" },
    textProp = "title",
    defaults = { title = "", width = 160, height = 26, multipleLine = false, editable = true },
    call = { { m = "setEditable", prop = "editable" }, { m = "setMultipleLine", prop = "multipleLine" } },
})

define("ISComboBox", {
    ctor = { "x", "y", "width", "height", "@self", "@handler" },
    handlerProp = "onChange",
    tooltipField = true,
    defaults = { width = 160, height = 26, options = "One,Two,Three" },
    call = { { m = "addOption", list = "options" } },
})

define("ISTickBox", {
    ctor = { "x", "y", "width", "height", "name", "@self", "@handler" },
    handlerProp = "onChange",
    tooltipField = true,
    textProp = "name",
    defaults = { width = 160, height = 26, name = "Option", options = "", checked = false },
    call = { { m = "addOption", list = "options" }, { set = "selected[1]", prop = "checked" } },
})

define("ISRadioButtons", {
    ctor = { "x", "y", "width", "height", "@self", "@handler" },
    handlerProp = "onChange",
    tooltipField = true,
    defaults = { width = 160, height = 60, options = "One,Two", selected = 0 },
    call = { { m = "addOption", list = "options" }, { m = "setSelected", prop = "selected" } },
})

define("ISSliderPanel", {
    class = "ISSliderPanel",
    requires = { "RadioCom/ISUIRadio/ISSliderPanel" },
    ctor = { "x", "y", "width", "height", "@self", "@handler" },
    handlerProp = "onChange",
    defaults = { width = 180, height = 24, min = 0, max = 100, step = 1, value = 50 },
    call = { { m = "setValues", args = { "min", "max", "step" } }, { m = "setCurrentValue", prop = "value" } },
})

define("ISProgressBar", {
    ctor = { "x", "y", "width", "height", "text", "font" },
    textProp = "text",
    defaults = { width = 200, height = 20, text = "", font = "Small", value = 0 },
    call = { { m = "setProgress", prop = "value" } },
})

define("ISVolumeControl", {
    ctor = { "x", "y", "width", "height", "@self", "@handler" },
    handlerProp = "onChange",
    defaults = { width = 30, height = 120, volume = 5 },
    call = { { m = "setVolume", prop = "volume" } },
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

function Schema.isColor(value)
    return type(value) == "table"
        and type(rawget(value, "r")) == "number"
        and type(rawget(value, "g")) == "number"
        and type(rawget(value, "b")) == "number"
end

function Schema.kindOf(key, value)
    if Schema.isFontField(key) then return "font" end
    if Schema.isColor(value) then return "color" end
    local kind = type(value)
    if kind == "number" or kind == "boolean" or kind == "string" then return kind end
    return nil
end

function Schema.isCtorProp(type, key)
    local spec = Schema.elements[type]
    if not spec then return false end
    for _, entry in ipairs(spec.ctor) do
        if entry == key then return true end
    end
    return false
end

function Schema.callKeys(type)
    local spec = Schema.elements[type]
    local set = {}
    for _, entry in ipairs(spec and spec.call or {}) do
        if entry.list then set[entry.list] = true end
        if entry.prop then set[entry.prop] = true end
        for _, name in ipairs(entry.args or {}) do set[name] = true end
    end
    return set
end

Schema.anchorFields = { anchorLeft = true, anchorRight = true, anchorTop = true, anchorBottom = true }

function Schema.liveFields(element)
    local out = {}
    if type(element) ~= "table" then return out end
    for key, value in pairs(element) do
        if not Schema.skipField(key) then
            local kind = Schema.kindOf(key, value)
            if kind then out[#out + 1] = { key = key, kind = kind, value = value } end
        end
    end
    table.sort(out, function(a, b) return a.key < b.key end)
    return out
end

function Schema.fontOptions()
    local list = {}
    for _, name in ipairs(Schema.fonts) do
        if UIFont and UIFont[name] then list[#list + 1] = name end
    end
    return list
end

function Schema.fontName(value)
    if type(value) ~= "string" then
        for _, name in ipairs(Schema.fonts) do
            if UIFont and UIFont[name] == value then return name end
        end
        return nil
    end
    for _, name in ipairs(Schema.fonts) do
        if name == value then return name end
    end
    return nil
end

function Builder.collectTypes(doc)
    local types = {}
    for _, element in pairs(doc and doc.elements or {}) do
        types[#types + 1] = element.type
    end
    return types
end
