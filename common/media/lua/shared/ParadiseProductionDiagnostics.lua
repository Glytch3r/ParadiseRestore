-- Production cleanup policy: owner/admin sandbox opt-in; default off.
-- This controls diagnostics/UI visibility only, never authorization or evidence.
ParadiseProductionDiagnostics = ParadiseProductionDiagnostics or {}

function ParadiseProductionDiagnostics.isEnabled()
    return SandboxVars ~= nil and SandboxVars.ParadiseZ ~= nil
        and SandboxVars.ParadiseZ.ProductionDiagnostics == true
end
