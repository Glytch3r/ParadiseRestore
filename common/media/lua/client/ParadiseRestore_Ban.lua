require "Chat/ISChat"
require "ISUI/ISPanel"

ParadiseDev = ParadiseDev or {}
ParadiseBan = ParadiseBan or {}
ParadiseBan.MODULE = "ParadiseBan"
ParadiseRestore.disablerState = ParadiseRestore.disablerState or {}

ParadiseRestore.CageInputBlocker = ParadiseRestore.CageInputBlocker or ISPanel:derive("ParadiseRestore_CageInputBlocker")

function ParadiseRestore.CageInputBlocker:onMouseDown()
    return true
end

function ParadiseRestore.CageInputBlocker:onMouseUp()
    return true
end

function ParadiseRestore.CageInputBlocker:onRightMouseDown()
    return true
end

function ParadiseRestore.CageInputBlocker:onRightMouseUp()
    return true
end

function ParadiseRestore.CageInputBlocker:onMouseWheel()
    return true
end

function ParadiseRestore.CageInputBlocker:onKeyPress(key)
    if ISChat.instance and getCore():isKey(KeybindId.TOGGLE_CHAT, key) then
        ISChat.instance.currentTabID = 1
        if ISChat.instance.tabs and ISChat.instance.tabs[1] then
            ISChat.instance.panel:activateView(ISChat.instance.tabs[1].tabTitle)
            ISChat.instance:onActivateView()
        end
        ISChat.instance:focus()
    end
    return true
end

function ParadiseRestore.CageInputBlocker:onKeyRepeat()
    return true
end

function ParadiseRestore.CageInputBlocker:onKeyRelease()
    return true
end

function ParadiseRestore.CageInputBlocker:new()
    local blocker = ISPanel.new(self, 0, 0, getCore():getScreenWidth(), getCore():getScreenHeight())
    blocker.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    blocker.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    blocker:setWantKeyEvents(true)
    return blocker
end

function ParadiseRestore.isCageRestricted()
    local pl = getPlayer and getPlayer() or nil
    local state = pl and ParadiseRestore.disablerState[pl] or nil
    return state and state.isCageRestricted == true or false
end

function ParadiseRestore.setCageInputBlocker(enabled)
    -- Cage movement rules still apply to admins, but their release controls must stay usable.
    local pl = getPlayer and getPlayer() or nil
    if enabled and pl and ParadiseRestore.isAdm(pl) then enabled = false end
    if enabled then
        if not ParadiseRestore.cageInputBlocker then
            ParadiseRestore.cageInputBlocker = ParadiseRestore.CageInputBlocker:new()
            ParadiseRestore.cageInputBlocker:initialise()
            ParadiseRestore.cageInputBlocker:addToUIManager()
        end
        ParadiseRestore.cageInputBlocker:setWidth(getCore():getScreenWidth())
        ParadiseRestore.cageInputBlocker:setHeight(getCore():getScreenHeight())
        ParadiseRestore.cageInputBlocker:setVisible(true)
        ParadiseRestore.cageInputBlocker:bringToTop()
        if ISChat.instance then ISChat.instance:bringToTop() end
        return
    end
    if ParadiseRestore.cageInputBlocker then
        ParadiseRestore.cageInputBlocker:setVisible(false)
        ParadiseRestore.cageInputBlocker:removeFromUIManager()
        ParadiseRestore.cageInputBlocker = nil
    end
end

function ParadiseRestore.onCageChatEntered(self)
    local chat = ISChat.instance
    local str = chat and chat.textEntry and chat.textEntry:getText() or ""
    str = string.gsub(str, "^/%a+%s*", "")
    str = string.gsub(str, "[\n\r]", " ")
    if chat then
        chat:unfocus()
        chat.timerTextEntry = 20
    end
    if str ~= "" and str ~= " " then processSayMessage(str) end
    doKeyPress(false)
end

function ParadiseRestore.refreshCageRestriction(pl)
    if not pl or pl ~= getPlayer() then return end
    local isCaged = ParadiseDev.Cage and ParadiseDev.Cage.isTargetCaged and ParadiseDev.Cage.isTargetCaged(pl) or false
    local state = ParadiseRestore.disablerState[pl]
    if state and state.isCageRestricted == isCaged then
        if isCaged then ParadiseRestore.setCageInputBlocker(true) end
        return
    end
    ParadiseRestore.Disabler(pl, isCaged, true)
end

