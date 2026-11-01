ParadiseDev = ParadiseDev or {}
ParadiseDev.Builder = ParadiseDev.Builder or {}
local Builder = ParadiseDev.Builder

if not Builder.isB41 then
    function Builder.isB41()
        return getCore():getGameVersion():getMajor() == 41
    end
end
if Builder.isB41() then return end

require "Dev/Builder/ParadiseDev_Builder_Schema"
require "Dev/Builder/ParadiseDev_Builder_Doc"

Builder.Gen = Builder.Gen or {}
local Gen = Builder.Gen
local Schema = Builder.Schema
local Doc = Builder.Doc

function Gen.identifier(value)
    local str = string.gsub(tostring(value or ""), "[^%w_]", "_")
    if str == "" then str = "element" end
    if string.match(str, "^%d") then str = "_" .. str end
    return str
end

function Gen.upperFirst(value)
    if value == "" then return value end
    return string.upper(string.sub(value, 1, 1)) .. string.sub(value, 2)
end

function Gen.quote(value)
    local str = tostring(value)
    str = string.gsub(str, "\\", "\\\\")
    str = string.gsub(str, '"', '\\"')
    str = string.gsub(str, "\n", "\\n")
    return '"' .. str .. '"'
end

function Gen.number(value)
    local number = tonumber(value)
    if not number then return "0" end
    return tostring(number)
end

function Gen.literal(value, key)
    if key and Schema.isFontField(key) then
        return "UIFont." .. Gen.identifier(Schema.fontName(value) or tostring(value))
    end
    if type(value) == "number" then return Gen.number(value) end
    if type(value) == "boolean" then return tostring(value) end
    if Schema.isColor(value) then
        return string.format("{r=%s, g=%s, b=%s, a=%s}",
            Gen.number(value.r), Gen.number(value.g), Gen.number(value.b), Gen.number(value.a or 1))
    end
    if type(value) == "string" then return Gen.quote(value) end
    return nil
end

