if isServer and isServer() then return end
require "Dev/ParadiseDev_Reincarnate"
require "Dev/ParadiseDev_LifeAmbitions"
require "Dev/ParadiseDev_LifeAmbitionsClient"
require "Dev/ParadiseDev_LifeStartingOutfit"
require "Dev/ParadiseDev_LifeCreationClient"
require "ISUI/ISPostDeathUI"
require "OptionScreens/MapSpawnSelect"
require "ISUI/ISUI3DModel"
require "ISUI/ISScrollingListBox"
require "ISUI/ISPanel"
require "ISUI/ISModalDialog"
require "TimedActions/ISTimedActionQueue"

ParadiseDev.LifeProfilesClient = ParadiseDev.LifeProfilesClient or {}
local C = ParadiseDev.LifeProfilesClient
local R = ParadiseDev.Reincarnate
C.module = "ParadiseLifeProfiles"
C.states = C.states or {}
C.sequence = C.sequence or 0
C.textures = C.textures or {}

-- Install at client-module load, before first-join character creation. Vanilla
-- skips the picker for one location; show the configured Bunker row without
-- replacing the native screen or changing fixed/safehouse/challenge policies.
if not MapSpawnSelect.lifeProfilesNativeHasChoices then
    MapSpawnSelect.lifeProfilesNativeHasChoices=MapSpawnSelect.hasChoices
    function MapSpawnSelect:hasChoices()
        if self.lifeProfilesNativeHasChoices(self) then return true end
        if not isClient() or not R.isShouldReincarnate() or not MainScreen.instance
                or MainScreen.instance.inGame or getCore():isChallenge() then return false end
        if self:getSafehouseSpawnRegion() or self:getFixedSpawnRegion() then return false end
        local regions=self:getSpawnRegions()
        return type(regions)=="table" and #regions==1
    end
end

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
    C.sequence=C.sequence+1
    s.listBody=pl;s.listObservation="body:"..tostring(now())..":"..tostring(C.sequence)
    C.send(pl, "list", {observationId=s.listObservation})
end

local function sameAmbitions(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a)do if not sameAmbitions(v,b[k])then return false end end
    for k in pairs(b)do if a[k]==nil then return false end end
    return true
end

function C.captureAmbitions(pl,final)
    if not pl or (isDead(pl) and not final) then return nil end
    local s=state(pl:getPlayerNum())
    local key=pl:getModData().ParadiseLifeProfileCharacterKey
    if type(key)~="string" or #key==0 or #key>256 or s.transaction then return nil end
    if s.ambitionBody~=pl or s.ambitionKey~=key then
        s.ambitionBody,s.ambitionKey=pl,key
        s.ambitionSeq,s.ambitionPending,s.ambitionAck=0,nil,nil
    end
    if not final and s.ambitionPending then return s.ambitionPending end
    local A=ParadiseDev.LifeAmbitions
    local payload=A and A.capture(pl)
    if not payload or (not final and sameAmbitions(payload,s.ambitionAck)) then return nil end
    s.ambitionSeq=(s.ambitionSeq or 0)+1
    local args={characterKey=key,seq=s.ambitionSeq,payload=payload}
    s.ambitionPending=args
    return args
end

function C.sampleAmbitions(pl)
    if not pl or isDead(pl) or not R.isShouldReincarnate() then return end
    local s=state(pl:getPlayerNum())
    if s.transaction or s.ambitionBootstrapBody~=pl or s.ambitionReady~=pl:getModData().ParadiseLifeProfileCharacterKey
            or not s.ambitionReady or now()-(s.lastAmbitionSend or 0)<10000 then return end
    s.lastAmbitionSend=now()
    C.reconcileCarry(pl)
    local args=C.captureAmbitions(pl,false)
    if args then C.send(pl,"ambitions",args) end
end

local function slotAt(s, number)
    for _, profile in ipairs(s.profiles and s.profiles.slots or {}) do
        if tonumber(profile.slot) == tonumber(number) then return profile end
    end
    return { slot = number, phase = "empty" }
end

function C.canDelete(panel)
    local s=state(panel.playerIndex)
    local profiles=s.profiles
    local profile=slotAt(s,s.selected)
    return panel.lifeProfilesUI and ISPostDeathUI.instance[panel.playerIndex]==panel
        and panel:isVisible() and isDead(localPlayer(panel.playerIndex))
        and profiles and profiles.canSelect==true and type(profiles.deathToken)=="string"
        and not profiles.pending and not s.transaction and not s.inflight and not s.cancelRequest
        and not s.deleteModal and not s.deleteRequest and not panel.quitToDesktopDialog
        and profile.id~=nil and profile.phase=="dead" and type(profile.revision)=="number"
        and type(profiles.revision)=="number"
end

function C.closeDeleteModal(index)
    local s=state(index)
    if s.deleteModal then s.deleteModal:destroy();s.deleteModal=nil end
end

function C.retryDelete(index)
    local s=state(index)
    local request=s.deleteRequest
    if not request or request.body~=localPlayer(index) or not isDead(request.body)
            or ISPostDeathUI.instance[index]~=request.panel then return end
    request.sentAt=now()
    if s.inflight then s.inflight.sentAt=request.sentAt end
    if not request.acknowledged then C.send(request.body,"deleteProfile",request.args) end
    C.requestList(request.body)
end

function C.reconcileDelete(index)
    local s=state(index)
    local request=s.deleteRequest
    local revision=tonumber(s.profiles and s.profiles.revision)
    if not request then return true end
    local current=slotAt(s,request.args.slot)
    local advanced=revision and revision>request.args.revision
    local confirmed=request.acknowledged and revision and revision>=request.acknowledged
        and current.id~=request.args.profileId
    local changed=advanced and (current.id~=nil or s.profiles.pending)
    if confirmed or changed then
        s.deleteRequest=nil;s.inflight=nil
        s.selected=request.args.slot
        s.deleteRevision=math.max(s.deleteRevision or 0,revision)
        s.message=confirmed and not current.id and "Profile deleted. This slot can start a new character."
            or "Your profiles changed. Review the selected profile before continuing."
        C.refreshStatus(index)
        return true
    end
    -- A newer list can reflect the first durable write while redundant recovery
    -- storage is still pending. Only the explicit receipt confirms completion.
    s.message=request.acknowledged and "Profile deleted. Refreshing profiles..."
        or request.failure or "Waiting for deletion confirmation..."
    C.refreshStatus(index)
    return false
end

function C.confirmDelete(panel,button,confirmation)
    if not button or button.internal~="YES" then return end
    local s=state(panel.playerIndex)
    local profile=slotAt(s,s.selected)
    local args=confirmation.args
    -- The dialog approves this exact saved profile, never a refreshed slot or
    -- a different life that arrived while the confirmation was open.
    if not C.canDelete(panel) or confirmation.body~=localPlayer(panel.playerIndex)
            or s.selected~=args.slot or profile.id~=args.profileId or profile.revision~=args.profileRevision
            or s.profiles.revision~=args.revision or s.profiles.deathToken~=args.deathToken then
        s.message="This profile changed. Review it and try again."
        C.requestList(localPlayer(panel.playerIndex))
        return
    end
    C.sequence=C.sequence+1
    args.requestId="delete:"..tostring(now())..":"..panel.playerIndex..":"..C.sequence
    s.deleteRequest={args=args,body=confirmation.body,panel=panel,sentAt=now(),startedAt=now()}
    s.inflight={command="deleteProfile",requestId=args.requestId,sentAt=now()}
    s.message="Deleting profile..."
    C.send(confirmation.body,"deleteProfile",args)
