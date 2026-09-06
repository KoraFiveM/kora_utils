local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)') or './'
local testDir = scriptDir .. '../'
local root = testDir .. '../'
package.path = testDir .. '?.lua;' .. package.path

local H = require('harness')
local Mocks = require('mocks')
local runtime = Mocks.install()

Config = {
    crouch = {
        enabled = true,
        keybind = 'LCONTROL',
        holdDuration = 500,
        crouchClipset = 'move_ped_crouched',
        crouchStrafeClipset = 'move_ped_crouched_strafing',
        proneClipset = 'move_crawl',
    },
}

dofile(root .. '/client/core.lua')
dofile(root .. '/modules/crouch/client.lua')

H.test('registers a rebindable left-control action', function()
    local binding = _G.__keybinds.qbsmallresources_crouch
    H.assertEqual(binding.defaultKey, 'LCONTROL')
    H.assertEqual(binding.description, 'Toggle crouch / hold prone')
end)

H.test('a tap toggles a real crouched movement clipset and then standing', function()
    runtime.keybind('qbsmallresources_crouch', 'pressed')
    runtime.keybind('qbsmallresources_crouch', 'released')
    H.assertEqual(_G.__movementClipset, 'move_ped_crouched')
    H.assertEqual(_G.__strafeClipset, 'move_ped_crouched_strafing')

    runtime.keybind('qbsmallresources_crouch', 'pressed')
    runtime.keybind('qbsmallresources_crouch', 'released')
    H.assertEqual(_G.__movementClipset, nil)
    H.assertEqual(_G.__strafeClipset, nil)
end)

H.test('holding the bind enters a player-controlled prone locomotion state', function()
    runtime.keybind('qbsmallresources_crouch', 'pressed')
    runtime.step()
    H.assertEqual(_G.__movementClipset, 'move_crawl')
    H.assertEqual(_G.__strafeClipset, 'move_crawl')
    H.assertEqual(_G.__lastAnimation, nil)

    runtime.keybind('qbsmallresources_crouch', 'released')
    H.assertEqual(_G.__movementClipset, 'move_crawl')
end)

H.report('crouch')
