-- B42 server adapter. Profile decisions and disk transactions live in the controller.
if isClient and isClient() then return end
require "Dev/ParadiseDev_LifeProfiles"
ParadiseDev.LifeProfileNative = ParadiseDev.LifeProfileNative or {}
local N = ParadiseDev.LifeProfileNative
local M = ParadiseDev.LifeProfiles
N.applying = setmetatable({}, {__mode="k"})
N.MAX_PERSISTENT_BYTES = 131072
-- Native ResourceLocation IDs are lowercase; saved assignment keys retain
-- their existing spelling in TraitSyncer's account store.
local managed = { ["paradisedev:caged"]="ParadiseDev:Caged", ["paradisedev:therangestaff"]="ParadiseDev:TheRangeStaff",
    ["paradisedev:pve"]="ParadiseDev:PvE", ["paradisedev:injuredpvp"]="ParadiseDev:InjuredPvP" }

local function finite(value) return type(value)=="number" and value==value and value>-math.huge and value<math.huge end
local function number(value, label)
    if not finite(value) then error("Invalid " .. label) end
    return value
end
local function boundedCopy(value)
    local copied, err = M.copy(value)
    if copied == nil and value ~= nil then error(err) end
    return copied
end
local function checked(fn, ...)
    local ok, value, detail = pcall(fn, ...)
    if not ok then return nil, tostring(value) end
    return value, detail
end
local function typeId(kind) return string.lower(tostring(kind)) end
local function eachPerk(fn)
    for index=1, Perks.getMaxIndex()-1 do
        local perk=Perks.fromIndex(index)
        if perk and perk:getParent() and perk:getParent():getId()~="None" then fn(perk,perk:getId()) end
    end
end
N.eachPerk=eachPerk
function N.xpTolerance(value) return math.max(0.001, math.abs(value or 0)*0.00000012) end

local function findDefinition(list, id)
    id=string.lower(id)
    local match
    for i=0,list:size()-1 do
        local definition=list:get(i)
        local kind=definition:getType()
        if typeId(kind)==id then return definition end
        if not id:find(":",1,true) and string.lower(tostring(kind:getName()))==id then
            if match then error("Ambiguous saved definition "..id) end
            match=definition
        end
    end
    return match
end
local function professionDefinition(id)
    return findDefinition(CharacterProfessionDefinition.getProfessions(),id)
end
local function traitDefinition(id)
    return findDefinition(CharacterTraitDefinition.getTraits(),id)
