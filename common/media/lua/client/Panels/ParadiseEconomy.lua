require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
require "ISUI/ISComboBox"
require "ISUI/ISScrollingListBox"
require "ISUI/ISPanel"
require "ISUI/ISModalDialog"
require "ISUI/ISInventoryPane"
require "ISUI/ISMouseDrag"
require "TimedActions/ISInventoryTransferAction"
require "TimedActions/ISTimedActionQueue"

ParadiseEconomy = ParadiseEconomy or {}

function ParadiseEconomy.clearLegacyMartPanels()
    local panels = {
        ParadiseEconomy.martAdminInstance,
        ParadiseEconomy.MartAdminPanel and ParadiseEconomy.MartAdminPanel.instance or nil,
        ParadiseEconomy.martInstance,
    }
    for _, panel in pairs(panels) do
        if panel.setVisible then panel:setVisible(false) end
        if panel.removeFromUIManager then panel:removeFromUIManager() end
    end
    ParadiseEconomy.martAdminInstance = nil
    ParadiseEconomy.martInstance = nil
    ParadiseEconomy.MartAdminPanel = nil
end
ParadiseEconomy.clearLegacyMartPanels()

ParadiseEconomy.clientState = ParadiseEconomy.clientState or {
    personal = { digital = {}, onhand = {} },
    merchants = {},
    accounts = {},
    zones = {},
    ledgerRows = {},
    orphanedPlayerListings = {},
    shops = {},
    myShops = {},
    marts = {},
    shop = nil,
    shopCache = {},
    market = { marts = {}, playerListings = {} },
}
ParadiseEconomy.accountFilterTypes = ParadiseEconomy.accountFilterTypes or {
    { key = "all", label = "All accounts" },
    { key = "personal", label = "Personal" },
    { key = "merchant", label = "Merchant" },
    { key = "trade", label = "Trade" },
    { key = "server", label = "Server" },
    { key = "custom", label = "Custom / Future" },
}
ParadiseEconomy.accountCreateTypes = ParadiseEconomy.accountCreateTypes or {
    { key = "personal", label = "Personal" },
    { key = "merchant", label = "Merchant" },
    { key = "trade", label = "Trade" },
    { key = "custom", label = "Custom" },
}
ParadiseEconomy.tableTypes = ParadiseEconomy.tableTypes or {
    { key = "accounts", label = "Accounts" },
    { key = "zones", label = "Trade Zones" },
    { key = "tradeMarts", label = "Trade Item Marts" },
    { key = "merchantListings", label = "Merchant Listings" },
    { key = "playerListings", label = "Player Listings" },
    { key = "orphaned", label = "Orphaned Listings" },
}
ParadiseEconomy.icons = ParadiseEconomy.icons or {
    jimoleon = getTexture("media/ui/Paradise/Economy/Jimoleon.png"),
    paradisium = getTexture("media/ui/Paradise/Economy/Paradisium.png"),
}

ParadiseEconomy.Theme = {
    windowBg = { r = 0.050, g = 0.065, b = 0.085, a = 0.97 },
    panelBg = { r = 0.070, g = 0.090, b = 0.115, a = 0.96 },
    cardBg = { r = 0.090, g = 0.118, b = 0.145, a = 0.96 },
    cardBgAlt = { r = 0.078, g = 0.100, b = 0.125, a = 0.92 },
    entryBg = { r = 0.035, g = 0.048, b = 0.062, a = 0.95 },
    listBg = { r = 0.045, g = 0.060, b = 0.078, a = 0.95 },
    buttonBg = { r = 0.105, g = 0.145, b = 0.175, a = 1.0 },
    buttonHover = { r = 0.160, g = 0.235, b = 0.270, a = 1.0 },
    headerBg = { r = 0.060, g = 0.095, b = 0.115, a = 1.0 },
    border = { r = 0.235, g = 0.330, b = 0.395, a = 0.90 },
    borderSoft = { r = 0.160, g = 0.225, b = 0.275, a = 0.80 },
    accent = { r = 0.350, g = 0.780, b = 0.820, a = 1.0 },
    accentDim = { r = 0.185, g = 0.370, b = 0.410, a = 1.0 },
    gold = { r = 0.950, g = 0.780, b = 0.300, a = 1.0 },
    green = { r = 0.450, g = 0.860, b = 0.550, a = 1.0 },
    warn = { r = 0.980, g = 0.680, b = 0.250, a = 1.0 },
    danger = { r = 0.950, g = 0.360, b = 0.320, a = 1.0 },
    text = { r = 0.920, g = 0.950, b = 0.970, a = 1.0 },
    textDim = { r = 0.630, g = 0.710, b = 0.770, a = 1.0 },
    textMuted = { r = 0.470, g = 0.545, b = 0.610, a = 1.0 },
    rowSelected = { r = 0.140, g = 0.320, b = 0.300, a = 0.90 },
    rowAlt = { r = 0.085, g = 0.108, b = 0.132, a = 0.65 },
}

function ParadiseEconomy.styleWindow(window)
    local theme = ParadiseEconomy.Theme
    window.backgroundColor = theme.windowBg
    window.borderColor = theme.border
    window.titleBarFont = UIFont.Medium
end

function ParadiseEconomy.styleButton(button)
    local theme = ParadiseEconomy.Theme
    button.backgroundColor = theme.buttonBg
    button.backgroundColorMouseOver = theme.buttonHover
    button.borderColor = theme.border
    button.textColor = theme.text
    button.font = UIFont.Small
    button.displayBackground = true
end

function ParadiseEconomy.styleEntry(entry)
    local theme = ParadiseEconomy.Theme
    entry.backgroundColor = theme.entryBg
    entry.borderColor = theme.borderSoft
end

function ParadiseEconomy.styleCombo(combo)
    local theme = ParadiseEconomy.Theme
    combo.backgroundColor = theme.entryBg
    combo.backgroundColorMouseOver = theme.buttonHover
    combo.borderColor = theme.border
    combo.textColor = theme.text
end

function ParadiseEconomy.styleList(list)
    local theme = ParadiseEconomy.Theme
    list.backgroundColor = theme.listBg
    list.borderColor = theme.borderSoft
    list.listHeaderColor = theme.headerBg
end

function ParadiseEconomy.styleTree(panel, seen)
    seen = seen or {}
    if not panel or seen[panel] then return end
    seen[panel] = true
    for _, child in ipairs(panel.childrenInOrder or {}) do
        if child.isButton then
            ParadiseEconomy.styleButton(child)
        elseif child.getInternalText and child.javaObject then
            ParadiseEconomy.styleEntry(child)
        elseif child.addOption and child.options then
            ParadiseEconomy.styleCombo(child)
        elseif child.addItem and child.itemheight then
            ParadiseEconomy.styleList(child)
        elseif child.backgroundColor and child.borderColor and child.background then
            local theme = ParadiseEconomy.Theme
            child.backgroundColor = theme.panelBg
            child.borderColor = theme.borderSoft
        end
        ParadiseEconomy.styleTree(child, seen)
    end
end

