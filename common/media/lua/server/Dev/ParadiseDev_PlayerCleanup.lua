if isClient() then return end

require "ParadiseDev_PlayerCleanup"

ParadiseDev = ParadiseDev or {}
ParadiseDev.PlayerCleanup = ParadiseDev.PlayerCleanup or {}

local cleanup = ParadiseDev.PlayerCleanup

cleanup.session = cleanup.session or {}

function cleanup.now()
    return getTimestampMs and getTimestampMs() or 0
end

function cleanup.store()
    local store = ModData.getOrCreate(cleanup.storeName)
    store.accounts = store.accounts or {}
    store.config = store.config or { inactiveDays = cleanup.defaultInactiveDays, accountDays = cleanup.defaultAccountDays }
    store.config.inactiveDays = cleanup.normalizeDays(store.config.inactiveDays, cleanup.defaultInactiveDays)
    store.config.accountDays = cleanup.normalizeDays(store.config.accountDays, cleanup.defaultAccountDays)
    return store
end

function cleanup.isSteamMode()
    return getSteamModeActive and getSteamModeActive() or false
end

function cleanup.username(pl)
    if not pl or not pl.getUsername then return nil end
    return cleanup.isValidName(pl:getUsername())
end

function cleanup.steamId(pl)
    if not pl or not pl.getSteamID then return nil end
    local id = tostring(pl:getSteamID())
    if id == "" or id == "0" then return nil end
    return id
end

function cleanup.accessLevel(pl)
    if not pl or not pl.getAccessLevel then return "" end
    return tostring(pl:getAccessLevel() or "")
end

function cleanup.senderKey(pl)
    return cleanup.lowerName(cleanup.username(pl))
end

function cleanup.record(pl)
    local username = cleanup.username(pl)
    if not username then return nil end
    local steamId = cleanup.isSteamMode() and cleanup.steamId(pl) or nil
    local key = cleanup.rosterKey(username, steamId)
    if not key then return nil end
    local store = cleanup.store()
    local now = cleanup.now()
    local entry = store.accounts[key]
    if not entry then
        entry = { username = username, steamId = steamId or "", firstSeenMs = now, lastSeenMs = now, adminLevel = "" }
        store.accounts[key] = entry
    end
    entry.username = username
    entry.steamId = steamId or entry.steamId or ""
    entry.firstSeenMs = tonumber(entry.firstSeenMs) or now
    if tonumber(entry.firstSeenMs) <= 0 then entry.firstSeenMs = now end
    entry.lastSeenMs = now
    entry.adminLevel = cleanup.accessLevel(pl)
    return entry, key
end

function cleanup.onCreatePlayer(_, pl)
    cleanup.record(pl)
end
Events.OnCreatePlayer.Remove(cleanup.onCreatePlayer)
Events.OnCreatePlayer.Add(cleanup.onCreatePlayer)

function cleanup.touchAll()
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players then return end
    for index = 0, players:size() - 1 do cleanup.record(players:get(index)) end
end
Events.EveryOneMinute.Remove(cleanup.touchAll)
Events.EveryOneMinute.Add(cleanup.touchAll)

function cleanup.getOnlineNames()
    local names = {}
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players then return names end
    for index = 0, players:size() - 1 do
        local name = cleanup.username(players:get(index))
        if name then names[cleanup.lowerName(name)] = true end
    end
    return names
end

function cleanup.findRosterEntry(store, username, steamId)
    local key = cleanup.rosterKey(username, steamId)
    if key and store.accounts[key] then return store.accounts[key] end
    local userKey = "username:" .. cleanup.lowerName(username)
    if store.accounts[userKey] then return store.accounts[userKey] end
    for _, entry in pairs(store.accounts) do
        if cleanup.lowerName(entry.username) == cleanup.lowerName(username) then return entry end
    end
    return nil
end

function cleanup.getAccounts(store)
    local list = {}
    for key, entry in pairs(store.accounts) do
        list[#list + 1] = {
            key = key,
            username = tostring(entry.username or ""),
            steamId = tostring(entry.steamId or ""),
            firstSeenMs = tonumber(entry.firstSeenMs) or 0,
            lastSeenMs = tonumber(entry.lastSeenMs) or 0,
            adminLevel = tostring(entry.adminLevel or ""),
        }
    end
    return list
