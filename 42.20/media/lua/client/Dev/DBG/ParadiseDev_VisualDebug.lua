ParadiseDev = ParadiseDev or {}
ParadiseDev.Visual = ParadiseDev.Visual or {}

local Visual = ParadiseDev.Visual

Visual.hidden = Visual.hidden or setmetatable({}, { __mode = "k" })
Visual.weaponSprites = Visual.weaponSprites or setmetatable({}, { __mode = "k" })

function Visual.fail(target, message)
    local player = target or (getPlayer and getPlayer() or nil)
    if not player then return nil end
    if HaloTextHelper and HaloTextHelper.addBadText then
        HaloTextHelper.addBadText(player, message)
    elseif player.setHaloNote then
        player:setHaloNote(message, 255, 80, 80, 300)
    end
    return nil
end

function Visual.getTarget(target)
    if type(target) == "string" and ParadiseDev.getTarg then
        target = ParadiseDev.getTarg(target)
    end

    if not target then return nil end
    if instanceof(target, "IsoPlayer") or instanceof(target, "IsoZombie") then
        return target
    end

    return nil
end

function Visual.hide(target)
    target = Visual.getTarget(target)
    if not target or not target.getItemVisuals then return Visual.fail(target, "Visual test needs a player or zombie target") end
    if Visual.hidden[target] then return target end

    local visuals = target:getItemVisuals()
    if not visuals or visuals:size() == 0 then return Visual.fail(target, "No worn visuals found to hide") end

    local saved = { visuals = {}, worn = {} }
    for index = 0, visuals:size() - 1 do
        saved.visuals[#saved.visuals + 1] = visuals:get(index)
    end

    local worn = target.getWornItems and target:getWornItems() or nil
    if worn then
        for index = 0, worn:size() - 1 do
            local item = worn:getItemByIndex(index)
            saved.worn[#saved.worn + 1] = { item = item, location = worn:getLocation(item) }
        end
        worn:clear()
    end

    Visual.hidden[target] = saved
    visuals:clear()

    if target.onWornItemsChanged then target:onWornItemsChanged() end
    if target.resetModelNextFrame then target:resetModelNextFrame() end
    return target
end

function Visual.replace(target)
    target = Visual.getTarget(target)
    if not target or not target.getItemVisuals then return Visual.fail(target, "Visual test needs a player or zombie target") end

    local saved = Visual.hidden[target]
    if not saved then return Visual.fail(target, "No hidden visuals are cached to restore") end

    local visuals = target:getItemVisuals()
    if not visuals then return Visual.fail(target, "Target has no visual list to restore") end

    visuals:clear()
    for index = 1, #(saved.visuals or saved) do
        visuals:add((saved.visuals or saved)[index])
    end

    local worn = target.getWornItems and target:getWornItems() or nil
    if worn and saved.worn then
        worn:clear()
        for index = 1, #saved.worn do
            local entry = saved.worn[index]
            if entry.item and entry.location then worn:setItem(entry.location, entry.item) end
        end
    end

    Visual.hidden[target] = nil
    if target.onWornItemsChanged then target:onWornItemsChanged() end
    if target.resetModelNextFrame then target:resetModelNextFrame() end
    return target
end

function Visual.testWeaponSprite(target)
    target = Visual.getTarget(target)
    if not target or not target.getPrimaryHandItem then return Visual.fail(target, "Visual test needs a player or zombie target") end

    local weapon = target:getPrimaryHandItem()
    if not weapon or not instanceof(weapon, "HandWeapon") or not weapon:isRanged() then
        return Visual.fail(target, "Hold a firearm in your primary hand")
    end

    Visual.weaponSprites[weapon] = Visual.weaponSprites[weapon] or weapon:getWeaponSprite()
    weapon:setWeaponSprite("Handgun03")

    if target.updateHandEquips then target:updateHandEquips() end
    if target.resetModelNextFrame then target:resetModelNextFrame() end
    return weapon
end

function Visual.resetWeaponSprite(target)
    target = Visual.getTarget(target)
    if not target or not target.getPrimaryHandItem then return Visual.fail(target, "Visual test needs a player or zombie target") end

    local weapon = target:getPrimaryHandItem()
    local sprite = weapon and Visual.weaponSprites[weapon] or nil
    if not sprite then return Visual.fail(target, "No firearm model swap is cached to restore") end

    weapon:setWeaponSprite(sprite)
    Visual.weaponSprites[weapon] = nil

    if target.updateHandEquips then target:updateHandEquips() end
    if target.resetModelNextFrame then target:resetModelNextFrame() end
    return weapon
end
