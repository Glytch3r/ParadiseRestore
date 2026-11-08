ParadisePOIBuilder = ParadisePOIBuilder or {}
ParadisePOIBuilder.Queue = ParadisePOIBuilder.Queue or {}
if ParadisePOIBuilder.isB41() then return end

local P = ParadisePOIBuilder
local Q = P.Queue

Q.jobs = {}
Q.count = 0
Q.nextId = 1
Q.emitter = Q.emitter or nil

local function emit(username, command, args)
    if Q.emitter then Q.emitter(username, command, args) end
end

function Q.isBusy(username)
    return Q.jobs[username] ~= nil
end

function Q.start(username, def)
    if Q.jobs[username] then
        return nil, "A job is already running. Cancel it first."
    end
    if type(def) ~= "table" then
        return nil, "Job definition is missing."
    end
    if type(def.units) ~= "table" or #def.units == 0 then
        return nil, "Nothing to build in that selection."
    end
    if type(def.step) ~= "function" then
        return nil, "Job has no work function."
    end
    local id = Q.nextId
    Q.nextId = id + 1
    local job = {
        id = id,
        kind = def.kind or "job",
        phase = def.phase or "Working",
        owner = username,
        area = def.area,
        payload = def.payload,
        units = def.units,
        step = def.step,
        onFinish = def.onFinish,
        cursor = 1,
        total = #def.units,
        done = 0,
        skipped = 0,
        failed = 0,
        lastError = nil,
        state = "running",
        nextProgressAt = 0,
    }
    Q.jobs[username] = job
    Q.count = Q.count + 1
    emit(username, "job", { id = id, kind = job.kind, phase = job.phase, total = job.total })
    return job
end

function Q.cancel(username)
    local job = Q.jobs[username]
    if not job then return false end
    job.state = "cancelled"
    return true
end

local function runUnit(job)
    local unit = job.units[job.cursor]
    job.cursor = job.cursor + 1
    local ok, result = pcall(job.step, job, unit)
    if not ok then
        job.failed = job.failed + 1
        job.lastError = tostring(result)
        return
    end
    if result == "abort" then
        job.state = "cancelled"
        return
    end
    if result == "skip" then
        job.skipped = job.skipped + 1
    else
        job.done = job.done + 1
    end
end

local function finish(job)
    Q.jobs[job.owner] = nil
    Q.count = Q.count - 1
    if Q.count < 0 then Q.count = 0 end

    local text, ok
    if job.abortReason then
        text = job.abortReason
        ok = false
    elseif job.onFinish then
        local success, customText, customOk = pcall(job.onFinish, job)
        if success and type(customText) == "string" then
            text = customText
            ok = customOk ~= false
        else
            text = "The job could not be completed."
            ok = false
        end
    elseif job.state == "cancelled" then
        if job.failed > 0 then
            text = string.format("%s cancelled at %d of %d. Built %d, skipped %d, failed %d. Last error: %s",
                job.phase, job.cursor - 1, job.total, job.done, job.skipped, job.failed, tostring(job.lastError))
        else
            text = string.format("%s cancelled at %d of %d. Built %d, skipped %d.",
                job.phase, job.cursor - 1, job.total, job.done, job.skipped)
        end
        ok = false
    elseif job.failed > 0 then
        text = string.format("%s finished with %d errors. Built %d, skipped %d. Last error: %s",
            job.phase, job.failed, job.done, job.skipped, tostring(job.lastError))
        ok = false
    else
        text = string.format("%s finished. Built %d, skipped %d.",
            job.phase, job.done, job.skipped)
        ok = true
    end

    emit(job.owner, "result", {
        ok = ok,
        text = text,
        kind = job.kind,
        done = job.done,
        skipped = job.skipped,
        failed = job.failed,
        total = job.total,
    })
end

function Q.tick()
    if Q.count == 0 then return end

    local snapshot = {}
    for _, job in pairs(Q.jobs) do
        snapshot[#snapshot + 1] = job
    end

    local now = getTimestampMs()
    local budget = P.JOB_BUDGET
    for i = 1, #snapshot do
        local job = snapshot[i]
        if Q.jobs[job.owner] == job then
            while budget > 0 and job.cursor <= job.total and job.state == "running" do
                runUnit(job)
                budget = budget - 1
            end
            if job.state ~= "running" or job.cursor > job.total then
                finish(job)
            elseif now >= job.nextProgressAt then
                job.nextProgressAt = now + P.PROGRESS_MS
                emit(job.owner, "progress", {
                    id = job.id,
                    done = job.cursor - 1,
                    total = job.total,
                    skipped = job.skipped,
                    failed = job.failed,
                    phase = job.phase,
                })
            end
        end
    end
end
Events.OnTick.Remove(Q.tick)
Events.OnTick.Add(Q.tick)
