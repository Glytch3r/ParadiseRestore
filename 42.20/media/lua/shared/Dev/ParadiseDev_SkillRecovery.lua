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

function recovery.getUsername(pl)
    if not pl then return nil end
    if pl.getUsername then return tostring(pl:getUsername()) end
    return pl.username and tostring(pl.username) or nil
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

function recovery.getRecord(pl)
    local username = recovery.getUsername(pl)
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
    return math.max(1, math.min(6, math.floor(mode or 1)))
end

function recovery.log(action, username, total)
    print("[ParadiseDevSkillRecovery] " .. action .. " " .. tostring(username) .. " raw XP=" .. tostring(total))
end

function recovery.getStoredTotal(record)
    local total = 0
    for _, life in ipairs(record and record.lives or {}) do total = total + (tonumber(life.total) or 0) end
    return total
end

function recovery.getTraits(pl)
    local traits = {}
    local list = pl and pl.getTraits and pl:getTraits() or nil
    if not list then
        local descriptor = pl and pl.getDescriptor and pl:getDescriptor() or nil
        list = descriptor and descriptor.getTraits and descriptor:getTraits() or nil
    end
    if list then
        for index = 0, list:size() - 1 do
            local trait = list:get(index)
            local traitID = type(trait) == "string" and trait or (trait and trait.getId and trait:getId() or tostring(trait))
            if traitID and traitID ~= "" then table.insert(traits, traitID) end
        end
    end
    return traits
end

function recovery.getKnownRecipes(pl)
    local recipes = {}
    local list = pl and pl.getKnownRecipes and pl:getKnownRecipes() or nil
    if list then
        for index = 0, list:size() - 1 do
            table.insert(recipes, list:get(index))
        end
    end
    return recipes
end

function recovery.saveDeath(pl)
    local user = recovery.getUsername(pl)
    local xp = pl and pl.getXp and pl:getXp() or nil
    if not user or not xp then return false end
    local store = recovery.getStore()
    local record = recovery.normalizeRecord(store.players[user]) or { lives = {} }
    local life = { skills = {}, earned = {}, total = 0 }
    local baseline = pl:getModData().ParadiseDevSkillRecoveryBaseline or {}
    recovery.forEachPerk(function(perk, perkID)
        local maxXP = recovery.getMaxXP(perk)
        local current = math.min(maxXP, math.max(0, tonumber(xp:getXP(perk)) or 0))
        local previous = math.min(maxXP, math.max(0, tonumber(baseline[perkID]) or 0))
        if current > 0 then life.skills[perkID] = current end
        if current > previous then life.earned[perkID] = current - previous end
        life.total = life.total + current
    end)
    local descriptor = pl.getDescriptor and pl:getDescriptor() or nil
    life.profession = descriptor and descriptor.getProfession and descriptor:getProfession() or nil
    life.forename = descriptor and descriptor.getForename and descriptor:getForename() or nil
    life.surname = descriptor and descriptor.getSurname and descriptor:getSurname() or nil
    life.traits = recovery.getTraits(pl)
    life.recipes = recovery.getKnownRecipes(pl)
    table.insert(record.lives, life)
    store.players[user] = record
    if ModData.transmit then ModData.transmit(recovery.storeName) end
    recovery.log("SAVE", user, life.total)
    return true
end

recovery.save = recovery.saveDeath

