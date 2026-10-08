-- Pure, bounded profile state machine. Callers persist returned copies before applying them.
require "Dev/ParadiseDev_LifeStartingOutfit"
ParadiseDev = ParadiseDev or {}
ParadiseDev.LifeProfiles = ParadiseDev.LifeProfiles or {}
local M = ParadiseDev.LifeProfiles
local O = ParadiseDev.LifeStartingOutfit
M.VERSION = 1
M.module = "ParadiseLifeProfiles"
M.MAX_SLOTS = 32
M.LIMITS = { depth = 16, nodes = 60000, bytes = 2097152, stringBytes = 131072 }

local function finite(n) return type(n) == "number" and n == n and n > -math.huge and n < math.huge end
local function integer(n, lo, hi) return finite(n) and n == math.floor(n) and n >= lo and n <= hi end
local function text(s, max) return type(s) == "string" and #s > 0 and #s <= (max or 256) end
local function copyValue(value, depth, seen, budget)
    budget.nodes = budget.nodes + 1
    if budget.nodes > M.LIMITS.nodes or depth > M.LIMITS.depth then error("profile data exceeds structural limits") end
    local kind = type(value)
    if kind == "string" then
        budget.bytes = budget.bytes + #value
        if #value > M.LIMITS.stringBytes or budget.bytes > M.LIMITS.bytes then error("profile data exceeds byte limits") end
        return value
    elseif kind == "number" then
        if not finite(value) then error("profile data contains non-finite number") end
        return value
    elseif kind == "boolean" or kind == "nil" then
        return value
    elseif kind ~= "table" then
        error("profile data contains unsupported " .. kind)
    end
    if seen[value] then error("profile data contains a cycle") end
    seen[value] = true
    local result = {}
    for key, item in pairs(value) do
        if type(key) ~= "string" and type(key) ~= "number" then error("profile table key is not string or number") end
        local nextKey = copyValue(key, depth + 1, seen, budget)
        result[nextKey] = copyValue(item, depth + 1, seen, budget)
    end
    seen[value] = nil
    return result
end

function M.copy(value)
    local ok, result = pcall(copyValue, value, 0, {}, { nodes = 0, bytes = 0 })
    if not ok then return nil, tostring(result) end
    return result
end

local function xpMap(skills)
    if type(skills) ~= "table" then return nil, "skills must be a table" end
    local count = 0
    for key, value in pairs(skills) do
        count = count + 1
        if count > 2048 or not text(key, 256) or not finite(value) or value < 0 or value > 1e12 then
            return nil, "invalid skill XP"
        end
    end
    return true
end

function M.validateSnapshot(snapshot)
    if type(snapshot) ~= "table" then return nil, "snapshot must be a table" end
    local copied, err = M.copy(snapshot)
    if not copied then return nil, err end
    local ok; ok, err = xpMap(snapshot.skills)
    if not ok then return nil, err end
    if type(snapshot.identity) ~= "table" or type(snapshot.identity.traits) ~= "table" then return nil, "snapshot identity/traits missing" end
    if type(snapshot.recipes) ~= "table" or type(snapshot.modData) ~= "table" then return nil, "snapshot recipes/modData missing" end
    if not finite(snapshot.hoursSurvived) or snapshot.hoursSurvived < 0 or not integer(snapshot.zombieKills, 0, 2147483647) then return nil, "invalid lifetime counters" end
    if not finite(snapshot.capturedAt) or snapshot.capturedAt < 0 then return nil, "invalid capture timestamp" end
    if snapshot.kind ~= "checkpoint" and snapshot.kind ~= "death" then return nil, "invalid snapshot kind" end
    if not text(snapshot.characterKey) then return nil, "missing character identity" end
    if type(snapshot.location) ~= "table" then return nil, "snapshot location missing" end
    for _, key in ipairs({ "x", "y", "z" }) do
        if not finite(snapshot.location[key]) then return nil, "invalid snapshot location" end
    end
    if snapshot.physical~=nil then
        if type(snapshot.physical)~="table" or not finite(snapshot.physical.weight) or snapshot.physical.weight<35 then
            return nil,"invalid physical weight"
        end
        for key in pairs(snapshot.physical)do if key~="weight" then return nil,"unsupported physical field" end end
    end
    return true
