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
require "ISUI/ISTickBox"
require "RadioCom/ISUIRadio/ISSliderPanel"

function ParadiseDev.Context.onOrOff(value)
    return value and "On" or "Off"
end

function ParadiseDev.Context.close(context)
    if context and context.hideAndChildren then
        context:hideAndChildren()
    end
end

function ParadiseDev.Context.runOption(callback, context, pl)
    if callback then
        callback(pl)
    end
    ParadiseDev.Context.close(context)
end

function ParadiseDev.Context.addOption(menu, label, callback, icon, pl)
    local option = menu:addOption(label, callback, ParadiseDev.Context.runOption, menu, pl)
    if option and icon then
        option.iconTexture = getTexture(icon)
    end
    return option
end

function ParadiseDev.Context.dbgSoundHandler(x, y, z, radius, volume, source)
    if not ParadiseZ.soundDbg then
        return
    end
    local pl = getPlayer()
    if not pl then
        return
    end
    local message =
        tostring(source) ..
        "\nx: " ..
            tostring(round(x)) ..
                " y: " ..
                    tostring(round(y)) ..
                        " z: " ..
                            tostring(round(z)) ..
                                "\nradius: " ..
                                    tostring(radius) ..
                                        "\nvolume: " ..
                                            tostring(volume) .. "\ndistance: " .. tostring(round(pl:DistTo(x, y)))
    pl:setHaloNote(message, 111, 133, 232, 900)
    if source and source.getSquare then
        ParadiseZ.addTempMarker(source:getSquare())
    end
end

function ParadiseDev.Context.toggleSound()
    ParadiseZ.soundDbg = not ParadiseZ.soundDbg
end

function ParadiseDev.Context.setRateOfFireTestMode(mode)
    ParadiseZ.rateOfFireTestMode = mode
end

function ParadiseDev.Context.resetMapVisited()
    if WorldMapVisited and WorldMapVisited.Reset then
        WorldMapVisited.Reset()
    end
end

function ParadiseDev.Context.toggleTrailingLight(pl)
    if ParadiseZ.toggleTrailingLightMode then
        ParadiseZ.toggleTrailingLightMode(pl)
    end
end

function ParadiseDev.Context.toggleShowAdminTag(pl)
    if not pl or not ParadiseRestore or not ParadiseRestore.isAdm or not ParadiseRestore.isAdm(pl) then return end
    if pl.getAccessLevel and string.lower(tostring(pl:getAccessLevel())) == "admin" then
        networkUserAction("SetRole", pl:getUsername(), "Officers")
        networkUserAction("SetAccessLevel", pl:getUsername(), "none")
    end
    if ParadiseZ.toggleShowAdminTag then
        ParadiseZ.toggleShowAdminTag(pl)
    end
end

function ParadiseDev.Context.saveRebound(pl)
    if ParadiseDev.TP then
        ParadiseDev.TP.saveRebound(pl, "Admin Rebound")
    end
end

function ParadiseDev.Context.forceRebound(pl)
    if ParadiseDev.TP then
        ParadiseDev.TP.rebound(pl)
    end
end

function ParadiseDev.Context.spawnRangeCard(pl)
    if not pl or not ParadiseDev.Inventory or not ParadiseDev.Inventory.syncAddedItem then
        return
    end
    local inventory = pl:getInventory()
    local item = inventory and inventory:AddItem("ParadiseZ.TheRangeCard")
    ParadiseDev.Inventory.syncAddedItem(inventory, item)
end

function ParadiseDev.Context.toggleNightVision(pl)
    if pl then
        pl:setWearingNightVisionGoggles(not pl:isWearingNightVisionGoggles())
    end
end

function ParadiseDev.Context.toggleZombieAttacks(pl)
    if not pl or not pl.setZombiesDontAttack or not pl.isZombiesDontAttack then
        return
    end
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

