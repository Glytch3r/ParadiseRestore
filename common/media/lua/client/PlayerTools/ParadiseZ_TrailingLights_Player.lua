-- Player-only bootstrap for public ParadiseZ trailing lights.
-- This intentionally installs only the renderer: it adds no menu or controls.
local function installSharedLightRenderer()
    local trailingLights = rawget(_G, "ParadiseZTrailingLights")
    if trailingLights and trailingLights.installRenderer then
        trailingLights.installRenderer()
    end
end

Events.OnGameStart.Add(installSharedLightRenderer)