function Gen.segments(dotted)
    local list = {}
    for part in string.gmatch(tostring(dotted or ""), "([^%.]+)") do
        list[#list + 1] = Gen.identifier(part)
    end
    return list
end

function Gen.qualify(dotted, name)
    local path = table.concat(Gen.segments(dotted), ".")
    if path == "" then return Gen.identifier(name) end
    return path .. "." .. Gen.identifier(name)
end

function Gen.handlerName(element)
    local spec = Schema.get(element.type)
    if not spec or not spec.handlerProp then return nil end
    if element.type == "ISButton" then return "onButton" end
    return "on" .. Gen.upperFirst(Gen.identifier(element.name))
end

function Gen.yExpr(parentType, value)
    local number = tonumber(value) or 0
    if parentType == "ISCollapsableWindow" then
        if number == 0 then return "self:titleBarHeight()" end
        return "self:titleBarHeight() + " .. Gen.number(number)
    end
    return Gen.number(number)
end

function Gen.usesCtorHandler(spec)
    for _, entry in ipairs(spec.ctor or {}) do
        if entry == "@handler" then return true end
    end
    return false
end

function Gen.ctorArgs(element, classVar, parentType)
    local spec = Schema.get(element.type)
    local args = {}
    for _, entry in ipairs(spec and spec.ctor or {}) do
        if entry == "@self" then
            args[#args + 1] = "self"
        elseif entry == "@handler" then
            args[#args + 1] = classVar .. "." .. tostring(Gen.handlerName(element))
        elseif entry == "@texture" then
            local name = element.props.texture
            if name and name ~= "" then
                args[#args + 1] = 'getTexture(' .. Gen.quote(name) .. ')'
            end
        elseif entry == "y" then
            args[#args + 1] = Gen.yExpr(parentType, element.props.y)
        else
            args[#args + 1] = Gen.literal(element.props[entry], entry) or "0"
        end
    end
    return args
end

function Gen.assignments(element, ref)
    local spec = Schema.get(element.type)
    local callKeys = Schema.callKeys(element.type)
    local keys = {}
    for key in pairs(element.props) do keys[#keys + 1] = key end
    table.sort(keys)
    local lines = {}
    for _, key in ipairs(keys) do
        local skip = spec.readOnly[key]
            or Schema.isCtorProp(element.type, key)
            or callKeys[key]
            or key == "tabLabel"
        if not skip then
            local value
            if spec.wrapProp and spec.wrapProp[key] then
                local path = element.props[key]
                if type(path) == "string" and path ~= "" then
                    value = "getTexture(" .. Gen.quote(path) .. ")"
                end
            else
                value = Gen.literal(element.props[key], key)
            end
            if value then lines[#lines + 1] = ref .. "." .. key .. " = " .. value end
        end
    end
    return lines
end

function Gen.callLines(element, ref)
    local spec = Schema.get(element.type)
    local lines = {}
    for _, entry in ipairs(spec.call or {}) do
        if entry.list then
            for _, item in ipairs(Doc.splitList(element.props[entry.list])) do
                lines[#lines + 1] = ref .. ":" .. entry.m .. "(" .. Gen.quote(item) .. ")"
            end
        elseif entry.args then
            local parts = {}
            for _, name in ipairs(entry.args) do
                parts[#parts + 1] = Gen.literal(element.props[name], name) or "0"
            end
            lines[#lines + 1] = ref .. ":" .. entry.m .. "(" .. table.concat(parts, ", ") .. ")"
        elseif entry.prop then
            local value = Gen.literal(element.props[entry.prop], entry.prop)
            if value then
                if entry.set then
                    lines[#lines + 1] = ref .. "." .. entry.set .. " = " .. value
                else
                    lines[#lines + 1] = ref .. ":" .. entry.m .. "(" .. value .. ")"
                end
            end
        end
    end
    return lines
end

function Gen.footprint(doc)
    local root = Doc.root(doc)
    if not root then return nil end
    local props = root.props
    return {
        x = tonumber(props.x) or 20,
        y = tonumber(props.y) or 20,
        width = tonumber(props.width) or 560,
        height = tonumber(props.height) or 420,
    }
end

function Gen.panel(doc)
    if not doc or not doc.settings then return nil, "no document" end
    local settings = doc.settings
    local classVar = Gen.qualify(settings.namespace, settings.className)
    local moduleVar = Gen.qualify(settings.namespace, settings.module)
    local root = Doc.root(doc)
    if not root then return nil, "document has no root element" end
    local base = Schema.get(root.type)
    local baseClass = base.class
    local segments = Gen.segments(settings.namespace)
    local lines = {}

    lines[#lines + 1] = "-- generated by ParadiseDev.Builder"
    lines[#lines + 1] = segments[1] .. " = " .. segments[1] .. " or {}"
    lines[#lines + 1] = "if not " .. segments[1] .. ".isB41 then"
    lines[#lines + 1] = "    function " .. segments[1] .. ".isB41()"
    lines[#lines + 1] = "        return getCore():getGameVersion():getMajor() == 41"
    lines[#lines + 1] = "    end"
    lines[#lines + 1] = "end"
    lines[#lines + 1] = "if " .. segments[1] .. ".isB41() then return end"
    lines[#lines + 1] = ""
    local path = ""
    for _, segment in ipairs(segments) do
        path = path == "" and segment or path .. "." .. segment
        lines[#lines + 1] = path .. " = " .. path .. " or {}"
    end
    lines[#lines + 1] = ""
    for _, line in ipairs(Schema.requireLines(Builder.collectTypes(doc))) do
        lines[#lines + 1] = line
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = moduleVar .. " = " .. moduleVar .. " or {}"
    lines[#lines + 1] = ""
    lines[#lines + 1] = classVar .. " = " .. baseClass .. ':derive("' .. classVar .. '")'
    lines[#lines + 1] = ""

    lines[#lines + 1] = "function " .. classVar .. ":new(x, y, width, height)"
    lines[#lines + 1] = "    local panel = " .. baseClass .. ":new(x, y, width, height)"
    lines[#lines + 1] = "    setmetatable(panel, self)"
    lines[#lines + 1] = "    self.__index = self"
    for _, line in ipairs(Gen.assignments(root, "panel")) do
        lines[#lines + 1] = "    " .. line
    end
    lines[#lines + 1] = "    return panel"
    lines[#lines + 1] = "end"
    lines[#lines + 1] = ""

    lines[#lines + 1] = "function " .. classVar .. ":createChildren()"
    lines[#lines + 1] = "    " .. baseClass .. ".createChildren(self)"
    for _, element in ipairs(Gen.walk(doc)) do
        if element ~= root then
            local ref = "self." .. Gen.identifier(element.name)
            local parent = Doc.get(doc, element.parentId)
            local args = Gen.ctorArgs(element, classVar, parent and parent.type)
            local spec = Schema.get(element.type)
            lines[#lines + 1] = "    " .. ref .. " = " .. element.type .. ":new(" .. table.concat(args, ", ") .. ")"
            lines[#lines + 1] = "    " .. ref .. ":initialise()"
            if element.type == "ISButton" then
                lines[#lines + 1] = "    " .. ref .. '.internal = ' .. Gen.quote(string.upper(Gen.identifier(element.name)))
            end
            if spec.handlerTarget then
                lines[#lines + 1] = "    " .. ref .. "." .. spec.handlerTarget .. " = self"
            end
            local handler = Gen.handlerName(element)
            if handler and not Gen.usesCtorHandler(spec) then
                lines[#lines + 1] = "    " .. ref .. "." .. spec.handlerProp .. " = " .. classVar .. "." .. handler
            end
            for _, line in ipairs(Gen.assignments(element, ref)) do
                lines[#lines + 1] = "    " .. line
            end
            local parentRef = "self"
            if parent and parent ~= root then parentRef = "self." .. Gen.identifier(parent.name) end
            if parent and Schema.get(parent.type).tabContainer then
                lines[#lines + 1] = "    " .. parentRef .. ":addView(" .. Gen.quote(element.props.tabLabel or element.name) .. ", " .. ref .. ")"
            else
                lines[#lines + 1] = "    " .. parentRef .. ":addChild(" .. ref .. ")"
            end
            for _, line in ipairs(Gen.callLines(element, ref)) do
                lines[#lines + 1] = "    " .. line
            end
        end
    end
    lines[#lines + 1] = "end"
    lines[#lines + 1] = ""

    local buttonCases = {}
    local otherHandlers = {}
    for _, element in ipairs(Gen.walk(doc)) do
        local handler = element ~= root and Gen.handlerName(element) or nil
        if handler then
            if handler == "onButton" then
                buttonCases[#buttonCases + 1] = string.upper(Gen.identifier(element.name))
            else
                otherHandlers[#otherHandlers + 1] = { name = handler, element = element }
            end
        end
    end
    if #buttonCases > 0 then
        lines[#lines + 1] = "function " .. classVar .. ":onButton(button)"
        for index, case in ipairs(buttonCases) do
            local keyword = index == 1 and "if" or "elseif"
            lines[#lines + 1] = "    " .. keyword .. " button.internal == " .. Gen.quote(case) .. " then"
            lines[#lines + 1] = "        -- wire up"
        end
        lines[#lines + 1] = "    end"
        lines[#lines + 1] = "end"
        lines[#lines + 1] = ""
    end
    for _, entry in ipairs(otherHandlers) do
        lines[#lines + 1] = "function " .. classVar .. ":" .. entry.name .. "(value)"
        lines[#lines + 1] = "    -- wire up " .. entry.element.name
        lines[#lines + 1] = "end"
        lines[#lines + 1] = ""
    end

    lines[#lines + 1] = "function " .. classVar .. ":close()"
    lines[#lines + 1] = "    " .. moduleVar .. ".ClosePanel()"
    lines[#lines + 1] = "end"
    return table.concat(lines, "\n")
end

function Gen.walk(doc)
    local root = Doc.root(doc)
    if not root then return {} end
    local out = {}
    local function visit(element)
        out[#out + 1] = element
        for _, child in ipairs(Doc.children(doc, element.id)) do
            visit(child)
        end
    end
    visit(root)
    return out
end

function Gen.guard(dotted)
    local parts = {}
    local path = ""
    for _, segment in ipairs(Gen.segments(dotted)) do
        path = path == "" and segment or path .. "." .. segment
        parts[#parts + 1] = path
    end
    return table.concat(parts, " and ")
end

function Gen.registry(doc)
    if not doc or not doc.settings then return nil, "no document" end
    local settings = doc.settings
    local classVar = Gen.qualify(settings.namespace, settings.className)
    local moduleVar = Gen.qualify(settings.namespace, settings.module)
    local footprint = Gen.footprint(doc)
    local lines = {}
    lines[#lines + 1] = "-- add beside the other module tables at the top of ParadisePanels_table.lua"
    lines[#lines + 1] = settings.namespace .. " = " .. settings.namespace .. " or {}"
    lines[#lines + 1] = ""
    lines[#lines + 1] = "-- add inside ParadisePanels.table"
    lines[#lines + 1] = "{"
    lines[#lines + 1] = "    key = " .. Gen.quote(settings.panelKey) .. ","
    lines[#lines + 1] = "    isAdmOnly = " .. tostring(settings.adminOnly and true or false) .. ","
    lines[#lines + 1] = "    getModule = function() return " .. Gen.guard(moduleVar) .. " end,"
    lines[#lines + 1] = "    getInstance = function() return " .. Gen.guard(moduleVar) .. " and " .. moduleVar .. ".instance end,"
    lines[#lines + 1] = "    setInstance = function(instance) " .. moduleVar .. ".instance = instance end,"
    lines[#lines + 1] = "    create = function()"
    lines[#lines + 1] = "        return initialise(" .. classVar .. ":new(" .. footprint.x .. ", " .. footprint.y
        .. ", " .. footprint.width .. ", " .. footprint.height .. "))"
    lines[#lines + 1] = "    end,"
    lines[#lines + 1] = "},"
    return table.concat(lines, "\n")
end

function Gen.openers(doc)
    if not doc or not doc.settings then return nil, "no document" end
    local settings = doc.settings
    local moduleVar = Gen.qualify(settings.namespace, settings.module)
    local lines = { "-- paste into a client lua file" }
    lines[#lines + 1] = "-- debug console: " .. moduleVar .. ".OpenPanel()"
    for _, opener in ipairs(settings.openers or {}) do
        if opener == "keybind" then
            local owner = Gen.segments(settings.namespace)[1]
            lines[#lines + 1] = ""
            lines[#lines + 1] = "function " .. owner .. ".openBuilderByKey(key)"
            lines[#lines + 1] = "    if not getCore():getDebug() then return end"
            lines[#lines + 1] = "    if getCore():getKey(" .. Gen.quote(settings.bindName) .. ") == key then"
            lines[#lines + 1] = "        " .. moduleVar .. ".OpenPanel()"
            lines[#lines + 1] = "    end"
            lines[#lines + 1] = "end"
            lines[#lines + 1] = "getCore():addKeyBinding(" .. Gen.quote(settings.bindName) .. ", " .. settings.bindKey .. ", 0, false, false, false)"
            lines[#lines + 1] = "Events.OnKeyPressed.Remove(" .. owner .. ".openBuilderByKey)"
            lines[#lines + 1] = "Events.OnKeyPressed.Add(" .. owner .. ".openBuilderByKey)"
        elseif opener == "contextmenu" then
            lines[#lines + 1] = ""
            lines[#lines + 1] = "ParadiseDev.BuilderMenu = ParadiseDev.BuilderMenu or {}"
            lines[#lines + 1] = "function ParadiseDev.BuilderMenu.onWorldContext(plNum, context, worldobjects, test)"
            lines[#lines + 1] = "    if test or not context or not isAdmin() then return end"
            lines[#lines + 1] = "    context:addOption(" .. Gen.quote(settings.menuText) .. ", " .. moduleVar .. ", " .. moduleVar .. ".OpenPanel)"
            lines[#lines + 1] = "end"
            lines[#lines + 1] = "Events.OnFillWorldObjectContextMenu.Remove(ParadiseDev.BuilderMenu.onWorldContext)"
            lines[#lines + 1] = "Events.OnFillWorldObjectContextMenu.Add(ParadiseDev.BuilderMenu.onWorldContext)"
        end
    end
    return table.concat(lines, "\n")
end
