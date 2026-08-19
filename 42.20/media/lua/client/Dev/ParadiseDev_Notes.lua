ParadiseDev = ParadiseDev or {}
ParadiseDev.Notes = ParadiseDev.Notes or {}

ParadiseDev.Notes.module = "ParadiseDevNotes"
ParadiseDev.Notes.key = "ParadiseDevNote"
ParadiseDev.Notes.colorKey = "ParadiseDevNoteColor"
ParadiseDev.Notes.ownerKey = "ParadiseDevNoteOwner"
ParadiseDev.Notes.globalStore = "ParadiseDev_GlobalNotes"
ParadiseDev.Notes.maxLength = 160
ParadiseDev.Notes.renderRadius = 24
ParadiseDev.Notes.refreshTicks = 30
ParadiseDev.Notes.cache = ParadiseDev.Notes.cache or {}
ParadiseDev.Notes.mapLabels = ParadiseDev.Notes.mapLabels or {}
ParadiseDev.Notes.mapAPI = ParadiseDev.Notes.mapAPI or nil
ParadiseDev.Notes.tick = 0
ParadiseDev.Notes.mapDirty = true
ParadiseDev.Notes.settings = ParadiseDev.Notes.settings or { font = UIFont.Medium, showText = true, offsetX = 0, offsetY = 0 }

function ParadiseDev.Notes.getMaxLength()
    local value = SandboxVars and SandboxVars.ParadiseZnotes and tonumber(SandboxVars.ParadiseZnotes.NotesMaxLineWidth) or ParadiseDev.Notes.maxLength
    return math.max(1, math.min(1000, math.floor(value or ParadiseDev.Notes.maxLength)))
end

function ParadiseDev.Notes.getIcon(name)
    return getTexture("media/ui/Paradise/" .. name .. ".png")
end

function ParadiseDev.Notes.normalizeTag(tag)
    if tag == nil then return nil end
    tag = tostring(tag):gsub("[\r\n]+", " ")
    tag = tag:match("^%s*(.-)%s*$")
    if tag == "" then return nil end
    return string.sub(tag, 1, ParadiseDev.Notes.getMaxLength())
end

function ParadiseDev.Notes.normalizeColor(color)
    color = type(color) == "table" and color or {}
    local function channel(value, fallback)
        value = tonumber(value) or fallback
        return math.max(0, math.min(1, value))
    end
    return { r = channel(color.r, 1), g = channel(color.g, 0.85), b = channel(color.b, 0.2) }
end

function ParadiseDev.Notes.getNote(flr)
    if not flr or not flr.getModData then return nil end
    return ParadiseDev.Notes.normalizeTag(flr:getModData()[ParadiseDev.Notes.key])
end

function ParadiseDev.Notes.getColor(flr)
    return ParadiseDev.Notes.normalizeColor(flr and flr.getModData and flr:getModData()[ParadiseDev.Notes.colorKey])
end

function ParadiseDev.Notes.getOwner(flr)
    local owner = flr and flr.getModData and flr:getModData()[ParadiseDev.Notes.ownerKey] or nil
    return owner and tostring(owner) ~= "" and tostring(owner) or nil
end

function ParadiseDev.Notes.getUsername()
    local pl = getPlayer and getPlayer() or nil
    return pl and pl.getUsername and tostring(pl:getUsername()) or nil
end

function ParadiseDev.Notes.isAdmin()
    return ParadiseDev.isAdm and ParadiseDev.isAdm() or false
end

function ParadiseDev.Notes.canModifyFloor(flr)
    local note = ParadiseDev.Notes.getNote(flr)
    if not note then return true end
    return ParadiseDev.Notes.isAdmin() or ParadiseDev.Notes.getOwner(flr) == ParadiseDev.Notes.getUsername()
end

function ParadiseDev.Notes.getSquareRef(sq)
    if not sq then return nil end
    return { x = sq:getX(), y = sq:getY(), z = sq:getZ() }
