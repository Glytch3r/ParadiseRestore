-- B42.20 admin spectate support.  The scoreboard layout remains vanilla;
-- only its player context menu is extended.
ParadiseZ = ParadiseZ or {}
ParadiseZ.Oversight = ParadiseZ.Oversight or {}

local MODULE = "ParadiseZOversight"
local FOLLOW_INTERVAL = 5
local followTicks = 0

if ParadiseZ.Oversight.followPlayer then
    Events.OnPlayerUpdate.Remove(ParadiseZ.Oversight.followPlayer)
end
if ParadiseZ.Oversight.syncHiddenModels then
    Events.OnTick.Remove(ParadiseZ.Oversight.syncHiddenModels)
end
if ParadiseZ.Oversight.requestHideState then
    Events.OnGameStart.Remove(ParadiseZ.Oversight.requestHideState)
end

local function canSpectate(player)
    local role = player and player:getRole()
    return role and role:hasCapability(Capability.TeleportToPlayer)
end

local function getLocalPlayer()
    return getPlayer()
end

function ParadiseZ.isSpectating(player)
    player = player or getLocalPlayer()
    return player ~= nil and player:getModData().ParadiseZSpectateTarget ~= nil
end

function ParadiseZ.getSpectateTargUser(player)
    player = player or getLocalPlayer()
    return player and player:getModData().ParadiseZSpectateTarget or nil
end

function ParadiseZ.getSpectateTarg(player)
    local username = ParadiseZ.getSpectateTargUser(player)
    return username and getPlayerFromUsername(username) or nil
end

function ParadiseZ.setSpectate(target)
    local player = getLocalPlayer()
    if not player then return end

    local username = type(target) == "string" and target or (target and target:getUsername())
    if not username or username == "" or username == player:getUsername() then
        player:getModData().ParadiseZSpectateTarget = nil
        ParadiseZ.setSpectateSkin(player)
        return
    end

    player:getModData().ParadiseZSpectateTarget = username
    ParadiseZ.setSpectateSkin(player)
end

function ParadiseZ.stopSpectate()
    ParadiseZ.setSpectate(nil)
end

local function applyHiddenModel(player, hidden)
    if not player then return end
    player:setHideWeaponModel(hidden)
    player:setAlpha(hidden and 0 or 1)
    player:setTargetAlpha(hidden and 0 or 1)
    player:resetModelNextFrame()
end

function ParadiseZ.setSpectateHiddenModel(player, hidden)
    player = player or getLocalPlayer()
    if not player then return end

    hidden = hidden == true
    local modData = player:getModData()
    if modData.ParadiseZHideModel == hidden then return end
    modData.ParadiseZHideModel = hidden
    ParadiseZ.Oversight.hiddenUsers = ParadiseZ.Oversight.hiddenUsers or {}
    ParadiseZ.Oversight.hiddenUsers[player:getUsername()] = hidden
    applyHiddenModel(player, hidden)

    if isClient() then
        sendClientCommand(MODULE, "setHideModel", { hidden = hidden })
    end
end

function ParadiseZ.setSpectateSkin(player)
    player = player or getLocalPlayer()
    if not player then return end

    local spectating = ParadiseZ.isSpectating(player)
    local options = SandboxVars.ParadiseZ or {}
    ParadiseZ.setSpectateHiddenModel(player, spectating and options.HideAvatar == true)

    -- Invisible and ghost mode are separate vanilla admin states.  We leave
    -- them untouched here until their server-authoritative migration is done.
end

function ParadiseZ.doSpectateTP(player)
    player = player or getLocalPlayer()
    if not player or not ParadiseZ.isSpectating(player) then return end
    if player:getVehicle() then
        ParadiseZ.stopSpectate()
        return
    end

    local username = ParadiseZ.getSpectateTargUser(player)
    if not username then return end

    followTicks = followTicks + 1
    if followTicks % FOLLOW_INTERVAL ~= 0 then return end

    if isClient() then
        sendClientCommand(MODULE, "follow", { username = username })
        return
    end

    local target = getPlayerFromUsername(username)
    if target and ParadiseDev and ParadiseDev.TP then
        ParadiseDev.TP.applyTeleport(player, target:getX(), target:getY(), target:getZ())
    elseif not target then
        ParadiseZ.stopSpectate()
    end
