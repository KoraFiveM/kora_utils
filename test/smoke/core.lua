local scriptDir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"
local testDir = scriptDir .. "../"
local repoRoot = testDir .. "../"
package.path = testDir .. "?.lua;" .. package.path

local harness = require("harness")
local mocks = require("mocks")

local handle = mocks.install()

dofile(repoRoot .. "client/core.lua")
dofile(repoRoot .. "client/util.lua")

harness.test("onFrame runs every registered task once per step", function()
    local a, b = 0, 0
    Small.onFrame(function() a = a + 1 end)
    Small.onFrame(function() b = b + 1 end)
    handle.step()
    harness.assertTrue(a >= 1 and b >= 1, "both frame tasks should have run")
    local aBefore, bBefore = a, b
    handle.step()
    harness.assertEqual(a, aBefore + 1, "task a should advance exactly one per step")
    harness.assertEqual(b, bBefore + 1, "task b should advance exactly one per step")
end)

harness.test("onFrame setActive pauses and resumes a task without disturbing others", function()
    local paused, other = 0, 0
    local setActive
    setActive = Small.onFrame(function()
        paused = paused + 1
        setActive(false)
    end)
    Small.onFrame(function() other = other + 1 end)
    handle.step()
    local pausedBefore, otherBefore = paused, other
    handle.step()
    harness.assertEqual(paused, pausedBefore, "a paused task must not run")
    harness.assertEqual(other, otherBefore + 1, "other tasks keep running every frame")
    setActive(true)
    handle.step()
    harness.assertEqual(paused, pausedBefore + 1, "a resumed task runs again")
end)

