local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)') or './'
local testDir = scriptDir .. '../'
local repoRoot = testDir .. '../'
package.path = testDir .. '?.lua;' .. package.path

local harness = require('harness')
local handle = require('mocks').install()

dofile(repoRoot .. 'config.lua')
dofile(repoRoot .. 'client/core.lua')
dofile(repoRoot .. 'modules/vehiclerewards/client.lua')

harness.test('vehicle rewards are disabled on spawn', function()
    harness.assertTrue(_G.__vehicleRewardDisables >= 1,
        'the initial player spawn must suppress GTA vehicle weapon rewards')

    local before = _G.__vehicleRewardDisables
    handle.fire('playerSpawned')
    harness.assertEqual(_G.__vehicleRewardDisables, before + 1,
        'the suppression must be reapplied after each respawn')
end)

harness.test('vehicle reward module is config-gated', function()
    local file = assert(io.open(repoRoot .. 'modules/vehiclerewards/client.lua', 'r'))
    local source = file:read('*a')
    file:close()
    harness.assertTrue(source:find('if not cfg.disable then return end', 1, true) ~= nil,
        'disabling the feature must avoid registering any lifecycle work')
end)

harness.report('vehicle_rewards')