function ParadiseDev.Context.clearUniversal(pl, radius, selected)
    if not pl or not selected then
        return
    end
    local cell, center = pl:getCell(), pl:getCurrentSquare()
    if not cell or not center then
        return
    end
    local wanted = {}
    for _, name in ipairs(selected) do
        wanted[name] = true
    end
    local x, y, z, rad = math.floor(center:getX()), math.floor(center:getY()), math.floor(center:getZ()), math.floor(radius or 15)
    if wanted.animals then
        local animals = cell:getObjectListForLua()
        local foundAnimal = false
        if animals then
            for i = animals:size(), 1, -1 do
                local animal = animals:get(i - 1)
                if instanceof(animal, "IsoAnimal") and math.abs(animal:getX() - x) <= rad and math.abs(animal:getY() - y) <= rad and math.floor(animal:getZ()) == z then
                    foundAnimal = true
                    if not isClient() then animal:remove() end
                end
            end
        end
        if foundAnimal and isClient() and DebugContextMenu and DebugContextMenu.OnRemoveAllAnimalsClient then
            DebugContextMenu.OnRemoveAllAnimalsClient()
        end
    end
    if wanted.zombies then
        local removeRadius = rad + 1
        if isClient() then
            if DebugContextMenu and DebugContextMenu.OnRemoveAllZombiesClient then
                DebugContextMenu.OnRemoveAllZombiesClient()
            else
                SendCommandToServer(string.format("/removezombies -x %d -y %d -z %d -radius %d", x, y, z, removeRadius))
            end
        else
            for sx = x - removeRadius, x + removeRadius do
                for sy = y - removeRadius, y + removeRadius do
                    local target = cell:getGridSquare(sx, sy, z)
                    if target then
                        local moving = target:getMovingObjects()
                        for i = moving:size(), 1, -1 do
                            local zed = moving:get(i - 1)
                            if instanceof(zed, "IsoZombie") then
                                zed:removeFromWorld()
                                zed:removeFromSquare()
                            end
                        end
                    end
                end
            end
        end
    end
    for dx = -rad, rad do
        for dy = -rad, rad do
            local sq = cell:getGridSquare(x + dx, y + dy, z)
            if sq then
                if wanted.puddle and sq.getPuddlesInGround and sq:getPuddlesInGround() > 0 and sq.setPuddles then
                    sq:setPuddles(0)
                end
                if wanted.fire and sq:Is(IsoFlagType.burning) then
                    sq:transmitStopFire()
                    sq:stopFire()
                end
                local objects = sq:getObjects()
                if objects then
                    for i = objects:size() - 1, 0, -1 do
                        local obj = objects:get(i)
                        local remove = false
                        local isFloor = obj == sq:getFloor()
                        if wanted.floorItems and instanceof(obj, "IsoWorldInventoryObject") then
                            remove = true
                        end
                        if wanted.trees and instanceof(obj, "IsoTree") then
                            remove = true
                        end
                        if wanted.animals and instanceof(obj, "IsoAnimal") then
                            remove = true
                        end
                        if wanted.corpses and instanceof(obj, "IsoDeadBody") and not obj:isPlayer() then
                            remove = true
                        end
                        if wanted.plants and not instanceof(obj, "IsoTree") then
                            local sprite, props = obj:getSprite(), obj:getProperties()
                            if props and (props:has(IsoFlagType.canBeCut) or props:has(IsoFlagType.canBeRemoved)) then
                                remove = true
                            end
                        end
                        if
                            wanted.worldobjects and not isFloor and not instanceof(obj, "IsoFloor") and
                                not instanceof(obj, "IsoTree") and
                                not instanceof(obj, "IsoZombie") and
                                not instanceof(obj, "IsoDeadBody") and
                                not instanceof(obj, "IsoAnimal") and
                                not instanceof(obj, "IsoWorldInventoryObject")
                         then
                            remove = true
                        end
                        if wanted.containerItems and obj.getContainer then
                            local container = obj:getContainer()
                            local items = container and container:getItems()
                            if items then
                                for n = items:size() - 1, 0, -1 do
                                    container:DoRemoveItem(items:get(n))
                                end
                            end
                        end
                        if remove then
                            sq:transmitRemoveItemFromSquare(obj)
                        end
                    end
                end
                if wanted.cars and sq.getVehicles then
                    local vehicles = sq:getVehicles()
                    if vehicles then
                        for i = vehicles:size() - 1, 0, -1 do
                            local car = vehicles:get(i)
                            if car and car.permanentlyRemove then
                                car:permanentlyRemove()
                            end
                        end
                    end
                end
            end
        end
    end
end

