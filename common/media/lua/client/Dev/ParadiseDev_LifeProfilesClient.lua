if isServer and isServer() then return end
require "Dev/ParadiseDev_Reincarnate"
require "ISUI/ISPostDeathUI"
require "ISUI/ISUI3DModel"
require "ISUI/ISScrollingListBox"
require "ISUI/ISPanel"
require "TimedActions/ISTimedActionQueue"

ParadiseDev.LifeProfilesClient = ParadiseDev.LifeProfilesClient or {}
local C = ParadiseDev.LifeProfilesClient
local R = ParadiseDev.Reincarnate
C.module = "ParadiseLifeProfiles"
C.states = C.states or {}
C.sequence = C.sequence or 0
C.textures = C.textures or {}

local function now() return getTimestampMs and getTimestampMs() or getTimestamp() * 1000 end
local function report(code) if ParadiseLimbo and ParadiseLimbo.report then ParadiseLimbo.report(code) end end
local function state(index)
    C.states[index] = C.states[index] or { selected = 1, handled = {}, completed = {} }
    return C.states[index]
end
local function localPlayer(index) return getSpecificPlayer(index or 0) end
local function isDead(pl) return pl and pl.isDead and pl:isDead() end

function C.send(pl, command, args)
    if not pl then return false end
    args=args or {}
    args.playerIndex=pl:getPlayerNum()
    if command=="ready" or command=="list" then
        local key=pl:getModData().ParadiseLifeProfileCharacterKey
        if type(key)=="string" and #key<=256 then args.characterKey=key end
    end
    if isClient and isClient() then
        sendClientCommand(pl, C.module, command, args)
    elseif ParadiseDev.LifeProfilesServer and ParadiseDev.LifeProfilesServer.onClientCommand then
        ParadiseDev.LifeProfilesServer.onClientCommand(C.module, command, pl, args)
    else
        return false
    end
    return true
end

function C.requestList(pl)
    pl = pl or localPlayer(0)
    if not pl then return end
    local s = state(pl:getPlayerNum())
    s.lastList = now()
    C.send(pl, "list", {})
end

local function slotAt(s, number)
    for _, profile in ipairs(s.profiles and s.profiles.slots or {}) do
        if tonumber(profile.slot) == tonumber(number) then return profile end
    end
    return { slot = number, phase = "empty" }
end

function C.professionType(name)
    name=string.lower(tostring(name))
    local definitions = CharacterProfessionDefinition.getProfessions()
    local bare, count=nil,0
    for i = 0, definitions:size() - 1 do
        local definition = definitions:get(i)
        local kind = definition:getType()
        if string.lower(tostring(kind)) == name then return kind end
        if not name:find(":",1,true) and string.lower(tostring(kind:getName())) == name then bare=kind;count=count+1 end
    end
    return count==1 and bare or nil
end

function C.traitType(name)
    name=string.lower(tostring(name))
    local definitions = CharacterTraitDefinition.getTraits()
    local bare,count=nil,0
    for i = 0, definitions:size() - 1 do
        local kind = definitions:get(i):getType()
        if string.lower(tostring(kind)) == name then return kind end
        if not name:find(":",1,true) and string.lower(tostring(kind:getName())) == name then bare=kind;count=count+1 end
    end
    return count==1 and bare or nil
end

function C.isManagedTrait(id)
    local name=string.lower(tostring(id))
    if not name:find(":",1,true) then
        local kind=C.traitType(name)
        if not kind then return false end
        name=string.lower(tostring(kind))
    end
    return name=="paradisedev:caged" or name=="paradisedev:therangestaff" or name=="paradisedev:pve" or name=="paradisedev:injuredpvp"
end

function C.displayDefinition(name,profession)
    local definitions=profession and CharacterProfessionDefinition.getProfessions() or CharacterTraitDefinition.getTraits()
    local kind=profession and C.professionType(name) or C.traitType(name)
    if kind then
        for i=0,definitions:size()-1 do
            local definition=definitions:get(i)
            if definition:getType()==kind and definition.getLabel then return definition:getLabel() end
        end
    end
    return tostring(name or "Unknown")
end

