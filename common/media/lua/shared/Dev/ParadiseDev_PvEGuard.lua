-- Player-only, per-hit protection on both client and server.
require "Dev/ParadiseDev_TraitUtils"
ParadiseDev = ParadiseDev or {}
ParadiseDev.PvE = ParadiseDev.PvE or {}
function ParadiseDev.PvE.onWeaponHit(atkr, targ, wpn, dmg)
    if not atkr or not targ then return end
    if not instanceof(atkr, "IsoPlayer") or not instanceof(targ, "IsoPlayer") then return end
    if ParadiseDev.hasTrait(atkr, "ParadiseDev:PvE") or ParadiseDev.hasTrait(targ, "ParadiseDev:PvE") then
        targ:setAvoidDamage(true)
    end
end
Events.OnWeaponHitCharacter.Remove(ParadiseDev.PvE.onWeaponHit)
Events.OnWeaponHitCharacter.Add(ParadiseDev.PvE.onWeaponHit)
