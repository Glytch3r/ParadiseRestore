-- Player-only, per-hit protection on both client and server.
require "Dev/ParadiseDev_PvEPolicy"
ParadiseDev = ParadiseDev or {}
ParadiseDev.PvE = ParadiseDev.PvE or {}
function ParadiseDev.PvE.onWeaponHit(atkr, targ, wpn, dmg)
    if not atkr or not targ then return end
    if not instanceof(atkr, "IsoPlayer") or not instanceof(targ, "IsoPlayer") then return end
    if ParadiseDev.PvEPolicy.isHitProtected(atkr,targ) then
        targ:setAvoidDamage(true)
    end
end
Events.OnWeaponHitCharacter.Remove(ParadiseDev.PvE.onWeaponHit)
Events.OnWeaponHitCharacter.Add(ParadiseDev.PvE.onWeaponHit)