function C.applyVisual(visual, saved)
    if not visual or type(saved) ~= "table" then return end
    for _, entry in ipairs({ {"hairModel","setHairModel"}, {"beardModel","setBeardModel"},
        {"skinTextureIndex","setSkinTextureIndex"}, {"bodyHairIndex","setBodyHairIndex"} }) do
        if saved[entry[1]] ~= nil then visual[entry[2]](visual, saved[entry[1]]) end
    end
    for _, entry in ipairs({ {"hairColor","setHairColor"}, {"beardColor","setBeardColor"},
        {"naturalHairColor","setNaturalHairColor"}, {"naturalBeardColor","setNaturalBeardColor"},
        {"skinColor","setSkinColor"} }) do
        local color = saved[entry[1]]
        if type(color) == "table" then
            visual[entry[2]](visual, ImmutableColor.new(color.r or color[1], color.g or color[2], color.b or color[3], 1))
        end
    end
    if type(saved.bodyVisuals)=="table" then
        visual:getBodyVisuals():clear()
        for _, itemType in ipairs(saved.bodyVisuals) do visual:addBodyVisualFromItemType(itemType) end
    end
end

function C.descriptor(identity,previewOnly)
    identity = identity or {}
    local desc = SurvivorFactory.CreateSurvivor()
    if identity.forename then desc:setForename(identity.forename) end
    if identity.surname then desc:setSurname(identity.surname) end
    if identity.female ~= nil then desc:setFemale(identity.female == true) end
    local profession = C.professionType(identity.profession)
    if not profession then error("The saved profession is not available. Ask an administrator to review this profile.") end
    desc:setCharacterProfession(profession)
    if identity.voiceType ~= nil then desc:setVoiceType(identity.voiceType) end
    if identity.voicePitch ~= nil then desc:setVoicePitch(identity.voicePitch) end
    desc:setVoicePrefix(identity.female and "VoiceFemale" or "VoiceMale")
    desc:getHumanVisual():clear()
    C.applyVisual(desc:getHumanVisual(), identity.visual)
    -- B42 SurvivorDesc has no trait list. Traits are supplied separately to
    -- the native world creation flow; validate saved types before spawning.
    for _, id in ipairs(identity.traits or {}) do
        if not C.isManagedTrait(id) then
            local kind = C.traitType(id)
            if not kind then error("A saved trait is not available: " .. tostring(id)) end
        end
    end
    -- Worn visuals are temporary preview objects, never restored inventory.
    if previewOnly and ItemVisual and ItemVisual.createLastStandItem then
        for _,saved in ipairs(identity.visual and identity.visual.clothingVisuals or {})do
            local item=ItemVisual.createLastStandItem(saved)
            if item and item:getBodyLocation() then desc:getWornItems():setItem(item:getBodyLocation(),item) end
        end
    end
    return desc
end

function C.select(panel)
    local pl = localPlayer(panel.playerIndex)
    local s = state(panel.playerIndex)
    local profiles = s.profiles
    if not isDead(pl) or not profiles or s.inflight then return end
    if s.transaction then
        local pending = s.transaction
        if pending.kind and pending.profile and not s.handled[pending.transactionId] then
            s.inflight = {requestId=pending.requestId,slot=pending.profile.slot,sentAt=now()}
            C.accept(panel.playerIndex,pending)
        end
        return
    end
    if profiles.canSelect ~= true then return end
    C.sequence = C.sequence + 1
    local requestId = tostring(now()) .. ":" .. tostring(panel.playerIndex) .. ":" .. tostring(C.sequence)
    s.inflight = { requestId = requestId, slot = s.selected, sentAt = now() }
    s.message = "Confirming your selection..."
    C.send(pl, "select", { slot = s.selected, revision = profiles.revision,
        deathToken = profiles.deathToken, requestId = requestId })
end

function C.cancel(index)
    local s = state(index)
    local transaction = s.transaction
    if transaction then C.send(localPlayer(index), "cancel", { transactionId = transaction.transactionId }) end
    s.transaction, s.inflight = nil, nil
    s.message = "Selection cancelled."
    C.requestList(localPlayer(index))
end

function C.resumeAudio()
    if C.audioPaused then C.audioPaused = false; resumeSoundAndMusic() end
end

function C.releaseControls(index)
    local s=state(index)
    local lease=s.controlLease
    if not lease then return end
    s.controlLease=nil
    -- Restore only flags acquired by this restoration, on its original body.
    -- A movement/attack lock that already existed belongs to another system.
    if lease.movement and lease.player:isBlockMovement() then lease.player:setBlockMovement(false) end
    if lease.attacking and lease.player:isBannedAttacking() then lease.player:setBannedAttacking(false) end
end

