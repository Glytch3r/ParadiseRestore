require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
require "ISUI/ISComboBox"
require "ISUI/ISScrollingListBox"
require "ISUI/ISPanel"
require "ISUI/ISModalDialog"
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

ParadiseEconomy.clientState = ParadiseEconomy.clientState or { account = {}, carried = {}, transactions = {}, market = { tabs = {} } }
ParadiseEconomy.icons = ParadiseEconomy.icons or {
    jimoleon = getTexture("media/ui/Paradise/Economy/Jimoleon.png"),
    paradisium = getTexture("media/ui/Paradise/Economy/Paradisium.png"),
}
ParadiseEconomy.Panel = ISCollapsableWindow:derive("ParadiseEconomyPanel")
ParadiseEconomy.MartPanel = ISCollapsableWindow:derive("ParadiseMartPanel")
ParadiseEconomy.AdminPanel = ISCollapsableWindow:derive("ParadiseEconomyAdminPanel")
ParadiseEconomy.MartAdminView = ISPanel:derive("ParadiseMartAdminView")
ParadiseEconomy.ListingPanel = ISCollapsableWindow:derive("ParadiseEconomyListingPanel")
ParadiseEconomy.HUD = ISPanel:derive("ParadiseEconomyHUD")

function ParadiseEconomy.send(command, args)
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
    self.martButton = ISButton:new(487, 90, 130, 25, "ParadiseMart", self, ParadiseEconomy.Panel.openMart)
    self.martButton:initialise()
    self:addChild(self.martButton)
    self.transactions = ISScrollingListBox:new(15, 130, self.width - 30, self.height - 170)
    self.transactions:initialise()
    self.transactions.itemheight = 24
    self.transactions.doDrawItem = ParadiseEconomy.Panel.drawTransaction
    self:addChild(self.transactions)
end

function ParadiseEconomy.Panel:update()
    ISCollapsableWindow.update(self)
    local canUseMarket = ParadiseEconomy.canUsePlayerEconomy(getPlayer())
    self.martButton:setEnable(canUseMarket)
    self.martButton:setTooltip(canUseMarket and nil or "Enter a Trade Zone to use ParadiseMart")
end

function ParadiseEconomy.Panel:openMart()
    if ParadiseEconomy.canUsePlayerEconomy(getPlayer()) and ParadiseEconomy.MartPanel.OpenPanel then
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
    self:drawTextureScaled(ParadiseEconomy.icons.jimoleon, 15, 27, 22, 22, 1)
    self:drawText("Account J: " .. ParadiseEconomy.getBalance(state.account, "jimoleon"), 42, 30, 0.85, 0.9, 0.95, 1, UIFont.Small)
    self:drawTextureScaled(ParadiseEconomy.icons.paradisium, 155, 27, 22, 22, 1)
    self:drawText("Account P: " .. ParadiseEconomy.getBalance(state.account, "paradisium"), 182, 30, 0.45, 1, 0.8, 1, UIFont.Small)
    self:drawText("Carried: " .. ParadiseEconomy.formatBalances(state.carried), 330, 30, 1, 0.85, 0.25, 1, UIFont.Small)
    if state.message then self:drawText(state.message, 15, self.height - 28, 1, 1, 1, 1, UIFont.Small) end
end

function ParadiseEconomy.MartPanel:new(x, y, w, h)
    local obj = ISCollapsableWindow.new(self, x, y, w, h)
    obj.title = "ParadiseMart"
    obj.resizable = true
    obj.direction = "buy"
    obj.adminMode = false
    obj.isAdm = ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(getPlayer()) or false
    return obj
end

