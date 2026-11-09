local root = (debug.getinfo(1, 'S').source:match('@?(.*/)') or './') .. '../../'
local tasks, calls, frames, starHides = {}, {}, {}, 0
local ped = 42
Kora = { cache = { ped = function() return ped end, playerId = function() return 0 end } }
Small = { onInterval = function(interval, fn)
    assert(interval == 2000 or interval == 10000 or interval == 30000)
    tasks[#tasks + 1] = fn
end, onSpawn = function(fn) tasks[#tasks + 1] = fn end,
    onFrame = function(fn) frames[#frames + 1] = fn end }
local wanted = { max = 0, set = 0, cleared = 0, level = 3 }
function PlayerId() return 0 end
function SetMaxWantedLevel() wanted.max = wanted.max + 1 end
function GetPlayerWantedLevel() return wanted.level end
function SetPlayerWantedLevel() wanted.set = wanted.set + 1; wanted.level = 0 end
function SetPlayerWantedLevelNow() end
function ClearPlayerWantedLevel() wanted.cleared = wanted.cleared + 1 end
function EnableDispatchService() end
function CreateThread() error('modules must schedule through Small, not raw threads') end
function HideHudComponentThisFrame(id) if id == 1 then starHides = starHides + 1 end end
function SetPedConfigFlag(entity, flag, enabled)
    calls[#calls + 1] = { entity, flag, enabled }
end

Config = { wantedLevel = { disable = false }, weaponWheel = { disable = false } }
dofile(root .. 'modules/wantedlevel/client.lua')
dofile(root .. 'modules/weaponwheel/client.lua')
assert(#tasks == 0 and #calls == 0 and #frames == 0, 'disabled features must do no work')

Config.wantedLevel.disable, Config.weaponWheel.disable = true, true
dofile(root .. 'modules/wantedlevel/client.lua')
dofile(root .. 'modules/weaponwheel/client.lua')
assert(#frames == 0, 'no per-frame work unless hideHudStar is explicitly enabled')
assert(#calls == 2, 'enabled flags apply immediately')
tasks, calls, wanted.max, wanted.set, wanted.cleared, wanted.level = {}, {}, 0, 0, 0, 3
Config.wantedLevel.hideHudStar = true
dofile(root .. 'modules/wantedlevel/client.lua')
dofile(root .. 'modules/weaponwheel/client.lua')
assert(#tasks == 5 and #calls == 2, 'flags apply immediately and reapply on spawn / safety-net intervals')
assert(wanted.max == 1 and wanted.set == 1 and wanted.cleared == 1, 'a leaked wanted level is capped and cleared')
assert(calls[1][2] == 42 and calls[2][2] == 48)
assert(#frames == 1, 'wanted star hide shares the coordinator frame thread')
frames[1]()
assert(starHides == 1, 'frame task hides the wanted star component')
ped = 99
for _, task in ipairs(tasks) do task() end
assert(#calls > 2, 'spawn and safety-net ticks reapply the ped flags')
for i = 3, #calls do assert(calls[i][1] == 99 and calls[i][3] == true, 'ticks must read the current ped') end
print('PASS ped flags: disabled, initial application, interval and ped replacement')
