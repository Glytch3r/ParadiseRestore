require "Dev/ParadiseEconomy/ParadiseEconomy_Shared"
require "TimedActions/ISBaseTimedAction"
require "ISUI/ISPanel"
require "ISUI/ISLabel"
require "ISUI/ISButton"
require "RadioCom/ISUIRadio/ISSliderPanel"

local economy = ParadiseEconomy
economy.balance = economy.balance or { gold = 0, silver = 0 }

economy.Action = ISBaseTimedAction:derive("ParadiseEconomy.Action")
function economy.Action:isValid() return self.character and self.character:isAlive() end
function economy.Action:start() self:setActionAnim("Loot") end
function economy.Action:perform()
    ISBaseTimedAction.perform(self)
    sendClientCommand(self.character, economy.module, self.command, self.args)
end
function economy.Action:new(pl, command, args, time)
    local action = ISBaseTimedAction.new(self, pl)
    setmetatable(action, self); self.__index = self
    action.character, action.command, action.args, action.maxTime = pl, command, args, time
    action.stopOnWalk, action.stopOnRun = true, true
    if pl:isTimedActionInstant() then action.maxTime = 1 end
    return action
end

function economy.queue(pl, command, args, time)
    ISTimedActionQueue.add(economy.Action:new(pl, command, args, time))
end

