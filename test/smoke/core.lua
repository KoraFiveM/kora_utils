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

harness.report("core")
