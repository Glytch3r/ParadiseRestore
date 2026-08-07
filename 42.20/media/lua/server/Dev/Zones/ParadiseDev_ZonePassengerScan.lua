ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.PassengerScan = ParadiseDev.Zones.PassengerScan or {}
local P = ParadiseDev.Zones.PassengerScan
local E = ParadiseDev.Zones.Engine

function P.ejectDeniedPassengersOnDriverMove(player)
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

Events.OnPlayerMove.Add(P.ejectDeniedPassengersOnDriverMove)

