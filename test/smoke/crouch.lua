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
        proneAnimDict = 'move_crawl',
        proneForwardAnim = 'onfront_fwd',
        proneBackwardAnim = 'onfront_bwd',
        proneTurnSpeed = 1.0,
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
    H.assertEqual(_G.__movementClipset, nil)
    H.assertEqual(_G.__strafeClipset, nil)
    H.assertEqual(_G.__lastAnimation.dict, 'move_crawl')
    H.assertEqual(_G.__lastAnimation.clip, 'onfront_fwd')
    H.assertEqual(_G.__lastAnimation.animTime, 1.0)

    runtime.keybind('qbsmallresources_crouch', 'released')
    H.assertEqual(_G.__lastAnimation.clip, 'onfront_fwd')

    runtime.control(32, true)
    runtime.step()
    H.assertEqual(_G.__lastAnimation.clip, 'onfront_fwd')
    H.assertEqual(_G.__lastAnimation.flag, 2)
    H.assertEqual(_G.__lastAnimation.animTime, nil)

    runtime.advanceTime(820)
    runtime.step()
    H.assertEqual(_G.__lastAnimation.clip, 'onfront_fwd')

    runtime.control(32, false)
    runtime.control(33, true)
    runtime.step()
    H.assertEqual(_G.__lastAnimation.clip, 'onfront_bwd')

    runtime.control(33, false)
    runtime.step()
    H.assertEqual(_G.__lastAnimation.clip, 'onfront_bwd')
    H.assertEqual(_G.__lastAnimation.animTime, 1.0)

    runtime.control(34, true)
    runtime.step()
    H.assertEqual(_G.__heading, 1.0)

    runtime.control(34, false)
    runtime.keybind('qbsmallresources_crouch', 'pressed')
    runtime.keybind('qbsmallresources_crouch', 'released')
    H.assertEqual(_G.__lastAnimation, nil)
end)

H.report('crouch')