function ParadiseRestore.Disabler(targ, disabled, isCageRestricted)
    if not targ then return end
    isCageRestricted = isCageRestricted == true
    local state = ParadiseRestore.disablerState[targ] or { disabled = false, isCageRestricted = false }
    if isCageRestricted then
        state.isCageRestricted = disabled == true
    else
        state.disabled = disabled == true
    end
    ParadiseRestore.disablerState[targ] = state
    local effectiveDisabled = state.disabled or state.isCageRestricted
    if effectiveDisabled then
        ISTimedActionQueue.clear(targ)
        targ:setAutoWalk(false)
    end
    targ:setIgnoreInputsForDirection(effectiveDisabled)
    targ:setAuthorizeMeleeAction(not effectiveDisabled)
    targ:setIgnoreMovement(effectiveDisabled)
    targ:setCanShout(not effectiveDisabled)
    targ:setBlockMovement(effectiveDisabled)
    JoypadState.disableClimbOver = effectiveDisabled
    JoypadState.disableSmashWindow = effectiveDisabled
    JoypadState.disableReload = effectiveDisabled
    JoypadState.disableGrab = effectiveDisabled
    JoypadState.disableInvInteraction = effectiveDisabled
    JoypadState.disableYInventory = effectiveDisabled
    JoypadState.disableControllerPrompt = effectiveDisabled
    JoypadState.disableMovement = effectiveDisabled
    ISBackButtonWheel.disablePlayerInfo = effectiveDisabled
    ISBackButtonWheel.disableCrafting = effectiveDisabled
    ISBackButtonWheel.disableTime = effectiveDisabled
    ISBackButtonWheel.disableMoveable = effectiveDisabled
    ISBackButtonWheel.disableZoomOut = effectiveDisabled
    ISBackButtonWheel.disableZoomIn = effectiveDisabled
    if targ == getPlayer() then ParadiseRestore.setCageInputBlocker(state.isCageRestricted) end
end

Events.OnPlayerUpdate.Remove(ParadiseRestore.refreshCageRestriction)
Events.OnPlayerUpdate.Add(ParadiseRestore.refreshCageRestriction)

ParadiseBanTimedAction = ISBaseTimedAction:derive("ParadiseBanTimedAction")

function ParadiseBanTimedAction:isValid()
    return self.character and self.target and self.target:getUsername() ~= self.character:getUsername() and ParadiseRestore.isAdm(self.character)
end

function ParadiseBanTimedAction:start()
    local targSteamID = ParadiseRestore.getSteamIdOrUser(targ)
    self:setActionAnim(self.choice.animSet)
    self:setOverrideHandModels(nil, nil)
    sendClientCommand(ParadiseBan.MODULE, "start", {
        targUser = self.target:getUsername(),
        targSteamID = tostring(targSteamID),
        animStr = self.animStr,
        banDelay = self.choice.banDelay,
    })
end

function ParadiseBanTimedAction:perform()
    ISBaseTimedAction.perform(self)
end

function ParadiseBanTimedAction:new(character, target, animStr)
    local action = ISBaseTimedAction.new(self, character)
    setmetatable(action, self)
    self.__index = self
    action.character = character
    action.target = target
    action.animStr = animStr
    action.choice = ParadiseBan.getAnimChoice(animStr)
    action.stopOnWalk = true
    action.stopOnRun = true
    action.maxTime = math.max(1, math.floor((action.choice.banDelay or 1000) / 10))
    return action
end

function ParadiseBan.doBan(target, animStr)
    local pl = getPlayer()
    local choice = ParadiseBan.getAnimChoice(animStr)
    if not pl or not target or not choice or not ParadiseRestore.isAdm(pl) then return end
    ISTimedActionQueue.add(ParadiseBanTimedAction:new(pl, target, animStr))
end

function ParadiseBan.addTargetMenu(menu, target, localPlayer)
    if not menu or not target then return end
    local root = menu:addOption("ParadiseBan")
    local sub = ISContextMenu:getNew(menu)
    menu:addSubMenu(root, sub)
    local keys = {}
    for key in pairs(ParadiseBan.animChoices) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local choice = ParadiseBan.animChoices[key]
        local option = sub:addOption(choice.label, nil, ParadiseBan.doBan, target, key)
        if localPlayer and target == localPlayer then
            option.notAvailable = true
        end
    end
end

function ParadiseBan.onServerCommand(module, command, args)
    if module ~= ParadiseBan.MODULE or type(args) ~= "table" then return end
    if command == "disable" then
        ParadiseRestore.Disabler(getPlayer(), true)
    elseif command == "release" then
        ParadiseRestore.Disabler(getPlayer(), false)
    end
end

Events.OnServerCommand.Remove(ParadiseBan.onServerCommand)
Events.OnServerCommand.Add(ParadiseBan.onServerCommand)
