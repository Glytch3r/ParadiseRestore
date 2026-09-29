ParadiseDev = ParadiseDev or {}
ParadiseDev.PreyZed = ParadiseDev.PreyZed or {}

function ParadiseDev.PreyZed.huntHandler(zed)
    if not zed or not ParadiseDev.PreyZed.isPrey or not ParadiseDev.PreyZed.isPrey(zed) then return end
    local pl = getPlayer()
    if not pl or not zed.getAttackedBy or zed:getAttackedBy() ~= pl then return end
    local sq = zed:getSquare()
    if not sq or not ParadiseDev.PreyZed.isHuntZoneAt(sq:getX(), sq:getY(), sq:getZ()) then return end
    if ParadiseDev.TheRange and ParadiseDev.TheRange.requestPreyReward then ParadiseDev.TheRange.requestPreyReward(zed) end
end

Events.OnZombieDead.Remove(ParadiseDev.PreyZed.huntHandler)
Events.OnZombieDead.Add(ParadiseDev.PreyZed.huntHandler)
