ParadiseRestore = ParadiseRestore or {}
ParadiseCloner = ParadiseCloner or {}

local function labelPrompt(title, callback)
    local modal = ISTextBox:new(title, "Label", "", 300, 150, true, ParadiseCloner, callback, nil)
    modal:initialise(); modal:addToUIManager(); modal:bringToTop()
end

function ParadiseCloner.onLabel(target, button)
    if button.internal == "OK" then ParadiseCloner.submitRecord(target.entry:getText(), false) end
end

function ParadiseCloner.inventoryContext(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player or not ParadiseRestore.isAdm or not ParadiseRestore.isAdm(player) then return end
    local selected = {}
    for _, entry in ipairs(items or {}) do
        local item = entry.items and entry.items[1] or entry
        if instanceof(item, "InventoryItem") then selected[#selected + 1] = { item = item, location = "inventory" } end
    end
    if #selected == 0 then return end
    context:addOption("Record Paradise Loadout", nil, function()
        ParadiseCloner.pendingItems = selected
        labelPrompt("Record Loadout", ParadiseCloner.onLabel)
    end)
end

function ParadiseCloner.addTargetOption(context, target)
    context:addOption("Paradise Loadout Record", target, ParadiseCloner.openPanel, target)
    context:addOption("Record Target Inventory", target, function(targ)
        ParadiseCloner.pendingTarget = targ:getUsername()
        labelPrompt("Record Target Inventory", function(box, button)
        if button.internal == "OK" then sendClientCommand(getPlayer(), ParadiseCloner.module, "recordTarget", { username = ParadiseCloner.pendingTarget, key = box.entry:getText() }) end
        end)
    end)
end

Events.OnFillInventoryObjectContextMenu.Remove(ParadiseCloner.inventoryContext)
Events.OnFillInventoryObjectContextMenu.Add(ParadiseCloner.inventoryContext)

ParadiseCloner.LoadoutPanel = ISCollapsableWindow:derive("ParadiseCloner.LoadoutPanel")
ParadiseCloner.panels = ParadiseCloner.panels or {}
function ParadiseCloner.LoadoutPanel:createChildren()
    ISCollapsableWindow.createChildren(self)
    self.list = ISScrollingListBox:new(12, self:titleBarHeight() + 12, self.width - 24, self.height - 80)
    self.list:initialise(); self.list:instantiate(); self:addChild(self.list)
    self.spawn = ISButton:new(12, self.height - 56, 110, 26, "Spawn", self, function() local e = self.list.items[self.list.selected]; if e then ParadiseCloner.cloneRecord(e.item, self.owner, self.targetUsername) end end)
    self.spawn:initialise(); self.spawn:instantiate(); self:addChild(self.spawn)
    self.delete = ISButton:new(130, self.height - 56, 110, 26, "Delete", self, function() local e = self.list.items[self.list.selected]; if e then sendClientCommand(getPlayer(), ParadiseCloner.module, "delete", { owner = self.owner, recordkey = e.item }) end; self:populate() end)
    self.delete:initialise(); self.delete:instantiate(); self:addChild(self.delete)
    self:populate()
end
function ParadiseCloner.LoadoutPanel:populate()
    self.list:clear()
    local records = ParadiseCloner.remoteRecords and ParadiseCloner.remoteRecords[self.owner] or ParadiseCloner.getRecords(self.owner)
    for key in pairs(records) do self.list:addItem(key, key) end
end
function ParadiseCloner.LoadoutPanel:close()
    ISCollapsableWindow.close(self)
    if ParadiseCloner.panels[self.owner] == self then ParadiseCloner.panels[self.owner] = nil end
end
function ParadiseCloner.openPanel(target)
    if not ParadiseRestore.isAdm or not ParadiseRestore.isAdm(getPlayer()) then return end
    target = target or getPlayer()
    local owner = ParadiseCloner.ownerKey(target)
    local existing = ParadiseCloner.panels[owner]
    if existing then existing:setVisible(true); existing:bringToTop(); existing:populate(); return end
    local panel = ParadiseCloner.LoadoutPanel:new(300, 180, 420, 320)
    panel.owner = owner
    panel.targetUsername = target.getUsername and target:getUsername() or tostring(target)
    panel.title = "Paradise Loadout Record - " .. tostring(target.getUsername and target:getUsername() or target)
    panel:initialise(); panel:addToUIManager(); ParadiseCloner.panels[owner] = panel
    if owner ~= ParadiseCloner.ownerKey(getPlayer()) then sendClientCommand(getPlayer(), ParadiseCloner.module, "fetch", { owner = owner }) end
end

function ParadiseCloner.onServerCommand(module, command, args)
    if module ~= ParadiseCloner.module or command ~= "records" or not args then return end
    ParadiseCloner.remoteRecords = ParadiseCloner.remoteRecords or {}
    ParadiseCloner.remoteRecords[args.owner] = args.records or {}
    if ParadiseCloner.panels[args.owner] then ParadiseCloner.panels[args.owner]:populate() end
end
Events.OnServerCommand.Add(ParadiseCloner.onServerCommand)
