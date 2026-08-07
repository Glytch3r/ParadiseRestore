-- ParadiseZ's admin world-context tools for B42.20.
-- Each option only calls functionality that is already present in this dev build.
ParadiseZ = ParadiseZ or {}
ParadiseZ.soundDbg = ParadiseZ.soundDbg or false

local function isAdmin(player)
    return player and string.lower(tostring(player:getAccessLevel())) == "admin"
end

local function onOrOff(value)
    return value and "On" or "Off"
end

local function closeContext(context)
    if context and context.hideAndChildren then
        context:hideAndChildren()
    end
end

local function addOption(menu, label, callback, icon)
    local option = menu:addOption(label, nil, function()
        callback()
        closeContext(menu)
    end)
    if option and icon then
        option.iconTexture = getTexture(icon)
    end
    return option
end

function ParadiseZ.dbgSoundHandler(x, y, z, radius, volume, source)
    if not ParadiseZ.soundDbg then return end

    local player = getPlayer()
    if not player then return end
    local message = tostring(source)
        .. "\nx: " .. tostring(round(x)) .. " y: " .. tostring(round(y)) .. " z: " .. tostring(round(z))
        .. "\nradius: " .. tostring(radius)
        .. "\nvolume: " .. tostring(volume)
        .. "\ndistance: " .. tostring(round(player:DistTo(x, y)))
    player:setHaloNote(message, 111, 133, 232, 900)

    if source and source.getSquare then
        ParadiseZ.addTempMarker(source:getSquare())
    end
end

Events.OnWorldSound.Remove(ParadiseZ.dbgSoundHandler)
Events.OnWorldSound.Add(ParadiseZ.dbgSoundHandler)

