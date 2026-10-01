-- Smoke tests for the shared tick coordinator (client/core.lua) and the small
-- hashing helpers (client/util.lua). These are the parts of qbsmallresources
-- with real logic to verify; the feature modules themselves are thin wrappers
-- of native calls exercised via the coordinator, covered by config-gating
-- assertions below.
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
    -- The frame thread was resumed once when it started (on the first onFrame),
    -- running whatever was registered at that instant. step() drives one more
    -- full frame with both tasks present.
    handle.step()
    harness.assertTrue(a >= 1 and b >= 1, "both frame tasks should have run")
    local aBefore, bBefore = a, b
    handle.step()
    harness.assertEqual(a, aBefore + 1, "task a should advance exactly one per step")
    harness.assertEqual(b, bBefore + 1, "task b should advance exactly one per step")
end)

harness.test("onInterval shares one thread per distinct interval", function()
    local calls = 0
    Small.onInterval(2000, function() calls = calls + 1 end)
    Small.onInterval(2000, function() calls = calls + 1 end)
    handle.step()
    -- Two tasks on the same interval both run on each tick of the single shared
    -- thread -> +2 per step (the initial resume already ran them once too).
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
        Small, QB = nil, nil
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
        -- Each client chunk has its own yielding FiveM host execution.
        CreateThread(function() dofile(repoRoot .. "modules/wantedlevel/client.lua") end)
        CreateThread(function() dofile(repoRoot .. "modules/weaponwheel/client.lua") end)
        local requested = case.disable and case.option
        harness.assertEqual(#dispatch, requested and 15 or 0,
            "dispatch option must emit one disable for each documented service")
        harness.assertEqual(#autoswap, requested and 1 or 0,
            "autoswap option must apply on the initial spawn")
        harness.assertEqual(#flags, case.disable and 2 or 0, "existing initial ped flags remain")
        if case.disable then
            harness.assertEqual(flags[1][1], 10)
            harness.assertEqual(flags[1][2], 42)
            harness.assertEqual(flags[2][2], 48)
        else
            harness.assertEqual(#waits, 0, "disabled modules register no scheduling work")
        end
        runtime.fire("playerSpawned")
        runtime.fire("QBCore:Client:OnPlayerLoaded")
        harness.assertEqual(#autoswap, requested and 3 or 0, "autoswap reasserts through existing lifecycle events")
        _G.__ped = 99
        runtime.step()
        harness.assertEqual(#dispatch, requested and 30 or 0, "dispatch reuses the existing periodic work")
        harness.assertEqual(#autoswap, requested and 4 or 0, "autoswap follows the existing ped replacement watcher")
        harness.assertEqual(#flags, case.disable and 4 or 0, "existing flag cadence remains")
        for index, call in ipairs(dispatch) do
            harness.assertEqual(call[1], (index - 1) % 15 + 1, "dispatch service order and bounds remain exact")
            harness.assertEqual(call[2], false, "dispatch disabling passes boolean false")
        end
        for _, enabled in ipairs(autoswap) do harness.assertEqual(enabled, true) end
        for _, call in ipairs(flags) do harness.assertEqual(call[3], true) end
        if case.disable then
            harness.assertEqual(flags[3][1], 99, "periodic wanted flag reads the current ped")
            harness.assertEqual(flags[4][1], 99, "periodic wheel flag reads the current ped")
            for _, ms in ipairs(waits) do
                harness.assertTrue(ms == 2000 or (requested and ms == 1000),
                    "only existing flag cadence and spawn watcher sleeps are used")
            end
        end
    end
end)

harness.report("core")
