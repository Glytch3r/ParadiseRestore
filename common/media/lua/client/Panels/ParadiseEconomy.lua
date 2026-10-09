require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
require "ISUI/ISComboBox"
require "ISUI/ISScrollingListBox"
require "ISUI/ISPanel"
require "TimedActions/ISInventoryTransferAction"
require "TimedActions/ISTimedActionQueue"

ParadiseEconomy = ParadiseEconomy or {}
ParadiseEconomy.clientState = ParadiseEconomy.clientState or { account = {}, carried = {}, transactions = {}, market = { tabs = {} } }
ParadiseEconomy.icons = ParadiseEconomy.icons or {
    jimoleon = getTexture("media/ui/Paradise/Economy/Jimoleon.png"),
    paradisium = getTexture("media/ui/Paradise/Economy/Paradisium.png"),
}
ParadiseEconomy.Panel = ISCollapsableWindow:derive("ParadiseEconomyPanel")
ParadiseEconomy.MartPanel = ISCollapsableWindow:derive("ParadiseMartPanel")
ParadiseEconomy.AdminPanel = ISCollapsableWindow:derive("ParadiseEconomyAdminPanel")
ParadiseEconomy.MartAdminPanel = ISCollapsableWindow:derive("ParadiseMartAdminPanel")
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
    self.transactions = ISScrollingListBox:new(15, 130, self.width - 30, self.height - 170)
    self.transactions:initialise()
    self.transactions.itemheight = 24
    self.transactions.doDrawItem = ParadiseEconomy.Panel.drawTransaction
    self:addChild(self.transactions)
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
    self.list = ISScrollingListBox:new(15, 70, self.width - 30, self.height - 150)
    self.list:initialise()
    self.list.itemheight = 24
    self.list.doDrawItem = ParadiseEconomy.MartPanel.drawListing
    self:addChild(self.list)
    self.quantity = ISTextEntryBox:new("1", 15, self.height - 65, 80, 25)
    self.quantity:initialise()
    self.quantity:setOnlyNumbers(true)
    self:addChild(self.quantity)
    self.actionButton = ISButton:new(105, self.height - 65, 120, 25, "Buy Selected", self, ParadiseEconomy.MartPanel.onTrade)
    self.actionButton:initialise()
    self:addChild(self.actionButton)
    self:refreshTabs()
end

function ParadiseEconomy.MartPanel:refreshTabs()
    self.tabs:clear()
    for _, tab in ipairs((ParadiseEconomy.clientState.market or {}).tabs or {}) do self.tabs:addOption(tab.name) end
    self:refresh()
end

function ParadiseEconomy.MartPanel:setDirection(button)
    self.direction = button.internal
    self.actionButton:setTitle(self.direction == "buy" and "Buy Selected" or "Sell Selected")
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
    local tab = self:getTab()
    for _, listing in ipairs(tab and tab.listings or {}) do
        if listing.direction == self.direction then self.list:addItem(listing.fullType, listing) end
    end
end

function ParadiseEconomy.MartPanel:drawListing(y, item, alt)
    local listing = item.item
    self:drawText(listing.fullType .. " | " .. listing.price .. " " .. listing.currency, 8, y + 4, 1, 1, 1, 1, UIFont.Small)
    return y + self.itemheight
end

function ParadiseEconomy.MartPanel:onTrade()
    local selected = self.list.items[self.list.selected]
    local tabName = self.tabs.options[self.tabs.selected]
    if not selected or not tabName then return end
    ParadiseEconomy.send(self.direction == "buy" and "marketBuy" or "marketSell", {
        tabName = tabName,
        fullType = selected.item.fullType,
        quantity = self.quantity:getInternalText(),
    })
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
    if not pl then return end
    for _, selected in ipairs(items or {}) do
        local item = selected.items and selected.items[1] or selected
        if ParadiseEconomy.isWallet(item) then
            local wallet = ParadiseEconomy.getWalletData(item)
            if ParadiseEconomy.hasMoney(wallet) then
                context:addOption("Pillage " .. ParadiseEconomy.formatBalances(wallet), item, ParadiseEconomy.pillage, pl)
                return
            end
        end
    end
end
Events.OnFillInventoryObjectContextMenu.Remove(ParadiseEconomy.fillInventoryContext)
Events.OnFillInventoryObjectContextMenu.Add(ParadiseEconomy.fillInventoryContext)

function ParadiseEconomy.AdminPanel:new(x, y, w, h)
    local obj = ISCollapsableWindow.new(self, x, y, w, h)
    obj.title = "Paradise Economy - Admin Accounts"
    obj.resizable = true
    return obj
end


