local H = PZZoneHarness
if H then
    function H.enableAdminTesting()
        sendClientCommand(H.MODULE, "disableDemoAdminBypass", {})
    end
end
