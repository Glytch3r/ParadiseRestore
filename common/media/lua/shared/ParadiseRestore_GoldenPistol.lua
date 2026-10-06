ParadiseRestore = ParadiseRestore or {}

ParadiseRestore.goldenPistolType = "Base.Pistol3_gold"
ParadiseRestore.goldenPistolBaseType = "Base.Pistol3"

function ParadiseRestore.isB41()
    return getCore():getGameVersion():getMajor() == 41
end
if ParadiseRestore.isB41() then return end

function ParadiseRestore.addGoldenPistolMounts()
    local itemScrs = ScriptManager.instance:getAllItems()
    for i = 0, itemScrs:size() - 1 do
        local itemScr = itemScrs:get(i)
        local item = instanceItem(itemScr:getFullName())
        if item and instanceof(item, "WeaponPart") then
            local mountOn = item:getMountOn()
            if mountOn:contains(ParadiseRestore.goldenPistolBaseType) and not mountOn:contains(ParadiseRestore.goldenPistolType) then
                local mountTypes = {}
                for j = 0, mountOn:size() - 1 do
                    mountTypes[#mountTypes + 1] = mountOn:get(j)
                end
                mountTypes[#mountTypes + 1] = ParadiseRestore.goldenPistolType
                itemScr:DoParam("MountOn = " .. table.concat(mountTypes, ";"))
            end
        end
    end
end
Events.OnGameBoot.Remove(ParadiseRestore.addGoldenPistolMounts)
Events.OnGameBoot.Add(ParadiseRestore.addGoldenPistolMounts)
