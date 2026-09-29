ParadiseDev = ParadiseDev or {}
ParadiseDev.PreyZed = ParadiseDev.PreyZed or {}

ParadiseDev.PreyZed.skinTicks = ParadiseDev.PreyZed.skinTicks or 0
ParadiseDev.PreyZed.skinInterval = 60
ParadiseDev.PreyZed.SkinList_F = {
    F_ZedBody01_level1 = "FemaleBody01",
    F_ZedBody01_level2 = "FemaleBody02",
    F_ZedBody01_level3 = "FemaleBody03",
    F_ZedBody01 = "FemaleBody04",
    F_ZedBody02_level1 = "FemaleBody05",
    F_ZedBody02_level2 = "FemaleBody01",
    F_ZedBody02_level3 = "FemaleBody02",
    F_ZedBody02 = "FemaleBody03",
    F_ZedBody03_level1 = "FemaleBody04",
    F_ZedBody03_level2 = "FemaleBody05",
    F_ZedBody03_level3 = "FemaleBody01",
    F_ZedBody03 = "FemaleBody02",
    F_ZedBody04_level1 = "FemaleBody03",
    F_ZedBody04_level2 = "FemaleBody04",
    F_ZedBody04_level3 = "FemaleBody05",
    F_ZedBody04 = "FemaleBody01",
}
ParadiseDev.PreyZed.SkinList_M = {
    M_ZedBody01_level1 = "MaleBody01",
    M_ZedBody01_level2 = "MaleBody01a",
    M_ZedBody01_level3 = "MaleBody02",
    M_ZedBody01 = "MaleBody02a",
    M_ZedBody02_level1 = "MaleBody03",
    M_ZedBody02_level2 = "MaleBody03a",
    M_ZedBody02_level3 = "MaleBody04",
    M_ZedBody02 = "MaleBody04a",
    M_ZedBody03_level1 = "MaleBody05",
    M_ZedBody03_level2 = "MaleBody05a",
    M_ZedBody03_level3 = "MaleBody01",
    M_ZedBody03 = "MaleBody01a",
    M_ZedBody04_level1 = "MaleBody02",
    M_ZedBody04_level2 = "MaleBody02a",
    M_ZedBody04_level3 = "MaleBody03",
    M_ZedBody04 = "MaleBody03a",
}

function ParadiseDev.PreyZed.isPrey(zed)
    if not zed then return false end
    if zed.getOutfitName and zed:getOutfitName() == "PreyZed" then return true end
    return zed.getModData and zed:getModData().ParadiseDevPreyZed == true or false
end

function ParadiseDev.PreyZed.isHuntZoneAt(x, y, z)
    if not ParadiseDev.Zones or not ParadiseDev.Zones.Border or not ParadiseDev.Zones.Border.getAuthorityAt then return false end
    local zone = ParadiseDev.Zones.Border.getAuthorityAt(x, y, z, 0)
    return zone and zone.features and zone.features.isHunt == true or false
end

function ParadiseDev.PreyZed.clearVisual(zed)
    if not zed or not zed.getHumanVisual then return end
    local visual = zed:getHumanVisual()
    if not visual then return end
    if zed.clearAttachedItems then zed:clearAttachedItems() end
    if visual.removeBlood then visual:removeBlood() end
    if BloodBodyPartType and BloodBodyPartType.MAX then
        for index = 0, BloodBodyPartType.MAX:index() - 1 do
            local part = BloodBodyPartType.FromIndex(index)
            if visual.setBlood then visual:setBlood(part, 0) end
            if visual.setDirt then visual:setDirt(part, 0) end
        end
    end
    local itemVisuals = zed.getItemVisuals and zed:getItemVisuals() or nil
    if itemVisuals and BloodBodyPartType and BloodBodyPartType.MAX then
        for index = 0, itemVisuals:size() - 1 do
            local item = itemVisuals:get(index)
            if item then
                for partIndex = 0, BloodBodyPartType.MAX:index() - 1 do
                    local part = BloodBodyPartType.FromIndex(partIndex)
                    if item.setBlood then item:setBlood(part, 0) end
                    if item.setDirt then item:setDirt(part, 0) end
                end
                if item.setInventoryItem then item:setInventoryItem(nil) end
            end
        end
    end
end

function ParadiseDev.PreyZed.applyAnimation(zed)
    if zed and zed.setVariable then zed:setVariable("isPrey", true) end
end

function ParadiseDev.PreyZed.setSkin(zed)
    if not zed then return end
    if zed.dressInPersistentOutfit then zed:dressInPersistentOutfit("PreyZed") end
    ParadiseDev.PreyZed.applyAnimation(zed)
    if zed.getModData then zed:getModData().ParadiseDevPreyZed = true end
    ParadiseDev.PreyZed.clearVisual(zed)
    local visual = zed.getHumanVisual and zed:getHumanVisual() or nil
    if visual and visual.getSkinTexture and visual.setSkinTextureName then
        local current = visual:getSkinTexture()
        local skin = zed:isFemale() and ParadiseDev.PreyZed.SkinList_F[current] or ParadiseDev.PreyZed.SkinList_M[current]
        if skin then visual:setSkinTextureName(skin) end
    end
    if zed.resetModel then zed:resetModel() end
end

function ParadiseDev.PreyZed.skinHandler(zed)
    ParadiseDev.PreyZed.skinTicks = ParadiseDev.PreyZed.skinTicks + 1
    if not zed then return end
    if zed.isReanimatedPlayer and zed:isReanimatedPlayer() then return end
    if ParadiseDev.PreyZed.isPrey(zed) then ParadiseDev.PreyZed.applyAnimation(zed) end
    if ParadiseDev.PreyZed.skinTicks % ParadiseDev.PreyZed.skinInterval ~= 0 then return end
    local sq = zed:getSquare()
    if not sq or not ParadiseDev.PreyZed.isHuntZoneAt(sq:getX(), sq:getY(), sq:getZ()) then return end
    if not ParadiseDev.PreyZed.isPrey(zed) then ParadiseDev.PreyZed.setSkin(zed) end
end

Events.OnZombieUpdate.Remove(ParadiseDev.PreyZed.skinHandler)
Events.OnZombieUpdate.Add(ParadiseDev.PreyZed.skinHandler)
