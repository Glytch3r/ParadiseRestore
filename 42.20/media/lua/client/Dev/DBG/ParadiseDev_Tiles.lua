ParadiseDev = ParadiseDev or {}
ParadiseDev.Tiles = ParadiseDev.Tiles or {}


function ParadiseDev.Tiles.getSpriteName(spr)
    if not spr or not spr.getName then return nil end
    local ok, name = pcall(spr.getName, spr)
    if not ok or not name or tostring(name) == "" then return nil end
    return tostring(name)
end

function ParadiseDev.Tiles.getObjectSpriteName(obj)
    if not obj or not obj.getSprite then return nil end
    local ok, spr = pcall(obj.getSprite, obj)
    if not ok then return nil end
    return ParadiseDev.Tiles.getSpriteName(spr)
end

function ParadiseDev.Tiles.getOverlaySpriteName(obj)
    if not obj or not obj.getOverlaySprite then return nil end
    local ok, spr = pcall(obj.getOverlaySprite, obj)
    if not ok then return nil end
    return ParadiseDev.Tiles.getSpriteName(spr)
end

function ParadiseDev.Tiles.getAttachedSpriteName(attached)
    if not attached or not attached.getParentSprite then return nil end
    local ok, spr = pcall(attached.getParentSprite, attached)
    if not ok then return nil end
    return ParadiseDev.Tiles.getSpriteName(spr)
end

function ParadiseDev.Tiles.setOptionIcon(option, spriteName)
    if not option or not spriteName or not getTexture then return end
    local ok, texture = pcall(getTexture, spriteName)
    if ok and texture then option.iconTexture = texture end
end

function ParadiseDev.Tiles.copyTile(obj, spriteName, pl)
    if not spriteName or tostring(spriteName) == "" then return end
    spriteName = tostring(spriteName)
    if Clipboard and Clipboard.setClipboard then Clipboard.setClipboard(spriteName) end
    pl = pl or getPlayer()
    if pl and pl.setHaloNote then pl:setHaloNote("Sprite: " .. spriteName, 150, 250, 150, 900) end
    if pl and pl.getPlayerNum and ISBrushToolTileCursor and getCell then
        local cursor = ISBrushToolTileCursor:new(spriteName, spriteName, pl)
        local cell = getCell()
        if cell and cell.setDrag then cell:setDrag(cursor, pl:getPlayerNum()) end
    end
    if ISMoveableCursor and ISMoveableCursor.clearCacheForAllPlayers then ISMoveableCursor.clearCacheForAllPlayers() end
    if obj and ParadiseDev.DataCheck and ParadiseDev.DataCheck.open then ParadiseDev.DataCheck.open(obj, spriteName) end
end

function ParadiseDev.Tiles.addCopyOption(menu, label, obj, spriteName, pl)
    if not menu or not spriteName then return end
    local option = menu:addOption(label, obj, ParadiseDev.Tiles.copyTile, spriteName, pl)
    ParadiseDev.Tiles.setOptionIcon(option, spriteName)
    return option
end

function ParadiseDev.Tiles.addObjectOptions(menu, obj, pl)
    local spriteName = ParadiseDev.Tiles.getObjectSpriteName(obj)
    if spriteName then ParadiseDev.Tiles.addCopyOption(menu, "[MAIN] " .. spriteName, obj, spriteName, pl) end
    local overlayName = ParadiseDev.Tiles.getOverlaySpriteName(obj)
    if overlayName then ParadiseDev.Tiles.addCopyOption(menu, "[OVERLAY] " .. overlayName, obj, overlayName, pl) end
    if not obj or not obj.getAttachedAnimSprite then return end
    local okSprites, sprites = pcall(obj.getAttachedAnimSprite, obj)
    if not okSprites or not sprites or not sprites.size or not sprites.get then return end
    local okCount, count = pcall(sprites.size, sprites)
    if not okCount or not count then return end
    for index = 0, count - 1 do
        local okAttached, attached = pcall(sprites.get, sprites, index)
        local attachedName = okAttached and ParadiseDev.Tiles.getAttachedSpriteName(attached) or nil
        if attachedName then ParadiseDev.Tiles.addCopyOption(menu, "[ATTACHED] " .. attachedName, obj, attachedName, pl) end
    end
end

function ParadiseDev.Tiles.getClickedSquare()
    if ISWorldObjectContextMenu and ISWorldObjectContextMenu.fetchVars then return ISWorldObjectContextMenu.fetchVars.clickedSquare end
    return clickedSquare
end

function ParadiseDev.Tiles.addContext(plNum, context, worldobjects, test)
    if test or not ParadiseDev.isAdm() then return end
    local pl = getSpecificPlayer(plNum)
    if not pl then return end
    local sq = ParadiseDev.Tiles.getClickedSquare()
    if not sq or not sq.getObjects then return end
    local objects = sq:getObjects()
    if not objects or not objects.size or not objects.get then return end
    local okCount, count = pcall(objects.size, objects)
    if not okCount or not count or count <= 0 then return end
    local root = context:addOptionOnTop("Copy Tile")
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(root, menu)
    for index = 0, count - 1 do
        local okObj, obj = pcall(objects.get, objects, index)
        if okObj and obj then ParadiseDev.Tiles.addObjectOptions(menu, obj, pl) end
    end
end

Events.OnFillWorldObjectContextMenu.Remove(ParadiseDev.Tiles.addContext)
Events.OnFillWorldObjectContextMenu.Add(ParadiseDev.Tiles.addContext)