function ParadiseEconomy.MartPanel:createChildren()
    ISCollapsableWindow.createChildren(self)
    self.tabs = ISComboBox:new(15, 35, 180, 25, self, ParadiseEconomy.MartPanel.refresh)
    self.tabs:initialise()
    self:addChild(self.tabs)
    self.buyButton = ISButton:new(205, 35, 90, 25, "Buy", self, ParadiseEconomy.MartPanel.setDirection)
    self.buyButton:initialise()
    self.buyButton.internal = "buy"
    self:addChild(self.buyButton)
    self.sellButton = ISButton:new(305, 35, 90, 25, "Sell", self, ParadiseEconomy.MartPanel.setDirection)
    self.sellButton:initialise()
    self.sellButton.internal = "sell"
    self:addChild(self.sellButton)
    self.playerButton = ISButton:new(405, 35, 120, 25, "Player Shop", self, ParadiseEconomy.MartPanel.setDirection)
    self.playerButton:initialise()
    self.playerButton.internal = "player"
    self:addChild(self.playerButton)
    self.manageButton = ISButton:new(535, 35, 145, 25, "Manage Market", self, ParadiseEconomy.MartPanel.toggleAdminMode)
    self.manageButton:initialise()
    self:addChild(self.manageButton)
    self.list = ISScrollingListBox:new(15, 70, self.width - 30, self.height - 150)
    self.list:initialise()
    self.list.itemheight = 24
    self.list.doDrawItem = ParadiseEconomy.MartPanel.drawListing
    self:addChild(self.list)
    self.quantity = ISTextEntryBox:new("1", 15, self.height - 65, 80, 25)
    self.quantity:initialise()
    self.quantity:instantiate()
    self.quantity:setOnlyNumbers(true)
    self:addChild(self.quantity)
    self.actionButton = ISButton:new(105, self.height - 65, 120, 25, "Buy Selected", self, ParadiseEconomy.MartPanel.onTrade)
    self.actionButton:initialise()
    self:addChild(self.actionButton)
    self.cancelButton = ISButton:new(235, self.height - 65, 140, 25, "Cancel My Listing", self, ParadiseEconomy.MartPanel.onCancelListing)
    self.cancelButton:initialise()
    self:addChild(self.cancelButton)
    self.adminView = ParadiseEconomy.MartAdminView:new(0, 65, self.width, self.height - 65, self)
    self.adminView:initialise()
    self.adminView:setVisible(false)
    self:addChild(self.adminView)
    self:refreshTabs()
end

function ParadiseEconomy.MartPanel:update()
    ISCollapsableWindow.update(self)
    if not ParadiseEconomy.canUsePlayerEconomy(getPlayer()) and ParadiseEconomy.MartPanel.ClosePanel then
        ParadiseEconomy.MartPanel.ClosePanel()
        return
    end
    self.isAdm = ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(getPlayer()) or false
    if not self.isAdm then self.adminMode = false end
    self.manageButton:setVisible(self.isAdm)
    self.adminView:setWidth(self.width)
    self.adminView:setHeight(self.height - 65)
    self.adminView:layout()
    self:applyModeVisibility()
end

function ParadiseEconomy.MartPanel:refreshTabs()
    self.tabs:clear()
    for _, tab in ipairs((ParadiseEconomy.clientState.market or {}).tabs or {}) do self.tabs:addOption(tab.name) end
    self:refresh()
    if self.adminView then self.adminView:refreshTabs() end
end

function ParadiseEconomy.MartPanel:toggleAdminMode()
    if not self.isAdm then return end
    self.adminMode = not self.adminMode
    self.manageButton:setTitle(self.adminMode and "Back to Market" or "Manage Market")
    self:setTitle(self.adminMode and "ParadiseMart - Manage" or "ParadiseMart")
    self:applyModeVisibility()
end

function ParadiseEconomy.MartPanel:applyModeVisibility()
    local showMarket = not self.adminMode
    self.tabs:setVisible(showMarket and self.direction ~= "player")
    self.buyButton:setVisible(showMarket)
    self.sellButton:setVisible(showMarket)
    self.playerButton:setVisible(showMarket)
    self.list:setVisible(showMarket)
    self.quantity:setVisible(showMarket and self.direction ~= "player")
    self.actionButton:setVisible(showMarket)
    self.cancelButton:setVisible(showMarket and self.direction == "player")
    self.adminView:setVisible(self.adminMode and self.isAdm)
end

function ParadiseEconomy.MartPanel:setDirection(button)
    self.direction = button.internal
    self.actionButton:setTitle(self.direction == "sell" and "Sell Selected" or "Buy Selected")
    self:refresh()
end

function ParadiseEconomy.MartPanel:getTab()
    local name = self.tabs.options[self.tabs.selected]
    for _, tab in ipairs((ParadiseEconomy.clientState.market or {}).tabs or {}) do
        if tab.name == name then return tab end
    end
end

function ParadiseEconomy.MartPanel:refresh()
    if not self.list then return end
    self.list:clear()
    if self.direction == "player" then
        for _, listing in ipairs((ParadiseEconomy.clientState.market or {}).playerListings or {}) do
            self.list:addItem(listing.itemData and listing.itemData.name or listing.id, listing)
        end
    else
        local tab = self:getTab()
        for _, listing in ipairs(tab and tab.listings or {}) do
            if listing.direction == self.direction then self.list:addItem(listing.fullType, listing) end
        end
    end
    self.tabs:setVisible(self.direction ~= "player")
    self.quantity:setVisible(self.direction ~= "player")
    self.cancelButton:setVisible(self.direction == "player")
    self:applyModeVisibility()
end

