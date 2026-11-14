ParadisePOIBuilder = ParadisePOIBuilder or {}
ParadisePOIBuilder.WallUI = ParadisePOIBuilder.WallUI or {}
if ParadisePOIBuilder.isB41() then return end

require "ISUI/ISPanel"
require "ISUI/ISScrollingListBox"
require "ISUI/ISLabel"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
require "ISUI/ISComboBox"
require "ISUI/ISTickBox"

local P = ParadisePOIBuilder
local U = P.WallUI

local ROW_H = getTextManager():getFontHeight(UIFont.Small) + 8

U.TARGET_LABELS = { north = "North edge", west = "West edge" }

P.TileGrid = ISPanel:derive("ParadisePOIBuilderTileGrid")

function P.TileGrid:render()
    local ok, err = pcall(function() U.drawTileGrid(self) end)
    if not ok and not self.renderErrorLogged then
        self.renderErrorLogged = true
        print("POIBuilder tile grid render error: " .. tostring(err))
    end
end

function U.buildTileCache(grid)
    local imageName = grid.imageName
    grid.tileCacheSheet = imageName
    grid.tileCache = {}
    grid.validTiles = {}
    grid.posToTileNameTable = {}
    if not imageName then
        grid:setScrollHeight(0)
        return
    end
    local tileWidth, tileHeight = 64, 128
    local scale = tileWidth / 128
    local cache = grid.tileCache
    local maxRow = 1
    for r = 1, 256 do
        local row = {}
        for c = 1, 8 do
            local tileName = imageName .. "_" .. tostring((c - 1) + (r - 1) * 8)
            row[c] = tileName
            local texture = getTexture(tileName)
            if texture then
                grid.validTiles[tileName] = true
                cache[#cache + 1] = {
                    name = tileName,
                    texture = texture,
                    x = (c - 1) * tileWidth + texture:getOffsetX() * scale,
                    y = (r - 1) * tileHeight + texture:getOffsetY() * scale,
                    w = texture:getWidth() * scale,
                    h = texture:getHeight() * scale,
                }
                maxRow = r
            end
        end
        grid.posToTileNameTable[r] = row
    end
    grid:setScrollHeight(maxRow * tileHeight)
end

function U.drawTileGrid(grid)
    ISPanel.render(grid)
    if grid.tileCacheSheet ~= grid.imageName then
        U.buildTileCache(grid)
    end
    if not grid.imageName then
        grid:drawTextCentre("Pick a sheet on the left", grid.width / 2, 12, 0.8, 0.8, 0.8, 1.0, UIFont.Small)
        return
    end
    local cache = grid.tileCache or {}
    for i = 1, #cache do
        local e = cache[i]
        grid:drawTextureScaled(e.texture, e.x, e.y, e.w, e.h, 1.0, 1.0, 1.0, 1.0)
    end
    local c = math.floor(grid:getMouseX() / 64)
    local r = math.floor(grid:getMouseY() / 128)
    if c >= 0 and c < 8 and r >= 0 and r < 128 then
        grid:drawRectBorder(c * 64, r * 128, 64, 128, 0.6, 1, 1, 1)
    end
end

function P.TileGrid:onMouseWheel(del)
    self:setYScroll(self:getYScroll() - del * 128)
    return true
end

function P.TileGrid:onMouseDown(x, y)
    local c = math.floor(x / 64)
    local r = math.floor(y / 128)
    if c < 0 or c >= 8 or r < 0 or r >= 128 then return end
    local row = self.posToTileNameTable[r + 1]
    if not row or not row[c + 1] then return end
    local name = row[c + 1]
    if not (self.validTiles and self.validTiles[name]) then return end
    if self.panel.tool == "object" and P.FillUI then
        P.FillUI.addObjectEntry(self.panel, name)
    else
        U.selectTile(self.panel, name)
    end
end

function P.TileGrid:new(x, y, w, h, panel)
    local o = ISPanel.new(self, x, y, w, h)
    o.backgroundColor = { r = 0.05, g = 0.05, b = 0.07, a = 1.0 }
    o.imageName = nil
    o.panel = panel
    o.posToTileNameTable = {}
    o.tileCache = {}
    o.tileCacheSheet = nil
    o.validTiles = {}
    return o
