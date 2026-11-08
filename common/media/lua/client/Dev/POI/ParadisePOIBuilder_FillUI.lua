ParadisePOIBuilder = ParadisePOIBuilder or {}
ParadisePOIBuilder.FillUI = ParadisePOIBuilder.FillUI or {}
if ParadisePOIBuilder.isB41() then return end

require "ISUI/ISPanel"
require "ISUI/ISScrollingListBox"
require "ISUI/ISLabel"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
require "ISUI/ISComboBox"
require "RadioCom/ISUIRadio/ISSliderPanel"

local P = ParadisePOIBuilder
local F = P.FillUI

local ROW_H = getTextManager():getFontHeight(UIFont.Small) + 8
local LIST_H = 120

F.itemCache = F.itemCache or nil
F.itemCategories = F.itemCategories or nil

function F.buildItemCache()
    if F.itemCache then return F.itemCache end
    local cache, categories, seen = {}, {}, {}
    local all = ScriptManager.instance:getAllItems()
    for i = 0, all:size() - 1 do
        local scrItem = all:get(i)
        local fullType = tostring(scrItem:getFullName())
        local displayName = tostring(scrItem:getDisplayName() or "")
        local category = tostring(scrItem:getDisplayCategory() or "Misc")
        cache[#cache + 1] = {
            id = fullType,
            text = displayName .. "  (" .. fullType .. ")",
            search = string.lower(fullType .. " " .. displayName),
            category = category,
        }
        if not seen[category] then
            seen[category] = true
            categories[#categories + 1] = category
        end
    end
    table.sort(cache, function(a, b) return a.text < b.text end)
    table.sort(categories)
    F.itemCache = cache
    F.itemCategories = categories
    return cache
end

function F.setTool(panel, tool)
    if tool ~= "wall" and tool ~= "object" and tool ~= "item" and tool ~= "clone" then return end
    if tool == "clone" then
        if P.CloneUI then P.CloneUI.setTool(panel) end
        return
    end
    if panel.tool == "clone" and P.CloneUI then P.CloneUI.leave(panel) end
    panel.tool = tool
    if tool == "item" then F.fillItemBrowser(panel) end
    panel:layout()
    if panel.dumpState then panel:dumpState() end
end

function F.refillList(panel, which)
    local list = which == "object" and panel.objectList or panel.itemEntryList
    local entries = which == "object" and panel.objectEntries or panel.itemEntries
    list:clear()
    list:setScrollHeight(0)
    for i = 1, #entries do
        list:addItem(entries[i], entries[i])
    end
end

function F.addObjectEntry(panel, sprName)
    if #panel.objectEntries >= P.MAX_FILL_ENTRIES then
        panel:setStatus(string.format("The fill list holds at most %d entries.", P.MAX_FILL_ENTRIES))
        return
    end
    for i = 1, #panel.objectEntries do
        if panel.objectEntries[i] == sprName then return end
    end
    panel.objectEntries[#panel.objectEntries + 1] = sprName
    F.refillList(panel, "object")
end

function F.addItemEntry(panel, fullType)
    if #panel.itemEntries >= P.MAX_FILL_ENTRIES then
        panel:setStatus(string.format("The fill list holds at most %d entries.", P.MAX_FILL_ENTRIES))
        return
    end
    for i = 1, #panel.itemEntries do
        if panel.itemEntries[i] == fullType then return end
    end
    panel.itemEntries[#panel.itemEntries + 1] = fullType
    F.refillList(panel, "item")
end

function F.removeSelected(panel, which)
    local list = which == "object" and panel.objectList or panel.itemEntryList
    local entries = which == "object" and panel.objectEntries or panel.itemEntries
    local item = list.items[list.selected]
    if not item then return end
    for i = 1, #entries do
        if entries[i] == item.item then
            table.remove(entries, i)
            break
        end
    end
    F.refillList(panel, which)
end

function F.fillItemBrowser(panel)
    F.buildItemCache()
    if panel.itemCategory:getOptionCount() == 0 then
        panel.itemCategory:addOptionWithData("All categories", "")
        for i = 1, #F.itemCategories do
            panel.itemCategory:addOptionWithData(F.itemCategories[i], F.itemCategories[i])
        end
    end
    F.filterItems(panel)
end

function F.filterItems(panel)
    local needle = string.lower(tostring(panel.itemSearch:getInternalText() or ""))
    local category = panel.itemCategory:getOptionData(panel.itemCategory:getSelected()) or ""
    local list = panel.itemBrowser
    list:clear()
    list:setScrollHeight(0)
    for i = 1, #F.itemCache do
        local rec = F.itemCache[i]
        if (category == "" or rec.category == category)
            and (needle == "" or string.find(rec.search, needle, 1, true)) then
            list:addItem(rec.text, rec.id)
        end
    end
end

function F.onFill(panel, kind)
    if not panel.area then
        panel:setStatus(panel.areaReason or "Pick two corners first.")
        return
    end
    local entries = kind == "item" and panel.itemEntries or panel.objectEntries
    local props, reason = P.fillProps({
        percent = panel.percent,
        count = panel.itemCount,
        entries = entries,
    }, kind)
    if not props then
        panel:setStatus(reason or "Fill settings are incomplete.")
        return
    end
    if kind == "item" then
        P.Client.requestItemFill(panel.area, props)
    else
        P.Client.requestObjectFill(panel.area, props)
    end
end

function F.build(panel)
    local function label(text)
        local lbl = ISLabel:new(0, 0, ROW_H, text, 1, 1, 1, 1, UIFont.Small, true)
        lbl:initialise()
        return lbl
    end

    panel.percentLabel = label("100%")
    panel.percentSlider = ISSliderPanel:new(0, 0, 160, ROW_H, panel, function(_, value)
        panel.percent = math.floor(tonumber(value) or 100)
        panel.percentLabel:setNameWithoutMoving(tostring(panel.percent) .. "%")
    end)
    panel.percentSlider:initialise()
    panel.percentSlider:instantiate()
    panel.percentSlider:setValues(1, 100, 1, 5, true)
    panel.percentSlider:setCurrentValue(100, true)
    panel:addRow({
        { widget = label("Percent") },
        { widget = panel.percentSlider, x = 62, width = 150 },
        { widget = panel.percentLabel, x = 218, width = 44 },
    })

    panel.countEntry = ISTextEntryBox:new("1", 0, 0, 60, ROW_H)
    panel.countEntry:initialise()
    panel.countEntry:instantiate()
    panel.countEntry:setOnlyNumbers(true)
    panel.countEntry.onTextChangeFunction = function()
        panel.itemCount = tonumber(panel.countEntry:getInternalText()) or 1
    end
    local countRow = { { widget = label("Per square") }, { widget = panel.countEntry, x = 80, width = 60 } }
    panel:addRow(countRow)
    panel.rows[#panel.rows].tool = "item"

    panel.objectList = ISScrollingListBox:new(0, 0, 200, LIST_H)
    panel.objectList:initialise()
    panel.objectList:instantiate()
    panel.objectList.itemheight = ROW_H
    panel.objectList.font = UIFont.Small
    panel.objectList.drawBorder = true
    local objRow = { { widget = panel.objectList } }
    panel:addRow(objRow, LIST_H)
    panel.rows[#panel.rows].tool = "object"

    panel.itemEntryList = ISScrollingListBox:new(0, 0, 200, LIST_H)
    panel.itemEntryList:initialise()
    panel.itemEntryList:instantiate()
    panel.itemEntryList.itemheight = ROW_H
    panel.itemEntryList.font = UIFont.Small
    panel.itemEntryList.drawBorder = true
    local itemRow = { { widget = panel.itemEntryList } }
    panel:addRow(itemRow, LIST_H)
    panel.rows[#panel.rows].tool = "item"

    panel.objRemoveBtn = ISButton:new(0, 0, 80, ROW_H, "Remove", panel, function() F.removeSelected(panel, "object") end)
    panel.objRemoveBtn:initialise()
    panel.objRemoveBtn:instantiate()
    panel.bloodEntry = ISTextEntryBox:new("5", 0, 0, 40, ROW_H)
    panel.bloodEntry:initialise()
    panel.bloodEntry:instantiate()
    panel.bloodEntry:setOnlyNumbers(true)
    panel.bloodBtn = ISButton:new(0, 0, 80, ROW_H, "Blood", panel, function()
        local n = P.clampInt(panel.bloodEntry:getInternalText(), 1, P.BLOOD_MAX) or 1
        F.addObjectEntry(panel, "blood:" .. tostring(n))
    end)
    panel.bloodBtn:initialise()
    panel.bloodBtn:instantiate()
    local objBtnRow = {
        { widget = panel.objRemoveBtn, width = 80 },
        { widget = panel.bloodBtn, x = 86, width = 80 },
        { widget = panel.bloodEntry, x = 172, width = 40 },
    }
    panel:addRow(objBtnRow)
    panel.rows[#panel.rows].tool = "object"

    panel.itemRemoveBtn = ISButton:new(0, 0, 80, ROW_H, "Remove", panel, function() F.removeSelected(panel, "item") end)
    panel.itemRemoveBtn:initialise()
    panel.itemRemoveBtn:instantiate()
    local itemBtnRow = { { widget = panel.itemRemoveBtn, width = 80 } }
    panel:addRow(itemBtnRow)
    panel.rows[#panel.rows].tool = "item"

    panel.fillBtn = ISButton:new(0, 0, 90, ROW_H, "Fill", panel, function() F.onFill(panel, panel.tool) end)
    panel.fillBtn:initialise()
    panel.fillBtn:instantiate()
    panel.fillCancelBtn = ISButton:new(0, 0, 90, ROW_H, "Cancel", panel, function() P.Client.requestCancel() end)
    panel.fillCancelBtn:initialise()
    panel.fillCancelBtn:instantiate()
    panel:addRow({
        { widget = panel.fillBtn, width = 90 },
        { widget = panel.fillCancelBtn, x = 96, width = 90 },
    })

    panel.itemSearch = ISTextEntryBox:new("", 0, 0, 200, ROW_H)
    panel.itemSearch:initialise()
    panel.itemSearch:instantiate()
    panel.itemSearch.onTextChange = function() F.filterItems(panel) end
    panel:addChild(panel.itemSearch)

    panel.itemCategory = ISComboBox:new(0, 0, 200, ROW_H, panel, nil)
    panel.itemCategory:initialise()
    panel.itemCategory:instantiate()
    panel.itemCategory:setOnChange(panel, function(p) F.filterItems(p) end)
    panel:addChild(panel.itemCategory)

    panel.itemAddBtn = ISButton:new(0, 0, 200, ROW_H, "Add to list", panel, function()
        local item = panel.itemBrowser.items[panel.itemBrowser.selected]
        if item then F.addItemEntry(panel, item.item) end
    end)
    panel.itemAddBtn:initialise()
    panel.itemAddBtn:instantiate()
    panel:addChild(panel.itemAddBtn)

    panel.itemBrowser = ISScrollingListBox:new(0, 0, 300, 300)
    panel.itemBrowser:initialise()
    panel.itemBrowser:instantiate()
    panel.itemBrowser.itemheight = ROW_H
    panel.itemBrowser.font = UIFont.Small
    panel.itemBrowser.drawBorder = true
    panel:addChild(panel.itemBrowser)

    F.refillList(panel, "object")
    F.refillList(panel, "item")
end

function F.onGameStart()
    F.itemCache = nil
    F.itemCategories = nil
end
Events.OnCreatePlayer.Remove(F.onGameStart)
Events.OnCreatePlayer.Add(F.onGameStart)