end

function ParadiseDev.Notes.getFloorKey(flr)
    local ref = flr and ParadiseDev.Notes.getSquareRef(flr:getSquare()) or nil
    return ref and ref.x .. ":" .. ref.y .. ":" .. ref.z or nil
end

function ParadiseDev.Notes.setNote(flr, note, color, owner)
    if not flr or not flr.getModData then return false end
    local md = flr:getModData()
    note = ParadiseDev.Notes.normalizeTag(note)
    md[ParadiseDev.Notes.key] = note
    if note then
        md[ParadiseDev.Notes.colorKey] = ParadiseDev.Notes.normalizeColor(color or md[ParadiseDev.Notes.colorKey])
        md[ParadiseDev.Notes.ownerKey] = md[ParadiseDev.Notes.ownerKey] or owner or ParadiseDev.Notes.getUsername()
    else
        md[ParadiseDev.Notes.colorKey] = nil
        md[ParadiseDev.Notes.ownerKey] = nil
    end
    if flr.transmitModData then flr:transmitModData() end
    ParadiseDev.Notes.mapDirty = true
    ParadiseDev.Notes.refresh(true)
    return true
end

function ParadiseDev.Notes.requestSet(flr, note, color)
    local ref = flr and ParadiseDev.Notes.getSquareRef(flr:getSquare()) or nil
    if not ref then return false end
    ref.note = ParadiseDev.Notes.normalizeTag(note)
    ref.color = ParadiseDev.Notes.normalizeColor(color or ParadiseDev.Notes.getColor(flr))
    if isClient() then
        sendClientCommand(ParadiseDev.Notes.module, "set", ref)
        return true
    end
    return ParadiseDev.Notes.setNote(flr, ref.note, ref.color, ParadiseDev.Notes.getUsername())
end

function ParadiseDev.Notes.onEnteredText(target, button, flr)
    if not button or button.internal ~= "OK" or not button.parent or not button.parent.entry then return end
    ParadiseDev.Notes.requestSet(flr, button.parent.entry:getText())
end

function ParadiseDev.Notes.openTextBox(flr, plNum)
    local pl = getSpecificPlayer and plNum ~= nil and getSpecificPlayer(plNum) or getPlayer()
    if not flr or not pl or not ParadiseDev.Notes.canModifyFloor(flr) then return end
    local modal = ISTextBox:new(0, 0, 280, 180, "Note:", ParadiseDev.Notes.getNote(flr) or "", ParadiseDev.Notes, ParadiseDev.Notes.onEnteredText, plNum, flr)
    modal.maxChars = ParadiseDev.Notes.getMaxLength()
    modal:initialise()
--[[     modal:setMaxLines(3)
    modal:setMultipleLine(true) ]]
    modal:addToUIManager()
end

function ParadiseDev.Notes.remove(flr)
    if not ParadiseDev.Notes.canModifyFloor(flr) then return false end
    return ParadiseDev.Notes.requestSet(flr, nil)
end

function ParadiseDev.Notes.onFloorColorPicked(target, color, mouseUp, flr)
    if flr and ParadiseDev.Notes.canModifyFloor(flr) then ParadiseDev.Notes.requestSet(flr, ParadiseDev.Notes.getNote(flr), color) end
end

function ParadiseDev.Notes.openColorPicker(flr, hsb)
    if not flr or not ParadiseDev.Notes.canModifyFloor(flr) then return end
    local color = ParadiseDev.Notes.getColor(flr)
    if hsb then
        local initial = ColorInfo.new()
        initial:set(color.r, color.g, color.b, 1)
        local picker = ISColorPickerHSB:new(getMouseX(), getMouseY(), initial)
        picker:setPickedFunc(ParadiseDev.Notes.onFloorColorPicked, flr)
        picker:initialise()
        picker:addToUIManager()
        return
    end
    local picker = ISColorPicker:new(getMouseX(), getMouseY())
    local nearest, distance = 1, math.huge
    for index, value in ipairs(picker.colors) do
        local d = (value.r - color.r) ^ 2 + (value.g - color.g) ^ 2 + (value.b - color.b) ^ 2
        if d < distance then nearest, distance = index, d end
    end
    picker.index = nearest
    picker:setPickedFunc(ParadiseDev.Notes.onFloorColorPicked, flr)
    picker:initialise()
    picker:addToUIManager()
