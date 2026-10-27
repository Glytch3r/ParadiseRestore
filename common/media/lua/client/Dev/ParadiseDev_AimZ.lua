require "Dev/ParadiseDev_PvEPolicy"
require "Dev/ParadiseDev_PvPNet"
require "Dev/ParadiseDev_PvP"
require "TimedActions/ISReloadWeaponAction"

ParadiseDev = ParadiseDev or {}
ParadiseDev.AimZ = ParadiseDev.AimZ or {}
local AZ = ParadiseDev.AimZ

function AZ.isB41()
    return getCore():getGameVersion():getMajor() == 41
end
if AZ.isB41() then return end

AZ.step = 0
AZ.binds = nil
AZ.hijacked = false
AZ.corridor = 0.45
AZ.sample = 0.25
AZ.overshoot = 2.0
AZ.maxTiles = 60
AZ.minTiles = 0.75
AZ.resolveMs = 150
AZ.dropMs = 500
AZ.pending = nil

function AZ.getOption(key, fallback)
    local pvp = SandboxVars and SandboxVars.ParadiseZpvp or {}
    return tonumber(pvp[key]) or fallback
end

function AZ.getMax()
    return math.max(0, math.min(4, math.floor(AZ.getOption("AimZMax", 2) + 0.5)))
end

function AZ.sightRequired()
    local pvp = SandboxVars and SandboxVars.ParadiseZpvp
    return not pvp or pvp.AimZRequireSight ~= false
end

function AZ.isFirearm(wpn)
    return ParadiseDev.PvPNet.isFirearm(wpn)
end

function AZ.levelOf(pl)
    return ParadiseDev.PvPNet.level(pl) + AZ.step
end

function AZ.aiming(pl)
    if not pl or not pl.isAiming or not pl:isAiming() then return false end
    return AZ.isFirearm(pl:getPrimaryHandItem())
end

function AZ.findBind(id)
    if not keyBinding then return nil end
    for index = 1, #keyBinding do
        local bind = keyBinding[index]
        if bind and tostring(bind.value) == id then return bind end
    end
    return nil
end

