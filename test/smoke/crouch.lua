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
        blockStockDuck = true,
    },
}

-- kora_lib's cache reports `false` (not nil) when the player is on foot.
_G.__vehicle = false

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

    runtime.keybind('qbsmallresources_prone_forward', 'pressed')
    H.assertEqual(_G.__lastAnimation.clip, 'onfront_fwd')
    H.assertEqual(_G.__lastAnimation.flag, 2)
    H.assertEqual(_G.__lastAnimation.animTime, nil)

    -- the step clip is replayed by its own timer while the key stays down
    _G.__lastAnimation = nil
    runtime.advanceTime(820)
    H.assertEqual(_G.__lastAnimation.clip, 'onfront_fwd')
    H.assertEqual(_G.__lastAnimation.flag, 2)

    runtime.keybind('qbsmallresources_prone_forward', 'released')
    runtime.keybind('qbsmallresources_prone_backward', 'pressed')
    H.assertEqual(_G.__lastAnimation.clip, 'onfront_bwd')

    runtime.keybind('qbsmallresources_prone_backward', 'released')
    H.assertEqual(_G.__lastAnimation.clip, 'onfront_bwd')
    H.assertEqual(_G.__lastAnimation.animTime, 1.0)

    runtime.keybind('qbsmallresources_prone_left', 'pressed')
    runtime.step()
    H.assertEqual(_G.__heading, 1.0)
    runtime.keybind('qbsmallresources_prone_left', 'released')
    runtime.keybind('qbsmallresources_prone_right', 'pressed')
    runtime.step()
    H.assertEqual(_G.__heading, 0.0)
    runtime.keybind('qbsmallresources_prone_right', 'released')
    runtime.step()
    H.assertEqual(_G.__heading, 0.0, 'turning stops when the key is released')

    runtime.keybind('qbsmallresources_crouch', 'pressed')
    runtime.keybind('qbsmallresources_crouch', 'released')
    H.assertEqual(_G.__lastAnimation, nil)
end)

H.test('event mode: no per-frame duck block on foot or in a vehicle', function()
    local disabled = {}
    local original = _G.DisableControlAction
    _G.DisableControlAction = function(_, control) disabled[control] = true end

    runtime.step()
    H.assertEqual(disabled[36], nil, 'on foot: control 36 is not disabled every frame')

    _G.__vehicle = 123
    runtime.cacheChange('vehicle', 123)
    runtime.step()
    H.assertEqual(disabled[36], nil, 'in a vehicle: control 36 left alone')

    _G.__vehicle = false
    runtime.cacheChange('vehicle', false)
    _G.DisableControlAction = original
end)

H.test('event mode: pressing the crouch key undoes the stock duck it also triggers', function()
    _G.__stealth = false
    runtime.keybind('qbsmallresources_crouch', 'pressed')
    _G.__stealth = true -- the game applies its own duck a frame later
    runtime.advanceTime(50)
    H.assertEqual(_G.__stealth, false, 'stealth from the same key press is cleared')
    runtime.keybind('qbsmallresources_crouch', 'released')
    runtime.keybind('qbsmallresources_crouch', 'pressed')
    runtime.keybind('qbsmallresources_crouch', 'released')
    runtime.advanceTime(1000)
    H.assertEqual(_G.__movementClipset, nil, 'standing again')
end)

H.test('event mode: stealth is left alone in a vehicle', function()
    _G.__vehicle = 123
    runtime.cacheChange('vehicle', 123)
    _G.__stealth = true
    runtime.keybind('qbsmallresources_crouch', 'pressed')
    runtime.advanceTime(200)
    H.assertEqual(_G.__stealth, true, 'the press does not touch stealth in a vehicle')
    _G.__vehicle = false
    runtime.cacheChange('vehicle', false)
    _G.__stealth = false
    -- end standing: release toggles crouch on, a second tap stands again
    runtime.keybind('qbsmallresources_crouch', 'released')
    runtime.keybind('qbsmallresources_crouch', 'pressed')
    runtime.keybind('qbsmallresources_crouch', 'released')
    runtime.advanceTime(1000)
    H.assertEqual(_G.__movementClipset, nil, 'standing again')
end)