function ParadiseZ.context(playerNum, context)
    local player = getSpecificPlayer(playerNum)
    if not player or not player:isAlive() or not isAdmin(player) then return end

    local main = context:addOptionOnTop("ParadiseZ")
    main.iconTexture = getTexture("media/ui/Paradise/ContextIcon.png")
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(main, menu)

    if ParadiseDev and ParadiseDev.Zones and ParadiseDev.Zones.openUI then
        addOption(menu, "Zone Editor Panel", ParadiseDev.Zones.openUI, "media/ui/Paradise/ZoneContextIcon.png")
    end
    if ParadiseDev and ParadiseDev.Zones and ParadiseDev.Zones.openTestRemote then
        addOption(menu, "Zone Test Control Remote", ParadiseDev.Zones.openTestRemote, "media/ui/Paradise/ZoneContextIcon.png")
    end
    if ParadiseDev and ParadiseDev.Cage and ParadiseDev.Cage.openPanel then
        addOption(menu, "Cage Administration", ParadiseDev.Cage.openPanel, "media/ui/Paradise/ContextIcon.png")
    end

    addOption(menu, "Audio Direction: " .. onOrOff(ParadiseZ.soundDbg), function()
        ParadiseZ.soundDbg = not ParadiseZ.soundDbg
    end, "media/ui/Paradise/LightContextIcon.png")

    if ParadiseZ.isTrailingLightMode and ParadiseZ.toggleTrailingLightMode then
        addOption(menu, "Trailing Light: " .. onOrOff(ParadiseZ.isTrailingLightMode(player)), function()
            ParadiseZ.toggleTrailingLightMode(player)
        end, "media/ui/Paradise/LightContextIcon.png")
    end

    if ParadiseZ.isHideAdminTag and ParadiseZ.toggleHideAdminTag then
        addOption(menu, "Hide Admin Tag: " .. onOrOff(ParadiseZ.isHideAdminTag(player)), function()
            ParadiseZ.toggleHideAdminTag(player)
        end, "media/ui/Paradise/AdmTagContextIcon.png")
    end

    if ParadiseDev and ParadiseDev.TP then
        addOption(menu, "Save Rebound Point", function()
            ParadiseDev.TP.saveRebound(player, "Admin Rebound")
        end, "media/ui/Paradise/ContextIcon.png")
        if ParadiseDev.TP.getRebound(player) then
            addOption(menu, "Force Rebound", function()
                ParadiseDev.TP.rebound(player)
            end, "media/ui/Paradise/ContextIcon.png")
        end
    end

    addOption(menu, "Spawn TheRange Membership Card", function()
        player:getInventory():AddItem("ParadiseZ.TheRangeCard")
    end, "media/textures/TheRange.png")

    addOption(menu, "NVG: " .. onOrOff(player:isWearingNightVisionGoggles()), function()
        player:setWearingNightVisionGoggles(not player:isWearingNightVisionGoggles())
    end, "media/ui/Paradise/NVGContextIcon.png")

    if ParadiseZ.lvlUp then
        addOption(menu, "Level Up", ParadiseZ.lvlUp, "media/ui/Paradise/LvlContextIcon.png")
    end
    if ParadiseZ.die then
        addOption(menu, "Suicide", ParadiseZ.die, "media/ui/Paradise/RIPContextIcon.png")
    end

    local zombieRoot = menu:addOption("Zombies")
    zombieRoot.iconTexture = getTexture("media/ui/Paradise/StopZedContextIcon.png")
    local zombieMenu = ISContextMenu:getNew(context)
    menu:addSubMenu(zombieRoot, zombieMenu)
    local radius = SandboxVars.ParadiseZ and SandboxVars.ParadiseZ.ClearRadius or 15

    addOption(zombieMenu, "Prevent Zombie Attacks: " .. onOrOff(player:isZombiesDontAttack()), function()
        player:setZombiesDontAttack(not player:isZombiesDontAttack())
    end, "media/ui/Paradise/StopZedContextIcon.png")
    addOption(zombieMenu, "Kill Zeds", function() ParadiseZ.killZeds(nil, nil, nil, radius) end, "media/ui/LootableMaps/map_cross.png")
    addOption(zombieMenu, "Count Dead", function() ParadiseZ.countDead(nil, nil, nil, radius) end, "media/ui/LootableMaps/map_question.png")
    addOption(zombieMenu, "Count Zeds", function() ParadiseZ.countZed(nil, nil, nil, radius) end, "media/ui/LootableMaps/map_skull.png")
    addOption(zombieMenu, "Delete Corpses", function() ParadiseZ.delBodies(nil, nil, nil, radius) end, "media/ui/LootableMaps/map_cross.png")
    addOption(zombieMenu, "Delete Zeds", function() ParadiseZ.delZeds(nil, nil, nil, radius) end, "media/ui/LootableMaps/map_facedead.png")

    local clearRoot = menu:addOption("Clear")
    clearRoot.iconTexture = getTexture("media/ui/Paradise/ClearContextIcon.png")
    local clearMenu = ISContextMenu:getNew(context)
    menu:addSubMenu(clearRoot, clearMenu)

    local confirmClear = {
        { label = "Clear Trees", fn = ParadiseZ.ClearTrees, icon = "media/ui/Paradise/TreesContextIcon.png" },
        { label = "Clear Plants", fn = ParadiseZ.DespawnPlants, icon = "media/ui/Paradise/PlantsContextIcon.png" },
        { label = "Clear Cars", fn = ParadiseZ.DespawnCars, icon = "media/ui/Paradise/CarsContextIcon.png" },
        { label = "Clear Fire", fn = ParadiseZ.StopFire, icon = "media/ui/Paradise/NoFireContextIcon.png" },
        { label = "Clear Floor Items", fn = ParadiseZ.ClearFloorItems2, icon = "media/ui/Paradise/NoItemsContextIcon.png" },
    }
    for _, entry in ipairs(confirmClear) do
        if entry.fn then
            addOption(clearMenu, entry.label, function()
                ParadiseZ.popup("ParadiseZ Clear", entry.label, entry.fn, "Clear")
            end, entry.icon)
        end
    end

    addOption(clearMenu, "Clean Character", ParadiseZ.washChar, "media/ui/Paradise/WashContextIcon.png")
    addOption(clearMenu, "Clear Map Record", ParadiseZ.ClearMap, "media/ui/Paradise/MapContextIcon.png")
    addOption(clearMenu, "Clear Weather", ParadiseZ.clearWeather, "media/ui/Paradise/WeatherContextIcon.png")
    addOption(clearMenu, "Clear Worn Items", ParadiseZ.ClearWornItems, "media/ui/Paradise/WornItemsContextIcon.png")
    addOption(clearMenu, "Clear Perks", ParadiseZ.ClearPerks, "media/ui/Paradise/MemoryContextIcon.png")
    addOption(clearMenu, "Clear Learned Recipes", ParadiseZ.ClearLearned, "media/ui/Paradise/LearnContextIcon.png")
end

Events.OnFillWorldObjectContextMenu.Remove(ParadiseZ.context)
Events.OnFillWorldObjectContextMenu.Add(ParadiseZ.context)
