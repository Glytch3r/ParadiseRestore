

if ISServerSavingMessage then
    if ISServerSavingMessage.showPauseMessage and ISServerSavingMessage.showSavingFinishMessage then  
        Events.OnServerStartSaving.Remove(ISServerSavingMessage.showPauseMessage);
        Events.OnServerFinishSaving.Remove(ISServerSavingMessage.showSavingFinishMessage);
    end
end
