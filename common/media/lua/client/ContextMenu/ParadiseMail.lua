ParadiseRestore = ParadiseRestore or {}
ParadiseMail = ParadiseMail or {}

function ParadiseMail.mailContext(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player or not ParadiseRestore.isAdm or not ParadiseRestore.isAdm(player) then return end
    local selected = {}
    for _, entry in ipairs(items or {}) do
        local item = entry.items and entry.items[1] or entry
        if instanceof(item, "InventoryItem") then selected[#selected + 1] = item end
    end
    if #selected == 0 then return end
    local root = context:addOption("Add to Mail Set", nil, function()
        local added = 0
        for _, item in ipairs(selected) do
            local data = ParadiseEconomy and ParadiseEconomy.ItemData and ParadiseEconomy.ItemData.toData(item)
            if data and ParadiseMail.addCapturedData(data) then added = added + 1 end
        end
        ParadiseMail.halo("Added " .. tostring(added) .. " to mail set")
        if ParadiseMail.adminInstance and ParadiseMail.adminInstance.refreshWorking then
            ParadiseMail.adminInstance:refreshWorking()
        end
    end)
    if ParadiseRestore.ContextMenuManager then
        ParadiseRestore.ContextMenuManager.registerParent("inventory", "Mail", context, root)
    end
end

Events.OnFillInventoryObjectContextMenu.Remove(ParadiseMail.mailContext)
Events.OnFillInventoryObjectContextMenu.Add(ParadiseMail.mailContext)
