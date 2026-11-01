local root = (debug.getinfo(1, 'S').source:match('@?(.*/)') or './') .. '../../'
local tasks, calls = {}, {}
local ped = 42
Kora = { cache = { ped = function() return ped end } }
Small = { onInterval = function(interval, fn)
    assert(interval == 2000)
    tasks[#tasks + 1] = fn
end, onSpawn = function(fn) tasks[#tasks + 1] = fn end }
local wanted = { max = 0, set = 0, cleared = 0, level = 3 }
function PlayerId() return 0 end
function SetMaxWantedLevel() wanted.max = wanted.max + 1 end
function GetPlayerWantedLevel() return wanted.level end
function SetPlayerWantedLevel() wanted.set = wanted.set + 1; wanted.level = 0 end
function SetPlayerWantedLevelNow() end
function ClearPlayerWantedLevel() wanted.cleared = wanted.cleared + 1 end
function EnableDispatchService() end
function CreateThread() end
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
assert(#tasks == 3 and #calls == 2, 'enabled flags apply immediately; wanted level also reapplies on spawn')
assert(wanted.max == 1 and wanted.set == 1 and wanted.cleared == 1, 'a leaked wanted level is capped and cleared')
assert(calls[1][2] == 42 and calls[2][2] == 48)
ped = 99
for _, task in ipairs(tasks) do task() end
assert(#calls == 4 and calls[3][1] == 99 and calls[4][1] == 99, 'ticks must read the current ped')
assert(calls[3][3] == true and calls[4][3] == true)
print('PASS ped flags: disabled, initial application, interval and ped replacement')
