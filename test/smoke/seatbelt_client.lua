local dir=debug.getinfo(1,'S').source:match('@?(.*/)');local root=dir..'../../'
local h=dofile(root..'test/harness.lua')
local events,commands,exportsNative,frames,serverEvents,localEvents,controls={},{},{},{},{},{},{}
local vehicle,speed,body,clock,dead=70,60,1000,1000,false
local change,progressCallback,progress=true,nil,nil
local completed,accepted=true,true
local ejections,health,busyWrites=0,200,{}
Config={seatbelt={enabled=true,equipDuration=5000,crashCooldown=1000,keybind='B'}}
function AddEventHandler(name,fn) events[name]=fn end
function RegisterNetEvent(name,fn) events[name]=fn end
function RegisterCommand(name,fn) commands[name]=fn end
function RegisterKeyMapping() end
function exports(name,fn) exportsNative[name]=fn end
function GetVehicleClass() return 0 end
function PlayerPedId() return 10 end
function GetVehiclePedIsIn() return vehicle or 0 end
function GetEntitySpeed(entity) return entity==10 and 10 or speed end
function GetVehicleBodyHealth() return body end
function GetEntityVelocity() return {x=2,y=3,z=0} end
function IsEntityDead() return dead end
function IsPauseMenuActive() return false end
function GetGameTimer() return clock end
function DisableControlAction(group,id) controls[#controls+1]={group,id} end
function TriggerServerEvent(name,...) serverEvents[#serverEvents+1]={name=name,args={...}} end
function TriggerEvent(name,...) localEvents[#localEvents+1]={name=name,args={...}} end
function GetCurrentResourceName() return 'kora_utils' end
function GetOffsetFromEntityInWorldCoords() return {x=1,y=2,z=3} end
function SetEntityCoords() ejections=ejections+1 end
function SetPedToRagdoll() end
function SetEntityVelocity() end
function GetEntityHealth() return health end
function SetEntityHealth(_,value) health=value end
function SetVehicleEngineOn() end
LocalPlayer={state=setmetatable({}, {__index={set=function(self,key,value) self[key]=value;busyWrites[#busyWrites+1]={key,value} end}})}
Kora={compat=dofile(root..'../kora_lib/compat/provider.lua')(),
 cache={onChange=function(_,fn) change=fn end,vehicle=function() return vehicle end},
 progressbar={start=function() if progressCallback then progressCallback() end;return completed end,cancel=function() end},
 callback={trigger=function() return accepted end},notify={send=function() end}}
local frameActive=true
Small={onFrame=function(fn) frames[#frames+1]=fn;return function(on) frameActive=on~=false end end}
dofile(root..'modules/seatbelt/client.lua')
local function grant(on,uses) source=65535;events['qbsmallresources:client:harnessState'](on,uses) end
local function frame() if not frameActive then return end for _,fn in ipairs(frames) do fn() end end
h.test('seatbelt command and legacy exports reflect real exit-control state',function()
 h.assertFalse(exportsNative.HasSeatbeltOn());commands.toggleseatbelt();h.assertTrue(exportsNative.HasSeatbeltOn())
 frame();h.assertEqual(#controls,2);h.assertEqual(controls[1][2],75);h.assertTrue(LocalPlayer.state.seatbelt)
 commands.toggleseatbelt();h.assertFalse(exportsNative.HasSeatbeltOn())
end)
h.test('clients cannot self-grant harness via event or successful progress alone',function()
 source=0;events['qbsmallresources:client:harnessState'](true,100);h.assertFalse(exportsNative.HasHarness())
 source=65535;events['seatbelt:client:UseHarness']({slot=3},'token')
 h.assertFalse(exportsNative.HasHarness());h.assertFalse(LocalPlayer.state.inv_busy)
 grant(true,4);h.assertTrue(exportsNative.HasHarness());h.assertTrue(exportsNative.HasSeatbeltOn())
end)
h.test('cancelled progress and vehicle exit release busy and equipment state',function()
 completed=false;events['seatbelt:client:UseHarness']({slot=3},'cancel')
 h.assertFalse(LocalPlayer.state.inv_busy);h.assertEqual(serverEvents[#serverEvents].name,'qbsmallresources:server:cancelHarness')
 vehicle=nil;change(nil);h.assertFalse(exportsNative.HasHarness());h.assertFalse(exportsNative.HasSeatbeltOn())
 h.assertFalse(LocalPlayer.state.seatbelt)
end)
h.test('a qualifying impact ejects an unbelted player and drains health',function()
 vehicle=70;speed=60;body=1000;change(70);clock=5000;frame()
 local random=math.random;math.random=function(maximum) return maximum end
 speed=10;body=900;clock=5100;frame();clock=5200;frame();math.random=random
 h.assertEqual(ejections,1);h.assertTrue(health<200)
end)
h.test('harness absorbs the same impact and requests server-validated damage',function()
 vehicle=nil;change(nil);vehicle=70;speed=60;body=1000;change(70);grant(true,3);clock=7000;frame()
 local random=math.random;math.random=function(maximum) return maximum end
 speed=10;body=900;clock=7100;frame();clock=7200;frame();math.random=random
 h.assertEqual(ejections,1);h.assertEqual(serverEvents[#serverEvents].name,'seatbelt:DoHarnessDamage')
 grant(false,0);h.assertFalse(exportsNative.HasHarness())
end)
h.test('progress errors and resource stop clean UI state',function()
 progressCallback=function() error('controlled progress failure') end
 events['seatbelt:client:UseHarness']({slot=3},'error');h.assertFalse(LocalPlayer.state.inv_busy)
 grant(true,2);events.onClientResourceStop('kora_utils')
 h.assertFalse(exportsNative.HasHarness());h.assertFalse(LocalPlayer.state.inv_busy);h.assertFalse(LocalPlayer.state.seatbelt)
end)
h.test('frame work pauses on foot and resumes in a vehicle',function()
 vehicle=nil;change(nil);frame();h.assertFalse(frameActive)
 local before=#controls;commands.toggleseatbelt();frame();h.assertEqual(#controls,before)
 vehicle=70;change(70);h.assertTrue(frameActive)
end)
h.test('kora_lib restart re-registers the vehicle listener and re-seeds',function()
 change=nil;vehicle=70;events.onClientResourceStart('other');h.assertEqual(change,nil)
 events.onClientResourceStart('kora_lib');h.assertTrue(change~=nil);h.assertTrue(frameActive)
 vehicle=nil;change(nil);frame();h.assertFalse(frameActive)
end)
h.report('seatbelt client')
