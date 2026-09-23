ParadiseDev = ParadiseDev or {}
ParadiseDev.TargContext = ParadiseDev.TargContext or {}

function ParadiseDev.TargContext.getSquare(worldobjects)
    if ISWorldObjectContextMenu and ISWorldObjectContextMenu.fetchVars then
        local square = ISWorldObjectContextMenu.fetchVars.clickedSquare
        if square then return square end
    end
    if clickedSquare then return clickedSquare end
    for _, object in ipairs(worldobjects or {}) do
        if object and object.getSquare then
            local square = object:getSquare()
            if square then return square end
        end
    end
    return nil
end

function ParadiseDev.TargContext.getPlayers(square, radius)
    local players = {}
    local seen = {}
    local cell = getCell and getCell() or nil
    if not square or not cell then return players end
    radius = radius or 2
    for dx = -radius, radius do
        for dy = -radius, radius do
            if dx * dx + dy * dy <= radius * radius then
                local nearby = cell:getGridSquare(square:getX() + dx, square:getY() + dy, square:getZ())
                local moving = nearby and nearby:getMovingObjects() or nil
                if moving then
                    for index = 0, moving:size() - 1 do
                        local object = moving:get(index)
                        if object and instanceof(object, "IsoPlayer") and object.getUsername and not seen[object] then
                            seen[object] = true
                            players[#players + 1] = object
                        end
                    end
                end
            end
        end
    end
    table.sort(players, function(left, right)
        return string.lower(tostring(left:getUsername())) < string.lower(tostring(right:getUsername()))
    end)
    return players
end

function ParadiseDev.TargContext.setSuspect(target)
    if not target or not target.getUsername or not networkUserAction then return end
    networkUserAction("SetRole", target:getUsername(), "Suspect")
end

function ParadiseDev.TargContext.setCage(_, target, isCaged)
    if not target or not target.getUsername then return end
    local username = target:getUsername()
    if ParadiseDev.Cage and ParadiseDev.Cage.requestSet then
        ParadiseDev.Cage.requestSet(username, isCaged)
    end
end

function ParadiseDev.TargContext.spectate(_, username)
    if ParadiseZ and ParadiseZ.setSpectate then ParadiseZ.setSpectate(username) end
end
--[[ 
        ISPlayerStatsUI.instance.char:getCharacterTraits():add(trait:getType());
        ISPlayerStatsUI.instance.char:modifyTraitXPBoost(trait:getType(), false);
        SyncXp(ISPlayerStatsUI.instance.char);
        ISPlayerStatsUI.instance:loadTraits();
 ]]
function ParadiseDev.TargContext.addPlayerMenu(context, target, localPlayer)
    local username = target:getUsername()
    local root = context:addOption(username)
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(root, menu)

    if ParadiseDev.TraitSyncer then
        ParadiseDev.TraitSyncer.addTargetMenu(menu, target)
    end
    if ParadiseDev.Cage then
        local isCaged = ParadiseDev.Cage.isTargetCaged and ParadiseDev.Cage.isTargetCaged(target)
        if ParadiseDev.Cage.requestSet then
            menu:addOption(isCaged and "Uncage" or "Cage", nil, ParadiseDev.TargContext.setCage, target, not isCaged)
        end
    end

    if ParadiseZ and ParadiseZ.setSpectate then
        local spectate = menu:addOption("Spectate", nil, ParadiseDev.TargContext.spectate, username)
        if username == localPlayer:getUsername() then spectate.notAvailable = true end
    elseif ParadiseZ and ParadiseZ.isSpectating and ParadiseZ.isSpectating(localPlayer) and ParadiseZ.stopSpectate then
        menu:addOption("Stop Spectating", nil, ParadiseZ.stopSpectate)
    end

    if networkUserAction then
        menu:addOption("Set Suspect Role", nil, ParadiseDev.TargContext.setSuspect, target)
    end

    if ParadiseCloner and ParadiseCloner.addTargetOption then ParadiseCloner.addTargetOption(menu, target) end

    if ParadiseBan and ParadiseBan.addTargetMenu then
        ParadiseBan.addTargetMenu(menu, target, localPlayer)
    end
end

function ParadiseDev.TargContext.addWorldContext(plNum, context, worldobjects, test)
    if test or not context or not ParadiseDev.isAdm() then return end
    local localPlayer = getSpecificPlayer(plNum)
    if not localPlayer then return end
    local square = ParadiseDev.TargContext.getSquare(worldobjects)
    local players = ParadiseDev.TargContext.getPlayers(square, 2)
    if #players == 0 then return end

    local root = context:addOption("Target Player")
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(root, menu)
    for _, target in ipairs(players) do
        ParadiseDev.TargContext.addPlayerMenu(menu, target, localPlayer)
    end
end

Events.OnFillWorldObjectContextMenu.Remove(ParadiseDev.TargContext.addWorldContext)
Events.OnFillWorldObjectContextMenu.Add(ParadiseDev.TargContext.addWorldContext)
