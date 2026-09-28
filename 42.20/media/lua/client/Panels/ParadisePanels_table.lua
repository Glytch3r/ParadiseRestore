ParadisePanels = ParadisePanels or {}
ParadisePromo = ParadisePromo or {}
ParadisePromo.AdminPanel = ParadisePromo.AdminPanel or {}
ParadisePromo.PlayerPanel = ParadisePromo.PlayerPanel or {}

local function initialise(panel, instantiate)
    if not panel then return nil end
    panel:initialise()
    if instantiate and panel.instantiate then panel:instantiate() end
    return panel
end

ParadisePanels.table = {
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
            if panel.resizeWidget then panel.resizeWidget.resizeFunction = module.Panel.resizeWindow end
            if panel.resizeWidget2 then panel.resizeWidget2.resizeFunction = module.Panel.resizeWindow end
            return panel
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
        onOpen = function(panel)
            panel:setAlwaysOnTop(true)
            panel:setWantKeyEvents(true)
            panel:setForceCursorVisible(true)
            if JoypadState.players[panel.playerNumber + 1] then
                panel.previousJoypadFocus = JoypadState.players[panel.playerNumber + 1].focus
                setJoypadFocus(panel.playerNumber, panel)
            end
        end,
        onClose = function(panel)
            if panel.playerNumber and JoypadState.players[panel.playerNumber + 1] then
                setJoypadFocus(panel.playerNumber, panel.previousJoypadFocus)
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
