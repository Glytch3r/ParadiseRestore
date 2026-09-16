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
    contContext.registerLoot(container, square, container and container:getType() or nil)
end

function contContext.registerLoot(container, square, lootType)
    if not container or not square or not sendClientCommand then return end
    sendClientCommand(contContext.module, "register", {
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
        containerType = container:getType(),
        lootType = lootType,
    })
end

function contContext.forceRefill(container, square, lootType)
    if not container or not square or not sendClientCommand then return end
    sendClientCommand(contContext.module, "forceRefill", {
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
        lootType = lootType,
    })
end

function contContext.getLootTypes()
    local result = {}
    local seen = {}
    local containers = ItemPickerJava and ItemPickerJava.getItemPickerContainers and ItemPickerJava.getItemPickerContainers() or nil
    if containers then
        for name in pairs(containers) do
            if type(name) == "string" and not seen[name] then
                seen[name] = true
                result[#result + 1] = name
            end
        end
    end
    if #result == 0 then
        result = {
            "CrateTools",
            "CrateMetalwork",
            "CrateFishing",
            "CrateFarming",
            "CrateLumber",
            "StoreCounterTobacco",
            "StoreCounterMisc",
            "DrugLab",
            "MedicalStorage",
        }
    end
    table.sort(result)
    return result
end

function contContext.forceRefillWithType(container, square, lootType)
    contContext.forceRefill(container, square, lootType)
end

function contContext.addLootOptions(menu, container, square)
    local lootRoot = menu:addOption("Loot Spawn Type")
    local lootMenu = ISContextMenu:getNew(menu)
    menu:addSubMenu(lootRoot, lootMenu)
    local types = contContext.getLootTypes()
    for _, lootType in ipairs(types) do
        local typeRoot = lootMenu:addOption(lootType)
        local typeMenu = ISContextMenu:getNew(lootMenu)
        lootMenu:addSubMenu(typeRoot, typeMenu)
        local register = typeMenu:addOption("Enable Automatic Spawn", nil, contContext.registerLoot, container, square, lootType)
        local refill = typeMenu:addOption("Force Refill Now", nil, contContext.forceRefillWithType, container, square, lootType)
        if register then register.iconTexture = getTexture("media/ui/Paradise/ContextIcon.png") end
        if refill then refill.iconTexture = getTexture("media/ui/Paradise/ContextIcon.png") end
    end
    return lootRoot
end

function contContext.addWorldContext(plNum, context, worldobjects, test)
    if test or not context or not ParadiseDev.isAdm() then return end
    local container, square = contContext.getContainer(worldobjects)
    if not container then return end
    local root = context:addOption("Container Loot")
    root.iconTexture = getTexture("media/ui/Paradise/ContextIcon.png")
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(root, menu)
    contContext.addLootOptions(menu, container, square)
end

Events.OnFillWorldObjectContextMenu.Remove(contContext.addWorldContext)
Events.OnFillWorldObjectContextMenu.Add(contContext.addWorldContext)
