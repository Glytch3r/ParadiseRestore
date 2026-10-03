ParadiseDev = ParadiseDev or {}
ParadiseDev.PvE = ParadiseDev.PvE or {}
function ParadiseDev.PvE.onWeaponHit(atkr, targ, wpn, dmg)
    local isShouldPrevent = ParadiseDev.hasTrait(targ, "ParadiseDev:PvE") or ParadiseDev.hasTrait(atkr, "ParadiseDev:PvE")
    if isShouldPrevent then 
        targ:setAvoidDamage(true)
    end
end

Events.OnWeaponHitCharacter.Remove(ParadiseDev.PvE.onWeaponHit)
Events.OnWeaponHitCharacter.Add(ParadiseDev.PvE.onWeaponHit)
 