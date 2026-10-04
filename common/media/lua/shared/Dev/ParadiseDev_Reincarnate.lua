ParadiseDev = ParadiseDev or {}
ParadiseDev.Reincarnate = ParadiseDev.Reincarnate or {}

local recovery = ParadiseDev.Reincarnate
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

function recovery.getRecordKeyStr(pl)
    pl = pl or getPlayer()
    local desc = pl and pl.getDescriptor and pl:getDescriptor() or nil
    if not desc then return nil end
    local forename = tostring(desc:getForename() or "unknown")
    local surname = tostring(desc:getSurname() or "unknown")
    local prof = desc.getCharacterProfession and desc:getCharacterProfession() or nil
    prof = prof and prof.getName and prof:getName() or (desc.getProfession and desc:getProfession() or "unemployed")
    return string.lower((forename .. "_" .. surname .. "_" .. tostring(prof)):gsub("[^%w_%-]", "_"))
end

function recovery.copyTab(tab)
    if type(tab) ~= "table" then return tab end
    local result = {}
    for key, value in pairs(tab) do result[recovery.copyTab(key)] = recovery.copyTab(value) end
    return result
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
    life.hoursSurvived = pl.getHoursSurvived and pl:getHoursSurvived() or 0
    life.zombieKills = pl.getZombieKills and pl:getZombieKills() or 0
    life.x = pl.getX and pl:getX() or nil
    life.y = pl.getY and pl:getY() or nil
    life.z = pl.getZ and pl:getZ() or nil
    table.insert(record.lives, life)
    store.players[user] = record
    if ModData.transmit then ModData.transmit(recovery.storeName) end
    recovery.log("SAVE", user, life.total)
    return true
end

function recovery.saveNamedRecord(pl)
    if not pl then return false end
    recovery.saveDeath(pl)
    local record = recovery.getRecord(pl)
    local key = recovery.getRecordKeyStr(pl)
    if not record or not key then return false end
    local store = recovery.getStore()
    store.records = store.records or {}
    store.records[key] = recovery.copyTab(record)
    if ModData.transmit then ModData.transmit(recovery.storeName) end
    return true
end

