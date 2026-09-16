

local ticks = 0
function windowsOfDeathPatch(pl)
    ticks = ticks + 1
    if ticks % 3 ~= 0 then return end

    local rad = 5
    local cell = pl:getCell()
    local x, y, z = pl:getX(), pl:getY(), pl:getZ()

    for xDelta = -rad, rad do
        for yDelta = -rad, rad do
            local sq = cell:getOrCreateGridSquare(x + xDelta, y + yDelta, z)
            if sq then
                for i = 0, sq:getObjects():size() - 1 do
                    local obj = sq:getObjects():get(i)
                    if not obj or not obj.getSprite then return end
                
                    local spr = obj:getSprite()
                    if spr then
                        local sprName = spr:getName()
                        if sprName and string.lower(sprName) == 'walls_commercial_01_33' or string.lower(sprName) == 'walls_commercial_01_32' then
                            obj:setSmashed(true)
                        end
                    end
                end
            end
        end
    end
end
Events.OnPlayerUpdate.Remove(windowsOfDeathPatch)
--Events.OnPlayerUpdate.Add(windowsOfDeathPatch)
