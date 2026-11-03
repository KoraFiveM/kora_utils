local root = (debug.getinfo(1, 'S').source:match('@?(.*/)') or './') .. '../../'
local tasks, calls, frames, starHides = {}, {}, {}, 0
local ped = 42
local frameActive = nil
Kora = { cache = { ped = function() return ped end } }
Small = { onInterval = function(interval, fn)
    assert(interval == 2000)
    tasks[#tasks + 1] = fn
end, onSpawn = function(fn) tasks[#tasks + 1] = fn end,
    onFrame = function(fn)
        frames[#frames + 1] = fn
        frameActive = true
        return function(on) frameActive = on ~= false end
    end }
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
assert(#tasks == 3 and #calls == 2, 'enabled flags apply immediately; wanted level also reapplies on spawn')
assert(wanted.max == 1 and wanted.set == 1 and wanted.cleared == 1, 'a leaked wanted level is capped and cleared')
assert(calls[1][2] == 42 and calls[2][2] == 48)
assert(#frames == 1, 'wanted star hide shares the coordinator frame thread')
assert(frameActive == true, 'the star hide runs while a leaked level is being cleared')
frames[1]()
assert(starHides == 1, 'frame task hides the wanted star component')
local interval = tasks[2]
interval()
assert(frameActive == false, 'no per-frame star hide once the level stays at 0')
local before = #calls
interval()
assert(#calls == before, 'the interval only caps the wanted level, it does not re-apply ped flags')
wanted.level = 2; interval()
assert(frameActive == true and wanted.level == 0, 'a level that slips through is cleared and hidden')
ped = 99
tasks[1](); tasks[3]()
assert(#calls == 4 and calls[3][1] == 99 and calls[4][1] == 99, 'spawn re-applies flags to the current ped')
assert(calls[3][2] == 42 and calls[4][2] == 48 and calls[3][3] == true and calls[4][3] == true)
print('PASS ped flags: disabled, initial application, interval and ped replacement')
