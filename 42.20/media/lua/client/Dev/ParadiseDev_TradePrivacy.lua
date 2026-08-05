-- Prevent Trade from revealing an admin or an invisible player through the
-- B42 world context menu.  This only removes the exact vanilla Trade option.
ParadiseDev = ParadiseDev or {}
ParadiseDev.TradePrivacy = ParadiseDev.TradePrivacy or {}

local TradePrivacy = ParadiseDev.TradePrivacy

function TradePrivacy.isProtectedTarget(player)
    if not player then return false end
    if player.isInvisible and player:isInvisible() then return true end

    local accessLevel = player.getAccessLevel and player:getAccessLevel() or ""
    return string.lower(tostring(accessLevel)) == "admin"
end

function TradePrivacy.getTradeTarget(option)
    if not option or option.param1 ~= ISWorldObjectContextMenu.onTrade then return nil end
    -- addGetUpOption wraps onTrade. Its original callback is param1 and the
    -- clicked player is param4: param2=worldobjects, param3=local player.
    return option.param4
end

function TradePrivacy.removeProtectedTradeOption(playerNum, context)
    if not context or not context.options then return end

    for _, option in ipairs(context.options) do
        if TradePrivacy.isProtectedTarget(TradePrivacy.getTradeTarget(option)) then
            context:removeOptionByName(option.name)
            return
        end
    end
end

Events.OnFillWorldObjectContextMenu.Remove(TradePrivacy.removeProtectedTradeOption)
Events.OnFillWorldObjectContextMenu.Add(TradePrivacy.removeProtectedTradeOption)