function recovery.getRecordKeys()
    local keys = {}
    local records = recovery.getStore().records or {}
    for key in pairs(records) do keys[#keys + 1] = key end
    table.sort(keys)
    return keys
end

function recovery.deleteRecord(key)
    local records = recovery.getStore().records or {}
    records[key] = nil
    if ModData.transmit then ModData.transmit(recovery.storeName) end
end

function recovery.loadRecord(pl, key)
    local record = recovery.normalizeRecord((recovery.getStore().records or {})[key])
    local user = recovery.getUsername(pl)
    if not record or not user then return false end
    recovery.getStore().players[user] = recovery.copyTab(record)
    return recovery.retrieve(pl)
end

function recovery.syncRecords(pl)
    if not pl then return end
    local records = recovery.getStore().records or {}
    if isServer and isServer() then
        sendServerCommand(pl, recovery.module, "recordsSync", { records = records })
    else
        recovery.receiveRecords(records)
    end
end

function recovery.receiveRecords(records)
    recovery.getStore().records = records or {}
end

function recovery.applyStats(pl)
    local record = recovery.getRecord(pl)
    local lives = record and record.lives or {}
    local life = lives[#lives]
    if not life then return end
    if SandboxVars.ParadiseZ.ReincarnateKeepSurvivalTime and pl.setHoursSurvived then pl:setHoursSurvived(tonumber(life.hoursSurvived) or 0) end
    if SandboxVars.ParadiseZ.ReincarnateKeepZombieKills and pl.setZombieKills then pl:setZombieKills(tonumber(life.zombieKills) or 0) end
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
    if mode == 1 then
        result = (tonumber(lives[#lives].skills and lives[#lives].skills[perkID]) or 0) * 0.9
    elseif mode == 4 then
        result = (tonumber(lives[#lives].earned and lives[#lives].earned[perkID]) or 0) * 0.5
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
    if rawAmount <= 0 then return 0 end
    -- Only the server (or single-player) may award the saved, server-calculated XP.
    if isClient and isClient() then return 0 end
    if isServer and isServer() then
        -- B42's supported award path also updates its XP anti-cheat baseline.
        -- Do not fall back to raw AddXP on a server: that caused recovery spikes.
        if not addXpNoMultiplier then
            error("[ParadiseDevSkillRecovery] server XP award helper unavailable")
        end
        addXpNoMultiplier(pl, perk, rawAmount)
    else
        xp:AddXP(perk, rawAmount, false, false, true)
    end
    local awarded = math.max(0, (tonumber(xp:getXP(perk)) or current) - current)
    recovery.log("AWARD " .. tostring(perkID) .. " requested=" .. tostring(rawAmount), recovery.getUsername(pl), awarded)
    return awarded
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
        local existingTraits = {}
        for index = 0, playerTraits:size() - 1 do
            existingTraits[#existingTraits + 1] = tostring(playerTraits:get(index))
        end
        for _, traitID in ipairs(existingTraits) do
            ParadiseDev.setTrait(traitID, false, pl)
        end
        for _, traitID in ipairs(life.traits or {}) do
            ParadiseDev.setTrait(traitID, true, pl)
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
    if command == "save" and ParadiseRestore.isAdm(sender) then
        recovery.saveDeath(target)
    elseif command == "retrieve" and ParadiseRestore.isAdm(sender) then
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
    elseif command == "saveRecord" and ParadiseRestore.isAdm(sender) then
        recovery.saveNamedRecord(target)
        recovery.syncRecords(sender)
    elseif command == "deleteRecord" and ParadiseRestore.isAdm(sender) and args.key then
        recovery.deleteRecord(args.key)
        recovery.syncRecords(sender)
    elseif command == "loadRecord" and ParadiseRestore.isAdm(sender) and args.key then
        recovery.loadRecord(target, args.key)
        recovery.syncRecords(sender)
    elseif command == "getRecords" and ParadiseRestore.isAdm(sender) then
        recovery.syncRecords(sender)
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
    if not context or not target or not ParadiseRestore.isAdm() then return end
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
    if not menu or not pl or not ParadiseRestore.isAdm(pl) then return end
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

function recovery.randomizeName(pl)
    pl = pl or getPlayer()
    if not pl then return end
    SurvivorFactory.randomName(pl:getDescriptor())
    sendPlayerStatsChange(pl)
end

function recovery.isTraitExclusive(traitDef, selected)
    local excluded = traitDef:getMutuallyExclusiveTraits()
    for index = 0, excluded:size() - 1 do
        if selected[tostring(excluded:get(index))] then return true end
    end
    return false
end

function recovery.randomizeTraits(pl, pointBudget)
    local current = recovery.getTraits(pl)
    for _, traitID in ipairs(current) do ParadiseDev.setTrait(traitID, false, pl) end
    local positive = {}
    local negative = {}
    local traits = CharacterTraitDefinition.getTraits()
    for index = 0, traits:size() - 1 do
        local traitDef = traits:get(index)
        if not traitDef:isFree() and not (isClient() and traitDef:isDisabledInMultiplayer()) then
            if traitDef:getCost() > 0 then positive[#positive + 1] = traitDef elseif traitDef:getCost() < 0 then negative[#negative + 1] = traitDef end
        end
    end
    local selected = {}
    local points = pointBudget
    for count = 1, ZombRand(1, 4) do
        if #negative > 0 then
            local traitDef = table.remove(negative, ZombRand(#negative) + 1)
            if not recovery.isTraitExclusive(traitDef, selected) then
                local traitID = tostring(traitDef:getType())
                selected[traitID] = true
                points = points - traitDef:getCost()
                ParadiseDev.setTrait(traitID, true, pl)
            end
        end
    end
    for count = 1, ZombRand(1, 5) do
        if #positive > 0 then
            local traitDef = table.remove(positive, ZombRand(#positive) + 1)
            if traitDef:getCost() <= points and not recovery.isTraitExclusive(traitDef, selected) then
                local traitID = tostring(traitDef:getType())
                selected[traitID] = true
                points = points - traitDef:getCost()
                ParadiseDev.setTrait(traitID, true, pl)
            end
        end
    end
end

function recovery.randomizePerks(pl, hours)
    local days = hours / 24
    local maxLvl = math.min(10, math.max(1, math.floor(math.sqrt(days + 1) + 1)))
    recovery.forEachPerk(function(perk)
        pl:setPerkLevelDebug(perk, 0)
        pl:getXp():setXPToLevel(perk, 0)
        if ZombRand(100) < math.min(70, 12 + days) then
            local lvl = ZombRand(maxLvl + 1)
            pl:setPerkLevelDebug(perk, lvl)
            pl:getXp():setXPToLevel(perk, lvl)
            local currentXP = lvl > 0 and perk:getTotalXpForLevel(lvl) or 0
            local nextXP = lvl < 10 and perk:getTotalXpForLevel(lvl + 1) or currentXP
            if nextXP > currentXP then pl:getXp():AddXP(perk, ZombRandFloat(0, nextXP - currentXP), false, false, true) end
        end
    end)
end

function recovery.randomizeCharacter(pl)
    pl = pl or getPlayer()
    if not pl or not ParadiseRestore.isAdm(pl) then return end
    recovery.randomizeName(pl)
    local professions = CharacterProfessionDefinition.getProfessions()
    local prof = professions:get(ZombRand(professions:size()))
    pl:getDescriptor():setCharacterProfession(prof:getType())
    recovery.randomizeTraits(pl, (tonumber(SandboxVars.CharacterFreePoints) or 0) + prof:getCost())
    local grantedTraits = prof:getGrantedTraits()
    for index = 0, grantedTraits:size() - 1 do ParadiseDev.setTrait(tostring(grantedTraits:get(index)), true, pl) end
    local hours = math.floor(math.pow(ZombRandFloat(0, 1), 2.4) * 4320) + 1
    local kills = math.floor(hours / 24 * ZombRandFloat(0.5, 18) + ZombRand(8))
    pl:setHoursSurvived(hours)
    pl:setZombieKills(kills)
    recovery.randomizePerks(pl, hours)
    SyncXp(pl)
    sendPlayerStatsChange(pl)
    sendPlayerExtraInfo(pl)
end

function recovery.addRecordTooltip(opt, record)
    if not opt or not record then return end
    local life = (record.lives or {})[#(record.lives or {})] or {}
    local tip = ISToolTip:new()
    tip:initialise()
    tip:setVisible(false)
    tip.description = tostring(life.forename) .. " " .. tostring(life.surname) .. "\nProfession: " .. tostring(life.profession) .. "\nHours: " .. tostring(life.hoursSurvived or 0) .. "\nZombie kills: " .. tostring(life.zombieKills or 0) .. "\nXP: " .. tostring(recovery.getStoredTotal(record)) .. "\nLives: " .. tostring(#(record.lives or {}))
    opt.toolTip = tip
end

function recovery.requestOption(_, command, username, key)
    if key then
        if isClient and isClient() then
            sendClientCommand(recovery.module, command, { username = username, key = key })
        else
            recovery.onClientCommand(recovery.module, command, getPlayer(), { username = username, key = key })
        end
        return
    end
    recovery.request(command, username)
end

function recovery.addTraitOption(_, pl)
    ParadiseDev.setTrait(recovery.trait, true, pl)
end

function recovery.retrieveOption(_, pl)
    recovery.retrieve(pl)
end

function recovery.randomizeNameOption(_, pl)
    recovery.randomizeName(pl)
end

function recovery.randomizeCharacterOption(_, pl)
    recovery.randomizeCharacter(pl)
end

function recovery.addTestOptions(menu, pl)
    if not ParadiseRestore.isAdm(pl) then return end
    local root = menu:addOption("ReincarnateTest")
    local sub = ISContextMenu:getNew(menu)
    menu:addSubMenu(root, sub)
    sub:addOption("Add Reincarnate Trait", nil, recovery.addTraitOption, pl)
    sub:addOption("doReincarnate", nil, recovery.retrieveOption, pl)
    sub:addOption("Save Record", nil, recovery.requestOption, "saveRecord", recovery.getUsername(pl))
    sub:addOption("randomizeName", nil, recovery.randomizeNameOption, pl)
    sub:addOption("Randomize Character", nil, recovery.randomizeCharacterOption, pl)
    local records = recovery.getStore().records or {}
    for _, label in ipairs({"Delete Record", "Load Record"}) do
        local opt = sub:addOption(label)
        local list = ISContextMenu:getNew(sub)
        sub:addSubMenu(opt, list)
        for _, key in ipairs(recovery.getRecordKeys()) do
            local command = label == "Delete Record" and "deleteRecord" or "loadRecord"
            local item = list:addOption(key, nil, recovery.requestOption, command, recovery.getUsername(pl), key)
            recovery.addRecordTooltip(item, records[key])
        end
    end
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
    recovery.applyStats(pl)
    if isClient and isClient() then
        recovery.request("autoStart", recovery.getUsername(pl))
    else
        recovery.queueRecovery(pl, recovery.getPlan(pl), recovery.getLifeCount(pl))
    end
end

function recovery.onPlayerDeath(pl)
    if pl and recovery.hasReincarnate(pl) then
        recovery.pending = recovery.pending or {}
        recovery.pending[pl:getPlayerNum()] = true
    end
    if isClient and isClient() then
        if pl and pl.isLocalPlayer and pl:isLocalPlayer() then
            sendClientCommand(recovery.module, "death", {})
        end
        return
    end
    recovery.recordDeath(pl)
end

function recovery.doReincarnate(plNum)
    local pl = getSpecificPlayer(plNum)
    local record = recovery.getRecord(pl)
    local life = record and record.lives and record.lives[#record.lives] or nil
    if not life then return false end
    local desc = SurvivorFactory.CreateSurvivor()
    desc:setForename(life.forename or desc:getForename())
    desc:setSurname(life.surname or desc:getSurname())
    if life.profession and desc.setProfession then desc:setProfession(life.profession) end
    if SandboxVars.ParadiseZ.isSpawnAtDeathLoc and life.x and life.y then
        getWorld():setLuaPosX(life.x)
        getWorld():setLuaPosY(life.y)
        getWorld():setLuaPosZ(life.z or 0)
    end
    getWorld():setLuaPlayerDesc(desc)
    getWorld():getLuaTraits():clear()
    for _, traitID in ipairs(life.traits or {}) do getWorld():addLuaTrait(traitID) end
    if ISPostDeathUI.instance[plNum] then ISPostDeathUI.instance[plNum]:removeFromUIManager() end
    ISPostDeathUI.instance[plNum] = nil
    recovery.pending[plNum] = nil
    setPlayerMouse(nil)
    return true
end

function recovery.installHooks()
    if not ISPostDeathUI or recovery.hooksInstalled then return end
    recovery.hooksInstalled = true
    recovery.createChildrenHook = ISPostDeathUI.createChildren
    recovery.onRespawnHook = ISPostDeathUI.onRespawn
    function ISPostDeathUI:createChildren()
        recovery.createChildrenHook(self)
        if recovery.pending and recovery.pending[self.playerIndex] then self.buttonRespawn:setTitle("Reincarnate") end
    end
    function ISPostDeathUI:onRespawn()
        if recovery.pending and recovery.pending[self.playerIndex] and recovery.doReincarnate(self.playerIndex) then return end
        return recovery.onRespawnHook(self)
    end
end

function recovery.onServerCommand(module, command, args)
    if module ~= recovery.module then return end
    if command == "recoveryPlan" then
        recovery.queueRecovery(getPlayer and getPlayer() or nil, args and args.skills or {}, args and args.lifeCount)
    elseif command == "recordsSync" then
        recovery.receiveRecords(args and args.records or {})
    end
end

if Events.OnClientCommand then Events.OnClientCommand.Remove(recovery.onClientCommand) Events.OnClientCommand.Add(recovery.onClientCommand) end
if Events.OnCreatePlayer then Events.OnCreatePlayer.Remove(recovery.onCreatePlayer) Events.OnCreatePlayer.Add(recovery.onCreatePlayer) end
if Events.OnPlayerDeath then Events.OnPlayerDeath.Remove(recovery.onPlayerDeath) Events.OnPlayerDeath.Add(recovery.onPlayerDeath) end
if Events.OnTick then Events.OnTick.Remove(recovery.onTick) Events.OnTick.Add(recovery.onTick) end
if Events.OnServerCommand then Events.OnServerCommand.Remove(recovery.onServerCommand) Events.OnServerCommand.Add(recovery.onServerCommand) end
if Events.OnGameStart then Events.OnGameStart.Remove(recovery.installHooks) Events.OnGameStart.Add(recovery.installHooks) end

function recovery.requestStore()
    if ModData.request then ModData.request(recovery.storeName) end
end

if Events.OnGameStart then Events.OnGameStart.Remove(recovery.requestStore) Events.OnGameStart.Add(recovery.requestStore) end

function recovery.onReceiveGlobalModData(name, data)
    if name ~= recovery.storeName or not data then return end
    if ModData.exists(recovery.storeName) then ModData.remove(recovery.storeName) end
    ModData.add(recovery.storeName, data)
end

if Events.OnReceiveGlobalModData then Events.OnReceiveGlobalModData.Remove(recovery.onReceiveGlobalModData) Events.OnReceiveGlobalModData.Add(recovery.onReceiveGlobalModData) end
