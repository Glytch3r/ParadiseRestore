ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.Radiation = ParadiseDev.Zones.Radiation or {}
ParadiseDev.Zones.Radiation.lastDamageAt = ParadiseDev.Zones.Radiation.lastDamageAt or 0
ParadiseDev.Zones.Radiation.lastDecayAt = ParadiseDev.Zones.Radiation.lastDecayAt or 0
ParadiseDev.Zones.Radiation.trail = ParadiseDev.Zones.Radiation.trail or {}

function ParadiseDev.Zones.Radiation.getOptions()
    return SandboxVars and SandboxVars.ParadiseZ or {}
end

function ParadiseDev.Zones.Radiation.isRadZone(pl)
    local border = ParadiseDev.Zones and ParadiseDev.Zones.Border
    local zone = border and border.getZoneFor and border.getZoneFor(pl) or nil
    return zone and zone.features and zone.features.isRad == true or false
end

function ParadiseDev.Zones.Radiation.isPvE(pl)
    return ParadiseDev.hasTrait and ParadiseDev.hasTrait(pl, "ParadiseDev:PvE") or false
end

function ParadiseDev.Zones.Radiation.getRadSuitDamageMult(pl)
    local items = pl and pl:getWornItems() or nil
    if not items then return 1 end
    local hasSuit = false
    local hasHole = false
    for i = 0, items:size() - 1 do
        local item = items:getItemByIndex(i)
        local md = item and item:getModData() or nil
        if md and md.isRadSuit ~= nil then
            hasSuit = true
            local vis = item:getVisual()
            if vis and vis:getHolesNumber() > 0 then hasHole = true end
        end
    end
    if not hasSuit then return 1 end
    if hasHole then return 0.5 end
    return 0
end

function ParadiseDev.Zones.Radiation.canDamage(pl)
    if not pl or not pl:isAlive() or not ParadiseDev.Zones.Radiation.isRadZone(pl) then return false end
    local opt = ParadiseDev.Zones.Radiation.getOptions()
    if opt.RadZonePvpOnly == true and ParadiseDev.Zones.Radiation.isPvE(pl) then return false end
    return ParadiseDev.Zones.Radiation.getRadSuitDamageMult(pl) > 0
end

function ParadiseDev.Zones.Radiation.clearFloor(entry)
    if entry and entry.flr then entry.flr:setHighlighted(false, false) end
end

function ParadiseDev.Zones.Radiation.refreshTrail()
    local count = #ParadiseDev.Zones.Radiation.trail
    for i, entry in ipairs(ParadiseDev.Zones.Radiation.trail) do
        local alpha = (count - i + 1) / 4
        entry.flr:setHighlightColor(0, entry.green, 0, alpha)
        entry.flr:setHighlighted(true, false)
    end
end

function ParadiseDev.Zones.Radiation.addTrailFloor(pl)
    local sq = pl and pl:getSquare() or nil
    local flr = sq and sq:getFloor() or nil
    if not flr then return end
    local key = tostring(sq:getX()) .. ":" .. tostring(sq:getY()) .. ":" .. tostring(sq:getZ())
    local trail = ParadiseDev.Zones.Radiation.trail
    if trail[#trail] and trail[#trail].key == key then return end
    for i = #trail, 1, -1 do
        if trail[i].key == key then table.remove(trail, i) end
    end
    trail[#trail + 1] = { key = key, flr = flr, green = ZombRand(55, 101) / 100 }
    while #trail > 3 do ParadiseDev.Zones.Radiation.clearFloor(table.remove(trail, 1)) end
    ParadiseDev.Zones.Radiation.refreshTrail()
end

function ParadiseDev.Zones.Radiation.decayTrail(now)
    if #ParadiseDev.Zones.Radiation.trail == 0 or now - ParadiseDev.Zones.Radiation.lastDecayAt < 1000 then return end
    ParadiseDev.Zones.Radiation.lastDecayAt = now
    ParadiseDev.Zones.Radiation.clearFloor(table.remove(ParadiseDev.Zones.Radiation.trail, 1))
    ParadiseDev.Zones.Radiation.refreshTrail()
end

function ParadiseDev.Zones.Radiation.applyDamage(pl, dmg)
    local opt = ParadiseDev.Zones.Radiation.getOptions()
    if opt.RadToModHp == true then
        local md = pl:getModData()
        md.LifePoints = math.max(0, (tonumber(md.LifePoints) or 100) - dmg)
        return
    end
    pl:getBodyDamage():ReduceGeneralHealth(dmg)
end

function ParadiseDev.Zones.Radiation.tick(pl, now)
    now = tonumber(now) or getTimestampMs()
    local opt = ParadiseDev.Zones.Radiation.getOptions()
    if not ParadiseDev.Zones.Radiation.canDamage(pl) then
        ParadiseDev.Zones.Radiation.lastDamageAt = now
        ParadiseDev.Zones.Radiation.decayTrail(now)
        return
    end
    if opt.RadGlowIndicator ~= false then
        ParadiseDev.Zones.Radiation.addTrailFloor(pl)
    else
        while #ParadiseDev.Zones.Radiation.trail > 0 do ParadiseDev.Zones.Radiation.clearFloor(table.remove(ParadiseDev.Zones.Radiation.trail)) end
    end
    if now - ParadiseDev.Zones.Radiation.lastDamageAt < 1000 then return end
    ParadiseDev.Zones.Radiation.lastDamageAt = now
    local dmg = math.max(0, tonumber(opt.RadDamageMultiplier) or 1) * ParadiseDev.Zones.Radiation.getRadSuitDamageMult(pl)
    if dmg > 0 then ParadiseDev.Zones.Radiation.applyDamage(pl, dmg) end
end

function ParadiseDev.Zones.Radiation.getSuitList()
    local opt = ParadiseDev.Zones.Radiation.getOptions()
    local str = tostring(opt.RadSuitList or "TheyKnew.MysteriousHazm;Base.HazmatSuit;Base.Hat_NBCmask")
    local tab = {}
    for itemType in str:gmatch("[^;]+") do tab[#tab + 1] = itemType end
    return tab
end

function ParadiseDev.Zones.Radiation.applyRadSuitParams()
    for _, itemType in ipairs(ParadiseDev.Zones.Radiation.getSuitList()) do
        local item = ScriptManager.instance:getItem(itemType)
        if item then item:DoParam("isRadSuit = TRUE") end
    end
end
Events.OnCreatePlayer.Remove(ParadiseDev.Zones.Radiation.applyRadSuitParams)
Events.OnCreatePlayer.Add(ParadiseDev.Zones.Radiation.applyRadSuitParams)
if not Events.OnSandboxModified then LuaEventManager.AddEvent("OnSandboxModified") end
Events.OnSandboxModified.Remove(ParadiseDev.Zones.Radiation.applyRadSuitParams)
Events.OnSandboxModified.Add(ParadiseDev.Zones.Radiation.applyRadSuitParams)

function ParadiseDev.Zones.Radiation.onPlayerUpdate(pl)
    if pl ~= getPlayer() then return end
    ParadiseDev.Zones.Radiation.tick(pl, getTimestampMs())
end
Events.OnPlayerUpdate.Remove(ParadiseDev.Zones.Radiation.onPlayerUpdate)
Events.OnPlayerUpdate.Add(ParadiseDev.Zones.Radiation.onPlayerUpdate)