end

function U.buildSheetNames()
    local names, seen = {}, {}
    local all = getWorld():getTileImageNames()
    if not all then return names end
    for i = 0, all:size() - 1 do
        local full = all:get(i)
        if full then
            local sheet = luautils.split(full, ".")[1]
            if sheet and not seen[sheet] and getTexture(sheet .. "_0") then
                seen[sheet] = true
                names[#names + 1] = sheet
            end
        end
    end
    table.sort(names)
    return names
end

function U.build(panel)
    local function label(text)
        local lbl = ISLabel:new(0, 0, ROW_H, text, 1, 1, 1, 1, UIFont.Small, true)
        lbl:initialise()
        return lbl
    end

    local function entry(text, w)
        local e = ISTextEntryBox:new(text or "", 0, 0, w or 70, ROW_H)
        e:initialise()
        e:instantiate()
        return e
    end

    panel.wallHeader = label("Wall Builder")
    panel:addRow({ { widget = panel.wallHeader } })

    panel.modeCombo = ISComboBox:new(0, 0, 110, ROW_H, panel, nil)
    panel.modeCombo:initialise()
    panel.modeCombo:instantiate()
    panel.modeCombo:addOptionWithData("Box", "box")
    panel.modeCombo:addOptionWithData("Linear", "linear")

    panel.axisCombo = ISComboBox:new(0, 0, 110, ROW_H, panel, nil)
    panel.axisCombo:initialise()
    panel.axisCombo:instantiate()
    panel.axisCombo:addOptionWithData("Auto", "auto")
    panel.axisCombo:addOptionWithData("X run", "x")
    panel.axisCombo:addOptionWithData("Y run", "y")

    panel:addRow({
        { widget = label("Mode") },
        { widget = panel.modeCombo, x = 52, width = 100 },
        { widget = panel.axisCombo, x = 158, width = 100 },
    })

    panel.hpEntry = entry("500", 90)

    panel:addRow({
        { widget = label("Health") },
        { widget = panel.hpEntry, x = 52, width = 90 },
    })

    panel.indestructibleTick = ISTickBox:new(0, 0, 190, ROW_H, "", panel, nil)
    panel.indestructibleTick:initialise()
    panel.indestructibleTick:instantiate()
    panel.indestructibleTick:addOption("Indestructible")
    panel:addRow({ { widget = panel.indestructibleTick } })

    panel.sledgeTick = ISTickBox:new(0, 0, 220, ROW_H, "", panel, nil)
    panel.sledgeTick:initialise()
    panel.sledgeTick:instantiate()
    panel.sledgeTick:addOption("Can be sledged")
    panel:addRow({ { widget = panel.sledgeTick } })

    panel.climbTick = ISTickBox:new(0, 0, 240, ROW_H, "", panel, nil)
    panel.climbTick:initialise()
    panel.climbTick:instantiate()
    panel.climbTick:addOption("Climbable (unverified)")
    panel:addRow({ { widget = panel.climbTick } })

    panel.buildBtn = ISButton:new(0, 0, 90, ROW_H, "Build", panel, ParadisePOIBuilderPanel.onBuild)
    panel.buildBtn:initialise()
    panel.buildBtn:instantiate()
    panel.cancelBtn = ISButton:new(0, 0, 90, ROW_H, "Cancel", panel, ParadisePOIBuilderPanel.onCancelJob)
    panel.cancelBtn:initialise()
    panel.cancelBtn:instantiate()
    panel:addRow({
        { widget = panel.buildBtn, width = 90 },
        { widget = panel.cancelBtn, x = 96, width = 90 },
    })

    panel.assignCombo = ISComboBox:new(0, 0, 110, ROW_H, panel, nil)
    panel.assignCombo:initialise()
    panel.assignCombo:instantiate()
    panel.assignCombo:addOptionWithData("North edge", "north")
    panel.assignCombo:addOptionWithData("West edge", "west")

    panel.northSlot = label(U.TARGET_LABELS.north .. ": none")
    panel.westSlot = label(U.TARGET_LABELS.west .. ": none")

    panel:addRow({
        { widget = label("Assign") },
        { widget = panel.assignCombo, x = 52, width = 110 },
    })
    panel:addRow({ { widget = panel.northSlot } })
    panel:addRow({ { widget = panel.westSlot } })

    panel.sheetSearch = ISTextEntryBox:new("", 0, 0, 200, ROW_H)
    panel.sheetSearch:initialise()
    panel.sheetSearch:instantiate()
    panel.sheetSearch.onTextChange = function() U.filterSheets(panel) end
    panel:addChild(panel.sheetSearch)

    panel.sheetList = ISScrollingListBox:new(0, 0, 200, 200)
    panel.sheetList:initialise()
    panel.sheetList:instantiate()
    panel.sheetList.itemheight = ROW_H
    panel.sheetList.font = UIFont.Small
    panel.sheetList.drawBorder = true
    panel.sheetList.doDrawItem = U.drawSheetItem
    panel.sheetList.onMouseDown = U.onSheetMouseDown
    panel:addChild(panel.sheetList)

    panel.tilePicker = P.TileGrid:new(0, 0, 300, 300, panel)
    panel.tilePicker:initialise()
    panel.tilePicker:instantiate()
    panel.tilePicker:addScrollBars()
    panel:addChild(panel.tilePicker)

    if not panel.sheetNames then panel.sheetNames = U.buildSheetNames() end
    panel.filteredSheets = panel.sheetNames
    U.fillSheetList(panel)
    if not panel.selectedSheet and panel.filteredSheets and #panel.filteredSheets > 0 then
        panel.sheetList.selected = 1
        U.onSheetChosen(panel, { item = panel.filteredSheets[1] })
    end
    panel:layout()
end

function U.drawSheetItem(list, y, item, alt)
    list:drawText(tostring(item.text), 6, y + 3, 1, 1, 1, 1, UIFont.Small)
    return y + list.itemheight
end

function U.fillSheetList(panel)
    local list = panel.sheetList
    list:clear()
    list:setScrollHeight(0)
    for i = 1, #panel.filteredSheets do
        list:addItem(panel.filteredSheets[i], panel.filteredSheets[i])
    end
end

function U.filterSheets(panel)
    local needle = string.lower(tostring(panel.sheetSearch:getInternalText() or ""))
    if needle == "" then
        panel.filteredSheets = panel.sheetNames
    else
        local out = {}
        for i = 1, #panel.sheetNames do
            local name = panel.sheetNames[i]
            if string.find(string.lower(name), needle, 1, true) then out[#out + 1] = name end
        end
        panel.filteredSheets = out
    end
    U.fillSheetList(panel)
end

function U.onSheetMouseDown(list, x, y)
    ISScrollingListBox.onMouseDown(list, x, y)
    local item = list.items[list.selected]
    if item then U.onSheetChosen(list.parent, item) end
    return true
end

function U.onSheetChosen(panel, item)
    if not panel or not item or not item.item then return end
    panel.selectedSheet = item.item
    panel.tilePicker.imageName = panel.selectedSheet
    panel.tilePicker.tileCacheSheet = nil
    U.buildTileCache(panel.tilePicker)
    panel.tilePicker:setYScroll(0)
end

function U.selectTile(panel, sprName)
    if panel.assignCombo:getOptionData(panel.assignCombo:getSelected()) == "west" then
        panel.westSprite = sprName
        panel.westSlot:setName(U.TARGET_LABELS.west .. ": " .. sprName)
    else
        panel.northSprite = sprName
        panel.northSlot:setName(U.TARGET_LABELS.north .. ": " .. sprName)
    end
    panel:layout()
end

function U.syncVScroll(elem)
    local sb = elem and elem.vscroll
    if not sb then return end
    sb.x = elem.width - 16
    sb.y = 0
    sb.width = 17
    sb.height = elem.height
    if sb.javaObject then
        sb.javaObject:setX(sb.x)
        sb.javaObject:setY(sb.y)
        sb.javaObject:setWidth(sb.width)
        sb.javaObject:setHeight(sb.height)
    end
end

function U.syncLayout(panel)
    U.syncVScroll(panel.tilePicker)
    U.syncVScroll(panel.sheetList)
end