end

function cleanup.getPlaytime()
    local store = ModData.getOrCreate(cleanup.auditStore)
    local list, seen = {}, {}
    for _, profile in pairs(store.profiles or {}) do
        local name = cleanup.isValidName(profile.username)
        if name and not seen[cleanup.lowerName(name)] then
            seen[cleanup.lowerName(name)] = true
            list[#list + 1] = { username = name, seconds = tonumber(profile.seconds) or 0 }
        end
    end
    for name, seconds in pairs(store.seconds or {}) do
        local user = cleanup.isValidName(name)
        if user and not seen[cleanup.lowerName(user)] then
            seen[cleanup.lowerName(user)] = true
            list[#list + 1] = { username = user, seconds = tonumber(seconds) or 0 }
        end
    end
    return list
end

function cleanup.getSession(pl)
    return { deletes = tonumber(cleanup.session[cleanup.senderKey(pl)]) or 0, max = cleanup.maxSessionDeletes }
end

function cleanup.sendState(pl)
    if not pl then return end
    local store = cleanup.store()
    sendServerCommand(pl, cleanup.module, "state", {
        nowMs = cleanup.now(),
        todayDays = cleanup.todayDays(),
        world = cleanup.getWorldName(),
        config = {
            inactiveDays = store.config.inactiveDays,
            accountDays = store.config.accountDays,
        },
        accounts = cleanup.getAccounts(store),
        playtime = cleanup.getPlaytime(),
        session = cleanup.getSession(pl),
    })
end

function cleanup.onSetConfig(pl, args)
    local store = cleanup.store()
    store.config.inactiveDays = cleanup.normalizeDays(args and args.inactiveDays, store.config.inactiveDays)
    store.config.accountDays = cleanup.normalizeDays(args and args.accountDays, store.config.accountDays)
    cleanup.sendState(pl)
end

function cleanup.todayDays()
    return cleanup.parseConnection(os.date("%Y-%m-%d")) or 0
end

function cleanup.getWorldName()
    return tostring(getServerName and getServerName() or "")
end

function cleanup.candidatePaths()
    local world = cleanup.getWorldName()
    if world == "" then return nil end
    local paths, tried = {}, {}
    local names = { world }
    if sanitizeWorldName then names[#names + 1] = tostring(sanitizeWorldName(world)) end
    if getCurrentSaveName then names[#names + 1] = tostring(getCurrentSaveName()) end
    for _, name in ipairs(names) do
        if name ~= "" and not tried[name] then
            tried[name] = true
            paths[#paths + 1] = { saveDir = "Multiplayer/" .. name, world = world }
            paths[#paths + 1] = { saveDir = name, world = world }
        end
    end
    return paths
end

function cleanup.existsInDatabase(saveDir, username, world)
    if not checkPlayerExistsInDatabase then return false end
    local ok, exists = pcall(checkPlayerExistsInDatabase, saveDir, username, world)
    return ok and exists == true
end

function cleanup.resolvePath(username)
    local paths = cleanup.candidatePaths()
    if not paths then return nil end
    for _, path in ipairs(paths) do
        if cleanup.existsInDatabase(path.saveDir, username, path.world) then return path end
    end
    return nil
end

function cleanup.describeAccount(username)
    local store = ModData.getOrCreate(cleanup.economyStore)
    local detail = { accounts = {}, listings = 0 }
    local key = cleanup.lowerName(username)
    if not store.accounts then return detail end
    if store.personalIndex then
        local id = store.personalIndex[key]
        if id and store.accounts[id] then detail.accounts[#detail.accounts + 1] = store.accounts[id] end
    end
    for indexKey, id in pairs(store.merchantIndex or {}) do
        if tostring(indexKey):sub(-(string.len(key) + 1)) == ("|" .. key) and store.accounts[id] then
            detail.accounts[#detail.accounts + 1] = store.accounts[id]
        end
    end
    for _, listing in ipairs(store.market and store.market.playerListings or {}) do
        if cleanup.lowerName(listing.seller) == key then detail.listings = detail.listings + 1 end
    end
    return detail
end

function cleanup.purgeEconomy(username)
    local store = ModData.getOrCreate(cleanup.economyStore)
    local removed = 0
    local key = cleanup.lowerName(username)
    if not store.accounts then return removed end
    local personal = store.personalIndex and store.personalIndex[key] or nil
    if personal then
        if store.accounts[personal] then store.accounts[personal] = nil end
        store.personalIndex[key] = nil
        removed = removed + 1
    end
    for indexKey, id in pairs(store.merchantIndex or {}) do
        if tostring(indexKey):sub(-(string.len(key) + 1)) == ("|" .. key) then
            if store.accounts[id] then store.accounts[id] = nil end
            store.merchantIndex[indexKey] = nil
            removed = removed + 1
        end
    end
    if store.addressBooks and store.addressBooks[key] then
        store.addressBooks[key] = nil
        removed = removed + 1
    end
    return removed
end

function cleanup.purgeRecords(username, steamId)
    local removed = 0
    local key = cleanup.lowerName(username)
    local cage = ModData.getOrCreate(cleanup.cageStore)
    for _, name in ipairs({ "players", "names", "pending", "pendingNames", "released" }) do
        local tab = cage[name]
        if tab then
            if steamId and tab["steam:" .. tostring(steamId)] then tab["steam:" .. tostring(steamId)] = nil; removed = removed + 1 end
            if tab[key] then tab[key] = nil; removed = removed + 1 end
            if tab[tostring(username)] then tab[tostring(username)] = nil; removed = removed + 1 end
        end
    end
    for cageKey, entry in pairs(cage.players or {}) do
        if type(entry) == "table" and cleanup.lowerName(entry.username) == key then
            cage.players[cageKey] = nil
            removed = removed + 1
        end
    end
    local audit = ModData.getOrCreate(cleanup.auditStore)
    for name in pairs(audit.seconds or {}) do
        if cleanup.lowerName(name) == key then audit.seconds[name] = nil; removed = removed + 1 end
    end
    for auditKey, profile in pairs(audit.profiles or {}) do
        if cleanup.lowerName(profile.username) == key then audit.profiles[auditKey] = nil; removed = removed + 1 end
    end
    local store = cleanup.store()
    for rosterKey, entry in pairs(store.accounts) do
        if cleanup.lowerName(entry.username) == key then store.accounts[rosterKey] = nil; removed = removed + 1 end
    end
    return removed
end

function cleanup.scanSafehouses(username)
    local entries = {}
    local list = SafeHouse and SafeHouse.getSafehouseList and SafeHouse.getSafehouseList() or nil
    if not list then return entries end
    local key = cleanup.lowerName(username)
    for index = 0, list:size() - 1 do
        local house = list:get(index)
        if house then
            local players = house:getPlayers()
            local others, member = 0, false
            if players then
                for p = 0, players:size() - 1 do
                    local name = tostring(players:get(p) or "")
                    if cleanup.lowerName(name) == key then member = true
                    elseif name ~= "" then others = others + 1 end
                end
            end
            local owner = cleanup.lowerName(house:getOwner()) == key
            if owner or member then
                entries[#entries + 1] = {
                    house = house,
                    players = players,
                    title = tostring(house:getTitle()),
                    isOwner = owner,
                    others = others,
                    key = key,
                }
            end
        end
    end
    return entries
end

function cleanup.applySafehouses(entries)
    local removed, coOwned = {}, {}
    for int = #entries, 1, -1 do
        local entry = entries[int]
        if entry.isOwner then
            if entry.others == 0 then
                SafeHouse.removeSafeHouse(entry.house)
                removed[#removed + 1] = entry.title
            else
                coOwned[#coOwned + 1] = entry.title
            end
        elseif entry.players then
            for p = entry.players:size() - 1, 0, -1 do
                local name = tostring(entry.players:get(p) or "")
                if cleanup.lowerName(name) == entry.key then entry.house:removePlayer(name) end
            end
            removed[#removed + 1] = entry.title .. " (member)"
        end
    end
    return removed, coOwned
end

function cleanup.writeManifest(lines)
    if not getFileWriter then return false end
    local path = cleanup.logDir .. "/" .. os.date("%Y-%m-%d") .. ".log"
    local ok, writer = pcall(getFileWriter, path, true, true)
    if not ok or not writer then return false end
    for _, line in ipairs(lines) do writer:write(tostring(line) .. "\n") end
    writer:close()
    return true
end

function cleanup.formatManifest(admin, target, entry, config, opts, detail, houses, coOwned, path)
    local lines = {
        "[PlayerCleanup]|time:" .. tostring(os.date("%Y-%m-%d %H:%M:%S")),
        "  admin:" .. tostring(admin),
        "  user:" .. tostring(target.username),
        "  steam:" .. tostring(target.steamId or (entry and entry.steamId) or ""),
        "  lastConnection:" .. tostring(target.lastConnection or ""),
        "  knownSince:" .. cleanup.formatDate(entry and entry.firstSeenMs or 0),
        "  lastSeen:" .. cleanup.formatDate(entry and entry.lastSeenMs or 0),
        "  level:" .. tostring(entry and entry.adminLevel or ""),
        "  playSeconds:" .. tostring(math.floor(tonumber(target.playSeconds) or 0)),
        "  thresholds:" .. tostring(config.inactiveDays) .. "/" .. tostring(config.accountDays),
        "  purge:" .. tostring(opts.purgeEconomy and "E" or "-") .. tostring(opts.purgeRecords and "R" or "-") .. tostring(opts.purgeSafehouses and "S" or "-"),
        "  dbPath:" .. tostring(path.saveDir) .. "|" .. tostring(path.world),
        "  economyAccounts:" .. tostring(#detail.accounts),
        "  marketListings:" .. tostring(detail.listings or 0),
    }
    for _, account in ipairs(detail.accounts) do
        local digital = account.digital or {}
        lines[#lines + 1] = "    account:" .. tostring(account.id) .. " title:" .. tostring(account.title or account.type)
            .. " jimoleon:" .. tostring(digital.jimoleon or 0) .. " paradisium:" .. tostring(digital.paradisium or 0)
    end
    for _, title in ipairs(houses) do lines[#lines + 1] = "    safehouseRemoved:" .. title end
    for _, title in ipairs(coOwned) do lines[#lines + 1] = "    safehouseCoOwned:" .. title end
    return lines
end

function cleanup.checkTarget(sender, target, config, opts, store, online, todayDays, now)
    local name = cleanup.isValidName(target.username)
    if not name then return false, "invalid username" end
    if cleanup.lowerName(name) == cleanup.lowerName(cleanup.username(sender)) then return false, "own account" end
    if online[cleanup.lowerName(name)] then return false, "online now" end
    local entry = cleanup.findRosterEntry(store, name, target.steamId)
    if opts.protectAdmins and entry and cleanup.isProtectedLevel(entry.adminLevel) then
        return false, "recorded level " .. tostring(entry.adminLevel)
    end
    local last = cleanup.parseConnection(target.lastConnection)
    if last and (todayDays - last) < config.inactiveDays then
        return false, "inactive " .. tostring(todayDays - last) .. "d under " .. tostring(config.inactiveDays) .. "d"
    end
    local seenDays = entry and cleanup.msToDays(now - (tonumber(entry.lastSeenMs) or now)) or nil
    if entry and tonumber(entry.lastSeenMs) and tonumber(entry.lastSeenMs) > 0 then
        if seenDays < config.inactiveDays then return false, "server saw them " .. tostring(seenDays) .. "d ago" end
    elseif not last then
        return false, "no inactivity proof"
    end
    local firstSeen = entry and tonumber(entry.firstSeenMs) or 0
    if firstSeen > 0 then
        local ageDays = math.floor((now - firstSeen) / cleanup.dayMs)
        if ageDays < config.accountDays then return false, "account " .. tostring(ageDays) .. "d under " .. tostring(config.accountDays) .. "d" end
    elseif not opts.allowUnknownAge then
        return false, "account age unknown"
    end
    return true, entry, name
end

function cleanup.predictSafehouses(entries)
    local removed, coOwned = {}, {}
    for _, entry in ipairs(entries) do
        if entry.isOwner then
            if entry.others == 0 then removed[#removed + 1] = entry.title
            else coOwned[#coOwned + 1] = entry.title .. " (co-owners kept)" end
        else
            removed[#removed + 1] = entry.title .. " (member)"
        end
    end
    return removed, coOwned
end

function cleanup.deleteTarget(sender, target, config, opts, store, online, todayDays, now)
    local ok, reasonOrEntry, name = cleanup.checkTarget(sender, target, config, opts, store, online, todayDays, now)
    if not ok then return { username = tostring(target.username or ""), status = "skipped", reason = reasonOrEntry } end
    local entry = reasonOrEntry
    target.username = name
    local path = cleanup.resolvePath(name)
    if not path then return { username = name, status = "skipped", reason = "not in this world database" } end
    local used = tonumber(cleanup.session[cleanup.senderKey(sender)]) or 0
    if used >= cleanup.maxSessionDeletes then
        return { username = name, status = "skipped", reason = "session limit " .. tostring(cleanup.maxSessionDeletes) }
    end
    local detail = cleanup.describeAccount(name)
    local scan = opts.purgeSafehouses and cleanup.scanSafehouses(name) or {}
    local houses, coOwned = cleanup.predictSafehouses(scan)
    if not cleanup.writeManifest(cleanup.formatManifest(cleanup.username(sender), target, entry, config, opts, detail, houses, coOwned, path)) then
        return { username = name, status = "skipped", reason = "manifest write failed, nothing deleted" }
    end
    if opts.purgeSafehouses then cleanup.applySafehouses(scan) end
    if opts.purgeEconomy then cleanup.purgeEconomy(name) end
    if opts.purgeRecords then cleanup.purgeRecords(name, target.steamId or (entry and entry.steamId) or "") end
    if deletePlayerFromDatabase then pcall(deletePlayerFromDatabase, path.saveDir, name, path.world) end
    cleanup.session[cleanup.senderKey(sender)] = used + 1
    if cleanup.existsInDatabase(path.saveDir, name, path.world) then
        return { username = name, status = "partial", reason = "database row remains" }
    end
    return { username = name, status = "deleted", reason = "" }
end

function cleanup.getOpts(args)
    local purge = args and args.purge or {}
    local opts = args and args.opts or {}
    return {
        purgeEconomy = purge.economy == true,
        purgeRecords = purge.records == true,
        purgeSafehouses = purge.safehouses == true,
        protectAdmins = opts.ignoreAdminProtect ~= true,
        allowUnknownAge = opts.allowUnknownAge ~= false,
    }
end

function cleanup.performDeletes(pl, args)
    local store = cleanup.store()
    local config = { inactiveDays = store.config.inactiveDays, accountDays = store.config.accountDays }
    if args and args.config then
        config.inactiveDays = cleanup.normalizeDays(args.config.inactiveDays, config.inactiveDays)
        config.accountDays = cleanup.normalizeDays(args.config.accountDays, config.accountDays)
    end
    local opts = cleanup.getOpts(args)
    local online = cleanup.getOnlineNames()
    local todayDays, now = cleanup.todayDays(), cleanup.now()
    local results = {}
    for _, target in ipairs(args and args.targets or {}) do
        if #results >= cleanup.maxRequestTargets then
            results[#results + 1] = { username = "(request cap)", status = "skipped", reason = "too many targets" }
            break
        end
        if type(target) == "table" then
            results[#results + 1] = cleanup.deleteTarget(pl, target, config, opts, store, online, todayDays, now)
        end
    end
    sendServerCommand(pl, cleanup.module, "results", { results = results, session = cleanup.getSession(pl) })
    cleanup.sendState(pl)
end

function cleanup.onClientCommand(module, command, pl, args)
    if module ~= cleanup.module then return end
    if not ParadiseRestore or not ParadiseRestore.isAdm or not ParadiseRestore.isAdm(pl) then return end
    if command == "requestState" then cleanup.sendState(pl); return end
    if command == "setConfig" then cleanup.onSetConfig(pl, args); return end
    if command == "delete" then cleanup.performDeletes(pl, args); return end
end
Events.OnClientCommand.Remove(cleanup.onClientCommand)
Events.OnClientCommand.Add(cleanup.onClientCommand)