end

ParadiseZ.Oversight.followPlayer = ParadiseZ.doSpectateTP
Events.OnPlayerUpdate.Add(ParadiseZ.Oversight.followPlayer)

ParadiseZ.Oversight.hiddenUsers = ParadiseZ.Oversight.hiddenUsers or {}
ParadiseZ.Oversight.hiddenTick = ParadiseZ.Oversight.hiddenTick or 0
ParadiseZ.Oversight.syncHiddenModels = function()
    ParadiseZ.Oversight.hiddenTick = ParadiseZ.Oversight.hiddenTick + 1
    if ParadiseZ.Oversight.hiddenTick % 30 ~= 0 then return end

    for username, hidden in pairs(ParadiseZ.Oversight.hiddenUsers) do
        local player = getPlayerFromUsername(username)
        if player then applyHiddenModel(player, hidden) end
    end
end
Events.OnTick.Add(ParadiseZ.Oversight.syncHiddenModels)

ParadiseZ.Oversight.requestHideState = function()
    if isClient() then
        sendClientCommand(MODULE, "requestHideState", {})
    end
end
Events.OnGameStart.Add(ParadiseZ.Oversight.requestHideState)

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= MODULE then return end

    if command == "teleport" then
        local player = getLocalPlayer()
        if player and ParadiseZ.isSpectating(player) and args then
            if ParadiseDev and ParadiseDev.TP then ParadiseDev.TP.applyTeleport(player, args.x, args.y, args.z) end
        end
    elseif command == "hideModel" and args then
        ParadiseZ.Oversight.hiddenUsers[args.username] = args.hidden == true
        applyHiddenModel(getPlayerFromUsername(args.username), args.hidden == true)
    elseif command == "hideState" and args and args.entries then
        for _, entry in ipairs(args.entries) do
            ParadiseZ.Oversight.hiddenUsers[entry.username] = entry.hidden == true
            applyHiddenModel(getPlayerFromUsername(entry.username), entry.hidden == true)
        end
    end
end)

-- Keep the B42 scoreboard's UI and permission-gated vanilla actions.
ParadiseZ.Oversight.vanillaScoreboardContext = ParadiseZ.Oversight.vanillaScoreboardContext or ISMiniScoreboardUI.doPlayerListContextMenu
function ISMiniScoreboardUI:doPlayerListContextMenu(player, x, y)
    local playerNum = self.admin:getPlayerNum()
    local context = ISContextMenu.get(playerNum, x + self:getAbsoluteX(), y + self:getAbsoluteY())
    local admin = self.admin
    local role = admin:getRole()

    if role:hasCapability(Capability.TeleportToPlayer) then
        context:addOption(getText("UI_Scoreboard_Teleport"), self, ISMiniScoreboardUI.onCommand, player, "TELEPORT")
        context:addOption("Spectate: " .. player.username, nil, function()
            ParadiseZ.setSpectate(player.username)
        end)
        if ParadiseZ.isSpectating(admin) then
            context:addOption("Stop Spectating", nil, ParadiseZ.stopSpectate)
        end
    end
    if role:hasCapability(Capability.TeleportPlayerToAnotherPlayer) then
        context:addOption(getText("UI_Scoreboard_TeleportToYou"), self, ISMiniScoreboardUI.onCommand, player, "TELEPORTTOYOU")
    end
    if role:hasCapability(Capability.ToggleInvisibleEveryone) then
        context:addOption(getText("UI_Scoreboard_Invisible"), self, ISMiniScoreboardUI.onCommand, player, "INVISIBLE")
    end
    if role:hasCapability(Capability.ToggleGodModEveryone) then
        context:addOption(getText("UI_Scoreboard_GodMod"), self, ISMiniScoreboardUI.onCommand, player, "GODMOD")
    end
    if role:hasCapability(Capability.CanSeePlayersStats) then
        context:addOption("Check Stats", self, ISMiniScoreboardUI.onCommand, player, "STATS")
    end
end
