local H = PZZoneHarness
if H then
    function H.probe()
        sendClientCommand(H.MODULE, "probe", {})
    end
end