function economy.items(items)
    local result = {}
    for _, entry in ipairs(items or {}) do
        local item = instanceof(entry, "InventoryItem") and entry or entry.items and entry.items[1]
        if item and economy.getCoin(item) then result[#result + 1] = item end
    end
    return result
end

function economy.addContext(plNum, context, items)
    local pl, selected = getSpecificPlayer(plNum), economy.items(items)
    if not pl or #selected ~= 1 then return end
    local item, coin, count = selected[1], economy.getCoin(selected[1]), economy.getCount(selected[1])
    local root = context:addOption(coin.label)
    local menu = ISContextMenu:getNew(context); context:addSubMenu(root, menu)
    menu:addOption("Deposit " .. tostring(count), function() economy.queue(pl, "deposit", { itemID = item:getID() }, 30) end)
    if count > 1 then menu:addOption("Split Half", function() economy.queue(pl, "split", { itemID = item:getID(), count = math.floor(count / 2) }, 30) end) end
    local merge = menu:addOption("Merge")
    local mergeMenu = ISContextMenu:getNew(context); menu:addSubMenu(merge, mergeMenu)
    local all = {}
    local function scan(container)
        local list = container:getItems()
        for i = 0, list:size() - 1 do local other = list:get(i); all[#all + 1] = other; if other.getInventory then scan(other:getInventory()) end end
    end
    scan(pl:getInventory())
    for _, other in ipairs(all) do
        if other ~= item and other:getFullType() == item:getFullType() and economy.hasStack(other) then
            mergeMenu:addOption(other:getDisplayName(), function() economy.queue(pl, "merge", { targetID = item:getID(), sourceID = other:getID() }, 15 + economy.getCount(other) * 5) end)
        end
    end
    local mergeAllCount = 0
    for _, other in ipairs(all) do if other ~= item and other:getFullType() == item:getFullType() then mergeAllCount = mergeAllCount + economy.getCount(other) end end
    menu:addOption("Merge All", function() economy.queue(pl, "mergeAll", { targetID = item:getID() }, 15 + mergeAllCount * 5) end)
end

function economy.autoStack()
    local pl = getPlayer(); if not pl then return end
    local byType = {}
    local function scan(container)
        local list = container:getItems()
        for i = 0, list:size() - 1 do local item = list:get(i); if economy.getCoin(item) then byType[item:getFullType()] = byType[item:getFullType()] or {}; table.insert(byType[item:getFullType()], item) end; if item.getInventory then scan(item:getInventory()) end end
    end
    scan(pl:getInventory())
    for _, coins in pairs(byType) do
        local target
        for _, item in ipairs(coins) do if economy.hasStack(item) then target = item; break end end
        if not target and #coins > 1 then target = coins[1] end
        if target then for _, item in ipairs(coins) do if item ~= target and not economy.hasStack(item) then sendClientCommand(pl, economy.module, "autoStack", { targetID = target:getID(), sourceID = item:getID() }) end end end
    end
end

economy.Panel = ISPanel:derive("ParadiseEconomy.Panel")
function economy.Panel:new(pl)
    local width, height = 410, 260
    local panel = ISPanel:new((getCore():getScreenWidth()-width)/2, (getCore():getScreenHeight()-height)/2, width, height)
    setmetatable(panel, self); self.__index = self
    panel.player, panel.moveWithMouse = pl, true
    panel.backgroundColor, panel.borderColor = { r=0, g=0, b=0, a=0.85 }, { r=0.5, g=0.5, b=0.5, a=1 }
    return panel
end
function economy.Panel:updateLine(key, value)
    value = math.floor(value)
    self[key .. "Value"]:setName("Stored: " .. tostring(economy.balance[key]) .. "    Withdraw: " .. tostring(value) .. "    Value: " .. tostring(value))
end
function economy.Panel:onSlide(key, value) self:updateLine(key, value) end
function economy.Panel:onWithdraw(key)
    local count = math.floor(self[key .. "Slider"]:getCurrentValue())
    if count > 0 then economy.queue(self.player, "withdraw", { key = key, count = count }, 30) end
end
function economy.Panel:onClose() self:removeFromUIManager(); economy.panel = nil end
function economy.Panel:createChildren()
    ISPanel.createChildren(self)
    local title = ISLabel:new(12, 12, 20, tostring(self.player:getUsername()) .. " Finance Manager", 1, 1, 1, 1, UIFont.Medium, true); title:initialise(); title:instantiate(); self:addChild(title)
    for index, key in ipairs({ "gold", "silver" }) do
        local y, label = 55 + (index - 1) * 85, "FU " .. (key == "gold" and "Gold" or "Silver") .. " Coins"
        local name = ISLabel:new(12, y, 20, label, 1, 1, 1, 1, UIFont.Small, true); name:initialise(); name:instantiate(); self:addChild(name)
        self[key .. "Value"] = ISLabel:new(12, y + 22, 20, "", 1, 1, 1, 1, UIFont.Small, true); self[key .. "Value"]:initialise(); self[key .. "Value"]:instantiate(); self:addChild(self[key .. "Value"])
        local slider = ISSliderPanel:new(12, y + 45, 270, 20, self, function(_, value) self:onSlide(key, value) end); slider:initialise(); slider:instantiate(); slider:setValues(0, math.max(1, economy.balance[key]), 1, 5, true); slider:setCurrentValue(0, true); self:addChild(slider); self[key .. "Slider"] = slider
        local button = ISButton:new(295, y + 42, 100, 26, "Withdraw", self, function() self:onWithdraw(key) end); button:initialise(); button:instantiate(); self:addChild(button)
        self:updateLine(key, 0)
    end
    local close = ISButton:new(285, 220, 110, 26, "Close", self, economy.Panel.onClose); close:initialise(); close:instantiate(); self:addChild(close)
end
function economy.openPanel(pl)
    pl = pl or getPlayer(); if not pl then return end
    if economy.panel then economy.panel:onClose() end
    sendClientCommand(pl, economy.module, "requestBalance", {})
    local panel = economy.Panel:new(pl); panel:initialise(); panel:addToUIManager(); economy.panel = panel
end
function economy.refreshPanel()
    if not economy.panel then return end
    local pl = economy.panel.player
    economy.panel:onClose()
    local panel = economy.Panel:new(pl); panel:initialise(); panel:addToUIManager(); economy.panel = panel
end
function economy.onCommand(module, command, args)
    if module ~= economy.module then return end
    if command == "balance" then
        economy.balance.gold, economy.balance.silver = math.max(0, tonumber(args.gold) or 0), math.max(0, tonumber(args.silver) or 0)
        economy.refreshPanel()
    elseif command == "halo" and args and args.text then HaloTextHelper.addText(getPlayer(), args.text, HaloTextHelper.getColorGreen()) end
end

Events.OnFillInventoryObjectContextMenu.Add(economy.addContext)
Events.OnContainerUpdate.Add(economy.autoStack)
Events.OnServerCommand.Add(economy.onCommand)
