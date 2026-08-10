ParadiseDev = ParadiseDev or {}
ParadiseDev.ObjectTags = ParadiseDev.ObjectTags or {}


ParadiseDev.ObjectTags.module = "ParadiseDevObjectTags"
ParadiseDev.ObjectTags.key = "ParadiseDevObjectTag"
ParadiseDev.ObjectTags.maxLength = 96
ParadiseDev.ObjectTags.renderRadius = 24
ParadiseDev.ObjectTags.refreshTicks = 30
ParadiseDev.ObjectTags.showTags = true
ParadiseDev.ObjectTags.showForAll = ParadiseDev.ObjectTags.showForAll ~= false
ParadiseDev.ObjectTags.cache = ParadiseDev.ObjectTags.cache or {}
ParadiseDev.ObjectTags.tick = 0

function ParadiseDev.ObjectTags.normalizeTag(tag)
    if tag == nil then return nil end
    tag = tostring(tag):gsub("[\r\n]+", " ")
    tag = tag:match("^%s*(.-)%s*$")
    if tag == "" then return nil end
    return string.sub(tag, 1, ParadiseDev.ObjectTags.maxLength)
end

function ParadiseDev.ObjectTags.getTag(obj)
    if not obj or not obj.getModData then return nil end
    return ParadiseDev.ObjectTags.normalizeTag(obj:getModData()[ParadiseDev.ObjectTags.key])
end

function ParadiseDev.ObjectTags.getObjectRef(obj)
    if not obj or not obj.getSquare or not obj.getObjectIndex then return nil end
    local sq = obj:getSquare()
    local index = obj:getObjectIndex()
    if not sq or not index or index < 0 then return nil end
    return {
        x = sq:getX(),
        y = sq:getY(),
        z = sq:getZ(),
        index = index,
    }
end

function ParadiseDev.ObjectTags.getObjectKey(obj)
    local ref = ParadiseDev.ObjectTags.getObjectRef(obj)
    if not ref then return nil end
    return ref.x .. ":" .. ref.y .. ":" .. ref.z .. ":" .. ref.index
end

function ParadiseDev.ObjectTags.setTag(obj, tag)
    if not obj or not obj.getModData then return false end
    obj:getModData()[ParadiseDev.ObjectTags.key] = ParadiseDev.ObjectTags.normalizeTag(tag)
    if obj.transmitModData then obj:transmitModData() end
    ParadiseDev.ObjectTags.refresh(true)
    return true
end

function ParadiseDev.ObjectTags.requestSet(obj, tag)
    local ref = ParadiseDev.ObjectTags.getObjectRef(obj)
    if not ref then return false end
    tag = ParadiseDev.ObjectTags.normalizeTag(tag)
    if isClient() then
        ref.tag = tag
        sendClientCommand(ParadiseDev.ObjectTags.module, "set", ref)
        return true
    end
    return ParadiseDev.ObjectTags.setTag(obj, tag)
end

function ParadiseDev.ObjectTags.onEnteredText(target, button, obj)
    if not button or button.internal ~= "OK" or not button.parent or not button.parent.entry then return end
    ParadiseDev.ObjectTags.requestSet(obj, button.parent.entry:getText())
end

function ParadiseDev.ObjectTags.openTextBox(obj, plNum)
    local pl = getSpecificPlayer and plNum ~= nil and getSpecificPlayer(plNum) or getPlayer()
    if not obj or not pl then return end
    local modal = ISTextBox:new(0, 0, 280, 180, "Object Tag:", ParadiseDev.ObjectTags.getTag(obj) or "", ParadiseDev.ObjectTags, ParadiseDev.ObjectTags.onEnteredText, plNum, obj)
    modal:initialise()
    modal:addToUIManager()
end

function ParadiseDev.ObjectTags.clearTag(obj)
    return ParadiseDev.ObjectTags.requestSet(obj, nil)
end

function ParadiseDev.ObjectTags.getObjectName(obj)
    if not obj then return "Object" end
    if obj.getSprite then
        local spr = obj:getSprite()
        if spr and spr.getName and spr:getName() then return spr:getName() end
    end
    if obj.getName and obj:getName() then return obj:getName() end
    local ref = ParadiseDev.ObjectTags.getObjectRef(obj)
    return ref and "Object " .. tostring(ref.index) or "Object"
end

function ParadiseDev.ObjectTags.getClickedSquare()
    if ISWorldObjectContextMenu and ISWorldObjectContextMenu.fetchVars then return ISWorldObjectContextMenu.fetchVars.clickedSquare end
    return clickedSquare
end

