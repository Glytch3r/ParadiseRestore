ParadiseDev = ParadiseDev or {}
ParadiseDev.Notes = ParadiseDev.Notes or {}


ParadiseDev.Notes.module = "ParadiseDevNotes"
ParadiseDev.Notes.key = "ParadiseDevNote"
ParadiseDev.Notes.maxLength = 160
ParadiseDev.Notes.renderRadius = 24
ParadiseDev.Notes.refreshTicks = 30
ParadiseDev.Notes.cache = ParadiseDev.Notes.cache or {}
ParadiseDev.Notes.tick = 0
ParadiseDev.Notes.settings = ParadiseDev.Notes.settings or { font = UIFont.Medium, color = { r = 1, g = 0.85, b = 0.2 }, showText = true }

function ParadiseDev.Notes.getIcon(name)
    return getTexture("media/ui/Paradise/" .. name .. ".png")
end

function ParadiseDev.Notes.normalizeTag(tag)
    if tag == nil then return nil end
    tag = tostring(tag):gsub("[\r\n]+", " ")
    tag = tag:match("^%s*(.-)%s*$")
    if tag == "" then return nil end
    return string.sub(tag, 1, ParadiseDev.Notes.maxLength)
end

function ParadiseDev.Notes.getNote(flr)
    if not flr or not flr.getModData then return nil end
    return ParadiseDev.Notes.normalizeTag(flr:getModData()[ParadiseDev.Notes.key])
end

function ParadiseDev.Notes.getSquareRef(sq)
    if not sq then return nil end
    return {
        x = sq:getX(),
        y = sq:getY(),
        z = sq:getZ(),
    }
end

function ParadiseDev.Notes.getFloorKey(flr)
    local ref = flr and ParadiseDev.Notes.getSquareRef(flr:getSquare()) or nil
    if not ref then return nil end
    return ref.x .. ":" .. ref.y .. ":" .. ref.z
end

function ParadiseDev.Notes.setNote(flr, note)
    if not flr or not flr.getModData then return false end
    flr:getModData()[ParadiseDev.Notes.key] = ParadiseDev.Notes.normalizeTag(note)
    if flr.transmitModData then flr:transmitModData() end
    ParadiseDev.Notes.refresh(true)
    return true
end

function ParadiseDev.Notes.requestSet(flr, note)
    local ref = flr and ParadiseDev.Notes.getSquareRef(flr:getSquare()) or nil
    if not ref then return false end
    note = ParadiseDev.Notes.normalizeTag(note)
    if isClient() then
        ref.note = note
        sendClientCommand(ParadiseDev.Notes.module, "set", ref)
        return true
    end
    return ParadiseDev.Notes.setNote(flr, note)
end

function ParadiseDev.Notes.onEnteredText(target, button, flr)
    if not button or button.internal ~= "OK" or not button.parent or not button.parent.entry then return end
    ParadiseDev.Notes.requestSet(flr, button.parent.entry:getText())
end

function ParadiseDev.Notes.openTextBox(flr, plNum)
    local pl = getSpecificPlayer and plNum ~= nil and getSpecificPlayer(plNum) or getPlayer()
    if not flr or not pl then return end
    local modal = ISTextBox:new(0, 0, 280, 180, "Note:", ParadiseDev.Notes.getNote(flr) or "", ParadiseDev.Notes, ParadiseDev.Notes.onEnteredText, plNum, flr)
    modal.maxChars = ParadiseDev.Notes.maxLength
    modal:initialise()
--[[     modal:setMaxLines(3)
    modal:setMultipleLine(true) ]]
    modal:addToUIManager()
end

function ParadiseDev.Notes.remove(flr)
    return ParadiseDev.Notes.requestSet(flr, nil)
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

function ParadiseDev.Notes.onColorPicked(target, color)
    if color then ParadiseDev.Notes.settings.color = { r = color.r, g = color.g, b = color.b } end
end

function ParadiseDev.Notes.openColorPicker()
    local picker = ISColorPicker:new(getMouseX(), getMouseY())
    local color = ParadiseDev.Notes.settings.color
    local nearest, distance = 1, math.huge
    for index, value in ipairs(picker.colors) do
        local d = (value.r - color.r) ^ 2 + (value.g - color.g) ^ 2 + (value.b - color.b) ^ 2
        if d < distance then nearest, distance = index, d end
    end
    picker.index = nearest
    picker:setPickedFunc(ParadiseDev.Notes.onColorPicked)
    picker:initialise()
    picker:addToUIManager()
end

