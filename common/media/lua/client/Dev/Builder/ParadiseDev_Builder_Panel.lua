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
require "Dev/Builder/ParadiseDev_Builder_Gen"
require "ISUI/ISCollapsableWindow"
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISComboBox"
require "ISUI/ISImage"
require "ISUI/ISWindow"
require "ISUI/ISTabPanel"
require "ISUI/ISTickBox"
require "ISUI/ISRadioButtons"
require "ISUI/ISProgressBar"
require "ISUI/ISVolumeControl"
require "ISUI/ISRichTextPanel"
require "ISUI/ISScrollingListBox"
require "ISUI/ISTextEntryBox"
require "RadioCom/ISUIRadio/ISSliderPanel"

local Schema = Builder.Schema
local Doc = Builder.Doc
local Gen = Builder.Gen

Builder.GAP = 8
Builder.ROW = 28
Builder.LEFT = 220
Builder.RIGHT = 330
Builder.PAGE_ROWS = 10
Builder.TOOLBAR_ROWS = 3
Builder.BIND = "ToggleParadiseUIBuilder"

Builder.doc = Builder.doc or Doc.newDoc("MyFeaturePanel")
Builder.instance = nil
Builder.selection = nil
Builder.page = 0
Builder.mode = "element"
Builder.view = "preview"
Builder.codeKind = "lua"
Builder.probes = {}

local function nop() end

Builder.Panel = Builder.Panel or ISCollapsableWindow:derive("ParadiseDev.Builder.Panel")
local Panel = Builder.Panel

function Builder.current()
    local doc = Builder.doc
    if not doc then return nil end
    if Builder.selection then
        local element = Doc.get(doc, Builder.selection)
        if element then return element end
    end
    return Doc.root(doc)
end

function Builder.setStatus(message)
    if Builder.instance and Builder.instance.statusLabel then
        Builder.instance.statusLabel:setNameWithoutMoving("  " .. tostring(message))
    end
end

function Builder.status(message)
    print("[ParadiseDev.Builder] " .. tostring(message))
    Builder.setStatus(message)
end

function Builder.fontValue(name)
    if UIFont and name and UIFont[name] then return UIFont[name] end
    return UIFont and UIFont.Small
end

function Builder.propValue(key, value)
    if Schema.isFontField(key) and type(value) == "string" then
        return Builder.fontValue(value)
    end
    return value
end

