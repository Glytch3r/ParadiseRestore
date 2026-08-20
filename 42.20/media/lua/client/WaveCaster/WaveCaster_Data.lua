--client/WaveCaster_Data.lua
WaveCaster = WaveCaster or {}

function WaveCaster.isAdm()
    local pl = getPlayer()
    return ((pl and string.lower(pl:getAccessLevel()) == "admin") or (isClient() and isAdmin())) 
end

function WaveCaster.saveData(data)
    if not data then return end    
	if isClient() then 
		sendClientCommand("WaveCaster", "Sync", {  data = data })
	end	
    if WaveCasterPanel.instance then
        WaveCasterPanel.instance:refreshData()
    end
end

function WaveCaster.DataInit()
    if ModData.exists("WaveCaster_Data") then ModData.remove("WaveCaster_Data"); end
    WaveCaster.Data = ModData.getOrCreate("WaveCaster_Data");
    ModData.request("WaveCaster_Data");
end
Events.OnInitGlobalModData.Add(WaveCaster.DataInit)

function WaveCaster.RecieveData(key, data)

    if key ~= "WaveCaster_Data" then return end
    if data then return end
    if ModData.exists("WaveCaster_Data") then ModData.remove("WaveCaster_Data"); end
    ModData.add("WaveCaster_Data", data) 
    WaveCaster.Data = data
end

Events.OnReceiveGlobalModData.Add(WaveCaster.RecieveData)
-----------------------            ---------------------------
