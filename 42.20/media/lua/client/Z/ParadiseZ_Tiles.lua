----------------------------------------------------------------
-----  ▄▄▄   ▄    ▄   ▄  ▄▄▄▄▄   ▄▄▄   ▄   ▄   ▄▄▄    ▄▄▄  -----
----- █   ▀  █    █▄▄▄█    █    █   ▀  █▄▄▄█  ▀  ▄█  █ ▄▄▀ -----
----- █  ▀█  █      █      █    █   ▄  █   █  ▄   █  █   █ -----
-----  ▀▀▀▀  ▀▀▀▀   ▀      ▀     ▀▀▀   ▀   ▀   ▀▀▀   ▀   ▀ -----
----------------------------------------------------------------
--                                                            --
--   Project Zomboid Modding Commissions                      --
--   https://steamcommunity.com/id/glytch3r/myworkshopfiles   --
--                                                            --

--   ▫ Support  ꞉   https://ko-fi.com/glytch3r                --
--   ▫ Youtube  ꞉   https://www.youtube.com/@glytch3r         --
--   ▫ Github   ꞉   https://github.com/Glytch3r               --
--                                                            --
----------------------------------------------------------------
----- ▄   ▄   ▄▄▄   ▄   ▄   ▄▄▄     ▄      ▄   ▄▄▄▄  ▄▄▄▄  -----
----- █   █  █   ▀  █   █  ▀   █    █      █      █  █▄  █ -----
----- ▄▀▀ █  █▀  ▄  █▀▀▀█  ▄   █    █    █▀▀▀█    █  ▄   █ -----
-----  ▀▀▀    ▀▀▀   ▀   ▀   ▀▀▀   ▀▀▀▀▀  ▀   ▀    ▀   ▀▀▀  -----
----------------------------------------------------------------
require "lua_timers"

ParadiseZ = ParadiseZ or {}

ParadiseZ.List = {
   ["ParadiseTiles_48"]=true,
   ["ParadiseTiles_49"]=true,
   ["ParadiseTiles_50"]=true,
   ["ParadiseTiles_51"]=true,
}

ParadiseZ.Frames = {  
   ["48"]="49",
   ["49"]="50",
   ["50"]="51",
   ["51"]="49",
}


function ParadiseZ.getRandFloat()
    return ZombRand(0, 101)/100
end


function ParadiseZ.getSpr(obj)
    if not obj or not obj.getSprite then return nil end
    return obj:getSprite()
end

function ParadiseZ.getSprName(obj)
    local spr = ParadiseZ.getSpr(obj)
    return spr and spr:getName() or nil
end

function ParadiseZ.getSprNum(sprName)
    if not sprName then return nil end
    local num = sprName:match("(%d+)$")
    return tonumber(num)
end

function ParadiseZ.isSpr(obj, prefix)
    local sprName = ParadiseZ.getSprName(obj)
    if not sprName then return false end
    return prefix and luautils.stringStarts(sprName, prefix) or false
end

function ParadiseZ.setSpr(obj, targSpr)
    local spr = obj:getSprite()
    if spr then
        local sprName = spr:getName()
        if sprName ~= targSpr then
            obj:setSprite(targSpr)
            obj:getSprite():setName(targSpr)
            obj:setSpriteFromName(targSpr)
            getPlayerLoot(0):refreshBackpacks()
        end
    end
end


function ParadiseZ.getSprObj(sq, prefix)
    if not sq then return nil end
    for i = 0, sq:getObjects():size() - 1 do
        local obj = sq:getObjects():get(i)
        if ParadiseZ.isSpr(obj, prefix) then
            return obj
        end
    end
    return nil
end

local ticks = 0
function ParadiseZ.sprHandler(pl)
    pl = pl or getPlayer()
    local rad = 15
    local cell = pl:getCell()
    local px, py, pz = pl:getX(), pl:getY(), pl:getZ()

    ticks = ticks + 1
    if ticks % 16 ~= 0 then return end

    for xDelta = -rad, rad do
        for yDelta = -rad, rad do
            local sq = cell:getOrCreateGridSquare(px + xDelta, py + yDelta, pz)
            if sq then
                for i = 0, sq:getObjects():size() - 1 do
                    local obj = sq:getObjects():get(i)
                    if obj and ParadiseZ.isSpr(obj, "ParadiseTiles") then
                        local sprName = ParadiseZ.getSprName(obj)
                        if sprName and ParadiseZ.List[sprName] then
                            local sprNum = ParadiseZ.getSprNum(sprName)
                            if sprNum then
                                if obj and obj.isActivated and obj:isActivated() then
                                    local nextSprNum = ParadiseZ.Frames[tostring(sprNum)]
                                    if nextSprNum then
                                        ParadiseZ.setSpr(obj, "ParadiseTiles_" .. nextSprNum)
                                    end
                                else
                                    if sprNum ~= 48 then
                                        ParadiseZ.setSpr(obj, "ParadiseTiles_48")
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end
Events.OnPlayerUpdate.Remove(ParadiseZ.sprHandler)
Events.OnPlayerUpdate.Add(ParadiseZ.sprHandler)
