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
ParadiseEconomy.accountTypes = { personal = true, merchant = true, trade = true, finance = true, server = true, custom = true }
ParadiseEconomy.accountTypeLabels = {
    personal = "Personal",
    merchant = "Merchant",
    trade = "Treasury",
    finance = "Finance",
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
    if account.type == "personal" or account.type == "trade" or account.type == "finance" then return "digital" end
    if account.type == "merchant" then return "earnings" end
    return "balances"
end

function ParadiseEconomy.getAccountBuckets(account)
    if type(account) ~= "table" then return {} end
    if account.type == "personal" then
        return { { key = "digital", label = "Digital" }, { key = "onhand", label = "On Hand" } }
    elseif account.type == "trade" then
        return { { key = "digital", label = "Treasury" } }
    elseif account.type == "finance" then
        return { { key = "digital", label = "Finance" } }
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
    if account.type == "trade" then return "Treasury · " .. tostring(title) end
    if account.type == "finance" then return "Finance · " .. tostring(title) end
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

function ParadiseEconomy.normalizeMerchantDailyFee(fee)
    fee = tonumber(fee)
    if not fee then return nil end
    return math.max(0, math.min(2147483647, math.floor(fee)))
end

function ParadiseEconomy.getMerchantDailyFee(tradeOrZone)
    local fee = type(tradeOrZone) == "table" and ParadiseEconomy.normalizeMerchantDailyFee(tradeOrZone.merchantDailyFee) or nil
    return fee or 0
end

function ParadiseEconomy.normalizeMerchantFeeCurrency(currency)
    currency = string.lower(tostring(currency or ""))
    return ParadiseEconomy.currencies[currency] and currency or nil
end

function ParadiseEconomy.getMerchantFeeCurrency(tradeOrZone)
    local currency = type(tradeOrZone) == "table"
        and ParadiseEconomy.normalizeMerchantFeeCurrency(tradeOrZone.merchantFeeCurrency) or nil
    return currency or "jimoleon"
end

function ParadiseEconomy.getMerchantFeeDue(days, fee)
    days = tonumber(days) or 0
    fee = ParadiseEconomy.normalizeMerchantDailyFee(fee) or 0
    if days <= 0 or fee <= 0 then return 0 end
    return math.min(2147483647, math.floor(days) * fee)
end

function ParadiseEconomy.isAccountFrozen(account)
    return type(account) == "table" and account.frozen == true
end

function ParadiseEconomy.getAccountStatus(account)
    if type(account) ~= "table" then return "unknown" end
    if account.archived == true then return "archived" end
    if ParadiseEconomy.isAccountFrozen(account) then return "frozen" end
    if account.type == "merchant" and account.suspended == true then return "suspended" end
    if account.type == "merchant" and ParadiseEconomy.isMerchantExpired(account) then return "expired" end
    return "active"
end

function ParadiseEconomy.isMerchantClosed(account, now)
    if type(account) ~= "table" or account.type ~= "merchant" then return true end
    if account.archived == true or account.suspended == true then return true end
    return ParadiseEconomy.isMerchantExpired(account, now)
end

function ParadiseEconomy.getMerchantStatus(account, now)
    if type(account) ~= "table" or account.type ~= "merchant" then return "unknown" end
    if account.archived == true then return "archived" end
    if account.suspended == true then return "suspended" end
    if ParadiseEconomy.isMerchantExpired(account, now) then return "expired" end
    return "active"
end

function ParadiseEconomy.getMerchantStatusLabel(account, now)
    local status = ParadiseEconomy.getMerchantStatus(account, now)
    if status == "suspended" then return "Suspended" end
    if status == "expired" then return "Suspended · lease expired" end
    if status == "archived" then return "Closed" end
    return "Active"
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

function ParadiseEconomy.formatNumber(value)
    local text = tostring(math.floor(tonumber(value) or 0))
    local sign = ""
    if string.sub(text, 1, 1) == "-" then
        sign = "-"
        text = string.sub(text, 2)
    end
    local grouped = string.reverse(text)
    grouped = string.gsub(grouped, "(%d%d%d)", "%1,")
    grouped = string.reverse(grouped)
    if string.sub(grouped, 1, 1) == "," then grouped = string.sub(grouped, 2) end
    return sign .. grouped
end

function ParadiseEconomy.getItemDisplayName(fullType)
    fullType = tostring(fullType or "")
    if fullType == "" then return "" end
    local manager = getScriptManager and getScriptManager() or nil
    local script = manager and manager.getItem and manager:getItem(fullType) or nil
    local name = script and script.getDisplayName and script:getDisplayName() or nil
    if name and tostring(name) ~= "" then return tostring(name) end
    return (string.gsub(fullType, "^Base%.", ""))
end

ParadiseEconomy.Ledger = ParadiseEconomy.Ledger or {}
local Ledger = ParadiseEconomy.Ledger

Ledger.digits = "0123456789abcdefghijklmnopqrstuvwxyz"

function Ledger.base36(value)
    value = math.floor(tonumber(value) or 0)
    if value <= 0 then return "0" end
    local out = ""
    while value > 0 do
        local rem = value % 36
        out = string.sub(Ledger.digits, rem + 1, rem + 1) .. out
        value = math.floor(value / 36)
    end
    return out
end

function Ledger.unbase36(text)
    text = string.lower(tostring(text or ""))
    local value = 0
    for index = 1, #text do
        local char = string.sub(text, index, index)
        local found = string.find(Ledger.digits, char, 1, true)
        if not found then return nil end
        value = value * 36 + (found - 1)
    end
    return value
end

function Ledger.dayKey(time)
    return os.date("%Y-%m-%d", math.floor(tonumber(time) or os.time()))
end

function Ledger.timeOfDay(time)
    local h, m, s = string.match(os.date("%H:%M:%S", math.floor(tonumber(time) or os.time())), "(%d+):(%d+):(%d+)")
    return (tonumber(h) or 0) * 3600 + (tonumber(m) or 0) * 60 + (tonumber(s) or 0)
end

function Ledger.timeText(rec)
    local tod = math.floor(tonumber(rec and (rec.tod or rec.t)) or 0) % 86400
    return string.format("%02d:%02d", math.floor(tod / 3600), math.floor((tod % 3600) / 60))
end

function Ledger.currencyCode(currency)
    currency = string.lower(tostring(currency or ""))
    if currency == "jimoleon" then return "j" end
    if currency == "paradisium" then return "p" end
    if currency == "j" or currency == "p" then return currency end
    return ""
end

function Ledger.currencyName(code)
    if code == "j" then return "jimoleon" end
    if code == "p" then return "paradisium" end
    return ""
end

local function cleanField(value)
    local text = tostring(value or "")
    if text == "" then return "" end
    return (string.gsub(text, "|", "/"))
end

local function splitFields(text)
    local parts = {}
    local start = 1
    while true do
        local pos = string.find(text, "|", start, true)
        if not pos then
            parts[#parts + 1] = string.sub(text, start)
            break
        end
        parts[#parts + 1] = string.sub(text, start, pos - 1)
        start = pos + 1
    end
    return parts
end

local function normalizeKind(kind)
    if kind == "B" or kind == "T" or kind == "L" or kind == "S" or kind == "C" then return kind end
    return "G"
end

function Ledger.encode(rec)
    if type(rec) ~= "table" then return "" end
    local kind = normalizeKind(tostring(rec.kind or "G"))
    local tod = rec.tod or Ledger.timeOfDay(rec.time or os.time())
    local parts = { kind, Ledger.base36(tod) }
    if kind == "B" then
        parts[#parts + 1] = cleanField(rec.a)
        parts[#parts + 1] = cleanField(rec.b)
        parts[#parts + 1] = Ledger.currencyCode(rec.cur)
        parts[#parts + 1] = Ledger.base36(rec.amount)
        parts[#parts + 1] = Ledger.base36(rec.tax)
        parts[#parts + 1] = cleanField(rec.taxAcc)
        parts[#parts + 1] = cleanField(rec.item)
        parts[#parts + 1] = Ledger.base36(rec.qty or 1)
        parts[#parts + 1] = cleanField(rec.zone)
    elseif kind == "T" then
        parts[#parts + 1] = cleanField(rec.reason)
        parts[#parts + 1] = cleanField(rec.a)
        parts[#parts + 1] = cleanField(rec.b)
        parts[#parts + 1] = Ledger.currencyCode(rec.cur)
        parts[#parts + 1] = Ledger.base36(rec.amount)
        parts[#parts + 1] = cleanField(rec.note)
        parts[#parts + 1] = cleanField(rec.zone)
    elseif kind == "L" then
        parts[#parts + 1] = cleanField(rec.reason)
        parts[#parts + 1] = cleanField(rec.a)
        parts[#parts + 1] = Ledger.currencyCode(rec.cur)
        parts[#parts + 1] = Ledger.base36(rec.amount)
        parts[#parts + 1] = cleanField(rec.item)
        parts[#parts + 1] = Ledger.base36(rec.qty or 1)
        parts[#parts + 1] = cleanField(rec.zone)
    elseif kind == "S" then
        parts[#parts + 1] = cleanField(rec.reason)
        parts[#parts + 1] = cleanField(rec.a)
        parts[#parts + 1] = cleanField(rec.actor)
        parts[#parts + 1] = cleanField(rec.zone)
        parts[#parts + 1] = cleanField(rec.note)
    elseif kind == "C" then
        parts[#parts + 1] = cleanField(rec.reason)
        parts[#parts + 1] = cleanField(rec.actor)
        parts[#parts + 1] = cleanField(rec.b)
        parts[#parts + 1] = cleanField(rec.zone)
        parts[#parts + 1] = cleanField(rec.note)
    else
        parts[#parts + 1] = cleanField(rec.action)
        parts[#parts + 1] = cleanField(rec.actor)
        parts[#parts + 1] = cleanField(rec.a)
        parts[#parts + 1] = cleanField(rec.b)
        parts[#parts + 1] = Ledger.currencyCode(rec.cur)
        parts[#parts + 1] = Ledger.base36(rec.amount)
        parts[#parts + 1] = cleanField(rec.note)
    end
    for index = #parts, 3, -1 do
        if parts[index] ~= "" then break end
        parts[index] = nil
    end
    return table.concat(parts, "|")
end

function Ledger.decode(text, day)
    local rec = { kind = "G", day = day, raw = tostring(text or ""), tod = 0, note = "" }
    local parts = splitFields(tostring(text or ""))
    local kind = normalizeKind(parts[1] or "G")
    rec.kind = kind
    rec.tod = Ledger.unbase36(parts[2]) or 0
    if kind == "B" then
        rec.a = parts[3] or ""
        rec.b = parts[4] or ""
        rec.cur = Ledger.currencyName(parts[5])
        rec.amount = Ledger.unbase36(parts[6]) or 0
        rec.tax = Ledger.unbase36(parts[7]) or 0
        rec.taxAcc = parts[8] or ""
        rec.item = parts[9] or ""
        rec.qty = Ledger.unbase36(parts[10]) or 1
        rec.zone = parts[11] or ""
    elseif kind == "T" then
        rec.reason = parts[3] or ""
        rec.a = parts[4] or ""
        rec.b = parts[5] or ""
        rec.cur = Ledger.currencyName(parts[6])
        rec.amount = Ledger.unbase36(parts[7]) or 0
        rec.note = parts[8] or ""
        rec.zone = parts[9] or ""
    elseif kind == "L" then
        rec.reason = parts[3] or ""
        rec.a = parts[4] or ""
        rec.cur = Ledger.currencyName(parts[5])
        rec.amount = Ledger.unbase36(parts[6]) or 0
        rec.item = parts[7] or ""
        rec.qty = Ledger.unbase36(parts[8]) or 1
        rec.zone = parts[9] or ""
    elseif kind == "S" then
        rec.reason = parts[3] or ""
        rec.a = parts[4] or ""
        rec.actor = parts[5] or ""
        rec.zone = parts[6] or ""
        rec.note = parts[7] or ""
    elseif kind == "C" then
        rec.reason = parts[3] or ""
        rec.actor = parts[4] or ""
        rec.b = parts[5] or ""
        rec.zone = parts[6] or ""
        rec.note = parts[7] or ""
    else
        rec.reason = ""
        rec.action = parts[3] or ""
        rec.actor = parts[4] or ""
        rec.a = parts[5] or ""
        rec.b = parts[6] or ""
        rec.cur = Ledger.currencyName(parts[7])
        rec.amount = Ledger.unbase36(parts[8]) or 0
        rec.note = parts[9] or ""
    end
    return rec
end

function Ledger.debugEncode(rec)
    return Ledger.encode(rec)
end

function Ledger.debugDecode(text, day)
    return Ledger.decode(text, day)
end

Ledger.actions = {
    ["market purchase"] = { kind = "B" },
    ["market sale"] = { kind = "B" },
    ["player shop purchase"] = { kind = "B" },
    ["player shop posted"] = { kind = "L", reason = "p" },
    ["player shop cancelled"] = { kind = "L", reason = "c" },
    ["market listing saved"] = { kind = "L", reason = "s" },
    ["merchant store registered"] = { kind = "S", reason = "rg" },
    ["market created"] = { kind = "S", reason = "rg" },
    ["merchant suspended"] = { kind = "S", reason = "su" },
    ["merchant resumed"] = { kind = "S", reason = "rs" },
    ["merchant lease renewed"] = { kind = "S", reason = "rn" },
    ["merchant lease expired"] = { kind = "S", reason = "ex" },
    ["merchant lease clear"] = { kind = "S", reason = "rn" },
    ["merchant renamed"] = { kind = "S", reason = "nm" },
    ["market renamed"] = { kind = "S", reason = "nm" },
    ["trade renamed"] = { kind = "S", reason = "nm" },
    ["admin froze account"] = { kind = "S", reason = "fz" },
    ["admin unfroze account"] = { kind = "S", reason = "uf" },
    ["merchant collected"] = { kind = "T", reason = "c" },
    ["deposited"] = { kind = "T", reason = "d" },
    ["migrated carried funds"] = { kind = "T", reason = "d" },
    ["withdrew"] = { kind = "T", reason = "w" },
    ["withdrew to wallet"] = { kind = "T", reason = "v" },
    ["transferred"] = { kind = "T", reason = "t" },
    ["treasury sweep"] = { kind = "T", reason = "s" },
    ["finance withdrawal"] = { kind = "T", reason = "f" },
    ["finance transfer"] = { kind = "T", reason = "g" },
    ["trade withdrawal"] = { kind = "T", reason = "r" },
    ["trade transfer"] = { kind = "T", reason = "a" },
    ["admin transfer"] = { kind = "T", reason = "x" },
    ["admin add"] = { kind = "T", reason = "+" },
    ["admin remove"] = { kind = "T", reason = "-" },
    ["admin set"] = { kind = "T", reason = "=" },
    ["trade tax collected"] = { kind = "T", reason = "y" },
    ["pillaged wallet"] = { kind = "T", reason = "l" },
    ["death wallet"] = { kind = "T", reason = "k" },
    ["merchant lease paid"] = { kind = "T", reason = "e" },
    ["trade tax set"] = { kind = "C", reason = "tx" },
    ["zone daily fee set"] = { kind = "C", reason = "fe" },
    ["zone owner set"] = { kind = "C", reason = "ow" },
    ["admin set trade owner"] = { kind = "C", reason = "ow" },
    ["admin set market owner"] = { kind = "C", reason = "mo" },
    ["admin set merchant tax route"] = { kind = "C", reason = "rt" },
    ["trade lease set"] = { kind = "C", reason = "ls" },
    ["admin created account"] = { kind = "C", reason = "ca" },
    ["admin deleted account"] = { kind = "C", reason = "da" },
    ["admin purged ledger"] = { kind = "C", reason = "pl" },
    ["admin rebuilt account indexes"] = { kind = "C", reason = "ri" },
}

function Ledger.fromLegacyTx(tx, resolveId)
    if type(tx) ~= "table" then return nil end
    local action = tostring(tx.action or "")
    local mapped = Ledger.actions[action] or { kind = "G" }
    local rec = {
        kind = mapped.kind,
        reason = mapped.reason,
        time = tonumber(tx.time) or os.time(),
        actor = tostring(tx.username or ""),
        a = tostring(tx.accountId or ""),
        b = tostring(tx.counterpartyId or ""),
        cur = Ledger.currencyCode(tx.currency),
        amount = tonumber(tx.amount) or 0,
        zone = tostring(tx.zoneId or ""),
        note = tostring(tx.detail or ""),
    }
    if resolveId then
        if rec.a == "" and tx.from then rec.a = resolveId(tx.from) or "" end
        if rec.b == "" and tx.to then rec.b = resolveId(tx.to) or "" end
    end
    local detail = tostring(tx.detail or "")
    if rec.kind == "B" then
        local qty, item = string.match(detail, "^(%d+)x%s+(.+)$")
        rec.qty = tonumber(qty) or 1
        rec.item = item or string.match(detail, ":(Base%.[^:]+):") or ""
        rec.tax = tonumber(string.match(detail, ":tax=(%d+)")) or 0
        rec.note = ""
    elseif rec.kind == "L" then
        rec.item = string.match(detail, "([^:]+)$") or ""
        rec.qty = 1
        rec.note = ""
    elseif rec.kind == "G" then
        rec.action = action
        rec.note = detail
    end
    return rec
end

function Ledger.involves(rec, accIds, user)
    if not rec or rec.kind == "C" then return false end
    accIds = accIds or {}
    if rec.kind == "S" then
        return rec.a ~= nil and rec.a ~= "" and accIds[rec.a] == true
    end
    if rec.a and rec.a ~= "" and accIds[rec.a] then return true end
    if rec.b and rec.b ~= "" and accIds[rec.b] then return true end
    if rec.actor and rec.actor ~= "" and user then
        local actorKey = ParadiseEconomy.usernameKey(rec.actor)
        if actorKey and actorKey == ParadiseEconomy.usernameKey(user) then return true end
    end
    return false
end

function Ledger.amountText(rec, sign)
    local value = ParadiseEconomy.formatNumber(rec and rec.amount or 0)
    local code = "j"
    if rec and rec.cur == "p" then code = "p" end
    if rec and rec.cur ~= "j" and rec.cur ~= "p" then code = "" end
    return (sign or "") .. value .. code
end

function Ledger.playerText(rec, ctx)
    ctx = ctx or {}
    local accIds = ctx.accIds or {}
    local names = ctx.names or {}
    local zones = ctx.zones or {}
    local function name(id)
        if not id or id == "" then return "unknown" end
        return names[id] or id
    end
    local function zoneName(id)
        if not id or id == "" then return "" end
        return zones[id] or id
    end
    local function owns(id) return id and id ~= "" and accIds[id] == true end
    local function itemName(fullType)
        if not fullType or fullType == "" then return "item" end
        if ctx.itemName then return ctx.itemName(fullType) end
        return ParadiseEconomy.getItemDisplayName(fullType)
    end
    local time = Ledger.timeText(rec)
    local amount = Ledger.amountText(rec, "")
    local kind = rec.kind
    if kind == "B" then
        local item = itemName(rec.item)
        local qty = tonumber(rec.qty) or 1
        local label = qty > 1 and (tostring(qty) .. "x " .. item) or item
        local tax = tonumber(rec.tax) or 0
        local taxText = tax > 0 and (" (tax " .. Ledger.amountText({ amount = tax, cur = rec.cur }, "") .. ")") or ""
        local at = rec.zone ~= "" and (" at " .. zoneName(rec.zone)) or ""
        if owns(rec.a) then
            return "You purchased " .. label .. " from " .. name(rec.b) .. " for " .. amount .. taxText .. at .. ", " .. time,
                "Buyer account " .. tostring(rec.a) .. " · seller " .. tostring(rec.b), "out", "-" .. amount
        end
        if owns(rec.b) then
            return name(rec.a) .. " purchased " .. label .. " from you for " .. amount .. taxText .. at .. ", " .. time,
                "Seller account " .. tostring(rec.b) .. " · buyer " .. tostring(rec.a), "in", "+" .. amount
        end
        return name(rec.a) .. " purchased " .. label .. " from " .. name(rec.b) .. " for " .. amount .. at .. ", " .. time,
            "", "flat", amount
    elseif kind == "T" then
        local reason = rec.reason or ""
        local actor = rec.actor and rec.actor ~= "" and rec.actor or name(rec.a)
        if reason == "d" then
            if owns(rec.a) then return "You deposited " .. amount .. ", " .. time, "", "flat", amount end
            return actor .. " deposited " .. amount .. ", " .. time, "", "flat", amount
        end
        if reason == "w" then
            if owns(rec.a) then return "You withdrew " .. amount .. ", " .. time, "", "flat", amount end
            return actor .. " withdrew " .. amount .. ", " .. time, "", "flat", amount
        end
        if reason == "v" then
            if owns(rec.a) then return "You moved " .. amount .. " into a wallet, " .. time, "", "flat", amount end
            return actor .. " moved " .. amount .. " into a wallet, " .. time, "", "flat", amount
        end
        if reason == "t" then
            if owns(rec.a) then return "You sent " .. amount .. " to " .. name(rec.b) .. ", " .. time, "", "out", "-" .. amount end
            if owns(rec.b) then return name(rec.a) .. " sent you " .. amount .. ", " .. time, "", "in", "+" .. amount end
            return name(rec.a) .. " sent " .. amount .. " to " .. name(rec.b) .. ", " .. time, "", "flat", amount
        end
        if reason == "c" then
            if owns(rec.a) then return "You collected " .. amount .. " from your store, " .. time, "", "in", "+" .. amount end
            if owns(rec.b) then return name(rec.a) .. " collected " .. amount .. " into your account, " .. time, "", "flat", amount end
            return name(rec.a) .. " collected " .. amount .. ", " .. time, "", "flat", amount
        end
        if reason == "s" then return "Treasury swept " .. amount .. " into finance, " .. time, "", "flat", amount end
        if reason == "f" or reason == "g" or reason == "r" or reason == "a" then
            if owns(rec.a) then return "You transferred " .. amount .. " to " .. name(rec.b) .. ", " .. time, "", "out", "-" .. amount end
            if owns(rec.b) then return name(rec.a) .. " transferred " .. amount .. " to your account, " .. time, "", "in", "+" .. amount end
            return name(rec.a) .. " transferred " .. amount .. " to " .. name(rec.b) .. ", " .. time, "", "flat", amount
        end
        if reason == "x" or reason == "+" or reason == "-" or reason == "=" then
            local color = reason == "+" and "in" or (reason == "-" and "out" or "flat")
            local sign = reason == "+" and "+" or (reason == "-" and "-" or "")
            if owns(rec.b) then
                return "An admin adjusted your account by " .. sign .. amount .. ", " .. time, "", color, sign .. amount
            end
            if owns(rec.a) then
                return "An admin adjusted this account by " .. sign .. amount .. ", " .. time, "", color, sign .. amount
            end
            return "Admin adjusted an account by " .. sign .. amount .. ", " .. time, "", "flat", amount
        end
        if reason == "y" then
            if owns(rec.a) then return "You received " .. amount .. " in tax, " .. time, "", "in", "+" .. amount end
            if owns(rec.b) then return amount .. " tax collected from your sale, " .. time, "", "flat", amount end
            return amount .. " tax collected, " .. time, "", "flat", amount
        end
        if reason == "l" then
            if owns(rec.a) then return "You recovered " .. amount .. " from a wallet, " .. time, "", "in", "+" .. amount end
            return actor .. " recovered " .. amount .. " from a wallet, " .. time, "", "flat", amount
        end
        if reason == "k" then
            if owns(rec.a) then return "You lost " .. amount .. " when your wallet dropped, " .. time, "", "out", "-" .. amount end
            return actor .. " lost " .. amount .. " from a wallet on death, " .. time, "", "flat", amount
        end
        if reason == "e" then
            if owns(rec.a) then return "You paid " .. amount .. " for your store lease, " .. time, "", "out", "-" .. amount end
            return name(rec.a) .. " paid " .. amount .. " for a store lease, " .. time, "", "flat", amount
        end
        return "Moved " .. amount .. " from " .. name(rec.a) .. " to " .. name(rec.b) .. ", " .. time, "", "flat", amount
    elseif kind == "L" then
        local item = itemName(rec.item)
        local who = owns(rec.a) and "You" or name(rec.a)
        if rec.reason == "p" then return who .. " listed " .. item .. " for " .. amount .. ", " .. time, "", "flat", amount end
        if rec.reason == "c" then return who .. " cancelled the listing of " .. item .. " (" .. amount .. "), " .. time, "", "flat", amount end
        return "Listing updated: " .. item .. " at " .. amount .. ", " .. time, "", "flat", amount
    elseif kind == "S" then
        local acc = tostring(rec.a or "")
        local subject = owns(rec.a) and ("Your account " .. acc) or ("Account " .. acc)
        local actor = tostring(rec.actor or "system")
        local note = rec.note ~= "" and rec.note or ""
        if rec.reason == "su" then return subject .. " (merchant) was suspended by " .. actor .. ", " .. time, note, "flat", "" end
        if rec.reason == "rs" then return subject .. " was resumed by " .. actor .. ", " .. time, note, "flat", "" end
        if rec.reason == "rg" then return subject .. " was registered, " .. time, note, "flat", "" end
        if rec.reason == "rn" then return subject .. " lease was renewed by " .. actor .. ", " .. time, note, "flat", "" end
        if rec.reason == "ex" then return subject .. " lease has expired, " .. time, note, "flat", "" end
        if rec.reason == "fz" then return subject .. " was frozen by " .. actor .. ", " .. time, note, "flat", "" end
        if rec.reason == "uf" then return subject .. " was unfrozen by " .. actor .. ", " .. time, note, "flat", "" end
        if rec.reason == "nm" then return subject .. " was renamed, " .. time, note, "flat", "" end
        return subject .. " updated, " .. time, note, "flat", ""
    end
    if kind == "G" then
        return tostring(rec.action or "Transaction") .. " · " .. amount .. ", " .. time, tostring(rec.note or ""), "flat", amount
    end
    return "Transaction, " .. time, "", "flat", ""
end

function Ledger.adminText(rec)
    local time = Ledger.timeText(rec)
    local amount = Ledger.amountText(rec, "")
    local kind = rec.kind
    local zoneText = rec.zone and rec.zone ~= "" and ("  zone:" .. tostring(rec.zone)) or ""
    local noteText = rec.note and rec.note ~= "" and ("  " .. tostring(rec.note)) or ""
    if kind == "B" then
        local taxText = (tonumber(rec.tax) or 0) > 0
            and ("  tax " .. Ledger.amountText({ amount = rec.tax, cur = rec.cur }, "") .. " > " .. tostring(rec.taxAcc)) or ""
        return string.format("%s  B  %s > %s  %s%s  %s x%s%s", time, tostring(rec.a), tostring(rec.b), amount, taxText,
            tostring(rec.item), tostring(rec.qty or 1), zoneText)
    end
    if kind == "T" then
        return string.format("%s  T:%s  %s > %s  %s%s%s", time, tostring(rec.reason), tostring(rec.a), tostring(rec.b),
            amount, noteText, zoneText)
    end
    if kind == "L" then
        return string.format("%s  L:%s  %s  %s  %s x%s%s", time, tostring(rec.reason), tostring(rec.a), amount,
            tostring(rec.item), tostring(rec.qty or 1), zoneText)
    end
    if kind == "S" then
        return string.format("%s  S:%s  %s  by %s%s%s", time, tostring(rec.reason), tostring(rec.a), tostring(rec.actor),
            zoneText, noteText)
    end
    if kind == "C" then
        return string.format("%s  C:%s  %s > %s%s%s", time, tostring(rec.reason), tostring(rec.actor), tostring(rec.b),
            zoneText, noteText)
    end
    return string.format("%s  G  %s  %s > %s  %s%s", time, tostring(rec.action), tostring(rec.a), tostring(rec.b),
        amount, noteText)
end

function Ledger.adminDetail(rec)
    local lines = {
        "raw: " .. tostring(rec.raw or ""),
        "day " .. tostring(rec.day or "") .. "  time " .. Ledger.timeText(rec),
        "kind " .. tostring(rec.kind or "") .. "  reason " .. tostring(rec.reason or ""),
        "actor " .. tostring(rec.actor or "") .. "  zone " .. tostring(rec.zone or ""),
        "account " .. tostring(rec.a or "") .. "  counterparty " .. tostring(rec.b or ""),
        "currency " .. tostring(rec.cur or "") .. "  amount " .. tostring(rec.amount or 0),
    }
    if (tonumber(rec.tax) or 0) > 0 then
        lines[#lines + 1] = "tax " .. tostring(rec.tax) .. "  tax account " .. tostring(rec.taxAcc or "")
    end
    if rec.item and rec.item ~= "" then
        lines[#lines + 1] = "item " .. tostring(rec.item) .. " x" .. tostring(rec.qty or 1)
    end
    if rec.note and rec.note ~= "" then lines[#lines + 1] = "note " .. tostring(rec.note) end
    if rec.action and rec.action ~= "" then lines[#lines + 1] = "action " .. tostring(rec.action) end
    return lines
end

if isClient and isClient() then return end