function AZ.bindIds()
    local ids = {}
    if not KeybindId then return ids end
    if KeybindId.ZOOM_IN then ids[#ids + 1] = tostring(KeybindId.ZOOM_IN:getId()) end
    if KeybindId.ZOOM_OUT then ids[#ids + 1] = tostring(KeybindId.ZOOM_OUT:getId()) end
    return ids
end

function AZ.encodeBinds(binds)
    local parts = {}
    for index = 1, #binds do
        local bind = binds[index]
        parts[#parts + 1] = table.concat({
            tostring(bind.id), tostring(tonumber(bind.key) or 0), tostring(tonumber(bind.alt) or 0),
            bind.shift and 1 or 0, bind.ctrl and 1 or 0, bind.altMod and 1 or 0,
        }, ",")
    end
    return table.concat(parts, ";")
end

function AZ.decodeBinds(str)
    local binds = {}
    if type(str) ~= "string" then return binds end
    for entry in str:gmatch("[^;]+") do
        local id, key, alt, shift, ctrl, altMod = entry:match("([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+)")
        if id then
            binds[#binds + 1] = {
                id = id,
                key = tonumber(key) or 0,
                alt = tonumber(alt) or 0,
                shift = shift == "1",
                ctrl = ctrl == "1",
                altMod = altMod == "1",
            }
        end
    end
    return binds
end

function AZ.apply(bind)
    getCore():addKeyBinding(bind.id, bind.key, bind.alt, bind.shift, bind.ctrl, bind.altMod)
end

function AZ.stash(pl, binds)
    if not pl then return end
    pl:getModData().ParadiseAimZBinds = AZ.encodeBinds(binds)
end

function AZ.unstash(pl)
    if not pl then return end
    pl:getModData().ParadiseAimZBinds = nil
end

function AZ.recover()
    if AZ.hijacked then return end
    local pl = getPlayer()
    if not pl then return end
    local stale = AZ.decodeBinds(pl:getModData().ParadiseAimZBinds)
    if #stale == 0 then return end
    for index = 1, #stale do AZ.apply(stale[index]) end
    AZ.unstash(pl)
    print("[ParadiseDev.AimZ] restored zoom bindings after interrupted aim")
end

function AZ.hijack()
    if AZ.hijacked then return end
    local ids = AZ.bindIds()
    if #ids == 0 then return end
    local binds = {}
    for index = 1, #ids do
        local id = ids[index]
        local key = getCore():getKey(id)
        local alt = getCore():getAltKey(id)
        if key ~= 0 or alt ~= 0 then
            local bind = AZ.findBind(id)
            binds[#binds + 1] = {
                id = id,
                key = key,
                alt = alt,
                shift = bind and bind.shift == true or false,
                ctrl = bind and bind.ctrl == true or false,
                altMod = bind and bind.altKey == true or false,
            }
        end
    end
    if #binds == 0 then return end
    for index = 1, #binds do
        getCore():addKeyBinding(binds[index].id, 0, 0, false, false, false)
    end
    AZ.binds = binds
    AZ.hijacked = true
    AZ.stash(getPlayer(), binds)
end

function AZ.release()
    if not AZ.hijacked then
        AZ.step = 0
        return
    end
    for index = 1, #AZ.binds do AZ.apply(AZ.binds[index]) end
    AZ.binds = nil
    AZ.hijacked = false
    AZ.step = 0
    AZ.unstash(getPlayer())
end

function AZ.tick()
    if not isIngameState() then AZ.release() return end
    AZ.recover()
end
Events.OnTick.Remove(AZ.tick)
Events.OnTick.Add(AZ.tick)

function AZ.setStep(step)
    local max = AZ.getMax()
    AZ.step = math.max(-max, math.min(max, step))
end

function AZ.onKeyStart(key)
    if not AZ.hijacked or not key or key == 0 then return end
    for index = 1, #AZ.binds do
        local bind = AZ.binds[index]
        if key == bind.key or (bind.alt ~= 0 and key == bind.alt) then
            AZ.setStep(AZ.step + (index == 1 and 1 or -1))
            return
        end
    end
end
Events.OnKeyStartPressed.Remove(AZ.onKeyStart)
Events.OnKeyStartPressed.Add(AZ.onKeyStart)

function AZ.track(pl)
    if pl ~= getPlayer() then return end
    AZ.resolvePending()
    if AZ.aiming(pl) then
        if not AZ.hijacked then AZ.hijack() end
        return
    end
    AZ.release()
end
Events.OnPlayerUpdate.Remove(AZ.track)
Events.OnPlayerUpdate.Add(AZ.track)

function AZ.draw()
    if not AZ.hijacked then return end
    local pl = getPlayer()
    if not pl then return end
    local sign = AZ.step > 0 and "+" .. tostring(AZ.step) or tostring(AZ.step)
    local str = "Aim Z " .. sign .. "   level " .. tostring(AZ.levelOf(pl))
    getTextManager():DrawString(UIFont.Small, getMouseX() + 20, getMouseY() - 12, str, 1, 0.85, 0.25, 0.95)
end
Events.OnPostUIDraw.Remove(AZ.draw)
Events.OnPostUIDraw.Add(AZ.draw)

function AZ.aimWorld(pl, level)
    local wx, wy = ISCoordConversion.ToWorld(getMouseXScaled(), getMouseYScaled(), level)
    if not wx or not wy then return nil, nil end
    return tonumber(wx), tonumber(wy)
end

function AZ.blocked(pl, x, y, level)
    local sq = getCell():getGridSquare(x, y, level)
    if not sq then return true end
    if AZ.sightRequired() and not sq:isCanSee(pl:getPlayerNum()) then return true end
    return false
end

function AZ.candidates(pl, ux, uy, level, limit)
    local result = {}
    local players = getOnlinePlayers()
    if not players then return result end
    for index = 0, players:size() - 1 do
        local cand = players:get(index)
        if cand and cand ~= pl and cand:isAlive() and ParadiseDev.PvPNet.canAttack(pl, cand)
            and ParadiseDev.PvPNet.level(cand) == level then
            local dx, dy = cand:getX() - pl:getX(), cand:getY() - pl:getY()
            local along = dx * ux + dy * uy
            local perp = math.abs(dx * uy - dy * ux)
            if along > AZ.minTiles and along <= limit and perp <= AZ.corridor then
                result[#result + 1] = { pl = cand, t = along }
            end
        end
    end
    table.sort(result, function(left, right) return left.t < right.t end)
    return result
end

function AZ.project(pl, level)
    local ox, oy = pl:getX(), pl:getY()
    local wx, wy = AZ.aimWorld(pl, level)
    if not wx then return nil end
    local dx, dy = wx - ox, wy - oy
    local total = math.sqrt(dx * dx + dy * dy)
    if total < 0.1 then return nil end
    local ux, uy = dx / total, dy / total
    local limit = math.min(total + AZ.overshoot, AZ.maxTiles)
    local list = AZ.candidates(pl, ux, uy, level, limit)
    local entry = list[1]
    if not entry then return nil end
    local probe = AZ.minTiles
    while probe < entry.t do
        if AZ.blocked(pl, ox + ux * probe, oy + uy * probe, level) then return nil end
        probe = probe + AZ.sample
    end
    if AZ.blocked(pl, ox + ux * entry.t, oy + uy * entry.t, level) then return nil end
    return entry.pl, entry.t
end

function AZ.beginPending(pl)
    AZ.pending = {
        pl = pl,
        level = AZ.levelOf(pl),
        critical = pl:isCriticalHit() == true,
        stamp = ParadiseDev.PvPNet.now(),
    }
end

function AZ.resolvePending()
    local pend = AZ.pending
    if not pend then return end
    local elapsed = ParadiseDev.PvPNet.now() - pend.stamp
    if elapsed < AZ.resolveMs then return end
    AZ.pending = nil
    if elapsed > AZ.dropMs then return end
    if not pend.pl or pend.pl:isDead() then return end
    local victim = AZ.project(pend.pl, pend.level)
    if not victim then return end
    ParadiseDev.PvPNet.sendHit(pend.pl, victim, pend.level, pend.critical)
end

function AZ.swing(pl, wpn)
    if not pl or pl ~= getPlayer() or AZ.step == 0 then return end
    if not AZ.isFirearm(wpn) or not ISReloadWeaponAction.canShoot(wpn) then return end
    AZ.beginPending(pl)
end
Events.OnWeaponSwing.Remove(AZ.swing)
Events.OnWeaponSwing.Add(AZ.swing)

function AZ.hit(char, targ, wpn)
    if not char or char ~= getPlayer() or not targ then return end
    if not instanceof(targ, "IsoPlayer") or not AZ.isFirearm(wpn) then return end
    if ParadiseDev.PvEPolicy.isProtected(char) then return end
    if not ParadiseDev.PvEPolicy.isProtected(targ) then
        AZ.pending = nil
        return
    end
    if AZ.step ~= 0 then return end
    local level = AZ.levelOf(char)
    local victim = AZ.project(char, level)
    if not victim then return end
    ParadiseDev.PvPNet.sendHit(char, victim, level, char:isCriticalHit())
end
Events.OnWeaponHitCharacter.Remove(AZ.hit)
Events.OnWeaponHitCharacter.Add(AZ.hit)

function AZ.debug()
    print("[ParadiseDev.AimZ] step=" .. tostring(AZ.step) .. " max=" .. tostring(AZ.getMax())
        .. " level=" .. tostring(getPlayer() and AZ.levelOf(getPlayer()) or "n/a")
        .. " hijacked=" .. tostring(AZ.hijacked) .. " sight=" .. tostring(AZ.sightRequired()))
    return AZ.step
end

function AZ.testScan()
    local pl = getPlayer()
    if not pl then
        print("[ParadiseDev.AimZ] no local player")
        return nil
    end
    local level = AZ.levelOf(pl)
    local victim, dist = AZ.project(pl, level)
    print("[ParadiseDev.AimZ] scan level=" .. tostring(level) .. " hit=" .. (victim
        and (ParadiseDev.PvPNet.user(victim) .. " @" .. tostring(math.floor(dist * 10) / 10) .. " tiles")
        or "none"))
    return victim
end
