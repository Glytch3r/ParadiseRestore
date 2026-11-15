ParadiseZ = ParadiseZ or {}

if getCore():getGameVersion():getMajor() == 41 then return end

function ParadiseZ.fixSawSheetRecipe()
    local scr = getScriptManager():getCraftRecipe("SawSheet")
    if not scr then return end
    local outs = scr:getOutputs()
    local bad = nil
    local hasMapper = false
    for i = 0, outs:size() - 1 do
        local out = outs:get(i)
        if out:getOutputMapper() then
            hasMapper = true
        elseif string.find(out:getOriginalLine(), "Base.SmallSheetMetal", 1, true) then
            bad = out
        end
    end
    if not bad or not hasMapper then return end
    outs:remove(bad)
    scr:getIoLines():remove(bad)
end
Events.OnGameStart.Remove(ParadiseZ.fixSawSheetRecipe)
Events.OnGameStart.Add(ParadiseZ.fixSawSheetRecipe)
Events.OnServerStarted.Remove(ParadiseZ.fixSawSheetRecipe)
Events.OnServerStarted.Add(ParadiseZ.fixSawSheetRecipe)