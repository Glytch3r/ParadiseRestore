ParadiseEconomy = ParadiseEconomy or {}

ParadiseEconomy.module = "ParadiseEconomy"
ParadiseEconomy.storeName = "ParadiseEconomy"
ParadiseEconomy.countKey = "ParadiseEconomyCount"
ParadiseEconomy.weightPerCoin = 0.001
ParadiseEconomy.coinTypes = {
    ["ParadiseZ.FU_GoldCoin"] = { key = "gold", label = "FU Gold Coin" },
    ["ParadiseZ.FU_SilverCoin"] = { key = "silver", label = "FU Silver Coin" },
}

function ParadiseEconomy.getCoin(item)
    return item and item.getFullType and ParadiseEconomy.coinTypes[item:getFullType()] or nil
end

function ParadiseEconomy.getCount(item)
    local value = item and item.getModData and tonumber(item:getModData()[ParadiseEconomy.countKey]) or nil
    return value and math.max(1, math.floor(value)) or 1
end

function ParadiseEconomy.hasStack(item)
    return item and item.getModData and item:getModData()[ParadiseEconomy.countKey] ~= nil
end

function ParadiseEconomy.setCount(item, count)
    local coin = ParadiseEconomy.getCoin(item)
    if not coin or not item.getModData then return false end
    count = math.max(1, math.floor(tonumber(count) or 1))
    item:getModData()[ParadiseEconomy.countKey] = count
    item:setName(coin.label .. " [" .. tostring(count) .. "]")
    if item.setActualWeight then item:setActualWeight(ParadiseEconomy.weightPerCoin * count) end
    return true
end

function ParadiseEconomy.getBalance(data, key)
    return math.max(0, math.floor(tonumber(data and data[key]) or 0))
end
