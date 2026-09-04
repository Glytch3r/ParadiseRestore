ParadiseDev = ParadiseDev or {}
ParadiseDev.Skin = ParadiseDev.Skin or {}

local skin = ParadiseDev.Skin
skin.module = "ParadiseDevSkin"

function skin.syncAddedItem(container, item)
    if not container or not item then return false end
    if item.SynchSpawn then item:SynchSpawn() end
    sendAddItemToContainer(container, item)
    return true
end

function skin.spawnGoldgun(player)
    if not player or not ParadiseDev.isAdm(player) then return false end

    local inventory = player:getInventory()
    local itemScript = ScriptManager.instance:getItem("Base.Pistol3_gold")
    if not inventory or not itemScript then return false end

    local originalSprite = itemScript:getWeaponSprite()
    itemScript:DoParam("WeaponSprite = Handgun_gold")
    local ok, item = pcall(function()
        return inventory:AddItem("Base.Pistol3_gold")
    end)
    itemScript:DoParam("WeaponSprite = " .. tostring(originalSprite))
    if not ok or not item then return false end

    item:setWeaponSprite("Handgun_gold")
    skin.syncAddedItem(inventory, item)
    return item
end

function skin.reloadGun(player, gun)
    if not gun or not instanceof(gun, "HandWeapon") or not gun:isRanged() then return end
    if (gun:getMagazineType() and gun:isContainsClip()) or gun:getCurrentAmmoCount() > 0 or (gun:haveChamber() and gun:isRoundChambered()) then return end
    gun:setCurrentAmmoCount(gun:getMaxAmmo())
    if gun:getMagazineType() then gun:setContainsClip(true) end
    if gun:haveChamber() then gun:setRoundChambered(true) end
    if sendItemStats then sendItemStats(gun) end
end

function skin.reloadGuns(player)
    if not player or not ParadiseDev.isAdm(player) then return false end
    local loaded = {}
    local function loadContainer(container)
        if not container then return end
        local items = container:getItems()
        for index = 0, items:size() - 1 do
            local item = items:get(index)
            if not loaded[item] then
                loaded[item] = true
                skin.reloadGun(player, item)
                if item.getInventory then loadContainer(item:getInventory()) end
            end
        end
    end
    loadContainer(player:getInventory())
    skin.reloadGun(player, player:getPrimaryHandItem())
    skin.reloadGun(player, player:getSecondaryHandItem())
    return true
end

function skin.onClientCommand(module, command, player)
    if module ~= skin.module then return end
    if command == "spawnGoldgun" then skin.spawnGoldgun(player) end
    if command == "reloadGuns" then skin.reloadGuns(player) end
end

Events.OnClientCommand.Remove(skin.onClientCommand)
Events.OnClientCommand.Add(skin.onClientCommand)

function ParadiseDev.cloneWithWeaponSprite(item, newSprite)
    if not item then return end

    local pl = getPlayer()
    if not pl then return end

    local fullType = item:getFullType()
    local itemScr = ScriptManager.instance:getItem(fullType)
    if not itemScr then return end

    local wasPrimary = pl:getPrimaryHandItem() == item
    local wasSecondary = pl:getSecondaryHandItem() == item

    local originalSprite = itemScr:getWeaponSprite()
    itemScr:DoParam("WeaponSprite = " .. tostring(newSprite))

    local clonedItem = ParadiseDev.cloneStuff(item)

    itemScr:DoParam("WeaponSprite = " .. tostring(originalSprite))

    if clonedItem then
        if wasPrimary then
            pl:setPrimaryHandItem(clonedItem)
        end

        if wasSecondary then
            pl:setSecondaryHandItem(clonedItem)
        end
    end

    item:getContainer():DoRemoveItem(item)

    return clonedItem
end
--[[ 
function ParadiseDev.mp5SpriteSwap(player, context, items)
    local user = getPlayer():getUsername()
    if not ParadiseDev.isAllowedToChange(user) then return end
    for _, item in ipairs(items) do
        local realItem

        if type(item) == "table" and item.items and item.items[1] then
            realItem = item.items[1]
        elseif instanceof(item, "InventoryItem") then
            realItem = item
        end
        
        if realItem and realItem:getFullType() == "Base.MP5SD" and realItem:getWeaponSprite() ~= 'alt_MP5SD' then
            context:addOption("Change MP5SD Skin", realItem, function(itemObj)
                ParadiseDev.cloneWithWeaponSprite(itemObj, "alt_MP5SD")
            end)
            break
        end
    end
end
Events.OnFillInventoryObjectContextMenu.Remove(ParadiseDev.mp5SpriteSwap)
Events.OnFillInventoryObjectContextMenu.Add(ParadiseDev.mp5SpriteSwap)
 ]]
--[[ 
function ParadiseDev.mp5ReloadResikin(pl, wpn)
    if not pl or not wpn then return end

    local user = pl:getUsername()
    if not ParadiseDev.isAllowedToChange(user) then return end

    if wpn:getFullType() == "Base.MP5SD" and wpn:getWeaponSprite() ~= "alt_MP5SD" then
        ParadiseDev.cloneWithWeaponSprite(wpn, "alt_MP5SD")
    end
end

Events.OnPressReloadButton.Remove(ParadiseDev.mp5ReloadResikin)
Events.OnPressReloadButton.Add(ParadiseDev.mp5ReloadResikin)
 ]]

function ParadiseDev.parseMp5AllowedSkinChangeNames()
    local strList = SandboxVars.ParadiseDev.mp5SkinChanger or "Glytch3r;OldmanTurtle"
    local t = {}

    for name in string.gmatch(strList, "[^;]+") do
        t[string.lower(name)] = true
    end

    return t
end
function ParadiseDev.isAllowedToChange(user)
    local parsed = ParadiseDev.parseMp5AllowedSkinChangeNames()
    user = string.lower(user or "")
    return parsed[user] == true
end
