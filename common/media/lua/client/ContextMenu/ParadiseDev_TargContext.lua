ParadiseDev = ParadiseDev or {}
ParadiseDev.TargContext = ParadiseDev.TargContext or {}

function ParadiseDev.TargContext.getUsername(target)
    if not target then return nil end
    return target.username or (target.getUsername and target:getUsername()) or nil
end

function ParadiseDev.TargContext.resolveTarget(target)
    local username = ParadiseDev.TargContext.getUsername(target)
    return username and getPlayerFromUsername and getPlayerFromUsername(username) or target
end

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

function ParadiseDev.TargContext.isSuspect(target)
    local role = target and target.getRole and target:getRole() or nil
    return role and role.getName and string.lower(tostring(role:getName())) == "suspect" or false
end

function ParadiseDev.TargContext.getPlayerRoleName()
    local roles = getRoles and getRoles() or nil
    if roles then
        for _, wanted in ipairs({ "player", "user", "none" }) do
            for index = 0, roles:size() - 1 do
                local role = roles:get(index)
                if role and string.lower(tostring(role:getName())) == wanted then return role:getName() end
            end
        end
    end
    return "player"
end

function ParadiseDev.TargContext.toggleSuspect(_, target)
    local username = ParadiseDev.TargContext.getUsername(target)
    if not username or not networkUserAction then return end
    local role = ParadiseDev.TargContext.isSuspect(target) and ParadiseDev.TargContext.getPlayerRoleName() or "Suspect"
    networkUserAction("SetRole", username, role)
end

function ParadiseDev.TargContext.toggleCage(_, target)
    if ParadiseDev.Cage and ParadiseDev.Cage.requestToggle then ParadiseDev.Cage.requestToggle(target) end
end

function ParadiseDev.TargContext.setCage(_, username, isCaged)
    if ParadiseDev.Cage and ParadiseDev.Cage.requestSet then
        ParadiseDev.Cage.requestSet(username, isCaged)
    end
end

function ParadiseDev.TargContext.spectate(_, username)
    if ParadiseZ and ParadiseZ.setSpectate then ParadiseZ.setSpectate(username) end
end

function ParadiseDev.TargContext.setPvE(_, username, enabled)
    local syncer = ParadiseDev.TraitSyncer
    if not username or type(enabled) ~= "boolean" or not syncer or not syncer.requestSet then return end
    syncer.requestSet(username, "ParadiseDev:PvE", enabled)
end

function ParadiseDev.TargContext.addPlayerActions(menu, target, localPlayer, includePvE)
    if not menu or not target or not localPlayer then return end
    local username = ParadiseDev.TargContext.getUsername(target)
    if not username then return end
    target = ParadiseDev.TargContext.resolveTarget(target)
    local caged = ParadiseDev.Cage and ParadiseDev.Cage.isTargetCaged and ParadiseDev.Cage.isTargetCaged(target) or false
    -- Keep the displayed action fixed even if a state update arrives before the click.
    local cageOption = menu:addOption((caged and "Uncage: " or "Cage: ") .. username, nil,
        ParadiseDev.TargContext.setCage, username, not caged)
    cageOption.paradiseManagerKey = "Cage"
    cageOption.paradiseManagerLabel = "Cage / Uncage"

    local spectateOption
    if ParadiseZ and ParadiseZ.isSpectating and ParadiseZ.isSpectating(localPlayer) then
        spectateOption = menu:addOption("Stop Spectating", nil, ParadiseZ.stopSpectate)
    elseif username ~= localPlayer:getUsername() and ParadiseZ and ParadiseZ.setSpectate then
        spectateOption = menu:addOption("Spectate: " .. username, nil, ParadiseDev.TargContext.spectate, username)
    end
    if spectateOption then
        spectateOption.paradiseManagerKey = "Spectate"
        spectateOption.paradiseManagerLabel = "Spectate / Stop Spectating"
    end

    if includePvE ~= false then
        local syncer = ParadiseDev.TraitSyncer
        if syncer and syncer.requestMenuState then syncer.requestMenuState() end
        local pve, known
        if syncer and syncer.getTargetPvEState then pve, known = syncer.getTargetPvEState(target) end
        local pveOption
        if known then
            -- Preserve the displayed action if a newer state arrives before click.
            pveOption = menu:addOption((pve and "Disable PvE: " or "Enable PvE: ") .. username, nil,
                ParadiseDev.TargContext.setPvE, username, not pve)
        else
            pveOption = menu:addOption("PvE status loading: " .. username)
            pveOption.notAvailable = true
        end
        pveOption.paradiseManagerKey = "PvE"
        pveOption.paradiseManagerLabel = "Enable / Disable PvE"
    end

    local suspect = ParadiseDev.TargContext.isSuspect(target)
    local suspectOption = menu:addOption((suspect and "Remove Suspect Role: " or "Assign Suspect Role: ") .. username, nil,
        ParadiseDev.TargContext.toggleSuspect, target)
    suspectOption.paradiseManagerKey = "Suspect Role"
    suspectOption.paradiseManagerLabel = "Assign / Remove Suspect Role"
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

    ParadiseDev.TargContext.addPlayerActions(menu, target, localPlayer)
end

function ParadiseDev.TargContext.addWorldContext(plNum, context, worldobjects, test)
    if test or not context or not ParadiseRestore.isAdm() then return end
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
    if ParadiseRestore.ContextMenuManager then
        ParadiseRestore.ContextMenuManager.registerParent("world", "Target Player", context, root, menu, {dynamicLevels = {[1] = true}})
    end
end

Events.OnFillWorldObjectContextMenu.Remove(ParadiseDev.TargContext.addWorldContext)
Events.OnFillWorldObjectContextMenu.Add(ParadiseDev.TargContext.addWorldContext)
