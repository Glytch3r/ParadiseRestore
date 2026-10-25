if isClient() then return end

ParadiseEconomy = ParadiseEconomy or {}

local SCHEMA_VERSION = 6

local function ensureBucket(tab)
    tab = tab or {}
    tab.jimoleon = math.max(0, math.floor(tonumber(tab.jimoleon) or 0))
    tab.paradisium = math.max(0, math.floor(tonumber(tab.paradisium) or 0))
    return tab
end

function ParadiseEconomy.ensureServerAccount(store)
    store.accounts = store.accounts or {}
    local account = store.accounts[ParadiseEconomy.serverAccountId]
    if not account then
        account = {
            id = ParadiseEconomy.serverAccountId,
            type = "server",
            name = "Server",
            balances = { jimoleon = 0, paradisium = 0 },
            createdAt = os.time(),
        }
        store.accounts[ParadiseEconomy.serverAccountId] = account
    end
    account.type = "server"
    account.name = account.name or "Server"
    account.balances = ensureBucket(account.balances)
    return account
end

function ParadiseEconomy.getStore()
    local store = ModData.getOrCreate(ParadiseEconomy.storeName)
    store.accounts = store.accounts or {}
    store.transactions = store.transactions or {}
    store.market = store.market or { tabs = {}, playerListings = {}, nextListingId = 1 }
    store.market.tabs = store.market.tabs or {}
    store.market.playerListings = store.market.playerListings or {}
    store.market.nextListingId = tonumber(store.market.nextListingId) or 1
    store.market.nextItemMartId = tonumber(store.market.nextItemMartId) or 1
    store.personalIndex = store.personalIndex or {}
    store.merchantIndex = store.merchantIndex or {}
    store.nextAccountSerial = tonumber(store.nextAccountSerial) or 1
    store.playerShops = store.playerShops or {}
    store.orphanedPlayerListings = store.orphanedPlayerListings or {}
    store.zones = store.zones or {}
    if not store.playerShopStorageMigrated then
        for _, listing in ipairs(store.market.playerListings) do
            store.orphanedPlayerListings[#store.orphanedPlayerListings + 1] = listing
        end
        store.market.playerListings = {}
        store.playerShopStorageMigrated = true
    end
    local version = tonumber(store.schemaVersion) or 1
    if version < SCHEMA_VERSION then
        if version < 4 then ParadiseEconomy.migrateStore(store) end
        if version < 6 then ParadiseEconomy.migrateAccountIds(store) end
        ParadiseEconomy.migrateMerchantLeases(store)
        store.schemaVersion = SCHEMA_VERSION
    end
    ParadiseEconomy.ensureServerAccount(store)
    return store
end

ParadiseEconomy.accountIdLength = 6
ParadiseEconomy.accountIdAlphabet = "abcdefghjkmnpqrstuvwxyz23456789"

function ParadiseEconomy.generateAccountId(store, taken)
    local alphabet = ParadiseEconomy.accountIdAlphabet
    for _ = 1, 200 do
        local chars = {}
        for int = 1, ParadiseEconomy.accountIdLength do
            local index = ZombRand(1, #alphabet + 1)
            chars[int] = string.sub(alphabet, index, index)
        end
        local id = table.concat(chars)
        if id ~= ParadiseEconomy.serverAccountId
            and not (store and store.accounts and store.accounts[id])
            and not (taken and taken[id]) then
            return id
        end
    end
    return nil
end

function ParadiseEconomy.migrateAccountIds(store)
    store.accounts = store.accounts or {}
    store.zones = store.zones or {}
    store.transactions = store.transactions or {}
    store.orphanedPlayerListings = store.orphanedPlayerListings or {}
    store.market = store.market or {}
    store.market.playerListings = store.market.playerListings or {}
    local idMap = {}
    local accounts = {}
    for oldId, account in pairs(store.accounts) do
        if type(account) == "table" then
            oldId = tostring(oldId)
            local newId = oldId
            if oldId ~= ParadiseEconomy.serverAccountId then
                newId = ParadiseEconomy.generateAccountId(store, accounts) or oldId
            end
            account.id = newId
            accounts[newId] = account
            if newId ~= oldId then idMap[oldId] = newId end
        end
    end
    store.accounts = accounts
    local function remapListing(listing)
        if type(listing) == "table" and listing.merchantAccountId then
            local mapped = idMap[tostring(listing.merchantAccountId)]
            if mapped then listing.merchantAccountId = mapped end
        end
    end
    for _, account in pairs(store.accounts) do
        if account.taxRoute then
            local mapped = idMap[tostring(account.taxRoute)]
            if mapped then account.taxRoute = mapped end
        end
        for _, listing in ipairs(account.listings or {}) do remapListing(listing) end
    end
    for _, listing in ipairs(store.orphanedPlayerListings) do remapListing(listing) end
    for _, listing in ipairs(store.market.playerListings) do remapListing(listing) end
    for _, zone in pairs(store.zones) do
        if zone.tradeAccountId then
            local mapped = idMap[tostring(zone.tradeAccountId)]
            if mapped then zone.tradeAccountId = mapped end
        end
    end
    for _, tx in ipairs(store.transactions) do
        if tx.accountId then
            local mapped = idMap[tostring(tx.accountId)]
            if mapped then tx.accountId = mapped end
        end
        if tx.counterpartyId then
            local mapped = idMap[tostring(tx.counterpartyId)]
            if mapped then tx.counterpartyId = mapped end
        end
    end
    for accountId, account in pairs(store.accounts) do
        if account.type == "trade" and account.zoneId then
            local zone = store.zones[account.zoneId]
            if zone and not store.accounts[tostring(zone.tradeAccountId or "")] then zone.tradeAccountId = accountId end
        end
    end
    store.personalIndex = {}
    store.merchantIndex = {}
    for accountId, account in pairs(store.accounts) do
        local key = ParadiseEconomy.usernameKey(account.owner)
        if key then
            if account.type == "personal" then
                if not store.personalIndex[key] then store.personalIndex[key] = accountId end
            elseif account.type == "merchant" and account.zoneId then
                store.merchantIndex[account.zoneId .. "|" .. key] = accountId
            end
        end
    end
    return store
end

function ParadiseEconomy.resolveZoneIdByTitle(title)
    local key = ParadiseEconomy.tradeZoneKey(title)
    if not key then return nil end
    local store = ModData.getOrCreate(ParadiseEconomy.storeName)
    for id, record in pairs(store.zones or {}) do
        if ParadiseEconomy.tradeZoneKey(record.name) == key then return id end
    end
    local engine = ParadiseDev and ParadiseDev.Zones and ParadiseDev.Zones.Engine or nil
    for id, zone in pairs(engine and engine.zones or {}) do
        if ParadiseEconomy.tradeZoneKey(zone.name) == key then return id end
    end
    return nil
end

function ParadiseEconomy.seedTradeItemMart(store, account)
    if type(store) ~= "table" or type(account) ~= "table" then return end
    account.itemMart = account.itemMart or {}
    if account.itemMartSeeded then return end
    store.market = store.market or {}
    local market = store.market
    market.nextItemMartId = tonumber(market.nextItemMartId) or 1
    for _, tab in ipairs(market.tabs or {}) do
        for _, listing in ipairs(tab.listings or {}) do
            local currency = ParadiseEconomy.normalizeCurrency(listing.currency)
            local price = ParadiseEconomy.normalizeAmount(listing.price)
            local direction = listing.direction == "sell" and "sell" or listing.direction == "buy" and "buy" or nil
            if listing.fullType and currency and price and direction then
                local int = tonumber(market.nextItemMartId) or 1
                market.nextItemMartId = int + 1
                account.itemMart[#account.itemMart + 1] = {
                    id = "item-" .. tostring(int),
                    category = tostring(tab.name or "General"),
                    fullType = listing.fullType,
                    direction = direction,
                    currency = currency,
                    price = price,
                }
            end
        end
    end
    account.itemMartSeeded = true
end

function ParadiseEconomy.migrateStore(store)
    store.accounts = store.accounts or {}
    store.market = store.market or { tabs = {} }
    store.market.tabs = store.market.tabs or {}
    store.market.nextItemMartId = tonumber(store.market.nextItemMartId) or 1
    store.zones = store.zones or {}
    store.transactions = store.transactions or {}
    store.personalIndex = {}
    local accounts = {}
    local idMap = {}
    local personals = {}

    local function mergeBucket(target, source)
        target = ensureBucket(target)
        if type(source) == "table" then
            target.jimoleon = target.jimoleon + ParadiseEconomy.getBalance(source, "jimoleon")
            target.paradisium = target.paradisium + ParadiseEconomy.getBalance(source, "paradisium")
        end
        return target
    end

    local function legacyOwner(account, oldId)
        local owner = ParadiseEconomy.normalizeUsername(account.owner or account.username)
        if owner then return owner end
        local idString = tostring(oldId)
        local legacy = idString:match("^p:(.+)$") or idString
        return ParadiseEconomy.normalizeUsername(legacy)
    end

    for oldId, account in pairs(store.accounts) do
        if type(account) == "table" and (account.type == "personal" or not account.type) then
            local owner = legacyOwner(account, oldId)
            local key = ParadiseEconomy.usernameKey(owner)
            if key then
                local entry = personals[key]
                if not entry then
                    entry = {
                        owner = owner,
                        title = ParadiseEconomy.normalizeTradeZoneTitle(account.title) or owner,
                        digital = { jimoleon = 0, paradisium = 0 },
                        onhand = { jimoleon = 0, paradisium = 0 },
                        createdAt = tonumber(account.createdAt) or os.time(),
                        steamid = account.steamid,
                        oldIds = {},
                    }
                    personals[key] = entry
                end
                mergeBucket(entry.digital, account.digital)
                mergeBucket(entry.digital, account.online)
                mergeBucket(entry.digital, account)
                mergeBucket(entry.onhand, account.onhand)
                entry.oldIds[#entry.oldIds + 1] = tostring(oldId)
                local created = tonumber(account.createdAt)
                if created and created < entry.createdAt then entry.createdAt = created end
            end
        else
            accounts[tostring(oldId)] = account
        end
    end

    local keys = {}
    for key in pairs(personals) do keys[#keys + 1] = key end
    table.sort(keys)
    local serial = math.max(1, tonumber(store.nextAccountSerial) or 1)
    for _, key in ipairs(keys) do
        local entry = personals[key]
        local id
        repeat
            id = "p:" .. tostring(serial)
            serial = serial + 1
        until not accounts[id] and not store.accounts[id]
        local personal = {
            id = id,
            type = "personal",
            owner = entry.owner,
            title = entry.title,
            digital = entry.digital,
            onhand = entry.onhand,
            createdAt = entry.createdAt,
        }
        if entry.steamid then personal.steamid = entry.steamid end
        accounts[id] = personal
        store.personalIndex[key] = id
        for _, oldId in ipairs(entry.oldIds) do idMap[oldId] = id end
    end
    store.nextAccountSerial = serial
    store.accounts = accounts

    for _, tx in ipairs(store.transactions) do
        if tx.accountId and idMap[tostring(tx.accountId)] then tx.accountId = idMap[tostring(tx.accountId)] end
        if tx.counterpartyId and idMap[tostring(tx.counterpartyId)] then tx.counterpartyId = idMap[tostring(tx.counterpartyId)] end
    end

    for zoneId, zone in pairs(store.zones) do
        if zone.taxAccountId then
            zone.tradeAccountId = zone.taxAccountId
            zone.taxAccountId = nil
        end
        if zone.isTrade and not zone.tradeAccountId then
            zone.tradeAccountId = ParadiseEconomy.tradeAccountId(zoneId)
        end
    end

    local defaultTax = ParadiseEconomy.getPlayerShopTaxPercent()
    for id, account in pairs(store.accounts) do
        if account.type == "personal" then
            account.title = ParadiseEconomy.normalizeTradeZoneTitle(account.title) or account.owner
            account.digital = ensureBucket(account.digital)
            account.onhand = ensureBucket(account.onhand)
            account.online = nil
        elseif account.type == "tax" or account.type == "trade" then
            local zone = account.zoneId and store.zones[account.zoneId] or nil
            local zoneName = (zone and zone.name) or account.zoneName or account.name or tostring(account.zoneId or id)
            account.type = "trade"
            account.zoneId = account.zoneId or (zone and zone.id)
            account.zoneName = zoneName
            account.tradeId = tostring(zoneName)
            account.title = ParadiseEconomy.normalizeTradeZoneTitle(account.title) or tostring(zoneName)
            account.owner = account.owner or ParadiseEconomy.serverAccountId
            account.tradeTax = ParadiseEconomy.normalizeTradeTaxPercent(account.tradeTax) or defaultTax
            account.digital = ensureBucket(account.digital or account.balances or account.earnings)
            account.itemMart = account.itemMart or {}
            if zone then zone.tradeAccountId = id end
        elseif account.type == "merchant" then
            local zone = account.zoneId and store.zones[account.zoneId] or nil
            local zoneName = tostring(account.zoneName or (zone and zone.name) or account.zoneId or "Trade Zone")
            account.title = ParadiseEconomy.normalizeTradeZoneTitle(account.title)
                or (tostring(account.owner or "Merchant") .. " @ " .. zoneName)
            account.taxRoute = account.taxRoute or (zone and zone.tradeAccountId)
                or (account.zoneId and ParadiseEconomy.tradeAccountId(account.zoneId))
                or ParadiseEconomy.serverAccountId
            account.earnings = ensureBucket(account.earnings)
            account.listings = account.listings or {}
        else
            account.balances = ensureBucket(account.balances)
        end
    end

    local tradeRenames = {}
    for id, account in pairs(store.accounts) do
        if account.type == "trade" and account.zoneId then
            local desired = ParadiseEconomy.tradeAccountId(account.zoneId)
            if desired and id ~= desired then
                tradeRenames[#tradeRenames + 1] = { id = id, desired = desired, account = account }
            end
        end
    end
    for _, entry in ipairs(tradeRenames) do
        local existing = store.accounts[entry.desired]
        if existing and existing ~= entry.account then
            existing.digital = ensureBucket(existing.digital)
            entry.account.digital = ensureBucket(entry.account.digital)
            existing.digital.jimoleon = existing.digital.jimoleon + entry.account.digital.jimoleon
            existing.digital.paradisium = existing.digital.paradisium + entry.account.digital.paradisium
            existing.itemMart = existing.itemMart or {}
            for _, listing in ipairs(entry.account.itemMart or {}) do
                existing.itemMart[#existing.itemMart + 1] = listing
            end
            idMap[entry.id] = entry.desired
            store.accounts[entry.id] = nil
        else
            store.accounts[entry.desired] = entry.account
            store.accounts[entry.id] = nil
            idMap[entry.id] = entry.desired
            entry.account.id = entry.desired
        end
    end

    for zoneId, zone in pairs(store.zones) do
        if zone.tradeAccountId and idMap[zone.tradeAccountId] then
            zone.tradeAccountId = idMap[zone.tradeAccountId]
        end
        if zone.isTrade and zone.tradeAccountId and not store.accounts[zone.tradeAccountId] then
            zone.tradeAccountId = ParadiseEconomy.tradeAccountId(zoneId)
        end
    end

    for _, account in pairs(store.accounts) do
        if account.type == "merchant" and account.taxRoute and idMap[account.taxRoute] then
            account.taxRoute = idMap[account.taxRoute]
        end
    end

    for _, tx in ipairs(store.transactions) do
        if tx.accountId and idMap[tostring(tx.accountId)] then tx.accountId = idMap[tostring(tx.accountId)] end
        if tx.counterpartyId and idMap[tostring(tx.counterpartyId)] then tx.counterpartyId = idMap[tostring(tx.counterpartyId)] end
    end

    for _, account in pairs(store.accounts) do
        if account.type == "trade" then
            ParadiseEconomy.seedTradeItemMart(store, account)
        end
    end

    for zoneKey, zoneRecord in pairs(store.playerShops or {}) do
        if type(zoneRecord) == "table" then
            local title = tostring(zoneRecord.title or zoneKey)
            local zoneId = ParadiseEconomy.normalizeZoneId(ParadiseEconomy.resolveZoneIdByTitle(title))
                or ("legacy_" .. tostring(zoneKey))
            local zone = store.zones[zoneId]
            if not zone then
                zone = { id = zoneId, name = title, isTrade = true, legacy = true, createdAt = os.time() }
                store.zones[zoneId] = zone
            end
            zone.isTrade = true
            zone.tradeAccountId = zone.tradeAccountId or ParadiseEconomy.tradeAccountId(zoneId)
            for userKey, shop in pairs(zoneRecord.shops or {}) do
                if type(shop) == "table" then
                    local owner = ParadiseEconomy.normalizeUsername(shop.owner or userKey) or tostring(userKey)
                    local accountId = ParadiseEconomy.merchantAccountId(zoneId, owner)
                        or ("m:" .. tostring(zoneId) .. ":" .. tostring(userKey))
                    local merchant = store.accounts[accountId]
                    if not merchant then
                        merchant = {
                            id = accountId,
                            type = "merchant",
                            zoneId = zoneId,
                            zoneName = zone.name,
                            owner = owner,
                            title = owner .. " @ " .. tostring(zone.name),
                            taxRoute = zone.tradeAccountId or ParadiseEconomy.serverAccountId,
                            listings = {},
                            earnings = { jimoleon = 0, paradisium = 0 },
                            createdAt = tonumber(shop.createdAt) or os.time(),
                        }
                        store.accounts[accountId] = merchant
                    end
                    merchant.taxRoute = merchant.taxRoute or zone.tradeAccountId or ParadiseEconomy.serverAccountId
                    for _, listing in ipairs(shop.listings or {}) do
                        listing.zoneId = listing.zoneId or zoneId
                        listing.zoneTitle = listing.zoneTitle or zone.name
                        listing.merchantAccountId = merchant.id
                        merchant.listings[#merchant.listings + 1] = listing
                    end
                end
            end
        end
    end
    store.playerShops = {}
    return store
end

function ParadiseEconomy.grantMerchantLease(account, days, now)
    if type(account) ~= "table" or account.type ~= "merchant" then return false end
    days = ParadiseEconomy.normalizeMerchantLeaseDays(days) or ParadiseEconomy.getDefaultMerchantLeaseDays()
    now = tonumber(now) or getTimestampMs()
    account.leaseDays = days
    if days > 0 then
        account.expiresAt = now + days * ParadiseEconomy.merchantLeaseDayMs
        account.leaseStartedAt = now
    else
        account.expiresAt = 0
        account.leaseStartedAt = nil
    end
    account.lastRenewedAt = now
    return true
end

function ParadiseEconomy.migrateMerchantLeases(store)
    store = store or {}
    store.accounts = store.accounts or {}
    local now = getTimestampMs()
    for _, account in pairs(store.accounts) do
        if account.type == "trade" then
            account.merchantLeaseDays = ParadiseEconomy.normalizeMerchantLeaseDays(account.merchantLeaseDays)
                or ParadiseEconomy.getDefaultMerchantLeaseDays()
        end
    end
    for _, account in pairs(store.accounts) do
        if account.type == "merchant" and tonumber(account.expiresAt) == nil then
            local zone = account.zoneId and store.zones and store.zones[account.zoneId] or nil
            local trade = zone and zone.tradeAccountId and store.accounts[zone.tradeAccountId] or nil
            if not trade and account.zoneId then
                local tradeId = ParadiseEconomy.findTradeAccountId(store, account.zoneId)
                trade = tradeId and store.accounts[tradeId] or nil
            end
            ParadiseEconomy.grantMerchantLease(account, ParadiseEconomy.getMerchantLeaseDays(trade), now)
        end
    end
    return store
end

function ParadiseEconomy.getMerchantZoneTrade(account)
    if type(account) ~= "table" or not account.zoneId then return nil end
    return ParadiseEconomy.getTradeAccount(account.zoneId, false)
end

function ParadiseEconomy.ensureMerchantLease(account, now)
    if type(account) ~= "table" or account.type ~= "merchant" then return false end
    if tonumber(account.expiresAt) ~= nil then
        account.expiresAt = math.max(0, math.floor(tonumber(account.expiresAt)))
        return false
    end
    local trade = ParadiseEconomy.getMerchantZoneTrade(account)
    return ParadiseEconomy.grantMerchantLease(account, ParadiseEconomy.getMerchantLeaseDays(trade), now)
end

function ParadiseEconomy.canManageMerchantLease(pl, account)
    if type(account) ~= "table" or account.type ~= "merchant" then return false end
    if ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(pl) then return true end
    if ParadiseEconomy.isAccountOwner(pl, account) then return true end
    local trade = ParadiseEconomy.getMerchantZoneTrade(account)
    return trade ~= nil and ParadiseEconomy.canManageTradeAccount(pl, trade)
end

function ParadiseEconomy.setTradeLeaseDays(trade, days)
    if type(trade) ~= "table" or trade.type ~= "trade" then return 0 end
    days = ParadiseEconomy.normalizeMerchantLeaseDays(days) or ParadiseEconomy.getDefaultMerchantLeaseDays()
    trade.merchantLeaseDays = days
    local now = getTimestampMs()
    local count = 0
    for _, account in pairs(ParadiseEconomy.getStore().accounts) do
        if account.type == "merchant" and account.zoneId == trade.zoneId then
            ParadiseEconomy.grantMerchantLease(account, days, now)
            count = count + 1
        end
    end
    return count
end

function ParadiseEconomy.renewMerchantLease(account, days, now)
    if type(account) ~= "table" or account.type ~= "merchant" then return false, "Merchant account not found" end
    local trade = ParadiseEconomy.getMerchantZoneTrade(account)
    days = ParadiseEconomy.normalizeMerchantLeaseDays(days) or ParadiseEconomy.getMerchantLeaseDays(trade)
    if days <= 0 then return false, "Merchant leases are disabled for this zone" end
    now = tonumber(now) or getTimestampMs()
    local base = math.max(now, tonumber(account.expiresAt) or 0)
    account.leaseDays = days
    account.expiresAt = base + days * ParadiseEconomy.merchantLeaseDayMs
    account.lastRenewedAt = now
    return true, "Merchant lease renewed for " .. ParadiseEconomy.formatMerchantLeaseDuration(account.expiresAt - now)
end

function ParadiseEconomy.setMerchantLeaseState(account, action, now)
    if type(account) ~= "table" or account.type ~= "merchant" then return false, "Merchant account not found" end
    now = tonumber(now) or getTimestampMs()
    ParadiseEconomy.ensureMerchantLease(account, now)
    if action == "expire" then
        account.expiresAt = math.max(1, now - 1)
        if not tonumber(account.leaseDays) or tonumber(account.leaseDays) <= 0 then
            account.leaseDays = ParadiseEconomy.getMerchantLeaseDays(ParadiseEconomy.getMerchantZoneTrade(account))
        end
        return true, "Merchant lease expired"
    elseif action == "clear" then
        account.expiresAt = 0
        account.leaseDays = 0
        account.lastRenewedAt = now
        return true, "Merchant lease removed"
    end
    return false, "Unknown lease action"
end

function ParadiseEconomy.registerZone(zoneId, name, isTrade)
    zoneId = ParadiseEconomy.normalizeZoneId(zoneId)
    if not zoneId then return nil end
    local store = ParadiseEconomy.getStore()
    local zone = store.zones[zoneId] or { id = zoneId, createdAt = os.time() }
    name = tostring(name or ""):match("^%s*(.-)%s*$")
    if name ~= "" then zone.name = name end
    zone.name = zone.name or zoneId
    zone.isTrade = isTrade == true
    zone.removed = nil
    store.zones[zoneId] = zone
    if zone.isTrade then
        zone.tradeAccountId = ParadiseEconomy.ensureTradeAccount(zoneId, zone.name)
    end
    for _, account in pairs(store.accounts) do
        if account.type == "merchant" and account.zoneId == zoneId then
            account.zoneName = zone.name
            account.archived = nil
            if not account.taxRoute or not store.accounts[account.taxRoute] then
                account.taxRoute = zone.tradeAccountId or ParadiseEconomy.serverAccountId
            end
        end
    end
    local trade = zone.tradeAccountId and store.accounts[zone.tradeAccountId] or nil
    if trade then
        trade.zoneName = zone.name
        trade.tradeId = zone.name
        trade.title = trade.title or zone.name
        trade.archived = nil
    end
    return zone
end

function ParadiseEconomy.findTradeAccountId(store, zoneId)
    for accountId, account in pairs(store.accounts or {}) do
        if account.type == "trade" and account.zoneId == zoneId then return accountId end
    end
    return nil
end

function ParadiseEconomy.ensureTradeAccount(zoneId, zoneName)
    zoneId = ParadiseEconomy.normalizeZoneId(zoneId)
    if not zoneId then return nil end
    local store = ParadiseEconomy.getStore()
    local zone = store.zones[zoneId]
    zoneName = tostring(zoneName or ""):match("^%s*(.-)%s*$")
    if zoneName == "" then zoneName = zoneId end
    local id = zone and zone.tradeAccountId or nil
    local account = id and store.accounts[id] or nil
    if not account then
        id = ParadiseEconomy.findTradeAccountId(store, zoneId)
        account = id and store.accounts[id] or nil
    end
    if not account then
        id = ParadiseEconomy.generateAccountId(store)
        if not id then return nil end
        account = {
            id = id,
            type = "trade",
            zoneId = zoneId,
            zoneName = zoneName,
            tradeId = zoneName,
            title = zoneName,
            owner = ParadiseEconomy.serverAccountId,
            tradeTax = ParadiseEconomy.getPlayerShopTaxPercent(),
            digital = { jimoleon = 0, paradisium = 0 },
            itemMart = {},
            createdAt = os.time(),
        }
        store.accounts[id] = account
    end
    if zone then zone.tradeAccountId = id end
    account.type = "trade"
    account.zoneId = zoneId
    account.zoneName = account.zoneName or zoneName
    account.tradeId = zoneName
    account.title = ParadiseEconomy.normalizeTradeZoneTitle(account.title) or zoneName
    account.owner = account.owner or ParadiseEconomy.serverAccountId
    account.tradeTax = ParadiseEconomy.normalizeTradeTaxPercent(account.tradeTax) or ParadiseEconomy.getPlayerShopTaxPercent()
    account.merchantLeaseDays = ParadiseEconomy.normalizeMerchantLeaseDays(account.merchantLeaseDays)
        or ParadiseEconomy.getDefaultMerchantLeaseDays()
    account.digital = ensureBucket(account.digital)
    account.itemMart = account.itemMart or {}
    ParadiseEconomy.seedTradeItemMart(store, account)
    return id
end

function ParadiseEconomy.onZoneChanged(zone)
    if not ParadiseEconomy.isEnabled() then return end
    if not zone or not zone.id then return end
    ParadiseEconomy.registerZone(zone.id, zone.name, zone.features and zone.features.isTrade == true)
    ParadiseEconomy.transmit()
end

function ParadiseEconomy.onZoneRemoved(zoneId)
    if not ParadiseEconomy.isEnabled() then return end
    zoneId = ParadiseEconomy.normalizeZoneId(zoneId)
    if not zoneId then return end
    local store = ParadiseEconomy.getStore()
    local zone = store.zones[zoneId]
    if zone then zone.removed = os.time() end
    local tradeId = zone and zone.tradeAccountId or ParadiseEconomy.findTradeAccountId(store, zoneId)
    local trade = tradeId and store.accounts[tradeId] or nil
    if trade then trade.archived = true end
    for _, account in pairs(store.accounts) do
        if account.type == "merchant" and account.zoneId == zoneId then account.archived = true end
    end
    ParadiseEconomy.transmit()
end

function ParadiseEconomy.ensureAllTradeZoneAccounts()
    local count = 0
    local engine = ParadiseDev and ParadiseDev.Zones and ParadiseDev.Zones.Engine or nil
    for id, zone in pairs(engine and engine.zones or {}) do
        if zone.features and zone.features.isTrade == true then
            ParadiseEconomy.registerZone(id, zone.name, true)
            count = count + 1
        end
    end
    local store = ParadiseEconomy.getStore()
    for id, zone in pairs(store.zones) do
        if zone.isTrade then
            zone.tradeAccountId = ParadiseEconomy.ensureTradeAccount(id, zone.name)
        end
    end
    for _, account in pairs(store.accounts) do
        if account.type == "merchant" then
            if not account.taxRoute or not store.accounts[account.taxRoute] then
                local zone = account.zoneId and store.zones[account.zoneId] or nil
                account.taxRoute = zone and zone.tradeAccountId or ParadiseEconomy.serverAccountId
            end
        end
    end
    ParadiseEconomy.transmit()
    return count
end

function ParadiseEconomy.refreshAccountOwnerCase(account, user)
    if type(account) ~= "table" or not account.owner then return end
    local owner = ParadiseEconomy.normalizeUsername(user)
    if not owner or owner == account.owner then return end
    if ParadiseEconomy.usernameKey(account.owner) ~= ParadiseEconomy.usernameKey(owner) then return end
    local previous = account.owner
    account.owner = owner
    if account.type == "personal" then
        if ParadiseEconomy.usernameKey(account.title) == ParadiseEconomy.usernameKey(previous) then
            account.title = owner
        end
    elseif account.type == "merchant" then
        local zoneName = tostring(account.zoneName or account.zoneId or "")
        if account.title == (tostring(previous) .. " @ " .. zoneName) then
            account.title = tostring(owner) .. " @ " .. zoneName
        end
    end
end

function ParadiseEconomy.getPersonalAccount(user, create)
    local key = ParadiseEconomy.usernameKey(user)
    if not key then return nil end
    local store = ParadiseEconomy.getStore()
    store.personalIndex = store.personalIndex or {}
    local id = store.personalIndex[key]
    local account = id and store.accounts[id] or nil
    if not account then
        for accountId, check in pairs(store.accounts) do
            if check.type == "personal" and ParadiseEconomy.usernameKey(check.owner) == key then
                id = accountId
                account = check
                store.personalIndex[key] = accountId
                break
            end
        end
    end
    if not account and create then
        id = ParadiseEconomy.generateAccountId(store)
        if not id then return nil end
        account = {
            id = id,
            type = "personal",
            owner = ParadiseEconomy.normalizeUsername(user),
            title = ParadiseEconomy.normalizeUsername(user),
            digital = { jimoleon = 0, paradisium = 0 },
            onhand = { jimoleon = 0, paradisium = 0 },
            createdAt = os.time(),
        }
        store.accounts[id] = account
        store.personalIndex[key] = id
    end
    if account then
        account.digital = ensureBucket(account.digital or account.online)
        account.onhand = ensureBucket(account.onhand)
        account.owner = account.owner or ParadiseEconomy.normalizeUsername(user)
        ParadiseEconomy.refreshAccountOwnerCase(account, user)
        account.title = ParadiseEconomy.normalizeTradeZoneTitle(account.title) or account.owner
        account.online = nil
    end
    return account
end

function ParadiseEconomy.rebuildAccountIndexes()
    local store = ParadiseEconomy.getStore()
    store.personalIndex = {}
    store.merchantIndex = {}
    local candidates = {}
    local merchantCandidates = {}
    for accountId, account in pairs(store.accounts or {}) do
        local key = ParadiseEconomy.usernameKey(account.owner)
        if key and account.type == "personal" then
            candidates[key] = candidates[key] or {}
            candidates[key][#candidates[key] + 1] = accountId
        elseif key and account.type == "merchant" and account.zoneId then
            local indexKey = account.zoneId .. "|" .. key
            merchantCandidates[indexKey] = merchantCandidates[indexKey] or {}
            merchantCandidates[indexKey][#merchantCandidates[indexKey] + 1] = accountId
        end
    end
    local indexed, duplicates = 0, 0
    local function pickOldest(ids)
        table.sort(ids, function(a, b)
            local accountA, accountB = store.accounts[a], store.accounts[b]
            local createdA = accountA and tonumber(accountA.createdAt) or math.huge
            local createdB = accountB and tonumber(accountB.createdAt) or math.huge
            if createdA == createdB then return a < b end
            return createdA < createdB
        end)
        return ids[1], #ids - 1
    end
    for key, ids in pairs(candidates) do
        local id, skipped = pickOldest(ids)
        store.personalIndex[key] = id
        indexed = indexed + 1
        duplicates = duplicates + skipped
    end
    for indexKey, ids in pairs(merchantCandidates) do
        local id, skipped = pickOldest(ids)
        store.merchantIndex[indexKey] = id
        indexed = indexed + 1
        duplicates = duplicates + skipped
    end
    return indexed, duplicates
end


function ParadiseEconomy.getMerchantAccount(zoneId, user, create)
    zoneId = ParadiseEconomy.normalizeZoneId(zoneId)
    local owner = ParadiseEconomy.normalizeUsername(user)
    if not zoneId or not owner then return nil end
    local key = ParadiseEconomy.usernameKey(owner)
    local store = ParadiseEconomy.getStore()
    store.merchantIndex = store.merchantIndex or {}
    local indexKey = zoneId .. "|" .. key
    local id = store.merchantIndex[indexKey]
    local account = id and store.accounts[id] or nil
    if not account then
        for accountId, check in pairs(store.accounts) do
            if check.type == "merchant" and check.zoneId == zoneId
                and ParadiseEconomy.usernameKey(check.owner) == key then
                id = accountId
                account = check
                store.merchantIndex[indexKey] = accountId
                break
            end
        end
    end
    if not account and create then
        id = ParadiseEconomy.generateAccountId(store)
        if not id then return nil end
        local zone = store.zones[zoneId]
        local zoneName = tostring(zone and zone.name or zoneId)
        account = {
            id = id,
            type = "merchant",
            zoneId = zoneId,
            zoneName = zoneName,
            owner = owner,
            title = tostring(owner) .. " @ " .. zoneName,
            taxRoute = zone and zone.tradeAccountId or ParadiseEconomy.serverAccountId,
            listings = {},
            earnings = { jimoleon = 0, paradisium = 0 },
            createdAt = os.time(),
        }
        store.accounts[id] = account
        store.merchantIndex[indexKey] = id
    end
    if account then
        account.listings = account.listings or {}
        account.earnings = ensureBucket(account.earnings)
        ParadiseEconomy.refreshAccountOwnerCase(account, owner)
        account.title = ParadiseEconomy.normalizeTradeZoneTitle(account.title)
            or (tostring(account.owner or owner or "Merchant") .. " @ " .. tostring(account.zoneName or zoneId))
        if not account.taxRoute or not store.accounts[account.taxRoute] then
            local zone = store.zones[zoneId]
            account.taxRoute = zone and zone.tradeAccountId or ParadiseEconomy.serverAccountId
        end
        ParadiseEconomy.ensureMerchantLease(account)
    end
    return account
end

function ParadiseEconomy.getTradeAccount(zoneId, create)
    zoneId = ParadiseEconomy.normalizeZoneId(zoneId)
    if not zoneId then return nil end
    local store = ParadiseEconomy.getStore()
    local zone = store.zones[zoneId]
    local id = zone and zone.tradeAccountId or nil
    local account = id and store.accounts[id] or nil
    if not account then
        id = ParadiseEconomy.findTradeAccountId(store, zoneId)
        account = id and store.accounts[id] or nil
        if account and zone then zone.tradeAccountId = id end
    end
    if not account and create then
        local tradeId = ParadiseEconomy.ensureTradeAccount(zoneId, zone and zone.name or zoneId)
        account = tradeId and store.accounts[tradeId] or nil
    end
    return account
end

function ParadiseEconomy.getServerAccount()
    return ParadiseEconomy.ensureServerAccount(ParadiseEconomy.getStore())
end

function ParadiseEconomy.getTradeOrServerAccount(zoneId)
    local account = ParadiseEconomy.getTradeAccount(zoneId, false)
    if account then return account end
    local normalized = ParadiseEconomy.normalizeZoneId(zoneId)
    local zone = normalized and ParadiseEconomy.getStore().zones[normalized] or nil
    if zone and zone.isTrade then return ParadiseEconomy.getTradeAccount(normalized, true) end
    return ParadiseEconomy.getServerAccount()
end

function ParadiseEconomy.getAccount(user, create)
    return ParadiseEconomy.getPersonalAccount(user, create)
end

function ParadiseEconomy.getAccountById(accountId)
    return ParadiseEconomy.getStore().accounts[tostring(accountId or "")]
end

function ParadiseEconomy.getPlayerMerchants(user)
    local key = ParadiseEconomy.usernameKey(user)
    local list = {}
    if not key then return list end
    for _, account in pairs(ParadiseEconomy.getStore().accounts) do
        if account.type == "merchant" and ParadiseEconomy.usernameKey(account.owner) == key then
            ParadiseEconomy.refreshAccountOwnerCase(account, user)
            list[#list + 1] = account
        end
    end
    table.sort(list, function(a, b)
        return tostring(a.zoneName or a.zoneId) .. a.id < tostring(b.zoneName or b.zoneId) .. b.id
    end)
    return list
end

function ParadiseEconomy.getMerchantManagementView(account, now)
    if type(account) ~= "table" or account.type ~= "merchant" then return nil end
    now = tonumber(now) or getTimestampMs()
    return {
        id = account.id,
        zoneId = account.zoneId,
        zoneName = account.zoneName,
        owner = account.owner,
        title = account.title,
        taxRoute = account.taxRoute,
        earnings = account.earnings,
        listingCount = #(account.listings or {}),
        expiresAt = tonumber(account.expiresAt) or 0,
        leaseDays = tonumber(account.leaseDays) or 0,
        lastRenewedAt = tonumber(account.lastRenewedAt) or 0,
        leaseStatus = ParadiseEconomy.getMerchantLeaseStatus(account, now),
        leaseLabel = ParadiseEconomy.getMerchantLeaseLabel(account, now),
        active = not ParadiseEconomy.isMerchantExpired(account, now) and account.archived ~= true,
        archived = account.archived == true,
    }
end

function ParadiseEconomy.getZoneMerchantViews(zoneId, now)
    local views = {}
    zoneId = ParadiseEconomy.normalizeZoneId(zoneId)
    if not zoneId then return views end
    for _, account in pairs(ParadiseEconomy.getStore().accounts) do
        if account.type == "merchant" and account.zoneId == zoneId then
            local view = ParadiseEconomy.getMerchantManagementView(account, now)
            if view then views[#views + 1] = view end
        end
    end
    table.sort(views, function(a, b)
        return tostring(a.title or a.owner or a.id) < tostring(b.title or b.owner or b.id)
    end)
    return views
end

function ParadiseEconomy.isAccountOwner(pl, account)
    if not pl or type(account) ~= "table" or not account.owner then return false end
    local key = ParadiseEconomy.usernameKey(pl:getUsername())
    return key ~= nil and key == ParadiseEconomy.usernameKey(account.owner)
end

function ParadiseEconomy.canManageAccount(pl, account)
    if type(account) ~= "table" then return false end
    if ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(pl) then return true end
    return ParadiseEconomy.isAccountOwner(pl, account)
end

function ParadiseEconomy.canManageTradeAccount(pl, account)
    return type(account) == "table" and account.type == "trade" and ParadiseEconomy.canManageAccount(pl, account)
end

function ParadiseEconomy.getTradePublicView(account)
    if type(account) ~= "table" then return nil end
    return {
        id = account.id,
        zoneId = account.zoneId,
        tradeId = account.tradeId,
        title = account.title,
        owner = account.owner,
        tradeTax = ParadiseEconomy.getTradeTaxPercent(account),
        merchantLeaseDays = ParadiseEconomy.getMerchantLeaseDays(account),
        digital = {
            jimoleon = ParadiseEconomy.getBalance(account.digital, "jimoleon"),
            paradisium = ParadiseEconomy.getBalance(account.digital, "paradisium"),
        },
        itemCount = #(account.itemMart or {}),
        itemMart = account.itemMart or {},
    }
end

function ParadiseEconomy.nextItemMartId()
    local market = ParadiseEconomy.getStore().market
    local int = tonumber(market.nextItemMartId) or 1
    market.nextItemMartId = int + 1
    return "item-" .. tostring(int)
end

function ParadiseEconomy.getTradeItem(trade, fullType, direction, category)
    if type(trade) ~= "table" then return nil end
    for _, listing in ipairs(trade.itemMart or {}) do
        if listing.fullType == fullType and listing.direction == direction
            and (not category or listing.category == category) then
            return listing
        end
    end
    return nil
end

function ParadiseEconomy.saveTradeItem(zoneId, listingId, fullType, direction, currency, price, category)
    local trade = ParadiseEconomy.getTradeAccount(zoneId, false)
    if not trade then return nil, "Trade account not found" end
    fullType = tostring(fullType or "")
    direction = direction == "sell" and "sell" or direction == "buy" and "buy" or nil
    currency = ParadiseEconomy.normalizeCurrency(currency)
    price = ParadiseEconomy.normalizeAmount(price)
    category = tostring(category or "General"):match("^%s*(.-)%s*$")
    if category == "" then category = "General" end
    if #category > 32 then category = category:sub(1, 32) end
    if not ScriptManager.instance:getItem(fullType) or not direction or not currency or not price then
        return nil, "Invalid item mart listing"
    end
    local listing
    for _, check in ipairs(trade.itemMart) do
        if listingId and tostring(check.id) == tostring(listingId) then listing = check end
    end
    if listingId and not listing then return nil, "Listing not found" end
    for _, check in ipairs(trade.itemMart) do
        if check ~= listing and check.fullType == fullType and check.direction == direction and check.category == category then
            return nil, "Duplicate item and action in this category"
        end
    end
    if not listing then
        listing = { id = ParadiseEconomy.nextItemMartId() }
        trade.itemMart[#trade.itemMart + 1] = listing
    end
    listing.fullType = fullType
    listing.direction = direction
    listing.currency = currency
    listing.price = price
    listing.category = category
    return listing, "Item mart listing saved"
end

function ParadiseEconomy.deleteTradeItem(zoneId, listingId)
    local trade = ParadiseEconomy.getTradeAccount(zoneId, false)
    if not trade then return false, "Trade account not found" end
    for index, listing in ipairs(trade.itemMart) do
        if tostring(listing.id) == tostring(listingId) then
            table.remove(trade.itemMart, index)
            return true, "Item mart listing deleted"
        end
    end
    return false, "Listing not found"
end

function ParadiseEconomy.setTradeTitle(zoneId, title)
    local trade = ParadiseEconomy.getTradeAccount(zoneId, false)
    title = ParadiseEconomy.normalizeTradeZoneTitle(title)
    if not trade or not title then return false, "Invalid trade title" end
    trade.title = title
    return true, "Trade account renamed"
end

function ParadiseEconomy.setTradeTax(zoneId, percent)
    local trade = ParadiseEconomy.getTradeAccount(zoneId, false)
    percent = ParadiseEconomy.normalizeTradeTaxPercent(percent)
    if not trade or not percent then return false, "Invalid trade tax" end
    trade.tradeTax = percent
    return true, "Trade tax set to " .. tostring(percent) .. "%"
end

function ParadiseEconomy.setMerchantTitle(accountId, title)
    local account = ParadiseEconomy.getAccountById(accountId)
    title = ParadiseEconomy.normalizeTradeZoneTitle(title)
    if not account or account.type ~= "merchant" or not title then return false, "Invalid merchant title" end
    account.title = title
    return true, "Merchant renamed"
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

function ParadiseEconomy.findItemInContainer(container, itemId, visited)
    if not container then return nil end
    visited = visited or {}
    local key = tostring(container)
    if visited[key] then return nil end
    visited[key] = true
    local items = container:getItems()
    for int = 0, items:size() - 1 do
        local item = items:get(int)
        if tostring(item:getID()) == tostring(itemId) then return item end
        local nested = instanceof(item, "InventoryContainer") and item:getInventory() or nil
        if nested then
            local found = ParadiseEconomy.findItemInContainer(nested, itemId, visited)
            if found then return found end
        end
    end
    return nil
end

function ParadiseEconomy.findCarriedItem(pl, itemId)
    if not pl or not itemId then return nil end
    local item = ParadiseEconomy.findInventoryItem(pl, itemId)
    if item then return item end
    return ParadiseEconomy.findItemInContainer(pl:getInventory(), itemId, {})
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

function ParadiseEconomy.getPlayerListingView(listing, merchant)
    if type(listing) ~= "table" then return nil end
    merchant = merchant or (listing.merchantAccountId and ParadiseEconomy.getAccountById(listing.merchantAccountId)) or nil
    local taxAccount = merchant and merchant.taxRoute and ParadiseEconomy.getAccountById(merchant.taxRoute) or nil
    local now = getTimestampMs()
    return {
        id = listing.id,
        seller = listing.seller,
        itemData = listing.itemData,
        fullType = listing.itemData and listing.itemData.fullType or listing.fullType,
        currency = listing.currency,
        price = listing.price,
        createdAt = listing.createdAt,
        zoneId = listing.zoneId or (merchant and merchant.zoneId),
        zoneTitle = listing.zoneTitle or (merchant and merchant.zoneName),
        merchantAccountId = merchant and merchant.id or listing.merchantAccountId,
        merchantTitle = merchant and merchant.title,
        merchantOwner = merchant and merchant.owner,
        merchantExpiresAt = merchant and tonumber(merchant.expiresAt) or 0,
        merchantLeaseDays = merchant and tonumber(merchant.leaseDays) or 0,
        merchantLeaseStatus = merchant and ParadiseEconomy.getMerchantLeaseStatus(merchant, now) or "none",
        merchantLeaseLabel = merchant and ParadiseEconomy.getMerchantLeaseLabel(merchant, now) or "No expiry",
        merchantArchived = merchant and merchant.archived == true or false,
        expired = merchant and ParadiseEconomy.isMerchantExpired(merchant, now) or false,
        taxPercent = taxAccount and ParadiseEconomy.getTradeTaxPercent(taxAccount) or nil,
    }
end

function ParadiseEconomy.getMerchantListingViews(merchant, includeExpired)
    local listings = {}
    if type(merchant) ~= "table" or merchant.type ~= "merchant" then return listings end
    if not includeExpired and (merchant.archived == true or ParadiseEconomy.isMerchantExpired(merchant)) then
        return listings
    end
    for _, listing in ipairs(merchant.listings or {}) do
        local view = ParadiseEconomy.getPlayerListingView(listing, merchant)
        if view then listings[#listings + 1] = view end
    end
    table.sort(listings, function(a, b)
        local left, right = tonumber(a.createdAt) or 0, tonumber(b.createdAt) or 0
        if left ~= right then return left > right end
        return tostring(a.id) < tostring(b.id)
    end)
    return listings
end

function ParadiseEconomy.getPlayerListingsForZone(zoneId, includeExpired)
    local listings = {}
    zoneId = ParadiseEconomy.normalizeZoneId(zoneId)
    if not zoneId then return listings end
    for _, account in pairs(ParadiseEconomy.getStore().accounts) do
        if account.type == "merchant" and account.zoneId == zoneId then
            for _, view in ipairs(ParadiseEconomy.getMerchantListingViews(account, includeExpired)) do
                listings[#listings + 1] = view
            end
        end
    end
    table.sort(listings, function(a, b)
        local left, right = tonumber(a.createdAt) or 0, tonumber(b.createdAt) or 0
        if left ~= right then return left > right end
        return tostring(a.id) < tostring(b.id)
    end)
    return listings
end

function ParadiseEconomy.findPlayerListing(listingId)
    if not listingId then return nil end
    for _, account in pairs(ParadiseEconomy.getStore().accounts) do
        if account.type == "merchant" then
            for index, listing in ipairs(account.listings or {}) do
                if tostring(listing.id) == tostring(listingId) then return listing, account, index end
            end
        end
    end
    return nil
end

function ParadiseEconomy.postPlayerListing(pl, itemId, currency, price)
    local zone = ParadiseEconomy.getTradeZone(pl)
    if not zone or not zone.id then return false end
    currency = ParadiseEconomy.normalizeCurrency(currency)
    price = ParadiseEconomy.normalizeAmount(price)
    local item = ParadiseEconomy.findCarriedItem(pl, itemId)
    if not item or not currency or not price or ParadiseEconomy.isEquipped(pl, item) then return false end
    local itemData = ParadiseEconomy.ItemData.toData(item)
    if not itemData then return false end
    local zoneRecord = ParadiseEconomy.registerZone(zone.id, zone.name, true)
    local merchant = ParadiseEconomy.getMerchantAccount(zone.id, pl:getUsername(), true)
    if not merchant then return false end
    if merchant.archived == true or ParadiseEconomy.isMerchantExpired(merchant) then
        return false, "Your merchant lease has expired. Renew it in the Tradeshop."
    end
    local listing = ParadiseEconomy.newPlayerListing(
        ParadiseEconomy.nextPlayerListingId(), pl:getUsername(), itemData, currency, price, os.time(),
        zoneRecord and zoneRecord.name or zone.name, zone.id, merchant.id)
    if not listing then return false end
    local cont = item:getContainer()
    if not cont then return false end
    cont:Remove(item)
    sendRemoveItemFromContainer(cont, item)
    merchant.listings[#merchant.listings + 1] = listing
    return listing, merchant
end

function ParadiseEconomy.spawnItemData(pl, itemData, cont)
    local item = ParadiseEconomy.ItemData.cloneItem(itemData)
    if not item then return nil end
    local target = cont or pl:getInventory()
    target:AddItem(item)
    if item.SynchSpawn then item:SynchSpawn() end
    sendAddItemToContainer(target, item)
    return item, target
end

function ParadiseEconomy.resolvePurchaseDestination(pl, destination)
    local inv = pl:getInventory()
    if type(destination) ~= "table" then return inv, "your inventory" end
    local kind = tostring(destination.kind or "")
    if kind == "bag" and destination.itemId then
        local item = ParadiseEconomy.findCarriedItem(pl, destination.itemId)
        local cont = item and instanceof(item, "InventoryContainer") and item:getInventory() or nil
        if cont and cont:isInCharacterInventory(pl) then
            local name = tostring(item:getDisplayName() or item:getName() or "bag")
            return cont, "your " .. name
        end
    elseif kind == "object" then
        local x = math.floor(tonumber(destination.x) or -1)
        local y = math.floor(tonumber(destination.y) or -1)
        local z = math.floor(tonumber(destination.z) or -1)
        local index = tonumber(destination.index)
        local containerIndex = tonumber(destination.containerIndex)
        local sq = x >= 0 and y >= 0 and getSquare(x, y, z) or nil
        if sq and index and containerIndex and math.floor(pl:getZ()) == z and pl:DistTo(x, y) <= 2.5 then
            local objs = sq:getObjects()
            if index >= 0 and index < objs:size() then
                local obj = objs:get(index)
                local cont = obj and obj:getContainerByIndex(containerIndex) or nil
                if cont then return cont, tostring(cont:getType() or "container") end
            end
        end
    end
    return inv, "your inventory"
end

function ParadiseEconomy.buyPlayerListing(pl, listingId, opts)
    opts = type(opts) == "table" and opts or {}
    local listing, merchant, index = ParadiseEconomy.findPlayerListing(listingId)
    if not listing or not merchant then return false, "This listing is no longer available" end
    if merchant.archived == true or ParadiseEconomy.isMerchantExpired(merchant) then
        return false, "This merchant listing has expired"
    end
    if ParadiseEconomy.usernameKey(listing.seller) == ParadiseEconomy.usernameKey(pl:getUsername()) then
        return false, "You cannot buy your own listing"
    end
    local zone = ParadiseEconomy.getTradeZone(pl)
    if not zone or ParadiseEconomy.normalizeZoneId(zone.id) ~= ParadiseEconomy.normalizeZoneId(listing.zoneId or merchant.zoneId) then
        return false, "You must be in the listing's Trade Zone"
    end
    local buyer = ParadiseEconomy.getPersonalAccount(pl:getUsername(), true)
    if not buyer then return false, "No personal account" end
    local useOnHand = opts.payFromOnHand == true
    local bucket = useOnHand and buyer.onhand or buyer.digital
    local bucketName = useOnHand and "onhand" or "digital"
    local balance = ParadiseEconomy.getBalance(bucket, listing.currency)
    if balance < listing.price then
        return false, "Not enough " .. tostring(listing.currency) .. " " .. (useOnHand and "on hand" or "digital")
            .. ". Need " .. tostring(listing.price) .. ", have " .. tostring(balance) .. "."
    end
    local destination, destinationLabel = ParadiseEconomy.resolvePurchaseDestination(pl, opts.destination)
    local item = ParadiseEconomy.spawnItemData(pl, listing.itemData, destination)
    if not item then return false, "Could not create the purchased item" end
    local taxAccount = merchant.taxRoute and ParadiseEconomy.getAccountById(merchant.taxRoute) or nil
    taxAccount = taxAccount or ParadiseEconomy.getTradeOrServerAccount(merchant.zoneId)
    local payout, tax = ParadiseEconomy.getPlayerShopPayout(listing.price, ParadiseEconomy.getTradeTaxPercent(taxAccount))
    ParadiseEconomy.takeBalance(bucket, listing.currency, listing.price)
    if payout > 0 then
        ParadiseEconomy.addBalance(merchant.earnings, listing.currency, payout)
    end
    if tax > 0 then
        ParadiseEconomy.addAccountBalance(taxAccount, listing.currency, tax)
    end
    table.remove(merchant.listings, index)
    local info = {
        itemName = listing.itemData and listing.itemData.name or listing.itemData and listing.itemData.fullType or "item",
        price = listing.price,
        tax = tax,
        total = listing.price,
        currency = listing.currency,
        destination = destinationLabel,
        paidBucket = bucketName,
    }
    return listing, item, tax, payout, merchant, taxAccount, buyer, info
end

function ParadiseEconomy.cancelPlayerListing(pl, listingId)
    local listing, merchant, index = ParadiseEconomy.findPlayerListing(listingId)
    if not listing or not merchant then return false end
    if ParadiseEconomy.usernameKey(listing.seller) ~= ParadiseEconomy.usernameKey(pl:getUsername()) then return false end
    local item = ParadiseEconomy.spawnItemData(pl, listing.itemData)
    if not item then return false end
    table.remove(merchant.listings, index)
    return listing, item, merchant
end

function ParadiseEconomy.collectMerchantEarnings(pl)
    local personal = ParadiseEconomy.getPersonalAccount(pl:getUsername(), true)
    if not personal then return nil end
    local collected = { jimoleon = 0, paradisium = 0 }
    for _, merchant in ipairs(ParadiseEconomy.getPlayerMerchants(pl:getUsername())) do
        for _, currency in ipairs({ "jimoleon", "paradisium" }) do
            local amount = ParadiseEconomy.getBalance(merchant.earnings or {}, currency)
            if amount > 0 and ParadiseEconomy.takeBalance(merchant.earnings, currency, amount) then
                ParadiseEconomy.addBalance(personal.digital, currency, amount)
                collected[currency] = collected[currency] + amount
                ParadiseEconomy.record(pl, "merchant collected", currency, amount, pl:getUsername(), pl:getUsername(),
                    tostring(merchant.title or merchant.zoneName or merchant.zoneId), {
                        accountId = merchant.id,
                        counterpartyId = personal.id,
                        zoneId = merchant.zoneId,
                        bucket = "digital",
                    })
            end
        end
    end
    return collected
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
        .. "|accountId:" .. tostring(tx.accountId or "") .. "|counterpartyId:" .. tostring(tx.counterpartyId or "")
        .. "|zoneId:" .. tostring(tx.zoneId or "") .. "|detail:" .. tostring(tx.detail or "") .. "\n")
    writer:close()
    return true
end

function ParadiseEconomy.record(pl, action, currency, amount, fromUser, toUser, detail, meta)
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
    if type(meta) == "table" then
        tx.accountId = meta.accountId and tostring(meta.accountId) or nil
        tx.counterpartyId = meta.counterpartyId and tostring(meta.counterpartyId) or nil
        tx.zoneId = meta.zoneId and tostring(meta.zoneId) or nil
        tx.bucket = meta.bucket and tostring(meta.bucket) or nil
    end
    local transactions = ParadiseEconomy.getStore().transactions
    transactions[#transactions + 1] = tx
    while #transactions > 5000 do table.remove(transactions, 1) end
    ParadiseEconomy.writeLog(tx)
    return tx
end

function ParadiseEconomy.transferAccounts(fromUser, toUser, currency, amount)
    local from = ParadiseEconomy.getPersonalAccount(fromUser, false)
    local to = ParadiseEconomy.getPersonalAccount(toUser, true)
    if not from or not to or from == to then return false end
    currency = ParadiseEconomy.normalizeCurrency(currency)
    amount = ParadiseEconomy.normalizeAmount(amount)
    if not currency or not amount then return false end
    if not ParadiseEconomy.takeBalance(from.digital, currency, amount) then return false end
    ParadiseEconomy.addBalance(to.digital, currency, amount)
    return true
end

function ParadiseEconomy.transferBetweenAccounts(fromAccount, toAccount, currency, amount, fromBucket, toBucket)
    if not fromAccount or not toAccount or fromAccount == toAccount then return false end
    currency = ParadiseEconomy.normalizeCurrency(currency)
    amount = ParadiseEconomy.normalizeAmount(amount)
    if not currency or not amount then return false end
    fromBucket = ParadiseEconomy.resolveBucket(fromAccount, fromBucket)
    toBucket = ParadiseEconomy.resolveBucket(toAccount, toBucket)
    if not ParadiseEconomy.takeAccountBalance(fromAccount, currency, amount, fromBucket) then return false end
    ParadiseEconomy.addAccountBalance(toAccount, currency, amount, toBucket)
    return true, fromBucket, toBucket
end

function ParadiseEconomy.getTransactions(user, isAdm)
    local rows = {}
    local key = ParadiseEconomy.usernameKey(user)
    local store = ParadiseEconomy.getStore()
    local owned = {}
    if key then
        for id, account in pairs(store.accounts) do
            if ParadiseEconomy.usernameKey(account.owner) == key then owned[id] = true end
        end
    end
    for index = #store.transactions, 1, -1 do
        local tx = store.transactions[index]
        if isAdm or owned[tx.accountId] or owned[tx.counterpartyId] or
            (key and (ParadiseEconomy.usernameKey(tx.from) == key or ParadiseEconomy.usernameKey(tx.to) == key)) then
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
    if item then
        if item.SynchSpawn then item:SynchSpawn() end
        sendAddItemToContainer(pl:getInventory(), item)
    end
    return item, item and ParadiseEconomy.getWalletData(item) or nil
end

function ParadiseEconomy.migrateLegacyPlayerData(pl)
    if not pl or not pl.getModData then return end
    local md = pl:getModData()
    local legacy = md[ParadiseEconomy.playerKey]
    if type(legacy) ~= "table" then return end
    local account = ParadiseEconomy.getPersonalAccount(pl:getUsername(), true)
    local jimoleon = ParadiseEconomy.getBalance(legacy, "jimoleon")
    local paradisium = ParadiseEconomy.getBalance(legacy, "paradisium")
    if account and (jimoleon > 0 or paradisium > 0) then
        if jimoleon > 0 then ParadiseEconomy.addBalance(account.onhand, "jimoleon", jimoleon) end
        if paradisium > 0 then ParadiseEconomy.addBalance(account.onhand, "paradisium", paradisium) end
        ParadiseEconomy.record(pl, "migrated carried funds", "mixed", jimoleon + paradisium,
            pl:getUsername(), pl:getUsername(), "legacy carried balance", { accountId = account.id, bucket = "onhand" })
    end
    md[ParadiseEconomy.playerKey] = nil
    ParadiseEconomy.syncPlayerData(pl)
end

function ParadiseEconomy.sendState(pl, message, extra)
    ParadiseEconomy.migrateLegacyPlayerData(pl)
    local user = pl:getUsername()
    local isAdm = ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(pl) or false
    local store = ParadiseEconomy.getStore()
    local personal = ParadiseEconomy.getPersonalAccount(user, true)
    if personal and getSteamModeActive and getSteamModeActive() then
        personal.steamid = ParadiseEconomy.getSteamIdOrUser(pl)
    end
    local merchants = {}
    for _, merchant in ipairs(ParadiseEconomy.getPlayerMerchants(user)) do
        local view = ParadiseEconomy.getMerchantManagementView(merchant)
        if view then
            view.listings = ParadiseEconomy.getMerchantListingViews(merchant, true)
            merchants[#merchants + 1] = view
        end
    end
    local market = {
        playerListings = {},
        taxDefault = ParadiseEconomy.getPlayerShopTaxPercent(),
    }
    local zone = ParadiseEconomy.getTradeZone(pl)
    if zone and zone.id then
        local zoneRecord = ParadiseEconomy.registerZone(zone.id, zone.name, zone.features and zone.features.isTrade == true)
        local trade = zoneRecord.tradeAccountId and store.accounts[zoneRecord.tradeAccountId] or nil
        market.tradeZoneId = zoneRecord.id
        market.tradeZoneTitle = zoneRecord.name
        market.trade = trade and ParadiseEconomy.getTradePublicView(trade) or nil
        market.itemMart = trade and trade.itemMart or {}
        market.canManage = trade and ParadiseEconomy.canManageTradeAccount(pl, trade) or false
        market.leaseDays = trade and ParadiseEconomy.getMerchantLeaseDays(trade) or nil
        market.playerListings = ParadiseEconomy.getPlayerListingsForZone(zoneRecord.id)
        if market.canManage then
            market.managedMerchants = ParadiseEconomy.getZoneMerchantViews(zoneRecord.id)
            market.managedListings = ParadiseEconomy.getPlayerListingsForZone(zoneRecord.id, true)
        end
    end
    local managedZones = {}
    for _, account in pairs(store.accounts) do
        if account.type == "trade" and account.archived ~= true and ParadiseEconomy.canManageTradeAccount(pl, account) then
            local view = ParadiseEconomy.getTradePublicView(account)
            if view then
                view.managedMerchants = ParadiseEconomy.getZoneMerchantViews(account.zoneId)
                view.managedListings = ParadiseEconomy.getPlayerListingsForZone(account.zoneId, true)
                managedZones[#managedZones + 1] = view
            end
        end
    end
    table.sort(managedZones, function(a, b)
        return tostring(a.title or a.zoneId) < tostring(b.title or b.zoneId)
    end)
    market.managedZones = managedZones
    local payload = {
        personal = personal,
        merchants = merchants,
        transactions = ParadiseEconomy.getTransactions(user, isAdm),
        accounts = isAdm and store.accounts or nil,
        zones = isAdm and store.zones or nil,
        orphanedPlayerListings = isAdm and store.orphanedPlayerListings or nil,
        market = market,
        message = message,
    }
    if type(extra) == "table" then
        for key, value in pairs(extra) do payload[key] = value end
    end
    sendServerCommand(pl, ParadiseEconomy.module, "state", payload)
end

function ParadiseEconomy.sendStateToAll(sourcePl, message, extra)
    local players = getOnlinePlayers()
    for int = 0, players:size() - 1 do
        local pl = players:get(int)
        ParadiseEconomy.sendState(pl, pl == sourcePl and message or nil, pl == sourcePl and extra or nil)
    end
end

function ParadiseEconomy.syncPlayerData(pl)
    if pl and pl.transmitModData then pl:transmitModData() end
end

function ParadiseEconomy.movePlayerAccount(pl, currency, amount, toDigital)
    currency = ParadiseEconomy.normalizeCurrency(currency)
    amount = ParadiseEconomy.normalizeAmount(amount)
    local account = ParadiseEconomy.getPersonalAccount(pl:getUsername(), true)
    if not currency or not amount or not account then return false end
    local from = toDigital and account.onhand or account.digital
    local to = toDigital and account.digital or account.onhand
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
    for _, item in ipairs(found) do
        inv:Remove(item)
        sendRemoveItemFromContainer(inv, item)
    end
    return true
end

function ParadiseEconomy.resolveAccountArg(accountId, username)
    local account = accountId and ParadiseEconomy.getAccountById(accountId) or nil
    if account then return account end
    if username then
        return ParadiseEconomy.getPersonalAccount(username, false)
    end
    return nil
end

function ParadiseEconomy.deleteAccount(accountId)
    accountId = tostring(accountId or "")
    local store = ParadiseEconomy.getStore()
    local account = store.accounts[accountId]
    if not account then return false, "Account not found" end
    if accountId == ParadiseEconomy.serverAccountId then return false, "Server account cannot be deleted" end
    if account.type == "personal" then
        for key, id in pairs(store.personalIndex or {}) do
            if id == accountId then
                store.personalIndex[key] = nil
                break
            end
        end
    elseif account.type == "merchant" then
        for _, listing in ipairs(account.listings or {}) do
            store.orphanedPlayerListings[#store.orphanedPlayerListings + 1] = listing
        end
        for key, id in pairs(store.merchantIndex or {}) do
            if id == accountId then store.merchantIndex[key] = nil end
        end
    elseif account.type == "trade" then
        local zone = store.zones[account.zoneId]
        if zone and zone.tradeAccountId == accountId then zone.tradeAccountId = nil end
        for _, merchant in pairs(store.accounts) do
            if merchant.taxRoute == accountId then merchant.taxRoute = ParadiseEconomy.serverAccountId end
        end
    end
    store.accounts[accountId] = nil
    return true, "Account removed"
end

function ParadiseEconomy.createAccountOfType(accountType, owner, zoneId, name)
    local store = ParadiseEconomy.getStore()
    owner = ParadiseEconomy.normalizeUsername(owner)
    zoneId = ParadiseEconomy.normalizeZoneId(zoneId)
    name = tostring(name or ""):match("^%s*(.-)%s*$")
    if accountType == "personal" then
        if not owner then return nil, "Username is required" end
        local account = ParadiseEconomy.getPersonalAccount(owner, true)
        if not account then return nil, "Account could not be created" end
        return account, "Personal account " .. account.id .. " ready for " .. owner
    elseif accountType == "merchant" then
        if not owner then return nil, "Username is required" end
        local zone = zoneId and store.zones[zoneId] or nil
        if not zone or zone.isTrade ~= true then return nil, "A trade zone is required" end
        local account = ParadiseEconomy.getMerchantAccount(zoneId, owner, true)
        if not account then return nil, "Account could not be created" end
        account.zoneName = zone.name or zoneId
        account.archived = nil
        return account, "Merchant account ready for " .. owner .. " in " .. tostring(account.zoneName)
    elseif accountType == "trade" then
        local zone = zoneId and store.zones[zoneId] or nil
        if not zone or zone.isTrade ~= true then return nil, "A trade zone is required" end
        local id = ParadiseEconomy.ensureTradeAccount(zoneId, zone.name)
        zone.tradeAccountId = id
        local account = id and store.accounts[id] or nil
        if not account then return nil, "Account could not be created" end
        account.archived = nil
        return account, "Trade account ready for " .. tostring(zone.name or zoneId)
    end
    if name == "" then name = owner end
    if not name or name == "" then return nil, "Account name is required" end
    local id = ParadiseEconomy.generateAccountId(store)
    if not id then return nil, "Account could not be created" end
    local account = {
        id = id,
        type = "custom",
        owner = name,
        name = name,
        balances = { jimoleon = 0, paradisium = 0 },
        createdAt = os.time(),
    }
    store.accounts[id] = account
    return account, "Created custom account " .. id
end

function ParadiseEconomy.onClientCommand(module, command, pl, args)
    if module ~= ParadiseEconomy.module or not pl then return end
    if not ParadiseEconomy.isEnabled() then return end
    args = args or {}
    local user = pl:getUsername()
    local currency = ParadiseEconomy.normalizeCurrency(args.currency)
    local amount = ParadiseEconomy.normalizeAmount(args.amount)
    local isAdm = ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(pl) or false
    local message
    local syncAll = false
    local purchaseResult
    if (command == "marketBuy" or command == "marketSell" or command == "playerShopPost" or
        command == "playerShopBuy") and not ParadiseEconomy.canUsePlayerEconomy(pl) then
        if command == "playerShopBuy" and args.source == "drag" then
            purchaseResult = { ok = false, listingId = args.listingId,
                message = "ParadiseMart is only available in a Trade Zone" }
        end
        ParadiseEconomy.sendState(pl, "ParadiseMart is only available in a Trade Zone", { purchase = purchaseResult })
        return
    end
    if command == "requestState" then
        ParadiseEconomy.sendState(pl)
        return
    elseif command == "deposit" and ParadiseEconomy.movePlayerAccount(pl, currency, amount, true) then
        local personal = ParadiseEconomy.getPersonalAccount(user, true)
        ParadiseEconomy.record(pl, "deposited", currency, amount, user, user, "carried to digital", {
            accountId = personal.id, bucket = "digital",
        })
        message = "Deposited " .. amount .. " " .. currency
    elseif command == "withdraw" and ParadiseEconomy.movePlayerAccount(pl, currency, amount, false) then
        local personal = ParadiseEconomy.getPersonalAccount(user, true)
        ParadiseEconomy.record(pl, "withdrew", currency, amount, user, user, "digital to carried", {
            accountId = personal.id, bucket = "onhand",
        })
        message = "Withdrew " .. amount .. " " .. currency
    elseif command == "transfer" then
        local targetUser = ParadiseEconomy.normalizeUsername(args.username)
        if targetUser and ParadiseEconomy.transferAccounts(user, targetUser, currency, amount) then
            local personal = ParadiseEconomy.getPersonalAccount(user, true)
            local target = ParadiseEconomy.getPersonalAccount(targetUser, false)
            ParadiseEconomy.record(pl, "transferred", currency, amount, user, targetUser, "account transfer", {
                accountId = personal.id,
                counterpartyId = target and target.id or nil,
                bucket = "digital",
            })
            message = "Sent " .. amount .. " " .. currency .. " to " .. targetUser
            syncAll = true
        end
    elseif command == "withdrawWallet" then
        local account = ParadiseEconomy.getPersonalAccount(user, true)
        if currency and amount and ParadiseEconomy.getBalance(account.digital, currency) >= amount then
            local item, wallet = ParadiseEconomy.makeWallet(pl)
            if item and wallet and ParadiseEconomy.takeBalance(account.digital, currency, amount) then
                ParadiseEconomy.addBalance(wallet, currency, amount)
                syncItemModData(pl, item)
                ParadiseEconomy.record(pl, "withdrew to wallet", currency, amount, user, user, tostring(item:getID()), {
                    accountId = account.id, bucket = "onhand",
                })
                message = "Placed " .. amount .. " " .. currency .. " in a wallet"
            else
                message = "Could not create a wallet"
            end
        end
    elseif command == "pillage" then
        local item, wallet = ParadiseEconomy.findWallet(pl:getInventory(), args.itemId, true)
        if item and wallet then
            local jimoleon = ParadiseEconomy.getBalance(wallet, "jimoleon")
            local paradisium = ParadiseEconomy.getBalance(wallet, "paradisium")
            local personal = ParadiseEconomy.getPersonalAccount(user, true)
            if jimoleon > 0 then ParadiseEconomy.addBalance(personal.onhand, "jimoleon", jimoleon) end
            if paradisium > 0 then ParadiseEconomy.addBalance(personal.onhand, "paradisium", paradisium) end
            ParadiseEconomy.setBalances(wallet, 0, 0)
            syncItemModData(pl, item)
            ParadiseEconomy.record(pl, "pillaged wallet", "mixed", jimoleon + paradisium, "wallet", user,
                tostring(jimoleon) .. " Jimoleons, " .. tostring(paradisium) .. " Paradisium", {
                    accountId = personal.id, bucket = "onhand",
                })
            sendServerCommand(pl, ParadiseEconomy.module, "say", { message = "I pillaged " .. jimoleon .. " Jimoleons and " .. paradisium .. " Paradisium." })
            message = "Wallet pillaged"
        end
    elseif command == "merchantCollect" then
        local collected = ParadiseEconomy.collectMerchantEarnings(pl)
        if collected and (collected.jimoleon > 0 or collected.paradisium > 0) then
            message = "Collected " .. collected.jimoleon .. " Jimoleons and " .. collected.paradisium .. " Paradisium"
        else
            message = "No merchant earnings to collect"
        end
    elseif command == "tradeSetTitle" then
        local trade = ParadiseEconomy.getTradeAccount(args.zoneId, false)
        if not trade then
            message = "Trade account not found"
        elseif not ParadiseEconomy.canManageTradeAccount(pl, trade) then
            message = "Not allowed to rename this trade account"
        else
            local saved, titleMessage = ParadiseEconomy.setTradeTitle(args.zoneId, args.title)
            message = titleMessage
            syncAll = saved
            if saved then
                ParadiseEconomy.record(pl, "trade renamed", "mixed", 0, user, trade.id, tostring(trade.title), {
                    accountId = trade.id, zoneId = trade.zoneId,
                })
            end
        end
    elseif command == "tradeSetTax" then
        local trade = ParadiseEconomy.getTradeAccount(args.zoneId, false)
        if not trade then
            message = "Trade account not found"
        elseif not ParadiseEconomy.canManageTradeAccount(pl, trade) then
            message = "Not allowed to change this trade tax"
        else
            local saved, taxMessage = ParadiseEconomy.setTradeTax(args.zoneId, args.percent)
            message = taxMessage
            syncAll = saved
            if saved then
                ParadiseEconomy.record(pl, "trade tax set", "mixed", 0, user, trade.id, tostring(trade.tradeTax) .. "%", {
                    accountId = trade.id, zoneId = trade.zoneId,
                })
            end
        end
    elseif command == "tradeSetLeaseDays" then
        local trade = ParadiseEconomy.getTradeAccount(args.zoneId, false)
        local days = ParadiseEconomy.normalizeMerchantLeaseDays(args.days)
        if not trade then
            message = "Trade account not found"
        elseif not ParadiseEconomy.canManageTradeAccount(pl, trade) then
            message = "Not allowed to change this merchant lease"
        elseif days == nil then
            message = "Invalid lease days"
        else
            local count = ParadiseEconomy.setTradeLeaseDays(trade, days)
            message = days == 0 and "Merchant leases disabled for this zone"
                or "Merchant lease set to " .. tostring(days) .. " days for " .. tostring(count) .. " merchants"
            syncAll = true
            ParadiseEconomy.record(pl, "trade lease set", "mixed", 0, user, trade.id,
                tostring(days) .. " days", { accountId = trade.id, zoneId = trade.zoneId })
        end
    elseif command == "merchantRenew" then
        local account = ParadiseEconomy.getAccountById(args.accountId)
        if not account or account.type ~= "merchant" then
            message = "Merchant account not found"
        elseif not ParadiseEconomy.canManageMerchantLease(pl, account) then
            message = "Not allowed to renew this merchant lease"
        else
            local renewed, leaseMessage = ParadiseEconomy.renewMerchantLease(account, args.days)
            message = leaseMessage
            syncAll = renewed
            if renewed then
                ParadiseEconomy.record(pl, "merchant lease renewed", "mixed", 0, user, account.id,
                    tostring(account.leaseDays) .. " days", { accountId = account.id, zoneId = account.zoneId })
            end
        end
    elseif command == "merchantLeaseAction" then
        local account = ParadiseEconomy.getAccountById(args.accountId)
        local action = tostring(args.action or "")
        if not account or account.type ~= "merchant" then
            message = "Merchant account not found"
        elseif not ParadiseEconomy.canManageMerchantLease(pl, account) then
            message = "Not allowed to change this merchant lease"
        else
            local trade = ParadiseEconomy.getMerchantZoneTrade(account)
            if action ~= "expire" and action ~= "clear" then
                message = "Unknown lease action"
            elseif not isAdm and not (trade and ParadiseEconomy.canManageTradeAccount(pl, trade)) then
                message = "Only the trade zone manager can change this lease"
            else
                local changed, leaseMessage = ParadiseEconomy.setMerchantLeaseState(account, action)
                message = leaseMessage
                syncAll = changed
                if changed then
                    ParadiseEconomy.record(pl, "merchant lease " .. action, "mixed", 0, user, account.id,
                        action, { accountId = account.id, zoneId = account.zoneId })
                end
            end
        end
    elseif command == "tradeWithdraw" then
        local trade = ParadiseEconomy.getTradeAccount(args.zoneId, false)
        if not trade then
            message = "Trade account not found"
        elseif not ParadiseEconomy.canManageTradeAccount(pl, trade) then
            message = "Not allowed to withdraw from this trade account"
        elseif not currency or not amount then
            message = "Invalid amount or currency"
        else
            local personal = ParadiseEconomy.getPersonalAccount(user, true)
            if ParadiseEconomy.takeAccountBalance(trade, currency, amount, "digital") then
                ParadiseEconomy.addAccountBalance(personal, currency, amount, "digital")
                ParadiseEconomy.record(pl, "trade withdrawal", currency, amount, trade.id, personal.id, "trade to personal", {
                    accountId = trade.id, counterpartyId = personal.id, zoneId = trade.zoneId, bucket = "digital",
                })
                message = "Withdrew " .. amount .. " " .. currency .. " from the trade account"
                syncAll = true
            else
                message = "Trade account has insufficient funds"
            end
        end
    elseif command == "tradeTransfer" then
        local trade = ParadiseEconomy.getTradeAccount(args.zoneId, false)
        local target = args.targetAccountId and ParadiseEconomy.getAccountById(args.targetAccountId) or nil
        if not target and args.targetUser then
            target = ParadiseEconomy.getPersonalAccount(args.targetUser, false)
        end
        if not trade then
            message = "Trade account not found"
        elseif not ParadiseEconomy.canManageTradeAccount(pl, trade) then
            message = "Not allowed to transfer from this trade account"
        elseif not target or target == trade or not currency or not amount then
            message = "Invalid transfer target or amount"
        elseif ParadiseEconomy.transferBetweenAccounts(trade, target, currency, amount, "digital", nil) then
            ParadiseEconomy.record(pl, "trade transfer", currency, amount, trade.id, target.id, "trade account transfer", {
                accountId = trade.id, counterpartyId = target.id, zoneId = trade.zoneId, bucket = "digital",
            })
            message = "Transferred " .. amount .. " " .. currency .. " from the trade account"
            syncAll = true
        else
            message = "Trade account has insufficient funds"
        end
    elseif command == "tradeItemSave" then
        local trade = ParadiseEconomy.getTradeAccount(args.zoneId, false)
        if not trade then
            message = "Trade account not found"
        elseif not ParadiseEconomy.canManageTradeAccount(pl, trade) then
            message = "Not allowed to manage this item mart"
        else
            local listing
            listing, message = ParadiseEconomy.saveTradeItem(args.zoneId, args.listingId, args.fullType,
                args.direction, currency, ParadiseEconomy.normalizeAmount(args.price or args.amount), args.category)
            syncAll = listing ~= nil
            if listing then
                ParadiseEconomy.record(pl, "item mart listing saved", listing.currency, listing.price, user, trade.id,
                    tostring(listing.category) .. ":" .. listing.direction .. ":" .. listing.fullType, {
                        accountId = trade.id, zoneId = trade.zoneId,
                    })
            end
        end
    elseif command == "tradeItemDelete" then
        local trade = ParadiseEconomy.getTradeAccount(args.zoneId, false)
        if not trade then
            message = "Trade account not found"
        elseif not ParadiseEconomy.canManageTradeAccount(pl, trade) then
            message = "Not allowed to manage this item mart"
        else
            local removed
            removed, message = ParadiseEconomy.deleteTradeItem(args.zoneId, args.listingId)
            syncAll = removed
        end
    elseif command == "merchantSetTitle" then
        local account = ParadiseEconomy.getAccountById(args.accountId)
        if not account then
            message = "Merchant account not found"
        elseif account.type ~= "merchant" then
            message = "Only merchant accounts can be renamed here"
        elseif not ParadiseEconomy.canManageAccount(pl, account) then
            message = "Not allowed to rename this merchant account"
        else
            local saved, titleMessage = ParadiseEconomy.setMerchantTitle(account.id, args.title)
            message = titleMessage
            syncAll = saved
            if saved then
                ParadiseEconomy.record(pl, "merchant renamed", "mixed", 0, user, account.id, tostring(account.title), {
                    accountId = account.id, zoneId = account.zoneId,
                })
            end
        end
    elseif command == "adminSetTradeOwner" and isAdm then
        local trade = ParadiseEconomy.getTradeAccount(args.zoneId, false)
        local owner = ParadiseEconomy.normalizeUsername(args.owner)
        if not trade then
            message = "Trade account not found"
        elseif not owner then
            message = "Invalid owner"
        else
            trade.owner = owner
            message = "Trade account owner set to " .. owner
            syncAll = true
            ParadiseEconomy.record(pl, "admin set trade owner", "mixed", 0, user, trade.id, owner, {
                accountId = trade.id, zoneId = trade.zoneId,
            })
        end
    elseif command == "adminSetTaxRoute" and isAdm then
        local merchant = ParadiseEconomy.getAccountById(args.accountId)
        local route = ParadiseEconomy.getAccountById(args.taxRoute)
        if not merchant or merchant.type ~= "merchant" then
            message = "Merchant account not found"
        elseif not route then
            message = "Tax route account not found"
        elseif route.type == "merchant" then
            message = "Tax route must be a non-merchant account"
        else
            merchant.taxRoute = route.id
            message = "Merchant tax route set to " .. route.id
            syncAll = true
            ParadiseEconomy.record(pl, "admin set merchant tax route", "mixed", 0, user, merchant.id, route.id, {
                accountId = merchant.id, counterpartyId = route.id,
            })
        end
    elseif command == "adminAdjust" and isAdm then
        local account = ParadiseEconomy.resolveAccountArg(args.accountId, args.username)
        if account then
            local bucket = ParadiseEconomy.resolveBucket(account, args.bucket)
            local operation = tostring(args.operation or "add")
            local adjusted
            if operation == "set" then
                local setAmount = ParadiseEconomy.normalizeBalance(args.amount)
                adjusted = setAmount and ParadiseEconomy.setAccountBalance(account, currency, setAmount, bucket)
            elseif operation == "remove" then
                adjusted = ParadiseEconomy.takeAccountBalance(account, currency, amount, bucket)
            else
                adjusted = ParadiseEconomy.addAccountBalance(account, currency, amount, bucket)
            end
            if adjusted then
                ParadiseEconomy.record(pl, "admin " .. operation, currency, args.amount, user, account.id, "account adjustment", {
                    accountId = account.id, bucket = bucket,
                })
                message = "Account updated"
                syncAll = true
            else
                message = "Account adjustment rejected"
            end
        else
            message = "Account not found"
        end
    elseif command == "adminTransfer" and isAdm then
        local from = ParadiseEconomy.resolveAccountArg(args.fromAccountId)
        local to = ParadiseEconomy.resolveAccountArg(args.toAccountId)
        if from and to and ParadiseEconomy.transferBetweenAccounts(from, to, currency, amount, args.fromBucket, args.toBucket) then
            local fromBucket = ParadiseEconomy.resolveBucket(from, args.fromBucket)
            ParadiseEconomy.record(pl, "admin transfer", currency, amount, from.id, to.id, "account reroute", {
                accountId = from.id,
                counterpartyId = to.id,
                bucket = fromBucket,
            })
            message = "Account rerouted"
            syncAll = true
        else
            message = "Reroute rejected"
        end
    elseif command == "adminDelete" and isAdm then
        local account = ParadiseEconomy.resolveAccountArg(args.accountId, args.username)
        if account then
            local removed, deleteMessage = ParadiseEconomy.deleteAccount(account.id)
            ParadiseEconomy.record(pl, "admin deleted account", "mixed", 0, user, account.id, "account removed", {
                accountId = account.id,
            })
            message = deleteMessage
            syncAll = removed
        else
            message = "Account not found"
        end
    elseif command == "adminCreateAccount" and isAdm then
        local account, createMessage = ParadiseEconomy.createAccountOfType(
            tostring(args.accountType or "custom"), args.owner, args.zoneId, args.name)
        message = createMessage
        if account then
            ParadiseEconomy.record(pl, "admin created account", "mixed", 0, user, account.id,
                tostring(account.type) .. ":" .. tostring(account.owner or account.name or account.id), {
                    accountId = account.id,
                })
            syncAll = true
        else
            ParadiseEconomy.sendState(pl, message)
            return
        end
    elseif command == "adminPurgeLedger" and isAdm then
        ParadiseEconomy.getStore().transactions = {}
        ParadiseEconomy.record(pl, "admin purged ledger", "mixed", 0, user, "ledger", "transaction history cleared", {
            accountId = ParadiseEconomy.getPersonalAccount(user, true).id,
        })
        message = "Transaction ledger cleared"
        syncAll = true
    elseif command == "adminRebuildIndex" and isAdm then
        local indexed, duplicates = ParadiseEconomy.rebuildAccountIndexes()
        message = "Rebuilt account indexes: " .. tostring(indexed) .. " linked"
        if duplicates > 0 then message = message .. ", " .. tostring(duplicates) .. " duplicates skipped" end
        syncAll = true
        ParadiseEconomy.record(pl, "admin rebuilt account indexes", "mixed", 0, user, "index", message, {
            accountId = ParadiseEconomy.getPersonalAccount(user, true).id,
        })
    elseif command == "adminSyncZones" and isAdm then
        local count = ParadiseEconomy.ensureAllTradeZoneAccounts()
        message = "Synced " .. tostring(count) .. " trade zone accounts"
        syncAll = true
    elseif command == "marketBuy" then
        local zone = ParadiseEconomy.getTradeZone(pl)
        local trade = zone and ParadiseEconomy.getTradeAccount(zone.id, true) or nil
        local listing = trade and ParadiseEconomy.getTradeItem(trade, tostring(args.fullType or ""), "buy", args.category) or nil
        local quantity = ParadiseEconomy.normalizeAmount(args.quantity) or 1
        if quantity > 100 then quantity = nil end
        local personal = ParadiseEconomy.getPersonalAccount(user, true)
        local total = listing and quantity and listing.price * quantity or nil
        if listing and total and ParadiseEconomy.takeBalance(personal.digital, listing.currency, total) then
            ParadiseEconomy.addBalance(trade.digital, listing.currency, total)
            local inv = pl:getInventory()
            for _ = 1, quantity do
                local item = inv:AddItem(listing.fullType)
                if item then
                    if item.SynchSpawn then item:SynchSpawn() end
                    sendAddItemToContainer(inv, item)
                end
            end
            ParadiseEconomy.record(pl, "market purchase", listing.currency, total, user, tostring(trade.title), quantity .. "x " .. listing.fullType, {
                accountId = personal.id, counterpartyId = trade.id, zoneId = trade.zoneId, bucket = "digital",
            })
            message = "Purchase complete"
            syncAll = true
        elseif listing and total then
            message = "Insufficient digital funds"
        end
    elseif command == "marketSell" then
        local zone = ParadiseEconomy.getTradeZone(pl)
        local trade = zone and ParadiseEconomy.getTradeAccount(zone.id, true) or nil
        local listing = trade and ParadiseEconomy.getTradeItem(trade, tostring(args.fullType or ""), "sell", args.category) or nil
        local quantity = ParadiseEconomy.normalizeAmount(args.quantity) or 1
        if quantity > 100 then quantity = nil end
        local personal = ParadiseEconomy.getPersonalAccount(user, true)
        local total = listing and quantity and listing.price * quantity or nil
        if listing and total and ParadiseEconomy.getBalance(trade.digital, listing.currency) >= total then
            if ParadiseEconomy.removeItems(pl:getInventory(), listing.fullType, quantity) then
                ParadiseEconomy.takeBalance(trade.digital, listing.currency, total)
                ParadiseEconomy.addBalance(personal.digital, listing.currency, total)
                ParadiseEconomy.record(pl, "market sale", listing.currency, total, tostring(trade.title), user, quantity .. "x " .. listing.fullType, {
                    accountId = personal.id, counterpartyId = trade.id, zoneId = trade.zoneId, bucket = "digital",
                })
                message = "Sale complete"
                syncAll = true
            else
                message = "You do not have enough items"
            end
        elseif listing and total then
            message = "The trade account cannot pay for this sale"
        end
    elseif command == "playerShopPost" then
        local listing, merchantOrMessage = ParadiseEconomy.postPlayerListing(pl, args.itemId, currency, amount)
        if listing then
            ParadiseEconomy.record(pl, "player shop posted", listing.currency, listing.price, user, tostring(merchantOrMessage.title),
                listing.id .. ":" .. listing.itemData.fullType, {
                    accountId = merchantOrMessage.id,
                    zoneId = listing.zoneId,
                })
            message = "Item posted in the Tradeshop"
            syncAll = true
        else
            message = merchantOrMessage
        end
    elseif command == "playerShopBuy" then
        local opts = nil
        if args.source == "drag" then
            opts = {
                payFromOnHand = true,
                destination = {
                    kind = args.destKind,
                    itemId = args.destItemId,
                    x = args.destX,
                    y = args.destY,
                    z = args.destZ,
                    index = args.destIndex,
                    containerIndex = args.destContainerIndex,
                },
            }
        end
        local listing, itemOrMessage, tax, payout, merchant, taxAccount, buyer, info =
            ParadiseEconomy.buyPlayerListing(pl, args.listingId, opts)
        if listing then
            ParadiseEconomy.record(pl, "player shop purchase", listing.currency, listing.price, user, listing.seller,
                listing.id .. ":" .. listing.itemData.fullType .. ":tax=" .. tostring(tax) .. ":payout=" .. tostring(payout)
                    .. ":paid=" .. tostring(info.paidBucket), {
                    accountId = buyer.id,
                    counterpartyId = merchant.id,
                    zoneId = merchant.zoneId,
                    bucket = info.paidBucket,
                })
            if tax and tax > 0 then
                ParadiseEconomy.record(pl, "trade tax collected", listing.currency, tax, listing.seller, taxAccount.id,
                    tostring(merchant.title or merchant.zoneName or merchant.zoneId), {
                        accountId = taxAccount.id,
                        counterpartyId = merchant.id,
                        zoneId = merchant.zoneId,
                    })
            end
            message = "Purchased " .. tostring(info.itemName) .. " for " .. tostring(listing.price) .. " "
                .. tostring(listing.currency) .. " (" .. tostring(info.paidBucket) .. ")"
            syncAll = true
            purchaseResult = {
                ok = true,
                listingId = listing.id,
                itemName = info.itemName,
                currency = info.currency,
                price = info.price,
                tax = info.tax,
                total = info.total,
                destination = info.destination,
            }
        else
            message = itemOrMessage
            purchaseResult = { ok = false, listingId = args.listingId, message = itemOrMessage }
        end
    elseif command == "playerShopCancel" then
        local listing, item, merchant = ParadiseEconomy.cancelPlayerListing(pl, args.listingId)
        if listing then
            ParadiseEconomy.record(pl, "player shop cancelled", listing.currency, listing.price, user, user,
                listing.id .. ":" .. listing.itemData.fullType, {
                    accountId = merchant.id,
                    zoneId = merchant.zoneId,
                })
            message = "Listing returned to inventory"
            syncAll = true
        end
    end
    ParadiseEconomy.transmit()
    local extra = purchaseResult and { purchase = purchaseResult } or nil
    if syncAll then ParadiseEconomy.sendStateToAll(pl, message, extra)
    else ParadiseEconomy.sendState(pl, message or "Transaction rejected", extra) end
end
Events.OnClientCommand.Remove(ParadiseEconomy.onClientCommand)
Events.OnClientCommand.Add(ParadiseEconomy.onClientCommand)

function ParadiseEconomy.onCharacterDeath(pl)
    if not ParadiseEconomy.isEnabled() then return end
    if not pl or not instanceof(pl, "IsoPlayer") then return end
    local personal = ParadiseEconomy.getPersonalAccount(pl:getUsername(), true)
    if not personal or not ParadiseEconomy.hasMoney(personal.onhand) then return end
    local item, wallet = ParadiseEconomy.makeWallet(pl)
    if not item or not wallet then return end
    local jimoleon = ParadiseEconomy.getBalance(personal.onhand, "jimoleon")
    local paradisium = ParadiseEconomy.getBalance(personal.onhand, "paradisium")
    ParadiseEconomy.setBalances(wallet, jimoleon, paradisium)
    ParadiseEconomy.setBalances(personal.onhand, 0, 0)
    syncItemModData(pl, item)
    ParadiseEconomy.record(pl, "death wallet", "mixed", jimoleon + paradisium, pl:getUsername(), "wallet",
        tostring(item:getID()), { accountId = personal.id, bucket = "onhand" })
    ParadiseEconomy.transmit()
    ParadiseEconomy.sendState(pl)
end
Events.OnCharacterDeath.Remove(ParadiseEconomy.onCharacterDeath)
Events.OnCharacterDeath.Add(ParadiseEconomy.onCharacterDeath)

function ParadiseEconomy.onCreatePlayer(plNum, pl)
    if not ParadiseEconomy.isEnabled() then return end
    ParadiseEconomy.migrateLegacyPlayerData(pl)
end
Events.OnCreatePlayer.Remove(ParadiseEconomy.onCreatePlayer)
Events.OnCreatePlayer.Add(ParadiseEconomy.onCreatePlayer)

function ParadiseEconomy.onInitGlobalModData()
    if not ParadiseEconomy.isEnabled() then return end
    ParadiseEconomy.getStore()
    ParadiseEconomy.ensureAllTradeZoneAccounts()
end
Events.OnInitGlobalModData.Remove(ParadiseEconomy.onInitGlobalModData)
Events.OnInitGlobalModData.Add(ParadiseEconomy.onInitGlobalModData)

function ParadiseEconomy.onServerStarted()
    if not ParadiseEconomy.isEnabled() then return end
    ParadiseEconomy.getStore()
    ParadiseEconomy.ensureAllTradeZoneAccounts()
end
Events.OnServerStarted.Remove(ParadiseEconomy.onServerStarted)
Events.OnServerStarted.Add(ParadiseEconomy.onServerStarted)
