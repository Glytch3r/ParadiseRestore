ParadisePOIBuilder = ParadisePOIBuilder or {}
if ParadisePOIBuilder.isB41() then return end

require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISTextEntryBox"
require "ISUI/ISComboBox"
require "ISUI/ISTickBox"
require "ISUI/ISScrollingListBox"
require "ISUI/ISRichTextPanel"
require "RadioCom/ISUIRadio/ISSliderPanel"

local P = ParadisePOIBuilder
local FONT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local ROW_H = FONT_SMALL + 8
local GAP = 6
local PAD = 8
local STATUS_H = 96

ParadisePOIBuilderPanel = ISCollapsableWindow:derive("ParadisePOIBuilderPanel")

function ParadisePOIBuilderPanel:new(x, y, width, height)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.title = "POI Builder"
    o.titleBarFont = UIFont.Medium
    o.titleFontHgt = getTextManager():getFontHeight(UIFont.Medium)
    o.minimumWidth = 1130
    o.minimumHeight = 620
    o.resizable = true
    o.rows = {}
    o.area = nil
    o.pickTarget = nil
    o.cursor = nil
    o.northSprite = nil
    o.westSprite = nil
    o.assignTarget = "north"
    o.selectedSheet = nil
    o.sheetNames = nil
    o.tool = "wall"
    o.percent = 100
    o.itemCount = 1
    o.objectEntries = {}
    o.itemEntries = {}
    return o
end

function ParadisePOIBuilderPanel:columnWidth()
    return math.max(260, math.floor(self.width * 0.20))
end

