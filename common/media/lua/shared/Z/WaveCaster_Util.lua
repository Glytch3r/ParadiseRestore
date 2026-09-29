WaveCaster = WaveCaster or {}
function WaveCaster.CloneData(t1, t2)
    if not t1 or not t2 then return end
    
    for key, value in pairs(t2) do
        t1[key] = value
    end
    for key, _ in pairs(t1) do
        if not t2[key] then
            t1[key] = nil
        end
    end
end

function WaveCaster.checkDist(chr, x, y)
    if not chr or not (x and y) then return end
    if not (x and y) then return end

    local dx = chr:getX() - x
    local dy = chr:getY() - y
    return round(math.sqrt(dx * dx + dy * dy))
end