end

function ParadiseDev.Notes.getClickedSquare()
    if ISWorldObjectContextMenu and ISWorldObjectContextMenu.fetchVars then return ISWorldObjectContextMenu.fetchVars.clickedSquare end
    return clickedSquare
end

function ParadiseDev.Notes.setFont(target, font)
    ParadiseDev.Notes.settings.font = font
end

function ParadiseDev.Notes.setTextVisible()
    ParadiseDev.Notes.settings.showText = not ParadiseDev.Notes.settings.showText
end

function ParadiseDev.Notes.onOffsetEntered(target, button)
    if not button or button.internal ~= "OK" or not button.parent then return end
    local modal = button.parent
    ParadiseDev.Notes.settings.offsetX = tonumber(modal.offsetX and modal.offsetX:getText()) or 0
    ParadiseDev.Notes.settings.offsetY = tonumber(modal.offsetY and modal.offsetY:getText()) or 0
end

function ParadiseDev.Notes.openOffsetPanel()
    local modal = ISModalDialog:new(0, 0, 300, 170, "World note offset", false, ParadiseDev.Notes, ParadiseDev.Notes.onOffsetEntered)
    modal:initialise()
    modal.offsetX = ISTextEntryBox:new(tostring(ParadiseDev.Notes.settings.offsetX or 0), 75, 58, 180, 24)
    modal.offsetX:initialise()
    modal.offsetX:instantiate()
    modal:addChild(modal.offsetX)
    modal.offsetY = ISTextEntryBox:new(tostring(ParadiseDev.Notes.settings.offsetY or 0), 75, 90, 180, 24)
    modal.offsetY:initialise()
    modal.offsetY:instantiate()
    modal:addChild(modal.offsetY)
    modal.prerender = function(self)
        ISModalDialog.prerender(self)
        self:drawText("X", 48, 62, 1, 1, 1, 1, UIFont.Small)
        self:drawText("Y", 48, 94, 1, 1, 1, 1, UIFont.Small)
    end
    modal:addToUIManager()
end

function ParadiseDev.Notes.addSettings(menu)
    local settingsOption = menu:addOption("Settings")
    settingsOption.iconTexture = ParadiseDev.Notes.getIcon("context_noteWrite")
    local settingsMenu = ISContextMenu:getNew(menu)
    menu:addSubMenu(settingsOption, settingsMenu)
    local sizeOption = settingsMenu:addOption("Size")
    sizeOption.iconTexture = ParadiseDev.Notes.getIcon("context_noteRead")
    local sizeMenu = ISContextMenu:getNew(settingsMenu)
    settingsMenu:addSubMenu(sizeOption, sizeMenu)
    local small = sizeMenu:addOption("Small", ParadiseDev.Notes, ParadiseDev.Notes.setFont, UIFont.Small)
    local medium = sizeMenu:addOption("Medium", ParadiseDev.Notes, ParadiseDev.Notes.setFont, UIFont.Medium)
    local large = sizeMenu:addOption("Large", ParadiseDev.Notes, ParadiseDev.Notes.setFont, UIFont.Large)
    sizeMenu:setOptionChecked(small, ParadiseDev.Notes.settings.font == UIFont.Small)
    sizeMenu:setOptionChecked(medium, ParadiseDev.Notes.settings.font == UIFont.Medium)
    sizeMenu:setOptionChecked(large, ParadiseDev.Notes.settings.font == UIFont.Large)
    local text = settingsMenu:addOption("Show", ParadiseDev.Notes, ParadiseDev.Notes.setTextVisible)
    settingsMenu:setOptionChecked(text, ParadiseDev.Notes.settings.showText)
    settingsMenu:addOption("World Offset", ParadiseDev.Notes, ParadiseDev.Notes.openOffsetPanel)
