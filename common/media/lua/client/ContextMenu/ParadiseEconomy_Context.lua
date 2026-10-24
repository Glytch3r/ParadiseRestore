ParadiseEconomy = ParadiseEconomy or {}

function ParadiseEconomy.ensureContextPanels()
    if ParadiseEconomy.OpenPanel and ParadiseEconomy.MartPanel and ParadiseEconomy.MartPanel.OpenPanel and
        ParadiseEconomy.AdminPanel and ParadiseEconomy.AdminPanel.OpenPanel and
        ParadiseEconomy.TradeManagementPanel and ParadiseEconomy.TradeManagementPanel.OpenPanel and
        ParadiseEconomy.AccountBrowser and ParadiseEconomy.AccountBrowser.OpenPanel then return true end
    if ParadisePanels and ParadisePanels.Install then ParadisePanels.Install() end
    return ParadiseEconomy.OpenPanel and ParadiseEconomy.MartPanel and ParadiseEconomy.MartPanel.OpenPanel and
        ParadiseEconomy.AdminPanel and ParadiseEconomy.AdminPanel.OpenPanel and
        ParadiseEconomy.TradeManagementPanel and ParadiseEconomy.TradeManagementPanel.OpenPanel and
        ParadiseEconomy.AccountBrowser and ParadiseEconomy.AccountBrowser.OpenPanel
end

function ParadiseEconomy.addAdminPanelMenu(panelsMenu, context)
    if not ParadiseEconomy.isEnabled() then return end
    if not panelsMenu or not context or not ParadiseEconomy.ensureContextPanels() then return end
    local root = panelsMenu:addOption("Economy")
    local menu = ISContextMenu:getNew(context)
    panelsMenu:addSubMenu(root, menu)
    menu:addOption("Account and Transactions", nil, ParadiseEconomy.OpenPanel)
    menu:addOption("Account Browser", nil, ParadiseEconomy.AccountBrowser.OpenPanel)
    menu:addOption("Admin Accounts", nil, ParadiseEconomy.AdminPanel.OpenPanel)
    if ParadiseEconomy.TablesPanel and ParadiseEconomy.TablesPanel.OpenPanel then
        menu:addOption("Data Tables", nil, ParadiseEconomy.TablesPanel.OpenPanel)
    end
    menu:addOption("Tradeshop", nil, ParadiseEconomy.MartPanel.OpenPanel)
    if ParadiseEconomy.canManageTradeZones and ParadiseEconomy.canManageTradeZones() then
        menu:addOption("Trade Management", nil, ParadiseEconomy.TradeManagementPanel.OpenPanel)
    end
end

function ParadiseEconomy.fillWorldContext(plNum, context, worldObjs, test)
    if test then return end
    if not ParadiseEconomy.isEnabled() then return end
    local pl = getSpecificPlayer(plNum)
    if not pl or not ParadiseEconomy.ensureContextPanels() then return end
    local root = context:addOptionOnTop("Paradise Economy")
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(root, menu)
    menu:addOption("Economy Account", nil, ParadiseEconomy.OpenPanel)
    if ParadiseEconomy.canOpenMart and ParadiseEconomy.canOpenMart(pl) then
        menu:addOption("Tradeshop", nil, ParadiseEconomy.MartPanel.OpenPanel)
    end
    if ParadiseEconomy.canManageTradeZones and ParadiseEconomy.canManageTradeZones() then
        menu:addOption("Trade Management", nil, ParadiseEconomy.TradeManagementPanel.OpenPanel)
    end
    if ParadiseRestore.ContextMenuManager then
        ParadiseRestore.ContextMenuManager.registerParent("world", "Paradise Economy", context, root, menu)
    end
end
Events.OnFillWorldObjectContextMenu.Remove(ParadiseEconomy.fillWorldContext)
Events.OnFillWorldObjectContextMenu.Add(ParadiseEconomy.fillWorldContext)
