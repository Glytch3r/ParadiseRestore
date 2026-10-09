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

if isClient and isClient() then return end
