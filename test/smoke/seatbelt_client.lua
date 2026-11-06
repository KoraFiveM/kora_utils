local dir=debug.getinfo(1,'S').source:match('@?(.*/)');local root=dir..'../../'
local h=dofile(root..'test/harness.lua')
local events,commands,exportsNative,frames,serverEvents,localEvents,controls={},{},{},{},{},{},{}
local vehicle,speed,body,clock,dead=70,60,1000,1000,false
local change,progressCallback,progress=true,nil,nil
local completed,accepted=true,true
local ejections,health,busyWrites=0,200,{}
local keyMappings,notices,callbackResult,callbackCalls={},{},true,{}
Config={seatbelt={enabled=true,equipDuration=5000,crashCooldown=1000,keybind='B',
 harness={separateFromSeatbelt=true,command='raceharness',keybind='',lockInventory=false}}}
function CreateThread(fn) fn() end
function AddEventHandler(name,fn) events[name]=fn end
function RegisterNetEvent(name,fn) events[name]=fn end
function RegisterCommand(name,fn) commands[name]=fn end
function RegisterKeyMapping(command,label,mapper,key) keyMappings[command]={label,mapper,key} end
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
 callback={trigger=function(name,...) callbackCalls[#callbackCalls+1]=name
  if name=='qbsmallresources:server:toggleHarness' then return callbackResult end
  return accepted end},notify={send=function(n) notices[#notices+1]=n end}}
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
 grant(true,4);h.assertTrue(exportsNative.HasHarness());h.assertFalse(exportsNative.HasSeatbeltOn())
end)
h.test('separate harness: never toggles the belt, belt key never removes it, harness alone blocks exit',function()
 h.assertTrue(exportsNative.HasHarness());h.assertFalse(LocalPlayer.state.seatbelt);h.assertTrue(LocalPlayer.state.harness)
 local last=localEvents[#localEvents];h.assertEqual(last.name,'seatbelt:client:ToggleHarness');h.assertTrue(last.args[1])
 local before=#controls;frame();h.assertEqual(#controls,before+2);h.assertEqual(controls[#controls][2],75)
 grant(true,0);local sent=#serverEvents
 commands.toggleseatbelt();h.assertTrue(exportsNative.HasSeatbeltOn());h.assertTrue(exportsNative.HasHarness())
 h.assertEqual(serverEvents[#serverEvents].name,'InteractSound_SV:PlayWithinDistance');h.assertEqual(#serverEvents,sent+1)
 grant(false,0);h.assertTrue(exportsNative.HasSeatbeltOn());h.assertFalse(exportsNative.HasHarness());h.assertFalse(LocalPlayer.state.harness)
 commands.toggleseatbelt();h.assertFalse(exportsNative.HasSeatbeltOn())
 before=#controls;frame();h.assertEqual(#controls,before)
end)
h.test('race harness command and key mapping ask the server and report a missing item',function()
 h.assertTrue(commands.raceharness~=nil);h.assertEqual(keyMappings.raceharness[3],'')
 callbackResult='noitem';commands.raceharness()
 h.assertEqual(callbackCalls[#callbackCalls],'qbsmallresources:server:toggleHarness')
 h.assertEqual(notices[#notices].message,'You do not have a race harness to use')
 local count=#notices;callbackResult='removing';commands.raceharness();h.assertEqual(#notices,count)
 local calls=#callbackCalls;vehicle=nil;change(nil);commands.raceharness();h.assertEqual(#callbackCalls,calls)
 vehicle=70;change(70)
end)
h.test('harness progress leaves inv_busy to kora_inventory and a refused start cancels the pending action',function()
 local writes=#busyWrites;completed=true;events['seatbelt:client:UseHarness']({slot=false},'k1')
 for i=writes+1,#busyWrites do h.assertTrue(busyWrites[i][1]~='inv_busy','no inv_busy write') end
 LocalPlayer.state.inv_busy=true;events['seatbelt:client:UseHarness']({slot=3},'k2')
 h.assertEqual(serverEvents[#serverEvents].name,'qbsmallresources:server:cancelHarness');h.assertEqual(serverEvents[#serverEvents].args[1],'k2')
 LocalPlayer.state.inv_busy=nil
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
