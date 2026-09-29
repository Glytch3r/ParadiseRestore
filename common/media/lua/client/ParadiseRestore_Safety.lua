ParadiseDev = ParadiseDev or {}
ParadiseDev.PvE = ParadiseDev.PvE or {}
ParadiseDev.PvE.Safety = ParadiseDev.PvE.Safety or {}

function ParadiseDev.PvE.Safety.isLocked(pl)
    pl = pl or getPlayer()
    if not pl or not ParadiseDev.LifeBar then return false end
    if ParadiseDev.LifeBar.isPvE(pl) then return true end
    local inPvE = ParadiseDev.LifeBar.isPvEZone(pl)
    local border = ParadiseDev.Zones and ParadiseDev.Zones.Border
    local zone = border and border.getZoneFor and border.getZoneFor(pl) or nil
    local inKos = zone and zone.features and zone.features.isKos == true or false
    return inPvE or inKos
end

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

    if safety:isEnabled() ~= shouldBeOn then safety:toggleSafety() end
end

function ParadiseDev.PvE.Safety.installHooks()
    if ParadiseDev.PvE.Safety.hooked or not ISEquippedItem then return end

    ParadiseDev.PvE.Safety.originalToggleSafety = ISEquippedItem.toggleSafety
    function ISEquippedItem:toggleSafety()
        if ParadiseDev.PvE.Safety.isLocked(getPlayer()) then return end
        return ParadiseDev.PvE.Safety.originalToggleSafety(self)
    end

    ParadiseDev.PvE.Safety.originalOnKeyPressed = ISEquippedItem.onKeyPressed
    ISEquippedItem.onKeyPressed = function(key)
        if getCore():isKey("Toggle Safety", key) and ParadiseDev.PvE.Safety.isLocked(getPlayer()) then return end
        return ParadiseDev.PvE.Safety.originalOnKeyPressed(key)
    end
    ParadiseDev.PvE.Safety.hooked = true
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
Events.OnGameStart.Remove(ParadiseDev.PvE.Safety.installHooks)
Events.OnGameStart.Add(ParadiseDev.PvE.Safety.installHooks)
ParadiseDev.PvE.Safety.installHooks()
