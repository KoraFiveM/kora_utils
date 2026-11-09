local scriptDir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"
local testDir = scriptDir .. "../"
local repoRoot = testDir .. "../"
package.path = testDir .. "?.lua;" .. package.path

local harness = require("harness")
local mocks = require("mocks")

local handle = mocks.install()

Config = {
    blacklist = {
        weapons = { "WEAPON_RPG", "WEAPON_MINIGUN" },
        notifyOnStrip = true,
        vehicles = { "rhino" },
        peds = {},
    },
}

dofile(repoRoot .. "client/core.lua")
dofile(repoRoot .. "client/util.lua")
dofile(repoRoot .. "modules/blacklist/client.lua")
dofile(repoRoot .. "modules/blacklist/server.lua")

harness.test("client strips a held blacklisted weapon and notifies", function()
    _G.__removedWeapons = {}
    _G.__notifications = {}
    _G.__selectedWeapon = joaat("WEAPON_RPG")

    handle.cacheChange("weapon", joaat("WEAPON_RPG"), joaat("WEAPON_UNARMED"))

    harness.assertTrue(_G.__removedWeapons[joaat("WEAPON_RPG")], "the RPG should have been removed")
    harness.assertTrue(#_G.__notifications >= 1, "the player should have been notified")
end)

harness.test("client leaves a non-blacklisted weapon alone", function()
    _G.__removedWeapons = {}
    _G.__notifications = {}
    _G.__selectedWeapon = joaat("WEAPON_PISTOL")

    handle.cacheChange("weapon", joaat("WEAPON_PISTOL"), joaat("WEAPON_UNARMED"))

    harness.assertFalse(_G.__removedWeapons[joaat("WEAPON_PISTOL")] or false, "an allowed weapon must not be removed")
    harness.assertEqual(#_G.__notifications, 0, "no notification for an allowed weapon")
end)

harness.test("server cancels the spawn of a blacklisted vehicle", function()
    _G.__cancelled = false
    _G.__entityModel = joaat("rhino")

    handle.fire("entityCreating", 5)

    harness.assertTrue(_G.__cancelled, "spawning a blacklisted model must CancelEvent")
end)

harness.test("server allows the spawn of a non-blacklisted vehicle", function()
    _G.__cancelled = false
    _G.__entityModel = joaat("adder")

    handle.fire("entityCreating", 6)

    harness.assertFalse(_G.__cancelled, "an allowed model must not be cancelled")
end)

harness.report("blacklist")