end

function M.account()
    return { version = M.VERSION, revision = 0, slots = {} }
end

function M.validateAccount(account)
    if type(account) ~= "table" then return nil, "account must be a table" end
    local bounded, err = M.copy(account)
    if not bounded then return nil, err end
    if account.version ~= M.VERSION or not integer(account.revision, 0, 9007199254740000) or type(account.slots) ~= "table" then return nil, "invalid account header" end
    local count, ids = 0, {}
    for index, slot in pairs(account.slots) do
        count = count + 1
        if not integer(index, 1, M.MAX_SLOTS) or count > M.MAX_SLOTS or type(slot) ~= "table" or slot.slot ~= index or not text(slot.id) or ids[slot.id] then return nil, "invalid profile slot" end
        ids[slot.id] = true
        if slot.phase ~= "alive" and slot.phase ~= "dead" then return nil, "invalid profile phase" end
        if not integer(slot.revision, 1, account.revision) or not integer(slot.deathSeq, 0, 9007199254740000) or not integer(slot.incarnations, 0, 9007199254740000) then return nil, "invalid profile counters" end
        if type(slot.creationIdentity) ~= "table" then return nil, "creation identity missing" end
        if slot.startingOutfit~=nil then
            local outfit,why=O.validate(slot.startingOutfit)
            if not outfit then return nil,why end
        end
        local ok; ok, err = xpMap(slot.creationXP)
        if not ok then return nil, err end
        ok, err = M.validateSnapshot(slot.checkpoint)
        if not ok or slot.checkpoint.kind ~= "checkpoint" then return nil, err or "invalid checkpoint kind" end
        if slot.death then
            ok, err = M.validateSnapshot(slot.death)
            if not ok or slot.death.kind ~= "death" then return nil, err or "invalid death snapshot kind" end
        end
        if slot.phase == "dead" and (not slot.death or slot.deathSeq < 1) then return nil, "dead profile has no death snapshot" end
        if slot.phase == "alive" and account.activeSlot ~= index then return nil, "inactive profile cannot be alive" end
    end
    if account.activeSlot ~= nil and (not integer(account.activeSlot, 1, M.MAX_SLOTS) or not account.slots[account.activeSlot]) then return nil, "active profile missing" end
    if count > 0 and account.activeSlot == nil and not account.deletedDeath then return nil, "active slot missing" end
    if account.deletedDeath~=nil then
        local d=account.deletedDeath
        if type(d)~="table" or not text(d.characterKey) or not integer(d.revision,1,account.revision)
                or account.activeSlot~=nil or account.enrollmentDeath~=nil or type(d.location)~="table" then
            return nil,"invalid deleted-profile death"
        end
        for key in pairs(d) do
            if key~="characterKey" and key~="revision" and key~="location" then return nil,"unexpected deleted-profile data" end
        end
        for key in pairs(d.location) do if key~="x" and key~="y" and key~="z" then return nil,"unexpected deleted-profile location" end end
        for _,key in ipairs({"x","y","z"}) do if not finite(d.location[key]) then return nil,"invalid deleted-profile location" end end
    end
    if account.enrollmentDeath ~= nil then
        local ok; ok, err = M.validateSnapshot(account.enrollmentDeath)
        if not ok or account.enrollmentDeath.kind ~= "death" or count ~= 0 or account.activeSlot ~= nil then return nil, err or "invalid enrollment death" end
        if not integer(account.enrollmentRevision, 1, account.revision) then return nil, "invalid enrollment revision" end
    elseif account.enrollmentRevision ~= nil then return nil, "enrollment revision has no death" end
    if account.pending ~= nil then
        local p = account.pending
        local source = account.slots[account.activeSlot]
        if type(p) ~= "table" or not text(p.id) or not integer(p.slot, 1, M.MAX_SLOTS) or (p.status ~= "prepared" and p.status ~= "applying") then return nil, "invalid pending transition" end
        if p.status == "applying" and (not text(p.newCharacterKey) or p.newCharacterKey == p.sourceCharacterKey or p.newCharacterKey == p.targetCharacterKey) then return nil, "invalid bound transition character" end
        if p.spawnSelection ~= nil then
            local spawn = p.spawnSelection
            if type(spawn) ~= "table" or not text(spawn.id) or type(spawn.location) ~= "table" then return nil, "invalid spawn selection" end
            if spawn.regionName ~= nil and not text(spawn.regionName) then return nil, "invalid spawn region" end
            for _, axis in ipairs({"x", "y", "z"}) do
                if not finite(spawn.location[axis]) then return nil, "invalid spawn coordinates" end
            end
        end
        if p.failedBodies ~= nil then
            if type(p.failedBodies) ~= "table" or not integer(p.retryCount, 1, 9007199254740000) then return nil, "invalid transition retry history" end
            local failedCount = 0
            for index, key in pairs(p.failedBodies) do
                failedCount = failedCount + 1
                if not integer(index, 1, 16) or not text(key) then return nil, "invalid failed body identity" end
                if key == p.newCharacterKey then return nil, "transition is bound to a failed body" end
            end
            if failedCount == 0 or failedCount ~= #p.failedBodies or failedCount > 16 then return nil, "invalid failed body history" end
        elseif p.retryCount ~= nil then return nil, "retry count has no failed body history" end
        if p.creationSnapshot ~= nil then
            local ok; ok, err = M.validateSnapshot(p.creationSnapshot)
            if not ok or p.creationSnapshot.kind ~= "checkpoint" or not text(p.profileId) then return nil, err or "invalid frozen creation snapshot" end
            ok, err = xpMap(p.creationXP)
            if not ok then return nil, err end
        end
        for _,field in ipairs({"targetStartingOutfit","creationStartingOutfit"}) do
            if p[field]~=nil then
                local outfit,why=O.validate(p[field])
                if not outfit then return nil,why end
            end
        end
        if p.sourceKind == "enrollment" then
            if source or count ~= 0 or not account.enrollmentDeath or p.sourceSlot ~= nil or p.sourceCharacterKey ~= account.enrollmentDeath.characterKey or p.sourceDeathSeq ~= 1 or p.sourceRevision ~= account.enrollmentRevision or p.kind ~= "create" then return nil, "pending enrollment does not match death" end
        elseif p.sourceKind == "deleted" then
            local d=account.deletedDeath
            if source or not d or p.sourceSlot~=nil or p.sourceCharacterKey~=d.characterKey
                    or p.sourceDeathSeq~=1 or p.sourceRevision~=d.revision then return nil,"pending deleted-profile death changed" end
        elseif p.sourceKind == "profile" then
            if not source or source.phase ~= "dead" or p.sourceSlot ~= account.activeSlot or p.sourceCharacterKey ~= source.death.characterKey or p.sourceDeathSeq ~= source.deathSeq or p.sourceRevision ~= source.revision then return nil, "pending source does not match death" end
        else return nil, "invalid transition source kind" end
        if p.kind == "restore" then
            local target = account.slots[p.slot]
            if not target or target.phase ~= "dead" or p.targetRevision ~= target.revision or p.targetDeathSeq ~= target.deathSeq or p.targetCharacterKey ~= target.death.characterKey then return nil, "pending target does not match death" end
            local ok; ok, err = M.validateSnapshot(p.targetSnapshot)
            if not ok then return nil, err end
        elseif p.kind == "create" then
            if account.slots[p.slot] or p.targetSnapshot ~= nil then return nil, "new profile reservation is occupied" end
        else return nil, "invalid pending transition kind" end
    end
    if account.lastCompletion ~= nil then
        local last = account.lastCompletion
        if type(last) ~= "table" or not text(last.id) or not text(last.characterKey) or not integer(last.slot, 1, M.MAX_SLOTS) then return nil, "invalid completion receipt" end
    end
    if account.lastDeletion~=nil then
        local d=account.lastDeletion
        if type(d)~="table" or not text(d.id) or not text(d.profileId) or not text(d.deathToken,512)
                or not integer(d.slot,1,M.MAX_SLOTS) or not integer(d.profileRevision,1,account.revision)
                or not integer(d.expectedRevision,1,account.revision) or not integer(d.revision,1,account.revision)
                or d.revision~=d.expectedRevision+1 then return nil,"invalid deletion receipt" end
    end
    return true
