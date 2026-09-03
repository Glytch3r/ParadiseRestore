require "TimedActions/ISBaseTimedAction"

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
    local injury = ParadiseDev.getTrait and ParadiseDev.getTrait("ParadiseDev:InjuredPvP") or nil
    if injury then self.character:getTraits():remove(injury) end
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
