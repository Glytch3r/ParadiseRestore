ParadiseDev = ParadiseDev or {}
ParadiseDev.LifeBar = ParadiseDev.LifeBar or {}

require "ISUI/ISPanel"

ParadiseDev.LifeBar.panel = nil
ParadiseDev.LifeBar.visible = true
ParadiseDev.LifeBar.maxValue = 100

ParadiseDev.LifeBar.UI = ISPanel:derive("ParadiseDev.LifeBar.UI")

function ParadiseDev.LifeBar.isPvE(pl)
    return ParadiseDev.hasTrait and ParadiseDev.hasTrait(pl, "ParadiseDev:PvE") or false
end

function ParadiseDev.LifeBar.isPvEZone(pl)
    local border = ParadiseDev.Zones and ParadiseDev.Zones.Border
    local zone = border and border.getZoneFor and border.getZoneFor(pl) or nil
    return zone and zone.features and zone.features.isPvE == true or false
end

function ParadiseDev.LifeBar.getConditionRGB(condition)
    local value = condition / ParadiseDev.LifeBar.maxValue
    return 1 - value, 0, value
end

function ParadiseDev.LifeBar.UI:initialise()
    ISPanel.initialise(self)
end

function ParadiseDev.LifeBar.UI:render()
    if ParadiseDev.PvP and ParadiseDev.PvP.isEnabled and not ParadiseDev.PvP.isEnabled() then return end
    local pl = getPlayer()
    if not pl then return end

    if ParadiseDev.LifeBar.isPvE(pl) then
        local injury = ParadiseDev.getTrait and ParadiseDev.getTrait("ParadiseDev:InjuredPvP") or nil
        if injury and ParadiseDev.hasTrait(pl, injury) then pl:getTraits():remove(injury) end
        return
    end

    local md = pl:getModData()
    if not md or not md.LifePoints then return end

    local life = math.max(0, math.min(ParadiseDev.LifeBar.maxValue, md.LifePoints))
    local barW = (life / ParadiseDev.LifeBar.maxValue) * self.width
    local r, g, b = ParadiseDev.LifeBar.getConditionRGB(life)

    self:drawRect(0, 0, self.width, self.height, 1, 0, 0, 0)
    self:drawRect(0, 0, barW, self.height, 1, r, g, b)
    self:drawRectBorder(0, 0, self.width, self.height, 1, 1, 1, 1)
end

function ParadiseDev.LifeBar.UI:new(x, y, width, height)
    local ui = ISPanel:new(x, y, width, height)
    setmetatable(ui, self)
    self.__index = self
    return ui
end

function ParadiseDev.LifeBar.create()
    local ui = ParadiseDev.LifeBar.UI:new(68, 50, 150, 20)
    ui:initialise()
    ui:addToUIManager()
    ParadiseDev.LifeBar.panel = ui
end

function ParadiseDev.LifeBar.show()
    if not ParadiseDev.LifeBar.panel then ParadiseDev.LifeBar.create() end
    ParadiseDev.LifeBar.visible = true
    ParadiseDev.LifeBar.panel:setVisible(true)
end

function ParadiseDev.LifeBar.hide()
    if not ParadiseDev.LifeBar.panel then return end
    ParadiseDev.LifeBar.visible = false
    ParadiseDev.LifeBar.panel:setVisible(false)
end

function ParadiseDev.LifeBar.updateVisibility(pl)
    if not isIngameState() then return end
    pl = pl or getPlayer()
    if not pl then return end
    if (ParadiseDev.PvP and ParadiseDev.PvP.isEnabled and not ParadiseDev.PvP.isEnabled()) or ParadiseDev.LifeBar.isPvE(pl) or ParadiseDev.LifeBar.isPvEZone(pl) or pl:isDead() then
        ParadiseDev.LifeBar.hide()
    else
        ParadiseDev.LifeBar.show()
    end
end

function ParadiseDev.LifeBar.init()
    local pl = getPlayer()
    if not pl then return end
    local md = pl:getModData()
    md.LifePoints = md.LifePoints or ParadiseDev.LifeBar.maxValue
end

function ParadiseDev.LifeBar.tick(pl)
    if not pl or (ParadiseDev.PvP and ParadiseDev.PvP.isEnabled and not ParadiseDev.PvP.isEnabled()) or ParadiseDev.LifeBar.isPvE(pl) then return end
    local md = pl:getModData()
    if not md or not md.LifePoints then return end

    local pvp = SandboxVars and SandboxVars.ParadiseZpvp
    local recovery = pvp and tonumber(pvp.LifeBarRecovery) or 0
    local injuryDrain = pvp and tonumber(pvp.InjuryDrain) or 0
    local life = md.LifePoints + recovery

    if ParadiseDev.hasTrait and ParadiseDev.hasTrait(pl, "ParadiseDev:InjuredPvP") then
        if ZombRand(1, 101) <= 1 then
            local sq = pl:getSquare()
            if sq then addBloodSplat(sq, 15) end
        end
        life = md.LifePoints - injuryDrain
    end

    md.LifePoints = math.max(0, math.min(ParadiseDev.LifeBar.maxValue, life))
end

function ParadiseDev.LifeBar.onMinute()
    ParadiseDev.LifeBar.tick(getPlayer())
end

Events.OnPlayerUpdate.Remove(ParadiseDev.LifeBar.updateVisibility)
Events.OnPlayerUpdate.Add(ParadiseDev.LifeBar.updateVisibility)
Events.OnCreatePlayer.Remove(ParadiseDev.LifeBar.init)
Events.OnCreatePlayer.Add(ParadiseDev.LifeBar.init)
Events.EveryOneMinute.Remove(ParadiseDev.LifeBar.onMinute)
Events.EveryOneMinute.Add(ParadiseDev.LifeBar.onMinute)
