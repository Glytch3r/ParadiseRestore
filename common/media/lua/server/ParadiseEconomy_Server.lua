if isClient() then return end

ParadiseEconomy = ParadiseEconomy or {}

local SCHEMA_VERSION = 9

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

function ParadiseEconomy.ensureFinanceAccount(store, zone)
    store = store or ParadiseEconomy.getStore()
    if type(zone) ~= "table" then
        local zoneId = ParadiseEconomy.normalizeZoneId(zone)
        zone = zoneId and store.zones and store.zones[zoneId] or nil
    end
    if not zone or not zone.id then return nil end
    local id = zone.financeAccountId
    local account = id and store.accounts[id] or nil
    if account and account.type ~= "finance" then account = nil end
    if not account then
        for accountId, check in pairs(store.accounts) do
            if check.type == "finance" and ParadiseEconomy.normalizeZoneId(check.zoneId) == zone.id then
                id = accountId
                account = check
                break
            end
        end
    end
    if not account then
        id = ParadiseEconomy.generateAccountId(store)
        if not id then return nil end
        account = {
            id = id,
            type = "finance",
            zoneId = zone.id,
            zoneName = zone.name,
            tradeId = zone.name,
            title = tostring(zone.name or zone.id) .. " Finance",
            owner = zone.owner or ParadiseEconomy.serverAccountId,
            ownerType = zone.ownerType or "server",
            digital = { jimoleon = 0, paradisium = 0 },
            createdAt = os.time(),
        }
        store.accounts[id] = account
    end
    account.type = "finance"
    account.zoneId = zone.id
    account.zoneName = account.zoneName or zone.name
    account.tradeId = account.tradeId or zone.name
    account.title = account.title or (tostring(zone.name or zone.id) .. " Finance")
    account.owner = zone.owner or account.owner or ParadiseEconomy.serverAccountId
    account.ownerType = zone.ownerType or account.ownerType or "server"
    account.digital = ensureBucket(account.digital)
    zone.financeAccountId = id
    return account
end

function ParadiseEconomy.ensureZoneFinances(store)
    store = store or ParadiseEconomy.getStore()
    store.zones = store.zones or {}
    for _, account in pairs(store.accounts or {}) do
        if account.type == "trade" and account.zoneId and not store.zones[account.zoneId] then
            store.zones[account.zoneId] = {
                id = account.zoneId,
                name = account.title or account.zoneName or account.zoneId,
                isTrade = true,
                createdAt = os.time(),
            }
        end
    end
    for _, zone in pairs(store.zones) do
        if zone.isTrade then
            if not ParadiseEconomy.normalizeUsername(zone.owner) then
                local trade = zone.tradeAccountId and store.accounts[zone.tradeAccountId] or nil
                zone.owner = trade and ParadiseEconomy.normalizeUsername(trade.owner) or ParadiseEconomy.serverAccountId
                zone.ownerType = ParadiseEconomy.usernameKey(zone.owner) == ParadiseEconomy.usernameKey(ParadiseEconomy.serverAccountId)
                    and "server" or "player"
            end
            zone.merchantDailyFee = ParadiseEconomy.normalizeMerchantDailyFee(zone.merchantDailyFee) or 0
            zone.merchantFeeCurrency = ParadiseEconomy.normalizeMerchantFeeCurrency(zone.merchantFeeCurrency) or "jimoleon"
            local finance = ParadiseEconomy.ensureFinanceAccount(store, zone)
            local trade = zone.tradeAccountId and store.accounts[zone.tradeAccountId] or nil
            if trade then
                trade.owner = zone.owner
                trade.ownerType = zone.ownerType
                trade.merchantDailyFee = zone.merchantDailyFee
                trade.merchantFeeCurrency = zone.merchantFeeCurrency
            end
            if finance then
                finance.owner = zone.owner
                finance.ownerType = zone.ownerType
            end
        end
    end
    return store
end

function ParadiseEconomy.normalizeZoneOwner(owner)
    owner = ParadiseEconomy.normalizeUsername(owner)
    if not owner or ParadiseEconomy.usernameKey(owner) == ParadiseEconomy.usernameKey(ParadiseEconomy.serverAccountId) then
        return ParadiseEconomy.serverAccountId, "server"
    end
    return owner, "player"
end

function ParadiseEconomy.getZoneOwnerName(zoneOrTrade)
    if type(zoneOrTrade) ~= "table" then return ParadiseEconomy.serverAccountId end
    return ParadiseEconomy.normalizeZoneOwner(zoneOrTrade.owner)
end

function ParadiseEconomy.getZoneForAccount(account)
    if type(account) ~= "table" or not account.zoneId then return nil end
    local store = ParadiseEconomy.getStore()
    return store.zones and store.zones[account.zoneId] or nil
end

function ParadiseEconomy.syncZoneOwnership(store, zone, owner)
    store = store or ParadiseEconomy.getStore()
    if type(zone) ~= "table" or not zone.id then return nil end
    local normalized, ownerType = ParadiseEconomy.normalizeZoneOwner(owner)
    zone.owner = normalized
    zone.ownerType = ownerType
    zone.merchantDailyFee = ParadiseEconomy.normalizeMerchantDailyFee(zone.merchantDailyFee) or 0
    zone.merchantFeeCurrency = ParadiseEconomy.normalizeMerchantFeeCurrency(zone.merchantFeeCurrency) or "jimoleon"
    local trade = zone.tradeAccountId and store.accounts[zone.tradeAccountId] or nil
    if trade then
        trade.owner = normalized
        trade.ownerType = ownerType
        trade.merchantDailyFee = zone.merchantDailyFee
        trade.merchantFeeCurrency = zone.merchantFeeCurrency
    end
    local finance = ParadiseEconomy.ensureFinanceAccount(store, zone)
    if finance then
        finance.owner = normalized
        finance.ownerType = ownerType
        finance.zoneName = zone.name or finance.zoneName
    end
    return normalized, ownerType
end

function ParadiseEconomy.isZoneOwner(pl, zoneOrTrade)
    if not pl then return false end
    if ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(pl) then return true end
    local owner = ParadiseEconomy.getZoneOwnerName(zoneOrTrade)
    return ParadiseEconomy.usernameKey(pl:getUsername()) == ParadiseEconomy.usernameKey(owner)
end

function ParadiseEconomy.getZoneFinanceAccount(zoneId, create)
    local zoneIdNorm = ParadiseEconomy.normalizeZoneId(zoneId)
    if not zoneIdNorm then return nil end
    local store = ParadiseEconomy.getStore()
    local zone = store.zones and store.zones[zoneIdNorm] or nil
    if not zone then return nil end
    if create then return ParadiseEconomy.ensureFinanceAccount(store, zone) end
    local id = zone.financeAccountId
    local account = id and store.accounts[id] or nil
    if account and account.type == "finance" then return account end
    return nil
end

function ParadiseEconomy.getZoneFeeConfig(zoneOrTrade)
    return ParadiseEconomy.getMerchantDailyFee(zoneOrTrade), ParadiseEconomy.getMerchantFeeCurrency(zoneOrTrade)
end

function ParadiseEconomy.getStore()
    local store = ModData.getOrCreate(ParadiseEconomy.storeName)
    store.accounts = store.accounts or {}
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
    store.marts = store.marts or {}
    store.nextMartId = tonumber(store.nextMartId) or 1
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
        if version < 7 then ParadiseEconomy.migrateShopSquares(store) end
        if version < 8 then ParadiseEconomy.migrateOwnershipModel(store) end
        if version < 9 then ParadiseEconomy.migrateLedger(store) end
        store.schemaVersion = SCHEMA_VERSION
    end
    ParadiseEconomy.ensureServerAccount(store)
    ParadiseEconomy.ensureZoneFinances(store)
    ParadiseEconomy.ensureZoneMarts(store)
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

function ParadiseEconomy.squareKey(x, y, z)
    x = math.floor(tonumber(x) or 0)
    y = math.floor(tonumber(y) or 0)
    z = math.floor(tonumber(z) or 0)
    return tostring(x) .. "|" .. tostring(y) .. "|" .. tostring(z)
end

function ParadiseEconomy.normalizeSquare(x, y, z)
    x = math.floor(tonumber(x) or -1)
    y = math.floor(tonumber(y) or -1)
    z = math.floor(tonumber(z) or -1)
    if x < 0 or y < 0 or z < 0 then return nil end
    return x, y, z
end

function ParadiseEconomy.merchantIndexKey(zoneId, user)
    zoneId = ParadiseEconomy.normalizeZoneId(zoneId)
    local key = ParadiseEconomy.usernameKey(user)
    if not zoneId or not key then return nil end
    return zoneId .. "|" .. key
end

function ParadiseEconomy.getMerchantIndexKey(account)
    if type(account) ~= "table" then return nil end
    return ParadiseEconomy.merchantIndexKey(account.zoneId, account.owner)
end

function ParadiseEconomy.getZoneSquare(store, zoneId)
    zoneId = ParadiseEconomy.normalizeZoneId(zoneId)
    if not zoneId then return nil end
    local engine = ParadiseDev and ParadiseDev.Zones and ParadiseDev.Zones.Engine or nil
    local engineZone = engine and engine.zones and engine.zones[zoneId] or nil
    if not engineZone and engine and engine.zones then
        for id, check in pairs(engine.zones) do
            if ParadiseEconomy.normalizeZoneId(id) == zoneId then engineZone = check break end
        end
    end
    local region = engineZone and engineZone.regions and engineZone.regions[1] or nil
    if region and engine and engine.regionCenter then
        local x, y = engine.regionCenter(region)
        local z = math.floor(tonumber(engineZone.zMin) or 0)
        return math.floor(x), math.floor(y), z
    end
    local record = store and store.zones and store.zones[zoneId] or nil
    if record then
        local x, y, z = ParadiseEconomy.normalizeSquare(record.x, record.y, record.z)
        if x then return x, y, z end
    end
    return nil
end

function ParadiseEconomy.getSquareTradeZone(x, y, z)
    local sx, sy, sz = ParadiseEconomy.normalizeSquare(x, y, z)
    if not sx then return nil end
    local engine = ParadiseDev and ParadiseDev.Zones and ParadiseDev.Zones.Engine or nil
    if not engine or not engine.getAuthority then return nil end
    local zone = engine.getAuthority(sx + 0.5, sy + 0.5, sz, 0)
    if zone and zone.features and zone.features.isTrade == true then return zone end
    for _, candidate in ipairs(engine.getCandidateZones and engine.getCandidateZones(sx + 0.5, sy + 0.5, 0) or {}) do
        if candidate.features and candidate.features.isTrade == true
            and engine.zoneContains and engine.zoneContains(candidate, sx + 0.5, sy + 0.5, sz, 0) then
            return candidate
        end
    end
    return nil
end

function ParadiseEconomy.isPlayerNearSquare(pl, x, y, z, maxDist)
    local sx, sy, sz = ParadiseEconomy.normalizeSquare(x, y, z)
    if not pl or not sx then return false end
    if math.floor(tonumber(pl:getZ()) or -1) ~= sz then return false end
    return pl:DistTo(sx + 0.5, sy + 0.5) <= (tonumber(maxDist) or 3.0)
end

