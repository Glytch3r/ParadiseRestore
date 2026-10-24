ParadiseEconomy = ParadiseEconomy or {}

ParadiseEconomy.module = "ParadiseEconomy"
ParadiseEconomy.storeName = "ParadiseEconomy"
ParadiseEconomy.walletKey = "ParadiseEconomyWallet"
ParadiseEconomy.playerKey = "ParadiseEconomy"
ParadiseEconomy.currencies = { jimoleon = true, paradisium = true }
ParadiseEconomy.walletTypes = {
    ["Base.Wallet"] = true,
    ["Base.Wallet_Female"] = true,
    ["Base.Wallet_Male"] = true,
    ["Base.Wallet_Hide"] = true,
}
ParadiseEconomy.serverAccountId = "server"
ParadiseEconomy.accountTypes = { personal = true, merchant = true, trade = true, server = true, custom = true }
ParadiseEconomy.accountTypeLabels = {
    personal = "Personal",
    merchant = "Merchant",
    trade = "Trade",
    server = "Server",
    custom = "Custom",
}

function ParadiseEconomy.normalizeUsername(user)
    user = tostring(user or ""):match("^%s*(.-)%s*$")
    if user == "" or #user > 64 then return nil end
    return user
end

function ParadiseEconomy.usernameKey(user)
    user = ParadiseEconomy.normalizeUsername(user)
    return user and string.lower(user) or nil
end

function ParadiseEconomy.normalizeZoneId(zoneId)
    zoneId = tostring(zoneId or ""):match("^%s*(.-)%s*$")
    if zoneId == "" or #zoneId > 96 then return nil end
    return string.lower(zoneId)
end

function ParadiseEconomy.personalAccountId(user)
    local key = ParadiseEconomy.usernameKey(user)
    return key and ("p:" .. key) or nil
end

function ParadiseEconomy.merchantAccountId(zoneId, user)
    local key = ParadiseEconomy.usernameKey(user)
    zoneId = ParadiseEconomy.normalizeZoneId(zoneId)
    if not key or not zoneId then return nil end
    return "m:" .. zoneId .. ":" .. key
end

function ParadiseEconomy.tradeAccountId(zoneId)
    zoneId = ParadiseEconomy.normalizeZoneId(zoneId)
    return zoneId and ("t:" .. zoneId) or nil
end

function ParadiseEconomy.getAccountType(accountId)
    accountId = tostring(accountId or "")
    if accountId == ParadiseEconomy.serverAccountId then return "server" end
    local prefix = accountId:match("^(%a+):")
    if prefix == "p" then return "personal" end
    if prefix == "m" then return "merchant" end
    if prefix == "t" then return "trade" end
    if prefix == "c" then return "custom" end
    return nil
end

function ParadiseEconomy.normalizeCurrency(currency)
    currency = string.lower(tostring(currency or ""))
    return ParadiseEconomy.currencies[currency] and currency or nil
end

function ParadiseEconomy.normalizeAmount(amount)
    amount = tostring(amount or "")
    if not amount:match("^%d+$") then return nil end
    amount = tonumber(amount)
    if not amount or amount < 1 or amount > 2147483647 then return nil end
    return math.floor(amount)
end

function ParadiseEconomy.normalizeBalance(amount)
    amount = tostring(amount or "")
    if not amount:match("^%d+$") then return nil end
    amount = tonumber(amount)
    if not amount or amount < 0 or amount > 2147483647 then return nil end
    return math.floor(amount)
end

function ParadiseEconomy.newAccount(user)
    return { username = ParadiseEconomy.normalizeUsername(user), jimoleon = 0, paradisium = 0 }
end

function ParadiseEconomy.getBalance(tab, currency)
    currency = ParadiseEconomy.normalizeCurrency(currency)
    if not currency or type(tab) ~= "table" then return 0 end
    local amount = tonumber(tab[currency]) or 0
    return math.max(0, math.floor(amount))
end

function ParadiseEconomy.setBalances(tab, jimoleon, paradisium)
    if type(tab) ~= "table" then return false end
    tab.jimoleon = math.max(0, math.floor(tonumber(jimoleon) or 0))
    tab.paradisium = math.max(0, math.floor(tonumber(paradisium) or 0))
    return true
end

function ParadiseEconomy.addBalance(tab, currency, amount)
    currency = ParadiseEconomy.normalizeCurrency(currency)
    amount = ParadiseEconomy.normalizeAmount(amount)
    if not currency or not amount or type(tab) ~= "table" then return false end
    tab[currency] = ParadiseEconomy.getBalance(tab, currency) + amount
    return true
end