end

function ParadiseDev.Notes.getGlobalNotes()
    local data = ModData and ModData.get and ModData.get(ParadiseDev.Notes.globalStore) or nil
    return data and data.notes or {}
end

function ParadiseDev.Notes.getDiscovery()
    local pl = getPlayer and getPlayer() or nil
    if not pl or not pl.getModData then return {} end
    local md = pl:getModData()
    md.ParadiseDevNotesDiscovery = md.ParadiseDevNotesDiscovery or {}
    return md.ParadiseDevNotesDiscovery
end

function ParadiseDev.Notes.rememberFloor(flr)
    local key, owner = ParadiseDev.Notes.getFloorKey(flr), ParadiseDev.Notes.getOwner(flr)
    if not key or not owner or owner == ParadiseDev.Notes.getUsername() then return end
    local discovered = ParadiseDev.Notes.getDiscovery()
    if not discovered[key] then
        discovered[key] = { show = true }
        local pl = getPlayer and getPlayer() or nil
        if pl and pl.transmitModData then pl:transmitModData() end
    end
end

function ParadiseDev.Notes.isMapVisible(flr)
    if ParadiseDev.Notes.getOwner(flr) == ParadiseDev.Notes.getUsername() then return true end
    local state = ParadiseDev.Notes.getDiscovery()[ParadiseDev.Notes.getFloorKey(flr)]
    return state and state.show == true or false
end

function ParadiseDev.Notes.toggleMapVisible(flr)
    local key = ParadiseDev.Notes.getFloorKey(flr)
    if not key or ParadiseDev.Notes.getOwner(flr) == ParadiseDev.Notes.getUsername() then return end
    local discovered = ParadiseDev.Notes.getDiscovery()
    discovered[key] = discovered[key] or {}
    discovered[key].show = not (discovered[key].show == true)
    local pl = getPlayer and getPlayer() or nil
    if pl and pl.transmitModData then pl:transmitModData() end
    ParadiseDev.Notes.mapDirty = true
end

function ParadiseDev.Notes.requestGlobal(flr, note, color)
    if not ParadiseDev.Notes.isAdmin() then return false end
    local ref = flr and ParadiseDev.Notes.getSquareRef(flr:getSquare()) or nil
    if not ref then return false end
    ref.note = ParadiseDev.Notes.normalizeTag(note)
    ref.color = ParadiseDev.Notes.normalizeColor(color)
    if isClient() then
        sendClientCommand(ParadiseDev.Notes.module, "globalSet", ref)
        return true
    end
    return false
end

function ParadiseDev.Notes.openGlobalTextBox(flr, plNum)
    if not ParadiseDev.Notes.isAdmin() then return end
    local key = ParadiseDev.Notes.getFloorKey(flr)
    local entry = key and ParadiseDev.Notes.getGlobalNotes()[key] or nil
    local modal = ISTextBox:new(0, 0, 280, 180, "Global Note:", entry and entry.text or "", ParadiseDev.Notes, function(target, button, floor)
        if button and button.internal == "OK" and button.parent and button.parent.entry then ParadiseDev.Notes.requestGlobal(floor, button.parent.entry:getText(), entry and entry.color or nil) end
    end, plNum, flr)
    modal.maxChars = ParadiseDev.Notes.getMaxLength()
    modal:initialise()
    modal:addToUIManager()
end

