-- qbsmallresources client core -- the shared tick coordinator every feature
-- module schedules its work through, instead of each module spawning its own
-- `while true ... Wait(0)` thread.
--
-- Why this exists: a "small resources" bundle is a pile of tiny always-on
-- tweaks (invalidate the idle cam, block the weapon wheel, clear the wanted
-- level, zero the health regen, strip blacklisted weapons...). The naive shape
-- -- one CreateThread per feature -- means a server running ten of them pays
-- ten separate coroutine resumes every single frame, most doing one cheap
-- native call. That is exactly the "running hot" pattern we optimised out of
-- baseevents. Here every enabled feature registers a callback and we run AT
-- MOST one frame thread for the whole resource, plus one thread per distinct
-- slow interval. A feature disabled in config registers nothing and costs
-- literally zero -- no thread, no branch in a hot loop.
--
-- Realm: client only. Server-side features (spawn blacklists etc.) use plain
-- event handlers and don't need a tick.

Small = Small or {}

-- Every-frame (Wait 0) callbacks. One shared thread drains this list. The
-- thread is created lazily on the first onFrame registration and never torn
-- down -- once something wants per-frame work, the frame thread is warranted
-- for the resource's lifetime. If NOTHING ever calls onFrame, the thread never
-- exists.
local frameTasks = {}
local frameThreadStarted = false

---Run `fn` every frame (`Wait(0)`), for the lifetime of the resource. Intended
---for natives that must be reasserted each frame to take effect --
---`BlockWeaponWheelThisFrame`, `DisablePlayerFiring`, disabling a control
---action, etc. Anything that only needs reasserting occasionally belongs on
---`onInterval` instead; per-frame is the most expensive cadence there is, so
---reach for it only when the native genuinely demands it.
---@param fn fun()
function Small.onFrame(fn)
    frameTasks[#frameTasks + 1] = fn

    if frameThreadStarted then return end
    frameThreadStarted = true

    CreateThread(function()
        -- Cache the length only inside the frame; onFrame can still append
        -- (features register at load, before the first frame runs, but a late
        -- registration must not be skipped forever either), so re-read #.
        while true do
            for i = 1, #frameTasks do
                frameTasks[i]()
            end
            Wait(0)
        end
    end)
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

-- Re-run `fn` on first spawn and on every respawn. A lot of player-scoped
-- natives (`SetPlayerHealthRechargeMultiplier`, `SetMaxWantedLevel`,
-- `SetPoliceIgnorePlayer`) are reset by the engine when the ped is recreated
-- on death/respawn, so "set it once at load" silently wears off the first time
-- the player dies. This funnels those through one place: it fires `fn` once the
-- ped first exists, then again after each `playerSpawned` (qbcore/spawnmanager)
-- and after the ped entity handle changes (the reliable respawn signal even
-- when no spawn event fires).
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
    -- OnPlayerLoaded only ever arrives over the wire from qbcore, and FiveM
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
            local ped = PlayerPedId()
            if ped ~= lastPed and ped ~= 0 and DoesEntityExist(ped) then
                lastPed = ped
                fireAll()
            end
            Wait(1000)
        end
    end)
end
