ParadiseDev = ParadiseDev or {}
ParadiseBan = ParadiseBan or {}
ParadiseBan.MODULE = "ParadiseBan"

function ParadiseRestore.Disabler(targ, disabled)
    if not targ then return end
    if disabled then
        ISTimedActionQueue.clear(targ)
        targ:setAutoWalk(false)
    end
    targ:setIgnoreInputsForDirection(disabled)
    targ:setAuthorizeMeleeAction(not disabled)
    targ:setIgnoreMovement(disabled)
    targ:setCanShout(not disabled)
    targ:setBlockMovement(disabled)
    JoypadState.disableClimbOver = disabled
    JoypadState.disableSmashWindow = disabled
    JoypadState.disableReload = disabled
    JoypadState.disableGrab = disabled
    JoypadState.disableInvInteraction = disabled
    JoypadState.disableYInventory = disabled
    JoypadState.disableControllerPrompt = disabled
    JoypadState.disableMovement = disabled
    ISBackButtonWheel.disablePlayerInfo = disabled
    ISBackButtonWheel.disableCrafting = disabled
    ISBackButtonWheel.disableTime = disabled
    ISBackButtonWheel.disableMoveable = disabled
    ISBackButtonWheel.disableZoomOut = disabled
    ISBackButtonWheel.disableZoomIn = disabled
end

ParadiseBanTimedAction = ISBaseTimedAction:derive("ParadiseBanTimedAction")

function ParadiseBanTimedAction:isValid()
    return self.character and self.target and self.target:getUsername() ~= self.character:getUsername() and ParadiseRestore.isAdm(self.character)
end

function ParadiseBanTimedAction:start()
    local targSteamID = ParadiseDev.getSteamIdOrUser(targ)
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

Events.OnServerCommand.Add(ParadiseBan.onServerCommand)