function ParadiseDev.Notes.addWorldContext(plNum, context, worldobjects, test)
    if test then return end
    local sq = ParadiseDev.Notes.getClickedSquare()
    local flr = sq and sq:getFloor() or nil
    if not flr then return end
    local note = ParadiseDev.Notes.getNote(flr)
    local option = context:addOptionOnTop("Notes:")
    option.iconTexture = ParadiseDev.Notes.getIcon("context_note")
    if note then
        local tooltip = ISToolTip:new()
        tooltip:initialise()
        tooltip.description = note
        option.toolTip = tooltip
    end
    local submenu = ISContextMenu:getNew(context)
    context:addSubMenu(option, submenu)
    local modify = submenu:addOption(note and "Edit" or "Write", flr, ParadiseDev.Notes.openTextBox, plNum)
    modify.iconTexture = ParadiseDev.Notes.getIcon("context_noteWrite")
    modify.notAvailable = not ParadiseDev.Notes.canModifyFloor(flr)
    local remove = submenu:addOption("Erase", flr, ParadiseDev.Notes.remove)
    remove.iconTexture = ParadiseDev.Notes.getIcon("context_noteRead")
    remove.notAvailable = not ParadiseDev.Notes.getNote(flr) or not ParadiseDev.Notes.canModifyFloor(flr)
    local colors = submenu:addOption("Colors")
    colors.iconTexture = ParadiseDev.Notes.getIcon("context_noteRGB")
    local colorsMenu = ISContextMenu:getNew(submenu)
    submenu:addSubMenu(colors, colorsMenu)
    local color = colorsMenu:addOption("Note Color", flr, ParadiseDev.Notes.openColorPicker, false)
    color.iconTexture = ParadiseDev.Notes.getIcon("context_noteRGB")
    color.notAvailable = not ParadiseDev.Notes.getNote(flr) or not ParadiseDev.Notes.canModifyFloor(flr)
    local hsbColor = colorsMenu:addOption("Note Color HSB", flr, ParadiseDev.Notes.openColorPicker, true)
    hsbColor.iconTexture = ParadiseDev.Notes.getIcon("context_noteRGB")
    hsbColor.notAvailable = color.notAvailable
    if ParadiseDev.Notes.isAdmin() then
        local global = submenu:addOption("Write Global Note", flr, ParadiseDev.Notes.openGlobalTextBox, plNum)
        global.iconTexture = ParadiseDev.Notes.getIcon("context_noteWrite")
        local key = ParadiseDev.Notes.getFloorKey(flr)
        local globalNote = key and ParadiseDev.Notes.getGlobalNotes()[key] or nil
        local eraseGlobal = submenu:addOption("Erase Global Note", flr, ParadiseDev.Notes.requestGlobal, nil, nil)
        eraseGlobal.iconTexture = ParadiseDev.Notes.getIcon("context_noteRead")
        eraseGlobal.notAvailable = not globalNote
        local globalColor = colorsMenu:addOption("Global Note Color", flr, function(floor)
            local existing = ParadiseDev.Notes.getGlobalNotes()[ParadiseDev.Notes.getFloorKey(floor)]
            if not existing then return end
            local picker = ISColorPicker:new(getMouseX(), getMouseY())
            picker:setPickedFunc(function(target, picked, mouseUp, targetFloor)
                ParadiseDev.Notes.requestGlobal(targetFloor, existing.text, picked)
            end, floor)
            picker:initialise()
            picker:addToUIManager()
        end)
        globalColor.iconTexture = ParadiseDev.Notes.getIcon("context_noteRGB")
        globalColor.notAvailable = not globalNote
    end
    if ParadiseDev.Notes.getNote(flr) and ParadiseDev.Notes.getOwner(flr) ~= ParadiseDev.Notes.getUsername() then
        ParadiseDev.Notes.rememberFloor(flr)
        local mapOption = submenu:addOption(ParadiseDev.Notes.isMapVisible(flr) and "Hide Note On Map" or "Show Note On Map", flr, ParadiseDev.Notes.toggleMapVisible)
        mapOption.iconTexture = ParadiseDev.Notes.getIcon("context_note")
    end
    ParadiseDev.Notes.addSettings(submenu)
end