function ParadiseEconomy.MartPanel:drawListing(y, item, alt)
    local listing = item.item
    local label
    if listing.itemData then
        label = tostring(listing.itemData.name or listing.itemData.fullType) .. " | "
            .. ParadiseEconomy.ItemData.getSummary(listing.itemData) .. " | Seller " .. tostring(listing.seller)
            .. " | " .. tostring(listing.price) .. " " .. tostring(listing.currency)
    else
        label = listing.fullType .. " | " .. listing.price .. " " .. listing.currency
    end
    self:drawText(label, 8, y + 4, 1, 1, 1, 1, UIFont.Small)
    return y + self.itemheight
end

function ParadiseEconomy.MartPanel:onTrade()
    local selected = self.list.items[self.list.selected]
    if self.direction == "player" then
        if selected then ParadiseEconomy.send("playerShopBuy", { listingId = selected.item.id }) end
        return
    end
    local tabName = self.tabs.options[self.tabs.selected]
    if not selected or not tabName then return end
    ParadiseEconomy.send(self.direction == "buy" and "marketBuy" or "marketSell", {
        tabName = tabName,
        fullType = selected.item.fullType,
        quantity = self.quantity:getInternalText(),
    })
end

function ParadiseEconomy.MartPanel:onCancelListing()
    local selected = self.list.items[self.list.selected]
    if selected and selected.item and selected.item.id then
        ParadiseEconomy.send("playerShopCancel", { listingId = selected.item.id })
    end
end

function ParadiseEconomy.sync(module, command, args)
    if module ~= ParadiseEconomy.module then return end
    if command == "state" then
        ParadiseEconomy.clientState = args or ParadiseEconomy.clientState
        if ParadiseEconomy.instance then ParadiseEconomy.instance:refresh() end
        if ParadiseEconomy.martInstance then ParadiseEconomy.martInstance:refreshTabs() end
        if ParadiseEconomy.adminInstance then ParadiseEconomy.adminInstance:refresh() end
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
            context:addOption("Post in ParadiseMart", item, ParadiseEconomy.openListingPanel)
            return
        end
    end
end
Events.OnFillInventoryObjectContextMenu.Remove(ParadiseEconomy.fillInventoryContext)
Events.OnFillInventoryObjectContextMenu.Add(ParadiseEconomy.fillInventoryContext)

function ParadiseEconomy.ListingPanel:new(x, y, item)
    local obj = ISCollapsableWindow.new(self, x, y, 520, 190)
    obj.title = "Post Item in ParadiseMart"
    obj.item = item
    return obj
end

function ParadiseEconomy.ListingPanel:createChildren()
    ISCollapsableWindow.createChildren(self)
    self.currency = ISComboBox:new(15, 90, 145, 25, self)
    self.currency:initialise()
    self.currency:addOption("jimoleon")
    self.currency:addOption("paradisium")
    self:addChild(self.currency)
    self.price = ISTextEntryBox:new("", 170, 90, 120, 25)
    self.price:initialise()
    self.price:instantiate()
    self.price:setOnlyNumbers(true)
    self:addChild(self.price)
    self.postButton = ISButton:new(300, 90, 95, 25, "Post Item", self, ParadiseEconomy.ListingPanel.post)
    self.postButton:initialise()
    self:addChild(self.postButton)
    self.cancelButton = ISButton:new(405, 90, 95, 25, "Cancel", self, ParadiseEconomy.ListingPanel.close)
    self.cancelButton:initialise()
    self:addChild(self.cancelButton)
end

function ParadiseEconomy.ListingPanel:getTaxWarning()
    local percent = ParadiseEconomy.getPlayerShopTaxPercent()
    local payout, tax = ParadiseEconomy.getPlayerShopPayout(self.price:getInternalText())
    if payout then
        return "Sales tax warning: " .. string.format("%g", percent) .. "% deducts " .. tostring(tax) .. ". You receive " .. tostring(payout) .. "."
    end
    return "Sales tax warning: " .. string.format("%g", percent) .. "% is deducted from your sale payout."
end

function ParadiseEconomy.ListingPanel:prerender()
    ISCollapsableWindow.prerender(self)
    local data = ParadiseEconomy.ItemData.toData(self.item)
    self:drawText(tostring(self.item and self.item:getDisplayName() or "Item"), 15, 35, 1, 1, 1, 1, UIFont.Medium)
    self:drawText(ParadiseEconomy.ItemData.getSummary(data), 15, 62, 0.75, 0.85, 0.9, 1, UIFont.Small)
    self:drawText("Currency", 15, 120, 0.8, 0.8, 0.8, 1, UIFont.Small)
    self:drawText("Price", 170, 120, 0.8, 0.8, 0.8, 1, UIFont.Small)
    self:drawText(self:getTaxWarning(), 15, 145, 1, 0.65, 0.2, 1, UIFont.Small)
end

function ParadiseEconomy.ListingPanel:update()
    ISCollapsableWindow.update(self)
    if not ParadiseEconomy.canUsePlayerEconomy(getPlayer()) then self:close() end