H.test('registers rebindable prone movement keys', function()
    H.assertEqual(_G.__keybinds.qbsmallresources_prone_forward.defaultKey, 'W')
    H.assertEqual(_G.__keybinds.qbsmallresources_prone_backward.defaultKey, 'S')
    H.assertEqual(_G.__keybinds.qbsmallresources_prone_left.defaultKey, 'A')
    H.assertEqual(_G.__keybinds.qbsmallresources_prone_right.defaultKey, 'D')
end)

H.test('prone sprint and jump are only disabled while prone', function()
    local disabled = {}
    local original = _G.DisableControlAction
    _G.DisableControlAction = function(_, control) disabled[control] = true end

    runtime.step()
    H.assertEqual(disabled[21], nil, 'standing: no sprint block')

    runtime.keybind('qbsmallresources_crouch', 'pressed')
    runtime.step() -- hold timer elapses, prone starts
    runtime.step() -- first frame while prone
    H.assertEqual(disabled[21], true, 'prone: sprint blocked')
    H.assertEqual(disabled[22], true, 'prone: jump blocked')
    runtime.keybind('qbsmallresources_crouch', 'released')

    _G.DisableControlAction = original
    runtime.step()
    runtime.keybind('qbsmallresources_crouch', 'pressed')
    runtime.keybind('qbsmallresources_crouch', 'released')
end)

H.test('a key already held when prone starts begins crawling immediately', function()
    runtime.keybind('qbsmallresources_prone_forward', 'pressed')
    runtime.keybind('qbsmallresources_crouch', 'pressed')
    runtime.step()
    H.assertEqual(_G.__lastAnimation.clip, 'onfront_fwd')
    H.assertEqual(_G.__lastAnimation.flag, 2)
    H.assertEqual(_G.__lastAnimation.animTime, nil)
    runtime.keybind('qbsmallresources_prone_forward', 'released')
    runtime.keybind('qbsmallresources_crouch', 'released')
    runtime.keybind('qbsmallresources_crouch', 'pressed')
    runtime.keybind('qbsmallresources_crouch', 'released')
    H.assertEqual(_G.__lastAnimation, nil, 'standing again')
end)

H.test('controller stick drives prone crawling and turning from the prone frame task', function()
    runtime.keybind('qbsmallresources_crouch', 'pressed')
    runtime.step() -- hold elapses, prone starts
    runtime.control(32, true) -- stick up
    runtime.step()
    H.assertEqual(_G.__lastAnimation.clip, 'onfront_fwd')
    H.assertEqual(_G.__lastAnimation.flag, 2)

    runtime.control(32, false)
    runtime.step()
    H.assertEqual(_G.__lastAnimation.clip, 'onfront_fwd')
    H.assertEqual(_G.__lastAnimation.animTime, 1.0, 'stick released: back to idle')

    local heading = _G.__heading
    runtime.control(34, true) -- stick left
    runtime.step()
    runtime.control(34, false)
    H.assertEqual(_G.__heading, heading + 1.0)

    runtime.keybind('qbsmallresources_crouch', 'released')
    runtime.keybind('qbsmallresources_crouch', 'pressed')
    runtime.keybind('qbsmallresources_crouch', 'released')
    H.assertEqual(_G.__lastAnimation, nil, 'standing again')
end)