function Builder.newArgs(type, props, host, handler)
    local spec = Schema.get(type)
    local args = {}
    for _, entry in ipairs(spec.ctor) do
        if entry == "@self" then
            args[#args + 1] = host
        elseif entry == "@handler" then
            args[#args + 1] = handler
        elseif entry == "@texture" then
            local name = props.texture
            if name and name ~= "" then args[#args + 1] = getTexture(name) end
        else
            args[#args + 1] = Builder.propValue(entry, props[entry])
        end
    end
    return args
end

function Builder.probe(typeName)
    if Builder.probes[typeName] ~= nil then return Builder.probes[typeName] end
    local spec = Schema.get(typeName)
    if not spec then
        Builder.probes[typeName] = false
        return false
    end
    local class = _G[spec.class]
    if not class or not class.new then
        Builder.probes[typeName] = false
        return false
    end
    local args = Builder.newArgs(typeName, Schema.newProps(typeName), {}, nop)
    local ok, widget = pcall(function(...) return class:new(...) end, unpack(args))
    if not ok or type(widget) ~= "table" then
        Builder.probes[typeName] = false
        return false
    end
    Builder.probes[typeName] = widget
    return widget
end

function Builder.fields(element)
    local list = {}
    local seen = {}
    if not element then return list end
    local spec = Schema.get(element.type)
    local probe = Builder.probe(element.type)
    if probe then
        for _, entry in ipairs(Schema.liveFields(probe)) do
            if not seen[entry.key] then
                seen[entry.key] = true
                list[#list + 1] = { key = entry.key, kind = entry.kind }
            end
        end
    end
    for _, entry in ipairs(spec and spec.ctor or {}) do
        if entry ~= "@self" and entry ~= "@handler" and entry ~= "@texture" and not seen[entry] then
            seen[entry] = true
            list[#list + 1] = { key = entry, kind = Schema.kindOf(entry, element.props[entry]) or "number" }
        end
    end
    for key, value in pairs(element.props) do
        if not seen[key] then
            seen[key] = true
            local kind = Schema.kindOf(key, value)
            if kind then list[#list + 1] = { key = key, kind = kind } end
        end
    end
    table.sort(list, function(a, b) return a.key < b.key end)
    table.insert(list, 1, { key = "@name", kind = "string" })
    if spec and spec.tabContainer then
        list[#list + 1] = { key = "tabLabels", kind = "string" }
    end
    return list
end

function Builder.rowValue(element, field)
    local value = element.props[field.key]
    if value == nil then
        local probe = Builder.probe(element.type)
        if probe then value = probe[field.key] end
    end
    if field.key == "tabLabels" then
        local names = {}
        for _, child in ipairs(Doc.children(Builder.doc, element.id)) do
            names[#names + 1] = (child.props.tabLabel or child.name) .. "=" .. child.name
        end
        return table.concat(names, ",")
    end
    if field.kind == "color" and type(value) ~= "table" then
        return { r = 0, g = 0, b = 0, a = 1 }
    end
    return value
end

function Builder.flat(doc)
    doc = doc or Builder.doc
    local out = {}
    local root = doc and Doc.root(doc)
    if not root then return out end
    local function visit(element, depth)
        out[#out + 1] = { element = element, depth = depth }
        for _, child in ipairs(Doc.children(doc, element.id)) do
            visit(child, depth + 1)
        end
    end
    visit(root, 0)
    return out
end

Builder.Rig = Builder.Rig or {}
local Rig = Builder.Rig

function Rig.titleHeight()
    return ISCollapsableWindow.TitleBarHeight()
end

function Rig.yOf(parentType, value)
    local number = tonumber(value) or 0
    if parentType == "ISCollapsableWindow" then
        return number + Rig.titleHeight()
    end
    return number
end

function Rig.assignPath(widget, path, value)
    local field = string.match(path, "^([^%[]+)")
    local index = string.match(path, "%[([^%]]+)%]")
    if not index then
        widget[path] = value
        return
    end
    if type(widget[field]) ~= "table" then widget[field] = {} end
    widget[field][tonumber(index) or index] = value
end

function Rig.usesCtorHandler(spec)
    for _, entry in ipairs(spec.ctor or {}) do
        if entry == "@handler" then return true end
    end
    return false
end

function Rig.assign(element, widget)
    local spec = Schema.get(element.type)
    local callKeys = Schema.callKeys(element.type)
    for key, value in pairs(element.props) do
        local skip = spec.readOnly[key]
            or Schema.isCtorProp(element.type, key)
            or callKeys[key]
            or key == "tabLabel"
            or key == "tabLabels"
        if not skip then
            if spec.wrapProp and spec.wrapProp[key] then
                if type(value) == "string" and value ~= "" then
                    widget[key] = getTexture(value)
                end
            else
                widget[key] = Builder.propValue(key, value)
            end
        end
    end
end

function Rig.calls(element, widget)
    local spec = Schema.get(element.type)
    for _, entry in ipairs(spec.call or {}) do
        if entry.list then
            for _, item in ipairs(Doc.splitList(element.props[entry.list])) do
                widget[entry.m](widget, item)
            end
        elseif entry.args then
            local parts = {}
            for _, name in ipairs(entry.args) do
                parts[#parts + 1] = Builder.propValue(name, element.props[name])
            end
            widget[entry.m](widget, unpack(parts))
        elseif entry.prop and element.props[entry.prop] ~= nil then
            local value = Builder.propValue(entry.prop, element.props[entry.prop])
            if entry.set then
                Rig.assignPath(widget, entry.set, value)
            else
                widget[entry.m](widget, value)
            end
        end
    end
end

function Rig.spawn(element, host, parentType)
    local class = _G[element.type]
    if not class or not class.new then return nil end
    local props = {}
    for key, value in pairs(element.props) do
        if key == "y" and parentType == "ISCollapsableWindow" then
            props.y = Rig.yOf(parentType, value)
        else
            props[key] = value
        end
    end
    local args = Builder.newArgs(element.type, props, host, nop)
    local ok, widget = pcall(function(...) return class:new(...) end, unpack(args))
    if not ok or type(widget) ~= "table" then
        Builder.status("cannot build " .. tostring(element.type) .. ": " .. tostring(widget))
        return nil
    end

    local spec = Schema.get(element.type)
    if spec.handlerTarget then widget[spec.handlerTarget] = host end
    if spec.handlerProp and not Rig.usesCtorHandler(spec) then widget[spec.handlerProp] = nop end
    Rig.assign(element, widget)
    if element.type == "ISButton" then
        widget.internal = string.upper(Doc.sanitize(element.name))
    end
    pcall(function() widget:initialise() end)
    if not widget.javaObject then
        pcall(function() widget:instantiate() end)
    end

    for _, child in ipairs(Doc.children(Builder.doc, element.id)) do
        local childWidget = Rig.spawn(child, host, element.type)
        if childWidget then
            if spec.tabContainer then
                widget:addView(child.props.tabLabel or child.name, childWidget)
            else
                widget:addChild(childWidget)
            end
        end
    end
    local callsOk, callsErr = pcall(function() Rig.calls(element, widget) end)
    if not callsOk then
        Builder.status("cannot apply " .. tostring(element.type) .. " calls: " .. tostring(callsErr))
    end
    return widget
end

function Builder.rebuildRig()
    local panel = Builder.instance
    if not panel or not panel.rig or not Builder.doc then return end
    local root = Doc.root(Builder.doc)
    if not root then return end
    Rig.host = panel.rig
    panel.rig:clearChildren()

    local width = math.max(120, tonumber(root.props.width) or 560)
    local height = math.max(80, tonumber(root.props.height) or 420)
    panel.rig:setWidth(width)
    panel.rig:setHeight(height)

    local bandHeight = Rig.titleHeight()
    panel.rigBand = ISPanel:new(0, 0, width, bandHeight)
    panel.rigBand:initialise()
    panel.rigBand.backgroundColor = {r=0.27, g=0.27, b=0.30, a=1}
    panel.rigBand.doBorder = false
    panel.rig:addChild(panel.rigBand)

    panel.rigTitle = ISLabel:new(4, 2, 14, tostring(root.props.title or ""), 1, 1, 1, 1, UIFont.Small, true)
    panel.rigTitle:initialise()
    panel.rig:addChild(panel.rigTitle)

    local bg = root.props.backgroundColor
    if type(bg) == "table" then panel.rig.backgroundColor = bg end
    local border = root.props.borderColor
    if type(border) == "table" then panel.rig.borderColor = border end

    for _, child in ipairs(Doc.children(Builder.doc, root.id)) do
        local widget = Rig.spawn(child, panel.rig, root.type)
        if widget then panel.rig:addChild(widget) end
    end
end

function Builder.refresh()
    local panel = Builder.instance
    if not panel then return end
    panel:updateTree()
    Builder.rebuildRig()
    panel:updateInspector()
end

function Builder.refreshLight()
    local panel = Builder.instance
    if not panel then return end
    panel:updateTree()
    Builder.rebuildRig()
end

function Builder.select(id)
    Builder.selection = id
    Builder.mode = "element"
    Builder.page = 0
    Builder.refresh()
end

function Builder.treeText(entry)
    local root = Builder.doc and Doc.root(Builder.doc)
    local mark = "  "
    if root == entry.element then
        mark = "# "
    elseif Builder.selection == entry.element.id then
        mark = "> "
    end
    return mark .. string.rep("   ", entry.depth) .. entry.element.name .. "  [" .. entry.element.type .. "]"
end

function Builder.add(type)
    if not type or type == "" then type = Schema.order[1] end
    local spec = Schema.get(type)
    if not spec then
        Builder.status("unknown element type: " .. tostring(type))
        return nil
    end
    if spec.rootOnly then
        Builder.status(type .. " is the layout root and already exists")
        return nil
    end
    local parent = nil
    local current = Builder.current()
    if current and Schema.acceptsChildren(current.type) then parent = current.id end
    local element, err = Doc.addElement(Builder.doc, type, parent)
    if not element then
        Builder.status("cannot add " .. tostring(type) .. ": " .. tostring(err))
        return nil
    end
    Builder.selection = element.id
    Builder.mode = "element"
    Builder.refresh()
    Builder.setStatus("added " .. element.type .. " as " .. element.name)
    return element
end

function Builder.removeSelected()
    local element = Builder.current()
    if not element then return false end
    local ok, err = Doc.remove(Builder.doc, element.id)
    if not ok then
        Builder.status("cannot remove " .. element.name .. ": " .. tostring(err))
        return false
    end
    Builder.selection = nil
    Builder.refresh()
    Builder.setStatus("removed " .. element.name)
    return true
end

function Builder.duplicateSelected()
    local element = Builder.current()
    if not element or not element.parentId then
        Builder.status("the root element cannot be duplicated")
        return nil
    end
    local copy, err = Doc.addElement(Builder.doc, element.type, element.parentId)
    if not copy then
        Builder.status("cannot duplicate: " .. tostring(err))
        return nil
    end
    for key, value in pairs(element.props) do
        copy.props[key] = value
    end
    copy.props.x = (tonumber(copy.props.x) or 0) + 8
    copy.props.y = (tonumber(copy.props.y) or 0) + 8
    Builder.selection = copy.id
    Builder.refresh()
    Builder.setStatus("duplicated as " .. copy.name)
    return copy
end

function Builder.moveSelected(delta)
    local element = Builder.current()
    if not element then return false end
    if Doc.moveWithinParent(Builder.doc, element.id, delta) then
        Builder.refresh()
        return true
    end
    Builder.setStatus("cannot move " .. element.name)
    return false
end

function Builder.applyName(text)
    local doc = Builder.doc
    if not doc or not doc.settings then return end
    local name = Doc.sanitize(text)
    doc.settings.className = name
    doc.settings.module = Doc.moduleName(name)
    doc.settings.panelKey = string.gsub(name, "^.", function(first) return string.lower(first) end)
    doc.settings.menuText = name
    doc.name = name
end

function Builder.setProp(key, value)
    if Builder.mode == "settings" then
        if Doc.applySetting(Builder.doc.settings, key, tostring(value)) then
            if key == "class" then Builder.applyName(value) end
            Builder.setStatus("setting " .. key .. " = " .. tostring(value))
            Builder.refreshLight()
        end
        return false
    end
    local element = Builder.current()
    if not element then return false end
    if key == "@name" then
        element.name = Doc.uniqueName(Builder.doc, element.parentId, Doc.sanitize(value))
        Builder.refreshLight()
        return true
    end
    if key == "tabLabels" then
        for pair in string.gmatch(tostring(value or ""), "([^,]+)") do
            local label, target = string.match(pair, "^(.-)=(.+)$")
            if label and target then
                for _, child in ipairs(Doc.children(Builder.doc, element.id)) do
                    if child.name == target then child.props.tabLabel = label end
                end
            end
        end
        Builder.refreshLight()
        return true
    end
    element.props[key] = value
    Builder.refreshLight()
    return true
end

function Builder.setColorChannel(key, channel, text)
    local element = Builder.current()
    if not element then return false end
    local value = element.props[key]
    if type(value) ~= "table" then
        local probe = Builder.probe(element.type)
        local source = probe and probe[key] or nil
        value = {
            r = source and source.r or 0,
            g = source and source.g or 0,
            b = source and source.b or 0,
            a = source and source.a or 1,
        }
    end
    value[channel] = tonumber(text) or value[channel] or 0
    element.props[key] = value
    Builder.refreshLight()
    return true
end

function Builder.codeText(kind)
    if kind == "registry" then return Gen.registry(Builder.doc) end
    if kind == "openers" then return Gen.openers(Builder.doc) end
    return Gen.panel(Builder.doc)
end

function Builder.refreshCode()
    local panel = Builder.instance
    if not panel or not panel.codeList then return end
    panel.codeList:clear()
    local text = Builder.codeText(Builder.codeKind) or ""
    local width = panel.codeList.width
    for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
        panel.codeList:addItem(line, line)
        local measure = getTextManager():MeasureStringX(panel.codeList.font, line) + 30
        if measure > width then width = measure end
    end
    panel.codeList:setScrollWidth(width)
end

function Builder.showCode(kind)
    Builder.codeKind = kind or Builder.codeKind
    Builder.view = "code"
    Builder.refreshCode()
    local panel = Builder.instance
    if panel then panel:updateToolbar() end
    Builder.setStatus("showing " .. Builder.codeKind)
    return Builder.codeText(Builder.codeKind)
end

function Builder.copyCode(text)
    local data = text or Builder.codeText(Builder.codeKind)
    if not data then
        Builder.status("nothing to copy")
        return false
    end
    local ok = pcall(function() Clipboard.setClipboard(data) end)
    if not ok then
        Builder.status("clipboard unavailable")
        return false
    end
    local lines = 1
    for _ in string.gmatch(data, "\n") do lines = lines + 1 end
    Builder.setStatus("copied " .. Builder.codeKind .. " (" .. lines .. " lines)")
    return true
end

function Builder.entryName()
    if Builder.instance and Builder.instance.nameEntry then
        return Builder.instance.nameEntry:getText()
    end
    return Builder.doc.settings.className
end

function Builder.newLayout(name)
    Builder.applyName(name or Builder.entryName())
    Builder.doc = Doc.newDoc(Builder.doc.settings.className)
    Builder.selection = nil
    Builder.page = 0
    Builder.mode = "element"
    Builder.view = "preview"
    if Builder.instance then
        Builder.instance.nameEntry:setText(Builder.doc.settings.className)
    end
    Builder.refresh()
    Builder.setStatus("new layout " .. Builder.doc.settings.className)
    return Builder.doc
end

function Builder.saveLayout(name)
    local target = name or (Builder.instance and Builder.instance.nameEntry and Builder.instance.nameEntry:getText())
    local ok, message = Doc.save(target and Doc.sanitize(target) or nil)
    Builder.status(ok and ("saved " .. tostring(message)) or ("save failed: " .. tostring(message)))
    return ok
end

function Builder.loadLayout(name)
    local target = name or (Builder.instance and Builder.instance.nameEntry and Builder.instance.nameEntry:getText())
    if not target or target == "" then
        Builder.status("type a layout name, or Builder.loadLayout(\"name\")")
        return nil
    end
    target = Doc.sanitize(target)
    local doc, err = Doc.load(target)
    if not doc then
        Builder.status("load failed: " .. tostring(err))
        return nil
    end
    Builder.selection = nil
    Builder.page = 0
    Builder.mode = "element"
    Builder.view = "preview"
    if Builder.instance then Builder.instance.nameEntry:setText(target) end
    Builder.refresh()
    Builder.setStatus("loaded " .. target)
    return doc
end

function Builder.resolve(dotted)
    local node = _G
    for _, segment in ipairs(Gen.segments(dotted)) do
        node = node[segment]
        if not node then return nil end
    end
    return node
end

function Builder.loader()
    if type(load) == "function" then return load end
    if type(loadstring) == "function" then return loadstring end
    return nil
end

function Builder.runLayout()
    local code, err = Gen.panel(Builder.doc)
    if not code then
        Builder.status("cannot generate code: " .. tostring(err))
        return false
    end
    local loader = Builder.loader()
    if not loader then
        Builder.showCode("lua")
        Builder.status("this Lua VM has no load(): copy the code and run it from the F1 console")
        return false
    end
    local chunk, problem = loader(code)
    if not chunk then
        Builder.showCode("lua")
        Builder.status("generated code does not parse: " .. tostring(problem))
        return false
    end
    local ok, failure = pcall(chunk)
    if not ok then
        Builder.status("generated code failed: " .. tostring(failure))
        return false
    end
    local settings = Builder.doc.settings
    local class = Builder.resolve(settings.namespace .. "." .. settings.className)
    if not class or not class.new then
        Builder.status("generated class " .. tostring(settings.className) .. " was not defined")
        return false
    end
    local footprint = Gen.footprint(Builder.doc)
    local ok2, instance = pcall(function(...) return class:new(...) end,
        footprint.x + 40, footprint.y + 40, footprint.width, footprint.height)
    if not ok2 or type(instance) ~= "table" then
        Builder.status("could not instantiate " .. tostring(settings.className) .. ": " .. tostring(instance))
        return false
    end
    instance:initialise()
    instance:addToUIManager()
    Builder.setStatus("ran " .. settings.className)
    return true
end

function Panel:new(x, y, width, height)
    local panel = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(panel, self)
    self.__index = self
    panel.title = "Paradise UI Builder"
    panel.minimumWidth = 900
    panel.minimumHeight = 520
    panel.resizable = true
    return panel
end

function Panel:button(label, x, width, y)
    local button = ISButton:new(x, y, width, 24, label, self, Panel.onButton)
    button:initialise()
    button.internal = string.upper(Doc.sanitize(label))
    self:addChild(button)
    self[button.internal] = button
    return button
end

function Panel:createChildren()
    ISCollapsableWindow.createChildren(self)
    local gap = Builder.GAP
    local row = Builder.ROW
    local top = self:titleBarHeight() + gap

    self.nameEntry = ISTextEntryBox:new(Builder.doc.settings.className, gap, top, 180, 24)
    self.nameEntry:initialise()
    self.nameEntry.target = self
    self.nameEntry.onTextChange = Panel.onNameChange
    self:addChild(self.nameEntry)

    self:button("NEW", 196, 54, top)
    self:button("SAVE", 256, 54, top)
    self:button("LOAD", 316, 54, top)
    self:button("SETTINGS", 376, 86, top)
    self:button("RUN", 468, 54, top)

    local rowB = top + row
    self.typeCombo = ISComboBox:new(gap, rowB, 170, 24, self, Panel.onTypePick)
    self.typeCombo:initialise()
    self:addChild(self.typeCombo)
    for _, type in ipairs(Schema.order) do
        self.typeCombo:addOption(type)
    end

    self:button("ADD", 186, 54, rowB)
    self:button("DELETE", 246, 72, rowB)
    self:button("DUPLICATE", 324, 96, rowB)
    self:button("UP", 426, 48, rowB)
    self:button("DOWN", 480, 60, rowB)

    local rowC = top + row * 2
    self:button("CODE", gap, 62, rowC)
    self:button("REGISTRY", 78, 86, rowC)
    self:button("OPENERS", 170, 82, rowC)
    self:button("PREVIEW", 258, 78, rowC)
    self:button("COPY", 342, 62, rowC)

    self.tree = ISScrollingListBox:new(gap, 0, 0, 0)
    self.tree:initialise()
    self.tree.font = UIFont.Small
    self.tree.itemheight = 20
    self.tree.target = self
    self.tree.onmousedown = Panel.onTreePick
    self:addChild(self.tree)

    self.rigHost = ISPanel:new(gap, 0, 100, 100)
    self.rigHost:initialise()
    self.rigHost.backgroundColor = {r=0.05, g=0.05, b=0.05, a=0.6}
    self.rigHost.borderColor = {r=0.35, g=0.35, b=0.35, a=0.9}
    self.rigHost.doBorder = true
    self:addChild(self.rigHost)

    self.rig = ISPanel:new(8, 8, 560, 420)
    self.rig:initialise()
    self.rig.backgroundColor = {r=0.15, g=0.15, b=0.15, a=0.95}
    self.rig.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
    self.rig.doBorder = true
    self.rigHost:addChild(self.rig)

    self.codeList = ISScrollingListBox:new(gap, 0, 100, 100)
    self.codeList:initialise()
    self.codeList.font = Builder.fontValue("Code") or UIFont.Small
    self.codeList.itemheight = 17
    self.codeList.target = self
    self:addChild(self.codeList)

    self.inspTitle = ISLabel:new(gap, 0, 14, "Element", 1, 1, 1, 1, UIFont.Small, true)
    self.inspTitle:initialise()
    self:addChild(self.inspTitle)

    self.pageLabel = ISLabel:new(gap, 0, 14, "1/1", 0.8, 0.8, 0.8, 1, UIFont.Small, true)
    self.pageLabel:initialise()
    self:addChild(self.pageLabel)

    self:button("PREVPAGE", 0, 34, 0)
    self.PREVPAGE:setTitle("<")
    self:button("NEXTPAGE", 0, 34, 0)
    self.NEXTPAGE:setTitle(">")

    self.inspArea = ISPanel:new(gap, 0, 300, 100)
    self.inspArea:initialise()
    self.inspArea.backgroundColor = {r=0, g=0, b=0, a=0.35}
    self.inspArea.borderColor = {r=0.3, g=0.3, b=0.3, a=0.8}
    self.inspArea.doBorder = true
    self:addChild(self.inspArea)

    self.statusLabel = ISLabel:new(gap, 0, 16, "  ready", 0.7, 0.9, 0.7, 1, UIFont.Small, true)
    self.statusLabel:initialise()
    self:addChild(self.statusLabel)

    self:setResizable(true)
    Panel.layout(self)
    self:updateToolbar()
    Builder.refresh()
end

function Panel:updateToolbar()
    local showCode = Builder.view == "code"
    self.codeList:setVisible(showCode)
    self.rigHost:setVisible(not showCode)
end

function Rig.place(widget, x, y, width, height)
    if not widget then return end
    widget:setX(x)
    widget:setY(y)
    if width then widget:setWidth(width) end
    if height then widget:setHeight(height) end
end

function Panel.layout(panel)
    if not panel.tree or not panel.rigHost then return end
    local gap = Builder.GAP
    local contentY = panel:titleBarHeight() + gap + Builder.ROW * Builder.TOOLBAR_ROWS + gap
    local contentHeight = math.max(120, panel.height - contentY - gap - 22 - panel:resizeWidgetHeight())
    local leftWidth = Builder.LEFT
    local rightWidth = math.max(220, math.min(Builder.RIGHT, math.floor(panel.width * 0.32)))
    local centerX = gap + leftWidth + gap
    local centerWidth = math.max(160, panel.width - centerX - rightWidth - gap * 3)
    local rightX = panel.width - rightWidth - gap

    Rig.place(panel.tree, gap, contentY, leftWidth, contentHeight)
    Rig.place(panel.rigHost, centerX, contentY, centerWidth, contentHeight)
    Rig.place(panel.codeList, centerX, contentY, centerWidth, contentHeight)

    Rig.place(panel.inspTitle, rightX, contentY, rightWidth - 90, 16)
    Rig.place(panel.pageLabel, rightX + rightWidth - 76, contentY, 40, 16)
    Rig.place(panel.PREVPAGE, rightX + rightWidth - 70, contentY - 3, 34, 22)
    Rig.place(panel.NEXTPAGE, rightX + rightWidth - 34, contentY - 3, 34, 22)
    Rig.place(panel.inspArea, rightX, contentY + 22, rightWidth, math.max(60, contentHeight - 22))
    Rig.place(panel.statusLabel, gap, panel.height - 22 - panel:resizeWidgetHeight(), panel.width - gap * 2, 16)
end

function Panel:onResize()
    ISCollapsableWindow.onResize(self)
    Panel.layout(self)
end

function Panel:updateTree()
    if not self.tree then return end
    self.tree:clear()
    local width = self.tree.width
    for _, entry in ipairs(Builder.flat()) do
        local text = Builder.treeText(entry)
        self.tree:addItem(text, entry.element)
        local measure = getTextManager():MeasureStringX(self.tree.font, text) + 30
        if measure > width then width = measure end
    end
    self.tree:setScrollWidth(width)
end

function Panel:rows()
    if Builder.mode == "settings" then
        local rows = {}
        for _, entry in ipairs(Doc.settingKeys) do
            local value = Builder.doc.settings[entry.field]
            if entry.list then value = table.concat(value or {}, ",") end
            rows[#rows + 1] = { key = entry.key, kind = entry.bool and "boolean" or "string", value = value }
        end
        return rows
    end
    local element = Builder.current()
    if not element then return {} end
    local rows = {}
    for _, field in ipairs(Builder.fields(element)) do
        rows[#rows + 1] = {
            key = field.key,
            kind = field.kind,
            value = field.key == "@name" and element.name or Builder.rowValue(element, field),
        }
    end
    return rows
end

function Panel:updateInspector()
    if not self.inspArea then return end
    local element = Builder.current()
    if Builder.mode == "settings" then
        self.inspTitle:setNameWithoutMoving("Layout settings")
    else
        self.inspTitle:setNameWithoutMoving((element and (element.name .. "  " .. element.type)) or "no element")
    end

    local rows = self:rows()
    local pageCount = math.max(1, math.ceil(#rows / Builder.PAGE_ROWS))
    if Builder.page > pageCount - 1 then Builder.page = pageCount - 1 end
    if Builder.page < 0 then Builder.page = 0 end
    self.pageLabel:setNameWithoutMoving((Builder.page + 1) .. "/" .. pageCount)

    self.inspArea:clearChildren()
    local rowHeight = 26
    local labelWidth = 120
    for index = 1, Builder.PAGE_ROWS do
        local row = rows[Builder.page * Builder.PAGE_ROWS + index]
        if row then
            self:addRow(row, 4, 6 + (index - 1) * rowHeight, labelWidth)
        end
    end
end

function Panel:addRow(row, x, y, labelWidth)
    local label = ISLabel:new(x, y + 3, 14, row.key, 0.9, 0.9, 0.9, 1, UIFont.Small, true)
    label:initialise()
    self.inspArea:addChild(label)

    local entryWidth = math.max(60, self.inspArea.width - labelWidth - 12)

    if row.kind == "boolean" then
        local button = ISButton:new(x + labelWidth, y, entryWidth, 22, tostring(row.value), self, Panel.onButton)
        button:initialise()
        button.internal = "BOOL:" .. row.key
        self.inspArea:addChild(button)
    elseif row.kind == "color" then
        local channelWidth = math.floor(entryWidth / 4) - 2
        for index, channel in ipairs({ "r", "g", "b", "a" }) do
            local entry = ISTextEntryBox:new(tostring((row.value or {})[channel] or 0),
                x + labelWidth + (index - 1) * (channelWidth + 2), y, channelWidth, 22)
            entry:initialise()
            entry.target = self
            entry.propKey = row.key
            entry.channel = channel
            entry.onTextChange = Panel.onColorChange
            self.inspArea:addChild(entry)
        end
    elseif row.kind == "font" then
        local combo = ISComboBox:new(x + labelWidth, y, entryWidth, 22, self, Panel.onFontPick)
        combo:initialise()
        combo.propKey = row.key
        self.inspArea:addChild(combo)
        local current = Schema.fontName(row.value)
        for index, name in ipairs(Schema.fontOptions()) do
            combo:addOption(name)
            if name == current then combo:setSelected(index) end
        end
    else
        local entry = ISTextEntryBox:new(tostring(row.value == nil and "" or row.value),
            x + labelWidth, y, entryWidth, 22)
        entry:initialise()
        entry.target = self
        entry.propKey = row.key
        entry.onTextChange = Panel.onPropChange
        self.inspArea:addChild(entry)
    end
end

function Panel.onNameChange(box)
    if not box then return end
    Builder.applyName(box:getText())
end

function Panel.onPropChange(box)
    if not box then return end
    local text = box:getText()
    local key = box.propKey
    if key == "x" or key == "y" or key == "width" or key == "height" or key == "min" or key == "max"
        or key == "step" or key == "value" or key == "volume" or key == "selected" then
        if text == "" or not tonumber(text) then return end
        Builder.setProp(key, tonumber(text))
        return
    end
    Builder.setProp(key, Doc.coerce(text))
end

function Panel.onColorChange(box)
    if not box then return end
    Builder.setColorChannel(box.propKey, box.channel, box:getText())
end

function Panel.onFontPick(target, combo)
    if not target then return end
    Builder.setProp(combo.propKey, combo:getSelectedText())
end

function Panel.onTypePick(target, combo)
    if not target then return end
    Builder.add(combo:getSelectedText())
end

function Panel:onTreePick(element)
    if element and element.id then Builder.select(element.id) end
end

function Panel:toggleBoolean(key)
    if Builder.mode == "settings" then
        local field = nil
        for _, entry in ipairs(Doc.settingKeys) do
            if entry.key == key then field = entry.field end
        end
        if field then
            Builder.setProp(key, not (Builder.doc.settings[field] and true or false))
            self:updateInspector()
        end
        return
    end
    local element = Builder.current()
    if not element then return end
    local current = element.props[key]
    if current == nil then
        local probe = Builder.probe(element.type)
        current = probe and probe[key]
    end
    Builder.setProp(key, not (current and true or false))
    self:updateInspector()
end

function Panel:onButton(button)
    local id = button.internal
    if string.sub(id, 1, 5) == "BOOL:" then
        self:toggleBoolean(string.sub(id, 6))
    elseif id == "ADD" then
        Builder.add(self.typeCombo:getSelectedText())
    elseif id == "DELETE" then
        Builder.removeSelected()
    elseif id == "DUPLICATE" then
        Builder.duplicateSelected()
    elseif id == "UP" then
        Builder.moveSelected(-1)
    elseif id == "DOWN" then
        Builder.moveSelected(1)
    elseif id == "NEW" then
        Builder.newLayout()
    elseif id == "SAVE" then
        Builder.saveLayout()
    elseif id == "LOAD" then
        Builder.loadLayout()
    elseif id == "SETTINGS" then
        Builder.mode = "settings"
        Builder.page = 0
        self:updateInspector()
        Builder.setStatus("editing layout settings")
    elseif id == "RUN" then
        Builder.runLayout()
    elseif id == "CODE" then
        Builder.showCode("lua")
    elseif id == "REGISTRY" then
        Builder.showCode("registry")
    elseif id == "OPENERS" then
        Builder.showCode("openers")
    elseif id == "PREVIEW" then
        Builder.view = "preview"
        self:updateToolbar()
        Builder.setStatus("preview")
    elseif id == "COPY" then
        Builder.copyCode()
    elseif id == "PREVPAGE" then
        if Builder.page > 0 then
            Builder.page = Builder.page - 1
            self:updateInspector()
        end
    elseif id == "NEXTPAGE" then
        Builder.page = Builder.page + 1
        self:updateInspector()
    end
end

function Panel:close()
    Builder.ClosePanel()
end

function Builder.OpenPanel()
    if not Builder.instance then
        local width = math.min(1240, getCore():getScreenWidth() - 40)
        local height = math.min(780, getCore():getScreenHeight() - 40)
        local x = math.max(20, math.floor((getCore():getScreenWidth() - width) / 2))
        local y = math.max(20, math.floor((getCore():getScreenHeight() - height) / 2))
        Builder.instance = Panel:new(x, y, width, height)
        Builder.instance:initialise()
        Builder.instance:addToUIManager()
    else
        Builder.instance:setVisible(true)
        Builder.instance:addToUIManager()
    end
    Builder.refresh()
    Builder.instance:updateToolbar()
    Builder.instance:bringToTop()
    return Builder.instance
end

function Builder.ClosePanel()
    if not Builder.instance then return end
    Builder.instance:setVisible(false)
    Builder.instance:removeFromUIManager()
    Builder.instance = nil
end

function Builder.TogglePanel()
    if Builder.instance then
        Builder.ClosePanel()
        return nil
    end
    return Builder.OpenPanel()
end

function Builder.onKeyPressed(key)
    if not getCore():getDebug() then return end
    if getCore():getKey(Builder.BIND) == key then
        Builder.TogglePanel()
    end
end
Events.OnKeyPressed.Remove(Builder.onKeyPressed)
Events.OnKeyPressed.Add(Builder.onKeyPressed)

function Builder.onGameStart()
    Builder.ClosePanel()
end
Events.OnGameStart.Remove(Builder.onGameStart)
Events.OnGameStart.Add(Builder.onGameStart)

function Builder.installBind()
    local ok = pcall(function()
        getCore():addKeyBinding(Builder.BIND, Keyboard.KEY_F9, 0, false, false, false)
    end)
    Builder.bindOk = ok and true or false
    return Builder.bindOk
end
Builder.installBind()

function Builder.tree()
    local out = {}
    for _, entry in ipairs(Builder.flat()) do
        out[#out + 1] = Builder.treeText(entry)
    end
    return out
end

function Builder.dump()
    for _, line in ipairs(Builder.tree()) do
        print(line)
    end
    return Builder.doc
end
