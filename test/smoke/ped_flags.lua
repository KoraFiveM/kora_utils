local root = (debug.getinfo(1, 'S').source:match('@?(.*/)') or './') .. '../../'
local tasks, calls = {}, {}
local ped = 42
QB = { cache = { ped = function() return ped end } }
Small = { onInterval = function(interval, fn)
    assert(interval == 2000)
    tasks[#tasks + 1] = fn
end }
function SetPedConfigFlag(entity, flag, enabled)
    calls[#calls + 1] = { entity, flag, enabled }
end

Config = { wantedLevel = { disable = false }, weaponWheel = { disable = false } }
dofile(root .. 'modules/wantedlevel/client.lua')
dofile(root .. 'modules/weaponwheel/client.lua')
assert(#tasks == 0 and #calls == 0, 'disabled features must do no work')

Config.wantedLevel.disable, Config.weaponWheel.disable = true, true
dofile(root .. 'modules/wantedlevel/client.lua')
dofile(root .. 'modules/weaponwheel/client.lua')
assert(#tasks == 2 and #calls == 2, 'enabled flags apply immediately and share the interval coordinator')
assert(calls[1][2] == 42 and calls[2][2] == 48)
ped = 99
for _, task in ipairs(tasks) do task() end
assert(#calls == 4 and calls[3][1] == 99 and calls[4][1] == 99, 'ticks must read the current ped')
assert(calls[3][3] == true and calls[4][3] == true)
print('PASS ped flags: disabled, initial application, interval and ped replacement')
