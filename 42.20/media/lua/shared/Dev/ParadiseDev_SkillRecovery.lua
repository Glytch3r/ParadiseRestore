ParadiseDev = ParadiseDev or {}
ParadiseDev.SkillRecovery = ParadiseDev.SkillRecovery or {}

local recovery = ParadiseDev.SkillRecovery
recovery.module = "ParadiseDevSkillRecovery"
recovery.storeName = "ParadiseDev_SkillRecovery"
recovery.trait = "ParadiseDev:Reincarnate"

function recovery.getStore()
    local store = ModData.getOrCreate(recovery.storeName)
    store.players = store.players or {}
    return store
end

function recovery.getUsername(player)
    if not player then return nil end
    if player.getUsername then return tostring(player:getUsername()) end
    return player.username and tostring(player.username) or nil
end

function recovery.normalizeRecord(record)
    if not record then return nil end
    if not record.lives then
        record.lives = { { skills = record.skills or {}, earned = record.skills or {}, total = record.total or 0 } }
        record.skills = nil
        record.total = nil
    end
    return record
end

function recovery.getRecord(player)
    local username = recovery.getUsername(player)
    if not username or username == "" then return nil end
    return recovery.normalizeRecord(recovery.getStore().players[username]), username
end

function recovery.forEachPerk(callback)
    for index = 1, Perks.getMaxIndex() - 1 do
        local perk = Perks.fromIndex(index)
        if perk and perk.getId and perk.getParent and perk:getParent():getId() ~= "None" then callback(perk, perk:getId()) end
    end
end

function recovery.getMaxXP(perk)
    return perk and perk.getTotalXpForLevel and math.max(0, tonumber(perk:getTotalXpForLevel(10)) or 0) or 0
end

function recovery.getMode()
    local mode = SandboxVars and SandboxVars.ParadiseZ and tonumber(SandboxVars.ParadiseZ.RecoverySystem) or 1
    return math.max(1, math.min(5, math.floor(mode or 1)))
end

function recovery.log(action, username, total)
    print("[ParadiseDevSkillRecovery] " .. action .. " " .. tostring(username) .. " raw XP=" .. tostring(total))
end

function recovery.getStoredTotal(record)
    local total = 0
    for _, life in ipairs(record and record.lives or {}) do total = total + (tonumber(life.total) or 0) end
    return total
end

function recovery.saveDeath(player)
    local username = recovery.getUsername(player)
    local xp = player and player.getXp and player:getXp() or nil
    if not username or not xp then return false end
    local store = recovery.getStore()
    local record = recovery.normalizeRecord(store.players[username]) or { lives = {} }
    local life = { skills = {}, earned = {}, total = 0 }
    local baseline = player:getModData().ParadiseDevSkillRecoveryBaseline or {}
    recovery.forEachPerk(function(perk, perkID)
        local maxXP = recovery.getMaxXP(perk)
        local current = math.min(maxXP, math.max(0, tonumber(xp:getXP(perk)) or 0))
        local previous = math.min(maxXP, math.max(0, tonumber(baseline[perkID]) or 0))
        if current > 0 then life.skills[perkID] = current end
        if current > previous then life.earned[perkID] = current - previous end
        life.total = life.total + current
    end)
    table.insert(record.lives, life)
    store.players[username] = record
    if ModData.transmit then ModData.transmit(recovery.storeName) end
    recovery.log("SAVE", username, life.total)
    return true
end

recovery.save = recovery.saveDeath

function recovery.recordDeath(player)
    if not player or not player.getModData then return false end
    local data = player:getModData()
    local now = getGameTime and getGameTime():getWorldAgeHours() or 0
    if data.ParadiseDevSkillRecoveryDeathTime == now then return false end
    data.ParadiseDevSkillRecoveryDeathTime = now
    return recovery.saveDeath(player)
end