function ParadiseEconomy.takeBalance(tab, currency, amount)
    currency = ParadiseEconomy.normalizeCurrency(currency)
    amount = ParadiseEconomy.normalizeAmount(amount)
    if not currency or not amount or type(tab) ~= "table" then return false end
    local balance = ParadiseEconomy.getBalance(tab, currency)
    if balance < amount then return false end
    tab[currency] = balance - amount
    return true
end

function ParadiseEconomy.setBalance(tab, currency, amount)
    currency = ParadiseEconomy.normalizeCurrency(currency)
    amount = ParadiseEconomy.normalizeBalance(amount)
    if not currency or not amount or type(tab) ~= "table" then return false end
    tab[currency] = amount
    return true
end

function ParadiseEconomy.getPrimaryBucket(account)
    if type(account) ~= "table" then return nil end
    if account.type == "personal" or account.type == "trade" then return "digital" end
    if account.type == "merchant" then return "earnings" end
    return "balances"
end

function ParadiseEconomy.getAccountBuckets(account)
    if type(account) ~= "table" then return {} end
    if account.type == "personal" then
        return { { key = "digital", label = "Digital" }, { key = "onhand", label = "On Hand" } }
    elseif account.type == "trade" then
        return { { key = "digital", label = "Digital" } }
    elseif account.type == "merchant" then
        return { { key = "earnings", label = "Earnings" } }
    end
    return { { key = "balances", label = "Balance" } }
end

function ParadiseEconomy.resolveBucket(account, bucket)
    for _, entry in ipairs(ParadiseEconomy.getAccountBuckets(account)) do
        if entry.key == bucket then return bucket end
    end
    if bucket == "online" then
        for _, entry in ipairs(ParadiseEconomy.getAccountBuckets(account)) do
            if entry.key == "digital" then return "digital" end
        end
    end
    return ParadiseEconomy.getPrimaryBucket(account)
end

function ParadiseEconomy.getBucketTable(account, bucket)
    if type(account) ~= "table" then return nil end
    bucket = ParadiseEconomy.resolveBucket(account, bucket)
    if not bucket then return nil end
    account[bucket] = account[bucket] or {}
    return account[bucket]
end

function ParadiseEconomy.getAccountBalance(account, currency, bucket)
    return ParadiseEconomy.getBalance(ParadiseEconomy.getBucketTable(account, bucket), currency)
end

function ParadiseEconomy.addAccountBalance(account, currency, amount, bucket)
    return ParadiseEconomy.addBalance(ParadiseEconomy.getBucketTable(account, bucket), currency, amount)
end

function ParadiseEconomy.takeAccountBalance(account, currency, amount, bucket)
    return ParadiseEconomy.takeBalance(ParadiseEconomy.getBucketTable(account, bucket), currency, amount)
end

function ParadiseEconomy.setAccountBalance(account, currency, amount, bucket)
    return ParadiseEconomy.setBalance(ParadiseEconomy.getBucketTable(account, bucket), currency, amount)
end

function ParadiseEconomy.getAccountLabel(account)
    if type(account) ~= "table" then return "Unknown" end
    local owner = account.owner or account.name or account.id or "?"
    local title = account.title or owner
    if account.type == "personal" then return "Personal · " .. tostring(title) end
    if account.type == "merchant" then
        return "Merchant · " .. tostring(title) .. " · " .. tostring(account.zoneName or account.zoneId or "?")
    end
    if account.type == "trade" then return "Trade · " .. tostring(title) end
    if account.type == "server" then return "Server · " .. tostring(account.name or "Server") end
    return "Custom · " .. tostring(title)
end