end

function ParadiseEconomy.ListingPanel:post()
    if not self.item or not ParadiseEconomy.canUsePlayerEconomy(getPlayer()) then
        self:close()
        return
    end
    ParadiseEconomy.send("playerShopPost", {
        itemId = self.item:getID(),
        currency = self.currency.options[self.currency.selected],
        amount = self.price:getInternalText(),
    })
    self:close()
end

function ParadiseEconomy.ListingPanel:close()
    if ParadiseEconomy.listingInstance == self then ParadiseEconomy.listingInstance = nil end
    self:setVisible(false)
    self:removeFromUIManager()
end

function ParadiseEconomy.openListingPanel(item)
    if not item or not ParadiseEconomy.canUsePlayerEconomy(getPlayer()) then return end
    if ParadiseEconomy.listingInstance then ParadiseEconomy.listingInstance:close() end
    local panel = ParadiseEconomy.ListingPanel:new(
        (getCore():getScreenWidth() - 520) / 2,
        (getCore():getScreenHeight() - 190) / 2,
        item)
    panel:initialise()
    panel:addToUIManager()
    ParadiseEconomy.listingInstance = panel
end

function ParadiseEconomy.AdminPanel:new(x, y, w, h, targetUser)
    local obj = ISCollapsableWindow.new(self, x, y, w, h)
    obj.title = "Paradise Economy - Admin Accounts"
    obj.resizable = true
    obj.targetUsername = ParadiseEconomy.normalizeUsername(targetUser)
    return obj
end


function ParadiseEconomy.AdminPanel:createChildren()
    ISCollapsableWindow.createChildren(self)
    self.username = ISTextEntryBox:new(self.targetUsername or "Username", 15, 40, 180, 25)
    self.username:initialise()
    self.username:instantiate()
    self.username:setEditable(self.targetUsername == nil)
    self:addChild(self.username)
    self.currency = ISComboBox:new(205, 40, 130, 25, self)
    self.currency:initialise()
    self.currency:addOption("jimoleon")
    self.currency:addOption("paradisium")
    self:addChild(self.currency)
    self.amount = ISTextEntryBox:new("", 345, 40, 100, 25)
    self.amount:initialise()
    self.amount:instantiate()
    self.amount:setOnlyNumbers(true)
    self:addChild(self.amount)
    local add = ISButton:new(455, 40, 80, 25, "Add", self, ParadiseEconomy.AdminPanel.adjust)
    add:initialise()
    add.internal = "add"
    self:addChild(add)
    local remove = ISButton:new(545, 40, 80, 25, "Reduce", self, ParadiseEconomy.AdminPanel.adjust)
    remove:initialise()
    remove.internal = "remove"
    self:addChild(remove)
    local delete = ISButton:new(635, 40, 90, 25, "Delete Account", self, ParadiseEconomy.AdminPanel.deleteAccount)
    delete:initialise()
    self:addChild(delete)
    self.accounts = ISScrollingListBox:new(15, 80, self.width - 30, self.height - 110)
    self.accounts:initialise()
    self.accounts.itemheight = 24
    self.accounts.doDrawItem = ParadiseEconomy.AdminPanel.drawAccount
    self:addChild(self.accounts)
end

function ParadiseEconomy.AdminPanel:setTargetUsername(targetUser)
    self.targetUsername = ParadiseEconomy.normalizeUsername(targetUser)
    if not self.username then return end
    self.username:setText(self.targetUsername or "Username")
    self.username:setEditable(self.targetUsername == nil)
    self:setTitle(self.targetUsername and "Paradise Economy - " .. self.targetUsername or "Paradise Economy - Admin Accounts")
    self:refresh()
end

function ParadiseEconomy.AdminPanel:deleteAccount()
    ParadiseEconomy.send("adminDelete", { username = self.username:getInternalText() })
end

function ParadiseEconomy.AdminPanel:adjust(button)
    ParadiseEconomy.send("adminAdjust", {
        username = self.username:getInternalText(),
        currency = self.currency.options[self.currency.selected],
        amount = self.amount:getInternalText(),
        operation = button.internal,
    })
end

function ParadiseEconomy.AdminPanel:drawAccount(y, item, alt)
    local account = item.item
    self:drawText(account.username .. " | " .. ParadiseEconomy.formatBalances(account), 8, y + 4, 1, 1, 1, 1, UIFont.Small)
    return y + self.itemheight
end

function ParadiseEconomy.AdminPanel:refresh()
    if not self.accounts then return end
    self.accounts:clear()
    local targetKey = ParadiseEconomy.usernameKey(self.targetUsername)
    for _, account in pairs(ParadiseEconomy.clientState.accounts or {}) do
        if not targetKey or ParadiseEconomy.usernameKey(account.username) == targetKey then
            self.accounts:addItem(account.username, account)
        end
    end
