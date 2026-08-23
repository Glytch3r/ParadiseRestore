ParadiseDev = ParadiseDev or {}
ParadiseDev.TradePrivacy = ParadiseDev.TradePrivacy or {}


function ParadiseDev.TradePrivacy.isProtectedTarget(targ)
    if not targ then return false end
    if targ.isInvisible and targ:isInvisible() then return true end
    return ParadiseDev.isAdm(targ)
end

function ParadiseDev.TradePrivacy.getPlayerActionTarget(option)
    if not option then return nil end
    if option.param1 ~= ISWorldObjectContextMenu.onTrade
        and option.param1 ~= ISWorldObjectContextMenu.onMedicalCheck
        and option.param1 ~= ISWorldObjectContextMenu.onWakeOther then return nil end
    return option.param4
end

function ParadiseDev.TradePrivacy.removeProtectedTradeOption(plNum, context)
    if not context or not context.options then return end

    local names = {}
    for _, option in ipairs(context.options) do
        if ParadiseDev.TradePrivacy.isProtectedTarget(ParadiseDev.TradePrivacy.getPlayerActionTarget(option)) then
            names[#names + 1] = option.name
        end
    end
    for _, name in ipairs(names) do context:removeOptionByName(name) end
end

Events.OnFillWorldObjectContextMenu.Remove(ParadiseDev.TradePrivacy.removeProtectedTradeOption)
Events.OnFillWorldObjectContextMenu.Add(ParadiseDev.TradePrivacy.removeProtectedTradeOption)
