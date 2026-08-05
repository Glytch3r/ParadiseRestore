----------------------------------------------------------------
-----  ▄▄▄   ▄    ▄   ▄  ▄▄▄▄▄   ▄▄▄   ▄   ▄   ▄▄▄    ▄▄▄  -----
----- █   ▀  █    █▄▄▓█    █    █   ▀  █▄▄▓█  ▀  ▄█  █ ▄▄▀ -----
----- █  ▀█  █      █      █    █   ▄  █   █  ▄   █  █   █ -----
-----  ▀▀▀▀  ▀▀▀▀   ▀      ▀     ▀▀▀   ▀   ▀   ▀▀▀   ▀   ▀ -----
----------------------------------------------------------------
--                                                            --
--   Project Zomboid Modding Commissions                      --
--   https://steamcommunity.com/id/glytch3r/myworkshopfiles   --
--                                                            --
--   ▫ Discord  ꞉   glytch3r                                  --
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

function ParadiseZ.randFloat()
    return ZombRand(0, 101) / 100
end

function ParadiseZ.setTrailingLightMode(activate, pl)
    pl = pl or getPlayer()
    if not pl or not pl:isAlive() then return end
    if string.lower(pl:getAccessLevel()) == "admin" then
        if activate ~= nil then
            pl:getModData().isTrailLight = activate
        end
    end
end

function ParadiseZ.toggleTrailingLightMode(pl)
    pl = pl or getPlayer()
    if not pl or not pl:isAlive() then return end
    if string.lower(pl:getAccessLevel()) ~= "admin" then return end
    local md = pl:getModData()
    local active = not (md.isTrailLight or false)
    md.isTrailLight = active
    if not active then       
        ParadiseZ.delTrail()
    end
    if not md.isTrailLight then
        ParadiseZ.delLamp()
    end
end

function ParadiseZ.isTrailingLightMode(pl)
    pl = pl or getPlayer()
    if not pl or not pl:isAlive() then return end
    local md = pl:getModData()
    md.isTrailLight = md.isTrailLight or false
    return md.isTrailLight
end

ParadiseZ.trailTicks = 0
function ParadiseZ.TrailingLight(pl)
    ParadiseZ.trailTicks = ParadiseZ.trailTicks + 1
    if ParadiseZ.trailTicks % 3 ~= 0 then 
        if not ParadiseZ.isTrailingLightMode(pl) then return end
        if string.lower(pl:getAccessLevel()) == "admin" then 
            ParadiseZ.addLamp()
            local csq = pl:getCurrentSquare()
            if not csq then return end                
            ParadiseZ.addTrail(pl, csq)
        end
       
    end
end
Events.OnPlayerUpdate.Remove(ParadiseZ.TrailingLight)
Events.OnPlayerUpdate.Add(ParadiseZ.TrailingLight)


-----------------------            ---------------------------

function ParadiseZ.delLamp()
    if ParadiseZ.TrailLight then
        getCell():removeLamppost(ParadiseZ.TrailLight)
        ParadiseZ.TrailLight = nil
    end
end

function ParadiseZ.addLamp()
    ParadiseZ.delLamp()
    local pl = getPlayer()
    if not pl then return end
    
    local x, y, z = round(pl:getX()), round(pl:getY()), pl:getZ()
    
    ParadiseZ.TrailLight = IsoLightSource.new(x, y, z, 255, 255, 255, 255)
    getCell():addLamppost(ParadiseZ.TrailLight)
end


-----------------------            ---------------------------

function ParadiseZ.delTrail()   
    if ParadiseZ.TrailingMarker then
        ParadiseZ.TrailingMarker:remove()
        ParadiseZ.TrailingMarker = nil
    end
end

function ParadiseZ.addTrail(pl, csq)
    if not SandboxVars.ParadiseZ.showTrailingMarkers then return end
    pl = pl or getPlayer()
    csq = csq or pl:getCurrentSquare()
    if not csq then return end
    
    ParadiseZ.delTrail()
    local r = ParadiseZ.randFloat()
    ParadiseZ.TrailingMarker = getWorldMarkers():addGridSquareMarker(
        "circle_center", "circle_only_highlight", csq, r, r, r, true, r
    )
end


