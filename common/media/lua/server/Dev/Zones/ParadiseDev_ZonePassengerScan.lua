ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.PassengerScan = ParadiseDev.Zones.PassengerScan or {}

function ParadiseDev.Zones.PassengerScan.ejectDeniedPassengersOnDriverMove(pl)
    if not ParadiseDev.Zones.Engine or not pl then return end
    local vehicle = pl:getVehicle()
    if not vehicle or vehicle:getCharacter(0) ~= pl then return end

    local x, y, z = vehicle:getX(), vehicle:getY(), pl:getZ()
    local zone, region = ParadiseDev.Zones.Engine.getAuthority(x, y, z, 2.0)
    if not zone or not ParadiseDev.Zones.Engine.isAllowed(zone, pl) then return end

    for seat = 1, vehicle:getMaxPassengers() - 1 do
        local passenger = vehicle:getCharacter(seat)
        if passenger and not ParadiseDev.Zones.Engine.isAllowed(zone, passenger) then
            -- This helper rechecks both permissions and the current seat immediately
            -- before exit; the driver's denial always moves the car as a unit.
            ParadiseDev.Zones.Engine.ejectBoundaryPassenger(passenger, vehicle, zone, region, x, y, z)
        end
    end
end
