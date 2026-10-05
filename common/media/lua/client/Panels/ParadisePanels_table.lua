ParadisePanels = ParadisePanels or {}
ParadisePromo = ParadisePromo or {}
ParadisePromo.AdminPanel = ParadisePromo.AdminPanel or {}
ParadisePromo.PlayerPanel = ParadisePromo.PlayerPanel or {}
ParadiseZTrailingLights = ParadiseZTrailingLights or {}
JimsRulesAdmin = JimsRulesAdmin or {}

local function initialise(panel, instantiate)
    if not panel then return nil end
    panel:initialise()
    if instantiate and panel.instantiate then panel:instantiate() end
    return panel
end

ParadisePanels.table = {
    {
        key = "jimsRulesAdmin",
        isAdmOnly = true,
        getModule = function() return JimsRulesAdmin end,
        getInstance = function() return JimsRulesAdmin.instance end,
        setInstance = function(instance) JimsRulesAdmin.instance = instance end,
        create = function()
            local width = math.min(900, getCore():getScreenWidth() - 40)
            local height = math.min(700, getCore():getScreenHeight() - 40)
            return initialise(JimsRulesAdmin.Panel:new(
                math.max(20, (getCore():getScreenWidth() - width) / 2),
                math.max(20, (getCore():getScreenHeight() - height) / 2),
                width,
                height
            ))
        end,
        onOpen = function() JimsRulesAdmin.requestRules() end,
    },
    {
        key = "trailingLights",
        isAdmOnly = true,
        getModule = function() return ParadiseZTrailingLights end,
        getInstance = function() return ParadiseZTrailingLights.instance end,
        setInstance = function(instance) ParadiseZTrailingLights.instance = instance end,
        create = function(plNum)
            plNum = plNum or 0
            local width = 276
            local height = 392
            local x = math.max(20, math.floor((getCore():getScreenWidth() - width) / 2))
            local y = math.max(20, math.floor((getCore():getScreenHeight() - height) / 2))
            return initialise(ParadiseZTrailingLightsWindow:new(x, y, width, height, plNum))
        end,
        onOpen = function(panel)
            ParadiseZTrailingLights.windows[panel.playerNum] = panel
            panel:syncFromState()
        end,
        onClose = function(panel)
            ParadiseZTrailingLights.windows[panel.playerNum] = nil
            if panel.colorPicker then
                panel.colorPicker:removeSelf()
                panel.colorPicker = nil
            end
        end,
    },
    {
        key = "uiInspector",
        isAdmOnly = true,
        getModule = function() return ParadiseDev and ParadiseDev.UI end,
        getInstance = function() return ParadiseDev and ParadiseDev.UI and ParadiseDev.UI.instance end,
        setInstance = function(instance) ParadiseDev.UI.instance = instance end,
        create = function()
            local bounds = ParadiseDev.UI.getPanelBounds(
                getCore():getScreenWidth(),
                getCore():getScreenHeight()
            )
            return initialise(ParadiseDev.UI.Panel:new(
                bounds.x,
                bounds.y,
                bounds.width,
                bounds.height
            ))
        end,
        onOpen = function(panel) panel:refresh() end,
    },
    {
        key = "factionManager",
        isAdmOnly = true,
        getModule = function() return FactionManager end,
        getInstance = function() return FactionManager and FactionManager.instance end,
        setInstance = function(instance) FactionManager.instance = instance end,
        create = function()
            local width = math.min(1120, getCore():getScreenWidth() - 40)
            local height = math.min(720, getCore():getScreenHeight() - 40)
            local panel = FactionManager.Panel:new(
                math.max(20, (getCore():getScreenWidth() - width) / 2),
                math.max(20, (getCore():getScreenHeight() - height) / 2),
                width,
                height
            )
            return initialise(panel)
        end,
        onOpen = function() FactionManager.requestState() end,
    },
    {
        key = "dataCheck",
        isAdmOnly = true,
        getModule = function() return ParadiseDev and ParadiseDev.DataCheck end,
        getInstance = function() return ParadiseDev and ParadiseDev.DataCheck and ParadiseDev.DataCheck.window end,
        setInstance = function(instance) ParadiseDev.DataCheck.window = instance end,
        create = function()
            return initialise(ParadiseDev.DataCheck.Panel:new(60, 60, 1250, 620))
        end,
        onOpen = function(panel, obj, name)
            local index = ParadiseDev.DataCheck.add(obj, name) or 1
            panel:refresh(index)
        end,
    },
    {
        key = "globalModData",
        isAdmOnly = true,
        getModule = function() return ParadiseDev and ParadiseDev.Panels and ParadiseDev.Panels.GlobalModData end,
        getInstance = function() return ParadiseDev and ParadiseDev.Panels and ParadiseDev.Panels.globalModData end,
        setInstance = function(instance) ParadiseDev.Panels.globalModData = instance end,
        create = function()
            return initialise(ParadiseDev.Panels.GlobalModData:new(100, 100, 900, 600, "ParadiseZ Global ModData"), true)
        end,
        onOpen = function(panel) panel:populateList() end,
    },
    {
        key = "mediaSpawner",
        isAdmOnly = true,
        getModule = function() return ParadiseDev and ParadiseDev.Panels and ParadiseDev.Panels.MediaSpawner end,
        getInstance = function() return ParadiseDev and ParadiseDev.Panels and ParadiseDev.Panels.mediaSpawner end,
        setInstance = function(instance) ParadiseDev.Panels.mediaSpawner = instance end,
        create = function()
            return initialise(ParadiseDev.Panels.MediaSpawner:new(250, 180, 620, 500))
        end,
        onOpen = function(panel)
            panel:populateCategories()
            panel:populateList()
        end,
    },
    {
        key = "modActiveCheck",
        isAdmOnly = true,
        getModule = function() return ParadiseDev and ParadiseDev.Panels and ParadiseDev.Panels.ModActiveCheck end,
        getInstance = function() return ParadiseDev and ParadiseDev.Panels and ParadiseDev.Panels.modActiveCheck end,
        setInstance = function(instance) ParadiseDev.Panels.modActiveCheck = instance end,
        create = function()
            return initialise(ParadiseDev.Panels.ModActiveCheck:new(250, 180, 360, 150))
        end,
    },
    {
        key = "playtimeCheck",
        isAdmOnly = true,
        getModule = function() return ParadiseDev and ParadiseDev.Panels and ParadiseDev.Panels.PlaytimeCheck end,
        getInstance = function() return ParadiseDev and ParadiseDev.Panels and ParadiseDev.Panels.playtimeCheck end,
        setInstance = function(instance) ParadiseDev.Panels.playtimeCheck = instance end,
        create = function()
            return initialise(ParadiseDev.Panels.PlaytimeCheck:new(250, 180, 400, 180))
        end,
    },
    {
        key = "traitSyncer",
        isAdmOnly = true,
        getModule = function() return ParadiseDev and ParadiseDev.TraitSyncer end,
        getInstance = function() return ParadiseDev and ParadiseDev.TraitSyncer and ParadiseDev.TraitSyncer.window end,
        setInstance = function(instance) ParadiseDev.TraitSyncer.window = instance end,
        create = function()
            return initialise(ParadiseDev.TraitSyncer.Panel:new(220, 180, 700, 420))
        end,
        onOpen = function() ParadiseDev.TraitSyncer.requestState() end,
    },
    {
        key = "zedController",
        isAdmOnly = true,
        getModule = function() return ParadiseDev and ParadiseDev.ZedController end,
        getInstance = function() return ParadiseDev and ParadiseDev.ZedController and ParadiseDev.ZedController.instance end,
        setInstance = function(instance) ParadiseDev.ZedController.instance = instance end,
        create = function(pl)
            local module = ParadiseDev.ZedController
            pl = pl or getPlayer()
            if not pl or not module.isAdmin(pl) then return nil end
            local core = getCore()
            local width = math.min(920, math.max(360, core:getScreenWidth() - 16))
            local height = math.min(650, math.max(280, core:getScreenHeight() - 16))
            local panel = module.Panel:new(
                math.max(8, math.floor((core:getScreenWidth() - width) / 2)),
                math.max(8, math.floor((core:getScreenHeight() - height) / 2)),
                width, height, pl)
            initialise(panel)
            return panel
        end,
        onOpen = function(panel)
            local resize = ParadiseDev.ZedController.Panel.resizeWindow
            if panel.resizeWidget then panel.resizeWidget.resizeFunction = resize end
            if panel.resizeWidget2 then panel.resizeWidget2.resizeFunction = resize end
        end,
        onClose = function(panel)
            panel:clearCursor()
            panel:clearSelection()
        end,
    },
    {
        key = "zones",
        isAdmOnly = true,
        getModule = function() return ParadiseDev and ParadiseDev.Zones end,
        getInstance = function() return ParadiseDev and ParadiseDev.Zones and ParadiseDev.Zones.window end,
        setInstance = function(instance) ParadiseDev.Zones.window = instance end,
        create = function()
            local width, height = 1200, 568
            local x = math.max(0, (getCore():getScreenWidth() - width) / 2 - 180)
            local y = math.max(0, (getCore():getScreenHeight() - height) / 2)
            return initialise(ParadiseDev.Zones.Panel:new(x, y, width, height))
        end,
        onOpen = function() ParadiseDev.Zones.send("requestAdminState") end,
        onClose = function()
            if ParadiseDev.Zones.Editor and ParadiseDev.Zones.Editor.ClosePanel then
                ParadiseDev.Zones.Editor.ClosePanel()
            end
        end,
    },
    {
        key = "zonesEditor",
        isAdmOnly = true,
        getModule = function() return ParadiseDev and ParadiseDev.Zones and ParadiseDev.Zones.Editor end,
        getInstance = function() return ParadiseDev and ParadiseDev.Zones and ParadiseDev.Zones.editorWindow end,
        setInstance = function(instance) ParadiseDev.Zones.editorWindow = instance end,
        create = function(zoneId, parent)
            if not zoneId then return nil end
            local width, height = 950, 520
            local x = math.max(0, (getCore():getScreenWidth() - width) / 2 + 220)
            local y = math.max(0, (getCore():getScreenHeight() - height) / 2)
            return initialise(ParadiseDev.Zones.Editor:new(x, y, width, height, zoneId, parent))
        end,
        onOpen = function(panel, zoneId, parent)
            if zoneId then panel.zoneId = zoneId end
            if panel.parentWindow and panel.parentWindow ~= parent and panel.parentWindow.childEditor == panel then
                panel.parentWindow.childEditor = nil
            end
            panel.parentWindow = parent
            if parent then parent.childEditor = panel end
            local zone = ParadiseDev.Zones.zoneById(panel.zoneId)
            if zone and panel.loadZone then panel:loadZone(zone) end
        end,
        onClose = function(panel)
            if panel.parentWindow and panel.parentWindow.childEditor == panel then
                panel.parentWindow.childEditor = nil
            end
        end,
    },
    {
        key = "zonesTestRemote",
        isAdmOnly = true,
        getModule = function() return ParadiseDev and ParadiseDev.Zones and ParadiseDev.Zones.TestRemote end,
        getInstance = function() return ParadiseDev and ParadiseDev.Zones and ParadiseDev.Zones.testWindow end,
        setInstance = function(instance) ParadiseDev.Zones.testWindow = instance end,
        create = function()
            local width, height = 560, 410
            local x = math.max(0, (getCore():getScreenWidth() - width) / 2 + 260)
            local y = math.max(0, (getCore():getScreenHeight() - height) / 2)
            return initialise(ParadiseDev.Zones.TestRemote:new(x, y, width, height))
        end,
        onOpen = function() ParadiseDev.Zones.send("requestAdminState") end,
    },
    {
        key = "poi",
        isAdmOnly = true,
        getModule = function() return ParadisePOI end,
        getInstance = function() return ParadisePOI and ParadisePOI.instance end,
        setInstance = function(instance) ParadisePOI.instance = instance end,
        create = function()
            local width, height = 960, 430
            local x = (getCore():getScreenWidth() - width) / 2
            local y = (getCore():getScreenHeight() - height) / 2
            return initialise(Paradise_POI_Manager:new(x, y, width, height))
        end,
        onOpen = function() ParadisePOI.requestSync() end,
    },
    {
        key = "luaResetTool",
        isAdmOnly = true,
        getModule = function() return LuaResetTool end,
        getInstance = function() return LuaResetTool and LuaResetTool.window end,
        setInstance = function(instance) LuaResetTool.window = instance end,
        create = function()
            local width, height = 770, 560
            local x = math.floor((getCore():getScreenWidth() - width) / 2)
            local y = math.floor((getCore():getScreenHeight() - height) / 2)
            return initialise(LuaResetWindow:new(x, y, width, height))
        end,
        onOpen = function(panel)
            panel:setAlwaysOnTop(true)
        end,
    },
    {
        key = "waveCaster",
        isAdmOnly = true,
        getModule = function() return WaveCasterPanel end,
        getInstance = function() return WaveCasterPanel and WaveCasterPanel.instance end,
        setInstance = function(instance) WaveCasterPanel.instance = instance end,
        create = function(pl, square)
            pl = pl or getPlayer()
            if not pl then return nil end
            square = square or pl:getSquare()
            if not square then return nil end
            local width, height = 1020, 960
            local x = (getCore():getScreenWidth() - width) / 2 - 300
            local y = (getCore():getScreenHeight() - height) / 2
            return initialise(WaveCasterPanel:new(x, y, width, height, pl, square))
        end,
        onOpen = function(panel, pl, square)
            pl = pl or getPlayer()
            if not pl then return end
            square = square or pl:getSquare()
            if not square then return end
            panel.chr = pl
            panel.plNum = pl:getPlayerNum()
            panel.castX, panel.castY = square:getX(), square:getY()
            panel.selectX, panel.selectY, panel.selectZ = square:getX(), square:getY(), square:getZ()
            panel:removeMarker()
            panel:addPickMarker(square)
        end,
        onClose = function(panel)
            if panel.childEditor then
                if panel.childEditor.onCancel then
                    panel.childEditor:onCancel()
                else
                    panel.childEditor:close()
                end
                panel.childEditor = nil
            end
            panel:removeMarker()
        end,
    },
    {
        key = "jimsRules",
        isAdmOnly = false,
        getModule = function() return JimsRulesUI end,
        getInstance = function() return JimsRulesUI and JimsRulesUI.instance end,
        setInstance = function(instance) JimsRulesUI.instance = instance end,
        create = function(playerNumber, player, title, subtitle, rawRules, reviewOnly)
            if playerNumber == nil then return nil end
            local panel = JimsRulesUI:new(0, 0, getCore():getScreenWidth(), getCore():getScreenHeight(),
                playerNumber, player, title, subtitle, rawRules, reviewOnly)
            return initialise(panel)
        end,
        onOpen = function(panel, playerNumber, player, title, subtitle, rawRules, reviewOnly)
            if playerNumber ~= nil then panel.playerNumber = playerNumber end
            panel.player = player
            panel.title = tostring(title or "JIM'S PARADISE")
            panel.subtitle = tostring(subtitle or "Read the rules below before entering the world.")
            panel.rawRules = tostring(rawRules or "")
            panel.reviewOnly = reviewOnly == true
            panel.awaitingServer = false
            panel.errorMessage = nil
            if panel.rulesPanel then
                panel.rulesPanel:setText(JimsRulesUI.formatRules(panel.rawRules))
                panel.rulesPanel:paginate()
            end
            if panel.agreement then
                panel.agreement:setVisible(not panel.reviewOnly)
                panel.agreement:setSelected(1, false)
            end
            if panel.acceptButton then
                panel.acceptButton:setTitle(panel.reviewOnly and "CLOSE" or "ACCEPT AND ENTER")
                panel.acceptButton:setEnable(panel.reviewOnly)
            end
            panel:setAlwaysOnTop(true)
            panel:setWantKeyEvents(true)
            panel:setForceCursorVisible(true)

            if panel._paradiseFocusCaptured and panel._paradiseFocusPlayer ~= panel.playerNumber then
                local previousPlayer = JoypadState.players[panel._paradiseFocusPlayer + 1]
                if previousPlayer then setJoypadFocus(panel._paradiseFocusPlayer, panel.previousJoypadFocus) end
                panel._paradiseFocusCaptured = false
                panel.previousJoypadFocus = nil
            end
            if JoypadState.players[panel.playerNumber + 1] then
                if not panel._paradiseFocusCaptured then
                    panel.previousJoypadFocus = JoypadState.players[panel.playerNumber + 1].focus
                    panel._paradiseFocusCaptured = true
                    panel._paradiseFocusPlayer = panel.playerNumber
                end
                setJoypadFocus(panel.playerNumber, panel)
            end
        end,
        onClose = function(panel)
            local playerNumber = panel._paradiseFocusPlayer or panel.playerNumber
            if panel._paradiseFocusCaptured and playerNumber ~= nil and JoypadState.players[playerNumber + 1] then
                setJoypadFocus(playerNumber, panel.previousJoypadFocus)
            end
        end,
    },
    {
        key = "promoAdmin",
        isAdmOnly = true,
        getModule = function() return ParadisePromo.AdminPanel end,
        getInstance = function() return ParadisePromo.adminInstance end,
        setInstance = function(instance) ParadisePromo.adminInstance = instance end,
        create = function()
            local width, height = 700, 460
            local x = (getCore():getScreenWidth() - width) / 2
            local y = (getCore():getScreenHeight() - height) / 2
            return initialise(ParadisePromo_Admin_Manager:new(x, y, width, height))
        end,
        onOpen = function()
            sendClientCommand(getPlayer(), "ParadisePromo", "requestSync", {})
        end,
    },
    {
        key = "promoPlayer",
        isAdmOnly = false,
        getModule = function() return ParadisePromo.PlayerPanel end,
        getInstance = function() return ParadisePromo.playerInstance end,
        setInstance = function(instance) ParadisePromo.playerInstance = instance end,
        create = function()
            local width, height = 320, 130
            local x = (getCore():getScreenWidth() - width) / 2
            local y = (getCore():getScreenHeight() - height) / 2
            return initialise(ParadisePromo_Player_Panel:new(x, y, width, height))
        end,
    },
}
