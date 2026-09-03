require "Dev/ParadiseDev_ApplyMedkitPvP"

ParadiseDev = ParadiseDev or {}
ParadiseDev.PvP = ParadiseDev.PvP or {}

function ParadiseDev.PvP.isEnabled()
    local pvp = SandboxVars and SandboxVars.ParadiseZpvp
    return not pvp or pvp.CustomPvP ~= false
end

ParadiseDev.PvP.defaultShotguns = {
    ["Base.Shotgun"] = true, ["Base.Spas12"] = true, ["Base.Spas12Folded"] = true,
    ["Base.ShotgunSemi"] = true, ["Base.Shotgun2"] = true, ["Base.ShotgunSawnoff"] = true,
    ["Base.ShotgunSawnoffNoStock"] = true, ["Base.DoubleBarrelShotgun"] = true,
    ["Base.DoubleBarrelShotgunSawnoff"] = true, ["Base.DoubleBarrelShotgunSawnoffNoStock"] = true,
    ["SpoonEngineerStuff.ScrappyBlunderbuss"] = true, ["Base.AssaultRifleMasterkeyShotgun"] = true,
    ["Base.M2400_Shotgun"] = true,
}

function ParadiseDev.PvP.isProtected(pl)
    return ParadiseDev.LifeBar.isPvE(pl) or ParadiseDev.LifeBar.isPvEZone(pl)
end

function ParadiseDev.PvP.isUnarmed(pl)
    return tostring(WeaponType.getWeaponType(pl)) == "barehand"
end

function ParadiseDev.PvP.isFirearm(wpn)
    local item = wpn and wpn:getScriptItem() or nil
    return item and item:isRanged() or false
end

function ParadiseDev.PvP.getShotguns()
    local pvp = SandboxVars and SandboxVars.ParadiseZpvp
    local list = pvp and pvp.ShotgunList
    if type(list) ~= "string" or list == "" then return ParadiseDev.PvP.defaultShotguns end
    local shotguns = {}
    for fullType in list:gmatch("[^;]+") do shotguns[fullType] = true end
    return shotguns
end

function ParadiseDev.PvP.getWeaponDamage(wpn, pl)
    local pvp = SandboxVars and SandboxVars.ParadiseZpvp or {}
    if ParadiseDev.PvP.isUnarmed(pl) then return 0 end
    wpn = wpn or pl:getPrimaryHandItem()
    if not ParadiseDev.PvP.isFirearm(wpn) then return tonumber(pvp.MeleePvpDmg) or 10 end
    local item = wpn:getScriptItem()
    if item and item.getSwingAnim and item:getSwingAnim() == "Rifle" then
        return ParadiseDev.PvP.getShotguns()[wpn:getFullType()] and (tonumber(pvp.ShotgunPvpDmg) or 25) or (tonumber(pvp.RiflePvpDmg) or 20)
    end
    return tonumber(pvp.PistolPvpDmg) or 15
end

function ParadiseDev.PvP.injure(pl)
    local trait = ParadiseDev.getTrait and ParadiseDev.getTrait("ParadiseDev:InjuredPvP") or nil
    if trait and not ParadiseDev.hasTrait(pl, trait) then
        pl:getTraits():add(trait)
        pl:addLineChatElement("PvP Injured")
    end
end

function ParadiseDev.PvP.applyDamage(targ, char, wpn, bonus)
    if not ParadiseDev.PvP.isEnabled() then return end
    local pvp = SandboxVars and SandboxVars.ParadiseZpvp or {}
    local md = targ:getModData()
    local lowest = targ:isGodMod() and 1 or 0
    local dmg = ParadiseDev.PvP.getWeaponDamage(wpn, char) + (bonus or 0)
    md.LifePoints = math.max(lowest, (md.LifePoints or 100) - dmg)
    md.ParadiseDevDamageFlash = { decay = 0.04, rgb = { 1, 0, 0 }, opacity = 0.4 }
    if ParadiseDev.PvP.isFirearm(wpn) and ZombRand(1, 101) <= (tonumber(pvp.PvPInjuryChance) or 0) then ParadiseDev.PvP.injure(targ) end
    if md.LifePoints <= 0 and not pvp.teleportPvpDeath then targ:Kill(char) end
end

function ParadiseDev.PvP.onWeaponHit(char, targ, wpn)
    if not ParadiseDev.PvP.isEnabled() then return end
    if not char or not targ then return end
    if instanceof(char, "IsoZombie") or instanceof(targ, "IsoZombie") then
        targ:setAvoidDamage(false)
        return
    end
    local protected = ParadiseDev.PvP.isProtected(char) or ParadiseDev.PvP.isProtected(targ)
    targ:setAvoidDamage(true)
    if protected or targ ~= getPlayer() then return end
    local pvp = SandboxVars and SandboxVars.ParadiseZpvp or {}
    local bonus = targ:isCriticalHit() and ZombRand(0, (tonumber(pvp.pvpDmgMult) or 0) + 1) or 0
    ParadiseDev.PvP.applyDamage(targ, char, wpn, bonus)
end

function ParadiseDev.PvP.addMedkitOption(plNum, context, items)
    if not ParadiseDev.PvP.isEnabled() then return end
    local pl = getSpecificPlayer(plNum)
    if not pl then return end
    local item
    for _, entry in ipairs(items or {}) do
        local candidate = type(entry) == "table" and entry.items and entry.items[1] or entry
        if candidate and candidate:getFullType() == "ParadiseZ.MedkitPvP" then item = candidate break end
    end
    if not item or not pl:getInventory():contains(item) then return end
    local option = context:addOption("Apply PvP Medkit", item, function(medkit)
        ISTimedActionQueue.add(ParadiseDev.ApplyMedkitPvP:new(pl, medkit))
    end)
    local md = pl:getModData()
    if not ParadiseDev.hasTrait(pl, "ParadiseDev:InjuredPvP") and (md.LifePoints or 100) >= 100 then option.notAvailable = true end
end

Events.OnWeaponHitCharacter.Remove(ParadiseDev.PvP.onWeaponHit)
Events.OnWeaponHitCharacter.Add(ParadiseDev.PvP.onWeaponHit)
Events.OnFillInventoryObjectContextMenu.Remove(ParadiseDev.PvP.addMedkitOption)
Events.OnFillInventoryObjectContextMenu.Add(ParadiseDev.PvP.addMedkitOption)