function ParadisePOIBuilderPanel:addRow(cells, height)
    self.rows[#self.rows + 1] = { cells = cells, height = height or ROW_H }
    for i = 1, #cells do
        self:addChild(cells[i].widget)
    end
end

function ParadisePOIBuilderPanel:createChildren()
    ISCollapsableWindow.createChildren(self)
    self:setResizable(true)
    if self.resizeWidget then self.resizeWidget.resizeFunction = ParadisePOIBuilderPanel.onResize end
    if self.resizeWidget2 then self.resizeWidget2.resizeFunction = ParadisePOIBuilderPanel.onResize end

    self.statusArea = ISRichTextPanel:new(PAD, 0, 260, STATUS_H)
    self.statusArea:initialise()
    self.statusArea:instantiate()
    self.statusArea.background = true
    self.statusArea.backgroundColor = { r = 0.06, g = 0.06, b = 0.09, a = 0.95 }
    self.statusArea.borderColor = { r = 0.28, g = 0.30, b = 0.42, a = 1.0 }
    self.statusArea.autosetheight = false
    self.statusArea.clip = true
    self.statusArea:setMargins(8, 6, 8, 6)
    self.statusArea:addScrollBars()
    self:addChild(self.statusArea)
    self:setStatus(P.Client.status)

    self.toolCombo = ISComboBox:new(0, 0, 200, ROW_H, self, nil)
    self.toolCombo:initialise()
    self.toolCombo:instantiate()
    self.toolCombo:addOptionWithData("Wall Builder", "wall")
    self.toolCombo:addOptionWithData("Object Fill", "object")
    self.toolCombo:addOptionWithData("Item Fill", "item")
    self.toolCombo:addOptionWithData("Structure Clone", "clone")
    self.toolCombo:setOnChange(self, function(p, combo)
        P.FillUI.setTool(p, combo:getOptionData(combo:getSelected()))
    end)
    self:addRow({ { widget = self:makeLabel("Tool") }, { widget = self.toolCombo, x = 52, width = 150 } })

    local wallFirst = #self.rows + 1
    if P.WallUI then P.WallUI.build(self) end
    for i = wallFirst, #self.rows do self.rows[i].tool = "wall" end

    local fillFirst = #self.rows + 1
    if P.FillUI then P.FillUI.build(self) end
    for i = fillFirst, #self.rows do
        if not self.rows[i].tool then self.rows[i].tool = "fill" end
    end

    local cloneFirst = #self.rows + 1
    if P.CloneUI then P.CloneUI.build(self) end
    for i = cloneFirst, #self.rows do
        if not self.rows[i].tool then self.rows[i].tool = "clone" end
    end

    self:buildAreaBlock()
    self:layout()
    self:dumpState()
end

function ParadisePOIBuilder.dumpPath()
    return getAbsoluteSaveFolderName("") .. "/poibuilder_state.txt"
end

local DUMP_WIDGETS = {
    "statusArea",
    "sheetSearch", "sheetList", "tilePicker",
    "itemSearch", "itemCategory", "itemAddBtn", "itemBrowser",
    "objectList", "itemEntryList", "countEntry", "bloodBtn", "fillBtn",
    "percentSlider", "toolCombo",
    "modeCombo", "axisCombo", "hpEntry", "buildBtn", "cancelBtn",
    "assignCombo", "northSlot", "westSlot",
    "bpCopyTitle", "bpCopyBtn", "bpList", "bpDetail", "bpTitle",
    "bpRenameBtn", "bpDeleteBtn", "bpLoadBtn",
    "bpRepositionBtn", "bpCancelBtn", "bpBuildBtn",
}

function ParadisePOIBuilderPanel.dumpState(self)
    local ok, err = pcall(function()
        local lines = {}
        local function add(key, value)
            lines[#lines + 1] = key .. "=" .. tostring(value)
        end
        local function probe(name)
            local widget = self[name]
            if not widget then return name .. "=MISSING" end
            local pok, vis, x, y, w, h = pcall(function()
                return widget:isVisible(), widget:getX(), widget:getY(), widget:getWidth(), widget:getHeight()
            end)
            if not pok then return name .. "=ERROR" end
            return string.format("%s=vis:%s x:%s y:%s w:%s h:%s java:%s", name, tostring(vis), tostring(x),
                tostring(y), tostring(w), tostring(h), tostring(widget.javaObject ~= nil))
        end

        add("title", self.title)
        add("titleBarFont", tostring(self.titleBarFont))
        add("drawFrame", tostring(self.drawFrame))
        add("isCollapsed", tostring(self.isCollapsed))
        add("windowWidth", self.width)
        add("windowHeight", self.height)
        add("rowCount", #self.rows)
        for i = 1, #self.rows do
            add(string.format("row%d", i), tostring(self.rows[i].tool))
        end
        add("sheetNames", self.sheetNames and #self.sheetNames or -1)
        add("sheetListItems", self.sheetList and self.sheetList.items and #self.sheetList.items or -1)
        add("tileImageName", self.tilePicker and self.tilePicker.imageName or "nil")
        add("tileCache", self.tilePicker and self.tilePicker.tileCache and #self.tilePicker.tileCache or -1)
        add("tileScrollBar", tostring(self.tilePicker and self.tilePicker.vscroll ~= nil))
        add("itemCache", P.FillUI and P.FillUI.itemCache and #P.FillUI.itemCache or -1)
        add("itemBrowserItems", self.itemBrowser and self.itemBrowser.items and #self.itemBrowser.items or -1)
        add("blueprints", P.Client and P.Client.blueprints and #P.Client.blueprints or -1)
        add("selectedBlueprint", tostring(P.CloneUI and P.CloneUI.selectedId))
        add("placementLocked", tostring(P.Placement and P.Placement.isLocked and P.Placement.isLocked()))
        add("vetoReason", tostring(P.Placement and P.Placement.vetoReason))
        local origin = P.Placement and P.Placement.origin
        add("origin", origin and (origin.x .. "," .. origin.y .. "," .. origin.z) or "nil")
        local job = P.Client and P.Client.job
        add("job", job and (job.phase .. " " .. tostring(job.done) .. "/" .. tostring(job.total)) or "nil")
        local area = self.area
        add("area", area and (area.x1 .. "," .. area.y1 .. "," .. area.x2 .. "," .. area.y2 .. "," .. area.zMin .. "," .. area.zMax) or "nil")
        add("status", P.Client and P.Client.status or "")

        local original = self.tool
        for _, tool in ipairs({ "wall", "object", "item", "clone" }) do
            self.tool = tool
            self:layout()
            add("tool", tool)
            for _, name in ipairs(DUMP_WIDGETS) do
                add("w", probe(name))
            end
        end
        self.tool = original
        self:layout()

        local path = ParadisePOIBuilder.dumpPath()
        local writer = getFileWriter(path, true, false)
        if writer then
            for i = 1, #lines do writer:write(lines[i] .. "\n") end
            writer:close()
            print("POIBuilder state written to " .. path)
        end
    end)
    if not ok then
        print("POIBuilder dumpState failed: " .. tostring(err))
    end
end

function ParadisePOIBuilderPanel:setStatus(text)
    self.statusText = text or ""
    if self.statusArea then
        self.statusArea:setText(self.statusText)
        self.statusArea:paginate()
    end
end

ParadisePOIBuilderPanel.onResize = function(panel, width, height)
    panel:setWidth(math.max(width, panel.minimumWidth or 0))
    panel:setHeight(math.max(height, panel.minimumHeight or 0))
    panel:layout()
end

function ParadisePOIBuilderPanel:layout()
    local titleH = self:titleBarHeight()
    local resizeH = self:resizeWidgetHeight()
    local colW = self:columnWidth()
    local col2X = PAD + colW + GAP
    local col3X = col2X + colW + GAP
    local col3W = math.max(200, self.width - col3X - PAD)
    local contentH = math.max(120, self.height - titleH - resizeH - PAD * 2)

    if self.resizeWidget then
        self.resizeWidget:setX(self.width - resizeH)
        self.resizeWidget:setY(self.height - resizeH)
    end
    if self.resizeWidget2 then
        self.resizeWidget2:setY(self.height - resizeH)
        self.resizeWidget2:setWidth(self.width - resizeH)
    end

    local y = titleH + PAD
    for i = 1, #self.rows do
        local row = self.rows[i]
        local visible = row.tool == nil or row.tool == self.tool
            or (row.tool == "fill" and (self.tool == "object" or self.tool == "item"))
        for j = 1, #row.cells do
            row.cells[j].widget:setVisible(visible)
        end
        if visible then
            for j = 1, #row.cells do
                local cell = row.cells[j]
                local x = PAD + (cell.x or 0)
                local w = cell.width or math.max(40, colW - (cell.x or 0))
                cell.widget:setX(x)
                cell.widget:setY(y)
                cell.widget:setWidth(w)
                cell.widget:setHeight(row.height)
            end
            y = y + row.height + GAP
        end
    end
    self.col1Bottom = y

    self.statusArea:setX(PAD)
    self.statusArea:setY(math.max(y, titleH + contentH - STATUS_H))
    self.statusArea:setWidth(colW)
    self.statusArea:setHeight(STATUS_H)

    self.col2X = col2X
    self.col3X = col3X
    self.col3W = col3W
    self.contentH = contentH
    self.titleH = titleH

    local tileSide = self.tool == "wall" or self.tool == "object"
    local itemSide = self.tool == "item"
    local cloneSide = self.tool == "clone"

    if self.sheetSearch then
        self.sheetSearch:setVisible(tileSide)
        self.sheetSearch:setX(col2X)
        self.sheetSearch:setY(titleH + PAD)
        self.sheetSearch:setWidth(colW)
    end
    if self.sheetList then
        self.sheetList:setVisible(tileSide)
        self.sheetList:setX(col2X)
        self.sheetList:setY(titleH + PAD + ROW_H + GAP)
        self.sheetList:setWidth(colW)
        self.sheetList:setHeight(math.max(80, contentH - ROW_H - GAP))
    end
    if self.tilePicker then
        self.tilePicker:setVisible(tileSide)
        self.tilePicker:setX(col3X)
        self.tilePicker:setY(titleH + PAD)
        self.tilePicker:setWidth(col3W)
        self.tilePicker:setHeight(contentH)
    end
    if P.WallUI and P.WallUI.syncLayout then P.WallUI.syncLayout(self) end
    if self.itemSearch then
        self.itemSearch:setVisible(itemSide)
        self.itemSearch:setX(col2X)
        self.itemSearch:setY(titleH + PAD)
        self.itemSearch:setWidth(colW)
    end
    if self.itemCategory then
        self.itemCategory:setVisible(itemSide)
        self.itemCategory:setX(col2X)
        self.itemCategory:setY(titleH + PAD + ROW_H + GAP)
        self.itemCategory:setWidth(colW)
    end
    if self.itemAddBtn then
        self.itemAddBtn:setVisible(itemSide)
        self.itemAddBtn:setX(col2X)
        self.itemAddBtn:setY(titleH + PAD + (ROW_H + GAP) * 2)
        self.itemAddBtn:setWidth(colW)
    end
    if self.itemBrowser then
        self.itemBrowser:setVisible(itemSide)
        self.itemBrowser:setX(col3X)
        self.itemBrowser:setY(titleH + PAD)
        self.itemBrowser:setWidth(col3W)
        self.itemBrowser:setHeight(contentH)
    end
    if self.bpList then
        self.bpList:setVisible(cloneSide)
        self.bpList:setX(col2X)
        self.bpList:setY(titleH + PAD)
        self.bpList:setWidth(colW)
        self.bpList:setHeight(contentH)
    end

    local detailH = math.max(60, contentH - (ROW_H + GAP) * 3)
    if self.bpDetail then
        self.bpDetail:setVisible(cloneSide)
        self.bpDetail:setX(col3X)
        self.bpDetail:setY(titleH + PAD)
        self.bpDetail:setWidth(col3W)
        self.bpDetail:setHeight(detailH)
    end
    if self.bpTitle then
        self.bpTitle:setVisible(cloneSide)
        self.bpTitle:setX(col3X)
        self.bpTitle:setY(titleH + PAD + detailH + GAP)
        self.bpTitle:setWidth(col3W)
        self.bpTitle:setHeight(ROW_H)
    end

    local btnW = math.max(60, math.floor((col3W - GAP * 2) / 3))
    local btnRow1Y = titleH + PAD + detailH + GAP + ROW_H + GAP
    local btnRow2Y = btnRow1Y + ROW_H + GAP
    local btnRowOne = { self.bpRenameBtn, self.bpDeleteBtn, self.bpLoadBtn }
    local btnRowTwo = { self.bpRepositionBtn, self.bpCancelBtn, self.bpBuildBtn }
    for i = 1, 3 do
        local b1 = btnRowOne[i]
        if b1 then
            b1:setVisible(cloneSide)
            b1:setX(col3X + (i - 1) * (btnW + GAP))
            b1:setY(btnRow1Y)
            b1:setWidth(btnW)
            b1:setHeight(ROW_H)
        end
        local b2 = btnRowTwo[i]
        if b2 then
            b2:setVisible(cloneSide)
            b2:setX(col3X + (i - 1) * (btnW + GAP))
            b2:setY(btnRow2Y)
            b2:setWidth(btnW)
            b2:setHeight(ROW_H)
        end
    end
end

function ParadisePOIBuilderPanel:refresh()
    self:setStatus(P.Client.status)
    if P.CloneUI then P.CloneUI.refresh(self) end
end

function ParadisePOIBuilderPanel:makeEntry(text, width)
    local entry = ISTextEntryBox:new(text or "", 0, 0, width or 70, ROW_H)
    entry:initialise()
    entry:instantiate()
    entry:setOnlyNumbers(true)
    return entry
end

function ParadisePOIBuilderPanel:makeLabel(text)
    local lbl = ISLabel:new(0, 0, ROW_H, text, 1, 1, 1, 1, UIFont.Small, true)
    lbl:initialise()
    return lbl
end

function ParadisePOIBuilderPanel:makeButton(label, click)
    local btn = ISButton:new(0, 0, 70, ROW_H, label, self, click)
    btn:initialise()
    btn:instantiate()
    return btn
end

function ParadisePOIBuilderPanel:buildAreaBlock()
    self.x1Entry = self:makeEntry("")
    self.y1Entry = self:makeEntry("")
    self.x2Entry = self:makeEntry("")
    self.y2Entry = self:makeEntry("")
    self.zMinEntry = self:makeEntry("", 50)
    self.zMaxEntry = self:makeEntry("", 50)

    self.pick1Btn = self:makeButton("Pick 1", ParadisePOIBuilderPanel.onPick1)
    self.pick2Btn = self:makeButton("Pick 2", ParadisePOIBuilderPanel.onPick2)

    self:addRow({ { widget = self:makeLabel("Area") } })

    self:addRow({
        { widget = self:makeLabel("Point 1") },
        { widget = self.x1Entry, x = 62, width = 62 },
        { widget = self.y1Entry, x = 130, width = 62 },
        { widget = self.pick1Btn, x = 198, width = 60 },
    })

    self:addRow({
        { widget = self:makeLabel("Point 2") },
        { widget = self.x2Entry, x = 62, width = 62 },
        { widget = self.y2Entry, x = 130, width = 62 },
        { widget = self.pick2Btn, x = 198, width = 60 },
    })

    self:addRow({
        { widget = self:makeLabel("Z min") },
        { widget = self.zMinEntry, x = 62, width = 50 },
        { widget = self:makeLabel("Z max excl."), x = 120, width = 82 },
        { widget = self.zMaxEntry, x = 206, width = 50 },
    })

    self.zMinEntry:setText("0")
    self.zMaxEntry:setText("1")

    local areaEntries = { self.x1Entry, self.y1Entry, self.x2Entry, self.y2Entry, self.zMinEntry, self.zMaxEntry }
    for i = 1, #areaEntries do
        areaEntries[i].onTextChangeFunction = function() self:updateArea() end
    end

    self:layout()
end

function ParadisePOIBuilderPanel:beginPick(target, cursorField)
    local player = getPlayer()
    if not player then return end
    self.pickTarget = target
    self.cursor = ISSelectCursor:new(player, self, self.onSquareSelected)
    self.cursor.skipWalk2 = true
    getCell():setDrag(self.cursor, player:getPlayerNum())
end

function ParadisePOIBuilderPanel:onSquareSelected(sq)
    self.cursor = nil
    if not sq or not self.pickTarget then
        self.pickTarget = nil
        return
    end
    local x, y = sq:getX(), sq:getY()
    if self.pickTarget == 1 then
        self.x1Entry:setText(tostring(x))
        self.y1Entry:setText(tostring(y))
    elseif self.pickTarget == 2 then
        self.x2Entry:setText(tostring(x))
        self.y2Entry:setText(tostring(y))
    end
    self.pickTarget = nil
    self:updateArea()
end

function ParadisePOIBuilderPanel:updateArea()
    local raw = {
        x1 = tonumber(self.x1Entry:getInternalText()),
        y1 = tonumber(self.y1Entry:getInternalText()),
        x2 = tonumber(self.x2Entry:getInternalText()),
        y2 = tonumber(self.y2Entry:getInternalText()),
        zMin = tonumber(self.zMinEntry:getInternalText()),
        zMax = tonumber(self.zMaxEntry:getInternalText()),
    }
    if not raw.x1 or not raw.y1 or not raw.x2 or not raw.y2 then
        self.area = nil
        self.areaReason = nil
        return
    end
    local area, reason = P.normalizeArea(raw)
    self.area = area
    self.areaReason = reason
    if reason then
        self:setStatus(reason)
    else
        self:setStatus(string.format("Area ready over %d level(s).", area.zMax - area.zMin))
    end
    if P.CloneUI then P.CloneUI.repin(self, area) end
end

ParadisePOIBuilderPanel.onPick1 = function(self) self:beginPick(1) end
ParadisePOIBuilderPanel.onPick2 = function(self) self:beginPick(2) end

function ParadisePOIBuilderPanel:clearPick()
    if self.cursor then
        local pl = getPlayer()
        if pl then getCell():setDrag(nil, pl:getPlayerNum()) end
    end
    self.cursor = nil
    self.pickTarget = nil
end

function ParadisePOIBuilderPanel:close()
    self:clearPick()
    if P.CloneUI then P.CloneUI.leave(self) end
    P.Client.listener = nil
    P.ClosePanel()
end

ParadisePOIBuilderPage = ParadisePOIBuilderPage or {}

function ParadisePOIBuilderPage.render()
    local panel = ParadisePOIBuilder.instance
    if not panel or not panel.area then return end
    local pl = getPlayer()
    if not pl then return end
    local plNum = pl:getPlayerNum()
    local area = panel.area
    local fill = { r = 0.20, g = 0.85, b = 0.45, a = 0.12 }
    local border = { r = 0.20, g = 0.85, b = 0.45, a = 0.75 }
    for z = area.zMin, area.zMax - 1 do
        ParadiseDev.Zones.Visualization.drawWorldArea(plNum, area.x1, area.y1, area.x2 + 1, area.y2 + 1, z, fill, border)
    end
end
Events.OnPreUIDraw.Remove(ParadisePOIBuilderPage.render)
Events.OnPreUIDraw.Add(ParadisePOIBuilderPage.render)

function ParadisePOIBuilderPage.cancelPick(key)
    if key ~= Keyboard.KEY_ESCAPE then return end
    local panel = ParadisePOIBuilder.instance
    if not panel or not panel.cursor then return end
    panel:clearPick()
    panel:setStatus("Pick cancelled.")
end
Events.OnKeyPressed.Remove(ParadisePOIBuilderPage.cancelPick)
Events.OnKeyPressed.Add(ParadisePOIBuilderPage.cancelPick)

ParadisePOIBuilderPanel.onBuild = function(self)
    if not self.area then
        self:setStatus(self.areaReason or "Pick two corners first.")
        return
    end
    local mode = self.modeCombo:getOptionData(self.modeCombo:getSelected()) or "box"
    local axis = self.axisCombo:getOptionData(self.axisCombo:getSelected()) or "auto"
    local units = P.wallUnits(self.area, mode, axis)
    if not units or #units == 0 then
        self:setStatus("That selection has no wall edges.")
        return
    end
    local needNorth, needWest = P.wallDirections(units)
    local props, reason = P.wallProps({
        northSprite = self.northSprite,
        westSprite = self.westSprite,
        hp = self.hpEntry:getInternalText(),
        indestructible = self.indestructibleTick:isSelected(1),
        sledge = self.sledgeTick:isSelected(1),
        climb = self.climbTick:isSelected(1),
    }, needNorth, needWest)
    if not props then
        self:setStatus(reason or "Wall settings are incomplete.")
        return
    end
    P.Client.requestWall(self.area, props, mode, axis)
end

ParadisePOIBuilderPanel.onCancelJob = function(self)
    P.Client.requestCancel()
end
