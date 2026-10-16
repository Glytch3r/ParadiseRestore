if isClient() then return end

ParadiseEconomy = ParadiseEconomy or {}

function ParadiseEconomy.getStore()
    local store = ModData.getOrCreate(ParadiseEconomy.storeName)
    store.accounts = store.accounts or {}
    store.transactions = store.transactions or {}
    store.market = store.market or { tabs = {}, playerListings = {}, nextListingId = 1 }
    store.market.tabs = store.market.tabs or {}
    store.market.playerListings = store.market.playerListings or {}
    store.market.nextListingId = tonumber(store.market.nextListingId) or 1
    store.market.nextTabId = tonumber(store.market.nextTabId) or 1
    store.market.nextMarketListingId = tonumber(store.market.nextMarketListingId) or 1
    store.playerShops = store.playerShops or {}
    store.orphanedPlayerListings = store.orphanedPlayerListings or {}
    if not store.playerShopStorageMigrated then
        for _, listing in ipairs(store.market.playerListings) do
            store.orphanedPlayerListings[#store.orphanedPlayerListings + 1] = listing
        end
        store.market.playerListings = {}
        store.playerShopStorageMigrated = true
    end
    return store
end

function ParadiseEconomy.nextMarketId(key, prefix)
    local market = ParadiseEconomy.getStore().market
    local int = tonumber(market[key]) or 1
    market[key] = int + 1
    return prefix .. tostring(int)
end

function ParadiseEconomy.ensureMarketIds()
    local market = ParadiseEconomy.getStore().market
    local maxTabId = 0
    local maxListingId = 0
    for _, tab in ipairs(market.tabs) do
        maxTabId = math.max(maxTabId, tonumber(tostring(tab.id or ""):match("^tab%-(%d+)$")) or 0)
        for _, listing in ipairs(tab.listings or {}) do
            maxListingId = math.max(maxListingId, tonumber(tostring(listing.id or ""):match("^listing%-(%d+)$")) or 0)
        end
    end
    market.nextTabId = math.max(tonumber(market.nextTabId) or 1, maxTabId + 1)
    market.nextMarketListingId = math.max(tonumber(market.nextMarketListingId) or 1, maxListingId + 1)
    for _, tab in ipairs(market.tabs) do
        tab.listings = tab.listings or {}
        if not tab.id then tab.id = ParadiseEconomy.nextMarketId("nextTabId", "tab-") end
        for _, listing in ipairs(tab.listings) do
            if not listing.id then listing.id = ParadiseEconomy.nextMarketId("nextMarketListingId", "listing-") end
        end
    end
    return market
end

function ParadiseEconomy.getMarketTabById(id)
    if not id then return nil end
    for _, tab in ipairs(ParadiseEconomy.ensureMarketIds().tabs) do
        if tostring(tab.id) == tostring(id) then return tab end
    end
    return nil
end

function ParadiseEconomy.createMarketTab(name)
    name = tostring(name or ""):match("^%s*(.-)%s*$")
    if name == "" or #name > 32 or ParadiseEconomy.getMarketTab(name, false) then return nil, "Invalid or duplicate tab name" end
    local tab = { id = ParadiseEconomy.nextMarketId("nextTabId", "tab-"), name = name, listings = {} }
    local tabs = ParadiseEconomy.getStore().market.tabs
    tabs[#tabs + 1] = tab
    return tab, "ParadiseMart tab created"
end

function ParadiseEconomy.renameMarketTab(id, name)
    local tab = ParadiseEconomy.getMarketTabById(id)
    name = tostring(name or ""):match("^%s*(.-)%s*$")
    if not tab or name == "" or #name > 32 then return false, "Invalid tab name" end
    local duplicate = ParadiseEconomy.getMarketTab(name, false)
    if duplicate and duplicate ~= tab then return false, "Duplicate tab name" end
    tab.name = name
    return true, "ParadiseMart tab renamed"
end

function ParadiseEconomy.deleteMarketTab(id)
    local tabs = ParadiseEconomy.ensureMarketIds().tabs
    for int, tab in ipairs(tabs) do
        if tostring(tab.id) == tostring(id) then
            table.remove(tabs, int)
            return true, "ParadiseMart tab deleted"
        end
    end
    return false, "Tab not found"
end

function ParadiseEconomy.moveMarketTab(id, delta)
    local tabs = ParadiseEconomy.ensureMarketIds().tabs
    delta = tonumber(delta)
    if delta ~= -1 and delta ~= 1 then return false, "Invalid tab move" end
    for int, tab in ipairs(tabs) do
        if tostring(tab.id) == tostring(id) then
            local dest = int + delta
            if dest < 1 or dest > #tabs then return false, "Tab cannot move farther" end
            tabs[int], tabs[dest] = tabs[dest], tabs[int]
            return true, "ParadiseMart tab moved"
        end
    end
    return false, "Tab not found"
end

function ParadiseEconomy.saveMarketListing(tabId, listingId, fullType, direction, currency, price)
    local tab = ParadiseEconomy.getMarketTabById(tabId)
    fullType = tostring(fullType or "")
    direction = direction == "sell" and "sell" or direction == "buy" and "buy" or nil
    currency = ParadiseEconomy.normalizeCurrency(currency)
    price = ParadiseEconomy.normalizeAmount(price)
    if not tab or not ScriptManager.instance:getItem(fullType) or not direction or not currency or not price then
        return nil, "Invalid ParadiseMart listing"
    end
    local listing
    for _, check in ipairs(tab.listings) do
        if listingId and tostring(check.id) == tostring(listingId) then listing = check end
    end
    if listingId and not listing then return nil, "Listing not found" end
    for _, check in ipairs(tab.listings) do
        if check ~= listing and check.fullType == fullType and check.direction == direction then
            return nil, "Duplicate item and action in this tab"
        end
    end
    if not listing then
        listing = { id = ParadiseEconomy.nextMarketId("nextMarketListingId", "listing-") }
        tab.listings[#tab.listings + 1] = listing
    end
    listing.fullType = fullType
    listing.direction = direction
    listing.currency = currency
    listing.price = price
    return listing, "ParadiseMart listing saved"
end

function ParadiseEconomy.deleteMarketListing(tabId, listingId)
    local tab = ParadiseEconomy.getMarketTabById(tabId)
    if not tab then return false, "Tab not found" end
    for int, listing in ipairs(tab.listings) do
        if tostring(listing.id) == tostring(listingId) then
            table.remove(tab.listings, int)
            return true, "ParadiseMart listing deleted"
        end
    end
    return false, "Listing not found"
end

function ParadiseEconomy.findInventoryItem(pl, itemId)
    if not pl or not itemId then return nil end
    local inv = pl:getInventory()
    if inv.getItemById then
        local item = inv:getItemById(tonumber(itemId) or itemId)
        if item then return item end
    end
    local items = inv:getItems()
    for int = 0, items:size() - 1 do
        local item = items:get(int)
        if tostring(item:getID()) == tostring(itemId) then return item end
    end
    return nil
end

function ParadiseEconomy.isEquipped(pl, item)
    if not pl or not item then return false end
    if pl:getPrimaryHandItem() == item or pl:getSecondaryHandItem() == item then return true end
    local worn = pl:getWornItems()
    for int = 0, worn:size() - 1 do
        if worn:get(int):getItem() == item then return true end
    end
    return false
end

function ParadiseEconomy.nextPlayerListingId()
    local market = ParadiseEconomy.getStore().market
    local id = tostring(os.time()) .. "-" .. tostring(market.nextListingId)
    market.nextListingId = market.nextListingId + 1
    return id
end

function ParadiseEconomy.getPlayerShop(zoneTitle, user, create)
    zoneTitle = ParadiseEconomy.normalizeTradeZoneTitle(zoneTitle)
    local zoneKey = ParadiseEconomy.tradeZoneKey(zoneTitle)
    local userKey = ParadiseEconomy.usernameKey(user)
    if not zoneKey or not userKey then return nil end
    local store = ParadiseEconomy.getStore()
    if not store.playerShops[zoneKey] and create then
        store.playerShops[zoneKey] = { title = ParadiseEconomy.normalizeTradeZoneTitle(zoneTitle), shops = {} }
    end
    local zoneShops = store.playerShops[zoneKey]
    if not zoneShops or zoneShops.title ~= zoneTitle then return nil end
    zoneShops.shops = zoneShops.shops or {}
    if not zoneShops.shops[userKey] and create then
        zoneShops.shops[userKey] = {
            owner = ParadiseEconomy.normalizeUsername(user),
            zoneTitle = zoneShops.title,
            listings = {},
            createdAt = os.time(),
        }
    end
    return zoneShops.shops[userKey]
end

function ParadiseEconomy.getPlayerListingsForZone(zoneTitle)
    local listings = {}
    zoneTitle = ParadiseEconomy.normalizeTradeZoneTitle(zoneTitle)
    local zoneKey = ParadiseEconomy.tradeZoneKey(zoneTitle)
    local zoneShops = zoneKey and ParadiseEconomy.getStore().playerShops[zoneKey] or nil
    if not zoneShops or zoneShops.title ~= zoneTitle then return listings end
    zoneShops.shops = zoneShops.shops or {}
    for _, shop in pairs(zoneShops.shops) do
        shop.listings = shop.listings or {}
        for _, listing in ipairs(shop.listings) do
            listings[#listings + 1] = listing
        end
    end
    return listings
end

function ParadiseEconomy.findPlayerListing(id, zoneTitle)
    zoneTitle = ParadiseEconomy.normalizeTradeZoneTitle(zoneTitle)
    local zoneKey = ParadiseEconomy.tradeZoneKey(zoneTitle)
    local zoneShops = zoneKey and ParadiseEconomy.getStore().playerShops[zoneKey] or nil
    if not zoneShops or zoneShops.title ~= zoneTitle then return nil end
    zoneShops.shops = zoneShops.shops or {}
    for _, shop in pairs(zoneShops.shops) do
        shop.listings = shop.listings or {}
        for index, listing in ipairs(shop.listings) do
            if tostring(listing.id) == tostring(id) then return listing, index, shop end
        end
    end
    return nil
end

function ParadiseEconomy.postPlayerListing(pl, itemId, currency, price)
    local zoneTitle = ParadiseEconomy.getTradeZoneTitle(pl)
    if not zoneTitle then return false end
    currency = ParadiseEconomy.normalizeCurrency(currency)
    price = ParadiseEconomy.normalizeAmount(price)
    local item = ParadiseEconomy.findInventoryItem(pl, itemId)
    if not item or not currency or not price or ParadiseEconomy.isEquipped(pl, item) then return false end
    local itemData = ParadiseEconomy.ItemData.toData(item)
    if not itemData then return false end
    local listing = ParadiseEconomy.newPlayerListing(
        ParadiseEconomy.nextPlayerListingId(), pl:getUsername(), itemData, currency, price, os.time(), zoneTitle)
    if not listing then return false end
    local shop = ParadiseEconomy.getPlayerShop(zoneTitle, pl:getUsername(), true)
    if not shop then return false end
    local cont = item:getContainer()
    if not cont then return false end
    cont:Remove(item)
    sendRemoveItemFromContainer(cont, item)
    shop.listings[#shop.listings + 1] = listing
    return listing
end

function ParadiseEconomy.spawnItemData(pl, itemData)
    local item = ParadiseEconomy.ItemData.cloneItem(itemData)
    if not item then return nil end
    local inv = pl:getInventory()
    inv:AddItem(item)
    if item.SynchSpawn then item:SynchSpawn() end
    sendAddItemToContainer(inv, item)
    return item
end

function ParadiseEconomy.buyPlayerListing(pl, listingId)
    local zoneTitle = ParadiseEconomy.getTradeZoneTitle(pl)
    if not zoneTitle then return false end
    local listing, index, shop = ParadiseEconomy.findPlayerListing(listingId, zoneTitle)
    if not listing or ParadiseEconomy.usernameKey(listing.seller) == ParadiseEconomy.usernameKey(pl:getUsername()) then return false end
    local buyer = ParadiseEconomy.getAccount(pl:getUsername(), true)
    if ParadiseEconomy.getBalance(buyer, listing.currency) < listing.price then return false end
    local item = ParadiseEconomy.spawnItemData(pl, listing.itemData)
    if not item then return false end
    local payout, tax = ParadiseEconomy.getPlayerShopPayout(listing.price)
    ParadiseEconomy.takeBalance(buyer, listing.currency, listing.price)
    if payout > 0 then ParadiseEconomy.addBalance(ParadiseEconomy.getAccount(listing.seller, true), listing.currency, payout) end
    table.remove(shop.listings, index)
    return listing, item, tax, payout
end

function ParadiseEconomy.cancelPlayerListing(pl, listingId)
    local zoneTitle = ParadiseEconomy.getTradeZoneTitle(pl)
    if not zoneTitle then return false end
    local listing, index, shop = ParadiseEconomy.findPlayerListing(listingId, zoneTitle)
    if not listing or ParadiseEconomy.usernameKey(listing.seller) ~= ParadiseEconomy.usernameKey(pl:getUsername()) then return false end
    local item = ParadiseEconomy.spawnItemData(pl, listing.itemData)
    if not item then return false end
    table.remove(shop.listings, index)
    return listing, item
end

function ParadiseEconomy.getAccount(user, create)
    local key = ParadiseEconomy.usernameKey(user)
    if not key then return nil end
    local store = ParadiseEconomy.getStore()
    if not store.accounts[key] and create then store.accounts[key] = ParadiseEconomy.newAccount(user) end
    return store.accounts[key]
end

function ParadiseEconomy.getSteamIdOrUser(pl)
    if getSteamModeActive and getSteamModeActive() then
        local id = pl and pl.getSteamID and pl:getSteamID() or nil
        if id and tostring(id) ~= "" and tostring(id) ~= "0" then return tostring(id) end
    end
    return pl and pl.getUsername and pl:getUsername() or nil
end

function ParadiseEconomy.transmit()
    if ModData.transmit then ModData.transmit(ParadiseEconomy.storeName) end
end

function ParadiseEconomy.writeLog(tx)
    local writer = getFileWriter("ParadiseEconomy/" .. os.date("%Y-%m-%d") .. ".log", true, true)
    if not writer then return false end
    writer:write("[ParadiseEconomy]|time:" .. tostring(tx.time) .. "|username:" .. tostring(tx.username or "")
        .. "|steamid:" .. tostring(tx.steamid or "") .. "|action:" .. tostring(tx.action or "")
        .. "|currency:" .. tostring(tx.currency or "") .. "|amount:" .. tostring(tx.amount or 0)
        .. "|from:" .. tostring(tx.from or "") .. "|to:" .. tostring(tx.to or "")
        .. "|detail:" .. tostring(tx.detail or "") .. "\n")
    writer:close()
    return true
end

function ParadiseEconomy.record(pl, action, currency, amount, fromUser, toUser, detail)
    local tx = {
        time = os.time(),
        username = pl and pl:getUsername() or tostring(fromUser or "server"),
        steamid = pl and ParadiseEconomy.getSteamIdOrUser(pl) or "",
        action = tostring(action or ""),
        currency = tostring(currency or ""),
        amount = tonumber(amount) or 0,
        from = tostring(fromUser or ""),
        to = tostring(toUser or ""),
        detail = tostring(detail or ""),
    }
    local transactions = ParadiseEconomy.getStore().transactions
    transactions[#transactions + 1] = tx
    while #transactions > 5000 do table.remove(transactions, 1) end
    ParadiseEconomy.writeLog(tx)
    return tx
end

function ParadiseEconomy.transferAccounts(fromUser, toUser, currency, amount)
    currency = ParadiseEconomy.normalizeCurrency(currency)
    amount = ParadiseEconomy.normalizeAmount(amount)
    local from = ParadiseEconomy.getAccount(fromUser, false)
    local to = ParadiseEconomy.getAccount(toUser, true)
    if not from or not to or not currency or not amount then return false end
    if not ParadiseEconomy.takeBalance(from, currency, amount) then return false end
    ParadiseEconomy.addBalance(to, currency, amount)
    return true
end

function ParadiseEconomy.getTransactions(user, isAdm)
    local rows = {}
    local key = ParadiseEconomy.usernameKey(user)
    for index = #ParadiseEconomy.getStore().transactions, 1, -1 do
        local tx = ParadiseEconomy.getStore().transactions[index]
        if isAdm or ParadiseEconomy.usernameKey(tx.from) == key or ParadiseEconomy.usernameKey(tx.to) == key then
            rows[#rows + 1] = tx
        end
        if #rows >= 500 then break end
    end
    return rows
end

function ParadiseEconomy.findWallet(inv, itemId, requireMoney)
    if not inv or not inv.getItems then return nil end
    local items = inv:getItems()
    for int = 0, items:size() - 1 do
        local item = items:get(int)
        if ParadiseEconomy.isWallet(item) and (not itemId or tostring(item:getID()) == tostring(itemId)) then
            local wallet = ParadiseEconomy.getWalletData(item)
            if not requireMoney or ParadiseEconomy.hasMoney(wallet) then return item, wallet end
        end
    end
    return nil
end

function ParadiseEconomy.makeWallet(pl)
    local item, wallet = ParadiseEconomy.findWallet(pl:getInventory(), nil, false)
    if item and not ParadiseEconomy.hasMoney(wallet) then return item, wallet end
    item = pl:getInventory():AddItem("Base.Wallet")
    return item, ParadiseEconomy.getWalletData(item)
end

function ParadiseEconomy.sendState(pl, message)
    local user = pl:getUsername()
    local isAdm = ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(pl) or false
    local store = ParadiseEconomy.getStore()
    ParadiseEconomy.ensureMarketIds()
    local zoneTitle = ParadiseEconomy.getTradeZoneTitle(pl)
    local market = {
        tabs = store.market.tabs,
        nextListingId = store.market.nextListingId,
        playerListings = ParadiseEconomy.getPlayerListingsForZone(zoneTitle),
        tradeZoneTitle = zoneTitle,
    }
    sendServerCommand(pl, ParadiseEconomy.module, "state", {
        account = ParadiseEconomy.getAccount(user, true),
        carried = ParadiseEconomy.getPlayerData(pl),
        transactions = ParadiseEconomy.getTransactions(user, false),
        accounts = isAdm and store.accounts or nil,
        market = market,
        message = message,
    })
end

function ParadiseEconomy.sendStateToAll(sourcePl, message)
    local players = getOnlinePlayers()
    for int = 0, players:size() - 1 do
        local pl = players:get(int)
        ParadiseEconomy.sendState(pl, pl == sourcePl and message or nil)
    end
end

function ParadiseEconomy.syncPlayerData(pl)
    if pl and pl.transmitModData then pl:transmitModData() end
end

function ParadiseEconomy.movePlayerAccount(pl, currency, amount, toAccount)
    currency = ParadiseEconomy.normalizeCurrency(currency)
    amount = ParadiseEconomy.normalizeAmount(amount)
    if not currency or not amount then return false end
    local playerData = ParadiseEconomy.getPlayerData(pl)
    local account = ParadiseEconomy.getAccount(pl:getUsername(), true)
    local from = toAccount and playerData or account
    local to = toAccount and account or playerData
    if not ParadiseEconomy.takeBalance(from, currency, amount) then return false end
    ParadiseEconomy.addBalance(to, currency, amount)
    return true
end

function ParadiseEconomy.removeItems(inv, fullType, amount)
    local found = {}
    local items = inv:getItems()
    for int = items:size() - 1, 0, -1 do
        local item = items:get(int)
        if item:getFullType() == fullType then found[#found + 1] = item end
        if #found >= amount then break end
    end
    if #found < amount then return false end
    for _, item in ipairs(found) do inv:Remove(item) end
    return true
end

function ParadiseEconomy.getMarketTab(name, create)
    name = tostring(name or ""):match("^%s*(.-)%s*$")
    if name == "" or #name > 32 then return nil end
    local tabs = ParadiseEconomy.ensureMarketIds().tabs
    for _, tab in ipairs(tabs) do
        if string.lower(tab.name) == string.lower(name) then return tab end
    end
    if not create then return nil end
    local tab = { id = ParadiseEconomy.nextMarketId("nextTabId", "tab-"), name = name, listings = {} }
    tabs[#tabs + 1] = tab
    return tab
end

function ParadiseEconomy.getListing(tabName, fullType, direction)
    local tab = ParadiseEconomy.getMarketTab(tabName, false)
    if not tab then return nil end
    for _, listing in ipairs(tab.listings) do
        if listing.fullType == fullType and listing.direction == direction then return listing end
    end
    return nil
end

function ParadiseEconomy.onClientCommand(module, command, pl, args)
    if module ~= ParadiseEconomy.module or not pl then return end
    args = args or {}
    local user = pl:getUsername()
    local currency = ParadiseEconomy.normalizeCurrency(args.currency)
    local amount = ParadiseEconomy.normalizeAmount(args.amount)
    local message
    local syncAll = false
    if (command == "marketBuy" or command == "marketSell" or command == "playerShopPost" or
        command == "playerShopBuy" or command == "playerShopCancel") and not ParadiseEconomy.canUsePlayerEconomy(pl) then
        ParadiseEconomy.sendState(pl, "ParadiseMart is only available in a Trade Zone")
        return
    end
    if command == "requestState" then
        ParadiseEconomy.sendState(pl)
        return
    elseif command == "deposit" and ParadiseEconomy.movePlayerAccount(pl, currency, amount, true) then
        ParadiseEconomy.syncPlayerData(pl)
        ParadiseEconomy.record(pl, "deposited", currency, amount, user, user, "carried to account")
        message = "Deposited " .. amount .. " " .. currency
    elseif command == "withdraw" and ParadiseEconomy.movePlayerAccount(pl, currency, amount, false) then
        ParadiseEconomy.syncPlayerData(pl)
        ParadiseEconomy.record(pl, "withdrew", currency, amount, user, user, "account to carried")
        message = "Withdrew " .. amount .. " " .. currency
    elseif command == "transfer" and ParadiseEconomy.transferAccounts(user, args.username, currency, amount) then
        ParadiseEconomy.record(pl, "transferred", currency, amount, user, ParadiseEconomy.normalizeUsername(args.username), "account transfer")
        message = "Sent " .. amount .. " " .. currency .. " to " .. tostring(args.username)
    elseif command == "withdrawWallet" then
        local account = ParadiseEconomy.getAccount(user, true)
        if currency and amount and ParadiseEconomy.takeBalance(account, currency, amount) then
            local item, wallet = ParadiseEconomy.makeWallet(pl)
            ParadiseEconomy.addBalance(wallet, currency, amount)
            ParadiseEconomy.record(pl, "withdrew to wallet", currency, amount, user, user, tostring(item:getID()))
            message = "Placed " .. amount .. " " .. currency .. " in a wallet"
        end
    elseif command == "pillage" then
        local item, wallet = ParadiseEconomy.findWallet(pl:getInventory(), args.itemId, true)
        if item and wallet then
            local jimoleon = ParadiseEconomy.getBalance(wallet, "jimoleon")
            local paradisium = ParadiseEconomy.getBalance(wallet, "paradisium")
            local carried = ParadiseEconomy.getPlayerData(pl)
            if jimoleon > 0 then ParadiseEconomy.addBalance(carried, "jimoleon", jimoleon) end
            if paradisium > 0 then ParadiseEconomy.addBalance(carried, "paradisium", paradisium) end
            ParadiseEconomy.setBalances(wallet, 0, 0)
            ParadiseEconomy.syncPlayerData(pl)
            ParadiseEconomy.record(pl, "pillaged wallet", "mixed", jimoleon + paradisium, "wallet", user,
                tostring(jimoleon) .. " Jimoleons, " .. tostring(paradisium) .. " Paradisium")
            sendServerCommand(pl, ParadiseEconomy.module, "say", { message = "I pillaged " .. jimoleon .. " Jimoleons and " .. paradisium .. " Paradisium." })
            message = "Wallet pillaged"
        end
    elseif command == "adminAdjust" and ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(pl) then
        local account = ParadiseEconomy.getAccount(args.username, true)
        if account and currency and amount then
            local adjusted = args.operation == "add" and ParadiseEconomy.addBalance(account, currency, amount) or
                args.operation == "remove" and ParadiseEconomy.takeBalance(account, currency, amount)
            if adjusted then
                ParadiseEconomy.record(pl, "admin " .. tostring(args.operation), currency, amount, user, args.username, "account adjustment")
                message = "Account updated"
            else
                message = "Account adjustment rejected"
            end
        end
    elseif command == "adminDelete" and ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(pl) then
        local key = ParadiseEconomy.usernameKey(args.username)
        local account = key and ParadiseEconomy.getStore().accounts[key] or nil
        if account then
            ParadiseEconomy.getStore().accounts[key] = nil
            ParadiseEconomy.record(pl, "admin deleted account", "mixed", 0, user, account.username, "account removed")
            message = "Account removed"
        end
    elseif command == "adminMarketCreateTab" and ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(pl) then
        local tab
        tab, message = ParadiseEconomy.createMarketTab(args.tabName)
        syncAll = tab ~= nil
    elseif command == "adminMarketRenameTab" and ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(pl) then
        syncAll, message = ParadiseEconomy.renameMarketTab(args.tabId, args.tabName)
    elseif command == "adminMarketDeleteTab" and ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(pl) then
        syncAll, message = ParadiseEconomy.deleteMarketTab(args.tabId)
    elseif command == "adminMarketMoveTab" and ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(pl) then
        syncAll, message = ParadiseEconomy.moveMarketTab(args.tabId, args.delta)
    elseif command == "adminMarketSaveListing" and ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(pl) then
        local listing
        listing, message = ParadiseEconomy.saveMarketListing(args.tabId, args.listingId, args.fullType, args.direction, currency, amount)
        syncAll = listing ~= nil
        if listing then
            ParadiseEconomy.record(pl, "market listing saved", listing.currency, listing.price, user, "ParadiseMart", listing.direction .. ":" .. listing.fullType)
        end
    elseif command == "adminMarketDeleteListing" and ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(pl) then
        syncAll, message = ParadiseEconomy.deleteMarketListing(args.tabId, args.listingId)
    elseif command == "adminMarketSave" and ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(pl) then
        local fullType = tostring(args.fullType or "")
        local direction = args.direction == "sell" and "sell" or "buy"
        local scrItem = ScriptManager.instance:getItem(fullType)
        local tab = ParadiseEconomy.getMarketTab(args.tabName, true)
        if scrItem and tab and currency and amount then
            local listing
            listing, message = ParadiseEconomy.saveMarketListing(tab.id, nil, fullType, direction, currency, amount)
            syncAll = listing ~= nil
            if listing then ParadiseEconomy.record(pl, "market listing saved", currency, amount, user, "ParadiseMart", direction .. ":" .. fullType) end
        end
    elseif command == "marketBuy" then
        local listing = ParadiseEconomy.getListing(args.tabName, tostring(args.fullType or ""), "buy")
        local quantity = ParadiseEconomy.normalizeAmount(args.quantity) or 1
        if quantity > 100 then quantity = nil end
        local account = ParadiseEconomy.getAccount(user, true)
        local total = listing and quantity and listing.price * quantity or nil
        if listing and total and ParadiseEconomy.takeBalance(account, listing.currency, total) then
            for _ = 1, quantity do pl:getInventory():AddItem(listing.fullType) end
            ParadiseEconomy.record(pl, "market purchase", listing.currency, total, user, "ParadiseMart", quantity .. "x " .. listing.fullType)
            message = "Purchase complete"
        end
    elseif command == "marketSell" then
        local listing = ParadiseEconomy.getListing(args.tabName, tostring(args.fullType or ""), "sell")
        local quantity = ParadiseEconomy.normalizeAmount(args.quantity) or 1
        if quantity > 100 then quantity = nil end
        local account = ParadiseEconomy.getAccount(user, true)
        if listing and quantity and ParadiseEconomy.removeItems(pl:getInventory(), listing.fullType, quantity) then
            local total = listing.price * quantity
            ParadiseEconomy.addBalance(account, listing.currency, total)
            ParadiseEconomy.record(pl, "market sale", listing.currency, total, "ParadiseMart", user, quantity .. "x " .. listing.fullType)
            message = "Sale complete"
        end
    elseif command == "playerShopPost" then
        local listing = ParadiseEconomy.postPlayerListing(pl, args.itemId, currency, amount)
        if listing then
            ParadiseEconomy.record(pl, "player shop posted", listing.currency, listing.price, user, "ParadiseMart",
                listing.id .. ":" .. listing.itemData.fullType)
            message = "Item posted in ParadiseMart"
            syncAll = true
        end
    elseif command == "playerShopBuy" then
        local listing, item, tax, payout = ParadiseEconomy.buyPlayerListing(pl, args.listingId)
        if listing then
            ParadiseEconomy.record(pl, "player shop purchase", listing.currency, listing.price, user, listing.seller,
                listing.id .. ":" .. listing.itemData.fullType .. ":tax=" .. tostring(tax) .. ":payout=" .. tostring(payout))
            message = "Player shop purchase complete"
            syncAll = true
        end
    elseif command == "playerShopCancel" then
        local listing = ParadiseEconomy.cancelPlayerListing(pl, args.listingId)
        if listing then
            ParadiseEconomy.record(pl, "player shop cancelled", listing.currency, listing.price, user, user,
                listing.id .. ":" .. listing.itemData.fullType)
            message = "Listing returned to inventory"
            syncAll = true
        end
    end
    ParadiseEconomy.transmit()
    if syncAll then ParadiseEconomy.sendStateToAll(pl, message)
    else ParadiseEconomy.sendState(pl, message or "Transaction rejected") end
end
Events.OnClientCommand.Remove(ParadiseEconomy.onClientCommand)
Events.OnClientCommand.Add(ParadiseEconomy.onClientCommand)

function ParadiseEconomy.onCharacterDeath(pl)
    if not pl or not instanceof(pl, "IsoPlayer") then return end
    local carried = ParadiseEconomy.getPlayerData(pl)
    if not ParadiseEconomy.hasMoney(carried) then return end
    local item, wallet = ParadiseEconomy.makeWallet(pl)
    local jimoleon = ParadiseEconomy.getBalance(carried, "jimoleon")
    local paradisium = ParadiseEconomy.getBalance(carried, "paradisium")
    ParadiseEconomy.setBalances(wallet, jimoleon, paradisium)
    ParadiseEconomy.setBalances(carried, 0, 0)
    ParadiseEconomy.syncPlayerData(pl)
    ParadiseEconomy.record(pl, "death wallet", "mixed", jimoleon + paradisium, pl:getUsername(), "wallet",
        tostring(item:getID()))
    ParadiseEconomy.transmit()
end
Events.OnCharacterDeath.Remove(ParadiseEconomy.onCharacterDeath)
Events.OnCharacterDeath.Add(ParadiseEconomy.onCharacterDeath)

function ParadiseEconomy.onInitGlobalModData()
    ParadiseEconomy.getStore()
end
Events.OnInitGlobalModData.Remove(ParadiseEconomy.onInitGlobalModData)
Events.OnInitGlobalModData.Add(ParadiseEconomy.onInitGlobalModData)