end

local function cloneAccount(account)
    local ok, err = M.validateAccount(account)
    if not ok then return nil, err end
    return M.copy(account)
end

local function finish(account, value)
    local ok, err = M.validateAccount(account)
    if not ok then return nil, err end
    return account, value
end

function M.ensureSlot(account, index, id, creationXP, snapshot, startingOutfit)
    local nextAccount, err = cloneAccount(account)
    if not nextAccount then return nil, err end
    if not integer(index, 1, M.MAX_SLOTS) or not text(id) then return nil, "invalid slot identity" end
    local ok; ok, err = xpMap(creationXP)
    if not ok then return nil, err end
    ok, err = M.validateSnapshot(snapshot)
    if not ok or snapshot.kind ~= "checkpoint" then return nil, err or "adoption requires checkpoint" end
    local existing = nextAccount.slots[index]
    if existing then
        if existing.id == id and nextAccount.activeSlot == index and existing.phase == "alive" and existing.checkpoint.characterKey == snapshot.characterKey then return nextAccount, existing end
        return nil, "slot already exists"
    end
    if nextAccount.pending or nextAccount.activeSlot or nextAccount.enrollmentDeath or nextAccount.deletedDeath then return nil, "creation must use a death selection" end
    nextAccount.revision = nextAccount.revision + 1
    local slot = { id = id, slot = index, phase = "alive", creationXP = M.copy(creationXP), creationIdentity = M.copy(snapshot.identity), checkpoint = M.copy(snapshot), deathSeq = 0, incarnations = 0, revision = nextAccount.revision }
    if startingOutfit~=nil then
        slot.startingOutfit,err=O.validate(startingOutfit)
        if not slot.startingOutfit then return nil,err end
    end
    nextAccount.slots[index], nextAccount.activeSlot = slot, index
    return finish(nextAccount, slot)
