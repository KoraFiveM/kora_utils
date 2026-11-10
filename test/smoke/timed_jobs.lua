local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)')
local root = scriptDir .. '../../'
local events, provided, thread, waits, owner = {}, {}, nil, {}, 'jobres'
function GetCurrentResourceName() return 'kora_utils' end
function GetInvokingResource() return owner end
function AddEventHandler(name, fn) events[name]=fn end
function exports(name, fn) provided[name]=fn end
function CreateThread(fn) assert(not thread, 'one loop only'); thread=coroutine.create(fn); coroutine.resume(thread) end
function Wait(ms) waits[#waits+1]=ms; coroutine.yield() end
Kora = {compat=dofile(dofile(root .. 'test/resource_path.lua')(root, 'kora_lib') .. 'compat/provider.lua')()}
dofile(root .. 'server/timedjobs.lua')
local function legacy(name)
 local fn; events['__cfx_export_qb-smallresources_'..name](function(value) fn=value end); return fn
end
for _, name in ipairs({'CreateTimedJob','ForceRunTimedJob','StopTimedJob'}) do assert(legacy(name)==provided[name]) end
assert(thread==nil, 'no thread until a job exists')
assert(provided.CreateTimedJob('1', 0, print)==nil and provided.CreateTimedJob(1, 0, nil)==nil and thread==nil)
local ran = {}
local a = provided.CreateTimedJob(os.date('*t').hour, os.date('*t').min, function(d,h,m) ran[#ran+1]={d,h,m} end)
local b = provided.CreateTimedJob(99, 0, setmetatable({}, {__call=function() ran[#ran+1]='table' end}))
assert(a==1 and b==2 and thread and #waits==1 and waits[1]>0 and waits[1]<=60000)
provided.ForceRunTimedJob(a); assert(#ran==1 and ran[1][2]==os.date('*t').hour)
provided.ForceRunTimedJob(b); assert(ran[2]=='table')
provided.StopTimedJob(b); provided.ForceRunTimedJob(b); assert(#ran==2)
provided.ForceRunTimedJob(999)
local errored = provided.CreateTimedJob(0, 0, function() error('boom') end)
provided.ForceRunTimedJob(errored)
owner='other'; local c = provided.CreateTimedJob(0,0,function() end); events.onResourceStop('other'); provided.ForceRunTimedJob(c)
assert(provided.CreateTimedJob(1,1,print)==c+1, 'ids are never reused')
print('kora_utils timed jobs: all checks passed')