function recovery.getRecoveryXP(record, perkID)
    if not record then return 0 end
    local perk = Perks[perkID]
    local maxXP = recovery.getMaxXP(perk)
    local lives = record.lives or {}
    local mode = recovery.getMode()
    if mode == 5 or #lives == 0 then return 0 end
    local result = 0
    if mode == 1 or mode == 4 then
        result = tonumber(lives[#lives].earned and lives[#lives].earned[perkID]) or 0
        if mode == 4 then result = result * 0.5 end
    elseif mode == 2 then
        for _, life in ipairs(lives) do result = result + (tonumber(life.earned and life.earned[perkID]) or 0) end
    elseif mode == 3 then
        for _, life in ipairs(lives) do result = (result + (tonumber(life.earned and life.earned[perkID]) or 0)) * 0.75 end
    end
    return math.min(maxXP, math.max(0, result))
end

function recovery.applySkill(player, perkID)
    local record = recovery.getRecord(player)
    local perk = Perks[perkID]
    local xp = player and player.getXp and player:getXp() or nil
    if not record or not perk or not xp then return 0 end
    local baseline = player.getModData and player:getModData().ParadiseDevSkillRecoveryBaseline or {}
    local startingXP = math.max(0, tonumber(baseline[perkID]) or 0)
    local desired = math.min(recovery.getMaxXP(perk), startingXP + recovery.getRecoveryXP(record, perkID))
    local current = math.max(0, tonumber(xp:getXP(perk)) or 0)
    local rawAmount = math.max(0, desired - current)
    if rawAmount > 0 then xp:AddXP(perk, rawAmount, false, false, true) end
    return rawAmount
end

function recovery.retrieve(player)
    local record, username = recovery.getRecord(player)
    if not record then return false end
    local restored = 0
    recovery.forEachPerk(function(_, perkID) restored = restored + recovery.applySkill(player, perkID) end)
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

function recovery.getReincarnateTrait()
    if not CharacterTrait or not ResourceLocation then return nil end
    return CharacterTrait.get(ResourceLocation.of(recovery.trait))
end

function recovery.hasReincarnate(player)
    local trait = recovery.getReincarnateTrait()
    return player and trait and player.hasTrait and player:hasTrait(trait) or false
end

function recovery.setBaseline(player)
    local xp = player and player.getXp and player:getXp() or nil
    if not xp then return end
    local baseline = {}
    recovery.forEachPerk(function(perk, perkID) baseline[perkID] = math.max(0, tonumber(xp:getXP(perk)) or 0) end)
    player:getModData().ParadiseDevSkillRecoveryBaseline = baseline
end

function recovery.getPlan(player)
    local record = recovery.getRecord(player)
    local xp = player and player.getXp and player:getXp() or nil
    local skills = {}
    if not record or not xp or recovery.getMode() == 5 then return skills end
    local baseline = player.getModData and player:getModData().ParadiseDevSkillRecoveryBaseline or {}
    recovery.forEachPerk(function(perk, perkID)
        local startingXP = math.max(0, tonumber(baseline[perkID]) or 0)
        local desired = math.min(recovery.getMaxXP(perk), startingXP + recovery.getRecoveryXP(record, perkID))
        if desired > (tonumber(xp:getXP(perk)) or 0) then table.insert(skills, perkID) end
    end)
    return skills
end

function recovery.request(command, username, perkID)
    if not username or username == "" then return false end
    local args = { username = username, perkID = perkID }
    if isClient and isClient() then
        if not sendClientCommand then return false end
        sendClientCommand(recovery.module, command, args)
    else
        recovery.onClientCommand(recovery.module, command, getPlayer and getPlayer() or nil, args)
    end
    return true
end

function recovery.onClientCommand(module, command, sender, args)
    if module ~= recovery.module or not sender then return end
    local target = recovery.findPlayer(args and args.username, sender)
    if command == "save" and ParadiseDev.isAdm(sender) then
        recovery.saveDeath(target)
    elseif command == "retrieve" and ParadiseDev.isAdm(sender) then
        recovery.retrieve(target)
    elseif command == "autoStart" and recovery.hasReincarnate(sender) then
        recovery.setBaseline(sender)
        local skills = recovery.getPlan(sender)
        if isServer and isServer() then sendServerCommand(sender, recovery.module, "recoveryPlan", { skills = skills }) else recovery.queueRecovery(sender, skills) end
    elseif command == "recoverSkill" and recovery.hasReincarnate(sender) and args and args.perkID then
        recovery.applySkill(sender, args.perkID)
    elseif command == "death" then
        recovery.recordDeath(sender)
    end
end

function recovery.addTooltip(option, target)
    if not option or not ISToolTip then return end
    local record = recovery.getRecord(target)
    local tip = ISToolTip:new()
    tip:initialise()
    tip:setVisible(false)
    tip:setName("Stored Skill XP")
    tip.description = "Raw XP stored: " .. tostring(record and recovery.getStoredTotal(record) or 0) .. "\nLives recorded: " .. tostring(record and #record.lives or 0)
    option.toolTip = tip
end

function recovery.addTargetOptions(context, target)
    if not context or not target or not ParadiseDev.isAdm() then return end
    local username = target.username or recovery.getUsername(target)
    if not username or username == "" then return end
    local save = context:addOption("Save Skill XP: " .. username, nil, recovery.request, "save", username)
    local retrieve = context:addOption("Retrieve Skill XP: " .. username, nil, recovery.request, "retrieve", username)
    recovery.addTooltip(save, target)
    recovery.addTooltip(retrieve, target)
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
    local save = context:addOption("Save My Skill XP", nil, recovery.request, "save", username)
    local retrieve = context:addOption("Retrieve My Skill XP", nil, recovery.request, "retrieve", username)
    recovery.addTooltip(save, player)
    recovery.addTooltip(retrieve, player)
end

function recovery.queueRecovery(player, skills)
    if not player or not skills or #skills == 0 then
        recovery.setBaseline(player)
        return
    end
    recovery.queue = { player = player, skills = skills, index = 1, delay = 90, announced = false }
end

function recovery.onTick()
    local queue = recovery.queue
    if not queue then return end
    queue.delay = queue.delay - 1
    if queue.delay > 0 then return end
    if not queue.announced then
        queue.announced = true
        queue.delay = 60
        HaloTextHelper.addText(queue.player, "Recovering skill points...", "", HaloTextHelper.getColorWhite())
        return
    end
    local perkID = queue.skills[queue.index]
    if not perkID then
        recovery.setBaseline(queue.player)
        recovery.queue = nil
        return
    end
    recovery.request("recoverSkill", recovery.getUsername(queue.player), perkID)
    HaloTextHelper.addText(queue.player, "Recovered " .. tostring(perkID) .. " skill points", "", HaloTextHelper.getColorWhite())
    queue.index = queue.index + 1
    queue.delay = 30
end

function recovery.onCreatePlayer(playerNum, player)
    if isServer and isServer() then return end
    player = player or (getPlayer and getPlayer() or nil)
    recovery.setBaseline(player)
    if not recovery.hasReincarnate(player) then
        return
    end
    if isClient and isClient() then
        recovery.request("autoStart", recovery.getUsername(player))
    else
        recovery.queueRecovery(player, recovery.getPlan(player))
    end
end

function recovery.onPlayerDeath(player)
    if isClient and isClient() then
        if player and player.isLocalPlayer and player:isLocalPlayer() then
            sendClientCommand(recovery.module, "death", {})
        end
        return
    end
    recovery.recordDeath(player)
end

function recovery.onServerCommand(module, command, args)
    if module ~= recovery.module or command ~= "recoveryPlan" then return end
    recovery.queueRecovery(getPlayer and getPlayer() or nil, args and args.skills or {})
end

if Events.OnClientCommand then Events.OnClientCommand.Add(recovery.onClientCommand) end
if Events.OnFillWorldObjectContextMenu then Events.OnFillWorldObjectContextMenu.Add(recovery.addWorldOptions) end
if Events.OnCreatePlayer then Events.OnCreatePlayer.Add(recovery.onCreatePlayer) end
if Events.OnPlayerDeath then Events.OnPlayerDeath.Add(recovery.onPlayerDeath) end
if Events.OnTick then Events.OnTick.Add(recovery.onTick) end
if Events.OnServerCommand then Events.OnServerCommand.Add(recovery.onServerCommand) end

if Events.OnGameStart then Events.OnGameStart.Add(function()
    if ModData.request then ModData.request(recovery.storeName) end
end) end