end

function M.checkpoint(account, index, snapshot)
    local nextAccount, err = cloneAccount(account)
    if not nextAccount then return nil, err end
    local ok; ok, err = M.validateSnapshot(snapshot)
    if not ok or snapshot.kind ~= "checkpoint" then return nil, err or "checkpoint kind required" end
    local slot = nextAccount.slots[index]
    if nextAccount.pending or nextAccount.activeSlot ~= index or not slot or slot.phase ~= "alive" then return nil, "profile is not alive and active" end
    if slot.checkpoint.characterKey ~= snapshot.characterKey then return nil, "checkpoint belongs to another character" end
    if snapshot.capturedAt < slot.checkpoint.capturedAt then return nil, "stale checkpoint" end
    nextAccount.revision = nextAccount.revision + 1
    slot.checkpoint, slot.revision = M.copy(snapshot), nextAccount.revision
    return finish(nextAccount, slot)
end

function M.recordDeath(account, index, snapshot)
    local nextAccount, err = cloneAccount(account)
    if not nextAccount then return nil, err end
    local ok; ok, err = M.validateSnapshot(snapshot)
    if not ok or snapshot.kind ~= "death" then return nil, err or "death snapshot kind required" end
    local slot = nextAccount.slots[index]
    if not slot or nextAccount.activeSlot ~= index then return nil, "death profile is not active" end
    if slot.phase == "dead" and slot.death.characterKey == snapshot.characterKey then return nextAccount, slot end
    if nextAccount.pending or slot.phase ~= "alive" or slot.checkpoint.characterKey ~= snapshot.characterKey then return nil, "death belongs to another character" end
    if snapshot.capturedAt < slot.checkpoint.capturedAt then return nil, "death precedes latest checkpoint" end
    nextAccount.revision = nextAccount.revision + 1
    slot.phase, slot.death, slot.deathSeq, slot.revision = "dead", M.copy(snapshot), slot.deathSeq + 1, nextAccount.revision
    return finish(nextAccount, slot)
end

function M.deathToken(account)
    if account and account.deletedDeath then
        return "deleted:"..tostring(account.deletedDeath.revision)..":"..account.deletedDeath.characterKey
    end
    if account and account.enrollmentDeath then
        return "enrollment:" .. tostring(account.enrollmentRevision) .. ":" .. account.enrollmentDeath.characterKey
    end
    local slot = account and account.slots and account.slots[account.activeSlot]
    if not slot or slot.phase ~= "dead" or not slot.death then return nil end
    return tostring(slot.slot) .. ":" .. slot.id .. ":" .. tostring(slot.deathSeq) .. ":" .. slot.death.characterKey
