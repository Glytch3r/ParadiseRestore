ParadiseDev = ParadiseDev or {}
ParadiseDev.Reincarnate = ParadiseDev.Reincarnate or {}

local recovery = ParadiseDev.Reincarnate
recovery.module = "ParadiseDevSkillRecovery"
recovery.storeName = "ParadiseDev_SkillRecovery"
recovery.deathAudioPaused = recovery.deathAudioPaused or false
recovery.wideLayoutWidth = 900
recovery.deathTextures = recovery.deathTextures or {}
recovery.deathTextureCount = 60
recovery.deathTextureFrameMs = 30
recovery.creationInProgress = recovery.creationInProgress or {}
recovery.deathSubmitted = recovery.deathSubmitted or {}

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
    local prof = descriptor and descriptor.getCharacterProfession and descriptor:getCharacterProfession() or nil
    life.profession = prof and prof.getName and prof:getName() or (descriptor and descriptor.getProfession and descriptor:getProfession() or nil)
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
    return recovery.applyRecordExact(pl, record)
end

function recovery.applyRecordExact(pl, record)
    local lives = record and record.lives or {}
    local life = lives[#lives]
    local xp = pl and pl.getXp and pl:getXp() or nil
    if not life or not xp then return false end
    recovery.forEachPerk(function(perk, perkID)
        pl:setPerkLevelDebug(perk, 0)
        xp:setXPToLevel(perk, 0)
        local saved = math.max(0, tonumber(life.skills and life.skills[perkID]) or 0)
        local earned = math.max(0, tonumber(life.earned and life.earned[perkID]) or 0)
        local amount = math.max(0, saved - earned + earned * 0.9)
        if amount > 0 then xp:AddXP(perk, amount, false, false, true) end
    end)
    local desc = pl:getDescriptor()
    if life.forename then desc:setForename(life.forename) end
    if life.surname then desc:setSurname(life.surname) end
    if life.profession then
        local professions = CharacterProfessionDefinition.getProfessions()
        for index = 0, professions:size() - 1 do
            local profDef = professions:get(index)
            if tostring(profDef:getType():getName()) == tostring(life.profession) then
                desc:setCharacterProfession(profDef:getType())
                break
            end
        end
    end
    local current = recovery.getTraits(pl)
    for _, traitID in ipairs(current) do ParadiseDev.setTrait(traitID, false, pl) end
    for _, traitID in ipairs(life.traits or {}) do ParadiseDev.setTrait(traitID, true, pl) end
    local recipes = pl.getKnownRecipes and pl:getKnownRecipes() or nil
    if recipes then
        recipes:clear()
        for _, recipeName in ipairs(life.recipes or {}) do recipes:add(recipeName) end
    end
    if pl.setHoursSurvived then pl:setHoursSurvived(tonumber(life.hoursSurvived) or 0) end
    if pl.setZombieKills then pl:setZombieKills(tonumber(life.zombieKills) or 0) end
    if not (isServer and isServer()) then
        SyncXp(pl)
        sendPlayerStatsChange(pl)
        sendPlayerExtraInfo(pl)
    end
    return true
end

function recovery.syncRecords(pl, status, key)
    if not pl then return end
    local records = recovery.getStore().records or {}
    if isServer and isServer() then
        sendServerCommand(pl, recovery.module, "recordsSync", { records = records, status = status, key = key })
    else
        recovery.receiveRecords(records)
        recovery.showRecordHalo(pl, status, key)
    end
end

function recovery.receiveRecords(records)
    recovery.getStore().records = records or {}
end

function recovery.showRecordHalo(pl, status, key)
    if not pl or not status or not key then return end
    pl:setHaloNote(tostring(key) .. " " .. tostring(status), 150, 250, 150, 900)
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

function recovery.isShouldReincarnate()
    local sand = SandboxVars and SandboxVars.ParadiseZ or nil
    return not sand or sand.isShouldReincarnate ~= false
end

function ParadiseDev.Reincarnate.getDeathMessages()
    local sand = SandboxVars and SandboxVars.ParadiseZ or nil
    local str = sand and tostring(sand.ReincarnateDeathMessages or "") or ""
    local tab = {}
    for strEntry in string.gmatch(str, "([^;]+)") do
        strEntry = strEntry:gsub("^%s+", ""):gsub("%s+$", "")
        if strEntry ~= "" then tab[#tab + 1] = strEntry end
    end
    if #tab == 0 then tab[1] = "THAT WAS PARADISE." end
    return tab
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
    elseif command == "autoStart" and recovery.isShouldReincarnate() then
        recovery.setBaseline(sender)
        local skills = recovery.getPlan(sender)
        local lifeCount = recovery.getLifeCount(sender)
        if isServer and isServer() then sendServerCommand(sender, recovery.module, "recoveryPlan", { skills = skills, lifeCount = lifeCount }) else recovery.queueRecovery(sender, skills, lifeCount) end
    elseif command == "recoverSkill" and recovery.isShouldReincarnate() and args and args.perkID then
        recovery.applySkill(sender, args.perkID)
    elseif command == "autoComplete" and recovery.isShouldReincarnate() then
        recovery.completeRecovery(sender, args and args.lifeCount)
    elseif command == "death" then
        recovery.recordDeath(sender)
    elseif command == "saveRecord" and ParadiseRestore.isAdm(sender) then
        local key = recovery.getRecordKeyStr(target)
        local overwritten = key and (recovery.getStore().records or {})[key] ~= nil
        if recovery.saveNamedRecord(target) then recovery.syncRecords(sender, overwritten and "overwritten" or "saved", key) end
    elseif command == "deleteRecord" and ParadiseRestore.isAdm(sender) and args.key then
        recovery.deleteRecord(args.key)
        recovery.syncRecords(sender, "deleted", args.key)
    elseif command == "loadRecord" and ParadiseRestore.isAdm(sender) and args.key then
        local record = (recovery.getStore().records or {})[args.key]
        if recovery.loadRecord(target, args.key) then
            if isServer and isServer() and record then sendServerCommand(sender, recovery.module, "applyRecord", { record = record }) end
            recovery.syncRecords(sender, "loaded", args.key)
        end
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

function recovery.retrieveOption(_, pl)
    local record = recovery.getRecord(pl)
    recovery.applyRecordExact(pl, record)
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

function recovery.pauseDeathAudio(pl)
    if isServer and isServer() then return end
    if not pl or not pl.isLocalPlayer or not pl:isLocalPlayer() then return end
    if recovery.deathAudioPaused then return end
    recovery.deathAudioPaused = true
    pauseSoundAndMusic()
end

function recovery.resumeDeathAudio()
    if not recovery.deathAudioPaused then return end
    recovery.deathAudioPaused = false
    resumeSoundAndMusic()
end

function ParadiseDev.Reincarnate.removeCreationTransition()
    if not recovery.creationTransition then return end
    recovery.creationTransition:removeFromUIManager()
    recovery.creationTransition = nil
end

function ParadiseDev.Reincarnate.showCreationTransition()
    recovery.removeCreationTransition()
    local panel = ISPanel:new(0, 0, getCore():getScreenWidth(), getCore():getScreenHeight())
    panel:initialise()
    panel.background = true
    panel.backgroundColor = { r = 0, g = 0, b = 0, a = 1 }
    panel.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    panel:setAlwaysOnTop(true)
    panel:addToUIManager()
    recovery.creationTransition = panel
end

function ParadiseDev.Reincarnate.setCreationBackground()
    local panel = CoopCharacterCreation and CoopCharacterCreation.instance or nil
    if not panel then return end
    panel.background = true
    panel.backgroundColor = { r = 0, g = 0, b = 0, a = 1 }
    panel.borderColor = { r = 0, g = 0, b = 0, a = 0 }
end

function ParadiseDev.Reincarnate.clearCreationState(plNum)
    recovery.creationBlackout = false
    if plNum ~= nil then
        recovery.creationInProgress[plNum] = nil
    else
        recovery.creationInProgress = {}
    end
    recovery.removeCreationTransition()
end

function recovery.onCreatePlayer(playerNum, pl)
    if isServer and isServer() then return end
    pl = pl or (getPlayer and getPlayer() or nil)
    ParadiseDev.Reincarnate.clearCreationState(playerNum)
    recovery.deathSubmitted[playerNum] = nil
    recovery.resumeDeathAudio()
    recovery.setBaseline(pl)
    if not recovery.isShouldReincarnate() then
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
    recovery.pauseDeathAudio(pl)
    if not pl then return end
    local plNum = pl:getPlayerNum()
    if recovery.creationInProgress[plNum] or recovery.deathSubmitted[plNum] then return end
    recovery.deathSubmitted[plNum] = true
    if pl and recovery.isShouldReincarnate() then
        recovery.pending = recovery.pending or {}
        recovery.pending[plNum] = true
    end
    if isClient and isClient() then
        if pl and pl.isLocalPlayer and pl:isLocalPlayer() then
            if ParadiseLimbo and ParadiseLimbo.report then ParadiseLimbo.report(0) end
            sendClientCommand(recovery.module, "death", {})
        end
        return
    end
    recovery.recordDeath(pl)
end

function recovery.getPlayerByUsername(username)
    if not username then return nil end
    local target = getPlayerFromUsername and getPlayerFromUsername(username) or nil
    if target then return target end
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players then return nil end
    username = string.lower(tostring(username))
    for index = 0, players:size() - 1 do
        local pl = players:get(index)
        local user = recovery.getUsername(pl)
        if user and string.lower(user) == username then return pl end
    end
    return nil
end

function recovery.getCagedRespawnLoc(username)
    local pl = recovery.getPlayerByUsername(username)
    local engine = ParadiseDev and ParadiseDev.Zones and ParadiseDev.Zones.Engine or nil
    if not pl or not engine or not ParadiseDev.Cage or not ParadiseDev.Cage.isCaged or not ParadiseDev.Cage.isCaged(pl) then return nil end
    local steamID = engine.playerSteamId and engine.playerSteamId(pl) or nil
    local zoneID = steamID and engine.cageAssignments and engine.cageAssignments[steamID] or nil
    local zone = zoneID and engine.zones and engine.zones[zoneID] or nil
    if not zone and engine.nearestCageZone then zone = engine.nearestCageZone(pl) end
    if not zone then return nil end
    local point = engine.getCageRebound and engine.getCageRebound(pl, zone) or nil
    if point then return point.x, point.y, point.z end
    local region = engine.nearestRegion and engine.nearestRegion(zone, pl:getX(), pl:getY()) or nil
    if not region then return nil end
    local x, y = engine.regionCenter(region)
    local z = zone.zMode == "floor" and zone.zMin or pl:getZ()
    return x, y, z
end

function recovery.getLoreEventRespawnLoc(username)
    --[[
    LoreEvents respawn condition and location resolver goes here when that system is written.
    --]]
    return nil
end

function recovery.getSafehouseRespawnLoc(username)
    local safehouse = username and SafeHouse and SafeHouse.hasSafehouse and SafeHouse.hasSafehouse(username) or nil
    if not safehouse then return nil end
    return safehouse:getX() + safehouse:getW() / 2, safehouse:getY() + safehouse:getH() / 2, 0
end

function recovery.getServerRespawnLoc()
    local options = getServerOptions and getServerOptions() or nil
    local value = options and options.getOption and options:getOption("SpawnPoint") or nil
    local xyz = value and value:split(",") or nil
    if not xyz or #xyz ~= 3 then return nil end
    local x, y, z = tonumber(xyz[1]), tonumber(xyz[2]), tonumber(xyz[3])
    if not x or not y or not z or x == 0 and y == 0 then return nil end
    return x, y, z
end

function recovery.getVanillaRespawnLoc()
    local regions = SpawnRegionMgr and SpawnRegionMgr.getSpawnRegions and SpawnRegionMgr.getSpawnRegions() or nil
    local region = regions and regions[1] or nil
    local points = region and region.points or nil
    local spawn = points and (points.unemployed or points[CharacterProfession and CharacterProfession.UNEMPLOYED and CharacterProfession.UNEMPLOYED:getName()]) or nil
    if not spawn or #spawn == 0 then return nil end
    local point = spawn[ZombRand(#spawn) + 1]
    local x = point.worldX and point.worldX * 300 + point.posX or point.posX
    local y = point.worldY and point.worldY * 300 + point.posY or point.posY
    return x, y, point.posZ or 0
end

function recovery.getRespawnLoc(username)
    local x, y, z = recovery.getCagedRespawnLoc(username)
    if x then return x, y, z end
    x, y, z = recovery.getLoreEventRespawnLoc(username)
    if x then return x, y, z end
    x, y, z = recovery.getSafehouseRespawnLoc(username)
    if x then return x, y, z end
    x, y, z = recovery.getServerRespawnLoc()
    if x then return x, y, z end
    return recovery.getVanillaRespawnLoc()
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

function recovery.onContinueAsNew(panel)
    recovery.pending = recovery.pending or {}
    recovery.pending[panel.playerIndex] = nil
    recovery.creationBlackout = true
    recovery.creationInProgress[panel.playerIndex] = true
    if ParadiseLimbo and ParadiseLimbo.report then ParadiseLimbo.report(2) end
    local result = recovery.onRespawnHook(panel)
    recovery.setCreationBackground()
    return result
end

function recovery.onEventRespawn()
    if ParadiseLimbo and ParadiseLimbo.report then ParadiseLimbo.report(5) end
end

function recovery.getDeathTexture()
    local now = getTimestampMs and getTimestampMs() or os.time() * 1000
    local frame = math.floor(now / recovery.deathTextureFrameMs) % recovery.deathTextureCount + 1
    if not recovery.deathTextures[frame] then
        recovery.deathTextures[frame] = getTexture("media/ui/Paradise/DeathAnim/DeathAnim_" .. string.format("%03d", frame) .. ".png")
    end
    return recovery.deathTextures[frame]
end

function recovery.layoutPostDeath(panel)
    local width = panel.screenWidth
    local height = panel.screenHeight
    panel:setX(panel.screenX)
    panel:setY(panel.screenY)
    panel:setWidth(width)
    panel:setHeight(height)
    local margin = math.max(12, math.floor(math.min(width, height) * 0.025))
    local normalButtonHgt = math.max(28, getTextManager():getFontHeight(UIFont.Small) + 12)
    local buttonHgt = normalButtonHgt
    local buttons = { panel.buttonRespawn, panel.buttonEventRespawn, panel.buttonContinue, panel.buttonExit, panel.buttonQuit }
    if width >= recovery.wideLayoutWidth and height >= 500 then
        local gap = margin
        local primaryWidth = math.min(260, math.floor((width - margin * 4) / 3))
        local primaryTotal = primaryWidth * 3 + gap * 2
        local primaryX = math.floor((width - primaryTotal) / 2)
        local primaryY = height - buttonHgt * 2 - margin * 2
        for index = 1, 3 do
            local button = buttons[index]
            button:setX(primaryX + (index - 1) * (primaryWidth + gap))
            button:setY(primaryY)
            button:setWidth(primaryWidth)
            button:setHeight(buttonHgt)
        end
        local secondaryWidth = math.min(220, math.floor((width - margin * 3) / 2))
        local secondaryX = math.floor((width - secondaryWidth * 2 - gap) / 2)
        for index = 4, 5 do
            local button = buttons[index]
            button:setX(secondaryX + (index - 4) * (secondaryWidth + gap))
            button:setY(primaryY + buttonHgt + margin)
            button:setWidth(secondaryWidth)
            button:setHeight(buttonHgt)
        end
    else
        local buttonWidth = math.max(1, math.min(width - margin * 2, 420))
        local gap = height < 350 and 4 or math.max(4, math.floor(margin / 2))
        local buttonArea = height < 350 and math.floor(height * 0.58) or height - margin * 2
        buttonHgt = math.max(18, math.min(normalButtonHgt, math.floor((buttonArea - gap * (#buttons - 1)) / #buttons)))
        local totalHeight = buttonHgt * #buttons + gap * (#buttons - 1)
        local buttonX = math.floor((width - buttonWidth) / 2)
        local buttonY = height - totalHeight - margin
        for index, button in ipairs(buttons) do
            button:setX(buttonX)
            button:setY(buttonY + (index - 1) * (buttonHgt + gap))
            button:setWidth(buttonWidth)
            button:setHeight(buttonHgt)
        end
    end
    panel.deathContentBottom = buttons[1]:getY() - margin
end

function recovery.renderPostDeath(panel)
    ISPanelJoypad.render(panel)
    if panel.quitToDesktopDialog and panel.quitToDesktopDialog:isReallyVisible() then
        panel:clearStencilRect()
        return
    end
    local width = panel.screenWidth
    local height = panel.screenHeight
    local compact = width < recovery.wideLayoutWidth or height < 500
    local textureY = math.max(16, math.floor(height * (compact and 0.06 or 0.08)))
    local contentHeight = math.max(48, (panel.deathContentBottom or height * 0.65) - textureY)
    local minimal = contentHeight < 190
    local reservedTextHeight = minimal and 38 or getTextManager():getFontHeight(UIFont.Large) + getTextManager():getFontHeight(UIFont.Small) * #(panel.lines or {}) + 22
    local textureSize = math.floor(math.min(width * (compact and 0.28 or 0.24), contentHeight - reservedTextHeight, 360))
    textureSize = math.max(16, textureSize)
    local deathTexture = recovery.getDeathTexture()
    if deathTexture then panel:drawTextureScaled(deathTexture, math.floor((width - textureSize) / 2), textureY, textureSize, textureSize, 1, 1, 1, 1) end
    local titleY = textureY + textureSize + math.max(8, math.floor(height * 0.015))
    local titleFont = minimal and UIFont.Small or UIFont.Large
    panel:drawTextCentre(panel.deathMessage, width / 2, titleY, 1, 1, 1, 1, titleFont)
    if not minimal then
        local lineY = titleY + getTextManager():getFontHeight(titleFont) + 8
        for _, line in ipairs(panel.lines or {}) do
            panel:drawTextCentre(line, width / 2, lineY, 0.85, 0.85, 0.85, 1, UIFont.Small)
            lineY = lineY + getTextManager():getFontHeight(UIFont.Small) + 2
        end
    end
    panel:clearStencilRect()
end

function recovery.installHooks()
    if not ISPostDeathUI or recovery.hooksInstalled then return end
    recovery.hooksInstalled = true
    recovery.createChildrenHook = ISPostDeathUI.createChildren
    recovery.prerenderHook = ISPostDeathUI.prerender
    recovery.renderHook = ISPostDeathUI.render
    recovery.onRespawnHook = ISPostDeathUI.onRespawn
    recovery.onExitHook = ISPostDeathUI.onExit
    recovery.onConfirmQuitToDesktopHook = ISPostDeathUI.onConfirmQuitToDesktop
    recovery.coopAcceptHook = CoopCharacterCreation and CoopCharacterCreation.accept or nil
    recovery.coopCancelHook = CoopCharacterCreation and CoopCharacterCreation.cancel or nil
    function ISPostDeathUI:createChildren()
        recovery.createChildrenHook(self)
        self.buttonRespawn:setTitle("Reincarnate")
        self.buttonRespawn:setEnable(recovery.pending and recovery.pending[self.playerIndex] == true)
        self.buttonEventRespawn = ISButton:new(0, 0, 100, 25, "Event Respawn", self, recovery.onEventRespawn)
        self:configButton(self.buttonEventRespawn)
        self.buttonEventRespawn:setEnable(false)
        self.buttonEventRespawn:enableDisabledColor()
        self:addChild(self.buttonEventRespawn)
        self.buttonContinue = ISButton:new(0, 0, 100, 25, "Continue as New Character", self, recovery.onContinueAsNew)
        self:configButton(self.buttonContinue)
        self:addChild(self.buttonContinue)
        local tab = ParadiseDev.Reincarnate.getDeathMessages()
        self.deathMessage = tab[ZombRand(#tab) + 1]
        recovery.layoutPostDeath(self)
    end
    function ISPostDeathUI:prerender()
        self:drawRect(0, 0, self.screenWidth, self.screenHeight, 1, 0, 0, 0)
        recovery.prerenderHook(self)
        recovery.layoutPostDeath(self)
        self.buttonEventRespawn:setVisible(self.buttonRespawn:isVisible())
        self.buttonContinue:setVisible(self.buttonRespawn:isVisible())
    end
    function ISPostDeathUI:render()
        return recovery.renderPostDeath(self)
    end
    function ISPostDeathUI:onRespawn()
        if recovery.pending and recovery.pending[self.playerIndex] and recovery.doReincarnate(self.playerIndex) then
            if ParadiseLimbo and ParadiseLimbo.report then ParadiseLimbo.report(1) end
            return
        end
        if ParadiseLimbo and ParadiseLimbo.report then ParadiseLimbo.report(2) end
        return recovery.onRespawnHook(self)
    end
    function ISPostDeathUI:onExit()
        ParadiseDev.Reincarnate.clearCreationState()
        recovery.resumeDeathAudio()
        if CoopCharacterCreation and CoopCharacterCreation.setVisibleAllUI then CoopCharacterCreation.setVisibleAllUI(true) end
        if ParadiseLimbo and ParadiseLimbo.report then ParadiseLimbo.report(3) end
        return recovery.onExitHook(self)
    end
    function ISPostDeathUI:onConfirmQuitToDesktop(button)
        if button and button.internal == "YES" then
            ParadiseDev.Reincarnate.clearCreationState()
            recovery.resumeDeathAudio()
            if CoopCharacterCreation and CoopCharacterCreation.setVisibleAllUI then CoopCharacterCreation.setVisibleAllUI(true) end
            if ParadiseLimbo and ParadiseLimbo.report then ParadiseLimbo.report(4) end
        end
        return recovery.onConfirmQuitToDesktopHook(self, button)
    end
    if recovery.coopAcceptHook then
        function CoopCharacterCreation:accept()
            recovery.showCreationTransition()
            local result = recovery.coopAcceptHook(self)
            if CoopCharacterCreation.instance then
                recovery.removeCreationTransition()
            else
                recovery.creationBlackout = false
            end
            return result
        end
    end
    if recovery.coopCancelHook then
        function CoopCharacterCreation:cancel()
            local result = recovery.coopCancelHook(self)
            ParadiseDev.Reincarnate.clearCreationState(self.playerIndex)
            return result
        end
    end
end

function recovery.onServerCommand(module, command, args)
    if module ~= recovery.module then return end
    if command == "recoveryPlan" then
        recovery.queueRecovery(getPlayer and getPlayer() or nil, args and args.skills or {}, args and args.lifeCount)
    elseif command == "recordsSync" then
        recovery.receiveRecords(args and args.records or {})
        recovery.showRecordHalo(getPlayer(), args and args.status, args and args.key)
    elseif command == "applyRecord" then
        recovery.applyRecordExact(getPlayer(), args and args.record)
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