end

function C.deleteProfile(panel)
    if not C.canDelete(panel) then return end
    local index=panel.playerIndex
    local s=state(index)
    local profile=slotAt(s,s.selected)
    local confirmation={body=localPlayer(index),args={slot=s.selected,profileId=profile.id,
        profileRevision=profile.revision,revision=s.profiles.revision,deathToken=s.profiles.deathToken}}
    local text="Are you sure? This will permanently delete this profile."
    local width,height=ISModalDialog.CalcSize(560,150,text)
    local modal=ISModalDialog:new(getPlayerScreenLeft(index)+(getPlayerScreenWidth(index)-width)/2,
        getPlayerScreenTop(index)+(getPlayerScreenHeight(index)-height)/2,width,height,text,true,panel,C.confirmDelete,index,confirmation)
    modal.profileName="Profile "..s.selected..": "..tostring(profile.name or "Saved character")
    local destroy=modal.destroy
    function modal:destroy()
        if state(index).deleteModal==self then state(index).deleteModal=nil end
        destroy(self)
    end
    function modal:render()
        local name=C.screenLines(self.profileName,UIFont.Small,self.width-32,1)[1] or ""
        self:drawTextCentre(name,self.width/2,50,0.85,0.85,0.85,1,UIFont.Small)
    end
    modal:initialise();modal:setAlwaysOnTop(true);modal:addToUIManager();modal:bringToTop()
    s.deleteModal=modal
    if JoypadState.players[index+1] then
        modal.prevFocus=JoypadState.players[index+1].focus
        setJoypadFocus(index,modal)
    end
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

function C.descriptor(identity,previewOnly,startingOutfit)
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
    -- Every new life starts in fresh copies of its creation clothing. Later
    -- death equipment stays with the corpse, including in profile previews.
    local dressed,err=ParadiseDev.LifeStartingOutfit.dressDescriptor(desc,startingOutfit)
    if not dressed then error(err or "The starting outfit is unavailable.") end
    return desc
end

function C.resumeSelection(index)
    local s=state(index)
    local pending=s.transaction
    if not pending or pending.completionReplay or not isDead(localPlayer(index))
            or s.handled[pending.transactionId] or s.cancelRequest then return end
    -- Summaries may describe a reservation, but only a fresh acceptance carries
    -- the current server-approved destinations. Never open from cached data.
    s.inflight={command="resume",requestId=pending.requestId,transactionId=pending.transactionId,
        slot=pending.profile and pending.profile.slot,sentAt=now()}
    s.message="Refreshing your profile and spawn locations..."
    C.send(localPlayer(index),"resume",{transactionId=pending.transactionId,requestId=pending.requestId})
end

function C.select(panel)
    local pl = localPlayer(panel.playerIndex)
    local s = state(panel.playerIndex)
    local profiles = s.profiles
    if not isDead(pl) or not profiles or s.inflight or s.deleteModal or s.deleteRequest then return end
    if s.transaction then
        C.resumeSelection(panel.playerIndex)
        return
    end
    if profiles.canSelect ~= true then return end
    C.sequence = C.sequence + 1
    local requestId = tostring(now()) .. ":" .. tostring(panel.playerIndex) .. ":" .. tostring(C.sequence)
    s.inflight = { command="select",requestId = requestId, slot = s.selected, sentAt = now() }
    s.message = "Confirming your selection..."
    C.send(pl, "select", { slot = s.selected, revision = profiles.revision,
        deathToken = profiles.deathToken, requestId = requestId })
end

function C.cancel(index)
    local s = state(index)
    local transaction = s.transaction
    if s.cancelRequest and not transaction then return end
    -- The native create paths remove the death panel before sending a body
    -- request. While that panel remains, cancellation can safely make a lost
    -- cancel acknowledgement recoverable from the same durable reservation.
    if transaction and (not isDead(localPlayer(index)) or not ISPostDeathUI.instance[index]
            or s.completed[transaction.transactionId]) then return end
    if transaction then
        s.handled[transaction.transactionId]=nil
        s.cancelRequest={transaction=transaction,revision=transaction.revision or s.transactionRevision,
            sentAt=now()}
        C.send(localPlayer(index), "cancel", { transactionId = transaction.transactionId })
    end
    if s.spawnCreation and CoopCharacterCreation.instance==s.spawnCreation then C.native.coopCancel(s.spawnCreation) end
    s.spawnCreation,s.spawnRequest=nil,nil
    s.transaction,s.transactionRevision,s.spawnUnavailable=nil,nil,nil
    s.inflight=transaction and {command="cancel",requestId=transaction.transactionId,sentAt=now()} or nil
    s.message = transaction and "Cancelling your selection..." or "Selection cancelled."
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

function C.applyCarryFloor(pl,value)
    if type(value)=="number" and value==math.floor(value) and value>=1 and value<=2147483647
            and pl:getMaxWeightBase()<value then pl:setMaxWeightBase(value) end
end

-- Callers first validate their response's observation/transaction/sequence.
-- This cache is deliberately not loaded from locally editable ambition data.
function C.acceptCarry(pl,value,key,revision)
    if not pl or isDead(pl) or localPlayer(pl:getPlayerNum())~=pl
            or type(key)~="string" or #key<1 or #key>256 or key~=pl:getModData().ParadiseLifeProfileCharacterKey
            or type(revision)~="number" or revision~=math.floor(revision) or revision<0 or revision>9007199254740000
            or type(value)~="number" or value~=math.floor(value) or value<1 or value>2147483647 then return false end
    local s=state(pl:getPlayerNum())
    local previous=s.carry
    if previous and previous.body==pl and previous.key==key then
        if revision<previous.revision or (revision==previous.revision and value~=previous.target) then return false end
    end
    s.carry={body=pl,key=key,revision=revision,target=value}
    C.reconcileCarry(pl)
    return true
end