H.test('no timers or stance work remain while standing', function()
    runtime.keybind('qbsmallresources_crouch', 'pressed')
    runtime.keybind('qbsmallresources_crouch', 'released')
    H.assertEqual(_G.__movementClipset, 'move_ped_crouched')
    runtime.keybind('qbsmallresources_crouch', 'pressed')
    runtime.keybind('qbsmallresources_crouch', 'released')
    H.assertEqual(_G.__movementClipset, nil)
    runtime.advanceTime(1000)
    H.assertEqual(runtime.pendingTimers(), 0, 'the crouch tick stops once standing')
end)

H.test('the interrupt tick stands the ped up when it can no longer hold a stance', function()
    runtime.keybind('qbsmallresources_crouch', 'pressed')
    runtime.keybind('qbsmallresources_crouch', 'released')
    H.assertEqual(_G.__movementClipset, 'move_ped_crouched')

    _G.__ragdoll = true
    runtime.advanceTime(250)
    _G.__ragdoll = false
    H.assertEqual(_G.__movementClipset, nil, 'ragdoll cancels the crouch')
    H.assertEqual(runtime.pendingTimers(), 0)
end)

H.test('an emote standing the ped up is event driven, not polled', function()
    runtime.keybind('qbsmallresources_crouch', 'pressed')
    runtime.keybind('qbsmallresources_crouch', 'released')
    H.assertEqual(_G.__movementClipset, 'move_ped_crouched')

    runtime.stateBag('qbemotemenu:active', 'player:2', true)
    H.assertEqual(_G.__movementClipset, 'move_ped_crouched', 'another player\'s emote is ignored')

    runtime.stateBag('qbemotemenu:active', 'player:1', 'dance')
    H.assertEqual(_G.__movementClipset, nil)

    runtime.keybind('qbsmallresources_crouch', 'pressed')
    runtime.keybind('qbsmallresources_crouch', 'released')
    H.assertEqual(_G.__movementClipset, nil, 'cannot crouch during an emote')

    runtime.stateBag('qbemotemenu:active', 'player:1', false)
    runtime.keybind('qbsmallresources_crouch', 'pressed')
    runtime.keybind('qbsmallresources_crouch', 'released')
    H.assertEqual(_G.__movementClipset, 'move_ped_crouched')
    runtime.keybind('qbsmallresources_crouch', 'pressed')
    runtime.keybind('qbsmallresources_crouch', 'released')
end)

H.test('the stock duck stance (stealth) is cleared by the standing backstop check, and by crouch', function()
    _G.__stealth = true
    runtime.step()
    H.assertEqual(_G.__stealth, false, 'standing still: stealth from a stock duck tap is undone by the backstop check')

    _G.__stealth = true
    runtime.keybind('qbsmallresources_crouch', 'pressed')
    runtime.keybind('qbsmallresources_crouch', 'released')
    H.assertEqual(_G.__stealth, false, 'crouching clears stealth')
    H.assertEqual(_G.__movementClipset, 'move_ped_crouched')
    runtime.keybind('qbsmallresources_crouch', 'pressed')
    runtime.keybind('qbsmallresources_crouch', 'released')
end)

H.test("'frame' mode blocks the stock duck every frame on foot and releases it in a vehicle", function()
    Small, Kora = nil, nil
    local rt = Mocks.install()
    Config.crouch.blockStockDuck = 'frame'
    _G.__vehicle = false
    dofile(root .. '/client/core.lua')
    dofile(root .. '/modules/crouch/client.lua')

    local disabled = {}
    _G.DisableControlAction = function(_, control) disabled[control] = true end
    rt.step()
    H.assertEqual(disabled[36], true, 'on foot: control 36 blocked every frame')

    disabled = {}
    _G.__vehicle = 123
    rt.cacheChange('vehicle', 123)
    rt.step()
    H.assertEqual(disabled[36], nil, 'in a vehicle: control 36 left alone')

    _G.__vehicle = false
    rt.cacheChange('vehicle', false)
    disabled = {}
    rt.step()
    H.assertEqual(disabled[36], true, 'back on foot: blocked again')
    Config.crouch.blockStockDuck = true
end)

H.report('crouch')
