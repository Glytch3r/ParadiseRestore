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

function ParadiseZ.setSpr(obj, targSpr, visualOnly)
    local spr = obj:getSprite()
    if spr then
        local sprName = spr:getName()
        if sprName ~= targSpr then
            obj:setSprite(targSpr)
            obj:getSprite():setName(targSpr)
            obj:setSpriteFromName(targSpr)
            if not visualOnly then getPlayerLoot(0):refreshBackpacks() end
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

-- Spread the existing discovery pass across updates. Never create world squares
-- for a decorative animation. Keep an independent cursor for each local player.
local cursors = setmetatable({}, { __mode = "k" })
function ParadiseZ.sprHandler(pl)
    pl = pl or getPlayer()
    if not pl or not pl:isLocalPlayer() then return end
    local cell = pl:getCell()
    if not cell then return end
    local px, py, pz = math.floor(pl:getX()), math.floor(pl:getY()), math.floor(pl:getZ())
    local cursor = cursors[pl] or 0
    -- 961 positions / 16 callbacks: 61 maximum lookups per callback instead of
    -- a single 961-position burst. Each position is visited once per 16 updates.
    local first = math.floor(cursor * 961 / 16)
    local last = math.floor((cursor + 1) * 961 / 16) - 1
    for index = first, last do
        local dx, dy = math.floor(index / 31) - 15, index % 31 - 15
        local sq = cell:getGridSquare(px + dx, py + dy, pz)
        if sq then
            local objects = sq:getObjects()
            for i = 0, objects:size() - 1 do
                local obj = objects:get(i)
                local name = ParadiseZ.getSprName(obj)
                if name and ParadiseZ.List[name] then
                    local target = "ParadiseTiles_48"
                    if obj.isActivated and obj:isActivated() then
                        local nextFrame = ParadiseZ.Frames[tostring(ParadiseZ.getSprNum(name))]
                        if nextFrame then target = "ParadiseTiles_" .. nextFrame end
                    end
                    if name ~= target then ParadiseZ.setSpr(obj, target, true) end
                end
            end
        end
    end
    cursors[pl] = (cursor + 1) % 16
end
Events.OnPlayerUpdate.Remove(ParadiseZ.sprHandler)
Events.OnPlayerUpdate.Add(ParadiseZ.sprHandler)
