

ParadiseDev = ParadiseDev or {}


function ParadiseDev.getTraitDef(tStr)
    if not tStr then return end
    local tList = CharacterTraitDefinition.getTraits()
    if tStr == '' then return end
    tStr = string.lower(tStr)

    for i = 0, tList:size() - 1 do
        local tDef = tList:get(i)
        if tDef then
            local tType = tDef:getType()
            tType = string.lower(tostring(tType))
            local tLabel = tDef:getLabel()
            tLabel = string.lower(tostring(tLabel))          
            if tStr == tType or tStr == tLabel then
                return tDef
            end
        end
    end
end

function ParadiseDev.isHasTrait(tStr)
    if not tStr then return false end
    local tDef = ParadiseDev.getTraitDef(tStr)
    if not tDef then return false end
    local pl = getPlayer() 
    if not pl then return end
    local tType = tDef:getType()
    if not tType then return false end
    return pl:hasTrait(tType)
end

function ParadiseDev.setTrait(tStr, isAdd)
    local pl = getPlayer()
    if not pl then return end

    local tDef = ParadiseDev.getTraitDef(tStr)
    if not tDef then return end

    local tType = tDef:getType()

    if isAdd then
        if not pl:hasTrait(tType) then
            pl:getCharacterTraits():add(tType)
            pl:modifyTraitXPBoost(tType, false)
        end
    else
        if pl:hasTrait(tType) then
            pl:getCharacterTraits():remove(tType)
            pl:modifyTraitXPBoost(tType, true)
        end
    end

    SyncXp(pl)
end
