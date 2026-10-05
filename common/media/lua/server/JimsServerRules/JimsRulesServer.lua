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

function JimsServerRules.encodeJsonString(str)
    str = tostring(str or "")
    str = string.gsub(str, "\\", "\\\\")
    str = string.gsub(str, '"', '\\"')
    str = string.gsub(str, "\r", "\\r")
    str = string.gsub(str, "\n", "\\n")
    str = string.gsub(str, "\t", "\\t")
    return str
end

function JimsServerRules.codepointToUtf8(codepoint)
    if codepoint <= 0x7F then
        return string.char(codepoint)
    elseif codepoint <= 0x7FF then
        return string.char(0xC0 + math.floor(codepoint / 0x40), 0x80 + codepoint % 0x40)
    elseif codepoint <= 0xFFFF then
        return string.char(0xE0 + math.floor(codepoint / 0x1000), 0x80 + math.floor(codepoint / 0x40) % 0x40, 0x80 + codepoint % 0x40)
    elseif codepoint <= 0x10FFFF then
        return string.char(0xF0 + math.floor(codepoint / 0x40000), 0x80 + math.floor(codepoint / 0x1000) % 0x40, 0x80 + math.floor(codepoint / 0x40) % 0x40, 0x80 + codepoint % 0x40)
    end
    return nil
end

function JimsServerRules.decodeJsonString(str)
    local result = {}
    local index = 1
    while index <= #str do
        local char = string.sub(str, index, index)
        if char == "\\" then
            index = index + 1
            local escaped = string.sub(str, index, index)
            if escaped == "n" then char = "\n"
            elseif escaped == "r" then char = "\r"
            elseif escaped == "t" then char = "\t"
            elseif escaped == "b" then char = "\b"
            elseif escaped == "f" then char = "\f"
            elseif escaped == "/" then char = "/"
            elseif escaped == '"' then char = '"'
            elseif escaped == "\\" then char = "\\"
            elseif escaped == "u" then
                local hex = string.sub(str, index + 1, index + 4)
                local codepoint = tonumber(hex, 16)
                if not codepoint or #hex ~= 4 then return nil end
                index = index + 4
                if codepoint >= 0xD800 and codepoint <= 0xDBFF then
                    if string.sub(str, index + 1, index + 2) ~= "\\u" then return nil end
                    local lowHex = string.sub(str, index + 3, index + 6)
                    local low = tonumber(lowHex, 16)
                    if not low or low < 0xDC00 or low > 0xDFFF then return nil end
                    codepoint = 0x10000 + (codepoint - 0xD800) * 0x400 + low - 0xDC00
                    index = index + 6
                elseif codepoint >= 0xDC00 and codepoint <= 0xDFFF then
                    return nil
                end
                char = JimsServerRules.codepointToUtf8(codepoint)
                if not char then return nil end
            else return nil end
        end
        table.insert(result, char)
        index = index + 1
    end
    return table.concat(result)
end

function JimsServerRules.toJson(rules)
    return '{"rules":"' .. JimsServerRules.encodeJsonString(rules) .. '"}'
end

function JimsServerRules.fromJson(str)
    local encoded = tostring(str or ""):match('^%s*{%s*"rules"%s*:%s*"(.*)"%s*}%s*$')
    if not encoded then return nil end
    return JimsServerRules.decodeJsonString(encoded)
end

function JimsServerRules.writeRules(rules)
    local writer = getFileWriter(JimsServerRules.RULES_FILE, true, false)
    if not writer then return false end
    writer:write(JimsServerRules.toJson(rules))
    writer:close()
    return true
end

function JimsServerRules.readRules()
    local str = readFile(JimsServerRules.RULES_FILE, JimsServerRules.toJson(JimsServerRules.DEFAULT_RULES))
    return JimsServerRules.fromJson(str)
end

function JimsServerRules.isAdm(pl)
    if not pl then return false end
    return string.lower(tostring(pl:getAccessLevel() or "")) == "admin"
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

    local rules = JimsServerRules.readRules()
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
    local rules = JimsServerRules.readRules()
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

function JimsServerRules.sendAdminRules(pl, message)
    local rules = JimsServerRules.readRules()
    if not rules then
        sendServerCommand(pl, JimsServerRules.MODULE, JimsServerRules.COMMAND_ADMIN_ERROR, {
            message = "JimsServerRules.json is invalid. Fix it manually or restore the default rules."
        })
        return
    end
    sendServerCommand(pl, JimsServerRules.MODULE, JimsServerRules.COMMAND_ADMIN_DATA, {
        rules = rules,
        message = message
    })
end

function JimsServerRules.sendAdminError(pl, message)
    sendServerCommand(pl, JimsServerRules.MODULE, JimsServerRules.COMMAND_ADMIN_ERROR, {
        message = message
    })
end

function JimsServerRules.handleAdminCommand(command, pl, args)
    if not JimsServerRules.isAdm(pl) then
        JimsServerRules.sendAdminError(pl, "Admin access is required.")
        return
    end
    if command == JimsServerRules.COMMAND_ADMIN_REQUEST then
        JimsServerRules.sendAdminRules(pl)
    elseif command == JimsServerRules.COMMAND_ADMIN_SAVE then
        local rules = trim(args and args.rules)
        if rules == "" then
            JimsServerRules.sendAdminError(pl, "Server rules cannot be empty.")
        elseif JimsServerRules.writeRules(rules) then
            JimsServerRules.sendAdminRules(pl, "Server rules saved.")
        else
            JimsServerRules.sendAdminError(pl, "The server could not save the rules JSON file.")
        end
    elseif command == JimsServerRules.COMMAND_ADMIN_RESET then
        if JimsServerRules.writeRules(JimsServerRules.DEFAULT_RULES) then
            JimsServerRules.sendAdminRules(pl, "Default server rules restored.")
        else
            JimsServerRules.sendAdminError(pl, "The server could not save the rules JSON file.")
        end
    end
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

    if command == JimsServerRules.COMMAND_ADMIN_REQUEST
        or command == JimsServerRules.COMMAND_ADMIN_SAVE
        or command == JimsServerRules.COMMAND_ADMIN_RESET then
        JimsServerRules.handleAdminCommand(command, player, arguments)
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
    ensureFile(JimsServerRules.RULES_FILE, JimsServerRules.toJson(JimsServerRules.DEFAULT_RULES))
    ensureFile(JimsServerRules.ACCEPTED_USERS_FILE, "")
    log("Ready. Rules and accepted-user files are read dynamically for every player request.")
end

Events.OnClientCommand.Add(onClientCommand)
Events.OnServerStarted.Add(onServerStarted)
