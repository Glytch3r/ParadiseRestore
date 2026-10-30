require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISPanel"

ParadiseAdminHub = ParadiseAdminHub or {}

function ParadiseAdminHub.canOpen()
    return ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(getPlayer()) or false
end

function ParadiseAdminHub.getEntries()
    local list = {}
    local function add(label, open)
        list[#list + 1] = { label = label, open = open }
    end

    if ParadiseEconomy and ParadiseEconomy.isEnabled and ParadiseEconomy.isEnabled() then
        if ParadiseEconomy.OpenPanel then
            add("Economy", function() ParadiseEconomy.OpenPanel() end)
        end
        if ParadiseEconomy.AccountBrowser and ParadiseEconomy.AccountBrowser.OpenPanel then
            add("Accounts", function() ParadiseEconomy.AccountBrowser.OpenPanel() end)
        end
        if ParadiseEconomy.AdminPanel and ParadiseEconomy.AdminPanel.OpenPanel then
            add("Economy Admin", function() ParadiseEconomy.AdminPanel.OpenPanel() end)
        end
        if ParadiseEconomy.TablesPanel and ParadiseEconomy.TablesPanel.OpenPanel then
            add("Data Tables", function() ParadiseEconomy.TablesPanel.OpenPanel() end)
        end
        if ParadiseEconomy.MartPanel and ParadiseEconomy.MartPanel.OpenPanel then
            add("Tradeshop", function() ParadiseEconomy.MartPanel.OpenPanel() end)
        end
        if ParadiseEconomy.TradeManagementPanel and ParadiseEconomy.TradeManagementPanel.OpenPanel
            and ParadiseEconomy.canManageTradeZones and ParadiseEconomy.canManageTradeZones() then
            add("Trade Management", function() ParadiseEconomy.TradeManagementPanel.OpenPanel() end)
        end
    end

    if RecordsPanel and RecordsPanel.OpenPanel then
        add("Records", function() RecordsPanel.OpenPanel() end)
    end
    if ParadiseDev and ParadiseDev.SafehouseAdmin and ParadiseDev.SafehouseAdmin.OpenPanel then
        add("Safehouse Records", function() ParadiseDev.SafehouseAdmin.OpenPanel(getPlayer()) end)
    end
    if JimsRulesAdmin and JimsRulesAdmin.OpenPanel then
        add("Server Rules", function() JimsRulesAdmin.OpenPanel() end)
    end
    if ParadiseThemes and ParadiseThemes.Admin and ParadiseThemes.Admin.OpenPanel then
        add("Theme Editor", function() ParadiseThemes.Admin.OpenPanel() end)
    end
    if FactionManager and FactionManager.OpenPanel then
        add("Factions", function() FactionManager.OpenPanel() end)
    end
    if ParadiseDev and ParadiseDev.Zones and ParadiseDev.Zones.OpenPanel then
        add("Zones", function() ParadiseDev.Zones.OpenPanel() end)
    end
    if ParadisePOI and ParadisePOI.OpenPanel then
        add("POI Manager", function() ParadisePOI.OpenPanel() end)
    end
    if WaveCasterPanel and WaveCasterPanel.OpenPanel then
        add("WaveCaster", function() WaveCasterPanel.OpenPanel() end)
    end
    if ParadiseDev and ParadiseDev.ZedController and ParadiseDev.ZedController.OpenPanel then
        add("Zed Control", function() ParadiseDev.ZedController.OpenPanel() end)
    end
    if ParadiseDev and ParadiseDev.TraitSyncer and ParadiseDev.TraitSyncer.OpenPanel then
        add("Trait Syncer", function() ParadiseDev.TraitSyncer.OpenPanel() end)
    end
    if ParadiseDev and ParadiseDev.Panels and ParadiseDev.Panels.MediaSpawner and ParadiseDev.Panels.MediaSpawner.OpenPanel then
        add("Media Spawner", function() ParadiseDev.Panels.MediaSpawner.OpenPanel() end)
    end
    if ParadiseDev and ParadiseDev.Panels and ParadiseDev.Panels.GlobalModData and ParadiseDev.Panels.GlobalModData.OpenPanel then
        add("Global ModData", function() ParadiseDev.Panels.GlobalModData.OpenPanel() end)
    end
    if ParadiseDev and ParadiseDev.Panels and ParadiseDev.Panels.PlaytimeCheck and ParadiseDev.Panels.PlaytimeCheck.OpenPanel then
        add("Playtime", function() ParadiseDev.Panels.PlaytimeCheck.OpenPanel() end)
    end
    if ParadiseDev and ParadiseDev.Sniffer and ParadiseDev.Sniffer.startPick then
        add("Sniffer", function() ParadiseDev.Sniffer.startPick() end)
    end
    if ParadiseProductionDiagnostics and ParadiseProductionDiagnostics.isEnabled and ParadiseProductionDiagnostics.isEnabled() then
        if ParadiseDev and ParadiseDev.Panels and ParadiseDev.Panels.ModActiveCheck and ParadiseDev.Panels.ModActiveCheck.OpenPanel then
            add("Mod Check", function() ParadiseDev.Panels.ModActiveCheck.OpenPanel() end)
        end
        if LuaResetTool and LuaResetTool.OpenPanel then
            add("Lua Reset", function() LuaResetTool.OpenPanel() end)
        end
    end
    if ParadisePanels and ParadisePanels.CloseAdminPanels then
        add("Close All Panels", function() ParadisePanels.CloseAdminPanels() end)
    end

    return list
end

function ParadiseAdminHub.getSize()
    local rows = math.ceil(#ParadiseAdminHub.getEntries() / 2)
    return 560, rows * 36 + 74
end

function ParadiseAdminHub.runEntry(entry)
    if not entry or not entry.open then return end
    entry.open()
end

ParadiseAdminHub.Panel = ISCollapsableWindow:derive("ParadiseAdminHub.Panel")

function ParadiseAdminHub.Panel:createChildren()
    ISCollapsableWindow.createChildren(self)

    local entries = ParadiseAdminHub.getEntries()
    local top = self:titleBarHeight() + 10
    local gap = 8
    local rowH = 28
    local rowGap = 6
    local columns = 2
    local contentW = self.width - 24
    local colW = math.floor((contentW - gap * (columns - 1)) / columns)

    for index, entry in ipairs(entries) do
        local col = (index - 1) % columns
        local row = math.floor((index - 1) / columns)
        local button = ISButton:new(12 + col * (colW + gap), top + row * (rowH + rowGap), colW, rowH, entry.label, self, ParadiseAdminHub.Panel.onEntry)
        button.hubEntry = entry
        button:initialise()
        button:instantiate()
        if ParadiseEconomy and ParadiseEconomy.styleButton then ParadiseEconomy.styleButton(button) end
        self:addChild(button)
    end
end

function ParadiseAdminHub.Panel:onEntry(button)
    ParadiseAdminHub.runEntry(button and button.hubEntry)
end

function ParadiseAdminHub.Panel:close()
    ParadiseAdminHub.ClosePanel()
end

function ParadiseAdminHub.Panel:new(x, y, width, height)
    local panel = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(panel, self)
    self.__index = self
    panel.title = "Paradise Admin Hub"
    panel.resizable = false
    panel.minimumWidth = 360
    panel.minimumHeight = 200
    if ParadiseEconomy and ParadiseEconomy.styleWindow then ParadiseEconomy.styleWindow(panel) end
    return panel
end
