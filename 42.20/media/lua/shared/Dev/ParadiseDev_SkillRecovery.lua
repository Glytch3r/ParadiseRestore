ParadiseDev = ParadiseDev or {}
ParadiseDev.SkillRecovery = ParadiseDev.SkillRecovery or {}

local recovery = ParadiseDev.SkillRecovery
recovery.module = "ParadiseDevSkillRecovery"
recovery.storeName = "ParadiseDev_SkillRecovery"

function recovery.getStore()
    local store = ModData.getOrCreate(recovery.storeName)
    store.players = store.players or {}
    return store
end

function recovery.getUsername(player)
    return player and player.getUsername and tostring(player:getUsername()) or nil
end

function recovery.getRecord(player)
    local username = recovery.getUsername(player)
    if not username or username == "" then return nil end
    return recovery.getStore().players[username], username
end

function recovery.forEachPerk(callback)
    for index = 1, Perks.getMaxIndex() - 1 do
        local perk = Perks.fromIndex(index)
        if perk and perk.getId and perk.getParent and perk:getParent():getId() ~= "None" then callback(perk, perk:getId()) end
    end
end

function recovery.log(action, username, total)
    print("[ParadiseDevSkillRecovery] " .. action .. " " .. tostring(username) .. " raw XP=" .. tostring(total))
end

function recovery.save(player)
    local username = recovery.getUsername(player)
    local xp = player and player.getXp and player:getXp() or nil
    if not username or not xp then return false end
    local record = { skills = {}, total = 0 }
    recovery.forEachPerk(function(perk, perkID)
        local amount = math.max(0, tonumber(xp:getXP(perk)) or 0)
        if amount > 0 then
            record.skills[perkID] = amount
            record.total = record.total + amount
        end
    end)
    recovery.getStore().players[username] = record
    if ModData.transmit then ModData.transmit(recovery.storeName) end
    recovery.log("SAVE", username, record.total)
    return true
end

function recovery.retrieve(player)
    local record, username = recovery.getRecord(player)
    local xp = player and player.getXp and player:getXp() or nil
    if not record or not xp then return false end
    local restored = 0
    for perkID, stored in pairs(record.skills or {}) do
        local perk = Perks[perkID]
        if perk then
            local current = math.max(0, tonumber(xp:getXP(perk)) or 0)
            local rawAmount = math.max(0, (tonumber(stored) or 0) - current)
            if rawAmount > 0 then
                xp:AddXP(perk, rawAmount, false, false, true)
                restored = restored + rawAmount
            end
        end
    end
    recovery.log("RETRIEVE", username, restored)
    return true
end

function recovery.findPlayer(username, fallback)
    if not username or username == "" then return fallback end
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if players then
        for index = 0, players:size() - 1 do
            local player = players:get(index)
            if recovery.getUsername(player) == username then return player end
        end
    end
    return fallback and recovery.getUsername(fallback) == username and fallback or nil
end

function recovery.request(command, username)
    if not username or username == "" or not sendClientCommand then return false end
    sendClientCommand(recovery.module, command, { username = username })
    return true
end

function recovery.onClientCommand(module, command, admin, args)
    if module ~= recovery.module or not ParadiseDev.isAdm(admin) then return end
    local target = recovery.findPlayer(args and args.username, admin)
    if command == "save" then recovery.save(target) end
    if command == "retrieve" then recovery.retrieve(target) end
end

function recovery.addTargetOptions(context, target)
    if not context or not target or not ParadiseDev.isAdm() then return end
    local username = target.username or recovery.getUsername(target)
    if not username or username == "" then return end
    context:addOption("Save Skill XP: " .. username, nil, recovery.request, "save", username)
    context:addOption("Retrieve Skill XP: " .. username, nil, recovery.request, "retrieve", username)
end

function recovery.getWorldTarget(context)
    if not context or not context.options then return nil end
    for _, option in ipairs(context.options) do
        if option.param4 and instanceof(option.param4, "IsoPlayer") then return option.param4 end
    end
    return nil
end

function recovery.addWorldOptions(playerNum, context, worldobjects, test)
    if test or not ParadiseDev.isAdm() then return end
    local target = recovery.getWorldTarget(context)
    if target then
        recovery.addTargetOptions(context, target)
        return
    end
    local player = getPlayer and getPlayer() or nil
    local username = recovery.getUsername(player)
    if not username then return end
    context:addOption("Save My Skill XP", nil, recovery.request, "save", username)
    context:addOption("Retrieve My Skill XP", nil, recovery.request, "retrieve", username)
end

if Events.OnClientCommand then Events.OnClientCommand.Add(recovery.onClientCommand) end
if Events.OnFillWorldObjectContextMenu then Events.OnFillWorldObjectContextMenu.Add(recovery.addWorldOptions) end

function recovery.installScoreboardHook()
    if recovery.scoreboardInstalled or not ISMiniScoreboardUI then return end
    recovery.scoreboardInstalled = true
    recovery.scoreboardContext = ISMiniScoreboardUI.doPlayerListContextMenu
    function ISMiniScoreboardUI:doPlayerListContextMenu(player, x, y)
        recovery.scoreboardContext(self, player, x, y)
        local context = ISContextMenu.get(self.admin:getPlayerNum(), x + self:getAbsoluteX(), y + self:getAbsoluteY())
        recovery.addTargetOptions(context, player)
    end
end

recovery.installScoreboardHook()
if Events.OnGameStart then Events.OnGameStart.Add(recovery.installScoreboardHook) end
