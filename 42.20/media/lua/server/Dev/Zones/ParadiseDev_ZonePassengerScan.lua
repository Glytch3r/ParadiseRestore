ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.PassengerScan = ParadiseDev.Zones.PassengerScan or {}

function ParadiseDev.Zones.PassengerScan.ejectDeniedPassengersOnDriverMove(pl)
    if not ParadiseDev.Zones.Engine or not pl then return end
    local vehicle = pl:getVehicle()
    if not vehicle or vehicle:getCharacter(0) ~= pl then return end

    local x, y, z = vehicle:getX(), vehicle:getY(), pl:getZ()
    local zone, region = ParadiseDev.Zones.Engine.getAuthority(x, y, z)
    if not zone then return end

    local outX, outY = ParadiseDev.Zones.Engine.nearestOutside(region, x, y, 2.0)
    for seat = 1, vehicle:getMaxPassengers() - 1 do
        local passenger = vehicle:getCharacter(seat)
        if passenger and not ParadiseDev.Zones.Engine.isAllowed(zone, passenger) then
            if ParadiseDev.Zones.Engine.forcePassengerOut(passenger, outX, outY, z) then
                ParadiseDev.Zones.Engine.log("passenger-ejected", passenger, zone, "seat=" .. tostring(seat))
            end
        end
    end
end

Events.OnPlayerMove.Remove(ParadiseDev.Zones.PassengerScan.ejectDeniedPassengersOnDriverMove)
Events.OnPlayerMove.Add(ParadiseDev.Zones.PassengerScan.ejectDeniedPassengersOnDriverMove)
