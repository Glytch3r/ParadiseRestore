if isClient and isClient() then return end

ParadiseDev = ParadiseDev or {}
ParadiseDev.BrushTool = ParadiseDev.BrushTool or {}

local brush = ParadiseDev.BrushTool
brush.module = "ParadiseDevBrushTool"
brush.maxDistance = 100

function brush.normalizeRequest(args)
    if type(args) ~= "table" or type(args.sprite) ~= "string" or #args.sprite == 0 or #args.sprite > 128 then return nil end
    local x, y, z = tonumber(args.x), tonumber(args.y), tonumber(args.z)
    if not x or not y or not z or x ~= math.floor(x) or y ~= math.floor(y) or z ~= math.floor(z) or z < 0 then return nil end
    return { x = x, y = y, z = z, sprite = args.sprite }
end

function brush.isNearPlayer(player, request)
    if not player or not player.getX or not player.getY then return false end
    local dx, dy = player:getX() - request.x, player:getY() - request.y
    return dx * dx + dy * dy <= brush.maxDistance * brush.maxDistance
end

function brush.hasSprite(square, spriteName)
    local objects = square and square:getObjects() or nil
    if not objects then return false end
    for index = 0, objects:size() - 1 do
        local object = objects:get(index)
        local sprite = object and object:getSprite() or nil
        if sprite and sprite:getName() == spriteName then return true end
    end
    return false
end

function brush.place(player, request)
    if not ParadiseDev.isAdm(player) or not brush.isNearPlayer(player, request) then return false end
    local square = getCell():getGridSquare(request.x, request.y, request.z)
    if not square or brush.hasSprite(square, request.sprite) then return false end
    local source = IsoObject.new(square, request.sprite)
    local sprite = source and source:getSprite() or nil
    if not sprite then return false end
    local props = ISMoveableSpriteProps.new(sprite)
    local item = instanceItem("Base.Plank")
    if not props or not item then return false end
    props.rawWeight = 10
    local ok = pcall(props.placeMoveableInternal, props, square, item, request.sprite)
    return ok
end

function brush.onClientCommand(module, command, player, args)
    if module ~= brush.module or not ParadiseDev.isAdm(player) then return end
    if command == "place" then
        local request = brush.normalizeRequest(args)
        if request then brush.place(player, request) end
        return
    end
    if command ~= "replace" and command ~= "destroy" and command ~= "moveable" then return end
    local request = brush.normalizeRequest(args)
    local index = args and tonumber(args.index) or nil
    if not request or not index or index ~= math.floor(index) or not brush.isNearPlayer(player, request) then return end
    local square = getCell():getGridSquare(request.x, request.y, request.z)
    if not square or index < 0 or index >= square:getObjects():size() then return end
    local object = square and square:getObjects():get(index) or nil
    if not object then return end
    if command == "replace" then
        if object.setSpriteFromName then object:setSpriteFromName(request.sprite) end
        if object.transmitUpdatedSpriteToClients then object:transmitUpdatedSpriteToClients() end
    elseif command == "destroy" then
        square:transmitRemoveItemFromSquare(object)
    else
        local item = player:getInventory():AddItem("Moveables.Moveable")
        if item then
            item:ReadFromWorldSprite(request.sprite)
            sendAddItemToContainer(player:getInventory(), item)
        end
    end
end

Events.OnClientCommand.Remove(brush.onClientCommand)
Events.OnClientCommand.Add(brush.onClientCommand)
