DiscoballRemover = DiscoballRemover or {}

require "BuildingObjects/ISBuildingObject"

DiscoballRemover.rgbKeys = {
    "DiscoBallRGBLight", "DiscoBallRGBLight2", "DiscoBallRGBLight3", "DiscoBallRGBLight4",
    "DiscoBallRGBLight5", "DiscoBallRGBLight6", "DiscoBallRGBLight7", "DiscoBallRGBLight8",
    "DiscoBallRGBLightA1", "DiscoBallRGBLightA2", "DiscoBallRGBLightA3", "DiscoBallRGBLightA4",
    "DiscoBallRGBLightA5", "DiscoBallRGBLightA6", "DiscoBallRGBLightA7", "DiscoBallRGBLightA8",
}

function DiscoballRemover.customName(obj)
    local spr = obj:getSprite()
    local props = spr and spr:getProperties()
    if not props then return nil end
    return props:get("CustomName")
end

function DiscoballRemover.isHelper(obj)
    local nm = obj:getName()
    if nm == "DiscoLight1" or nm == "DiscoLight2" or nm == "DiscoLight3" or nm == "DiscoLight4" then
        return true
    end
    local spr = obj:getSprite()
    local sprName = spr and spr:getName()
    if sprName and luautils.stringStarts(sprName, "LS_Discoball_") and sprName ~= "LS_Discoball_0" then
        return true
    end
    return false
end

function DiscoballRemover.isBall(obj)
    local nm = obj:getName()
    if nm and nm:lower() == "ls_discoball" then return true end
    local spr = obj:getSprite()
    if spr then
        if spr:getName() == "LS_Discoball_0" then return true end
        local props = spr:getProperties()
        if props and props:propertyEquals("CustomName", "Disco Ball") then
            return true
        end
    end
    return false
end

function DiscoballRemover.cleanLights(ball)
    if not ball or not ball:hasModData() then return end
    local md = ball:getModData()
    local cell = ball:getCell()
    md.OnOff = "off"
    if md.BallMainLight then
        cell:removeLamppost(md.BallMainLight)
        md.BallMainLight = nil
    end
    for i = 1, #DiscoballRemover.rgbKeys do
        local key = DiscoballRemover.rgbKeys[i]
        if md[key] then
            cell:removeLamppost(md[key])
            md[key] = nil
        end
    end
    ball:transmitModData()
end

function DiscoballRemover.removeObject(sq, obj)
    if not sq or not obj then return false end
    if DiscoballRemover.isBall(obj) then
        DiscoballRemover.cleanLights(obj)
        if isClient() then
            sledgeDestroy(obj)
            sq:transmitRemoveItemFromSquare(obj)
        else
            sq:transmitRemoveItemFromSquare(obj)
        end
        return true
    end
    if DiscoballRemover.isHelper(obj) then
        sq:transmitRemoveItemFromSquare(obj)
        return true
    end
    return false
end

function DiscoballRemover.hasDisco(sq)
    if not sq then return false end
    local objs = sq:getObjects()
    if not objs then return false end
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        if DiscoballRemover.isBall(obj) or DiscoballRemover.isHelper(obj) then
            return true
        end
    end
    return false
end

function DiscoballRemover.dump(sq)
    print("[DiscoballRemover] square " .. sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ() ..
        " solid=" .. tostring(sq:isSolid()) ..
        " solidTrans=" .. tostring(sq:isSolidTrans()) ..
        " free=" .. tostring(sq:isFree(false)))
    local objs = sq:getObjects()
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        local kind = instanceof(obj, "IsoThumpable") and "Thumpable" or "Object"
        local spr = obj:getSprite()
        local sprName = spr and spr:getName() or "<no sprite>"
        print(string.format("[DiscoballRemover]   #%d %s name=%s sprite=%s solid=%s solidTrans=%s custom=%s floor=%s",
            i, kind, tostring(obj:getName()), tostring(sprName),
            tostring(obj:hasProperty(IsoFlagType.solid)), tostring(obj:hasProperty(IsoFlagType.solidtrans)),
            tostring(DiscoballRemover.customName(obj)), tostring(obj:isFloor())))
    end
end

