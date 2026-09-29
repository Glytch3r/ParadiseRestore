if not isServer() then
    return
end

require "JimsServerRules/JimsRulesShared"

local pendingPlayers = {}

local function log(message)
    print("[JimsServerRules] " .. tostring(message))
end

local function trim(value)
    if value == nil then
        return ""
    end

    return tostring(value):match("^%s*(.-)%s*$")
end

local function ensureFile(fileName, defaultContents)
    local reader = getFileReader(fileName, false)
    if reader then
        reader:close()
        return true
    end

    local writer = getFileWriter(fileName, true, false)
    if not writer then
        log("Unable to create " .. fileName)
        return false
    end

    if defaultContents and defaultContents ~= "" then
        writer:write(defaultContents)
    end

    writer:close()
    log("Created " .. fileName .. " in the server's Zomboid/Lua directory.")
    return true
end

local function readFile(fileName, defaultContents)
    if not ensureFile(fileName, defaultContents) then
        return nil
    end

    local reader = getFileReader(fileName, false)
    if not reader then
        return nil
    end

    local lines = {}
    while true do
        local line = reader:readLine()
        if line == nil then
            break
        end

        table.insert(lines, line)
    end

    reader:close()
    return table.concat(lines, "\n")
end

local function getPlayerIdentity(player)
    if not player then
        return nil
    end

    local username = trim(player:getUsername())
    local steamId = nil

    if getSteamIDFromUsername and username ~= "" then
        local succeeded, result = pcall(getSteamIDFromUsername, username)
        if succeeded then
            steamId = trim(result)
        end
    end

    if steamId == "" or steamId == "0" then
        steamId = nil
    end

    -- This fallback is primarily for non-Steam or test environments.
    if not steamId and player.getSteamID then
        local succeeded, result = pcall(function()
            return player:getSteamID()
        end)

        if succeeded then
            local candidate = trim(result)
            if candidate ~= "" and candidate ~= "0" then
                steamId = candidate
            end
        end
    end

    if steamId then
        return steamId
    end

    if username ~= "" then
        return "username:" .. string.lower(username)
    end

    return nil
end

local function loadAcceptedUsers()
    ensureFile(JimsServerRules.ACCEPTED_USERS_FILE, "")

    local acceptedUsers = {}
    local reader = getFileReader(JimsServerRules.ACCEPTED_USERS_FILE, false)
    if not reader then
        return acceptedUsers
    end

    while true do
        local line = reader:readLine()
        if line == nil then
            break
        end

        local identity = trim(line)
        if identity ~= "" and string.sub(identity, 1, 1) ~= "#" then
            acceptedUsers[identity] = true
        end
    end

    reader:close()
    return acceptedUsers
end

local function isAccepted(identity)
    if not identity then
        return false
    end

    return loadAcceptedUsers()[identity] == true
end

local function saveAcceptance(identity)
    if not identity then
        return false
    end

    if isAccepted(identity) then
        return true
    end

    local writer = getFileWriter(JimsServerRules.ACCEPTED_USERS_FILE, true, true)
    if not writer then
        return false
    end

    writer:writeln(identity)
    writer:close()
    return true
end

local function sendError(player, message)
    sendServerCommand(player, JimsServerRules.MODULE, JimsServerRules.COMMAND_ERROR, {
        message = message
    })
end

local function handleRulesRequest(player)
    local identity = getPlayerIdentity(player)
    if not identity then
        sendError(player, "The server could not identify your account. Please reconnect.")
        return
    end

    if isAccepted(identity) then
        pendingPlayers[identity] = nil
        sendServerCommand(
            player,
            JimsServerRules.MODULE,
            JimsServerRules.COMMAND_ALREADY_ACCEPTED,
            {}
        )
        return
    end

    local rules = readFile(JimsServerRules.RULES_FILE, JimsServerRules.DEFAULT_RULES)
    if not rules or trim(rules) == "" then
        sendError(player, "The server rules file is empty or unavailable. Please contact an administrator.")
        return
    end

    pendingPlayers[identity] = true
    sendServerCommand(player, JimsServerRules.MODULE, JimsServerRules.COMMAND_SHOW, {
        title = JimsServerRules.TITLE,
        subtitle = JimsServerRules.SUBTITLE,
        rules = rules,
        reviewOnly = false
    })
end

local function handleRulesView(player)
    local rules = readFile(JimsServerRules.RULES_FILE, JimsServerRules.DEFAULT_RULES)
    if not rules or trim(rules) == "" then
        sendError(player, "The server rules file is empty or unavailable. Please contact an administrator.")
        return
    end

    sendServerCommand(player, JimsServerRules.MODULE, JimsServerRules.COMMAND_SHOW, {
        title = JimsServerRules.TITLE,
        subtitle = JimsServerRules.SUBTITLE,
        rules = rules,
        reviewOnly = true
    })
end

local function handleRulesAcceptance(player)
    local identity = getPlayerIdentity(player)
    if not identity then
        sendError(player, "The server could not identify your account. Please reconnect.")
        return
    end

    if not pendingPlayers[identity] and not isAccepted(identity) then
        sendError(player, "Your rules session expired. Please reconnect and try again.")
        return
    end

    if not saveAcceptance(identity) then
        sendError(player, "The server could not save your acceptance. Please contact an administrator.")
        return
    end

    pendingPlayers[identity] = nil
    log(identity .. " accepted the server rules.")
    sendServerCommand(
        player,
        JimsServerRules.MODULE,
        JimsServerRules.COMMAND_ACCEPTED,
        {}
    )
end

local function onClientCommand(module, command, player, arguments)
    if module ~= JimsServerRules.MODULE then
        return
    end

    if command == JimsServerRules.COMMAND_REQUEST then
        handleRulesRequest(player)
        return
    end

    if command == JimsServerRules.COMMAND_VIEW then
        handleRulesView(player)
        return
    end

    if command == JimsServerRules.COMMAND_ACCEPT then
        handleRulesAcceptance(player)
    end
end

local function onServerStarted()
    ensureFile(JimsServerRules.RULES_FILE, JimsServerRules.DEFAULT_RULES)
    ensureFile(JimsServerRules.ACCEPTED_USERS_FILE, "")
    log("Ready. Rules and accepted-user files are read dynamically for every player request.")
end

Events.OnClientCommand.Add(onClientCommand)
Events.OnServerStarted.Add(onServerStarted)