end

-- Logical deletion is a normal revisioned server commit. Preserve only the
-- current corpse's authorization/location when its profile is removed: never
-- reuse another profile's body or retain the deleted XP/identity as a new life.
function M.deleteProfile(account,index,profileId,profileRevision,expectedRevision,deathToken,requestId)
    local nextAccount,err=cloneAccount(account)
    if not nextAccount then return nil,err end
    if not integer(index,1,M.MAX_SLOTS) or not text(profileId) or not text(requestId)
            or not integer(profileRevision,1,9007199254740000) or not integer(expectedRevision,1,9007199254740000)
            or not text(deathToken,512) then return nil,"Invalid profile deletion" end
    local last=nextAccount.lastDeletion
    if last and last.id==requestId then
        if last.slot==index and last.profileId==profileId and last.profileRevision==profileRevision
                and last.expectedRevision==expectedRevision and last.deathToken==deathToken then return nextAccount,last end
        return nil,"Deletion request was already used for another profile"
    end
    if nextAccount.pending then return nil,"Cancel your pending selection before deleting a profile" end
    if expectedRevision~=nextAccount.revision or deathToken~=M.deathToken(nextAccount) then
        return nil,"Your profiles changed. Review the refreshed list before deleting"
    end
    local slot=nextAccount.slots[index]
    if not slot or slot.phase~="dead" or slot.id~=profileId or slot.revision~=profileRevision then
        return nil,"The selected profile changed. Review it before deleting"
    end
    nextAccount.revision=nextAccount.revision+1
    if nextAccount.activeSlot==index then
        nextAccount.deletedDeath={characterKey=slot.death.characterKey,revision=nextAccount.revision,
            location={x=slot.death.location.x,y=slot.death.location.y,z=slot.death.location.z}}
        nextAccount.activeSlot=nil
    end
    nextAccount.slots[index]=nil
    if nextAccount.lastCompletion and nextAccount.lastCompletion.slot==index then nextAccount.lastCompletion=nil end
    nextAccount.lastDeletion={id=requestId,slot=index,profileId=profileId,profileRevision=profileRevision,
        expectedRevision=expectedRevision,deathToken=deathToken,revision=nextAccount.revision}
    return finish(nextAccount,nextAccount.lastDeletion)
end

function M.recordUnenrolledDeath(account, snapshot)
    local nextAccount, err = cloneAccount(account)
    if not nextAccount then return nil, err end
    local ok; ok, err = M.validateSnapshot(snapshot)
    if not ok or snapshot.kind ~= "death" then return nil, err or "enrollment requires death snapshot" end
    if nextAccount.activeSlot then return nil, "account is already enrolled" end
    if nextAccount.deletedDeath then return nil,"Deleted profile death is already sealed" end
    for _ in pairs(nextAccount.slots) do return nil, "account is already enrolled" end
    if nextAccount.enrollmentDeath then
        if nextAccount.enrollmentDeath.characterKey == snapshot.characterKey then return nextAccount, nextAccount.enrollmentDeath end
        return nil, "another enrollment death is already sealed"
    end
    if nextAccount.pending then return nil, "transition is pending" end
    nextAccount.revision = nextAccount.revision + 1
    nextAccount.enrollmentDeath, nextAccount.enrollmentRevision = M.copy(snapshot), nextAccount.revision
    return finish(nextAccount, nextAccount.enrollmentDeath)
end

function M.penalizedSnapshot(slot)
    if not slot or not slot.death then return nil, "death snapshot missing" end
    local result, err = M.copy(slot.death)
    if not result then return nil, err end
    for perk, current in pairs(result.skills) do
        local base = math.min(current, tonumber(slot.creationXP[perk]) or 0)
        result.skills[perk] = base + 0.9 * math.max(0, current - base)
    end
    return result
end