function ParadiseDev.ObjectTags.addObjectContext(menu, obj, plNum)
    if not menu or not ParadiseDev.ObjectTags.getObjectRef(obj) then return end
    local option = menu:addOption(ParadiseDev.ObjectTags.getObjectName(obj))
    local submenu = ISContextMenu:getNew(menu)
    menu:addSubMenu(option, submenu)
    submenu:addOption("Set Tag", obj, ParadiseDev.ObjectTags.openTextBox, plNum)
    if ParadiseDev.ObjectTags.getTag(obj) then submenu:addOption("Clear Tag", obj, ParadiseDev.ObjectTags.clearTag) end
end

function ParadiseDev.ObjectTags.addWorldContext(plNum, context, worldobjects, test)
    if test or not ParadiseDev.isAdm() then return end
    local sq = ParadiseDev.ObjectTags.getClickedSquare()
    if not sq then return end
    local objects = sq:getObjects()
    if not objects or objects:size() <= 0 then return end
    local option = context:addOptionOnTop("Object Tags")
    local submenu = ISContextMenu:getNew(context)
    context:addSubMenu(option, submenu)
    for index = 0, objects:size() - 1 do
        ParadiseDev.ObjectTags.addObjectContext(submenu, objects:get(index), plNum)
    end
end

function ParadiseDev.ObjectTags.refresh(force)
    ParadiseDev.ObjectTags.tick = ParadiseDev.ObjectTags.tick + 1
    if not force and ParadiseDev.ObjectTags.tick < ParadiseDev.ObjectTags.refreshTicks then return end
    ParadiseDev.ObjectTags.tick = 0
    ParadiseDev.ObjectTags.cache = {}
    local pl = getPlayer()
    local cell = getCell and getCell() or nil
    if not pl or not cell then return end
    local radius = math.floor(ParadiseDev.ObjectTags.renderRadius)
    local x = math.floor(pl:getX())
    local y = math.floor(pl:getY())
    local z = math.floor(pl:getZ())
    for sx = x - radius, x + radius do
        for sy = y - radius, y + radius do
            local sq = cell:getGridSquare(sx, sy, z)
            local objects = sq and sq:getObjects() or nil
            if objects then
                for index = 0, objects:size() - 1 do
                    local obj = objects:get(index)
                    local key = ParadiseDev.ObjectTags.getObjectKey(obj)
                    if key and ParadiseDev.ObjectTags.getTag(obj) then ParadiseDev.ObjectTags.cache[key] = obj end
                end
            end
        end
    end
end

function ParadiseDev.ObjectTags.canDraw()
    if not ParadiseDev.ObjectTags.showTags then return false end
    return ParadiseDev.ObjectTags.showForAll or ParadiseDev.isAdm()
end

function ParadiseDev.ObjectTags.draw()
    if not ParadiseDev.ObjectTags.canDraw() then return end
    local pl = getPlayer()
    if not pl then return end
    local plNum = pl:getPlayerNum()
    local radius = ParadiseDev.ObjectTags.renderRadius
    local radiusSq = radius * radius
    for key, obj in pairs(ParadiseDev.ObjectTags.cache) do
        local tag = ParadiseDev.ObjectTags.getTag(obj)
        local ref = ParadiseDev.ObjectTags.getObjectRef(obj)
        if not tag or not ref then
            ParadiseDev.ObjectTags.cache[key] = nil
        else
            local dx = obj:getX() - pl:getX()
            local dy = obj:getY() - pl:getY()
            if dx * dx + dy * dy <= radiusSq then
                local x = isoToScreenX(plNum, obj:getX() + 0.5, obj:getY() + 0.5, obj:getZ())
                local y = isoToScreenY(plNum, obj:getX() + 0.5, obj:getY() + 0.5, obj:getZ()) - 18
                getTextManager():DrawStringCentre(UIFont.Small, x - 1, y - 1, tag, 0, 0, 0, 1)
                getTextManager():DrawStringCentre(UIFont.Small, x + 1, y + 1, tag, 0, 0, 0, 1)
                getTextManager():DrawStringCentre(UIFont.Small, x, y, tag, 1, 0.85, 0.2, 1)
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Remove(ParadiseDev.ObjectTags.addWorldContext)
Events.OnFillWorldObjectContextMenu.Add(ParadiseDev.ObjectTags.addWorldContext)
Events.OnPostUIDraw.Remove(ParadiseDev.ObjectTags.draw)
Events.OnPostUIDraw.Add(ParadiseDev.ObjectTags.draw)
Events.OnTick.Remove(ParadiseDev.ObjectTags.refresh)
Events.OnTick.Add(ParadiseDev.ObjectTags.refresh)
