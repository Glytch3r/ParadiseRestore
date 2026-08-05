
-- The flashlight debug teleport now lives in Dev/ParadiseDev_Keys.lua.
-- This compatibility file intentionally registers no key handler, preventing a
-- single flashlight press from running both the legacy direct move and Dev API.

--[[ 


local count = 0
local rad = 80
local pl = getPlayer()
local cell = pl:getCell()
local x, y, z = pl:getX(), pl:getY(), pl:getZ()
for xDelta = -rad, rad do
	for yDelta = -rad, rad do
		local sq = cell:getOrCreateGridSquare(x + xDelta, y + yDelta, z)
        local car = ParadiseZ.pickCar(sq)
        if car then
			local name = car:getScript():getFullName()
			if isClient() then	sendClientCommand(pl, "vehicle", "remove", { vehicle = car:getId() }) end
			car:permanentlyRemove()
			pl:Say('car despawned: '..tostring(name))
			print(car:getId())
		end
	end
end


local whereVar = math.floor(getPlayer():getX()) ..', '.. math.floor(getPlayer():getY()) ..', '.. math.floor(getPlayer():getZ()); Clipboard.setClipboard(whereVar); print('Clipboard Saved: ' ..whereVar) 
]]
