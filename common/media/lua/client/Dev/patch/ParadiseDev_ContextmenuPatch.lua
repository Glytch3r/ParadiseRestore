ParadiseDev = ParadiseDev or {}
ParadiseDev.TradePrivacy = ParadiseDev.TradePrivacy or {}


function ParadiseDev.TradePrivacy.isProtectedTarget(targ)
    if not targ or not targ.isInvisible or not targ:isInvisible() then return false end
    return ParadiseRestore.isAdm(targ)
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
    local hook = DebugContextMenu and DebugContextMenu[functionName]
    if not hook or ParadiseDev._DisabledDebugContextOptions and ParadiseDev._DisabledDebugContextOptions[functionName] then return end

    local disabledNames = {}
    for _, textKey in ipairs(disabledTextKeys) do
        disabledNames[getText(textKey)] = true
    end

    local wrapped = function(...)
        local hookAddOption = ISContextMenu.addOption
        ISContextMenu.addOption = function(self, name, ...)
            if disabledNames[name] then return nil end
            return hookAddOption(self, name, ...)
        end

        hook(...)
        ISContextMenu.addOption = hookAddOption
    end
    ParadiseDev._DisabledDebugContextOptions = ParadiseDev._DisabledDebugContextOptions or {}
    ParadiseDev._DisabledDebugContextOptions[functionName] = true
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

ParadiseDev.CtxProbe = ParadiseDev.CtxProbe or {}

function ParadiseDev.CtxProbe.count(key)
    local probe = ParadiseDev.CtxProbe
    probe.hits = probe.hits or {}
    probe.hits[key] = (probe.hits[key] or 0) + 1
end

function ParadiseDev.CtxProbe.hiddenCount()
    local mgr = ParadiseRestore and ParadiseRestore.ContextMenuManager
    if not mgr or not mgr.profile or not mgr.profile.hidden then return -1 end
    local n = 0
    for _ in pairs(mgr.profile.hidden) do n = n + 1 end
    return n
end

function ParadiseDev.CtxProbe.buildGates(plNum)
    local pl = getSpecificPlayer(plNum)
    local speedControls = UIManager.getSpeedControls()
    local fetch = ISWorldObjectContextMenu and ISWorldObjectContextMenu.fetchVars
    local mgr = ParadiseRestore and ParadiseRestore.ContextMenuManager
    return {
        speed = speedControls and speedControls:getCurrentGameSpeed(),
        dead = pl and pl:isDead(),
        asleep = pl and pl:isAsleep(),
        state = pl and pl:getCurrentState() and tostring(pl:getCurrentState()),
        fishing = FishingState and FishingState.instance() and tostring(FishingState.instance()),
        noInvMenu = tostring(ISInventoryPaneContextMenu.dontCreateMenu),
        radial = tostring(getCore():getOptionRadialMenuKeyToggle()),
        hidden = ParadiseDev.CtxProbe.hiddenCount(),
        wrapped = mgr and tostring(mgr.hooks ~= nil) or "no manager",
        safehouseAllowInteract = fetch and fetch.safehouseAllowInteract,
        fetchC = fetch and fetch.c,
    }
end

function ParadiseDev.CtxProbe.preFill(plNum, context, worldobjects, test)
    ParadiseDev.CtxProbe.count(test and "worldTest" or "worldReal")
    if test or ParadiseDev.CtxProbe.gates then return end
    local ok, gates = pcall(ParadiseDev.CtxProbe.buildGates, plNum)
    ParadiseDev.CtxProbe.gates = ok and gates or {error = tostring(gates)}
end
Events.OnPreFillWorldObjectContextMenu.Remove(ParadiseDev.CtxProbe.preFill)
Events.OnPreFillWorldObjectContextMenu.Add(ParadiseDev.CtxProbe.preFill)

function ParadiseDev.CtxProbe.worldFill(plNum, context, worldobjects, test)
    ParadiseDev.CtxProbe.count(test and "worldFillTest" or "worldFill")
end
Events.OnFillWorldObjectContextMenu.Remove(ParadiseDev.CtxProbe.worldFill)
Events.OnFillWorldObjectContextMenu.Add(ParadiseDev.CtxProbe.worldFill)