function C.holdControls(index)
    local s=state(index)
    local pl=localPlayer(index)
    if not s.transaction or not pl or isDead(pl) then return end
    if s.controlLease and s.controlLease.player~=pl then C.releaseControls(index) end
    if not s.controlLease then
        s.controlLease={player=pl,movement=not pl:isBlockMovement(),attacking=not pl:isBannedAttacking()}
        if ISTimedActionQueue then ISTimedActionQueue.clear(pl) end
    end
    pl:setBlockMovement(true)
    pl:setBannedAttacking(true)
end

function C.showRestoring(index)
    local s=state(index)
    C.holdControls(index)
    if s.waitPanel then return end
    local w,h=getPlayerScreenWidth(index),getPlayerScreenHeight(index)
    local panel=ISPanel:new(getPlayerScreenLeft(index)+(w-420)/2,getPlayerScreenTop(index)+h-100,420,62)
    panel:initialise()
    panel.backgroundColor={r=0,g=0,b=0,a=0.95}
    panel.borderColor={r=0.4,g=0.8,b=0.65,a=0.8}
    function panel:render()
        self:drawTextCentre("Restoring profile...",self.width/2,8,1,1,1,1,UIFont.Medium or UIFont.Small)
        self:drawTextCentre("Waiting for the server's saved skills.",self.width/2,33,0.8,0.8,0.8,1,UIFont.Small)
    end
    panel:setAlwaysOnTop(true);panel:addToUIManager();s.waitPanel=panel
end

function C.mirrorRestored(pl,args)
    local identity=args.identity or {}
    local desc=pl:getDescriptor()
    if identity.forename then desc:setForename(identity.forename) end
    if identity.surname then desc:setSurname(identity.surname) end
    local profession=C.professionType(identity.profession)
    if profession then desc:setCharacterProfession(profession) end
    if identity.female~=nil then pl:setFemale(identity.female==true);desc:setFemale(identity.female==true) end
    if identity.voiceType~=nil then desc:setVoiceType(identity.voiceType) end
    if identity.voicePitch~=nil then desc:setVoicePitch(identity.voicePitch) end
    if identity.visual then C.applyVisual(pl:getHumanVisual(),identity.visual);pl:resetModel() end
    if args.hoursSurvived~=nil then pl:setHoursSurvived(args.hoursSurvived) end
    if args.zombieKills~=nil then pl:setZombieKills(args.zombieKills) end
    if type(args.recipes)=="table" then
        local recipes=pl:getKnownRecipes();recipes:clear()
        for _,name in ipairs(args.recipes)do recipes:add(name)end
    end
    -- This command is server-originated and contains only its reviewed, bounded
    -- mod-data allowlist. Never publish a local mod-data/XP replacement packet.
    if type(args.modData)=="table" then
        local data=pl:getModData()
        for key,value in pairs(args.modData)do data[key]=value end
    end
    if type(args.characterKey)=="string" then pl:getModData().ParadiseLifeProfileCharacterKey=args.characterKey end
end

function C.checkNativeXP(index)
    local s=state(index)
    local restored=s.restored
    local pl=localPlayer(index)
    if not restored or not pl or isDead(pl) or type(restored.expectedSkills)~="table" then return false end
    local xp=pl:getXp()
    for name,value in pairs(restored.expectedSkills)do
        local perk=Perks.FromString(name)
        local tolerance=math.max(0.001,math.abs(value)*1.2e-7)
        if not perk or math.abs((tonumber(xp:getXP(perk)) or -1)-value)>tolerance then return false end
    end
    if s.waitPanel then s.waitPanel:removeFromUIManager();s.waitPanel=nil end
    s.completed[restored.transactionId]=true
    C.releaseControls(index)
    s.transaction=nil;s.inflight=nil;s.restored=nil;s.message="Profile restored."
    C.resumeAudio()
    C.send(pl,"observed",{transactionId=restored.transactionId})
    C.requestList(pl)
    return true
end