end

function ParadiseEconomy.MartAdminView:new(x, y, w, h, mart)
    local obj = ISPanel.new(self, x, y, w, h)
    obj.mart = mart
    obj.selectedTabId = nil
    obj.selectedListingId = nil
    obj.lastWidth = 0
    obj.lastHeight = 0
    return obj
end

function ParadiseEconomy.MartAdminView:createChildren()
    ISPanel.createChildren(self)

    self.tabSearch = ISTextEntryBox:new("", 15, 48, 200, 25)
    self.tabSearch.target = self
    self.tabSearch.onTextChange = ParadiseEconomy.MartAdminView.onTabSearchChanged
    self.tabSearch:initialise()
    self.tabSearch:instantiate()
    self:addChild(self.tabSearch)
    self.tabFilterButton = ISButton:new(220, 48, 65, 25, "Search", self, ParadiseEconomy.MartAdminView.refreshTabs)
    self.tabFilterButton:initialise()
    self:addChild(self.tabFilterButton)
    self.tabs = ISScrollingListBox:new(15, 80, 270, 220)
    self.tabs:initialise()
    self.tabs.itemheight = 24
    self.tabs.doDrawItem = ParadiseEconomy.MartAdminView.drawTab
    self.tabs:setOnMouseDownFunction(self, ParadiseEconomy.MartAdminView.selectTab)
    self:addChild(self.tabs)
    self.tabName = ISTextEntryBox:new("", 15, 310, 270, 25)
    self.tabName:initialise()
    self:addChild(self.tabName)

    local tabButtons = {
        { "addTabButton", "Add", "createTab" }, { "renameTabButton", "Rename", "renameTab" },
        { "deleteTabButton", "Delete", "deleteTab" }, { "upTabButton", "Up", "moveTab" },
        { "downTabButton", "Down", "moveTab" },
    }
    for int, data in ipairs(tabButtons) do
        local button = ISButton:new(15 + (int - 1) * 55, 342, 50, 25, data[2], self, ParadiseEconomy.MartAdminView[data[3]])
        button:initialise()
        button.internal = data[1] == "upTabButton" and -1 or data[1] == "downTabButton" and 1 or nil
        self[data[1]] = button
        self:addChild(button)
    end

    self.listingSearch = ISTextEntryBox:new("", 300, 48, 250, 25)
    self.listingSearch.target = self
    self.listingSearch.onTextChange = ParadiseEconomy.MartAdminView.onListingSearchChanged
    self.listingSearch:initialise()
    self.listingSearch:instantiate()
    self:addChild(self.listingSearch)
    self.listingFilterButton = ISButton:new(555, 48, 65, 25, "Search", self, ParadiseEconomy.MartAdminView.refreshListings)
    self.listingFilterButton:initialise()
    self:addChild(self.listingFilterButton)
    self.listings = ISScrollingListBox:new(300, 80, self.width - 315, 287)
    self.listings:initialise()
    self.listings.itemheight = 26
    self.listings.doDrawItem = ParadiseEconomy.MartAdminView.drawListing
    self.listings:setOnMouseDownFunction(self, ParadiseEconomy.MartAdminView.selectListing)
    self:addChild(self.listings)

    self.itemSearch = ISTextEntryBox:new("", 15, 405, 225, 25)
    self.itemSearch.target = self
    self.itemSearch.onTextChange = ParadiseEconomy.MartAdminView.onItemSearchChanged
    self.itemSearch:initialise()
    self.itemSearch:instantiate()
    self:addChild(self.itemSearch)
    self.itemFilterButton = ISButton:new(245, 405, 70, 25, "Find Item", self, ParadiseEconomy.MartAdminView.refreshItems)
    self.itemFilterButton:initialise()
    self:addChild(self.itemFilterButton)
    self.items = ISScrollingListBox:new(15, 437, 300, self.height - 487)
    self.items:initialise()
    self.items.itemheight = 20
    self.items.font = UIFont.Small
    self.items.doDrawItem = ParadiseEconomy.MartAdminView.drawItem
    self.items:setOnMouseDownFunction(self, ParadiseEconomy.MartAdminView.selectItem)
    self:addChild(self.items)

    self.fullType = ISTextEntryBox:new("", 330, 437, self.width - 345, 25)
    self.fullType:initialise()
    self:addChild(self.fullType)
    self.direction = ISComboBox:new(330, 477, 180, 25, self)
    self.direction:initialise()
    self.direction:addOption("Server Sells / Player Buys")
    self.direction:addOption("Server Buys / Player Sells")
    self:addChild(self.direction)
    self.currency = ISComboBox:new(520, 477, 140, 25, self)
    self.currency:initialise()
    self.currency:addOption("jimoleon")
    self.currency:addOption("paradisium")
    self:addChild(self.currency)
    self.price = ISTextEntryBox:new("", 670, 477, 90, 25)
    self.price:initialise()
    self.price:instantiate()
    self.price:setOnlyNumbers(true)
    self:addChild(self.price)
    self.clearButton = ISButton:new(330, 517, 90, 25, "Clear", self, ParadiseEconomy.MartAdminView.clearEditor)
    self.clearButton:initialise()
    self:addChild(self.clearButton)
    self.deleteListingButton = ISButton:new(430, 517, 130, 25, "Delete Listing", self, ParadiseEconomy.MartAdminView.deleteListing)
    self.deleteListingButton:initialise()
    self:addChild(self.deleteListingButton)
    self.saveButton = ISButton:new(570, 517, 120, 25, "Save Listing", self, ParadiseEconomy.MartAdminView.saveListing)
    self.saveButton:initialise()
    self:addChild(self.saveButton)

    self:refreshItems()
    self:refreshTabs()
    self:layout()
