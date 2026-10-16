ParadiseEconomy = ParadiseEconomy or {}

function ParadiseEconomy.ensureContextPanels()
    if ParadiseEconomy.OpenPanel and ParadiseEconomy.MartPanel and ParadiseEconomy.MartPanel.OpenPanel and
        ParadiseEconomy.AdminPanel and ParadiseEconomy.AdminPanel.OpenPanel then return true end
    if ParadisePanels and ParadisePanels.Install then ParadisePanels.Install() end
    return ParadiseEconomy.OpenPanel and ParadiseEconomy.MartPanel and ParadiseEconomy.MartPanel.OpenPanel and
        ParadiseEconomy.AdminPanel and ParadiseEconomy.AdminPanel.OpenPanel
end

function ParadiseEconomy.addAdminPanelMenu(panelsMenu, context)
    if not panelsMenu or not context or not ParadiseEconomy.ensureContextPanels() then return end
    local root = panelsMenu:addOption("Economy")
    local menu = ISContextMenu:getNew(context)
    panelsMenu:addSubMenu(root, menu)
    menu:addOption("Account and Transactions", nil, ParadiseEconomy.OpenPanel)
    menu:addOption("Admin Accounts", nil, ParadiseEconomy.AdminPanel.OpenPanel)
    menu:addOption("ParadiseMart", nil, ParadiseEconomy.MartPanel.OpenPanel)
end

function ParadiseEconomy.fillWorldContext(plNum, context, worldObjs, test)
    if test then return end
    local pl = getSpecificPlayer(plNum)
    if not pl or not ParadiseEconomy.ensureContextPanels() then return end
    local canUse = ParadiseEconomy.canUsePlayerEconomy and ParadiseEconomy.canUsePlayerEconomy(pl)
    if not canUse then return end
    local root = context:addOptionOnTop("Paradise Economy")
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(root, menu)
    menu:addOption("Economy Account", nil, ParadiseEconomy.OpenPanel)
    if ParadiseRestore.ContextMenuManager then
        ParadiseRestore.ContextMenuManager.registerParent("world", "Paradise Economy", context, root, menu)
    end
end
Events.OnFillWorldObjectContextMenu.Remove(ParadiseEconomy.fillWorldContext)
Events.OnFillWorldObjectContextMenu.Add(ParadiseEconomy.fillWorldContext)