end
local function traitIds(pl)
    local list=pl:getCharacterTraits():getKnownTraits()
    local result,seen={},{}
    for i=0,list:size()-1 do
        local id=typeId(list:get(i))
        if not seen[id] then result[#result+1]=id; seen[id]=true end
    end
    table.sort(result)
    return result
end
local function listStrings(list)
    local result={}
    for i=0,list:size()-1 do result[#result+1]=tostring(list:get(i)) end
    return result
end
local function captureColor(color)
    if not color then return nil end
    return {r=color:getRedFloat(),g=color:getGreenFloat(),b=color:getBlueFloat()}
end
local visualFields={ {"hairModel","getHairModel","setHairModel"}, {"beardModel","getBeardModel","setBeardModel"},
    {"skinTextureIndex","getSkinTextureIndex","setSkinTextureIndex"}, {"bodyHairIndex","getBodyHairIndex","setBodyHairIndex"} }
local colorFields={ {"hairColor","getHairColor","setHairColor"}, {"beardColor","getBeardColor","setBeardColor"},
    {"naturalHairColor","getNaturalHairColor","setNaturalHairColor"}, {"naturalBeardColor","getNaturalBeardColor","setNaturalBeardColor"},
    {"skinColor","getSkinColor","setSkinColor"} }
local function captureVisual(visual)
    local result={bodyVisuals={}}
    for _,entry in ipairs(visualFields) do result[entry[1]]=visual[entry[2]](visual) end
    for _,entry in ipairs(colorFields) do result[entry[1]]=captureColor(visual[entry[2]](visual)) end
    local body=visual:getBodyVisuals()
    for i=0,body:size()-1 do
        local id=body:get(i):getItemType()
        if id then result.bodyVisuals[#result.bodyVisuals+1]=id end
    end
    return result
end
local function applyVisual(visual,saved)
    if not saved then return end
    for _,entry in ipairs(visualFields) do
        if saved[entry[1]]~=nil then visual[entry[3]](visual,saved[entry[1]]) end
    end
    for _,entry in ipairs(colorFields) do
        local color=saved[entry[1]]
        if color then visual[entry[3]](visual,ImmutableColor.new(color.r,color.g,color.b,1)) end
    end
    visual:getBodyVisuals():clear()
    for _,id in ipairs(saved.bodyVisuals or {}) do visual:addBodyVisualFromItemType(id) end
end

-- These values describe a connection, enforcement state or dying body, not
-- persistent character progress. Other mods' serializable data is retained.
local transientKeys={lifepoints=true,lifebar=true,rebound=true,paradisezrebound=true,
    caged=true,cagekey=true,cagestate=true,injuredpvp=true,isdead=true,deadplayer=true,corpse=true,
    teleport=true,pvp=true,pve=true,safety=true,inventory=true,equipment=true,wornitems=true,
    admin=true,staff=true,role=true,accesslevel=true,capabilities=true,godmode=true,isghost=true,isnoclip=true,
    paradisezhidemodel=true,paradisezspectatetarget=true,paradisezspectateoffset=true,
    paradisedevflash=true,lastcheatstate=true,paradisedevsafehousevehicle=true,
    paradisedevnotesdiscovery=true}
function N.isPersistentKey(key)
    if type(key)~="string" then return type(key)=="number" end
    local lower=string.lower(key)
    if transientKeys[lower] then return false end
    for _,prefix in ipairs({"paradisedevskillrecovery","paradisedevreincarn","reincarnation","lifeprofile",
        "paradiselifeprofile","paradisedevcage","paradisedevteleport","paradiserestoredeadplayer"}) do
        if lower:sub(1,#prefix)==prefix then return false end
    end
    return true
end
function N.persistentData(data)
    local result={}
    for key,value in pairs(data or {}) do
        if N.isPersistentKey(key) then result[key]=value end
    end
    result=boundedCopy(result)
    -- Native player saves also contain inventory and have a separate total
    -- limit. Reserve a conservative budget for restored mod data; four bytes
    -- per string unit plus structural overhead overestimates its native UTF-8
    -- encoding. This is not a guarantee that the whole player save will fit.
    local bytes=0
    local function measure(value)
        local kind=type(value)
        if kind=="string" then bytes=bytes+16+4*#value
        elseif kind=="table" then
            bytes=bytes+16
            for key,item in pairs(value) do
                bytes=bytes+16;measure(key);measure(item)
            end
        else bytes=bytes+16 end
        if bytes>N.MAX_PERSISTENT_BYTES then
            error("Persistent mod data exceeds the 128 KiB restoration budget; profile saved state requires review")
        end
    end
    measure(result)
    return result
end

function N.creationXP(pl)
    return checked(function()
        local desc=pl:getDescriptor()
        local profession=professionDefinition(typeId(desc:getCharacterProfession()))
        if not profession then error("Creation profession is unavailable") end
        local levels={Fitness=5,Strength=5}
        local function addBoosts(definition)
            local boosts=transformIntoKahluaTable(definition:getXpBoosts())
            for perk,value in pairs(boosts) do
                local amount=type(value)=="number" and value or value:intValue()
                local id=perk:getId()
                levels[id]=(levels[id] or 0)+number(amount,"creation XP boost")
            end
        end
        addBoosts(profession)
        for _,id in ipairs(traitIds(pl)) do
            local definition=traitDefinition(id)
            if not definition then error("Creation trait is unavailable: "..id) end
            addBoosts(definition)
        end
        local result={}
        eachPerk(function(perk,id)
            local level=math.max(0,math.min(10,levels[id] or 0))
            if level~=math.floor(level) then error("Non-integer creation level") end
            result[id]=perk:getTotalXpForLevel(level)
        end)
        -- This formula is exact only for a newly created character. An existing
        -- character may have acquired traits; the controller must not infer provenance.
        return result,"fresh_profession_and_creation_traits"
    end)
end

function N.capture(pl,kind,characterKey,creationXP)
    return checked(function()
        local xp,desc=pl:getXp(),pl:getDescriptor()
        local identity={forename=desc:getForename(),surname=desc:getSurname(),profession=typeId(desc:getCharacterProfession()),
            female=desc:isFemale(),voicePitch=desc:getVoicePitch(),voiceType=desc:getVoiceType(),
            traits=traitIds(pl),visual=captureVisual(pl:getHumanVisual()),xpBoosts={}}
        local skills={}
        eachPerk(function(perk,id)
            skills[id]=number(xp:getXP(perk),"XP")
            identity.xpBoosts[id]=xp:getPerkBoost(perk)
        end)
        local snapshot={skills=skills,identity=identity,recipes=listStrings(pl:getKnownRecipes()),
            hoursSurvived=number(pl:getHoursSurvived(),"survival time"),zombieKills=number(pl:getZombieKills(),"zombie kills"),
            location={x=pl:getX(),y=pl:getY(),z=pl:getZ()},capturedAt=getTimestampMs(),kind=kind,characterKey=characterKey,
            modData=N.persistentData(pl:getModData())}
        if creationXP then snapshot.creationXP=boundedCopy(creationXP) end
        local ok,err=M.validateSnapshot(snapshot)
        if not ok then error(err) end
        return boundedCopy(snapshot)
    end)
end

local function managedStates(pl)
    local result={}
    local current={}
    for _,id in ipairs(traitIds(pl)) do current[id]=true end
    local user=tostring(pl:getUsername())
    local syncer=ParadiseDev.TraitSyncer
    local record,_,ambiguous
    if syncer and syncer.getStoredRecord then record,_,ambiguous=syncer.getStoredRecord(user) end
    if ambiguous then error("Conflicting authoritative trait assignments") end
    for id,recordKey in pairs(managed) do
        result[id]=record and type(record[recordKey])=="boolean" and record[recordKey] or current[id]==true
        if record and record[recordKey]==false then result[id]=false end
    end
    if ParadiseDev.Cage and ParadiseDev.Cage.getEntries then
        result["paradisedev:caged"]=false
        for _,entry in ipairs(ParadiseDev.Cage.getEntries()) do
            if string.lower(tostring(entry.username))==string.lower(user) then result["paradisedev:caged"]=entry.isCaged==true end
        end
    end
    result["paradisedev:injuredpvp"]=false
    return result
end

local function prepare(pl,snapshot)
    if isClient and isClient() then error("Profile restoration requires the server") end
    if not pl or pl:isDead() then error("A living replacement character is required") end
    if not pl:isExistInTheWorld() then error("The replacement character is not ready") end
    if pl:isAsleep() then error("The replacement character must be awake") end
    if isServer and isServer() and type(addXpNoMultiplier)~="function" then error("Native XP checker refresh is unavailable") end
    local ok,err=M.validateSnapshot(snapshot)
    if not ok then error(err) end
    local identity=snapshot.identity
    if type(identity.forename)~="string" or type(identity.surname)~="string" or type(identity.profession)~="string" then error("Identity is incomplete") end
    if identity.female~=nil and type(identity.female)~="boolean" then error("Invalid saved sex") end
    if identity.voicePitch~=nil and not finite(identity.voicePitch) then error("Invalid saved voice pitch") end
    if identity.voiceType~=nil and (not finite(identity.voiceType) or identity.voiceType~=math.floor(identity.voiceType)) then error("Invalid saved voice type") end
    local profession=professionDefinition(identity.profession)
    if not profession then error("Saved profession is unavailable: "..identity.profession) end
    local authority=managedStates(pl)
    local traits,traitSet={},{}
    for _,id in ipairs(identity.traits) do
        if type(id)~="string" then error("Invalid saved trait") end
        if not managed[string.lower(id)] then
            local definition=traitDefinition(id)
            if not definition then error("Saved trait is unavailable: "..id) end
            local canonical=typeId(definition:getType())
            if not managed[canonical] then traitSet[canonical]=true end
        end
    end
    for id,enabled in pairs(authority) do if enabled then traitSet[id]=true end end
    for id in pairs(traitSet) do
        local definition=traitDefinition(id)
        if not definition then error("Saved trait is unavailable: "..id) end
        traits[#traits+1]=definition:getType()
    end
    local perks,seen={},{}
    eachPerk(function(perk,id)
        local amount=snapshot.skills[id]
        if not finite(amount) or amount<0 or amount>perk:getTotalXpForLevel(10)+N.xpTolerance(amount) then error("Invalid saved XP for "..id) end
        local level=0
        for n=1,10 do if amount>=perk:getTotalXpForLevel(n) then level=n else break end end
        local boost=identity.xpBoosts and identity.xpBoosts[id]
        if boost~=nil and (not finite(boost) or boost~=math.floor(boost) or boost<0 or boost>10) then error("Invalid XP boost for "..id) end
        perks[#perks+1]={perk=perk,id=id,amount=amount,level=level,boost=boost}
        seen[id]=true
    end)
    for id in pairs(snapshot.skills) do if not seen[id] then error("Saved skill is unavailable: "..tostring(id)) end end
    for _,recipe in ipairs(snapshot.recipes) do if type(recipe)~="string" then error("Invalid saved recipe") end end
    local persistent=N.persistentData(snapshot.modData)
    local visual=identity.visual
    if visual~=nil then
        if type(visual)~="table" then error("Invalid saved appearance") end
        for _,key in ipairs({"hairModel","beardModel"}) do
            if visual[key]~=nil and type(visual[key])~="string" then error("Invalid appearance model") end
        end
        for _,key in ipairs({"skinTextureIndex","bodyHairIndex"}) do
            if visual[key]~=nil and (not finite(visual[key]) or visual[key]~=math.floor(visual[key])) then error("Invalid appearance index") end
        end
        for _,entry in ipairs(colorFields) do
            local color=visual[entry[1]]
            if color then for _,key in ipairs({"r","g","b"}) do
                if not finite(color[key]) or color[key]<0 or color[key]>1 then error("Invalid appearance color") end
            end end
        end
        for _,id in ipairs(visual.bodyVisuals or {}) do if type(id)~="string" then error("Invalid body visual") end end
    end
    return {profession=profession:getType(),traits=traits,perks=perks,persistent=persistent,authority=authority}
end
function N.ready(pl,snapshot)
    return checked(function() prepare(pl,snapshot); return true end)
end

-- Native AddXP applies Strength nutrition multipliers even when doXPBoost=false.
-- Start at a level boundary with a temporary zero level; this also avoids the
-- Fitness weight guard and replaying every earned level's events and sounds.
function N.setExactXP(pl,entry)
    local xp=pl:getXp()
    local nutrition=pl:getNutrition()
    local proteins=nutrition:getProteins()
    local ok,err=pcall(function()
        if entry.id=="Strength" then nutrition:setProteins(0) end
        pl:setPerkLevelDebug(entry.perk,0)
        xp:setXPToLevel(entry.perk,entry.level)
        local remainder=entry.amount-entry.perk:getTotalXpForLevel(entry.level)
        if remainder>0 then xp:AddXP(entry.perk,remainder,false,false,true) end
        pl:setPerkLevelDebug(entry.perk,entry.level)
        if entry.id=="Fitness" then pl:getStats():set(CharacterStat.FITNESS,entry.level/5-1) end
        if entry.boost~=nil then xp:setPerkBoost(entry.perk,entry.boost) end
        if math.abs(xp:getXP(entry.perk)-entry.amount)>N.xpTolerance(entry.amount) or pl:getPerkLevel(entry.perk)~=entry.level then
            error("Native XP readback failed for "..entry.id)
        end
    end)
    if entry.id=="Strength" then nutrition:setProteins(proteins) end
    if not ok then error(err) end
end

function N.apply(pl,snapshot)
    local plan,err=checked(prepare,pl,snapshot)
    if not plan then return nil,err end
    N.applying[pl]=true
    local ok,result=pcall(function()
        local identity,desc=snapshot.identity,pl:getDescriptor()
        desc:setForename(identity.forename); desc:setSurname(identity.surname)
        desc:setCharacterProfession(plan.profession)
        if identity.female~=nil then desc:setFemale(identity.female==true); pl:setFemale(identity.female==true) end
        if identity.voicePitch~=nil then desc:setVoicePitch(identity.voicePitch) end
        if identity.voiceType~=nil then desc:setVoiceType(identity.voiceType) end
        local nativeTraits=pl:getCharacterTraits()
        local existing=nativeTraits:getKnownTraits()
        for i=0,existing:size()-1 do nativeTraits:remove(existing:get(i)) end
        for _,kind in ipairs(plan.traits) do if not nativeTraits:get(kind) then nativeTraits:add(kind) end end
        for _,entry in ipairs(plan.perks) do N.setExactXP(pl,entry) end
        local recipes=pl:getKnownRecipes(); recipes:clear()
        for _,recipe in ipairs(snapshot.recipes) do recipes:add(recipe) end
        pl:setHoursSurvived(snapshot.hoursSurvived); pl:setZombieKills(snapshot.zombieKills)
        local data=pl:getModData()
        local remove={}
        for key in pairs(data) do if N.isPersistentKey(key) then remove[#remove+1]=key end end
        for _,key in ipairs(remove) do data[key]=nil end
        for key,value in pairs(plan.persistent) do data[key]=boundedCopy(value) end
        applyVisual(pl:getHumanVisual(),identity.visual)
        applyVisual(desc:getHumanVisual(),identity.visual)
        pl:resetModelNextFrame()
        if isServer and isServer() then
            -- This exposed server award path refreshes the native anti-cheat
            -- baseline. XP/traits are sent by the engine's one-second sync.
            local first=plan.perks[1]
            if first then addXpNoMultiplier(pl,first.perk,0) end
            sendSyncPlayerFields(pl,3) -- recipes | traits
            syncVisuals(pl)
        end
        -- Injury belongs to the dead body. Clear its existing administrator
        -- record too, so later status lists cannot replay a stale injury.
        local syncer=ParadiseDev.TraitSyncer
        if syncer and syncer.getStoredRecord then
            local record=syncer.getStoredRecord(tostring(pl:getUsername()))
            if record and record["ParadiseDev:InjuredPvP"]~=false then
                record["ParadiseDev:InjuredPvP"]=false
                if ModData and ModData.transmit and syncer.StoreName then ModData.transmit(syncer.StoreName) end
            end
        end
        return true
    end)
    N.applying[pl]=nil
    if not ok then return nil,tostring(result) end
    return true
end

-- Only mirror non-XP, non-authority fields to the owning client. XP and traits
-- arrive through native server replication; client SyncXp is an admin packet.
function N.mirror(snapshot)
    return checked(function()
        local identity=boundedCopy(snapshot.identity)
        identity.traits=nil; identity.xpBoosts=nil
        return {identity=identity,recipes=boundedCopy(snapshot.recipes),hoursSurvived=snapshot.hoursSurvived,
            zombieKills=snapshot.zombieKills,modData=N.persistentData(snapshot.modData)}
    end)
end
return N
