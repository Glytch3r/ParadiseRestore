ParadiseDev = ParadiseDev or {}
ParadiseDev.MediaSpawner = ParadiseDev.MediaSpawner or {}

local mediaSpawner = ParadiseDev.MediaSpawner
mediaSpawner.module = "ParadiseDevMediaSpawn"
mediaSpawner.itemTypes = {
    ["CDs"] = "Base.Disc_Retail",
    ["Retail-VHS"] = "Base.VHS_Retail",
    ["Home-VHS"] = "Base.VHS_Home",
}

function mediaSpawner.getMedia(category, mediaIndex)
    if type(category) ~= "string" or type(mediaIndex) ~= "number" or mediaIndex ~= math.floor(mediaIndex) or not mediaSpawner.itemTypes[category] then return nil end
    local radio = getZomboidRadio and getZomboidRadio() or nil
    local recordedMedia = radio and radio:getRecordedMedia() or nil
    if not recordedMedia then return nil end
    local entries = recordedMedia:getAllMediaForCategory(category)
    for index = 0, entries:size() - 1 do
        local media = entries:get(index)
        if media:getIndexForLua() == mediaIndex then return media end
    end
    return nil
end

function mediaSpawner.spawn(player, args)
    if not ParadiseDev.isAdm(player) or type(args) ~= "table" then return false end
    local media = mediaSpawner.getMedia(args.category, args.mediaIndex)
    local inventory = player:getInventory()
    local item = media and inventory and inventory:AddItem(mediaSpawner.itemTypes[args.category]) or nil
    if not item then return false end
    item:setRecordedMediaData(media)
    sendAddItemToContainer(inventory, item)
    return true
end

function mediaSpawner.onClientCommand(module, command, player, args)
    if module == mediaSpawner.module and command == "spawn" then mediaSpawner.spawn(player, args) end
end

Events.OnClientCommand.Remove(mediaSpawner.onClientCommand)
Events.OnClientCommand.Add(mediaSpawner.onClientCommand)