function C.spawnSaved(panel, accepted)
    local pl = localPlayer(panel.playerIndex)
    local profile = accepted.profile or {}
    local desc = C.descriptor(profile.identity)
    -- Cage priority must survive profile changes. The server may supply its own
    -- approved location; otherwise retain the mod's established spawn resolver.
    local x, y, z = R.getCagedRespawnLoc(R.getUsername(pl))
    if not x and accepted.spawn then x, y, z = accepted.spawn.x, accepted.spawn.y, accepted.spawn.z end
    if not x then x, y, z = R.getRespawnLoc(R.getUsername(pl)) end
    if not x or not y then error("No valid respawn location is available. Your saved profile is unchanged.") end
    getWorld():setLuaPosX(x); getWorld():setLuaPosY(y); getWorld():setLuaPosZ(z or 0)
    getWorld():setLuaPlayerDesc(desc)
    getWorld():getLuaTraits():clear()
    for _, id in ipairs(profile.identity and profile.identity.traits or {}) do
        if not C.isManagedTrait(id) then getWorld():addLuaTrait(C.traitType(id)) end
    end
    setGameSpeed(1)
    panel:removeFromUIManager()
    ISPostDeathUI.instance[panel.playerIndex] = nil
    report(1)
    local joypad = JoypadState and JoypadState.players[panel.playerIndex + 1]
    if joypad then
        setPlayerJoypad(panel.playerIndex, joypad.id, nil, panel.playerIndex > 0 and R.getUsername(pl) or nil, true)
        joypad.focus = nil
        joypad.lastfocus = nil
    else
        setPlayerMouse(nil)
    end
end

function C.accept(index, accepted)
    local s = state(index)
    local pl = localPlayer(index)
    local panel = ISPostDeathUI.instance[index]
    if not accepted.transactionId or s.handled[accepted.transactionId] then return end
    if not s.inflight or accepted.requestId ~= s.inflight.requestId then return end
    if not isDead(pl) or not panel then return end
    if accepted.kind ~= "create" and accepted.kind ~= "restore" then return end
    s.handled[accepted.transactionId] = true
    s.transaction = accepted
    s.inflight = nil
    s.message = "Preparing your character..."
    local ok, err = pcall(function()
        if accepted.kind == "restore" then
            C.spawnSaved(panel, accepted)
        else
            report(2)
            C.native.onRespawn(panel)
            if CoopCharacterCreation.instance then
                CoopCharacterCreation.instance.background = true
                CoopCharacterCreation.instance.backgroundColor = {r=0,g=0,b=0,a=1}
            else
                error("Character creation could not open. Try selecting the empty slot again.")
            end
        end
    end)
    if not ok then
        C.cancel(index)
        s.message = tostring(err)
    end
end