function M.select(account, index, deathToken, requestId, maxSlots)
    local nextAccount, err = cloneAccount(account)
    if not nextAccount then return nil, err end
    if not integer(index, 1, M.MAX_SLOTS) or not text(requestId) or not integer(maxSlots, 1, M.MAX_SLOTS) then return nil, "invalid selection" end
    if nextAccount.pending then
        local p = nextAccount.pending
        if p.id == requestId and p.slot == index and p.deathToken == deathToken then return nextAccount, p end
        return nil, "another transition is pending"
    end
    if nextAccount.lastCompletion and nextAccount.lastCompletion.id == requestId then return nil, "request already completed" end
    local source = nextAccount.slots[nextAccount.activeSlot]
    local enrollment = nextAccount.enrollmentDeath
    local deleted=nextAccount.deletedDeath
    if (not enrollment and not deleted and (not source or source.phase ~= "dead")) or deathToken ~= M.deathToken(nextAccount) then return nil, "selection requires current death token" end
    local target = nextAccount.slots[index]
    if target and target.phase ~= "dead" then return nil, "cannot switch to a living profile" end
    if not target and index > maxSlots then return nil, "profile slot limit reached" end
    local p = { id = requestId, slot = index, sourceKind = enrollment and "enrollment" or deleted and "deleted" or "profile", sourceSlot = nextAccount.activeSlot, sourceCharacterKey = enrollment and enrollment.characterKey or deleted and deleted.characterKey or source.death.characterKey, sourceDeathSeq = (enrollment or deleted) and 1 or source.deathSeq, sourceRevision = enrollment and nextAccount.enrollmentRevision or deleted and deleted.revision or source.revision, deathToken = deathToken, status = "prepared", kind = target and "restore" or "create" }
    if target then
        p.targetSnapshot, err = M.penalizedSnapshot(target)
        if not p.targetSnapshot then return nil, err end
        p.targetStartingOutfit,err=O.forProfile(target.startingOutfit)
        if not p.targetStartingOutfit then return nil,err end
        p.targetRevision, p.targetDeathSeq, p.targetCharacterKey = target.revision, target.deathSeq, target.death.characterKey
    end
    nextAccount.pending, nextAccount.revision = p, nextAccount.revision + 1
    return finish(nextAccount, p)
end

function M.xpTolerance(target)
    return math.max(0.001, math.abs(tonumber(target) or 0) * 1.2e-7)
end

-- Only the server policy may supply a resolved destination. Selection changes
-- neither the frozen death snapshot nor its XP penalty. Cancel to choose again.
function M.chooseSpawn(account, requestId, selection)
    local nextAccount, err = cloneAccount(account)
    if not nextAccount then return nil, err end
    local p = nextAccount.pending
    if not p or p.id ~= requestId or p.status ~= "prepared" then return nil, "spawn selection requires a prepared transition" end
    if type(selection) ~= "table" or not text(selection.id) then return nil, "invalid spawn selection" end
    if p.spawnSelection then
        if p.spawnSelection.id ~= selection.id then return nil, "Cancel this selection before choosing a different destination" end
        return nextAccount, p.spawnSelection
    end
    p.spawnSelection = {id=selection.id, regionName=selection.regionName, location=M.copy(selection.location)}
    nextAccount.revision = nextAccount.revision + 1
    return finish(nextAccount, p.spawnSelection)
end

function M.xpEqual(actual, target)
    return finite(actual) and finite(target) and math.abs(actual - target) <= M.xpTolerance(target)
end