function ParadiseEconomy.formatAccountBalances(account)
    local parts = {}
    for _, entry in ipairs(ParadiseEconomy.getAccountBuckets(account)) do
        local tab = type(account[entry.key]) == "table" and account[entry.key] or {}
        parts[#parts + 1] = entry.label .. ": " .. tostring(ParadiseEconomy.getBalance(tab, "jimoleon"))
            .. " Jimoleons, " .. tostring(ParadiseEconomy.getBalance(tab, "paradisium")) .. " Paradisium"
    end
    return table.concat(parts, " | ")
end

function ParadiseEconomy.isWallet(item)
    return item and item.getFullType and ParadiseEconomy.walletTypes[item:getFullType()] == true
end

function ParadiseEconomy.getWalletData(item)
    if not ParadiseEconomy.isWallet(item) or not item.getModData then return nil end
    local md = item:getModData()
    md[ParadiseEconomy.walletKey] = md[ParadiseEconomy.walletKey] or { jimoleon = 0, paradisium = 0 }
    return md[ParadiseEconomy.walletKey]
end

function ParadiseEconomy.getPlayerData(pl)
    if not pl or not pl.getModData then return nil end
    local md = pl:getModData()
    md[ParadiseEconomy.playerKey] = md[ParadiseEconomy.playerKey] or { jimoleon = 0, paradisium = 0 }
    return md[ParadiseEconomy.playerKey]
end

function ParadiseEconomy.hasMoney(tab)
    return ParadiseEconomy.getBalance(tab, "jimoleon") > 0 or ParadiseEconomy.getBalance(tab, "paradisium") > 0
end

function ParadiseEconomy.formatBalances(tab)
    return tostring(ParadiseEconomy.getBalance(tab, "jimoleon")) .. " Jimoleons, "
        .. tostring(ParadiseEconomy.getBalance(tab, "paradisium")) .. " Paradisium"
end

function ParadiseEconomy.getHUDPosition(screenWidth, width, height, clockX, clockY)
    screenWidth = tonumber(screenWidth) or 0
    width = tonumber(width) or 270
    if clockX ~= nil and clockY ~= nil then
        return math.max(10, math.floor(tonumber(clockX) - width - 10)), math.max(10, math.floor(tonumber(clockY)))
    end
    return math.max(10, math.floor(screenWidth - width - 20)), 80
end

function ParadiseEconomy.getTradeZone(pl)
    pl = pl or getPlayer()
    if not pl then return nil end
    local vehicle = pl.getVehicle and pl:getVehicle() or nil
    local x = vehicle and vehicle:getX() or pl:getX()
    local y = vehicle and vehicle:getY() or pl:getY()
    local z = pl:getZ()
    local padding = vehicle and 2.0 or 0
    if ParadiseDev and ParadiseDev.Zones and ParadiseDev.Zones.Engine and ParadiseDev.Zones.Engine.getAuthority then
        local engine = ParadiseDev.Zones.Engine
        local zone = engine.getAuthority(x, y, z, padding)
        if zone and zone.features and zone.features.isTrade == true then return zone end
        if engine.getCandidateZones and engine.zoneContains then
            for _, candidate in ipairs(engine.getCandidateZones(x, y, padding)) do
                local inside = engine.zoneContains(candidate, x, y, z, padding)
                if inside and candidate.features and candidate.features.isTrade == true then return candidate end
            end
        end
    end
    if ParadiseDev and ParadiseDev.Zones and ParadiseDev.Zones.Border and ParadiseDev.Zones.Border.getZoneFor then
        local border = ParadiseDev.Zones.Border
        local zone = border.getZoneFor(pl)
        if zone and zone.features and zone.features.isTrade == true then return zone end
        if border.zoneContains then
            for _, candidate in ipairs(border.zones or {}) do
                if candidate.features and candidate.features.isTrade == true and border.zoneContains(candidate, x, y, z) then
                    return candidate
                end
            end
        end
    end
    return nil
end

function ParadiseEconomy.isInTradeZone(pl)
    local zone = ParadiseEconomy.getTradeZone(pl)
    return zone ~= nil and zone.features ~= nil and zone.features.isTrade == true
end

function ParadiseEconomy.isEnabled()
    local sand = SandboxVars and SandboxVars.ParadiseZ or nil
    return not sand or sand.PlayerEconomyEnabled ~= false
end

function ParadiseEconomy.isTradeZoneOnly()
    local sand = SandboxVars and SandboxVars.ParadiseZ or nil
    return not sand or sand.PlayerEconomyTradeZoneOnly ~= false
end

function ParadiseEconomy.getPlayerShopTaxPercent()
    local sand = SandboxVars and SandboxVars.ParadiseZ or nil
    local percent = tonumber(sand and sand.PlayerShopTaxPercent) or 5
    return math.max(0, math.min(100, percent))
end

function ParadiseEconomy.normalizeTradeTaxPercent(percent)
    percent = tonumber(percent)
    if not percent then return nil end
    return math.max(0, math.min(100, math.floor(percent)))
end

function ParadiseEconomy.getTradeTaxPercent(account)
    local percent = type(account) == "table" and ParadiseEconomy.normalizeTradeTaxPercent(account.tradeTax) or nil
    return percent or ParadiseEconomy.getPlayerShopTaxPercent()
end

function ParadiseEconomy.getPlayerShopPayout(price, percent)
    price = ParadiseEconomy.normalizeAmount(price)
    if not price then return nil, nil end
    percent = ParadiseEconomy.normalizeTradeTaxPercent(percent) or ParadiseEconomy.getPlayerShopTaxPercent()
    local tax = math.ceil(price * percent / 100)
    return price - tax, tax
end

ParadiseEconomy.defaultMerchantLeaseDays = 7
ParadiseEconomy.merchantLeaseDayMs = 86400000

function ParadiseEconomy.normalizeMerchantLeaseDays(days)
    days = tonumber(days)
    if not days then return nil end
    return math.max(0, math.min(365, math.floor(days)))
end

function ParadiseEconomy.getDefaultMerchantLeaseDays()
    local sand = SandboxVars and SandboxVars.ParadiseZ or nil
    local days = tonumber(sand and sand.MerchantLeaseDays)
    if days == nil then days = ParadiseEconomy.defaultMerchantLeaseDays end
    return math.max(0, math.min(365, math.floor(days)))
end

function ParadiseEconomy.getMerchantLeaseDays(trade)
    local days = type(trade) == "table" and ParadiseEconomy.normalizeMerchantLeaseDays(trade.merchantLeaseDays) or nil
    return days or ParadiseEconomy.getDefaultMerchantLeaseDays()
end

function ParadiseEconomy.getMerchantLeaseRemaining(account, now)
    local expiresAt = type(account) == "table" and tonumber(account.expiresAt) or 0
    if not expiresAt or expiresAt <= 0 then return nil end
    return math.max(0, expiresAt - (tonumber(now) or getTimestampMs()))
end

function ParadiseEconomy.isMerchantExpired(account, now)
    local remaining = ParadiseEconomy.getMerchantLeaseRemaining(account, now)
    return remaining ~= nil and remaining <= 0
end

function ParadiseEconomy.getMerchantLeaseStatus(account, now)
    local remaining = ParadiseEconomy.getMerchantLeaseRemaining(account, now)
    if remaining == nil then return "none" end
    if remaining <= 0 then return "expired" end
    if remaining <= ParadiseEconomy.merchantLeaseDayMs then return "expiring" end
    return "active"
end

function ParadiseEconomy.formatMerchantLeaseDuration(ms)
    ms = tonumber(ms)
    if not ms then return "No expiry" end
    if ms <= 0 then return "Expired" end
    local totalMinutes = math.floor(ms / 60000)
    local days = math.floor(totalMinutes / 1440)
    local hours = math.floor((totalMinutes % 1440) / 60)
    local minutes = totalMinutes % 60
    if days > 0 then return tostring(days) .. "d " .. tostring(hours) .. "h" end
    if hours > 0 then return tostring(hours) .. "h " .. tostring(minutes) .. "m" end
    return tostring(math.max(1, minutes)) .. "m"
end

function ParadiseEconomy.getMerchantLeaseLabel(account, now)
    local status = ParadiseEconomy.getMerchantLeaseStatus(account, now)
    if status == "none" then return "No expiry" end
    if status == "expired" then return "Expired" end
    return ParadiseEconomy.formatMerchantLeaseDuration(ParadiseEconomy.getMerchantLeaseRemaining(account, now)) .. " left"
end

function ParadiseEconomy.canManageEconomy()
    if not ParadiseEconomy.isEnabled() then return false end
    local sand = SandboxVars and SandboxVars.ParadiseZ or nil
    return not sand or sand.AdminsCanManageEconomy ~= false
end

function ParadiseEconomy.canUsePlayerEconomy(pl)
    if not ParadiseEconomy.isEnabled() then return false end
    return not ParadiseEconomy.isTradeZoneOnly() or ParadiseEconomy.isInTradeZone(pl)
end

function ParadiseEconomy.normalizeTradeZoneTitle(title)
    title = tostring(title or ""):match("^%s*(.-)%s*$")
    if title == "" or #title > 128 then return nil end
    return title
end

function ParadiseEconomy.tradeZoneKey(title)
    title = ParadiseEconomy.normalizeTradeZoneTitle(title)
    return title and string.lower(title) or nil
end

function ParadiseEconomy.getTradeZoneTitle(pl)
    local zone = ParadiseEconomy.getTradeZone(pl)
    if not zone or not zone.features or zone.features.isTrade ~= true then return nil end
    return ParadiseEconomy.normalizeTradeZoneTitle(zone.name or zone.id)
end

function ParadiseEconomy.newPlayerListing(id, seller, itemData, currency, price, createdAt, zoneTitle, zoneId, merchantAccountId)
    seller = ParadiseEconomy.normalizeUsername(seller)
    currency = ParadiseEconomy.normalizeCurrency(currency)
    price = ParadiseEconomy.normalizeAmount(price)
    zoneTitle = ParadiseEconomy.normalizeTradeZoneTitle(zoneTitle)
    zoneId = ParadiseEconomy.normalizeZoneId(zoneId)
    if not id or not seller or type(itemData) ~= "table" or not itemData.fullType or not currency or not price then return nil end
    return {
        id = tostring(id),
        seller = seller,
        itemData = itemData,
        currency = currency,
        price = price,
        createdAt = tonumber(createdAt) or 0,
        zoneTitle = zoneTitle,
        zoneId = zoneId,
        merchantAccountId = merchantAccountId and tostring(merchantAccountId) or nil,
    }
end

if isClient and isClient() then return end
