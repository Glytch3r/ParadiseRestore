ParadiseDev = ParadiseDev or {}
ParadiseDev.PvE = ParadiseDev.PvE or {}

function ParadiseDev.PvE.updateSafety(pl)
    if not isIngameState() or not pl or not pl.getSafety or not ParadiseDev.LifeBar then return end

    local safety = pl:getSafety()
    if not safety or not safety.isEnabled then return end

    local hasPvETrait = ParadiseDev.LifeBar.isPvE(pl)
    local inPvE = ParadiseDev.LifeBar.isPvEZone(pl)
    local border = ParadiseDev.Zones and ParadiseDev.Zones.Border
    local zone = border and border.getZoneFor and border.getZoneFor(pl) or nil
    local inKos = zone and zone.features and zone.features.isKos == true or false

    local shouldBeOn
    if hasPvETrait then
        shouldBeOn = true
    elseif inPvE then
        shouldBeOn = true
    elseif inKos then
        shouldBeOn = false
    else
        return
    end

    if safety:isEnabled() ~= shouldBeOn then
        local ui = getPlayerSafetyUI and getPlayerSafetyUI(pl:getPlayerNum()) or nil
        if ui and ui.toggleSafety then ui:toggleSafety() end
    end
end

function ParadiseDev.PvE.isThrowable(item)
    if not item then return false end
    local script = item.getScriptItem and item:getScriptItem() or nil
    local swingAnim = item.getSwingAnim and item:getSwingAnim() or nil
    if not swingAnim and script and script.getSwingAnim then swingAnim = script:getSwingAnim() end
    return swingAnim == "Throw"
end

function ParadiseDev.PvE.updateThrowableRestriction(pl)
    if not pl or pl ~= getPlayer() or not pl.setAuthorizeMeleeAction then return end
    local inPvE = ParadiseDev.LifeBar and ParadiseDev.LifeBar.isPvEZone and ParadiseDev.LifeBar.isPvEZone(pl)
    local holdingThrowable = ParadiseDev.PvE.isThrowable(pl:getPrimaryHandItem())
    local shouldBlock = inPvE and holdingThrowable
    if shouldBlock and not ParadiseDev.PvE.throwableBlocked then
        ParadiseDev.PvE.throwableBlocked = true
        pl:setAuthorizeMeleeAction(false)
        if ISTimedActionQueue then ISTimedActionQueue.clear(pl) end
    elseif not shouldBlock and ParadiseDev.PvE.throwableBlocked then
        ParadiseDev.PvE.throwableBlocked = false
        pl:setAuthorizeMeleeAction(true)
    end
end

Events.OnPlayerUpdate.Remove(ParadiseDev.PvE.updateSafety)
Events.OnPlayerUpdate.Add(ParadiseDev.PvE.updateSafety)
Events.OnPlayerUpdate.Remove(ParadiseDev.PvE.updateThrowableRestriction)
Events.OnPlayerUpdate.Add(ParadiseDev.PvE.updateThrowableRestriction)
