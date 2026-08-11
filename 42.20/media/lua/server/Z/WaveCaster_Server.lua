
--server/WaveCaster_Server.lua

WaveCaster = WaveCaster or {}

if isClient() then return end

function WaveCaster.init()
    WaveCaster.Data = ModData.getOrCreate("WaveCaster_Data")
end
Events.OnInitGlobalModData.Add(WaveCaster.init)

function WaveCaster.transmit()
    ModData.transmit("WaveCaster_Data")
end

function WaveCaster.updateEvents(module, command, player, args)
    if module ~= "WaveCaster" then return end

    if command == "Sync" and args.data then
        WaveCaster.Data = ModData.getOrCreate("WaveCaster_Data")

        for k in pairs(WaveCaster.Data) do
            WaveCaster.Data[k] = nil
        end

        for k, v in pairs(args.data) do
            WaveCaster.Data[k] = v
        end
        ModData.transmit("WaveCaster_Data")
        sendServerCommand("WaveCaster", "Sync", { data = WaveCaster.Data })
    end
end
Events.OnClientCommand.Add(WaveCaster.updateEvents)
