ParadiseEconomy = ParadiseEconomy or {}

function ParadiseEconomy.fillWorldContext(plNum, context)
    local pl = getSpecificPlayer(plNum)
    if not pl or not ParadiseEconomy.OpenPanel or not ParadiseEconomy.MartPanel or not ParadiseEconomy.MartPanel.OpenPanel then return end
    local root = context:addOptionOnTop("Paradise Economy")
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(root, menu)
    menu:addOption("Account and Transactions", nil, ParadiseEconomy.OpenPanel)
    menu:addOption("ParadiseMart", nil, ParadiseEconomy.MartPanel.OpenPanel)
    if ParadiseDev and ParadiseDev.isAdm and ParadiseDev.isAdm(pl) then
        menu:addOption("Admin Accounts", nil, ParadiseEconomy.AdminPanel.OpenPanel)
        menu:addOption("Admin ParadiseMart", nil, ParadiseEconomy.MartAdminPanel.OpenPanel)
    end
end
Events.OnFillWorldObjectContextMenu.Remove(ParadiseEconomy.fillWorldContext)
Events.OnFillWorldObjectContextMenu.Add(ParadiseEconomy.fillWorldContext)
