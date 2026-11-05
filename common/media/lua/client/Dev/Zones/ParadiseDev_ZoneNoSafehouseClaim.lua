if getCore():getGameVersion():getMajor() == 41 then return end
require "Dev/Zones/ParadiseDev_ZoneNoSafehouse"
ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.NoSafeClaim = ParadiseDev.Zones.NoSafeClaim or {}
local Claim = ParadiseDev.Zones.NoSafeClaim

Claim.takeHook = Claim.takeHook or ISWorldObjectContextMenu.onTakeSafeHouse

function Claim.buildingBounds(square)
    local building = square and square:getBuilding() or nil
    local def = building and building:getDef() or nil
    if not def then return nil end
    return tonumber(def:getX()), tonumber(def:getY()), tonumber(def:getX2()), tonumber(def:getY2())
end

function Claim.inNoCampZone(square)
    local NoSafe = ParadiseDev.Zones.NoSafe
    local xMin, yMin, xMax, yMax = Claim.buildingBounds(square)
    if not xMin then return nil end
    local zones = nil
    if isClient and isClient() then
        zones = ParadiseDev.Zones.Border and ParadiseDev.Zones.Border.zones or nil
    else
        zones = ParadiseDev.Zones.Engine and ParadiseDev.Zones.Engine.zones or nil
    end
    if not zones then return nil end
    for _, zone in pairs(zones) do
        if NoSafe.isNoSafeZone(zone) then
            for _, region in ipairs(zone.regions or {}) do
                if xMin < region.xMax and region.xMin < xMax
                    and yMin < region.yMax and region.yMin < yMax then
                    return zone
                end
            end
        end
    end
    return nil
end

function Claim.onTakeSafeHouse(worldobjects, square, player)
    local zone = Claim.inNoCampZone(square)
    if zone then
        local pl = getSpecificPlayer and getSpecificPlayer(player) or (getPlayer and getPlayer() or nil)
        if pl then
            pl:setHaloNote("You cannot claim a safehouse inside the NoCamp zone \"" ..
                tostring(zone.name or zone.id) .. "\"", 250, 0, 0, 300)
        end
        return
    end
    return Claim.takeHook(worldobjects, square, player)
end
ISWorldObjectContextMenu.onTakeSafeHouse = Claim.onTakeSafeHouse

function Claim.debugClaim(square, pl)
    pl = pl or (getPlayer and getPlayer() or nil)
    square = square or (pl and pl:getCurrentSquare() or nil)
    if not pl or not square then return "no player or square" end
    local building = square:getBuilding()
    if not building or not building:getDef() then return "square has no building" end
    if Claim.inNoCampZone(square) then return "BLOCKED by NoCamp zone" end
    sendSafehouseClaim(square, pl, pl:getUsername())
    return "claim sent at " .. tostring(square:getX()) .. "," .. tostring(square:getY())
end
