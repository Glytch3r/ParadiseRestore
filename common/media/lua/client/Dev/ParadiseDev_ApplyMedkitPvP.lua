
ParadiseDev = ParadiseDev or {}
ParadiseDev.ApplyMedkitPvP = ISBaseTimedAction:derive("ParadiseDev.ApplyMedkitPvP")

function ParadiseDev.ApplyMedkitPvP:isValid()
    if ParadiseDev.PvP and ParadiseDev.PvP.isEnabled and not ParadiseDev.PvP.isEnabled() then return false end
    local md = self.character:getModData()
    return self.item and self.character:getInventory():contains(self.item) and
        ((ParadiseDev.hasTrait and ParadiseDev.hasTrait(self.character, "ParadiseDev:InjuredPvP")) or (md.LifePoints or 100) < 100)
end

function ParadiseDev.ApplyMedkitPvP:update()
    self.item:setJobDelta(self:getJobDelta())
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

function ParadiseDev.ApplyMedkitPvP:start()
    self:setActionAnim("Loot")
    self:setAnimVariable("LootPosition", "Mid")
    self.character:SetVariable("LootPosition", "Mid")
    self.character:reportEvent("EventLootItem")
    self:setOverrideHandModels(nil, nil)
    self.item:setJobType(getText("ContextMenu_Apply_Bandage"))
    self.item:setJobDelta(0)
end

function ParadiseDev.ApplyMedkitPvP:stop()
    ISBaseTimedAction.stop(self)
    if self.item then self.item:setJobDelta(0) end
end

function ParadiseDev.ApplyMedkitPvP:perform()
    if ParadiseDev.PvP and ParadiseDev.PvP.isEnabled and not ParadiseDev.PvP.isEnabled() then return end
    ISBaseTimedAction.perform(self)
    self.item:setJobDelta(0)
    ParadiseDev.setTrait("ParadiseDev:InjuredPvP", false, self.character)
    local md = self.character:getModData()
    local pvp = SandboxVars and SandboxVars.ParadiseZpvp
    md.LifePoints = math.min(100, (md.LifePoints or 100) + (pvp and tonumber(pvp.MedkitHeal) or 50))
    self.character:getXp():AddXP(Perks.Doctor, 0.5)
    self.character:getInventory():Remove(self.item)
end

function ParadiseDev.ApplyMedkitPvP:new(pl, item)
    local action = ISBaseTimedAction.new(self, pl)
    setmetatable(action, self)
    self.__index = self
    action.character = pl
    action.item = item
    action.stopOnWalk = true
    action.stopOnRun = true
    local level = pl:getPerkLevel(Perks.Doctor)
    action.maxTime = 120 - level * 4
    if pl:isTimedActionInstant() then action.maxTime = 1 end
    return action
end

function ParadiseDev.medkitContext(plNum, context, items)
    if not ParadiseDev.PvP.isEnabled() then return end
    local pl = getSpecificPlayer(plNum)
    if not pl then return end
    local item
    for _, entry in ipairs(items or {}) do
        local candidate = type(entry) == "table" and entry.items and entry.items[1] or entry
        if candidate and candidate:getFullType() == "ParadiseZ.MedkitPvP" then item = candidate break end
    end
    if not item or not pl:getInventory():contains(item) then return end
    local option = context:addOption("Apply PvP Medkit", item, function(medkit)
        ISTimedActionQueue.add(ParadiseDev.ApplyMedkitPvP:new(pl, medkit))
    end)
    local md = pl:getModData()
    if not ParadiseDev.hasTrait(pl, "ParadiseDev:InjuredPvP") and (md.LifePoints or 100) >= 100 then option.notAvailable = true end
end
Events.OnFillInventoryObjectContextMenu.Remove(ParadiseDev.medkitContext)
Events.OnFillInventoryObjectContextMenu.Add(ParadiseDev.medkitContext)