function M.complete(account, requestId, snapshot, creationXP, newProfileId)
    local nextAccount, err = cloneAccount(account)
    if not nextAccount then return nil, err end
    local ok; ok, err = M.validateSnapshot(snapshot)
    if not ok or snapshot.kind ~= "checkpoint" then return nil, err or "completion requires checkpoint" end
    local p = nextAccount.pending
    if not p then
        local last = nextAccount.lastCompletion
        if last and last.id == requestId and last.characterKey == snapshot.characterKey then return nextAccount, nextAccount.slots[last.slot] end
        return nil, "no matching pending transition"
    end
    if p.id ~= requestId or snapshot.characterKey == p.sourceCharacterKey or snapshot.characterKey == p.targetCharacterKey then return nil, "completion identity does not match new character" end
    if p.status ~= "applying" then return nil, "transition must be bound before completion" end
    if p.status == "applying" and snapshot.characterKey ~= p.newCharacterKey then return nil, "completion belongs to another character" end
    local slot = nextAccount.slots[p.slot]
    if p.kind == "create" then
        ok, err = xpMap(creationXP)
        if not ok or not text(newProfileId) then return nil, err or "new profile identity missing" end
        slot = { id = newProfileId, slot = p.slot, creationXP = M.copy(creationXP), creationIdentity = M.copy(snapshot.identity), deathSeq = 0, incarnations = 0 }
        -- Freeze only the first native creation outfit, never completion/death wear.
        slot.startingOutfit=M.copy(p.creationStartingOutfit)
        nextAccount.slots[p.slot] = slot
    else
        -- The adapter must verify native application before acknowledging. The model
        -- requires the complete exact XP target so a partial award cannot commit.
        for perk, target in pairs(p.targetSnapshot.skills) do
            if not M.xpEqual(snapshot.skills[perk], target) then return nil, "XP application is incomplete" end
        end
        for perk in pairs(snapshot.skills) do
            if p.targetSnapshot.skills[perk] == nil then return nil, "XP application has an unexpected skill" end
        end
        slot.incarnations = slot.incarnations + 1
    end
    nextAccount.revision = nextAccount.revision + 1
    slot.phase, slot.checkpoint, slot.revision = "alive", M.copy(snapshot), nextAccount.revision
    nextAccount.activeSlot, nextAccount.pending = p.slot, nil
    nextAccount.enrollmentDeath, nextAccount.enrollmentRevision = nil, nil
    nextAccount.deletedDeath=nil
    nextAccount.lastCompletion = { id = requestId, slot = p.slot, characterKey = snapshot.characterKey }
    return finish(nextAccount, slot)
end

function M.markApplying(account, requestId, characterKey)
    local nextAccount, err = cloneAccount(account)
    if not nextAccount then return nil, err end
    local p = nextAccount.pending
    if not p or p.id ~= requestId or not text(characterKey) or characterKey == p.sourceCharacterKey or characterKey == p.targetCharacterKey then return nil, "invalid transition binding" end
    for _, failedKey in ipairs(p.failedBodies or {}) do
        if failedKey == characterKey then return nil, "a failed body cannot receive restoration" end
    end
    if p.status == "applying" then
        if p.newCharacterKey == characterKey then return nextAccount, p end
        return nil, "transition is bound to another character"
    end
    p.status, p.newCharacterKey = "applying", characterKey
    nextAccount.revision = nextAccount.revision + 1
    return finish(nextAccount, p)
end

-- Only the server may call this after confirming that this exact bound body died.
-- The original XP target remains frozen: an incomplete restoration is retried,
-- rather than counted as another completed incarnation or charged another loss.
function M.retryAfterBodyDeath(account, requestId, characterKey)
    local nextAccount, err = cloneAccount(account)
    if not nextAccount then return nil, err end
    local p = nextAccount.pending
    if not p or p.id ~= requestId or not text(characterKey) then return nil, "no matching interrupted transition" end
    if p.status == "prepared" and p.failedBodies and p.failedBodies[#p.failedBodies] == characterKey then return nextAccount, p end
    if p.status ~= "applying" or p.newCharacterKey ~= characterKey then return nil, "death does not belong to the bound body" end
    p.failedBodies = p.failedBodies or {}
    p.failedBodies[#p.failedBodies + 1] = characterKey
    if #p.failedBodies > 16 then table.remove(p.failedBodies, 1) end
    p.retryCount = (p.retryCount or 0) + 1
    p.status, p.newCharacterKey = "prepared", nil
    nextAccount.revision = nextAccount.revision + 1
    return finish(nextAccount, p)
end

function M.cancel(account, requestId)
    local nextAccount, err = cloneAccount(account)
    if not nextAccount then return nil, err end
    local p = nextAccount.pending
    if not p or p.id ~= requestId or p.status ~= "prepared" then return nil, "only a prepared transition can be cancelled" end
    nextAccount.pending, nextAccount.revision = nil, nextAccount.revision + 1
    return finish(nextAccount, true)
end

return M
