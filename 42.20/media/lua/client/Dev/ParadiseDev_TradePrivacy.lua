ParadiseDev = ParadiseDev or {}
ParadiseDev.TradePrivacy = ParadiseDev.TradePrivacy or {}

require "Dev/ParadiseDev_Players"

function ParadiseDev.TradePrivacy.isProtectedTarget(targ)
    if not targ then return false end
    if targ.isInvisible and targ:isInvisible() then return true end
    return ParadiseDev.isAdm(targ)
end

function ParadiseDev.TradePrivacy.getTradeTarget(option)
    if not option or option.param1 ~= ISWorldObjectContextMenu.onTrade then return nil end
    return option.param4
end

function ParadiseDev.TradePrivacy.removeProtectedTradeOption(plNum, context)
    if not context or not context.options then return end

    for _, option in ipairs(context.options) do
        if ParadiseDev.TradePrivacy.isProtectedTarget(ParadiseDev.TradePrivacy.getTradeTarget(option)) then
            context:removeOptionByName(option.name)
            return
        end
    end
end

Events.OnFillWorldObjectContextMenu.Remove(ParadiseDev.TradePrivacy.removeProtectedTradeOption)
Events.OnFillWorldObjectContextMenu.Add(ParadiseDev.TradePrivacy.removeProtectedTradeOption)
