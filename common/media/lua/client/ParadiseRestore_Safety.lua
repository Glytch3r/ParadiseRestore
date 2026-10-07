require "Dev/ParadiseDev_PvEPolicy"
ParadiseDev = ParadiseDev or {}
ParadiseDev.PvE = ParadiseDev.PvE or {}
ParadiseDev.PvE.Safety = ParadiseDev.PvE.Safety or {}

function ParadiseDev.PvE.Safety.isLocked(pl)
    return ParadiseDev.PvEPolicy.safetyState(pl or getPlayer())
end

-- Compatibility entry point. The server bridge owns entry/exit transitions and
-- replication; clients never spam toggle packets while waiting for a countdown.
function ParadiseDev.PvE.updateSafety(pl)
    return ParadiseDev.PvEPolicy.safetyState(pl)
end

function ParadiseDev.PvE.Safety.updateButton(panel)
    local button=panel and panel.safetyBtn
    if not button then return end
    local locked,enabled,reason,zone=ParadiseDev.PvE.Safety.isLocked(panel.chr or getPlayer())
    if locked then
        if not button.paradisePvELocked then
            button.paradisePvEPreviousEnabled=button:isEnabled()
            button.paradisePvELocked=true
            button:setEnable(false)
        end
        local name=zone and type(zone.name)=="string" and zone.name:gsub("[%c]"," "):sub(1,120) or nil
        if not name or name:match("^%s*$") then name=reason=="KoS zone" and "this KoS zone" or "this PvE zone" end
        local tooltip
        if reason=="PvE character" then tooltip="Your PvE character cannot deal or receive PvP damage. Safety is locked on."
        elseif reason=="Safe zone" then tooltip="PvP is disabled in this native safe zone. Safety is locked on."
        elseif enabled then tooltip="PvP is disabled in "..name..". Safety is locked on."
        else tooltip="PvP is enabled in "..name..". Safety is locked off." end
        button:setTooltip(tooltip)
    elseif button.paradisePvELocked then
        button:setEnable(button.paradisePvEPreviousEnabled ~= false)
        button.paradisePvELocked,button.paradisePvEPreviousEnabled=nil,nil
        -- Vanilla prerender already restored its own tooltip for this location.
    end
end

function ParadiseDev.PvE.Safety.installHooks()
    local safety=ParadiseDev.PvE.Safety
    if safety.hooked or not ISEquippedItem then return end
    safety.originalToggleSafety=ISEquippedItem.toggleSafety
    function ISEquippedItem:toggleSafety()
        if ParadiseDev.PvE.Safety.isLocked(self.chr or getPlayer()) then return end
        return ParadiseDev.PvE.Safety.originalToggleSafety(self)
    end
    safety.originalOnKeyPressed=ISEquippedItem.onKeyPressed
    ISEquippedItem.onKeyPressed=function(key)
        local toggleKey=KeybindId and KeybindId.TOGGLE_SAFETY or "Toggle Safety"
        if getCore():isKey(toggleKey,key) and ParadiseDev.PvE.Safety.isLocked(getPlayer()) then return end
        return ParadiseDev.PvE.Safety.originalOnKeyPressed(key)
    end
    safety.originalPrerender=ISEquippedItem.prerender
    function ISEquippedItem:prerender()
        local result=ParadiseDev.PvE.Safety.originalPrerender(self)
        ParadiseDev.PvE.Safety.updateButton(self)
        return result
    end
    safety.hooked=true
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
Events.OnPlayerUpdate.Remove(ParadiseDev.PvE.updateThrowableRestriction)
Events.OnPlayerUpdate.Add(ParadiseDev.PvE.updateThrowableRestriction)
Events.OnGameStart.Remove(ParadiseDev.PvE.Safety.installHooks)
Events.OnGameStart.Add(ParadiseDev.PvE.Safety.installHooks)
ParadiseDev.PvE.Safety.installHooks()
