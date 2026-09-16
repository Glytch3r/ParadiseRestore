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

local function ParadiseDev_disableDebugContextOptions(functionName, disabledTextKeys)
    local original = DebugContextMenu and DebugContextMenu[functionName]
    if not original or original._ParadiseDevDisabledOptions then return end

    local disabledNames = {}
    for _, textKey in ipairs(disabledTextKeys) do
        disabledNames[getText(textKey)] = true
    end

    local wrapped = function(...)
        local originalAddOption = ISContextMenu.addOption
        ISContextMenu.addOption = function(self, name, ...)
            if disabledNames[name] then return nil end
            return originalAddOption(self, name, ...)
        end

        original(...)
        ISContextMenu.addOption = originalAddOption
    end
    wrapped._ParadiseDevDisabledOptions = true
    DebugContextMenu[functionName] = wrapped
end

ParadiseDev_disableDebugContextOptions("doDebugVehicleMenu", {
    "IGUI_DebugContext_RemoveAll",
})
ParadiseDev_disableDebugContextOptions("addRVSDebugMenu", {
    "IGUI_DebugContext_RemoveVehicles",
})
ParadiseDev_disableDebugContextOptions("doDebugPlayerMenu", {
    "IGUI_DebugContext_TeleportPlayers",
})
