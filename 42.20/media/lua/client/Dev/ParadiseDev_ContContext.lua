ParadiseDev = ParadiseDev or {}
ParadiseDev.ContContext = ParadiseDev.ContContext or {}

local contContext = ParadiseDev.ContContext
contContext.module = "ParadiseDevContainerLoot"

function contContext.getContainer(worldobjects)
    local square = ParadiseDev.TargContext and ParadiseDev.TargContext.getSquare(worldobjects) or nil
    if not square then return nil end
    local objects = square:getObjects()
    for index = 0, objects:size() - 1 do
        local object = objects:get(index)
        local container = object and object.getContainer and object:getContainer() or nil
        if container then return container, square end
    end
    return nil, square
end

function contContext.register(container, square)
    if not container or not square or not sendClientCommand then return end
    sendClientCommand(contContext.module, "register", {
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
        containerType = container:getType(),
    })
end

function contContext.forceRefill(container, square)
    if not container or not square or not sendClientCommand then return end
    sendClientCommand(contContext.module, "forceRefill", {
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
    })
end

function contContext.addWorldContext(plNum, context, worldobjects, test)
    if test or not context or not ParadiseDev.isAdm() then return end
    local container, square = contContext.getContainer(worldobjects)
    if not container then return end
    local option = context:addOption("Enable Automatic Container Loot", nil, contContext.register, container, square)
    if option then option.iconTexture = getTexture("media/ui/Paradise/ContextIcon.png") end
    local canForceRefill = square and container.getType and type(container:getType()) == "string" and container:getType() ~= ""
    local refill = context:addOption("Force Container Refill Now", nil, contContext.forceRefill, container, square)
    refill.notAvailable = not canForceRefill
    if refill then refill.iconTexture = getTexture("media/ui/Paradise/ContextIcon.png") end
end

Events.OnFillWorldObjectContextMenu.Remove(contContext.addWorldContext)
Events.OnFillWorldObjectContextMenu.Add(contContext.addWorldContext)