function C.reconcileCarry(pl)
    if not pl or isDead(pl) or localPlayer(pl:getPlayerNum())~=pl then return end
    local s=state(pl:getPlayerNum())
    local receipt=s.carry
    if not receipt or receipt.body~=pl or receipt.key~=pl:getModData().ParadiseLifeProfileCharacterKey then return end
    C.applyCarryFloor(pl,receipt.target)
    local ambitions=pl:getModData().Ambitions
    local wanderer=ambitions and ambitions.LSWanderer
    if type(wanderer)=="table" and wanderer.completed then wanderer.newWeight=receipt.target end
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
    if type(args.physical)=="table" and type(args.physical.weight)=="number"
            and args.physical.weight==args.physical.weight and args.physical.weight>=35 and args.physical.weight<math.huge then
        pl:getNutrition():setWeight(args.physical.weight)
    end
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
    C.acceptCarry(pl,args.carryWeight,args.characterKey,args.revision)
    local A=ParadiseDev.LifeAmbitionsClient
    if A and A.onRestored then A.onRestored(pl) end
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
    local A=ParadiseDev.LifeAmbitionsClient
    if A and A.onXPReady then A.onXPReady(pl) end
    -- The restoration mirror already supplied this body's authoritative
    -- Ambitions. A later list response must not roll back post-release progress.
    s.ambitionBootstrapBody=pl
    if s.waitPanel then s.waitPanel:removeFromUIManager();s.waitPanel=nil end
    s.completed[restored.transactionId]=true
    C.releaseControls(index)
    s.transaction=nil;s.inflight=nil;s.restored=nil;s.message="Profile restored."
    C.resumeAudio()
    C.send(pl,"observed",{transactionId=restored.transactionId})
    C.requestList(pl)
    return true
end

function C.spawnSaved(panel, accepted, prepared)
    if isClient() and not prepared then
        local gate=ParadiseDev.LifeCreationClient
        local index=panel.playerIndex
        local s=state(index)
        panel:setVisible(false)
        return gate.begin(gate.hints(accepted),function(result)
            if ISPostDeathUI.instance[index]~=panel or not isDead(localPlayer(index)) then return end
            accepted.spawn=result.creationLocation;accepted.spawnRegion=result.spawnRegion
            return C.spawnSaved(panel,accepted,true)
        end,function()
            s.handled[accepted.transactionId]=nil
            s.message="Preparation cancelled. Choose Resume profile or Change profile."
            if ISPostDeathUI.instance[index]==panel then panel:setVisible(true)end
        end)
    end
    local pl = localPlayer(panel.playerIndex)
    local profile = accepted.profile or {}
    local desc = C.descriptor(profile.identity,false,profile.startingOutfit)
    -- Only the server's accepted destination may create a profile body.
    -- Death coordinates and client-side legacy respawn rules are never fallbacks.
    local spawn = accepted.spawn
    if not C.validSpawn(spawn) then error("The server did not supply a valid spawn location. Your saved profile is unchanged.") end
    local x,y,z=spawn.x,spawn.y,spawn.z
    setSpawnRegion(accepted.spawnRegion)
    getWorld():setLuaPosX(x); getWorld():setLuaPosY(y); getWorld():setLuaPosZ(z or 0)
    getWorld():setLuaPlayerDesc(desc)
    getWorld():getLuaTraits():clear()
    for _, id in ipairs(profile.identity and profile.identity.traits or {}) do
        local key=string.lower(tostring(id))
        if not C.isManagedTrait(id) or profile.creationRetry and (key=="paradisedev:pve" or key=="pve") then
            getWorld():addLuaTrait(C.traitType(id))
        end
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

function C.validSpawn(spawn)
    if type(spawn)~="table" then return false end
    for _,key in ipairs({"x","y","z"}) do
        local value=spawn[key]
        if type(value)~="number" or value~=value or math.abs(value)>2147483647 then return false end
    end
    return spawn.z==math.floor(spawn.z) and spawn.z>=-32 and spawn.z<=31
end

function C.spawnOption(accepted,id)
    for _,option in ipairs(accepted.spawnOptions and accepted.spawnOptions.options or {}) do
        if type(option)=="table" and option.id==id then return option end
    end
end

function C.chooseSpawn(index,id)
    local s=state(index)
    local accepted=s.transaction
    if not accepted or not isDead(localPlayer(index)) or s.handled[accepted.transactionId] then return false end
    if not C.spawnOption(accepted,id) then return false end
    if s.spawnRequest and s.spawnRequest.spawnId~=id then return false end
    s.spawnRequest={transactionId=accepted.transactionId,spawnId=id,sentAt=now()}
    s.message="Confirming your spawn location..."
    C.send(localPlayer(index),"chooseSpawn",{transactionId=accepted.transactionId,spawnId=id})
    return true
end

local function spawnRegions(accepted)
    local regions={}
    local native=getServerSpawnRegions() or {}
    local options=accepted.spawnOptions and accepted.spawnOptions.options
    if type(options)~="table" or #options<1 or #options>128 then
        return nil,accepted.spawnError or "No approved spawn locations are available. Change profile to cancel this selection, then try again."
    end
    local seen={}
    for _,option in ipairs(options) do
        if type(option)~="table" or type(option.id)~="string" or #option.id<1 or #option.id>256 or seen[option.id] then
            return nil,"The server returned an invalid spawn list."
        end
        seen[option.id]=true
        local points
        if C.validSpawn(option.location) then
            points={unemployed={{posX=option.location.x,posY=option.location.y,posZ=option.location.z}}}
        elseif type(option.regionName)=="string" then
            for _,region in ipairs(native) do
                if region.name==option.regionName then points=region.points;break end
            end
        end
        if type(points)~="table" then return nil,"The selected spawn list is unavailable. Reconnect to refresh the server's locations." end
        regions[#regions+1]={name=option.name or option.regionName or "Spawn location",points=points,
            lifeSpawnId=option.id,lifeRegionName=option.regionName or option.name,
            lifeDescription=type(option.description)=="string" and option.description:sub(1,512) or nil,
            lifeWarning=type(accepted.spawnOptions.warning)=="string" and accepted.spawnOptions.warning:sub(1,1024) or nil}
    end
    return regions
end

function C.spawnRegions(accepted)
    -- Preserve the pre-entry login helper's existing exception contract.
    -- The death menu uses the non-throwing validator for normal unavailable data.
    local regions,err=spawnRegions(accepted)
    if not regions then error(err) end
    return regions
end

