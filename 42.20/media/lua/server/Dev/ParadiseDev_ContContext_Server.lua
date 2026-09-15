ParadiseDev = ParadiseDev or {}
ParadiseDev.ContainerLoot = ParadiseDev.ContainerLoot or {}

local loot = ParadiseDev.ContainerLoot
loot.module = "ParadiseDevContainerLoot"
loot.dataName = "ParadiseDev_AutomaticContainerLoot"
loot.intervalHours = 1

local function validNumber(value)
    return type(value) == "number" and value == math.floor(value)
end

local function key(x, y, z)
    return tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z)
end

function loot.getData()
    local data = ModData.getOrCreate(loot.dataName)
    data.entries = data.entries or {}
    return data
end

function loot.findContainer(entry)
    local cell = getCell()
    local square = cell and cell:getGridSquare(entry.x, entry.y, entry.z) or nil
    if not square then return nil end
    local objects = square:getObjects()
    for index = 0, objects:size() - 1 do
        local object = objects:get(index)
        local container = object and object.getContainer and object:getContainer() or nil
        if container then return container end
    end
    return nil
end

function loot.fill(entry, container)
    if not container then return false end
    container:setType(entry.containerType)
    local items = container:getItems()
    if container:isExplored() and items and items:size() > 0 then return false end
    container:setExplored(false)
    container:setHasBeenLooted(false)
    ItemPickerJava.fillContainer(container, nil)
    container:setExplored(true)
    container:setHasBeenLooted(true)
    container:requestSync()
    return true
end

function loot.fillLoadedSquare(square)
    if not square then return end
    local data = loot.getData()
    local now = getGameTime():getWorldAgeHours()
    for id, entry in pairs(data.entries) do
        if id == key(square:getX(), square:getY(), square:getZ()) and (not entry.nextFill or now >= entry.nextFill) then
            local container = loot.findContainer(entry)
            if container and loot.fill(entry, container) then entry.nextFill = now + loot.intervalHours end
        end
    end
end

function loot.update()
    local data = loot.getData()
    local now = getGameTime():getWorldAgeHours()
    for _, entry in pairs(data.entries) do
        if entry.nextFill and now >= entry.nextFill then
            entry.due = true
        end
    end
end

function loot.onLoadGridSquare(square)
    loot.fillLoadedSquare(square)
end

function loot.register(player, args)
    if not player or not ParadiseDev.isAdm(player) or type(args) ~= "table" then return end
    if not validNumber(args.x) or not validNumber(args.y) or not validNumber(args.z) or type(args.containerType) ~= "string" then return end
    local data = loot.getData()
    local id = key(args.x, args.y, args.z)
    data.entries[id] = {
        x = args.x,
        y = args.y,
        z = args.z,
        containerType = args.containerType,
        nextFill = 0,
    }
    ModData.transmit(loot.dataName)
    local square = getCell():getGridSquare(args.x, args.y, args.z)
    if square then loot.fillLoadedSquare(square) end
end

function loot.forceRefill(player, args)
    if not player or not ParadiseDev.isAdm(player) or type(args) ~= "table" then return end
    if not validNumber(args.x) or not validNumber(args.y) or not validNumber(args.z) then return end
    local data = loot.getData()
    local entry = data.entries[key(args.x, args.y, args.z)]
    if not entry then return end
    local container = loot.findContainer(entry)
    if not container or not container.getType or type(container:getType()) ~= "string" or container:getType() == "" then return end
    container:setExplored(false)
    container:setHasBeenLooted(false)
    if loot.fill(entry, container) then
        entry.nextFill = getGameTime():getWorldAgeHours() + loot.intervalHours
        ModData.transmit(loot.dataName)
    end
end

function loot.onClientCommand(module, command, player, args)
    if module == loot.module and command == "register" then loot.register(player, args) end
    if module == loot.module and command == "forceRefill" then loot.forceRefill(player, args) end
end

function loot.onInitGlobalModData()
    loot.getData()
end

Events.OnInitGlobalModData.Add(loot.onInitGlobalModData)
Events.OnClientCommand.Remove(loot.onClientCommand)
Events.OnClientCommand.Add(loot.onClientCommand)
Events.LoadGridsquare.Remove(loot.onLoadGridSquare)
Events.LoadGridsquare.Add(loot.onLoadGridSquare)
Events.EveryHours.Remove(loot.update)
Events.EveryHours.Add(loot.update)
