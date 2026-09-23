ParadiseDev = ParadiseDev or {}
ParadiseDev.TraitSyncer = ParadiseDev.TraitSyncer or {}
local Syncer = ParadiseDev.TraitSyncer

if LuaEventManager and LuaEventManager.AddEvent then
    LuaEventManager.AddEvent("OnTraitsSync")
end

Syncer.StoreName = "ParadiseDev_TraitSyncer"
Syncer.Traits = {
    "ParadiseDev:TheRangeStaff",
    "ParadiseDev:Caged",
    "ParadiseDev:InjuredPvP",
    "ParadiseDev:PvE",
    "ParadiseDev:Reincarnate",
}
Syncer.window = nil
Syncer.entries = {}
Syncer.lastSync = 0

function Syncer.getStore()
    return ModData.get(Syncer.StoreName) or ModData.getOrCreate(Syncer.StoreName)
end

function Syncer.has(player, traitId)
    return player and ParadiseDev.hasTrait and ParadiseDev.hasTrait(player, traitId) or false
end

function Syncer.setLocal(player, traitId, enabled)
    local trait = ParadiseDev.getTrait and ParadiseDev.getTrait(traitId) or nil
    if not player or not trait or not player.getCharacterTraits then return false end
    local traits = player:getCharacterTraits()
    local present = Syncer.has(player, traitId)
    if enabled and not present then traits:add(trait)
    elseif not enabled and present then traits:remove(trait)
    else return false end
    if player.modifyTraitXPBoost then player:modifyTraitXPBoost(trait, true) end
    if SyncXp then SyncXp(player) end
    if triggerEvent then triggerEvent("OnTraitsSync", traitId, enabled == true) end
    return true
end

function Syncer.cleanDuplicates(player)
    if not player or not player.getCharacterTraits then return end
    local traits = player:getCharacterTraits()
    for _, traitId in ipairs(Syncer.Traits) do
        local trait = ParadiseDev.getTrait and ParadiseDev.getTrait(traitId) or nil
        if trait and traits:contains(trait) then
            traits:remove(trait)
            traits:add(trait)
        end
    end
end

function Syncer.syncPlayer(player)
    if not player or not player.getUsername then return end
    local username = tostring(player:getUsername())
    local store = Syncer.getStore()
    local record = store.players and store.players[username] or nil
    if type(record) ~= "table" then record = {} end
    for _, traitId in ipairs(Syncer.Traits) do
        Syncer.setLocal(player, traitId, record[traitId] == true)
    end
    Syncer.cleanDuplicates(player)
    if ISPlayerStatsUI and ISPlayerStatsUI.instance and ISPlayerStatsUI.instance.loadTraits then
        ISPlayerStatsUI.instance:loadTraits()
    end
end

function Syncer.requestSet(username, traitId, enabled)
    if sendClientCommand then
        sendClientCommand("ParadiseDevTraitSyncer", "set", {
            username = tostring(username), trait = traitId, enabled = enabled == true,
        })
    end
end

function Syncer.isTargetTrait(target, traitId)
    return Syncer.has(target, traitId)
end

function Syncer.setTarget(_, target, traitId, enabled)
    if target and target.getUsername then Syncer.requestSet(target:getUsername(), traitId, enabled) end
end

function Syncer.addTargetMenu(menu, target)
    if not menu or not target or not target.getUsername then return end
    local root = menu:addOption("Trait Syncer")
    local submenu = ISContextMenu:getNew(menu)
    menu:addSubMenu(root, submenu)
    for _, traitId in ipairs(Syncer.Traits) do
        local enabled = Syncer.isTargetTrait(target, traitId)
        local option = submenu:addOption((enabled and "Remove " or "Add ") .. traitId, nil, Syncer.setTarget, target, traitId, not enabled)
        option.toolTip = "Global trait state: " .. (enabled and "TRUE" or "FALSE")
    end
end

