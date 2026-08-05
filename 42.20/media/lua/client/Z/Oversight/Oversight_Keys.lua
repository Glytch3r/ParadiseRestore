----------------------------------------------------------------
-----  ▄▄▄   ▄    ▄   ▄  ▄▄▄▄▄   ▄▄▄   ▄   ▄   ▄▄▄    ▄▄▄  -----
----- █   ▀  █    █▄▄▄█    █    █   ▀  █▄▄▄█  ▀  ▄█  █ ▄▄▀ -----
----- █  ▀█  █      █      █    █   ▄  █   █  ▄   █  █   █ -----
-----  ▀▀▀▀  ▀▀▀▀   ▀      ▀     ▀▀▀   ▀   ▀   ▀▀▀   ▀   ▀ -----
----------------------------------------------------------------
--                                                            --
--   Project Zomboid Modding Commissions                      --
--   https://steamcommunity.com/id/glytch3r/myworkshopfiles   --
--                                                            --
--   ▫ Discord  ꞉   glytch3r                                  --
--   ▫ Support  ꞉   https://ko-fi.com/glytch3r                --
--   ▫ Youtube  ꞉   https://www.youtube.com/@glytch3r         --
--   ▫ Github   ꞉   https://github.com/Glytch3r               --
--                                                            --
----------------------------------------------------------------
----- ▄   ▄   ▄▄▄   ▄   ▄   ▄▄▄     ▄      ▄   ▄▄▄▄  ▄▄▄▄  -----
----- █   █  █   ▀  █   █  ▀   █    █      █      █  █▄  █ -----
----- ▄▀▀ █  █▀  ▄  █▀▀▀█  ▄   █    █    █▀▀▀█    █  ▄   █ -----
-----  ▀▀▀    ▀▀▀   ▀   ▀   ▀▀▀   ▀▀▀▀▀  ▀   ▀    ▀   ▀▀▀  -----
----------------------------------------------------------------


ParadiseZ = ParadiseZ or {}

function ParadiseZ.getNextPl(currentPl, forward)
    if not ISMiniScoreboardUI.instance then return nil end
    if not ISMiniScoreboardUI.instance.scoreboard then return nil end
    
    local usernames = ISMiniScoreboardUI.instance.scoreboard.usernames
    if not usernames or usernames:size() == 0 then return nil end
    
    local playerList = {}
    for i = 1, usernames:size() do
        local username = usernames:get(i - 1)
        if username then
            table.insert(playerList, username)
        end
    end
    
    if #playerList == 0 then return nil end
    
    table.sort(playerList, function(a, b) return a < b end)
    
    for i, p in ipairs(playerList) do
        if p == currentPl then
            if forward then
                return playerList[(i % #playerList) + 1]
            else
                return playerList[((i - 2) % #playerList) + 1]
            end
        end
    end
    
    return playerList[1]
end

function ParadiseZ.getPrevPl(currentPl)
    return ParadiseZ.getNextPl(currentPl, false)
end


function ParadiseZ.setSpectateOffset(key)
    local pl = getPlayer()
    if not pl then return key end
    if not ParadiseZ.isSpectating(pl) then return key end

    local md = pl:getModData()
    local off = md.SpectateOffset
    if not off then return key end
    
    local core = getCore()
    local offsetForward = core:getKey("Oversight_OffsetForward")
    local offsetBackward = core:getKey("Oversight_OffsetBackward")
    local offsetLeft = core:getKey("Oversight_OffsetLeft")
    local offsetRight = core:getKey("Oversight_OffsetRight")
    local stopSpectate = core:getKey("Oversight_StopSpectate")
    local offsetUp = core:getKey("Oversight_OffsetUp")
    local offsetDown = core:getKey("Oversight_OffsetDown")
    local selectPrev = core:getKey("Oversight_SelectPrev")
    local selectNext = core:getKey("Oversight_SelectNext")
    local mapKey = core:getKey("Map")

    if key == offsetForward then
        off.y = off.y - 1
    elseif key == offsetBackward then
        off.y = off.y + 1
    elseif key == offsetLeft then
        off.x = off.x - 1
    elseif key == offsetRight then
        off.x = off.x + 1
    elseif key == stopSpectate or key == mapKey then
        md.Spectating = nil
    elseif key == offsetUp then
        off.z = math.min(7, math.max(0, off.z + 1))
    elseif key == offsetDown then
        off.z = math.min(7, math.max(0, off.z - 1))
    elseif key == selectPrev then
        local currentTargetUser = ParadiseZ.getSpectateTargUser(pl)
        if currentTargetUser then
            local prevPl = ParadiseZ.getPrevPl(currentTargetUser)
            if prevPl then
                ParadiseZ.setSpectate(prevPl)
            end
        end
    elseif key == selectNext then
        local currentTargetUser = ParadiseZ.getSpectateTargUser(pl)
        if currentTargetUser then
            local nextPl = ParadiseZ.getNextPl(currentTargetUser, true)
            if nextPl then
                ParadiseZ.setSpectate(nextPl)
            end
        end
    end

    return key
end

Events.OnKeyPressed.Remove(ParadiseZ.setSpectateOffset)
Events.OnKeyPressed.Add(ParadiseZ.setSpectateOffset)