function ParadiseDev.Notes.refresh(force)
    ParadiseDev.Notes.tick = ParadiseDev.Notes.tick + 1
    if not force and ParadiseDev.Notes.tick < ParadiseDev.Notes.refreshTicks then return end
    ParadiseDev.Notes.tick = 0
    ParadiseDev.Notes.cache = {}
    local pl = getPlayer()
    local cell = getCell and getCell() or nil
    if not pl or not cell then return end
    local radius = math.floor(ParadiseDev.Notes.renderRadius)
    local x, y, z = math.floor(pl:getX()), math.floor(pl:getY()), math.floor(pl:getZ())
    for sx = x - radius, x + radius do
        for sy = y - radius, y + radius do
            local sq = cell:getGridSquare(sx, sy, z)
            local flr = sq and sq:getFloor() or nil
            local key = ParadiseDev.Notes.getFloorKey(flr)
            if key and ParadiseDev.Notes.getNote(flr) then
                ParadiseDev.Notes.cache[key] = flr
                ParadiseDev.Notes.rememberFloor(flr)
            end
        end
    end
    ParadiseDev.Notes.mapDirty = true
end

function ParadiseDev.Notes.canDraw()
    if not ParadiseDev.Notes.settings.showText then return false end
    return not (ISWorldMap_instance and ISWorldMap_instance.isVisible and ISWorldMap_instance:isVisible())
end

function ParadiseDev.Notes.drawText(plNum, pl, ref, note, color)
    local x = isoToScreenX(plNum, ref.x + 0.5 + (ParadiseDev.Notes.settings.offsetX or 0), ref.y + 0.5 + (ParadiseDev.Notes.settings.offsetY or 0), ref.z)
    local y = isoToScreenY(plNum, ref.x + 0.5 + (ParadiseDev.Notes.settings.offsetX or 0), ref.y + 0.5 + (ParadiseDev.Notes.settings.offsetY or 0), ref.z) - 18
    local font = ParadiseDev.Notes.settings.font
    getTextManager():DrawStringCentre(font, x - 1, y - 1, note, 0, 0, 0, 1)
    getTextManager():DrawStringCentre(font, x + 1, y + 1, note, 0, 0, 0, 1)
    getTextManager():DrawStringCentre(font, x, y, note, color.r, color.g, color.b, 1)
end

function ParadiseDev.Notes.draw()
    if not ParadiseDev.Notes.canDraw() then return end
    local pl = getPlayer()
    if not pl then return end
    local plNum, radius = pl:getPlayerNum(), ParadiseDev.Notes.renderRadius
    local radiusSq = radius * radius
    for key, flr in pairs(ParadiseDev.Notes.cache) do
        local note = ParadiseDev.Notes.getNote(flr)
        local ref = flr and ParadiseDev.Notes.getSquareRef(flr:getSquare()) or nil
        if not note or not ref then
            ParadiseDev.Notes.cache[key] = nil
        else
            local dx, dy = ref.x - pl:getX(), ref.y - pl:getY()
            if dx * dx + dy * dy <= radiusSq then ParadiseDev.Notes.drawText(plNum, pl, ref, note, ParadiseDev.Notes.getColor(flr)) end
        end
    end
    for _, entry in pairs(ParadiseDev.Notes.getGlobalNotes()) do
        local ref = { x = tonumber(entry.x), y = tonumber(entry.y), z = tonumber(entry.z) or 0 }
        local dx, dy = ref.x - pl:getX(), ref.y - pl:getY()
        if entry.text and dx * dx + dy * dy <= radiusSq then ParadiseDev.Notes.drawText(plNum, pl, ref, tostring(entry.text), ParadiseDev.Notes.normalizeColor(entry.color)) end
    end
end

function ParadiseDev.Notes.getSymbolsAPI()
    local map = ISWorldMap_instance
    local api = map and map.mapAPI or nil
    if not api and map and map.javaObject and map.javaObject.getAPIv3 then api = map.javaObject:getAPIv3() end
    return api and api.getSymbolsAPIv2 and api:getSymbolsAPIv2() or nil
