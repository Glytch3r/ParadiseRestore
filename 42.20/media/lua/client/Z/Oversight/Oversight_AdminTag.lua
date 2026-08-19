
ParadiseZ = ParadiseZ or {} 

function ParadiseZ.hideAdminTag(pl)
    pl = pl or getPlayer()
    if not pl or pl ~= getPlayer() then return end
    local showAdminTag = not ParadiseZ.isHideAdminTag(pl)
    if pl:isShowAdminTag() == showAdminTag then return end
    pl:setShowAdminTag(showAdminTag)
    if isClient() then sendPlayerExtraInfo(pl) end
end
Events.OnPlayerUpdate.Remove(ParadiseZ.hideAdminTag)
Events.OnPlayerUpdate.Add(ParadiseZ.hideAdminTag)

function ParadiseZ.isHideAdminTag(pl)
    pl = pl or getPlayer()
    if not pl or not pl:isAlive() then return end
    local md = pl:getModData()
    md.isHideAdminTag = md.isHideAdminTag or false
    return md.isHideAdminTag
end

function ParadiseZ.setHideAdminTag(activate, pl)
    pl = pl or getPlayer()
    if not pl or not pl:isAlive() then return end
    if ParadiseDev.isAdm() then
        if activate ~= nil then
            pl:getModData().isHideAdminTag = activate
            ParadiseZ.hideAdminTag(pl)
        end
    end
end

function ParadiseZ.toggleHideAdminTag(pl, activate)
    pl = pl or getPlayer()
    if not pl or not pl:isAlive() then return end
    if not ParadiseDev.isAdm() then return end
    local md = pl:getModData()
    if activate ~= nil then
        md.isHideAdminTag = activate
    else
        md.isHideAdminTag = not (md.isHideAdminTag or false)
    end
    ParadiseZ.hideAdminTag(pl)
end
