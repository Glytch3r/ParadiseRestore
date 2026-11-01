ParadiseDev = ParadiseDev or {}
ParadiseDev.Builder = ParadiseDev.Builder or {}
local Builder = ParadiseDev.Builder

if not Builder.isB41 then
    function Builder.isB41()
        return getCore():getGameVersion():getMajor() == 41
    end
end
if Builder.isB41() then return end

Builder.Doc = Builder.Doc or {}
local Doc = Builder.Doc
local Schema = Builder.Schema

Doc.FOLDER = "Builder/"
Doc.EXT = ".txt"
Doc.VERSION = 1

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

function Doc.newDoc(className)
    local name = Doc.sanitize(className or "MyFeaturePanel")
    local doc = {
        name = name,
        nextId = 1,
        elements = {},
        settings = {
            className = name,
            namespace = "ParadiseDev.Panels",
            panelKey = string.gsub(name, "^.", function(first) return string.lower(first) end),
            adminOnly = true,
            sectionLabel = "ParadiseDev",
        },
    }
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

function Doc.addElement(doc, type, parentId)
    if not Schema.isKnown(type) then
        return nil, "unknown element type: " .. tostring(type)
    end
    local parent = nil
    if parentId then
        parent = doc.elements[parentId]
        if not parent then return nil, "unknown parent id" end
        if not Schema.acceptsChildren(parent.type) then
            parent = nil
        end
    end
    if not parent then parent = Doc.root(doc) end
    if not parent then return nil, "document has no root element" end

    local id = doc.nextId
    doc.nextId = doc.nextId + 1
    local base = string.gsub(type, "^IS", string.lower(string.sub(type, 3, 3)))
    local element = {
        id = id,
        type = type,
        name = Doc.uniqueName(doc, parent.id, base),
        parentId = parent.id,
        childIds = {},
        props = Schema.newProps(type),
    }
    element.props.x = 10
    element.props.y = 10
    doc.elements[id] = element
    parent.childIds[#parent.childIds + 1] = id
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

function Doc.ctorProps(type)
    local spec = Schema.elements[type]
    local list = {}
    if not spec then return list end
    for _, entry in ipairs(spec.ctor) do
        if not string.match(entry, "^@") and not spec.readOnly[entry] then
            list[#list + 1] = entry
        end
    end
    return list
end

function Doc.encode(doc)
    local lines = { "v=" .. Doc.VERSION }
    local settings = doc.settings
    lines[#lines + 1] = table.concat({
        "s=class=" .. Doc.escape(settings.className),
        "namespace=" .. Doc.escape(settings.namespace),
        "key=" .. Doc.escape(settings.panelKey),
        "admOnly=" .. tostring(settings.adminOnly and true or false),
    }, ";")

    local ids = {}
    for id in pairs(doc.elements) do ids[#ids + 1] = id end
    table.sort(ids)

    for _, id in ipairs(ids) do
        local element = doc.elements[id]
        local parent = element.parentId or 0
        local pairs_ = {}
        for _, prop in ipairs(Doc.ctorProps(element.type)) do
            pairs_[#pairs_ + 1] = prop .. "=" .. Doc.escape(element.props[prop])
        end
        lines[#lines + 1] = table.concat({ "e=" .. id, element.type, element.name, parent, table.concat(pairs_, ",") }, "|")
        local otherKeys = {}
        for key in pairs(element.props) do
            if key ~= "x" and key ~= "y" and key ~= "width" and key ~= "height" then
                otherKeys[#otherKeys + 1] = key
            end
        end
        table.sort(otherKeys)
        for _, key in ipairs(otherKeys) do
            local spec = Schema.elements[element.type]
            local inCtor = false
            for _, entry in ipairs(spec and spec.ctor or {}) do
                if entry == key then inCtor = true break end
            end
            if not inCtor then
                local value = element.props[key]
                local text = nil
                if type(value) == "table" then
                    if value.r then text = table.concat({ value.r, value.g, value.b, value.a }, ":") end
                else
                    text = tostring(value)
                end
                if text then
                    lines[#lines + 1] = table.concat({ "p=" .. id, key, Doc.escape(text) }, "|")
                end
            end
        end
    end
    return table.concat(lines, "\n")
end

function Doc.decode(text)
    if type(text) ~= "string" or text == "" then return nil, "empty layout" end
    local doc = { name = "MyFeaturePanel", nextId = 1, elements = {}, settings = { className = "MyFeaturePanel", namespace = "ParadiseDev.Panels", panelKey = "myFeaturePanel", adminOnly = true, sectionLabel = "ParadiseDev" } }
    local pending = {}
    local version = 0

    for line in string.gmatch(text, "([^\r\n]+)") do
        local head = string.match(line, "^([^=]+)=")
        local body = string.sub(line, #head + 2)
        if head == "v" then
            version = tonumber(body) or 0
        elseif head == "s" then
            for entry in string.gmatch(body, "([^;]+)") do
                local key = string.match(entry, "^([^=]+)")
                local value = string.sub(entry, #key + 2)
                key = Doc.unescape(key)
                value = Doc.unescape(value)
                if key == "class" then
                    doc.settings.className = value
                    doc.name = value
                elseif key == "namespace" then
                    doc.settings.namespace = value
                elseif key == "key" then
                    doc.settings.panelKey = value
                elseif key == "admOnly" then
                    doc.settings.adminOnly = value == "true"
                end
            end
        elseif head == "e" then
            local fields = {}
            for part in string.gmatch(body .. "|", "(.-)|") do fields[#fields + 1] = part end
            local id = tonumber(string.match(fields[1] or "", "^([^=]+)="))
            local type = fields[2]
            if not id or not type then return nil, "malformed element line: " .. line end
            if not Schema.isKnown(type) then
                pending[#pending + 1] = { skip = id }
                print("[ParadiseDev.Builder] skipping unknown element type at index " .. tostring(id) .. ": " .. type)
            else
                local element = {
                    id = id,
                    type = type,
                    name = Doc.unescape(fields[3] or "element"),
                    parentId = tonumber(fields[4]) or 0,
                    childIds = {},
                    props = Schema.newProps(type),
                }
                for pair in string.gmatch(fields[5] or "", "([^,]+)") do
                    local key = string.match(pair, "^([^=]+)")
                    local value = string.sub(pair, #key + 2)
                    if key then
                        local unescaped = Doc.unescape(value)
                        element.props[Doc.unescape(key)] = tonumber(unescaped) or unescaped
                    end
                end
                doc.elements[id] = element
                if id >= doc.nextId then doc.nextId = id + 1 end
            end
        elseif head == "p" then
            local fields = {}
            for part in string.gmatch(body .. "|", "(.-)|") do fields[#fields + 1] = part end
            local id = tonumber(string.match(fields[1] or "", "^([^=]+)="))
            local element = id and doc.elements[id] or nil
            if element and fields[2] then
                local value = Doc.unescape(fields[3] or "")
                local number = tonumber(value)
                if number then
                    element.props[Doc.unescape(fields[2])] = number
                elseif string.find(value, ":") then
                    local col = { r = 0, g = 0, b = 0, a = 1 }
                    local channels = {}
                    for part in string.gmatch(value, "([^:]+)") do channels[#channels + 1] = tonumber(part) or 0 end
                    col.r = channels[1] or 0
                    col.g = channels[2] or 0
                    col.b = channels[3] or 0
                    col.a = channels[4] or 1
                    element.props[Doc.unescape(fields[2])] = col
                elseif value == "true" or value == "false" then
                    element.props[Doc.unescape(fields[2])] = value == "true"
                else
                    element.props[Doc.unescape(fields[2])] = value
                end
            end
        end
    end

    if version < 1 then return nil, "layout is missing a version header" end

    for _, element in pairs(doc.elements) do
        local parent = element.parentId and doc.elements[element.parentId] or nil
        if parent and Schema.acceptsChildren(parent.type) then
            parent.childIds[#parent.childIds + 1] = element.id
        elseif not parent then
            element.parentId = nil
        end
    end
    for _, element in pairs(doc.elements) do
        if not element.parentId then
            if Doc.root(doc) then return nil, "layout declares more than one root element" end
        end
    end
    if not Doc.root(doc) then return nil, "layout has no root element" end
    return doc
end

function Doc.fileName(name)
    return Doc.FOLDER .. tostring(name or Doc.defaultName()) .. Doc.EXT
end

function Doc.defaultName()
    return Builder.doc and Builder.doc.settings.className or "Untitled"
end

function Doc.save(name, doc)
    doc = doc or Builder.doc
    if not doc then return false, "no document" end
    local ok, writer = pcall(getFileWriter, Doc.fileName(name), true, false)
    if not ok or not writer then return false, "unable to open " .. Doc.fileName(name) end
    writer:write(Doc.encode(doc))
    writer:close()
    return true, Doc.fileName(name)
end

function Doc.read(name)
    local ok, reader = pcall(getFileReader, Doc.fileName(name), true)
    if not ok or not reader then return nil, "no such layout: " .. Doc.fileName(name) end
    local lines = {}
    local line = reader:readLine()
    while line do
        lines[#lines + 1] = line
        line = reader:readLine()
    end
    reader:close()
    return table.concat(lines, "\n")
end

function Doc.load(name)
    local text, err = Doc.read(name)
    if not text then return nil, err end
    local doc, decodeErr = Doc.decode(text)
    if not doc then return nil, decodeErr end
    Builder.doc = doc
    return doc
end

function Doc.listSaved()
    local names = {}
    local ok, dir = pcall(getFolderFileList, "media/")
    if not ok or not dir then return names end
    for index = 0, dir:size() - 1 do
        local item = dir:get(index)
        local path = tostring(item:getPath())
        local folder = string.gsub(Doc.FOLDER, "/", "\\")
        if string.find(string.upper(path), "\\LUA\\" .. string.upper(folder)) then
            local leaf = string.match(path, "[^\\]+$")
            local base = string.match(leaf, "^(.-)" .. Doc.EXT)
            if base then names[#names + 1] = base end
        end
    end
    table.sort(names)
    return names
end
