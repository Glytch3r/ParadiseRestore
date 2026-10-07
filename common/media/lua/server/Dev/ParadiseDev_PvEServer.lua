-- The server directory is also loaded by multiplayer clients.
if isClient and isClient() then return end
require "Dev/ParadiseDev_PvEPolicy"
local Policy=ParadiseDev.PvEPolicy
local lastRefresh
if Policy.refreshOnlinePlayers then Events.OnTick.Remove(Policy.refreshOnlinePlayers) end
function Policy.refreshOnlinePlayers()
    local now=getTimestampMs()
    if lastRefresh and now >= lastRefresh and now-lastRefresh < 250 then return end
    lastRefresh=now
    if not Policy.publishZones() then return end
    local players=getOnlinePlayers and getOnlinePlayers() or nil
    if players then
        for index=0,players:size()-1 do Policy.refreshPlayer(players:get(index)) end
    elseif getPlayer then
        Policy.refreshPlayer(getPlayer())
    end
end
Events.OnTick.Remove(Policy.refreshOnlinePlayers)
Events.OnTick.Add(Policy.refreshOnlinePlayers)
Events.OnServerStarted.Remove(Policy.publishZones)
Events.OnServerStarted.Add(Policy.publishZones)
