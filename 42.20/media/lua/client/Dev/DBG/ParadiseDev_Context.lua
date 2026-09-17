ParadiseDev = ParadiseDev or {}
ParadiseDev.Context = ParadiseDev.Context or {}
ParadiseZ = ParadiseZ or {}
ParadiseZ.soundDbg = ParadiseZ.soundDbg or false

require "Dev/ParadiseDev_AdminPanels"
require "Dev/ParadiseDev_TargContext"
require "Dev/ParadiseDev_POI"
require "Dev/DBG/ParadiseDev_VisualDebug"
require "Dev/ParadiseDev_ZedController"
require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "RadioCom/ISUIRadio/ISSliderPanel"


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

function ParadiseDev.Context.setRateOfFireTestMode(mode)
    ParadiseZ.rateOfFireTestMode = mode
end

function ParadiseDev.Context.resetMapVisited()
    if WorldMapVisited and WorldMapVisited.Reset then WorldMapVisited.Reset() end
end

function ParadiseDev.Context.toggleTrailingLight(pl)
    if ParadiseZ.toggleTrailingLightMode then ParadiseZ.toggleTrailingLightMode(pl) end
end

function ParadiseDev.Context.toggleShowAdminTag(pl)
    if ParadiseZ.toggleShowAdminTag then ParadiseZ.toggleShowAdminTag(pl) end
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
    if not pl or not pl.setZombiesDontAttack or not pl.isZombiesDontAttack then return end
    pl:setZombiesDontAttack(not (pl:isZombiesDontAttack() == true))
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

function ParadiseDev.Context.clearScanned(pl, radius, predicate)
    local cell, sq = pl and pl:getCell(), pl and pl:getCurrentSquare()
    if not cell or not sq then return end
    local x, y, z, rad = sq:getX(), sq:getY(), sq:getZ(), math.floor(radius or 15)
    for dx = -rad, rad do for dy = -rad, rad do
        local target = cell:getGridSquare(x + dx, y + dy, z)
        local objects = target and target:getObjects()
        if objects then for i = objects:size() - 1, 0, -1 do
            local obj = objects:get(i)
            if obj and predicate(obj, target) then target:transmitRemoveItemFromSquare(obj) end
        end end
    end end
end

function ParadiseDev.Context.clearAnimals(pl, radius)
    ParadiseDev.Context.clearScanned(pl, radius, function(obj) return instanceof(obj, "IsoAnimal") end)
end

function ParadiseDev.Context.clearWorldObjects(pl, radius)
    ParadiseDev.Context.clearScanned(pl, radius, function(obj)
        return not instanceof(obj, "IsoFloor") and not instanceof(obj, "IsoTree") and not instanceof(obj, "IsoZombie") and not instanceof(obj, "IsoDeadBody") and not instanceof(obj, "IsoAnimal")
    end)
end

function ParadiseDev.Context.clearPuddles(pl, radius)
    if setPuddles then setPuddles(0) end
end

function ParadiseDev.Context.clearContainerItems(pl, radius)
    ParadiseDev.Context.clearScanned(pl, radius, function(obj)
        local container = obj.getContainer and obj:getContainer() or nil
        if not container then return false end
        local items = container:getItems()
        if items then for i = items:size() - 1, 0, -1 do container:DoRemoveItem(items:get(i)) end end
        return false
    end)
end

function ParadiseDev.Context.clearSelected(pl, radius, selected)
    pl = pl or getPlayer()
    if not pl or not selected then return end
    for _, entry in ipairs(selected) do
        local fn = ParadiseDev.Context.clearHandlers[entry.name]
        if fn then fn(pl, radius) end
    end
end

ParadiseDev.Context.clearHandlers = {
    floorItems = ParadiseZ.ClearFloorItems2,
    trees = ParadiseZ.ClearTrees,
    plants = ParadiseZ.DespawnPlants,
    cars = ParadiseZ.DespawnCars,
    corpses = function(_, radius) ParadiseZ.delBodies(nil, nil, nil, radius) end,
    zombies = function(_, radius) ParadiseZ.delZeds(nil, nil, nil, radius) end,
    fire = ParadiseZ.StopFire,
    animals = ParadiseDev.Context.clearAnimals,
    worldobjects = ParadiseDev.Context.clearWorldObjects,
    puddle = ParadiseDev.Context.clearPuddles,
    containerItems = ParadiseDev.Context.clearContainerItems,
}

function ParadiseDev.Context.clearAndSave(pl)
    if not pl or not ParadiseDev.Save or not sendClientCommand then return end
    sendClientCommand(ParadiseDev.Save.module, "clearAndSave", {})
