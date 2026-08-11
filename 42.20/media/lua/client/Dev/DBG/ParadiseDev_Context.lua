ParadiseDev = ParadiseDev or {}
ParadiseDev.Context = ParadiseDev.Context or {}
ParadiseZ = ParadiseZ or {}
ParadiseZ.soundDbg = ParadiseZ.soundDbg or false


function ParadiseDev.Context.onOrOff(value)
    return value and "On" or "Off"
end

function ParadiseDev.Context.close(context)
    if context and context.hideAndChildren then context:hideAndChildren() end
end

function ParadiseDev.Context.runOption(callback, context, pl)
    if callback then callback(pl) end
    ParadiseDev.Context.close(context)
end

function ParadiseDev.Context.addOption(menu, label, callback, icon, pl)
    local option = menu:addOption(label, callback, ParadiseDev.Context.runOption, menu, pl)
    if option and icon then option.iconTexture = getTexture(icon) end
    return option
end

function ParadiseDev.Context.dbgSoundHandler(x, y, z, radius, volume, source)
    if not ParadiseZ.soundDbg then return end
    local pl = getPlayer()
    if not pl then return end
    local message = tostring(source)
        .. "\nx: " .. tostring(round(x)) .. " y: " .. tostring(round(y)) .. " z: " .. tostring(round(z))
        .. "\nradius: " .. tostring(radius)
        .. "\nvolume: " .. tostring(volume)
        .. "\ndistance: " .. tostring(round(pl:DistTo(x, y)))
    pl:setHaloNote(message, 111, 133, 232, 900)
    if source and source.getSquare then ParadiseZ.addTempMarker(source:getSquare()) end
end

function ParadiseDev.Context.toggleSound()
    ParadiseZ.soundDbg = not ParadiseZ.soundDbg
end

function ParadiseDev.Context.resetMapVisited()
    if WorldMapVisited and WorldMapVisited.Reset then WorldMapVisited.Reset() end
end

function ParadiseDev.Context.toggleTrailingLight(pl)
    if ParadiseZ.toggleTrailingLightMode then ParadiseZ.toggleTrailingLightMode(pl) end
end

function ParadiseDev.Context.toggleHideAdminTag(pl)
    if ParadiseZ.toggleHideAdminTag then ParadiseZ.toggleHideAdminTag(pl) end
end

function ParadiseDev.Context.saveRebound(pl)
    if ParadiseDev.TP then ParadiseDev.TP.saveRebound(pl, "Admin Rebound") end
end

function ParadiseDev.Context.forceRebound(pl)
    if ParadiseDev.TP then ParadiseDev.TP.rebound(pl) end
end

function ParadiseDev.Context.spawnRangeCard(pl)
    if not pl or not ParadiseDev.Inventory or not ParadiseDev.Inventory.syncAddedItem then return end
    local inventory = pl:getInventory()
    local item = inventory and inventory:AddItem("ParadiseZ.TheRangeCard")
    ParadiseDev.Inventory.syncAddedItem(inventory, item)
end

function ParadiseDev.Context.toggleNightVision(pl)
    if pl then pl:setWearingNightVisionGoggles(not pl:isWearingNightVisionGoggles()) end
end

function ParadiseDev.Context.toggleZombieAttacks(pl)
    if pl then pl:setZombiesDontAttack(not pl:isZombiesDontAttack()) end
end

function ParadiseDev.Context.killZeds()
    ParadiseZ.killZeds(nil, nil, nil, ParadiseDev.Context.getClearRadius())
end

function ParadiseDev.Context.countDead()
    ParadiseZ.countDead(nil, nil, nil, ParadiseDev.Context.getClearRadius())
end

function ParadiseDev.Context.countZeds()
    ParadiseZ.countZed(nil, nil, nil, ParadiseDev.Context.getClearRadius())
end

function ParadiseDev.Context.deleteCorpses()
    ParadiseZ.delBodies(nil, nil, nil, ParadiseDev.Context.getClearRadius())
end

function ParadiseDev.Context.deleteZeds()
    ParadiseZ.delZeds(nil, nil, nil, ParadiseDev.Context.getClearRadius())
end