function recovery.recordDeath(pl)
    if not pl or not pl.getModData then return false end
    local data = pl:getModData()
    local now = getGameTime and getGameTime():getWorldAgeHours() or 0
    if data.ParadiseDevSkillRecoveryDeathTime == now then return false end
    data.ParadiseDevSkillRecoveryDeathTime = now
    return recovery.saveDeath(pl)
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
    elseif mode == 6 then
        result = (tonumber(lives[#lives].earned and lives[#lives].earned[perkID]) or 0) * 0.9
    end
    return math.min(maxXP, math.max(0, result))
end

function recovery.applySkill(pl, perkID)
    local record = recovery.getRecord(pl)
    local perk = Perks[perkID]
    local xp = pl and pl.getXp and pl:getXp() or nil
    if not record or not perk or not xp then return 0 end
    local baseline = pl.getModData and pl:getModData().ParadiseDevSkillRecoveryBaseline or {}
    local startingXP = math.max(0, tonumber(baseline[perkID]) or 0)
    local desired = math.min(recovery.getMaxXP(perk), startingXP + recovery.getRecoveryXP(record, perkID))
    local current = math.max(0, tonumber(xp:getXP(perk)) or 0)
    local rawAmount = math.max(0, desired - current)
    if rawAmount > 0 then xp:AddXP(perk, rawAmount, false, false, true) end
    return rawAmount
end

function recovery.retrieve(pl)
    local record, username = recovery.getRecord(pl)
    if not record then return false end
    if recovery.getMode() == 6 then recovery.applyIdentity(pl) end
    local restored = 0
    recovery.forEachPerk(function(_, perkID) restored = restored + recovery.applySkill(pl, perkID) end)
    recovery.log("RETRIEVE", username, restored)
    return true
end

function recovery.findPlayer(user, fallback)
    if not user or user == "" then return fallback end
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if players then
        for index = 0, players:size() - 1 do
            local pl = players:get(index)
            if recovery.getUsername(pl) == user then return pl end
        end
    end
    return fallback and recovery.getUsername(fallback) == user and fallback or nil
end

function recovery.getReincarnateTrait()
    if not CharacterTrait or not ResourceLocation then return nil end
    return CharacterTrait.get(ResourceLocation.of(recovery.trait))
end

function recovery.hasReincarnate(pl)
    local trait = recovery.getReincarnateTrait()
    return pl and trait and pl.hasTrait and pl:hasTrait(trait) or false
end

function recovery.setBaseline(pl)
    local xp = pl and pl.getXp and pl:getXp() or nil
    if not xp then return end
    local data = pl:getModData()
    if type(data.ParadiseDevSkillRecoveryBaseline) == "table" then return end
    local baseline = {}
    recovery.forEachPerk(function(perk, perkID) baseline[perkID] = math.max(0, tonumber(xp:getXP(perk)) or 0) end)
    data.ParadiseDevSkillRecoveryBaseline = baseline
end

function recovery.getLifeCount(pl)
    local record = recovery.getRecord(pl)
    return record and #(record.lives or {}) or 0
end

function recovery.isLifeRestored(pl, lifeCount)
    local data = pl and pl.getModData and pl:getModData() or nil
    return data and tonumber(data.ParadiseDevSkillRecoveryRestoredLifeCount) == tonumber(lifeCount) or false
end

function recovery.markLifeRestored(pl, lifeCount)
    if not pl or not pl.getModData then return end
    if tonumber(lifeCount) ~= recovery.getLifeCount(pl) then return end
    pl:getModData().ParadiseDevSkillRecoveryRestoredLifeCount = lifeCount
end

function recovery.completeRecovery(pl, lifeCount)
    if recovery.getMode() == 6 then recovery.applyIdentity(pl) end
    recovery.markLifeRestored(pl, lifeCount)
end

function recovery.getPlan(pl)
    local record = recovery.getRecord(pl)
    local xp = pl and pl.getXp and pl:getXp() or nil
    local skills = {}
    if not record or not xp or recovery.getMode() == 5 then return skills end
    if recovery.isLifeRestored(pl, #(record.lives or {})) then return skills end
    local baseline = pl.getModData and pl:getModData().ParadiseDevSkillRecoveryBaseline or {}
    recovery.forEachPerk(function(perk, perkID)
        local startingXP = math.max(0, tonumber(baseline[perkID]) or 0)
        local desired = math.min(recovery.getMaxXP(perk), startingXP + recovery.getRecoveryXP(record, perkID))
        if desired > (tonumber(xp:getXP(perk)) or 0) then table.insert(skills, perkID) end
    end)
    return skills
end

function recovery.applyIdentity(pl)
    local record = recovery.getRecord(pl)
    local lives = record and record.lives or {}
    local life = lives[#lives]
    if not life then return false end
    local descriptor = pl.getDescriptor and pl:getDescriptor() or nil
    if not descriptor then return false end
    if life.forename and descriptor.setForename then descriptor:setForename(life.forename) end
    if life.surname and descriptor.setSurname then descriptor:setSurname(life.surname) end
    if life.profession and descriptor.setProfession then descriptor:setProfession(life.profession) end
    local playerTraits = pl.getTraits and pl:getTraits() or nil
    if playerTraits then
        playerTraits:clear()
        for _, traitID in ipairs(life.traits or {}) do
            local trait = CharacterTrait and ResourceLocation and CharacterTrait.get and ResourceLocation.of and CharacterTrait.get(ResourceLocation.of(traitID)) or traitID
            if trait then playerTraits:add(trait) end
        end
    end
    if descriptor.getTraits then
        local currentTraits = descriptor:getTraits()
        if currentTraits then
            currentTraits:clear()
            for _, traitID in ipairs(life.traits or {}) do currentTraits:add(traitID) end
        end
    end
    local knownRecipes = pl.getKnownRecipes and pl:getKnownRecipes() or nil
    if knownRecipes then
        for _, recipeName in ipairs(life.recipes or {}) do
            if not knownRecipes:contains(recipeName) then knownRecipes:add(recipeName) end
        end
    end
    if sendPlayerStatsChange then sendPlayerStatsChange(pl) end
    return true
end

function recovery.request(command, username, perkID, lifeCount)
    if not username or username == "" then return false end
    local args = { username = username, perkID = perkID, lifeCount = lifeCount }
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
        local lifeCount = recovery.getLifeCount(sender)
        if isServer and isServer() then sendServerCommand(sender, recovery.module, "recoveryPlan", { skills = skills, lifeCount = lifeCount }) else recovery.queueRecovery(sender, skills, lifeCount) end
    elseif command == "recoverSkill" and recovery.hasReincarnate(sender) and args and args.perkID then
        recovery.applySkill(sender, args.perkID)
    elseif command == "autoComplete" and recovery.hasReincarnate(sender) then
        recovery.completeRecovery(sender, args and args.lifeCount)
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

function recovery.getClickedSquare(worldobjects)
    if ISWorldObjectContextMenu and ISWorldObjectContextMenu.fetchVars and ISWorldObjectContextMenu.fetchVars.clickedSquare then
        return ISWorldObjectContextMenu.fetchVars.clickedSquare
    end
    for _, obj in ipairs(worldobjects or {}) do
        if obj and obj.getSquare then
            local sq = obj:getSquare()
            if sq then return sq end
        end
    end
    return clickedSquare
end

function recovery.addParadiseOptions(menu, pl, worldobjects)
    if not menu or not pl or not ParadiseDev.isAdm(pl) then return end
    if recovery.getClickedSquare(worldobjects) ~= pl:getSquare() then return end
    local root = menu:addOption("Skill Recovery")
    root.iconTexture = getTexture("media/ui/Traits/trait_Reincarnate.png")
    local submenu = ISContextMenu:getNew(menu)
    menu:addSubMenu(root, submenu)
    local user = recovery.getUsername(pl)
    local save = submenu:addOption("Save Skill XP", nil, recovery.request, "save", user)
    local retrieve = submenu:addOption("Retrieve Skill XP", nil, recovery.request, "retrieve", user)
    recovery.addTooltip(save, pl)
    recovery.addTooltip(retrieve, pl)
end

function recovery.queueRecovery(pl, skills, lifeCount)
    if not pl or not skills or #skills == 0 then
        local completedLifeCount = lifeCount or recovery.getLifeCount(pl)
        if isClient and isClient() then recovery.request("autoComplete", recovery.getUsername(pl), nil, completedLifeCount) else recovery.completeRecovery(pl, completedLifeCount) end
        return
    end
    recovery.queue = { pl = pl, skills = skills, index = 1, delay = 90, announced = false, lifeCount = lifeCount or recovery.getLifeCount(pl) }
end

function recovery.onTick()
    local queue = recovery.queue
    if not queue then return end
    queue.delay = queue.delay - 1
    if queue.delay > 0 then return end
    if not queue.announced then
        queue.announced = true
        queue.delay = 60
        HaloTextHelper.addText(queue.pl, "Recovering skill points...", "", HaloTextHelper.getColorWhite())
        return
    end
    local perkID = queue.skills[queue.index]
    if not perkID then
        if isClient and isClient() then recovery.request("autoComplete", recovery.getUsername(queue.pl), nil, queue.lifeCount) else recovery.completeRecovery(queue.pl, queue.lifeCount) end
        recovery.queue = nil
        return
    end
    recovery.request("recoverSkill", recovery.getUsername(queue.pl), perkID)
    HaloTextHelper.addText(queue.pl, "Recovered " .. tostring(perkID) .. " skill points", "", HaloTextHelper.getColorWhite())
    queue.index = queue.index + 1
    queue.delay = 30
end

function recovery.onCreatePlayer(playerNum, pl)
    if isServer and isServer() then return end
    pl = pl or (getPlayer and getPlayer() or nil)
    recovery.setBaseline(pl)
    if not recovery.hasReincarnate(pl) then
        return
    end
    if isClient and isClient() then
        recovery.request("autoStart", recovery.getUsername(pl))
    else
        recovery.queueRecovery(pl, recovery.getPlan(pl), recovery.getLifeCount(pl))
    end
end

function recovery.onPlayerDeath(pl)
    if isClient and isClient() then
        if pl and pl.isLocalPlayer and pl:isLocalPlayer() then
            sendClientCommand(recovery.module, "death", {})
        end
        return
    end
    recovery.recordDeath(pl)
end

function recovery.onServerCommand(module, command, args)
    if module ~= recovery.module or command ~= "recoveryPlan" then return end
    recovery.queueRecovery(getPlayer and getPlayer() or nil, args and args.skills or {}, args and args.lifeCount)
end

if Events.OnClientCommand then Events.OnClientCommand.Add(recovery.onClientCommand) end
if Events.OnCreatePlayer then Events.OnCreatePlayer.Add(recovery.onCreatePlayer) end
if Events.OnPlayerDeath then Events.OnPlayerDeath.Add(recovery.onPlayerDeath) end
if Events.OnTick then Events.OnTick.Add(recovery.onTick) end
if Events.OnServerCommand then Events.OnServerCommand.Add(recovery.onServerCommand) end

if Events.OnGameStart then Events.OnGameStart.Add(function()
    if ModData.request then ModData.request(recovery.storeName) end
end) end
