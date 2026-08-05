-- Runs after PZZoneEngine_Server.lua.  A driver movement event is the reliable
-- opportunity to inspect only the occupied seats of that vehicle.  This keeps
-- the passenger rule event-driven and avoids depending on passenger movement
-- callbacks or scanning online players.
local E = PZZoneEngine

local function ejectDeniedPassengersOnDriverMove(player)
    if not E or not player then return end
    local vehicle = player:getVehicle()
    if not vehicle or vehicle:getCharacter(0) ~= player then return end

    local x, y, z = vehicle:getX(), vehicle:getY(), player:getZ()
    local zone, region = E.getAuthority(x, y, z)
    if not zone then return end

    local outX, outY = E.nearestOutside(region, x, y, 2.0)
    for seat = 1, vehicle:getMaxPassengers() - 1 do
        local passenger = vehicle:getCharacter(seat)
        if passenger and not E.isAllowed(zone, passenger) then
            if E.forcePassengerOut(passenger, outX, outY, z) then
                E.log("passenger-ejected", passenger, zone, "seat=" .. tostring(seat))
            end
        end
    end
end

Events.OnPlayerMove.Add(ejectDeniedPassengersOnDriverMove)
