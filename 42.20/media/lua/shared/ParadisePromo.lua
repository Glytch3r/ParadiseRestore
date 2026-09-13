ParadisePromo = ParadisePromo or {}
ParadisePromo.data = ParadisePromo.data or {}

function ParadisePromo.getCodes()
    return ModData.getOrCreate("ParadisePromo_Codes")
end

function ParadisePromo.getRedemptions()
    return ModData.getOrCreate("ParadisePromo_Redemptions")
end

function ParadisePromo.getDailyRedemptions()
    return ModData.getOrCreate("ParadisePromo_DailyRedemptions")
end

function ParadisePromo.getCharacterID(pl)
    local modData = pl:getModData()
    if not modData.ParadisePromoCharID then
        modData.ParadisePromoCharID = tostring(getTimestampMs and getTimestampMs() or os.time()) .. "_" .. tostring(ZombRand(1000000))
    end
    return modData.ParadisePromoCharID
end

function ParadisePromo.parseItems(itemsString)
    local list = {}
    if not itemsString or itemsString == "" then return list end
    for entry in itemsString:gmatch("([^;]+)") do
        local itemType, count = entry:match("^%s*(.-)%s*:%s*(%d+)%s*$")
        count = tonumber(count)
        if itemType and count and count > 0 then
            table.insert(list, { itemType = itemType, count = count })
        end
    end
    return list
end

function ParadisePromo.giveItems(pl, itemsString, randomized)
    local inventory = pl:getInventory()
    if not inventory then return end
    local list = ParadisePromo.parseItems(itemsString)
    if #list == 0 then return end

    if randomized then
        local pick = list[ZombRand(#list) + 1]
        for i = 1, pick.count do
            local item = inventory:AddItem(pick.itemType)
            if ParadiseDev.Inventory and ParadiseDev.Inventory.syncAddedItem then
                ParadiseDev.Inventory.syncAddedItem(inventory, item)
            end
        end
    else
        for _, entry in ipairs(list) do
            for i = 1, entry.count do
                local item = inventory:AddItem(entry.itemType)
                if ParadiseDev.Inventory and ParadiseDev.Inventory.syncAddedItem then
                    ParadiseDev.Inventory.syncAddedItem(inventory, item)
                end
            end
        end
    end
end

function ParadisePromo.canRedeem(pl, code, entry)
    if not entry.active then
        return false, "The code is disabled or expired"
    end
    local username = pl:getUsername()
    if entry.mode == 1 then
        local redemptions = ParadisePromo.getRedemptions()
        redemptions[code] = redemptions[code] or {}
        if redemptions[code][username] then
            return false, "You have already unlocked this code."
        end
        return true
    elseif entry.mode == 2 then
        local redemptions = ParadisePromo.getRedemptions()
        redemptions[code] = redemptions[code] or {}
        local charID = ParadisePromo.getCharacterID(pl)
        local record = redemptions[code][username]
        if record and record.charID == charID then
            return false, "You have already used this code on this character."
        end
        return true
    elseif entry.mode == 3 then
        return true
    elseif entry.mode == 4 then
        local daily = ParadisePromo.getDailyRedemptions()
        daily[code] = daily[code] or {}
        if daily[code][username] then
            return false, "Already used code for the day."
        end
        return true
    end
    return false, "Invalid code mode."
end

function ParadisePromo.recordRedemption(pl, code, entry)
    local username = pl:getUsername()
    if entry.mode == 1 then
        local redemptions = ParadisePromo.getRedemptions()
        redemptions[code] = redemptions[code] or {}
        redemptions[code][username] = { used = true }
    elseif entry.mode == 2 then
        local redemptions = ParadisePromo.getRedemptions()
        redemptions[code] = redemptions[code] or {}
        redemptions[code][username] = { charID = ParadisePromo.getCharacterID(pl) }
    elseif entry.mode == 4 then
        local daily = ParadisePromo.getDailyRedemptions()
        daily[code] = daily[code] or {}
        daily[code][username] = { used = true }
    end
end

function ParadisePromo.resetDailyData()
    local daily = ParadisePromo.getDailyRedemptions()
    for k in pairs(daily) do
        daily[k] = nil
    end
    ModData.transmit("ParadisePromo_DailyRedemptions")
end

function ParadisePromo.OnMidnightCheck()
    if not isServer() then return end
    local gameTime = getGameTime()
    local hour = gameTime:getHour()
    local day = gameTime:getDay() + (gameTime:getMonth() * 100) + (gameTime:getYear() * 10000)
    if hour == 0 then
        if ParadisePromo.midnightLastDay ~= day then
            ParadisePromo.midnightLastDay = day
            ParadisePromo.resetDailyData()
        end
    end
end

Events.EveryHours.Add(ParadisePromo.OnMidnightCheck)

function ParadisePromo.OnClientCommand(module, command, player, args)
    if module ~= "ParadisePromo" then return end

    if command == "requestSync" then
        sendServerCommand(player, "ParadisePromo", "sync", { data = ParadisePromo.getCodes() })

    elseif command == "save" then
        if not ParadiseDev.isAdm(player) then return end
        local codes = ParadisePromo.getCodes()
        codes[args.code] = {
            active = args.active,
            mode = args.mode,
            items = args.items,
            randomized = args.randomized
        }
        ModData.transmit("ParadisePromo_Codes")
        sendServerCommand(player, "ParadisePromo", "sync", { data = codes })

    elseif command == "delete" then
        if not ParadiseDev.isAdm(player) then return end
        local codes = ParadisePromo.getCodes()
        codes[args.code] = nil
        ModData.transmit("ParadisePromo_Codes")
        sendServerCommand(player, "ParadisePromo", "sync", { data = codes })

    elseif command == "redeem" then
        local codes = ParadisePromo.getCodes()
        local code = tostring(args.code or ""):gsub("^%s*(.-)%s*$", "%1")
        local entry = codes[code]
        if not entry then
            sendServerCommand(player, "ParadisePromo", "redeemResult", { success = false, message = "Invalid code." })
            return
        end
        local ok, reason = ParadisePromo.canRedeem(player, code, entry)
        if not ok then
            sendServerCommand(player, "ParadisePromo", "redeemResult", { success = false, message = reason })
            return
        end
        ParadisePromo.giveItems(player, entry.items, entry.randomized)
        ParadisePromo.recordRedemption(player, code, entry)
        sendServerCommand(player, "ParadisePromo", "redeemResult", { success = true, message = "Code redeemed successfully!" })
    end
end

function ParadisePromo.OnServerCommand(module, command, args)
    if module ~= "ParadisePromo" then return end

    if command == "sync" then
        ParadisePromo.data = args.data or {}
        if ParadisePromo.adminInstance then
            ParadisePromo.adminInstance:refreshCodeList()
        end

    elseif command == "redeemResult" then
        if ParadisePromo.playerInstance then
            ParadisePromo.playerInstance:onRedeemResult(args.success, args.message)
        end
        if not args.success then
            local pl = getPlayer()
            if pl then
                pl:setHaloNote(tostring(args.message), 150, 250, 150, 900)
            end
        end
    end
end

Events.OnClientCommand.Add(ParadisePromo.OnClientCommand)
Events.OnServerCommand.Add(ParadisePromo.OnServerCommand)