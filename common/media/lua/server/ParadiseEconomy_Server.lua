if isClient() then return end

ParadiseEconomy = ParadiseEconomy or {}

function ParadiseEconomy.getStore()
    local store = ModData.getOrCreate(ParadiseEconomy.storeName)
    store.accounts = store.accounts or {}
    store.transactions = store.transactions or {}
    store.market = store.market or { tabs = {} }
    return store
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
    sendServerCommand(pl, ParadiseEconomy.module, "state", {
        account = ParadiseEconomy.getAccount(user, true),
        carried = ParadiseEconomy.getPlayerData(pl),
        transactions = ParadiseEconomy.getTransactions(user, false),
        accounts = isAdm and ParadiseEconomy.getStore().accounts or nil,
        market = ParadiseEconomy.getStore().market,
        message = message,
    })
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
    local tabs = ParadiseEconomy.getStore().market.tabs
    for _, tab in ipairs(tabs) do
        if string.lower(tab.name) == string.lower(name) then return tab end
    end
    if not create then return nil end
    local tab = { name = name, listings = {} }
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
            if args.operation == "remove" then ParadiseEconomy.takeBalance(account, currency, amount)
            else ParadiseEconomy.addBalance(account, currency, amount) end
            ParadiseEconomy.record(pl, "admin " .. tostring(args.operation), currency, amount, user, args.username, "account adjustment")
            message = "Account updated"
        end
    elseif command == "adminDelete" and ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(pl) then
        local key = ParadiseEconomy.usernameKey(args.username)
        local account = key and ParadiseEconomy.getStore().accounts[key] or nil
        if account then
            ParadiseEconomy.getStore().accounts[key] = nil
            ParadiseEconomy.record(pl, "admin deleted account", "mixed", 0, user, account.username, "account removed")
            message = "Account removed"
        end
    elseif command == "adminMarketSave" and ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(pl) then
        local fullType = tostring(args.fullType or "")
        local direction = args.direction == "sell" and "sell" or "buy"
        local scrItem = ScriptManager.instance:getItem(fullType)
        local tab = ParadiseEconomy.getMarketTab(args.tabName, true)
        if scrItem and tab and currency and amount then
            local listing = ParadiseEconomy.getListing(tab.name, fullType, direction)
            if not listing then
                listing = { fullType = fullType, direction = direction }
                tab.listings[#tab.listings + 1] = listing
            end
            listing.currency = currency
            listing.price = amount
            ParadiseEconomy.record(pl, "market listing saved", currency, amount, user, "ParadiseMart", direction .. ":" .. fullType)
            message = "ParadiseMart listing saved"
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
    end
    ParadiseEconomy.transmit()
    ParadiseEconomy.sendState(pl, message or "Transaction rejected")
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
