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
    transactions = {},
    orphanedPlayerListings = {},
    market = { itemMart = {}, playerListings = {} },
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
    { key = "transactions", label = "Transactions" },
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
            trade.itemMart = trade.itemMart or market.itemMart or {}
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

function ParadiseEconomy.AccountPanel:refresh()
    if not self.transactions then return end
    local account = self:resolveAccount()
    self.transactions:clear()
    local id = account and account.id or nil
    for _, tx in ipairs(ParadiseEconomy.clientState.transactions or {}) do
        if not id or tx.accountId == id or tx.counterpartyId == id or tx.from == id or tx.to == id then
            self.transactions:addItem(tostring(tx.time), tx)
        end
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
            .. " | Mart items: " .. tostring(#(account.itemMart or {})), 15, 95, 0.75, 0.9, 1, 1, UIFont.Small)
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
    obj.title = "Paradise Economy Accounts"
    obj.resizable = true
    return obj
end

function ParadiseEconomy.AccountBrowser:createChildren()
    ISCollapsableWindow.createChildren(self)
    ParadiseEconomy.styleWindow(self)
    self.typeFilter = ISComboBox:new(15, 40, 180, 25, self, ParadiseEconomy.AccountBrowser.refresh)
    self.typeFilter:initialise()
    for _, entry in ipairs(ParadiseEconomy.accountFilterTypes) do self.typeFilter:addOption(entry.label) end
    self:addChild(self.typeFilter)
    self.search = ISTextEntryBox:new("", 205, 40, 300, 25)
    self.search.target = self
    self.search.onTextChangeFunction = ParadiseEconomy.AccountBrowser.onSearchChanged
    self.search:initialise()
    self.search:instantiate()
    self:addChild(self.search)
    self.refreshButton = ISButton:new(515, 40, 120, 25, "Request State", self, ParadiseEconomy.AccountBrowser.requestState)
    self.refreshButton:initialise()
    self:addChild(self.refreshButton)
    self.accounts = ISScrollingListBox:new(15, 75, self.width - 30, self.height - 125)
    self.accounts:initialise()
    self.accounts.itemheight = 24
    self.accounts.doDrawItem = ParadiseEconomy.AccountBrowser.drawAccount
    self.accounts:setOnMouseDownFunction(self, ParadiseEconomy.AccountBrowser.selectAccount)
    self:addChild(self.accounts)
    self.openButton = ISButton:new(15, self.height - 40, 170, 25, "Open Account", self, ParadiseEconomy.AccountBrowser.openSelected)
    self.openButton:initialise()
    self:addChild(self.openButton)
    ParadiseEconomy.styleTree(self)
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
    self.accounts:setWidth(self.width - 30)
    self.accounts:setHeight(math.max(80, self.height - 125))
    self.openButton:setY(self.height - 40)
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

function ParadiseEconomy.AccountBrowser:drawAccount(y, item, alt)
    if self.selected == item.index then self:drawRect(0, y, self.width, self.itemheight - 1, 0.3, 0.7, 0.35, 0.15) end
    local account = item.item
    self:drawText(ParadiseEconomy.getAccountLabel(account) .. " | " .. tostring(account.id), 8, y + 2, 1, 1, 1, 1, UIFont.Small)
    self:drawTextRight(ParadiseEconomy.formatAccountBalances(account), self.width - 8, y + 2, 0.75, 0.9, 1, 1, UIFont.Small)
    return y + self.itemheight
end

function ParadiseEconomy.AccountBrowser:selectAccount(account)
    self.openButton:setEnable(account ~= nil and self.accounts.selected > 0)
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

function ParadiseEconomy.Panel:new(x, y, w, h)
    local obj = ISCollapsableWindow.new(self, x, y, w, h)
    obj.title = "Paradise Economy"
    obj.resizable = true
    return obj
end

function ParadiseEconomy.Panel:createChildren()
    ISCollapsableWindow.createChildren(self)
    ParadiseEconomy.styleWindow(self)
    self.currency = ISComboBox:new(15, 55, 150, 25, self)
    self.currency:initialise()
    self.currency:addOption("jimoleon")
    self.currency:addOption("paradisium")
    self:addChild(self.currency)
    self.amount = ISTextEntryBox:new("", 175, 55, 110, 25)
    self.amount:initialise()
    self.amount:instantiate()
    self.amount:setOnlyNumbers(true)
    self:addChild(self.amount)
    self.target = ISTextEntryBox:new("Player username", 295, 55, 180, 25)
    self.target:initialise()
    self:addChild(self.target)
    local labels = { { "Deposit", "deposit" }, { "Withdraw", "withdraw" }, { "To Wallet", "withdrawWallet" }, { "Send", "transfer" } }
    for index, data in ipairs(labels) do
        local button = ISButton:new(15 + (index - 1) * 118, 90, 108, 25, data[1], self, ParadiseEconomy.Panel.onAction)
        button:initialise()
        button.internal = data[2]
        self:addChild(button)
    end
    self.martButton = ISButton:new(487, 90, 130, 25, "Tradeshop", self, ParadiseEconomy.Panel.openMart)
    self.martButton:initialise()
    self:addChild(self.martButton)
    self.transactions = ISScrollingListBox:new(15, 130, self.width - 30, self.height - 170)
    self.transactions:initialise()
    self.transactions.itemheight = 24
    self.transactions.doDrawItem = ParadiseEconomy.Panel.drawTransaction
    self:addChild(self.transactions)
    ParadiseEconomy.styleTree(self)
end

function ParadiseEconomy.Panel:update()
    ISCollapsableWindow.update(self)
    local canUseMarket = ParadiseEconomy.canOpenMart(getPlayer())
    self.martButton:setEnable(canUseMarket)
    self.martButton:setTooltip(canUseMarket and nil or "Enter a Trade Zone to use the Tradeshop")
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
    if ParadiseEconomy.canOpenMart(getPlayer()) and ParadiseEconomy.MartPanel.OpenPanel then
        ParadiseEconomy.MartPanel.OpenPanel()
    end
end

function ParadiseEconomy.Panel:onAction(button)
    ParadiseEconomy.send(button.internal, {
        currency = self.currency.options[self.currency.selected],
        amount = self.amount:getInternalText(),
        username = self.target:getInternalText(),
    })
end

function ParadiseEconomy.Panel:drawTransaction(y, item, alt)
    local tx = item.item
    self:drawText(tostring(tx.action) .. " | " .. tostring(tx.amount) .. " " .. tostring(tx.currency)
        .. " | " .. tostring(tx.from) .. " -> " .. tostring(tx.to), 8, y + 4, 1, 1, 1, 1, UIFont.Small)
    return y + self.itemheight
end

function ParadiseEconomy.Panel:refresh()
    local state = ParadiseEconomy.clientState
    self.transactions:clear()
    for _, tx in ipairs(state.transactions or {}) do self.transactions:addItem(tostring(tx.time), tx) end
end

function ParadiseEconomy.Panel:prerender()
    ISCollapsableWindow.prerender(self)
    local state = ParadiseEconomy.clientState
    local personal = ParadiseEconomy.getStatePersonal()
    self:drawTextureScaled(ParadiseEconomy.icons.jimoleon, 15, 27, 22, 22, 1)
    self:drawText("Digital J: " .. ParadiseEconomy.getBalance(personal.digital, "jimoleon"), 42, 30, 0.85, 0.9, 0.95, 1, UIFont.Small)
    self:drawTextureScaled(ParadiseEconomy.icons.paradisium, 155, 27, 22, 22, 1)
    self:drawText("P: " .. ParadiseEconomy.getBalance(personal.digital, "paradisium"), 182, 30, 0.45, 1, 0.8, 1, UIFont.Small)
    self:drawText("On Hand: " .. ParadiseEconomy.formatBalances(personal.onhand), 330, 30, 1, 0.85, 0.25, 1, UIFont.Small)
    if state.message then self:drawText(state.message, 15, self.height - 28, 1, 1, 1, 1, UIFont.Small) end
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

function ParadiseEconomy.MartPanel:new(x, y, w, h)
    local obj = ISCollapsableWindow.new(self, x, y, w, h)
    obj.title = "Tradeshop"
    obj.resizable = true
    obj.minimumWidth = 900
    obj.minimumHeight = 580
    obj.tab = "browse"
    obj.martDirection = "buy"
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

    self.tabBrowse = ISButton:new(15, 30, 110, 26, "Browse", self, ParadiseEconomy.MartPanel.onTab)
    self.tabBrowse.internal = "browse"
    self.tabBrowse.tooltip = "Active player trade posts in this zone"
    self.tabBrowse:initialise()
    self:addChild(self.tabBrowse)
    self.tabStore = ISButton:new(131, 30, 110, 26, "My Store", self, ParadiseEconomy.MartPanel.onTab)
    self.tabStore.internal = "store"
    self.tabStore.tooltip = "Your merchant store, lease, earnings and posts"
    self.tabStore:initialise()
    self:addChild(self.tabStore)
    self.tabMart = ISButton:new(247, 30, 120, 26, "Item Mart", self, ParadiseEconomy.MartPanel.onTab)
    self.tabMart.internal = "mart"
    self.tabMart.tooltip = "Buy from or sell to the zone item mart"
    self.tabMart:initialise()
    self:addChild(self.tabMart)
    self.manageButton = ISButton:new(self.width - 170, 30, 155, 26, "Trade Management", self, ParadiseEconomy.MartPanel.openManagement)
    self.manageButton.tooltip = "Renew merchant leases and review every player post in your trade zones"
    self.manageButton:initialise()
    self:addChild(self.manageButton)

    self.browseSearch = ISTextEntryBox:new("", 15, 86, self.width - 30, 25)
    self.browseSearch.target = self
    self.browseSearch.onTextChangeFunction = ParadiseEconomy.MartPanel.onBrowseSearchChanged
    self.browseSearch.tooltip = "Search by item, seller, merchant id or store title"
    self.browseSearch:initialise()
    self.browseSearch:instantiate()
    self:addChild(self.browseSearch)
    self.browseList = ISScrollingListBox:new(15, 118, self.width - 30, 300)
    self.browseList:initialise()
    self.browseList.itemheight = 42
    self.browseList.font = UIFont.Small
    self.browseList.doDrawItem = ParadiseEconomy.MartPanel.drawBrowseListing
    self.browseList:setOnMouseDownFunction(self, ParadiseEconomy.MartPanel.onBrowseSelect)
    local browseMouseDown = self.browseList.onMouseDown
    self.browseList.onMouseDown = function(list, x, y)
        if browseMouseDown then browseMouseDown(list, x, y) end
        local row = list:rowAt(x, y)
        if row < 1 or row > #list.items then return end
        self:beginListingDrag(list)
    end
    self:addChild(self.browseList)
    self.browseBuyButton = ISButton:new(0, 0, 120, 26, "Buy Selected", self, ParadiseEconomy.MartPanel.onBrowseBuy)
    self.browseBuyButton:initialise()
    self:addChild(self.browseBuyButton)

    self.storeTitle = ISTextEntryBox:new("", 15, 94, 230, 25)
    self.storeTitle.tooltip = "Your merchant store title in this trade zone"
    self.storeTitle:initialise()
    self.storeTitle:instantiate()
    self:addChild(self.storeTitle)
    self.renameStoreButton = ISButton:new(253, 94, 115, 25, "Rename Store", self, ParadiseEconomy.MartPanel.onRenameStore)
    self.renameStoreButton:initialise()
    self:addChild(self.renameStoreButton)
    self.renewLeaseButton = ISButton:new(0, 94, 125, 25, "Renew Lease", self, ParadiseEconomy.MartPanel.onRenewLease)
    self.renewLeaseButton.tooltip = "Extend this merchant store lease"
    self.renewLeaseButton:initialise()
    self:addChild(self.renewLeaseButton)
    self.collectButton = ISButton:new(0, 126, 125, 25, "Collect Earnings", self, ParadiseEconomy.MartPanel.onCollect)
    self.collectButton:initialise()
    self:addChild(self.collectButton)

    self.invSearch = ISTextEntryBox:new("", 15, 178, 250, 25)
    self.invSearch.target = self
    self.invSearch.onTextChangeFunction = ParadiseEconomy.MartPanel.onInventorySearchChanged
    self.invSearch.tooltip = "Search your carried items"
    self.invSearch:initialise()
    self.invSearch:instantiate()
    self:addChild(self.invSearch)
    self.invList = ISScrollingListBox:new(15, 208, 300, 200)
    self.invList:initialise()
    self.invList.itemheight = 24
    self.invList.font = UIFont.Small
    self.invList.doDrawItem = ParadiseEconomy.MartPanel.drawInventoryItem
    self.invList:setOnMouseDownFunction(self, ParadiseEconomy.MartPanel.onInventorySelect)
    self:addChild(self.invList)
    self.storePrice = ISTextEntryBox:new("", 15, 420, 80, 25)
    self.storePrice.tooltip = "Listing price"
    self.storePrice:initialise()
    self.storePrice:instantiate()
    self.storePrice:setOnlyNumbers(true)
    self:addChild(self.storePrice)
    self.storeCurrency = ISComboBox:new(100, 420, 105, 25, self)
    self.storeCurrency:initialise()
    self.storeCurrency:addOption("jimoleon")
    self.storeCurrency:addOption("paradisium")
    self:addChild(self.storeCurrency)
    self.postButton = ISButton:new(210, 420, 100, 25, "Post Item", self, ParadiseEconomy.MartPanel.onPostSelected)
    self.postButton:initialise()
    self:addChild(self.postButton)
    self.myListings = ISScrollingListBox:new(330, 178, 300, 260)
    self.myListings:initialise()
    self.myListings.itemheight = 40
    self.myListings.font = UIFont.Small
    self.myListings.doDrawItem = ParadiseEconomy.MartPanel.drawStoreListing
    self.myListings:setOnMouseDownFunction(self, ParadiseEconomy.MartPanel.onStoreListingSelect)
    self:addChild(self.myListings)
    self.cancelButton = ISButton:new(0, 0, 170, 26, "Cancel Listing", self, ParadiseEconomy.MartPanel.onCancelListing)
    self.cancelButton:initialise()
    self:addChild(self.cancelButton)

    self.category = ISComboBox:new(15, 86, 190, 25, self, ParadiseEconomy.MartPanel.onCategoryChanged)
    self.category:initialise()
    self:addChild(self.category)
    self.buyButton = ISButton:new(215, 86, 90, 25, "Buy", self, ParadiseEconomy.MartPanel.setDirection)
    self.buyButton.internal = "buy"
    self.buyButton:initialise()
    self:addChild(self.buyButton)
    self.sellButton = ISButton:new(313, 86, 90, 25, "Sell", self, ParadiseEconomy.MartPanel.setDirection)
    self.sellButton.internal = "sell"
    self.sellButton:initialise()
    self:addChild(self.sellButton)
    self.quantity = ISTextEntryBox:new("1", self.width - 275, 86, 70, 25)
    self.quantity.tooltip = "Quantity"
    self.quantity:initialise()
    self.quantity:instantiate()
    self.quantity:setOnlyNumbers(true)
    self:addChild(self.quantity)
    self.martTradeButton = ISButton:new(self.width - 185, 86, 170, 25, "Buy Selected", self, ParadiseEconomy.MartPanel.onMartTrade)
    self.martTradeButton:initialise()
    self:addChild(self.martTradeButton)
    self.martList = ISScrollingListBox:new(15, 122, self.width - 30, 300)
    self.martList:initialise()
    self.martList.itemheight = 26
    self.martList.font = UIFont.Small
    self.martList.doDrawItem = ParadiseEconomy.MartPanel.drawMartListing
    self.martList:setOnMouseDownFunction(self, ParadiseEconomy.MartPanel.onMartSelect)
    self:addChild(self.martList)

    ParadiseEconomy.styleWindow(self)
    ParadiseEconomy.styleTree(self)
    self:installDropCatchers()
    self:refreshAll()
    self:applyTab()
    self:layout()
end

function ParadiseEconomy.MartPanel:getMarket()
    return ParadiseEconomy.clientState.market or {}
end

function ParadiseEconomy.MartPanel:getZoneId()
    return self:getMarket().tradeZoneId
end

function ParadiseEconomy.MartPanel:getTrade()
    return self:getMarket().trade
end

function ParadiseEconomy.MartPanel:getMerchant()
    local zoneId = self:getZoneId()
    if not zoneId then return nil end
    for _, merchant in ipairs(ParadiseEconomy.clientState.merchants or {}) do
        if merchant.zoneId == zoneId then return merchant end
    end
    return nil
end

function ParadiseEconomy.MartPanel:getTaxPercent()
    local trade = self:getTrade()
    if trade then return ParadiseEconomy.getTradeTaxPercent(trade) end
    return ParadiseEconomy.getTradeTaxPercentFor(self:getZoneId())
end

function ParadiseEconomy.MartPanel:setTabState(button, active)
    local theme = ParadiseEconomy.Theme
    button.backgroundColor = active and theme.accentDim or theme.buttonBg
    button.backgroundColorMouseOver = active and theme.accentDim or theme.buttonHover
    button.textColor = active and theme.text or theme.textDim
end

function ParadiseEconomy.MartPanel:applyTab()
    local isBrowse = self.tab == "browse"
    local isStore = self.tab == "store"
    local isMart = self.tab == "mart"
    self.browseSearch:setVisible(isBrowse)
    self.browseList:setVisible(isBrowse)
    self.browseBuyButton:setVisible(isBrowse)
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
    self.category:setVisible(isMart)
    self.buyButton:setVisible(isMart)
    self.sellButton:setVisible(isMart)
    self.quantity:setVisible(isMart)
    self.martTradeButton:setVisible(isMart)
    self.martList:setVisible(isMart)
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
    local contentY = 86
    local footerY = h - 34
    self.tabBrowse:setX(15)
    self.tabBrowse:setY(30)
    self.tabStore:setX(131)
    self.tabStore:setY(30)
    self.tabMart:setX(247)
    self.tabMart:setY(30)
    self.manageButton:setX(w - 170)
    self.manageButton:setY(30)

    self.browseSearch:setX(15)
    self.browseSearch:setY(contentY)
    self.browseSearch:setWidth(w - 30)
    local detailW = math.min(340, math.max(270, w * 0.32))
    local listW = math.max(280, w - 40 - detailW)
    local detailX = 15 + listW + 10
    detailW = w - 15 - detailX
    local listY = contentY + 32
    self.browseList:setX(15)
    self.browseList:setY(listY)
    self.browseList:setWidth(listW)
    self.browseList:setHeight(footerY - listY)
    self.browseDetailX = detailX
    self.browseDetailY = listY
    self.browseDetailW = detailW
    self.browseDetailH = math.max(140, footerY - 44 - listY)
    self.browseBuyButton:setX(detailX + 10)
    self.browseBuyButton:setY(footerY - 34)
    self.browseBuyButton:setWidth(detailW - 20)

    self.storeTitle:setX(15)
    self.storeTitle:setY(contentY + 8)
    self.storeTitle:setWidth(math.max(110, math.min(240, w * 0.28)))
    self.renameStoreButton:setX(23 + self.storeTitle:getWidth())
    self.renameStoreButton:setY(contentY + 8)
    self.renewLeaseButton:setX(w - 140)
    self.renewLeaseButton:setY(contentY + 8)
    self.collectButton:setX(w - 140)
    self.collectButton:setY(contentY + 42)
    local invTop = contentY + 92
    local leftW = math.min(330, math.max(280, w * 0.33))
    local rightX = 15 + leftW + 15
    self.invSearch:setX(15)
    self.invSearch:setY(invTop)
    self.invSearch:setWidth(leftW)
    self.invList:setX(15)
    self.invList:setY(invTop + 30)
    self.invList:setWidth(leftW)
    self.invList:setHeight(math.max(60, footerY - (invTop + 30) - 62))
    local postY = self.invList:getY() + self.invList:getHeight() + 8
    self.storePrice:setX(15)
    self.storePrice:setY(postY)
    self.storeCurrency:setX(100)
    self.storeCurrency:setY(postY)
    self.postButton:setX(210)
    self.postButton:setY(postY)
    self.postButton:setWidth(math.max(80, leftW - 195))
    self.myListings:setX(rightX)
    self.myListings:setY(invTop)
    self.myListings:setWidth(math.max(200, w - 15 - rightX))
    self.myListings:setHeight(math.max(60, footerY - invTop - 40))
    self.cancelButton:setX(w - 185)
    self.cancelButton:setY(footerY - 32)

    self.category:setX(15)
    self.category:setY(contentY)
    self.category:setWidth(190)
    self.buyButton:setX(215)
    self.buyButton:setY(contentY)
    self.sellButton:setX(313)
    self.sellButton:setY(contentY)
    self.quantity:setX(w - 275)
    self.quantity:setY(contentY)
    self.martTradeButton:setX(w - 185)
    self.martTradeButton:setY(contentY)
    self.martList:setX(15)
    self.martList:setY(contentY + 36)
    self.martList:setWidth(w - 30)
    self.martList:setHeight(footerY - (contentY + 36))
    self.lastWidth = w
    self.lastHeight = h
end

function ParadiseEconomy.MartPanel:refreshAll()
    self:refreshBrowse()
    self:refreshStore()
    self:refreshInventory()
    self:refreshCategories()
    self:refreshMart()
end

function ParadiseEconomy.MartPanel:refreshMarket()
    self:refreshAll()
end

function ParadiseEconomy.MartPanel:refreshBrowse()
    if not self.browseList then return end
    local previous = self.selectedBrowseId
    local search = string.lower(self.browseSearch and self.browseSearch:getInternalText() or "")
    self.browseList:clear()
    self.browseCache = {}
    for _, listing in ipairs(self:getMarket().playerListings or {}) do
        local name = listing.itemData and listing.itemData.name or listing.fullType or "Item"
        local text = string.lower(tostring(name) .. " " .. tostring(listing.fullType or "") .. " "
            .. tostring(listing.seller or "") .. " " .. tostring(listing.merchantAccountId or "") .. " "
            .. tostring(listing.merchantTitle or ""))
        if search == "" or text:find(search, 1, true) then
            self.browseList:addItem(name, listing)
            self.browseCache[#self.browseCache + 1] = listing
        end
    end
    local selected
    if previous then
        for int, listing in ipairs(self.browseCache) do
            if tostring(listing.id) == tostring(previous) then selected = int end
        end
    end
    if selected then
        self.browseList.selected = selected
    elseif #self.browseCache == 0 then
        self.browseList.selected = 0
    else
        self.browseList.selected = 1
    end
    self.selectedBrowseId = self.browseList.selected > 0 and self.browseCache[self.browseList.selected].id or nil
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

function ParadiseEconomy.MartPanel:getMartItems()
    local market = self:getMarket()
    if market.itemMart and #market.itemMart > 0 then return market.itemMart end
    local trade = self:getTrade()
    return trade and trade.itemMart or {}
end

function ParadiseEconomy.MartPanel:getCategoryOptions()
    local seen = {}
    local categories = {}
    for _, listing in ipairs(self:getMartItems()) do
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
    if not self.category then return end
    local selected = self.category.options[self.category.selected] or "All Categories"
    self.category:clear()
    self.category:addOption("All Categories")
    local index = 1
    for _, name in ipairs(self:getCategoryOptions()) do
        self.category:addOption(name)
        if name == selected then index = #self.category.options end
    end
    self.category.selected = index
end

function ParadiseEconomy.MartPanel:getSelectedCategory()
    local name = self.category and self.category.options[self.category.selected] or nil
    if not name or name == "All Categories" then return nil end
    return name
end

function ParadiseEconomy.MartPanel:refreshMart()
    if not self.martList then return end
    local previous = self.selectedMartListingId
    local category = self:getSelectedCategory()
    self.martList:clear()
    self.martCache = {}
    for _, listing in ipairs(self:getMartItems()) do
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

function ParadiseEconomy.MartPanel.onBrowseSelect(target, listing)
    if target and listing then target.selectedBrowseId = listing.id end
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

function ParadiseEconomy.MartPanel:onBrowseBuy()
    local listing = self:getSelectedBrowse()
    if listing then ParadiseEconomy.send("playerShopBuy", { listingId = listing.id }) end
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
    ParadiseEconomy.send("merchantCollect")
end

function ParadiseEconomy.MartPanel:onPostSelected()
    local item = self:getSelectedInventoryItem()
    local price = self.storePrice:getInternalText()
    if not item or not tonumber(price) or tonumber(price) <= 0 then return end
    ParadiseEconomy.send("playerShopPost", {
        itemId = item:getID(),
        currency = self.storeCurrency.options[self.storeCurrency.selected],
        amount = price,
    })
    self.storePrice:setText("")
end

function ParadiseEconomy.MartPanel:onCancelListing()
    local listing = self:getSelectedStoreListing()
    if listing then ParadiseEconomy.send("playerShopCancel", { listingId = listing.id }) end
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
    if not pl or not ParadiseEconomy.canOpenMart(pl) then return false end
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
    end)
end

function ParadiseEconomy.MartPanel:beginListingDrag(list)
    if not list or list:isMouseOverScrollBar() then return end
    local listing = self:getSelectedBrowse()
    local pl = getPlayer()
    if not listing or listing.expired or not pl then return end
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
    if not listing then return end
    ParadiseEconomy.send(self.martDirection == "buy" and "marketBuy" or "marketSell", {
        category = listing.category,
        fullType = listing.fullType,
        quantity = self.quantity:getInternalText(),
    })
end

function ParadiseEconomy.MartPanel:update()
    ISCollapsableWindow.update(self)
    if not ParadiseEconomy.canOpenMart(getPlayer()) and ParadiseEconomy.MartPanel.ClosePanel then
        ParadiseEconomy.MartPanel.ClosePanel()
        return
    end
    if self.width ~= self.lastWidth or self.height ~= self.lastHeight then self:layout() end
    self.isAdm = ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(getPlayer()) or false
    local canManage = ParadiseEconomy.canManageTradeZones()
    self.manageButton:setVisible(canManage)
    self.manageButton:setEnable(canManage)
    if self.tab == "browse" then
        local listing = self:getSelectedBrowse()
        local pl = getPlayer()
        local own = listing and pl and ParadiseEconomy.usernameKey(listing.seller) == ParadiseEconomy.usernameKey(pl:getUsername())
        self.browseBuyButton:setEnable(listing ~= nil and not listing.expired and not own)
    elseif self.tab == "store" then
        local merchant = self:getMerchant()
        self.merchant = merchant
        if merchant and not self.storeTitle:isFocused() and self.storeTitle:getInternalText() ~= tostring(merchant.title or "") then
            self.storeTitle:setText(tostring(merchant.title or ""))
        end
        local price = tonumber(self.storePrice:getInternalText())
        local leaseDays = tonumber(self:getTrade() and self:getTrade().merchantLeaseDays) or 0
        self.storeTitle:setEnable(merchant ~= nil)
        self.renameStoreButton:setEnable(merchant ~= nil and self.storeTitle:getInternalText() ~= "")
        self.renewLeaseButton:setEnable(merchant ~= nil and leaseDays > 0)
        self.collectButton:setEnable(ParadiseEconomy.hasMoney(ParadiseEconomy.getMerchantEarnings(self:getZoneId())))
        self.postButton:setEnable(self:getSelectedInventoryItem() ~= nil and price ~= nil and price > 0)
        self.cancelButton:setEnable(self:getSelectedStoreListing() ~= nil)
    elseif self.tab == "mart" then
        local listing = self:getSelectedMartListing()
        local quantity = tonumber(self.quantity:getInternalText())
        self.martTradeButton:setEnable(listing ~= nil and quantity ~= nil and quantity > 0)
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

function ParadiseEconomy.MartPanel:drawBrowseListing(y, item, alt)
    local listing = item.item
    local theme = ParadiseEconomy.Theme
    if self.selected == item.index then
        self:drawRect(0, y, self.width, self.itemheight - 1, theme.rowSelected.a, theme.rowSelected.r, theme.rowSelected.g, theme.rowSelected.b)
    elseif alt then
        self:drawRect(0, y, self.width, self.itemheight - 1, theme.rowAlt.a, theme.rowAlt.r, theme.rowAlt.g, theme.rowAlt.b)
    end
    local name = listing.itemData and listing.itemData.name or listing.fullType or "Item"
    self:drawText(ParadiseEconomy.fitText(name, self.width - 160, UIFont.Small), 8, y + 5,
        theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Small)
    self:drawTextRight(tostring(listing.price) .. " " .. tostring(listing.currency), self.width - 8, y + 5,
        theme.gold.r, theme.gold.g, theme.gold.b, 1, UIFont.Small)
    local lease = ParadiseEconomy.getLeaseInfo(listing.merchantExpiresAt)
    local color = ParadiseEconomy.getLeaseColor(lease.status)
    local subtitle = tostring(listing.seller) .. "  |  " .. tostring(listing.merchantAccountId or "merchant")
    self:drawText(ParadiseEconomy.fitText(subtitle, self.width - 170, UIFont.Small), 8, y + 22,
        theme.textDim.r, theme.textDim.g, theme.textDim.b, 1, UIFont.Small)
    self:drawTextRight(lease.label, self.width - 8, y + 22, color.r, color.g, color.b, 1, UIFont.Small)
    return y + self.itemheight
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
    self:drawText(ParadiseEconomy.fitText(item.text, self.width - 16, UIFont.Small), 8, y + 4,
        theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Small)
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
    local action = listing.direction == "sell" and "Mart Sells" or "Mart Buys"
    self:drawText("[" .. tostring(listing.category or "General") .. "]", 8, y + 6,
        theme.accent.r, theme.accent.g, theme.accent.b, 1, UIFont.Small)
    self:drawText(ParadiseEconomy.fitText(tostring(listing.fullType), self.width - 370, UIFont.Small), 150, y + 6,
        theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Small)
    self:drawText(action, self.width - 210, y + 6, theme.textDim.r, theme.textDim.g, theme.textDim.b, 1, UIFont.Small)
    self:drawTextRight(tostring(listing.price) .. " " .. tostring(listing.currency), self.width - 10, y + 6,
        theme.gold.r, theme.gold.g, theme.gold.b, 1, UIFont.Small)
    return y + self.itemheight
end

function ParadiseEconomy.MartPanel:drawBrowseDetail()
    local theme = ParadiseEconomy.Theme
    local x, y = self.browseDetailX, self.browseDetailY
    local w, h = self.browseDetailW, self.browseDetailH
    ParadiseEconomy.drawCard(self, x, y, w, h, theme.accent)
    local listing = self:getSelectedBrowse()
    if not listing then
        self:drawText("Select a player shop listing.", x + 12, y + 12,
            theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
        return
    end
    local name = listing.itemData and listing.itemData.name or listing.fullType or "Item"
    self:drawText(ParadiseEconomy.fitText(name, w - 24, UIFont.Medium), x + 12, y + 10,
        theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Medium)
    local summary = listing.itemData and ParadiseEconomy.ItemData.getSummary(listing.itemData) or ""
    self:drawText(ParadiseEconomy.fitText(summary, w - 24, UIFont.Small), x + 12, y + 32,
        theme.textDim.r, theme.textDim.g, theme.textDim.b, 1, UIFont.Small)
    self:drawRect(x + 12, y + 52, w - 24, 1, theme.borderSoft.a, theme.borderSoft.r, theme.borderSoft.g, theme.borderSoft.b)
    local lease = ParadiseEconomy.getLeaseInfo(listing.merchantExpiresAt)
    local leaseColor = ParadiseEconomy.getLeaseColor(lease.status)
    local function row(label, value, yy, color)
        color = color or theme.textDim
        self:drawText(label, x + 12, yy, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
        self:drawTextRight(ParadiseEconomy.fitText(tostring(value), w - 120, UIFont.Small), x + w - 12, yy,
            color.r, color.g, color.b, 1, UIFont.Small)
    end
    row("Seller", listing.seller or "-", y + 60, theme.text)
    row("Store", listing.merchantTitle or "-", y + 78, theme.text)
    row("Merchant ID", listing.merchantAccountId or "-", y + 96, theme.accent)
    row("Lease", lease.label, y + 114, leaseColor)
    row("Price", tostring(listing.price) .. " " .. tostring(listing.currency), y + 138, theme.gold)
    local percent = tonumber(listing.taxPercent) or self:getTaxPercent()
    local payout, tax = ParadiseEconomy.getPlayerShopPayout(listing.price, percent)
    row("Tax (" .. string.format("%g", percent or 0) .. "%)", tostring(tax) .. " " .. tostring(listing.currency), y + 156, theme.warn)
    row("Seller receives", tostring(payout) .. " " .. tostring(listing.currency), y + 174, theme.green)
    row("Posted", ParadiseEconomy.formatTimestamp(listing.createdAt), y + 198, theme.textDim)
    local pl = getPlayer()
    if pl and ParadiseEconomy.usernameKey(listing.seller) == ParadiseEconomy.usernameKey(pl:getUsername()) then
        self:drawText("This is your listing. Cancel it from My Store.", x + 12, y + 220,
            theme.warn.r, theme.warn.g, theme.warn.b, 1, UIFont.Small)
    end
end

function ParadiseEconomy.MartPanel:prerender()
    ISCollapsableWindow.prerender(self)
    local theme = ParadiseEconomy.Theme
    local market = self:getMarket()
    local trade = self:getTrade()
    local zoneText = "Zone: " .. tostring(market.tradeZoneTitle or "No Trade Zone")
    if trade then zoneText = zoneText .. "  |  Trade: " .. tostring(trade.title or trade.tradeId or trade.id) end
    self:drawText(ParadiseEconomy.fitText(zoneText, self.width - 360, UIFont.Small), 15, 61,
        theme.textDim.r, theme.textDim.g, theme.textDim.b, 1, UIFont.Small)
    local leaseDays = trade and trade.merchantLeaseDays or market.leaseDays
    local leaseText = (tonumber(leaseDays) or 0) > 0 and (tostring(math.floor(tonumber(leaseDays))) .. " day leases") or "No lease limit"
    self:drawTextRight(leaseText .. "  |  Tax " .. string.format("%g", self:getTaxPercent() or 0) .. "%",
        self.width - 15, 61, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)

    if self.tab == "browse" then
        self:drawBrowseDetail()
    elseif self.tab == "store" then
        ParadiseEconomy.drawCard(self, 15, 86, self.width - 30, 80, theme.accentDim)
        local merchant = self:getMerchant()
        if merchant then
            local lease = ParadiseEconomy.getLeaseInfo(merchant.expiresAt)
            local color = ParadiseEconomy.getLeaseColor(lease.status)
            self:drawTextRight("Lease: " .. lease.label, self.renewLeaseButton:getX() - 12, 94,
                color.r, color.g, color.b, 1, UIFont.Small)
            self:drawText("Earnings: " .. ParadiseEconomy.formatBalances(merchant.earnings), 15, 128,
                theme.gold.r, theme.gold.g, theme.gold.b, 1, UIFont.Small)
            local merchantText = "Merchant: " .. tostring(merchant.id) .. "  |  Owner: " .. tostring(merchant.owner)
            self:drawTextRight(ParadiseEconomy.fitText(merchantText, math.max(120, self.collectButton:getX() - 250), UIFont.Small),
                self.collectButton:getX() - 12, 128, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
        else
            self:drawText("No merchant store in this zone yet. Post a carried item to open one.", 15, 98,
                theme.warn.r, theme.warn.g, theme.warn.b, 1, UIFont.Small)
            self:drawText("Your store is created automatically with your first post.", 15, 120,
                theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
        end
        self:drawText("Carried items", 15, 164, theme.accent.r, theme.accent.g, theme.accent.b, 1, UIFont.Small)
        self:drawText("Your trade posts", self.myListings:getX(), 164,
            theme.accent.r, theme.accent.g, theme.accent.b, 1, UIFont.Small)
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
    local message = ParadiseEconomy.clientState.message
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
    obj.minimumHeight = 640
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

    self.zone = ISComboBox:new(15, 30, 300, 25, self, ParadiseEconomy.TradeManagementPanel.onZoneChanged)
    self.zone.tooltip = "Trade zone to manage"
    self.zone:initialise()
    self:addChild(self.zone)
    self.leaseDays = ISTextEntryBox:new(325, 30, 64, 25)
    self.leaseDays.tooltip = "Merchant lease days for this trade zone (0 disables leases)"
    self.leaseDays:initialise()
    self.leaseDays:instantiate()
    self.leaseDays:setOnlyNumbers(true)
    self:addChild(self.leaseDays)
    self.applyLeaseButton = ISButton:new(397, 30, 150, 25, "Apply Lease Days", self, ParadiseEconomy.TradeManagementPanel.applyLeaseDays)
    self.applyLeaseButton.tooltip = "Grant this lease duration to every merchant in the zone"
    self.applyLeaseButton:initialise()
    self:addChild(self.applyLeaseButton)

    self.tabMerchants = ISButton:new(15, 64, 110, 26, "Merchants", self, ParadiseEconomy.TradeManagementPanel.onTab)
    self.tabMerchants.internal = "merchants"
    self.tabMerchants.tooltip = "Merchant leases in the selected trade zone"
    self.tabMerchants:initialise()
    self:addChild(self.tabMerchants)
    self.tabPosts = ISButton:new(131, 64, 120, 26, "Player Posts", self, ParadiseEconomy.TradeManagementPanel.onTab)
    self.tabPosts.internal = "posts"
    self.tabPosts.tooltip = "Every player trade post in the selected zone, including expired posts"
    self.tabPosts:initialise()
    self:addChild(self.tabPosts)
    self.tabMart = ISButton:new(257, 64, 155, 26, "Item Mart & Funds", self, ParadiseEconomy.TradeManagementPanel.onTab)
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
    self.merchantOwnerButton = ISButton:new(0, 0, 170, 26, "Open Owner Account", self, ParadiseEconomy.TradeManagementPanel.openMerchantOwner)
    self.merchantOwnerButton:initialise()
    self:addChild(self.merchantOwnerButton)

    self.postMerchant = ISComboBox:new(15, 100, 260, 25, self, ParadiseEconomy.TradeManagementPanel.onPostMerchantChanged)
    self.postMerchant.tooltip = "Filter player posts by merchant"
    self.postMerchant:initialise()
    self:addChild(self.postMerchant)
    self.postSearch = ISTextEntryBox:new(283, 100, 300, 25)
    self.postSearch.target = self
    self.postSearch.onTextChangeFunction = ParadiseEconomy.TradeManagementPanel.onPostSearchChanged
    self.postSearch.tooltip = "Search posts by item, seller or merchant id"
    self.postSearch:initialise()
    self.postSearch:instantiate()
    self:addChild(self.postSearch)
    self.postList = ISScrollingListBox:new(15, 132, 330, 300)
    self.postList:initialise()
    self.postList.itemheight = 44
    self.postList.font = UIFont.Small
    self.postList.doDrawItem = ParadiseEconomy.TradeManagementPanel.drawPost
    self.postList:setOnMouseDownFunction(self, ParadiseEconomy.TradeManagementPanel.onPostSelect)
    self:addChild(self.postList)
    self.postOwnerButton = ISButton:new(0, 0, 190, 26, "Open Seller Account", self, ParadiseEconomy.TradeManagementPanel.openPostSeller)
    self.postOwnerButton:initialise()
    self:addChild(self.postOwnerButton)

    self.adminView = ParadiseEconomy.MartAdminView:new(15, 100, self.width - 30, self.height - 134, self)
    self.adminView.onSelectedZoneChange = function(view, zoneId)
        self:onChildZoneChanged(zoneId)
    end
    self:addChild(self.adminView)

    ParadiseEconomy.styleWindow(self)
    ParadiseEconomy.styleTree(self)
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
    local theme = ParadiseEconomy.Theme
    button.backgroundColor = active and theme.accentDim or theme.buttonBg
    button.backgroundColorMouseOver = active and theme.accentDim or theme.buttonHover
    button.textColor = active and theme.text or theme.textDim
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
    self.merchantOwnerButton:setVisible(isMerchants)
    self.postMerchant:setVisible(isPosts)
    self.postSearch:setVisible(isPosts)
    self.postList:setVisible(isPosts)
    self.postOwnerButton:setVisible(isPosts)
    self.adminView:setVisible(isMart)
    self:setTabState(self.tabMerchants, isMerchants)
    self:setTabState(self.tabPosts, isPosts)
    self:setTabState(self.tabMart, isMart)
end

function ParadiseEconomy.TradeManagementPanel:onTab(button)
    self.tab = button.internal
    self:applyTab()
    if self.tab == "mart" and self.adminView then self.adminView:refreshMarket() end
end

function ParadiseEconomy.TradeManagementPanel:layout()
    if not self.zone then return end
    local w, h = self.width, self.height
    local contentY = 100
    local footerY = h - 34
    self.zone:setX(15)
    self.zone:setY(30)
    self.zone:setWidth(math.min(320, math.max(240, w * 0.30)))
    local zoneW = self.zone:getWidth()
    self.leaseDays:setX(23 + zoneW)
    self.leaseDays:setY(30)
    self.applyLeaseButton:setX(95 + zoneW)
    self.applyLeaseButton:setY(30)
    self.tabMerchants:setX(15)
    self.tabMerchants:setY(64)
    self.tabPosts:setX(131)
    self.tabPosts:setY(64)
    self.tabMart:setX(257)
    self.tabMart:setY(64)

    local leftW = math.min(370, math.max(300, w * 0.33))
    local detailX = 15 + leftW + 12
    local detailW = w - 15 - detailX
    self.merchantList:setX(15)
    self.merchantList:setY(contentY)
    self.merchantList:setWidth(leftW)
    self.merchantList:setHeight(footerY - contentY)
    self.merchantDetailX = detailX
    self.merchantDetailY = contentY
    self.merchantDetailW = detailW
    self.merchantDetailH = math.max(140, footerY - contentY - 72)
    self.merchantRenewButton:setX(detailX)
    self.merchantRenewButton:setY(footerY - 64)
    self.merchantExpireButton:setX(detailX + 140)
    self.merchantExpireButton:setY(footerY - 64)
    self.merchantClearButton:setX(detailX + 260)
    self.merchantClearButton:setY(footerY - 64)
    self.merchantPostsButton:setX(detailX)
    self.merchantPostsButton:setY(footerY - 32)
    self.merchantOwnerButton:setX(detailX + 160)
    self.merchantOwnerButton:setY(footerY - 32)

    self.postMerchant:setX(15)
    self.postMerchant:setY(contentY)
    self.postMerchant:setWidth(260)
    self.postSearch:setX(283)
    self.postSearch:setY(contentY)
    self.postSearch:setWidth(math.max(120, leftW - 268))
    self.postList:setX(15)
    self.postList:setY(contentY + 32)
    self.postList:setWidth(leftW)
    self.postList:setHeight(footerY - (contentY + 32))
    self.postDetailX = detailX
    self.postDetailY = contentY + 32
    self.postDetailW = detailW
    self.postDetailH = math.max(140, footerY - contentY - 42)
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
end

function ParadiseEconomy.TradeManagementPanel:syncZoneCombo(zoneId)
    for int, id in ipairs(self.zone.zoneIds or {}) do
        if id == zoneId then
            self.zone.selected = int
            return
        end
    end
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

function ParadiseEconomy.TradeManagementPanel:onChildZoneChanged(zoneId)
    if not zoneId then return end
    self.selectedZoneId = zoneId
    self:syncZoneCombo(zoneId)
    self:refreshLeaseEntry()
    self:refreshMerchants()
    self:refreshPostFilter()
    self:refreshPosts()
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
    self.merchantOwnerButton:setVisible(self.isAdm)
    self.merchantOwnerButton:setEnable(self.isAdm and merchant ~= nil and merchant.owner ~= nil)
    local post = self:getSelectedPost()
    self.postOwnerButton:setVisible(self.isAdm)
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

function ParadiseEconomy.TradeManagementPanel:drawMerchant(y, item, alt)
    local merchant = item.item
    local theme = ParadiseEconomy.Theme
    if self.selected == item.index then
        self:drawRect(0, y, self.width, self.itemheight - 1, theme.rowSelected.a, theme.rowSelected.r, theme.rowSelected.g, theme.rowSelected.b)
    elseif alt then
        self:drawRect(0, y, self.width, self.itemheight - 1, theme.rowAlt.a, theme.rowAlt.r, theme.rowAlt.g, theme.rowAlt.b)
    end
    local lease = ParadiseEconomy.getLeaseInfo(merchant.expiresAt)
    local color = merchant.archived and theme.danger or ParadiseEconomy.getLeaseColor(lease.status)
    local title = tostring(merchant.title or merchant.owner or merchant.id)
    self:drawText(ParadiseEconomy.fitText(title, self.width - 150, UIFont.Small), 8, y + 5,
        theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Small)
    self:drawTextRight(merchant.archived and "Archived" or lease.label, self.width - 8, y + 5,
        color.r, color.g, color.b, 1, UIFont.Small)
    local subtitle = tostring(merchant.owner or "-") .. "  |  " .. tostring(merchant.id)
    self:drawText(ParadiseEconomy.fitText(subtitle, self.width - 16, UIFont.Small), 8, y + 24,
        theme.textDim.r, theme.textDim.g, theme.textDim.b, 1, UIFont.Small)
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
    local name = post.itemData and post.itemData.name or post.fullType or "Item"
    self:drawText(ParadiseEconomy.fitText(name, self.width - 180, UIFont.Small), 8, y + 5,
        theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Small)
    self:drawTextRight(tostring(post.price) .. " " .. tostring(post.currency), self.width - 8, y + 5,
        theme.gold.r, theme.gold.g, theme.gold.b, 1, UIFont.Small)
    local lease = ParadiseEconomy.getLeaseInfo(post.merchantExpiresAt)
    local color = post.merchantArchived and theme.danger or ParadiseEconomy.getLeaseColor(lease.status)
    local subtitle = tostring(post.seller) .. "  |  " .. tostring(post.merchantAccountId or "-")
    self:drawText(ParadiseEconomy.fitText(subtitle, self.width - 160, UIFont.Small), 8, y + 24,
        theme.textDim.r, theme.textDim.g, theme.textDim.b, 1, UIFont.Small)
    local stateLabel = post.merchantArchived and "Archived" or (post.expired and "Expired" or lease.label)
    self:drawTextRight(stateLabel, self.width - 8, y + 24,
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
        self:drawText("Select a merchant to inspect its lease.", x + 12, y + 12,
            theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
        return
    end
    local lease = ParadiseEconomy.getLeaseInfo(merchant.expiresAt)
    local color = ParadiseEconomy.getLeaseColor(lease.status)
    local function row(label, value, yy, valueColor)
        valueColor = valueColor or theme.textDim
        self:drawText(label, x + 12, yy, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
        self:drawTextRight(ParadiseEconomy.fitText(tostring(value), w - 150, UIFont.Small), x + w - 12, yy,
            valueColor.r, valueColor.g, valueColor.b, 1, UIFont.Small)
    end
    self:drawText(ParadiseEconomy.fitText(merchant.title or merchant.owner or merchant.id, w - 24, UIFont.Medium),
        x + 12, y + 10, theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Medium)
    row("Owner", merchant.owner or "-", y + 42, theme.text)
    row("Merchant ID", merchant.id or "-", y + 60, theme.accent)
    row("Zone", tostring(merchant.zoneName or merchant.zoneId or "-"), y + 78, theme.textDim)
    row("Lease status", lease.label, y + 102, color)
    row("Expires", ParadiseEconomy.formatLeaseExpiry(merchant.expiresAt), y + 120, color)
    row("Lease days", tostring(merchant.leaseDays or 0), y + 138, theme.textDim)
    local renewed = tonumber(merchant.lastRenewedAt) or 0
    row("Last renewed", renewed > 0 and ParadiseEconomy.formatLeaseExpiry(renewed) or "-", y + 156, theme.textDim)
    row("Earnings", ParadiseEconomy.formatBalances(merchant.earnings), y + 180, theme.gold)
    row("Trade posts", tostring(merchant.listingCount or 0), y + 198, theme.textDim)
    row("Tax route", merchant.taxRoute or "server", y + 216, theme.textDim)
    row("Archived", merchant.archived and "Yes" or "No", y + 234, merchant.archived and theme.danger or theme.green)
end

function ParadiseEconomy.TradeManagementPanel:drawPostDetail()
    local theme = ParadiseEconomy.Theme
    local x, y = self.postDetailX, self.postDetailY
    local w, h = self.postDetailW, self.postDetailH
    ParadiseEconomy.drawCard(self, x, y, w, h, theme.accent)
    local post = self:getSelectedPost()
    if not post then
        self:drawText("Select a player post.", x + 12, y + 12,
            theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
        return
    end
    local name = post.itemData and post.itemData.name or post.fullType or "Item"
    self:drawText(ParadiseEconomy.fitText(name, w - 24, UIFont.Medium), x + 12, y + 10,
        theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Medium)
    local summary = post.itemData and ParadiseEconomy.ItemData.getSummary(post.itemData) or ""
    self:drawText(ParadiseEconomy.fitText(summary, w - 24, UIFont.Small), x + 12, y + 32,
        theme.textDim.r, theme.textDim.g, theme.textDim.b, 1, UIFont.Small)
    self:drawRect(x + 12, y + 52, w - 24, 1, theme.borderSoft.a, theme.borderSoft.r, theme.borderSoft.g, theme.borderSoft.b)
    local lease = ParadiseEconomy.getLeaseInfo(post.merchantExpiresAt)
    local color = ParadiseEconomy.getLeaseColor(lease.status)
    local function row(label, value, yy, valueColor)
        valueColor = valueColor or theme.textDim
        self:drawText(label, x + 12, yy, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
        self:drawTextRight(ParadiseEconomy.fitText(tostring(value), w - 160, UIFont.Small), x + w - 12, yy,
            valueColor.r, valueColor.g, valueColor.b, 1, UIFont.Small)
    end
    row("Seller", post.seller or "-", y + 60, theme.text)
    row("Merchant", post.merchantTitle or "-", y + 78, theme.text)
    row("Merchant ID", post.merchantAccountId or "-", y + 96, theme.accent)
    row("Merchant owner", post.merchantOwner or "-", y + 114, theme.textDim)
    row("Zone", tostring(post.zoneTitle or post.zoneId or "-"), y + 132, theme.textDim)
    row("Price", tostring(post.price) .. " " .. tostring(post.currency), y + 156, theme.gold)
    row("Posted", ParadiseEconomy.formatTimestamp(post.createdAt), y + 174, theme.textDim)
    local stateLabel = post.merchantArchived and "Archived" or (post.expired and "Expired" or lease.label)
    local stateColor = (post.merchantArchived or post.expired) and theme.danger or color
    row("Lease status", stateLabel, y + 198, stateColor)
    row("Lease expires", ParadiseEconomy.formatLeaseExpiry(post.merchantExpiresAt), y + 216, stateColor)
    if post.merchantArchived then
        self:drawText("Archived merchant store. This post is visible to management only.", x + 12, y + 240,
            theme.danger.r, theme.danger.g, theme.danger.b, 1, UIFont.Small)
    elseif post.expired then
        self:drawText("Expired posts stay visible to management only.", x + 12, y + 240,
            theme.danger.r, theme.danger.g, theme.danger.b, 1, UIFont.Small)
    end
end

function ParadiseEconomy.TradeManagementPanel:prerender()
    ISCollapsableWindow.prerender(self)
    local theme = ParadiseEconomy.Theme
    local zone = self:getSelectedZone()
    if zone then
        local info = "Tax " .. string.format("%g", tonumber(zone.tradeTax) or 0) .. "%  |  Owner: " .. tostring(zone.owner or "-")
        self:drawTextRight(ParadiseEconomy.fitText(info, self.width - 580, UIFont.Small), self.width - 15, 37,
            theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    end
    if self.tab == "merchants" then
        self:drawMerchantDetail()
    elseif self.tab == "posts" then
        self:drawPostDetail()
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
        state.transactions = state.transactions or {}
        state.orphanedPlayerListings = state.orphanedPlayerListings or {}
        state.market = state.market or { itemMart = {}, playerListings = {} }
        state.market.itemMart = state.market.itemMart or {}
        state.market.playerListings = state.market.playerListings or {}
        ParadiseEconomy.clientState = state
        if ParadiseEconomy.instance then ParadiseEconomy.instance:refresh() end
        if ParadiseEconomy.accountPanel then ParadiseEconomy.accountPanel:refresh() end
        if ParadiseEconomy.accountBrowser then ParadiseEconomy.accountBrowser:refresh() end
        if ParadiseEconomy.martInstance then ParadiseEconomy.martInstance:refreshMarket() end
        if ParadiseEconomy.tradeManagementInstance then ParadiseEconomy.tradeManagementInstance:refreshState() end
        if ParadiseEconomy.adminInstance then ParadiseEconomy.adminInstance:refresh() end
        if ParadiseEconomy.tablesPanel then ParadiseEconomy.tablesPanel:refresh() end
        ParadiseEconomy.handlePurchaseResult(state.purchase)
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
    for _, selected in ipairs(items or {}) do
        local item = selected.items and selected.items[1] or selected
        if ParadiseEconomy.isWallet(item) then
            local wallet = ParadiseEconomy.getWalletData(item)
            if ParadiseEconomy.hasMoney(wallet) then
                context:addOption("Pillage " .. ParadiseEconomy.formatBalances(wallet), item, ParadiseEconomy.pillage, pl)
            end
        end
        if item and item.getContainer and item:getContainer() == pl:getInventory() then
            context:addOption("Post in Tradeshop", item, ParadiseEconomy.openListingPanel)
            return
        end
    end
end
Events.OnFillInventoryObjectContextMenu.Remove(ParadiseEconomy.fillInventoryContext)
Events.OnFillInventoryObjectContextMenu.Add(ParadiseEconomy.fillInventoryContext)

function ParadiseEconomy.ListingPanel:new(x, y, item, onClose)
    local obj = ISCollapsableWindow.new(self, x, y, 520, 190)
    obj.title = "Post Item in Tradeshop"
    obj.item = item
    obj.onCloseCallback = onClose
    obj.closed = false
    return obj
end

function ParadiseEconomy.ListingPanel:createChildren()
    ISCollapsableWindow.createChildren(self)
    self.currency = ISComboBox:new(15, 94, 145, 25, self)
    self.currency:initialise()
    self.currency:addOption("jimoleon")
    self.currency:addOption("paradisium")
    self:addChild(self.currency)
    self.price = ISTextEntryBox:new("", 170, 94, 120, 25)
    self.price:initialise()
    self.price:instantiate()
    self.price:setOnlyNumbers(true)
    self:addChild(self.price)
    self.postButton = ISButton:new(300, 94, 95, 25, "Post Item", self, ParadiseEconomy.ListingPanel.post)
    self.postButton:initialise()
    self:addChild(self.postButton)
    self.cancelButton = ISButton:new(405, 94, 95, 25, "Cancel", self, ParadiseEconomy.ListingPanel.close)
    self.cancelButton:initialise()
    self:addChild(self.cancelButton)
    ParadiseEconomy.styleWindow(self)
    ParadiseEconomy.styleTree(self)
end

function ParadiseEconomy.ListingPanel:getTaxWarning()
    local market = ParadiseEconomy.clientState.market or {}
    local zoneId = market.tradeZoneId
    for _, merchant in ipairs(ParadiseEconomy.clientState.merchants or {}) do
        if merchant.zoneId == zoneId and merchant.leaseStatus == "expired" then
            return "Your merchant lease has expired. Renew it in Tradeshop > My Store before posting."
        end
    end
    local trade = ParadiseEconomy.getActiveTrade()
    local percent = trade and trade.tradeTax or ParadiseEconomy.getTradeTaxPercentFor(market.tradeZoneId)
    local payout, tax = ParadiseEconomy.getPlayerShopPayout(self.price:getInternalText(), percent)
    local title = trade and tostring(trade.title or trade.tradeId) or tostring(market.tradeZoneTitle or "Trade")
    if payout then
        return "Sales tax warning: " .. string.format("%g", percent or 0) .. "% to " .. title
            .. " deducts " .. tostring(tax) .. ". You receive " .. tostring(payout) .. "."
    end
    return "Sales tax warning: " .. string.format("%g", percent or 0) .. "% goes to " .. title .. "."
end

function ParadiseEconomy.ListingPanel:prerender()
    ISCollapsableWindow.prerender(self)
    local theme = ParadiseEconomy.Theme
    local data = ParadiseEconomy.ItemData.toData(self.item)
    self:drawText(tostring(self.item and self.item:getDisplayName() or "Item"), 15, 35,
        theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Medium)
    self:drawText(ParadiseEconomy.fitText(ParadiseEconomy.ItemData.getSummary(data), self.width - 30, UIFont.Small), 15, 62,
        theme.textDim.r, theme.textDim.g, theme.textDim.b, 1, UIFont.Small)
    self:drawText("Currency", 15, 78, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText("Price", 170, 78, theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 1, UIFont.Small)
    self:drawText(ParadiseEconomy.fitText(self:getTaxWarning(), self.width - 30, UIFont.Small), 15, 132,
        theme.warn.r, theme.warn.g, theme.warn.b, 1, UIFont.Small)
end

function ParadiseEconomy.ListingPanel:update()
    ISCollapsableWindow.update(self)
    if not ParadiseEconomy.canUsePlayerEconomy(getPlayer()) then self:close() end
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

function ParadiseEconomy.openListingPanel(item, onClose)
    if not item or not ParadiseEconomy.canUsePlayerEconomy(getPlayer()) then return end
    if ParadiseEconomy.listingInstance then
        ParadiseEconomy.listingInstance.suppressCloseCallback = true
        ParadiseEconomy.listingInstance:close()
    end
    local panel = ParadiseEconomy.ListingPanel:new(
        (getCore():getScreenWidth() - 520) / 2,
        (getCore():getScreenHeight() - 190) / 2,
        item, onClose)
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
    obj.title = "Paradise Economy - Admin Accounts"
    obj.resizable = true
    obj.minimumWidth = 900
    obj.minimumHeight = 640
    obj.targetUsername = ParadiseEconomy.normalizeUsername(targetUser)
    obj.selectedAccountId = nil
    obj.destAccountId = nil
    obj.accountMap = {}
    obj.pendingMessage = nil
    return obj
end

function ParadiseEconomy.AdminPanel:createChildren()
    ISCollapsableWindow.createChildren(self)
    self.typeFilter = ISComboBox:new(15, 40, 150, 25, self, ParadiseEconomy.AdminPanel.refresh)
    self.typeFilter:initialise()
    for _, entry in ipairs(ParadiseEconomy.accountFilterTypes) do self.typeFilter:addOption(entry.label) end
    self:addChild(self.typeFilter)

    self.search = ISTextEntryBox:new("", 175, 40, 285, 25)
    self.search.target = self
    self.search.onTextChangeFunction = ParadiseEconomy.AdminPanel.onSearchChanged
    self.search:initialise()
    self.search:instantiate()
    self:addChild(self.search)

    self.refreshButton = ISButton:new(470, 40, 100, 25, "Request State", self, ParadiseEconomy.AdminPanel.requestState)
    self.refreshButton:initialise()
    self:addChild(self.refreshButton)
    self.syncButton = ISButton:new(578, 40, 88, 25, "Sync Zones", self, ParadiseEconomy.AdminPanel.syncZones)
    self.syncButton:initialise()
    self:addChild(self.syncButton)
    self.purgeButton = ISButton:new(674, 40, 88, 25, "Purge Ledger", self, ParadiseEconomy.AdminPanel.purgeLedger)
    self.purgeButton:initialise()
    self:addChild(self.purgeButton)
    self.tablesButton = ISButton:new(770, 40, 100, 25, "Data Tables", self, ParadiseEconomy.AdminPanel.openTables)
    self.tablesButton:initialise()
    self:addChild(self.tablesButton)

    self.accounts = ISScrollingListBox:new(15, 120, 520, 360)
    self.accounts:initialise()
    self.accounts:instantiate()
    self.accounts.itemheight = 24
    self.accounts.font = UIFont.Small
    self.accounts.doDrawItem = ParadiseEconomy.AdminPanel.drawAccount
    self.accounts.drawBorder = true
    self.accounts.borderColor = { r = 0.2, g = 0.2, b = 0.5, a = 0.1 }
    self.accounts.listHeaderColor = { r = 0.0, g = 0.0, b = 0.4, a = 0.1 }
    self.accounts:addColumn("Account", 4)
    self.accounts:addColumn("Type", 220)
    self.accounts:addColumn("Zone / Owner", 300)
    self.accounts:addColumn("Balances", 400)
    self.accounts:setOnMouseDownFunction(self, ParadiseEconomy.AdminPanel.selectAccount)
    self.accounts:setOnMouseDoubleClick(self, ParadiseEconomy.AdminPanel.onAccountDoubleClick)
    self:addChild(self.accounts)

    self.newType = ISComboBox:new(15, 0, 115, 25, self)
    self.newType:initialise()
    for _, entry in ipairs(ParadiseEconomy.accountCreateTypes) do self.newType:addOption(entry.label) end
    self:addChild(self.newType)
    self.newOwner = ISTextEntryBox:new("", 0, 0, 150, 25)
    self.newOwner.tooltip = "Owner username for personal / merchant accounts"
    self.newOwner:initialise()
    self.newOwner:instantiate()
    self:addChild(self.newOwner)
    self.newZone = ISComboBox:new(0, 0, 200, 25, self)
    self.newZone:setToolTipMap({ defaultTooltip = "Trade zone for merchant / trade accounts" })
    self.newZone:initialise()
    self:addChild(self.newZone)
    self.newName = ISTextEntryBox:new("", 0, 0, 150, 25)
    self.newName.tooltip = "Display name for custom accounts"
    self.newName:initialise()
    self.newName:instantiate()
    self:addChild(self.newName)
    self.createButton = ISButton:new(0, 0, 105, 25, "Add Account", self, ParadiseEconomy.AdminPanel.createAccount)
    self.createButton:initialise()
    self:addChild(self.createButton)

    self.bucket = ISComboBox:new(500, 210, 145, 25, self)
    self.bucket:initialise()
    self:addChild(self.bucket)
    self.currency = ISComboBox:new(655, 210, 140, 25, self)
    self.currency:initialise()
    self.currency:addOption("jimoleon")
    self.currency:addOption("paradisium")
    self:addChild(self.currency)
    self.amount = ISTextEntryBox:new("", 805, 210, 150, 25)
    self.amount:initialise()
    self.amount:instantiate()
    self.amount:setOnlyNumbers(true)
    self:addChild(self.amount)

    self.addButton = ISButton:new(500, 244, 145, 25, "Add", self, ParadiseEconomy.AdminPanel.adjust)
    self.addButton:initialise()
    self.addButton.internal = "add"
    self:addChild(self.addButton)
    self.reduceButton = ISButton:new(655, 244, 140, 25, "Reduce", self, ParadiseEconomy.AdminPanel.adjust)
    self.reduceButton:initialise()
    self.reduceButton.internal = "remove"
    self:addChild(self.reduceButton)
    self.setButton = ISButton:new(805, 244, 150, 25, "Set", self, ParadiseEconomy.AdminPanel.adjust)
    self.setButton:initialise()
    self.setButton.internal = "set"
    self:addChild(self.setButton)

    self.destAccount = ISComboBox:new(500, 314, 455, 25, self, ParadiseEconomy.AdminPanel.onDestChanged)
    self.destAccount:initialise()
    self:addChild(self.destAccount)
    self.fromBucket = ISComboBox:new(500, 358, 145, 25, self)
    self.fromBucket:initialise()
    self:addChild(self.fromBucket)
    self.toBucket = ISComboBox:new(655, 358, 140, 25, self)
    self.toBucket:initialise()
    self:addChild(self.toBucket)
    self.rerouteAmount = ISTextEntryBox:new("", 805, 358, 150, 25)
    self.rerouteAmount:initialise()
    self.rerouteAmount:instantiate()
    self.rerouteAmount:setOnlyNumbers(true)
    self:addChild(self.rerouteAmount)
    self.rerouteButton = ISButton:new(500, 394, 170, 25, "Reroute Funds", self, ParadiseEconomy.AdminPanel.reroute)
    self.rerouteButton:initialise()
    self:addChild(self.rerouteButton)

    self.deleteButton = ISButton:new(500, 454, 160, 25, "Delete Account", self, ParadiseEconomy.AdminPanel.deleteAccount)
    self.deleteButton:initialise()
    self:addChild(self.deleteButton)
    self.openButton = ISButton:new(670, 454, 160, 25, "Open Account", self, ParadiseEconomy.AdminPanel.openAccount)
    self.openButton:initialise()
    self:addChild(self.openButton)
    self.serverButton = ISButton:new(840, 454, 135, 25, "Server Account", self, ParadiseEconomy.AdminPanel.selectServer)
    self.serverButton:initialise()
    self:addChild(self.serverButton)

    self.taxRoute = ISTextEntryBox:new(500, 432, 300, 25)
    self.taxRoute.tooltip = "Tax route account ID for the selected merchant account"
    self.taxRoute:initialise()
    self.taxRoute:instantiate()
    self:addChild(self.taxRoute)
    self.taxRouteButton = ISButton:new(810, 432, 145, 25, "Set Tax Route", self, ParadiseEconomy.AdminPanel.setTaxRoute)
    self.taxRouteButton:initialise()
    self:addChild(self.taxRouteButton)

    ParadiseEconomy.styleWindow(self)
    ParadiseEconomy.styleTree(self)
    self:layout()
    self:refreshZoneOptions()
end

function ParadiseEconomy.AdminPanel:layout()
    if not self.accounts then return end
    local contentX = 13
    local contentW = self.width - 26
    local top = self:titleBarHeight() + 8
    local fontH = getTextManager():getFontHeight(UIFont.Small)
    local toolbarY = top + fontH + 4
    self.headerY = top
    self.toolbarY = toolbarY

    local buttonW, gap = 100, 6
    local tablesX = contentX + contentW - buttonW
    local purgeX = tablesX - gap - 88
    local syncX = purgeX - gap - 88
    local requestX = syncX - gap - 100
    self.typeFilter:setX(contentX); self.typeFilter:setY(toolbarY)
    self.typeFilter:setWidth(150)
    self.search:setX(contentX + 156); self.search:setY(toolbarY)
    self.search:setWidth(math.max(120, requestX - gap - self.search:getX()))
    self.refreshButton:setX(requestX); self.refreshButton:setY(toolbarY); self.refreshButton:setWidth(100)
    self.syncButton:setX(syncX); self.syncButton:setY(toolbarY); self.syncButton:setWidth(88)
    self.purgeButton:setX(purgeX); self.purgeButton:setY(toolbarY); self.purgeButton:setWidth(88)
    self.tablesButton:setX(tablesX); self.tablesButton:setY(toolbarY); self.tablesButton:setWidth(buttonW)

    local newLabelY = toolbarY + 25 + 8
    local newY = newLabelY + fontH + 4
    self.newAccountLabelY = newLabelY
    local typeW, ownerW, nameW, addW = 115, 150, 150, 105
    local zoneW = math.max(140, contentW - typeW - ownerW - nameW - addW - 40)
    local x = contentX
    self.newType:setX(x); self.newType:setY(newY); self.newType:setWidth(typeW); x = x + typeW + 8
    self.newOwner:setX(x); self.newOwner:setY(newY); self.newOwner:setWidth(ownerW); x = x + ownerW + 8
    self.newZone:setX(x); self.newZone:setY(newY); self.newZone:setWidth(zoneW); x = x + zoneW + 8
    self.newName:setX(x); self.newName:setY(newY); self.newName:setWidth(nameW); x = x + nameW + 8
    self.createButton:setX(x); self.createButton:setY(newY); self.createButton:setWidth(addW)

    local listY = newY + 27 + 10 + self.accounts.itemheight
    local leftW = math.max(360, math.floor(contentW * 0.55))
    local listH = math.max(160, self.height - listY - 14)
    self.accounts:setX(contentX)
    self.accounts:setY(listY)
    self.accounts:setWidth(leftW)
    self.accounts:setHeight(listH)
    self.accounts.columns[1].size = 4
    self.accounts.columns[2].size = math.floor(leftW * 0.40)
    self.accounts.columns[3].size = math.floor(leftW * 0.56)
    self.accounts.columns[4].size = math.floor(leftW * 0.72)

    local rightX = contentX + leftW + 14
    local rightW = contentX + contentW - rightX
    local rightY = listY
    self.rightX, self.rightW, self.rightY = rightX, rightW, rightY
    local colW = math.floor((rightW - 20) / 3)
    local col3X = rightX + 2 * (colW + 10)
    self.bucket:setX(rightX); self.bucket:setY(rightY + 142); self.bucket:setWidth(colW)
    self.currency:setX(rightX + colW + 10); self.currency:setY(rightY + 142); self.currency:setWidth(colW)
    self.amount:setX(col3X); self.amount:setY(rightY + 142); self.amount:setWidth(rightW - 2 * (colW + 10))
    self.addButton:setX(rightX); self.addButton:setY(rightY + 174); self.addButton:setWidth(colW)
    self.reduceButton:setX(rightX + colW + 10); self.reduceButton:setY(rightY + 174); self.reduceButton:setWidth(colW)
    self.setButton:setX(col3X); self.setButton:setY(rightY + 174); self.setButton:setWidth(rightW - 2 * (colW + 10))
    self.destAccount:setX(rightX); self.destAccount:setY(rightY + 246); self.destAccount:setWidth(rightW)
    self.fromBucket:setX(rightX); self.fromBucket:setY(rightY + 294); self.fromBucket:setWidth(colW)
    self.toBucket:setX(rightX + colW + 10); self.toBucket:setY(rightY + 294); self.toBucket:setWidth(colW)
    self.rerouteAmount:setX(col3X); self.rerouteAmount:setY(rightY + 294); self.rerouteAmount:setWidth(rightW - 2 * (colW + 10))
    self.rerouteButton:setX(rightX); self.rerouteButton:setY(rightY + 326); self.rerouteButton:setWidth(170)
    self.deleteButton:setX(rightX); self.deleteButton:setY(rightY + 380); self.deleteButton:setWidth(160)
    self.openButton:setX(rightX + 170); self.openButton:setY(rightY + 380); self.openButton:setWidth(160)
    self.serverButton:setX(rightX + 340); self.serverButton:setY(rightY + 380)
    self.serverButton:setWidth(math.max(120, rightW - 340))
    self.taxRoute:setX(rightX); self.taxRoute:setY(rightY + 432)
    self.taxRoute:setWidth(math.max(160, rightW - 160))
    self.taxRouteButton:setX(rightX + rightW - 150); self.taxRouteButton:setY(rightY + 432)
    self.taxRouteButton:setWidth(150)
    self._lastLayoutW, self._lastLayoutH = self.width, self.height
end

function ParadiseEconomy.AdminPanel:update()
    ISCollapsableWindow.update(self)
    if not ParadiseEconomy.canManageEconomy() or not (ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(getPlayer())) then
        if ParadiseEconomy.AdminPanel.ClosePanel then ParadiseEconomy.AdminPanel.ClosePanel() end
        return
    end
    if self._lastLayoutW ~= self.width or self._lastLayoutH ~= self.height then
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
    if self.taxRoute and (force or not self.taxRoute:isFocused()) then
        self.taxRoute:setText(account and account.type == "merchant" and tostring(account.taxRoute or "") or "")
    end
    self:refreshButtons()
end

function ParadiseEconomy.AdminPanel:refreshButtons()
    local account = self:getSelectedAccount()
    local hasAccount = account ~= nil
    local amount = self.amount and self.amount:getInternalText() or ""
    local validAmount = amount:match("^%d+$") ~= nil and tonumber(amount) > 0
    local validSetAmount = amount:match("^%d+$") ~= nil
    local rerouteAmount = self.rerouteAmount and self.rerouteAmount:getInternalText() or ""
    self.addButton:setEnable(hasAccount and validAmount)
    self.reduceButton:setEnable(hasAccount and validAmount)
    self.setButton:setEnable(hasAccount and validSetAmount)
    local dest = self:getDestAccount()
    self.rerouteButton:setEnable(hasAccount and dest ~= nil and dest.id ~= account.id
        and rerouteAmount:match("^%d+$") ~= nil and tonumber(rerouteAmount) > 0)
    self.deleteButton:setEnable(hasAccount and account.id ~= ParadiseEconomy.serverAccountId)
    self.openButton:setEnable(hasAccount)
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
    local found = false
    for _, account in ipairs(ParadiseEconomy.getAccountsList()) do
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

function ParadiseEconomy.AdminPanel:setTaxRoute()
    local account = self:getSelectedAccount()
    if not account or account.type ~= "merchant" then return end
    ParadiseEconomy.send("adminSetTaxRoute", {
        accountId = account.id,
        taxRoute = self.taxRoute:getInternalText(),
    })
end

function ParadiseEconomy.AdminPanel:adjust(button)
    local account = self:getSelectedAccount()
    if not account then return end
    ParadiseEconomy.send("adminAdjust", {
        accountId = account.id,
        bucket = self.bucket.bucketKeys[self.bucket.selected],
        currency = self.currency.options[self.currency.selected],
        amount = self.amount:getInternalText(),
        operation = button.internal,
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
    self:setTitle("Paradise Economy - Admin Accounts")
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
    self:setTitle(self.targetUsername and "Paradise Economy - Admin: " .. self.targetUsername or "Paradise Economy - Admin Accounts")
    self:refresh()
end

function ParadiseEconomy.AdminPanel:drawAccount(y, item, alt)
    if self.selected == item.index then
        self:drawRect(0, y, self.width, self.itemheight, 0.32, 0.70, 0.35, 0.16)
    elseif alt then
        self:drawRect(0, y, self.width, self.itemheight, 0.13, 0.30, 0.32, 0.32)
    end
    self:drawRectBorder(0, y, self.width, self.itemheight, 0.45, 0.30, 0.35, 0.45)
    local account = item.item
    local typeLabel = ParadiseEconomy.accountTypeLabels[account.type] or account.type or "?"
    local zoneLabel = account.zoneName or account.zoneId or account.owner or account.name or "-"
    self:drawText(ParadiseEconomy.getAccountLabel(account), self.columns[1].size + 10, y + 4, 1, 1, 1, 0.95, self.font)
    self:drawText(typeLabel, self.columns[2].size + 10, y + 4, 0.75, 0.9, 1, 0.95, self.font)
    self:drawText(tostring(zoneLabel), self.columns[3].size + 10, y + 4, 0.8, 0.8, 0.8, 0.95, self.font)
    self:drawText(ParadiseEconomy.formatAccountBalances(account), self.columns[4].size + 10, y + 4, 1, 0.85, 0.25, 0.95, self.font)
    return y + self.itemheight
end

function ParadiseEconomy.AdminPanel:prerender()
    ISCollapsableWindow.prerender(self)
    local rightX = self.rightX or 500
    local rightY = self.rightY or 150
    local rightW = self.rightW or 400
    local account = self:getSelectedAccount()
    self:drawText("Account directory (" .. tostring(#(self.accounts.items or {})) .. ")",
        15, self.headerY or 30, 0.7, 0.9, 1, 1, UIFont.Small)
    self:drawText("New Account:", 13, self.newAccountLabelY or 60, 0.7, 0.9, 1, 1, UIFont.Small)

    self:drawText("Selected account", rightX, rightY, 0.7, 0.9, 1, 1, UIFont.Small)
    if account then
        self:drawText(ParadiseEconomy.getAccountLabel(account), rightX, rightY + 16, 1, 1, 1, 1, UIFont.Small)
        self:drawText(tostring(account.id), rightX, rightY + 32, 0.75, 0.9, 1, 1, UIFont.Small)
        local owner = "Owner: " .. tostring(account.owner or account.name or "-")
        if account.zoneId then owner = owner .. " | Zone: " .. tostring(account.zoneName or account.zoneId) end
        if account.tradeId then owner = owner .. " | Trade ID: " .. tostring(account.tradeId) end
        if account.taxRoute then owner = owner .. " | Tax route: " .. tostring(account.taxRoute) end
        if account.archived then owner = owner .. " | Archived" end
        self:drawText(owner, rightX, rightY + 48, 0.8, 0.8, 0.8, 1, UIFont.Small)
        self:drawText(ParadiseEconomy.formatAccountBalances(account), rightX, rightY + 64, 1, 0.85, 0.25, 1, UIFont.Small)
        if account.type == "trade" then
            local detail = "Tax: " .. string.format("%g", ParadiseEconomy.getTradeTaxPercent(account)) .. "% | Mart items: "
                .. tostring(#(account.itemMart or {})) .. " | Title: " .. tostring(account.title or "-")
            self:drawText(detail, rightX, rightY + 80, 0.75, 0.85, 0.9, 1, UIFont.Small)
        elseif account.type == "merchant" then
            self:drawText("Listings: " .. tostring(#(account.listings or {})) .. " | Title: "
                .. tostring(account.title or "-"), rightX, rightY + 80, 0.75, 0.85, 0.9, 1, UIFont.Small)
        elseif account.type == "personal" then
            self:drawText("Title: " .. tostring(account.title or account.owner or "-"), rightX, rightY + 80, 0.75, 0.85, 0.9, 1, UIFont.Small)
        end
    else
        self:drawText("Select an account from the directory.", rightX, rightY + 16, 0.8, 0.8, 0.8, 1, UIFont.Small)
    end

    self:drawText("Adjust balance", rightX, rightY + 108, 0.7, 0.9, 1, 1, UIFont.Small)
    local colW = math.floor((rightW - 20) / 3)
    self:drawText("Bucket", rightX, rightY + 126, 0.7, 0.75, 0.8, 1, UIFont.Small)
    self:drawText("Currency", rightX + colW + 10, rightY + 126, 0.7, 0.75, 0.8, 1, UIFont.Small)
    self:drawText("Amount", rightX + 2 * (colW + 10), rightY + 126, 0.7, 0.75, 0.8, 1, UIFont.Small)
    self:drawText("Reroute funds", rightX, rightY + 212, 0.7, 0.9, 1, 1, UIFont.Small)
    self:drawText("Destination account", rightX, rightY + 230, 0.7, 0.75, 0.8, 1, UIFont.Small)
    self:drawText("From bucket", rightX, rightY + 278, 0.7, 0.75, 0.8, 1, UIFont.Small)
    self:drawText("To bucket", rightX + colW + 10, rightY + 278, 0.7, 0.75, 0.8, 1, UIFont.Small)
    self:drawText("Amount", rightX + 2 * (colW + 10), rightY + 278, 0.7, 0.75, 0.8, 1, UIFont.Small)
    self:drawText("Account tools", rightX, rightY + 362, 0.7, 0.9, 1, 1, UIFont.Small)
    self:drawText("Merchant tax route (account ID)", rightX, rightY + 414, 0.7, 0.75, 0.8, 1, UIFont.Small)
    local message = self.pendingMessage or ParadiseEconomy.clientState.message
    if message then
        self:drawTextRight(tostring(message), self.width - 15, self.headerY or 30, 1, 0.9, 0.55, 1, UIFont.Small)
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
                "itemMart: " .. tostring(#(account.itemMart or {})),
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
                "itemMart: " .. tostring(trade and #(trade.itemMart or {})),
                "legacy: " .. tostring(zone.legacy),
                "removed: " .. tostring(zone.removed),
                "createdAt: " .. tostring(zone.createdAt),
            })
        end
    elseif key == "tradeMarts" then
        for _, account in ipairs(ParadiseEconomy.getAccountsList()) do
            if account.type == "trade" then
                for _, listing in ipairs(account.itemMart or {}) do
                    add("[" .. tostring(account.title or account.tradeId or account.zoneId) .. "] "
                        .. tostring(listing.category or "General") .. " | " .. tostring(listing.fullType) .. " | "
                        .. tostring(listing.direction) .. " | " .. tostring(listing.price) .. " "
                        .. tostring(listing.currency), {
                        "id: " .. tostring(listing.id),
                        "tradeAccount: " .. tostring(account.id),
                        "tradeTitle: " .. tostring(account.title),
                        "tradeId: " .. tostring(account.tradeId),
                        "zoneId: " .. tostring(account.zoneId),
                        "category: " .. tostring(listing.category),
                        "fullType: " .. tostring(listing.fullType),
                        "direction: " .. tostring(listing.direction),
                        "currency: " .. tostring(listing.currency),
                        "price: " .. tostring(listing.price),
                    })
                end
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
    elseif key == "transactions" then
        local transactions = ParadiseEconomy.clientState.transactions or {}
        for index = #transactions, 1, -1 do
            local tx = transactions[index]
            add(tostring(tx.time) .. " | " .. tostring(tx.action) .. " | " .. tostring(tx.amount) .. " "
                .. tostring(tx.currency) .. " | " .. tostring(tx.from) .. " -> " .. tostring(tx.to), function()
                return {
                    "time: " .. tostring(tx.time),
                    "username: " .. tostring(tx.username),
                    "steamid: " .. tostring(tx.steamid),
                    "action: " .. tostring(tx.action),
                    "currency: " .. tostring(tx.currency),
                    "amount: " .. tostring(tx.amount),
                    "from: " .. tostring(tx.from),
                    "to: " .. tostring(tx.to),
                    "accountId: " .. tostring(tx.accountId),
                    "counterpartyId: " .. tostring(tx.counterpartyId),
                    "zoneId: " .. tostring(tx.zoneId),
                    "bucket: " .. tostring(tx.bucket),
                    "detail: " .. tostring(tx.detail),
                }
            end)
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
    obj.selectedListingId = nil
    obj.lastWidth = 0
    obj.lastHeight = 0
    obj.backgroundColor = ParadiseEconomy.Theme.panelBg
    obj.borderColor = ParadiseEconomy.Theme.borderSoft
    return obj
end

function ParadiseEconomy.MartAdminView:createChildren()
    ISPanel.createChildren(self)

    self.zone = ISComboBox:new(15, 14, 300, 25, self, ParadiseEconomy.MartAdminView.onZoneChanged)
    self.zone:initialise()
    self:addChild(self.zone)
    self.titleEntry = ISTextEntryBox:new("", 325, 14, 275, 25)
    self.titleEntry.tooltip = "Trade account title"
    self.titleEntry:initialise()
    self.titleEntry:instantiate()
    self:addChild(self.titleEntry)
    self.renameButton = ISButton:new(610, 14, 135, 25, "Rename Trade", self, ParadiseEconomy.MartAdminView.renameTrade)
    self.renameButton:initialise()
    self:addChild(self.renameButton)

    self.taxEntry = ISTextEntryBox:new("", 15, 58, 80, 25)
    self.taxEntry.tooltip = "Trade tax percent (0-100)"
    self.taxEntry:initialise()
    self.taxEntry:instantiate()
    self.taxEntry:setOnlyNumbers(true)
    self:addChild(self.taxEntry)
    self.setTaxButton = ISButton:new(103, 58, 90, 25, "Set Tax", self, ParadiseEconomy.MartAdminView.setTax)
    self.setTaxButton:initialise()
    self:addChild(self.setTaxButton)
    self.withdrawCurrency = ISComboBox:new(205, 58, 115, 25, self)
    self.withdrawCurrency:initialise()
    self.withdrawCurrency:addOption("jimoleon")
    self.withdrawCurrency:addOption("paradisium")
    self:addChild(self.withdrawCurrency)
    self.withdrawAmount = ISTextEntryBox:new("", 328, 58, 95, 25)
    self.withdrawAmount:initialise()
    self.withdrawAmount:instantiate()
    self.withdrawAmount:setOnlyNumbers(true)
    self:addChild(self.withdrawAmount)
    self.withdrawButton = ISButton:new(431, 58, 110, 25, "Withdraw", self, ParadiseEconomy.MartAdminView.withdraw)
    self.withdrawButton:initialise()
    self:addChild(self.withdrawButton)
    self.transferCurrency = ISComboBox:new(549, 58, 110, 25, self)
    self.transferCurrency:initialise()
    self.transferCurrency:addOption("jimoleon")
    self.transferCurrency:addOption("paradisium")
    self:addChild(self.transferCurrency)
    self.transferAmount = ISTextEntryBox:new("", 667, 58, 78, 25)
    self.transferAmount:initialise()
    self.transferAmount:instantiate()
    self.transferAmount:setOnlyNumbers(true)
    self:addChild(self.transferAmount)

    self.transferTarget = ISTextEntryBox:new("", 15, 100, 210, 25)
    self.transferTarget.tooltip = "Username of the player account receiving the transfer"
    self.transferTarget:initialise()
    self.transferTarget:instantiate()
    self:addChild(self.transferTarget)
    self.transferButton = ISButton:new(233, 100, 110, 25, "Transfer", self, ParadiseEconomy.MartAdminView.transfer)
    self.transferButton:initialise()
    self:addChild(self.transferButton)
    self.ownerEntry = ISTextEntryBox:new("", 355, 100, 200, 25)
    self.ownerEntry.tooltip = "Trade account owner username"
    self.ownerEntry:initialise()
    self.ownerEntry:instantiate()
    self:addChild(self.ownerEntry)
    self.ownerButton = ISButton:new(563, 100, 90, 25, "Set Owner", self, ParadiseEconomy.MartAdminView.setOwner)
    self.ownerButton:initialise()
    self:addChild(self.ownerButton)

    self.itemSearch = ISTextEntryBox:new("", 15, 138, 225, 25)
    self.itemSearch.target = self
    self.itemSearch.onTextChangeFunction = ParadiseEconomy.MartAdminView.onItemSearchChanged
    self.itemSearch:initialise()
    self.itemSearch:instantiate()
    self:addChild(self.itemSearch)
    self.itemFilterButton = ISButton:new(248, 138, 70, 25, "Find", self, ParadiseEconomy.MartAdminView.refreshItems)
    self.itemFilterButton:initialise()
    self:addChild(self.itemFilterButton)
    self.items = ISScrollingListBox:new(15, 166, 300, 200)
    self.items:initialise()
    self.items.itemheight = 20
    self.items.font = UIFont.Small
    self.items.doDrawItem = ParadiseEconomy.MartAdminView.drawItem
    self.items:setOnMouseDownFunction(self, ParadiseEconomy.MartAdminView.selectItem)
    self:addChild(self.items)

    self.listingSearch = ISTextEntryBox:new("", 325, 138, 250, 25)
    self.listingSearch.target = self
    self.listingSearch.onTextChangeFunction = ParadiseEconomy.MartAdminView.onListingSearchChanged
    self.listingSearch:initialise()
    self.listingSearch:instantiate()
    self:addChild(self.listingSearch)
    self.listingFilterButton = ISButton:new(583, 138, 70, 25, "Search", self, ParadiseEconomy.MartAdminView.refreshListings)
    self.listingFilterButton:initialise()
    self:addChild(self.listingFilterButton)
    self.listings = ISScrollingListBox:new(325, 166, self.width - 340, 200)
    self.listings:initialise()
    self.listings.itemheight = 24
    self.listings.font = UIFont.Small
    self.listings.doDrawItem = ParadiseEconomy.MartAdminView.drawListing
    self.listings:setOnMouseDownFunction(self, ParadiseEconomy.MartAdminView.selectListing)
    self:addChild(self.listings)

    self.category = ISTextEntryBox:new("", 15, 399, 150, 25)
    self.category.tooltip = "Mart category"
    self.category:initialise()
    self.category:instantiate()
    self:addChild(self.category)
    self.fullType = ISTextEntryBox:new("", 173, 399, 300, 25)
    self.fullType.tooltip = "Item script name"
    self.fullType:initialise()
    self.fullType:instantiate()
    self:addChild(self.fullType)
    self.direction = ISComboBox:new(485, 399, 140, 25, self)
    self.direction:initialise()
    self.direction:addOption("Mart Sells")
    self.direction:addOption("Mart Buys")
    self:addChild(self.direction)
    self.currency = ISComboBox:new(635, 399, 110, 25, self)
    self.currency:initialise()
    self.currency:addOption("jimoleon")
    self.currency:addOption("paradisium")
    self:addChild(self.currency)
    self.price = ISTextEntryBox:new("", 15, 431, 120, 25)
    self.price:initialise()
    self.price:instantiate()
    self.price:setOnlyNumbers(true)
    self:addChild(self.price)
    self.clearButton = ISButton:new(143, 431, 90, 25, "Clear", self, ParadiseEconomy.MartAdminView.clearEditor)
    self.clearButton:initialise()
    self:addChild(self.clearButton)
    self.deleteListingButton = ISButton:new(241, 431, 130, 25, "Delete Listing", self, ParadiseEconomy.MartAdminView.deleteListing)
    self.deleteListingButton:initialise()
    self:addChild(self.deleteListingButton)
    self.saveButton = ISButton:new(625, 431, 120, 25, "Save Listing", self, ParadiseEconomy.MartAdminView.saveListing)
    self.saveButton:initialise()
    self:addChild(self.saveButton)

    ParadiseEconomy.styleTree(self)
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

function ParadiseEconomy.MartAdminView:getSelectedListing()
    local trade = self:getSelectedTrade()
    for _, listing in ipairs(trade and trade.itemMart or {}) do
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
    local action = listing.direction == "sell" and "Mart Buys" or "Mart Sells"
    if self.selected == item.index then
        self:drawRect(0, y, self.width, self.itemheight - 1, theme.rowSelected.a, theme.rowSelected.r, theme.rowSelected.g, theme.rowSelected.b)
    elseif alt then
        self:drawRect(0, y, self.width, self.itemheight - 1, theme.rowAlt.a, theme.rowAlt.r, theme.rowAlt.g, theme.rowAlt.b)
    end
    self:drawText("[" .. tostring(listing.category or "General") .. "]", 6, y + 5,
        theme.accent.r, theme.accent.g, theme.accent.b, 1, UIFont.Small)
    self:drawText(tostring(listing.fullType), 120, y + 5, theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Small)
    self:drawText(action, math.floor(self.width * 0.58), y + 5,
        theme.textDim.r, theme.textDim.g, theme.textDim.b, 1, UIFont.Small)
    self:drawTextRight(tostring(listing.price) .. " " .. tostring(listing.currency), self.width - 8, y + 5,
        theme.gold.r, theme.gold.g, theme.gold.b, 1, UIFont.Small)
    return y + self.itemheight
end

function ParadiseEconomy.MartAdminView:drawItem(y, item, alt)
    local theme = ParadiseEconomy.Theme
    if self.selected == item.index then
        self:drawRect(0, y, self.width, self.itemheight - 1, theme.rowSelected.a, theme.rowSelected.r, theme.rowSelected.g, theme.rowSelected.b)
    elseif alt then
        self:drawRect(0, y, self.width, self.itemheight - 1, theme.rowAlt.a, theme.rowAlt.r, theme.rowAlt.g, theme.rowAlt.b)
    end
    self:drawText(tostring(item.text), 6, y + 2, theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Small)
    return y + self.itemheight
end

function ParadiseEconomy.MartAdminView.onListingSearchChanged(target)
    if target and target.refreshListings then target:refreshListings() end
end

function ParadiseEconomy.MartAdminView.onItemSearchChanged(target)
    if target and target.refreshItems then target:refreshItems() end
end

function ParadiseEconomy.MartAdminView:setSelectedZone(zoneId)
    self.selectedZoneId = zoneId
    self.selectedListingId = nil
    self:clearEditor()
    self:refreshMarket()
end

function ParadiseEconomy.MartAdminView.onZoneChanged(target, combo)
    target.selectedZoneId = combo.zoneIds and combo.zoneIds[combo.selected] or nil
    target.selectedListingId = nil
    target:clearEditor()
    target:refreshMarket()
    if target.onSelectedZoneChange then target.onSelectedZoneChange(target, target.selectedZoneId) end
end

function ParadiseEconomy.MartAdminView:refreshZones()
    if not self.zone then return end
    local previous = self.selectedZoneId
    self.zone.zoneIds = {}
    self.zone:clear()
    self.zone:setToolTipMap({ defaultTooltip = "Trade account to manage" })
    self.zone.selected = 0
    local selectedIndex
    for _, trade in ipairs(self:getTradeList()) do
        self.zone:addOption(tostring(trade.title or trade.tradeId or trade.zoneId) .. " | " .. tostring(trade.zoneId))
        self.zone.zoneIds[#self.zone.zoneIds + 1] = trade.zoneId
        if trade.zoneId == previous then selectedIndex = #self.zone.zoneIds end
    end
    if #self.zone.zoneIds == 0 then
        self.zone:addOption("No trade accounts")
        self.zone.selected = 1
        self.selectedZoneId = nil
        return
    end
    if not selectedIndex then
        local market = ParadiseEconomy.clientState.market or {}
        for int, zoneId in ipairs(self.zone.zoneIds) do
            if zoneId == market.tradeZoneId then selectedIndex = int end
        end
    end
    self.zone.selected = selectedIndex or 1
    self.selectedZoneId = self.zone.zoneIds[self.zone.selected]
end

function ParadiseEconomy.MartAdminView:refreshMarket()
    if not self.zone then return end
    self:refreshZones()
    local trade = self:getSelectedTrade()
    if trade then
        if not self.titleEntry:isFocused() then self.titleEntry:setText(tostring(trade.title or trade.tradeId or "")) end
        if not self.taxEntry:isFocused() then self.taxEntry:setText(tostring(ParadiseEconomy.getTradeTaxPercent(trade))) end
        if not self.ownerEntry:isFocused() then self.ownerEntry:setText(tostring(trade.owner or "")) end
    else
        if not self.titleEntry:isFocused() then self.titleEntry:setText("") end
        if not self.taxEntry:isFocused() then self.taxEntry:setText("") end
        if not self.ownerEntry:isFocused() then self.ownerEntry:setText("") end
        self:clearEditor()
    end
    local adminView = self:isAdminView()
    self.ownerEntry:setVisible(adminView)
    self.ownerButton:setVisible(adminView)
    self:refreshListings()
end

function ParadiseEconomy.MartAdminView:renameTrade()
    if not self.selectedZoneId then return end
    ParadiseEconomy.send("tradeSetTitle", { zoneId = self.selectedZoneId, title = self.titleEntry:getInternalText() })
end

function ParadiseEconomy.MartAdminView:setTax()
    if not self.selectedZoneId then return end
    ParadiseEconomy.send("tradeSetTax", { zoneId = self.selectedZoneId, percent = self.taxEntry:getInternalText() })
end

function ParadiseEconomy.MartAdminView:setOwner()
    if not self.selectedZoneId or not self:isAdminView() then return end
    ParadiseEconomy.send("adminSetTradeOwner", { zoneId = self.selectedZoneId, owner = self.ownerEntry:getInternalText() })
end

function ParadiseEconomy.MartAdminView:withdraw()
    if not self.selectedZoneId then return end
    ParadiseEconomy.send("tradeWithdraw", {
        zoneId = self.selectedZoneId,
        currency = self.withdrawCurrency.options[self.withdrawCurrency.selected],
        amount = self.withdrawAmount:getInternalText(),
    })
end

function ParadiseEconomy.MartAdminView:transfer()
    if not self.selectedZoneId then return end
    ParadiseEconomy.send("tradeTransfer", {
        zoneId = self.selectedZoneId,
        targetUser = self.transferTarget:getInternalText(),
        currency = self.transferCurrency.options[self.transferCurrency.selected],
        amount = self.transferAmount:getInternalText(),
    })
end

function ParadiseEconomy.MartAdminView:refreshListings()
    if not self.listings then return end
    local previous = self.listings.selected or 0
    self.listings:clear()
    local search = string.lower(self.listingSearch:getInternalText() or "")
    local selected
    local trade = self:getSelectedTrade()
    for _, listing in ipairs(trade and trade.itemMart or {}) do
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
    if not self.selectedZoneId then return end
    ParadiseEconomy.send("tradeItemSave", {
        zoneId = self.selectedZoneId,
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
    if not listing then return end
    local modal = ISModalDialog:new(0, 0, 380, 160, "Delete listing '" .. tostring(listing.fullType) .. "'?", true, self, ParadiseEconomy.MartAdminView.onDeleteListingConfirmed, nil, self.selectedZoneId, listing.id)
    modal:initialise()
    modal:addToUIManager()
end

function ParadiseEconomy.MartAdminView.onDeleteListingConfirmed(target, button, zoneId, listingId)
    if button.internal == "YES" then
        target.selectedListingId = nil
        ParadiseEconomy.send("tradeItemDelete", { zoneId = zoneId, listingId = listingId })
    end
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
    local contentW = self.width - 30
    local listY = 166
    local listH = math.max(70, self.height - listY - 158)
    self.listY, self.listH = listY, listH
    self.items:setWidth(300)
    self.items:setHeight(listH)
    self.items:setY(listY)
    self.listings:setX(325)
    self.listings:setY(listY)
    self.listings:setWidth(math.max(300, contentW - 310))
    self.listings:setHeight(listH)
    self.listingSearch:setWidth(math.max(120, contentW - 310 - 75))
    self.listingFilterButton:setX(325 + math.max(120, contentW - 310 - 75) + 5)

    self.editorLabelY = listY + listH + 8
    local fieldY = self.editorLabelY + 16
    local buttonY = fieldY + 32
    self.editorFieldY, self.editorButtonY = fieldY, buttonY
    self.fullType:setX(173)
    self.fullType:setWidth(math.max(160, self.width - 173 - 15 - 110 - 140 - 20))
    self.direction:setX(self.width - 15 - 110 - 10 - 140)
    self.direction:setY(fieldY)
    self.direction:setWidth(140)
    self.currency:setX(self.width - 15 - 110)
    self.currency:setY(fieldY)
    self.currency:setWidth(110)
    self.category:setY(fieldY)
    self.fullType:setY(fieldY)
    self.price:setY(buttonY)
    self.clearButton:setY(buttonY)
    self.deleteListingButton:setY(buttonY)
    self.saveButton:setX(self.width - 15 - 120)
    self.saveButton:setY(buttonY)
    self.messageY = self.height - 24
    self.lastWidth = self.width
    self.lastHeight = self.height
end

function ParadiseEconomy.MartAdminView:update()
    ISPanel.update(self)
    if self.width ~= self.lastWidth or self.height ~= self.lastHeight then self:layout() end
    local trade = self:getSelectedTrade()
    local hasTrade = trade ~= nil
    local hasListing = self:getSelectedListing() ~= nil
    local fullType = self.fullType and self.fullType:getInternalText() or ""
    local price = self.price and self.price:getInternalText() or ""
    local withdrawAmount = self.withdrawAmount:getInternalText()
    local transferAmount = self.transferAmount:getInternalText()
    self.renameButton:setEnable(hasTrade and self.titleEntry:getInternalText() ~= "")
    self.setTaxButton:setEnable(hasTrade and self.taxEntry:getInternalText() ~= "")
    self.ownerButton:setEnable(hasTrade and self:isAdminView() and self.ownerEntry:getInternalText() ~= "")
    self.withdrawButton:setEnable(hasTrade and withdrawAmount:match("^%d+$") ~= nil and tonumber(withdrawAmount) > 0)
    self.transferButton:setEnable(hasTrade and self.transferTarget:getInternalText() ~= ""
        and transferAmount:match("^%d+$") ~= nil and tonumber(transferAmount) > 0)
    self.deleteListingButton:setEnable(hasListing)
    self.saveButton:setEnable(hasTrade and fullType ~= "" and price:match("^%d+$") ~= nil and tonumber(price) > 0)
end

function ParadiseEconomy.MartAdminView:prerender()
    ISPanel.prerender(self)
    self:drawText("Trade settings", 15, 0, 0.7, 0.9, 1, 1, UIFont.Small)
    self:drawText("Trade tax / withdraw / transfer funds", 15, 44, 0.7, 0.75, 0.8, 1, UIFont.Small)
    self:drawText("Transfer to player", 15, 86, 0.7, 0.75, 0.8, 1, UIFont.Small)
    if self:isAdminView() then self:drawText("Trade owner (admin)", 355, 86, 0.7, 0.75, 0.8, 1, UIFont.Small) end
    self:drawText("Item types", 15, 124, 0.7, 0.9, 1, 1, UIFont.Small)
    self:drawText("Trade mart listings", 325, 124, 0.7, 0.9, 1, 1, UIFont.Small)
    self:drawText("Listing editor", 15, self.editorLabelY or 390, 0.7, 0.9, 1, 1, UIFont.Small)
    local fieldY = self.editorFieldY or 400
    local buttonY = self.editorButtonY or 432
    self:drawText("Category", 15, fieldY - 14, 0.7, 0.75, 0.8, 1, UIFont.Small)
    self:drawText("Item type", 173, fieldY - 14, 0.7, 0.75, 0.8, 1, UIFont.Small)
    self:drawText("Action", self.width - 265, fieldY - 14, 0.7, 0.75, 0.8, 1, UIFont.Small)
    self:drawText("Currency", self.width - 125, fieldY - 14, 0.7, 0.75, 0.8, 1, UIFont.Small)
    self:drawText("Price", 15, buttonY - 14, 0.7, 0.75, 0.8, 1, UIFont.Small)
    local trade = self:getSelectedTrade()
    if trade then
        self:drawTextRight("Title: " .. tostring(trade.title or trade.tradeId) .. " | Owner: " .. tostring(trade.owner or "-")
            .. " | Funds: " .. ParadiseEconomy.formatBalances(trade.digital), self.width - 15, 0, 0.55, 0.95, 0.7, 1, UIFont.Small)
    else
        self:drawTextRight("No manageable trade account", self.width - 15, 0, 1, 0.65, 0.2, 1, UIFont.Small)
    end
    local message = ParadiseEconomy.clientState.message
    if message then self:drawText(tostring(message), 15, self.messageY or (self.height - 24), 1, 0.9, 0.55, 1, UIFont.Small) end
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