Syncer.Panel = ISCollapsableWindow:derive("ParadiseDev.TraitSyncer.Panel")
function Syncer.Panel:createChildren()
    ISCollapsableWindow.createChildren(self)
    local top = self:titleBarHeight() + 10
    self.info = ISLabel:new(12, top, 18, "Trait assignments", 0.85, 0.9, 1, 1, UIFont.Small, true)
    self.info:initialise(); self.info:instantiate(); self:addChild(self.info)
    self.usernameEntry = ISTextEntryBox:new("", 84, top + 24, self.width - 222, 24)
    self.usernameEntry:initialise(); self.usernameEntry:instantiate(); self:addChild(self.usernameEntry)
    self.addButton = ISButton:new(self.width - 128, top + 24, 116, 24, "Add", self, Syncer.Panel.onClick)
    self.addButton.internal = "ADD"; self.addButton:initialise(); self.addButton:instantiate(); self:addChild(self.addButton)
    self.list = ISScrollingListBox:new(12, top + 54, self.width - 24, self.height - top - 108)
    self.list:initialise(); self.list:instantiate(); self.list.itemheight = 22; self.list.font = UIFont.Small; self.list.drawBorder = true; self:addChild(self.list)
    self.refreshButton = ISButton:new(self.width - 122, self.height - 42, 110, 26, "Refresh", self, Syncer.Panel.onClick)
    self.refreshButton.internal = "REFRESH"; self.refreshButton:initialise(); self.refreshButton:instantiate(); self:addChild(self.refreshButton)
    self.trueButton = ISButton:new(12, self.height - 42, 110, 26, "Set TRUE", self, Syncer.Panel.onClick)
    self.trueButton.internal = "TRUE"; self.trueButton:initialise(); self.trueButton:instantiate(); self:addChild(self.trueButton)
    self.falseButton = ISButton:new(128, self.height - 42, 110, 26, "Set FALSE", self, Syncer.Panel.onClick)
    self.falseButton.internal = "FALSE"; self.falseButton:initialise(); self.falseButton:instantiate(); self:addChild(self.falseButton)
    Syncer.refreshPanel()
end
function Syncer.Panel:onClick(button)
    if button.internal == "REFRESH" then Syncer.requestState(); return end
    local username = self.usernameEntry and self.usernameEntry:getText() or ""
    if button.internal == "ADD" and username ~= "" then
        Syncer.requestSet(username, Syncer.Traits[1], true); self.usernameEntry:setText("")
        return
    end
    if button.internal == "TRUE" or button.internal == "FALSE" then
        local item = self.list.items[self.list.selected]
        local entry = item and item.item or nil
        if entry then Syncer.requestSet(entry.username, entry.trait, button.internal == "TRUE") end
    end
end
function Syncer.Panel:new(x, y, width, height)
    local panel = ISCollapsableWindow:new(x, y, width, height); setmetatable(panel, self); self.__index = self
    panel.title = "ParadiseZ Trait Syncer"; panel.resizable = true; return panel
end
function Syncer.refreshPanel()
    if not Syncer.window or not Syncer.window.list then return end
    Syncer.window.list:clear()
    for _, entry in ipairs(Syncer.entries) do
        for _, traitId in ipairs(Syncer.Traits) do
            local enabled = entry.traits and entry.traits[traitId] == true
            Syncer.window.list:addItem(tostring(entry.username) .. " | " .. traitId .. " | " .. (enabled and "TRUE" or "FALSE"), {
                username = entry.username, trait = traitId, enabled = enabled,
            })
        end
    end
end
function Syncer.requestState()
    if sendClientCommand then sendClientCommand("ParadiseDevTraitSyncer", "list", {}) end
end
function Syncer.openPanel()
    if not ParadiseDev.isAdm() then return end
    if Syncer.window then Syncer.window:setVisible(true); Syncer.window:bringToTop(); Syncer.requestState(); return end
    local panel = Syncer.Panel:new(220, 180, 700, 420); panel:initialise(); panel:addToUIManager(); panel:setVisible(true); Syncer.window = panel; Syncer.requestState()
end
function Syncer.onServerCommand(module, command, args)
    if module ~= "ParadiseDevTraitSyncer" then return end
    if command == "state" then Syncer.entries = args and args.entries or {}; Syncer.refreshPanel() end
end
function Syncer.onPlayerUpdate(player)
    if not player or player ~= getPlayer() then return end
    local now = getTimestampMs and getTimestampMs() or 0
    if now - Syncer.lastSync < 1000 then return end
    Syncer.lastSync = now; Syncer.syncPlayer(player)
end
Events.OnServerCommand.Add(Syncer.onServerCommand)
Events.OnPlayerUpdate.Add(Syncer.onPlayerUpdate)