function ParadiseDev.Notes.openHSBColorPicker()
    local color = ParadiseDev.Notes.settings.color
    local initial = ColorInfo.new()
    initial:set(color.r, color.g, color.b, 1)
    local picker = ISColorPickerHSB:new(getMouseX(), getMouseY(), initial)
    picker:setPickedFunc(ParadiseDev.Notes.onColorPicked)
    picker:initialise()
    picker:addToUIManager()
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
    local color = settingsMenu:addOption("Color", ParadiseDev.Notes, ParadiseDev.Notes.openColorPicker)
    color.iconTexture = ParadiseDev.Notes.getIcon("context_noteRGB")
    local hsbColor = settingsMenu:addOption("Color HSB", ParadiseDev.Notes, ParadiseDev.Notes.openHSBColorPicker)
    hsbColor.iconTexture = ParadiseDev.Notes.getIcon("context_noteRGB")
    local text = settingsMenu:addOption("Show", ParadiseDev.Notes, ParadiseDev.Notes.setTextVisible)
    settingsMenu:setOptionChecked(text, ParadiseDev.Notes.settings.showText)
end

function ParadiseDev.Notes.addWorldContext(plNum, context, worldobjects, test)
    if test then return end
    local sq = ParadiseDev.Notes.getClickedSquare()
    if not sq then return end
    local flr = sq:getFloor()
    if not flr then return end
    local option = context:addOptionOnTop("Notes:")
    option.iconTexture = ParadiseDev.Notes.getIcon("context_note")
    local submenu = ISContextMenu:getNew(context)
    context:addSubMenu(option, submenu)
    local modify = submenu:addOption("Write", flr, ParadiseDev.Notes.openTextBox, plNum)
    modify.iconTexture = ParadiseDev.Notes.getIcon("context_noteWrite")
    local remove = submenu:addOption("Erase", flr, ParadiseDev.Notes.remove)
    remove.iconTexture = ParadiseDev.Notes.getIcon("context_noteRead")
    remove.notAvailable = not ParadiseDev.Notes.getNote(flr)
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
    local x = math.floor(pl:getX())
    local y = math.floor(pl:getY())
    local z = math.floor(pl:getZ())
    for sx = x - radius, x + radius do
        for sy = y - radius, y + radius do
            local sq = cell:getGridSquare(sx, sy, z)
            local flr = sq and sq:getFloor() or nil
            local key = ParadiseDev.Notes.getFloorKey(flr)
            if key and ParadiseDev.Notes.getNote(flr) then ParadiseDev.Notes.cache[key] = flr end
        end
    end
end

function ParadiseDev.Notes.canDraw()
    return ParadiseDev.Notes.settings.showText
end

function ParadiseDev.Notes.draw()
    if not ParadiseDev.Notes.canDraw() then return end
    local pl = getPlayer()
    if not pl then return end
    local plNum = pl:getPlayerNum()
    local radius = ParadiseDev.Notes.renderRadius
    local radiusSq = radius * radius
    for key, flr in pairs(ParadiseDev.Notes.cache) do
        local note = ParadiseDev.Notes.getNote(flr)
        local ref = flr and ParadiseDev.Notes.getSquareRef(flr:getSquare()) or nil
        if not note or not ref then
            ParadiseDev.Notes.cache[key] = nil
        else
            local dx = flr:getX() - pl:getX()
            local dy = flr:getY() - pl:getY()
            if dx * dx + dy * dy <= radiusSq then
                local x = isoToScreenX(plNum, flr:getX() + 0.5, flr:getY() + 0.5, flr:getZ())
                local y = isoToScreenY(plNum, flr:getX() + 0.5, flr:getY() + 0.5, flr:getZ()) - 18
                local font = ParadiseDev.Notes.settings.font
                local color = ParadiseDev.Notes.settings.color
                getTextManager():DrawStringCentre(font, x - 1, y - 1, note, 0, 0, 0, 1)
                getTextManager():DrawStringCentre(font, x + 1, y + 1, note, 0, 0, 0, 1)
                getTextManager():DrawStringCentre(font, x, y, note, color.r, color.g, color.b, 1)
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Remove(ParadiseDev.Notes.addWorldContext)
Events.OnFillWorldObjectContextMenu.Add(ParadiseDev.Notes.addWorldContext)
Events.OnPostUIDraw.Remove(ParadiseDev.Notes.draw)
Events.OnPostUIDraw.Add(ParadiseDev.Notes.draw)
Events.OnTick.Remove(ParadiseDev.Notes.refresh)
Events.OnTick.Add(ParadiseDev.Notes.refresh)
