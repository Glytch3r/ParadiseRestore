require "Dev/ParadiseDev_LifeProfiles"
local M = ParadiseDev.LifeProfiles
M.Store = M.Store or {}
local S = M.Store
S.MAX_FILE_BYTES = 8388608
S.PREFIX = "ParadiseLifeProfiles_v1_"

local function client() return isClient and isClient() end
local function hex(value)
    return (value:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))
end

function S.accountFileKey(key)
    if type(key) ~= "string" or #key == 0 or #key > 96 then return nil, "account key must contain 1 to 96 bytes" end
    return hex(key)
end

local function checksum(value)
    local a, b = 1, 0
    for index = 1, #value do
        a = (a + string.byte(value, index)) % 65521
        b = (b + a) % 65521
    end
    return tostring(a) .. ":" .. tostring(b)
end
S.checksum = checksum

local function encodeValue(value)
    local kind = type(value)
    if kind == "string" then return "S" .. tostring(#value * 2) .. ":" .. hex(value) end
    if kind == "number" then
        -- Kahlua's formatter rounds %.17g to fewer significant digits. Its
        -- numeric tostring uses the round-trippable Java double representation.
        local valueText = tostring(value)
        return "N" .. tostring(#valueText) .. ":" .. valueText
    end
    if kind == "boolean" then return value and "B1;" or "B0;" end
    if kind ~= "table" then error("unsupported serialized value") end
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b)
        if type(a) == type(b) then return a < b end
        return type(a) < type(b)
    end)
    local pieces = { "T" .. tostring(#keys) .. ":" }
    for _, key in ipairs(keys) do
        pieces[#pieces + 1] = encodeValue(key)
        pieces[#pieces + 1] = encodeValue(value[key])
    end
    return table.concat(pieces)
end

function S.encode(value)
    local copied, err = M.copy(value)
    if copied == nil then return nil, err or "nil cannot be serialized" end
    local ok, result = pcall(encodeValue, copied)
    if not ok then return nil, tostring(result) end
    if #result > S.MAX_FILE_BYTES - 256 then return nil, "serialized profile exceeds file limit" end
    return result
end

function S.decode(data)
    if type(data) ~= "string" or #data > S.MAX_FILE_BYTES then return nil, "invalid encoded profile size" end
    local position, nodes, bytes = 1, 0, 0
    local function count()
        local ending = string.find(data, ":", position, true)
        if not ending or ending - position > 12 then error("invalid encoded length") end
        local digits = string.sub(data, position, ending - 1)
        if not digits:match("^%d+$") then error("invalid encoded length") end
        local result = tonumber(digits)
        position = ending + 1
        if not result or result > S.MAX_FILE_BYTES then error("encoded length exceeds limit") end
        return result
    end
    local parse
    parse = function(depth)
        nodes = nodes + 1
        if nodes > M.LIMITS.nodes or depth > M.LIMITS.depth then error("encoded structure exceeds limits") end
        local kind = string.sub(data, position, position)
        position = position + 1
        if kind == "B" then
            local value = string.sub(data, position, position + 1)
            position = position + 2
            if value == "1;" then return true elseif value == "0;" then return false end
            error("invalid encoded boolean")
        end
        if kind == "S" or kind == "N" then
            local length = count()
            if position + length - 1 > #data then error("truncated encoded scalar") end
            local value = string.sub(data, position, position + length - 1)
            position = position + length
            if kind == "N" then
                if length > 32 then error("encoded number is too long") end
                local number = tonumber(value)
                if not number or number ~= number or number <= -math.huge or number >= math.huge then error("invalid encoded number") end
                return number
            end
            if length % 2 ~= 0 or value:find("[^0-9a-f]") then error("invalid encoded string") end
            bytes = bytes + length / 2
            if length / 2 > M.LIMITS.stringBytes or bytes > M.LIMITS.bytes then error("encoded strings exceed limits") end
            return (value:gsub("..", function(pair) return string.char(tonumber(pair, 16)) end))
        elseif kind == "T" then
            local length, result = count(), {}
            if length > M.LIMITS.nodes / 2 then error("encoded table exceeds limits") end
            for _ = 1, length do
                local key = parse(depth + 1)
                if type(key) ~= "number" and type(key) ~= "string" then error("invalid encoded table key") end
                if result[key] ~= nil then error("duplicate encoded table key") end
                result[key] = parse(depth + 1)
            end
            return result
        end
        error("unknown encoded value type")
    end
    local ok, result = pcall(parse, 0)
    if not ok then return nil, tostring(result) end
    if position ~= #data + 1 then return nil, "trailing encoded data" end
    return result
end

local function defaultRead(path)
    if not getFileReader then return nil, "file reader unavailable" end
    local ok, reader = pcall(getFileReader, path, false)
    if not ok then return nil, "reader open failed" end
    if not reader then return nil, "missing" end
    local readOk, first, second = pcall(function() return reader:readLine(), reader:readLine() end)
    local closeOk = pcall(function() reader:close() end)
    if not readOk or not closeOk then return nil, "reader operation failed" end
    if first == nil then return "" end
    if second ~= nil then return nil, "unexpected extra file line" end
    return tostring(first)
end

local function defaultWrite(path, data)
    if not getFileWriter then return nil, "file writer unavailable" end
    local ok, writer = pcall(getFileWriter, path, true, false)
    if not ok or not writer then return nil, "writer open failed" end
    local wrote = pcall(function() writer:write(data) end)
    local closed = pcall(function() writer:close() end)
    if not wrote or not closed then return nil, "writer operation failed" end
    return true
end

-- Injectable only by the server/test harness. Production uses game cache-file APIs.
S.io = S.io or { read = defaultRead, write = defaultWrite }

local function envelope(account)
    local payload, err = S.encode(account)
    if not payload then return nil, err end
    return "PLP1|" .. tostring(account.revision) .. "|" .. tostring(#payload) .. "|" .. checksum(payload) .. "|" .. payload
end

local function unpackFile(raw)
    if type(raw) ~= "string" or #raw > S.MAX_FILE_BYTES then return nil, "invalid file size" end
    local generation, size, expected, payload = raw:match("^PLP1|(%d+)|(%d+)|([0-9]+:[0-9]+)|(.+)$")
    if not payload or tonumber(size) ~= #payload or checksum(payload) ~= expected then return nil, "profile checksum or envelope mismatch" end
    local account, err = S.decode(payload)
    if not account then return nil, err end
    local ok; ok, err = M.validateAccount(account)
    if not ok then return nil, err end
    if account.revision ~= tonumber(generation) then return nil, "profile revision mismatch" end
    return account
end

local function readBank(path)
    local ok, raw, err = pcall(S.io.read, path)
    if not ok then return { error = "read exception" } end
    if raw == nil then return { missing = err == "missing", error = err or "read failed" } end
    local account; account, err = unpackFile(raw)
    return { account = account, raw = raw, error = err }
end

function S.load(key)
    if client() then return nil, "profile store is server-only" end
    local encoded, err = S.accountFileKey(key)
    if not encoded then return nil, err end
    -- B42 getFileWriter only permits ini/cfg/txt/log/json extensions.
    local banks = { A = readBank(S.PREFIX .. encoded .. "_A.txt"), B = readBank(S.PREFIX .. encoded .. "_B.txt") }
    local selected
    if banks.A.account then selected = "A" end
    if banks.B.account then
        if not selected or banks.B.account.revision > banks.A.account.revision then selected = "B"
        elseif banks.B.account.revision == banks.A.account.revision and banks.B.raw ~= banks.A.raw then return nil, "conflicting profile generations" end
    end
    if not selected then
        if banks.A.missing and banks.B.missing then return M.account(), { status = "new", revision = 0 } end
        return nil, "both profile generations unreadable; manual recovery required"
    end
    local other = selected == "A" and "B" or "A"
    local recovered = not banks[other].account and not banks[other].missing
    return banks[selected].account, { status = recovered and "recovered" or "loaded", revision = banks[selected].account.revision, bank = selected, warning = recovered and banks[other].error or nil }
end

function S.save(key, account, expectedRevision)
    if client() then return nil, "profile store is server-only" end
    local ok, err = M.validateAccount(account)
    if not ok then return nil, err end
    local encoded; encoded, err = S.accountFileKey(key)
    if not encoded then return nil, err end
    local current, meta = S.load(key)
    if not current then return nil, meta end
    local raw; raw, err = envelope(account)
    if not raw then return nil, err end
    -- An exact repeated commit is harmless, including after close/readback uncertainty.
    if account.revision == current.revision then
        local previous; previous, err = envelope(current)
        if previous == raw and meta.status ~= "new" then return true, meta end
        return nil, "same revision has different content"
    end
    expectedRevision = expectedRevision == nil and account.revision - 1 or expectedRevision
    if expectedRevision ~= current.revision or account.revision ~= current.revision + 1 then return nil, "profile revision changed; reload before saving" end
    local bank = meta.bank == "A" and "B" or "A"
    local path = S.PREFIX .. encoded .. "_" .. bank .. ".txt"
    local wrote, result, writeError = pcall(S.io.write, path, raw)
    if not wrote or not result then return nil, writeError or "profile write failed" end
    local verified = readBank(path)
    if not verified.account or verified.raw ~= raw then return nil, "profile write readback failed; reload required" end
    -- Close plus readback verifies bytes visible through the game API. There is no
    -- fsync API here; do not represent this as power-loss-proof disk persistence.
    return true, { status = "saved", revision = account.revision, bank = bank, path = path }
end

-- Deletion acknowledgement requires both recovery banks to contain the current
-- post-delete state. Call only after the ordinary revisioned save succeeded.
-- Never replace the sole verified current bank, or create an unsaved revision.
function S.mirrorCurrent(key, account)
    if client() then return nil, "profile store is server-only" end
    local ok, err = M.validateAccount(account)
    if not ok then return nil, err end
    local encoded; encoded, err = S.accountFileKey(key)
    if not encoded then return nil, err end
    local raw; raw, err = envelope(account)
    if not raw then return nil, err end
    local paths = { A = S.PREFIX .. encoded .. "_A.txt", B = S.PREFIX .. encoded .. "_B.txt" }
    local banks = { A = readBank(paths.A), B = readBank(paths.B) }
    local source
    for _, bank in ipairs({"A", "B"}) do
        local value = banks[bank]
        if value.raw == nil and not value.missing then return nil, "Profile recovery bank could not be read; retry deletion verification" end
        if value.account then
            if value.account.revision > account.revision then return nil, "Profile revision changed before deletion verification" end
            if value.account.revision == account.revision and value.raw ~= raw then return nil, "Conflicting profile generation prevents deletion verification" end
            if value.raw == raw then source = source or bank end
        end
    end
    if not source then return nil, "No verified current profile generation; reload before deletion verification" end
    local other = source == "A" and "B" or "A"
    if banks[other].raw ~= raw or not banks[other].account then
        -- Recheck both observations before touching the older/damaged bank.
        -- Lua lifecycle writes are serialized; external edits must fail closed.
        local retained, destination = readBank(paths[source]), readBank(paths[other])
        if not retained.account or retained.raw ~= raw then return nil, "Current profile source changed before deletion verification" end
        local previous = banks[other]
        if destination.raw ~= previous.raw or destination.missing ~= previous.missing or destination.error ~= previous.error then
            return nil, "Profile recovery bank changed before deletion verification"
        end
        local wrote, result, detail = pcall(S.io.write, paths[other], raw)
        if not wrote or not result then return nil, detail or "Profile recovery write failed; retry deletion verification" end
    end
    local verifiedA, verifiedB = readBank(paths.A), readBank(paths.B)
    if not verifiedA.account or not verifiedB.account or verifiedA.raw ~= raw or verifiedB.raw ~= raw then
        return nil, "Both profile recovery banks must verify; retry deletion verification"
    end
    -- Exact close/readback evidence through the cache API, not an fsync promise.
    return true, { status = "mirrored", revision = account.revision, banks = {"A", "B"} }
end

return S