function ParadiseDev.CtxProbe.invFill(plNum, context)
    ParadiseDev.CtxProbe.count("invFill")
end
Events.OnFillInventoryObjectContextMenu.Remove(ParadiseDev.CtxProbe.invFill)
Events.OnFillInventoryObjectContextMenu.Add(ParadiseDev.CtxProbe.invFill)

function ParadiseDev.CtxProbe.invEmpty(plNum, context)
    ParadiseDev.CtxProbe.count("invNoItems")
end
if Events and Events.OnFillInventoryContextMenuNoItems then
    Events.OnFillInventoryContextMenuNoItems.Remove(ParadiseDev.CtxProbe.invEmpty)
    Events.OnFillInventoryContextMenuNoItems.Add(ParadiseDev.CtxProbe.invEmpty)
end

function ParadiseDev.CtxProbe.blockers()
    local lines = {}
    if not ParadiseDev.UI or not ParadiseDev.UI.getOpen then return lines end
    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()
    for _, entry in ipairs(ParadiseDev.UI.getOpen()) do
        if entry.depth == 0 and tonumber(entry.width) and tonumber(entry.height)
        and entry.width >= sw * 0.6 and entry.height >= sh * 0.6 then
            lines[#lines + 1] = string.format("%s x=%s y=%s %sx%s", tostring(entry.name),
                tostring(entry.x), tostring(entry.y), tostring(entry.width), tostring(entry.height))
        end
    end
    return lines
end

function ParadiseDev.CtxProbe.options(context)
    if not context or not context.options then return "none" end
    local names = {}
    for _, option in ipairs(context.options) do
        names[#names + 1] = tostring(option.name)
    end
    return table.concat(names, " | ")
end

function ParadiseDev.CtxProbe.report()
    local probe = ParadiseDev.CtxProbe
    local hits = probe.hits or {}
    local line = "hits worldReal=" .. tostring(hits.worldReal)
        .. " worldTest=" .. tostring(hits.worldTest)
        .. " worldFill=" .. tostring(hits.worldFill)
        .. " worldFillTest=" .. tostring(hits.worldFillTest)
        .. " invFill=" .. tostring(hits.invFill)
        .. " invNoItems=" .. tostring(hits.invNoItems)
    print(line)
    local g = probe.gates
    if g then
        print("gates speed=" .. tostring(g.speed) .. " dead=" .. tostring(g.dead)
            .. " asleep=" .. tostring(g.asleep) .. " state=" .. tostring(g.state)
            .. " fishing=" .. tostring(g.fishing) .. " noInvMenu=" .. tostring(g.noInvMenu)
            .. " radial=" .. tostring(g.radial) .. " hidden=" .. tostring(g.hidden)
            .. " wrapped=" .. tostring(g.wrapped)
            .. " allowInteract=" .. tostring(g.safehouseAllowInteract)
            .. " fetchC=" .. tostring(g.fetchC))
        if g.error then print("gates error: " .. tostring(g.error)) end
    else
        print("gates: no real world right-click captured since reset")
    end
    local cm = getPlayerContextMenu(0)
    if not cm then
        print("menu: none")
    else
        print("menu visible=" .. tostring(cm:isVisible())
            .. " anyVisible=" .. tostring(cm:isAnyVisible())
            .. " isEmpty=" .. tostring(cm.isEmpty and cm:isEmpty())
            .. " numOptions=" .. tostring(cm.numOptions)
            .. " optionCount=" .. tostring(#(cm.options or {}))
            .. " x=" .. tostring(cm:getX()) .. " y=" .. tostring(cm:getY())
            .. " w=" .. tostring(cm:getWidth()) .. " h=" .. tostring(cm:getHeight()))
        print("menu options: " .. ParadiseDev.CtxProbe.options(cm))
    end
    for _, blocker in ipairs(ParadiseDev.CtxProbe.blockers()) do
        print("blocker: " .. blocker)
    end
end

function ParadiseDev.CtxProbe.reset()
    ParadiseDev.CtxProbe.hits = {}
    ParadiseDev.CtxProbe.gates = nil
end