function ParadiseEconomy.AdminPanel:createChildren()
    ISCollapsableWindow.createChildren(self)
    self.username = ISTextEntryBox:new("Username", 15, 40, 180, 25)
    self.username:initialise()
    self:addChild(self.username)
    self.currency = ISComboBox:new(205, 40, 130, 25, self)
    self.currency:initialise()
    self.currency:addOption("jimoleon")
    self.currency:addOption("paradisium")
    self:addChild(self.currency)
    self.amount = ISTextEntryBox:new("", 345, 40, 100, 25)
    self.amount:initialise()
    self.amount:setOnlyNumbers(true)
    self:addChild(self.amount)
    local add = ISButton:new(455, 40, 80, 25, "Add", self, ParadiseEconomy.AdminPanel.adjust)
    add:initialise()
    add.internal = "add"
    self:addChild(add)
    local remove = ISButton:new(545, 40, 80, 25, "Remove", self, ParadiseEconomy.AdminPanel.adjust)
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
    for _, account in pairs(ParadiseEconomy.clientState.accounts or {}) do self.accounts:addItem(account.username, account) end
end

function ParadiseEconomy.MartAdminPanel:new(x, y, w, h)
    local obj = ISCollapsableWindow.new(self, x, y, w, h)
    obj.title = "ParadiseMart - Admin"
    return obj
end


function ParadiseEconomy.MartAdminPanel:createChildren()
    ISCollapsableWindow.createChildren(self)
    local fields = { { "tabName", "Tab name", 15, 180 }, { "fullType", "Base.Item", 205, 230 }, { "price", "Price", 445, 90 } }
    for _, field in ipairs(fields) do
        self[field[1]] = ISTextEntryBox:new(field[2], field[3], 45, field[4], 25)
        self[field[1]]:initialise()
        self:addChild(self[field[1]])
    end
    self.price:setOnlyNumbers(true)
    self.direction = ISComboBox:new(15, 85, 120, 25, self)
    self.direction:initialise()
    self.direction:addOption("buy")
    self.direction:addOption("sell")
    self:addChild(self.direction)
    self.currency = ISComboBox:new(145, 85, 140, 25, self)
    self.currency:initialise()
    self.currency:addOption("jimoleon")
    self.currency:addOption("paradisium")
    self:addChild(self.currency)
    local save = ISButton:new(295, 85, 140, 25, "Save Listing", self, ParadiseEconomy.MartAdminPanel.save)
    save:initialise()
    self:addChild(save)
    self.notice = "Create a tab by saving its first listing."
    self.search = ISTextEntryBox:new("", 15, 125, 250, 25)
    self.search:initialise()
    self:addChild(self.search)
    local filter = ISButton:new(275, 125, 100, 25, "Filter Items", self, ParadiseEconomy.MartAdminPanel.refreshItems)
    filter:initialise()
    self:addChild(filter)
    self.items = ISScrollingListBox:new(15, 160, self.width - 30, self.height - 175)
    self.items:initialise()
    self.items.itemheight = 23
    self.items:setOnMouseDownFunction(self, ParadiseEconomy.MartAdminPanel.selectItem)
    self:addChild(self.items)
    self:refreshItems()
end

function ParadiseEconomy.MartAdminPanel:save()
    ParadiseEconomy.send("adminMarketSave", {
        tabName = self.tabName:getInternalText(),
        fullType = self.fullType:getInternalText(),
        price = self.price:getInternalText(),
        amount = self.price:getInternalText(),
        direction = self.direction.options[self.direction.selected],
        currency = self.currency.options[self.currency.selected],
    })
end

function ParadiseEconomy.MartAdminPanel:prerender()
    ISCollapsableWindow.prerender(self)
    self:drawText("Tab and item", 15, 28, 1, 1, 1, 1, UIFont.Small)
    self:drawText(self.notice, 390, 130, 0.7, 0.8, 0.9, 1, UIFont.Small)
end

function ParadiseEconomy.MartAdminPanel:refreshItems()
    if not self.items then return end
    self.items:clear()
    local search = string.lower(self.search and self.search:getInternalText() or "")
    local all = ScriptManager.instance:getAllItems()
    for int = 0, all:size() - 1 do
        local scrItem = all:get(int)
        local fullType = scrItem:getFullName()
        local displayName = scrItem:getDisplayName()
        if search == "" or string.lower(fullType):find(search, 1, true) or string.lower(displayName):find(search, 1, true) then
            self.items:addItem(displayName .. " | " .. fullType, fullType)
        end
    end
end

function ParadiseEconomy.MartAdminPanel:selectItem(fullType)
    if fullType then self.fullType:setText(fullType) end
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
    ParadiseEconomy.send("requestState")
end
Events.OnCreatePlayer.Remove(ParadiseEconomy.createHUD)
Events.OnCreatePlayer.Add(ParadiseEconomy.createHUD)
