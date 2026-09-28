if isClient() then return end

local allowedCheats = {
    isInvisible = true, isGodMod = true, isNoClip = true,
    isTimedActionInstantCheat = true, isUnlimitedCarry = true,
    isUnlimitedEndurance = true, isUnlimitedAmmo = true,
    isKnowAllRecipes = true, canHearAll = true, isZombiesDontAttack = true,
    isAlwaysDayCheat = true, isAnimalExtraValuesCheat = true,
    ISFastTeleportMove = true, ISBuildMenu = true, ISFarmingMenu = true,
    ISHealthPanel = true, ISVehicleMechanics = true, ISMoveableDefinitions = true,
    BrushToolManager = true, AnimalContextMenu = true,
    isFishingCheat = true, canSeeAll = true, isBuildCheat = true, isFarmingCheat = true,
    isHealthCheat = true, isMechanicsCheat = true, isMovablesCheat = true,
    isFastMoveCheat = true, isAnimalCheat = true, isCanUseBrushTool = true,
    canUseLootZed = true, canUseLootLog = true, ISLootZed = true, ISLootLog = true,
}

local function getPlayerLogName(username)
    return "ParadiseSentinel/player_" .. username:gsub("[^a-z0-9_-]", function(char)
        return string.format("%%%02X", string.byte(char))
    end) .. ".log"
end

local function writeLog(pl, message)
    if not pl then return end
    local username = pl:getUsername()
    if type(username) ~= "string" or username == "" then return end
    local writer = getFileWriter(getPlayerLogName(username), true, true)
    if not writer then
        print("[Sentinel] Could not open player log")
        return
    end
    local marker = string.lower(tostring(pl:getAccessLevel())) == "admin" and " [ADMIN]" or ""
    local line = "(" .. os.date("%Y-%m-%d %H:%M:%S") .. ")" .. marker
        .. " " .. message .. "\n"
    writer:write(line)
    writer:close()
end

local function doLog(pl, args)
    if type(args) ~= "table" or type(args.cheatStr) ~= "string"
        or not allowedCheats[args.cheatStr] or type(args.newValue) ~= "boolean" then return end
    writeLog(pl, args.cheatStr .. " -> " .. tostring(args.newValue))
end

local function logActivity(pl, args)
    if type(args) ~= "table" or type(args.text) ~= "string" then return end
    local text = args.text:gsub("[%c]", " "):match("^%s*(.-)%s*$")
    if args.kind == "panel" then
        if not text:match("^IS[%w_]+$") or #text > 80 then return end
        writeLog(pl, "PANEL OPEN [client report]: " .. text)
    elseif args.kind == "command" then
        local name = text:match("^(/%S+)")
        if not name then return end
        local lower = string.lower(text)
        if lower:find("password", 1, true) or lower:find("passwd", 1, true)
            or lower:find("pwd", 1, true) or string.lower(name) == "/adduser" then
            text = name .. " [arguments redacted]"
        end
        local label = string.lower(name) == "/additem" and "ITEM SPAWN REQUEST" or "COMMAND REQUEST"
        writeLog(pl, label .. " [client report]: " .. text:sub(1, 1024))
    end
end

Events.OnClientCommand.Add(function(module, command, pl, args)
    if module ~= "Sentinel" then return end
    if command == "doLog" then doLog(pl, args)
    elseif command == "activity" then logActivity(pl, args) end
end)
