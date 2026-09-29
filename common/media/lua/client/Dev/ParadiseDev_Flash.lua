ParadiseDev = ParadiseDev or {}
ParadiseDev.Flash = ParadiseDev.Flash or {}

function ParadiseDev.Flash.getRGB(rgb)
    if type(rgb) ~= "table" then return nil end
    local r = tonumber(rgb.r or rgb[1])
    local g = tonumber(rgb.g or rgb[2])
    local b = tonumber(rgb.b or rgb[3])
    if not r or not g or not b then return nil end
    return math.max(0, math.min(1, r)), math.max(0, math.min(1, g)), math.max(0, math.min(1, b))
end

function ParadiseDev.Flash.run(rgb, sec, opacity, pl)
    pl = pl or getPlayer()
    if not pl then return false end
    local r, g, b = ParadiseDev.Flash.getRGB(rgb)
    sec = tonumber(sec)
    opacity = tonumber(opacity) or 0.4
    if not r or not sec or sec <= 0 then return false end
    local md = pl:getModData()
    md.ParadiseDevFlash = {
        rgb = { r, g, b },
        duration = sec,
        remaining = sec,
        opacity = math.max(0, math.min(1, opacity)),
    }
    return true
end

function ParadiseDev.Flash.draw()
    local pl = getPlayer()
    if not pl then return end
    local md = pl:getModData()
    local effect = md.ParadiseDevFlash
    if type(effect) ~= "table" then return end
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local duration = tonumber(effect.duration) or 0
    local remaining = tonumber(effect.remaining) or 0
    local opacity = tonumber(effect.opacity) or 0
    local r, g, b = ParadiseDev.Flash.getRGB(effect.rgb)
    if not r or duration <= 0 or remaining <= 0 then
        md.ParadiseDevFlash = nil
        return
    end
    getRenderer():renderRect(0, 0, sw, sh, r, g, b, math.min(1, opacity * (remaining / duration)))
    effect.remaining = remaining - getGameTime():getRealworldSecondsSinceLastUpdate()
    if effect.remaining <= 0 then md.ParadiseDevFlash = nil end
end

Events.OnPostUIDraw.Remove(ParadiseDev.Flash.draw)
Events.OnPostUIDraw.Add(ParadiseDev.Flash.draw)
