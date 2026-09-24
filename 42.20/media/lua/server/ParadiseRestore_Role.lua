ParadiseRestore = ParadiseRestore or {}
function ParadiseRestore.removeAdminCapability()
    if not getRoles or not getCapabilities or not setupRole then return end

    local roles = getRoles()
    local admin

    for i = 0, roles:size() - 1 do
        local role = roles:get(i)
        if role and string.lower(tostring(role:getName())) == "admin" then
            admin = role
            break
        end
    end

    if not admin then return end

    local enabled = {}
    local capabilities = getCapabilities()

    for i = 0, capabilities:size() - 1 do
        local capability = capabilities:get(i)
        local name = tostring(capability:getName())

        if name ~= "ToggleWriteRoleNameAbove" and admin:hasCapability(capability) then
            enabled[capability] = true
        end
    end

    setupRole(
        admin,
        admin:getDescription(),
        admin:getColor(),
        enabled
    )
end
Events.OnServerStarted.Remove(ParadiseRestore.removeAdminCapability)
Events.OnServerStarted.Add(ParadiseRestore.removeAdminCapability)

Events.OnServerStartSaving.Add(ParadiseRestore.removeAdminCapability)