end

function ParadiseDev.Notes.clearMapLabels()
    if ParadiseDev.Notes.mapAPI then
        for _, label in pairs(ParadiseDev.Notes.mapLabels) do ParadiseDev.Notes.mapAPI:removeSymbol(label) end
        if ParadiseDev.Notes.mapAPI.invalidateLayout then ParadiseDev.Notes.mapAPI:invalidateLayout() end
    end
    ParadiseDev.Notes.mapLabels = {}
end

function ParadiseDev.Notes.addMapLabel(api, key, text, ref, color)
    local label = api:addUntranslatedText(text, "text-place", ref.x, ref.y)
    if not label then return end
    color = ParadiseDev.Notes.normalizeColor(color)
    label:setRGBA(color.r, color.g, color.b, 1)
    label:setAnchor(0.5, 0.5)
    label:setScale(0.6)
    label:setRotation(0)
    label:setMatchPerspective(true)
    label:setApplyZoom(true)
    label:setMinZoom(0)
    label:setMaxZoom(24)
    label:setUserDefined(false)
    ParadiseDev.Notes.mapLabels[key] = label
end

function ParadiseDev.Notes.syncMap()
    local api = ParadiseDev.Notes.getSymbolsAPI()
    if not api then return end
    if api ~= ParadiseDev.Notes.mapAPI then
        ParadiseDev.Notes.mapAPI = api
        ParadiseDev.Notes.mapLabels = {}
        ParadiseDev.Notes.mapDirty = true
    end
    if not ParadiseDev.Notes.mapDirty then return end
    ParadiseDev.Notes.clearMapLabels()
    for key, flr in pairs(ParadiseDev.Notes.cache) do
        local ref, note = ParadiseDev.Notes.getSquareRef(flr:getSquare()), ParadiseDev.Notes.getNote(flr)
        if ref and note and ParadiseDev.Notes.isMapVisible(flr) then ParadiseDev.Notes.addMapLabel(api, "player:" .. key, note, ref, ParadiseDev.Notes.getColor(flr)) end
    end
    for key, entry in pairs(ParadiseDev.Notes.getGlobalNotes()) do
        if entry.text and tonumber(entry.x) and tonumber(entry.y) then ParadiseDev.Notes.addMapLabel(api, "global:" .. key, tostring(entry.text), entry, entry.color) end
    end
    if api.invalidateLayout then api:invalidateLayout() end
    ParadiseDev.Notes.mapDirty = false
end

function ParadiseDev.Notes.onGameStart()
    if ModData and ModData.request then ModData.request(ParadiseDev.Notes.globalStore) end
end

function ParadiseDev.Notes.onReceiveGlobalModData(name)
    if name == ParadiseDev.Notes.globalStore then ParadiseDev.Notes.mapDirty = true end
end

function ParadiseDev.Notes.onTick()
    ParadiseDev.Notes.refresh()
    ParadiseDev.Notes.syncMap()
end

Events.OnFillWorldObjectContextMenu.Remove(ParadiseDev.Notes.addWorldContext)
Events.OnFillWorldObjectContextMenu.Add(ParadiseDev.Notes.addWorldContext)
Events.OnPostUIDraw.Remove(ParadiseDev.Notes.draw)
Events.OnPostUIDraw.Add(ParadiseDev.Notes.draw)
Events.OnTick.Remove(ParadiseDev.Notes.onTick)
Events.OnTick.Add(ParadiseDev.Notes.onTick)
Events.OnGameStart.Remove(ParadiseDev.Notes.onGameStart)
Events.OnGameStart.Add(ParadiseDev.Notes.onGameStart)
Events.OnReceiveGlobalModData.Remove(ParadiseDev.Notes.onReceiveGlobalModData)
Events.OnReceiveGlobalModData.Add(ParadiseDev.Notes.onReceiveGlobalModData)