function ParadiseDev.Context.getClearRadius()
    return SandboxVars.ParadiseZ and SandboxVars.ParadiseZ.ClearRadius or 15
end

ParadiseDev.Context.clearOptions = {
    { label = "Clear Trees", name = "ClearTrees", icon = "media/ui/Paradise/TreesContextIcon.png" },
    { label = "Clear Plants", name = "DespawnPlants", icon = "media/ui/Paradise/PlantsContextIcon.png" },
    { label = "Clear Cars", name = "DespawnCars", icon = "media/ui/Paradise/CarsContextIcon.png" },
    { label = "Clear Fire", name = "StopFire", icon = "media/ui/Paradise/NoFireContextIcon.png" },
    { label = "Clear Floor Items", name = "ClearFloorItems2", icon = "media/ui/Paradise/NoItemsContextIcon.png" },
}

function ParadiseDev.Context.confirmClear(entry, context)
    if entry and ParadiseZ[entry.name] then ParadiseZ.popup("ParadiseZ Clear", entry.label, ParadiseZ[entry.name], "Clear") end
    ParadiseDev.Context.close(context)
end

function ParadiseDev.Context.addClearOption(menu, entry, context)
    if not entry or not ParadiseZ[entry.name] then return end
    local option = menu:addOption(entry.label, entry, ParadiseDev.Context.confirmClear, context)
    if option then option.iconTexture = getTexture(entry.icon) end
end