end

function ParadiseEconomy.MartAdminView:getSelectedTab()
    for _, tab in ipairs((ParadiseEconomy.clientState.market or {}).tabs or {}) do
        if tostring(tab.id) == tostring(self.selectedTabId) then return tab end
    end
end

function ParadiseEconomy.MartAdminView:getSelectedListing()
    local tab = self:getSelectedTab()
    for _, listing in ipairs(tab and tab.listings or {}) do
        if tostring(listing.id) == tostring(self.selectedListingId) then return listing end
    end
end

function ParadiseEconomy.MartAdminView:drawTab(y, item, alt)
    local tab = item.item
    self:drawText(tostring(tab.name), 8, y + 4, 1, 1, 1, 1, UIFont.Small)
    self:drawTextRight(tostring(#(tab.listings or {})), self.width - 8, y + 4, 0.65, 0.8, 0.9, 1, UIFont.Small)
    return y + self.itemheight
end

function ParadiseEconomy.MartAdminView:drawListing(y, item, alt)
    local listing = item.item
    local action = listing.direction == "sell" and "Server Buys" or "Server Sells"
    self:drawText(tostring(listing.fullType), 8, y + 5, 1, 1, 1, 1, UIFont.Small)
    self:drawText(action, math.floor(self.width * 0.55), y + 5, 0.75, 0.9, 1, 1, UIFont.Small)
    self:drawTextRight(tostring(listing.price) .. " " .. tostring(listing.currency), self.width - 8, y + 5, 1, 0.85, 0.3, 1, UIFont.Small)
    return y + self.itemheight
end

function ParadiseEconomy.MartAdminView:drawItem(y, item, alt)
    if self.selected == item.index then self:drawRect(0, y, self.width, self.itemheight - 1, 0.3, 0.7, 0.35, 0.15) end
    self:drawText(tostring(item.text), 6, y + 2, 0.9, 0.9, 0.9, 1, UIFont.Small)
    return y + self.itemheight
end

function ParadiseEconomy.MartAdminView.onTabSearchChanged(entry)
    if entry and entry.target then entry.target:refreshTabs() end
end

function ParadiseEconomy.MartAdminView.onListingSearchChanged(entry)
    if entry and entry.target then entry.target:refreshListings() end
end

function ParadiseEconomy.MartAdminView.onItemSearchChanged(entry)
    if entry and entry.target then entry.target:refreshItems() end
end

function ParadiseEconomy.MartAdminView:refreshTabs()
    if not self.tabs then return end
    self.tabs:clear()
    local search = string.lower(self.tabSearch:getInternalText() or "")
    local selected
    for _, tab in ipairs((ParadiseEconomy.clientState.market or {}).tabs or {}) do
        if search == "" or string.lower(tab.name):find(search, 1, true) then
            self.tabs:addItem(tab.name, tab)
            if tostring(tab.id) == tostring(self.selectedTabId) then selected = #self.tabs.items end
        end
    end
    if selected then self.tabs.selected = selected end
    if not self:getSelectedTab() then
        self.selectedTabId = self.tabs.items[1] and self.tabs.items[1].item.id or nil
        self.selectedListingId = nil
    end
    local tab = self:getSelectedTab()
    self.tabName:setText(tab and tab.name or "")
    self:refreshListings()
end

function ParadiseEconomy.MartAdminView:selectTab(tab)
    if not tab then return end
    self.selectedTabId = tab.id
    self.selectedListingId = nil
    self.tabName:setText(tab.name or "")
    self:clearEditor()
    self:refreshListings()
end

function ParadiseEconomy.MartAdminView:refreshListings()
    if not self.listings then return end
    self.listings:clear()
    local search = string.lower(self.listingSearch:getInternalText() or "")
    local selected
    local tab = self:getSelectedTab()
    for _, listing in ipairs(tab and tab.listings or {}) do
        local text = string.lower(tostring(listing.fullType) .. " " .. tostring(listing.direction) .. " " .. tostring(listing.currency))
        if search == "" or text:find(search, 1, true) then
            self.listings:addItem(listing.fullType, listing)
            if tostring(listing.id) == tostring(self.selectedListingId) then selected = #self.listings.items end
        end
    end
    if selected then self.listings.selected = selected end
    if self.selectedListingId and not self:getSelectedListing() then self:clearEditor() end
end

function ParadiseEconomy.MartAdminView:selectListing(listing)
    if not listing then return end
    self.selectedListingId = listing.id
    self.fullType:setText(listing.fullType or "")
    self.direction.selected = listing.direction == "sell" and 2 or 1
    self.currency.selected = listing.currency == "paradisium" and 2 or 1
    self.price:setText(tostring(listing.price or ""))
end

function ParadiseEconomy.MartAdminView:createTab()
    ParadiseEconomy.send("adminMarketCreateTab", { tabName = self.tabName:getInternalText() })
end

function ParadiseEconomy.MartAdminView:renameTab()
    if self.selectedTabId then ParadiseEconomy.send("adminMarketRenameTab", { tabId = self.selectedTabId, tabName = self.tabName:getInternalText() }) end
end

function ParadiseEconomy.MartAdminView:deleteTab()
    local tab = self:getSelectedTab()
    if not tab then return end
    local modal = ISModalDialog:new(0, 0, 380, 160, "Delete market tab '" .. tostring(tab.name) .. "' and all listings?", true, self, ParadiseEconomy.MartAdminView.onDeleteTabConfirmed, nil, tab.id)
    modal:initialise()
    modal:addToUIManager()
end

function ParadiseEconomy.MartAdminView:onDeleteTabConfirmed(button, tabId)
    if button.internal == "YES" then
        self.selectedTabId = nil
        self.selectedListingId = nil
        ParadiseEconomy.send("adminMarketDeleteTab", { tabId = tabId })
    end
end

function ParadiseEconomy.MartAdminView:moveTab(button)
    if self.selectedTabId then ParadiseEconomy.send("adminMarketMoveTab", { tabId = self.selectedTabId, delta = button.internal }) end
end

function ParadiseEconomy.MartAdminView:saveListing()
    if not self.selectedTabId then return end
    ParadiseEconomy.send("adminMarketSaveListing", {
        tabId = self.selectedTabId,
        listingId = self.selectedListingId,
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
    local modal = ISModalDialog:new(0, 0, 380, 160, "Delete listing '" .. tostring(listing.fullType) .. "'?", true, self, ParadiseEconomy.MartAdminView.onDeleteListingConfirmed, nil, self.selectedTabId, listing.id)
    modal:initialise()
    modal:addToUIManager()
end

function ParadiseEconomy.MartAdminView:onDeleteListingConfirmed(button, tabId, listingId)
    if button.internal == "YES" then
        self.selectedListingId = nil
        ParadiseEconomy.send("adminMarketDeleteListing", { tabId = tabId, listingId = listingId })
    end
end

function ParadiseEconomy.MartAdminView:clearEditor()
    self.selectedListingId = nil
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
    if not self.tabs then return end
    local leftW = math.max(250, math.floor(self.width * 0.36))
    local rightX = leftW + 30
    local rightW = self.width - rightX - 15
    local topY = 80
    local topBottom = math.max(290, math.floor(self.height * 0.56))
    local tabNameY = topBottom - 70
    local tabButtonY = topBottom - 38
    local lowerTitleY = topBottom + 8
    local editorY = lowerTitleY + 22
    self.tabSearch:setWidth(leftW - 85)
    self.tabFilterButton:setX(leftW - 65)
    self.tabs:setWidth(leftW)
    self.tabs:setHeight(tabNameY - topY - 8)
    self.tabName:setY(tabNameY); self.tabName:setWidth(leftW)
    for int, button in ipairs({ self.addTabButton, self.renameTabButton, self.deleteTabButton, self.upTabButton, self.downTabButton }) do
        local buttonW = math.floor((leftW - 20) / 5)
        button:setX(15 + (int - 1) * (buttonW + 5)); button:setY(tabButtonY); button:setWidth(buttonW)
    end
    self.listingSearch:setX(rightX); self.listingSearch:setWidth(rightW - 75)
    self.listingFilterButton:setX(rightX + rightW - 70)
    self.listings:setX(rightX); self.listings:setWidth(rightW); self.listings:setHeight(topBottom - topY - 13)
    self.itemSearch:setY(editorY); self.itemSearch:setWidth(leftW - 75)
    self.itemFilterButton:setX(leftW - 50); self.itemFilterButton:setY(editorY)
    self.items:setY(editorY + 32); self.items:setWidth(leftW); self.items:setHeight(math.max(45, self.height - editorY - 47))
    self.fullType:setX(rightX); self.fullType:setY(editorY + 32); self.fullType:setWidth(rightW)
    self.direction:setX(rightX); self.direction:setY(editorY + 72); self.direction:setWidth(math.floor(rightW * 0.44))
    self.currency:setX(rightX + math.floor(rightW * 0.46)); self.currency:setY(editorY + 72); self.currency:setWidth(math.floor(rightW * 0.30))
    self.price:setX(rightX + math.floor(rightW * 0.78)); self.price:setY(editorY + 72); self.price:setWidth(math.floor(rightW * 0.22))
    self.clearButton:setX(rightX); self.clearButton:setY(editorY + 112)
    self.deleteListingButton:setX(rightX + 100); self.deleteListingButton:setY(editorY + 112)
    self.saveButton:setX(rightX + rightW - 120); self.saveButton:setY(editorY + 112)
    self.lastWidth = self.width
    self.lastHeight = self.height
end

function ParadiseEconomy.MartAdminView:update()
    ISPanel.update(self)
    if self.width ~= self.lastWidth or self.height ~= self.lastHeight then self:layout() end
    local hasTab = self:getSelectedTab() ~= nil
    local hasListing = self:getSelectedListing() ~= nil
    local fullType = self.fullType and self.fullType:getInternalText() or ""
    local price = self.price and self.price:getInternalText() or ""
    self.renameTabButton:setEnable(hasTab)
    self.deleteTabButton:setEnable(hasTab)
    self.upTabButton:setEnable(hasTab)
    self.downTabButton:setEnable(hasTab)
    self.deleteListingButton:setEnable(hasListing)
    self.saveButton:setEnable(hasTab and fullType ~= "" and price:match("^%d+$") ~= nil and tonumber(price) > 0)
end

function ParadiseEconomy.MartAdminView:prerender()
    ISPanel.prerender(self)
    local leftW = math.max(250, math.floor(self.width * 0.36))
    local rightX = leftW + 30
    self:drawText("Global market tabs", 15, 28, 0.7, 0.9, 1, 1, UIFont.Small)
    self:drawText("Listings", rightX, 28, 0.7, 0.9, 1, 1, UIFont.Small)
    local lowerTitleY = math.max(290, math.floor(self.height * 0.56)) + 8
    local editorY = lowerTitleY + 22
    self:drawText("Search item types", 15, lowerTitleY, 0.7, 0.9, 1, 1, UIFont.Small)
    self:drawText("Listing editor", rightX, lowerTitleY, 0.7, 0.9, 1, 1, UIFont.Small)
    local rightW = self.width - rightX - 15
    self:drawText("Item type", rightX, editorY + 14, 0.7, 0.75, 0.8, 1, UIFont.Small)
    self:drawText("Action", rightX, editorY + 54, 0.7, 0.75, 0.8, 1, UIFont.Small)
    self:drawText("Currency", rightX + math.floor(rightW * 0.46), editorY + 54, 0.7, 0.75, 0.8, 1, UIFont.Small)
    self:drawText("Price", rightX + math.floor(rightW * 0.78), editorY + 54, 0.7, 0.75, 0.8, 1, UIFont.Small)
    local message = ParadiseEconomy.clientState.message
    if message then self:drawText(tostring(message), math.max(280, math.floor(self.width * 0.36)) + 30, self.height - 28, 1, 0.9, 0.55, 1, UIFont.Small) end
end

function ParadiseEconomy.HUD:new(x, y)
    local obj = ISPanel.new(self, x, y, 270, 46)
    obj.backgroundColor = { r = 0, g = 0, b = 0, a = 0.55 }
    obj.borderColor = { r = 0.4, g = 0.7, b = 0.4, a = 0.8 }
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
    local carried = ParadiseEconomy.clientState.carried or {}
    self:drawTextureScaled(ParadiseEconomy.icons.jimoleon, 5, 4, 18, 18, 1)
    self:drawText("Jimoleons: " .. ParadiseEconomy.getBalance(carried, "jimoleon"), 28, 5, 1, 0.85, 0.2, 1, UIFont.Small)
    self:drawTextureScaled(ParadiseEconomy.icons.paradisium, 5, 23, 18, 18, 1)
    self:drawText("Paradisium: " .. ParadiseEconomy.getBalance(carried, "paradisium"), 28, 24, 0.5, 0.9, 1, 1, UIFont.Small)
end

function ParadiseEconomy.createHUD()
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
