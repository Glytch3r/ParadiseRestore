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

function ParadiseEconomy.getSquareZoneInfo(sq)
    if not sq then return nil end
    local x, y, z = sq:getX(), sq:getY(), sq:getZ()
    local border = ParadiseDev and ParadiseDev.Zones and ParadiseDev.Zones.Border
    if border and border.getAuthorityAt then
        local zone = border.getAuthorityAt(x + 0.5, y + 0.5, z, 0)
        local zoneId = zone and ParadiseEconomy.normalizeZoneId(zone.id) or nil
        if zoneId then
            local record = (ParadiseEconomy.clientState.zones or {})[zoneId]
            return { id = zoneId, name = tostring((record and record.name) or zone.name or zone.id) }
        end
    end
    for _, shop in ipairs(ParadiseEconomy.getShopsAtSquare(x, y, z)) do
        local zoneId = ParadiseEconomy.normalizeZoneId(shop.zoneId)
        if zoneId then
            local record = (ParadiseEconomy.clientState.zones or {})[zoneId]
            return { id = zoneId, name = tostring((record and record.name) or zoneId) }
        end
    end
    return nil
end

function ParadiseEconomy.getZoneAccounts(zoneId)
    zoneId = ParadiseEconomy.normalizeZoneId(zoneId)
    if not zoneId then return {} end
    local accounts = ParadiseEconomy.clientState.accounts or {}
    local zone = (ParadiseEconomy.clientState.zones or {})[zoneId]
    local list, seen = {}, {}
    local function add(account)
        if type(account) ~= "table" or account.id == nil then return end
        local id = tostring(account.id)
        if seen[id] then return end
        seen[id] = true
        list[#list + 1] = account
    end
    if zone then
        add(accounts[zone.tradeAccountId])
        add(accounts[zone.financeAccountId])
    end
    for _, account in pairs(accounts) do
        if ParadiseEconomy.normalizeZoneId(account.zoneId) == zoneId then add(account) end
    end
    local tradeId = zone and zone.tradeAccountId or nil
    if tradeId then
        for _, account in pairs(accounts) do
            if tostring(account.taxRoute or "") == tostring(tradeId) then add(account) end
        end
    end
    for _, mart in pairs(ParadiseEconomy.clientState.marts or {}) do
        if ParadiseEconomy.normalizeZoneId(mart.zoneId) == zoneId then
            add(accounts[mart.ownerAccountId])
        end
    end
    local ownerKey = zone and ParadiseEconomy.usernameKey(zone.owner) or nil
    if ownerKey then
        for _, account in pairs(accounts) do
            if account.type == "personal" and ParadiseEconomy.usernameKey(account.owner) == ownerKey then add(account) end
        end
    end
    table.sort(list, function(a, b)
        local typeA, typeB = tostring(a.type or ""), tostring(b.type or "")
        if typeA ~= typeB then return typeA < typeB end
        return ParadiseEconomy.getAccountLabel(a) < ParadiseEconomy.getAccountLabel(b)
    end)
    return list
end

function ParadiseEconomy.addZoneAccountsMenu(menu, context, sq)
    local zone = ParadiseEconomy.getSquareZoneInfo(sq)
    local accounts = zone and ParadiseEconomy.getZoneAccounts(zone.id) or {}
    local title = zone and ("Zone Accounts (" .. tostring(#accounts) .. ")") or "Zone Accounts"
    local root = menu:addOption(title)
    local sub = ISContextMenu:getNew(context)
    menu:addSubMenu(root, sub)
    if not zone then
        local none = sub:addOption("No zone at this square")
        none.notAvailable = true
        return sub
    end
    local header = sub:addOption("Zone: " .. tostring(zone.name) .. " [" .. tostring(zone.id) .. "]")
    header.notAvailable = true
    if next(ParadiseEconomy.clientState.accounts or {}) == nil then
        local loading = sub:addOption("Economy data not loaded")
        loading.notAvailable = true
    elseif #accounts == 0 then
        local none = sub:addOption("No linked accounts")
        none.notAvailable = true
    else
        for _, account in ipairs(accounts) do
            local label = ParadiseEconomy.getAccountLabel(account) .. " [" .. tostring(account.id) .. "]"
            local status = ParadiseEconomy.getAccountStatus(account)
            if status ~= "active" then label = label .. " (" .. tostring(status) .. ")" end
            sub:addOption(label, account, function(targ)
                if targ and ParadiseEconomy.AccountPanel and ParadiseEconomy.AccountPanel.OpenPanel then
                    ParadiseEconomy.AccountPanel.OpenPanel(targ)
                end
            end)
        end
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
        if ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(pl) then
            ParadiseEconomy.addZoneAccountsMenu(menu, context, sq)
        end
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