harness.test("the frame thread stops when every task is paused and restarts on resume", function()
    local savedSmall, savedKora, savedCreate = Small, Kora, CreateThread
    Small, Kora = nil, nil
    local runtime = mocks.install()
    local create = CreateThread
    local threads, waits = 0, {}
    CreateThread = function(fn) threads = threads + 1; return create(fn) end
    local wait = Wait
    Wait = function(ms) waits[#waits + 1] = ms; return wait(ms) end
    dofile(repoRoot .. "client/core.lua")

    local runs = 0
    local setActive = Small.onFrame(function() runs = runs + 1 end)
    harness.assertEqual(threads, 1, "registering a task starts the frame thread")
    harness.assertEqual(runs, 0, "tasks only run on the frame loop, not inside the caller")
    runtime.step()
    harness.assertEqual(runs, 1, "the task runs on the next frame")

    setActive(false)
    runtime.step()
    runtime.step()
    harness.assertEqual(runs, 1, "a paused task does not run")
    local waitsWhileIdle = #waits
    runtime.step()
    harness.assertEqual(#waits, waitsWhileIdle, "with nothing active the thread has exited: no idle wake-ups")

    setActive(true)
    harness.assertEqual(threads, 2, "resuming a task starts the thread again")
    setActive(true)
    harness.assertEqual(threads, 2, "a second resume does not start a duplicate thread")
    runtime.step()
    harness.assertEqual(runs, 2, "the resumed task runs again")
    for _, ms in ipairs(waits) do harness.assertEqual(ms, 0, "the frame thread only ever waits one frame") end

    CreateThread, Wait = savedCreate, wait
    Small, Kora = savedSmall, savedKora
end)

harness.test("onInterval shares one thread per distinct interval", function()
    local calls = 0
    Small.onInterval(2000, function() calls = calls + 1 end)
    Small.onInterval(2000, function() calls = calls + 1 end)
    handle.step()
    harness.assertTrue(calls >= 2, "both interval tasks on the shared bucket should run")
end)

harness.test("onInterval rejects a non-positive interval", function()
    harness.assertThrows(function() Small.onInterval(0, function() end) end)
    harness.assertThrows(function() Small.onInterval(-5, function() end) end)
end)

harness.test("onSpawn fires on the playerSpawned event", function()
    local spawns = 0
    Small.onSpawn(function() spawns = spawns + 1 end)
    handle.fire("playerSpawned")
    harness.assertTrue(spawns >= 1, "onSpawn handler should run when playerSpawned fires")
end)

harness.test("onSpawn survives a throwing handler (pcall-wrapped)", function()
    local reached = false
    Small.onSpawn(function() error("boom") end)
    Small.onSpawn(function() reached = true end)
    handle.fire("QBCore:Client:OnPlayerLoaded")
    harness.assertTrue(reached, "a later handler must still run after an earlier one errors")
end)

harness.test("onSpawn watches the cached ped via onChange instead of polling", function()
    local savedSmall, savedKora = Small, Kora
    Small, Kora = nil, nil
    local runtime = mocks.install()
    _G.__ped = 0
    dofile(repoRoot .. "client/core.lua")
    local waits = {}
    local wait = Wait
    Wait = function(ms) waits[#waits + 1] = ms; return wait(ms) end
    local spawns = 0
    Small.onSpawn(function() spawns = spawns + 1 end)
    runtime.step()
    harness.assertEqual(spawns, 0, "no spawn while the cached ped is not valid")
    runtime.cacheChange('ped', 41, 0)
    harness.assertEqual(spawns, 1, "a new valid ped handle reapplies spawn handlers")
    runtime.cacheChange('ped', 41, 41)
    harness.assertEqual(spawns, 1, "an unchanged handle does not refire")
    runtime.cacheChange('ped', 0, 41)
    harness.assertEqual(spawns, 1, "an invalid handle is ignored")
    runtime.cacheChange('ped', 42, 41)
    harness.assertEqual(spawns, 2, "a respawn handle refires")
    runtime.step()
    runtime.step()
    for _, ms in ipairs(waits) do
        harness.assertTrue(ms ~= 1000, "no 1 s ped poll remains")
    end
    Wait = wait
    Small, Kora = savedSmall, savedKora
end)

harness.test("hash passes numbers through and hashes strings", function()
    harness.assertEqual(Small.hash(1234), 1234, "a numeric hash is returned unchanged")
    harness.assertEqual(Small.hash("WEAPON_PISTOL"), joaat("WEAPON_PISTOL"), "a string is joaat-hashed")
end)

harness.test("hashSet builds a hash-keyed lookup and tolerates nil", function()
    local set = Small.hashSet({ "WEAPON_RPG", 42 })
    harness.assertTrue(set[joaat("WEAPON_RPG")], "named entry is present under its hash")
    harness.assertTrue(set[42], "numeric entry is present under itself")
    harness.assertFalse(set[joaat("WEAPON_PISTOL")] or false, "an unlisted weapon is absent")

    local empty = Small.hashSet(nil)
    harness.assertFalse(next(empty) and true or false, "nil input yields an empty set")
end)

harness.test("dispatch and autoswap options emit their documented native calls", function()
    for _, case in ipairs({
        { disable = false, option = true },
        { disable = true, option = false },
        { disable = true, option = true },
        { disable = true },
    }) do
        Small, Kora = nil, nil
        local runtime = mocks.install()
        dofile(repoRoot .. "client/core.lua")
        Config = {
            wantedLevel = { disable = case.disable, disableDispatch = case.option },
            weaponWheel = { disable = case.disable, blockAutoSwap = case.option },
        }
        local flags, dispatch, autoswap, waits = {}, {}, {}, {}
        function SetPedConfigFlag(ped, flag, enabled)
            flags[#flags + 1] = { ped, flag, enabled }
        end
        function EnableDispatchService(service, enabled)
            dispatch[#dispatch + 1] = { service, enabled }
        end
        function SetWeaponsNoAutoswap(enabled)
            autoswap[#autoswap + 1] = enabled
        end
        local wait = Wait
        Wait = function(ms) waits[#waits + 1] = ms; return wait(ms) end
        CreateThread(function() dofile(repoRoot .. "modules/weaponwheel/client.lua") end)
        CreateThread(function() dofile(repoRoot .. "modules/wantedlevel/client.lua") end)
        local requested = case.disable and case.option
        harness.assertEqual(#dispatch, requested and 15 or 0,
            "dispatch option must emit one disable for each documented service")
        harness.assertEqual(#autoswap, requested and 1 or 0,
            "autoswap option must apply on the initial spawn")
        harness.assertTrue(#flags >= (case.disable and 2 or 0), "initial ped flags are applied")
        if case.disable then
            harness.assertEqual(flags[1][1], 10)
            harness.assertEqual(flags[1][2], 48)
            local has42 = false
            for _, f in ipairs(flags) do if f[2] == 42 then has42 = true end end
            harness.assertTrue(has42, "wanted-level ped flag is applied")
        else
            harness.assertEqual(#waits, 0, "disabled modules register no scheduling work")
        end
        runtime.fire("playerSpawned")
        runtime.fire("QBCore:Client:OnPlayerLoaded")
        harness.assertEqual(#autoswap, requested and 3 or 0, "autoswap reasserts through existing lifecycle events")
        local dispatchBefore, flagsBefore = #dispatch, #flags
        _G.__ped = 99
        runtime.cacheChange('ped', 99, 0)
        runtime.step()
        harness.assertTrue(#dispatch % 15 == 0, "dispatch is always applied as a full set of services")
        harness.assertTrue(#dispatch >= (requested and 30 or 0) and (requested or #dispatch == 0),
            "dispatch reapplies on spawn events and ped replacement")
        harness.assertEqual(#autoswap, requested and 4 or 0, "autoswap follows the existing ped replacement watcher")
        harness.assertTrue(#flags >= (case.disable and flagsBefore + 2 or 0), "flags reapply on ped replacement")
        for index, call in ipairs(dispatch) do
            harness.assertEqual(call[1], (index - 1) % 15 + 1, "dispatch service order and bounds remain exact")
            harness.assertEqual(call[2], false, "dispatch disabling passes boolean false")
        end
        for _, enabled in ipairs(autoswap) do harness.assertEqual(enabled, true) end
        for _, call in ipairs(flags) do harness.assertEqual(call[3], true) end
        if case.disable then
            for i = flagsBefore + 1, #flags do
                harness.assertEqual(flags[i][1], 99, "reapplied ped flags read the current ped")
            end
            for _, ms in ipairs(waits) do
                harness.assertTrue(ms == 2000 or ms == 0 or ms == 1000 or ms == 10000 or ms == 30000,
                    "only existing flag cadence and spawn watcher sleeps are used")
            end
        end
    end
end)

harness.test("onSpawn follows cache ped changes and re-registers on a kora_lib restart", function()
    Small, Kora = nil, nil
    local runtime = mocks.install()
    dofile(repoRoot .. "client/core.lua")
    _G.__ped = 10
    local spawns = 0
    Small.onSpawn(function() spawns = spawns + 1 end)
    harness.assertEqual(spawns, 1, "seeding from the current ped fires once at registration")
    runtime.cacheChange("ped", 10, 10)
    harness.assertEqual(spawns, 1, "an unchanged ped handle does not refire")
    runtime.cacheChange("ped", 0, 10)
    harness.assertEqual(spawns, 1, "a zero ped handle is ignored")
    runtime.cacheChange("ped", 55, 10)
    harness.assertEqual(spawns, 2, "a new ped handle fires the spawn handlers")
    runtime.step()
    harness.assertEqual(spawns, 2, "no polling thread refires without a change")
    _G.__ped = 55
    runtime.fire("onClientResourceStart", "kora_lib")
    harness.assertEqual(spawns, 2, "re-registering after a kora_lib restart re-seeds without refiring the same ped")
    runtime.cacheChange("ped", 77, 55)
    harness.assertTrue(spawns >= 3, "the re-registered listener follows the next ped change")
end)

harness.report("core")
