ParadiseDev = ParadiseDev or {}
ParadiseDev.Tiles = ParadiseDev.Tiles or {}

function ParadiseDev.Tiles.layoutBrushPanel(panel)
    local titleHeight = panel:titleBarHeight()
    local resizeHeight = panel:resizeWidgetHeight()
    local sidebarWidth = math.max(250, math.floor(panel.width * 0.36))
    if panel.resizeWidget then
        panel.resizeWidget:setX(panel.width - resizeHeight)
        panel.resizeWidget:setY(panel.height - resizeHeight)
    end
    if panel.resizeWidget2 then
        panel.resizeWidget2:setY(panel.height - resizeHeight)
        panel.resizeWidget2:setWidth(panel.width - resizeHeight)
    end
    if panel.searchEntryBox then
        panel.searchEntryBox:setY(titleHeight)
        panel.searchEntryBox:setWidth(sidebarWidth)
    end
    if panel.imageList then
        panel.imageList:setY(titleHeight + 20)
        panel.imageList:setWidth(sidebarWidth)
        panel.imageList:setHeight(math.max(100, panel.height - titleHeight - 20 - resizeHeight))
    end
    if panel.tilesList then
        panel.tilesList:setX(sidebarWidth)
        panel.tilesList:setY(titleHeight)
        panel.tilesList:setWidth(math.max(250, panel.width - sidebarWidth))
        panel.tilesList:setHeight(math.max(100, panel.height - titleHeight - resizeHeight))
    end
end

function ParadiseDev.Tiles.resizeBrushPanel(panel, width, height)
    panel:setWidth(math.max(width, panel.minimumWidth or 0))
    panel:setHeight(math.max(height, panel.minimumHeight or 0))
    ParadiseDev.Tiles.layoutBrushPanel(panel)
end

function ParadiseDev.Tiles.enableBrushResize(panel)
    panel.minimumWidth = 550
    panel.minimumHeight = 360
    panel:setResizable(true)
    if panel.resizeWidget then panel.resizeWidget.resizeFunction = ParadiseDev.Tiles.resizeBrushPanel end
    if panel.resizeWidget2 then panel.resizeWidget2.resizeFunction = ParadiseDev.Tiles.resizeBrushPanel end
    ParadiseDev.Tiles.layoutBrushPanel(panel)
end

function ParadiseDev.Tiles.openBrushTool()
    ParadiseDev.Tiles.installServerBrushCursor()
    local player = getPlayer and getPlayer() or nil
    if not player or not ParadiseDev.isAdm(player) then return end
    if BrushToolChooseTileUI and BrushToolChooseTileUI.openPanel then
        BrushToolChooseTileUI.openPanel(900, 20, player)
        local panel = BrushToolChooseTileUI.instance
        if panel then
            if not panel._paradiseBrushTool then
                panel:setWidth(1100)
                panel:setHeight(800)
                panel._paradiseBrushTool = true
            end
            ParadiseDev.Tiles.enableBrushResize(panel)
            panel.title = "Paradise Brush Tool"
            if panel.bringToTop then panel:bringToTop() end
        end
    end
end

function ParadiseDev.Tiles.installServerBrushCursor()
    if not ISBrushToolTileCursor or not ISBrushToolTileCursor.create then return end
    if ISBrushToolTileCursor.create == ParadiseDev.Tiles.serverBrushCreate then return end
    ParadiseDev.Tiles.originalBrushCreate = ISBrushToolTileCursor.create
    ParadiseDev.Tiles.serverBrushCreate = function(self, x, y, z, north, sprite)
        if isClient and isClient() then
            if sendClientCommand and self.character and type(sprite) == "string" then
                sendClientCommand(self.character, "ParadiseDevBrushTool", "place", { x = x, y = y, z = z, sprite = sprite })
            end
            return
        end
        return ParadiseDev.Tiles.originalBrushCreate(self, x, y, z, north, sprite)
    end
    ISBrushToolTileCursor.create = ParadiseDev.Tiles.serverBrushCreate
end

ParadiseDev.Tiles.installServerBrushCursor()


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

