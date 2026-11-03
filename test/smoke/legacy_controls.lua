local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)')
local root = scriptDir .. '../../'
local frame, events, provided, calls, owner = nil, {}, {}, {}, 'radial'
function GetCurrentResourceName() return 'kora_utils' end
function GetInvokingResource() return owner end
function AddEventHandler(name, fn) events[name]=fn end
function exports(name, fn) provided[name]=fn end
function DisableControlAction(group, control, disabled) calls[#calls+1]={group,control,disabled} end
local active
Small = { onFrame=function(fn) assert(not frame, 'one coordinator registration'); frame=fn; active=true; return function(on) active=on~=false end end }
Kora = {compat=dofile(root .. '../kora_lib/compat/provider.lua')()}
dofile(root .. 'client/compat.lua')
local function legacy(name)
 local fn; events['__cfx_export_qb-smallresources_'..name](function(value) fn=value end); return fn
end
assert(legacy('addDisableControls')==provided.addDisableControls)
assert(legacy('addDisableControls')({24,25})==nil); frame()
assert(#calls==2 and calls[1][1]==2 and calls[1][2]==24 and calls[1][3]==true)
legacy('removeDisableControls')(24);calls={};frame();assert(#calls==1 and calls[1][2]==25)
legacy('addDisableControls')(25);legacy('removeDisableControls')(25)
assert(#provided.getDisableControls()==1, 'remove first duplicate as upstream')
owner='other';provided.addDisableControls(75);events.onClientResourceStop('radial')
calls={};frame();assert(#calls==1 and calls[1][2]==75,'stopped owner controls cleaned')
provided.addDisableControls({[2]=24});assert(#provided.getDisableControls()==1,'sparse arrays rejected')
provided.removeDisableControls(75);calls={};frame();assert(#calls==0,'removed controls stop suppression')
assert(active==false,'frame task pauses once no control is disabled')
provided.addDisableControls(24);assert(active==true,'frame task resumes on the next add')
events.onClientResourceStop('other');assert(active==false,'owner stop that empties the list pauses the task')
print('qbsmallresources legacy controls: 11 checks passed')