function ParadiseDev.Context.toggleWorldZoneVisuals(pl)
    if not pl or not ParadiseDev.Zones or not ParadiseDev.Zones.Visualization then return end
    local visualization = ParadiseDev.Zones.Visualization
    visualization.setPlayerEnabled(pl, not visualization.isEnabledForPlayer(pl))
end

function ParadiseDev.Context.clearHighlight()
    for _, floor in pairs(ParadiseDev.Context.highlightedFloors or {}) do
        if floor then
            floor:setHighlighted(false, false)
        end
    end
    ParadiseDev.Context.highlightedFloors = {}
end

function ParadiseDev.Context.updateClearHighlight()
    local panel = ParadiseDev.Context.clearPanel
    if not panel or not panel.highlightEnabled then
        ParadiseDev.Context.clearHighlight()
        return
    end
    local pl, cell = panel.player or getPlayer(), panel.player and panel.player:getCell()
    local center = pl and pl:getCurrentSquare()
    if not cell or not center then
        return
    end
    ParadiseDev.Context.clearHighlight()
    local x, y, z, rad = center:getX(), center:getY(), center:getZ(), panel.radius or 15
    for dx = -rad, rad do
        for dy = -rad, rad do
            local sq = cell:getGridSquare(x + dx, y + dy, z)
            local floor = sq and sq:getFloor()
            if floor then
                floor:setHighlightColor(1, 1, 0, 0.75)
                floor:setHighlighted(true, false)
                ParadiseDev.Context.highlightedFloors[tostring(x + dx) .. ":" .. tostring(y + dy) .. ":" .. tostring(z)] =
                    floor
            end
        end
    end
end

function ParadiseDev.Context.onClearHighlightUpdate()
    ParadiseDev.Context.updateClearHighlight()
end

function ParadiseDev.Context.clearAndSave(pl)
    if not pl or not ParadiseDev.Save or not sendClientCommand then
        return
    end
    sendClientCommand(ParadiseDev.Save.module, "clearAndSave", {})
end

function ParadiseDev.Context.getClearRadius()
    return SandboxVars.ParadiseZ and SandboxVars.ParadiseZ.ClearRadius or 15
end

ParadiseDev.Context.ClearPanel = ISCollapsableWindow:derive("ParadiseDev.Context.ClearPanel")
ParadiseDev.Context.clearPanelState =
    ParadiseDev.Context.clearPanelState or {radius = nil, selected = {}, highlightEnabled = true}
if ParadiseDev.Context.clearPanelState.highlightEnabled == nil then
    ParadiseDev.Context.clearPanelState.highlightEnabled = true
end

function ParadiseDev.Context.ClearPanel:new(pl)
    local width, height = 360, 560
    local panel =
        ISCollapsableWindow:new(
        (getCore():getScreenWidth() - width) / 2,
        (getCore():getScreenHeight() - height) / 2,
        width,
        height
    )
    setmetatable(panel, self)
    self.__index = self
    panel.player = pl or getPlayer()
    local state = ParadiseDev.Context.clearPanelState
    panel.radius = state.radius or ParadiseDev.Context.getClearRadius()
    panel.highlightEnabled = state.highlightEnabled == true
    panel.moveWithMouse = true
    panel:setTitle("Paradise Clear Panel")
    return panel
end

