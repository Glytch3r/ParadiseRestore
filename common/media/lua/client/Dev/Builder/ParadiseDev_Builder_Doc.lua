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

Builder.Doc = Builder.Doc or {}
local Doc = Builder.Doc
local Schema = Builder.Schema

Doc.FOLDER = "Builder/"
Doc.EXT = ".txt"
Doc.VERSION = 1
Doc.saved = {}

local ESCAPES = {
    { raw = "\\", code = "\\" },
    { raw = "|", code = "p" },
    { raw = ",", code = "c" },
    { raw = "=", code = "e" },
    { raw = "\n", code = "n" },
}

function Doc.escape(value)
    local str = tostring(value)
    for _, pair in ipairs(ESCAPES) do
        str = string.gsub(str, pair.raw, "\\" .. pair.code)
    end
    return str
end

function Doc.unescape(value)
    local out = {}
    local index = 1
    local len = #value
    while index <= len do
        local char = string.sub(value, index, index)
        if char == "\\" and index < len then
            local code = string.sub(value, index + 1, index + 1)
            local mapped = nil
            for _, pair in ipairs(ESCAPES) do
                if pair.code == code then mapped = pair.raw break end
            end
            if mapped then
                out[#out + 1] = mapped
                index = index + 2
            else
                out[#out + 1] = code
                index = index + 2
            end
        else
            out[#out + 1] = char
            index = index + 1
        end
    end
    return table.concat(out, "")
end

function Doc.sanitize(value)
    local str = tostring(value or "")
    str = string.gsub(str, "[^%a%d_]", "_")
    if string.match(str, "^%d") then str = "_" .. str end
    if str == "" then str = "panel" end
    return str
end

function Doc.moduleName(className)
    local stripped = string.match(className, "^(.-)Panel$")
    if not stripped or stripped == "" then return className .. "UI" end
    return stripped
end

function Doc.newSettings(className)
    local name = Doc.sanitize(className or "MyFeaturePanel")
    return {
        className = name,
        module = Doc.moduleName(name),
        namespace = "ParadiseDev.Panels",
        panelKey = string.gsub(name, "^.", function(first) return string.lower(first) end),
        adminOnly = true,
        sectionLabel = "ParadiseDev",
        openers = { "debug" },
        bindName = "ToggleParadiseUIBuilder",
        bindKey = "Keyboard.KEY_F9",
        menuText = name,
    }
end

function Doc.newDoc(className)
    local settings = Doc.newSettings(className or "MyFeaturePanel")
    local doc = { name = settings.className, nextId = 1, elements = {}, settings = settings }
    local root = Doc.addElement(doc, "ISCollapsableWindow", nil)
    root.name = "panel"
    root.props.title = "My Panel"
    return doc
end

function Doc.get(doc, id)
    return doc.elements[id]
end

function Doc.root(doc)
    for _, element in pairs(doc.elements) do
        if not element.parentId then return element end
    end
    return nil
end

function Doc.children(doc, id)
    local element = doc.elements[id]
    if not element then return {} end
    local list = {}
    for _, childId in ipairs(element.childIds) do
        local child = doc.elements[childId]
        if child then list[#list + 1] = child end
    end
    return list
end

function Doc.descendants(doc, id, out)
    out = out or {}
    for _, child in ipairs(Doc.children(doc, id)) do
        out[#out + 1] = child
        Doc.descendants(doc, child.id, out)
    end
    return out
end

function Doc.uniqueName(doc, parentId, base)
    local name = Doc.sanitize(base)
    local parent = parentId and doc.elements[parentId] or { childIds = {} }
    local taken = {}
    for _, childId in ipairs(parent.childIds) do
        local child = doc.elements[childId]
        if child then taken[child.name] = true end
    end
    if not taken[name] then return name end
    local suffix = 2
    while taken[name .. suffix] do suffix = suffix + 1 end
    return name .. suffix
end

function Doc.coerce(text)
    if text == "true" then return true end
    if text == "false" then return false end
    local number = tonumber(text)
    if number then return number end
    return text
end

function Doc.baseName(type)
    local stripped = string.sub(type, 3)
    if string.sub(stripped, 1, 1) == string.upper(string.sub(stripped, 1, 1)) then
        stripped = string.lower(string.sub(stripped, 1, 1)) .. string.sub(stripped, 2)
    end
    return stripped
end

function Doc.addElement(doc, type, parentId)
    local spec = Schema.get(type)
    if not spec then
        return nil, "unknown element type: " .. tostring(type)
    end
    local parent = nil
    if parentId then
        parent = doc.elements[parentId]
        if not parent then return nil, "unknown parent id" end
        if not Schema.acceptsChildren(parent.type) then
            parent = Doc.root(doc)
        end
    else
        parent = Doc.root(doc)
    end
    if not parent and not spec.acceptsChildren then
        return nil, "a layout root must be able to contain children"
    end

    local id = doc.nextId
    doc.nextId = doc.nextId + 1
    local element = {
        id = id,
        type = type,
        parentId = parent and parent.id or nil,
        childIds = {},
        props = Schema.newProps(type),
    }
    element.name = Doc.uniqueName(doc, element.parentId, Doc.baseName(type))
    doc.elements[id] = element
    if parent then parent.childIds[#parent.childIds + 1] = id end
    element.props.x = 10
    element.props.y = 10
    return element
end

function Doc.remove(doc, id)
    local element = doc.elements[id]
    if not element then return false, "nothing to remove" end
    if not element.parentId then return false, "the root element cannot be removed" end
    local parent = doc.elements[element.parentId]
    if parent then
        for index, childId in ipairs(parent.childIds) do
            if childId == id then
                table.remove(parent.childIds, index)
                break
            end
        end
    end
    for _, dead in ipairs(Doc.descendants(doc, id)) do
        doc.elements[dead.id] = nil
    end
    doc.elements[id] = nil
    return true
end

function Doc.reparent(doc, id, newParentId)
    local element = doc.elements[id]
    if not element or not element.parentId then return false, "cannot move the root" end
    if newParentId == id then return false, "an element cannot parent itself" end
    for _, child in ipairs(Doc.descendants(doc, id)) do
        if child.id == newParentId then return false, "cannot move an element inside itself" end
    end
    local target = doc.elements[newParentId]
    if not target or not Schema.acceptsChildren(target.type) then return false, "target cannot contain children" end
    local oldParent = doc.elements[element.parentId]
    if oldParent then
        for index, childId in ipairs(oldParent.childIds) do
            if childId == id then
                table.remove(oldParent.childIds, index)
                break
            end
        end
    end
    element.parentId = newParentId
    target.childIds[#target.childIds + 1] = id
    element.name = Doc.uniqueName(doc, newParentId, element.name)
    return true
end

function Doc.moveWithinParent(doc, id, delta)
    local element = doc.elements[id]
    if not element or not element.parentId then return false end
    local parent = doc.elements[element.parentId]
    if not parent then return false end
    local position = nil
    for index, childId in ipairs(parent.childIds) do
        if childId == id then position = index break end
    end
    if not position then return false end
    local target = position + delta
    if target < 1 or target > #parent.childIds then return false end
    table.remove(parent.childIds, position)
    table.insert(parent.childIds, target, id)
    return true
end

function Doc.splitList(value)
    local list = {}
    for part in string.gmatch(tostring(value or ""), "[^,]+") do
        local trimmed = string.match(part, "^%s*(.-)%s*$")
        if trimmed ~= "" then list[#list + 1] = trimmed end
    end
    return list
end

function Doc.tag(value)
    if type(value) == "number" then return "n" end
    if type(value) == "boolean" then return "b" end
    if Doc.isColor(value) then return "c" end
    return "s"
end

function Doc.isColor(value)
    return type(value) == "table"
        and type(rawget(value, "r")) == "number"
        and type(rawget(value, "g")) == "number"
        and type(rawget(value, "b")) == "number"
end

Doc.settingKeys = {
    { key = "class", field = "className" },
    { key = "module", field = "module" },
    { key = "namespace", field = "namespace" },
    { key = "key", field = "panelKey" },
    { key = "admOnly", field = "adminOnly", bool = true },
    { key = "section", field = "sectionLabel" },
    { key = "openers", field = "openers", list = true },
    { key = "bindName", field = "bindName" },
    { key = "bindKey", field = "bindKey" },
    { key = "menuText", field = "menuText" },
}

function Doc.encodeSettings(settings)
    local parts = {}
    for _, entry in ipairs(Doc.settingKeys) do
        local value = settings[entry.field]
        if value ~= nil then
            if entry.list then
                value = table.concat(value, ",")
            elseif entry.bool then
                value = tostring(value and true or false)
            end
            parts[#parts + 1] = entry.key .. "=" .. Doc.escape(value)
        end
    end
    return "s=" .. table.concat(parts, ";")
end

function Doc.applySetting(settings, key, value)
    for _, entry in ipairs(Doc.settingKeys) do
        if entry.key == key then
            if entry.list then
                settings[entry.field] = Doc.splitList(value)
            elseif entry.bool then
                settings[entry.field] = value == "true"
            else
                settings[entry.field] = value
            end
            return true
        end
    end
    return false
end

function Doc.encode(doc)
    local lines = { "v=" .. Doc.VERSION, Doc.encodeSettings(doc.settings) }

    local ids = {}
    for id in pairs(doc.elements) do ids[#ids + 1] = id end
    table.sort(ids)

    for _, id in ipairs(ids) do
        local element = doc.elements[id]
        lines[#lines + 1] = table.concat({
            "e=" .. id, element.type, Doc.escape(element.name), tostring(element.parentId or 0),
        }, "|")

        local keys = {}
        for key in pairs(element.props) do keys[#keys + 1] = key end
        table.sort(keys)
        for _, key in ipairs(keys) do
            local value = element.props[key]
            local tag = Doc.tag(value)
            local text
            if tag == "c" then
                text = table.concat({ value.r, value.g, value.b, value.a or 1 }, ":")
            else
                text = tostring(value)
            end
            lines[#lines + 1] = table.concat({ "p=" .. id, Doc.escape(key), tag, Doc.escape(text) }, "|")
        end
    end
    return table.concat(lines, "\n")
end

function Doc.applyValue(element, key, tag, text)
    local value = Doc.unescape(text)
    if tag == "n" then
        element.props[key] = tonumber(value)
    elseif tag == "b" then
        element.props[key] = value == "true"
    elseif tag == "c" then
        local channels = {}
        for part in string.gmatch(value, "([^:]+)") do channels[#channels + 1] = tonumber(part) end
        element.props[key] = {
            r = channels[1] or 0, g = channels[2] or 0,
            b = channels[3] or 0, a = channels[4] or 1,
        }
    else
        element.props[key] = value
    end
end

function Doc.decode(text)
    if type(text) ~= "string" or text == "" then return nil, "empty layout" end
    local doc = {
        name = "MyFeaturePanel", nextId = 1, elements = {},
        settings = Doc.newSettings("MyFeaturePanel"),
    }
    local version = 0

    for line in string.gmatch(text, "([^\r\n]+)") do
        local head = string.match(line, "^([^=]+)=")
        if head then
            local body = string.sub(line, #head + 2)
            local fields = {}
            for part in string.gmatch(body .. "|", "(.-)|") do fields[#fields + 1] = part end
            if head == "v" then
                version = tonumber(fields[1]) or 0
            elseif head == "s" then
                for entry in string.gmatch(body, "([^;]+)") do
                    local key = string.match(entry, "^([^=]+)")
                    local value = string.sub(entry, #key + 2)
                    key = Doc.unescape(key)
                    value = Doc.unescape(value)
                    if Doc.applySetting(doc.settings, key, value) and key == "class" then
                        doc.name = value
                    end
                end
            elseif head == "e" then
                local id = tonumber(fields[1])
                local type = fields[2]
                if not id or not type then return nil, "malformed element line: " .. line end
                if not Schema.isKnown(type) then
                    print("[ParadiseDev.Builder] skipping unknown element type at index " .. tostring(id) .. ": " .. type)
                    doc.skipped = doc.skipped or {}
                    doc.skipped[id] = type
                else
                    doc.elements[id] = {
                        id = id,
                        type = type,
                        name = Doc.unescape(fields[3] or "element"),
                        parentId = tonumber(fields[4]) or 0,
                        childIds = {},
                        props = Schema.newProps(type),
                    }
                    if id >= doc.nextId then doc.nextId = id + 1 end
                end
            elseif head == "p" then
                local id = tonumber(fields[1])
                local element = id and doc.elements[id] or nil
                if element and fields[2] then
                    Doc.applyValue(element, Doc.unescape(fields[2]), fields[3] or "s", fields[4] or "")
                end
            end
        end
    end

    if version < 1 then return nil, "layout is missing a version header" end

    if doc.skipped then
        for _, element in pairs(doc.elements) do
            if doc.skipped[element.parentId] then element.parentId = 0 end
        end
        doc.skipped = nil
    end

    for _, element in pairs(doc.elements) do
        local parent = element.parentId ~= 0 and doc.elements[element.parentId] or nil
        if parent and Schema.acceptsChildren(parent.type) then
            parent.childIds[#parent.childIds + 1] = element.id
        else
            element.parentId = nil
        end
    end
    if not Doc.root(doc) then return nil, "layout has no root element" end
    for _, element in pairs(doc.elements) do
        if element.parentId == 0 then element.parentId = nil end
    end
    local roots = 0
    for _, element in pairs(doc.elements) do
        if not element.parentId then roots = roots + 1 end
    end
    if roots > 1 then return nil, "layout declares more than one root element" end
    return doc
end

function Doc.fileName(name)
    return Doc.FOLDER .. Doc.sanitize(name or Doc.defaultName()) .. Doc.EXT
end

function Doc.defaultName()
    return Builder.doc and Builder.doc.settings.className or "Untitled"
end

function Doc.save(name, doc)
    doc = doc or Builder.doc
    if not doc then return false, "no document" end
    local target = name or doc.settings.className
    local ok, writer = pcall(getFileWriter, Doc.fileName(target), true, false)
    if not ok or not writer then return false, "unable to open " .. Doc.fileName(target) end
    writer:write(Doc.encode(doc))
    writer:close()
    Doc.saved[target] = true
    return true, Doc.fileName(target)
end

function Doc.read(name)
    local ok, reader = pcall(getFileReader, Doc.fileName(name), false)
    if not ok or not reader then return nil, "no such layout: " .. Doc.fileName(name) end
    local lines = {}
    local readOk, line = pcall(reader.readLine, reader)
    while readOk and line do
        lines[#lines + 1] = line
        readOk, line = pcall(reader.readLine, reader)
    end
    pcall(reader.close, reader)
    return table.concat(lines, "\n")
end

function Doc.load(name)
    local text, err = Doc.read(name)
    if not text then return nil, err end
    local doc, decodeErr = Doc.decode(text)
    if not doc then return nil, decodeErr end
    Builder.doc = doc
    Doc.saved[name] = true
    return doc
end

function Doc.listSaved()
    local names = {}
    for name in pairs(Doc.saved) do names[#names + 1] = name end
    table.sort(names)
    return names
end