function DiscoballRemover.clean(x, y, z)
    local sq = getCell():getGridSquare(x, y, z)
    if not sq then
        print("[DiscoballRemover] no square at " .. x .. "," .. y .. "," .. z)
        return
    end
    print("[DiscoballRemover] === BEFORE ===")
    DiscoballRemover.dump(sq)

    local objs = sq:getObjects()
    local helpers = {}
    local ball = nil
    for i = objs:size() - 1, 0, -1 do
        local obj = objs:get(i)
        if DiscoballRemover.isHelper(obj) then
            helpers[#helpers + 1] = obj
        elseif DiscoballRemover.isBall(obj) then
            ball = obj
        end
    end

    for i = 1, #helpers do
        sq:RemoveTileObject(helpers[i])
        print("[DiscoballRemover] removed helper " .. tostring(helpers[i]:getName()))
    end

    if ball then
        DiscoballRemover.cleanLights(ball)
        if isClient() then
            sledgeDestroy(ball)
            print("[DiscoballRemover] sledgeDestroy ball (server-synced): " .. tostring(ball:getName()))
        else
            sq:transmitRemoveItemFromSquare(ball)
            print("[DiscoballRemover] removed ball (singleplayer): " .. tostring(ball:getName()))
        end
    else
        print("[DiscoballRemover] no disco ball object on this square client-side")
    end

    sq:RecalcAllWithNeighbours(true)
    print("[DiscoballRemover] === AFTER ===")
    DiscoballRemover.dump(sq)
    if sq:isSolid() or sq:isSolidTrans() then
        print("[DiscoballRemover] square STILL solid client-side - another object above is the blocker")
    else
        print("[DiscoballRemover] square is free client-side. If you still cannot walk here, the server holds a leftover ball: relog (or walk far away and back) to resync the square, then run DiscoballRemover.start() again.")
    end
end

DiscoballRemover.Cursor = ISBuildingObject:derive("DiscoballRemoverCursor")

function DiscoballRemover.Cursor:new(pl)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o:init()
    o.character = pl
    o.player = pl:getPlayerNum()
    o.skipBuildAction = true
    o.skipWalk = true
    o.renderFloorHelper = true
    o.dragNilAfterPlace = true
    o.renderX = -1
    o.renderY = -1
    o.renderZ = -1
    return o
end

function DiscoballRemover.Cursor:isValid(sq)
    self.renderX = sq:getX()
    self.renderY = sq:getY()
    self.renderZ = sq:getZ()
    return true
end

function DiscoballRemover.Cursor:walkTo(x, y, z)
    return true
end

function DiscoballRemover.Cursor:render(x, y, z, sq)
    self:getFloorCursorSprite():RenderGhostTileColor(x, y, z, 0.2, 0.8, 0.2, 0.6)
end

function DiscoballRemover.Cursor:create(x, y, z, north, spr)
    DiscoballRemover.clean(x, y, z)
end

function DiscoballRemover.start(pl)
    pl = pl or getPlayer()
    if not pl then
        print("[DiscoballRemover] no local player")
        return
    end
    getCell():setDrag(DiscoballRemover.Cursor:new(pl), pl:getPlayerNum())
    print("[DiscoballRemover] cursor active - left-click the blocked square")
end

function DiscoballRemover.stripLights(ball)
    if not ball or not ball:hasModData() then return end
    local md = ball:getModData()
    local cell = ball:getCell()
    if not cell then return end
    if md.BallMainLight then
        cell:removeLamppost(md.BallMainLight)
        md.BallMainLight = nil
    end
    for i = 1, #DiscoballRemover.rgbKeys do
        local key = DiscoballRemover.rgbKeys[i]
        if md[key] then
            cell:removeLamppost(md[key])
            md[key] = nil
        end
    end
end

function DiscoballRemover.onDestroy(thumpable, playerObj)
    if not thumpable or not DiscoballRemover.isBall(thumpable) then return end
    local sq = thumpable:getSquare()
    if not sq then return end
    DiscoballRemover.stripLights(thumpable)
    local objs = sq:getObjects()
    for i = objs:size() - 1, 0, -1 do
        local obj = objs:get(i)
        if obj ~= thumpable and DiscoballRemover.isHelper(obj) then
            sq:RemoveTileObject(obj)
        end
    end
    sq:RecalcAllWithNeighbours(true)
    print("[DiscoballRemover] swept disco leftovers on destroy at " .. sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ())
end
Events.OnDestroyIsoThumpable.Remove(DiscoballRemover.onDestroy)
Events.OnDestroyIsoThumpable.Add(DiscoballRemover.onDestroy)