function ParadiseDev.Context.ClearPanel:createChildren()
    ISCollapsableWindow.createChildren(self)
    local entries = ParadiseDev.Context.clearOptions
    local state = ParadiseDev.Context.clearPanelState
    self.checks = {}
    local title = ISLabel:new(16, 42, 20, "Select what to clear:", 1, 1, 1, 1, UIFont.Medium, true)
    title:initialise()
    title:instantiate()
    self:addChild(title)
    for index, entry in ipairs(entries) do
        local y = 72 + (index - 1) * 30
        local box = ISTickBox:new(16, y, 300, 25, "", self, ParadiseDev.Context.ClearPanel.onToggle)
        box:initialise()
        box:instantiate()
        box:addOption(entry.label)
        box.entry = entry
        box.selected[1] = state.selected[entry.name] == true
        self:addChild(box)
        self.checks[#self.checks + 1] = box
    end
    local radiusY = 72 + #entries * 30 + 8
    local highlight = ISTickBox:new(16, radiusY, 300, 25, "", self, ParadiseDev.Context.ClearPanel.onHighlightToggle)
    highlight:initialise()
    highlight:instantiate()
    highlight:addOption("Highlight Radius")
    highlight.selected[1] = self.highlightEnabled
    self:addChild(highlight)
    self.highlightBox = highlight
    radiusY = radiusY + 30
    self.radiusLabel = ISLabel:new(16, radiusY, 20, "Radius: " .. tostring(self.radius), 1, 1, 1, 1, UIFont.Small, true)
    self.radiusLabel:initialise()
    self.radiusLabel:instantiate()
    self:addChild(self.radiusLabel)
    self.radiusSlider =
        ISSliderPanel:new(16, radiusY + 24, 260, 20, self, ParadiseDev.Context.ClearPanel.onRadiusChanged)
    self.radiusSlider:initialise()
    self.radiusSlider:instantiate()
    self.radiusSlider:setValues(1, 50, 1, 5, true)
    self.radiusSlider:setCurrentValue(self.radius, true)
    self:addChild(self.radiusSlider)
    local clear =
        ISButton:new(16, radiusY + 58, 130, 28, "Clear Selected", self, ParadiseDev.Context.ClearPanel.onClear)
    clear:initialise()
    clear:instantiate()
    self:addChild(clear)
    local close = ISButton:new(160, radiusY + 58, 130, 28, "Close", self, ParadiseDev.Context.ClearPanel.onClose)
    close:initialise()
    close:instantiate()
    self:addChild(close)
end

function ParadiseDev.Context.ClearPanel:onToggle(index, selected)
    local box = self.checks and self.checks[index]
    if box and box.entry then
        ParadiseDev.Context.clearPanelState.selected[box.entry.name] = selected == true
    end
end

function ParadiseDev.Context.ClearPanel:onRadiusChanged(value)
    self.radius = math.floor(tonumber(value) or self.radius or 15)
    ParadiseDev.Context.clearPanelState.radius = self.radius
    if self.radiusLabel then
        self.radiusLabel:setName("Radius: " .. tostring(self.radius))
    end
end

function ParadiseDev.Context.ClearPanel:onHighlightToggle()
    self.highlightEnabled = self.highlightBox.selected[1] == true
    ParadiseDev.Context.clearPanelState.highlightEnabled = self.highlightEnabled
    if self.highlightEnabled then
        Events.OnPlayerUpdate.Remove(ParadiseDev.Context.onClearHighlightUpdate)
        Events.OnPlayerUpdate.Add(ParadiseDev.Context.onClearHighlightUpdate)
        ParadiseDev.Context.updateClearHighlight()
    else
        Events.OnPlayerUpdate.Remove(ParadiseDev.Context.onClearHighlightUpdate)
        ParadiseDev.Context.clearHighlight()
    end
end

function ParadiseDev.Context.ClearPanel:onClear()
    local selected = {}
    for _, button in ipairs(self.checks or {}) do
        if button.selected[1] == true then
            selected[#selected + 1] = button.entry.name
        end
    end
    if #selected == 0 then
        return
    end
    for _, button in ipairs(self.checks or {}) do
        ParadiseDev.Context.clearPanelState.selected[button.entry.name] = button.selected[1] == true
    end
    ParadiseDev.Context.clearPanelState.radius = self.radius
    ParadiseDev.Context.clearUniversal(self.player or getPlayer(), self.radius, selected)
end

function ParadiseDev.Context.ClearPanel:close()
    self:onClose()
end

function ParadiseDev.Context.ClearPanel:onClose()
    Events.OnPlayerUpdate.Remove(ParadiseDev.Context.onClearHighlightUpdate)
    ParadiseDev.Context.clearHighlight()
    self:removeFromUIManager()
    if ParadiseDev.Context.clearPanel == self then
        ParadiseDev.Context.clearPanel = nil
    end
end

function ParadiseDev.Context.openClearPanel(pl)
    if ParadiseDev.Context.clearPanel then
        ParadiseDev.Context.clearPanel:onClose()
    end
    local panel = ParadiseDev.Context.ClearPanel:new(pl or getPlayer())
    panel:initialise()
    panel:addToUIManager()
    ParadiseDev.Context.clearPanel = panel
    if panel.highlightEnabled then
        Events.OnPlayerUpdate.Remove(ParadiseDev.Context.onClearHighlightUpdate)
        Events.OnPlayerUpdate.Add(ParadiseDev.Context.onClearHighlightUpdate)
        ParadiseDev.Context.updateClearHighlight()
    end
end

ParadiseDev.Context.clearOptions = {
    {label = "Floor Items", name = "floorItems"},
    {label = "Trees", name = "trees"},
    {label = "Plants", name = "plants"},
    {label = "Cars", name = "cars"},
    {label = "Corpses", name = "corpses"},
    {label = "Zombies", name = "zombies"},
    {label = "Animals", name = "animals"},
    {label = "Fire", name = "fire"},
    {label = "Worldobjects", name = "worldobjects"},
    {label = "Puddle", name = "puddle"},
    {label = "Container Items", name = "containerItems"}
}

function ParadiseDev.Context.confirmClear(entry, context)
    if entry and ParadiseZ[entry.name] then
        ParadiseZ.popup("ParadiseZ Clear", entry.label, ParadiseZ[entry.name], "Clear")
    end
    ParadiseDev.Context.close(context)
end

function ParadiseDev.Context.addClearOption(menu, entry, context)
    if not entry or not ParadiseZ[entry.name] then
        return
    end
    local option = menu:addOption(entry.label, entry, ParadiseDev.Context.confirmClear, context)
    if option then
        option.iconTexture = getTexture(entry.icon)
    end
end

function ParadiseDev.Context.context(plNum, context, worldobjects)
    local pl = getSpecificPlayer(plNum)
    if not pl or not pl:isAlive() or not ParadiseDev.isAdm(pl) then
        return
    end
    local main = context:addOptionOnTop("ParadiseZ")
    main.iconTexture = getTexture("media/ui/Paradise/ContextIcon.png")
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(main, menu)

    if ParadiseDev.Zones and ParadiseDev.Zones.Visualization then
        local zoneVisuals = menu:addOption(
            (ParadiseDev.Zones.Visualization.isEnabledForPlayer(pl) and "Hide Zone Draw" or "Show Zone Draw"),
            ParadiseDev.Context.toggleWorldZoneVisuals,
            ParadiseDev.Context.runOption,
            menu,
            pl
        )
        zoneVisuals.iconTexture = getTexture("media/ui/Paradise/ZoneContextIcon.png")
    end

    if ParadiseDev.SkillRecovery and ParadiseDev.SkillRecovery.addParadiseOptions then
        ParadiseDev.SkillRecovery.addParadiseOptions(menu, pl, worldobjects)
    end

    local panelsRoot = menu:addOptionOnTop("Panels")
    panelsRoot.iconTexture = getTexture("media/ui/Paradise/ContextIcon.png")
    local panelsMenu = ISContextMenu:getNew(context)
    menu:addSubMenu(panelsRoot, panelsMenu)
    if ParadiseDev.Zones and ParadiseDev.Zones.openUI then
        ParadiseDev.Context.addOption(
            panelsMenu,
            "Zone Editor",
            ParadiseDev.Zones.openUI,
            "media/ui/Paradise/ZoneContextIcon.png"
        )
    end
    if ParadiseDev.Cage and ParadiseDev.Cage.openPanel then
        ParadiseDev.Context.addOption(
            panelsMenu,
            "Cage Administration",
            ParadiseDev.Cage.openPanel,
            "media/ui/Paradise/ContextIcon.png"
        )
    end
    if ParadiseDev.ZedController and ParadiseDev.ZedController.open then
        ParadiseDev.Context.addOption(
            panelsMenu,
            "Paradise Zed Control",
            ParadiseDev.ZedController.open,
            "media/ui/Paradise/StopZedContextIcon.png"
        )
    end
    if ParadiseDev.Panels then
        ParadiseDev.Context.addOption(
            panelsMenu,
            "WaveCaster",
            ParadiseDev.Panels.openWaveCaster,
            "media/ui/Paradise/ContextIcon.png"
        )
        ParadiseDev.Context.addOption(
            panelsMenu,
            "Media Spawner",
            ParadiseDev.Panels.openMediaSpawner,
            "media/ui/Paradise/ContextIcon.png"
        )
        --[[ 
            if ParadiseDev.Tiles and ParadiseDev.Tiles.openBrushTool then ParadiseDev.Context.addOption(panelsMenu, "Brush Tool", ParadiseDev.Tiles.openBrushTool, "media/ui/Paradise/ContextIcon.png") end
            ParadiseDev.Context.addOption(panelsMenu, "Promo Manager", function() 
                ParadisePromo.openAdminPanel()
            end, "media/ui/Paradise/ContextIcon.png")
]]
        ParadiseDev.Context.addOption(
            panelsMenu,
            "Mini Scoreboard",
            function()
                if ISMiniScoreboardUI.instance then
                    ISMiniScoreboardUI.instance:close()
                end
                local ui = ISMiniScoreboardUI:new(50, 50, 300, 300, getPlayer())
                ui:initialise()
                ui:addToUIManager()
            end,
            "media/ui/Paradise/ContextIcon.png"
        )
        ParadiseDev.Context.addOption(
            panelsMenu,
            "Users List",
            ParadiseDev.Panels.openUsersList,
            "media/ui/Paradise/ContextIcon.png"
        )
        ParadiseDev.Context.addOption(
            panelsMenu,
            "Global ModData",
            ParadiseDev.Panels.openGlobalModData,
            "media/ui/Paradise/ContextIcon.png"
        )
        if ParadisePOI and ParadisePOI.openPanel then
            ParadiseDev.Context.addOption(
                panelsMenu,
                "POI Manager",
                ParadisePOI.openPanel,
                "media/ui/Paradise/ContextIcon.png"
            )
        end
        ParadiseDev.Context.addOption(
            panelsMenu,
            "Mod Active Check",
            ParadiseDev.Panels.openModActiveCheck,
            "media/ui/Paradise/ContextIcon.png"
        )
        ParadiseDev.Context.addOption(
            panelsMenu,
            "Paradise Playtime Checker",
            ParadiseDev.Panels.openPlaytimeCheck,
            "media/ui/Paradise/ContextIcon.png"
        )
        if getCore():getDebug() then
            ParadiseDev.Context.addOption(
                panelsMenu,
                "AnimMonitor",
                ParadiseDev.Panels.ISAnimDebugMonitor,
                "media/ui/Paradise/ContextIcon.png"
            )
        end
    end
    if ParadiseDev.Zones and ParadiseDev.Zones.openTestRemote then
        ParadiseDev.Context.addOption(
            panelsMenu,
            "Zone Test Control",
            ParadiseDev.Zones.openTestRemote,
            "media/ui/Paradise/ZoneContextIcon.png"
        )
    end

    ParadiseDev.Context.addOption(
        menu,
        "Audio Direction: " .. ParadiseDev.Context.onOrOff(ParadiseZ.soundDbg),
        ParadiseDev.Context.toggleSound,
        "media/ui/Paradise/LightContextIcon.png"
    )
    if ParadiseZ.isTrailingLightMode and ParadiseZ.toggleTrailingLightMode then
        ParadiseDev.Context.addOption(
            menu,
            "Trailing Light: " .. ParadiseDev.Context.onOrOff(ParadiseZ.isTrailingLightMode(pl)),
            ParadiseDev.Context.toggleTrailingLight,
            "media/ui/Paradise/LightContextIcon.png",
            pl
        )
    end
    local adminTagOption =
        ParadiseDev.Context.addOption(
        menu,
        "Modded Admin Tag: " .. ParadiseDev.Context.onOrOff(ParadiseZ.isShowAdminTag(pl)),
        ParadiseDev.Context.toggleShowAdminTag,
        "media/ui/Paradise/AdmTagContextIcon.png",
        pl
    )
    if adminTagOption then
        adminTagOption.checkMark = ParadiseZ.isShowAdminTag(pl)
    end

    if ParadiseDev.TP then
        ParadiseDev.Context.addOption(
            menu,
            "Save Rebound Point",
            ParadiseDev.Context.saveRebound,
            "media/ui/Paradise/ContextIcon.png",
            pl
        )
        if ParadiseDev.TP.getRebound(pl) then
            ParadiseDev.Context.addOption(
                menu,
                "Force Rebound",
                ParadiseDev.Context.forceRebound,
                "media/ui/Paradise/ContextIcon.png",
                pl
            )
        end
    end

    ParadiseDev.Context.addOption(
        menu,
        "GunAmmos",
        function()
            ParadiseDev.Context.reloadGuns()
        end,
        "media/ui/LootableMaps/map_bullets.png",
        pl
    )

    ParadiseDev.Context.addOption(
        menu,
        "Goldgun",
        function()
            sendClientCommand("ParadiseDevSkin", "spawnGoldgun", {})
        end,
        "media/ui/LootableMaps/map_bullets.png",
        pl
    )

    local rateOfFireRoot = menu:addOption("Rate of Fire Test")
    rateOfFireRoot.iconTexture = getTexture("media/ui/LootableMaps/map_bullets.png")
    local rateOfFireMenu = ISContextMenu:getNew(context)
    menu:addSubMenu(rateOfFireRoot, rateOfFireMenu)
    ParadiseDev.Context.addOption(
        rateOfFireMenu,
        "RPS (rounds per sec)",
        ParadiseDev.Context.setRateOfFireTestMode,
        "media/ui/LootableMaps/map_bullets.png",
        "RPS"
    )
    ParadiseDev.Context.addOption(
        rateOfFireMenu,
        "RPM (rounds per min)",
        ParadiseDev.Context.setRateOfFireTestMode,
        "media/ui/LootableMaps/map_bullets.png",
        "RPM"
    )
    ParadiseDev.Context.addOption(
        rateOfFireMenu,
        "Disable",
        ParadiseDev.Context.setRateOfFireTestMode,
        "media/ui/LootableMaps/map_bullets.png",
        "Disable"
    )

    if ParadiseDev.Visual then
        local visualRoot = menu:addOption("Visual Tests")
        visualRoot.iconTexture = getTexture("media/ui/Paradise/ContextIcon.png")
        local visualMenu = ISContextMenu:getNew(context)
        menu:addSubMenu(visualRoot, visualMenu)
        ParadiseDev.Context.addOption(
            visualMenu,
            "Hide Worn Visuals",
            ParadiseDev.Visual.hide,
            "media/ui/Paradise/ContextIcon.png",
            pl
        )
        ParadiseDev.Context.addOption(
            visualMenu,
            "Restore Worn Visuals",
            ParadiseDev.Visual.replace,
            "media/ui/Paradise/ContextIcon.png",
            pl
        )
        ParadiseDev.Context.addOption(
            visualMenu,
            "Test Firearm Model: Handgun03",
            ParadiseDev.Visual.testWeaponSprite,
            "media/ui/LootableMaps/map_bullets.png",
            pl
        )
        ParadiseDev.Context.addOption(
            visualMenu,
            "Restore Firearm Model",
            ParadiseDev.Visual.resetWeaponSprite,
            "media/ui/LootableMaps/map_bullets.png",
            pl
        )
    end

    ParadiseDev.Context.addOption(
        menu,
        "Spawn TheRange Membership Card",
        ParadiseDev.Context.spawnRangeCard,
        "media/textures/TheRange.png",
        pl
    )
    local nvgOption =
        ParadiseDev.Context.addOption(
        menu,
        "NVG",
        ParadiseDev.Context.toggleNightVision,
        "media/ui/Paradise/NVGContextIcon.png",
        pl
    )
    if nvgOption then
        nvgOption.checkMark = pl:isWearingNightVisionGoggles()
    end
    if ParadiseZ.lvlUp then
        ParadiseDev.Context.addOption(menu, "Level Up", ParadiseZ.lvlUp, "media/ui/Paradise/LvlContextIcon.png")
    end
    if ParadiseZ.die then
        ParadiseDev.Context.addOption(menu, "Suicide", ParadiseZ.die, "media/ui/Paradise/RIPContextIcon.png")
    end

    local zombieRoot = menu:addOption("Zombies")
    zombieRoot.iconTexture = getTexture("media/ui/Paradise/StopZedContextIcon.png")
    local zombieMenu = ISContextMenu:getNew(context)
    menu:addSubMenu(zombieRoot, zombieMenu)
    local zombieAttackOption =
        ParadiseDev.Context.addOption(
        zombieMenu,
        "Prevent Zombie Attacks",
        ParadiseDev.Context.toggleZombieAttacks,
        "media/ui/Paradise/StopZedContextIcon.png",
        pl
    )
    if zombieAttackOption then
        zombieAttackOption.checkMark = pl:isZombiesDontAttack() == true
    end
    ParadiseDev.Context.addOption(
        zombieMenu,
        "Kill Zeds",
        ParadiseDev.Context.killZeds,
        "media/ui/LootableMaps/map_cross.png"
    )
    ParadiseDev.Context.addOption(
        zombieMenu,
        "Count Dead",
        ParadiseDev.Context.countDead,
        "media/ui/LootableMaps/map_question.png"
    )
    ParadiseDev.Context.addOption(
        zombieMenu,
        "Count Zeds",
        ParadiseDev.Context.countZeds,
        "media/ui/LootableMaps/map_skull.png"
    )

    local clearRoot = menu:addOptionOnTop("Clear")
    clearRoot.iconTexture = getTexture("media/ui/Paradise/ClearContextIcon.png")
    local clearMenu = ISContextMenu:getNew(context)
    menu:addSubMenu(clearRoot, clearMenu)
    ParadiseDev.Context.addOption(
        clearMenu,
        "OpenClearPanel",
        ParadiseDev.Context.openClearPanel,
        "media/ui/Paradise/ClearContextIcon.png",
        pl
    )
    ParadiseDev.Context.addOption(
        clearMenu,
        "Clear Vehicle",
        ParadiseZ.DespawnCar,
        "media/ui/Paradise/CarsContextIcon.png",
        pl
    )
    ParadiseDev.Context.addOption(
        clearMenu,
        "Clean Character",
        ParadiseZ.washChar,
        "media/ui/Paradise/WashContextIcon.png"
    )
    ParadiseDev.Context.addOption(
        clearMenu,
        "Clear Map Record",
        ParadiseZ.ClearMap,
        "media/ui/Paradise/MapContextIcon.png"
    )
    ParadiseDev.Context.addOption(
        clearMenu,
        "Clear WorldMapVisited",
        ParadiseDev.Context.resetMapVisited,
        "media/ui/Paradise/MapContextIcon.png"
    )
    ParadiseDev.Context.addOption(
        clearMenu,
        "Clear Weather",
        ParadiseZ.clearWeather,
        "media/ui/Paradise/WeatherContextIcon.png"
    )
    ParadiseDev.Context.addOption(
        clearMenu,
        "Clear Fog",
        ParadiseZ.clearFog,
        "media/ui/Paradise/WeatherContextIcon.png"
    )
    ParadiseDev.Context.addOption(
        clearMenu,
        "Clear Worn Items",
        ParadiseZ.ClearWornItems,
        "media/ui/Paradise/WornItemsContextIcon.png"
    )
    ParadiseDev.Context.addOption(
        clearMenu,
        "Clear Traits",
        ParadiseZ.ClearTraits,
        "media/ui/Paradise/TraitsContextIcon.png"
    )
    ParadiseDev.Context.addOption(
        clearMenu,
        "Clear Perks",
        ParadiseZ.ClearPerks,
        "media/ui/Paradise/MemoryContextIcon.png"
    )
    ParadiseDev.Context.addOption(
        clearMenu,
        "Clear Learned",
        ParadiseZ.ClearLearned,
        "media/ui/Paradise/LearnContextIcon.png"
    )
    ParadiseDev.Context.addOption(
        clearMenu,
        "Clear and Save",
        ParadiseDev.Context.clearAndSave,
        "media/ui/Paradise/ClearContextIcon.png",
        pl
    )
end

ParadiseZ.dbgSoundHandler = ParadiseDev.Context.dbgSoundHandler
ParadiseZ.context = ParadiseDev.Context.context

Events.OnWorldSound.Remove(ParadiseDev.Context.dbgSoundHandler)
Events.OnWorldSound.Add(ParadiseDev.Context.dbgSoundHandler)
Events.OnFillWorldObjectContextMenu.Remove(ParadiseDev.Context.context)
Events.OnFillWorldObjectContextMenu.Add(ParadiseDev.Context.context)

function ParadiseDev.Context.reloadGuns()
    local pl = getPlayer()
    if not pl or not (isClient and isClient()) then
        return
    end
    sendClientCommand("ParadiseDevSkin", "reloadGuns", {})
end
