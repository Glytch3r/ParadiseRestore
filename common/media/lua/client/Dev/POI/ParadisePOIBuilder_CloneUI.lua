ParadisePOIBuilder = ParadisePOIBuilder or {}
ParadisePOIBuilder.CloneUI = ParadisePOIBuilder.CloneUI or {}
if ParadisePOIBuilder.isB41() then return end

require "ISUI/ISPanel"
require "ISUI/ISScrollingListBox"
require "ISUI/ISLabel"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
require "ISUI/ISRichTextPanel"

local P = ParadisePOIBuilder
local K = P.CloneUI

local ROW_H = getTextManager():getFontHeight(UIFont.Small) + 8

K.selectedId = nil
K.loadedId = nil

local function makeLabel(text)
    local lbl = ISLabel:new(0, 0, ROW_H, text, 1, 1, 1, 1, UIFont.Small, true)
    lbl:initialise()
    return lbl
end

local function makeEntry(text, width)
    local e = ISTextEntryBox:new(text or "", 0, 0, width or 120, ROW_H)
    e:initialise()
    e:instantiate()
    return e
end

local function makeButton(panel, text, width, click)
    local b = ISButton:new(0, 0, width or 90, ROW_H, text, panel, click)
    b:initialise()
    b:instantiate()
    return b
end

function K.escape(text)
    local str = tostring(text or "")
    str = string.gsub(str, "<", "&lt;")
    str = string.gsub(str, ">", "&gt;")
    return str
end

function K.formatTime(seconds)
    local n = tonumber(seconds)
    if not n or n <= 0 then return "unknown" end
    local ok, str = pcall(os.date, "%Y-%m-%d %H:%M", n)
    if ok and str then return tostring(str) end
    return "unknown"
end

function K.build(panel)
    panel.bpCopyTitle = makeEntry("", 150)
    panel:addRow({ { widget = makeLabel("Clone") } })
    panel:addRow({
        { widget = makeLabel("Title") },
        { widget = panel.bpCopyTitle, x = 52, width = 150 },
    })
    panel.bpCopyBtn = makeButton(panel, "Copy area", 100, function() K.onCopy(panel) end)
    panel:addRow({ { widget = panel.bpCopyBtn, width = 100 } })
    panel:addRow({ { widget = makeLabel("Pick the area, then copy") } })

    panel.bpList = ISScrollingListBox:new(0, 0, 200, 200)
    panel.bpList:initialise()
    panel.bpList:instantiate()
    panel.bpList.itemheight = ROW_H
    panel.bpList.font = UIFont.Small
    panel.bpList.drawBorder = true
    panel.bpList:setOnMouseDownFunction(panel, function(_, id) K.onSelect(panel, id) end)
    panel:addChild(panel.bpList)

    panel.bpDetail = ISRichTextPanel:new(0, 0, 260, 120)
    panel.bpDetail:initialise()
    panel.bpDetail:instantiate()
    panel.bpDetail.background = true
    panel.bpDetail.backgroundColor = { r = 0.06, g = 0.06, b = 0.09, a = 0.95 }
    panel.bpDetail.borderColor = { r = 0.28, g = 0.30, b = 0.42, a = 1.0 }
    panel.bpDetail.autosetheight = false
    panel.bpDetail.clip = true
    panel.bpDetail:setMargins(8, 6, 8, 6)
    panel.bpDetail:addScrollBars()
    panel:addChild(panel.bpDetail)

    panel.bpTitle = makeEntry("", 200)
    panel:addChild(panel.bpTitle)

    panel.bpRenameBtn = makeButton(panel, "Rename", 90, function() K.onRename(panel) end)
    panel.bpDeleteBtn = makeButton(panel, "Delete", 90, function() K.onDelete(panel) end)
    panel.bpLoadBtn = makeButton(panel, "Load", 90, function() K.onLoad(panel) end)
    panel.bpRepositionBtn = makeButton(panel, "Reposition", 90, function() K.onReposition(panel) end)
    panel.bpCancelBtn = makeButton(panel, "Cancel", 90, function() K.onCancel(panel) end)
    panel.bpBuildBtn = makeButton(panel, "Build", 90, function() K.onBuild(panel) end)
    for _, btn in ipairs({ panel.bpRenameBtn, panel.bpDeleteBtn, panel.bpLoadBtn,
        panel.bpRepositionBtn, panel.bpCancelBtn, panel.bpBuildBtn }) do
        panel:addChild(btn)
    end

    if P.Placement then
        P.Placement.onLock = K.onLock
        P.Placement.onScan = K.onScan
    end
