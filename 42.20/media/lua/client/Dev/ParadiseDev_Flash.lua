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

function ParadiseDev.Flash.draw()
    local pl = getPlayer()
    if not pl then return end
    local md = pl:getModData()
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()

    for key, effect in pairs(md) do
        if type(effect) == "table" then
            local decay = tonumber(effect.decay)
            local opacity = tonumber(effect.opacity)
            local r, g, b = ParadiseDev.Flash.getRGB(effect.rgb)
            if decay and opacity and r then
                if opacity > 0 then
                    getRenderer():renderRect(0, 0, sw, sh, r, g, b, math.min(1, opacity))
                    effect.opacity = opacity - math.max(0, decay)
                end
                if effect.opacity <= 0 then md[key] = nil end
            end
        end
    end
end

Events.OnPostUIDraw.Remove(ParadiseDev.Flash.draw)
Events.OnPostUIDraw.Add(ParadiseDev.Flash.draw)
