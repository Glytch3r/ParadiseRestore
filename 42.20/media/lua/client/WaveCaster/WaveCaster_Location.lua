
-- client/WaveCaster_Location.lua
WaveCaster = WaveCaster or {}


function WaveCaster.getXYBldg(x, y)
    if not (x and y) then return end
    for z = 7, 0, -1 do
        --local sq = getCell():getGridSquare(x, y, z) 
        local sq = getCell():getOrCreateGridSquare(x, y, z) 
        local bldg
        if sq then 
            local flr = sq:getFloor() 
            if flr then 
                bldg = sq:getBuilding()
            end
            if bldg then
                local def = bldg:getDef()
                if def then
                    return def
                end
            end
        end
    end
end


-- x and y params could be any x y thats considered part of the bldg
-- we convert the x y to a fixed x y for the data
-- since we need to know if it already has a cast event
function WaveCaster.getBldgMidXY(x, y)
    local def = WaveCaster.getXYBldg(x, y)
    if not def then return end

    local x1 = def:getX()
    local y1 = def:getY()

    local x2 = x1 + def:getW() - 1
    local y2 = y1 + def:getH() - 1

    local centerX = math.floor((x1 + x2) / 2)
    local centerY = math.floor((y1 + y2) / 2)

    return centerX, centerY
end

-- x y from Cast Event Data
function WaveCaster.isCaster(chr, x, y)
    if not chr then return false end
    if not (x and y) then return false end    
    local castBldg = WaveCaster.getXYBldg(x, y)
    if not castBldg then return false end    

    local plX, plY = chr:getX(), chr:getY()
    if not (plX and plY) then return false end

    local casterBldg = WaveCaster.getXYBldg(plX, plY)
    if not casterBldg then return false end    
    return casterBldg == castBldg
end
-----------------------            ---------------------------

function WaveCaster.getClosestPlayerToXY(x, y)
    local closestPl = nil
    local closestDist = nil

    local onlinePlayers = getOnlinePlayers()

    for i = 0, onlinePlayers:size() - 1 do
        local chr = onlinePlayers:get(i)
        if chr then
            local dx = chr:getX() - x
            local dy = chr:getY() - y
            local dist = math.sqrt(dx * dx + dy * dy)

            if not closestDist or dist < closestDist then
                closestDist = dist
                closestPl = chr
            end
        end
    end

    if closestPl then
        if not instanceof(closestPl, "IsoPlayer") then
            if type(closestPl) == "string" then
                closestPl = getPlayerFromUsername(closestPl)
            end
        end
    end

    return closestPl
end
-----------------------            ---------------------------