function ParadiseDev.Context.context(plNum, context)
    local pl = getSpecificPlayer(plNum)
    if not pl or not pl:isAlive() or not ParadiseDev.isAdm(pl) then return end
    local main = context:addOptionOnTop("ParadiseZ")
    main.iconTexture = getTexture("media/ui/Paradise/ContextIcon.png")
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(main, menu)

    if ParadiseDev.Zones and ParadiseDev.Zones.openUI then ParadiseDev.Context.addOption(menu, "Zone Editor Panel", ParadiseDev.Zones.openUI, "media/ui/Paradise/ZoneContextIcon.png") end
    if ParadiseDev.Zones and ParadiseDev.Zones.openTestRemote then ParadiseDev.Context.addOption(menu, "Zone Test Control Remote", ParadiseDev.Zones.openTestRemote, "media/ui/Paradise/ZoneContextIcon.png") end
    if ParadiseDev.Cage and ParadiseDev.Cage.openPanel then ParadiseDev.Context.addOption(menu, "Cage Administration", ParadiseDev.Cage.openPanel, "media/ui/Paradise/ContextIcon.png") end

    ParadiseDev.Context.addOption(menu, "Audio Direction: " .. ParadiseDev.Context.onOrOff(ParadiseZ.soundDbg), ParadiseDev.Context.toggleSound, "media/ui/Paradise/LightContextIcon.png")
    if ParadiseZ.isTrailingLightMode and ParadiseZ.toggleTrailingLightMode then ParadiseDev.Context.addOption(menu, "Trailing Light: " .. ParadiseDev.Context.onOrOff(ParadiseZ.isTrailingLightMode(pl)), ParadiseDev.Context.toggleTrailingLight, "media/ui/Paradise/LightContextIcon.png", pl) end
    if ParadiseZ.isHideAdminTag and ParadiseZ.toggleHideAdminTag then ParadiseDev.Context.addOption(menu, "Hide Admin Tag: " .. ParadiseDev.Context.onOrOff(ParadiseZ.isHideAdminTag(pl)), ParadiseDev.Context.toggleHideAdminTag, "media/ui/Paradise/AdmTagContextIcon.png", pl) end

    if ParadiseDev.TP then
        ParadiseDev.Context.addOption(menu, "Save Rebound Point", ParadiseDev.Context.saveRebound, "media/ui/Paradise/ContextIcon.png", pl)
        if ParadiseDev.TP.getRebound(pl) then ParadiseDev.Context.addOption(menu, "Force Rebound", ParadiseDev.Context.forceRebound, "media/ui/Paradise/ContextIcon.png", pl) end
    end

    ParadiseDev.Context.addOption(menu, "Spawn TheRange Membership Card", ParadiseDev.Context.spawnRangeCard, "media/textures/TheRange.png", pl)
    ParadiseDev.Context.addOption(menu, "NVG: " .. ParadiseDev.Context.onOrOff(pl:isWearingNightVisionGoggles()), ParadiseDev.Context.toggleNightVision, "media/ui/Paradise/NVGContextIcon.png", pl)
    if ParadiseZ.lvlUp then ParadiseDev.Context.addOption(menu, "Level Up", ParadiseZ.lvlUp, "media/ui/Paradise/LvlContextIcon.png") end
    if ParadiseZ.die then ParadiseDev.Context.addOption(menu, "Suicide", ParadiseZ.die, "media/ui/Paradise/RIPContextIcon.png") end

    local zombieRoot = menu:addOption("Zombies")
    zombieRoot.iconTexture = getTexture("media/ui/Paradise/StopZedContextIcon.png")
    local zombieMenu = ISContextMenu:getNew(context)
    menu:addSubMenu(zombieRoot, zombieMenu)
    ParadiseDev.Context.addOption(zombieMenu, "Prevent Zombie Attacks: " .. ParadiseDev.Context.onOrOff(pl:isZombiesDontAttack()), ParadiseDev.Context.toggleZombieAttacks, "media/ui/Paradise/StopZedContextIcon.png", pl)
    ParadiseDev.Context.addOption(zombieMenu, "Kill Zeds", ParadiseDev.Context.killZeds, "media/ui/LootableMaps/map_cross.png")
    ParadiseDev.Context.addOption(zombieMenu, "Count Dead", ParadiseDev.Context.countDead, "media/ui/LootableMaps/map_question.png")
    ParadiseDev.Context.addOption(zombieMenu, "Count Zeds", ParadiseDev.Context.countZeds, "media/ui/LootableMaps/map_skull.png")
    ParadiseDev.Context.addOption(zombieMenu, "Delete Corpses", ParadiseDev.Context.deleteCorpses, "media/ui/LootableMaps/map_cross.png")
    ParadiseDev.Context.addOption(zombieMenu, "Delete Zeds", ParadiseDev.Context.deleteZeds, "media/ui/LootableMaps/map_facedead.png")

    local clearRoot = menu:addOption("Clear")
    clearRoot.iconTexture = getTexture("media/ui/Paradise/ClearContextIcon.png")
    local clearMenu = ISContextMenu:getNew(context)
    menu:addSubMenu(clearRoot, clearMenu)
    for _, entry in ipairs(ParadiseDev.Context.clearOptions) do ParadiseDev.Context.addClearOption(clearMenu, entry, context) end
    ParadiseDev.Context.addOption(clearMenu, "Clean Character", ParadiseZ.washChar, "media/ui/Paradise/WashContextIcon.png")
    ParadiseDev.Context.addOption(clearMenu, "Clear Map Record", ParadiseZ.ClearMap, "media/ui/Paradise/MapContextIcon.png")
    ParadiseDev.Context.addOption(clearMenu, "WorldMapVisited.Reset", ParadiseDev.Context.resetMapVisited, "media/ui/Paradise/MapContextIcon.png")
    ParadiseDev.Context.addOption(clearMenu, "Clear Weather", ParadiseZ.clearWeather, "media/ui/Paradise/WeatherContextIcon.png")
    ParadiseDev.Context.addOption(clearMenu, "Clear Worn Items", ParadiseZ.ClearWornItems, "media/ui/Paradise/WornItemsContextIcon.png")
    ParadiseDev.Context.addOption(clearMenu, "Clear Perks", ParadiseZ.ClearPerks, "media/ui/Paradise/MemoryContextIcon.png")
    ParadiseDev.Context.addOption(clearMenu, "Clear Learned Recipes", ParadiseZ.ClearLearned, "media/ui/Paradise/LearnContextIcon.png")
end

ParadiseZ.dbgSoundHandler = ParadiseDev.Context.dbgSoundHandler
ParadiseZ.context = ParadiseDev.Context.context

Events.OnWorldSound.Remove(ParadiseDev.Context.dbgSoundHandler)
Events.OnWorldSound.Add(ParadiseDev.Context.dbgSoundHandler)
Events.OnFillWorldObjectContextMenu.Remove(ParadiseDev.Context.context)
Events.OnFillWorldObjectContextMenu.Add(ParadiseDev.Context.context)
