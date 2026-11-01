-- Legacy qb-smallresources timed jobs. Server only, so there is no network
-- entry point: only another server resource can create or run one.
local jobs, nextId, running = {}, 0, false

local function clock()
    local now = os.time()
    local parts = os.date('*t', now)
    return { day = parts.wday, hour = parts.hour, min = parts.min }
end

local function run(job, time)
    local ok, err = pcall(job.cb, time.day, time.hour, time.min)
    if not ok then print(('[kora_utils] timed job from %s errored: %s'):format(job.owner, tostring(err))) end
end

local function start()
    if running then return end
    running = true
    CreateThread(function()
        while true do
            Wait((60 - os.time() % 60) * 1000)
            local time = clock()
            local due = {}
            for _, job in pairs(jobs) do
                if job.hour == time.hour and job.min == time.min then due[#due + 1] = job end
            end
            for index = 1, #due do run(due[index], time) end
        end
    end)
end

local function createTimedJob(hour, min, cb)
    if type(hour) ~= 'number' or type(min) ~= 'number' or not Kora.compat.isCallable(cb) then
        print('WARN: Invalid arguments for export CreateTimedJob(hour, min, cb)')
        return nil
    end
    nextId = nextId + 1
    jobs[nextId] = { hour = hour, min = min, cb = cb, owner = GetInvokingResource() or GetCurrentResourceName() }
    start()
    return nextId
end

local function forceRunTimedJob(id)
    local job = jobs[id]
    if job then run(job, clock()) end
end

local function stopTimedJob(id)
    jobs[id] = nil
end

for name, handler in pairs({ CreateTimedJob = createTimedJob, ForceRunTimedJob = forceRunTimedJob,
    StopTimedJob = stopTimedJob }) do
    exports(name, handler)
    Kora.compat.provideExport('qb-smallresources', name, handler)
end

AddEventHandler('onResourceStop', function(resource)
    for id, job in pairs(jobs) do
        if job.owner == resource then jobs[id] = nil end
    end
end)
