ParadiseDev = ParadiseDev or {}
ParadiseDev.Safehouse = ParadiseDev.Safehouse or {}
ParadiseDev.Safehouse.residentialRooms = ParadiseDev.Safehouse.residentialRooms or {
    bathroom = true,
    bedroom = true,
    closet = true,
    fishingstorage = true,
    garage = true,
    hall = true,
    kidsbedroom = true,
    kitchen = true,
    laundry = true,
    livingroom = true,
    diningroom = true,
    sewingroom = true,
    office = true,
    emptyoutside = true,
    empty = true,
}

function ParadiseDev.Safehouse.getUsername(pl)
    if type(pl) == "string" then return pl end
    if not pl and getPlayer then pl = getPlayer() end
    if pl and pl.getUsername then return tostring(pl:getUsername()) end
    return nil
end

function ParadiseDev.Safehouse.getSquare(obj)
    if not obj then return nil end
    if obj.getCurrentSquare then return obj:getCurrentSquare() end
    if obj.getSquare then return obj:getSquare() end
    return obj
end

function ParadiseDev.Safehouse.getBuilding(obj)
    if obj and obj.getDef then return obj end
    local sq = ParadiseDev.Safehouse.getSquare(obj)
    if sq and sq.getBuilding then return sq:getBuilding() end
    return nil
end

function ParadiseDev.Safehouse.getRooms(obj)
    local building = ParadiseDev.Safehouse.getBuilding(obj)
    if not building then return nil end
    if building.getDef then
        local def = building:getDef()
        if def and def.getRooms then return def:getRooms() end
    end
    if building.getRooms then return building:getRooms() end
    return nil
end

function ParadiseDev.Safehouse.getRoomName(room)
    if room and room.getName then return string.lower(tostring(room:getName())) end
    return nil
end

function ParadiseDev.Safehouse.isResidential(obj)
    if not ParadiseDev.Safehouse.getBuilding(obj) then return false end
    local rooms = ParadiseDev.Safehouse.getRooms(obj)
    if not rooms or not rooms.size or not rooms.get then return false end
    local hasLivingSpace = false
    for index = 0, rooms:size() - 1 do
        local roomName = ParadiseDev.Safehouse.getRoomName(rooms:get(index))
        if not ParadiseDev.Safehouse.residentialRooms[roomName] then return false end
        if roomName == "bedroom" or roomName == "livingroom" then hasLivingSpace = true end
    end
    return hasLivingSpace
end

function ParadiseDev.Safehouse.isCommercial(obj)
    return ParadiseDev.Safehouse.getBuilding(obj) ~= nil and not ParadiseDev.Safehouse.isResidential(obj)
end

function ParadiseDev.Safehouse.getSafehouse(obj)
    if not SafeHouse or not SafeHouse.getSafeHouse then return nil end
    local sq = ParadiseDev.Safehouse.getSquare(obj)
    if not sq then return nil end
    return SafeHouse.getSafeHouse(sq)
end

function ParadiseDev.Safehouse.getOwner(obj)
    local safehouse = ParadiseDev.Safehouse.getSafehouse(obj)
    if safehouse and safehouse.getOwner then
        local user = safehouse:getOwner()
        if user then return tostring(user) end
    end
    return nil
end

function ParadiseDev.Safehouse.isOwnerOfSH(obj, pl)
    local user = ParadiseDev.Safehouse.getUsername(pl)
    local owner = ParadiseDev.Safehouse.getOwner(obj)
    return user and owner and owner == user or false
end

function ParadiseDev.Safehouse.isMemberOfSH(obj, pl)
    local user = ParadiseDev.Safehouse.getUsername(pl)
    local safehouse = ParadiseDev.Safehouse.getSafehouse(obj)
    if not user or not safehouse or not safehouse.getPlayers then return false end
    local players = safehouse:getPlayers()
    if not players then return false end
    if players.contains and players:contains(user) then return true end
    if not players.size or not players.get then return false end
    for index = 0, players:size() - 1 do
        if tostring(players:get(index)) == user then return true end
    end
    return false
end

function ParadiseDev.Safehouse.isPartOfSH(obj, pl)
    return ParadiseDev.Safehouse.isOwnerOfSH(obj, pl) or ParadiseDev.Safehouse.isMemberOfSH(obj, pl)
end

function ParadiseDev.Safehouse.hasSafehouse(pl)
    if not SafeHouse or not SafeHouse.hasSafehouse then return nil end
    local user = ParadiseDev.Safehouse.getUsername(pl)
    if not user then return nil end
    return SafeHouse.hasSafehouse(user)
end

function ParadiseDev.Safehouse.getOwnedSafehouse(pl)
    if not SafeHouse or not SafeHouse.getSafehouseByOwner then return nil end
    local user = ParadiseDev.Safehouse.getUsername(pl)
    if not user then return nil end
    return SafeHouse.getSafehouseByOwner(user)
end
