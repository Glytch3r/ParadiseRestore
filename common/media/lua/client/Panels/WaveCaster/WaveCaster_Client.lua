
-- client/WaveCaster_Client.lua
WaveCaster = WaveCaster or {}


function WaveCaster.ClientSync(module, command, args)
    if module ~= "WaveCaster" then return end
    local pl = getPlayer()

    if command == "Sync" and args.data then
        for k, _ in pairs(WaveCaster.Data) do 
            WaveCaster.Data[k] = nil 
        end
        for k, v in pairs(args.data) do
            WaveCaster.Data[k] = v
        end

        if WaveCasterPanel and WaveCasterPanel.instance then
            WaveCasterPanel.instance:refreshWaveList()
        end
    elseif command == "Notify" and args.msg then  
        if not pl then return end
        if not pl:isAlive() then 
            pl:addLineChatElement(tostring(args.msg))
        else
            pl:Say(tostring(args.msg)) 
        end
    end
end
Events.OnServerCommand.Add(WaveCaster.ClientSync)



--[[ 
function WaveCaster.doPenalty(user)
    local pl = nil
    if instanceof(user, "IsoPlayer") then
        pl = user    
    else        
        pl:getBodyDamage():ReduceGeneralHealth(dmg)    
    end
end

 ]]

--[[ 

Events.OnServerCommand.Add(function(module, command, args)
	if Commands[module] and Commands[module][command] then
		Commands[module][command](args)
	end
end)
 ]]