function ParadiseEconomy.addMartCategory(mart, category)
    if type(mart) ~= "table" then return end
    mart.categories = mart.categories or {}
    category = tostring(category or "General"):match("^%s*(.-)%s*$")
    if category == "" then category = "General" end
    if #category > 32 then category = category:sub(1, 32) end
    for _, existing in ipairs(mart.categories) do
        if existing == category then return end
    end
    mart.categories[#mart.categories + 1] = category
    table.sort(mart.categories)
end

function ParadiseEconomy.createMartRecord(store, zoneId, x, y, z, title)
    store = store or ParadiseEconomy.getStore()
    zoneId = ParadiseEconomy.normalizeZoneId(zoneId)
    if not zoneId then return nil end
    store.marts = store.marts or {}
    local int = tonumber(store.nextMartId) or 1
    local id
    repeat
        id = "mart-" .. tostring(int)
        int = int + 1
    until not store.marts[id]
    store.nextMartId = int
    local zone = store.zones and store.zones[zoneId] or nil
    title = ParadiseEconomy.normalizeTradeZoneTitle(title) or (zone and zone.name) or zoneId
    local sx, sy, sz = ParadiseEconomy.normalizeSquare(x, y, z)
    if not sx then sx, sy, sz = ParadiseEconomy.getZoneSquare(store, zoneId) end
    local trade = zone and zone.tradeAccountId and store.accounts[zone.tradeAccountId] or nil
    local mart = {
        id = id,
        zoneId = zoneId,
        title = title,
        owner = zone and zone.owner or (trade and trade.owner) or ParadiseEconomy.serverAccountId,
        ownerAccountId = trade and trade.id or ParadiseEconomy.serverAccountId,
        categories = {},
        listings = {},
        createdAt = os.time(),
    }
    if sx then
        mart.x, mart.y, mart.z = sx, sy, sz
    else
        mart.unplaced = true
    end
    store.marts[id] = mart
    return mart
end

function ParadiseEconomy.ensureZoneMarts(store)
    store = store or ParadiseEconomy.getStore()
    store.marts = store.marts or {}
    store.nextMartId = tonumber(store.nextMartId) or 1
    store.merchantIndex = store.merchantIndex or {}
    for _, mart in pairs(store.marts) do
        if mart.archived ~= true and not ParadiseEconomy.normalizeSquare(mart.x, mart.y, mart.z) then
            local x, y, z = ParadiseEconomy.getZoneSquare(store, mart.zoneId)
            if x then
                mart.x, mart.y, mart.z = x, y, z
                mart.unplaced = nil
            end
        end
    end
    for _, account in pairs(store.accounts or {}) do
        if account.type == "merchant" then
            if account.archived ~= true and not ParadiseEconomy.normalizeSquare(account.x, account.y, account.z) then
                local x, y, z = ParadiseEconomy.getZoneSquare(store, account.zoneId)
                if x then
                    account.x, account.y, account.z = x, y, z
                    account.unplaced = nil
                end
            end
            local key = ParadiseEconomy.getMerchantIndexKey(account)
            if key and account.archived ~= true then store.merchantIndex[key] = account.id end
        end
    end
    return store
end

function ParadiseEconomy.migrateShopSquares(store)
    store.marts = store.marts or {}
    store.nextMartId = tonumber(store.nextMartId) or 1
    store.merchantIndex = {}
    local zoneMarts = {}
    for _, mart in pairs(store.marts) do
        if mart.zoneId and mart.archived ~= true and not zoneMarts[ParadiseEconomy.normalizeZoneId(mart.zoneId)] then
            zoneMarts[ParadiseEconomy.normalizeZoneId(mart.zoneId)] = mart
        end
    end
    for _, account in pairs(store.accounts or {}) do
        if account.type == "trade" and account.zoneId then
            local zoneId = ParadiseEconomy.normalizeZoneId(account.zoneId)
            local mart = zoneMarts[zoneId]
            if not mart then
                mart = ParadiseEconomy.createMartRecord(store, zoneId, nil, nil, nil, account.title)
                zoneMarts[zoneId] = mart
            end
            mart.categories = mart.categories or {}
            mart.listings = mart.listings or {}
            for _, listing in ipairs(account.itemMart or {}) do
                local duplicate = false
                for _, existing in ipairs(mart.listings) do
                    if tostring(existing.id) == tostring(listing.id) then duplicate = true break end
                end
                if not duplicate then
                    mart.listings[#mart.listings + 1] = listing
                    ParadiseEconomy.addMartCategory(mart, listing.category)
                end
            end
            account.itemMart = {}
            account.itemMartSeeded = true
        end
    end
    for _, account in pairs(store.accounts or {}) do
        if account.type == "merchant" then
            if not ParadiseEconomy.normalizeSquare(account.x, account.y, account.z) then
                local x, y, z = ParadiseEconomy.getZoneSquare(store, account.zoneId)
                if x then
                    account.x, account.y, account.z = x, y, z
                    account.unplaced = nil
                end
            end
            local key = ParadiseEconomy.getMerchantIndexKey(account)
            if key then store.merchantIndex[key] = account.id end
        end
    end
    return store
end

function ParadiseEconomy.migrateOwnershipModel(store)
    store = store or ParadiseEconomy.getStore()
    store.zones = store.zones or {}
    store.accounts = store.accounts or {}
    store.marts = store.marts or {}
    store.merchantIndex = {}
    for _, zone in pairs(store.zones) do
        local trade = zone.tradeAccountId and store.accounts[zone.tradeAccountId] or nil
        local owner = zone.owner
        if not owner and trade then owner = trade.owner end
        zone.owner, zone.ownerType = ParadiseEconomy.normalizeZoneOwner(owner)
        zone.merchantDailyFee = ParadiseEconomy.normalizeMerchantDailyFee(zone.merchantDailyFee) or 0
        zone.merchantFeeCurrency = ParadiseEconomy.normalizeMerchantFeeCurrency(zone.merchantFeeCurrency) or "jimoleon"
        if trade then
            trade.owner = zone.owner
            trade.ownerType = zone.ownerType
            trade.merchantDailyFee = zone.merchantDailyFee
            trade.merchantFeeCurrency = zone.merchantFeeCurrency
        end
        if zone.isTrade then ParadiseEconomy.ensureFinanceAccount(store, zone) end
    end
    local groups = {}
    for id, account in pairs(store.accounts) do
        if account.type == "merchant" and account.archived ~= true then
            local key = ParadiseEconomy.usernameKey(account.owner)
            local zoneId = ParadiseEconomy.normalizeZoneId(account.zoneId)
            if key and zoneId then
                local groupKey = zoneId .. "|" .. key
                groups[groupKey] = groups[groupKey] or {}
                groups[groupKey][#groups[groupKey] + 1] = id
            end
        end
    end
    for _, ids in pairs(groups) do
        if #ids > 1 then
            table.sort(ids, function(a, b)
                local accountA, accountB = store.accounts[a], store.accounts[b]
                local createdA = accountA and tonumber(accountA.createdAt) or math.huge
                local createdB = accountB and tonumber(accountB.createdAt) or math.huge
                if createdA == createdB then return tostring(a) < tostring(b) end
                return createdA < createdB
            end)
            local keep = store.accounts[ids[1]]
            for index = 2, #ids do
                local duplicate = store.accounts[ids[index]]
                keep.listings = keep.listings or {}
                for _, listing in ipairs(duplicate.listings or {}) do
                    listing.merchantAccountId = keep.id
                    listing.zoneId = listing.zoneId or keep.zoneId
                    listing.zoneTitle = listing.zoneTitle or keep.zoneName
                    keep.listings[#keep.listings + 1] = listing
                end
                keep.earnings = keep.earnings or { jimoleon = 0, paradisium = 0 }
                for _, currency in ipairs({ "jimoleon", "paradisium" }) do
                    local amount = ParadiseEconomy.getBalance(duplicate.earnings, currency)
                    if amount > 0 then
                        ParadiseEconomy.addBalance(keep.earnings, currency, amount)
                        ParadiseEconomy.setBalance(duplicate.earnings, currency, 0)
                    end
                end
                if not ParadiseEconomy.normalizeSquare(keep.x, keep.y, keep.z)
                    and ParadiseEconomy.normalizeSquare(duplicate.x, duplicate.y, duplicate.z) then
                    keep.x, keep.y, keep.z = duplicate.x, duplicate.y, duplicate.z
                end
                duplicate.archived = true
                duplicate.mergedInto = keep.id
                duplicate.listings = {}
            end
        end
    end
    for id, account in pairs(store.accounts) do
        if account.type == "merchant" and account.archived ~= true then
            local key = ParadiseEconomy.getMerchantIndexKey(account)
            if key then store.merchantIndex[key] = id end
        end
    end
    for _, mart in pairs(store.marts) do
        local zone = store.zones[ParadiseEconomy.normalizeZoneId(mart.zoneId)]
        local tradeId = zone and zone.tradeAccountId or nil
        if not mart.ownerAccountId or not store.accounts[mart.ownerAccountId] then
            mart.ownerAccountId = tradeId or ParadiseEconomy.serverAccountId
        end
        mart.owner = mart.owner or (zone and zone.owner) or ParadiseEconomy.serverAccountId
    end
    ParadiseEconomy.ensureZoneFinances(store)
    return store
end

function ParadiseEconomy.migrateAccountIds(store)
    store.accounts = store.accounts or {}
    store.zones = store.zones or {}
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
    for _, tx in ipairs(store.transactions or {}) do
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
                local indexKey = ParadiseEconomy.getMerchantIndexKey(account)
                if indexKey then store.merchantIndex[indexKey] = accountId end
            end
        end
    end
    return store
end

function ParadiseEconomy.migrateLedger(store)
    local ledger = ParadiseEconomy.getLedger()
    local function resolveId(value)
        value = tostring(value or "")
        if value == "" then return nil end
        if store.accounts and store.accounts[value] then return value end
        local key = ParadiseEconomy.usernameKey(value)
        return key and store.personalIndex and store.personalIndex[key] or nil
    end
    for _, tx in ipairs(store.transactions or {}) do
        local rec = ParadiseEconomy.Ledger.fromLegacyTx(tx, resolveId)
        if rec then
            local day = ParadiseEconomy.Ledger.dayKey(rec.time)
            local bucket = ledger.days[day]
            if not bucket then
                bucket = {}
                ledger.days[day] = bucket
            end
            rec.day = day
            bucket[#bucket + 1] = ParadiseEconomy.Ledger.encode(rec)
        end
    end
    store.transactions = nil
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

    for _, tx in ipairs(store.transactions or {}) do
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

    for _, tx in ipairs(store.transactions or {}) do
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

function ParadiseEconomy.getMerchantFeeQuote(account, days)
    local trade = ParadiseEconomy.getMerchantZoneTrade(account)
    local zone = ParadiseEconomy.getZoneForAccount(account)
    local dailyFee, currency = ParadiseEconomy.getZoneFeeConfig(trade or zone)
    local due = ParadiseEconomy.getMerchantFeeDue(days or ParadiseEconomy.getMerchantLeaseDays(trade), dailyFee)
    return due, currency, trade
end

function ParadiseEconomy.payMerchantLeaseFee(account, days)
    if type(account) ~= "table" or account.type ~= "merchant" then return false, "Merchant account not found", 0 end
    local due, currency, trade = ParadiseEconomy.getMerchantFeeQuote(account, days)
    if due <= 0 then return true, nil, 0 end
    local treasury = trade
    if not treasury or treasury.type ~= "trade" then
        treasury = ParadiseEconomy.getTradeOrServerAccount(account.zoneId)
    end
    if ParadiseEconomy.isAccountFrozen(treasury) then
        return false, "The zone treasury is frozen; lease renewal cancelled.", due
    end
    local personal = ParadiseEconomy.getPersonalAccount(account.owner, false)
    if not personal then return false, "The merchant owner has no personal account.", due end
    if ParadiseEconomy.isAccountFrozen(personal) then
        return false, "The merchant owner's personal account is frozen; lease renewal cancelled.", due
    end
    if ParadiseEconomy.getBalance(personal.digital, currency) < due then
        return false, "Lease renewal needs " .. tostring(due) .. " " .. tostring(currency)
            .. "; transfer funds to your digital account first.", due
    end
    if not ParadiseEconomy.takeBalance(personal.digital, currency, due) then
        return false, "Lease renewal payment failed.", due
    end
    if not ParadiseEconomy.addAccountBalance(treasury, currency, due, "digital") then
        ParadiseEconomy.addBalance(personal.digital, currency, due)
        return false, "Lease renewal payment failed.", due
    end
    return true, nil, due, currency, treasury
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

function ParadiseEconomy.setMerchantSuspended(account, suspended, actor, reason)
    if type(account) ~= "table" or account.type ~= "merchant" then return false, "Merchant account not found" end
    account.suspended = suspended == true or nil
    if suspended == true then
        account.suspendedAt = getTimestampMs()
        account.suspendedBy = actor and actor:getUsername() or tostring(actor or "")
        account.suspendReason = reason
    else
        account.suspendedAt = nil
        account.suspendedBy = nil
        account.suspendReason = nil
    end
    return true, suspended == true and "Merchant store suspended" or "Merchant store resumed"
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

function ParadiseEconomy.renewMerchantLease(account, days, now, skipCharge)
    if type(account) ~= "table" or account.type ~= "merchant" then return false, "Merchant account not found" end
    local trade = ParadiseEconomy.getMerchantZoneTrade(account)
    days = ParadiseEconomy.normalizeMerchantLeaseDays(days) or ParadiseEconomy.getMerchantLeaseDays(trade)
    if days <= 0 then return false, "Merchant leases are disabled for this zone" end
    local paidAmount, paidCurrency, paidTo
    if not skipCharge then
        local paid, feeMessage, due, feeCurrency, treasury = ParadiseEconomy.payMerchantLeaseFee(account, days)
        if not paid then return false, feeMessage, due end
        paidAmount, paidCurrency, paidTo = due, feeCurrency, treasury
    end
    now = tonumber(now) or getTimestampMs()
    local base = math.max(now, tonumber(account.expiresAt) or 0)
    account.leaseDays = days
    account.expiresAt = base + days * ParadiseEconomy.merchantLeaseDayMs
    account.lastRenewedAt = now
    account.suspended = nil
    account.suspendedAt = nil
    account.suspendedBy = nil
    account.suspendReason = nil
    return true, "Merchant lease renewed for " .. ParadiseEconomy.formatMerchantLeaseDuration(account.expiresAt - now),
        paidAmount, paidCurrency, paidTo
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
    zone.merchantDailyFee = ParadiseEconomy.normalizeMerchantDailyFee(zone.merchantDailyFee) or 0
    zone.merchantFeeCurrency = ParadiseEconomy.normalizeMerchantFeeCurrency(zone.merchantFeeCurrency) or "jimoleon"
    if zone.isTrade then
        zone.tradeAccountId = ParadiseEconomy.ensureTradeAccount(zoneId, zone.name)
    end
    local trade = zone.tradeAccountId and store.accounts[zone.tradeAccountId] or nil
    zone.owner, zone.ownerType = ParadiseEconomy.normalizeZoneOwner(zone.owner or (trade and trade.owner))
    local squareX, squareY, squareZ = ParadiseEconomy.getZoneSquare(store, zoneId)
    if squareX then
        zone.x, zone.y, zone.z = squareX, squareY, squareZ
    end
    if zone.isTrade then
        ParadiseEconomy.syncZoneOwnership(store, zone, zone.owner)
    end
    trade = zone.tradeAccountId and store.accounts[zone.tradeAccountId] or nil
    for _, account in pairs(store.accounts) do
        if account.type == "merchant" and account.zoneId == zoneId then
            account.zoneName = zone.name
            account.archived = nil
            if not account.taxRoute or not store.accounts[account.taxRoute] then
                account.taxRoute = zone.tradeAccountId or ParadiseEconomy.serverAccountId
            end
        end
    end
    if trade then
        trade.zoneName = zone.name
        trade.tradeId = zone.name
        trade.title = trade.title or zone.name
        trade.archived = nil
    end
    for _, mart in pairs(store.marts or {}) do
        if ParadiseEconomy.normalizeZoneId(mart.zoneId) == zoneId then
            mart.archived = nil
            if not mart.ownerAccountId or not store.accounts[mart.ownerAccountId] then
                mart.ownerAccountId = zone.tradeAccountId or ParadiseEconomy.serverAccountId
            end
            mart.owner = zone.owner
        end
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
            ownerType = "server",
            tradeTax = ParadiseEconomy.getPlayerShopTaxPercent(),
            merchantDailyFee = 0,
            merchantFeeCurrency = "jimoleon",
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
    account.merchantDailyFee = ParadiseEconomy.normalizeMerchantDailyFee(account.merchantDailyFee)
        or (zone and ParadiseEconomy.normalizeMerchantDailyFee(zone.merchantDailyFee)) or 0
    account.merchantFeeCurrency = ParadiseEconomy.normalizeMerchantFeeCurrency(account.merchantFeeCurrency)
        or (zone and ParadiseEconomy.normalizeMerchantFeeCurrency(zone.merchantFeeCurrency)) or "jimoleon"
    account.digital = ensureBucket(account.digital)
    account.itemMart = account.itemMart or {}
    if zone then
        zone.merchantDailyFee = account.merchantDailyFee
        zone.merchantFeeCurrency = account.merchantFeeCurrency
        ParadiseEconomy.ensureFinanceAccount(store, zone)
    end
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
    for _, mart in pairs(store.marts or {}) do
        if ParadiseEconomy.normalizeZoneId(mart.zoneId) == zoneId then mart.archived = true end
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
    ParadiseEconomy.ensureZoneMarts(store)
    ParadiseEconomy.rebuildAccountIndexes()
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
            -- expired: reserved for the future inactivity automation; nothing sets or enforces it yet.
            expired = nil,
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
        elseif key and account.type == "merchant" then
            local indexKey = ParadiseEconomy.getMerchantIndexKey(account)
            if indexKey then
                merchantCandidates[indexKey] = merchantCandidates[indexKey] or {}
                merchantCandidates[indexKey][#merchantCandidates[indexKey] + 1] = accountId
            end
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


function ParadiseEconomy.getMerchantForZone(zoneId, user, create, x, y, z)
    zoneId = ParadiseEconomy.normalizeZoneId(zoneId)
    local owner = ParadiseEconomy.normalizeUsername(user)
    if not zoneId or not owner then return nil end
    local key = ParadiseEconomy.usernameKey(owner)
    local store = ParadiseEconomy.getStore()
    store.merchantIndex = store.merchantIndex or {}
    local indexKey = ParadiseEconomy.merchantIndexKey(zoneId, owner)
    local id = indexKey and store.merchantIndex[indexKey] or nil
    local account = id and store.accounts[id] or nil
    if account and (account.type ~= "merchant" or ParadiseEconomy.normalizeZoneId(account.zoneId) ~= zoneId) then
        account = nil
    end
    if not account then
        local candidates = {}
        for accountId, check in pairs(store.accounts) do
            if check.type == "merchant" and ParadiseEconomy.normalizeZoneId(check.zoneId) == zoneId
                and ParadiseEconomy.usernameKey(check.owner) == key then
                candidates[#candidates + 1] = check
            end
        end
        table.sort(candidates, function(a, b)
            local archivedA, archivedB = a.archived == true and 1 or 0, b.archived == true and 1 or 0
            if archivedA ~= archivedB then return archivedA < archivedB end
            local createdA = tonumber(a.createdAt) or math.huge
            local createdB = tonumber(b.createdAt) or math.huge
            if createdA == createdB then return tostring(a.id) < tostring(b.id) end
            return createdA < createdB
        end)
        account = candidates[1]
        if account then
            id = account.id
            if indexKey then store.merchantIndex[indexKey] = id end
        end
    end
    local zone = store.zones[zoneId]
    if not zone then return nil end
    local zoneName = tostring(zone.name or zoneId)
    local sx, sy, sz = ParadiseEconomy.normalizeSquare(x, y, z)
    if not sx and create then sx, sy, sz = ParadiseEconomy.getZoneSquare(store, zoneId) end
    if not account and create then
        id = ParadiseEconomy.generateAccountId(store)
        if not id then return nil end
        account = {
            id = id,
            type = "merchant",
            zoneId = zoneId,
            zoneName = zoneName,
            x = sx,
            y = sy,
            z = sz,
            owner = owner,
            title = tostring(owner) .. " @ " .. zoneName,
            taxRoute = zone.tradeAccountId or ParadiseEconomy.serverAccountId,
            listings = {},
            earnings = { jimoleon = 0, paradisium = 0 },
            createdAt = os.time(),
        }
        store.accounts[id] = account
        if indexKey then store.merchantIndex[indexKey] = id end
    end
    if account then
        account.zoneId = zoneId
        account.zoneName = zoneName
        if sx then
            account.x, account.y, account.z = sx, sy, sz
            account.unplaced = nil
        end
        account.listings = account.listings or {}
        account.earnings = ensureBucket(account.earnings)
        ParadiseEconomy.refreshAccountOwnerCase(account, owner)
        account.title = ParadiseEconomy.normalizeTradeZoneTitle(account.title)
            or (tostring(account.owner or owner or "Merchant") .. " @ " .. tostring(account.zoneName or zoneId))
        if not account.taxRoute or not store.accounts[account.taxRoute] then
            account.taxRoute = zone.tradeAccountId or ParadiseEconomy.serverAccountId
        end
        if indexKey then store.merchantIndex[indexKey] = account.id end
        if tonumber(account.expiresAt) == nil then
            local dailyFee = ParadiseEconomy.getZoneFeeConfig(zone)
            local trade = ParadiseEconomy.getMerchantZoneTrade(account)
            local leaseDays = ParadiseEconomy.getMerchantLeaseDays(trade)
            if dailyFee > 0 and leaseDays > 0 then
                account.expiresAt = 1
                account.leaseDays = 0
            else
                ParadiseEconomy.ensureMerchantLease(account)
            end
        end
    end
    return account
end

function ParadiseEconomy.getMerchantAtSquare(x, y, z, user, create, zoneId)
    local sx, sy, sz = ParadiseEconomy.normalizeSquare(x, y, z)
    if not sx then return nil end
    zoneId = ParadiseEconomy.normalizeZoneId(zoneId)
    if not zoneId then
        local engineZone = ParadiseEconomy.getSquareTradeZone(sx, sy, sz)
        zoneId = engineZone and ParadiseEconomy.normalizeZoneId(engineZone.id) or nil
        if not zoneId then return nil end
        local store = ParadiseEconomy.getStore()
        if not store.zones[zoneId] then ParadiseEconomy.registerZone(zoneId, engineZone.name, true) end
    end
    return ParadiseEconomy.getMerchantForZone(zoneId, user, create, sx, sy, sz)
end

function ParadiseEconomy.getMerchantAccount(zoneId, user, create)
    zoneId = ParadiseEconomy.normalizeZoneId(zoneId)
    if not zoneId then return nil end
    local store = ParadiseEconomy.getStore()
    if not store.zones[zoneId] then return nil end
    local x, y, z = ParadiseEconomy.getZoneSquare(store, zoneId)
    return ParadiseEconomy.getMerchantForZone(zoneId, user, create, x, y, z)
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
        x = math.floor(tonumber(account.x) or 0),
        y = math.floor(tonumber(account.y) or 0),
        z = math.floor(tonumber(account.z) or 0),
        taxRoute = account.taxRoute,
        earnings = account.earnings,
        listingCount = #(account.listings or {}),
        expiresAt = tonumber(account.expiresAt) or 0,
        leaseDays = tonumber(account.leaseDays) or 0,
        lastRenewedAt = tonumber(account.lastRenewedAt) or 0,
        leaseStatus = ParadiseEconomy.getMerchantLeaseStatus(account, now),
        leaseLabel = ParadiseEconomy.getMerchantLeaseLabel(account, now),
        status = ParadiseEconomy.getMerchantStatus(account, now),
        statusLabel = ParadiseEconomy.getMerchantStatusLabel(account, now),
        suspended = account.suspended == true,
        suspendedAt = tonumber(account.suspendedAt) or 0,
        suspendedBy = account.suspendedBy,
        suspendReason = account.suspendReason,
        closed = ParadiseEconomy.isMerchantClosed(account, now),
        active = not ParadiseEconomy.isMerchantClosed(account, now),
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
    return type(account) == "table" and (account.type == "trade" or account.type == "finance")
        and ParadiseEconomy.canManageAccount(pl, account)
end

function ParadiseEconomy.canManageFinanceAccount(pl, account)
    return type(account) == "table" and account.type == "finance"
        and ParadiseEconomy.canManageAccount(pl, account)
end

function ParadiseEconomy.getTradePublicView(account, includeMartListings)
    if type(account) ~= "table" then return nil end
    local zone = ParadiseEconomy.getZoneForAccount(account)
    local finance = zone and ParadiseEconomy.getZoneFinanceAccount(zone.id, false) or nil
    return {
        id = account.id,
        zoneId = account.zoneId,
        tradeId = account.tradeId,
        title = account.title,
        owner = account.owner,
        ownerType = account.ownerType,
        tradeTax = ParadiseEconomy.getTradeTaxPercent(account),
        merchantLeaseDays = ParadiseEconomy.getMerchantLeaseDays(account),
        merchantDailyFee = ParadiseEconomy.getMerchantDailyFee(zone or account),
        merchantFeeCurrency = ParadiseEconomy.getMerchantFeeCurrency(zone or account),
        financeAccountId = finance and finance.id or nil,
        financeOwner = finance and finance.owner or nil,
        finance = ParadiseEconomy.getFinancePublicView(finance),
        digital = {
            jimoleon = ParadiseEconomy.getBalance(account.digital, "jimoleon"),
            paradisium = ParadiseEconomy.getBalance(account.digital, "paradisium"),
        },
        marts = ParadiseEconomy.getZoneMartViews(account.zoneId, includeMartListings == true),
    }
end

function ParadiseEconomy.getFinancePublicView(account)
    if type(account) ~= "table" then return nil end
    return {
        id = account.id,
        zoneId = account.zoneId,
        title = account.title,
        owner = account.owner,
        ownerType = account.ownerType,
        digital = {
            jimoleon = ParadiseEconomy.getBalance(account.digital, "jimoleon"),
            paradisium = ParadiseEconomy.getBalance(account.digital, "paradisium"),
        },
    }
end

function ParadiseEconomy.getMart(martId)
    local store = ParadiseEconomy.getStore()
    local mart = store.marts and store.marts[tostring(martId or "")] or nil
    if mart and mart.archived ~= true then return mart end
    return nil
end

function ParadiseEconomy.getZoneMarts(zoneId)
    local marts = {}
    zoneId = ParadiseEconomy.normalizeZoneId(zoneId)
    if not zoneId then return marts end
    for _, mart in pairs(ParadiseEconomy.getStore().marts or {}) do
        if mart.archived ~= true and ParadiseEconomy.normalizeZoneId(mart.zoneId) == zoneId then
            marts[#marts + 1] = mart
        end
    end
    table.sort(marts, function(a, b)
        return tostring(a.title or a.id) < tostring(b.title or b.id)
    end)
    return marts
end

function ParadiseEconomy.getSquareMarts(x, y, z)
    local marts = {}
    local sx, sy, sz = ParadiseEconomy.normalizeSquare(x, y, z)
    if not sx then return marts end
    for _, mart in pairs(ParadiseEconomy.getStore().marts or {}) do
        if mart.archived ~= true and math.floor(tonumber(mart.x) or -1) == sx
            and math.floor(tonumber(mart.y) or -1) == sy
            and math.floor(tonumber(mart.z) or -1) == sz then
            marts[#marts + 1] = mart
        end
    end
    table.sort(marts, function(a, b)
        return tostring(a.title or a.id) < tostring(b.title or b.id)
    end)
    return marts
end

function ParadiseEconomy.getMartView(mart, includeListings)
    if type(mart) ~= "table" then return nil end
    local categories = {}
    for _, category in ipairs(mart.categories or {}) do categories[#categories + 1] = category end
    table.sort(categories)
    local view = {
        id = mart.id,
        zoneId = mart.zoneId,
        title = mart.title,
        owner = mart.owner,
        ownerAccountId = mart.ownerAccountId,
        x = tonumber(mart.x) or 0,
        y = tonumber(mart.y) or 0,
        z = tonumber(mart.z) or 0,
        categories = categories,
        listingCount = #(mart.listings or {}),
        createdAt = tonumber(mart.createdAt) or 0,
    }
    if includeListings then
        local listings = {}
        for _, listing in ipairs(mart.listings or {}) do
            listings[#listings + 1] = {
                id = listing.id,
                category = listing.category,
                fullType = listing.fullType,
                direction = listing.direction,
                currency = listing.currency,
                price = listing.price,
            }
        end
        view.listings = listings
    end
    return view
end

function ParadiseEconomy.getZoneMartViews(zoneId, includeListings)
    local views = {}
    for _, mart in ipairs(ParadiseEconomy.getZoneMarts(zoneId)) do
        local view = ParadiseEconomy.getMartView(mart, includeListings)
        if view then views[#views + 1] = view end
    end
    return views
end

function ParadiseEconomy.getPublicShops(store)
    store = store or ParadiseEconomy.getStore()
    local shops = {}
    local now = getTimestampMs()
    for _, account in pairs(store.accounts or {}) do
        if account.type == "merchant" and account.archived ~= true
            and ParadiseEconomy.normalizeSquare(account.x, account.y, account.z) then
            local status = ParadiseEconomy.getMerchantStatus(account, now)
            shops[#shops + 1] = {
                kind = "store",
                id = account.id,
                title = account.title or account.owner or account.id,
                owner = account.owner,
                zoneId = account.zoneId,
                x = math.floor(tonumber(account.x) or 0),
                y = math.floor(tonumber(account.y) or 0),
                z = math.floor(tonumber(account.z) or 0),
                status = status,
                statusLabel = ParadiseEconomy.getMerchantStatusLabel(account, now),
                closed = status ~= "active",
            }
        end
    end
    for _, mart in pairs(store.marts or {}) do
        if mart.archived ~= true and ParadiseEconomy.normalizeSquare(mart.x, mart.y, mart.z) then
            shops[#shops + 1] = {
                kind = "mart",
                id = mart.id,
                title = mart.title or mart.id,
                owner = mart.owner,
                zoneId = mart.zoneId,
                x = math.floor(tonumber(mart.x) or 0),
                y = math.floor(tonumber(mart.y) or 0),
                z = math.floor(tonumber(mart.z) or 0),
            }
        end
    end
    table.sort(shops, function(a, b)
        local kindA, kindB = tostring(a.kind), tostring(b.kind)
        if kindA ~= kindB then return kindA < kindB end
        return tostring(a.title or a.id) < tostring(b.title or b.id)
    end)
    return shops
end

function ParadiseEconomy.getMartOwnerAccount(mart)
    if type(mart) ~= "table" then return nil end
    local account = mart.ownerAccountId and ParadiseEconomy.getAccountById(mart.ownerAccountId) or nil
    if account then return account end
    return ParadiseEconomy.getTradeOrServerAccount(mart.zoneId)
end

function ParadiseEconomy.canManageMart(pl, mart)
    if type(mart) ~= "table" then return false end
    if ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(pl) then return true end
    local owner = ParadiseEconomy.getMartOwnerAccount(mart)
    return owner ~= nil and ParadiseEconomy.canManageAccount(pl, owner)
end

function ParadiseEconomy.getShopState(pl, kind, shopId)
    local isAdm = ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(pl) or false
    if kind == "store" then
        local merchant = ParadiseEconomy.getAccountById(shopId)
        if not merchant or merchant.type ~= "merchant" then return nil, "Merchant store not found" end
        local canManage = isAdm or ParadiseEconomy.isAccountOwner(pl, merchant)
        local status = ParadiseEconomy.getMerchantStatus(merchant)
        local closed = ParadiseEconomy.isMerchantClosed(merchant)
        local taxAccount = merchant.taxRoute and ParadiseEconomy.getAccountById(merchant.taxRoute) or nil
        local trade = merchant.zoneId and ParadiseEconomy.getTradeAccount(merchant.zoneId, false) or nil
        taxAccount = taxAccount or trade
        local dailyFee, feeCurrency = ParadiseEconomy.getMerchantFeeQuote(merchant, tonumber(merchant.leaseDays))
        return {
            kind = "store",
            id = merchant.id,
            owner = merchant.owner,
            title = merchant.title,
            zoneId = merchant.zoneId,
            zoneTitle = merchant.zoneName,
            x = math.floor(tonumber(merchant.x) or 0),
            y = math.floor(tonumber(merchant.y) or 0),
            z = math.floor(tonumber(merchant.z) or 0),
            canManage = canManage,
            isOwner = ParadiseEconomy.isAccountOwner(pl, merchant),
            archived = merchant.archived == true,
            expired = ParadiseEconomy.isMerchantExpired(merchant),
            suspended = merchant.suspended == true,
            suspendedAt = tonumber(merchant.suspendedAt) or 0,
            suspendedBy = merchant.suspendedBy,
            suspendReason = merchant.suspendReason,
            status = status,
            statusLabel = ParadiseEconomy.getMerchantStatusLabel(merchant),
            closed = closed,
            leaseStatus = ParadiseEconomy.getMerchantLeaseStatus(merchant),
            leaseLabel = ParadiseEconomy.getMerchantLeaseLabel(merchant),
            leaseDays = tonumber(merchant.leaseDays) or 0,
            expiresAt = tonumber(merchant.expiresAt) or 0,
            earnings = ensureBucket(merchant.earnings),
            taxPercent = taxAccount and ParadiseEconomy.getTradeTaxPercent(taxAccount) or 0,
            taxAccountId = taxAccount and taxAccount.id or nil,
            taxAccountTitle = taxAccount and (taxAccount.title or taxAccount.name) or nil,
            dailyFee = dailyFee or 0,
            feeCurrency = feeCurrency or "jimoleon",
            listings = ParadiseEconomy.getMerchantListingViews(merchant, canManage),
        }
    elseif kind == "mart" then
        local mart = ParadiseEconomy.getMart(shopId)
        if not mart then return nil, "Market not found" end
        local view = ParadiseEconomy.getMartView(mart)
        local trade = mart.zoneId and ParadiseEconomy.getTradeAccount(mart.zoneId, false) or nil
        local ownerAccount = mart.ownerAccountId and ParadiseEconomy.getAccountById(mart.ownerAccountId) or nil
        ownerAccount = ownerAccount or trade
        view.kind = "mart"
        view.zoneTitle = trade and trade.title or mart.zoneId
        view.canManage = ParadiseEconomy.canManageMart(pl, mart)
        view.ownerAccountId = ownerAccount and ownerAccount.id or nil
        view.ownerAccountTitle = ownerAccount and (ownerAccount.title or ownerAccount.name) or nil
        view.taxPercent = trade and ParadiseEconomy.getTradeTaxPercent(trade) or 0
        view.taxAccountId = trade and trade.id or nil
        view.taxAccountTitle = trade and (trade.title or trade.name) or nil
        view.listings = {}
        for _, listing in ipairs(mart.listings or {}) do view.listings[#view.listings + 1] = listing end
        return view
    end
    return nil, "Shop not found"
end

function ParadiseEconomy.sendShopState(pl, kind, shopId)
    local shop, message = ParadiseEconomy.getShopState(pl, tostring(kind or ""), shopId)
    sendServerCommand(pl, ParadiseEconomy.module, "shopState", {
        kind = tostring(kind or ""), id = shopId, shop = shop, message = message,
    })
end

function ParadiseEconomy.resolveMartArg(args)
    if type(args) ~= "table" then return nil end
    local mart = args.martId and ParadiseEconomy.getMart(args.martId) or nil
    if not mart and args.zoneId then
        for _, candidate in ipairs(ParadiseEconomy.getZoneMarts(args.zoneId)) do
            mart = candidate
            break
        end
    end
    return mart
end

function ParadiseEconomy.nextItemMartId()
    local market = ParadiseEconomy.getStore().market
    local int = tonumber(market.nextItemMartId) or 1
    market.nextItemMartId = int + 1
    return "item-" .. tostring(int)
end

function ParadiseEconomy.getMartItem(mart, listingId)
    if type(mart) ~= "table" then return nil end
    for _, listing in ipairs(mart.listings or {}) do
        if tostring(listing.id) == tostring(listingId) then return listing end
    end
    return nil
end

function ParadiseEconomy.saveMartItem(martId, listingId, fullType, direction, currency, price, category)
    local mart = ParadiseEconomy.getMart(martId)
    if not mart then return nil, "Market not found" end
    fullType = tostring(fullType or "")
    direction = direction == "sell" and "sell" or direction == "buy" and "buy" or nil
    currency = ParadiseEconomy.normalizeCurrency(currency)
    price = ParadiseEconomy.normalizeAmount(price)
    category = tostring(category or "General"):match("^%s*(.-)%s*$")
    if category == "" then category = "General" end
    if #category > 32 then category = category:sub(1, 32) end
    if not ScriptManager.instance:getItem(fullType) or not direction or not currency or not price then
        return nil, "Invalid market listing"
    end
    local listing
    for _, check in ipairs(mart.listings) do
        if listingId and tostring(check.id) == tostring(listingId) then listing = check end
    end
    if listingId and not listing then return nil, "Listing not found" end
    for _, check in ipairs(mart.listings) do
        if check ~= listing and check.fullType == fullType and check.direction == direction and check.category == category then
            return nil, "Duplicate item and action in this category"
        end
    end
    if not listing then
        listing = { id = ParadiseEconomy.nextItemMartId() }
        mart.listings[#mart.listings + 1] = listing
    end
    listing.fullType = fullType
    listing.direction = direction
    listing.currency = currency
    listing.price = price
    listing.category = category
    ParadiseEconomy.addMartCategory(mart, category)
    return listing, "Market listing saved"
end

function ParadiseEconomy.deleteMartItem(martId, listingId)
    local mart = ParadiseEconomy.getMart(martId)
    if not mart then return false, "Market not found" end
    for index, listing in ipairs(mart.listings) do
        if tostring(listing.id) == tostring(listingId) then
            table.remove(mart.listings, index)
            return true, "Market listing deleted"
        end
    end
    return false, "Listing not found"
end

function ParadiseEconomy.setMartTitle(martId, title)
    local mart = ParadiseEconomy.getMart(martId)
    title = ParadiseEconomy.normalizeTradeZoneTitle(title)
    if not mart or not title then return false, "Invalid market title" end
    mart.title = title
    return true, "Market renamed"
end

function ParadiseEconomy.setMartCategories(martId, categories)
    local mart = ParadiseEconomy.getMart(martId)
    if not mart or type(categories) ~= "table" then return false, "Invalid market categories" end
    local cleaned = {}
    for _, category in ipairs(categories) do
        category = tostring(category or ""):match("^%s*(.-)%s*$")
        if category ~= "" and #category <= 32 and #cleaned < 24 then
            local duplicate = false
            for _, existing in ipairs(cleaned) do
                if existing == category then duplicate = true break end
            end
            if not duplicate then cleaned[#cleaned + 1] = category end
        end
    end
    table.sort(cleaned)
    mart.categories = cleaned
    for _, listing in ipairs(mart.listings or {}) do
        ParadiseEconomy.addMartCategory(mart, listing.category)
    end
    return true, "Market categories updated"
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
        merchantSuspended = merchant and merchant.suspended == true or false,
        merchantStatus = merchant and ParadiseEconomy.getMerchantStatus(merchant, now) or nil,
        merchantStatusLabel = merchant and ParadiseEconomy.getMerchantStatusLabel(merchant, now) or nil,
        closed = merchant and ParadiseEconomy.isMerchantClosed(merchant, now) or false,
        expired = merchant and ParadiseEconomy.isMerchantExpired(merchant, now) or false,
        taxPercent = taxAccount and ParadiseEconomy.getTradeTaxPercent(taxAccount) or nil,
    }
end

function ParadiseEconomy.getMerchantListingViews(merchant, includeExpired)
    local listings = {}
    if type(merchant) ~= "table" or merchant.type ~= "merchant" then return listings end
    if not includeExpired and ParadiseEconomy.isMerchantClosed(merchant) then
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

function ParadiseEconomy.postPlayerListing(pl, merchantId, itemId, currency, price)
    local merchant = ParadiseEconomy.getAccountById(merchantId)
    if not merchant or merchant.type ~= "merchant" then return false, "Merchant store not found" end
    if ParadiseEconomy.usernameKey(merchant.owner) ~= ParadiseEconomy.usernameKey(pl:getUsername()) then
        return false, "You do not own this merchant store"
    end
    if not ParadiseEconomy.isPlayerNearSquare(pl, merchant.x, merchant.y, merchant.z) then
        return false, "You must stand at your merchant store square"
    end
    if ParadiseEconomy.isMerchantClosed(merchant) then
        if merchant.archived == true then return false, "This merchant store is closed" end
        if merchant.suspended == true then return false, "This merchant store is suspended" end
        return false, "Your merchant lease has expired. Renew it at your store."
    end
    local owner = ParadiseEconomy.getPersonalAccount(merchant.owner, false)
    if ParadiseEconomy.isAccountFrozen(owner) then
        return false, "Your account is frozen; transaction cancelled."
    end
    currency = ParadiseEconomy.normalizeCurrency(currency)
    price = ParadiseEconomy.normalizeAmount(price)
    local item = ParadiseEconomy.findCarriedItem(pl, itemId)
    if not item or not currency or not price or ParadiseEconomy.isEquipped(pl, item) then return false end
    local itemData = ParadiseEconomy.ItemData.toData(item)
    if not itemData then return false end
    local zoneRecord = merchant.zoneId and ParadiseEconomy.registerZone(merchant.zoneId,
        merchant.zoneName, true) or nil
    local listing = ParadiseEconomy.newPlayerListing(
        ParadiseEconomy.nextPlayerListingId(), pl:getUsername(), itemData, currency, price, os.time(),
        merchant.zoneName or (zoneRecord and zoneRecord.name), merchant.zoneId, merchant.id)
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
    if ParadiseEconomy.isMerchantClosed(merchant) then
        if merchant.suspended == true then return false, "This merchant store is suspended" end
        return false, "This merchant listing has expired"
    end
    if ParadiseEconomy.usernameKey(listing.seller) == ParadiseEconomy.usernameKey(pl:getUsername()) then
        return false, "You cannot buy your own listing"
    end
    if not ParadiseEconomy.isPlayerNearSquare(pl, merchant.x, merchant.y, merchant.z) then
        return false, "You must stand at the merchant store square"
    end
    local buyer = ParadiseEconomy.getPersonalAccount(pl:getUsername(), true)
    if not buyer then return false, "No personal account" end
    if ParadiseEconomy.isAccountFrozen(buyer) then
        return false, "Your account is frozen; transaction cancelled."
    end
    local useOnHand = opts.payFromOnHand == true
    local bucket = useOnHand and buyer.onhand or buyer.digital
    local bucketName = useOnHand and "onhand" or "digital"
    local balance = ParadiseEconomy.getBalance(bucket, listing.currency)
    if balance < listing.price then
        return false, "Not enough " .. tostring(listing.currency) .. " " .. (useOnHand and "on hand" or "digital")
            .. ". Need " .. tostring(listing.price) .. ", have " .. tostring(balance) .. "."
    end
    local taxAccount = merchant.taxRoute and ParadiseEconomy.getAccountById(merchant.taxRoute) or nil
    taxAccount = taxAccount or ParadiseEconomy.getTradeOrServerAccount(merchant.zoneId)
    local payout, tax = ParadiseEconomy.getPlayerShopPayout(listing.price, ParadiseEconomy.getTradeTaxPercent(taxAccount))
    if tax > 0 and ParadiseEconomy.isAccountFrozen(taxAccount) then
        return false, ParadiseEconomy.getFrozenMessage(taxAccount, "recipient")
    end
    local destination, destinationLabel = ParadiseEconomy.resolvePurchaseDestination(pl, opts.destination)
    local item = ParadiseEconomy.spawnItemData(pl, listing.itemData, destination)
    if not item then return false, "Could not create the purchased item" end
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
    if ParadiseEconomy.isAccountFrozen(personal) then
        return false, "Your account is frozen; transaction cancelled."
    end
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

ParadiseEconomy.ledgerStoreName = "ParadiseEconomy_Ledger"

function ParadiseEconomy.getLedger()
    local ledger = ModData.getOrCreate(ParadiseEconomy.ledgerStoreName)
    ledger.version = tonumber(ledger.version) or 1
    ledger.days = ledger.days or {}
    return ledger
end

function ParadiseEconomy.appendLedger(rec)
    if type(rec) ~= "table" then return end
    local ledger = ParadiseEconomy.getLedger()
    local day = rec.day or ParadiseEconomy.Ledger.dayKey(rec.time or os.time())
    local bucket = ledger.days[day]
    if not bucket then
        bucket = {}
        ledger.days[day] = bucket
    end
    rec.day = day
    bucket[#bucket + 1] = ParadiseEconomy.Ledger.encode(rec)
end

function ParadiseEconomy.getLedgerDays()
    local ledger = ParadiseEconomy.getLedger()
    local days = {}
    for day, bucket in pairs(ledger.days) do
        days[#days + 1] = { d = day, n = #bucket }
    end
    table.sort(days, function(a, b) return a.d > b.d end)
    return days
end

function ParadiseEconomy.getLedgerPage(day, page, pageSize)
    local ledger = ParadiseEconomy.getLedger()
    local bucket = ledger.days[tostring(day or "")] or {}
    pageSize = math.max(1, math.floor(tonumber(pageSize) or 20))
    local total = #bucket
    local pages = math.max(1, math.ceil(total / pageSize))
    page = math.max(1, math.min(pages, math.floor(tonumber(page) or 1)))
    local rows = {}
    local first = (page - 1) * pageSize + 1
    for index = first, math.min(total, first + pageSize - 1) do
        rows[#rows + 1] = bucket[index]
    end
    return { day = tostring(day or ""), page = page, pages = pages, count = total, rows = rows }
end

function ParadiseEconomy.Ledger.debugDays()
    return ParadiseEconomy.getLedgerDays()
end

function ParadiseEconomy.Ledger.debugPage(day, page)
    return ParadiseEconomy.getLedgerPage(day, page, 20)
end

function ParadiseEconomy.getLedgerNames(store)
    local names = {}
    for id, account in pairs((store and store.accounts) or {}) do
        names[id] = account.title or account.name or account.owner or id
    end
    return names
end

function ParadiseEconomy.getLedgerZoneNames(store)
    local zones = {}
    for id, zone in pairs((store and store.zones) or {}) do
        zones[id] = zone.name or id
    end
    return zones
end

function ParadiseEconomy.getPlayerLedgerRows(user, accountId, limit, isAdm)
    limit = math.max(1, math.floor(tonumber(limit) or 200))
    local store = ParadiseEconomy.getStore()
    local accIds = {}
    if accountId then
        local account = store.accounts[tostring(accountId)]
        local owned = account and ParadiseEconomy.usernameKey(account.owner) == ParadiseEconomy.usernameKey(user)
        if account and (isAdm == true or owned) then accIds[account.id] = true end
    else
        local key = ParadiseEconomy.usernameKey(user)
        for id, account in pairs(store.accounts) do
            if ParadiseEconomy.usernameKey(account.owner) == key then accIds[id] = true end
        end
    end
    local ctx = {
        user = user,
        accIds = accIds,
        names = ParadiseEconomy.getLedgerNames(store),
        zones = ParadiseEconomy.getLedgerZoneNames(store),
    }
    local ledger = ParadiseEconomy.getLedger()
    local rows = {}
    for _, entry in ipairs(ParadiseEconomy.getLedgerDays()) do
        local bucket = ledger.days[entry.d] or {}
        for index = #bucket, 1, -1 do
            local rec = ParadiseEconomy.Ledger.decode(bucket[index], entry.d)
            if ParadiseEconomy.Ledger.involves(rec, accIds, accountId and nil or user) then
                local title, detail, colorKey, amountText = ParadiseEconomy.Ledger.playerText(rec, ctx)
                rows[#rows + 1] = {
                    t = rec.tod, d = rec.day, x = title, e = detail or "",
                    k = colorKey or "flat", m = amountText or "",
                    a = rec.a or "", b = rec.b or "",
                }
                if #rows >= limit then
                    return { rows = rows, count = #rows }
                end
            end
        end
    end
    return { rows = rows, count = #rows }
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
    meta = type(meta) == "table" and meta or {}
    local now = os.time()
    local tx = {
        time = now,
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
    local store = ParadiseEconomy.getStore()
    local function resolveId(value)
        value = tostring(value or "")
        if value == "" then return "" end
        if store.accounts[value] then return value end
        local account = ParadiseEconomy.getPersonalAccount(value, false)
        return account and account.id or ""
    end
    local mapped = ParadiseEconomy.Ledger.actions[tx.action] or { kind = "G" }
    local rec = {
        kind = mapped.kind,
        reason = mapped.reason,
        time = now,
        actor = tx.username,
        a = meta.accountId and tostring(meta.accountId) or resolveId(fromUser),
        b = meta.counterpartyId and tostring(meta.counterpartyId) or resolveId(toUser),
        cur = ParadiseEconomy.Ledger.currencyCode(currency),
        amount = tx.amount,
        item = meta.itemType and tostring(meta.itemType) or nil,
        qty = meta.quantity,
        tax = meta.tax,
        taxAcc = meta.taxAccountId and tostring(meta.taxAccountId) or nil,
        zone = meta.zoneId and tostring(meta.zoneId) or nil,
        note = meta.note and tostring(meta.note) or nil,
    }
    if mapped.kind == "G" then
        rec.action = tx.action
        rec.note = tx.detail
    elseif not rec.note then
        rec.note = tx.detail
    end
    ParadiseEconomy.appendLedger(rec)
    ParadiseEconomy.writeLog(tx)
    return tx
end

function ParadiseEconomy.getFrozenMessage(account, role)
    if not ParadiseEconomy.isAccountFrozen(account) then return nil end
    if role == "sender" then return "Your account is frozen; transaction cancelled." end
    local label = account.owner or account.name or account.title or account.id or "The account"
    return tostring(label) .. "'s account is frozen; transaction cancelled."
end

function ParadiseEconomy.canMoveFunds(fromAccount, toAccount, allowFrozen)
    if allowFrozen then return true end
    local message = ParadiseEconomy.getFrozenMessage(fromAccount, "sender")
    if message then return false, message end
    message = ParadiseEconomy.getFrozenMessage(toAccount, "recipient")
    if message then return false, message end
    return true
end

function ParadiseEconomy.transferAccounts(fromUser, toUser, currency, amount, allowFrozen)
    local from = ParadiseEconomy.getPersonalAccount(fromUser, false)
    local to = ParadiseEconomy.getPersonalAccount(toUser, true)
    if not from or not to or from == to then return false end
    currency = ParadiseEconomy.normalizeCurrency(currency)
    amount = ParadiseEconomy.normalizeAmount(amount)
    if not currency or not amount then return false end
    local allowed, frozenMessage = ParadiseEconomy.canMoveFunds(from, to, allowFrozen)
    if not allowed then return false, frozenMessage end
    if not ParadiseEconomy.takeBalance(from.digital, currency, amount) then
        return false, "Insufficient digital funds"
    end
    if not ParadiseEconomy.addBalance(to.digital, currency, amount) then
        ParadiseEconomy.addBalance(from.digital, currency, amount)
        return false, "Transaction failed"
    end
    return true
end

function ParadiseEconomy.transferBetweenAccounts(fromAccount, toAccount, currency, amount, fromBucket, toBucket, allowFrozen)
    if not fromAccount or not toAccount or fromAccount == toAccount then return false end
    currency = ParadiseEconomy.normalizeCurrency(currency)
    amount = ParadiseEconomy.normalizeAmount(amount)
    if not currency or not amount then return false end
    local allowed, frozenMessage = ParadiseEconomy.canMoveFunds(fromAccount, toAccount, allowFrozen)
    if not allowed then return false, nil, nil, frozenMessage end
    fromBucket = ParadiseEconomy.resolveBucket(fromAccount, fromBucket)
    toBucket = ParadiseEconomy.resolveBucket(toAccount, toBucket)
    if not ParadiseEconomy.takeAccountBalance(fromAccount, currency, amount, fromBucket) then
        return false, fromBucket, toBucket, "Insufficient funds"
    end
    if not ParadiseEconomy.addAccountBalance(toAccount, currency, amount, toBucket) then
        ParadiseEconomy.addAccountBalance(fromAccount, currency, amount, fromBucket)
        return false, fromBucket, toBucket, "Transaction failed"
    end
    return true, fromBucket, toBucket
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
    local myShops = {}
    for _, merchant in ipairs(ParadiseEconomy.getPlayerMerchants(user)) do
        local view = ParadiseEconomy.getMerchantManagementView(merchant)
        if view then
            view.listings = ParadiseEconomy.getMerchantListingViews(merchant, true)
            merchants[#merchants + 1] = view
            local square = ParadiseEconomy.normalizeSquare(merchant.x, merchant.y, merchant.z)
            myShops[#myShops + 1] = {
                kind = "store",
                id = view.id,
                title = view.title or view.owner or view.id,
                owner = view.owner,
                zoneId = view.zoneId,
                x = square and math.floor(tonumber(merchant.x) or 0) or nil,
                y = square and math.floor(tonumber(merchant.y) or 0) or nil,
                z = square and math.floor(tonumber(merchant.z) or 0) or nil,
                status = view.status,
                statusLabel = view.statusLabel,
                suspended = view.suspended,
                closed = view.closed,
                expired = view.status == "expired",
                archived = view.archived == true,
            }
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
        local finance = zoneRecord.financeAccountId and store.accounts[zoneRecord.financeAccountId] or nil
        market.tradeZoneId = zoneRecord.id
        market.tradeZoneTitle = zoneRecord.name
        market.trade = trade and ParadiseEconomy.getTradePublicView(trade) or nil
        market.finance = finance and ParadiseEconomy.getFinancePublicView(finance) or nil
        market.zoneOwner = zoneRecord.owner
        market.zoneOwnerType = zoneRecord.ownerType
        market.merchantDailyFee = ParadiseEconomy.getMerchantDailyFee(trade or zoneRecord)
        market.merchantFeeCurrency = ParadiseEconomy.getMerchantFeeCurrency(trade or zoneRecord)
        market.marts = ParadiseEconomy.getZoneMartViews(zoneRecord.id)
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
            local view = ParadiseEconomy.getTradePublicView(account, true)
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
        accounts = isAdm and store.accounts or nil,
        zones = isAdm and store.zones or nil,
        orphanedPlayerListings = isAdm and store.orphanedPlayerListings or nil,
        marts = isAdm and store.marts or nil,
        myShops = myShops,
        shops = ParadiseEconomy.getPublicShops(store),
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
    if not currency or not amount or not account then return false, "Invalid amount or currency" end
    if ParadiseEconomy.isAccountFrozen(account) then
        return false, "Your account is frozen; transaction cancelled."
    end
    local from = toDigital and account.onhand or account.digital
    local to = toDigital and account.digital or account.onhand
    if not ParadiseEconomy.takeBalance(from, currency, amount) then
        return false, "Insufficient funds"
    end
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
    elseif account.type == "finance" then
        local zone = store.zones[account.zoneId]
        if zone and zone.financeAccountId == accountId then
            return false, "Finance accounts cannot be deleted while attached to a zone"
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
        account.suspended = nil
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
    local ctx = {
        command = command,
        pl = pl,
        args = args,
        user = pl:getUsername(),
        currency = ParadiseEconomy.normalizeCurrency(args.currency),
        amount = ParadiseEconomy.normalizeAmount(args.amount),
        isAdm = ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(pl) or false,
    }
    if (command == "marketBuy" or command == "marketSell" or command == "playerShopPost" or
        command == "playerShopBuy") and not ParadiseEconomy.canUsePlayerEconomy(pl) then
        if command == "playerShopBuy" and args.source == "drag" then
            ctx.purchaseResult = { ok = false, listingId = args.listingId,
                message = "ParadiseMart is only available in a Trade Zone" }
        end
        ParadiseEconomy.sendState(pl, "ParadiseMart is only available in a Trade Zone",
            { purchase = ctx.purchaseResult })
        return
    end
    if ParadiseEconomy.handleLedgerCommand(ctx) then return end
    if command == "requestState" then
        ParadiseEconomy.sendState(pl)
        return
    elseif command == "requestShop" then
        ParadiseEconomy.sendShopState(pl, args.kind, args.id)
        return
    end
    for _, handler in ipairs(ParadiseEconomy.commandGroups) do
        if handler(ctx) then break end
    end
    if ctx.stop then return end
    ParadiseEconomy.transmit()
    local extra = nil
    if ctx.purchaseResult then extra = extra or {}; extra.purchase = ctx.purchaseResult end
    if ctx.shopResult then extra = extra or {}; extra.shopRequest = ctx.shopResult end
    if ctx.syncAll then ParadiseEconomy.sendStateToAll(pl, ctx.message, extra)
    else ParadiseEconomy.sendState(pl, ctx.message or "Transaction rejected", extra) end
end
Events.OnClientCommand.Remove(ParadiseEconomy.onClientCommand)
Events.OnClientCommand.Add(ParadiseEconomy.onClientCommand)

function ParadiseEconomy.handleLedgerCommand(ctx)
    local pl, args, user, isAdm = ctx.pl, ctx.args, ctx.user, ctx.isAdm
    local command = ctx.command
    if command == "ledgerDays" then
        if isAdm then
            sendServerCommand(pl, ParadiseEconomy.module, "ledgerDays",
                { days = ParadiseEconomy.getLedgerDays() })
        end
        return true
    elseif command == "ledgerPage" then
        if isAdm then
            sendServerCommand(pl, ParadiseEconomy.module, "ledgerPage",
                ParadiseEconomy.getLedgerPage(args.day, args.page, 20))
        end
        return true
    elseif command == "ledgerMine" then
        local scope = args.accountId and tostring(args.accountId) or nil
        sendServerCommand(pl, ParadiseEconomy.module, "ledgerMine",
            ParadiseEconomy.getPlayerLedgerRows(user, scope, 200, isAdm))
        return true
    end
    return false
end

function ParadiseEconomy.handleStoreCommand(ctx)
    local pl, args, user, isAdm = ctx.pl, ctx.args, ctx.user, ctx.isAdm
    local message, syncAll = ctx.message, ctx.syncAll
    local shopResult = ctx.shopResult
    local command = ctx.command
    if command == "registerStore" then
        local sx, sy, sz = ParadiseEconomy.normalizeSquare(args.x, args.y, args.z)
        if not sx then
            message = "Invalid square"
        elseif not ParadiseEconomy.isPlayerNearSquare(pl, sx, sy, sz) then
            message = "Stand at the square to register your merchant store"
        else
            local zone = ParadiseEconomy.getSquareTradeZone(sx, sy, sz)
            if not zone then
                message = "Merchant stores can only be registered inside a Trade Zone"
            else
                local zoneRecord = ParadiseEconomy.registerZone(zone.id, zone.name, true)
                local existing = ParadiseEconomy.getMerchantAccount(zoneRecord.id, user, false)
                local merchant = ParadiseEconomy.getMerchantAtSquare(sx, sy, sz, user, true, zoneRecord.id)
                if not merchant then
                    message = "Could not register the merchant store"
                else
                    merchant.archived = nil
                    merchant.zoneId = zoneRecord.id
                    merchant.zoneName = zoneRecord.name
                    merchant.x, merchant.y, merchant.z = sx, sy, sz
                    merchant.unplaced = nil
                    if not merchant.taxRoute or not ParadiseEconomy.getStore().accounts[merchant.taxRoute] then
                        merchant.taxRoute = zoneRecord.tradeAccountId or ParadiseEconomy.serverAccountId
                    end
                    local merchantTrade = ParadiseEconomy.getMerchantZoneTrade(merchant)
                    local leaseDays = ParadiseEconomy.getMerchantLeaseDays(merchantTrade)
                    local feeDue = ParadiseEconomy.getMerchantFeeQuote(merchant, leaseDays)
                    local registered = true
                    local registrationMessage = "Merchant store registered"
                    if not existing and leaseDays > 0 then
                        local chargePaid, chargeMessage, due, feeCurrency, feeTarget = true, nil, 0
                        if feeDue > 0 then
                            chargePaid, chargeMessage, due, feeCurrency, feeTarget =
                                ParadiseEconomy.payMerchantLeaseFee(merchant, leaseDays)
                        end
                        if chargePaid then
                            ParadiseEconomy.grantMerchantLease(merchant, leaseDays)
                            if due > 0 then
                                ParadiseEconomy.record(pl, "merchant lease paid", feeCurrency or "jimoleon", due, user,
                                    feeTarget and feeTarget.id or merchant.id, tostring(leaseDays) .. " days", {
                                        accountId = merchant.id,
                                        counterpartyId = feeTarget and feeTarget.id or nil,
                                        zoneId = merchant.zoneId,
                                        note = tostring(leaseDays) .. " days",
                                    })
                            end
                        else
                            ParadiseEconomy.deleteAccount(merchant.id)
                            registered = false
                            registrationMessage = chargeMessage
                        end
                    elseif not existing then
                        ParadiseEconomy.grantMerchantLease(merchant, 0)
                    elseif ParadiseEconomy.isMerchantExpired(merchant) and leaseDays > 0 then
                        local renewed, leaseMessage, paidAmount, paidCurrency, paidTo =
                            ParadiseEconomy.renewMerchantLease(merchant, leaseDays)
                        if renewed then
                            if paidAmount and paidAmount > 0 then
                                ParadiseEconomy.record(pl, "merchant lease paid", paidCurrency or "jimoleon",
                                    paidAmount, user, paidTo and paidTo.id or merchant.id,
                                    tostring(leaseDays) .. " days", {
                                        accountId = merchant.id,
                                        counterpartyId = paidTo and paidTo.id or nil,
                                        zoneId = merchant.zoneId,
                                        note = tostring(leaseDays) .. " days",
                                    })
                            end
                        else
                            registrationMessage = leaseMessage
                        end
                    end
                    message = registrationMessage
                    if registered then
                        shopResult = { kind = "store", id = merchant.id }
                        ParadiseEconomy.record(pl, "merchant store registered", "mixed", 0, user, merchant.id,
                            tostring(merchant.title or ""), { accountId = merchant.id, zoneId = merchant.zoneId })
                    end
                    syncAll = true
                end
            end
        end
    elseif command == "createMart" then
        local sx, sy, sz = ParadiseEconomy.normalizeSquare(args.x, args.y, args.z)
        local zone = sx and ParadiseEconomy.getSquareTradeZone(sx, sy, sz) or nil
        local trade = zone and ParadiseEconomy.getTradeAccount(zone.id, true) or nil
        if not sx then
            message = "Invalid square"
        elseif not ParadiseEconomy.isPlayerNearSquare(pl, sx, sy, sz) then
            message = "Stand at the square to create a market"
        elseif not zone then
            message = "Markets can only be created inside a Trade Zone"
        elseif not trade or not (isAdm or ParadiseEconomy.canManageTradeAccount(pl, trade)) then
            message = "Only the trade zone manager can create markets here"
        else
            local zoneRecord = ParadiseEconomy.registerZone(zone.id, zone.name, true)
            local title = tostring(args.title or ""):match("^%s*(.-)%s*$")
            if title == "" then
                title = tostring(zoneRecord.name or "Market") .. " Market "
                    .. tostring(#ParadiseEconomy.getZoneMarts(zoneRecord.id) + 1)
            end
            local mart = ParadiseEconomy.createMartRecord(ParadiseEconomy.getStore(), zoneRecord.id, sx, sy, sz, title)
            if not mart then
                message = "Could not create the market"
            else
                message = "Market created: " .. tostring(mart.title)
                shopResult = { kind = "mart", id = mart.id }
                syncAll = true
                ParadiseEconomy.record(pl, "market created", "mixed", 0, user, trade.id, tostring(mart.title), {
                    accountId = trade.id, zoneId = mart.zoneId,
                })
            end
        end
    elseif command == "renameMart" then
        local mart = ParadiseEconomy.resolveMartArg(args)
        if not mart then
            message = "Market not found"
        elseif not ParadiseEconomy.canManageMart(pl, mart) then
            message = "Not allowed to rename this market"
        else
            local saved, titleMessage = ParadiseEconomy.setMartTitle(mart.id, args.title)
            message = titleMessage
            syncAll = saved
            if saved then
                local trade = ParadiseEconomy.getTradeAccount(mart.zoneId, false)
                ParadiseEconomy.record(pl, "market renamed", "mixed", 0, user, trade and trade.id or mart.id,
                    tostring(mart.title), { accountId = trade and trade.id or nil, zoneId = mart.zoneId })
            end
        end
    elseif command == "martSetCategories" then
        local mart = ParadiseEconomy.resolveMartArg(args)
        if not mart then
            message = "Market not found"
        elseif not ParadiseEconomy.canManageMart(pl, mart) then
            message = "Not allowed to change this market"
        else
            local categories = args.categories
            if type(categories) ~= "table" then
                categories = {}
                for part in string.gmatch(tostring(args.text or ""), "[^;]+") do
                    categories[#categories + 1] = part
                end
            end
            local saved, categoryMessage = ParadiseEconomy.setMartCategories(mart.id, categories)
            message = categoryMessage
            syncAll = saved
        end
    else
        return false
    end
    ctx.message, ctx.syncAll = message, syncAll
    ctx.shopResult = shopResult
    return true
end

function ParadiseEconomy.handleFundsCommand(ctx)
    local pl, args, user, isAdm = ctx.pl, ctx.args, ctx.user, ctx.isAdm
    local currency, amount = ctx.currency, ctx.amount
    local message, syncAll = ctx.message, ctx.syncAll
    local command = ctx.command
    if command == "deposit" then
        local moved, moveMessage = ParadiseEconomy.movePlayerAccount(pl, currency, amount, true)
        if moved then
            local personal = ParadiseEconomy.getPersonalAccount(user, true)
            ParadiseEconomy.record(pl, "deposited", currency, amount, user, user, "carried to digital", {
                accountId = personal.id, bucket = "digital",
            })
            message = "Deposited " .. amount .. " " .. currency
        else
            message = moveMessage
        end
    elseif command == "withdraw" then
        local moved, moveMessage = ParadiseEconomy.movePlayerAccount(pl, currency, amount, false)
        if moved then
            local personal = ParadiseEconomy.getPersonalAccount(user, true)
            ParadiseEconomy.record(pl, "withdrew", currency, amount, user, user, "digital to carried", {
                accountId = personal.id, bucket = "onhand",
            })
            message = "Withdrew " .. amount .. " " .. currency
        else
            message = moveMessage
        end
    elseif command == "transfer" then
        local targetUser = ParadiseEconomy.normalizeUsername(args.username)
        if not targetUser then
            message = "Invalid recipient"
        else
            local sent, sendMessage = ParadiseEconomy.transferAccounts(user, targetUser, currency, amount)
            if sent then
                local personal = ParadiseEconomy.getPersonalAccount(user, true)
                local target = ParadiseEconomy.getPersonalAccount(targetUser, false)
                ParadiseEconomy.record(pl, "transferred", currency, amount, user, targetUser, "account transfer", {
                    accountId = personal.id,
                    counterpartyId = target and target.id or nil,
                    bucket = "digital",
                })
                message = "Sent " .. amount .. " " .. currency .. " to " .. targetUser
                syncAll = true
            else
                message = sendMessage or "Transaction rejected"
            end
        end
    elseif command == "withdrawWallet" then
        local account = ParadiseEconomy.getPersonalAccount(user, true)
        if ParadiseEconomy.isAccountFrozen(account) then
            message = "Your account is frozen; transaction cancelled."
        elseif currency and amount and ParadiseEconomy.getBalance(account.digital, currency) >= amount then
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
        local personal = ParadiseEconomy.getPersonalAccount(user, true)
        if ParadiseEconomy.isAccountFrozen(personal) then
            message = "Your account is frozen; transaction cancelled."
        elseif item and wallet then
            local jimoleon = ParadiseEconomy.getBalance(wallet, "jimoleon")
            local paradisium = ParadiseEconomy.getBalance(wallet, "paradisium")
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
        local collected, collectMessage = ParadiseEconomy.collectMerchantEarnings(pl)
        if collected and (collected.jimoleon > 0 or collected.paradisium > 0) then
            message = "Collected " .. collected.jimoleon .. " Jimoleons and " .. collected.paradisium .. " Paradisium"
        elseif collected == false then
            message = collectMessage
        else
            message = "No merchant earnings to collect"
        end
    else
        return false
    end
    ctx.message, ctx.syncAll = message, syncAll
    return true
end

function ParadiseEconomy.handleZoneCommand(ctx)
    local pl, args, user, isAdm = ctx.pl, ctx.args, ctx.user, ctx.isAdm
    local message, syncAll = ctx.message, ctx.syncAll
    local command = ctx.command
    if command == "tradeSetTitle" then
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
    elseif command == "zoneSetDailyFee" then
        local zoneId = ParadiseEconomy.normalizeZoneId(args.zoneId)
        local store = ParadiseEconomy.getStore()
        local zone = zoneId and store.zones[zoneId] or nil
        local trade = zone and ParadiseEconomy.getTradeAccount(zone.id, false) or nil
        local dailyFee = ParadiseEconomy.normalizeMerchantDailyFee(args.fee)
        local feeCurrency = ParadiseEconomy.normalizeMerchantFeeCurrency(args.currency)
        if not zone or not trade then
            message = "Trade zone not found"
        elseif not ParadiseEconomy.isZoneOwner(pl, trade) then
            message = "Only the zone owner can change merchant fees"
        elseif dailyFee == nil then
            message = "Invalid daily fee"
        elseif not feeCurrency then
            message = "Invalid fee currency"
        else
            zone.merchantDailyFee = dailyFee
            zone.merchantFeeCurrency = feeCurrency
            ParadiseEconomy.syncZoneOwnership(store, zone, zone.owner)
            message = "Merchant fee set to " .. tostring(dailyFee) .. " " .. feeCurrency .. " per day"
            syncAll = true
            ParadiseEconomy.record(pl, "zone daily fee set", feeCurrency, dailyFee, zone.owner, trade.id,
                tostring(dailyFee) .. " per day", {
                    accountId = trade.id, zoneId = zone.id,
                    note = tostring(dailyFee) .. " " .. tostring(feeCurrency),
                })
        end
    elseif command == "zoneSetOwner" then
        local zoneId = ParadiseEconomy.normalizeZoneId(args.zoneId)
        local store = ParadiseEconomy.getStore()
        local zone = zoneId and store.zones[zoneId] or nil
        local owner = tostring(args.owner or ""):match("^%s*(.-)%s*$")
        if not isAdm then
            message = "Only admins can reassign zone ownership"
        elseif not zone or not zone.tradeAccountId then
            message = "Trade zone not found"
        elseif owner == "" then
            message = "Invalid owner"
        else
            local ownerName, ownerType = ParadiseEconomy.syncZoneOwnership(store, zone, owner)
            message = ownerType == "server" and "Zone owner reset to the server account"
                or ("Zone owner set to " .. tostring(ownerName))
            syncAll = true
            ParadiseEconomy.record(pl, "zone owner set", "mixed", 0, user, zone.tradeAccountId, tostring(ownerName), {
                accountId = zone.tradeAccountId, zoneId = zone.id,
            })
        end
    elseif command == "zoneSweep" then
        local trade = ParadiseEconomy.getTradeAccount(args.zoneId, false)
        local finance = trade and ParadiseEconomy.getZoneFinanceAccount(trade.zoneId, true) or nil
        if not trade then
            message = "Trade zone not found"
        elseif not finance then
            message = "Finance account not found"
        elseif not ParadiseEconomy.isZoneOwner(pl, trade) then
            message = "Only the zone owner can sweep the treasury"
        else
            local allowed, frozenMessage = ParadiseEconomy.canMoveFunds(trade, finance, isAdm)
            if not allowed then
                message = frozenMessage
            else
                local moved = 0
                for _, cur in ipairs({ "jimoleon", "paradisium" }) do
                    local balance = ParadiseEconomy.getBalance(trade.digital, cur)
                    if balance > 0 and ParadiseEconomy.takeAccountBalance(trade, cur, balance, "digital") then
                        if ParadiseEconomy.addAccountBalance(finance, cur, balance, "digital") then
                            moved = moved + 1
                            ParadiseEconomy.record(pl, "treasury sweep", cur, balance, trade.id, finance.id,
                                "treasury to finance", {
                                    accountId = trade.id,
                                    counterpartyId = finance.id,
                                    zoneId = trade.zoneId,
                                    bucket = "digital",
                                })
                        else
                            ParadiseEconomy.addAccountBalance(trade, cur, balance, "digital")
                        end
                    end
                end
                message = moved > 0 and "Treasury swept to finance" or "Treasury is empty"
                syncAll = true
            end
        end
    else
        return false
    end
    ctx.message, ctx.syncAll = message, syncAll
    return true
end

function ParadiseEconomy.handleFinanceCommand(ctx)
    local pl, args, user, isAdm = ctx.pl, ctx.args, ctx.user, ctx.isAdm
    local currency, amount = ctx.currency, ctx.amount
    local message, syncAll = ctx.message, ctx.syncAll
    local command = ctx.command
    if command == "financeWithdraw" then
        local finance = ParadiseEconomy.getZoneFinanceAccount(args.zoneId, false)
        if not finance then
            message = "Finance account not found"
        elseif not ParadiseEconomy.canManageFinanceAccount(pl, finance) then
            message = "Not allowed to withdraw from this finance account"
        elseif not currency or not amount then
            message = "Invalid amount or currency"
        else
            local personal = ParadiseEconomy.getPersonalAccount(user, true)
            local moved, _, _, transferMessage =
                ParadiseEconomy.transferBetweenAccounts(finance, personal, currency, amount, "digital", "digital", isAdm)
            if moved then
                ParadiseEconomy.record(pl, "finance withdrawal", currency, amount, finance.id, personal.id,
                    "finance to personal", {
                        accountId = finance.id, counterpartyId = personal.id, zoneId = finance.zoneId, bucket = "digital",
                    })
                message = "Withdrew " .. amount .. " " .. currency .. " from the finance account"
                syncAll = true
            else
                message = transferMessage or "Finance account has insufficient funds"
            end
        end
    elseif command == "financeTransfer" then
        local finance = ParadiseEconomy.getZoneFinanceAccount(args.zoneId, false)
        local target = args.targetAccountId and ParadiseEconomy.getAccountById(args.targetAccountId) or nil
        if not target and args.targetUser then
            target = ParadiseEconomy.getPersonalAccount(args.targetUser, false)
        end
        if not finance then
            message = "Finance account not found"
        elseif not ParadiseEconomy.canManageFinanceAccount(pl, finance) then
            message = "Not allowed to transfer from this finance account"
        elseif not target or target == finance or not currency or not amount then
            message = "Invalid transfer target or amount"
        else
            local moved, _, _, transferMessage =
                ParadiseEconomy.transferBetweenAccounts(finance, target, currency, amount, "digital", nil, isAdm)
            if moved then
                ParadiseEconomy.record(pl, "finance transfer", currency, amount, finance.id, target.id,
                    "finance account transfer", {
                        accountId = finance.id, counterpartyId = target.id, zoneId = finance.zoneId, bucket = "digital",
                    })
                message = "Transferred " .. amount .. " " .. currency .. " from the finance account"
                syncAll = true
            else
                message = transferMessage or "Finance account has insufficient funds"
            end
        end
    else
        return false
    end
    ctx.message, ctx.syncAll = message, syncAll
    return true
end

function ParadiseEconomy.handleMerchantCommand(ctx)
    local pl, args, user, isAdm = ctx.pl, ctx.args, ctx.user, ctx.isAdm
    local currency, amount = ctx.currency, ctx.amount
    local message, syncAll = ctx.message, ctx.syncAll
    local command = ctx.command
    if command == "merchantSuspend" then
        local account = ParadiseEconomy.getAccountById(args.accountId)
        if not account or account.type ~= "merchant" then
            message = "Merchant account not found"
        else
            local trade = ParadiseEconomy.getMerchantZoneTrade(account)
            if not isAdm and not (trade and ParadiseEconomy.isZoneOwner(pl, trade)) then
                message = "Only the zone owner can suspend merchant stores"
            else
                local suspended = args.suspended == true
                local changed, suspendMessage =
                    ParadiseEconomy.setMerchantSuspended(account, suspended, pl, args.reason)
                message = suspendMessage
                syncAll = changed
                if changed then
                    ParadiseEconomy.record(pl, "merchant " .. (suspended and "suspended" or "resumed"), "mixed", 0,
                        user, account.id, tostring(account.title or account.owner or ""), {
                            accountId = account.id, zoneId = account.zoneId,
                            note = tostring(args.reason or ""),
                        })
                end
            end
        end
    elseif command == "adminSetAccountFrozen" then
        local account = ParadiseEconomy.resolveAccountArg(args.accountId, args.username)
        if not isAdm then
            message = "Only admins can freeze accounts"
        elseif not account then
            message = "Account not found"
        elseif account.type ~= "personal" then
            message = "Only personal accounts can be frozen"
        else
            local frozen = args.frozen == true
            account.frozen = frozen or nil
            if frozen then
                account.frozenAt = os.time()
                account.frozenBy = user
            else
                account.frozenAt = nil
                account.frozenBy = nil
            end
            message = frozen and ("Froze " .. tostring(account.owner or account.id))
                or ("Unfroze " .. tostring(account.owner or account.id))
            syncAll = true
            ParadiseEconomy.record(pl, frozen and "admin froze account" or "admin unfroze account", "mixed", 0,
                user, account.id, tostring(account.owner or ""), { accountId = account.id })
        end
    elseif command == "adminSetMartOwner" then
        local mart = ParadiseEconomy.resolveMartArg(args)
        local account = ParadiseEconomy.resolveAccountArg(args.ownerAccountId, args.ownerUsername)
        if not isAdm then
            message = "Only admins can reassign market ownership"
        elseif not mart then
            message = "Market not found"
        elseif not account then
            message = "Owner account not found"
        elseif account.type == "merchant" then
            message = "A merchant account cannot own a market"
        else
            mart.ownerAccountId = account.id
            mart.owner = account.owner or account.title or account.name or account.id
            message = "Market owner set to " .. tostring(mart.owner)
            syncAll = true
            ParadiseEconomy.record(pl, "admin set market owner", "mixed", 0, user, account.id,
                tostring(mart.title or mart.id), {
                    accountId = account.id, counterpartyId = mart.id, zoneId = mart.zoneId,
                })
        end
    elseif command == "merchantRenew" then
        local account = ParadiseEconomy.getAccountById(args.accountId)
        if not account or account.type ~= "merchant" then
            message = "Merchant account not found"
        elseif not ParadiseEconomy.canManageMerchantLease(pl, account) then
            message = "Not allowed to renew this merchant lease"
        else
            local renewed, leaseMessage, paidAmount, paidCurrency, paidTo =
                ParadiseEconomy.renewMerchantLease(account, args.days)
            message = leaseMessage
            syncAll = renewed
            if renewed then
                ParadiseEconomy.record(pl, "merchant lease renewed", "mixed", 0, user, account.id,
                    tostring(account.leaseDays) .. " days", { accountId = account.id, zoneId = account.zoneId })
                if paidAmount and paidAmount > 0 then
                    ParadiseEconomy.record(pl, "merchant lease paid", paidCurrency or "jimoleon", paidAmount,
                        account.owner or user, paidTo and paidTo.id or account.id,
                        tostring(account.leaseDays) .. " days", {
                            accountId = account.id,
                            counterpartyId = paidTo and paidTo.id or nil,
                            zoneId = account.zoneId,
                            note = tostring(account.leaseDays) .. " days",
                        })
                end
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
                    local actionLabel = action == "expire" and "expired" or action
                    ParadiseEconomy.record(pl, "merchant lease " .. actionLabel, "mixed", 0, user, account.id,
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
            local allowed, frozenMessage = ParadiseEconomy.canMoveFunds(trade, personal)
            if not allowed then
                message = frozenMessage
            elseif not ParadiseEconomy.takeAccountBalance(trade, currency, amount, "digital") then
                message = "Trade account has insufficient funds"
            else
                ParadiseEconomy.addAccountBalance(personal, currency, amount, "digital")
                ParadiseEconomy.record(pl, "trade withdrawal", currency, amount, trade.id, personal.id, "trade to personal", {
                    accountId = trade.id, counterpartyId = personal.id, zoneId = trade.zoneId, bucket = "digital",
                })
                message = "Withdrew " .. amount .. " " .. currency .. " from the trade account"
                syncAll = true
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
        else
            local moved, _, _, transferMessage =
                ParadiseEconomy.transferBetweenAccounts(trade, target, currency, amount, "digital", nil)
            if moved then
                ParadiseEconomy.record(pl, "trade transfer", currency, amount, trade.id, target.id, "trade account transfer", {
                    accountId = trade.id, counterpartyId = target.id, zoneId = trade.zoneId, bucket = "digital",
                })
                message = "Transferred " .. amount .. " " .. currency .. " from the trade account"
                syncAll = true
            else
                message = transferMessage or "Trade account has insufficient funds"
            end
        end
    elseif command == "tradeItemSave" then
        local mart = ParadiseEconomy.resolveMartArg(args)
        if not mart then
            message = "Market not found"
        elseif not ParadiseEconomy.canManageMart(pl, mart) then
            message = "Not allowed to manage this market"
        else
            local listing
            listing, message = ParadiseEconomy.saveMartItem(mart.id, args.listingId, args.fullType,
                args.direction, currency, ParadiseEconomy.normalizeAmount(args.price or args.amount), args.category)
            syncAll = listing ~= nil
            if listing then
                local trade = ParadiseEconomy.getTradeAccount(mart.zoneId, false)
                ParadiseEconomy.record(pl, "market listing saved", listing.currency, listing.price, user,
                    trade and trade.id or mart.id,
                    tostring(listing.category) .. ":" .. listing.direction .. ":" .. listing.fullType, {
                        accountId = trade and trade.id or nil, zoneId = mart.zoneId,
                        itemType = listing.fullType, quantity = listing.quantity or 1,
                        note = tostring(listing.category) .. ":" .. tostring(listing.direction),
                    })
            end
        end
    elseif command == "tradeItemDelete" then
        local mart = ParadiseEconomy.resolveMartArg(args)
        if not mart then
            message = "Market not found"
        elseif not ParadiseEconomy.canManageMart(pl, mart) then
            message = "Not allowed to manage this market"
        else
            local removed
            removed, message = ParadiseEconomy.deleteMartItem(mart.id, args.listingId)
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
    else
        return false
    end
    ctx.message, ctx.syncAll = message, syncAll
    return true
end

function ParadiseEconomy.handleAdminCommand(ctx)
    local pl, args, user, isAdm = ctx.pl, ctx.args, ctx.user, ctx.isAdm
    local currency, amount = ctx.currency, ctx.amount
    local message, syncAll = ctx.message, ctx.syncAll
    local command = ctx.command
    if command == "adminSetTradeOwner" and isAdm then
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
                    accountId = account.id, bucket = bucket, note = tostring(bucket),
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
        local moved, _, _, transferMessage = from and to and
            ParadiseEconomy.transferBetweenAccounts(from, to, currency, amount, args.fromBucket, args.toBucket, true)
        if moved then
            local fromBucket = ParadiseEconomy.resolveBucket(from, args.fromBucket)
            ParadiseEconomy.record(pl, "admin transfer", currency, amount, from.id, to.id, "account reroute", {
                accountId = from.id,
                counterpartyId = to.id,
                bucket = fromBucket,
            })
            message = "Account rerouted"
            syncAll = true
        else
            message = transferMessage or "Reroute rejected"
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
            ctx.stop = true
            return true
        end
    elseif command == "adminPurgeLedger" and isAdm then
        local ledger = ParadiseEconomy.getLedger()
        if args.day then
            ledger.days[tostring(args.day)] = nil
        else
            ledger.days = {}
        end
        ParadiseEconomy.record(pl, "admin purged ledger", "mixed", 0, user, "ledger", "transaction history cleared", {
            accountId = ParadiseEconomy.getPersonalAccount(user, true).id,
        })
        message = "Transaction history cleared"
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
    else
        return false
    end
    ctx.message, ctx.syncAll = message, syncAll
    return true
end

function ParadiseEconomy.handleMarketCommand(ctx)
    local pl, args, user = ctx.pl, ctx.args, ctx.user
    local message, syncAll = ctx.message, ctx.syncAll
    local command = ctx.command
    if command == "marketBuy" then
        local mart = ParadiseEconomy.resolveMartArg(args)
        local ownerAccount = mart and ParadiseEconomy.getMartOwnerAccount(mart) or nil
        local listing = mart and ParadiseEconomy.getMartItem(mart, args.listingId) or nil
        local quantity = ParadiseEconomy.normalizeAmount(args.quantity) or 1
        local personal = ParadiseEconomy.getPersonalAccount(user, true)
        if not mart then
            message = "Market not found"
        elseif not ParadiseEconomy.isPlayerNearSquare(pl, mart.x, mart.y, mart.z) then
            message = "Stand at the market square to buy"
        elseif not ownerAccount then
            message = "Market account not found"
        elseif not listing or listing.direction ~= "buy" then
            message = "Market listing not found"
        elseif quantity > 100 then
            message = "Invalid quantity"
        elseif not ParadiseEconomy.canMoveFunds(personal, ownerAccount) then
            message = ParadiseEconomy.getFrozenMessage(personal, "sender")
                or ParadiseEconomy.getFrozenMessage(ownerAccount, "recipient")
        else
            local total = listing.price * quantity
            if ParadiseEconomy.takeBalance(personal.digital, listing.currency, total) then
                ParadiseEconomy.addBalance(ownerAccount.digital, listing.currency, total)
                local inv = pl:getInventory()
                for _ = 1, quantity do
                    local item = inv:AddItem(listing.fullType)
                    if item then
                        if item.SynchSpawn then item:SynchSpawn() end
                        sendAddItemToContainer(inv, item)
                    end
                end
                ParadiseEconomy.record(pl, "market purchase", listing.currency, total, user,
                    tostring(ownerAccount.title or ownerAccount.name), quantity .. "x " .. listing.fullType, {
                        accountId = personal.id, counterpartyId = ownerAccount.id, zoneId = mart.zoneId, bucket = "digital",
                        itemType = listing.fullType, quantity = quantity,
                    })
                message = "Purchase complete"
                syncAll = true
            else
                message = "Insufficient digital funds"
            end
        end
    elseif command == "marketSell" then
        local mart = ParadiseEconomy.resolveMartArg(args)
        local ownerAccount = mart and ParadiseEconomy.getMartOwnerAccount(mart) or nil
        local listing = mart and ParadiseEconomy.getMartItem(mart, args.listingId) or nil
        local quantity = ParadiseEconomy.normalizeAmount(args.quantity) or 1
        local personal = ParadiseEconomy.getPersonalAccount(user, true)
        if not mart then
            message = "Market not found"
        elseif not ParadiseEconomy.isPlayerNearSquare(pl, mart.x, mart.y, mart.z) then
            message = "Stand at the market square to sell"
        elseif not ownerAccount then
            message = "Market account not found"
        elseif not listing or listing.direction ~= "sell" then
            message = "Market listing not found"
        elseif quantity > 100 then
            message = "Invalid quantity"
        elseif not ParadiseEconomy.canMoveFunds(ownerAccount, personal) then
            message = ParadiseEconomy.getFrozenMessage(ownerAccount, "sender")
                or ParadiseEconomy.getFrozenMessage(personal, "recipient")
        else
            local total = listing.price * quantity
            if ParadiseEconomy.getBalance(ownerAccount.digital, listing.currency) < total then
                message = "The market account cannot pay for this sale"
            elseif not ParadiseEconomy.removeItems(pl:getInventory(), listing.fullType, quantity) then
                message = "You do not have enough items"
            else
                ParadiseEconomy.takeBalance(ownerAccount.digital, listing.currency, total)
                ParadiseEconomy.addBalance(personal.digital, listing.currency, total)
                ParadiseEconomy.record(pl, "market sale", listing.currency, total,
                    tostring(ownerAccount.title or ownerAccount.name), user, quantity .. "x " .. listing.fullType, {
                        accountId = personal.id, counterpartyId = ownerAccount.id, zoneId = mart.zoneId, bucket = "digital",
                        itemType = listing.fullType, quantity = quantity,
                    })
                message = "Sale complete"
                syncAll = true
            end
        end
    else
        return false
    end
    ctx.message, ctx.syncAll = message, syncAll
    return true
end

function ParadiseEconomy.handlePlayerShopCommand(ctx)
    local pl, args, user = ctx.pl, ctx.args, ctx.user
    local currency, amount = ctx.currency, ctx.amount
    local message, syncAll = ctx.message, ctx.syncAll
    local purchaseResult = ctx.purchaseResult
    local command = ctx.command
    if command == "playerShopPost" then
        local listing, merchantOrMessage = ParadiseEconomy.postPlayerListing(pl, args.merchantId,
            args.itemId, currency, amount)
        if listing then
            ParadiseEconomy.record(pl, "player shop posted", listing.currency, listing.price, user, tostring(merchantOrMessage.title),
                listing.id .. ":" .. listing.itemData.fullType, {
                    accountId = merchantOrMessage.id,
                    zoneId = listing.zoneId,
                    itemType = listing.itemData.fullType, quantity = 1,
                })
            message = "Item posted in your merchant store"
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
                    itemType = listing.itemData.fullType, quantity = 1,
                    tax = tax, taxAccountId = taxAccount and taxAccount.id or nil,
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
                    itemType = listing.itemData.fullType, quantity = 1,
                })
            message = "Listing returned to inventory"
            syncAll = true
        end
    else
        return false
    end
    ctx.message, ctx.syncAll = message, syncAll
    ctx.purchaseResult = purchaseResult
    return true
end

ParadiseEconomy.commandGroups = {
    ParadiseEconomy.handleStoreCommand,
    ParadiseEconomy.handleFundsCommand,
    ParadiseEconomy.handleZoneCommand,
    ParadiseEconomy.handleFinanceCommand,
    ParadiseEconomy.handleMerchantCommand,
    ParadiseEconomy.handleAdminCommand,
    ParadiseEconomy.handleMarketCommand,
    ParadiseEconomy.handlePlayerShopCommand,
}

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