function ParadiseDev.Tiles.requestTileAction(command, obj, spriteName, pl)
    if not obj or not obj.getSquare then return end
    local square = obj:getSquare()
    if not square then return end
    spriteName = spriteName or ParadiseDev.Tiles.getObjectSpriteName(obj)
    local args = { x = square:getX(), y = square:getY(), z = square:getZ(), index = obj:getObjectIndex(), sprite = spriteName }
    if isClient and isClient() then
        if sendClientCommand then sendClientCommand(pl or getPlayer(), "ParadiseDevBrushTool", command, args) end
        return
    end
    if command == "replace" and spriteName and obj.setSpriteFromName then
        obj:setSpriteFromName(spriteName)
        if obj.transmitUpdatedSpriteToClients then obj:transmitUpdatedSpriteToClients() end
    elseif command == "destroy" and square.transmitRemoveItemFromSquare then
        square:transmitRemoveItemFromSquare(obj)
    elseif command == "moveable" and spriteName and pl then
        local item = pl:getInventory():AddItem("Moveables.Moveable")
        if item then item:ReadFromWorldSprite(spriteName) end
    end
end

function ParadiseDev.Tiles.copyProperties(obj)
    local sprite = obj and obj.getSprite and obj:getSprite() or nil
    local properties = sprite and sprite.getProperties and sprite:getProperties() or nil
    local names = properties and properties.getPropertyNames and properties:getPropertyNames() or nil
    if not names or not Clipboard or not Clipboard.setClipboard then return end
    local lines = {}
    for index = 0, names:size() - 1 do
        local name = names:get(index)
        table.insert(lines, tostring(name) .. "  " .. tostring(properties:Val(name)))
    end
    Clipboard.setClipboard(table.concat(lines, "\n"))
end

function ParadiseDev.Tiles.copyCoordinates(square, worldData)
    if not square or not Clipboard or not Clipboard.setClipboard then return end
    local x, y, z = math.floor(square:getX()), math.floor(square:getY()), math.floor(square:getZ())
    if not worldData then
        Clipboard.setClipboard(tostring(x) .. "  " .. tostring(y) .. "  " .. tostring(z))
        return
    end
    local cellX, cellY = math.floor(x / 300), math.floor(y / 300)
    Clipboard.setClipboard("CellX: " .. cellX .. " CellY: " .. cellY .. " RelX: " .. (x - cellX * 300) .. " RelY: " .. (y - cellY * 300) .. " WorldX: " .. x .. " WorldY: " .. y .. " Z: " .. z)
end

function ParadiseDev.Tiles.copyTile(obj, spriteName, pl)
    if not spriteName or tostring(spriteName) == "" then return end
    ParadiseDev.Tiles.installServerBrushCursor()
    spriteName = tostring(spriteName)
    ParadiseDev.Tiles.selectedSprite = spriteName
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
    if spriteName then
        ParadiseDev.Tiles.addCopyOption(menu, "[MAIN] " .. spriteName, obj, spriteName, pl)
        menu:addOption("Replace " .. spriteName, obj, ParadiseDev.Tiles.requestTileAction, "replace", ParadiseDev.Tiles.selectedSprite, pl)
        menu:addOption("Destroy " .. spriteName, obj, ParadiseDev.Tiles.requestTileAction, "destroy", nil, pl)
        menu:addOption("Get Moveable " .. spriteName, obj, ParadiseDev.Tiles.requestTileAction, "moveable", spriteName, pl)
        menu:addOption("Copy Properties " .. spriteName, obj, ParadiseDev.Tiles.copyProperties)
    end
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
    local root = context:addOptionOnTop("Tiles: " .. math.floor(sq:getX()) .. " " .. math.floor(sq:getY()))
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(root, menu)
    menu:addOption("Copy Coordinates", sq, ParadiseDev.Tiles.copyCoordinates, false)
    menu:addOption("Copy World Data", sq, ParadiseDev.Tiles.copyCoordinates, true)
    menu:addOption("Brush Tool", ParadiseDev.Tiles.openBrushTool)
    for index = 0, count - 1 do
        local okObj, obj = pcall(objects.get, objects, index)
        if okObj and obj then ParadiseDev.Tiles.addObjectOptions(menu, obj, pl) end
    end
end

--Events.OnFillWorldObjectContextMenu.Remove(ParadiseDev.Tiles.addContext)
Events.OnFillWorldObjectContextMenu.Add(ParadiseDev.Tiles.addContext)
