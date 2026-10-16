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

function ParadiseEconomy.normalizeUsername(user)
    user = tostring(user or ""):match("^%s*(.-)%s*$")
    if user == "" or #user > 64 then return nil end
    return user
end

function ParadiseEconomy.usernameKey(user)
    user = ParadiseEconomy.normalizeUsername(user)
    return user and string.lower(user) or nil
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

function ParadiseEconomy.isTradeZoneOnly()
    local sand = SandboxVars and SandboxVars.ParadiseZ or nil
    return not sand or sand.PlayerEconomyTradeZoneOnly ~= false
end

function ParadiseEconomy.getPlayerShopTaxPercent()
    local sand = SandboxVars and SandboxVars.ParadiseZ or nil
    local percent = tonumber(sand and sand.PlayerShopTaxPercent) or 5
    return math.max(0, math.min(100, percent))
end

function ParadiseEconomy.getPlayerShopPayout(price)
    price = ParadiseEconomy.normalizeAmount(price)
    if not price then return nil, nil end
    local tax = math.ceil(price * ParadiseEconomy.getPlayerShopTaxPercent() / 100)
    return price - tax, tax
end

function ParadiseEconomy.canUsePlayerEconomy(pl)
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

function ParadiseEconomy.newPlayerListing(id, seller, itemData, currency, price, createdAt, zoneTitle)
    seller = ParadiseEconomy.normalizeUsername(seller)
    currency = ParadiseEconomy.normalizeCurrency(currency)
    price = ParadiseEconomy.normalizeAmount(price)
    zoneTitle = ParadiseEconomy.normalizeTradeZoneTitle(zoneTitle)
    if not id or not seller or type(itemData) ~= "table" or not itemData.fullType or not currency or not price then return nil end
    return {
        id = tostring(id),
        seller = seller,
        itemData = itemData,
        currency = currency,
        price = price,
        createdAt = tonumber(createdAt) or 0,
        zoneTitle = zoneTitle,
    }
end

if isClient and isClient() then return end