function C.profileLines(profile)
    if not profile.id then
        return { "Empty profile", "Create a new character in this slot.",
            "Your other profiles remain saved.", "Items remain with each character's corpse." }
    end
    local identity = profile.identity or {}
    local hours = tonumber(profile.hoursSurvived) or 0
    local traits={}
    for _,id in ipairs(identity.traits or {})do traits[#traits+1]=C.displayDefinition(id,false)end
    local earnedTotal,lossTotal=0,0
    for id,value in pairs(profile.skills or {})do
        earnedTotal=earnedTotal+math.max(0,value-(tonumber(profile.creationXP and profile.creationXP[id]) or 0))
        lossTotal=lossTotal+(tonumber(profile.loss and profile.loss[id]) or 0)
    end
    local rows = {
        profile.name or ((identity.forename or "") .. " " .. (identity.surname or "")),
        "Profession: " .. C.displayDefinition(identity.profession,true),
        "Time alive: " .. tostring(math.floor(hours / 24)) .. " days, " .. tostring(math.floor(hours % 24)) .. " hours",
        "Zombies killed: " .. tostring(profile.zombieKills or 0),
        "Lives: " .. tostring(profile.incarnations or 1),
        "Saved state: " .. (profile.snapshotKind == "death" and "at death" or "latest checkpoint"),
        "Traits: " .. table.concat(traits, ", "),
        "Retained earned XP: " .. string.format("%.1f",earnedTotal) .. "  |  Reincarnation loss: " .. string.format("%.1f",lossTotal),
        "Items remain on the corpse; skills and identity continue.",
        "Skill XP: current  /  lost  /  after reincarnation",
    }
    local keys = {}
    for id in pairs(profile.skills or {}) do keys[#keys + 1] = id end
    table.sort(keys)
    for _, id in ipairs(keys) do
        local current = tonumber(profile.skills[id]) or 0
        local loss = tonumber(profile.loss and profile.loss[id]) or 0
        local after = tonumber(profile.postXP and profile.postXP[id]) or current
        rows[#rows + 1] = tostring(id) .. ": " .. string.format("%.1f / %.1f / %.1f", current, loss, after)
    end
    rows[#rows + 1] = "Creation XP is protected. Other retained XP loses 10% each reincarnation."
    return rows
end

function C.refreshStatus(index)
    local s=state(index)
    local panel=s.statusPanel
    if not panel then return end
    panel.lines:clear()
    local profiles=s.profiles
    local function add(text)panel.lines:addItem(text,{})end
    add("Life profiles are saved automatically. Switching is available only after death.")
    if not profiles then add("Loading your profiles...");return end
    if profiles.enrollmentRequired then
        add(profiles.enrollmentMessage or "Your first death starts enrollment into the new profile system.")
        add("Existing character progress is not recovered into a new profile.")
    end
    for i=1,profiles.maxSlots or 3 do
        local profile=slotAt(s,i)
        add("Profile "..i..": "..(profile.id and (profile.name or "Saved character") or "Empty"))
        if profile.id then
            add("  Time alive: "..string.format("%.1f",tonumber(profile.hoursSurvived) or 0).." hours; zombies: "..tostring(profile.zombieKills or 0))
        end
    end
end

function C.showStatus(pl)
    pl=pl or localPlayer(0)
    if not pl then return end
    local index=pl:getPlayerNum()
    local s=state(index)
    if s.statusPanel then s.statusPanel:removeFromUIManager() end
    local w=math.min(660,getPlayerScreenWidth(index)-32)
    local h=math.min(400,getPlayerScreenHeight(index)-32)
    local panel=ISPanelJoypad:new(getPlayerScreenLeft(index)+(getPlayerScreenWidth(index)-w)/2,
        getPlayerScreenTop(index)+(getPlayerScreenHeight(index)-h)/2,w,h)
    panel:initialise()
    panel.backgroundColor={r=.03,g=.03,b=.03,a=.98}
    panel.lines=ISScrollingListBox:new(12,12,w-24,h-62)
    panel.lines:initialise();panel.lines:instantiate();panel.lines:setFont(UIFont.Small,4)
    panel.lines.itemheight=getTextManager():getFontHeight(UIFont.Small)+8
    panel:addChild(panel.lines)
    local close=ISButton:new(w-112,h-40,100,28,"Close",panel,function(target)
        target:removeFromUIManager();s.statusPanel=nil
    end)
    close:initialise();panel:addChild(close)
    panel:setAlwaysOnTop(true);panel:addToUIManager();s.statusPanel=panel
    C.refreshStatus(index)
    C.requestList(pl)
end

function C.refreshDetails(panel)
    if not panel.profileDetails then return end
    local s = state(panel.playerIndex)
    local profile = slotAt(s, s.selected)
    panel.profileDetails:clear()
    local width = math.max(90, panel.profileDetails.width - 26)
    for _, line in ipairs(C.profileLines(profile)) do
        local row = ""
        for word in string.gmatch(line, "%S+") do
            local candidate = row == "" and word or row .. " " .. word
            if row ~= "" and getTextManager():MeasureStringX(UIFont.Small, candidate) > width then
                panel.profileDetails:addItem(row, {})
                row = word
            else row = candidate end
        end
        panel.profileDetails:addItem(row, {})
    end
    panel.profileModel:setVisible(profile.id ~= nil)
    panel.previewError = nil
    if profile.id then
        local ok, desc = pcall(C.descriptor, profile.identity,true)
        if ok then panel.profileModel:setSurvivorDesc(desc)
        else panel.profileModel:setVisible(false); panel.previewError = tostring(desc) end
    end
    panel.detailsRevision = tostring(s.profiles and s.profiles.revision) .. ":" .. tostring(s.selected)
end

function C.chooseSlot(panel, button)
    local s = state(panel.playerIndex)
    if s.inflight or s.transaction then return end
    s.selected = button.profileSlot
    C.refreshDetails(panel)
end

function C.changePage(panel, button)
    local s = state(panel.playerIndex)
    if s.inflight or s.transaction then return end
    s.page = math.max(1, math.min(panel.profilePageCount or 1, (s.page or 1) + button.pageDelta))
    s.selected = (s.page - 1) * 6 + 1
    C.layout(panel)
    C.refreshDetails(panel)
end

function C.refreshButton(panel)
    local s = state(panel.playerIndex)
    -- Reuse an in-flight request identifier; the server treats retries once.
    if s.inflight and s.profiles then
        s.inflight.sentAt = now()
        C.send(localPlayer(panel.playerIndex), "select", { slot = s.inflight.slot,
            revision = s.profiles.revision, deathToken = s.profiles.deathToken, requestId = s.inflight.requestId })
    elseif s.transaction and not isDead(localPlayer(panel.playerIndex)) then
        C.send(localPlayer(panel.playerIndex), "ready", {transactionId=s.transaction.transactionId})
    else C.requestList(localPlayer(panel.playerIndex)) end
end

function C.layout(panel)
    local w, h = panel.screenWidth, panel.screenHeight
    panel:setX(panel.screenX); panel:setY(panel.screenY); panel:setWidth(w); panel:setHeight(h)
    local margin = math.max(8, math.min(22, math.floor(w * 0.02)))
    local buttonHeight = math.max(28, getTextManager():getFontHeight(UIFont.Small) + 10)
    local s = state(panel.playerIndex)
    local maxSlots = math.max(1, math.min(32, tonumber(s.profiles and s.profiles.maxSlots) or 3))
    panel.profilePageCount = math.ceil(maxSlots / 6)
    s.page = math.max(1, math.min(panel.profilePageCount, s.page or math.ceil(s.selected / 6)))
    local shown = math.min(6, maxSlots)
    local columns = w < 680 and math.min(3,shown) or math.min(6,shown)
    local rows = math.ceil(shown / columns)
    local slotWidth = math.floor((w - margin * (columns + 1)) / columns)
    for i = 1, maxSlots do
        if not panel.slotButtons[i] then
            local button = ISButton:new(0,0,100,buttonHeight,"",panel,C.chooseSlot)
            panel:configButton(button); panel:addChild(button)
            button.profileSlot = i; panel.slotButtons[i] = button
        end
        local b = panel.slotButtons[i]
        local pageIndex = (i - 1) % 6
        b:setX(margin + (pageIndex % columns) * (slotWidth+margin))
        b:setY(90 + math.floor(pageIndex/columns) * (buttonHeight+6))
        b:setWidth(slotWidth); b:setHeight(buttonHeight)
    end
    local detailY = 90 + rows * (buttonHeight + 6) + margin
    local pageWidth = math.min(160, math.floor((w - margin * 3) / 2))
    for i,b in ipairs({panel.profilePrevious,panel.profileNext}) do
        b:setX(i==1 and margin or w-margin-pageWidth);b:setY(detailY)
        b:setWidth(pageWidth);b:setHeight(buttonHeight)
    end
    if panel.profilePageCount > 1 then detailY = detailY + buttonHeight + margin end
    local bottom = h - buttonHeight * 2 - margin * 3 - 24
    local detailH = math.max(30, bottom - detailY)
    local modelW = math.max(90,math.floor((w-margin*3)*0.27))
    panel.profileModel:setX(margin); panel.profileModel:setY(detailY)
    panel.profileModel:setWidth(modelW); panel.profileModel:setHeight(detailH)
    panel.profileDetails:setX(margin*2+modelW); panel.profileDetails:setY(detailY)
    panel.profileDetails:setWidth(w-margin*3-modelW); panel.profileDetails:setHeight(detailH)
    local actionW = math.floor((w - margin * 3) / 2)
    for i,b in ipairs({panel.buttonRespawn,panel.profileRefresh,panel.buttonExit,panel.buttonQuit}) do
        b:setX(margin + ((i-1)%2)*(actionW+margin)); b:setWidth(actionW); b:setHeight(buttonHeight)
        b:setY(h - margin - buttonHeight * (i < 3 and 2 or 1) - (i < 3 and margin or 0))
    end
    if panel.layoutWidth ~= w or panel.layoutHeight ~= h then
        panel.layoutWidth, panel.layoutHeight = w,h
        C.refreshDetails(panel)
    end
end

function C.install()
    if C.installed then return end
    C.installed = true
    C.native = { createChildren = ISPostDeathUI.createChildren, prerender = ISPostDeathUI.prerender,
        render = ISPostDeathUI.render, onRespawn = ISPostDeathUI.onRespawn,
        onExit = ISPostDeathUI.onExit, onConfirmQuitToDesktop = ISPostDeathUI.onConfirmQuitToDesktop,
        coopCancel = CoopCharacterCreation.cancel }
    function ISPostDeathUI:createChildren()
        C.native.createChildren(self)
        if not R.isShouldReincarnate() then return end
        self.lifeProfilesUI = true
        self.slotButtons = {}
        self.profileModel = ISUI3DModel:new(0,0,100,100)
        self:addChild(self.profileModel)
        self.profileModel:setState("idle"); self.profileModel:setDirection(IsoDirections.S)
        self.profileModel:setIsometric(false); self.profileModel:setDoRandomExtAnimations(true)
        self.profileModel:setAnimateWhilePaused(true); self.profileModel:setZoom(-3)
        self.profileDetails = ISScrollingListBox:new(0,0,100,100)
        self.profileDetails:initialise(); self.profileDetails:instantiate()
        self.profileDetails:setFont(UIFont.Small,4); self.profileDetails.itemheight = getTextManager():getFontHeight(UIFont.Small)+8
        self:addChild(self.profileDetails)
        self.profileRefresh = ISButton:new(0,0,100,28,"Refresh",self,C.refreshButton)
        self:configButton(self.profileRefresh); self:addChild(self.profileRefresh)
        self.profilePrevious = ISButton:new(0,0,100,28,"Previous profiles",self,C.changePage)
        self.profilePrevious.pageDelta = -1
        self:configButton(self.profilePrevious);self:addChild(self.profilePrevious)
        self.profileNext = ISButton:new(0,0,100,28,"Next profiles",self,C.changePage)
        self.profileNext.pageDelta = 1
        self:configButton(self.profileNext);self:addChild(self.profileNext)
        local messages = R.getDeathMessages()
        self.deathMessage = messages[ZombRand(#messages)+1]
        C.layout(self); C.refreshDetails(self)
        C.requestList(localPlayer(self.playerIndex))
    end
    function ISPostDeathUI:prerender()
        if not self.lifeProfilesUI then return C.native.prerender(self) end
        self:drawRect(0,0,self.screenWidth,self.screenHeight,1,0,0,0)
        C.native.prerender(self)
        C.layout(self)
        local s = state(self.playerIndex)
        local available = self.buttonRespawn:isVisible()
        local maxSlots = tonumber(s.profiles and s.profiles.maxSlots) or 3
        for i,b in ipairs(self.slotButtons) do
            local p = slotAt(s,i)
            b:setTitle("Profile " .. i .. ": " .. (p.id and (p.name or "Saved character") or "Empty"))
            b:setVisible(available and i<=maxSlots and math.ceil(i/6)==s.page)
            b:setEnable(not s.inflight and not s.transaction)
            b.borderColor = s.selected==i and {r=0.4,g=0.8,b=0.65,a=1} or {r=0.4,g=0.4,b=0.4,a=0.5}
        end
        self.profilePrevious:setVisible(available and self.profilePageCount>1)
        self.profileNext:setVisible(available and self.profilePageCount>1)
        self.profilePrevious:setEnable(not s.inflight and not s.transaction and s.page>1)
        self.profileNext:setEnable(not s.inflight and not s.transaction and s.page<self.profilePageCount)
        local profile = slotAt(s,s.selected)
        local pending=s.transaction
        local resumable=pending and pending.kind and pending.profile and not s.handled[pending.transactionId]
        self.buttonRespawn:setTitle(resumable and "Resume selected profile" or (profile.id and "Reincarnate as selected profile" or "Create character in selected slot"))
        self.buttonRespawn:setEnable(not s.inflight and (resumable or s.profiles and s.profiles.canSelect==true and not pending) or false)
        self.profileRefresh:setVisible(available)
        self.profileRefresh:setEnable(not s.transaction and (not s.inflight or now()-s.inflight.sentAt>5000))
        self.profileRefresh:setTitle(s.inflight and "Retry selection" or "Refresh")
        self.profileDetails:setVisible(available)
        if self.detailsRevision ~= tostring(s.profiles and s.profiles.revision) .. ":" .. tostring(s.selected) then C.refreshDetails(self) end
        self.profileModel:setVisible(available and profile.id~=nil and not self.previewError)
    end
    function ISPostDeathUI:render()
        if not self.lifeProfilesUI then return C.native.render(self) end
        ISPanelJoypad.render(self)
        if self.quitToDesktopDialog and self.quitToDesktopDialog:isReallyVisible() then self:clearStencilRect(); return end
        self:drawRect(0,0,self.width,88,1,0,0,0)
        local frame = math.floor(now()/30)%60+1
        C.textures[frame] = C.textures[frame] or getTexture("media/ui/Paradise/DeathAnim/DeathAnim_" .. string.format("%03d",frame) .. ".png")
        if C.textures[frame] then self:drawTextureScaled(C.textures[frame],14,8,64,64,1,1,1,1) end
        self:drawText(self.deathMessage,90,14,1,1,1,1,UIFont.Large)
        self:drawText("Choose a life to continue",90,46,0.65,0.85,0.75,1,UIFont.Small)
        local s = state(self.playerIndex)
        local message = self.previewError or s.message or (s.profiles and "Profiles are saved automatically." or "Loading your profiles...")
        self:drawText(message,16,self.buttonRespawn.y-24,0.9,0.85,0.7,1,UIFont.Small)
        self:clearStencilRect()
    end
    function ISPostDeathUI:onRespawn()
        if not self.lifeProfilesUI then return C.native.onRespawn(self) end
        C.select(self)
    end
    function ISPostDeathUI:onExit()
        C.releaseControls(self.playerIndex)
        C.resumeAudio(); report(3)
        return C.native.onExit(self)
    end
    function ISPostDeathUI:onConfirmQuitToDesktop(button)
        if button and button.internal=="YES" then C.releaseControls(self.playerIndex);C.resumeAudio(); report(4) end
        return C.native.onConfirmQuitToDesktop(self,button)
    end
    function CoopCharacterCreation:cancel()
        local index = self.playerIndex
        local result = C.native.coopCancel(self)
        if state(index).transaction then C.cancel(index) end
        return result
    end
end

function C.onDeath(pl)
    if not pl or not pl:isLocalPlayer() or not R.isShouldReincarnate() then return end
    local s = state(pl:getPlayerNum())
    -- A body can die while the server is retrying a restoration. The same
    -- durable transaction must then be allowed to create its next body once.
    local transactionId = s.transaction and s.transaction.transactionId
    if transactionId and not s.completed[transactionId] then s.handled[transactionId] = nil end
    C.releaseControls(pl:getPlayerNum())
    if s.waitPanel then s.waitPanel:removeFromUIManager();s.waitPanel=nil end
    s.restored=nil
    s.profiles, s.transaction, s.inflight = nil,nil,nil
    s.message = "Saving your final character state..."
    if not C.audioPaused then C.audioPaused=true; pauseSoundAndMusic() end
    report(0)
    C.send(pl,"death",{})
    C.requestList(pl)
end

function C.onCreate(index,pl)
    if not pl or not pl:isLocalPlayer() or not R.isShouldReincarnate() then return end
    local s = state(index)
    C.resumeAudio()
    if s.transaction then C.showRestoring(index);s.lastReady=now(); C.send(pl,"ready",{transactionId=s.transaction.transactionId}) end
    C.requestList(pl)
end

function C.onServerCommand(module,command,args)
    if module~=C.module or type(args)~="table" then return end
    local index = tonumber(args.playerIndex) or 0
    local s = state(index)
    if command=="profiles" then
        if s.profiles and tonumber(args.revision) and tonumber(s.profiles.revision) and args.revision<s.profiles.revision then return end
        s.profiles=args
        s.selected=math.min(tonumber(args.maxSlots) or 3,math.max(1,s.selected))
        s.message=args.enrollmentRequired and (args.enrollmentMessage or "Start a new profile after your first death. Existing progress is not recovered.")
            or (args.canSelect and "Select a saved profile or an empty slot." or "Profiles can be selected after death.")
        C.refreshStatus(index)
        if args.pending and args.pending.transactionId and not s.completed[args.pending.transactionId] then
            s.transaction=args.pending
            if not isDead(localPlayer(index)) then C.showRestoring(index);s.lastReady=now(); C.send(localPlayer(index),"ready",{transactionId=args.pending.transactionId}) end
        end
    elseif command=="selectionAccepted" then C.accept(index,args)
    elseif command=="restored" then
        if not s.transaction or s.transaction.transactionId~=args.transactionId then return end
        local pl=localPlayer(index)
        if not pl or isDead(pl) then return end
        C.mirrorRestored(pl,args)
        s.restored=args
        C.showRestoring(index)
        C.checkNativeXP(index)
    elseif command=="error" then
        if args.requestId and s.inflight and args.requestId~=s.inflight.requestId then return end
        s.inflight=nil
        s.message=tostring(args.message or "Profile operation failed. Refresh and try again.")
    end
end

function C.onTick()
    for index,s in pairs(C.states) do
        local pl=localPlayer(index)
        if s.transaction then C.holdControls(index) end
        if s.restored then C.checkNativeXP(index) end
        if pl and not isDead(pl) and s.transaction and now()-(s.lastReady or 0)>2000 then
            s.lastReady=now()
            C.send(pl,"ready",{transactionId=s.transaction.transactionId})
        elseif isDead(pl) and not s.profiles and now()-(s.lastList or 0)>3000 then C.requestList(pl) end
    end
end

Events.OnGameStart.Add(C.install)
Events.OnCreatePlayer.Add(C.onCreate)
Events.OnPlayerDeath.Add(C.onDeath)
Events.OnServerCommand.Add(C.onServerCommand)
Events.OnTick.Add(C.onTick)
