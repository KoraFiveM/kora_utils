Small = Small or {}

local frameTasks = {}
local frameThreadRunning = false

-- The shared frame thread only exists while at least one frame task is active.
-- When the last task pauses, the thread exits instead of idling, so a player
-- with nothing needing a per-frame native costs zero thread resumes. Activating
-- a task starts it again. It begins with Wait(0) so tasks only ever run on the
-- frame loop, never synchronously inside whichever caller resumed them.
local function startFrameThread()
    if frameThreadRunning or #frameTasks == 0 then return end
    frameThreadRunning = true
    CreateThread(function()
        while true do
            Wait(0)
            local tasks = frameTasks
            local count = #tasks
            if count == 0 then break end
            for i = 1, count do
                tasks[i]()
            end
        end
        frameThreadRunning = false
    end)
end

---Run `fn` every frame (`Wait(0)`), for the lifetime of the resource. Intended
---for natives that must be reasserted each frame to take effect --
---`BlockWeaponWheelThisFrame`, `DisablePlayerFiring`, disabling a control
---action, etc. Anything that only needs reasserting occasionally belongs on
---`onInterval` instead; per-frame is the most expensive cadence there is, so
---reach for it only when the native genuinely demands it.
---Returns `setActive(bool)`: a feature that is only conditionally relevant (e.g.
---seatbelt while on foot) pauses itself so it costs nothing until resumed.
---@param fn fun()
---@return fun(active: boolean)
function Small.onFrame(fn)
    local active = false
    local function setActive(enabled)
        enabled = enabled ~= false
        if enabled == active then return end
        active = enabled
        local tasks = {}
        for i = 1, #frameTasks do
            if frameTasks[i] ~= fn then tasks[#tasks + 1] = frameTasks[i] end
        end
        if enabled then tasks[#tasks + 1] = fn end
        frameTasks = tasks
        if enabled then startFrameThread() end
    end
    setActive(true)
    return setActive
end

local buckets = {}

---Run `fn` every `ms` milliseconds. The right default for reassert-occasionally
---work (clearing the wanted level, re-zeroing health regen after a respawn,
---sweeping for blacklisted weapons) -- cheap, and invisible in a frame profile.
---@param ms integer Interval in milliseconds. Features sharing an interval share one thread.
---@param fn fun()
function Small.onInterval(ms, fn)
    assert(type(ms) == "number" and ms > 0, "Small.onInterval: ms must be a positive number")

    local bucket = buckets[ms]

    if not bucket then
        bucket = { tasks = {} }
        buckets[ms] = bucket

        CreateThread(function()
            while true do
                local tasks = bucket.tasks
                for i = 1, #tasks do
                    tasks[i]()
                end
                Wait(ms)
            end
        end)
    end

    bucket.tasks[#bucket.tasks + 1] = fn
end

---Run `fn` once, now, in its own thread -- for one-shot setup that yields
---(waiting on the ped to exist, loading something) and shouldn't block the
---load of the next module file. Non-yielding setup should just run inline at
---file scope; this is only for the yielding case.
---@param fn fun()
function Small.once(fn)
    CreateThread(fn)
end

local spawnHandlers = {}
local spawnWatcherStarted = false

---@param fn fun()
function Small.onSpawn(fn)
    spawnHandlers[#spawnHandlers + 1] = fn

    if spawnWatcherStarted then return end
    spawnWatcherStarted = true

    local function fireAll()
        for i = 1, #spawnHandlers do
            local ok, err = pcall(spawnHandlers[i])
            if not ok then
                print(("[qbsmallresources] onSpawn handler errored: %s"):format(tostring(err)))
            end
        end
    end

    AddEventHandler("playerSpawned", fireAll)
    RegisterNetEvent("QBCore:Client:OnPlayerLoaded", fireAll)

    local lastPed, pendingPed = 0, nil
    local function pedChanged(ped)
        if not ped or ped == 0 or ped == lastPed then return end
        if DoesEntityExist(ped) then
            lastPed, pendingPed = ped, nil
            CreateThread(fireAll)
            return
        end
        if pendingPed == ped then return end
        pendingPed = ped
        CreateThread(function()
            while pendingPed == ped and not DoesEntityExist(ped) do Wait(1000) end
            if pendingPed == ped then
                pendingPed = nil
                pedChanged(ped)
            end
        end)
    end

    local function watchPed()
        Kora.cache.onChange('ped', pedChanged)
        pedChanged(Kora.cache.ped())
    end
    watchPed()
    AddEventHandler('onClientResourceStart', function(resource)
        if resource == 'kora_lib' then watchPed() end
    end)
end
