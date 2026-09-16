if not isClient() then
    return
end

require "JimsServerRules/JimsRulesShared"
require "JimsServerRules/JimsRulesUI"

JimsRulesClient = JimsRulesClient or {}

require "JimsServerRules/JimsRulesSidebar"

local activePlayer = nil
local activePlayerNumber = 0
local waitingForServer = false
local lastRequestTime = 0
local requestAttempts = 0
local waitingForReview = false

local REQUEST_RETRY_MS = 5000

local function requestRules()
    if not activePlayer then
        return
    end

    waitingForServer = true
    requestAttempts = requestAttempts + 1
    lastRequestTime = getTimestampMs()

    sendClientCommand(
        activePlayer,
        JimsServerRules.MODULE,
        JimsServerRules.COMMAND_REQUEST,
        {}
    )
end

function JimsRulesClient.requestReview()
    if not activePlayer or waitingForServer or waitingForReview or JimsRulesUI.instance then
        return
    end

    waitingForReview = true
    sendClientCommand(
        activePlayer,
        JimsServerRules.MODULE,
        JimsServerRules.COMMAND_VIEW,
        {}
    )
end

local function onKeyPressed(key)
    if key ~= Keyboard.KEY_F2 then
        return
    end

    JimsRulesClient.requestReview()
end

local function onCreatePlayer(playerNumber, player)
    activePlayerNumber = playerNumber or 0
    activePlayer = player
    requestAttempts = 0
    requestRules()
end

local function onServerCommand(module, command, arguments)
    if module ~= JimsServerRules.MODULE then
        return
    end

    arguments = arguments or {}

    if command == JimsServerRules.COMMAND_ALREADY_ACCEPTED then
        waitingForServer = false
        return
    end

    if command == JimsServerRules.COMMAND_SHOW then
        waitingForServer = false
        waitingForReview = false
        JimsRulesUI.show(
            activePlayerNumber,
            activePlayer,
            arguments.title,
            arguments.subtitle,
            arguments.rules,
            arguments.reviewOnly == true
        )
        return
    end

    if command == JimsServerRules.COMMAND_ACCEPTED then
        waitingForServer = false
        if JimsRulesUI.instance then
            JimsRulesUI.instance:destroy()
        end
        return
    end

    if command == JimsServerRules.COMMAND_ERROR then
        if JimsRulesUI.instance then
            waitingForServer = false
            waitingForReview = false
            JimsRulesUI.instance:showError(arguments.message)
        elseif waitingForReview then
            waitingForReview = false
            print("[JimsServerRules] " .. tostring(arguments.message or "Unknown server error."))
        else
            waitingForServer = true
            lastRequestTime = getTimestampMs()
            print("[JimsServerRules] " .. tostring(arguments.message or "Unknown server error."))
        end
    end
end

local function onPlayerUpdate(player)
    if player ~= activePlayer then
        return
    end

    if JimsRulesUI.instance then
        return
    end

    if not waitingForServer then
        return
    end

    if getTimestampMs() - lastRequestTime < REQUEST_RETRY_MS then
        return
    end

    if requestAttempts % 6 == 0 then
        print("[JimsServerRules] Still waiting for the server to answer the rules request.")
    end

    requestRules()
end

Events.OnCreatePlayer.Add(onCreatePlayer)
Events.OnServerCommand.Add(onServerCommand)
Events.OnPlayerUpdate.Add(onPlayerUpdate)
Events.OnKeyPressed.Add(onKeyPressed)
