ParadiseBan = ParadiseBan or {}

ParadiseBan.animChoices = {
    Katana_Stab = { label = "Katana_Stab", timedAction = "ParadiseBanTimedAction", animSet = "Katana_Stab", animX = "Katana_Stab.x", banDelay = 900 },
    Katana_SneakAttack = { label = "Katana_SneakAttack", timedAction = "ParadiseBanTimedAction", animSet = "Katana_SneakAttack", animX = "Katana_SneakAttack.x", banDelay = 900 },
    Katana_ReverseSlashAim = { label = "Katana_ReverseSlashAim", timedAction = "ParadiseBanTimedAction", animSet = "Katana_ReverseSlashAim", animX = "Katana_ReverseSlashAim.x", banDelay = 900 },
    Katana_ReverseSlash = { label = "Katana_ReverseSlash", timedAction = "ParadiseBanTimedAction", animSet = "Katana_ReverseSlash", animX = "Katana_ReverseSlash.x", banDelay = 900 },
    Katana_QuickdrawSlash = { label = "Katana_QuickdrawSlash", timedAction = "ParadiseBanTimedAction", animSet = "Katana_QuickdrawSlash", animX = "Katana_QuickdrawSlash.x", banDelay = 900 },
    Katana_QuickdrawShoveNew = { label = "Katana_QuickdrawShoveNew", timedAction = "ParadiseBanTimedAction", animSet = "Katana_QuickdrawShoveNew", animX = "Katana_QuickdrawShoveNew.x", banDelay = 900 },
    Katana_QuickdrawShove = { label = "Katana_QuickdrawShove", timedAction = "ParadiseBanTimedAction", animSet = "Katana_QuickdrawShove", animX = "Katana_QuickdrawShove.x", banDelay = 900 },
    Katana_ParryToSlash = { label = "Katana_ParryToSlash", timedAction = "ParadiseBanTimedAction", animSet = "Katana_ParryToSlash", animX = "Katana_ParryToSlash.x", banDelay = 900 },
    Katana_LegSlash = { label = "Katana_LegSlash", timedAction = "ParadiseBanTimedAction", animSet = "Katana_LegSlash", animX = "Katana_LegSlash.x", banDelay = 900 },
    Katana_HighToLow = { label = "Katana_HighToLow", timedAction = "ParadiseBanTimedAction", animSet = "Katana_HighToLow", animX = "Katana_HighToLow.x", banDelay = 900 },
    Katana_Floor3 = { label = "Katana_Floor3", timedAction = "ParadiseBanTimedAction", animSet = "Katana_Floor3", animX = "Katana_Floor3.x", banDelay = 900 },
    Katana_AltSlash = { label = "Katana_AltSlash", timedAction = "ParadiseBanTimedAction", animSet = "Katana_AltSlash", animX = "Katana_AltSlash.x", banDelay = 900 },
    Pistol_Shoot_Style_1 = { label = "Pistol_Shoot_Style_1", timedAction = "ParadiseBanTimedAction", animSet = "Pistol_Shoot_Style_1", animX = "Pistol_Shoot_Style_1.x", banDelay = 700 },
    Pistol_Shoot_Style_2 = { label = "Pistol_Shoot_Style_2", timedAction = "ParadiseBanTimedAction", animSet = "Pistol_Shoot_Style_2", animX = "Pistol_Shoot_Style_2.x", banDelay = 700 },
    Pistol_Shoot_Style_3 = { label = "Pistol_Shoot_Style_3", timedAction = "ParadiseBanTimedAction", animSet = "Pistol_Shoot_Style_3", animX = "Pistol_Shoot_Style_3.x", banDelay = 700 },
    Pistol_Shoot_Style_4 = { label = "Pistol_Shoot_Style_4", timedAction = "ParadiseBanTimedAction", animSet = "Pistol_Shoot_Style_4", animX = "Pistol_Shoot_Style_4.x", banDelay = 700 },
    Pistol_Shoot_Style_5 = { label = "Pistol_Shoot_Style_5", timedAction = "ParadiseBanTimedAction", animSet = "Pistol_Shoot_Style_5", animX = "Pistol_Shoot_Style_5.x", banDelay = 700 },
    Zombie_IdleEating = { label = "Zombie_IdleEating", timedAction = "ParadiseBanTimedAction", animSet = "Devour", animX = "Zombie_IdleEating.X", banDelay = 2500 },
    Zombie_IdleEating_OnKnees = { label = "Zombie_IdleEating_OnKnees", timedAction = "ParadiseBanTimedAction", animSet = "Devour2", animX = "Zombie_IdleEating_OnKnees.X", banDelay = 2500 },
}

function ParadiseBan.getAnimChoice(animStr)
    return ParadiseBan.animChoices[animStr]
end
