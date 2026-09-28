ParadisePlStats = ParadisePlStats or {}

ParadisePlStats.VANILLA_DRUNK_REDUCTION = 0.0042
ParadisePlStats.VANILLA_DRUNK_MAX_MINUTES = 100 / (ParadisePlStats.VANILLA_DRUNK_REDUCTION * 60 * 60)

function ParadisePlStats.drunkHandler(_, pl)
    if not pl then return end

    local options = SandboxVars and SandboxVars.ParadiseZ or nil
    local maxMinutes = options and tonumber(options.DrunkMaxMinutes) or ParadisePlStats.VANILLA_DRUNK_MAX_MINUTES
    if not maxMinutes or maxMinutes <= 0 then
        maxMinutes = ParadisePlStats.VANILLA_DRUNK_MAX_MINUTES
    end

    local bodyDamage = pl:getBodyDamage()
    if bodyDamage then
        bodyDamage:setDrunkReductionValue(100 / (maxMinutes * 60 * 60))
    end
end

Events.OnCreatePlayer.Add(ParadisePlStats.drunkHandler)
