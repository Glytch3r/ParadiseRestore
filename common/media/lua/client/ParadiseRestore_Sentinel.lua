if not isClient() then return end

ParadiseRestore = ParadiseRestore or {}
ParadiseRestore.Sentinel = ParadiseRestore.Sentinel or {}
local Sentinel = ParadiseRestore.Sentinel

local playerCheats = {
    "isInvisible", "isGodMod", "isNoClip", "isTimedActionInstantCheat",
    "isUnlimitedCarry", "isUnlimitedEndurance", "isUnlimitedAmmo",
    "isKnowAllRecipes", "canHearAll", "isZombiesDontAttack",
    "isAlwaysDayCheat", "isAnimalExtraValuesCheat",
    "isFishingCheat", "canSeeAll", "isBuildCheat", "isFarmingCheat",
    "isHealthCheat", "isMechanicsCheat", "isMovablesCheat", "isFastMoveCheat",
    "isAnimalCheat", "isCanUseBrushTool", "canUseLootZed", "canUseLootLog",
}
local menuCheats = {
    "ISFastTeleportMove", "ISBuildMenu", "ISFarmingMenu", "ISHealthPanel",
    "ISVehicleMechanics", "ISMoveableDefinitions", "BrushToolManager", "AnimalContextMenu",
    "ISLootZed", "ISLootLog",
}
local ticks = setmetatable({}, { __mode = "k" })
local panelNames = {
    "ISAdminPanelUI", "ISAdminPowerUI", "ISItemsListViewer", "ISPlayerStatsUI",
    "ISServerOptions", "ISServerSandboxOptionsUI", "ISRolesList", "ISUsersList",
    "ISFactionsList", "ISSafehousesList", "ISPvpZonePanel", "ISAddSafeZoneUI",
    "ISAdminTicketsUI", "ISMiniScoreboardUI", "ISStatisticsUI", "ISAdminWeather",
    "ISAdmPanelClimate", "ISAdmPanelWeather", "ISPVPLogToolUI", "ISMultiplayerZoneEditor",
    "ISItemEditorUI", "ISItemEditPanel", "ISLootZed", "ISLootLog",
}
local hooks = {}
local commandSerial = 0
local unpackValues = unpack or table.unpack

local function pack(...)
    return { n = select("#", ...), ... }
end

local function safeCommand(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("[%c]", " "):match("^%s*(.-)%s*$")
    local name = text:match("^(/%S+)")
    if not name then return nil end
    local lower = string.lower(text)
    if lower:find("password", 1, true) or lower:find("passwd", 1, true)
        or lower:find("pwd", 1, true) or string.lower(name) == "/adduser" then
        return name .. " [arguments redacted]"
    end
    return text:sub(1, 1024)
end

function Sentinel.reportActivity(kind, text)
    local pl = getPlayer()
    if not pl then return end
    if kind == "command" then text = safeCommand(text) end
    if not text then return end
    sendClientCommand(pl, "Sentinel", "activity", { kind = kind, text = text })
end

local function hookPanel(name)
    local class = _G[name]
    if type(class) ~= "table" or type(class.addToUIManager) ~= "function"
        or hooks[name] == class.addToUIManager then return end
    local original = class.addToUIManager
    local wrapper = function(self, ...)
        local result = pack(original(self, ...))
        Sentinel.reportActivity("panel", name)
        return unpackValues(result, 1, result.n)
    end
    hooks[name] = wrapper
    class.addToUIManager = wrapper
end

function Sentinel.installHooks()
    if type(SendCommandToServer) == "function" and hooks.send ~= SendCommandToServer then
        local original = SendCommandToServer
        hooks.send = function(command, ...)
            commandSerial = commandSerial + 1
            Sentinel.reportActivity("command", command)
            return original(command, ...)
        end
        SendCommandToServer = hooks.send
    end
    if ISChat and type(ISChat.onCommandEntered) == "function" and hooks.chat ~= ISChat.onCommandEntered then
        local original = ISChat.onCommandEntered
        hooks.chat = function(self, ...)
            local chat = ISChat.instance or self
            local command = chat.textEntry and chat.textEntry:getText()
            local serial = commandSerial
            local result = pack(original(self, ...))
            if serial == commandSerial then Sentinel.reportActivity("command", command) end
            return unpackValues(result, 1, result.n)
        end
        ISChat.onCommandEntered = hooks.chat
        if ISChat.instance and ISChat.instance.textEntry then
            ISChat.instance.textEntry.onCommandEntered = hooks.chat
        end
    end
    for _, name in ipairs(panelNames) do hookPanel(name) end
end

LuaEventManager.AddEvent("OnSentinelDetect")

local function readStates(pl)
    local states = {}
    for _, name in ipairs(playerCheats) do
        if pl[name] then states[name] = pl[name](pl) == true end
    end
    for _, name in ipairs(menuCheats) do
        local menu = _G[name]
        if type(menu) == "table" then states[name] = menu.cheat == true end
    end
    return states
end

function Sentinel.initPlayer(pl)
    if not pl or not pl:isLocalPlayer() then return end
    pl:getModData().LastCheatState = readStates(pl)
    ticks[pl] = 0
end

function Sentinel.init()
    Sentinel.installHooks()
    for index = 0, getNumActivePlayers() - 1 do
        Sentinel.initPlayer(getSpecificPlayer(index))
    end
end

function Sentinel.handler(pl)
    if not pl or not pl:isLocalPlayer() then return end
    if ticks[pl] == nil then
        Sentinel.initPlayer(pl)
        return
    end
    ticks[pl] = ticks[pl] + 1
    if ticks[pl] < 5 then return end
    ticks[pl] = 0
    local md = pl:getModData()
    local previous = md.LastCheatState or {}
    for name, value in pairs(readStates(pl)) do
        if (previous[name] ~= nil and previous[name] ~= value)
            or (previous[name] == nil and value) then
            triggerEvent("OnSentinelDetect", pl, name, value)
        end
        previous[name] = value
    end
    md.LastCheatState = previous
end

function Sentinel.doReport(pl, cheatStr, newValue)
    sendClientCommand(pl, "Sentinel", "doLog", { cheatStr = cheatStr, newValue = newValue })
end

Events.OnSentinelDetect.Add(Sentinel.doReport)
Events.OnGameStart.Add(Sentinel.init)
Events.OnCreatePlayer.Add(function(index, pl) Sentinel.initPlayer(pl) end)
Events.OnPlayerUpdate.Add(Sentinel.handler)
