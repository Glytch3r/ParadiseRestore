ParadiseRestore = ParadiseRestore or {}

function ParadiseRestore.getRolesCapability(role)
    if type(role) == "string" and getRoles then
        local wanted = string.lower(role)
        local roles = getRoles()
        for index = 0, roles:size() - 1 do
            local candidate = roles:get(index)
            if candidate and string.lower(tostring(candidate:getName())) == wanted then
                role = candidate
                break
            end
        end
    end
    if not role then return { error = "Role not found" } end

    local result = {
        Role = role.getName and role:getName() or tostring(role),
        Description = role.getDescription and role:getDescription() or "",
        Capabilities = {},
    }
    if getCapabilities then
        local capabilities = getCapabilities()
        for index = 0, capabilities:size() - 1 do
            local capability = capabilities:get(index)
            local name = capability and capability.getName and capability:getName() or tostring(capability)
            result.Capabilities[name] = role.hasCapability and role:hasCapability(capability) == true or false
        end
    end
    return result
end

if isServer and isServer() then
    local function hasAnyCapability(role)
        if not role or not getCapabilities then return false end
        local capabilities = getCapabilities()
        for index = 0, capabilities:size() - 1 do
            if role:hasCapability(capabilities:get(index)) then return true end
        end
        return false
    end

    local function getDefaultPlayerCapabilities()
        if not getRoles or not getCapabilities then return {} end
        local roles = getRoles()
        local playerRole = nil
        for index = 0, roles:size() - 1 do
            local role = roles:get(index)
            local name = role and role:getName() or ""
            if string.lower(name) == "player" or string.lower(name) == "user" or string.lower(name) == "none" then
                playerRole = role
                break
            end
        end
        if not playerRole then return {} end
        local capabilities = {}
        local allCapabilities = getCapabilities()
        for index = 0, allCapabilities:size() - 1 do
            local capability = allCapabilities:get(index)
            if playerRole:hasCapability(capability) then capabilities[capability] = true end
        end
        return capabilities
    end

    local function setupParadiseRoles()
        if not addRole or not getRoles or not setupRole then return end
        local roles = getRoles()
        local suspect, admin
        for index = 0, roles:size() - 1 do
            local role = roles:get(index)
            local name = role and string.lower(tostring(role:getName())) or ""
            if name == "suspect" then suspect = role end
            if name == "admin" then admin = role end
        end
        if not suspect then
            addRole("Suspect")
            roles = getRoles()
            for index = 0, roles:size() - 1 do
                local role = roles:get(index)
                if role and string.lower(tostring(role:getName())) == "suspect" then suspect = role break end
            end
        end
        if suspect and not hasAnyCapability(suspect) then
            setupRole(suspect, "", Color.new(1, 0, 0, 1), getDefaultPlayerCapabilities())
        end
        if not admin or not getCapabilities then return end
        local capabilities = {}
        local allCapabilities = getCapabilities()
        for index = 0, allCapabilities:size() - 1 do
            local capability = allCapabilities:get(index)
            if admin:hasCapability(capability) then capabilities[capability] = true end
        end
        capabilities[Capability.ToggleWriteRoleNameAbove] = nil
        setupRole(admin, admin:getDescription(), admin:getColor(), capabilities)

        local staff = nil
        for index = 0, roles:size() - 1 do
            local role = roles:get(index)
            if role and string.lower(tostring(role:getName())) == "staff" then staff = role break end
        end
        if not staff then
            addRole("Staff")
            roles = getRoles()
            for index = 0, roles:size() - 1 do
                local role = roles:get(index)
                if role and string.lower(tostring(role:getName())) == "staff" then staff = role break end
            end
        end
        if staff then
            local staffCapabilities = {
                LoginOnServer = true, PriorityLogin = true, CantBeKickedIfTooLaggy = true,
                ToggleGodModHimself = true, ToggleInvisibleHimself = true, ToggleInvincibleHimself = true,
                ToggleNoclipHimself = true, SeePlayersConnected = true, TeleportToPlayer = true,
                TeleportToCoordinates = true, CanGoInsideSafehouses = true, CanAlwaysJoinServer = true,
                CanSeeMessageForAdmin = true, CantBeKickedByAnticheat = true, CantBeBannedByAnticheat = true,
                SeeWorldMap = true, TeleportPlayerToAnotherPlayer = true, KickUser = true,
                AdminChat = true, EditMapSymbols = true, CanSetupSafehouses = true,
                CanSetupNonPVPZone = true, AnswerTickets = true, UseMechanicsCheat = true,
                GeneralCheats = true, GetSteamScoreboard = true, GetStatistic = true,
                ReadUserLog = true, AddUserlog = true, InspectPlayerInventory = true,
                CanSeeAll = true,
            }
            local enabled = {}
            local allCapabilities = getCapabilities()
            for index = 0, allCapabilities:size() - 1 do
                local capability = allCapabilities:get(index)
                local name = capability.getName and capability:getName() or tostring(capability)
                if staffCapabilities[name] then enabled[capability] = true end
            end
            setupRole(staff, "A member of the Jim's Paradise staff", Color.new(0.9, 0.25, 0.05, 1), enabled)
        end
    end

    Events.OnServerStarted.Remove(setupParadiseRoles)
    Events.OnServerStarted.Add(setupParadiseRoles)
end
