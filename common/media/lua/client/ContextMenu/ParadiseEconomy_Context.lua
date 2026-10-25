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

function ParadiseEconomy.getContextSquare(worldObjs)
    for _, obj in ipairs(worldObjs or {}) do
        if obj and obj.getSquare then
            local sq = obj:getSquare()
            if sq then return sq end
        end
    end
    return nil
end

function ParadiseEconomy.addShopListMenu(menu, context, title, shops)
    local root = menu:addOption(title)
    local sub = ISContextMenu:getNew(context)
    menu:addSubMenu(root, sub)
    if #shops == 0 then
        local none = sub:addOption("Nothing here")
        none.notAvailable = true
        return sub
    end
    for _, shop in ipairs(shops) do
        local label = tostring(shop.title or shop.id)
        if shop.closed then
            label = label .. " (" .. tostring(shop.statusLabel or "Closed") .. ")"
        end
        local option = sub:addOption(label, shop, function(targ)
            if targ and not targ.closed then ParadiseEconomy.openShop(targ.kind, targ.id) end
        end)
        if shop.closed then option.notAvailable = true end
    end
    return sub
end

function ParadiseEconomy.registerStoreHere(sq)
    if not sq then return end
    ParadiseEconomy.send("registerStore", { x = sq:getX(), y = sq:getY(), z = sq:getZ() })
end

function ParadiseEconomy.createMartHere(sq)
    if not sq then return end
    ParadiseEconomy.send("createMart", { x = sq:getX(), y = sq:getY(), z = sq:getZ() })
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
    local sq = ParadiseEconomy.getContextSquare(worldObjs)
    if sq then
        local stores, marts = {}, {}
        for _, shop in ipairs(ParadiseEconomy.getShopsAtSquare(sq:getX(), sq:getY(), sq:getZ())) do
            if shop.kind == "store" then
                stores[#stores + 1] = shop
            elseif shop.kind == "mart" then
                marts[#marts + 1] = shop
            end
        end
        ParadiseEconomy.addShopListMenu(menu, context, "Merchant Stores", stores)
        ParadiseEconomy.addShopListMenu(menu, context, "Market Listings", marts)
        if ParadiseEconomy.canUsePlayerEconomy(pl) and ParadiseEconomy.getActiveTrade() then
            menu:addOption("Register Merchant Store Here", sq, ParadiseEconomy.registerStoreHere)
        end
        if ParadiseEconomy.canManageTradeZones() then
            menu:addOption("Create Market Here", sq, ParadiseEconomy.createMartHere)
        end
    end
    if ParadiseEconomy.canManageTradeZones() then
        menu:addOption("Trade Management", nil, ParadiseEconomy.TradeManagementPanel.OpenPanel)
    end
    if ParadiseRestore.ContextMenuManager then
        ParadiseRestore.ContextMenuManager.registerParent("world", "Paradise Economy", context, root, menu)
    end
end
Events.OnFillWorldObjectContextMenu.Remove(ParadiseEconomy.fillWorldContext)
Events.OnFillWorldObjectContextMenu.Add(ParadiseEconomy.fillWorldContext)