function ParadiseEconomy.fitText(text, maxWidth, font)
    text = tostring(text or "")
    local textManager = getTextManager()
    font = font or UIFont.Small
    if textManager:MeasureStringX(font, text) <= maxWidth then return text end
    while #text > 3 and textManager:MeasureStringX(font, string.sub(text, 1, #text - 1) .. "...") > maxWidth do
        text = string.sub(text, 1, #text - 1)
    end
    return string.sub(text, 1, #text - 1) .. "..."
end

function ParadiseEconomy.drawCard(panel, x, y, w, h, accent)
    local theme = ParadiseEconomy.Theme
    panel:drawRect(x, y, w, h, theme.cardBg.a, theme.cardBg.r, theme.cardBg.g, theme.cardBg.b)
    panel:drawRectBorder(x, y, w, h, theme.borderSoft.a, theme.borderSoft.r, theme.borderSoft.g, theme.borderSoft.b)
    if accent then
        panel:drawRect(x, y, 3, h, accent.a, accent.r, accent.g, accent.b)
    end
end

function ParadiseEconomy.drawAdminChip(panel, x, y, label)
    local theme = ParadiseEconomy.Theme
    label = label or "ADMIN"
    local chipW = getTextManager():MeasureStringX(UIFont.Small, label) + 12
    panel:drawRect(x, y, chipW, 15, 0.14, theme.gold.r, theme.gold.g, theme.gold.b)
    panel:drawRectBorder(x, y, chipW, 15, 0.7, theme.gold.r, theme.gold.g, theme.gold.b)
    panel:drawText(label, x + 6, y + 1, theme.gold.r, theme.gold.g, theme.gold.b, 1, UIFont.Small)
    return chipW
end

function ParadiseEconomy.drawPanelHeader(panel, subtitle, badge, tag)
    local theme = ParadiseEconomy.Theme
    local w = panel.width
    panel:drawText(tostring(subtitle), 18, 29, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    if tag then
        local tagW = getTextManager():MeasureStringX(UIFont.Small, tag) + 14
        local tagX = w - 68 - 8 - tagW
        panel:drawRect(tagX, 26, tagW, 20, 0.14, theme.gold.r, theme.gold.g, theme.gold.b)
        panel:drawRectBorder(tagX, 26, tagW, 20, 0.7, theme.gold.r, theme.gold.g, theme.gold.b)
        panel:drawText(tag, tagX + 7, 30, theme.gold.r, theme.gold.g, theme.gold.b, 1, UIFont.Small)
    end
    panel:drawRect(w - 68, 22, 52, 28, theme.gold.a, theme.gold.r, theme.gold.g, theme.gold.b)
    panel:drawRectBorder(w - 68, 22, 52, 28, theme.gold.a, theme.gold.r, theme.gold.g, theme.gold.b)
    panel:drawTextCentre(tostring(badge), w - 42, 29, 0.06, 0.07, 0.08, 1, UIFont.Medium)
    panel:drawRect(15, 56, w - 30, 1, theme.borderSoft.a, theme.borderSoft.r, theme.borderSoft.g, theme.borderSoft.b)
end

function ParadiseEconomy.styleTabButton(button, active)
    local theme = ParadiseEconomy.Theme
    button.displayBackground = false
    button.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    button.backgroundColorMouseOver = { r = theme.accent.r, g = theme.accent.g, b = theme.accent.b, a = 0.10 }
    button.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    button.textColor = active and theme.text or theme.textMuted
    button.font = UIFont.Small
end

function ParadiseEconomy.drawTabUnderline(panel, button, active)
    local theme = ParadiseEconomy.Theme
    local color = active and theme.gold or theme.borderSoft
    panel:drawRect(button:getX() + 2, button:getY() + button:getHeight() - 2, button:getWidth() - 4, 2,
        active and 1 or 0.35, color.r, color.g, color.b)
end

function ParadiseEconomy.getItemInitials(name)
    local words = {}
    for word in tostring(name or "?"):gmatch("%S+") do words[#words + 1] = word end
    if #words == 0 then return "?" end
    if #words == 1 then return string.upper(string.sub(words[1], 1, 2)) end
    return string.upper(string.sub(words[1], 1, 1) .. string.sub(words[#words], 1, 1))
end

function ParadiseEconomy.getCategoryColor(category)
    local theme = ParadiseEconomy.Theme
    local key = string.lower(tostring(category or ""))
    if string.find(key, "weapon", 1, true) or string.find(key, "gun", 1, true) then return theme.danger end
    if string.find(key, "medical", 1, true) or string.find(key, "firstaid", 1, true) then return theme.green end
    if string.find(key, "food", 1, true) or string.find(key, "cook", 1, true) then return theme.warn end
    if string.find(key, "cloth", 1, true) or string.find(key, "wear", 1, true) then return theme.accent end
    if string.find(key, "tool", 1, true) or string.find(key, "material", 1, true) then return { r = 0.72, g = 0.62, b = 0.92, a = 1 } end
    if string.find(key, "vehicle", 1, true) or string.find(key, "car", 1, true) then return { r = 0.60, g = 0.72, b = 0.95, a = 1 } end
    return theme.accent
end

function ParadiseEconomy.getAccountTypeStyle(accountType)
    local theme = ParadiseEconomy.Theme
    if accountType == "personal" then return "PERSONAL", theme.accent end
    if accountType == "merchant" then return "MERCHANT", theme.gold end
    if accountType == "trade" then return "TRADE", theme.green end
    if accountType == "server" then return "SERVER", theme.warn end
    return "CUSTOM", theme.textDim
end

function ParadiseEconomy.getAccountTotalBalance(account, currency)
    local total = 0
    for _, entry in ipairs(ParadiseEconomy.getAccountBuckets(account)) do
        total = total + ParadiseEconomy.getBalance(account[entry.key], currency)
    end
    return total
end

function ParadiseEconomy.getListingStatusView(listing)
    local theme = ParadiseEconomy.Theme
    if not listing then return "UNKNOWN", theme.textMuted end
    if listing.expired then return "EXPIRED", theme.danger end
    local data = listing.itemData or {}
    local condition = tonumber(data.condition)
    local conditionMax = tonumber(data.conditionMax)
    if condition and conditionMax and conditionMax > 0 then
        local percent = math.max(0, math.min(100, math.floor(condition / conditionMax * 100)))
        return tostring(percent) .. "%", percent >= 60 and theme.green or (percent >= 30 and theme.warn or theme.danger)
    end
    local used = tonumber(data.usedDelta)
    if used ~= nil then
        local percent = math.max(0, math.min(100, math.floor(used * 100)))
        return tostring(percent) .. "%", percent >= 50 and theme.green or theme.warn
    end
    if tonumber(data.ammoCount) then return "AMMO " .. tostring(math.floor(tonumber(data.ammoCount))), theme.accent end
    return "LISTED", theme.textMuted
end

function ParadiseEconomy.getLeaseInfo(expiresAt)
    expiresAt = tonumber(expiresAt) or 0
    if expiresAt <= 0 then return "No expiry", "none", 0 end
    local remaining = expiresAt - getTimestampMs()
    if remaining <= 0 then return "Expired", "expired", 0 end
    local status = remaining <= ParadiseEconomy.merchantLeaseDayMs and "expiring" or "active"
    return ParadiseEconomy.formatMerchantLeaseDuration(remaining) .. " left", status, remaining
end

function ParadiseEconomy.getLeaseColor(status)
    local theme = ParadiseEconomy.Theme
    if status == "expired" then return theme.danger end
    if status == "expiring" then return theme.warn end
    if status == "active" then return theme.green end
    return theme.textMuted
end

function ParadiseEconomy.isItemEquipped(pl, item)
    if not pl or not item then return false end
    if pl:getPrimaryHandItem() == item or pl:getSecondaryHandItem() == item then return true end
    local worn = pl:getWornItems()
    for int = 0, worn:size() - 1 do
        if worn:get(int):getItem() == item then return true end
    end
    return false
end

function ParadiseEconomy.getManagedZones()
    return (ParadiseEconomy.clientState.market or {}).managedZones or {}
end

function ParadiseEconomy.hasManagedZones()
    return #ParadiseEconomy.getManagedZones() > 0
end

function ParadiseEconomy.canManageTradeZones()
    if not ParadiseEconomy.isEnabled() then return false end
    local pl = getPlayer()
    if ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(pl) then return true end
    return ParadiseEconomy.canManageActiveTrade() or ParadiseEconomy.hasManagedZones()
end

function ParadiseEconomy.getManageableTradeZones()
    local list = {}
    for _, zone in ipairs(ParadiseEconomy.getManagedZones()) do
        list[#list + 1] = zone
    end
    if #list == 0 then
        local market = ParadiseEconomy.clientState.market or {}
        if market.canManage and market.trade then
            local trade = {}
            for key, value in pairs(market.trade) do trade[key] = value end
            trade.marts = trade.marts or market.marts or {}
            trade.managedMerchants = market.managedMerchants or {}
            trade.managedListings = market.managedListings or {}
            list[#list + 1] = trade
        end
    end
    table.sort(list, function(a, b)
        return tostring(a.title or a.zoneId) < tostring(b.title or b.zoneId)
    end)
    return list
end

function ParadiseEconomy.getStatePersonal()
    local state = ParadiseEconomy.clientState
    state.personal = state.personal or { digital = {}, onhand = {} }
    state.personal.digital = state.personal.digital or {}
    state.personal.onhand = state.personal.onhand or {}
    return state.personal
end

function ParadiseEconomy.getAccountsList()
    local list = {}
    for _, account in pairs(ParadiseEconomy.clientState.accounts or {}) do list[#list + 1] = account end
    table.sort(list, function(a, b)
        local typeA, typeB = tostring(a.type or ""), tostring(b.type or "")
        if typeA ~= typeB then return typeA < typeB end
        return ParadiseEconomy.getAccountLabel(a) < ParadiseEconomy.getAccountLabel(b)
    end)
    return list
end

function ParadiseEconomy.getTradeZoneOptions()
    local zones = {}
    for _, zone in pairs(ParadiseEconomy.clientState.zones or {}) do
        if type(zone) == "table" and zone.isTrade == true and not zone.removed then zones[#zones + 1] = zone end
    end
    table.sort(zones, function(a, b)
        return tostring(a.name or a.id) < tostring(b.name or b.id)
    end)
    return zones
end

function ParadiseEconomy.canOpenMart(pl)
    if not ParadiseEconomy.isEnabled() then return false end
    pl = pl or getPlayer()
    if ParadiseEconomy.canUsePlayerEconomy(pl) then return true end
    return ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(pl) or false
end

function ParadiseEconomy.getShopsAtSquare(x, y, z)
    local list = {}
    x, y = tonumber(x), tonumber(y)
    if not x or not y then return list end
    z = math.floor(tonumber(z) or 0)
    for _, shop in ipairs(ParadiseEconomy.clientState.shops or {}) do
        if math.floor(tonumber(shop.x) or -1) == math.floor(x)
            and math.floor(tonumber(shop.y) or -1) == math.floor(y)
            and math.floor(tonumber(shop.z) or 0) == z then
            list[#list + 1] = shop
        end
    end
    return list
end

function ParadiseEconomy.getShop(kind, id)
    for _, shop in ipairs(ParadiseEconomy.clientState.shops or {}) do
        if shop.kind == kind and tostring(shop.id) == tostring(id) then return shop end
    end
    return nil
end

function ParadiseEconomy.getPlayerShops(pl)
    pl = pl or getPlayer()
    local square = pl and pl:getSquare() or nil
    if not square then return {} end
    return ParadiseEconomy.getShopsAtSquare(square:getX(), square:getY(), square:getZ())
end

function ParadiseEconomy.getZoneMarketViews(zoneId)
    local list, seen = {}, {}
    local function add(mart)
        if type(mart) ~= "table" or mart.archived == true then return end
        local key = tostring(mart.id)
        if seen[key] then return end
        seen[key] = true
        list[#list + 1] = mart
    end
    for _, zone in ipairs(ParadiseEconomy.getManagedZones()) do
        if zone.zoneId == zoneId then
            for _, mart in ipairs(zone.marts or {}) do add(mart) end
        end
    end
    for _, mart in pairs(ParadiseEconomy.clientState.marts or {}) do
        if mart.zoneId == zoneId then add(mart) end
    end
    table.sort(list, function(a, b) return tostring(a.title or a.id) < tostring(b.title or b.id) end)
    return list
end

function ParadiseEconomy.getPlayerMerchantStore(pl)
    pl = pl or getPlayer()
    if not pl then return nil end
    local key = ParadiseEconomy.usernameKey(pl:getUsername())
    local fallback
    local function check(shop)
        if shop.kind ~= "store" or ParadiseEconomy.usernameKey(shop.owner) ~= key then return nil end
        if shop.x and shop.expired ~= true and shop.closed ~= true then return shop end
        fallback = fallback or shop
        return nil
    end
    for _, shop in ipairs(ParadiseEconomy.clientState.myShops or {}) do
        local found = check(shop)
        if found then return found end
    end
    for _, shop in ipairs(ParadiseEconomy.getPlayerShops(pl)) do
        local found = check(shop)
        if found then return found end
    end
    return fallback
end

function ParadiseEconomy.isPlayerNearShop(pl, shop)
    if not pl or not shop or not shop.x then return false end
    local square = pl:getSquare()
    if not square or math.floor(square:getZ()) ~= math.floor(tonumber(shop.z) or 0) then return false end
    return pl:DistTo(shop.x + 0.5, shop.y + 0.5) <= 3
end

function ParadiseEconomy.getActivePlayerMerchantStore(pl)
    pl = pl or getPlayer()
    local shop = ParadiseEconomy.getPlayerMerchantStore(pl)
    if shop and shop.expired ~= true and shop.closed ~= true and ParadiseEconomy.isPlayerNearShop(pl, shop) then return shop end
    return nil
end

function ParadiseEconomy.openShop(kind, id)
    if not ParadiseEconomy.MartPanel or not ParadiseEconomy.MartPanel.OpenPanel then return end
    ParadiseEconomy.MartPanel.OpenPanel({ kind = kind, id = id })
end

function ParadiseEconomy.getZoneMartListingCount(zoneId)
    local count, seen = 0, {}
    local function add(mart)
        if type(mart) ~= "table" then return end
        local key = tostring(mart.id)
        if seen[key] then return end
        seen[key] = true
        if not zoneId or mart.zoneId == zoneId then
            count = count + math.max(tonumber(mart.listingCount) or 0, #(mart.listings or {}))
        end
    end
    for _, mart in pairs(ParadiseEconomy.clientState.marts or {}) do add(mart) end
    for _, mart in ipairs((ParadiseEconomy.clientState.market or {}).marts or {}) do add(mart) end
    return count
end

function ParadiseEconomy.getMerchantEarnings(zoneId)
    local earnings = { jimoleon = 0, paradisium = 0 }
    for _, merchant in ipairs(ParadiseEconomy.clientState.merchants or {}) do
        if not zoneId or merchant.zoneId == zoneId then
            earnings.jimoleon = earnings.jimoleon + ParadiseEconomy.getBalance(merchant.earnings, "jimoleon")
            earnings.paradisium = earnings.paradisium + ParadiseEconomy.getBalance(merchant.earnings, "paradisium")
        end
    end
    return earnings
end
function ParadiseEconomy.getStatePersonalAccount()
    local personal = ParadiseEconomy.getStatePersonal()
    local pl = getPlayer()
    local user = pl and pl:getUsername() or "You"
    return {
        id = personal.id,
        type = "personal",
        owner = personal.owner or user,
        title = personal.title or personal.owner or user,
        digital = personal.digital,
        onhand = personal.onhand,
    }
end

function ParadiseEconomy.getActiveTrade()
    return (ParadiseEconomy.clientState.market or {}).trade or nil
end

function ParadiseEconomy.getTradeAccountForZone(zoneId)
    if not zoneId then return nil end
    for _, account in pairs(ParadiseEconomy.clientState.accounts or {}) do
        if account.type == "trade" and account.zoneId == zoneId then return account end
    end
    return nil
end

function ParadiseEconomy.getTradeTaxPercentFor(zoneId)
    local market = ParadiseEconomy.clientState.market or {}
    local trade = market.trade
    if zoneId and market.tradeZoneId ~= zoneId then
        local account = ParadiseEconomy.getTradeAccountForZone(zoneId)
        return account and ParadiseEconomy.getTradeTaxPercent(account) or market.taxDefault
            or ParadiseEconomy.getPlayerShopTaxPercent()
    end
    return trade and ParadiseEconomy.getTradeTaxPercent(trade) or market.taxDefault
        or ParadiseEconomy.getPlayerShopTaxPercent()
end

function ParadiseEconomy.canManageActiveTrade()
    return (ParadiseEconomy.clientState.market or {}).canManage == true
end

function ParadiseEconomy.findAccountIdByOwner(user)
    local key = ParadiseEconomy.usernameKey(user)
    if not key then return nil end
    for _, account in ipairs(ParadiseEconomy.getAccountsList()) do
        if account.type == "personal" and ParadiseEconomy.usernameKey(account.owner) == key then
            return account.id
        end
    end
    return nil
end

ParadiseEconomy.Panel = ISCollapsableWindow:derive("ParadiseEconomyPanel")
ParadiseEconomy.AccountPanel = ISCollapsableWindow:derive("ParadiseEconomyAccountPanel")
ParadiseEconomy.AccountBrowser = ISCollapsableWindow:derive("ParadiseEconomyAccountBrowser")
ParadiseEconomy.MartPanel = ISCollapsableWindow:derive("ParadiseMartPanel")
ParadiseEconomy.TradeManagementPanel = ISCollapsableWindow:derive("ParadiseEconomyTradeManagementPanel")
ParadiseEconomy.AdminPanel = ISCollapsableWindow:derive("ParadiseEconomyAdminPanel")
ParadiseEconomy.MartAdminView = ISPanel:derive("ParadiseMartAdminView")
ParadiseEconomy.ListingPanel = ISCollapsableWindow:derive("ParadiseEconomyListingPanel")
ParadiseEconomy.PurchasePanel = ISCollapsableWindow:derive("ParadiseEconomyPurchasePanel")
ParadiseEconomy.HUD = ISPanel:derive("ParadiseEconomyHUD")

function ParadiseEconomy.AccountPanel:new(x, y, w, h, account)
    local obj = ISCollapsableWindow.new(self, x, y, w, h)
    obj.title = "Paradise Economy Account"
    obj.resizable = true
    obj.account = account or ParadiseEconomy.getStatePersonalAccount()
    obj.accountId = account and account.id or nil
    if obj.account then obj.title = "Paradise Economy - " .. ParadiseEconomy.getAccountLabel(obj.account) end
    return obj
end

function ParadiseEconomy.AccountPanel:createChildren()
    ISCollapsableWindow.createChildren(self)
    ParadiseEconomy.styleWindow(self)
    self.transactions = ISScrollingListBox:new(15, 225, self.width - 30, self.height - 260)
    self.transactions:initialise()
    self.transactions.itemheight = 24
    self.transactions.doDrawItem = ParadiseEconomy.Panel.drawTransaction
    self:addChild(self.transactions)
    ParadiseEconomy.styleTree(self)
end

function ParadiseEconomy.AccountPanel:setAccount(account)
    self.account = account or ParadiseEconomy.getStatePersonalAccount()
    self.accountId = account and account.id or nil
    self.title = "Paradise Economy - " .. ParadiseEconomy.getAccountLabel(self.account)
    self:refresh()
end

function ParadiseEconomy.AccountPanel:resolveAccount()
    if self.accountId then
        for _, account in ipairs(ParadiseEconomy.getAccountsList()) do
            if account.id == self.accountId then
                self.account = account
                break
            end
        end
    else
        self.account = ParadiseEconomy.getStatePersonalAccount()
    end
    if self.account then self.title = "Paradise Economy - " .. ParadiseEconomy.getAccountLabel(self.account) end
    return self.account
end

function ParadiseEconomy.AccountPanel:refresh(skipRequest)
    if not self.transactions then return end
    local account = self:resolveAccount()
    self.transactions:clear()
    local id = account and account.id or nil
    for _, row in ipairs(ParadiseEconomy.clientState.ledgerRows or {}) do
        if not id or row.a == id or row.b == id then
            self.transactions:addItem(tostring(row.t), row)
        end
    end
    if not skipRequest and self:isVisible() then
        ParadiseEconomy.send("ledgerMine", { accountId = id })
    end
end

function ParadiseEconomy.AccountPanel:update()
    ISCollapsableWindow.update(self)
    self.transactions:setWidth(self.width - 30)
    self.transactions:setHeight(math.max(60, self.height - 260))
end

function ParadiseEconomy.AccountPanel:close()
    if ParadiseEconomy.AccountPanel.ClosePanel then
        ParadiseEconomy.AccountPanel.ClosePanel()
    else
        self:setVisible(false)
        self:removeFromUIManager()
    end
end

function ParadiseEconomy.AccountPanel:prerender()
    ISCollapsableWindow.prerender(self)
    local account = self.account
    if not account then
        self:drawText("No account selected.", 15, 35, 1, 1, 1, 1, UIFont.Small)
        return
    end
    self:drawText("Type: " .. tostring(ParadiseEconomy.accountTypeLabels[account.type] or account.type or "Unknown"), 15, 35, 1, 1, 1, 1, UIFont.Small)
    self:drawText("ID: " .. tostring(account.id), 15, 55, 0.75, 0.9, 1, 1, UIFont.Small)
    self:drawText("Owner: " .. tostring(account.owner or account.name or "-"), 15, 75, 1, 1, 1, 1, UIFont.Small)
    if account.type == "trade" then
        self:drawText("Trade ID: " .. tostring(account.tradeId or account.zoneName or account.zoneId)
            .. " | Tax: " .. string.format("%g", ParadiseEconomy.getTradeTaxPercent(account)) .. "%"
            .. " | Mart items: " .. tostring(ParadiseEconomy.getZoneMartListingCount(account.zoneId)), 15, 95, 0.75, 0.9, 1, 1, UIFont.Small)
    elseif account.zoneId then
        self:drawText("Zone: " .. tostring(account.zoneName or account.zoneId) .. " (" .. tostring(account.zoneId) .. ")", 15, 95, 0.75, 0.9, 1, 1, UIFont.Small)
    end
    local y = 120
    for _, entry in ipairs(ParadiseEconomy.getAccountBuckets(account)) do
        local tab = type(account[entry.key]) == "table" and account[entry.key] or {}
        self:drawText(entry.label .. ": " .. tostring(ParadiseEconomy.getBalance(tab, "jimoleon")) .. " Jimoleons / "
            .. tostring(ParadiseEconomy.getBalance(tab, "paradisium")) .. " Paradisium", 15, y, 1, 0.85, 0.25, 1, UIFont.Small)
        y = y + 20
    end
    if account.type == "merchant" then
        self:drawText("Listings: " .. tostring(#(account.listings or {})) .. " | Tax route: " .. tostring(account.taxRoute or "-")
            .. (account.archived and " | Archived" or ""), 15, y, 0.8, 0.8, 0.8, 1, UIFont.Small)
    elseif account.archived then
        self:drawText("Archived account", 15, y, 0.8, 0.8, 0.8, 1, UIFont.Small)
    end
    self:drawText("Related transactions", 15, 205, 0.7, 0.9, 1, 1, UIFont.Small)
end

function ParadiseEconomy.AccountBrowser:new(x, y, w, h)
    local obj = ISCollapsableWindow.new(self, x, y, w, h)
    obj.title = "Account Browser"
    obj.resizable = true
    obj.lastWidth = 0
    obj.lastHeight = 0
    return obj
end

function ParadiseEconomy.AccountBrowser:createChildren()
    ISCollapsableWindow.createChildren(self)
    ParadiseEconomy.styleWindow(self)
    self.typeFilter = ISComboBox:new(15, 66, 260, 26, self, ParadiseEconomy.AccountBrowser.refresh)
    self.typeFilter:initialise()
    for _, entry in ipairs(ParadiseEconomy.accountFilterTypes) do
        self.typeFilter:addOption(entry.key == "all" and "All account types" or entry.label)
    end
    self:addChild(self.typeFilter)
    self.search = ISTextEntryBox:new("", 283, 66, 400, 26)
    self.search.target = self
    self.search.onTextChangeFunction = ParadiseEconomy.AccountBrowser.onSearchChanged
    self.search:initialise()
    self.search:instantiate()
    self.search:setPlaceholderText("ID, owner, title, zone...")
    self:addChild(self.search)
    self.refreshButton = ISButton:new(700, 66, 120, 26, "REFRESH", self, ParadiseEconomy.AccountBrowser.requestState)
    self.refreshButton:initialise()
    self:addChild(self.refreshButton)
    self.accounts = ISScrollingListBox:new(15, 104, self.width - 30, 400)
    self.accounts:initialise()
    self.accounts.itemheight = 96
    self.accounts.font = UIFont.Small
    self.accounts.doDrawItem = ParadiseEconomy.AccountBrowser.drawAccount
    self.accounts:setOnMouseDownFunction(self, ParadiseEconomy.AccountBrowser.selectAccount)
    self.accounts:setOnMouseDoubleClick(self, ParadiseEconomy.AccountBrowser.onAccountDoubleClick)
    self:addChild(self.accounts)
    self.openButton = ISButton:new(15, self.height - 40, 170, 26, "OPEN ACCOUNT", self, ParadiseEconomy.AccountBrowser.openSelected)
    self.openButton:initialise()
    self:addChild(self.openButton)
    ParadiseEconomy.styleTree(self)
    self.accounts.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    self.accounts.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    local theme = ParadiseEconomy.Theme
    self.openButton.backgroundColor = theme.accentDim
    self.openButton.backgroundColorMouseOver = theme.accent
    self.openButton.borderColor = theme.accent
    self.openButton.textColor = theme.text
    self:layout()
    self:refresh()
end

function ParadiseEconomy.AccountBrowser:layout()
    if not self.accounts then return end
    local w, h = self.width, self.height
    self.typeFilter:setX(15)
    self.typeFilter:setY(66)
    self.typeFilter:setWidth(260)
    self.typeFilter:setHeight(26)
    self.refreshButton:setX(w - 15 - 120)
    self.refreshButton:setY(66)
    self.refreshButton:setWidth(120)
    self.refreshButton:setHeight(26)
    self.search:setX(283)
    self.search:setY(66)
    self.search:setWidth(math.max(160, w - 15 - 120 - 12 - 283))
    self.search:setHeight(26)
    self.accounts:setX(15)
    self.accounts:setY(104)
    self.accounts:setWidth(w - 30)
    self.accounts:setHeight(math.max(100, h - 156))
    self.openButton:setX(w - 15 - 170)
    self.openButton:setY(h - 40)
    self.openButton:setWidth(170)
    self.openButton:setHeight(26)
    self.lastWidth = w
    self.lastHeight = h
end

function ParadiseEconomy.AccountBrowser:update()
    ISCollapsableWindow.update(self)
    if not ParadiseEconomy.canManageEconomy() or not (ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(getPlayer())) then
        if ParadiseEconomy.AccountBrowser.ClosePanel then
            ParadiseEconomy.AccountBrowser.ClosePanel()
        else
            self:setVisible(false)
            self:removeFromUIManager()
        end
        return
    end
    if self.width ~= self.lastWidth or self.height ~= self.lastHeight then self:layout() end
end

function ParadiseEconomy.AccountBrowser:close()
    if ParadiseEconomy.AccountBrowser.ClosePanel then
        ParadiseEconomy.AccountBrowser.ClosePanel()
    else
        self:setVisible(false)
        self:removeFromUIManager()
    end
end

function ParadiseEconomy.AccountBrowser:getFilterKey()
    local entry = ParadiseEconomy.accountFilterTypes[self.typeFilter.selected]
    return entry and entry.key or "all"
end

function ParadiseEconomy.AccountBrowser:refresh()
    if not self.accounts then return end
    local selectedId = self:getSelected() and self:getSelected().id or nil
    self.accounts:clear()
    local filter = self:getFilterKey()
    local search = string.lower(self.search:getInternalText() or "")
    for _, account in ipairs(ParadiseEconomy.getAccountsList()) do
        local typeMatch = filter == "all" or account.type == filter
        local text = string.lower(tostring(account.id or "") .. " " .. tostring(account.owner or "") .. " "
            .. tostring(account.name or "") .. " " .. tostring(account.title or "") .. " "
            .. tostring(account.tradeId or "") .. " " .. tostring(account.taxRoute or "") .. " "
            .. tostring(account.zoneName or "") .. " " .. tostring(account.zoneId or ""))
        if typeMatch and (search == "" or text:find(search, 1, true)) then
            self.accounts:addItem(ParadiseEconomy.getAccountLabel(account), account)
        end
    end
    if selectedId then
        for index, item in ipairs(self.accounts.items) do
            if item.item and item.item.id == selectedId then self.accounts.selected = index end
        end
    end
    self.openButton:setEnable(self:getSelected() ~= nil)
end

function ParadiseEconomy.AccountBrowser:prerender()
    ISCollapsableWindow.prerender(self)
    ParadiseEconomy.drawPanelHeader(self, "ECONOMY ACCOUNTS  ·  PERSONAL, MERCHANT, TRADE AND SERVER", "09", "ADMIN")
    local theme = ParadiseEconomy.Theme
    self:drawText("Double-click an account or use OPEN ACCOUNT.", 15, self.height - 34,
        theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
end

function ParadiseEconomy.AccountBrowser:drawAccount(y, item, alt)
    local account = item.item
    local theme = ParadiseEconomy.Theme
    local w = self.width
    local selected = self.selected == item.index
    local cardX, cardY, cardW, cardH = 2, y + 4, w - 4, self.itemheight - 8
    self:drawRect(cardX, cardY, cardW, cardH, selected and theme.rowSelected.a or theme.cardBg.a,
        selected and theme.rowSelected.r or theme.cardBg.r,
        selected and theme.rowSelected.g or theme.cardBg.g,
        selected and theme.rowSelected.b or theme.cardBg.b)
    self:drawRectBorder(cardX, cardY, cardW, cardH, (selected and 1 or theme.borderSoft.a),
        selected and theme.gold.r or theme.borderSoft.r,
        selected and theme.gold.g or theme.borderSoft.g,
        selected and theme.gold.b or theme.borderSoft.b)
    if selected then self:drawRect(cardX, cardY, 3, cardH, 1, theme.gold.r, theme.gold.g, theme.gold.b) end

    local typeLabel, typeColor = ParadiseEconomy.getAccountTypeStyle(account.type)
    local chipW = getTextManager():MeasureStringX(UIFont.Small, typeLabel) + 16
    self:drawRect(cardX + 12, cardY + 10, chipW, 18, 0.16, typeColor.r, typeColor.g, typeColor.b)
    self:drawRectBorder(cardX + 12, cardY + 10, chipW, 18, 0.65, typeColor.r, typeColor.g, typeColor.b)
    self:drawText(typeLabel, cardX + 20, cardY + 12, typeColor.r, typeColor.g, typeColor.b, 1, UIFont.Small)
    local title = tostring(account.title or account.name or account.owner or account.id or "Account")
    if account.frozen == true then title = "[FROZEN] " .. title end
    local titleColor = account.frozen == true and theme.danger or theme.text
    self:drawText(ParadiseEconomy.fitText(title, cardW - 260, UIFont.Medium), cardX + 12, cardY + 34,
        titleColor.r, titleColor.g, titleColor.b, 1, UIFont.Medium)
    self:drawText(ParadiseEconomy.fitText(tostring(account.id or "?"), cardW - 260, UIFont.Small), cardX + 12, cardY + 58,
        theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)

    local bucket = type(account.digital) == "table" and account.digital
        or type(account.balances) == "table" and account.balances
        or type(account.earnings) == "table" and account.earnings or {}
    local jText = ParadiseEconomy.formatNumber(ParadiseEconomy.getBalance(bucket, "jimoleon"))
    local pText = ParadiseEconomy.formatNumber(ParadiseEconomy.getBalance(bucket, "paradisium"))
    local right = cardX + cardW - 12
    local pTextX = right - getTextManager():MeasureStringX(UIFont.Small, pText)
    local pIconX = pTextX - 20
    local jIconX = pIconX - 18 - 16
    local jTextX = jIconX - 4 - getTextManager():MeasureStringX(UIFont.Small, jText)
    if ParadiseEconomy.icons.paradisium then
        self:drawTextureScaled(ParadiseEconomy.icons.paradisium, pIconX, cardY + 32, 16, 16, 1)
    end
    self:drawText(pText, pTextX, cardY + 35, theme.accent.r, theme.accent.g, theme.accent.b, 1, UIFont.Small)
    if ParadiseEconomy.icons.jimoleon then
        self:drawTextureScaled(ParadiseEconomy.icons.jimoleon, jIconX, cardY + 32, 16, 16, 1)
    end
    self:drawText(jText, jTextX, cardY + 35, theme.gold.r, theme.gold.g, theme.gold.b, 1, UIFont.Small)
    return y + self.itemheight
end

function ParadiseEconomy.AccountBrowser:selectAccount(account)
    self.openButton:setEnable(account ~= nil and self.accounts.selected > 0)
end

function ParadiseEconomy.AccountBrowser.onAccountDoubleClick(target, account)
    if target and account then target:openSelected() end
end

function ParadiseEconomy.AccountBrowser:getSelected()
    local item = self.accounts and self.accounts.items[self.accounts.selected] or nil
    return item and item.item or nil
end

function ParadiseEconomy.AccountBrowser:openSelected()
    local account = self:getSelected()
    if account and ParadiseEconomy.AccountPanel.OpenPanel then
        ParadiseEconomy.AccountPanel.OpenPanel(account)
    end
end

function ParadiseEconomy.AccountBrowser.onSearchChanged(target)
    if target and target.refresh then target:refresh() end
end

function ParadiseEconomy.AccountBrowser:requestState()
    ParadiseEconomy.send("requestState")
end

function ParadiseEconomy.send(command, args)
    if not ParadiseEconomy.isEnabled() then return end
    local pl = getPlayer()
    if pl then sendClientCommand(pl, ParadiseEconomy.module, command, args or {}) end
end

ParadiseEconomy.Panel.operations = {
    { key = "deposit", label = "Deposit to digital", button = "DEPOSIT TO DIGITAL", hint = "ON-HAND  ->  DIGITAL" },
    { key = "withdraw", label = "Withdraw to on-hand", button = "WITHDRAW TO ON-HAND", hint = "DIGITAL  ->  ON-HAND" },
}

function ParadiseEconomy.Panel:new(x, y, w, h)
    local obj = ISCollapsableWindow.new(self, x, y, w, h)
    obj.title = "Personal Economy"
    obj.resizable = true
    obj.minimumWidth = 840
    obj.minimumHeight = 600
    return obj
end

function ParadiseEconomy.Panel:createChildren()
    ISCollapsableWindow.createChildren(self)
    ParadiseEconomy.styleWindow(self)
    self.operation = ISComboBox:new(0, 0, 200, 25, self)
    self.operation:initialise()
    for _, entry in ipairs(ParadiseEconomy.Panel.operations) do self.operation:addOption(entry.label) end
    self:addChild(self.operation)
    self.currency = ISComboBox:new(0, 0, 130, 25, self)
    self.currency:initialise()
    self.currency:addOption("jimoleon")
    self.currency:addOption("paradisium")
    self:addChild(self.currency)
    self.amount = ISTextEntryBox:new("", 0, 0, 130, 25)
    self.amount.tooltip = "Amount for the selected bank operation"
    self.amount:initialise()
    self.amount:instantiate()
    self.amount:setOnlyNumbers(true)
    self:addChild(self.amount)
    self.actionButton = ISButton:new(0, 0, 200, 26, "DEPOSIT TO DIGITAL", self, ParadiseEconomy.Panel.onBankAction)
    self.actionButton:initialise()
    self:addChild(self.actionButton)
    self.quick100 = ISButton:new(0, 0, 56, 26, "+100", self, ParadiseEconomy.Panel.addQuickAmount)
    self.quick100.internal = 100
    self.quick100.tooltip = "Add 100 to the amount"
    self.quick100:initialise()
    self:addChild(self.quick100)
    self.quick500 = ISButton:new(0, 0, 56, 26, "+500", self, ParadiseEconomy.Panel.addQuickAmount)
    self.quick500.internal = 500
    self.quick500.tooltip = "Add 500 to the amount"
    self.quick500:initialise()
    self:addChild(self.quick500)
    self.maxButton = ISButton:new(0, 0, 56, 26, "MAX", self, ParadiseEconomy.Panel.setMaxAmount)
    self.maxButton.tooltip = "Use the full available balance"
    self.maxButton:initialise()
    self:addChild(self.maxButton)
    self.walletButton = ISButton:new(0, 0, 130, 26, "TO WALLET", self, ParadiseEconomy.Panel.onWalletAction)
    self.walletButton.tooltip = "Place digital funds into a carried wallet"
    self.walletButton:initialise()
    self:addChild(self.walletButton)
    self.recipient = ISTextEntryBox:new("", 0, 0, 210, 25)
    self.recipient.tooltip = "Recipient username"
    self.recipient:initialise()
    self.recipient:instantiate()
    self:addChild(self.recipient)
    self.transferAmount = ISTextEntryBox:new("", 0, 0, 120, 25)
    self.transferAmount.tooltip = "Amount to transfer"
    self.transferAmount:initialise()
    self.transferAmount:instantiate()
    self.transferAmount:setOnlyNumbers(true)
    self:addChild(self.transferAmount)
    self.transferButton = ISButton:new(0, 0, 200, 26, "SEND TRANSFER", self, ParadiseEconomy.Panel.onTransfer)
    self.transferButton:initialise()
    self:addChild(self.transferButton)
    self.martButton = ISButton:new(0, 0, 110, 26, "Tradeshop", self, ParadiseEconomy.Panel.openMart)
    self.martButton:initialise()
    self:addChild(self.martButton)
    self.ledgerButton = ISButton:new(0, 0, 170, 22, "VIEW FULL LEDGER  >>", self, ParadiseEconomy.Panel.openLedger)
    self.ledgerButton:initialise()
    self:addChild(self.ledgerButton)
    self.transactions = ISScrollingListBox:new(0, 0, 100, 100)
    self.transactions:initialise()
    self.transactions.itemheight = 26
    self.transactions.font = UIFont.Small
    self.transactions.doDrawItem = ParadiseEconomy.Panel.drawLedgerRow
    self:addChild(self.transactions)
    ParadiseEconomy.styleTree(self)
    self:applyCustomStyle()
    self:layout()
    self:refresh()
end

function ParadiseEconomy.Panel:applyCustomStyle()
    local theme = ParadiseEconomy.Theme
    self.actionButton.backgroundColor = theme.gold
    self.actionButton.backgroundColorMouseOver = { r = 1.0, g = 0.88, b = 0.48, a = 1.0 }
    self.actionButton.textColor = { r = 0.06, g = 0.07, b = 0.09, a = 1.0 }
    self.transferButton.backgroundColor = theme.accentDim
    self.transferButton.backgroundColorMouseOver = theme.accent
    self.transferButton.textColor = theme.text
    self.walletButton.backgroundColor = theme.buttonBg
    self.martButton.backgroundColor = theme.accentDim
    self.martButton.backgroundColorMouseOver = theme.accent
    self.ledgerButton.displayBackground = false
    self.ledgerButton.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    self.ledgerButton.backgroundColorMouseOver = { r = 0, g = 0, b = 0, a = 0 }
    self.ledgerButton.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    self.ledgerButton.textColor = theme.accent
    self.transactions.backgroundColor = { r = 0.045, g = 0.060, b = 0.078, a = 0.35 }
    self.transactions.borderColor = { r = 0, g = 0, b = 0, a = 0 }
end

function ParadiseEconomy.Panel:layout()
    if not self.transactions then return end
    local w, h = self.width, self.height
    self.cardY = 104
    self.cardH = 88
    self.cardW = math.floor((w - 66) / 4)
    self.bankY = self.cardY + self.cardH + 14
    self.bankH = 168
    self.bankW = math.floor((w - 44) * 0.56)
    self.transferX = 15 + self.bankW + 14
    self.transferW = w - 15 - self.transferX
    self.ledgerY = self.bankY + self.bankH + 14
    self.ledgerH = math.max(120, h - self.ledgerY - 12)
    self.martButton:setX(w - 200)
    self.martButton:setY(22)
    self.martButton:setWidth(110)
    local inner = 29
    local bankInnerW = self.bankW - 28
    local opW = math.floor(bankInnerW * 0.42)
    local currencyW = math.floor(bankInnerW * 0.25)
    local amountW = bankInnerW - opW - currencyW - 16
    local fieldY = self.bankY + 52
    self.operation:setX(inner)
    self.operation:setY(fieldY)
    self.operation:setWidth(opW)
    self.currency:setX(inner + opW + 8)
    self.currency:setY(fieldY)
    self.currency:setWidth(currencyW)
    self.amount:setX(inner + opW + currencyW + 16)
    self.amount:setY(fieldY)
    self.amount:setWidth(amountW)
    local actionY = self.bankY + 88
    local actionW = math.floor(bankInnerW * 0.48)
    self.actionButton:setX(inner)
    self.actionButton:setY(actionY)
    self.actionButton:setWidth(actionW)
    local quickX = inner + actionW + 10
    self.quick100:setX(quickX)
    self.quick100:setY(actionY)
    self.quick100:setWidth(56)
    self.quick500:setX(quickX + 62)
    self.quick500:setY(actionY)
    self.quick500:setWidth(56)
    self.maxButton:setX(quickX + 124)
    self.maxButton:setY(actionY)
    self.maxButton:setWidth(56)
    self.walletButton:setX(inner + bankInnerW - 130)
    self.walletButton:setY(self.bankY + 124)
    self.walletButton:setWidth(130)
    local transferInnerX = self.transferX + 14
    local transferInnerW = self.transferW - 28
    local recipientW = math.floor(transferInnerW * 0.60)
    local transferAmountW = transferInnerW - recipientW - 8
    self.recipient:setX(transferInnerX)
    self.recipient:setY(fieldY)
    self.recipient:setWidth(recipientW)
    self.transferAmount:setX(transferInnerX + recipientW + 8)
    self.transferAmount:setY(fieldY)
    self.transferAmount:setWidth(transferAmountW)
    self.transferButton:setX(transferInnerX)
    self.transferButton:setY(actionY)
    self.transferButton:setWidth(transferInnerW)
    self.ledgerButton:setX(w - 185)
    self.ledgerButton:setY(self.ledgerY + 6)
    self.ledgerButton:setWidth(170)
    self.transactions:setX(25)
    self.transactions:setY(self.ledgerY + 58)
    self.transactions:setWidth(w - 50)
    self.transactions:setHeight(math.max(40, self.ledgerH - 84))
    self.lastWidth = w
    self.lastHeight = h
end

function ParadiseEconomy.Panel:getOperation()
    return ParadiseEconomy.Panel.operations[self.operation.selected] or ParadiseEconomy.Panel.operations[1]
end

function ParadiseEconomy.Panel:getCurrency()
    return self.currency.options[self.currency.selected] or "jimoleon"
end

function ParadiseEconomy.Panel:getCurrencyTag()
    return self:getCurrency() == "paradisium" and "P" or "J"
end

function ParadiseEconomy.Panel:getMaxAmount()
    local personal = ParadiseEconomy.getStatePersonal()
    local bucket = self:getOperation().key == "deposit" and personal.onhand or personal.digital
    return ParadiseEconomy.getBalance(bucket, self:getCurrency())
end

function ParadiseEconomy.Panel:setAmountValue(value)
    self.amount:setText(tostring(math.max(0, math.floor(tonumber(value) or 0))))
end

function ParadiseEconomy.Panel:addQuickAmount(button)
    self:setAmountValue((tonumber(self.amount:getInternalText()) or 0) + (tonumber(button.internal) or 0))
end

function ParadiseEconomy.Panel:setMaxAmount()
    self:setAmountValue(self:getMaxAmount())
end

function ParadiseEconomy.Panel:onBankAction()
    ParadiseEconomy.send(self:getOperation().key, {
        currency = self:getCurrency(),
        amount = self.amount:getInternalText(),
    })
end

function ParadiseEconomy.Panel:onWalletAction()
    ParadiseEconomy.send("withdrawWallet", {
        currency = self:getCurrency(),
        amount = self.amount:getInternalText(),
    })
end

function ParadiseEconomy.Panel:onTransfer()
    ParadiseEconomy.send("transfer", {
        currency = self:getCurrency(),
        amount = self.transferAmount:getInternalText(),
        username = self.recipient:getInternalText(),
    })
end

function ParadiseEconomy.Panel:update()
    ISCollapsableWindow.update(self)
    if self.width ~= self.lastWidth or self.height ~= self.lastHeight then self:layout() end
    local canUseMarket = ParadiseEconomy.canOpenMart(getPlayer())
    self.martButton:setEnable(canUseMarket)
    self.martButton:setTooltip(canUseMarket and "Open the Tradeshop" or "Enter a Trade Zone to use the Tradeshop")
    self.actionButton:setTitle(self:getOperation().button)
    local amount = tonumber(self.amount:getInternalText())
    self.actionButton:setEnable(amount ~= nil and amount > 0)
    self.walletButton:setEnable(amount ~= nil and amount > 0)
    local transferAmount = tonumber(self.transferAmount:getInternalText())
    local recipient = self.recipient:getInternalText()
    self.transferButton:setEnable(transferAmount ~= nil and transferAmount > 0 and recipient ~= nil and recipient ~= "")
end

function ParadiseEconomy.Panel:close()
    if ParadiseEconomy.ClosePanel then
        ParadiseEconomy.ClosePanel()
    else
        self:setVisible(false)
        self:removeFromUIManager()
    end
end

function ParadiseEconomy.Panel:openMart()
    if not ParadiseEconomy.canOpenMart(getPlayer()) then return end
    local pl = getPlayer()
    local store = ParadiseEconomy.getPlayerMerchantStore(pl)
    if store then
        ParadiseEconomy.openShop(store.kind, store.id)
        return
    end
    local shops = ParadiseEconomy.getPlayerShops(pl)
    for _, kind in ipairs({ "store", "mart" }) do
        for _, shop in ipairs(shops) do
            if shop.kind == kind then
                ParadiseEconomy.openShop(shop.kind, shop.id)
                return
            end
        end
    end
    ParadiseEconomy.openShop(nil)
end

function ParadiseEconomy.Panel:openLedger()
    if ParadiseEconomy.AccountPanel.OpenPanel then
        ParadiseEconomy.AccountPanel.OpenPanel()
    end
end

function ParadiseEconomy.getLedgerColor(key)
    local theme = ParadiseEconomy.Theme
    if key == "in" then return theme.green end
    if key == "out" then return theme.danger end
    return theme.textDim
end

function ParadiseEconomy.Panel:drawTransaction(y, item, alt)
    local row = item.item
    local theme = ParadiseEconomy.Theme
    local color = ParadiseEconomy.getLedgerColor(row.k)
    self:drawText(ParadiseEconomy.Ledger.timeText(row), 8, y + 4, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText(ParadiseEconomy.fitText(row.x or "-", self.width - 80, UIFont.Small), 62, y + 4,
        color.r, color.g, color.b, 1, UIFont.Small)
    return y + self.itemheight
end

function ParadiseEconomy.Panel:drawLedgerRow(y, item, alt)
    local row = item.item
    local theme = ParadiseEconomy.Theme
    if self.selected == item.index then
        self:drawRect(0, y, self.width, self.itemheight - 1, theme.rowSelected.a, theme.rowSelected.r, theme.rowSelected.g, theme.rowSelected.b)
    elseif alt then
        self:drawRect(0, y, self.width, self.itemheight - 1, theme.rowAlt.a, theme.rowAlt.r, theme.rowAlt.g, theme.rowAlt.b)
    end
    local color = ParadiseEconomy.getLedgerColor(row.k)
    self:drawText(ParadiseEconomy.Ledger.timeText(row), 8, y + 5, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText(ParadiseEconomy.fitText(row.x or "-", 165, UIFont.Small), 86, y + 5,
        theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Small)
    self:drawText(tostring(row.m or ""), 260, y + 5, color.r, color.g, color.b, 1, UIFont.Small)
    self:drawText(ParadiseEconomy.fitText(row.e or "", self.width - 500, UIFont.Small), 380, y + 5,
        theme.textDim.r, theme.textDim.g, theme.textDim.b, 1, UIFont.Small)
    self:drawTextRight(tostring(row.d or ""), self.width - 10, y + 5,
        theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    return y + self.itemheight
end

function ParadiseEconomy.Panel:refresh(skipRequest)
    if not self.transactions then return end
    self.transactions:clear()
    for _, row in ipairs(ParadiseEconomy.clientState.ledgerRows or {}) do
        self.transactions:addItem(tostring(row.t), row)
    end
    if not skipRequest and self:isVisible() then ParadiseEconomy.send("ledgerMine") end
end

function ParadiseEconomy.Panel:prerender()
    ISCollapsableWindow.prerender(self)
    local theme = ParadiseEconomy.Theme
    local w = self.width
    local personal = ParadiseEconomy.getStatePersonal()
    local player = getPlayer()

    self:drawText("ParadiseEconomy.Panel", 18, 29, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawRect(w - 68, 22, 52, 28, theme.cardBg.a, theme.cardBg.r, theme.cardBg.g, theme.cardBg.b)
    self:drawRectBorder(w - 68, 22, 52, 28, theme.borderSoft.a, theme.borderSoft.r, theme.borderSoft.g, theme.borderSoft.b)
    self:drawTextCentre("02", w - 42, 29, theme.accent.r, theme.accent.g, theme.accent.b, 1, UIFont.Medium)
    self:drawRect(15, 56, w - 30, 1, theme.borderSoft.a, theme.borderSoft.r, theme.borderSoft.g, theme.borderSoft.b)

    local accountId = tostring(personal.id or "------")
    local owner = tostring(personal.owner or personal.title or (player and player:getUsername()) or "UNLINKED")
    self:drawText(accountId, 18, 64, theme.accent.r, theme.accent.g, theme.accent.b, 1, UIFont.Small)
    local idWidth = getTextManager():MeasureStringX(UIFont.Small, accountId)
    local ownerX = 18 + idWidth + 8
    self:drawText(ParadiseEconomy.fitText("/  " .. owner, w - 110 - ownerX, UIFont.Small), ownerX, 64,
        theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Small)
    self:drawRect(w - 92, 60, 74, 20, 0.12, theme.green.r, theme.green.g, theme.green.b)
    self:drawRectBorder(w - 92, 60, 74, 20, theme.green.a, theme.green.r, theme.green.g, theme.green.b)
    self:drawTextCentre("ACTIVE", w - 55, 63, theme.green.r, theme.green.g, theme.green.b, 1, UIFont.Small)
    self:drawRect(15, 96, w - 30, 1, theme.borderSoft.a, theme.borderSoft.r, theme.borderSoft.g, theme.borderSoft.b)

    local cards = {
        { label = "JIMOLEONS ON-HAND", value = ParadiseEconomy.getBalance(personal.onhand, "jimoleon"), accent = theme.gold, icon = ParadiseEconomy.icons.jimoleon },
        { label = "JIMOLEONS DIGITAL", value = ParadiseEconomy.getBalance(personal.digital, "jimoleon"), accent = theme.gold, icon = ParadiseEconomy.icons.jimoleon },
        { label = "PARADISIUM ON-HAND", value = ParadiseEconomy.getBalance(personal.onhand, "paradisium"), accent = theme.accent, icon = ParadiseEconomy.icons.paradisium },
        { label = "PARADISIUM DIGITAL", value = ParadiseEconomy.getBalance(personal.digital, "paradisium"), accent = theme.accent, icon = ParadiseEconomy.icons.paradisium },
    }
    for index, card in ipairs(cards) do
        local x = 15 + (index - 1) * (self.cardW + 12)
        ParadiseEconomy.drawCard(self, x, self.cardY, self.cardW, self.cardH, card.accent)
        self:drawText(card.label, x + 14, self.cardY + 12, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
        self:drawText(ParadiseEconomy.formatNumber(card.value), x + 14, self.cardY + 34,
            theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Medium)
        if card.icon then self:drawTextureScaled(card.icon, x + self.cardW - 38, self.cardY + 12, 24, 24, 0.95) end
    end

    ParadiseEconomy.drawCard(self, 15, self.bankY, self.bankW, self.bankH, theme.gold)
    self:drawText("BANK OPERATIONS", 29, self.bankY + 12, theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Medium)
    self:drawText("OPERATION", self.operation:getX(), self.operation:getY() - 16,
        theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText("CURRENCY", self.currency:getX(), self.currency:getY() - 16,
        theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText("AMOUNT (" .. self:getCurrencyTag() .. ")", self.amount:getX(), self.amount:getY() - 16,
        theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText(self:getOperation().hint, 29, self.bankY + 131, theme.textDim.r, theme.textDim.g, theme.textDim.b, 1, UIFont.Small)

    ParadiseEconomy.drawCard(self, self.transferX, self.bankY, self.transferW, self.bankH, theme.accent)
    self:drawText("DIRECT TRANSFER", self.transferX + 14, self.bankY + 12,
        theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Medium)
    self:drawText("RECIPIENT", self.recipient:getX(), self.recipient:getY() - 16,
        theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText("AMOUNT (" .. self:getCurrencyTag() .. ")", self.transferAmount:getX(), self.transferAmount:getY() - 16,
        theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText("Transfers are irreversible.", self.transferX + 14, self.bankY + 124,
        theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText("Recipient validation occurs before authorization.", self.transferX + 14, self.bankY + 140,
        theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)

    ParadiseEconomy.drawCard(self, 15, self.ledgerY, w - 30, self.ledgerH, theme.accentDim)
    self:drawText("RECENT TRANSACTIONS", 29, self.ledgerY + 10, theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Medium)
    local headerY = self.ledgerY + 38
    self:drawText("TIME", 33, headerY, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText("ACTION", 111, headerY, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText("AMOUNT", 285, headerY, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText("DETAIL", 405, headerY, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawTextRight("STATUS", w - 35, headerY, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawRect(25, self.ledgerY + 54, w - 50, 1, theme.borderSoft.a, theme.borderSoft.r, theme.borderSoft.g, theme.borderSoft.b)
    local message = ParadiseEconomy.clientState.message
    if message then
        self:drawText(ParadiseEconomy.fitText(tostring(message), w - 60, UIFont.Small), 29, self.ledgerY + self.ledgerH - 20,
            theme.warn.r, theme.warn.g, theme.warn.b, 1, UIFont.Small)
    end
end

function ParadiseEconomy.formatTimestamp(seconds)
    seconds = tonumber(seconds)
    if not seconds or seconds <= 0 then return "-" end
    return os.date("%Y-%m-%d %H:%M", math.floor(seconds))
end

function ParadiseEconomy.formatLeaseExpiry(expiresAt)
    expiresAt = tonumber(expiresAt) or 0
    if expiresAt <= 0 then return "No expiry" end
    return os.date("%Y-%m-%d %H:%M", math.floor(expiresAt / 1000))
end

function ParadiseEconomy.MartPanel:new(x, y, w, h, scope)
    local obj = ISCollapsableWindow.new(self, x, y, w, h)
    obj.shopKind = scope and scope.kind or nil
    obj.shopId = scope and scope.id or nil
    obj.shop = nil
    obj.shopMessage = nil
    obj.title = scope and "Shop" or "Tradeshop"
    obj.resizable = true
    obj.minimumWidth = 900
    obj.minimumHeight = 580
    obj.tab = obj.shopKind == "mart" and "mart" or "browse"
    obj.martDirection = "buy"
    obj.martCategory = nil
    obj.martCache = {}
    obj.browseCategory = nil
    obj.browseChips = {}
    obj.martChips = {}
    obj.isAdm = ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(getPlayer()) or false
    obj.selectedBrowseId = nil
    obj.selectedStoreListingId = nil
    obj.selectedInventoryId = nil
    obj.selectedMartListingId = nil
    obj.browseCache = {}
    obj.storeCache = {}
    obj.inventoryCache = {}
    obj.martCache = {}
    obj.listingDrag = nil
    obj.listingQueue = {}
    obj.dropHint = nil
    obj.dropHintUntil = 0
    obj.lastWidth = 0
    obj.lastHeight = 0
    return obj
end

function ParadiseEconomy.MartPanel:createChildren()
    ISCollapsableWindow.createChildren(self)

    self.tabBrowse = ISButton:new(15, 58, 150, 24, "BROWSE STORES", self, ParadiseEconomy.MartPanel.onTab)
    self.tabBrowse.internal = "browse"
    self.tabBrowse.tooltip = "Active player trade posts in this zone"
    self.tabBrowse:initialise()
    self:addChild(self.tabBrowse)
    self.tabStore = ISButton:new(173, 58, 150, 24, "MY STORE STALL", self, ParadiseEconomy.MartPanel.onTab)
    self.tabStore.internal = "store"
    self.tabStore.tooltip = "Your merchant store, lease, earnings and posts"
    self.tabStore:initialise()
    self:addChild(self.tabStore)
    self.tabMart = ISButton:new(331, 58, 160, 24, "ZONE ITEM MART", self, ParadiseEconomy.MartPanel.onTab)
    self.tabMart.internal = "mart"
    self.tabMart.tooltip = "Buy from or sell to the zone item mart"
    self.tabMart:initialise()
    self:addChild(self.tabMart)
    self.manageButton = ISButton:new(self.width - 231, 22, 155, 24, "Trade Management", self, ParadiseEconomy.MartPanel.openManagement)
    self.manageButton.tooltip = "Renew merchant leases and review every player post in your trade zones"
    self.manageButton:initialise()
    self:addChild(self.manageButton)

    self.browseSearch = ISTextEntryBox:new("", 15, 96, self.width - 30, 24)
    self.browseSearch.target = self
    self.browseSearch.onTextChangeFunction = ParadiseEconomy.MartPanel.onBrowseSearchChanged
    self.browseSearch.tooltip = "Search by item, seller, merchant id or store title"
    self.browseSearch:initialise()
    self.browseSearch:instantiate()
    self.browseSearch:setPlaceholderText("Search item, seller, merchant id or store title...")
    self:addChild(self.browseSearch)
    self.browseList = ISScrollingListBox:new(15, 160, self.width - 30, 300)
    self.browseList:initialise()
    self.browseList.target = self
    self.browseList.itemheight = 176
    self.browseList.font = UIFont.Small
    self.browseList.doDrawItem = ParadiseEconomy.MartPanel.drawBrowseRow
    self.browseList.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    self.browseList.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    local browseMouseDown = self.browseList.onMouseDown
    self.browseList.onMouseDown = function(list, x, y)
        if browseMouseDown then browseMouseDown(list, x, y) end
        ParadiseEconomy.MartPanel.onBrowseGridMouseDown(self, list, x, y)
    end
    self:addChild(self.browseList)

    self.storeTitle = ISTextEntryBox:new("", 28, 122, 230, 24)
    self.storeTitle.tooltip = "Your merchant store title in this trade zone"
    self.storeTitle:initialise()
    self.storeTitle:instantiate()
    self:addChild(self.storeTitle)
    self.renameStoreButton = ISButton:new(266, 122, 115, 24, "Rename Store", self, ParadiseEconomy.MartPanel.onRenameStore)
    self.renameStoreButton:initialise()
    self:addChild(self.renameStoreButton)
    self.renewLeaseButton = ISButton:new(0, 122, 125, 24, "Renew Lease", self, ParadiseEconomy.MartPanel.onRenewLease)
    self.renewLeaseButton.tooltip = "Extend this merchant store lease"
    self.renewLeaseButton:initialise()
    self:addChild(self.renewLeaseButton)
    self.collectButton = ISButton:new(0, 122, 140, 24, "Collect Earnings", self, ParadiseEconomy.MartPanel.onCollect)
    self.collectButton:initialise()
    self:addChild(self.collectButton)

    self.invSearch = ISTextEntryBox:new("", 15, 204, 250, 24)
    self.invSearch.target = self
    self.invSearch.onTextChangeFunction = ParadiseEconomy.MartPanel.onInventorySearchChanged
    self.invSearch.tooltip = "Search your carried items"
    self.invSearch:initialise()
    self.invSearch:instantiate()
    self.invSearch:setPlaceholderText("Search carried items...")
    self:addChild(self.invSearch)
    self.invList = ISScrollingListBox:new(15, 234, 300, 200)
    self.invList:initialise()
    self.invList.itemheight = 24
    self.invList.font = UIFont.Small
    self.invList.doDrawItem = ParadiseEconomy.MartPanel.drawInventoryItem
    self.invList:setOnMouseDownFunction(self, ParadiseEconomy.MartPanel.onInventorySelect)
    self:addChild(self.invList)
    self.storePrice = ISTextEntryBox:new("", 15, 420, 80, 24)
    self.storePrice.tooltip = "Listing price"
    self.storePrice:initialise()
    self.storePrice:instantiate()
    self.storePrice:setOnlyNumbers(true)
    self:addChild(self.storePrice)
    self.storeCurrency = ISComboBox:new(100, 420, 105, 24, self)
    self.storeCurrency:initialise()
    self.storeCurrency:addOption("jimoleon")
    self.storeCurrency:addOption("paradisium")
    self:addChild(self.storeCurrency)
    self.postButton = ISButton:new(210, 420, 100, 24, "Post Item", self, ParadiseEconomy.MartPanel.onPostSelected)
    self.postButton:initialise()
    self:addChild(self.postButton)
    self.myListings = ISScrollingListBox:new(330, 204, 300, 260)
    self.myListings:initialise()
    self.myListings.itemheight = 40
    self.myListings.font = UIFont.Small
    self.myListings.doDrawItem = ParadiseEconomy.MartPanel.drawStoreListing
    self.myListings:setOnMouseDownFunction(self, ParadiseEconomy.MartPanel.onStoreListingSelect)
    self:addChild(self.myListings)
    self.cancelButton = ISButton:new(0, 0, 170, 26, "Cancel Listing", self, ParadiseEconomy.MartPanel.onCancelListing)
    self.cancelButton:initialise()
    self:addChild(self.cancelButton)

    self.category = ISComboBox:new(15, 96, 190, 24, self, ParadiseEconomy.MartPanel.onCategoryChanged)
    self.category:initialise()
    self:addChild(self.category)
    self.buyButton = ISButton:new(213, 96, 80, 24, "Buy", self, ParadiseEconomy.MartPanel.setDirection)
    self.buyButton.internal = "buy"
    self.buyButton:initialise()
    self:addChild(self.buyButton)
    self.sellButton = ISButton:new(301, 96, 80, 24, "Sell", self, ParadiseEconomy.MartPanel.setDirection)
    self.sellButton.internal = "sell"
    self.sellButton:initialise()
    self:addChild(self.sellButton)
    self.quantity = ISTextEntryBox:new("1", self.width - 263, 96, 70, 24)
    self.quantity.tooltip = "Quantity"
    self.quantity:initialise()
    self.quantity:instantiate()
    self.quantity:setOnlyNumbers(true)
    self:addChild(self.quantity)
    self.martTradeButton = ISButton:new(self.width - 185, 96, 170, 24, "Buy Selected", self, ParadiseEconomy.MartPanel.onMartTrade)
    self.martTradeButton:initialise()
    self:addChild(self.martTradeButton)
    self.martList = ISScrollingListBox:new(15, 152, self.width - 30, 300)
    self.martList:initialise()
    self.martList.itemheight = 28
    self.martList.font = UIFont.Small
    self.martList.doDrawItem = ParadiseEconomy.MartPanel.drawMartListing
    self.martList:setOnMouseDownFunction(self, ParadiseEconomy.MartPanel.onMartSelect)
    self:addChild(self.martList)

    ParadiseEconomy.styleWindow(self)
    ParadiseEconomy.styleTree(self)
    self.browseList.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    self.browseList.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    self:installDropCatchers()
    self:refreshAll()
    self:applyTab()
    self:layout()
    if self.shopKind and self.shopId then self:requestShop() end
end

function ParadiseEconomy.MartPanel:setScope(scope)
    self.shopKind = scope and scope.kind or nil
    self.shopId = scope and scope.id or nil
    self.shop = nil
    self.shopMessage = nil
    self.scopeLoaded = false
    self.browseCategory = nil
    self.martCategory = nil
    self.selectedBrowseId = nil
    self.selectedMartListingId = nil
    self.selectedStoreListingId = nil
    if self.shopKind == "mart" then
        self.tab = "mart"
    else
        self.tab = "browse"
    end
    self:setTitle(self:getShopTitle())
    self:refreshAll()
    self:applyTab()
    self:layout()
    self:requestShop()
end

function ParadiseEconomy.MartPanel:getShopTitle()
    if self.shop and self.shop.title then return tostring(self.shop.title) end
    if self.shopKind and self.shopId then
        for _, shop in ipairs(ParadiseEconomy.clientState.shops or {}) do
            if tostring(shop.id) == tostring(self.shopId) and shop.kind == self.shopKind then
                return tostring(shop.title or shop.id)
            end
        end
    end
    if self.shopKind == "store" then return "Merchant Store" end
    if self.shopKind == "mart" then return "Market" end
    return "Tradeshop"
end

function ParadiseEconomy.MartPanel:requestShop()
    if self.shopKind and self.shopId then
        ParadiseEconomy.send("requestShop", { kind = self.shopKind, id = self.shopId })
    end
end

function ParadiseEconomy.MartPanel:applyShopState(kind, id, shop, message)
    if self.shopKind ~= kind or tostring(self.shopId) ~= tostring(id) then return end
    self.shop = shop
    self.shopMessage = message
    if shop and shop.kind == "store" and shop.canManage == true and not self.scopeLoaded then
        self.tab = "store"
    end
    self.scopeLoaded = true
    self:setTitle(self:getShopTitle())
    self:refreshAll()
    self:applyTab()
    self:layout()
end

function ParadiseEconomy.MartPanel:getMarket()
    return ParadiseEconomy.clientState.market or {}
end

function ParadiseEconomy.MartPanel:getZoneId()
    if self.shop and self.shop.zoneId then return self.shop.zoneId end
    return self:getMarket().tradeZoneId
end

function ParadiseEconomy.MartPanel:getTrade()
    local zoneId = self:getZoneId()
    for _, trade in ipairs(ParadiseEconomy.getManagedZones()) do
        if trade.zoneId == zoneId then return trade end
    end
    local market = self:getMarket()
    if market.trade and (not zoneId or market.trade.zoneId == zoneId) then return market.trade end
    return nil
end

function ParadiseEconomy.MartPanel:getMerchant()
    local shop = self.shop
    if not shop or shop.kind ~= "store" then return nil end
    for _, merchant in ipairs(ParadiseEconomy.clientState.merchants or {}) do
        if tostring(merchant.id) == tostring(shop.id) then return merchant end
    end
    if shop.canManage == true then return shop end
    return nil
end

function ParadiseEconomy.MartPanel:getTaxPercent()
    if self.shop and tonumber(self.shop.taxPercent) then return tonumber(self.shop.taxPercent) end
    local trade = self:getTrade()
    if trade then return ParadiseEconomy.getTradeTaxPercent(trade) end
    return ParadiseEconomy.getTradeTaxPercentFor(self:getZoneId())
end

function ParadiseEconomy.MartPanel:setTabState(button, active)
    ParadiseEconomy.styleTabButton(button, active)
end

function ParadiseEconomy.MartPanel:applyTab()
    local martOnly = self.shopKind == "mart"
    if martOnly then
        self.tab = "mart"
    elseif self.tab == "mart" then
        self.tab = "browse"
    end
    local isBrowse = self.tab == "browse" and not martOnly
    local isStore = self.tab == "store" and not martOnly
    local isMart = self.tab == "mart" and martOnly
    self.browseSearch:setVisible(isBrowse)
    self.browseList:setVisible(isBrowse)
    self.storeTitle:setVisible(isStore)
    self.renameStoreButton:setVisible(isStore)
    self.renewLeaseButton:setVisible(isStore)
    self.collectButton:setVisible(isStore)
    self.invSearch:setVisible(isStore)
    self.invList:setVisible(isStore)
    self.storePrice:setVisible(isStore)
    self.storeCurrency:setVisible(isStore)
    self.postButton:setVisible(isStore)
    self.myListings:setVisible(isStore)
    self.cancelButton:setVisible(isStore)
    self.category:setVisible(false)
    self.buyButton:setVisible(isMart)
    self.sellButton:setVisible(isMart)
    self.quantity:setVisible(isMart)
    self.martTradeButton:setVisible(isMart)
    self.martList:setVisible(isMart)
    self.tabBrowse:setVisible(not martOnly)
    self.tabStore:setVisible(not martOnly)
    self.tabMart:setVisible(martOnly)
    self.tabBrowse:setTitle(self.shopKind == "store" and "STORE LISTINGS" or "BROWSE STORES")
    self.tabStore:setTitle("MY STORE")
    self.tabMart:setTitle("MARKET LISTINGS")
    self:setTabState(self.tabBrowse, isBrowse)
    self:setTabState(self.tabStore, isStore)
    self:setTabState(self.tabMart, isMart)
    self:setMartDirectionState()
end

function ParadiseEconomy.MartPanel:onTab(button)
    self.tab = button.internal
    self:refreshAll()
    self:applyTab()
end

function ParadiseEconomy.MartPanel:layout()
    if not self.tabBrowse then return end
    local w, h = self.width, self.height
    local contentY = 96
    local footerY = h - 34
    self.tabBrowse:setX(15)
    self.tabBrowse:setY(58)
    self.tabBrowse:setWidth(150)
    self.tabBrowse:setHeight(24)
    self.tabStore:setX(173)
    self.tabStore:setY(58)
    self.tabStore:setWidth(150)
    self.tabStore:setHeight(24)
    self.tabMart:setX(self.shopKind == "mart" and 15 or 331)
    self.tabMart:setY(58)
    self.tabMart:setWidth(160)
    self.tabMart:setHeight(24)
    self.manageButton:setX(w - 231)
    self.manageButton:setY(22)

    local countText = tostring(self.browseItemCount or 0) .. " ITEMS"
    local countW = math.max(64, getTextManager():MeasureStringX(UIFont.Small, countText) + 18)
    self.browseCountText = countText
    self.browseCountW = countW
    self.browseSearch:setX(15)
    self.browseSearch:setY(contentY)
    self.browseSearch:setWidth(math.max(160, w - 30 - countW - 8))
    self:positionBrowse()

    self.storeTitle:setX(28)
    self.storeTitle:setY(122)
    self.storeTitle:setWidth(math.max(110, math.min(230, w * 0.24)))
    self.renameStoreButton:setX(36 + self.storeTitle:getWidth())
    self.renameStoreButton:setY(122)
    self.renewLeaseButton:setX(w - 155)
    self.renewLeaseButton:setY(122)
    self.collectButton:setX(w - 303)
    self.collectButton:setY(122)
    local leftW = math.min(360, math.max(300, w * 0.34))
    local rightX = 15 + leftW + 15
    local listTop = 204
    self.invSearch:setX(15)
    self.invSearch:setY(listTop)
    self.invSearch:setWidth(leftW)
    self.invList:setX(15)
    self.invList:setY(listTop + 30)
    self.invList:setWidth(leftW)
    self.invList:setHeight(math.max(60, footerY - (listTop + 30) - 62))
    local postY = self.invList:getY() + self.invList:getHeight() + 8
    self.storePrice:setX(15)
    self.storePrice:setY(postY)
    self.storeCurrency:setX(100)
    self.storeCurrency:setY(postY)
    self.postButton:setX(210)
    self.postButton:setY(postY)
    self.postButton:setWidth(math.max(80, leftW - 195))
    self.myListings:setX(rightX)
    self.myListings:setY(listTop)
    self.myListings:setWidth(math.max(200, w - 15 - rightX))
    self.myListings:setHeight(math.max(60, footerY - listTop - 40))
    self.cancelButton:setX(w - 185)
    self.cancelButton:setY(footerY - 32)

    self.category:setX(15)
    self.category:setY(contentY)
    self.category:setWidth(190)
    self.buyButton:setX(213)
    self.buyButton:setY(contentY)
    self.sellButton:setX(301)
    self.sellButton:setY(contentY)
    self.quantity:setX(w - 263)
    self.quantity:setY(contentY)
    self.martTradeButton:setX(w - 185)
    self.martTradeButton:setY(contentY)
    self:positionMart()
    self.lastWidth = w
    self.lastHeight = h
end

function ParadiseEconomy.MartPanel:computeMartChips()
    local chips = {}
    local maxX = self.width - 15
    local x, y = 15, 130
    local rowH = 24
    local entries = { { key = "__all", label = "All" } }
    for _, name in ipairs(self:getCategoryOptions()) do
        entries[#entries + 1] = { key = name, label = name }
    end
    for _, entry in ipairs(entries) do
        local chipW = math.min(200, math.max(58, getTextManager():MeasureStringX(UIFont.Small, entry.label) + 20))
        if x + chipW > maxX and x > 15 then
            x = 15
            y = y + rowH + 6
        end
        chips[#chips + 1] = { key = entry.key, label = entry.label, x = x, y = y, w = chipW, h = rowH }
        x = x + chipW + 6
    end
    self.martChips = chips
    self.martChipsBottom = #chips > 0 and (y + rowH) or 130
end

function ParadiseEconomy.MartPanel:positionMart()
    if not self.martList then return end
    local footerY = self.height - 34
    self:computeMartChips()
    local listY = (self.martChipsBottom or 130) + 24
    self.martList:setX(15)
    self.martList:setY(listY)
    self.martList:setWidth(self.width - 30)
    self.martList:setHeight(math.max(80, footerY - listY))
end

function ParadiseEconomy.MartPanel:computeBrowseChips()
    local chips = {}
    local maxX = self.width - 15
    local x, y = 15, 130
    local rowH = 24
    for _, entry in ipairs(self.browseCategoryOptions or {}) do
        local label = tostring(entry.label) .. "  " .. tostring(entry.count or 0)
        local chipW = math.min(200, math.max(58, getTextManager():MeasureStringX(UIFont.Small, label) + 20))
        if x + chipW > maxX and x > 15 then
            x = 15
            y = y + rowH + 6
        end
        chips[#chips + 1] = { key = entry.key, label = label, x = x, y = y, w = chipW, h = rowH }
        x = x + chipW + 6
    end
    self.browseChips = chips
    self.browseChipsBottom = #chips > 0 and (y + rowH) or 130
end

function ParadiseEconomy.MartPanel:positionBrowse()
    if not self.browseList then return end
    local w, h = self.width, self.height
    local footerY = h - 34
    self:computeBrowseChips()
    local listY = (self.browseChipsBottom or 130) + 10
    local listW = w - 30
    self.browseList:setX(15)
    self.browseList:setY(listY)
    self.browseList:setWidth(listW)
    self.browseList:setHeight(math.max(80, footerY - listY))
    self.browseList.cardGap = 10
    self.browseList.cardW = math.max(140, math.floor((listW - 16 - 3 * 10) / 4))
end

function ParadiseEconomy.MartPanel:refreshAll()
    self:refreshBrowse()
    self:refreshStore()
    self:refreshInventory()
    self:refreshCategories()
    self:refreshMart()
end

function ParadiseEconomy.MartPanel:refreshMarket()
    if self.shopKind and self.shopId then self:requestShop() end
    self:refreshAll()
end

function ParadiseEconomy.MartPanel:getListingCategory(listing)
    return tostring((listing.itemData and listing.itemData.category) or listing.category or "General")
end

function ParadiseEconomy.MartPanel:refreshBrowse()
    if not self.browseList then return end
    local previous = self.selectedBrowseId
    local search = string.lower(self.browseSearch and self.browseSearch:getInternalText() or "")
    local searched = {}
    for _, listing in ipairs(self:getBrowseListings()) do
        local name = listing.itemData and listing.itemData.name or listing.fullType or "Item"
        local text = string.lower(tostring(name) .. " " .. tostring(listing.fullType or "") .. " "
            .. tostring(listing.seller or "") .. " " .. tostring(listing.merchantAccountId or "") .. " "
            .. tostring(listing.merchantTitle or ""))
        if search == "" or text:find(search, 1, true) then
            searched[#searched + 1] = listing
        end
    end
    local counts = {}
    local categories = {}
    for _, listing in ipairs(searched) do
        local category = self:getListingCategory(listing)
        if not counts[category] then
            counts[category] = 0
            categories[#categories + 1] = category
        end
        counts[category] = counts[category] + 1
    end
    table.sort(categories)
    local options = { { key = "__all", label = "All", count = #searched } }
    for _, name in ipairs(categories) do
        options[#options + 1] = { key = name, label = name, count = counts[name] }
    end
    self.browseCategoryOptions = options
    if self.browseCategory and not counts[self.browseCategory] then self.browseCategory = nil end
    local active = self.browseCategory
    local filtered = {}
    for _, listing in ipairs(searched) do
        if not active or self:getListingCategory(listing) == active then
            filtered[#filtered + 1] = listing
        end
    end
    self.browseList:clear()
    self.browseCache = filtered
    self.browseItemCount = #filtered
    self.browseRows = {}
    for first = 1, #filtered, 4 do
        local row = { listings = {} }
        for cell = 0, 3 do
            local listing = filtered[first + cell]
            if listing then row.listings[#row.listings + 1] = listing end
        end
        self.browseRows[#self.browseRows + 1] = row
        self.browseList:addItem("row", row)
    end
    local selectedRow
    if previous then
        for index, row in ipairs(self.browseRows) do
            for _, listing in ipairs(row.listings) do
                if tostring(listing.id) == tostring(previous) then selectedRow = index end
            end
        end
    end
    if selectedRow then
        self.browseList.selected = selectedRow
    elseif #self.browseRows == 0 then
        self.browseList.selected = 0
        self.selectedBrowseId = nil
    else
        self.browseList.selected = 1
        self.selectedBrowseId = self.browseRows[1].listings[1].id
    end
    self:layout()
end

function ParadiseEconomy.MartPanel:refreshStore()
    if not self.myListings then return end
    local merchant = self:getMerchant()
    self.merchant = merchant
    if merchant and not self.storeTitle:isFocused() and self.storeTitle:getInternalText() ~= tostring(merchant.title or "") then
        self.storeTitle:setText(tostring(merchant.title or ""))
    elseif not merchant and not self.storeTitle:isFocused() and self.storeTitle:getInternalText() ~= "" then
        self.storeTitle:setText("")
    end
    local previous = self.selectedStoreListingId
    self.myListings:clear()
    self.storeCache = {}
    for _, listing in ipairs(merchant and merchant.listings or {}) do
        local name = listing.itemData and listing.itemData.name or listing.fullType or "Item"
        self.myListings:addItem(name, listing)
        self.storeCache[#self.storeCache + 1] = listing
    end
    local selected
    if previous then
        for int, listing in ipairs(self.storeCache) do
            if tostring(listing.id) == tostring(previous) then selected = int end
        end
    end
    if selected then
        self.myListings.selected = selected
    elseif #self.storeCache == 0 then
        self.myListings.selected = 0
    else
        self.myListings.selected = 1
    end
    self.selectedStoreListingId = self.myListings.selected > 0 and self.storeCache[self.myListings.selected].id or nil
end

function ParadiseEconomy.MartPanel:refreshInventory()
    if not self.invList then return end
    local previous = self.selectedInventoryId
    local search = string.lower(self.invSearch and self.invSearch:getInternalText() or "")
    local pl = getPlayer()
    local inv = pl and pl:getInventory() or nil
    local items = inv and inv:getItems() or nil
    self.invList:clear()
    self.inventoryCache = {}
    if items then
        for int = 0, items:size() - 1 do
            local item = items:get(int)
            if item and not ParadiseEconomy.isItemEquipped(pl, item) then
                local name = tostring(item:getDisplayName() or item:getName() or item:getFullType())
                local text = string.lower(name .. " " .. tostring(item:getFullType()))
                if search == "" or text:find(search, 1, true) then
                    self.invList:addItem(name, item)
                    self.inventoryCache[#self.inventoryCache + 1] = item
                end
            end
        end
    end
    table.sort(self.inventoryCache, function(a, b)
        return tostring(a:getDisplayName() or a:getFullType()) < tostring(b:getDisplayName() or b:getFullType())
    end)
    table.sort(self.invList.items, function(a, b) return tostring(a.text) < tostring(b.text) end)
    local selected
    if previous then
        for int, row in ipairs(self.invList.items) do
            if row.item and tostring(row.item:getID()) == tostring(previous) then selected = int end
        end
    end
    if selected then
        self.invList.selected = selected
    elseif #self.invList.items == 0 then
        self.invList.selected = 0
    else
        self.invList.selected = 1
    end
    self.selectedInventoryId = self.invList.selected > 0 and self.invList.items[self.invList.selected].item:getID() or nil
end

function ParadiseEconomy.MartPanel:getBrowseListings()
    if self.shopKind == "store" and self.shop then return self.shop.listings or {} end
    if not self.shopKind then
        local pl = getPlayer()
        local square = pl and pl:getSquare() or nil
        if not square then return {} end
        local ids = {}
        for _, shop in ipairs(ParadiseEconomy.getShopsAtSquare(square:getX(), square:getY(), square:getZ())) do
            if shop.kind == "store" then ids[tostring(shop.id)] = true end
        end
        local list = {}
        for _, listing in ipairs(self:getMarket().playerListings or {}) do
            if ids[tostring(listing.merchantAccountId)] then list[#list + 1] = listing end
        end
        return list
    end
    return {}
end

function ParadiseEconomy.MartPanel:getMartListings()
    if self.shopKind == "mart" and self.shop then return self.shop.listings or {} end
    return {}
end

function ParadiseEconomy.MartPanel:getCategoryOptions()
    local seen = {}
    local categories = {}
    if self.shop and self.shop.categories then
        for _, category in ipairs(self.shop.categories) do
            local name = tostring(category or "General")
            if not seen[name] then
                seen[name] = true
                categories[#categories + 1] = name
            end
        end
    end
    for _, listing in ipairs(self:getMartListings()) do
        local category = tostring(listing.category or "General")
        if not seen[category] then
            seen[category] = true
            categories[#categories + 1] = category
        end
    end
    table.sort(categories)
    return categories
end

function ParadiseEconomy.MartPanel:refreshCategories()
    local options = self:getCategoryOptions()
    local valid = false
    for _, name in ipairs(options) do
        if name == self.martCategory then valid = true end
    end
    if not valid then self.martCategory = nil end
end

function ParadiseEconomy.MartPanel:getSelectedCategory()
    return self.martCategory
end

function ParadiseEconomy.MartPanel:refreshMart()
    if not self.martList then return end
    local previous = self.selectedMartListingId
    local category = self:getSelectedCategory()
    self.martList:clear()
    self.martCache = {}
    for _, listing in ipairs(self:getMartListings()) do
        if listing.direction == self.martDirection and (not category or listing.category == category) then
            self.martList:addItem(tostring(listing.fullType), listing)
            self.martCache[#self.martCache + 1] = listing
        end
    end
    local selected
    if previous then
        for int, listing in ipairs(self.martCache) do
            if tostring(listing.id) == tostring(previous) then selected = int end
        end
    end
    if selected then
        self.martList.selected = selected
    elseif #self.martCache == 0 then
        self.martList.selected = 0
    else
        self.martList.selected = 1
    end
    self.selectedMartListingId = self.martList.selected > 0 and self.martCache[self.martList.selected].id or nil
end

function ParadiseEconomy.MartPanel:getSelectedBrowse()
    for _, listing in ipairs(self.browseCache or {}) do
        if tostring(listing.id) == tostring(self.selectedBrowseId) then return listing end
    end
    return nil
end

function ParadiseEconomy.MartPanel:getSelectedStoreListing()
    for _, listing in ipairs(self.storeCache or {}) do
        if tostring(listing.id) == tostring(self.selectedStoreListingId) then return listing end
    end
    return nil
end

function ParadiseEconomy.MartPanel:getSelectedInventoryItem()
    local row = self.invList and self.invList.items[self.invList.selected or 0] or nil
    if not row or not row.item then return nil end
    local pl = getPlayer()
    local inv = pl and pl:getInventory() or nil
    local items = inv and inv:getItems() or nil
    if not items then return nil end
    for int = 0, items:size() - 1 do
        local item = items:get(int)
        if item and tostring(item:getID()) == tostring(row.item:getID()) then return item end
    end
    return nil
end

function ParadiseEconomy.MartPanel:getSelectedMartListing()
    for _, listing in ipairs(self.martCache or {}) do
        if tostring(listing.id) == tostring(self.selectedMartListingId) then return listing end
    end
    return nil
end

function ParadiseEconomy.MartPanel:onBrowseSearchChanged(target)
    if target and target.refreshBrowse then target:refreshBrowse() end
end

function ParadiseEconomy.MartPanel:onInventorySearchChanged(target)
    if target and target.refreshInventory then target:refreshInventory() end
end

function ParadiseEconomy.MartPanel:onBrowseGridMouseDown(list, x, y)
    if list:isMouseOverScrollBar() then return end
    local row = list:rowAt(x, y)
    if row < 1 or row > #list.items then return end
    local rowData = list.items[row].item
    if not rowData or not rowData.listings then return end
    local cardW = list.cardW or 0
    local cardGap = list.cardGap or 10
    local cell = 1
    if cardW > 0 then cell = math.floor(x / (cardW + cardGap)) + 1 end
    local listing = rowData.listings[cell]
    if not listing then return end
    self.selectedBrowseId = listing.id
    self.selectedBrowseCell = cell
    local offsetY = y - list:topOfItem(row)
    if offsetY >= list.itemheight - 34 and offsetY < list.itemheight - 10 then
        self:buyBrowseListing(listing)
    else
        self:beginListingDrag(listing)
    end
end

function ParadiseEconomy.MartPanel:buyBrowseListing(listing)
    local pl = getPlayer()
    if not listing or listing.expired then return end
    if listing.closed then
        self:setDropHint(tostring(listing.merchantTitle or "This store") .. " is "
            .. tostring(listing.merchantStatusLabel or "closed"))
        return
    end
    if pl and ParadiseEconomy.usernameKey(listing.seller) == ParadiseEconomy.usernameKey(pl:getUsername()) then
        self:setDropHint("This is your own listing. Cancel it from My Store.")
        return
    end
    ParadiseEconomy.send("playerShopBuy", { listingId = listing.id })
end

function ParadiseEconomy.MartPanel.onStoreListingSelect(target, listing)
    if target and listing then target.selectedStoreListingId = listing.id end
end

function ParadiseEconomy.MartPanel.onInventorySelect(target, item)
    if target and item then target.selectedInventoryId = item:getID() end
end

function ParadiseEconomy.MartPanel.onMartSelect(target, listing)
    if target and listing then target.selectedMartListingId = listing.id end
end

function ParadiseEconomy.MartPanel:onRenameStore()
    local merchant = self:getMerchant()
    if merchant then
        ParadiseEconomy.send("merchantSetTitle", { accountId = merchant.id, title = self.storeTitle:getInternalText() })
    end
end

function ParadiseEconomy.MartPanel:onRenewLease()
    local merchant = self:getMerchant()
    if merchant then ParadiseEconomy.send("merchantRenew", { accountId = merchant.id }) end
end

function ParadiseEconomy.MartPanel:onCollect()
    if self.shop and self.shop.isOwner == true then ParadiseEconomy.send("merchantCollect") end
end

function ParadiseEconomy.MartPanel:onPostSelected()
    local item = self:getSelectedInventoryItem()
    local merchant = self:getMerchant()
    local price = self.storePrice:getInternalText()
    if not item or not merchant or (self.shop and self.shop.isOwner ~= true) then return end
    if self.shop and self.shop.closed then
        self:setDropHint("This merchant store is " .. tostring(self.shop.statusLabel or "closed")
            .. ". Renew the lease before posting.")
        return
    end
    if not tonumber(price) or tonumber(price) <= 0 then return end
    ParadiseEconomy.send("playerShopPost", {
        merchantId = merchant.id,
        itemId = item:getID(),
        currency = self.storeCurrency.options[self.storeCurrency.selected],
        amount = price,
    })
    self.storePrice:setText("")
end

function ParadiseEconomy.MartPanel:onCancelListing()
    local listing = self:getSelectedStoreListing()
    if listing and self.shop and self.shop.isOwner == true then
        ParadiseEconomy.send("playerShopCancel", { listingId = listing.id })
    end
end

function ParadiseEconomy.MartPanel:openManagement()
    if ParadiseEconomy.TradeManagementPanel and ParadiseEconomy.TradeManagementPanel.OpenPanel then
        ParadiseEconomy.TradeManagementPanel.OpenPanel()
    end
end

function ParadiseEconomy.MartPanel:installDropCatchers()
    local children = self:getChildren()
    for _, child in pairs(children or {}) do
        if child and child.onMouseUp and not child.paradiseDropCatcher then
            child.paradiseDropCatcher = true
            local baseMouseUp = child.onMouseUp
            child.onMouseUp = function(element, x, y)
                if baseMouseUp then baseMouseUp(element, x, y) end
                self:tryAcceptInventoryDrop()
            end
        end
    end
end

function ParadiseEconomy.MartPanel:onMouseDown(x, y)
    ISCollapsableWindow.onMouseDown(self, x, y)
    if self.tab == "mart" then
        for _, chip in ipairs(self.martChips or {}) do
            if x >= chip.x and x < chip.x + chip.w and y >= chip.y and y < chip.y + chip.h then
                local key = chip.key ~= "__all" and chip.key or nil
                if key ~= self.martCategory then
                    self.martCategory = key
                    self:refreshMart()
                end
                return
            end
        end
        return
    end
    if self.tab ~= "browse" or not self.browseChips then return end
    for _, chip in ipairs(self.browseChips) do
        if x >= chip.x and x < chip.x + chip.w and y >= chip.y and y < chip.y + chip.h then
            local key = chip.key ~= "__all" and chip.key or nil
            if key ~= self.browseCategory then
                self.browseCategory = key
                self:refreshBrowse()
            end
            return
        end
    end
end

function ParadiseEconomy.MartPanel:onMouseUp(x, y)
    ISCollapsableWindow.onMouseUp(self, x, y)
    self:tryAcceptInventoryDrop()
end

function ParadiseEconomy.MartPanel:setDropHint(text)
    self.dropHint = text
    self.dropHintUntil = os.time() + 4
end

function ParadiseEconomy.MartPanel:isCarriedItem(item)
    local pl = getPlayer()
    local cont = item and item.getContainer and item:getContainer() or nil
    return pl ~= nil and cont ~= nil and cont:isInCharacterInventory(pl) and not ParadiseEconomy.isItemEquipped(pl, item)
end

function ParadiseEconomy.MartPanel:tryAcceptInventoryDrop()
    if not self:getIsVisible() or self.isCollapsed then return false end
    if not self:isMouseOver() then return false end
    if not ISMouseDrag.dragging or #ISMouseDrag.dragging == 0 then return false end
    local pl = getPlayer()
    if not pl or self.shopKind == "mart" or not self:getMerchant() then return false end
    if self.shop and self.shop.isOwner ~= true then return false end
    local items = ISInventoryPane.getActualItems(ISMouseDrag.dragging)
    local accepted = {}
    for _, item in ipairs(items or {}) do
        if item and item.getID and self:isCarriedItem(item) then accepted[#accepted + 1] = item end
    end
    if #accepted == 0 then return false end
    ISMouseDrag.dragging = nil
    ISMouseDrag.draggingFocus = nil
    ISMouseDrag.dragView = nil
    self:queueListingItems(accepted)
    return true
end

function ParadiseEconomy.MartPanel:queueListingItems(items)
    if not items or #items == 0 then return end
    self.listingQueue = self.listingQueue or {}
    for _, item in ipairs(items) do self.listingQueue[#self.listingQueue + 1] = item end
    if ParadiseEconomy.listingInstance and ParadiseEconomy.listingInstance.suppressCloseCallback ~= true then
        ParadiseEconomy.listingInstance.suppressCloseCallback = true
        ParadiseEconomy.listingInstance:close()
    end
    self:openNextQueuedListing()
end

function ParadiseEconomy.MartPanel:openNextQueuedListing()
    if not self.listingQueue or #self.listingQueue == 0 then return end
    local item = table.remove(self.listingQueue, 1)
    local merchant = self:getMerchant()
    ParadiseEconomy.openListingPanel(item, function(panel, posted)
        if not self:getIsVisible() then
            self.listingQueue = {}
            return
        end
        if posted then
            self:setDropHint("Listing posted. Drag another item to add more.")
            self:openNextQueuedListing()
        else
            self.listingQueue = {}
            self:setDropHint("Listing cancelled.")
        end
    end, merchant and merchant.id or nil)
end

function ParadiseEconomy.MartPanel:beginListingDrag(listing)
    local pl = getPlayer()
    if not listing or listing.expired or listing.closed or not pl then return end
    if ParadiseEconomy.usernameKey(listing.seller) == ParadiseEconomy.usernameKey(pl:getUsername()) then return end
    self.listingDrag = {
        listing = listing,
        startX = getMouseX(),
        startY = getMouseY(),
        mouseX = getMouseX(),
        mouseY = getMouseY(),
        active = false,
    }
end

function ParadiseEconomy.MartPanel:updateListingDrag()
    local drag = self.listingDrag
    if not drag then return end
    local mx, my = getMouseX(), getMouseY()
    drag.mouseX, drag.mouseY = mx, my
    if isMouseButtonDown(0) then
        if not drag.active and (math.abs(mx - drag.startX) > 6 or math.abs(my - drag.startY) > 6) then
            drag.active = true
        end
        return
    end
    self.listingDrag = nil
    if drag.active then self:finishListingDrag(drag, mx, my) end
end

function ParadiseEconomy.MartPanel:getDropContainerAt(mx, my)
    if self:isPointOver(mx, my) then return nil end
    local pl = getPlayer()
    if not pl then return nil end
    local plNum = pl:getPlayerNum()
    local pages = {}
    local loot = getPlayerLoot and getPlayerLoot(plNum) or nil
    local inventory = getPlayerInventory and getPlayerInventory(plNum) or nil
    if loot then pages[#pages + 1] = loot end
    if inventory then pages[#pages + 1] = inventory end
    for _, page in ipairs(pages) do
        if page and page:getIsVisible() and not page.isCollapsed and page:isPointOver(mx, my) then
            local button = page.mouseOverButton
            if button and button.inventory and button:isMouseOver() then return button.inventory end
            if page.inventoryPane and page.inventoryPane.inventory then return page.inventoryPane.inventory end
        end
    end
    return nil
end

function ParadiseEconomy.MartPanel:finishListingDrag(drag, mx, my)
    local listing = drag.listing
    if not listing then return end
    local container = self:getDropContainerAt(mx, my)
    if not container then
        self:setDropHint("Drop the listing on your inventory or an open container to purchase.")
        return
    end
    local destination = ParadiseEconomy.getContainerDestination(getPlayer(), container)
    if not destination then
        self:setDropHint("That container cannot receive purchased items.")
        return
    end
    ParadiseEconomy.openPurchasePanel(listing, destination)
end

function ParadiseEconomy.getContainerDestination(pl, container)
    if not pl or not container then return nil end
    if container == pl:getInventory() then
        return { kind = "player", label = "your inventory" }
    end
    local item = container.getContainingItem and container:getContainingItem() or nil
    if item and container:isInCharacterInventory(pl) then
        local name = tostring(item:getDisplayName() or item:getName() or "bag")
        return { kind = "bag", itemId = item:getID(), label = "your " .. name }
    end
    local parent = container.getParent and container:getParent() or nil
    local square = container.getSourceGrid and container:getSourceGrid() or nil
    if parent and square then
        local objects = square:getObjects()
        local index = -1
        for int = 0, objects:size() - 1 do
            if objects:get(int) == parent then
                index = int
                break
            end
        end
        if index >= 0 then
            local containerIndex = parent.getContainerIndex and parent:getContainerIndex(container) or -1
            return {
                kind = "object",
                x = square:getX(),
                y = square:getY(),
                z = square:getZ(),
                index = index,
                containerIndex = containerIndex,
                label = tostring(container:getType() or "container"),
            }
        end
    end
    return nil
end

function ParadiseEconomy.MartPanel.onCategoryChanged(target, combo)
    target.category.selected = combo.selected
    target:refreshMart()
end

function ParadiseEconomy.MartPanel:setMartDirectionState()
    local theme = ParadiseEconomy.Theme
    local buy = self.martDirection == "buy"
    self.buyButton.backgroundColor = buy and theme.accentDim or theme.buttonBg
    self.sellButton.backgroundColor = not buy and theme.accentDim or theme.buttonBg
    self.martTradeButton:setTitle(buy and "Buy Selected" or "Sell Selected")
end

function ParadiseEconomy.MartPanel:setDirection(button)
    self.martDirection = button.internal
    self:refreshMart()
    self:setMartDirectionState()
end

function ParadiseEconomy.MartPanel:onMartTrade()
    local listing = self:getSelectedMartListing()
    if not listing or not self.shop or self.shop.kind ~= "mart" then return end
    ParadiseEconomy.send(self.martDirection == "buy" and "marketBuy" or "marketSell", {
        martId = self.shop.id,
        listingId = listing.id,
        quantity = self.quantity:getInternalText(),
    })
end

function ParadiseEconomy.MartPanel:update()
    ISCollapsableWindow.update(self)
    if self.width ~= self.lastWidth or self.height ~= self.lastHeight then self:layout() end
    self.isAdm = ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(getPlayer()) or false
    local canManage = ParadiseEconomy.canManageTradeZones()
    self.manageButton:setVisible(canManage)
    self.manageButton:setEnable(canManage)
    if self.tab == "store" then
        local merchant = self:getMerchant()
        self.merchant = merchant
        if merchant and not self.storeTitle:isFocused() and self.storeTitle:getInternalText() ~= tostring(merchant.title or "") then
            self.storeTitle:setText(tostring(merchant.title or ""))
        end
        local price = tonumber(self.storePrice:getInternalText())
        local leaseDays = tonumber(merchant and merchant.leaseDays) or 0
        local isOwner = self.shop ~= nil and self.shop.isOwner == true
        self.storeTitle:setEnable(merchant ~= nil)
        self.renameStoreButton:setEnable(merchant ~= nil and self.storeTitle:getInternalText() ~= "")
        self.renewLeaseButton:setEnable(merchant ~= nil and leaseDays > 0)
        self.collectButton:setEnable(isOwner and merchant ~= nil and ParadiseEconomy.hasMoney(merchant.earnings))
        self.postButton:setEnable(isOwner and merchant ~= nil and self.shop.closed ~= true
            and self:getSelectedInventoryItem() ~= nil and price ~= nil and price > 0)
        self.cancelButton:setEnable(isOwner and self:getSelectedStoreListing() ~= nil)
    elseif self.tab == "mart" then
        local listing = self:getSelectedMartListing()
        local quantity = tonumber(self.quantity:getInternalText())
        self.martTradeButton:setEnable(listing ~= nil and self.shop ~= nil and quantity ~= nil and quantity > 0)
    end
    self:updateListingDrag()
end

function ParadiseEconomy.MartPanel:close()
    self.listingDrag = nil
    self.listingQueue = {}
    if ParadiseEconomy.purchaseInstance then ParadiseEconomy.purchaseInstance:close() end
    if ParadiseEconomy.MartPanel.ClosePanel then
        ParadiseEconomy.MartPanel.ClosePanel()
    else
        self:setVisible(false)
        self:removeFromUIManager()
    end
end

function ParadiseEconomy.MartPanel:drawBrowseCard(list, x, y, w, h, listing)
    local theme = ParadiseEconomy.Theme
    local panel = list.target or self
    local data = listing.itemData or {}
    local name = tostring(data.name or listing.fullType or "Item")
    local category = panel:getListingCategory(listing)
    local tint = ParadiseEconomy.getCategoryColor(category)
    local selected = tostring(panel.selectedBrowseId) == tostring(listing.id)
    list:drawRect(x, y, w, h, theme.cardBg.a, theme.cardBg.r, theme.cardBg.g, theme.cardBg.b)
    list:drawRectBorder(x, y, w, h, selected and 1 or theme.borderSoft.a,
        selected and theme.accent.r or theme.borderSoft.r,
        selected and theme.accent.g or theme.borderSoft.g,
        selected and theme.accent.b or theme.borderSoft.b)
    local imgH = math.max(56, math.floor(h * 0.42))
    list:drawRect(x + 1, y + 1, w - 2, imgH, 0.55, tint.r * 0.22, tint.g * 0.22, tint.b * 0.22)
    local stripe = 0
    while stripe < imgH do
        list:drawRect(x + 1, y + 1 + stripe, w - 2, 1, 0.09, tint.r, tint.g, tint.b)
        stripe = stripe + 12
    end
    list:drawTextCentre(ParadiseEconomy.getItemInitials(name), x + w / 2, y + math.floor(imgH / 2) - 9,
        tint.r, tint.g, tint.b, 0.9, UIFont.Large)
    local chipText = ParadiseEconomy.fitText(category, w - 28, UIFont.Small)
    local chipW = getTextManager():MeasureStringX(UIFont.Small, chipText) + 14
    list:drawRect(x + 6, y + 6, chipW, 16, 0.82, 0.020, 0.030, 0.038)
    list:drawRectBorder(x + 6, y + 6, chipW, 16, 0.75, tint.r, tint.g, tint.b)
    list:drawText(chipText, x + 13, y + 8, tint.r, tint.g, tint.b, 1, UIFont.Small)
    local nameY = y + imgH + 7
    list:drawText(ParadiseEconomy.fitText(name, w - 16, UIFont.Medium), x + 8, nameY,
        theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Medium)
    local seller = tostring(listing.seller or "-")
    local place = tostring(listing.zoneTitle or listing.merchantTitle or "-")
    list:drawText(ParadiseEconomy.fitText(seller .. "  ·  " .. place, w - 16, UIFont.Small), x + 8, nameY + 22,
        theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    local priceY = y + h - 50
    local icon = listing.currency == "paradisium" and ParadiseEconomy.icons.paradisium or ParadiseEconomy.icons.jimoleon
    if icon then list:drawTextureScaled(icon, x + 8, priceY + 1, 14, 14, 1) end
    local priceColor = listing.currency == "paradisium" and theme.accent or theme.gold
    list:drawText(ParadiseEconomy.formatNumber(listing.price), x + 26, priceY,
        priceColor.r, priceColor.g, priceColor.b, 1, UIFont.Medium)
    local status, statusColor = ParadiseEconomy.getListingStatusView(listing)
    list:drawTextRight(status, x + w - 8, priceY + 1, statusColor.r, statusColor.g, statusColor.b, 1, UIFont.Small)
    local pl = getPlayer()
    local own = pl and ParadiseEconomy.usernameKey(listing.seller) == ParadiseEconomy.usernameKey(pl:getUsername())
    local barColor, barText, barTextColor
    if own then
        barColor, barText, barTextColor = theme.accentDim, "YOUR LISTING", theme.text
    elseif listing.expired then
        barColor, barText, barTextColor = { r = 0.30, g = 0.14, b = 0.13, a = 1 }, "EXPIRED", theme.danger
    else
        barColor = theme.gold
        barText = "BUY  " .. ParadiseEconomy.formatNumber(listing.price) .. "  "
            .. (listing.currency == "paradisium" and "P" or "J")
        barTextColor = { r = 0.05, g = 0.06, b = 0.07, a = 1 }
    end
    local barY = y + h - 26
    list:drawRect(x + 1, barY, w - 2, 25, barColor.a, barColor.r, barColor.g, barColor.b)
    list:drawTextCentre(barText, x + w / 2, barY + 6, barTextColor.r, barTextColor.g, barTextColor.b, 1, UIFont.Small)
end

function ParadiseEconomy.MartPanel:drawBrowseRow(y, item, alt)
    local list = self
    local gap = list.cardGap or 10
    local cardW = list.cardW or 200
    local cardH = list.itemheight - 10
    for index, listing in ipairs(item.item.listings or {}) do
        local x = (index - 1) * (cardW + gap)
        list.target:drawBrowseCard(list, x, y, cardW, cardH, listing)
    end
    return y + list.itemheight
end

function ParadiseEconomy.MartPanel:drawStoreListing(y, item, alt)
    local listing = item.item
    local theme = ParadiseEconomy.Theme
    if self.selected == item.index then
        self:drawRect(0, y, self.width, self.itemheight - 1, theme.rowSelected.a, theme.rowSelected.r, theme.rowSelected.g, theme.rowSelected.b)
    elseif alt then
        self:drawRect(0, y, self.width, self.itemheight - 1, theme.rowAlt.a, theme.rowAlt.r, theme.rowAlt.g, theme.rowAlt.b)
    end
    local name = listing.itemData and listing.itemData.name or listing.fullType or "Item"
    self:drawText(ParadiseEconomy.fitText(name, self.width - 160, UIFont.Small), 8, y + 4,
        theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Small)
    self:drawTextRight(tostring(listing.price) .. " " .. tostring(listing.currency), self.width - 8, y + 4,
        theme.gold.r, theme.gold.g, theme.gold.b, 1, UIFont.Small)
    local lease = ParadiseEconomy.getLeaseInfo(listing.merchantExpiresAt)
    local color = ParadiseEconomy.getLeaseColor(lease.status)
    local subtitle = "Merchant " .. tostring(listing.merchantAccountId or "-")
    self:drawText(ParadiseEconomy.fitText(subtitle, self.width - 160, UIFont.Small), 8, y + 21,
        theme.textDim.r, theme.textDim.g, theme.textDim.b, 1, UIFont.Small)
    self:drawTextRight(lease.label, self.width - 8, y + 21, color.r, color.g, color.b, 1, UIFont.Small)
    return y + self.itemheight
end

function ParadiseEconomy.MartPanel:drawInventoryItem(y, item, alt)
    local theme = ParadiseEconomy.Theme
    if self.selected == item.index then
        self:drawRect(0, y, self.width, self.itemheight - 1, theme.rowSelected.a, theme.rowSelected.r, theme.rowSelected.g, theme.rowSelected.b)
    elseif alt then
        self:drawRect(0, y, self.width, self.itemheight - 1, theme.rowAlt.a, theme.rowAlt.r, theme.rowAlt.g, theme.rowAlt.b)
    end
    self:drawText(ParadiseEconomy.fitText(item.text, self.width - 140, UIFont.Small), 8, y + 4,
        theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Small)
    local category = item.item and item.item.getCategory and item.item:getCategory() or nil
    if category then
        self:drawTextRight(ParadiseEconomy.fitText(tostring(category), 120, UIFont.Small), self.width - 8, y + 4,
            theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    end
    return y + self.itemheight
end

function ParadiseEconomy.MartPanel:drawMartListing(y, item, alt)
    local listing = item.item
    local theme = ParadiseEconomy.Theme
    if self.selected == item.index then
        self:drawRect(0, y, self.width, self.itemheight - 1, theme.rowSelected.a, theme.rowSelected.r, theme.rowSelected.g, theme.rowSelected.b)
    elseif alt then
        self:drawRect(0, y, self.width, self.itemheight - 1, theme.rowAlt.a, theme.rowAlt.r, theme.rowAlt.g, theme.rowAlt.b)
    end
    local action = listing.direction == "sell" and "MART BUYS" or "MART SELLS"
    local tint = ParadiseEconomy.getCategoryColor(listing.category)
    local chipText = ParadiseEconomy.fitText(tostring(listing.category or "General"), 120, UIFont.Small)
    local chipW = getTextManager():MeasureStringX(UIFont.Small, chipText) + 14
    self:drawRect(8, y + 6, chipW, 16, 0.18, tint.r, tint.g, tint.b)
    self:drawRectBorder(8, y + 6, chipW, 16, 0.55, tint.r, tint.g, tint.b)
    self:drawText(chipText, 15, y + 7, tint.r, tint.g, tint.b, 1, UIFont.Small)
    self:drawText(ParadiseEconomy.fitText(tostring(listing.fullType), self.width - 430, UIFont.Small), 150, y + 7,
        theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Small)
    self:drawText(action, self.width - 210, y + 7, theme.textDim.r, theme.textDim.g, theme.textDim.b, 1, UIFont.Small)
    local priceText = ParadiseEconomy.formatNumber(listing.price)
    local priceW = getTextManager():MeasureStringX(UIFont.Small, priceText)
    local icon = listing.currency == "paradisium" and ParadiseEconomy.icons.paradisium or ParadiseEconomy.icons.jimoleon
    if icon then self:drawTextureScaled(icon, self.width - 12 - priceW - 18, y + 6, 14, 14, 1) end
    self:drawTextRight(priceText, self.width - 10, y + 7,
        theme.gold.r, theme.gold.g, theme.gold.b, 1, UIFont.Small)
    return y + self.itemheight
end

function ParadiseEconomy.MartPanel:drawBrowseChips()
    local theme = ParadiseEconomy.Theme
    for _, chip in ipairs(self.browseChips or {}) do
        local active = (chip.key == "__all" and not self.browseCategory) or chip.key == self.browseCategory
        local bg = active and theme.accentDim or theme.cardBg
        local border = active and theme.accent or theme.borderSoft
        self:drawRect(chip.x, chip.y, chip.w, chip.h, bg.a, bg.r, bg.g, bg.b)
        self:drawRectBorder(chip.x, chip.y, chip.w, chip.h, border.a, border.r, border.g, border.b)
        local color = active and theme.text or theme.textMuted
        self:drawTextCentre(chip.label, chip.x + chip.w / 2, chip.y + 4, color.r, color.g, color.b, 1, UIFont.Small)
    end
end

function ParadiseEconomy.MartPanel:drawMartChips()
    local theme = ParadiseEconomy.Theme
    for _, chip in ipairs(self.martChips or {}) do
        local active = (chip.key == "__all" and not self.martCategory) or chip.key == self.martCategory
        local bg = active and theme.accentDim or theme.cardBg
        local border = active and theme.accent or theme.borderSoft
        self:drawRect(chip.x, chip.y, chip.w, chip.h, bg.a, bg.r, bg.g, bg.b)
        self:drawRectBorder(chip.x, chip.y, chip.w, chip.h, border.a, border.r, border.g, border.b)
        local color = active and theme.text or theme.textMuted
        self:drawTextCentre(chip.label, chip.x + chip.w / 2, chip.y + 4, color.r, color.g, color.b, 1, UIFont.Small)
    end
end

function ParadiseEconomy.MartPanel:drawBrowseTab()
    local theme = ParadiseEconomy.Theme
    local w = self.width
    local countText = self.browseCountText or (tostring(self.browseItemCount or 0) .. " ITEMS")
    local countW = self.browseCountW or math.max(64, getTextManager():MeasureStringX(UIFont.Small, countText) + 18)
    self:drawRect(w - 15 - countW, 96, countW, 24, theme.cardBg.a, theme.cardBg.r, theme.cardBg.g, theme.cardBg.b)
    self:drawRectBorder(w - 15 - countW, 96, countW, 24, theme.borderSoft.a, theme.borderSoft.r, theme.borderSoft.g, theme.borderSoft.b)
    self:drawTextCentre(countText, w - 15 - countW / 2, 101,
        theme.accent.r, theme.accent.g, theme.accent.b, 1, UIFont.Small)
    self:drawBrowseChips()
    if #(self.browseCache or {}) == 0 then
        local emptyText = self.shopKind == "store" and "This merchant store has no listings yet."
            or "No player listings match this filter."
        self:drawTextCentre(emptyText, w / 2, self.browseList:getY() + 40,
            theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    end
end

function ParadiseEconomy.MartPanel:drawStoreTab()
    local theme = ParadiseEconomy.Theme
    local w = self.width
    ParadiseEconomy.drawCard(self, 15, 96, w - 30, 88, theme.accentDim)
    self:drawText("MERCHANT STALL", 29, 106, theme.accent.r, theme.accent.g, theme.accent.b, 1, UIFont.Small)
    local merchant = self:getMerchant()
    if merchant then
        local lease = ParadiseEconomy.getLeaseInfo(merchant.expiresAt)
        local color = ParadiseEconomy.getLeaseColor(lease.status)
        self:drawTextRight("LEASE  " .. string.upper(lease.label), w - 29, 106, color.r, color.g, color.b, 1, UIFont.Small)
        if merchant.closed then
            local status = tostring(merchant.statusLabel or "Suspended")
            self:drawText("STORE " .. string.upper(status) .. "  ·  BUYING AND POSTING DISABLED",
                29, 128, theme.danger.r, theme.danger.g, theme.danger.b, 1, UIFont.Small)
        end
        local merchantText = "MERCHANT  " .. tostring(merchant.id) .. "  ·  OWNER  " .. tostring(merchant.owner or "-")
        self:drawText(ParadiseEconomy.fitText(merchantText, w - 380, UIFont.Small), 29, 152,
            theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
        self:drawTextRight("EARNINGS  " .. ParadiseEconomy.formatBalances(merchant.earnings), w - 29, 152,
            theme.gold.r, theme.gold.g, theme.gold.b, 1, UIFont.Small)
    else
        self:drawText("NO MERCHANT STORE OF YOURS AT THIS SQUARE.", 29, 110,
            theme.warn.r, theme.warn.g, theme.warn.b, 1, UIFont.Small)
        self:drawText("Right-click the square you want and choose Register Merchant Store Here.", 29, 132,
            theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    end
    self:drawText("CARRIED ITEMS", 15, 188, theme.accent.r, theme.accent.g, theme.accent.b, 1, UIFont.Small)
    self:drawTextRight(tostring(#(self.inventoryCache or {})) .. " ITEMS", 15 + self.invSearch:getWidth(), 188,
        theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText("YOUR STORE LISTINGS", self.myListings:getX(), 188, theme.accent.r, theme.accent.g, theme.accent.b, 1, UIFont.Small)
    self:drawTextRight(tostring(#(self.storeCache or {})) .. " POSTS", self.myListings:getX() + self.myListings:getWidth(), 188,
        theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText("PRICE", self.storePrice:getX(), self.storePrice:getY() - 15,
        theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText("CURRENCY", self.storeCurrency:getX(), self.storeCurrency:getY() - 15,
        theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
end

function ParadiseEconomy.MartPanel:drawMartTab()
    local theme = ParadiseEconomy.Theme
    local w = self.width
    self:drawMartChips()
    local headerY = self.martList:getY() - 17
    self:drawText("CATEGORY", 21, headerY, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText("ITEM", 150, headerY, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText("MODE", w - 210, headerY, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawTextRight("PRICE", w - 15, headerY, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawRect(15, headerY + 12, w - 30, 1, theme.borderSoft.a, theme.borderSoft.r, theme.borderSoft.g, theme.borderSoft.b)
    self:drawText("QTY", self.quantity:getX() - 32, self.quantity:getY() + 5,
        theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    if #(self.martCache or {}) == 0 then
        self:drawTextCentre("No item mart entries for this filter.", w / 2, self.martList:getY() + 40,
            theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    end
end

function ParadiseEconomy.MartPanel:prerender()
    ISCollapsableWindow.prerender(self)
    local theme = ParadiseEconomy.Theme
    local w = self.width
    local headerText = "TRADESHOP  ·  PLAYER LISTINGS AND ITEM MART"
    if self.shopKind == "store" then
        headerText = "MERCHANT STORE  ·  " .. string.upper(tostring(self:getShopTitle()))
    elseif self.shopKind == "mart" then
        headerText = "MARKET  ·  " .. string.upper(tostring(self:getShopTitle()))
    end
    ParadiseEconomy.drawPanelHeader(self, headerText, "04")
    ParadiseEconomy.drawTabUnderline(self, self.tabBrowse, self.tab == "browse")
    ParadiseEconomy.drawTabUnderline(self, self.tabStore, self.tab == "store")
    ParadiseEconomy.drawTabUnderline(self, self.tabMart, self.tab == "mart")

    local market = self:getMarket()
    local trade = self:getTrade()
    local zoneText = "ZONE  " .. string.upper(tostring((self.shop and self.shop.zoneTitle) or market.tradeZoneTitle or "NO TRADE ZONE"))
    if trade then zoneText = zoneText .. "  ·  TRADE  " .. string.upper(tostring(trade.title or trade.tradeId or trade.id)) end
    local leaseDays = tonumber(trade and trade.merchantLeaseDays or market.leaseDays) or 0
    zoneText = zoneText .. "  ·  " .. (leaseDays > 0 and (tostring(math.floor(leaseDays)) .. " DAY LEASES") or "NO LEASE LIMIT")
        .. "  ·  TAX " .. string.format("%g", self:getTaxPercent() or 0) .. "%"
    self:drawTextRight(ParadiseEconomy.fitText(zoneText, w - 530, UIFont.Small), w - 20, 64,
        theme.textDim.r, theme.textDim.g, theme.textDim.b, 1, UIFont.Small)
    self:drawRect(15, 86, w - 30, 1, theme.borderSoft.a, theme.borderSoft.r, theme.borderSoft.g, theme.borderSoft.b)

    if self.tab == "browse" then
        self:drawBrowseTab()
    elseif self.tab == "store" then
        self:drawStoreTab()
    elseif self.tab == "mart" then
        self:drawMartTab()
    end

    local draggingIn = ISMouseDrag.dragging and #ISMouseDrag.dragging > 0 and self:isMouseOver()
    if draggingIn and ParadiseEconomy.canOpenMart(getPlayer()) then
        self:drawRect(0, 0, self.width, self.height, 0.10, theme.gold.r, theme.gold.g, theme.gold.b)
        self:drawRectBorder(1, 1, self.width - 2, self.height - 2, 0.85, theme.gold.r, theme.gold.g, theme.gold.b)
        self:drawTextCentre("Release to price and post these items in your store", self.width / 2, self.height - 56,
            theme.gold.r, theme.gold.g, theme.gold.b, 1, UIFont.Small)
    end

    self:drawRect(0, self.height - 34, self.width, 34, theme.headerBg.a, theme.headerBg.r, theme.headerBg.g, theme.headerBg.b)
    local drag = self.listingDrag and self.listingDrag.active and self.listingDrag or nil
    local hint = self.dropHint and self.dropHintUntil >= os.time() and self.dropHint or nil
    local message = self.shopMessage or ParadiseEconomy.clientState.message
    if drag then
        local name = drag.listing.itemData and drag.listing.itemData.name or drag.listing.fullType or "listing"
        self:drawText(ParadiseEconomy.fitText("Drag " .. tostring(name) .. " to your inventory or an open container to purchase.",
            self.width - 30, UIFont.Small), 15, self.height - 25, theme.gold.r, theme.gold.g, theme.gold.b, 1, UIFont.Small)
    elseif hint then
        self:drawText(ParadiseEconomy.fitText(tostring(hint), self.width - 30, UIFont.Small), 15, self.height - 25,
            theme.accent.r, theme.accent.g, theme.accent.b, 1, UIFont.Small)
    elseif message then
        self:drawText(ParadiseEconomy.fitText(tostring(message), self.width - 30, UIFont.Small), 15, self.height - 25,
            theme.warn.r, theme.warn.g, theme.warn.b, 1, UIFont.Small)
    end
end

function ParadiseEconomy.TradeManagementPanel:new(x, y, w, h)
    local obj = ISCollapsableWindow.new(self, x, y, w, h)
    obj.title = "Trade Management"
    obj.resizable = true
    obj.minimumWidth = 1000
    obj.minimumHeight = 700
    obj.tab = "merchants"
    obj.isAdm = ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(getPlayer()) or false
    obj.selectedZoneId = nil
    obj.selectedMerchantId = nil
    obj.selectedPostId = nil
    obj.merchantFilterKey = ""
    obj.lastWidth = 0
    obj.lastHeight = 0
    return obj
end

function ParadiseEconomy.TradeManagementPanel:createChildren()
    ISCollapsableWindow.createChildren(self)

    self.zone = ISComboBox:new(15, 62, 300, 25, self, ParadiseEconomy.TradeManagementPanel.onZoneChanged)
    self.zone.tooltip = "Trade zone to manage"
    self.zone:initialise()
    self:addChild(self.zone)
    self.leaseDays = ISTextEntryBox:new("", 325, 62, 64, 25)
    self.leaseDays.tooltip = "Merchant lease days for this trade zone (0 disables leases)"
    self.leaseDays:initialise()
    self.leaseDays:instantiate()
    self.leaseDays:setOnlyNumbers(true)
    self:addChild(self.leaseDays)
    self.applyLeaseButton = ISButton:new(397, 62, 150, 25, "APPLY LEASE DAYS", self, ParadiseEconomy.TradeManagementPanel.applyLeaseDays)
    self.applyLeaseButton.tooltip = "Grant this lease duration to every merchant in the zone"
    self.applyLeaseButton:initialise()
    self:addChild(self.applyLeaseButton)
    self.dailyFee = ISTextEntryBox:new("", 559, 62, 64, 25)
    self.dailyFee.tooltip = "Merchant store cost per day, paid to the zone treasury (0 disables)"
    self.dailyFee:initialise()
    self.dailyFee:instantiate()
    self.dailyFee:setOnlyNumbers(true)
    self.dailyFee:setPlaceholderText("Fee/day")
    self:addChild(self.dailyFee)
    self.feeCurrency = ISComboBox:new(631, 62, 110, 25, self)
    self.feeCurrency.tooltip = "Currency merchants pay the daily store fee in"
    self.feeCurrency:initialise()
    self.feeCurrency:addOption("jimoleon")
    self.feeCurrency:addOption("paradisium")
    self:addChild(self.feeCurrency)
    self.applyFeeButton = ISButton:new(749, 62, 128, 25, "APPLY DAILY FEE", self, ParadiseEconomy.TradeManagementPanel.applyDailyFee)
    self.applyFeeButton.tooltip = "Set the per-day merchant store cost for this trade zone"
    self.applyFeeButton:initialise()
    self:addChild(self.applyFeeButton)
    self.zoneOwner = ISTextEntryBox:new("", 594, 94, 140, 24)
    self.zoneOwner.tooltip = "Admin only: zone owner username or 'server'"
    self.zoneOwner:initialise()
    self.zoneOwner:instantiate()
    self.zoneOwner:setPlaceholderText("Zone owner...")
    self:addChild(self.zoneOwner)
    self.setOwnerButton = ISButton:new(740, 94, 100, 24, "SET OWNER", self, ParadiseEconomy.TradeManagementPanel.applyZoneOwner)
    self.setOwnerButton.tooltip = "Admin only: reassign this trade zone's owner and finance account"
    self.setOwnerButton:initialise()
    self:addChild(self.setOwnerButton)
    self.sweepButton = ISButton:new(846, 94, 120, 24, "SWEEP", self, ParadiseEconomy.TradeManagementPanel.sweepTreasury)
    self.sweepButton.tooltip = "Move the zone treasury balance into its finance account"
    self.sweepButton:initialise()
    self:addChild(self.sweepButton)

    self.tabMerchants = ISButton:new(15, 94, 170, 24, "MERCHANTS", self, ParadiseEconomy.TradeManagementPanel.onTab)
    self.tabMerchants.internal = "merchants"
    self.tabMerchants.tooltip = "Merchant leases in the selected trade zone"
    self.tabMerchants:initialise()
    self:addChild(self.tabMerchants)
    self.tabPosts = ISButton:new(193, 94, 185, 24, "PLAYER POSTS", self, ParadiseEconomy.TradeManagementPanel.onTab)
    self.tabPosts.internal = "posts"
    self.tabPosts.tooltip = "Every player trade post in the selected zone, including expired posts"
    self.tabPosts:initialise()
    self:addChild(self.tabPosts)
    self.tabMart = ISButton:new(386, 94, 200, 24, "ITEM MART & FUNDS", self, ParadiseEconomy.TradeManagementPanel.onTab)
    self.tabMart.internal = "mart"
    self.tabMart.tooltip = "Item mart listings, trade tax, owner and funds"
    self.tabMart:initialise()
    self:addChild(self.tabMart)

    self.merchantList = ISScrollingListBox:new(15, 100, 330, 300)
    self.merchantList:initialise()
    self.merchantList.itemheight = 44
    self.merchantList.font = UIFont.Small
    self.merchantList.doDrawItem = ParadiseEconomy.TradeManagementPanel.drawMerchant
    self.merchantList:setOnMouseDownFunction(self, ParadiseEconomy.TradeManagementPanel.onMerchantSelect)
    self:addChild(self.merchantList)
    self.merchantRenewButton = ISButton:new(0, 0, 130, 26, "Renew Lease", self, ParadiseEconomy.TradeManagementPanel.renewMerchantLease)
    self.merchantRenewButton:initialise()
    self:addChild(self.merchantRenewButton)
    self.merchantExpireButton = ISButton:new(0, 0, 110, 26, "Expire Now", self, ParadiseEconomy.TradeManagementPanel.expireMerchantLease)
    self.merchantExpireButton:initialise()
    self:addChild(self.merchantExpireButton)
    self.merchantClearButton = ISButton:new(0, 0, 105, 26, "Clear Lease", self, ParadiseEconomy.TradeManagementPanel.clearMerchantLease)
    self.merchantClearButton:initialise()
    self:addChild(self.merchantClearButton)
    self.merchantPostsButton = ISButton:new(0, 0, 150, 26, "Open Posts", self, ParadiseEconomy.TradeManagementPanel.openMerchantPosts)
    self.merchantPostsButton.tooltip = "Show every trade post from this merchant, including expired posts"
    self.merchantPostsButton:initialise()
    self:addChild(self.merchantPostsButton)
    self.merchantOwnerButton = ISButton:new(0, 0, 170, 26, "ADMIN · OPEN OWNER", self, ParadiseEconomy.TradeManagementPanel.openMerchantOwner)
    self.merchantOwnerButton.tooltip = "Admin only: open the merchant owner's account in Economy Administration"
    self.merchantOwnerButton:initialise()
    self:addChild(self.merchantOwnerButton)
    self.merchantSuspendButton = ISButton:new(0, 0, 125, 26, "Suspend Store", self, ParadiseEconomy.TradeManagementPanel.toggleMerchantSuspension)
    self.merchantSuspendButton.tooltip = "Zone owner or admin: suspend or resume this merchant store"
    self.merchantSuspendButton:initialise()
    self:addChild(self.merchantSuspendButton)

    self.postMerchant = ISComboBox:new(15, 126, 260, 25, self, ParadiseEconomy.TradeManagementPanel.onPostMerchantChanged)
    self.postMerchant.tooltip = "Filter player posts by merchant"
    self.postMerchant:initialise()
    self:addChild(self.postMerchant)
    self.postSearch = ISTextEntryBox:new("", 283, 126, 300, 25)
    self.postSearch.target = self
    self.postSearch.onTextChangeFunction = ParadiseEconomy.TradeManagementPanel.onPostSearchChanged
    self.postSearch.tooltip = "Search posts by item, seller or merchant id"
    self.postSearch:initialise()
    self.postSearch:instantiate()
    self.postSearch:setPlaceholderText("Search posts by item, seller or merchant id...")
    self:addChild(self.postSearch)
    self.postList = ISScrollingListBox:new(15, 160, 330, 300)
    self.postList:initialise()
    self.postList.itemheight = 44
    self.postList.font = UIFont.Small
    self.postList.doDrawItem = ParadiseEconomy.TradeManagementPanel.drawPost
    self.postList:setOnMouseDownFunction(self, ParadiseEconomy.TradeManagementPanel.onPostSelect)
    self:addChild(self.postList)
    self.postOwnerButton = ISButton:new(0, 0, 190, 26, "ADMIN · OPEN SELLER", self, ParadiseEconomy.TradeManagementPanel.openPostSeller)
    self.postOwnerButton.tooltip = "Admin only: open the seller's account in Economy Administration"
    self.postOwnerButton:initialise()
    self:addChild(self.postOwnerButton)

    self.adminView = ParadiseEconomy.MartAdminView:new(15, 126, self.width - 30, self.height - 160, self)
    self:addChild(self.adminView)

    ParadiseEconomy.styleWindow(self)
    ParadiseEconomy.styleTree(self)
    local adminButtonColor = ParadiseEconomy.Theme.gold
    self.merchantOwnerButton.borderColor = adminButtonColor
    self.merchantOwnerButton.textColor = adminButtonColor
    self.postOwnerButton.borderColor = adminButtonColor
    self.postOwnerButton.textColor = adminButtonColor
    self:refreshState()
    self:applyTab()
    self:layout()
end

function ParadiseEconomy.TradeManagementPanel:getZoneList()
    return ParadiseEconomy.getManageableTradeZones()
end

function ParadiseEconomy.TradeManagementPanel:getSelectedZone()
    local zoneId = self.selectedZoneId
    if not zoneId then return nil end
    for _, zone in ipairs(self.zoneCache or {}) do
        if zone.zoneId == zoneId then return zone end
    end
    return nil
end

function ParadiseEconomy.TradeManagementPanel:getSelectedMerchant()
    for _, merchant in ipairs(self.merchantCache or {}) do
        if tostring(merchant.id) == tostring(self.selectedMerchantId) then return merchant end
    end
    return nil
end

function ParadiseEconomy.TradeManagementPanel:getSelectedPost()
    for _, post in ipairs(self.postCache or {}) do
        if tostring(post.id) == tostring(self.selectedPostId) then return post end
    end
    return nil
end

function ParadiseEconomy.TradeManagementPanel:setTabState(button, active)
    ParadiseEconomy.styleTabButton(button, active)
end

function ParadiseEconomy.TradeManagementPanel:updateTabTitles()
    if not self.tabMerchants then return end
    self.tabMerchants:setTitle("MERCHANTS  " .. tostring(#(self.merchantCache or {})))
    self.tabPosts:setTitle("PLAYER POSTS  " .. tostring(#(self.postCache or {})))
    self.tabMart:setTitle("ITEM MART & FUNDS")
end

function ParadiseEconomy.TradeManagementPanel:applyTab()
    local isMerchants = self.tab == "merchants"
    local isPosts = self.tab == "posts"
    local isMart = self.tab == "mart"
    self.merchantList:setVisible(isMerchants)
    self.merchantRenewButton:setVisible(isMerchants)
    self.merchantExpireButton:setVisible(isMerchants)
    self.merchantClearButton:setVisible(isMerchants)
    self.merchantPostsButton:setVisible(isMerchants)
    self.merchantOwnerButton:setVisible(isMerchants and self.isAdm)
    self.merchantSuspendButton:setVisible(isMerchants)
    self.postMerchant:setVisible(isPosts)
    self.postSearch:setVisible(isPosts)
    self.postList:setVisible(isPosts)
    self.postOwnerButton:setVisible(isPosts and self.isAdm)
    self.adminView:setVisible(isMart)
    self.zoneOwner:setVisible(self.isAdm)
    self.setOwnerButton:setVisible(self.isAdm)
    self:setTabState(self.tabMerchants, isMerchants)
    self:setTabState(self.tabPosts, isPosts)
    self:setTabState(self.tabMart, isMart)
    self:updateTabTitles()
end

function ParadiseEconomy.TradeManagementPanel:onTab(button)
    self.tab = button.internal
    self:applyTab()
    if self.tab == "mart" and self.adminView then self.adminView:refreshMarket() end
end

function ParadiseEconomy.TradeManagementPanel:layout()
    if not self.zone then return end
    local w, h = self.width, self.height
    local rowY = 62
    local contentY = 126
    local footerY = h - 34
    self.zone:setX(15)
    self.zone:setY(rowY)
    self.zone:setWidth(math.min(320, math.max(240, w * 0.30)))
    local zoneW = self.zone:getWidth()
    self.leaseDays:setX(23 + zoneW)
    self.leaseDays:setY(rowY)
    self.applyLeaseButton:setX(95 + zoneW)
    self.applyLeaseButton:setY(rowY)
    self.applyLeaseButton:setWidth(150)
    local feeX = 257 + zoneW
    self.dailyFee:setX(feeX)
    self.dailyFee:setY(rowY)
    self.dailyFee:setWidth(64)
    self.feeCurrency:setX(feeX + 72)
    self.feeCurrency:setY(rowY)
    self.feeCurrency:setWidth(110)
    self.applyFeeButton:setX(feeX + 190)
    self.applyFeeButton:setY(rowY)
    self.applyFeeButton:setWidth(128)
    self.zoneOwner:setX(594)
    self.zoneOwner:setY(94)
    self.zoneOwner:setWidth(140)
    self.setOwnerButton:setX(740)
    self.setOwnerButton:setY(94)
    self.setOwnerButton:setWidth(100)
    self.sweepButton:setX(846)
    self.sweepButton:setY(94)
    self.sweepButton:setWidth(120)
    self.tabMerchants:setX(15)
    self.tabMerchants:setY(94)
    self.tabMerchants:setWidth(170)
    self.tabMerchants:setHeight(24)
    self.tabPosts:setX(193)
    self.tabPosts:setY(94)
    self.tabPosts:setWidth(185)
    self.tabPosts:setHeight(24)
    self.tabMart:setX(386)
    self.tabMart:setY(94)
    self.tabMart:setWidth(200)
    self.tabMart:setHeight(24)

    local tableX = 15
    local tableW = w - 30
    local headerH = 20
    local tableH = math.max(120, math.floor((footerY - contentY) * 0.54))
    local tableY = contentY + headerH
    local detailY = tableY + tableH + 10
    local detailH = math.max(120, footerY - detailY)
    self.tableX = tableX
    self.tableW = tableW
    self.tableHeaderY = contentY
    self.merchantList:setX(tableX)
    self.merchantList:setY(tableY)
    self.merchantList:setWidth(tableW)
    self.merchantList:setHeight(tableH)
    self.merchantDetailX = tableX
    self.merchantDetailY = detailY
    self.merchantDetailW = tableW
    self.merchantDetailH = detailH
    self.merchantRenewButton:setX(w - 395)
    self.merchantRenewButton:setY(footerY - 64)
    self.merchantExpireButton:setX(w - 255)
    self.merchantExpireButton:setY(footerY - 64)
    self.merchantClearButton:setX(w - 135)
    self.merchantClearButton:setY(footerY - 64)
    self.merchantPostsButton:setX(w - 345)
    self.merchantPostsButton:setY(footerY - 32)
    self.merchantOwnerButton:setX(w - 185)
    self.merchantOwnerButton:setY(footerY - 32)
    self.merchantSuspendButton:setX(w - 530)
    self.merchantSuspendButton:setY(footerY - 64)
    self.merchantSuspendButton:setWidth(125)
    self.merchantSuspendButton:setHeight(26)

    self.postMerchant:setX(15)
    self.postMerchant:setY(contentY)
    self.postMerchant:setWidth(260)
    self.postSearch:setX(283)
    self.postSearch:setY(contentY)
    self.postSearch:setWidth(math.max(120, tableW - 268))
    local postHeaderY = contentY + 34
    self.postHeaderY = postHeaderY
    local postTableY = postHeaderY + 20
    local postTableH = math.max(100, math.floor((footerY - postHeaderY) * 0.54))
    self.postList:setX(tableX)
    self.postList:setY(postTableY)
    self.postList:setWidth(tableW)
    self.postList:setHeight(postTableH)
    self.postDetailX = tableX
    self.postDetailY = postTableY + postTableH + 10
    self.postDetailW = tableW
    self.postDetailH = math.max(100, footerY - self.postDetailY)
    self.postOwnerButton:setX(w - 15 - 190)
    self.postOwnerButton:setY(footerY - 32)

    self.adminView:setX(15)
    self.adminView:setY(contentY)
    self.adminView:setWidth(w - 30)
    self.adminView:setHeight(footerY - contentY)
    self.lastWidth = w
    self.lastHeight = h
end

function ParadiseEconomy.TradeManagementPanel:refreshState()
    if not self.zone then return end
    self.isAdm = ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(getPlayer()) or false
    self:refreshZones()
    self:refreshMerchants()
    self:refreshPostFilter()
    self:refreshPosts()
    if self.adminView then self.adminView.isAdm = self.isAdm end
end

function ParadiseEconomy.TradeManagementPanel:refresh()
    self:refreshState()
end

function ParadiseEconomy.TradeManagementPanel:refreshZones()
    local zones = self:getZoneList()
    self.zoneCache = zones
    local previous = self.selectedZoneId
    self.zone.zoneIds = {}
    self.zone:clear()
    self.zone.selected = 0
    local selectedIndex
    for _, zone in ipairs(zones) do
        self.zone:addOption(tostring(zone.title or zone.tradeId or zone.zoneId) .. "  |  " .. tostring(zone.zoneId))
        self.zone.zoneIds[#self.zone.zoneIds + 1] = zone.zoneId
        if zone.zoneId == previous then selectedIndex = #self.zone.zoneIds end
    end
    if #zones == 0 then
        self.zone:addOption("No manageable trade zones")
        self.zone.selected = 1
        self.selectedZoneId = nil
    else
        if not selectedIndex then
            local market = ParadiseEconomy.clientState.market or {}
            for int, zoneId in ipairs(self.zone.zoneIds) do
                if zoneId == market.tradeZoneId then selectedIndex = int end
            end
        end
        self.zone.selected = selectedIndex or 1
        self.selectedZoneId = self.zone.zoneIds[self.zone.selected]
    end
    self:refreshLeaseEntry()
    self:refreshZoneSettings()
    if self.adminView then
        self.adminView.isAdm = self.isAdm
        self.adminView:setSelectedZone(self.selectedZoneId)
    end
end

function ParadiseEconomy.TradeManagementPanel:refreshLeaseEntry()
    local zone = self:getSelectedZone()
    if self.leaseDays and not self.leaseDays:isFocused() then
        self.leaseDays:setText(zone and tostring(zone.merchantLeaseDays or 0) or "")
    end
end

function ParadiseEconomy.TradeManagementPanel:refreshZoneSettings()
    local zone = self:getSelectedZone()
    if self.dailyFee and not self.dailyFee:isFocused() then
        self.dailyFee:setText(zone and tostring(zone.merchantDailyFee or 0) or "")
    end
    if self.feeCurrency and zone then
        self.feeCurrency.selected = zone.merchantFeeCurrency == "paradisium" and 2 or 1
    end
    if self.zoneOwner and not self.zoneOwner:isFocused() then
        self.zoneOwner:setText(zone and tostring(zone.owner or "server") or "")
    end
end

function ParadiseEconomy.TradeManagementPanel:applyDailyFee()
    if not self.selectedZoneId then return end
    local fee = self.dailyFee:getInternalText()
    if not fee:match("^%d+$") then return end
    ParadiseEconomy.send("zoneSetDailyFee", {
        zoneId = self.selectedZoneId,
        fee = fee,
        currency = self.feeCurrency.options[self.feeCurrency.selected],
    })
end

function ParadiseEconomy.TradeManagementPanel:applyZoneOwner()
    if not self.selectedZoneId or not self.isAdm then return end
    local owner = self.zoneOwner:getInternalText()
    if owner == "" then return end
    ParadiseEconomy.send("zoneSetOwner", { zoneId = self.selectedZoneId, owner = owner })
end

function ParadiseEconomy.TradeManagementPanel:sweepTreasury()
    if not self.selectedZoneId then return end
    ParadiseEconomy.send("zoneSweep", { zoneId = self.selectedZoneId })
end

function ParadiseEconomy.TradeManagementPanel:toggleMerchantSuspension()
    local merchant = self:getSelectedMerchant()
    if not merchant then return end
    ParadiseEconomy.send("merchantSuspend", {
        accountId = merchant.id,
        suspended = not merchant.suspended,
    })
end

function ParadiseEconomy.TradeManagementPanel:refreshMerchants()
    if not self.merchantList then return end
    local previous = self.selectedMerchantId
    local zone = self:getSelectedZone()
    self.merchantList:clear()
    self.merchantCache = {}
    for _, merchant in ipairs(zone and zone.managedMerchants or {}) do
        self.merchantList:addItem(tostring(merchant.title or merchant.owner or merchant.id), merchant)
        self.merchantCache[#self.merchantCache + 1] = merchant
    end
    local selected
    if previous then
        for int, merchant in ipairs(self.merchantCache) do
            if tostring(merchant.id) == tostring(previous) then selected = int end
        end
    end
    if selected then
        self.merchantList.selected = selected
    elseif #self.merchantCache == 0 then
        self.merchantList.selected = 0
    else
        self.merchantList.selected = 1
    end
    self.selectedMerchantId = self.merchantList.selected > 0 and self.merchantCache[self.merchantList.selected].id or nil
    self:updateTabTitles()
end

function ParadiseEconomy.TradeManagementPanel:refreshPostFilter()
    if not self.postMerchant then return end
    local previous = self.merchantFilterKey or ""
    local zone = self:getSelectedZone()
    self.postMerchant.merchantIds = {}
    self.postMerchant:clear()
    self.postMerchant:addOption("All merchants")
    self.postMerchant.merchantIds[1] = ""
    local selectedIndex = 1
    for _, merchant in ipairs(zone and zone.managedMerchants or {}) do
        self.postMerchant:addOption(tostring(merchant.title or merchant.owner or merchant.id)
            .. "  |  " .. tostring(merchant.id))
        self.postMerchant.merchantIds[#self.postMerchant.merchantIds + 1] = merchant.id
        if tostring(previous) == tostring(merchant.id) then selectedIndex = #self.postMerchant.merchantIds end
    end
    self.postMerchant.selected = selectedIndex
    self.merchantFilterKey = self.postMerchant.merchantIds[selectedIndex] or ""
end

function ParadiseEconomy.TradeManagementPanel:refreshPosts()
    if not self.postList then return end
    local previous = self.selectedPostId
    local zone = self:getSelectedZone()
    local filter = self.merchantFilterKey or ""
    local search = string.lower(self.postSearch and self.postSearch:getInternalText() or "")
    self.postList:clear()
    self.postCache = {}
    for _, post in ipairs(zone and zone.managedListings or {}) do
        if filter == "" or tostring(post.merchantAccountId) == tostring(filter) then
            local name = post.itemData and post.itemData.name or post.fullType or "Item"
            local text = string.lower(tostring(name) .. " " .. tostring(post.fullType or "") .. " "
                .. tostring(post.seller or "") .. " " .. tostring(post.merchantAccountId or "") .. " "
                .. tostring(post.merchantTitle or ""))
            if search == "" or text:find(search, 1, true) then
                self.postList:addItem(name, post)
                self.postCache[#self.postCache + 1] = post
            end
        end
    end
    local selected
    if previous then
        for int, post in ipairs(self.postCache) do
            if tostring(post.id) == tostring(previous) then selected = int end
        end
    end
    if selected then
        self.postList.selected = selected
    elseif #self.postCache == 0 then
        self.postList.selected = 0
    else
        self.postList.selected = 1
    end
    self.selectedPostId = self.postList.selected > 0 and self.postCache[self.postList.selected].id or nil
    self:updateTabTitles()
end

function ParadiseEconomy.TradeManagementPanel:onZoneChanged(target, combo)
    target.selectedZoneId = combo.zoneIds and combo.zoneIds[combo.selected] or nil
    target.selectedMerchantId = nil
    target.selectedPostId = nil
    target.merchantFilterKey = ""
    target:refreshLeaseEntry()
    target:refreshMerchants()
    target:refreshPostFilter()
    target:refreshPosts()
    if target.adminView then target.adminView:setSelectedZone(target.selectedZoneId) end
end

function ParadiseEconomy.TradeManagementPanel.onMerchantSelect(target, merchant)
    if target and merchant then target.selectedMerchantId = merchant.id end
end

function ParadiseEconomy.TradeManagementPanel.onPostSelect(target, post)
    if target and post then target.selectedPostId = post.id end
end

function ParadiseEconomy.TradeManagementPanel.onPostMerchantChanged(target, combo)
    target.merchantFilterKey = combo.merchantIds and combo.merchantIds[combo.selected] or ""
    target:refreshPosts()
end

function ParadiseEconomy.TradeManagementPanel:onPostSearchChanged(target)
    if target and target.refreshPosts then target:refreshPosts() end
end

function ParadiseEconomy.TradeManagementPanel:applyLeaseDays()
    if not self.selectedZoneId then return end
    local days = self.leaseDays:getInternalText()
    if not days:match("^%d+$") then return end
    ParadiseEconomy.send("tradeSetLeaseDays", { zoneId = self.selectedZoneId, days = days })
end

function ParadiseEconomy.TradeManagementPanel:renewMerchantLease()
    local merchant = self:getSelectedMerchant()
    if merchant then ParadiseEconomy.send("merchantRenew", { accountId = merchant.id }) end
end

function ParadiseEconomy.TradeManagementPanel:expireMerchantLease()
    local merchant = self:getSelectedMerchant()
    if not merchant then return end
    local modal = ISModalDialog:new(0, 0, 440, 170, "Expire the merchant lease for '" .. tostring(merchant.title or merchant.owner)
        .. "'?", true, self, ParadiseEconomy.TradeManagementPanel.onLeaseActionConfirmed, nil, merchant.id, "expire")
    modal:initialise()
    modal:addToUIManager()
end

function ParadiseEconomy.TradeManagementPanel:clearMerchantLease()
    local merchant = self:getSelectedMerchant()
    if not merchant then return end
    local modal = ISModalDialog:new(0, 0, 440, 170, "Remove the lease limit for '" .. tostring(merchant.title or merchant.owner)
        .. "'?", true, self, ParadiseEconomy.TradeManagementPanel.onLeaseActionConfirmed, nil, merchant.id, "clear")
    modal:initialise()
    modal:addToUIManager()
end

function ParadiseEconomy.TradeManagementPanel.onLeaseActionConfirmed(target, button, accountId, action)
    if button.internal == "YES" then
        ParadiseEconomy.send("merchantLeaseAction", { accountId = accountId, action = action })
    end
end

function ParadiseEconomy.TradeManagementPanel:openMerchantPosts()
    local merchant = self:getSelectedMerchant()
    if not merchant then return end
    self.merchantFilterKey = merchant.id
    self.tab = "posts"
    self:refreshPostFilter()
    self:refreshPosts()
    self:applyTab()
end

function ParadiseEconomy.TradeManagementPanel:openMerchantOwner()
    local merchant = self:getSelectedMerchant()
    if not merchant or not self.isAdm or not merchant.owner then return end
    if ParadiseEconomy.AdminPanel and ParadiseEconomy.AdminPanel.OpenPanel then
        ParadiseEconomy.AdminPanel.OpenPanel(merchant.owner)
    end
end

function ParadiseEconomy.TradeManagementPanel:openPostSeller()
    local post = self:getSelectedPost()
    if not post or not self.isAdm or not post.seller then return end
    if ParadiseEconomy.AdminPanel and ParadiseEconomy.AdminPanel.OpenPanel then
        ParadiseEconomy.AdminPanel.OpenPanel(post.seller)
    end
end

function ParadiseEconomy.TradeManagementPanel:update()
    ISCollapsableWindow.update(self)
    if self.width ~= self.lastWidth or self.height ~= self.lastHeight then self:layout() end
    self.isAdm = ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(getPlayer()) or false
    if self.tab == "mart" and self.adminView then
        self.adminView.isAdm = self.isAdm
        self.adminView:update()
    end
    local merchant = self:getSelectedMerchant()
    local zoneLeaseDays = tonumber(self:getSelectedZone() and self:getSelectedZone().merchantLeaseDays) or 0
    self.merchantRenewButton:setEnable(merchant ~= nil and zoneLeaseDays > 0)
    self.merchantExpireButton:setEnable(merchant ~= nil)
    self.merchantClearButton:setEnable(merchant ~= nil)
    self.merchantPostsButton:setEnable(merchant ~= nil)
    self.merchantOwnerButton:setVisible(self.isAdm and self.tab == "merchants")
    self.merchantOwnerButton:setEnable(self.isAdm and merchant ~= nil and merchant.owner ~= nil)
    self.merchantSuspendButton:setEnable(merchant ~= nil)
    self.merchantSuspendButton:setTitle(merchant and merchant.suspended and "Resume Store" or "Suspend Store")
    self.zoneOwner:setVisible(self.isAdm)
    self.setOwnerButton:setVisible(self.isAdm)
    self.setOwnerButton:setEnable(self.isAdm and self.selectedZoneId ~= nil
        and self.zoneOwner:getInternalText() ~= "")
    local fee = self.dailyFee:getInternalText()
    self.applyFeeButton:setEnable(self.selectedZoneId ~= nil and fee:match("^%d+$") ~= nil)
    self.sweepButton:setEnable(self.selectedZoneId ~= nil and self:getSelectedZone() ~= nil)
    local post = self:getSelectedPost()
    self.postOwnerButton:setVisible(self.isAdm and self.tab == "posts")
    self.postOwnerButton:setEnable(self.isAdm and post ~= nil and post.seller ~= nil)
    local days = self.leaseDays:getInternalText()
    self.applyLeaseButton:setEnable(self.selectedZoneId ~= nil and days:match("^%d+$") ~= nil)
end

function ParadiseEconomy.TradeManagementPanel:close()
    if ParadiseEconomy.TradeManagementPanel.ClosePanel then
        ParadiseEconomy.TradeManagementPanel.ClosePanel()
    else
        self:setVisible(false)
        self:removeFromUIManager()
    end
end

function ParadiseEconomy.getTradeTableColumns(width)
    width = tonumber(width) or 1000
    return {
        detail = math.floor(width * 0.30),
        col2 = 8 + math.floor(width * 0.31),
        col3 = 8 + math.floor(width * 0.46),
        col4 = 8 + math.floor(width * 0.56),
        col5 = 8 + math.floor(width * 0.72),
    }
end

function ParadiseEconomy.getTradeStatusChip(panel, y, label, color)
    local chipW = getTextManager():MeasureStringX(UIFont.Small, label) + 14
    local x = panel.width - 24 - chipW
    panel:drawRect(x, y, chipW, 16, 0.16, color.r, color.g, color.b)
    panel:drawRectBorder(x, y, chipW, 16, 0.65, color.r, color.g, color.b)
    panel:drawText(label, x + 7, y + 2, color.r, color.g, color.b, 1, UIFont.Small)
end

function ParadiseEconomy.getTradeLeaseStatusLabel(lease, archived)
    if archived then return "ARCHIVED" end
    local status = tostring(lease.status or "none")
    if status == "none" then return "NO EXPIRY" end
    return string.upper(status)
end

function ParadiseEconomy.TradeManagementPanel:drawMerchant(y, item, alt)
    local merchant = item.item
    local theme = ParadiseEconomy.Theme
    if self.selected == item.index then
        self:drawRect(0, y, self.width, self.itemheight - 1, theme.rowSelected.a, theme.rowSelected.r, theme.rowSelected.g, theme.rowSelected.b)
    elseif alt then
        self:drawRect(0, y, self.width, self.itemheight - 1, theme.rowAlt.a, theme.rowAlt.r, theme.rowAlt.g, theme.rowAlt.b)
    end
    local columns = ParadiseEconomy.getTradeTableColumns(self.width)
    local lease = ParadiseEconomy.getLeaseInfo(merchant.expiresAt)
    local closed = merchant.closed == true
    local color = (merchant.archived or merchant.suspended) and theme.danger
        or (closed and theme.warn or ParadiseEconomy.getLeaseColor(lease.status))
    local stateLabel = merchant.statusLabel and string.upper(tostring(merchant.statusLabel))
        or ParadiseEconomy.getTradeLeaseStatusLabel(lease, merchant.archived)
    local title = tostring(merchant.title or merchant.owner or merchant.id)
    self:drawText(ParadiseEconomy.fitText(title, columns.detail - 16, UIFont.Small), 8, y + 7,
        theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Small)
    ParadiseEconomy.getTradeStatusChip(self, y + 6, stateLabel, color)
    self:drawText(ParadiseEconomy.fitText(tostring(merchant.owner or "-"), columns.detail - 16, UIFont.Small), 8, y + 26,
        theme.textDim.r, theme.textDim.g, theme.textDim.b, 1, UIFont.Small)
    self:drawText(ParadiseEconomy.fitText(tostring(merchant.id or "-"), columns.col3 - columns.col2 - 12, UIFont.Small),
        columns.col2, y + 17, theme.accent.r, theme.accent.g, theme.accent.b, 1, UIFont.Small)
    self:drawText(tostring(merchant.listingCount or 0), columns.col3, y + 17,
        theme.textDim.r, theme.textDim.g, theme.textDim.b, 1, UIFont.Small)
    self:drawText(tostring(ParadiseEconomy.formatLeaseExpiry(merchant.expiresAt)), columns.col4, y + 17,
        color.r, color.g, color.b, 1, UIFont.Small)
    self:drawText(ParadiseEconomy.formatBalances(merchant.earnings), columns.col5, y + 17,
        theme.gold.r, theme.gold.g, theme.gold.b, 1, UIFont.Small)
    return y + self.itemheight
end

function ParadiseEconomy.TradeManagementPanel:drawPost(y, item, alt)
    local post = item.item
    local theme = ParadiseEconomy.Theme
    if self.selected == item.index then
        self:drawRect(0, y, self.width, self.itemheight - 1, theme.rowSelected.a, theme.rowSelected.r, theme.rowSelected.g, theme.rowSelected.b)
    elseif alt then
        self:drawRect(0, y, self.width, self.itemheight - 1, theme.rowAlt.a, theme.rowAlt.r, theme.rowAlt.g, theme.rowAlt.b)
    end
    local columns = ParadiseEconomy.getTradeTableColumns(self.width)
    local lease = ParadiseEconomy.getLeaseInfo(post.merchantExpiresAt)
    local color = post.merchantArchived and theme.danger or ParadiseEconomy.getLeaseColor(lease.status)
    local name = post.itemData and post.itemData.name or post.fullType or "Item"
    self:drawText(ParadiseEconomy.fitText(name, columns.detail - 16, UIFont.Small), 8, y + 7,
        theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Small)
    local archived = post.merchantArchived == true
    local stateLabel = archived and "ARCHIVED" or (post.expired and "EXPIRED" or ParadiseEconomy.getTradeLeaseStatusLabel(lease, false))
    local stateColor = (archived or post.expired) and theme.danger or color
    ParadiseEconomy.getTradeStatusChip(self, y + 6, stateLabel, stateColor)
    self:drawText(ParadiseEconomy.fitText(tostring(post.seller or "-"), columns.detail - 16, UIFont.Small), 8, y + 26,
        theme.textDim.r, theme.textDim.g, theme.textDim.b, 1, UIFont.Small)
    self:drawText(ParadiseEconomy.fitText(tostring(post.merchantTitle or post.merchantAccountId or "-"),
        columns.col3 - columns.col2 - 12, UIFont.Small), columns.col2, y + 17,
        theme.textDim.r, theme.textDim.g, theme.textDim.b, 1, UIFont.Small)
    self:drawText(tostring(post.price) .. " " .. tostring(post.currency), columns.col3, y + 17,
        theme.gold.r, theme.gold.g, theme.gold.b, 1, UIFont.Small)
    self:drawText(tostring(ParadiseEconomy.formatTimestamp(post.createdAt)), columns.col4, y + 17,
        theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText(tostring(ParadiseEconomy.formatLeaseExpiry(post.merchantExpiresAt)), columns.col5, y + 17,
        color.r, color.g, color.b, 1, UIFont.Small)
    return y + self.itemheight
end

function ParadiseEconomy.TradeManagementPanel:drawMerchantDetail()
    local theme = ParadiseEconomy.Theme
    local x, y = self.merchantDetailX, self.merchantDetailY
    local w, h = self.merchantDetailW, self.merchantDetailH
    ParadiseEconomy.drawCard(self, x, y, w, h, theme.accentDim)
    local merchant = self:getSelectedMerchant()
    if not merchant then
        self:drawText("Select a merchant row to inspect its lease.", x + 14, y + 12,
            theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
        return
    end
    local lease = ParadiseEconomy.getLeaseInfo(merchant.expiresAt)
    local color = merchant.archived and theme.danger or ParadiseEconomy.getLeaseColor(lease.status)
    local colW = math.max(200, math.floor((w - 458) / 2))
    local col1 = x + 14
    local col2 = col1 + colW + 20
    local function row(label, value, colX, yy, valueColor)
        valueColor = valueColor or theme.textDim
        self:drawText(label, colX, yy, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
        self:drawTextRight(ParadiseEconomy.fitText(tostring(value), colW - 110, UIFont.Small), colX + colW - 6, yy,
            valueColor.r, valueColor.g, valueColor.b, 1, UIFont.Small)
    end
    self:drawText(ParadiseEconomy.fitText(merchant.title or merchant.owner or merchant.id, w - 420, UIFont.Medium),
        x + 14, y + 10, theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Medium)
    self:drawRect(x + 14, y + 30, w - 28, 1, theme.borderSoft.a, theme.borderSoft.r, theme.borderSoft.g, theme.borderSoft.b)
    row("Owner", merchant.owner or "-", col1, y + 42, theme.text)
    row("Merchant ID", merchant.id or "-", col1, y + 62, theme.accent)
    row("Zone", tostring(merchant.zoneName or merchant.zoneId or "-"), col1, y + 82, theme.textDim)
    row("Lease status", lease.label, col1, y + 102, color)
    row("Lease days", tostring(merchant.leaseDays or 0), col1, y + 122, theme.textDim)
    row("Archived", merchant.archived and "Yes" or "No", col1, y + 142, merchant.archived and theme.danger or theme.green)
    row("Expires", ParadiseEconomy.formatLeaseExpiry(merchant.expiresAt), col2, y + 42, color)
    local renewed = tonumber(merchant.lastRenewedAt) or 0
    row("Last renewed", renewed > 0 and ParadiseEconomy.formatLeaseExpiry(renewed) or "-", col2, y + 62, theme.textDim)
    row("Earnings", ParadiseEconomy.formatBalances(merchant.earnings), col2, y + 82, theme.gold)
    row("Trade posts", tostring(merchant.listingCount or 0), col2, y + 102, theme.textDim)
    row("Tax route", merchant.taxRoute or "server", col2, y + 122, theme.textDim)
    local statusColor = merchant.suspended and theme.danger or (merchant.closed and theme.warn or theme.green)
    row("Status", tostring(merchant.statusLabel or "Active"), col2, y + 142, statusColor)
    if merchant.suspended then
        row("Suspended by", tostring(merchant.suspendedBy or "-"), col1, y + 162, theme.danger)
    end
end

function ParadiseEconomy.TradeManagementPanel:drawPostDetail()
    local theme = ParadiseEconomy.Theme
    local x, y = self.postDetailX, self.postDetailY
    local w, h = self.postDetailW, self.postDetailH
    ParadiseEconomy.drawCard(self, x, y, w, h, theme.accent)
    local post = self:getSelectedPost()
    if not post then
        self:drawText("Select a player post to inspect its details.", x + 14, y + 12,
            theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
        return
    end
    local lease = ParadiseEconomy.getLeaseInfo(post.merchantExpiresAt)
    local color = ParadiseEconomy.getLeaseColor(lease.status)
    local colW = math.max(200, math.floor((w - 458) / 2))
    local col1 = x + 14
    local col2 = col1 + colW + 20
    local function row(label, value, colX, yy, valueColor)
        valueColor = valueColor or theme.textDim
        self:drawText(label, colX, yy, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
        self:drawTextRight(ParadiseEconomy.fitText(tostring(value), colW - 110, UIFont.Small), colX + colW - 6, yy,
            valueColor.r, valueColor.g, valueColor.b, 1, UIFont.Small)
    end
    local name = post.itemData and post.itemData.name or post.fullType or "Item"
    self:drawText(ParadiseEconomy.fitText(name, w - 420, UIFont.Medium), x + 14, y + 10,
        theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Medium)
    local summary = post.itemData and ParadiseEconomy.ItemData.getSummary(post.itemData) or ""
    self:drawText(ParadiseEconomy.fitText(summary, w - 420, UIFont.Small), x + 14, y + 30,
        theme.textDim.r, theme.textDim.g, theme.textDim.b, 1, UIFont.Small)
    self:drawRect(x + 14, y + 48, w - 28, 1, theme.borderSoft.a, theme.borderSoft.r, theme.borderSoft.g, theme.borderSoft.b)
    row("Seller", post.seller or "-", col1, y + 58, theme.text)
    row("Merchant", post.merchantTitle or "-", col1, y + 78, theme.text)
    row("Merchant ID", post.merchantAccountId or "-", col1, y + 98, theme.accent)
    row("Merchant owner", post.merchantOwner or "-", col1, y + 118, theme.textDim)
    row("Zone", tostring(post.zoneTitle or post.zoneId or "-"), col2, y + 58, theme.textDim)
    row("Price", tostring(post.price) .. " " .. tostring(post.currency), col2, y + 78, theme.gold)
    row("Posted", ParadiseEconomy.formatTimestamp(post.createdAt), col2, y + 98, theme.textDim)
    local stateLabel = post.merchantArchived and "Archived" or (post.expired and "Expired" or lease.label)
    local stateColor = (post.merchantArchived or post.expired) and theme.danger or color
    row("Lease status", stateLabel, col2, y + 118, stateColor)
    row("Lease expires", ParadiseEconomy.formatLeaseExpiry(post.merchantExpiresAt), col2, y + 138, stateColor)
    if post.merchantArchived then
        self:drawText("Archived merchant store. This post is visible to management only.", x + 14, y + h - 20,
            theme.danger.r, theme.danger.g, theme.danger.b, 1, UIFont.Small)
    elseif post.expired then
        self:drawText("Expired posts stay visible to management only.", x + 14, y + h - 20,
            theme.danger.r, theme.danger.g, theme.danger.b, 1, UIFont.Small)
    end
end

function ParadiseEconomy.TradeManagementPanel:drawTableHeader(label1, label2, label3, label4, label5, headerY)
    local theme = ParadiseEconomy.Theme
    headerY = headerY or self.tableHeaderY or 126
    local x = self.tableX or 15
    local tableW = self.tableW or (self.width - 30)
    local columns = ParadiseEconomy.getTradeTableColumns(tableW)
    local y = headerY + 4
    self:drawText(label1, x + 8, y, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText(label2, x + columns.col2, y, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText(label3, x + columns.col3, y, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText(label4, x + columns.col4, y, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    if label5 then self:drawText(label5, x + columns.col5, y, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small) end
    self:drawTextRight("STATUS", x + tableW - 24, y, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawRect(x, headerY + 18, tableW, 1, theme.borderSoft.a, theme.borderSoft.r, theme.borderSoft.g, theme.borderSoft.b)
end

function ParadiseEconomy.TradeManagementPanel:prerender()
    ISCollapsableWindow.prerender(self)
    local theme = ParadiseEconomy.Theme
    local w = self.width
    ParadiseEconomy.drawPanelHeader(self, "TRADE ZONE ADMINISTRATION  ·  MERCHANTS, POSTS AND ITEM MART", "07")
    self:drawRect(w - 110, 64, 95, 22, 0.12, theme.green.r, theme.green.g, theme.green.b)
    self:drawRectBorder(w - 110, 64, 95, 22, theme.green.a, theme.green.r, theme.green.g, theme.green.b)
    self:drawTextCentre("MANAGED", w - 62, 68, theme.green.r, theme.green.g, theme.green.b, 1, UIFont.Small)
    local zone = self:getSelectedZone()
    if zone then
        local info = "TAX " .. string.format("%g", tonumber(zone.tradeTax) or 0) .. "%  ·  FEE "
            .. tostring(zone.merchantDailyFee or 0) .. " " .. tostring(zone.merchantFeeCurrency or "jimoleon")
            .. "/DAY  ·  OWNER  " .. tostring(zone.owner or "-")
        self:drawTextRight(ParadiseEconomy.fitText(info, w - 520, UIFont.Small), w - 120, 68,
            theme.textDim.r, theme.textDim.g, theme.textDim.b, 1, UIFont.Small)
    end
    ParadiseEconomy.drawTabUnderline(self, self.tabMerchants, self.tab == "merchants")
    ParadiseEconomy.drawTabUnderline(self, self.tabPosts, self.tab == "posts")
    ParadiseEconomy.drawTabUnderline(self, self.tabMart, self.tab == "mart")
    self:drawRect(15, 120, w - 30, 1, theme.borderSoft.a, theme.borderSoft.r, theme.borderSoft.g, theme.borderSoft.b)

    if self.tab == "merchants" then
        self:drawTableHeader("MERCHANT / OWNER", "MERCHANT ID", "LISTINGS", "LEASE END", "REVENUE")
        self:drawMerchantDetail()
        if #(self.merchantCache or {}) == 0 then
            self:drawTextCentre("No merchant stalls in this trade zone yet.", w / 2, self.merchantList:getY() + 30,
                theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
        end
    elseif self.tab == "posts" then
        self:drawTableHeader("ITEM / SELLER", "MERCHANT", "PRICE", "POSTED", "LEASE END", self.postHeaderY)
        self:drawPostDetail()
        if #(self.postCache or {}) == 0 then
            self:drawTextCentre("No player trade posts match this filter.", w / 2, self.postList:getY() + 30,
                theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
        end
    end
    self:drawRect(0, self.height - 34, self.width, 34, theme.headerBg.a, theme.headerBg.r, theme.headerBg.g, theme.headerBg.b)
    local message = ParadiseEconomy.clientState.message
    if message then
        self:drawText(ParadiseEconomy.fitText(tostring(message), self.width - 30, UIFont.Small), 15, self.height - 25,
            theme.warn.r, theme.warn.g, theme.warn.b, 1, UIFont.Small)
    end
end

function ParadiseEconomy.sync(module, command, args)
    if module ~= ParadiseEconomy.module then return end
    if not ParadiseEconomy.isEnabled() then return end
    if command == "state" then
        local state = args or {}
        state.personal = state.personal or { digital = {}, onhand = {} }
        state.accounts = state.accounts or {}
        state.merchants = state.merchants or {}
        state.ledgerRows = ParadiseEconomy.clientState.ledgerRows or {}
        state.orphanedPlayerListings = state.orphanedPlayerListings or {}
        state.shops = state.shops or {}
        state.myShops = state.myShops or {}
        state.marts = state.marts or {}
        state.shopCache = ParadiseEconomy.clientState.shopCache or {}
        state.market = state.market or { marts = {}, playerListings = {} }
        state.market.marts = state.market.marts or {}
        state.market.playerListings = state.market.playerListings or {}
        ParadiseEconomy.clientState = state
        if ParadiseEconomy.instance then ParadiseEconomy.instance:refresh() end
        if ParadiseEconomy.accountPanel then ParadiseEconomy.accountPanel:refresh(true) end
        if ParadiseEconomy.accountBrowser then ParadiseEconomy.accountBrowser:refresh() end
        if ParadiseEconomy.martInstance then ParadiseEconomy.martInstance:refreshMarket() end
        if ParadiseEconomy.tradeManagementInstance then ParadiseEconomy.tradeManagementInstance:refreshState() end
        if ParadiseEconomy.adminInstance then ParadiseEconomy.adminInstance:refresh() end
        if ParadiseEconomy.tablesPanel then ParadiseEconomy.tablesPanel:refresh() end
        ParadiseEconomy.handlePurchaseResult(state.purchase)
        if state.shopRequest then
            ParadiseEconomy.openShop(state.shopRequest.kind, state.shopRequest.id)
        end
    elseif command == "shopState" then
        args = args or {}
        local key = tostring(args.kind or "") .. ":" .. tostring(args.id or "")
        ParadiseEconomy.clientState.shopCache = ParadiseEconomy.clientState.shopCache or {}
        ParadiseEconomy.clientState.shopCache[key] = args.shop
        ParadiseEconomy.clientState.shop = args.shop
        if args.message then ParadiseEconomy.clientState.message = args.message end
        if ParadiseEconomy.martInstance then
            ParadiseEconomy.martInstance:applyShopState(args.kind, args.id, args.shop, args.message)
        end
    elseif command == "ledgerMine" then
        ParadiseEconomy.clientState.ledgerRows = args and args.rows or {}
        if ParadiseEconomy.instance then ParadiseEconomy.instance:refresh(true) end
        if ParadiseEconomy.accountPanel then ParadiseEconomy.accountPanel:refresh(true) end
    elseif command == "ledgerDays" then
        if ParadiseEconomy.ledgerPanel then ParadiseEconomy.ledgerPanel:applyDays(args) end
    elseif command == "ledgerPage" then
        if ParadiseEconomy.ledgerPanel then ParadiseEconomy.ledgerPanel:applyPage(args) end
    elseif command == "say" then
        local pl = getPlayer()
        if pl and args and args.message then pl:Say(args.message) end
    end
end
Events.OnServerCommand.Remove(ParadiseEconomy.sync)
Events.OnServerCommand.Add(ParadiseEconomy.sync)

function ParadiseEconomy.sendPillage(item)
    ParadiseEconomy.send("pillage", { itemId = item:getID() })
end

function ParadiseEconomy.pillage(item, pl)
    pl = pl or getPlayer()
    if not pl or not item then return end
    if item:getContainer() == pl:getInventory() then
        ParadiseEconomy.sendPillage(item)
        return
    end
    local act = ISInventoryTransferAction:new(pl, item, item:getContainer(), pl:getInventory())
    act:setOnComplete(ParadiseEconomy.sendPillage, item)
    ISTimedActionQueue.add(act)
end

function ParadiseEconomy.fillInventoryContext(plNum, context, items)
    if not ParadiseEconomy.isEnabled() then return end
    local pl = getSpecificPlayer(plNum)
    if not pl or not ParadiseEconomy.canUsePlayerEconomy(pl) then return end
    local store = ParadiseEconomy.getActivePlayerMerchantStore(pl)
    for _, selected in ipairs(items or {}) do
        local item = selected.items and selected.items[1] or selected
        if ParadiseEconomy.isWallet(item) then
            local wallet = ParadiseEconomy.getWalletData(item)
            if ParadiseEconomy.hasMoney(wallet) then
                context:addOption("Pillage " .. ParadiseEconomy.formatBalances(wallet), item, ParadiseEconomy.pillage, pl)
            end
        end
        if store and item and item.getContainer and item:getContainer() == pl:getInventory() then
            context:addOption("Post in " .. tostring(store.title or "Merchant Store"), item,
                ParadiseEconomy.openListingPanel, nil, store.id)
            return
        end
    end
end
Events.OnFillInventoryObjectContextMenu.Remove(ParadiseEconomy.fillInventoryContext)
Events.OnFillInventoryObjectContextMenu.Add(ParadiseEconomy.fillInventoryContext)

function ParadiseEconomy.ListingPanel:new(x, y, item, onClose, merchantId)
    local obj = ISCollapsableWindow.new(self, x, y, 560, 390)
    obj.title = "Post Listing"
    obj.resizable = false
    obj.item = item
    obj.itemData = item and ParadiseEconomy.ItemData.toData(item) or nil
    obj.onCloseCallback = onClose
    obj.merchantId = merchantId
    obj.closed = false
    return obj
end

function ParadiseEconomy.ListingPanel:createChildren()
    ISCollapsableWindow.createChildren(self)
    self.currency = ISComboBox:new(15, 158, 160, 26, self)
    self.currency.tooltip = "Currency the buyer pays in"
    self.currency:initialise()
    self.currency:addOption("jimoleon")
    self.currency:addOption("paradisium")
    self:addChild(self.currency)
    self.price = ISTextEntryBox:new("", 185, 158, 160, 26)
    self.price.tooltip = "Asking price for this item"
    self.price:initialise()
    self.price:instantiate()
    self.price:setOnlyNumbers(true)
    self.price:setPlaceholderText("0")
    self:addChild(self.price)
    self.cancelButton = ISButton:new(self.width - 375, self.height - 46, 150, 30, "CANCEL", self, ParadiseEconomy.ListingPanel.close)
    self.cancelButton:initialise()
    self:addChild(self.cancelButton)
    self.postButton = ISButton:new(self.width - 215, self.height - 46, 200, 30, "POST LISTING", self, ParadiseEconomy.ListingPanel.post)
    self.postButton.tooltip = "Create this trade post in your merchant stall"
    self.postButton:initialise()
    self:addChild(self.postButton)
    ParadiseEconomy.styleWindow(self)
    ParadiseEconomy.styleTree(self)
    local theme = ParadiseEconomy.Theme
    self.postButton.backgroundColor = theme.gold
    self.postButton.backgroundColorMouseOver = { r = 1.0, g = 0.86, b = 0.45, a = 1.0 }
    self.postButton.textColor = { r = 0.05, g = 0.06, b = 0.07, a = 1.0 }
end

function ParadiseEconomy.ListingPanel:getMerchant()
    if not self.merchantId then return nil end
    for _, merchant in ipairs(ParadiseEconomy.clientState.merchants or {}) do
        if tostring(merchant.id) == tostring(self.merchantId) then return merchant end
    end
    return nil
end

function ParadiseEconomy.ListingPanel:getLeaseWarning()
    local merchant = self:getMerchant()
    if merchant then
        if merchant.closed then
            return "This merchant store is " .. tostring(merchant.statusLabel or "closed")
                .. ". Posting is disabled until the store reopens."
        end
        local _, status = ParadiseEconomy.getLeaseInfo(merchant.expiresAt)
        if status == "expired" then
            return "Your merchant lease has expired. Renew it before posting."
        end
        return nil
    end
    local market = ParadiseEconomy.clientState.market or {}
    local zoneId = market.tradeZoneId
    for _, other in ipairs(ParadiseEconomy.clientState.merchants or {}) do
        if other.zoneId == zoneId and other.leaseStatus == "expired" then
            return "Your merchant lease has expired. Renew it in Tradeshop > My Store before posting."
        end
    end
    return nil
end

function ParadiseEconomy.ListingPanel:getTaxPercent()
    local merchant = self:getMerchant()
    if merchant then
        if merchant.taxPercent then return tonumber(merchant.taxPercent) or 0 end
        return ParadiseEconomy.getTradeTaxPercentFor(merchant.zoneId)
    end
    local market = ParadiseEconomy.clientState.market or {}
    local trade = ParadiseEconomy.getActiveTrade()
    return trade and trade.tradeTax or ParadiseEconomy.getTradeTaxPercentFor(market.tradeZoneId)
end

function ParadiseEconomy.ListingPanel:getCurrency()
    return self.currency.options[self.currency.selected] or "jimoleon"
end

function ParadiseEconomy.ListingPanel:prerender()
    ISCollapsableWindow.prerender(self)
    local theme = ParadiseEconomy.Theme
    local w = self.width
    ParadiseEconomy.drawPanelHeader(self, "POST LISTING  ·  PRICE A CARRIED ITEM FOR YOUR MERCHANT STALL", "05")

    local data = self.itemData or {}
    local name = tostring(data.name or (self.item and self.item:getDisplayName()) or "Item")
    local tint = ParadiseEconomy.getCategoryColor(data.category)
    ParadiseEconomy.drawCard(self, 15, 66, w - 30, 64, tint)
    self:drawRect(25, 74, 48, 48, 0.22, tint.r, tint.g, tint.b)
    self:drawRectBorder(25, 74, 48, 48, 0.55, tint.r, tint.g, tint.b)
    self:drawTextCentre(ParadiseEconomy.getItemInitials(name), 49, 90, tint.r, tint.g, tint.b, 0.95, UIFont.Medium)
    self:drawText(ParadiseEconomy.fitText(name, w - 220, UIFont.Medium), 85, 76,
        theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Medium)
    local summary = ParadiseEconomy.ItemData.getSummary(data)
    local detail = tostring(data.fullType or "Item")
    if summary and summary ~= "" then detail = detail .. "  ·  " .. summary end
    self:drawText(ParadiseEconomy.fitText(detail, w - 220, UIFont.Small), 85, 100,
        theme.textDim.r, theme.textDim.g, theme.textDim.b, 1, UIFont.Small)
    self:drawTextRight("YOUR ITEM", w - 29, 78, theme.accent.r, theme.accent.g, theme.accent.b, 1, UIFont.Small)

    self:drawText("CURRENCY", 15, 142, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText("ASKING PRICE", 185, 142, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)

    ParadiseEconomy.drawCard(self, 15, 196, w - 30, 104, theme.gold)
    local percent = self:getTaxPercent()
    local amount = tonumber(self.price:getInternalText()) or 0
    local payout, tax = ParadiseEconomy.getPlayerShopPayout(amount, percent)
    local currency = self:getCurrency()
    local icon = currency == "paradisium" and ParadiseEconomy.icons.paradisium or ParadiseEconomy.icons.jimoleon
    local function summaryRow(label, value, yy, color)
        self:drawText(label, 29, yy, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
        local valueW = getTextManager():MeasureStringX(UIFont.Small, value)
        if icon then self:drawTextureScaled(icon, w - 49 - valueW - 14, yy - 1, 14, 14, 1) end
        self:drawTextRight(value, w - 29, yy, color.r, color.g, color.b, 1, UIFont.Small)
    end
    summaryRow("LISTING PRICE", amount > 0 and ParadiseEconomy.formatNumber(amount) or "-", 210, theme.text)
    summaryRow("ZONE TAX (" .. string.format("%g", percent or 0) .. "%)",
        tax and ParadiseEconomy.formatNumber(tax) or "-", 234, theme.warn)
    self:drawRect(29, 256, w - 58, 1, theme.borderSoft.a, theme.borderSoft.r, theme.borderSoft.g, theme.borderSoft.b)
    summaryRow("EST. PAYOUT", payout and ParadiseEconomy.formatNumber(payout) or "-", 268, theme.green)

    local warning = self:getLeaseWarning()
    if warning then
        self:drawText(ParadiseEconomy.fitText(warning, w - 30, UIFont.Small), 15, 312,
            theme.warn.r, theme.warn.g, theme.warn.b, 1, UIFont.Small)
    end
end

function ParadiseEconomy.ListingPanel:update()
    ISCollapsableWindow.update(self)
    if not ParadiseEconomy.canUsePlayerEconomy(getPlayer()) then self:close() end
    self.postButton:setEnable((tonumber(self.price:getInternalText()) or 0) > 0 and self:getLeaseWarning() == nil)
end

function ParadiseEconomy.ListingPanel:post()
    if not self.item or not ParadiseEconomy.canUsePlayerEconomy(getPlayer()) then
        self:close(false)
        return
    end
    ParadiseEconomy.send("playerShopPost", {
        itemId = self.item:getID(),
        currency = self.currency.options[self.currency.selected],
        amount = self.price:getInternalText(),
        merchantId = self.merchantId,
    })
    self:close(true)
end

function ParadiseEconomy.ListingPanel:close(posted)
    if self.closed then return end
    self.closed = true
    if ParadiseEconomy.listingInstance == self then ParadiseEconomy.listingInstance = nil end
    self:setVisible(false)
    self:removeFromUIManager()
    local callback = self.onCloseCallback
    if callback and not self.suppressCloseCallback then callback(self, posted == true) end
end

function ParadiseEconomy.openListingPanel(item, onClose, merchantId)
    if not item or not ParadiseEconomy.canUsePlayerEconomy(getPlayer()) then return end
    if ParadiseEconomy.listingInstance then
        ParadiseEconomy.listingInstance.suppressCloseCallback = true
        ParadiseEconomy.listingInstance:close()
    end
    local panel = ParadiseEconomy.ListingPanel:new(
        (getCore():getScreenWidth() - 560) / 2,
        (getCore():getScreenHeight() - 390) / 2,
        item, onClose, merchantId)
    panel:initialise()
    panel:addToUIManager()
    ParadiseEconomy.listingInstance = panel
end

function ParadiseEconomy.PurchasePanel:new(x, y, listing, destination)
    local obj = ISCollapsableWindow.new(self, x, y, 470, 320)
    obj.title = "Confirm Purchase"
    obj.resizable = false
    obj.listing = listing
    obj.listingId = listing.id
    obj.destination = destination or { kind = "player", label = "your inventory" }
    obj.itemName = listing.itemData and listing.itemData.name or listing.fullType or "Item"
    obj.itemSummary = listing.itemData and ParadiseEconomy.ItemData.getSummary(listing.itemData) or ""
    obj.currency = listing.currency
    obj.price = tonumber(listing.price) or 0
    obj.taxPercent = tonumber(listing.taxPercent) or ParadiseEconomy.getTradeTaxPercentFor(listing.zoneId) or 0
    local _, tax = ParadiseEconomy.getPlayerShopPayout(obj.price, obj.taxPercent)
    obj.tax = tax or 0
    obj.total = obj.price
    obj.seller = listing.seller or "-"
    obj.store = listing.merchantTitle or listing.merchantAccountId or "-"
    obj.status = nil
    obj.statusColor = ParadiseEconomy.Theme.text
    obj.busy = false
    obj.done = false
    obj.closed = false
    return obj
end

function ParadiseEconomy.PurchasePanel:createChildren()
    ISCollapsableWindow.createChildren(self)
    self.purchaseButton = ISButton:new(15, self.height - 46, 210, 30, "Purchase", self, ParadiseEconomy.PurchasePanel.onPurchase)
    self.purchaseButton:initialise()
    self:addChild(self.purchaseButton)
    self.cancelButton = ISButton:new(235, self.height - 46, 200, 30, "Cancel", self, ParadiseEconomy.PurchasePanel.close)
    self.cancelButton:initialise()
    self:addChild(self.cancelButton)
    ParadiseEconomy.styleWindow(self)
    ParadiseEconomy.styleTree(self)
end

function ParadiseEconomy.PurchasePanel:setStatus(text, color)
    self.status = text
    self.statusColor = color or ParadiseEconomy.Theme.text
end

function ParadiseEconomy.PurchasePanel:onPurchase()
    if self.done then
        self:close()
        return
    end
    if self.busy then return end
    local personal = ParadiseEconomy.getStatePersonal()
    local onhand = ParadiseEconomy.getBalance(personal.onhand, self.currency)
    if onhand < self.total then
        self:setStatus("Not enough " .. tostring(self.currency) .. " on hand. Need " .. tostring(self.total)
            .. ", have " .. tostring(onhand) .. ".", ParadiseEconomy.Theme.danger)
        return
    end
    self.busy = true
    self.purchaseButton:setEnable(false)
    self:setStatus("Purchasing...", ParadiseEconomy.Theme.textDim)
    local dest = self.destination or {}
    ParadiseEconomy.send("playerShopBuy", {
        listingId = self.listingId,
        source = "drag",
        destKind = dest.kind,
        destItemId = dest.itemId,
        destX = dest.x,
        destY = dest.y,
        destZ = dest.z,
        destIndex = dest.index,
        destContainerIndex = dest.containerIndex,
    })
end

function ParadiseEconomy.PurchasePanel:applyResult(result)
    self.busy = false
    self.purchaseButton:setEnable(true)
    if result.ok then
        self.done = true
        self.purchaseButton:setTitle("Close")
        self:setStatus("Success! " .. tostring(result.itemName or self.itemName) .. " was sent to "
            .. tostring(result.destination or self.destination.label or "your inventory") .. ".", ParadiseEconomy.Theme.green)
    else
        self:setStatus(tostring(result.message or "Purchase failed."), ParadiseEconomy.Theme.danger)
    end
end

function ParadiseEconomy.PurchasePanel:update()
    ISCollapsableWindow.update(self)
    if not ParadiseEconomy.canOpenMart(getPlayer()) then self:close() end
end

function ParadiseEconomy.PurchasePanel:close()
    if self.closed then return end
    self.closed = true
    if ParadiseEconomy.purchaseInstance == self then ParadiseEconomy.purchaseInstance = nil end
    self:setVisible(false)
    self:removeFromUIManager()
end

function ParadiseEconomy.PurchasePanel:prerender()
    ISCollapsableWindow.prerender(self)
    local theme = ParadiseEconomy.Theme
    local x = 15
    self:drawText(ParadiseEconomy.fitText(tostring(self.itemName), self.width - 30, UIFont.Medium), x, 32,
        theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Medium)
    self:drawText(ParadiseEconomy.fitText(tostring(self.itemSummary), self.width - 30, UIFont.Small), x, 54,
        theme.textDim.r, theme.textDim.g, theme.textDim.b, 1, UIFont.Small)
    ParadiseEconomy.drawCard(self, 15, 76, self.width - 30, 174, theme.accentDim)
    local function row(label, value, yy, color)
        color = color or theme.textDim
        self:drawText(label, 28, yy, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
        self:drawTextRight(ParadiseEconomy.fitText(tostring(value), self.width - 150, UIFont.Small), self.width - 28, yy,
            color.r, color.g, color.b, 1, UIFont.Small)
    end
    row("Price", tostring(self.price) .. " " .. tostring(self.currency), 88, theme.gold)
    row(string.format("Sales tax (%g%%)", self.taxPercent or 0), tostring(self.tax) .. " " .. tostring(self.currency), 108, theme.warn)
    row("Total to pay", tostring(self.total) .. " " .. tostring(self.currency), 128, theme.text)
    local personal = ParadiseEconomy.getStatePersonal()
    local onhand = ParadiseEconomy.getBalance(personal.onhand, self.currency)
    row("On hand", tostring(onhand) .. " " .. tostring(self.currency), 148, onhand >= self.total and theme.green or theme.danger)
    row("Destination", self.destination and self.destination.label or "your inventory", 168, theme.accent)
    row("Seller", tostring(self.seller) .. "  |  " .. tostring(self.store), 188, theme.textDim)
    self:drawText("Tax is deducted from the seller payout.", x, 214,
        theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText("Pay from your on-hand balance. The item is delivered to the drop destination.", x, 232,
        theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    if self.status then
        self:drawText(ParadiseEconomy.fitText(tostring(self.status), self.width - 30, UIFont.Small), x, self.height - 68,
            self.statusColor.r, self.statusColor.g, self.statusColor.b, 1, UIFont.Small)
    end
end

function ParadiseEconomy.openPurchasePanel(listing, destination)
    if not listing or not ParadiseEconomy.canOpenMart(getPlayer()) then return end
    if ParadiseEconomy.purchaseInstance then ParadiseEconomy.purchaseInstance:close() end
    local panel = ParadiseEconomy.PurchasePanel:new(
        (getCore():getScreenWidth() - 470) / 2,
        (getCore():getScreenHeight() - 320) / 2,
        listing, destination)
    panel:initialise()
    panel:addToUIManager()
    panel:bringToTop()
    ParadiseEconomy.purchaseInstance = panel
    return panel
end

function ParadiseEconomy.handlePurchaseResult(result)
    if not result then return end
    local panel = ParadiseEconomy.purchaseInstance
    if panel and tostring(panel.listingId) == tostring(result.listingId) then panel:applyResult(result) end
end

function ParadiseEconomy.AdminPanel:new(x, y, w, h, targetUser)
    local obj = ISCollapsableWindow.new(self, x, y, w, h)
    obj.title = "Economy Administration"
    obj.resizable = true
    obj.minimumWidth = 900
    obj.minimumHeight = 640
    obj.targetUsername = ParadiseEconomy.normalizeUsername(targetUser)
    obj.selectedAccountId = nil
    obj.destAccountId = nil
    obj.accountMap = {}
    obj.pendingMessage = nil
    obj.createOpen = false
    obj.lastWidth = 0
    obj.lastHeight = 0
    return obj
end

function ParadiseEconomy.AdminPanel:createChildren()
    ISCollapsableWindow.createChildren(self)

    self.typeFilter = ISComboBox:new(15, 66, 190, 26, self, ParadiseEconomy.AdminPanel.refresh)
    self.typeFilter:initialise()
    for _, entry in ipairs(ParadiseEconomy.accountFilterTypes) do
        local label = entry.label .. " accounts"
        if entry.key == "all" then label = "All account types" end
        if entry.key == "custom" then label = "Custom accounts" end
        self.typeFilter:addOption(label)
    end
    self:addChild(self.typeFilter)

    self.search = ISTextEntryBox:new("", 213, 66, 300, 26)
    self.search.target = self
    self.search.onTextChangeFunction = ParadiseEconomy.AdminPanel.onSearchChanged
    self.search:initialise()
    self.search:instantiate()
    self.search:setPlaceholderText("Search accounts...")
    self:addChild(self.search)

    self.createButton = ISButton:new(500, 66, 150, 26, "CREATE ACCOUNT", self, ParadiseEconomy.AdminPanel.toggleCreate)
    self.createButton.tooltip = "Admin only: create personal, merchant, trade or custom accounts."
    self.createButton:initialise()
    self:addChild(self.createButton)

    self.newType = ISComboBox:new(27, 124, 120, 24, self)
    self.newType:initialise()
    for _, entry in ipairs(ParadiseEconomy.accountCreateTypes) do self.newType:addOption(entry.label) end
    self:addChild(self.newType)
    self.newOwner = ISTextEntryBox:new("", 155, 124, 150, 24)
    self.newOwner.tooltip = "Owner username for personal / merchant accounts"
    self.newOwner:initialise()
    self.newOwner:instantiate()
    self.newOwner:setPlaceholderText("Owner username...")
    self:addChild(self.newOwner)
    self.newZone = ISComboBox:new(313, 124, 200, 24, self)
    self.newZone:setToolTipMap({ defaultTooltip = "Trade zone for merchant / trade accounts" })
    self.newZone:initialise()
    self:addChild(self.newZone)
    self.newName = ISTextEntryBox:new("", 27, 154, 200, 24)
    self.newName.tooltip = "Display name for custom accounts"
    self.newName:initialise()
    self.newName:instantiate()
    self.newName:setPlaceholderText("Custom account name...")
    self:addChild(self.newName)
    self.createConfirmButton = ISButton:new(0, 154, 90, 24, "CREATE", self, ParadiseEconomy.AdminPanel.createAccount)
    self.createConfirmButton:initialise()
    self:addChild(self.createConfirmButton)
    self.createCancelButton = ISButton:new(0, 154, 80, 24, "CANCEL", self, ParadiseEconomy.AdminPanel.closeCreate)
    self.createCancelButton:initialise()
    self:addChild(self.createCancelButton)

    self.accounts = ISScrollingListBox:new(15, 128, 600, 300)
    self.accounts:initialise()
    self.accounts.itemheight = 48
    self.accounts.font = UIFont.Small
    self.accounts.doDrawItem = ParadiseEconomy.AdminPanel.drawAccount
    self.accounts:setOnMouseDownFunction(self, ParadiseEconomy.AdminPanel.selectAccount)
    self.accounts:setOnMouseDoubleClick(self, ParadiseEconomy.AdminPanel.onAccountDoubleClick)
    self:addChild(self.accounts)

    self.tablesButton = ISButton:new(0, 74, 64, 20, "TABLES", self, ParadiseEconomy.AdminPanel.openTables)
    self.tablesButton:initialise()
    self:addChild(self.tablesButton)
    self.ledgerButton = ISButton:new(0, 74, 64, 20, "LEDGER", self, ParadiseEconomy.AdminPanel.openLedger)
    self.ledgerButton:initialise()
    self:addChild(self.ledgerButton)
    self.serverButton = ISButton:new(0, 74, 64, 20, "SERVER", self, ParadiseEconomy.AdminPanel.selectServer)
    self.serverButton:initialise()
    self:addChild(self.serverButton)
    self.freezeButton = ISButton:new(0, 74, 76, 20, "FREEZE", self, ParadiseEconomy.AdminPanel.toggleFreeze)
    self.freezeButton.tooltip = "Admin only: freeze or unfreeze the selected personal account"
    self.freezeButton:initialise()
    self:addChild(self.freezeButton)

    self.operation = ISComboBox:new(0, 0, 200, 24, self)
    self.operation:initialise()
    self.operation:addOption("Add funds")
    self.operation:addOption("Remove funds")
    self.operation:addOption("Set balance")
    self:addChild(self.operation)

    self.bucket = ISComboBox:new(0, 0, 100, 24, self)
    self.bucket:initialise()
    self:addChild(self.bucket)
    self.currency = ISComboBox:new(0, 0, 100, 24, self)
    self.currency:initialise()
    self.currency:addOption("jimoleon")
    self.currency:addOption("paradisium")
    self:addChild(self.currency)
    self.amount = ISTextEntryBox:new("", 0, 0, 150, 24)
    self.amount:initialise()
    self.amount:instantiate()
    self.amount:setOnlyNumbers(true)
    self.amount:setPlaceholderText("Amount")
    self:addChild(self.amount)
    self.applyButton = ISButton:new(0, 0, 200, 26, "APPLY OPERATION", self, ParadiseEconomy.AdminPanel.applyOperation)
    self.applyButton.tooltip = "Admin only: add, remove or set the selected account balance."
    self.applyButton:initialise()
    self:addChild(self.applyButton)

    self.destAccount = ISComboBox:new(0, 0, 300, 24, self, ParadiseEconomy.AdminPanel.onDestChanged)
    self.destAccount:initialise()
    self:addChild(self.destAccount)
    self.fromBucket = ISComboBox:new(0, 0, 90, 24, self)
    self.fromBucket:initialise()
    self:addChild(self.fromBucket)
    self.toBucket = ISComboBox:new(0, 0, 90, 24, self)
    self.toBucket:initialise()
    self:addChild(self.toBucket)
    self.rerouteAmount = ISTextEntryBox:new("", 0, 0, 90, 24)
    self.rerouteAmount:initialise()
    self.rerouteAmount:instantiate()
    self.rerouteAmount:setOnlyNumbers(true)
    self.rerouteAmount:setPlaceholderText("Amount")
    self:addChild(self.rerouteAmount)
    self.rerouteButton = ISButton:new(0, 0, 300, 26, "REROUTE ACCOUNT", self, ParadiseEconomy.AdminPanel.reroute)
    self.rerouteButton.tooltip = "Admin only: move funds from this account to another account."
    self.rerouteButton:initialise()
    self:addChild(self.rerouteButton)

    self.taxRoute = ISTextEntryBox:new("", 0, 0, 200, 24)
    self.taxRoute.tooltip = "Tax route account ID for the selected merchant account"
    self.taxRoute:initialise()
    self.taxRoute:instantiate()
    self.taxRoute:setPlaceholderText("Account ID...")
    self:addChild(self.taxRoute)
    self.taxRouteButton = ISButton:new(0, 0, 70, 24, "SET", self, ParadiseEconomy.AdminPanel.setTaxRoute)
    self.taxRouteButton.tooltip = "Admin only: set this merchant's tax route account."
    self.taxRouteButton:initialise()
    self:addChild(self.taxRouteButton)

    self.syncButton = ISButton:new(0, 0, 118, 28, "SYNC ZONES", self, ParadiseEconomy.AdminPanel.syncZones)
    self.syncButton:initialise()
    self:addChild(self.syncButton)
    self.rebuildButton = ISButton:new(0, 0, 118, 28, "REBUILD INDEX", self, ParadiseEconomy.AdminPanel.rebuildIndex)
    self.rebuildButton:initialise()
    self:addChild(self.rebuildButton)
    self.purgeButton = ISButton:new(0, 0, 118, 28, "PURGE LEDGER", self, ParadiseEconomy.AdminPanel.purgeLedger)
    self.purgeButton:initialise()
    self:addChild(self.purgeButton)
    self.deleteButton = ISButton:new(0, 0, 118, 28, "DELETE ACCOUNT", self, ParadiseEconomy.AdminPanel.deleteAccount)
    self.deleteButton:initialise()
    self:addChild(self.deleteButton)

    ParadiseEconomy.styleWindow(self)
    ParadiseEconomy.styleTree(self)
    self.accounts.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    self.accounts.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    local theme = ParadiseEconomy.Theme
    self.createButton.borderColor = theme.gold
    self.rerouteButton.borderColor = theme.gold
    self.taxRouteButton.borderColor = theme.gold
    self.applyButton.backgroundColor = theme.gold
    self.applyButton.backgroundColorMouseOver = { r = 0.99, g = 0.86, b = 0.45, a = 1 }
    self.applyButton.textColor = { r = 0.06, g = 0.07, b = 0.08, a = 1 }
    self.applyButton.borderColor = theme.gold
    self.createConfirmButton.borderColor = theme.accent
    self.createConfirmButton.textColor = theme.text
    self.purgeButton.borderColor = theme.danger
    self.purgeButton.textColor = theme.danger
    self.deleteButton.borderColor = theme.danger
    self.deleteButton.textColor = theme.danger
    self:setCreateOpen(false)
    self:refresh()
end

function ParadiseEconomy.AdminPanel:layout()
    if not self.accounts then return end
    local w, h = self.width, self.height
    local rightW = math.max(300, math.min(360, math.floor(w * 0.30)))
    local leftW = w - 30 - rightW - 14
    self.leftX, self.leftW = 15, leftW
    self.rightX, self.rightW = 15 + leftW + 14, rightW

    local toolbarY = 66
    self.toolbarY = toolbarY
    local filterW = 190
    local createW = 150
    self.createX = 15 + leftW - createW
    self.typeFilter:setX(15)
    self.typeFilter:setY(toolbarY)
    self.typeFilter:setWidth(filterW)
    self.typeFilter:setHeight(26)
    self.createButton:setX(self.createX)
    self.createButton:setY(toolbarY)
    self.createButton:setWidth(createW)
    self.createButton:setHeight(26)
    self.search:setX(15 + filterW + 8)
    self.search:setY(toolbarY)
    self.search:setWidth(math.max(120, self.createX - 8 - (15 + filterW + 8)))
    self.search:setHeight(26)

    local createY = 100
    self.createRowY = createY
    self.createRowH = 88
    local innerX = 27
    local innerW = leftW - 24
    local typeW, ownerW, confirmW, cancelW = 120, 150, 90, 80
    self.newType:setX(innerX)
    self.newType:setY(createY + 24)
    self.newType:setWidth(typeW)
    self.newType:setHeight(24)
    self.newOwner:setX(innerX + typeW + 8)
    self.newOwner:setY(createY + 24)
    self.newOwner:setWidth(ownerW)
    self.newOwner:setHeight(24)
    self.newZone:setX(innerX + typeW + ownerW + 16)
    self.newZone:setY(createY + 24)
    self.newZone:setWidth(math.max(100, innerW - typeW - ownerW - 16))
    self.newZone:setHeight(24)
    self.newName:setX(innerX)
    self.newName:setY(createY + 54)
    self.newName:setWidth(math.max(100, innerW - confirmW - cancelW - 16))
    self.newName:setHeight(24)
    self.createCancelButton:setX(innerX + innerW - cancelW)
    self.createCancelButton:setY(createY + 54)
    self.createCancelButton:setWidth(cancelW)
    self.createCancelButton:setHeight(24)
    self.createConfirmButton:setX(innerX + innerW - cancelW - 8 - confirmW)
    self.createConfirmButton:setY(createY + 54)
    self.createConfirmButton:setWidth(confirmW)
    self.createConfirmButton:setHeight(24)

    local listHeaderY = self.createOpen and (createY + self.createRowH + 12) or 104
    self.listHeaderY = listHeaderY
    self.listY = listHeaderY + 24
    local maintenanceH = 86
    self.maintenanceY = h - 8 - maintenanceH
    self.maintenanceH = maintenanceH
    local listH = math.max(120, self.maintenanceY - 12 - self.listY)
    self.listH = listH
    self.accounts:setX(15)
    self.accounts:setY(self.listY)
    self.accounts:setWidth(leftW)
    self.accounts:setHeight(listH)

    local idW = math.max(90, math.floor(leftW * 0.17))
    local ownerColW = math.max(120, math.floor(leftW * 0.34))
    self.rowIdX = 12
    self.rowOwnerX = 12 + idW
    self.rowTypeX = 12 + idW + ownerColW
    self.rowPRight = leftW - 14
    self.rowJRight = self.rowPRight - math.max(100, math.floor(leftW * 0.17))

    local cardX = self.rightX
    local cardY = 66
    local cardH = self.maintenanceY - 12 - cardY
    self.detailX, self.detailY, self.detailW, self.detailH = cardX, cardY, rightW, cardH
    local detailInnerX = cardX + 14
    local detailInnerW = rightW - 28
    self.detailInnerX, self.detailInnerW = detailInnerX, detailInnerW
    self.detailLabelY = cardY + 14
    self.detailTitleY = cardY + 32
    self.detailMetaY = cardY + 54
    self.balanceLabelY = cardY + 74
    self.balancePitch = 48
    self.balanceBoxH = 27
    local fieldW = math.floor((detailInnerW - 10) / 2)
    self.fieldW = fieldW
    self.fieldCol2X = detailInnerX + fieldW + 10
    self.opLabelY = cardY + 168
    self.opComboY = cardY + 182
    self.bucketRowY = cardY + 212
    self.amountLabelY = cardY + 240
    self.amountY = cardY + 252
    self.applyY = cardY + 282
    self.routeDividerY = cardY + 314
    self.routeLabelY = cardY + 318
    self.destY = cardY + 330
    self.routeRowY = cardY + 360
    self.rerouteY = cardY + 392
    self.taxLabelY = cardY + 424
    self.taxRowY = cardY + 436

    local routeColW = math.floor((detailInnerW - 16) / 3)
    self.routeColW = routeColW
    self.operation:setX(detailInnerX)
    self.operation:setY(self.opComboY)
    self.operation:setWidth(detailInnerW)
    self.operation:setHeight(24)
    self.bucket:setX(detailInnerX)
    self.bucket:setY(self.bucketRowY)
    self.bucket:setWidth(fieldW)
    self.bucket:setHeight(24)
    self.currency:setX(self.fieldCol2X)
    self.currency:setY(self.bucketRowY)
    self.currency:setWidth(fieldW)
    self.currency:setHeight(24)
    self.amount:setX(detailInnerX)
    self.amount:setY(self.amountY)
    self.amount:setWidth(detailInnerW)
    self.amount:setHeight(24)
    self.applyButton:setX(detailInnerX)
    self.applyButton:setY(self.applyY)
    self.applyButton:setWidth(detailInnerW)
    self.applyButton:setHeight(26)
    self.destAccount:setX(detailInnerX)
    self.destAccount:setY(self.destY)
    self.destAccount:setWidth(detailInnerW)
    self.destAccount:setHeight(24)
    self.fromBucket:setX(detailInnerX)
    self.fromBucket:setY(self.routeRowY)
    self.fromBucket:setWidth(routeColW)
    self.fromBucket:setHeight(24)
    self.toBucket:setX(detailInnerX + routeColW + 8)
    self.toBucket:setY(self.routeRowY)
    self.toBucket:setWidth(routeColW)
    self.toBucket:setHeight(24)
    self.rerouteAmount:setX(detailInnerX + 2 * (routeColW + 8))
    self.rerouteAmount:setY(self.routeRowY)
    self.rerouteAmount:setWidth(math.max(60, detailInnerW - 2 * (routeColW + 8)))
    self.rerouteAmount:setHeight(24)
    self.rerouteButton:setX(detailInnerX)
    self.rerouteButton:setY(self.rerouteY)
    self.rerouteButton:setWidth(detailInnerW)
    self.rerouteButton:setHeight(26)
    self.taxRoute:setX(detailInnerX)
    self.taxRoute:setY(self.taxRowY)
    self.taxRoute:setWidth(math.max(100, detailInnerW - 78))
    self.taxRoute:setHeight(24)
    self.taxRouteButton:setX(detailInnerX + detailInnerW - 70)
    self.taxRouteButton:setY(self.taxRowY)
    self.taxRouteButton:setWidth(70)
    self.taxRouteButton:setHeight(24)

    self.tablesButton:setX(cardX + rightW - 14 - 64)
    self.tablesButton:setY(cardY + 8)
    self.tablesButton:setWidth(64)
    self.tablesButton:setHeight(20)
    self.serverButton:setX(cardX + rightW - 14 - 64 - 6 - 64)
    self.serverButton:setY(cardY + 8)
    self.serverButton:setWidth(64)
    self.serverButton:setHeight(20)
    self.ledgerButton:setX(cardX + rightW - 14 - 64 - 6 - 64 - 6 - 64)
    self.ledgerButton:setY(cardY + 8)
    self.ledgerButton:setWidth(64)
    self.ledgerButton:setHeight(20)
    self.freezeButton:setX(detailInnerX)
    self.freezeButton:setY(self.taxRowY)
    self.freezeButton:setWidth(detailInnerW)
    self.freezeButton:setHeight(26)

    local buttonW, gap = 118, 8
    local buttonX = w - 15 - buttonW
    local buttonY = self.maintenanceY + 29
    self.deleteButton:setX(buttonX)
    self.deleteButton:setY(buttonY)
    self.deleteButton:setWidth(buttonW)
    self.deleteButton:setHeight(28)
    buttonX = buttonX - gap - buttonW
    self.purgeButton:setX(buttonX)
    self.purgeButton:setY(buttonY)
    self.purgeButton:setWidth(buttonW)
    self.purgeButton:setHeight(28)
    buttonX = buttonX - gap - buttonW
    self.rebuildButton:setX(buttonX)
    self.rebuildButton:setY(buttonY)
    self.rebuildButton:setWidth(buttonW)
    self.rebuildButton:setHeight(28)
    buttonX = buttonX - gap - buttonW
    self.syncButton:setX(buttonX)
    self.syncButton:setY(buttonY)
    self.syncButton:setWidth(buttonW)
    self.syncButton:setHeight(28)
    self.maintenanceTextRight = buttonX - 16

    self.lastWidth, self.lastHeight = w, h
end

function ParadiseEconomy.AdminPanel:setCreateOpen(open)
    self.createOpen = open == true
    for _, widget in ipairs({ self.newType, self.newOwner, self.newZone, self.newName,
        self.createConfirmButton, self.createCancelButton }) do
        widget:setVisible(self.createOpen)
    end
    if self.createButton then
        self.createButton:setTitle(self.createOpen and "CANCEL CREATE" or "CREATE ACCOUNT")
    end
    if self.accounts then self:layout() end
end

function ParadiseEconomy.AdminPanel:toggleCreate()
    self:setCreateOpen(not self.createOpen)
end

function ParadiseEconomy.AdminPanel:closeCreate()
    self:setCreateOpen(false)
end

function ParadiseEconomy.AdminPanel:update()
    ISCollapsableWindow.update(self)
    if not ParadiseEconomy.canManageEconomy() or not (ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(getPlayer())) then
        if ParadiseEconomy.AdminPanel.ClosePanel then ParadiseEconomy.AdminPanel.ClosePanel() end
        return
    end
    if self.lastWidth ~= self.width or self.lastHeight ~= self.height then
        self:layout()
    end
    self:refreshButtons()
end

function ParadiseEconomy.AdminPanel:close()
    if ParadiseEconomy.AdminPanel.ClosePanel then
        ParadiseEconomy.AdminPanel.ClosePanel()
    else
        self:setVisible(false)
        self:removeFromUIManager()
    end
end

function ParadiseEconomy.AdminPanel:getFilterKey()
    local entry = ParadiseEconomy.accountFilterTypes[self.typeFilter.selected]
    return entry and entry.key or "all"
end

function ParadiseEconomy.AdminPanel:findAccount(accountId)
    return accountId and self.accountMap[accountId] or nil
end

function ParadiseEconomy.AdminPanel:getSelectedAccount()
    return self:findAccount(self.selectedAccountId)
end

function ParadiseEconomy.AdminPanel:getDestAccount()
    return self:findAccount(self.destAccountId)
end

function ParadiseEconomy.AdminPanel:fillBucketCombo(combo, account)
    if not combo then return end
    local previousKey = combo.bucketKeys and combo.bucketKeys[combo.selected] or nil
    combo.bucketKeys = {}
    combo:clear()
    combo.selected = 0
    for _, entry in ipairs(ParadiseEconomy.getAccountBuckets(account)) do
        combo:addOption(entry.label)
        combo.bucketKeys[#combo.bucketKeys + 1] = entry.key
    end
    if #combo.bucketKeys == 0 then
        combo:addOption("No bucket")
        combo.selected = 1
        return
    end
    for int, key in ipairs(combo.bucketKeys) do
        if key == previousKey then combo.selected = int end
    end
    if combo.selected < 1 or combo.selected > #combo.bucketKeys then combo.selected = 1 end
end

function ParadiseEconomy.AdminPanel:refreshZoneOptions()
    if not self.newZone then return end
    local previousId = self.newZone.zoneIds and self.newZone.zoneIds[self.newZone.selected] or nil
    self.newZone.zoneIds = {}
    self.newZone:clear()
    self.newZone:setToolTipMap({ defaultTooltip = "Trade zone for merchant / trade accounts" })
    self.newZone.selected = 0
    local selectedIndex
    for _, zone in ipairs(ParadiseEconomy.getTradeZoneOptions()) do
        self.newZone:addOption(tostring(zone.name or zone.id) .. " [" .. tostring(zone.id) .. "]")
        self.newZone.zoneIds[#self.newZone.zoneIds + 1] = zone.id
        if zone.id == previousId then selectedIndex = #self.newZone.zoneIds end
    end
    if #self.newZone.zoneIds == 0 then
        self.newZone:addOption("No trade zones")
        self.newZone.selected = 1
        return
    end
    if not selectedIndex then
        local market = ParadiseEconomy.clientState.market or {}
        for int, zoneId in ipairs(self.newZone.zoneIds) do
            if zoneId == market.tradeZoneId then selectedIndex = int end
        end
    end
    self.newZone.selected = selectedIndex or 1
end

function ParadiseEconomy.AdminPanel:createAccount()
    local entry = ParadiseEconomy.accountCreateTypes[self.newType.selected]
    if not entry then return end
    local zoneId = self.newZone.zoneIds and self.newZone.zoneIds[self.newZone.selected] or nil
    self.pendingMessage = "Creating " .. entry.label .. " account..."
    ParadiseEconomy.send("adminCreateAccount", {
        accountType = entry.key,
        owner = self.newOwner:getInternalText(),
        zoneId = zoneId,
        name = self.newName:getInternalText(),
    })
    self.newOwner:setText("")
    self.newName:setText("")
    self:closeCreate()
end

function ParadiseEconomy.AdminPanel:refreshDestAccounts()
    if not self.destAccount then return end
    local previous = self.destAccountId
    self.destAccount.accountIds = {}
    self.destAccount:clear()
    self.destAccount.selected = 0
    local selectedIndex
    for _, account in ipairs(ParadiseEconomy.getAccountsList()) do
        self.destAccount:addOption(ParadiseEconomy.getAccountLabel(account) .. " [" .. tostring(account.id) .. "]")
        self.destAccount.accountIds[#self.destAccount.accountIds + 1] = account.id
        if account.id == previous then selectedIndex = #self.destAccount.accountIds end
    end
    if #self.destAccount.accountIds == 0 then
        self.destAccount:addOption("No accounts")
        self.destAccount.selected = 1
        self.destAccountId = nil
    else
        if selectedIndex then self.destAccount.selected = selectedIndex end
        if self.destAccount.selected < 1 or self.destAccount.selected > #self.destAccount.accountIds then
            self.destAccount.selected = 1
        end
        self.destAccountId = self.destAccount.accountIds[self.destAccount.selected]
    end
end

function ParadiseEconomy.AdminPanel:refreshSelection(force)
    local account = self:getSelectedAccount()
    self:fillBucketCombo(self.bucket, account)
    self:fillBucketCombo(self.fromBucket, account)
    self:fillBucketCombo(self.toBucket, self:getDestAccount())
    local isMerchant = account ~= nil and account.type == "merchant"
    self.taxRoute:setVisible(isMerchant)
    self.taxRouteButton:setVisible(isMerchant)
    if isMerchant and (force or not self.taxRoute:isFocused()) then
        self.taxRoute:setText(tostring(account.taxRoute or ""))
    end
    local isPersonal = account ~= nil and account.type == "personal"
    self.freezeButton:setVisible(isPersonal)
    self.freezeButton:setEnable(isPersonal)
    self.freezeButton:setTitle(account and account.frozen == true and "UNFREEZE ACCOUNT" or "FREEZE ACCOUNT")
    self:refreshButtons()
end

function ParadiseEconomy.AdminPanel:refreshButtons()
    local account = self:getSelectedAccount()
    local hasAccount = account ~= nil
    local amount = self.amount and self.amount:getInternalText() or ""
    local validAmount = amount:match("^%d+$") ~= nil and tonumber(amount) > 0
    local validSetAmount = amount:match("^%d+$") ~= nil
    local operation = self.operation.selected or 1
    self.applyButton:setEnable(hasAccount and (operation == 3 and validSetAmount or validAmount))
    local dest = self:getDestAccount()
    local rerouteAmount = self.rerouteAmount and self.rerouteAmount:getInternalText() or ""
    self.rerouteButton:setEnable(hasAccount and dest ~= nil and dest.id ~= account.id
        and rerouteAmount:match("^%d+$") ~= nil and tonumber(rerouteAmount) > 0)
    self.deleteButton:setEnable(hasAccount and account.id ~= ParadiseEconomy.serverAccountId)
    local taxRoute = self.taxRoute and self.taxRoute:getInternalText() or ""
    self.taxRouteButton:setEnable(hasAccount and account.type == "merchant" and taxRoute ~= "")
end

function ParadiseEconomy.AdminPanel:refresh()
    if not self.accounts then return end
    self.pendingMessage = nil
    self:refreshZoneOptions()
    local desiredId = self.selectedAccountId
    if not desiredId and self.targetUsername then desiredId = ParadiseEconomy.findAccountIdByOwner(self.targetUsername) end
    self.accounts:clear()
    self.accountMap = {}
    local filter = self:getFilterKey()
    local search = string.lower(self.search:getInternalText() or "")
    local allAccounts = ParadiseEconomy.getAccountsList()
    self.search:setPlaceholderText("Search " .. ParadiseEconomy.formatNumber(#allAccounts) .. " accounts...")
    local found = false
    for _, account in ipairs(allAccounts) do
        self.accountMap[account.id] = account
        local typeMatch = filter == "all" or account.type == filter
        local text = string.lower(tostring(account.id or "") .. " " .. tostring(account.owner or "") .. " "
            .. tostring(account.name or "") .. " " .. tostring(account.title or "") .. " "
            .. tostring(account.tradeId or "") .. " " .. tostring(account.taxRoute or "") .. " "
            .. tostring(account.zoneName or "") .. " " .. tostring(account.zoneId or "") .. " "
            .. tostring(account.type or ""))
        if typeMatch and (search == "" or text:find(search, 1, true)) then
            self.accounts:addItem(ParadiseEconomy.getAccountLabel(account), account)
            if account.id == desiredId then
                self.accounts.selected = #self.accounts.items
                found = true
            end
        end
    end
    self.selectedAccountId = found and desiredId or nil
    if not found then self.accounts.selected = 0 end
    if self.accounts.selected > #self.accounts.items then self.accounts.selected = 0 end
    self:refreshDestAccounts()
    self:refreshSelection()
end

function ParadiseEconomy.AdminPanel:selectAccount(account)
    self.selectedAccountId = account and account.id or nil
    self:refreshSelection(true)
end

function ParadiseEconomy.AdminPanel.onDestChanged(target, combo)
    target.destAccountId = combo.accountIds and combo.accountIds[combo.selected] or nil
    target:refreshSelection()
end

function ParadiseEconomy.AdminPanel.onSearchChanged(target)
    target:refresh()
end

function ParadiseEconomy.AdminPanel:requestState()
    ParadiseEconomy.send("requestState")
end

function ParadiseEconomy.AdminPanel:syncZones()
    ParadiseEconomy.send("adminSyncZones")
end

function ParadiseEconomy.AdminPanel:toggleFreeze()
    local account = self:getSelectedAccount()
    if not account or account.type ~= "personal" then return end
    ParadiseEconomy.send("adminSetAccountFrozen", {
        accountId = account.id,
        frozen = not (account.frozen == true),
    })
end

function ParadiseEconomy.AdminPanel:rebuildIndex()
    ParadiseEconomy.send("adminRebuildIndex")
end

function ParadiseEconomy.AdminPanel:setTaxRoute()
    local account = self:getSelectedAccount()
    if not account or account.type ~= "merchant" then return end
    ParadiseEconomy.send("adminSetTaxRoute", {
        accountId = account.id,
        taxRoute = self.taxRoute:getInternalText(),
    })
end

function ParadiseEconomy.AdminPanel:applyOperation()
    local account = self:getSelectedAccount()
    if not account then return end
    local operation = "add"
    if self.operation.selected == 2 then
        operation = "remove"
    elseif self.operation.selected == 3 then
        operation = "set"
    end
    ParadiseEconomy.send("adminAdjust", {
        accountId = account.id,
        bucket = self.bucket.bucketKeys[self.bucket.selected],
        currency = self.currency.options[self.currency.selected],
        amount = self.amount:getInternalText(),
        operation = operation,
    })
end

function ParadiseEconomy.AdminPanel:reroute()
    local account = self:getSelectedAccount()
    local dest = self:getDestAccount()
    if not account or not dest then return end
    local payload = {
        fromAccountId = account.id,
        toAccountId = dest.id,
        fromBucket = self.fromBucket.bucketKeys[self.fromBucket.selected],
        toBucket = self.toBucket.bucketKeys[self.toBucket.selected],
        currency = self.currency.options[self.currency.selected],
        amount = self.rerouteAmount:getInternalText(),
    }
    local text = "Reroute " .. tostring(payload.amount) .. " " .. tostring(payload.currency)
        .. " from " .. tostring(account.id) .. " to " .. tostring(dest.id) .. "?"
    local modal = ISModalDialog:new(0, 0, 520, 160, text, true, self,
        ParadiseEconomy.AdminPanel.onRerouteConfirmed, nil, payload)
    modal:initialise()
    modal:addToUIManager()
end

function ParadiseEconomy.AdminPanel.onRerouteConfirmed(target, button, payload)
    if button.internal == "YES" and payload then ParadiseEconomy.send("adminTransfer", payload) end
end

function ParadiseEconomy.AdminPanel:deleteAccount()
    local account = self:getSelectedAccount()
    if not account then return end
    local modal = ISModalDialog:new(0, 0, 480, 160,
        "Delete account " .. tostring(account.id) .. "? Merchant listings will be archived.", true, self,
        ParadiseEconomy.AdminPanel.onDeleteConfirmed, nil, account.id)
    modal:initialise()
    modal:addToUIManager()
end

function ParadiseEconomy.AdminPanel.onDeleteConfirmed(target, button, accountId)
    if button.internal == "YES" and accountId then ParadiseEconomy.send("adminDelete", { accountId = accountId }) end
end

function ParadiseEconomy.AdminPanel:purgeLedger()
    local modal = ISModalDialog:new(0, 0, 480, 160,
        "Purge the transaction ledger? This clears all transaction history.", true, self,
        ParadiseEconomy.AdminPanel.onPurgeConfirmed)
    modal:initialise()
    modal:addToUIManager()
end

function ParadiseEconomy.AdminPanel.onPurgeConfirmed(target, button)
    if button.internal == "YES" then ParadiseEconomy.send("adminPurgeLedger") end
end

function ParadiseEconomy.AdminPanel:openAccountFor(account)
    account = account or self:getSelectedAccount()
    if account and ParadiseEconomy.AccountPanel and ParadiseEconomy.AccountPanel.OpenPanel then
        ParadiseEconomy.AccountPanel.OpenPanel(account)
    end
end

function ParadiseEconomy.AdminPanel:openAccount()
    self:openAccountFor(self:getSelectedAccount())
end

function ParadiseEconomy.AdminPanel:selectServer()
    self.targetUsername = nil
    self.selectedAccountId = ParadiseEconomy.serverAccountId
    if self.search then self.search:setText("") end
    self:setTitle("Economy Administration")
    self:refresh()
end

function ParadiseEconomy.AdminPanel.onAccountDoubleClick(target, account)
    if target and target.openAccountFor then target:openAccountFor(account) end
end

function ParadiseEconomy.AdminPanel:openTables()
    if ParadiseEconomy.TablesPanel and ParadiseEconomy.TablesPanel.OpenPanel then
        ParadiseEconomy.TablesPanel.OpenPanel()
    end
end

function ParadiseEconomy.AdminPanel:openLedger()
    if ParadiseEconomy.LedgerPanel and ParadiseEconomy.LedgerPanel.OpenPanel then
        ParadiseEconomy.LedgerPanel.OpenPanel()
    end
end

function ParadiseEconomy.AdminPanel:setTargetUsername(targetUser)
    local target = ParadiseEconomy.normalizeUsername(targetUser)
    if target then
        self.targetUsername = target
        if self.search then self.search:setText(target) end
    elseif self.targetUsername then
        self.targetUsername = nil
        if self.search then self.search:setText("") end
    end
    if not self.search then return end
    self:setTitle(self.targetUsername and "Economy Administration - Admin: " .. self.targetUsername or "Economy Administration")
    self:refresh()
end

function ParadiseEconomy.AdminPanel.drawCoinValue(panel, rightX, y, amount, color, icon)
    local text = ParadiseEconomy.formatNumber(amount)
    local textW = getTextManager():MeasureStringX(UIFont.Small, text)
    if icon then panel:drawTextureScaled(icon, rightX - textW - 19, y - 1, 14, 14, 1) end
    panel:drawText(text, rightX - textW, y, color.r, color.g, color.b, 1, UIFont.Small)
end

function ParadiseEconomy.AdminPanel.drawCoinHeader(panel, rightX, y, icon)
    local label = "BALANCE"
    local textW = getTextManager():MeasureStringX(UIFont.Small, label)
    local theme = ParadiseEconomy.Theme
    if icon then panel:drawTextureScaled(icon, rightX - textW - 18, y - 1, 12, 12, 1) end
    panel:drawText(label, rightX - textW, y, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
end

function ParadiseEconomy.AdminPanel:drawAccount(y, item, alt)
    local account = item.item
    local theme = ParadiseEconomy.Theme
    local selected = self.selected == item.index
    local rowH = self.itemheight
    if selected then
        self:drawRect(0, y, self.width, rowH - 1, theme.rowSelected.a, theme.rowSelected.r, theme.rowSelected.g, theme.rowSelected.b)
        self:drawRectBorder(0, y, self.width, rowH - 1, 0.9, theme.gold.r, theme.gold.g, theme.gold.b)
        self:drawRect(0, y, 3, rowH - 1, 1, theme.gold.r, theme.gold.g, theme.gold.b)
    elseif alt then
        self:drawRect(0, y, self.width, rowH - 1, theme.rowAlt.a, theme.rowAlt.r, theme.rowAlt.g, theme.rowAlt.b)
    end
    self:drawRect(0, y + rowH - 1, self.width, 1, theme.borderSoft.a, theme.borderSoft.r, theme.borderSoft.g, theme.borderSoft.b)

    self:drawText(tostring(account.id or "?"), self.rowIdX, y + 17,
        theme.textDim.r, theme.textDim.g, theme.textDim.b, 1, UIFont.Small)
    local title = tostring(account.title or account.owner or account.name or account.id or "?")
    if account.frozen == true then title = "[FROZEN] " .. title end
    local titleColor = account.frozen == true and theme.danger or theme.text
    self:drawText(ParadiseEconomy.fitText(title, math.max(60, self.rowTypeX - 14 - self.rowOwnerX), UIFont.Medium),
        self.rowOwnerX, y + 14, titleColor.r, titleColor.g, titleColor.b, 1, UIFont.Medium)
    local typeLabel, typeColor = ParadiseEconomy.getAccountTypeStyle(account.type)
    local chipW = getTextManager():MeasureStringX(UIFont.Small, typeLabel) + 16
    self:drawRect(self.rowTypeX, y + 15, chipW, 18, 0.16, typeColor.r, typeColor.g, typeColor.b)
    self:drawRectBorder(self.rowTypeX, y + 15, chipW, 18, 0.6, typeColor.r, typeColor.g, typeColor.b)
    self:drawText(typeLabel, self.rowTypeX + 8, y + 17, typeColor.r, typeColor.g, typeColor.b, 1, UIFont.Small)

    local buckets = ParadiseEconomy.getAccountBuckets(account)
    local bucket = buckets[1] and account[buckets[1].key] or nil
    ParadiseEconomy.AdminPanel.drawCoinValue(self, self.rowJRight, y + 17,
        ParadiseEconomy.getBalance(bucket, "jimoleon"), theme.gold, ParadiseEconomy.icons.jimoleon)
    ParadiseEconomy.AdminPanel.drawCoinValue(self, self.rowPRight, y + 17,
        ParadiseEconomy.getBalance(bucket, "paradisium"), theme.accent, ParadiseEconomy.icons.paradisium)
    return y + rowH
end

function ParadiseEconomy.AdminPanel:prerender()
    ISCollapsableWindow.prerender(self)
    local theme = ParadiseEconomy.Theme
    local w = self.width
    ParadiseEconomy.drawPanelHeader(self, "ACCOUNT DIRECTORY  ·  BALANCES, LEDGER AND SYSTEM TOOLS", "10", "ADMIN")

    if self.createOpen then
        ParadiseEconomy.drawCard(self, 15, self.createRowY, self.leftW, self.createRowH, theme.accentDim)
        self:drawText("NEW ACCOUNT", 27, self.createRowY + 8,
            theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Small)
        ParadiseEconomy.drawAdminChip(self,
            27 + getTextManager():MeasureStringX(UIFont.Small, "NEW ACCOUNT") + 8, self.createRowY + 7)
        self:drawTextRight("Type · owner · zone · name", 15 + self.leftW - 14, self.createRowY + 8,
            theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    end

    local listX = self.accounts:getX()
    local headerY = self.listHeaderY
    self:drawRect(15, headerY, self.leftW, 24, theme.headerBg.a, theme.headerBg.r, theme.headerBg.g, theme.headerBg.b)
    self:drawRect(15, headerY + 24, self.leftW, 1, theme.borderSoft.a, theme.borderSoft.r, theme.borderSoft.g, theme.borderSoft.b)
    self:drawText("ACCOUNT ID", listX + self.rowIdX, headerY + 7,
        theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText("OWNER / TITLE", listX + self.rowOwnerX, headerY + 7,
        theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText("TYPE", listX + self.rowTypeX, headerY + 7,
        theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    ParadiseEconomy.AdminPanel.drawCoinHeader(self, listX + self.rowJRight, headerY + 7,
        ParadiseEconomy.icons.jimoleon)
    ParadiseEconomy.AdminPanel.drawCoinHeader(self, listX + self.rowPRight, headerY + 7,
        ParadiseEconomy.icons.paradisium)
    if #self.accounts.items == 0 then
        self:drawTextCentre("No accounts match this filter.", listX + leftW / 2, self.listY + 40,
            theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    end

    ParadiseEconomy.drawCard(self, self.detailX, self.detailY, self.detailW, self.detailH, theme.accentDim)
    self:drawText("SELECTED ACCOUNT", self.detailInnerX, self.detailLabelY,
        theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    local account = self:getSelectedAccount()
    if account then
        local line = tostring(account.id or "?") .. " / "
            .. tostring(account.title or account.owner or account.name or "?")
        self:drawText(ParadiseEconomy.fitText(line, self.detailInnerW, UIFont.Medium), self.detailInnerX, self.detailTitleY,
            theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Medium)
        local meta = "Owner: " .. tostring(account.owner or account.name or "-")
        if account.zoneName or account.zoneId then
            meta = meta .. "  ·  Zone: " .. tostring(account.zoneName or account.zoneId)
        end
        if account.taxRoute then meta = meta .. "  ·  Tax: " .. tostring(account.taxRoute) end
        if account.frozen == true then meta = meta .. "  ·  FROZEN" end
        local metaColor = account.frozen == true and theme.danger or theme.textMuted
        self:drawText(ParadiseEconomy.fitText(meta, self.detailInnerW, UIFont.Small), self.detailInnerX, self.detailMetaY,
            metaColor.r, metaColor.g, metaColor.b, 1, UIFont.Small)

        local buckets = ParadiseEconomy.getAccountBuckets(account)
        for index = 1, math.min(#buckets, 2) do
            local entry = buckets[index]
            local tab = account[entry.key]
            local rowY = self.balanceLabelY + (index - 1) * self.balancePitch
            local label = string.upper(tostring(entry.label))
            self:drawText("JIMOLEON " .. label, self.detailInnerX, rowY,
                theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
            self:drawText("PARADISIUM " .. label, self.fieldCol2X, rowY,
                theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
            local boxY = rowY + 13
            self:drawRect(self.detailInnerX, boxY, self.fieldW, self.balanceBoxH,
                theme.entryBg.a, theme.entryBg.r, theme.entryBg.g, theme.entryBg.b)
            self:drawRectBorder(self.detailInnerX, boxY, self.fieldW, self.balanceBoxH,
                theme.borderSoft.a, theme.borderSoft.r, theme.borderSoft.g, theme.borderSoft.b)
            self:drawText(ParadiseEconomy.formatNumber(ParadiseEconomy.getBalance(tab, "jimoleon")),
                self.detailInnerX + 8, boxY + 7, theme.gold.r, theme.gold.g, theme.gold.b, 1, UIFont.Small)
            self:drawRect(self.fieldCol2X, boxY, self.fieldW, self.balanceBoxH,
                theme.entryBg.a, theme.entryBg.r, theme.entryBg.g, theme.entryBg.b)
            self:drawRectBorder(self.fieldCol2X, boxY, self.fieldW, self.balanceBoxH,
                theme.borderSoft.a, theme.borderSoft.r, theme.borderSoft.g, theme.borderSoft.b)
            self:drawText(ParadiseEconomy.formatNumber(ParadiseEconomy.getBalance(tab, "paradisium")),
                self.fieldCol2X + 8, boxY + 7, theme.accent.r, theme.accent.g, theme.accent.b, 1, UIFont.Small)
        end
    else
        self:drawText("Select an account from the directory.", self.detailInnerX, self.detailTitleY,
            theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    end

    self:drawText("OPERATION", self.detailInnerX, self.opLabelY,
        theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    ParadiseEconomy.drawAdminChip(self,
        self.detailInnerX + getTextManager():MeasureStringX(UIFont.Small, "OPERATION") + 8, self.opLabelY - 1)
    self:drawText("AMOUNT", self.detailInnerX, self.amountLabelY,
        theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawRect(self.detailInnerX, self.routeDividerY, self.detailInnerW, 1,
        theme.borderSoft.a, theme.borderSoft.r, theme.borderSoft.g, theme.borderSoft.b)
    self:drawText("ROUTE TO", self.detailInnerX, self.routeLabelY,
        theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    ParadiseEconomy.drawAdminChip(self,
        self.detailInnerX + getTextManager():MeasureStringX(UIFont.Small, "ROUTE TO") + 8, self.routeLabelY - 1)
    if account and account.type == "merchant" then
        self:drawText("TAX ROUTE ACCOUNT ID", self.detailInnerX, self.taxLabelY,
            theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
        ParadiseEconomy.drawAdminChip(self,
            self.detailInnerX + getTextManager():MeasureStringX(UIFont.Small, "TAX ROUTE ACCOUNT ID") + 8,
            self.taxLabelY - 1)
    end

    self:drawRect(15, self.maintenanceY, w - 30, self.maintenanceH, 0.55, 0.20, 0.07, 0.05)
    self:drawRectBorder(15, self.maintenanceY, w - 30, self.maintenanceH, 0.55,
        theme.danger.r, theme.danger.g, theme.danger.b)
    self:drawRect(15, self.maintenanceY, 3, self.maintenanceH, 0.9,
        theme.danger.r, theme.danger.g, theme.danger.b)
    self:drawText("SYSTEM MAINTENANCE", 29, self.maintenanceY + 14,
        theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Medium)
    ParadiseEconomy.drawAdminChip(self,
        29 + getTextManager():MeasureStringX(UIFont.Medium, "SYSTEM MAINTENANCE") + 10, self.maintenanceY + 14)
    local subtitle = "High-impact actions require confirmation and are written to the audit ledger."
    self:drawText(ParadiseEconomy.fitText(subtitle, math.max(120, self.maintenanceTextRight - 29), UIFont.Small),
        29, self.maintenanceY + 40, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)

    local message = self.pendingMessage or ParadiseEconomy.clientState.message
    if message then
        self:drawTextRight(ParadiseEconomy.fitText(tostring(message), math.max(160, w - 450), UIFont.Small),
            w - 80, 29, theme.gold.r, theme.gold.g, theme.gold.b, 1, UIFont.Small)
    end
end

ParadiseEconomy.TablesPanel = ISCollapsableWindow:derive("ParadiseEconomyTablesPanel")

function ParadiseEconomy.TablesPanel:new(x, y, w, h)
    local obj = ISCollapsableWindow.new(self, x, y, w, h)
    obj.title = "Paradise Economy - Data Tables"
    obj.resizable = true
    obj.minimumWidth = 760
    obj.minimumHeight = 480
    obj.detailLines = {}
    return obj
end

function ParadiseEconomy.TablesPanel:createChildren()
    ISCollapsableWindow.createChildren(self)
    self.tableFilter = ISComboBox:new(15, 40, 170, 25, self, ParadiseEconomy.TablesPanel.refresh)
    self.tableFilter:initialise()
    for _, entry in ipairs(ParadiseEconomy.tableTypes) do self.tableFilter:addOption(entry.label) end
    self:addChild(self.tableFilter)
    self.search = ISTextEntryBox:new("", 195, 40, 320, 25)
    self.search.target = self
    self.search.onTextChangeFunction = ParadiseEconomy.TablesPanel.onSearchChanged
    self.search.tooltip = "Filter rows across this table"
    self.search:initialise()
    self.search:instantiate()
    self:addChild(self.search)
    self.refreshButton = ISButton:new(525, 40, 110, 25, "Request State", self, ParadiseEconomy.TablesPanel.requestState)
    self.refreshButton:initialise()
    self:addChild(self.refreshButton)
    self.recordsList = ISScrollingListBox:new(15, 90, self.width - 30, 300)
    self.recordsList:initialise()
    self.recordsList:instantiate()
    self.recordsList.itemheight = 24
    self.recordsList.font = UIFont.Small
    self.recordsList.doDrawItem = ParadiseEconomy.TablesPanel.drawRecord
    self.recordsList.drawBorder = true
    self.recordsList.borderColor = { r = 0.2, g = 0.2, b = 0.5, a = 0.1 }
    self.recordsList:setOnMouseDownFunction(self, ParadiseEconomy.TablesPanel.selectRecord)
    self:addChild(self.recordsList)
    ParadiseEconomy.styleWindow(self)
    ParadiseEconomy.styleTree(self)
    self:layout()
    self:refresh()
end

function ParadiseEconomy.TablesPanel:layout()
    if not self.recordsList then return end
    local contentX, contentW = 13, self.width - 26
    local top = self:titleBarHeight() + 8
    local fontH = getTextManager():getFontHeight(UIFont.Small)
    local rowY = top + fontH + 4
    self.headerY = top
    self.tableFilter:setX(contentX); self.tableFilter:setY(rowY); self.tableFilter:setWidth(170)
    self.search:setX(contentX + 178); self.search:setY(rowY)
    self.search:setWidth(math.max(120, contentW - 178 - 118))
    self.refreshButton:setX(contentX + contentW - 110); self.refreshButton:setY(rowY); self.refreshButton:setWidth(110)
    local listY = rowY + 25 + 10
    local detailH = 170
    self.recordsList:setX(contentX)
    self.recordsList:setY(listY)
    self.recordsList:setWidth(contentW)
    self.recordsList:setHeight(math.max(120, self.height - listY - detailH - 12))
    self.detailY = self.recordsList:getBottom() + 18
    self._lastLayoutW, self._lastLayoutH = self.width, self.height
end

function ParadiseEconomy.TablesPanel:update()
    ISCollapsableWindow.update(self)
    if not ParadiseEconomy.canManageEconomy() or not (ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(getPlayer())) then
        if ParadiseEconomy.TablesPanel.ClosePanel then ParadiseEconomy.TablesPanel.ClosePanel() end
        return
    end
    if self._lastLayoutW ~= self.width or self._lastLayoutH ~= self.height then
        self:layout()
    end
end

function ParadiseEconomy.TablesPanel:close()
    if ParadiseEconomy.TablesPanel.ClosePanel then
        ParadiseEconomy.TablesPanel.ClosePanel()
    else
        self:setVisible(false)
        self:removeFromUIManager()
    end
end

function ParadiseEconomy.TablesPanel:requestState()
    ParadiseEconomy.send("requestState")
end

function ParadiseEconomy.TablesPanel.onSearchChanged(target)
    if target and target.refresh then target:refresh() end
end

function ParadiseEconomy.TablesPanel:getTableKey()
    local entry = ParadiseEconomy.tableTypes[self.tableFilter.selected]
    return entry and entry.key or "accounts"
end

function ParadiseEconomy.TablesPanel:summaryItem(listing)
    if listing.itemData and ParadiseEconomy.ItemData and ParadiseEconomy.ItemData.getSummary then
        return tostring(listing.itemData.name or listing.itemData.fullType) .. " | "
            .. ParadiseEconomy.ItemData.getSummary(listing.itemData)
    end
    return tostring(listing.fullType or listing.item or listing.id or "-")
end

function ParadiseEconomy.TablesPanel:listingDetail(listing, extra)
    local lines = extra or {}
    lines[#lines + 1] = "id: " .. tostring(listing.id)
    lines[#lines + 1] = "seller: " .. tostring(listing.seller)
    lines[#lines + 1] = "zone: " .. tostring(listing.zoneTitle or listing.zoneName) .. " [" .. tostring(listing.zoneId) .. "]"
    lines[#lines + 1] = "merchant: " .. tostring(listing.merchantAccountId)
    lines[#lines + 1] = "price: " .. tostring(listing.price) .. " " .. tostring(listing.currency)
    lines[#lines + 1] = "item: " .. self:summaryItem(listing)
    return lines
end

function ParadiseEconomy.TablesPanel:getRecords()
    local key = self:getTableKey()
    local records = {}
    local add = function(row, detail)
        records[#records + 1] = {
            row = row,
            detail = type(detail) == "function" and nil or detail,
            detailBuilder = type(detail) == "function" and detail or nil,
        }
    end
    local market = ParadiseEconomy.clientState.market or {}
    if key == "accounts" then
        for _, account in ipairs(ParadiseEconomy.getAccountsList()) do
            add(ParadiseEconomy.getAccountLabel(account) .. " [" .. tostring(account.id) .. "] | "
                .. ParadiseEconomy.formatAccountBalances(account), {
                "id: " .. tostring(account.id),
                "type: " .. tostring(ParadiseEconomy.accountTypeLabels[account.type] or account.type),
                "owner: " .. tostring(account.owner),
                "title: " .. tostring(account.title),
                "name: " .. tostring(account.name),
                "zoneId: " .. tostring(account.zoneId),
                "zoneName: " .. tostring(account.zoneName),
                "tradeId: " .. tostring(account.tradeId),
                "tradeTax: " .. tostring(account.tradeTax),
                "taxRoute: " .. tostring(account.taxRoute),
                "archived: " .. tostring(account.archived),
                "steamid: " .. tostring(account.steamid),
                "createdAt: " .. tostring(account.createdAt),
                "balances: " .. ParadiseEconomy.formatAccountBalances(account),
                "listings: " .. tostring(#(account.listings or {})),
            })
        end
    elseif key == "zones" then
        local zones = {}
        for _, zone in pairs(ParadiseEconomy.clientState.zones or {}) do zones[#zones + 1] = zone end
        table.sort(zones, function(a, b) return tostring(a.name or a.id) < tostring(b.name or b.id) end)
        for _, zone in ipairs(zones) do
            local trade = zone.tradeAccountId and ParadiseEconomy.clientState.accounts
                and ParadiseEconomy.clientState.accounts[zone.tradeAccountId] or nil
            add(tostring(zone.name or zone.id) .. " [" .. tostring(zone.id) .. "] | "
                .. (zone.isTrade and "Trade" or "Not trade") .. " | Trade account: " .. tostring(zone.tradeAccountId), {
                "id: " .. tostring(zone.id),
                "name: " .. tostring(zone.name),
                "isTrade: " .. tostring(zone.isTrade),
                "tradeAccountId: " .. tostring(zone.tradeAccountId),
                "tradeTitle: " .. tostring(trade and trade.title),
                "tradeTax: " .. tostring(trade and ParadiseEconomy.getTradeTaxPercent(trade)),
                "marts: " .. tostring(#ParadiseEconomy.getZoneMarketViews(zone.id)),
                "legacy: " .. tostring(zone.legacy),
                "removed: " .. tostring(zone.removed),
                "createdAt: " .. tostring(zone.createdAt),
            })
        end
    elseif key == "tradeMarts" then
        local marts, seen = {}, {}
        for _, mart in pairs(ParadiseEconomy.clientState.marts or {}) do
            if not seen[tostring(mart.id)] then
                seen[tostring(mart.id)] = true
                marts[#marts + 1] = mart
            end
        end
        for _, zone in ipairs(ParadiseEconomy.getManagedZones()) do
            for _, mart in ipairs(zone.marts or {}) do
                if not seen[tostring(mart.id)] then
                    seen[tostring(mart.id)] = true
                    marts[#marts + 1] = mart
                end
            end
        end
        table.sort(marts, function(a, b) return tostring(a.title or a.id) < tostring(b.title or b.id) end)
        for _, mart in ipairs(marts) do
            for _, listing in ipairs(mart.listings or {}) do
                add("[" .. tostring(mart.title or mart.id) .. "] "
                    .. tostring(listing.category or "General") .. " | " .. tostring(listing.fullType) .. " | "
                    .. tostring(listing.direction) .. " | " .. tostring(listing.price) .. " "
                    .. tostring(listing.currency), {
                    "id: " .. tostring(listing.id),
                    "martId: " .. tostring(mart.id),
                    "martTitle: " .. tostring(mart.title),
                    "marketOwner: " .. tostring(mart.owner),
                    "zoneId: " .. tostring(mart.zoneId),
                    "square: " .. tostring(mart.x) .. "," .. tostring(mart.y) .. "," .. tostring(mart.z),
                    "category: " .. tostring(listing.category),
                    "fullType: " .. tostring(listing.fullType),
                    "direction: " .. tostring(listing.direction),
                    "currency: " .. tostring(listing.currency),
                    "price: " .. tostring(listing.price),
                })
            end
        end
    elseif key == "merchantListings" then
        for _, account in ipairs(ParadiseEconomy.getAccountsList()) do
            if account.type == "merchant" then
                for _, listing in ipairs(account.listings or {}) do
                    add("[" .. tostring(account.zoneName or account.zoneId) .. "] " .. tostring(account.owner)
                        .. " | " .. self:summaryItem(listing) .. " | " .. tostring(listing.price) .. " "
                        .. tostring(listing.currency), self:listingDetail(listing, {
                        "merchantAccountId: " .. tostring(account.id),
                        "merchantOwner: " .. tostring(account.owner),
                        "merchantArchived: " .. tostring(account.archived),
                    }))
                end
            end
        end
    elseif key == "playerListings" then
        local listings = {}
        local seen = {}
        for _, account in ipairs(ParadiseEconomy.getAccountsList()) do
            if account.type == "merchant" then
                for _, listing in ipairs(account.listings or {}) do
                    if not seen[listing.id] then
                        seen[listing.id] = true
                        listings[#listings + 1] = listing
                    end
                end
            end
        end
        for _, listing in ipairs(market.playerListings or {}) do
            if not seen[listing.id] then
                seen[listing.id] = true
                listings[#listings + 1] = listing
            end
        end
        for _, listing in ipairs(listings) do
            add(tostring(listing.seller) .. " | " .. self:summaryItem(listing) .. " | "
                .. tostring(listing.price) .. " " .. tostring(listing.currency)
                .. " | " .. tostring(listing.zoneTitle or listing.zoneId), self:listingDetail(listing))
        end
    elseif key == "orphaned" then
        for _, listing in ipairs(ParadiseEconomy.clientState.orphanedPlayerListings or {}) do
            add(tostring(listing.seller) .. " | " .. self:summaryItem(listing) .. " | "
                .. tostring(listing.price) .. " " .. tostring(listing.currency)
                .. " | " .. tostring(listing.zoneTitle or listing.zoneId), self:listingDetail(listing))
        end
    end
    return records
end

function ParadiseEconomy.TablesPanel:refresh()
    if not self.recordsList then return end
    local previous = self.recordsList.selected or 0
    self.recordsList:clear()
    local search = string.lower(self.search:getInternalText() or "")
    local records = self:getRecords()
    for _, record in ipairs(records) do
        local text = string.lower(record.row)
        if search == "" or text:find(search, 1, true) then
            self.recordsList:addItem(record.row, record)
        end
    end
    if #self.recordsList.items == 0 then
        self.recordsList.selected = 0
    else
        self.recordsList.selected = math.max(1, math.min(previous, #self.recordsList.items))
    end
    self:onSelectionChanged()
end

function ParadiseEconomy.TablesPanel:getSelectedRecord()
    local item = self.recordsList and self.recordsList.items[self.recordsList.selected] or nil
    return item and item.item or nil
end

function ParadiseEconomy.TablesPanel:onSelectionChanged()
    local record = self:getSelectedRecord()
    if record and not record.detail and record.detailBuilder then
        record.detail = record.detailBuilder()
    end
    self.detailLines = record and record.detail or {}
end

function ParadiseEconomy.TablesPanel:selectRecord(record)
    self:onSelectionChanged()
end

function ParadiseEconomy.TablesPanel:drawRecord(y, item, alt)
    if self.selected == item.index then
        self:drawRect(0, y, self.width, self.itemheight, 0.32, 0.70, 0.35, 0.16)
    elseif alt then
        self:drawRect(0, y, self.width, self.itemheight, 0.13, 0.30, 0.32, 0.32)
    end
    self:drawRectBorder(0, y, self.width, self.itemheight, 0.45, 0.30, 0.35, 0.45)
    self:drawText(item.item.row, 8, y + 4, 1, 1, 1, 0.95, self.font)
    return y + self.itemheight
end

function ParadiseEconomy.TablesPanel:fitText(text, maxWidth)
    text = tostring(text)
    local textManager = getTextManager()
    if textManager:MeasureStringX(UIFont.Small, text) <= maxWidth then return text end
    while #text > 3 and textManager:MeasureStringX(UIFont.Small, string.sub(text, 1, #text - 1) .. "...") > maxWidth do
        text = string.sub(text, 1, #text - 1)
    end
    return string.sub(text, 1, #text - 1) .. "..."
end

function ParadiseEconomy.TablesPanel:prerender()
    ISCollapsableWindow.prerender(self)
    local contentX = 13
    local contentW = self.width - 26
    local entry = ParadiseEconomy.tableTypes[self.tableFilter.selected]
    local label = entry and entry.label or "Table"
    self:drawText(label .. " (" .. tostring(#self.recordsList.items) .. " rows)", contentX, self.headerY or 30,
        0.7, 0.9, 1, 1, UIFont.Small)
    local detailY = self.detailY or 400
    self:drawText("Record detail", contentX, detailY - 16, 0.7, 0.9, 1, 1, UIFont.Small)
    local perCol = math.max(1, math.floor((self.height - detailY - 8) / 15))
    local colW = math.floor((contentW - 12) / 2)
    for int = 1, math.min(#self.detailLines, perCol * 2) do
        local col = math.floor((int - 1) / perCol)
        local row = (int - 1) % perCol
        self:drawText(self:fitText(self.detailLines[int], colW), contentX + col * (colW + 12), detailY + row * 15,
            0.82, 0.82, 0.82, 1, UIFont.Small)
    end
    if #self.detailLines == 0 then
        self:drawText("Select a row to inspect its fields.", contentX, detailY, 0.8, 0.8, 0.8, 1, UIFont.Small)
    end
end

function ParadiseEconomy.MartAdminView:new(x, y, w, h, mart)
    local obj = ISPanel.new(self, x, y, w, h)
    obj.mart = mart
    obj.selectedZoneId = nil
    obj.selectedMartId = nil
    obj.selectedListingId = nil
    obj.lastWidth = 0
    obj.lastHeight = 0
    obj.backgroundColor = ParadiseEconomy.Theme.panelBg
    obj.borderColor = ParadiseEconomy.Theme.borderSoft
    return obj
end

function ParadiseEconomy.MartAdminView:createChildren()
    ISPanel.createChildren(self)

    self.martCombo = ISComboBox:new(29, 64, 300, 24, self, ParadiseEconomy.MartAdminView.onMartChanged)
    self.martCombo.tooltip = "Market in the selected trade zone"
    self.martCombo:initialise()
    self:addChild(self.martCombo)

    self.titleEntry = ISTextEntryBox:new("", 337, 64, 300, 24)
    self.titleEntry.tooltip = "Market title"
    self.titleEntry:initialise()
    self.titleEntry:instantiate()
    self.titleEntry:setPlaceholderText("Market title...")
    self:addChild(self.titleEntry)
    self.saveDetailsButton = ISButton:new(700, 64, 150, 24, "SAVE MARKET", self, ParadiseEconomy.MartAdminView.saveDetails)
    self.saveDetailsButton:initialise()
    self:addChild(self.saveDetailsButton)

    self.taxEntry = ISTextEntryBox:new("", 29, 110, 110, 24)
    self.taxEntry.tooltip = "Trade tax percent (0-100)"
    self.taxEntry:initialise()
    self.taxEntry:instantiate()
    self.taxEntry:setOnlyNumbers(true)
    self.taxEntry:setPlaceholderText("0")
    self:addChild(self.taxEntry)

    self.categoriesEntry = ISTextEntryBox:new("", 147, 110, 300, 24)
    self.categoriesEntry.tooltip = "Market category tabs, separated by ;"
    self.categoriesEntry:initialise()
    self.categoriesEntry:instantiate()
    self.categoriesEntry:setPlaceholderText("Wheel; Tools; Seat; Windshield")
    self:addChild(self.categoriesEntry)

    self.dailyFee = ISTextEntryBox:new("", 101, 100, 70, 24)
    self.dailyFee.tooltip = "Merchant store cost per day in this trade zone"
    self.dailyFee:initialise()
    self.dailyFee:instantiate()
    self.dailyFee:setOnlyNumbers(true)
    self.dailyFee:setPlaceholderText("0")
    self:addChild(self.dailyFee)
    self.feeCurrency = ISComboBox:new(179, 100, 100, 24, self)
    self.feeCurrency.tooltip = "Daily store fee currency"
    self.feeCurrency:initialise()
    self.feeCurrency:addOption("jimoleon")
    self.feeCurrency:addOption("paradisium")
    self:addChild(self.feeCurrency)
    self.applyFeeButton = ISButton:new(287, 100, 100, 24, "SET FEE", self, ParadiseEconomy.MartAdminView.applyZoneFee)
    self.applyFeeButton.tooltip = "Apply the daily merchant store fee for this trade zone"
    self.applyFeeButton:initialise()
    self:addChild(self.applyFeeButton)

    self.ownerAccount = ISTextEntryBox:new("", 29, 136, 300, 24)
    self.ownerAccount.tooltip = "Admin only: account ID or username that owns this market's funds"
    self.ownerAccount:initialise()
    self.ownerAccount:instantiate()
    self.ownerAccount:setPlaceholderText("Owner account ID or username...")
    self:addChild(self.ownerAccount)
    self.assignOwnerButton = ISButton:new(337, 136, 150, 24, "ASSIGN OWNER", self, ParadiseEconomy.MartAdminView.assignMartOwner)
    self.assignOwnerButton.tooltip = "Admin only: route this market's funds to another account"
    self.assignOwnerButton:initialise()
    self:addChild(self.assignOwnerButton)

    self.fundsSource = ISComboBox:new(120, 172, 120, 20, self)
    self.fundsSource.tooltip = "Account the withdraw and transfer actions use"
    self.fundsSource:initialise()
    self.fundsSource:addOption("Treasury")
    self.fundsSource:addOption("Finance")
    self:addChild(self.fundsSource)
    self.sweepButton = ISButton:new(246, 172, 150, 20, "SWEEP TO FINANCE", self, ParadiseEconomy.MartAdminView.sweepTreasury)
    self.sweepButton.tooltip = "Move the whole zone treasury balance into the finance account"
    self.sweepButton:initialise()
    self:addChild(self.sweepButton)

    self.withdrawCurrency = ISComboBox:new(29, 172, 110, 24, self)
    self.withdrawCurrency:initialise()
    self.withdrawCurrency:addOption("jimoleon")
    self.withdrawCurrency:addOption("paradisium")
    self:addChild(self.withdrawCurrency)
    self.withdrawAmount = ISTextEntryBox:new("", 147, 172, 110, 24)
    self.withdrawAmount:initialise()
    self.withdrawAmount:instantiate()
    self.withdrawAmount:setOnlyNumbers(true)
    self.withdrawAmount:setPlaceholderText("Amount")
    self:addChild(self.withdrawAmount)
    self.withdrawButton = ISButton:new(265, 172, 110, 24, "WITHDRAW", self, ParadiseEconomy.MartAdminView.withdraw)
    self.withdrawButton:initialise()
    self:addChild(self.withdrawButton)

    self.transferCurrency = ISComboBox:new(414, 172, 110, 24, self)
    self.transferCurrency:initialise()
    self.transferCurrency:addOption("jimoleon")
    self.transferCurrency:addOption("paradisium")
    self:addChild(self.transferCurrency)
    self.transferAmount = ISTextEntryBox:new("", 532, 172, 100, 24)
    self.transferAmount:initialise()
    self.transferAmount:instantiate()
    self.transferAmount:setOnlyNumbers(true)
    self.transferAmount:setPlaceholderText("Amount")
    self:addChild(self.transferAmount)
    self.transferTarget = ISTextEntryBox:new("", 640, 172, 200, 24)
    self.transferTarget.tooltip = "Username of the player account receiving the transfer"
    self.transferTarget:initialise()
    self.transferTarget:instantiate()
    self.transferTarget:setPlaceholderText("Username...")
    self:addChild(self.transferTarget)
    self.transferButton = ISButton:new(850, 172, 110, 24, "TRANSFER", self, ParadiseEconomy.MartAdminView.transfer)
    self.transferButton:initialise()
    self:addChild(self.transferButton)

    self.addEntryButton = ISButton:new(850, 222, 120, 22, "+ ADD ENTRY", self, ParadiseEconomy.MartAdminView.addEntry)
    self.addEntryButton.tooltip = "Clear the editor and focus the item type field"
    self.addEntryButton:initialise()
    self:addChild(self.addEntryButton)

    self.itemSearch = ISTextEntryBox:new("", 29, 254, 200, 22)
    self.itemSearch.target = self
    self.itemSearch.onTextChangeFunction = ParadiseEconomy.MartAdminView.onItemSearchChanged
    self.itemSearch:initialise()
    self.itemSearch:instantiate()
    self.itemSearch:setPlaceholderText("Search item script or name...")
    self:addChild(self.itemSearch)
    self.itemFilterButton = ISButton:new(234, 254, 56, 22, "Find", self, ParadiseEconomy.MartAdminView.refreshItems)
    self.itemFilterButton:initialise()
    self:addChild(self.itemFilterButton)
    self.items = ISScrollingListBox:new(29, 282, 290, 160)
    self.items:initialise()
    self.items.itemheight = 22
    self.items.font = UIFont.Small
    self.items.doDrawItem = ParadiseEconomy.MartAdminView.drawItem
    self.items:setOnMouseDownFunction(self, ParadiseEconomy.MartAdminView.selectItem)
    self:addChild(self.items)

    self.listingSearch = ISTextEntryBox:new("", 335, 254, 220, 22)
    self.listingSearch.target = self
    self.listingSearch.onTextChangeFunction = ParadiseEconomy.MartAdminView.onListingSearchChanged
    self.listingSearch:initialise()
    self.listingSearch:instantiate()
    self.listingSearch:setPlaceholderText("Search mart listings...")
    self:addChild(self.listingSearch)
    self.listingFilterButton = ISButton:new(560, 254, 60, 22, "Search", self, ParadiseEconomy.MartAdminView.refreshListings)
    self.listingFilterButton:initialise()
    self:addChild(self.listingFilterButton)
    self.listings = ISScrollingListBox:new(335, 282, 400, 160)
    self.listings:initialise()
    self.listings.itemheight = 30
    self.listings.font = UIFont.Small
    self.listings.doDrawItem = ParadiseEconomy.MartAdminView.drawListing
    self.listings:setOnMouseDownFunction(self, ParadiseEconomy.MartAdminView.selectListing)
    self:addChild(self.listings)

    self.category = ISTextEntryBox:new("", 29, 484, 120, 24)
    self.category.tooltip = "Mart category"
    self.category:initialise()
    self.category:instantiate()
    self.category:setPlaceholderText("General")
    self:addChild(self.category)
    self.fullType = ISTextEntryBox:new("", 157, 484, 300, 24)
    self.fullType.tooltip = "Item script name"
    self.fullType:initialise()
    self.fullType:instantiate()
    self.fullType:setPlaceholderText("Base.Item...")
    self:addChild(self.fullType)
    self.direction = ISComboBox:new(465, 484, 120, 24, self)
    self.direction:initialise()
    self.direction:addOption("Mart Sells")
    self.direction:addOption("Mart Buys")
    self:addChild(self.direction)
    self.currency = ISComboBox:new(593, 484, 110, 24, self)
    self.currency:initialise()
    self.currency:addOption("jimoleon")
    self.currency:addOption("paradisium")
    self:addChild(self.currency)
    self.price = ISTextEntryBox:new("", 711, 484, 100, 24)
    self.price:initialise()
    self.price:instantiate()
    self.price:setOnlyNumbers(true)
    self.price:setPlaceholderText("0")
    self:addChild(self.price)
    self.clearButton = ISButton:new(29, 516, 80, 24, "CLEAR", self, ParadiseEconomy.MartAdminView.clearEditor)
    self.clearButton:initialise()
    self:addChild(self.clearButton)
    self.deleteListingButton = ISButton:new(117, 516, 120, 24, "DELETE ENTRY", self, ParadiseEconomy.MartAdminView.deleteListing)
    self.deleteListingButton:initialise()
    self:addChild(self.deleteListingButton)
    self.saveButton = ISButton:new(750, 516, 150, 24, "SAVE LISTING", self, ParadiseEconomy.MartAdminView.saveListing)
    self.saveButton:initialise()
    self:addChild(self.saveButton)

    ParadiseEconomy.styleTree(self)
    local theme = ParadiseEconomy.Theme
    self.saveDetailsButton.backgroundColor = theme.gold
    self.saveDetailsButton.backgroundColorMouseOver = { r = 0.99, g = 0.86, b = 0.45, a = 1 }
    self.saveDetailsButton.textColor = { r = 0.06, g = 0.07, b = 0.08, a = 1 }
    self.saveDetailsButton.borderColor = theme.gold
    self.saveButton.backgroundColor = theme.gold
    self.saveButton.backgroundColorMouseOver = { r = 0.99, g = 0.86, b = 0.45, a = 1 }
    self.saveButton.textColor = { r = 0.06, g = 0.07, b = 0.08, a = 1 }
    self.saveButton.borderColor = theme.gold
    self:refreshItems()
    self:refreshMarket()
    self:layout()
end

function ParadiseEconomy.MartAdminView:getTradeList()
    local list = {}
    local seen = {}
    for _, trade in ipairs(ParadiseEconomy.getManageableTradeZones()) do
        if trade.zoneId and not seen[trade.zoneId] then
            seen[trade.zoneId] = true
            list[#list + 1] = trade
        end
    end
    if #list == 0 then
        for _, account in pairs(ParadiseEconomy.clientState.accounts or {}) do
            if account.type == "trade" and not account.archived and account.zoneId and not seen[account.zoneId] then
                seen[account.zoneId] = true
                list[#list + 1] = account
            end
        end
    end
    table.sort(list, function(a, b)
        return tostring(a.title or a.tradeId or a.zoneId) < tostring(b.title or b.tradeId or b.zoneId)
    end)
    return list
end

function ParadiseEconomy.MartAdminView:getSelectedTrade()
    local zoneId = self.selectedZoneId
    if not zoneId then return nil end
    for _, trade in ipairs(self:getTradeList()) do
        if trade.zoneId == zoneId then return trade end
    end
    return nil
end

function ParadiseEconomy.MartAdminView:getMartList()
    local trade = self:getSelectedTrade()
    return trade and trade.marts or {}
end

function ParadiseEconomy.MartAdminView:getSelectedMart()
    for _, mart in ipairs(self:getMartList()) do
        if tostring(mart.id) == tostring(self.selectedMartId) then return mart end
    end
    return nil
end

function ParadiseEconomy.MartAdminView:getSelectedListing()
    local mart = self:getSelectedMart()
    for _, listing in ipairs(mart and mart.listings or {}) do
        if tostring(listing.id) == tostring(self.selectedListingId) then return listing end
    end
end

function ParadiseEconomy.MartAdminView:isAdminView()
    if self.isAdm == true then return true end
    if self.mart and self.mart.isAdm == true then return true end
    return ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(getPlayer()) or false
end

function ParadiseEconomy.MartAdminView:drawListing(y, item, alt)
    local listing = item.item
    local theme = ParadiseEconomy.Theme
    local w = self.width
    if self.selected == item.index then
        self:drawRect(0, y, w, self.itemheight - 1, theme.rowSelected.a, theme.rowSelected.r, theme.rowSelected.g, theme.rowSelected.b)
    elseif alt then
        self:drawRect(0, y, w, self.itemheight - 1, theme.rowAlt.a, theme.rowAlt.r, theme.rowAlt.g, theme.rowAlt.b)
    end
    local name = tostring(listing.fullType or "?")
    local nameW = math.max(120, math.floor(w * 0.32))
    self:drawText(ParadiseEconomy.fitText(name, nameW, UIFont.Small), 10, y + 9,
        theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Small)
    local tint = ParadiseEconomy.getCategoryColor(listing.category)
    local chipText = ParadiseEconomy.fitText(tostring(listing.category or "General"), 110, UIFont.Small)
    local chipW = getTextManager():MeasureStringX(UIFont.Small, chipText) + 14
    local chipX = 10 + nameW + 14
    self:drawRect(chipX, y + 6, chipW, 16, 0.16, tint.r, tint.g, tint.b)
    self:drawRectBorder(chipX, y + 6, chipW, 16, 0.55, tint.r, tint.g, tint.b)
    self:drawText(chipText, chipX + 7, y + 7, tint.r, tint.g, tint.b, 1, UIFont.Small)
    local action = listing.direction == "sell" and "MART BUYS" or "MART SELLS"
    local actionColor = listing.direction == "sell" and theme.gold or theme.accent
    self:drawText(action, chipX + chipW + 14, y + 9, actionColor.r, actionColor.g, actionColor.b, 1, UIFont.Small)
    self:drawTextRight("EDIT", w - 10, y + 9, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    local priceText = ParadiseEconomy.formatNumber(listing.price)
    local priceW = getTextManager():MeasureStringX(UIFont.Small, priceText)
    self:drawTextRight(priceText, w - 46, y + 9, theme.gold.r, theme.gold.g, theme.gold.b, 1, UIFont.Small)
    local icon = listing.currency == "paradisium" and ParadiseEconomy.icons.paradisium or ParadiseEconomy.icons.jimoleon
    if icon then self:drawTextureScaled(icon, w - 64 - priceW, y + 8, 14, 14, 1) end
    return y + self.itemheight
end

function ParadiseEconomy.MartAdminView:drawItem(y, item, alt)
    local theme = ParadiseEconomy.Theme
    if self.selected == item.index then
        self:drawRect(0, y, self.width, self.itemheight - 1, theme.rowSelected.a, theme.rowSelected.r, theme.rowSelected.g, theme.rowSelected.b)
    elseif alt then
        self:drawRect(0, y, self.width, self.itemheight - 1, theme.rowAlt.a, theme.rowAlt.r, theme.rowAlt.g, theme.rowAlt.b)
    end
    self:drawText(ParadiseEconomy.fitText(tostring(item.text), self.width - 16, UIFont.Small), 8, y + 4,
        theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Small)
    return y + self.itemheight
end

function ParadiseEconomy.MartAdminView.onListingSearchChanged(target)
    if target and target.refreshListings then target:refreshListings() end
end

function ParadiseEconomy.MartAdminView.onItemSearchChanged(target)
    if target and target.refreshItems then target:refreshItems() end
end

function ParadiseEconomy.MartAdminView:setSelectedZone(zoneId)
    if self.selectedZoneId ~= zoneId then self.selectedMartId = nil end
    self.selectedZoneId = zoneId
    self.selectedListingId = nil
    self:clearEditor()
    self:refreshMarket()
end

function ParadiseEconomy.MartAdminView:setSelectedMart(martId)
    self.selectedMartId = martId
    self.selectedListingId = nil
    self:clearEditor()
    self:refreshMarket()
end

function ParadiseEconomy.MartAdminView.onMartChanged(target)
    if target and target.refreshMartSelection then target:refreshMartSelection() end
end

function ParadiseEconomy.MartAdminView:refreshMartSelection()
    local marts = self:getMartList()
    local index = self.martCombo.selected
    local mart = marts[index]
    self:setSelectedMart(mart and mart.id or nil)
end

function ParadiseEconomy.MartAdminView:refreshMartCombo()
    if not self.martCombo then return end
    local marts = self:getMartList()
    local previous = self.selectedMartId
    self.martCombo.martIds = {}
    self.martCombo:clear()
    self.martCombo.selected = 0
    local selectedIndex
    for _, mart in ipairs(marts) do
        self.martCombo:addOption(tostring(mart.title or mart.id))
        self.martCombo.martIds[#self.martCombo.martIds + 1] = mart.id
        if tostring(mart.id) == tostring(previous) then selectedIndex = #self.martCombo.martIds end
    end
    if #marts == 0 then
        self.martCombo:addOption("No markets at this trade zone")
        self.martCombo.selected = 1
        self.selectedMartId = nil
    else
        self.martCombo.selected = selectedIndex or 1
        self.selectedMartId = self.martCombo.martIds[self.martCombo.selected]
    end
end

function ParadiseEconomy.MartAdminView:refreshMarket()
    if not self.titleEntry then return end
    self:refreshMartCombo()
    local trade = self:getSelectedTrade()
    local mart = self:getSelectedMart()
    if not self.titleEntry:isFocused() then
        self.titleEntry:setText(mart and tostring(mart.title or "") or "")
    end
    if not self.taxEntry:isFocused() then
        self.taxEntry:setText(trade and tostring(ParadiseEconomy.getTradeTaxPercent(trade)) or "")
    end
    if not self.categoriesEntry:isFocused() then
        local categories = mart and mart.categories or {}
        self.categoriesEntry:setText(table.concat(categories, "; "))
    end
    if self.dailyFee and not self.dailyFee:isFocused() then
        self.dailyFee:setText(trade and tostring(trade.merchantDailyFee or 0) or "")
    end
    if self.feeCurrency and trade then
        self.feeCurrency.selected = trade.merchantFeeCurrency == "paradisium" and 2 or 1
    end
    if self.ownerAccount and not self.ownerAccount:isFocused() then
        local ownerId = mart and mart.ownerAccountId or nil
        if mart and not ownerId then ownerId = trade and trade.id end
        self.ownerAccount:setText(ownerId and tostring(ownerId) or "")
    end
    if not mart then self:clearEditor() end
    self:refreshListings()
end

function ParadiseEconomy.MartAdminView:saveDetails()
    local mart = self:getSelectedMart()
    if mart and self.titleEntry:getInternalText() ~= "" then
        ParadiseEconomy.send("renameMart", { martId = mart.id, title = self.titleEntry:getInternalText() })
    end
    if mart then
        ParadiseEconomy.send("martSetCategories", { martId = mart.id, text = self.categoriesEntry:getInternalText() })
    end
    if self.selectedZoneId and self.taxEntry:getInternalText():match("^%d+$") then self:setTax() end
end

function ParadiseEconomy.MartAdminView:setTax()
    if not self.selectedZoneId then return end
    ParadiseEconomy.send("tradeSetTax", { zoneId = self.selectedZoneId, percent = self.taxEntry:getInternalText() })
end

function ParadiseEconomy.MartAdminView:withdraw()
    if not self.selectedZoneId then return end
    ParadiseEconomy.send(self:getFundsSourceCommand("Withdraw"), {
        zoneId = self.selectedZoneId,
        currency = self.withdrawCurrency.options[self.withdrawCurrency.selected],
        amount = self.withdrawAmount:getInternalText(),
    })
end

function ParadiseEconomy.MartAdminView:transfer()
    if not self.selectedZoneId then return end
    ParadiseEconomy.send(self:getFundsSourceCommand("Transfer"), {
        zoneId = self.selectedZoneId,
        targetUser = self.transferTarget:getInternalText(),
        currency = self.transferCurrency.options[self.transferCurrency.selected],
        amount = self.transferAmount:getInternalText(),
    })
end

function ParadiseEconomy.MartAdminView:getFundsSourceCommand(action)
    if self.fundsSource and self.fundsSource.selected == 2 then
        return action == "Withdraw" and "financeWithdraw" or "financeTransfer"
    end
    return action == "Withdraw" and "tradeWithdraw" or "tradeTransfer"
end

function ParadiseEconomy.MartAdminView:applyZoneFee()
    if not self.selectedZoneId then return end
    local fee = self.dailyFee:getInternalText()
    if not fee:match("^%d+$") then return end
    ParadiseEconomy.send("zoneSetDailyFee", {
        zoneId = self.selectedZoneId,
        fee = fee,
        currency = self.feeCurrency.options[self.feeCurrency.selected],
    })
end

function ParadiseEconomy.MartAdminView:assignMartOwner()
    local mart = self:getSelectedMart()
    if not mart then return end
    local owner = self.ownerAccount:getInternalText()
    if owner == "" then return end
    ParadiseEconomy.send("adminSetMartOwner", {
        martId = mart.id,
        ownerAccountId = owner,
        ownerUsername = owner,
    })
end

function ParadiseEconomy.MartAdminView:sweepTreasury()
    if not self.selectedZoneId then return end
    ParadiseEconomy.send("zoneSweep", { zoneId = self.selectedZoneId })
end

function ParadiseEconomy.MartAdminView:refreshListings()
    if not self.listings then return end
    local previous = self.listings.selected or 0
    self.listings:clear()
    local search = string.lower(self.listingSearch:getInternalText() or "")
    local selected
    local mart = self:getSelectedMart()
    for _, listing in ipairs(mart and mart.listings or {}) do
        local text = string.lower(tostring(listing.fullType) .. " " .. tostring(listing.category or "") .. " "
            .. tostring(listing.direction) .. " " .. tostring(listing.currency))
        if search == "" or text:find(search, 1, true) then
            self.listings:addItem(listing.fullType, listing)
            if tostring(listing.id) == tostring(self.selectedListingId) then selected = #self.listings.items end
        end
    end
    if selected then
        self.listings.selected = selected
    elseif #self.listings.items == 0 then
        self.listings.selected = 0
    else
        self.listings.selected = math.max(1, math.min(previous, #self.listings.items))
    end
    if self.selectedListingId and not self:getSelectedListing() then self:clearEditor() end
end

function ParadiseEconomy.MartAdminView:selectListing(listing)
    if not listing then return end
    self.selectedListingId = listing.id
    self.category:setText(listing.category or "General")
    self.fullType:setText(listing.fullType or "")
    self.direction.selected = listing.direction == "sell" and 2 or 1
    self.currency.selected = listing.currency == "paradisium" and 2 or 1
    self.price:setText(tostring(listing.price or ""))
end

function ParadiseEconomy.MartAdminView:saveListing()
    local mart = self:getSelectedMart()
    if not mart then return end
    ParadiseEconomy.send("tradeItemSave", {
        martId = mart.id,
        listingId = self.selectedListingId,
        category = self.category:getInternalText(),
        fullType = self.fullType:getInternalText(),
        price = self.price:getInternalText(),
        amount = self.price:getInternalText(),
        direction = self.direction.selected == 2 and "sell" or "buy",
        currency = self.currency.options[self.currency.selected],
    })
end

function ParadiseEconomy.MartAdminView:deleteListing()
    local listing = self:getSelectedListing()
    local mart = self:getSelectedMart()
    if not listing or not mart then return end
    local modal = ISModalDialog:new(0, 0, 380, 160, "Delete listing '" .. tostring(listing.fullType) .. "'?", true, self, ParadiseEconomy.MartAdminView.onDeleteListingConfirmed, nil, mart.id, listing.id)
    modal:initialise()
    modal:addToUIManager()
end

function ParadiseEconomy.MartAdminView.onDeleteListingConfirmed(target, button, martId, listingId)
    if button.internal == "YES" then
        target.selectedListingId = nil
        ParadiseEconomy.send("tradeItemDelete", { martId = martId, listingId = listingId })
    end
end

function ParadiseEconomy.MartAdminView:addEntry()
    self:clearEditor()
    if self.fullType then self.fullType:focus() end
end

function ParadiseEconomy.MartAdminView:clearEditor()
    self.selectedListingId = nil
    self.category:setText("")
    self.fullType:setText("")
    self.price:setText("")
    self.direction.selected = 1
    self.currency.selected = 1
end

function ParadiseEconomy.MartAdminView:refreshItems()
    if not self.items then return end
    self.items:clear()
    local search = string.lower(self.itemSearch and self.itemSearch:getInternalText() or "")
    local all = ScriptManager.instance:getAllItems()
    for int = 0, all:size() - 1 do
        local scrItem = all:get(int)
        local fullType = scrItem:getFullName()
        local displayName = scrItem:getDisplayName()
        if search == "" or string.lower(fullType):find(search, 1, true) or string.lower(displayName):find(search, 1, true) then
            self.items:addItem(fullType, fullType)
        end
    end
end

function ParadiseEconomy.MartAdminView:selectItem(fullType)
    if fullType then
        self.selectedListingId = nil
        self.fullType:setText(fullType)
    end
end

function ParadiseEconomy.MartAdminView:layout()
    if not self.items then return end
    local w, h = self.width, self.height

    self.accountCardY = 42
    self.accountCardH = 140
    self.accountLabelY = self.accountCardY + 8
    self.accountFieldY = self.accountCardY + 22
    self.accountLabel2Y = self.accountCardY + 54
    self.accountField2Y = self.accountCardY + 68
    self.accountLabel3Y = self.accountCardY + 100
    self.accountField3Y = self.accountCardY + 114

    local saveW = 150
    local gap = 12
    local comboW = math.min(300, math.max(180, math.floor((w - 58) * 0.34)))
    self.saveX = w - 29 - saveW
    self.martCombo:setX(29)
    self.martCombo:setY(self.accountFieldY)
    self.martCombo:setWidth(comboW)
    self.martCombo:setHeight(24)
    local titleX = 29 + comboW + gap
    self.titleEntry:setX(titleX)
    self.titleEntry:setY(self.accountFieldY)
    self.titleEntry:setWidth(math.max(120, self.saveX - gap - titleX))
    self.titleEntry:setHeight(24)
    self.saveDetailsButton:setX(self.saveX)
    self.saveDetailsButton:setY(self.accountFieldY)
    self.saveDetailsButton:setWidth(saveW)
    self.saveDetailsButton:setHeight(24)

    self.taxEntry:setX(29)
    self.taxEntry:setY(self.accountField2Y)
    self.taxEntry:setWidth(64)
    self.taxEntry:setHeight(24)
    self.dailyFee:setX(101)
    self.dailyFee:setY(self.accountField2Y)
    self.dailyFee:setWidth(70)
    self.dailyFee:setHeight(24)
    self.feeCurrency:setX(179)
    self.feeCurrency:setY(self.accountField2Y)
    self.feeCurrency:setWidth(100)
    self.feeCurrency:setHeight(24)
    self.applyFeeButton:setX(287)
    self.applyFeeButton:setY(self.accountField2Y)
    self.applyFeeButton:setWidth(100)
    self.applyFeeButton:setHeight(24)
    self.categoriesEntry:setX(403)
    self.categoriesEntry:setY(self.accountField2Y)
    self.categoriesEntry:setWidth(math.max(120, self.saveX - gap - 403))
    self.categoriesEntry:setHeight(24)

    self.ownerAccount:setX(29)
    self.ownerAccount:setY(self.accountField3Y)
    self.ownerAccount:setWidth(math.max(150, self.saveX - gap - 29 - 158))
    self.ownerAccount:setHeight(24)
    self.assignOwnerButton:setX(self.ownerAccount:getX() + self.ownerAccount:getWidth() + gap)
    self.assignOwnerButton:setY(self.accountField3Y)
    self.assignOwnerButton:setWidth(150)
    self.assignOwnerButton:setHeight(24)

    self.fundsCardY = 188
    self.fundsCardH = 68
    self.fundsLabelY = self.fundsCardY + 6
    self.actionY = self.fundsCardY + 30
    self.fundsSource:setX(80)
    self.fundsSource:setY(self.fundsCardY + 2)
    self.fundsSource:setWidth(120)
    self.fundsSource:setHeight(20)
    self.sweepButton:setX(206)
    self.sweepButton:setY(self.fundsCardY + 2)
    self.sweepButton:setWidth(150)
    self.sweepButton:setHeight(20)
    self.withdrawCurrency:setX(29)
    self.withdrawCurrency:setY(self.actionY)
    self.withdrawCurrency:setWidth(110)
    self.withdrawCurrency:setHeight(24)
    self.withdrawAmount:setX(147)
    self.withdrawAmount:setY(self.actionY)
    self.withdrawAmount:setWidth(110)
    self.withdrawAmount:setHeight(24)
    self.withdrawButton:setX(265)
    self.withdrawButton:setY(self.actionY)
    self.withdrawButton:setWidth(110)
    self.withdrawButton:setHeight(24)
    local transferX = math.max(410, math.floor(w * 0.38))
    self.transferX = transferX
    self.transferCurrency:setX(transferX)
    self.transferCurrency:setY(self.actionY)
    self.transferCurrency:setWidth(110)
    self.transferCurrency:setHeight(24)
    self.transferAmount:setX(transferX + 118)
    self.transferAmount:setY(self.actionY)
    self.transferAmount:setWidth(100)
    self.transferAmount:setHeight(24)
    local targetX = transferX + 226
    self.transferTarget:setX(targetX)
    self.transferTarget:setY(self.actionY)
    self.transferTarget:setWidth(math.max(80, w - 29 - 110 - 10 - targetX))
    self.transferTarget:setHeight(24)
    self.transferButton:setX(w - 29 - 110)
    self.transferButton:setY(self.actionY)
    self.transferButton:setWidth(110)
    self.transferButton:setHeight(24)

    self.inventoryCardY = 262
    local editorH = 108
    self.editorCardY = h - editorH - 8
    self.editorCardH = editorH
    self.inventoryCardH = math.max(140, self.editorCardY - 10 - self.inventoryCardY)
    self.inventoryHeaderY = self.inventoryCardY + 8
    self.addEntryButton:setX(w - 29 - 120)
    self.addEntryButton:setY(self.inventoryCardY + 4)
    self.addEntryButton:setWidth(120)
    self.addEntryButton:setHeight(22)
    local searchY = self.inventoryCardY + 46
    self.inventoryLabelY = self.inventoryCardY + 30
    self.inventorySearchY = searchY
    local itemSearchW = math.min(220, math.max(140, math.floor((w - 58) * 0.24)))
    self.itemSearch:setX(29)
    self.itemSearch:setY(searchY)
    self.itemSearch:setWidth(itemSearchW)
    self.itemSearch:setHeight(22)
    self.itemFilterButton:setX(29 + itemSearchW + 5)
    self.itemFilterButton:setY(searchY)
    self.itemFilterButton:setWidth(56)
    self.itemFilterButton:setHeight(22)
    self.listingX = 335
    self.listingSearch:setX(self.listingX)
    self.listingSearch:setY(searchY)
    self.listingSearch:setWidth(math.max(140, w - 29 - 60 - 6 - self.listingX))
    self.listingSearch:setHeight(22)
    self.listingFilterButton:setX(w - 29 - 60)
    self.listingFilterButton:setY(searchY)
    self.listingFilterButton:setWidth(60)
    self.listingFilterButton:setHeight(22)
    local listY = searchY + 28
    local listH = math.max(80, self.inventoryCardY + self.inventoryCardH - 8 - listY)
    self.listY, self.listH = listY, listH
    self.items:setX(29)
    self.items:setY(listY)
    self.items:setWidth(290)
    self.items:setHeight(listH)
    self.listings:setX(self.listingX)
    self.listings:setY(listY)
    self.listings:setWidth(math.max(200, w - 29 - self.listingX))
    self.listings:setHeight(listH)

    self.editorLabelY = self.editorCardY + 6
    self.editorFieldLabelY = self.editorCardY + 24
    self.editorFieldY = self.editorCardY + 38
    self.editorButtonY = self.editorCardY + 74
    local compact = (w - 58) < 760
    local saveW = compact and 130 or 150
    local priceW = compact and 85 or 100
    local currencyW = compact and 95 or 110
    local directionW = compact and 100 or 120
    self.category:setX(29)
    self.category:setY(self.editorFieldY)
    self.category:setWidth(120)
    self.category:setHeight(24)
    self.fullType:setY(self.editorFieldY)
    self.fullType:setHeight(24)
    local saveButtonX = w - 29 - saveW
    self.saveButton:setX(saveButtonX)
    self.saveButton:setY(self.editorButtonY)
    self.saveButton:setWidth(saveW)
    self.saveButton:setHeight(24)
    self.priceX = saveButtonX - 12 - priceW
    self.price:setX(self.priceX)
    self.price:setY(self.editorFieldY)
    self.price:setWidth(priceW)
    self.price:setHeight(24)
    self.currencyX = self.priceX - 10 - currencyW
    self.currency:setX(self.currencyX)
    self.currency:setY(self.editorFieldY)
    self.currency:setWidth(currencyW)
    self.currency:setHeight(24)
    self.directionX = self.currencyX - 8 - directionW
    self.direction:setX(self.directionX)
    self.direction:setY(self.editorFieldY)
    self.direction:setWidth(directionW)
    self.direction:setHeight(24)
    self.fullType:setX(157)
    self.fullType:setWidth(math.max(compact and 100 or 120, self.directionX - 16 - 157))
    self.clearButton:setX(29)
    self.clearButton:setY(self.editorButtonY)
    self.clearButton:setWidth(80)
    self.clearButton:setHeight(24)
    self.deleteListingButton:setX(117)
    self.deleteListingButton:setY(self.editorButtonY)
    self.deleteListingButton:setWidth(120)
    self.deleteListingButton:setHeight(24)
    self.lastWidth = w
    self.lastHeight = h
end

function ParadiseEconomy.MartAdminView:update()
    ISPanel.update(self)
    if self.width ~= self.lastWidth or self.height ~= self.lastHeight then self:layout() end
    local trade = self:getSelectedTrade()
    local mart = self:getSelectedMart()
    local hasTrade = trade ~= nil
    local hasMart = mart ~= nil
    local hasListing = self:getSelectedListing() ~= nil
    local fullType = self.fullType and self.fullType:getInternalText() or ""
    local price = self.price and self.price:getInternalText() or ""
    local withdrawAmount = self.withdrawAmount:getInternalText()
    local transferAmount = self.transferAmount:getInternalText()
    local finance = trade and trade.finance or nil
    local financeSelected = self.fundsSource.selected == 2
    local hasFundsSource = financeSelected and finance ~= nil or (not financeSelected and hasTrade)
    self.saveDetailsButton:setEnable(hasMart and self.titleEntry:getInternalText() ~= "")
    self.withdrawButton:setEnable(hasFundsSource and withdrawAmount:match("^%d+$") ~= nil and tonumber(withdrawAmount) > 0)
    self.transferButton:setEnable(hasFundsSource and self.transferTarget:getInternalText() ~= ""
        and transferAmount:match("^%d+$") ~= nil and tonumber(transferAmount) > 0)
    local fee = self.dailyFee:getInternalText()
    self.applyFeeButton:setEnable(hasTrade and fee:match("^%d+$") ~= nil)
    self.sweepButton:setEnable(hasTrade)
    self.ownerAccount:setVisible(self.isAdm == true)
    self.assignOwnerButton:setVisible(self.isAdm == true)
    self.assignOwnerButton:setEnable(hasMart and self.isAdm == true
        and self.ownerAccount:getInternalText() ~= "")
    self.addEntryButton:setEnable(hasMart)
    self.deleteListingButton:setEnable(hasListing)
    self.saveButton:setEnable(hasMart and fullType ~= "" and price:match("^%d+$") ~= nil and tonumber(price) > 0)
end

function ParadiseEconomy.MartAdminView:prerender()
    ISPanel.prerender(self)
    local theme = ParadiseEconomy.Theme
    local w = self.width
    local trade = self:getSelectedTrade()
    local mart = self:getSelectedMart()
    local martCount = #self:getMartList()

    self:drawRect(15, 8, 34, 20, theme.gold.a, theme.gold.r, theme.gold.g, theme.gold.b)
    self:drawTextCentre("08", 32, 12, 0.06, 0.07, 0.08, 1, UIFont.Small)
    self:drawText("MART ADMIN VIEW", 57, 10, theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Medium)
    local headerText = trade and ("TREASURY  ·  " .. tostring(trade.tradeId or trade.zoneId or "")
        .. "  ·  " .. tostring(martCount) .. " MARKETS") or "NO TRADE ACCOUNT"
    self:drawTextRight(ParadiseEconomy.fitText(headerText, math.max(200, w - 420), UIFont.Small), w - 15, 12,
        theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawRect(15, 36, w - 30, 1, theme.borderSoft.a, theme.borderSoft.r, theme.borderSoft.g, theme.borderSoft.b)

    ParadiseEconomy.drawCard(self, 15, self.accountCardY, w - 30, self.accountCardH, theme.accentDim)
    self:drawText("MARKET", 29, self.accountLabelY, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    local titleX = self.titleEntry:getX()
    self:drawText("MARKET TITLE", titleX, self.accountLabelY, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText("TRADE TAX / %", 29, self.accountLabel2Y, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText("DAILY FEE", 101, self.accountLabel2Y, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText("FEE CURRENCY", 179, self.accountLabel2Y, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText("CATEGORY TABS ( ; SEPARATED )", self.categoriesEntry:getX(), self.accountLabel2Y,
        theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    if self.isAdm then
        self:drawText("MARKET OWNER ACCOUNT (ADMIN)", 29, self.accountLabel3Y,
            theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    end

    ParadiseEconomy.drawCard(self, 15, self.fundsCardY, w - 30, self.fundsCardH, theme.borderSoft)
    self:drawText("SOURCE", 29, self.fundsLabelY, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    local tradeFunds = trade and trade.digital or {}
    local finance = trade and trade.finance or nil
    local financeFunds = finance and finance.digital or {}
    local function fundsText(label, bucket)
        return label .. "  " .. ParadiseEconomy.formatNumber(ParadiseEconomy.getBalance(bucket, "jimoleon")) .. "j  "
            .. ParadiseEconomy.formatNumber(ParadiseEconomy.getBalance(bucket, "paradisium")) .. "p"
    end
    local balanceLine = fundsText("TREASURY", tradeFunds)
    if finance then balanceLine = balanceLine .. "   ·   " .. fundsText("FINANCE", financeFunds) end
    self:drawTextRight(ParadiseEconomy.fitText(balanceLine, math.max(180, w - 400), UIFont.Small), w - 29,
        self.fundsLabelY, theme.textDim.r, theme.textDim.g, theme.textDim.b, 1, UIFont.Small)

    ParadiseEconomy.drawCard(self, 15, self.inventoryCardY, w - 30, self.inventoryCardH, theme.borderSoft)
    local headings = "MARKET LISTINGS"
    local listings = mart and mart.listings or {}
    self:drawText(headings, 29, self.inventoryHeaderY, theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Small)
    local martName = mart and tostring(mart.title or mart.id) or "No market selected"
    self:drawText("  ·  " .. ParadiseEconomy.fitText(martName, math.max(100, w - 480), UIFont.Small)
        .. "  ·  " .. tostring(#listings) .. " ENTRIES",
        29 + getTextManager():MeasureStringX(UIFont.Small, headings), self.inventoryHeaderY,
        theme.accent.r, theme.accent.g, theme.accent.b, 1, UIFont.Small)
    self:drawRect(29, self.inventoryCardY + 24, w - 58, 1,
        theme.borderSoft.a, theme.borderSoft.r, theme.borderSoft.g, theme.borderSoft.b)
    self:drawText("ITEM CATALOG", 29, self.inventoryLabelY, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText("MART LISTINGS", self.listingX, self.inventoryLabelY,
        theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    if self.listings and #self.listings.items == 0 then
        self:drawTextCentre("No item mart entries match this view.",
            self.listings:getX() + self.listings:getWidth() / 2, self.listings:getY() + 16,
            theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    end

    ParadiseEconomy.drawCard(self, 15, self.editorCardY, w - 30, self.editorCardH, theme.accentDim)
    self:drawText("LISTING EDITOR", 29, self.editorLabelY, theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Small)
    local listing = self:getSelectedListing()
    local editorText = listing and ("EDITING  " .. tostring(listing.fullType)) or "NEW ENTRY"
    self:drawTextRight(ParadiseEconomy.fitText(editorText, math.max(150, w - 420), UIFont.Small), w - 29, self.editorLabelY,
        theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    local fieldLabelY = self.editorFieldLabelY
    self:drawText("CATEGORY", 29, fieldLabelY, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText("ITEM TYPE", 157, fieldLabelY, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText("ACTION", self.directionX, fieldLabelY, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText("CURRENCY", self.currencyX, fieldLabelY, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText("PRICE", self.priceX, fieldLabelY, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
end

function ParadiseEconomy.HUD:new(x, y)
    local obj = ISPanel.new(self, x, y, 270, 46)
    local theme = ParadiseEconomy.Theme
    obj.backgroundColor = { r = theme.windowBg.r, g = theme.windowBg.g, b = theme.windowBg.b, a = 0.82 }
    obj.borderColor = { r = theme.border.r, g = theme.border.g, b = theme.border.b, a = 0.9 }
    obj.moveWithMouse = false
    return obj
end

function ParadiseEconomy.HUD:prerender()
    local clock = UIManager.getClock and UIManager.getClock() or nil
    local x, y = ParadiseEconomy.getHUDPosition(
        getCore():getScreenWidth(),
        self.width,
        self.height,
        clock and clock:isVisible() and clock:getX() or nil,
        clock and clock:isVisible() and clock:getY() or nil
    )
    if self.x ~= x then self:setX(x) end
    if self.y ~= y then self:setY(y) end
    ISPanel.prerender(self)
    local onhand = ParadiseEconomy.getStatePersonal().onhand
    local theme = ParadiseEconomy.Theme
    self:drawTextureScaled(ParadiseEconomy.icons.jimoleon, 5, 4, 18, 18, 1)
    self:drawText("Jimoleons: " .. ParadiseEconomy.getBalance(onhand, "jimoleon"), 28, 5,
        theme.gold.r, theme.gold.g, theme.gold.b, 1, UIFont.Small)
    self:drawTextureScaled(ParadiseEconomy.icons.paradisium, 5, 23, 18, 18, 1)
    self:drawText("Paradisium: " .. ParadiseEconomy.getBalance(onhand, "paradisium"), 28, 24,
        theme.accent.r, theme.accent.g, theme.accent.b, 1, UIFont.Small)
end

function ParadiseEconomy.createHUD()
    if not ParadiseEconomy.isEnabled() then return end
    if ParadiseEconomy.hud then return end
    local clock = UIManager.getClock and UIManager.getClock() or nil
    local x, y = ParadiseEconomy.getHUDPosition(
        getCore():getScreenWidth(),
        270,
        46,
        clock and clock:isVisible() and clock:getX() or nil,
        clock and clock:isVisible() and clock:getY() or nil
    )
    ParadiseEconomy.hud = ParadiseEconomy.HUD:new(x, y)
    ParadiseEconomy.hud:initialise()
    ParadiseEconomy.hud:addToUIManager()
    local pl = getPlayer()
    local settings = pl and ParadiseDev and ParadiseDev.ZoneHUD and ParadiseDev.ZoneHUD.getSettings and ParadiseDev.ZoneHUD.getSettings(pl) or nil
    ParadiseEconomy.hud:setVisible(not settings or settings.economyVisible ~= false)
    ParadiseEconomy.send("requestState")
end
Events.OnCreatePlayer.Remove(ParadiseEconomy.createHUD)
Events.OnCreatePlayer.Add(ParadiseEconomy.createHUD)

ParadiseEconomy.LedgerPanel = ISCollapsableWindow:derive("ParadiseEconomyLedgerPanel")

function ParadiseEconomy.LedgerPanel:new(x, y, w, h)
    local obj = ISCollapsableWindow.new(self, x, y, w, h)
    obj.title = "Paradise Economy - Ledger"
    obj.resizable = true
    obj.minimumWidth = 900
    obj.minimumHeight = 600
    obj.days = {}
    obj.rows = {}
    obj.page = 1
    obj.pages = 1
    obj.count = 0
    obj.selectedDay = nil
    obj.detailLines = {}
    obj.lastWidth = 0
    obj.lastHeight = 0
    return obj
end

function ParadiseEconomy.LedgerPanel:createChildren()
    ISCollapsableWindow.createChildren(self)
    ParadiseEconomy.styleWindow(self)
    self.refreshButton = ISButton:new(0, 0, 110, 25, "REFRESH", self, ParadiseEconomy.LedgerPanel.requestDays)
    self.refreshButton:initialise()
    self:addChild(self.refreshButton)
    self.dayList = ISScrollingListBox:new(15, 70, 250, 300)
    self.dayList:initialise()
    self.dayList.itemheight = 24
    self.dayList.font = UIFont.Small
    self.dayList.doDrawItem = ParadiseEconomy.LedgerPanel.drawDay
    self.dayList:setOnMouseDownFunction(self, ParadiseEconomy.LedgerPanel.selectDay)
    self.dayList.panel = self
    self:addChild(self.dayList)
    self.rowList = ISScrollingListBox:new(275, 70, 300, 300)
    self.rowList:initialise()
    self.rowList.itemheight = 22
    self.rowList.font = UIFont.Small
    self.rowList.doDrawItem = ParadiseEconomy.LedgerPanel.drawRow
    self.rowList:setOnMouseDownFunction(self, ParadiseEconomy.LedgerPanel.selectRow)
    self.rowList.panel = self
    self:addChild(self.rowList)
    self.prevButton = ISButton:new(0, 0, 80, 24, "PREV", self, ParadiseEconomy.LedgerPanel.prevPage)
    self.prevButton:initialise()
    self:addChild(self.prevButton)
    self.nextButton = ISButton:new(0, 0, 80, 24, "NEXT", self, ParadiseEconomy.LedgerPanel.nextPage)
    self.nextButton:initialise()
    self:addChild(self.nextButton)
    ParadiseEconomy.styleTree(self)
    self:layout()
end

function ParadiseEconomy.LedgerPanel:layout()
    if not self.rowList then return end
    local contentX = 15
    local contentW = self.width - 30
    local top = self:titleBarHeight() + 8
    self.refreshButton:setX(contentX + contentW - 110)
    self.refreshButton:setY(top)
    self.refreshButton:setWidth(110)
    local listY = top + 34
    local dayW = 250
    self.dayList:setX(contentX)
    self.dayList:setY(listY)
    self.dayList:setWidth(dayW)
    local detailH = 150
    local listH = math.max(160, self.height - listY - 30 - detailH - 40)
    self.dayList:setHeight(listH)
    self.rowList:setX(contentX + dayW + 10)
    self.rowList:setY(listY)
    self.rowList:setWidth(contentW - dayW - 10)
    self.rowList:setHeight(listH)
    self.pagerY = listY + listH + 8
    self.prevButton:setX(contentX)
    self.prevButton:setY(self.pagerY)
    self.prevButton:setWidth(80)
    self.nextButton:setX(contentX + 86)
    self.nextButton:setY(self.pagerY)
    self.nextButton:setWidth(80)
    self.detailY = self.pagerY + 32
    self.lastWidth, self.lastHeight = self.width, self.height
end

function ParadiseEconomy.LedgerPanel:update()
    ISCollapsableWindow.update(self)
    if not self.rowList then return end
    if self.width ~= self.lastWidth or self.height ~= self.lastHeight then self:layout() end
    self.prevButton:setEnable(self.page > 1)
    self.nextButton:setEnable(self.page < self.pages)
end

function ParadiseEconomy.LedgerPanel:close()
    if ParadiseEconomy.LedgerPanel.ClosePanel then
        ParadiseEconomy.LedgerPanel.ClosePanel()
    else
        self:setVisible(false)
        self:removeFromUIManager()
    end
end

function ParadiseEconomy.LedgerPanel:requestDays()
    ParadiseEconomy.send("ledgerDays")
end

function ParadiseEconomy.LedgerPanel:requestPage(day, page)
    if not day then return end
    ParadiseEconomy.send("ledgerPage", { day = day, page = page or 1 })
end

function ParadiseEconomy.LedgerPanel:prevPage()
    if self.page > 1 then self:requestPage(self.selectedDay, self.page - 1) end
end

function ParadiseEconomy.LedgerPanel:nextPage()
    if self.page < self.pages then self:requestPage(self.selectedDay, self.page + 1) end
end

function ParadiseEconomy.LedgerPanel:applyDays(payload)
    self.days = payload and payload.days or {}
    self.dayList:clear()
    for _, entry in ipairs(self.days) do
        self.dayList:addItem(entry.d, entry)
    end
    local known = false
    if self.selectedDay then
        for _, entry in ipairs(self.days) do
            if entry.d == self.selectedDay then
                known = true
                break
            end
        end
    end
    if not known then
        self.selectedDay = nil
        self.page = 1
        self.pages = 1
        self.count = 0
        self.rows = {}
        self.rowList:clear()
        self.detailLines = {}
    end
    if known then
        self:requestPage(self.selectedDay, self.page)
    elseif self.days[1] then
        self.dayList.selected = 1
        self:selectDay(self.days[1])
    end
end

function ParadiseEconomy.LedgerPanel:applyPage(payload)
    payload = payload or {}
    self.selectedDay = payload.day or self.selectedDay
    self.page = tonumber(payload.page) or 1
    self.pages = math.max(1, tonumber(payload.pages) or 1)
    self.count = tonumber(payload.count) or 0
    self.rows = payload.rows or {}
    self.rowList:clear()
    self.detailLines = {}
    for index, packed in ipairs(self.rows) do
        self.rowList:addItem(tostring(index), { packed = packed, index = index })
    end
end

function ParadiseEconomy.LedgerPanel:selectDay(entry)
    if not entry or not entry.d then return end
    self.selectedDay = entry.d
    self.page = 1
    self:requestPage(self.selectedDay, 1)
end

function ParadiseEconomy.LedgerPanel:selectRow(entry)
    if not entry then return end
    local rec = ParadiseEconomy.Ledger.decode(entry.packed, self.selectedDay)
    local names = {}
    for id, account in pairs(ParadiseEconomy.clientState.accounts or {}) do
        names[id] = account.title or account.name or account.owner or id
    end
    local zones = {}
    for id, zone in pairs(ParadiseEconomy.clientState.zones or {}) do
        zones[id] = zone.name or id
    end
    local pl = getPlayer()
    local title, detail = ParadiseEconomy.Ledger.playerText(rec, {
        user = pl and pl:getUsername() or "",
        accIds = {},
        names = names,
        zones = zones,
    })
    local lines = ParadiseEconomy.Ledger.adminDetail(rec)
    lines[#lines + 1] = "player " .. tostring(title)
    if detail and detail ~= "" then lines[#lines + 1] = "player detail " .. tostring(detail) end
    self.detailLines = lines
end

function ParadiseEconomy.LedgerPanel:drawDay(y, item, alt)
    local entry = item.item
    local theme = ParadiseEconomy.Theme
    if self.selected == item.index then
        self:drawRect(0, y, self.width, self.itemheight - 1, theme.rowSelected.a, theme.rowSelected.r, theme.rowSelected.g, theme.rowSelected.b)
    elseif alt then
        self:drawRect(0, y, self.width, self.itemheight - 1, theme.rowAlt.a, theme.rowAlt.r, theme.rowAlt.g, theme.rowAlt.b)
    end
    self:drawText(tostring(entry.d), 8, y + 5, theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Small)
    self:drawTextRight(tostring(entry.n) .. " ENTRIES", self.width - 8, y + 5,
        theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    return y + self.itemheight
end

function ParadiseEconomy.LedgerPanel:drawRow(y, item, alt)
    local panel = self.panel
    local theme = ParadiseEconomy.Theme
    if self.selected == item.index then
        self:drawRect(0, y, self.width, self.itemheight - 1, theme.rowSelected.a, theme.rowSelected.r, theme.rowSelected.g, theme.rowSelected.b)
    elseif alt then
        self:drawRect(0, y, self.width, self.itemheight - 1, theme.rowAlt.a, theme.rowAlt.r, theme.rowAlt.g, theme.rowAlt.b)
    end
    local day = panel and panel.selectedDay or nil
    local rec = ParadiseEconomy.Ledger.decode(item.item.packed, day)
    self:drawText(ParadiseEconomy.fitText(ParadiseEconomy.Ledger.adminText(rec), self.width - 16, UIFont.Small),
        8, y + 4, theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Small)
    return y + self.itemheight
end

function ParadiseEconomy.LedgerPanel:prerender()
    ISCollapsableWindow.prerender(self)
    local theme = ParadiseEconomy.Theme
    local w = self.width
    self:drawText("DAYS", 15, self.dayList:getY() - 16, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText("PAGE " .. tostring(self.page) .. " / " .. tostring(self.pages) .. "  -  "
        .. tostring(self.count) .. " ENTRIES  -  " .. tostring(self.selectedDay or "-"),
        190, self.pagerY + 5, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    ParadiseEconomy.drawCard(self, 15, self.detailY - 6, w - 30, math.max(60, self.height - self.detailY + 2), theme.borderSoft)
    if #(self.detailLines or {}) == 0 then
        self:drawText("Select a row to inspect the packed record and its player rendering.", 29,
            self.detailY + 8, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    else
        for index = 1, math.min(#self.detailLines, 7) do
            self:drawText(ParadiseEconomy.fitText(self.detailLines[index], w - 54, UIFont.Small),
                29, self.detailY + 6 + (index - 1) * 17,
                theme.textDim.r, theme.textDim.g, theme.textDim.b, 1, UIFont.Small)
        end
    end
    if #(self.days or {}) == 0 then
        self:drawTextCentre("No ledger entries yet.", self.rowList:getX() + self.rowList:getWidth() / 2,
            self.rowList:getY() + 30, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    end
end