end

function K.findEntry(id)
    if id == nil then return nil end
    local blueprints = P.Client and P.Client.blueprints or {}
    for i = 1, #blueprints do
        if tostring(blueprints[i].id) == tostring(id) then return blueprints[i] end
    end
    return nil
end

function K.refreshList(panel)
    local list = panel.bpList
    if not list then return end
    list:clear()
    list:setScrollHeight(0)
    local blueprints = P.Client and P.Client.blueprints or {}
    for i = 1, #blueprints do
        local entry = blueprints[i]
        local size = string.format("%dx%dx%d", tonumber(entry.dx) or 0, tonumber(entry.dy) or 0, tonumber(entry.dz) or 0)
        list:addItem(tostring(entry.title or "") .. "  " .. size, entry.id)
    end
    if K.selectedId then
        for i = 1, #list.items do
            if tostring(list.items[i].item) == tostring(K.selectedId) then
                list.selected = i
                break
            end
        end
    end
end

function K.updateDetail(panel)
    if not panel.bpDetail then return end
    local entry = K.findEntry(K.selectedId)
    local text
    if not entry then
        text = "<H2>No blueprint</H2><TEXT>Pick a blueprint from the list."
    else
        local lines = {}
        lines[#lines + 1] = "<H2>" .. K.escape(entry.title) .. "</H2><TEXT>"
        lines[#lines + 1] = "Size: " .. tostring(tonumber(entry.dx) or 0) .. " x " .. tostring(tonumber(entry.dy) or 0) .. " x " .. tostring(tonumber(entry.dz) or 0)
        lines[#lines + 1] = "Objects: " .. tostring(entry.objectCount or 0)
        lines[#lines + 1] = "Items: " .. tostring(entry.itemCount or 0)
        lines[#lines + 1] = "Created: " .. K.formatTime(entry.created)
        lines[#lines + 1] = "Author: " .. tostring(entry.author or "unknown")
        lines[#lines + 1] = "</TEXT>"
        text = table.concat(lines, "\n")
    end
    panel.bpDetail:setText(text)
    panel.bpDetail:paginate()
end

function K.updateButtons(panel)
    local L = P.Placement
    local locked = false
    local veto = nil
    local hasBlueprint = false
    if L then
        locked = L.isLocked() == true
        veto = L.vetoReason
        hasBlueprint = L.blueprint ~= nil
    end
    local busy = P.Client and P.Client.job ~= nil
    local selected = K.selectedId ~= nil
    if panel.bpBuildBtn then panel.bpBuildBtn:setEnable(locked and not veto and not busy) end
    if panel.bpRepositionBtn then panel.bpRepositionBtn:setEnable(locked) end
    if panel.bpCancelBtn then panel.bpCancelBtn:setEnable(hasBlueprint or locked) end
    if panel.bpLoadBtn then panel.bpLoadBtn:setEnable(selected and not busy) end
    if panel.bpRenameBtn then panel.bpRenameBtn:setEnable(selected) end
    if panel.bpDeleteBtn then panel.bpDeleteBtn:setEnable(selected and not busy) end
    if panel.bpCopyBtn then panel.bpCopyBtn:setEnable(panel.area ~= nil and not locked and not busy) end
end

function K.setTool(panel)
    panel.tool = "clone"
    K.refresh(panel)
    if panel.layout then panel:layout() end
end

function K.refresh(panel)
    K.refreshList(panel)
    local bp = P.Client and P.Client.blueprint or nil
    if bp and bp.id ~= K.loadedId then
        K.enterPlacement(panel, bp)
        return
    end
    if bp then
        K.selectedId = bp.id
        K.updateDetail(panel)
    end
    K.updateButtons(panel)
end

function K.onSelect(panel, id)
    K.selectedId = id
    local entry = K.findEntry(id)
    if entry and panel.bpTitle then
        panel.bpTitle:setText(tostring(entry.title or ""))
    end
    K.updateDetail(panel)
    K.updateButtons(panel)
end

function K.onCopy(panel)
    if not panel.area then
        panel:setStatus(panel.areaReason or "Pick two corners first.")
        return
    end
    local L = P.Placement
    if L and L.isLocked() then
        panel:setStatus("Cancel or reposition the placement before copying.")
        return
    end
    local title, reason = P.cleanString(panel.bpCopyTitle:getInternalText(), P.MAX_TITLE)
    if not title then
        panel:setStatus(reason or "Give the blueprint a title.")
        return
    end
    P.Client.requestCopy(panel.area, title)
    panel:setStatus("Copying " .. title .. "...")
end

function K.onRename(panel)
    if not K.selectedId then
        panel:setStatus("Select a blueprint first.")
        return
    end
    local title, reason = P.cleanString(panel.bpTitle:getInternalText(), P.MAX_TITLE)
    if not title then
        panel:setStatus(reason or "Give the blueprint a title.")
        return
    end
    P.Client.requestRename(K.selectedId, title)
end

function K.onDelete(panel)
    if not K.selectedId then
        panel:setStatus("Select a blueprint first.")
        return
    end
    P.Client.requestDelete(K.selectedId)
end

function K.onLoad(panel)
    if not K.selectedId then
        panel:setStatus("Select a blueprint first.")
        return
    end
    P.Client.requestGet(K.selectedId)
    panel:setStatus("Loading blueprint...")
end

function K.enterPlacement(panel, bp)
    local L = P.Placement
    if not L then return end
    L.setBlueprint(bp)
    L.install()
    K.loadedId = bp.id
    K.selectedId = bp.id
    K.updateDetail(panel)
    K.updateButtons(panel)
    panel:setStatus("Blueprint loaded. Click a square to set the spot, then press Build.")
end

function K.clearArea(panel)
    if not panel then return end
    if panel.x1Entry then panel.x1Entry:setText("") end
    if panel.y1Entry then panel.y1Entry:setText("") end
    if panel.x2Entry then panel.x2Entry:setText("") end
    if panel.y2Entry then panel.y2Entry:setText("") end
    if panel.zMinEntry then panel.zMinEntry:setText("0") end
    if panel.zMaxEntry then panel.zMaxEntry:setText("1") end
    panel.area = nil
    panel.areaReason = nil
end

function K.leave(panel)
    local L = P.Placement
    local locked = L and L.isLocked() == true
    if L then
        L.release()
        L.setBlueprint(nil)
    end
    K.loadedId = nil
    if P.Client then P.Client.blueprint = nil end
    if locked and panel then K.clearArea(panel) end
    if panel then K.updateButtons(panel) end
end

function K.onReposition(panel)
    local L = P.Placement
    if not L then return end
    L.unlock()
    K.clearArea(panel)
    K.updateButtons(panel)
    panel:setStatus("Placement unlocked. Click a square to set a new spot.")
end

function K.onCancel(panel)
    K.leave(panel)
    panel:setStatus("Placement cancelled.")
end

function K.onBuild(panel)
    local L = P.Placement
    if not K.loadedId then
        panel:setStatus("Load a blueprint first.")
        return
    end
    if not L or not L.isLocked() then
        panel:setStatus("Click a square to set the build spot first.")
        return
    end
    if L.vetoReason then
        panel:setStatus(L.vetoReason)
        return
    end
    if P.Client and P.Client.job then
        panel:setStatus("A job is already running.")
        return
    end
    P.Client.requestPaste(K.loadedId, L.origin, L.origin.z)
    panel:setStatus("Building...")
end

function K.repin(panel, area)
    local L = P.Placement
    if not L or not area then return end
    if not L.isLocked() then return end
    if not L.origin or L.origin.z == area.zMin then return end
    L.lock(L.origin.x, L.origin.y, area.zMin)
end

function K.onLock(origin)
    local panel = ParadisePOIBuilder.instance
    if not panel then return end
    local L = P.Placement
    local bp = L and L.blueprint or nil
    if not bp then return end
    local size = bp.size or {}
    local dx = tonumber(size.dx) or 1
    local dy = tonumber(size.dy) or 1
    local dz = tonumber(size.dz) or 1
    if panel.x1Entry then panel.x1Entry:setText(tostring(origin.x)) end
    if panel.y1Entry then panel.y1Entry:setText(tostring(origin.y)) end
    if panel.x2Entry then panel.x2Entry:setText(tostring(origin.x + dx - 1)) end
    if panel.y2Entry then panel.y2Entry:setText(tostring(origin.y + dy - 1)) end
    if panel.zMinEntry then panel.zMinEntry:setText(tostring(origin.z)) end
    if panel.zMaxEntry then panel.zMaxEntry:setText(tostring(origin.z + dz)) end
    if panel.updateArea then panel:updateArea() end
    K.updateButtons(panel)
    local message = string.format("Placement locked at %d, %d, %d.", origin.x, origin.y, origin.z)
    if L.vetoReason then message = L.vetoReason end
    panel:setStatus(message)
end

function K.onScan(reason)
    local panel = ParadisePOIBuilder.instance
    if not panel then return end
    K.updateButtons(panel)
    if reason then panel:setStatus(reason) end
end