function C.openSpawnPicker(index,accepted,show)
    local regions,err=spawnRegions(accepted)
    if not regions then return nil,err end
    local s=state(index)
    local creation=CoopCharacterCreation.instance
    if creation and creation.lifeProfileTransaction~=accepted.transactionId then return nil,"Another character creation screen is already open." end
    if not creation then
        C.native.onRespawn(ISPostDeathUI.instance[index])
        creation=CoopCharacterCreation.instance
    end
    if not creation or not creation.mapSpawnSelect then return nil,"The native spawn selection screen could not open. Try again." end
    creation.lifeProfileTransaction=accepted.transactionId
    creation.background=true;creation.backgroundColor={r=0,g=0,b=0,a=1}
    s.spawnCreation=creation
    local picker=creation.mapSpawnSelect
    picker.getSpawnRegions=function()return regions end
    -- Reuse the native region rows, map preview and controller navigation, but
    -- do not append Coop's body/other-player destinations or an unapproved row.
    picker.fillList=function(self)
        MapSpawnSelect.fillList(self)
        for _,row in ipairs(self.listbox.items or {}) do
            local item=row.item;local region=item and item.region
            if region then
                local extra=region.lifeDescription or ""
                if region.lifeWarning then extra=extra.." <LINE> Unavailable locations: "..region.lifeWarning end
                if extra~="" then item.desc=(item.desc or "").." <LINE> "..extra end
            end
        end
    end
    picker.hasChoices=function()return true end
    picker.clickBack=function()creation:cancel()end
    picker.clickNext=function(self)
        local item=self.listbox.items[self.listbox.selected]
        local region=item and item.item and item.item.region
        if region and not s.spawnRequest then C.chooseSpawn(index,region.lifeSpawnId) end
        self:setVisible(true,creation.joypadData)
    end
    if not picker.lifeNativePrerender then picker.lifeNativePrerender=picker.prerender end
    picker.prerender=function(self)
        self.lifeNativePrerender(self)
        self.nextButton:setEnable(not s.spawnRequest and #self.listbox.items>0)
        self.nextButton:setTitle(s.spawnRequest and "Confirming..." or getText("UI_btn_next"))
        self.nextButton.tooltip=s.message or (accepted.spawnOptions and accepted.spawnOptions.warning)
    end
    -- A chosen location is immutable within one durable restoration. Going
    -- back from professions cancels that reservation instead of silently
    -- switching the selected location after the server has accepted it.
    local profession=creation.charCreationProfession
    if not profession.lifeNativeOption then profession.lifeNativeOption=profession.onOptionMouseDown end
    profession.onOptionMouseDown=function(self,button,x,y)
        if button.internal=="BACK" then creation:cancel();return end
        return self.lifeNativeOption(self,button,x,y)
    end
    profession.backButton.onclick=profession.onOptionMouseDown
    creation.coopUserName:setVisible(false)
    creation.charCreationMain:setVisible(false)
    profession:setVisible(false)
    picker:fillList()
    picker.listbox.selected=1
    picker:setVisible(show==true,creation.joypadData)
    return creation,regions
end

function C.accept(index, accepted)
    local s=state(index)
    if not accepted.transactionId or accepted.completionReplay or s.cancelRequest or s.deleteModal or s.deleteRequest
            or s.handled[accepted.transactionId] then return end
    if tonumber(accepted.revision) and tonumber(s.profiles and s.profiles.revision)
            and accepted.revision<s.profiles.revision then return end
    if s.transaction and s.transaction.transactionId==accepted.transactionId and not s.inflight then return end
    if not s.inflight or accepted.requestId~=s.inflight.requestId then return end
    if not isDead(localPlayer(index)) or not ISPostDeathUI.instance[index] then return end
    if accepted.kind~="create" and accepted.kind~="restore" then return end
    s.transaction=accepted;s.transactionRevision=accepted.revision or s.transactionRevision
    s.inflight=nil;s.spawnRequest=nil;s.spawnUnavailable=nil
    s.message="Choose where to begin this life."
    local ok,result,err=pcall(function()
        local options=accepted.spawnOptions and accepted.spawnOptions.options
        if type(options)~="table" or #options==0 then
            return nil,accepted.spawnError or "No approved spawn locations are available. Change profile to cancel this selection, then try again."
        end
        if accepted.spawnId then
            if not C.chooseSpawn(index,accepted.spawnId) then return nil,"Spawn destinations changed. Use Change profile to choose again." end
        elseif accepted.spawnOptions.forced then
            if #options~=1 or not C.chooseSpawn(index,options[1].id) then return nil,"The forced spawn location is unavailable." end
        else return C.openSpawnPicker(index,accepted,true) end
        return true
    end)
    if not ok or not result then
        s.spawnUnavailable=tostring(ok and err or result)
        s.message=s.spawnUnavailable
    end
end

function C.acceptSpawn(index,accepted)
    local s=state(index)
    local pending=s.transaction
    local request=s.spawnRequest
    if not pending or not request or accepted.transactionId~=pending.transactionId then return end
    if accepted.requestId~=pending.requestId or accepted.spawnId~=request.spawnId or accepted.kind~=pending.kind then return end
    if s.handled[accepted.transactionId] or not isDead(localPlayer(index)) then return end
    if not C.validSpawn(accepted.spawn) or type(accepted.spawnRegion)~="string" then return end
    local panel=ISPostDeathUI.instance[index]
    if not panel then return end
    -- Preserve the server reservation and original options for replay/UI. Never
    -- use a coordinate supplied by a local selection or old character snapshot.
    pending.spawn=accepted.spawn;pending.spawnRegion=accepted.spawnRegion;pending.spawnId=accepted.spawnId
    s.handled[pending.transactionId]=true;s.spawnRequest=nil
    s.message="Preparing your character..."
    local ok,result,err=pcall(function()
        if pending.kind=="restore" then
            local creation=s.spawnCreation
            if creation then
                C.native.coopCancel(creation)
                s.spawnCreation=nil
            end
            C.spawnSaved(panel,pending)
        else
            local creation,regions=C.openSpawnPicker(index,pending,false)
            if not creation then return nil,regions end
            local region
            for _,candidate in ipairs(regions) do if candidate.lifeSpawnId==pending.spawnId then region=candidate;break end end
            if not region then return nil,"The accepted spawn location is unavailable." end
            creation.mapSpawnSelect.selectedRegion=region
            setSpawnRegion(pending.spawnRegion)
            getWorld():setLuaPosX(pending.spawn.x);getWorld():setLuaPosY(pending.spawn.y);getWorld():setLuaPosZ(pending.spawn.z)
            report(2)
            creation.charCreationProfession:setVisible(true,creation.joypadData)
        end
        return true
    end)
    if not ok or not result then C.cancel(index);s.message=tostring(ok and err or result) end
end

function C.profileLines(profile,profiles)
    if not profile.id then
        if profiles and profiles.legacyEnrollment==true then
            return { "Start your first saved profile",
                "Your previous character died before a profile was created.",
                "Create a new character in this slot to start your first saved profile.",
                "Your previous character's progress cannot be restored.",
                "Items remain with the previous character's corpse." }
        end
        local hasSavedProfile=false
        for _,slot in pairs(profiles and profiles.slots or {})do
            if slot.id then hasSavedProfile=true;break end
        end
        return { "Empty profile", "Create a new character in this slot.",
            hasSavedProfile and "Your other profiles remain saved." or "You do not have any saved profiles yet.",
            "Items remain with each character's corpse." }
    end
    local identity = profile.identity or {}
    local hours = tonumber(profile.hoursSurvived) or 0
    local traits={}
    for _,id in ipairs(identity.traits or {}) do
        local key=string.lower(tostring(id))
        if key~="paradisedev:pve" and key~="pve" then traits[#traits+1]=C.displayDefinition(id,false) end
    end
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
        "PvE: " .. (profile.pveConflict and "Needs administrator review" or profile.pve==true and "Enabled for this profile" or "Disabled for this profile"),
        "Traits: " .. table.concat(traits, ", "),
        "Spawn choices follow this profile's permissions and the current zones.",
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
    for _, line in ipairs(C.profileLines(profile,s.profiles)) do
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
        local ok, desc = pcall(C.descriptor, profile.identity,true,profile.startingOutfit)
        if ok then panel.profileModel:setSurvivorDesc(desc)
        else panel.profileModel:setVisible(false); panel.previewError = tostring(desc) end
    end
    panel.detailsRevision = tostring(s.profiles and s.profiles.revision) .. ":" .. tostring(s.selected)
end

function C.chooseSlot(panel, button)
    local s = state(panel.playerIndex)
    if s.inflight or s.transaction or s.deleteModal or s.deleteRequest then return end
    s.selected = button.profileSlot
    C.refreshDetails(panel)
end

function C.changePage(panel, button)
    local s = state(panel.playerIndex)
    if s.inflight or s.transaction or s.deleteModal or s.deleteRequest then return end
    s.page = math.max(1, math.min(panel.profilePageCount or 1, (s.page or 1) + button.pageDelta))
    s.selected = (s.page - 1) * 6 + 1
    C.layout(panel)
    C.refreshDetails(panel)
end

function C.refreshButton(panel)
    local s = state(panel.playerIndex)
    if s.deleteModal then return end
    if s.deleteRequest then C.retryDelete(panel.playerIndex);return end
    -- Reuse an in-flight request identifier; the server treats retries once.
    if s.inflight and s.profiles then
        s.inflight.sentAt = now()
        if s.inflight.command=="cancel" and s.cancelRequest then
            s.cancelRequest.sentAt=now()
            C.send(localPlayer(panel.playerIndex),"cancel",{transactionId=s.cancelRequest.transaction.transactionId})
            C.requestList(localPlayer(panel.playerIndex))
        elseif s.inflight.command=="resume" then C.resumeSelection(panel.playerIndex)
        else C.send(localPlayer(panel.playerIndex), "select", { slot = s.inflight.slot,
                revision = s.profiles.revision, deathToken = s.profiles.deathToken, requestId = s.inflight.requestId }) end
    elseif s.transaction and isDead(localPlayer(panel.playerIndex)) and s.transaction.canCancel==true then
        C.cancel(panel.playerIndex)
    elseif s.transaction and not isDead(localPlayer(panel.playerIndex)) then
        C.send(localPlayer(panel.playerIndex), "ready", {transactionId=s.transaction.transactionId})
    else C.requestList(localPlayer(panel.playerIndex)) end
end

-- A bounded text block keeps the original centered death presentation readable.
function C.screenLines(text, font, width, limit)
    local lines, row = {}, ""
    local tm = getTextManager()
    local function shorten(value)
        -- Kahlua strings use Java characters. Trim whole words, never split a glyph.
        return value:match("^(.*)%s+%S+$") or ""
    end
    for word in string.gmatch(tostring(text or ""), "%S+") do
        local combined = row == "" and word or row .. " " .. word
        if row ~= "" and tm:MeasureStringX(font, combined) > width then
            lines[#lines+1] = row; row = word
        else row = combined end
    end
    if row ~= "" then lines[#lines+1] = row end
    for i, line in ipairs(lines) do
        local clipped = false
        while #line > 0 and tm:MeasureStringX(font, line) > width do
            line = shorten(line); clipped = true
        end
        if clipped or (i == limit and #lines > limit) then
            while #line > 0 and tm:MeasureStringX(font, line .. "...") > width do line=shorten(line) end
            line=line .. "..."
        end
        lines[i]=line
    end
    while #lines > limit do table.remove(lines) end
    return lines
end

function C.layout(panel)
    local w, h = panel.screenWidth, panel.screenHeight
    panel:setX(panel.screenX); panel:setY(panel.screenY); panel:setWidth(w); panel:setHeight(h)
    local smallH=getTextManager():getFontHeight(UIFont.Small)
    local scale=math.max(1,smallH/16)
    local margin=math.max(12,math.min(28,math.floor(math.min(w,h)*0.026)))
    local gap=math.max(6,math.floor(margin/2))
    local buttonHeight=math.max(28,smallH+12)
    local contentW=math.min(w-margin*2,1100*scale)
    local contentX=math.floor((w-contentW)/2)
    local s=state(panel.playerIndex)
    local profile=slotAt(s,s.selected)
    local maxSlots=math.max(1,math.min(32,tonumber(s.profiles and s.profiles.maxSlots) or 3))
    panel.profilePageCount=math.ceil(maxSlots/6)
    s.page=math.max(1,math.min(panel.profilePageCount,s.page or math.ceil(s.selected/6)))
    local shown=math.min(6,maxSlots)
    local columns=math.min(w<560 and 2 or 3,shown)
    local rows=math.ceil(shown/columns)
    local slotWidth=math.floor((contentW-gap*(columns-1))/columns)
    local gridH=rows*buttonHeight+(rows-1)*gap
    local pageH=panel.profilePageCount>1 and buttonHeight+gap or 0
    local actionY=h-margin-buttonHeight*2-gap
    local statusH=(smallH+2)*2+gap
    local contentBottom=actionY-statusH-gap
    local freeH=contentBottom-margin-(smallH+gap)-gridH-pageH-gap*2
    local wantedDetails=profile.id and math.min(260*scale,h*0.25) or smallH*2+gap*2
    local detailsH=math.max(30,math.min(wantedDetails,freeH-(h<500 and 60 or 170*scale)))
    local detailY=contentBottom-detailsH
    local slotY=detailY-gap-gridH-pageH
    panel.profileHeadingY=slotY-smallH-gap
    panel.profileContentX,panel.profileContentWidth=contentX,contentW
    for i=1,maxSlots do
        if not panel.slotButtons[i] then
            local button=ISButton:new(0,0,100,buttonHeight,"",panel,C.chooseSlot)
            panel:configButton(button);panel:addChild(button)
            button.profileSlot=i;panel.slotButtons[i]=button
        end
        local b=panel.slotButtons[i]
        local index=(i-1)%6
        b:setX(contentX+(index%columns)*(slotWidth+gap))
        b:setY(slotY+math.floor(index/columns)*(buttonHeight+gap))
        b:setWidth(slotWidth);b:setHeight(buttonHeight)
    end
    local pageWidth=math.min(160*scale,math.floor((contentW-gap)/2))
    for i,b in ipairs({panel.profilePrevious,panel.profileNext}) do
        b:setX(contentX+(i==1 and 0 or contentW-pageWidth));b:setY(slotY+gridH+gap)
        b:setWidth(pageWidth);b:setHeight(buttonHeight)
    end
    local modelW=math.min(220*scale,math.floor(contentW*0.24))
    panel.profileModel:setX(contentX);panel.profileModel:setY(detailY)
    panel.profileModel:setWidth(modelW);panel.profileModel:setHeight(detailsH)
    panel.profileDetails:setX(contentX+modelW+gap);panel.profileDetails:setY(detailY)
    panel.profileDetails:setWidth(contentW-modelW-gap);panel.profileDetails:setHeight(detailsH)
    local actionW=math.floor((contentW-gap*2)/3)
    local primaryW=math.min(260*scale,actionW)
    local refreshW=math.min(160*scale,actionW)
    local deleteW=math.min(160*scale,actionW)
    local primaryX=math.floor((w-primaryW-refreshW-deleteW-gap*2)/2)
    local secondaryW=math.min(220*scale,math.floor((contentW-gap)/2))
    local secondaryX=math.floor((w-secondaryW*2-gap)/2)
    for i,b in ipairs({panel.buttonRespawn,panel.profileRefresh,panel.buttonExit,panel.buttonQuit}) do
        b:setHeight(buttonHeight)
        b:setY(i<3 and actionY or actionY+buttonHeight+gap)
        if i<3 then
            b:setX(primaryX+(i==1 and 0 or primaryW+gap));b:setWidth(i==1 and primaryW or refreshW)
        else b:setX(secondaryX+(i-3)*(secondaryW+gap));b:setWidth(secondaryW) end
    end
    panel.profileDelete:setX(primaryX+primaryW+refreshW+gap*2);panel.profileDelete:setY(actionY)
    panel.profileDelete:setWidth(deleteW);panel.profileDelete:setHeight(buttonHeight)
    panel.profileStatusY=actionY-statusH
    -- Restore the original animation, phrase and survival lines as the focal point.
    local heroH=math.max(16,panel.profileHeadingY-gap-margin)
    panel.deathTitleFont=h<500 and UIFont.Small or UIFont.Large
    local titleH=getTextManager():getFontHeight(panel.deathTitleFont)
    -- Very short split-screen viewports prioritize the phrase and usable controls.
    panel.showProfileHeading=heroH>=titleH+gap+16
    local phraseLimit=2
    if not panel.showProfileHeading then
        heroH=math.max(0,slotY-gap-margin)
        phraseLimit=1
    end
    local key=w..":"..h..":"..smallH..":"..phraseLimit..":"..tostring(panel.deathMessage)
    if panel.deathTextKey~=key then
        panel.deathTextKey=key
        panel.deathPhraseLines=C.screenLines(panel.deathMessage,panel.deathTitleFont,contentW,phraseLimit)
        panel.emptyProfileLines=C.screenLines("Create a new character in this profile. Your other lives remain saved.",UIFont.Small,contentW,2)
    end
    panel.deathStatsLines={}
    if h>=600 then
        for i,line in ipairs(panel.lines or {}) do
            if i>3 then break end
            panel.deathStatsLines[#panel.deathStatsLines+1]=C.screenLines(line,UIFont.Small,contentW,1)[1] or ""
        end
    end
    local phraseH=#panel.deathPhraseLines*(titleH+2)
    local statsH=#panel.deathStatsLines*(smallH+2)
    local artSize=math.floor(math.max(0,math.min(360*scale,contentW*0.42,heroH-phraseH-statsH-gap*2)))
    if artSize<16 then artSize=0 end
    local artGap=artSize>0 and gap or 0
    local blockH=artSize+phraseH+statsH+artGap+(statsH>0 and gap or 0)
    local artY=margin+math.max(0,math.floor((heroH-blockH)/2))
    panel.deathArt={x=math.floor((w-artSize)/2),y=artY,size=artSize}
    panel.deathTitleY=artY+artSize+artGap
    panel.deathStatsY=panel.deathTitleY+phraseH+gap
    panel.emptyProfileY=detailY+math.max(0,math.floor((detailsH-#panel.emptyProfileLines*(smallH+2))/2))
    local layoutKey=w..":"..h..":"..smallH..":"..tostring(profile.id)..":"..maxSlots
    if panel.profileLayoutKey~=layoutKey then
        panel.profileLayoutKey=layoutKey
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
        self.profileDetails.background = false; self.profileDetails.borderColor.a = 0
        self:addChild(self.profileDetails)
        self.profileRefresh = ISButton:new(0,0,100,28,"Refresh",self,C.refreshButton)
        self:configButton(self.profileRefresh); self:addChild(self.profileRefresh)
        self.profileDelete = ISButton:new(0,0,100,28,"Delete profile",self,C.deleteProfile)
        self:configButton(self.profileDelete);self:addChild(self.profileDelete)
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
            local fullTitle="Profile " .. i .. ": " .. (p.id and (p.name or "Saved character") or "Empty")
            local labelKey=fullTitle..":"..b.width..":"..getTextManager():getFontHeight(UIFont.Small)
            if b.profileLabelKey~=labelKey then
                b.profileLabelKey=labelKey
                b:setTitle(C.screenLines(fullTitle,UIFont.Small,b.width-16,1)[1] or "")
                b.tooltip=fullTitle
            end
            b:setVisible(available and i<=maxSlots and math.ceil(i/6)==s.page)
            b:setEnable(not s.inflight and not s.transaction and not s.deleteModal and not s.deleteRequest)
            b.borderColor = s.selected==i and {r=0.4,g=0.8,b=0.65,a=1} or {r=0.4,g=0.4,b=0.4,a=0.5}
        end
        self.profilePrevious:setVisible(available and self.profilePageCount>1)
        self.profileNext:setVisible(available and self.profilePageCount>1)
        self.profilePrevious:setEnable(not s.inflight and not s.transaction and not s.deleteModal and not s.deleteRequest and s.page>1)
        self.profileNext:setEnable(not s.inflight and not s.transaction and not s.deleteModal and not s.deleteRequest and s.page<self.profilePageCount)
        local profile = slotAt(s,s.selected)
        local pending=s.transaction
        local resumable=pending and pending.kind and pending.profile and not s.handled[pending.transactionId]
        self.buttonRespawn:setTitle(resumable and "Resume profile" or (profile.id and "Reincarnate" or "Create character"))
        self.buttonRespawn:setEnable(not s.inflight and not s.deleteModal and not s.deleteRequest
            and (resumable or s.profiles and s.profiles.canSelect==true and not pending) or false)
        self.profileRefresh:setVisible(available)
        self.profileRefresh:setEnable(not s.deleteModal and (not s.transaction or isDead(localPlayer(self.playerIndex)))
            and (not s.inflight or s.deleteRequest and (s.deleteRequest.failure~=nil or now()-s.deleteRequest.startedAt>5000)
                or not s.deleteRequest and now()-s.inflight.sentAt>5000))
        self.profileRefresh:setTitle(s.deleteRequest and "Retry deletion" or s.cancelRequest and "Retry cancellation" or s.inflight and "Retry selection"
            or pending and pending.canCancel==true and "Change profile" or "Refresh")
        self.profileDelete:setVisible(available)
        self.profileDelete:setEnable(C.canDelete(self) or false)
        self.buttonExit:setEnable(not s.deleteModal)
        self.buttonQuit:setEnable(not s.deleteModal)
        self.profileDetails:setVisible(available and profile.id~=nil)
        self.profileControlsAvailable=available
        if self.detailsRevision ~= tostring(s.profiles and s.profiles.revision) .. ":" .. tostring(s.selected) then C.refreshDetails(self) end
        self.profileModel:setVisible(available and profile.id~=nil and not self.previewError)
    end
    function ISPostDeathUI:render()
        if not self.lifeProfilesUI then return C.native.render(self) end
        ISPanelJoypad.render(self)
        if self.quitToDesktopDialog and self.quitToDesktopDialog:isReallyVisible() then self:clearStencilRect(); return end
        local frame = math.floor(now()/30)%60+1
        C.textures[frame] = C.textures[frame] or getTexture("media/ui/Paradise/DeathAnim/DeathAnim_" .. string.format("%03d",frame) .. ".png")
        local art=self.deathArt
        if C.textures[frame] and art.size>0 then self:drawTextureScaled(C.textures[frame],art.x,art.y,art.size,art.size,1,1,1,1) end
        local titleH=getTextManager():getFontHeight(self.deathTitleFont)+2
        for i,line in ipairs(self.deathPhraseLines) do
            self:drawTextCentre(line,self.width/2,self.deathTitleY+(i-1)*titleH,1,1,1,1,self.deathTitleFont)
        end
        local lineH=getTextManager():getFontHeight(UIFont.Small)+2
        for i,line in ipairs(self.deathStatsLines) do
            self:drawTextCentre(line,self.width/2,self.deathStatsY+(i-1)*lineH,0.85,0.85,0.85,1,UIFont.Small)
        end
        if self.profileControlsAvailable then
            if self.showProfileHeading then
                self:drawTextCentre("Choose a life to continue",self.width/2,self.profileHeadingY,0.7,0.8,0.75,1,UIFont.Small)
            end
            local s=state(self.playerIndex)
            if not slotAt(s,s.selected).id then
                for i,line in ipairs(self.emptyProfileLines) do
                    self:drawTextCentre(line,self.width/2,self.emptyProfileY+(i-1)*lineH,0.8,0.8,0.8,1,UIFont.Small)
                end
            end
            local message=self.previewError or s.message or (s.profiles and "Profiles are saved automatically." or "Loading your profiles...")
            local statusKey=message..":"..self.profileContentWidth..":"..lineH
            if self.profileStatusText~=statusKey then
                self.profileStatusText=statusKey
                self.profileStatusLines=C.screenLines(message,UIFont.Small,self.profileContentWidth,2)
            end
            self.buttonRespawn.tooltip=message
            for i,line in ipairs(self.profileStatusLines) do
                self:drawTextCentre(line,self.width/2,self.profileStatusY+(i-1)*lineH,0.9,0.85,0.7,1,UIFont.Small)
            end
        end
        self:clearStencilRect()
    end
    function ISPostDeathUI:onRespawn()
        if not self.lifeProfilesUI then return C.native.onRespawn(self) end
        C.select(self)
    end
    function ISPostDeathUI:onExit()
        C.closeDeleteModal(self.playerIndex)
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
    C.closeDeleteModal(pl:getPlayerNum())
    s.deleteRequest,s.deleteRevision=nil,nil
    local finalAmbitions=C.captureAmbitions(pl,true)
    -- A body can die while the server is retrying a restoration. The same
    -- durable transaction must then be allowed to create its next body once.
    local transactionId = s.transaction and s.transaction.transactionId
    if transactionId and not s.completed[transactionId] then s.handled[transactionId] = nil end
    C.releaseControls(pl:getPlayerNum())
    if s.waitPanel then s.waitPanel:removeFromUIManager();s.waitPanel=nil end
    s.restored=nil
    s.spawnCreation,s.spawnRequest=nil,nil
    s.profiles,s.transaction,s.transactionRevision,s.inflight,s.cancelRequest,s.spawnUnavailable=nil,nil,nil,nil,nil,nil
    s.message = "Saving your final character state..."
    if not C.audioPaused then C.audioPaused=true; pauseSoundAndMusic() end
    report(0)
    s.finalAmbition=finalAmbitions and {body=pl,args=finalAmbitions,startedAt=now(),sentAt=now()} or nil
    C.send(pl,"death",{ambitions=finalAmbitions})
    C.requestList(pl)
end

function C.onCreate(index,pl)
    if not pl or not pl:isLocalPlayer() or not R.isShouldReincarnate() then return end
    local s = state(index)
    C.closeDeleteModal(index)
    if s.deleteRequest then s.deleteRequest=nil;s.inflight=nil end
    s.deleteRevision=nil
    s.finalAmbition=nil
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
        if s.deleteRevision and (not tonumber(args.revision) or args.revision<s.deleteRevision) then return end
        local reservedRevision=tonumber(s.transactionRevision or s.cancelRequest and s.cancelRequest.revision)
        if reservedRevision and tonumber(args.revision) and args.revision<reservedRevision then return end
        s.profiles=args
        if args.deathToken then s.finalAmbition=nil end
        local pl=localPlayer(index)
        local deletion=s.deleteRequest
        if deletion then
            if not C.reconcileDelete(index) then return end
        end
        if pl and not isDead(pl) and type(args.characterKey)=="string" and #args.characterKey<=256
                and args.observationId and args.observationId==s.listObservation and s.listBody==pl then
            -- The server binds a newly created client body that has not yet
            -- received its profile marker through native persistence.
            pl:getModData().ParadiseLifeProfileCharacterKey=args.characterKey
            if not s.transaction then C.acceptCarry(pl,args.ambitionCarryWeight,args.characterKey,args.revision) end
            if not s.transaction and s.ambitionBootstrapBody~=pl then
                local A=ParadiseDev.LifeAmbitions
                local accepted=A and args.ambitionBootstrap and A.validate({version=1,ambitions=args.ambitionBootstrap})
                if accepted then
                    -- Empty first-birth data must not erase the client's normal
                    -- Lifestyle initialization. Existing progress is copied as
                    -- saved, without a new-life rebase or reward replay.
                    local nonempty=false;for _ in pairs(accepted.ambitions)do nonempty=true;break end
                    if nonempty then pl:getModData().Ambitions=accepted.ambitions end
                    local hooks=ParadiseDev.LifeAmbitionsClient
                    if hooks and hooks.install then hooks.install()end
                    if LSAmbtMng then LSAmbtMng.LSCheckCustomAmbts=false end
                end
                s.ambitionBootstrapBody=pl
            end
        end
        if pl and args.characterKey==pl:getModData().ParadiseLifeProfileCharacterKey
                and type(args.ambitionSeq)=="number" then
            if s.ambitionBody~=pl or s.ambitionKey~=args.characterKey then
                s.ambitionBody,s.ambitionKey=pl,args.characterKey
                s.ambitionSeq,s.ambitionPending,s.ambitionAck=0,nil,nil
            end
            s.ambitionSeq=math.max(s.ambitionSeq or 0,args.ambitionSeq)
            s.ambitionReady=args.characterKey
            if s.ambitionPending and s.ambitionPending.seq<=args.ambitionSeq then
                if s.ambitionPending.seq==args.ambitionSeq then s.ambitionAck=s.ambitionPending.payload end
                s.ambitionPending=nil
            end
        end
        s.selected=math.min(tonumber(args.maxSlots) or 3,math.max(1,s.selected))
        s.message=deletion and s.message or args.enrollmentRequired and (args.enrollmentMessage or "Start a new profile after your first death. Existing progress is not recovered.")
            or (args.canSelect and "Select a saved profile or an empty slot." or "Profiles can be selected after death.")
        C.refreshStatus(index)
        local pending=args.pending
        if pending and pending.completionReplay and isDead(pl) then pending=nil end
        local revision=tonumber(args.revision)
        local cancel=s.cancelRequest
        if cancel then
            local oldRevision=tonumber(cancel.revision)
            if revision and oldRevision and revision>oldRevision
                    and (not pending or pending.transactionId~=cancel.transaction.transactionId) then
                -- Acknowledged cancellation, not a local button click, unlocks
                -- selection. Delayed pre-cancel summaries cannot relock it.
                s.cancelRequest=nil;s.inflight=nil
            else
                s.message="Cancelling your selection..."
                return
            end
        end
        if pending and pending.transactionId and not s.completed[pending.transactionId] then
            local previous=s.transaction
            local same=previous and previous.transactionId==pending.transactionId
            s.transaction=pending
            s.transactionRevision=tonumber(pending.revision) or revision
            if same and previous.spawnOptions and not pending.spawnOptions then
                -- Summary data may be sparse; it still must never open a picker.
                s.transaction.spawnOptions=previous.spawnOptions
            end
            if s.inflight and s.inflight.command=="resume" and pending.requestId~=s.inflight.requestId then
                -- The requested reservation was replaced; the authoritative
                -- current one is available to resume without a stale Retry lock.
                s.inflight=nil
            end
            if isDead(pl) and s.inflight and pending.requestId==s.inflight.requestId
                    and s.inflight.command~="resume" then
                C.resumeSelection(index)
            elseif not isDead(pl) then C.showRestoring(index);s.lastReady=now(); C.send(pl,"ready",{transactionId=pending.transactionId}) end
            if s.spawnUnavailable then s.message=s.spawnUnavailable end
        elseif isDead(pl) and ISPostDeathUI and ISPostDeathUI.instance and ISPostDeathUI.instance[index] then
            local transaction=s.transaction
            local oldRevision=tonumber(s.transactionRevision or transaction and transaction.revision)
            if transaction and not s.handled[transaction.transactionId] and revision and oldRevision and revision>=oldRevision then
                if s.spawnCreation and CoopCharacterCreation.instance==s.spawnCreation then C.native.coopCancel(s.spawnCreation) end
                s.transaction,s.transactionRevision,s.spawnCreation,s.spawnRequest,s.spawnUnavailable=nil,nil,nil,nil,nil
                if s.inflight and s.inflight.command=="resume" then s.inflight=nil end
            end
        end
    elseif command=="profileDeleted" then
        local deletion=s.deleteRequest
        if not deletion or args.requestId~=deletion.args.requestId or args.slot~=deletion.args.slot
                or args.profileId~=deletion.args.profileId or type(args.revision)~="number"
                or args.revision<=deletion.args.revision or localPlayer(index)~=deletion.body or not isDead(deletion.body) then return end
        deletion.acknowledged=args.revision
        s.deleteRevision=math.max(s.deleteRevision or 0,args.revision)
        C.reconcileDelete(index)
        C.requestList(deletion.body)
    elseif command=="ambitionsSaved" then
        local pending=s.ambitionPending
        local pl=localPlayer(index)
        if pl and s.ambitionBody==pl and s.ambitionKey==args.characterKey
                and pl:getModData().ParadiseLifeProfileCharacterKey==args.characterKey
                and pending and pending.characterKey==args.characterKey and pending.seq==args.seq then
            if not s.transaction then C.acceptCarry(pl,args.carryWeight,args.characterKey,args.revision) end
            s.ambitionAck=pending.payload;s.ambitionPending=nil
            s.finalAmbition=nil
        end
    elseif command=="selectionAccepted" then C.accept(index,args)
    elseif command=="spawnAccepted" then C.acceptSpawn(index,args)
    elseif command=="restored" then
        if not s.transaction or s.transaction.transactionId~=args.transactionId then return end
        local pl=localPlayer(index)
        if not pl or isDead(pl) then return end
        C.mirrorRestored(pl,args)
        s.restored=args
        C.showRestoring(index)
        C.checkNativeXP(index)
    elseif command=="error" then
        if s.deleteRequest then
            if args.requestId~=s.deleteRequest.args.requestId or s.deleteRequest.acknowledged then return end
            if args.retryableDeletion==true then
                s.deleteRequest.failure=tostring(args.message or "Deletion is awaiting server confirmation. Use Retry deletion.")
                s.message=s.deleteRequest.failure
                C.requestList(localPlayer(index))
                return
            end
            s.deleteRequest=nil;s.inflight=nil
            s.message=tostring(args.message or "Profile deletion failed. Refresh and try again.")
            C.requestList(localPlayer(index))
            return
        end
        if args.requestId then
            local matches=(s.inflight and args.requestId==s.inflight.requestId)
                or (s.transaction and (args.requestId==s.transaction.transactionId or args.requestId==s.transaction.requestId))
            if not matches then return end
        end
        if s.cancelRequest then
            s.transaction=s.cancelRequest.transaction;s.transactionRevision=s.cancelRequest.revision
            s.cancelRequest=nil
        end
        s.spawnRequest=nil
        s.inflight=nil
        s.message=tostring(args.message or "Profile operation failed. Refresh and try again.")
    end
end

function C.onTick()
    for index,s in pairs(C.states) do
        local pl=localPlayer(index)
        C.sampleAmbitions(pl)
        if s.deleteRequest then
            if pl~=s.deleteRequest.body or not isDead(pl) or ISPostDeathUI.instance[index]~=s.deleteRequest.panel then
                s.deleteRequest=nil
                if s.inflight and s.inflight.command=="deleteProfile" then s.inflight=nil end
            elseif now()-s.deleteRequest.sentAt>2000 then C.retryDelete(index) end
        end
        local final=s.finalAmbition
        if final then
            if pl~=final.body or not isDead(pl) or now()-final.startedAt>5000 then s.finalAmbition=nil
            elseif now()-final.sentAt>=300 then
                final.sentAt=now();C.send(pl,"death",{ambitions=final.args})
            end
        end
        if isDead(pl) and s.cancelRequest and now()-s.cancelRequest.sentAt>2000 then
            s.cancelRequest.sentAt=now()
            if s.inflight then s.inflight.sentAt=now() end
            C.send(pl,"cancel",{transactionId=s.cancelRequest.transaction.transactionId})
            C.requestList(pl)
        end
        if s.transaction then C.holdControls(index) end
        if isDead(pl) and s.spawnRequest and now()-s.spawnRequest.sentAt>2000 then
            C.chooseSpawn(index,s.spawnRequest.spawnId)
        end
        if s.restored then C.checkNativeXP(index) end
        if pl and not isDead(pl) and s.transaction and now()-(s.lastReady or 0)>2000 then
            s.lastReady=now()
            C.send(pl,"ready",{transactionId=s.transaction.transactionId})
        elseif isDead(pl) and (not s.profiles or not s.profiles.deathToken and not s.transaction)
                and not s.cancelRequest and now()-(s.lastList or 0)>3000 then C.requestList(pl) end
    end
end

Events.OnGameStart.Add(C.install)
Events.OnCreatePlayer.Add(C.onCreate)
Events.OnPlayerDeath.Add(C.onDeath)
Events.OnServerCommand.Add(C.onServerCommand)
Events.OnTick.Add(C.onTick)