end




function ParadiseDev.Context.getClearRadius()
    return SandboxVars.ParadiseZ and SandboxVars.ParadiseZ.ClearRadius or 15
end

ParadiseDev.Context.ClearPanel = ISCollapsableWindow:derive("ParadiseDev.Context.ClearPanel")

function ParadiseDev.Context.ClearPanel:new(pl)
    local width, height = 430, 360
    local panel = ISCollapsableWindow:new((getCore():getScreenWidth() - width) / 2, (getCore():getScreenHeight() - height) / 2, width, height)
    setmetatable(panel, self)
    self.__index = self
    panel.player = pl or getPlayer()
    panel.radius = ParadiseDev.Context.getClearRadius()
    panel.moveWithMouse = true
    panel:setTitle("Paradise Clear Panel")
    return panel
end

function ParadiseDev.Context.ClearPanel:createChildren()
    ISCollapsableWindow.createChildren(self)
    local entries = ParadiseDev.Context.clearOptions
    self.checks = {}
    local title = ISLabel:new(16, 42, 20, "Select what to clear:", 1, 1, 1, 1, UIFont.Medium, true)
    title:initialise(); title:instantiate(); self:addChild(title)
    for index, entry in ipairs(entries) do
        local y = 72 + (index - 1) * 30
        local button = ISButton:new(16, y, 260, 25, entry.label, self, ParadiseDev.Context.ClearPanel.onToggle)
        button:initialise(); button:instantiate(); button.entry = entry; button.checkMark = false; self:addChild(button)
        self.checks[#self.checks + 1] = button
    end
    local radiusY = 72 + #entries * 30 + 8
    self.radiusLabel = ISLabel:new(16, radiusY, 20, "Radius: " .. tostring(self.radius), 1, 1, 1, 1, UIFont.Small, true)
    self.radiusLabel:initialise(); self.radiusLabel:instantiate(); self:addChild(self.radiusLabel)
    self.radiusSlider = ISSliderPanel:new(16, radiusY + 24, 390, 20, self, ParadiseDev.Context.ClearPanel.onRadiusChanged)
    self.radiusSlider:initialise(); self.radiusSlider:instantiate(); self.radiusSlider:setValues(1, 50, 1, 5, true); self.radiusSlider:setCurrentValue(self.radius, true); self:addChild(self.radiusSlider)
    local clear = ISButton:new(16, radiusY + 58, 185, 28, "Clear Selected", self, ParadiseDev.Context.ClearPanel.onClear)
    clear:initialise(); clear:instantiate(); self:addChild(clear)
    local close = ISButton:new(220, radiusY + 58, 185, 28, "Close", self, ParadiseDev.Context.ClearPanel.onClose)
    close:initialise(); close:instantiate(); self:addChild(close)
end

function ParadiseDev.Context.ClearPanel:onToggle(button)
    button.checkMark = not (button.checkMark == true)
end

function ParadiseDev.Context.ClearPanel:onRadiusChanged(value)
    self.radius = math.floor(tonumber(value) or self.radius or 15)
    if self.radiusLabel then self.radiusLabel:setName("Radius: " .. tostring(self.radius)) end
end

function ParadiseDev.Context.ClearPanel:onClear()
    local selected = {}
    for _, button in ipairs(self.checks or {}) do
        if button.checkMark == true and ParadiseDev.Context.clearHandlers[button.entry.name] then selected[#selected + 1] = button.entry end
    end
    if #selected == 0 then return end
    local radius = self.radius
    self:onClose()
    ParadiseZ.popup("ParadiseZ Clear", "Clear " .. tostring(#selected) .. " selected item types in radius " .. tostring(radius) .. "?", function(pl)
        ParadiseDev.Context.clearSelected(pl, radius, selected)
    end, "Clear")
end

function ParadiseDev.Context.ClearPanel:onClose()
    self:removeFromUIManager()
    if ParadiseDev.Context.clearPanel == self then ParadiseDev.Context.clearPanel = nil end
end

function ParadiseDev.Context.openClearPanel(pl)
    if ParadiseDev.Context.clearPanel then ParadiseDev.Context.clearPanel:onClose() end
    local panel = ParadiseDev.Context.ClearPanel:new(pl or getPlayer())
    panel:initialise(); panel:addToUIManager()
    ParadiseDev.Context.clearPanel = panel
end

ParadiseDev.Context.clearOptions = {
    { label = "Floor Items", name = "floorItems" },
    { label = "Trees", name = "trees" },
    { label = "Plants", name = "plants" },
    { label = "Cars", name = "cars" },
    { label = "Corpses", name = "corpses" },
    { label = "Zombies", name = "zombies" },
    { label = "Animals", name = "animals" },
    { label = "Fire", name = "fire" },
    { label = "Worldobjects", name = "worldobjects" },
    { label = "Puddle", name = "puddle" },
    { label = "Container Items", name = "containerItems" },
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

function ParadiseDev.Context.context(plNum, context, worldobjects)
    local pl = getSpecificPlayer(plNum)
    if not pl or not pl:isAlive() or not ParadiseDev.isAdm(pl) then return end
    local main = context:addOptionOnTop("ParadiseZ")
    main.iconTexture = getTexture("media/ui/Paradise/ContextIcon.png")
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(main, menu)

    if ParadiseDev.SkillRecovery and ParadiseDev.SkillRecovery.addParadiseOptions then
        ParadiseDev.SkillRecovery.addParadiseOptions(menu, pl, worldobjects)
    end

    local panelsRoot = menu:addOption("Panels")
    panelsRoot.iconTexture = getTexture("media/ui/Paradise/ContextIcon.png")
    local panelsMenu = ISContextMenu:getNew(context)
    menu:addSubMenu(panelsRoot, panelsMenu)
    if ParadiseDev.Zones and ParadiseDev.Zones.openUI then ParadiseDev.Context.addOption(panelsMenu, "Zone Editor", ParadiseDev.Zones.openUI, "media/ui/Paradise/ZoneContextIcon.png") end
    if ParadiseDev.Cage and ParadiseDev.Cage.openPanel then ParadiseDev.Context.addOption(panelsMenu, "Cage Administration", ParadiseDev.Cage.openPanel, "media/ui/Paradise/ContextIcon.png") end
    if ParadiseDev.ZedController and ParadiseDev.ZedController.open then ParadiseDev.Context.addOption(panelsMenu, "Paradise Zed Control", ParadiseDev.ZedController.open, "media/ui/Paradise/StopZedContextIcon.png") end
    if ParadiseDev.Panels then
            ParadiseDev.Context.addOption(panelsMenu, "WaveCaster", ParadiseDev.Panels.openWaveCaster, "media/ui/Paradise/ContextIcon.png")
            ParadiseDev.Context.addOption(panelsMenu, "Media Spawner", ParadiseDev.Panels.openMediaSpawner, "media/ui/Paradise/ContextIcon.png")
--[[ 
            if ParadiseDev.Tiles and ParadiseDev.Tiles.openBrushTool then ParadiseDev.Context.addOption(panelsMenu, "Brush Tool", ParadiseDev.Tiles.openBrushTool, "media/ui/Paradise/ContextIcon.png") end
            ParadiseDev.Context.addOption(panelsMenu, "Promo Manager", function() 
                ParadisePromo.openAdminPanel()
            end, "media/ui/Paradise/ContextIcon.png")
]]
            ParadiseDev.Context.addOption(panelsMenu, "Mini Scoreboard", function() 
                if ISMiniScoreboardUI.instance then
                    ISMiniScoreboardUI.instance:close()
                end
                local ui = ISMiniScoreboardUI:new(50,50,300,300, getPlayer());
                ui:initialise();
                ui:addToUIManager();
            end, "media/ui/Paradise/ContextIcon.png")
            ParadiseDev.Context.addOption(panelsMenu, "Users List", ParadiseDev.Panels.openUsersList, "media/ui/Paradise/ContextIcon.png")
            ParadiseDev.Context.addOption(panelsMenu, "Global ModData", ParadiseDev.Panels.openGlobalModData, "media/ui/Paradise/ContextIcon.png")
            if ParadisePOI and ParadisePOI.openPanel then ParadiseDev.Context.addOption(panelsMenu, "POI Manager", ParadisePOI.openPanel, "media/ui/Paradise/ContextIcon.png") end
            ParadiseDev.Context.addOption(panelsMenu, "Mod Active Check", ParadiseDev.Panels.openModActiveCheck, "media/ui/Paradise/ContextIcon.png")
            ParadiseDev.Context.addOption(panelsMenu, "Paradise Playtime Checker", ParadiseDev.Panels.openPlaytimeCheck, "media/ui/Paradise/ContextIcon.png")
        if getCore():getDebug() then
            ParadiseDev.Context.addOption(panelsMenu, "AnimMonitor", ParadiseDev.Panels.ISAnimDebugMonitor, "media/ui/Paradise/ContextIcon.png")
        end
    end
    if ParadiseDev.Zones and ParadiseDev.Zones.openTestRemote then ParadiseDev.Context.addOption(panelsMenu, "Zone Test Control", ParadiseDev.Zones.openTestRemote, "media/ui/Paradise/ZoneContextIcon.png") end

    ParadiseDev.Context.addOption(menu, "Audio Direction: " .. ParadiseDev.Context.onOrOff(ParadiseZ.soundDbg), ParadiseDev.Context.toggleSound, "media/ui/Paradise/LightContextIcon.png")
    if ParadiseZ.isTrailingLightMode and ParadiseZ.toggleTrailingLightMode then ParadiseDev.Context.addOption(menu, "Trailing Light: " .. ParadiseDev.Context.onOrOff(ParadiseZ.isTrailingLightMode(pl)), ParadiseDev.Context.toggleTrailingLight, "media/ui/Paradise/LightContextIcon.png", pl) end
    local adminTagOption = ParadiseDev.Context.addOption(menu, "Show Admin Tag", ParadiseDev.Context.toggleShowAdminTag, "media/ui/Paradise/AdmTagContextIcon.png", pl)
    if adminTagOption then adminTagOption.checkMark = ParadiseZ.isShowAdminTag(pl) end

    if ParadiseDev.TP then
        ParadiseDev.Context.addOption(menu, "Save Rebound Point", ParadiseDev.Context.saveRebound, "media/ui/Paradise/ContextIcon.png", pl)
        if ParadiseDev.TP.getRebound(pl) then ParadiseDev.Context.addOption(menu, "Force Rebound", ParadiseDev.Context.forceRebound, "media/ui/Paradise/ContextIcon.png", pl) end
    end

    ParadiseDev.Context.addOption(menu, "GunAmmos", function() ParadiseDev.Context.reloadGuns() end, "media/ui/LootableMaps/map_bullets.png", pl)

    ParadiseDev.Context.addOption(menu, "Goldgun", function() sendClientCommand("ParadiseDevSkin", "spawnGoldgun", {}) end, "media/ui/LootableMaps/map_bullets.png", pl)

    local rateOfFireRoot = menu:addOption("Rate of Fire Test")
    rateOfFireRoot.iconTexture = getTexture("media/ui/LootableMaps/map_bullets.png")
    local rateOfFireMenu = ISContextMenu:getNew(context)
    menu:addSubMenu(rateOfFireRoot, rateOfFireMenu)
    ParadiseDev.Context.addOption(rateOfFireMenu, "RPS (rounds per sec)", ParadiseDev.Context.setRateOfFireTestMode, "media/ui/LootableMaps/map_bullets.png", "RPS")
    ParadiseDev.Context.addOption(rateOfFireMenu, "RPM (rounds per min)", ParadiseDev.Context.setRateOfFireTestMode, "media/ui/LootableMaps/map_bullets.png", "RPM")
    ParadiseDev.Context.addOption(rateOfFireMenu, "Disable", ParadiseDev.Context.setRateOfFireTestMode, "media/ui/LootableMaps/map_bullets.png", "Disable")



    if ParadiseDev.Visual then
        local visualRoot = menu:addOption("Visual Tests")
        visualRoot.iconTexture = getTexture("media/ui/Paradise/ContextIcon.png")
        local visualMenu = ISContextMenu:getNew(context)
        menu:addSubMenu(visualRoot, visualMenu)
        ParadiseDev.Context.addOption(visualMenu, "Hide Worn Visuals", ParadiseDev.Visual.hide, "media/ui/Paradise/ContextIcon.png", pl)
        ParadiseDev.Context.addOption(visualMenu, "Restore Worn Visuals", ParadiseDev.Visual.replace, "media/ui/Paradise/ContextIcon.png", pl)
        ParadiseDev.Context.addOption(visualMenu, "Test Firearm Model: Handgun03", ParadiseDev.Visual.testWeaponSprite, "media/ui/LootableMaps/map_bullets.png", pl)
        ParadiseDev.Context.addOption(visualMenu, "Restore Firearm Model", ParadiseDev.Visual.resetWeaponSprite, "media/ui/LootableMaps/map_bullets.png", pl)
    end

    ParadiseDev.Context.addOption(menu, "Spawn TheRange Membership Card", ParadiseDev.Context.spawnRangeCard, "media/textures/TheRange.png", pl)
    local nvgOption = ParadiseDev.Context.addOption(menu, "NVG", ParadiseDev.Context.toggleNightVision, "media/ui/Paradise/NVGContextIcon.png", pl)
    if nvgOption then nvgOption.checkMark = pl:isWearingNightVisionGoggles() end
    if ParadiseZ.lvlUp then ParadiseDev.Context.addOption(menu, "Level Up", ParadiseZ.lvlUp, "media/ui/Paradise/LvlContextIcon.png") end
    if ParadiseZ.die then ParadiseDev.Context.addOption(menu, "Suicide", ParadiseZ.die, "media/ui/Paradise/RIPContextIcon.png") end





    local zombieRoot = menu:addOption("Zombies")
    zombieRoot.iconTexture = getTexture("media/ui/Paradise/StopZedContextIcon.png")
    local zombieMenu = ISContextMenu:getNew(context)
    menu:addSubMenu(zombieRoot, zombieMenu)
    local zombieAttackOption = ParadiseDev.Context.addOption(zombieMenu, "Prevent Zombie Attacks", ParadiseDev.Context.toggleZombieAttacks, "media/ui/Paradise/StopZedContextIcon.png", pl)
    if zombieAttackOption then zombieAttackOption.checkMark = pl:isZombiesDontAttack() == true end
    ParadiseDev.Context.addOption(zombieMenu, "Kill Zeds", ParadiseDev.Context.killZeds, "media/ui/LootableMaps/map_cross.png")
    ParadiseDev.Context.addOption(zombieMenu, "Count Dead", ParadiseDev.Context.countDead, "media/ui/LootableMaps/map_question.png")
    ParadiseDev.Context.addOption(zombieMenu, "Count Zeds", ParadiseDev.Context.countZeds, "media/ui/LootableMaps/map_skull.png")

    local clearRoot = menu:addOption("Clear")
    clearRoot.iconTexture = getTexture("media/ui/Paradise/ClearContextIcon.png")
    local clearMenu = ISContextMenu:getNew(context)
    menu:addSubMenu(clearRoot, clearMenu)
    ParadiseDev.Context.addOption(clearMenu, "OpenClearPanel", ParadiseDev.Context.openClearPanel, "media/ui/Paradise/ClearContextIcon.png", pl)
    ParadiseDev.Context.addOption(clearMenu, "Clear Vehicle", ParadiseZ.DespawnCar, "media/ui/Paradise/CarsContextIcon.png", pl)
    ParadiseDev.Context.addOption(clearMenu, "Clean Character", ParadiseZ.washChar, "media/ui/Paradise/WashContextIcon.png")
    ParadiseDev.Context.addOption(clearMenu, "Clear Map Record", ParadiseZ.ClearMap, "media/ui/Paradise/MapContextIcon.png")
    ParadiseDev.Context.addOption(clearMenu, "Clear WorldMapVisited", ParadiseDev.Context.resetMapVisited, "media/ui/Paradise/MapContextIcon.png")
    ParadiseDev.Context.addOption(clearMenu, "Clear Weather", ParadiseZ.clearWeather, "media/ui/Paradise/WeatherContextIcon.png")
    ParadiseDev.Context.addOption(clearMenu, "Clear Fog", ParadiseZ.clearFog, "media/ui/Paradise/WeatherContextIcon.png")
    ParadiseDev.Context.addOption(clearMenu, "Clear Worn Items", ParadiseZ.ClearWornItems, "media/ui/Paradise/WornItemsContextIcon.png")
    ParadiseDev.Context.addOption(clearMenu, "Clear Traits", ParadiseZ.ClearTraits, "media/ui/Paradise/TraitsContextIcon.png")
    ParadiseDev.Context.addOption(clearMenu, "Clear Perks", ParadiseZ.ClearPerks, "media/ui/Paradise/MemoryContextIcon.png")
    ParadiseDev.Context.addOption(clearMenu, "Clear Learned", ParadiseZ.ClearLearned, "media/ui/Paradise/LearnContextIcon.png")
    ParadiseDev.Context.addOption(clearMenu, "Clear and Save", ParadiseDev.Context.clearAndSave, "media/ui/Paradise/ClearContextIcon.png", pl)
end

ParadiseZ.dbgSoundHandler = ParadiseDev.Context.dbgSoundHandler
ParadiseZ.context = ParadiseDev.Context.context

Events.OnWorldSound.Remove(ParadiseDev.Context.dbgSoundHandler)
Events.OnWorldSound.Add(ParadiseDev.Context.dbgSoundHandler)
Events.OnFillWorldObjectContextMenu.Remove(ParadiseDev.Context.context)
Events.OnFillWorldObjectContextMenu.Add(ParadiseDev.Context.context)

function ParadiseDev.Context.reloadGuns()
    local pl = getPlayer()
    if not pl or not (isClient and isClient()) then return end
    sendClientCommand("ParadiseDevSkin", "reloadGuns", {})
end
