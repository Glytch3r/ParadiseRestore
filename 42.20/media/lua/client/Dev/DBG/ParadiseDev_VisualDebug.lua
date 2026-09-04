ParadiseDev = ParadiseDev or {}
ParadiseDev.Visual = ParadiseDev.Visual or {}

local visual = ParadiseDev.Visual

visual.hidden = visual.hidden or setmetatable({}, { __mode = "k" })
visual.weaponSprites = visual.weaponSprites or setmetatable({}, { __mode = "k" })

function visual.fail(targ, message)
    local pl = targ or (getPlayer and getPlayer() or nil)
    if not pl then return nil end
    if HaloTextHelper and HaloTextHelper.addBadText then
        HaloTextHelper.addBadText(pl, message)
    elseif pl.setHaloNote then
        pl:setHaloNote(message, 255, 80, 80, 300)
    end
    return nil
end

function visual.getTarget(targ)
    if type(targ) == "string" and ParadiseDev.getTarg then
        targ = ParadiseDev.getTarg(targ)
    end

    if not targ then return nil end
    if instanceof(targ, "IsoPlayer") or instanceof(targ, "IsoZombie") then
        return targ
    end

    return nil
end

function visual.hide(targ)
    targ = visual.getTarget(targ)
    if not targ or not targ.getItemVisuals then return visual.fail(targ, "Visual test needs a player or zombie target") end
    if visual.hidden[targ] then return targ end

    local visuals = targ:getItemVisuals()
    if not visuals or visuals:size() == 0 then return visual.fail(targ, "No worn visuals found to hide") end

    local saved = { visuals = {}, worn = {} }
    for int = 0, visuals:size() - 1 do
        saved.visuals[#saved.visuals + 1] = visuals:get(int)
    end

    local worn = targ.getWornItems and targ:getWornItems() or nil
    if worn then
        for int = 0, worn:size() - 1 do
            local obj = worn:getItemByIndex(int)
            saved.worn[#saved.worn + 1] = { obj = obj, loc = worn:getLocation(obj) }
        end
        worn:clear()
    end

    visual.hidden[targ] = saved
    visuals:clear()

    if targ.onWornItemsChanged then targ:onWornItemsChanged() end
    if targ.resetModelNextFrame then targ:resetModelNextFrame() end
    return targ
end

function visual.replace(targ)
    targ = visual.getTarget(targ)
    if not targ or not targ.getItemVisuals then return visual.fail(targ, "Visual test needs a player or zombie target") end

    local saved = visual.hidden[targ]
    if not saved then return visual.fail(targ, "No hidden visuals are cached to restore") end

    local visuals = targ:getItemVisuals()
    if not visuals then return visual.fail(targ, "Target has no visual list to restore") end

    visuals:clear()
    for int = 1, #(saved.visuals or saved) do
        visuals:add((saved.visuals or saved)[int])
    end

    local worn = targ.getWornItems and targ:getWornItems() or nil
    if worn and saved.worn then
        worn:clear()
        for int = 1, #saved.worn do
            local obj = saved.worn[int]
            if obj.obj and obj.loc then worn:setItem(obj.loc, obj.obj) end
        end
    end

    visual.hidden[targ] = nil
    if targ.onWornItemsChanged then targ:onWornItemsChanged() end
    if targ.resetModelNextFrame then targ:resetModelNextFrame() end
    return targ
end

function visual.testWeaponSprite(targ)
    targ = visual.getTarget(targ)
    if not targ or not targ.getPrimaryHandItem then return visual.fail(targ, "Visual test needs a player or zombie target") end

    local wpn = targ:getPrimaryHandItem()
    if not wpn or not instanceof(wpn, "HandWeapon") or not wpn:isRanged() then
        return visual.fail(targ, "Hold a firearm in your primary hand")
    end

    visual.weaponSprites[wpn] = visual.weaponSprites[wpn] or wpn:getWeaponSprite()
    wpn:setWeaponSprite("Handgun03")

    if targ.updateHandEquips then targ:updateHandEquips() end
    if targ.resetModelNextFrame then targ:resetModelNextFrame() end
    return wpn
end

function visual.resetWeaponSprite(targ)
    targ = visual.getTarget(targ)
    if not targ or not targ.getPrimaryHandItem then return visual.fail(targ, "Visual test needs a player or zombie target") end

    local wpn = targ:getPrimaryHandItem()
    local spr = wpn and visual.weaponSprites[wpn] or nil
    if not spr then return visual.fail(targ, "No firearm model swap is cached to restore") end

    wpn:setWeaponSprite(spr)
    visual.weaponSprites[wpn] = nil

    if targ.updateHandEquips then targ:updateHandEquips() end
    if targ.resetModelNextFrame then targ:resetModelNextFrame() end
    return wpn
end
