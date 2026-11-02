-- kora_utils client core -- the shared tick coordinator every feature module
-- schedules through instead of spawning its own `while true ... Wait(0)` thread.
-- At MOST one frame thread plus one thread per distinct interval; a feature
-- disabled in config registers nothing and costs zero.
--
-- Realm: client only.

Small = Small or {}

-- Every-frame callbacks drained by one shared thread, created lazily on the
-- first onFrame registration and never torn down. Only ACTIVE tasks live in
-- frameTasks; pausing/resuming swaps in a fresh table (copy-on-write) so a task
-- can pause itself mid-frame without shifting the list under the loop. With no
-- active task the thread drops to a slow idle poll instead of resuming per frame.
local frameTasks = {}
local frameThreadStarted = false
local FRAME_IDLE_WAIT = 100

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
    end
    setActive(true)

    if frameThreadStarted then return setActive end
    frameThreadStarted = true

    CreateThread(function()
        while true do
            local tasks = frameTasks
            local count = #tasks
            for i = 1, count do
                tasks[i]()
            end
            Wait(count > 0 and 0 or FRAME_IDLE_WAIT)
        end
    end)
    return setActive
end

-- Interval buckets: one thread per DISTINCT interval, shared by every feature
-- that asked for that cadence. Two features both wanting a 2000 ms tick share a
-- single thread and a single Wait(2000), not two.
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

-- Re-run `fn` on first spawn and every respawn: the engine resets player-scoped
-- natives (`SetPlayerHealthRechargeMultiplier`, `SetMaxWantedLevel`,
-- `SetPoliceIgnorePlayer`) when the ped is recreated. Also fires on a ped-handle
-- change, the reliable respawn signal when no spawn event is raised.
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

    -- The event path (fires on the framework/spawnmanager spawn). playerSpawned
    -- is raised locally by spawnmanager, so AddEventHandler is right for it;
    -- OnPlayerLoaded only ever arrives over the wire from kora_core, and FiveM
    -- SKIPS a net-delivered event attached with bare AddEventHandler (printing
    -- "event ... was not safe for net"), so it needs RegisterNetEvent.
    AddEventHandler("playerSpawned", fireAll)
    RegisterNetEvent("QBCore:Client:OnPlayerLoaded", fireAll)

    -- The reliable path: watch the ped handle. A respawn recreates the ped, so
    -- a changed handle means "new body, reapply everything" even on servers
    -- whose spawn flow never raises playerSpawned. Slow tick -- respawns are
    -- rare and a second of delay reapplying a passive tweak is harmless.
    Small.once(function()
        local lastPed = 0
        while true do
            local ped = Kora.cache.ped()
            if ped ~= lastPed and ped ~= 0 and DoesEntityExist(ped) then
                lastPed = ped
                fireAll()
            end
            Wait(1000)
        end
    end)
end
