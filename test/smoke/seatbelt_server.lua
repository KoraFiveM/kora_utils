local dir = debug.getinfo(1,'S').source:match('@?(.*/)')
local root=dir..'../../'
local h=dofile(root..'test/harness.lua')
local events, lifecycle, callbacks, messages, timeouts={}, {}, {}, {}, {}
local clock, vehicle, body, bucket, kind = 0, 70, 1000, 0, 'automobile'
local item, usable, writes, removals, failWrite, duringWrite
local function restore(uses)
 item={name='harness',slot=3,amount=1,info={uses=uses,label='keep'},metadata={uses=uses,label='keep'}}
 writes,removals,failWrite,duringWrite=0,0,false,nil
end
Config={HarnessUses=20,seatbelt={enabled=true,equipDuration=5000,actionLifetime=30000,crashCooldown=1000}}
function GetPlayerPed(src) return src==1 and 10 or 20 end
function GetVehiclePedIsIn(ped) return ped==10 and vehicle or 80 end
function DoesEntityExist() return true end
function GetPlayerRoutingBucket() return 0 end
function GetEntityRoutingBucket() return bucket end
function GetVehicleType() return kind end
function GetVehicleBodyHealth() return body end
function GetGameTimer() return clock end
function SetTimeout(_,fn) timeouts[#timeouts+1]=fn end
function TriggerClientEvent(name,target,...) messages[#messages+1]={name=name,target=target,args={...}} end
function RegisterNetEvent(name,fn) events[name]=fn end
function AddEventHandler(name,fn) lifecycle[name]=fn end
function GetCurrentResourceName() return 'kora_utils' end
QB={callback={register=function(name,fn) callbacks[name]=fn end}}
exports={kora_core={
 getItemBySlot=function(_,src,slot) return src==1 and item and slot==item.slot and item end,
 createUseable=function(_,name,fn) assert(name=='harness');usable=fn end,
 removeItem=function(_,src,name,count,slot)
  assert(src==1 and name=='harness' and count==1 and slot==3)
  if failWrite then return false end
  removals=removals+1;item=nil;return true
 end,
},['qb-inventory']={SetItemData=function(_,src,name,key,value,slot)
 assert(src==1 and name=='harness' and key=='info' and slot==3)
 if duringWrite then duringWrite() end
 if failWrite then return false end
 writes=writes+1; item.info=value;item.metadata={uses=value.uses,label=value.label};return true
end}}
dofile(root..'modules/seatbelt/server.lua')
local function fire(name,...) source=1;events[name](...) end
local function begin(uses)
 fire('qbsmallresources:server:leaveVehicle');restore(uses);body=1000;vehicle=70;bucket=0;kind='automobile'
 usable(1,{slot=3,info={uses=999}})
 return messages[#messages].args[2]
end
local function finish(token) clock=clock+5000;return callbacks['qbsmallresources:server:finishHarness'](1,{slot=3},token) end
local function lastState() return messages[#messages].args[1] end
h.test('actual owned harness and supported vehicle are required before a use starts',function()
 restore(3);local count=#messages;usable(1,{slot=99});h.assertEqual(#messages,count)
 kind='bike';usable(1,{slot=3});h.assertEqual(#messages,count);kind='automobile'
 bucket=1;usable(1,{slot=3});h.assertEqual(#messages,count);bucket=0
end)
h.test('early completion, forged token and replay cannot equip or consume another item',function()
 local token=begin(3)
 h.assertFalse(callbacks['qbsmallresources:server:finishHarness'](1,{slot=3},'forged'))
 h.assertFalse(callbacks['qbsmallresources:server:finishHarness'](1,{slot=3},token))
 h.assertEqual(writes,0)
 token=begin(3);h.assertTrue(finish(token));h.assertTrue(lastState())
 h.assertEqual(item.info.uses,2);h.assertEqual(item.metadata.uses,2);h.assertEqual(item.info.label,'keep')
 h.assertFalse(finish(token));h.assertEqual(writes,1)
end)
h.test('legacy completion uses pending server item and ignores forged client durability',function()
 begin(4);clock=clock+5000;fire('equip:harness',{slot=3,info={uses=999}})
 h.assertTrue(lastState());h.assertEqual(item.info.uses,3)
end)
h.test('crash damage requires equipped ownership and fresh real body damage',function()
 local token=begin(3);h.assertTrue(finish(token))
 fire('seatbelt:DoHarnessDamage',999,{slot=99});h.assertEqual(writes,1)
 body=900;clock=clock+1000;source=2;events['seatbelt:DoHarnessDamage'](0,{slot=3});h.assertEqual(writes,1)
 fire('seatbelt:DoHarnessDamage',999,{slot=99});h.assertEqual(item.info.uses,1)
 fire('seatbelt:DoHarnessDamage',0,{slot=3});h.assertEqual(writes,2)
 body=800;clock=clock+1000;fire('seatbelt:DoHarnessDamage',999,{slot=99})
 h.assertEqual(removals,1);h.assertFalse(lastState())
end)
h.test('the final equipped use is consumed once and expires after the next impact',function()
 local token=begin(1);h.assertTrue(finish(token));h.assertEqual(removals,1);h.assertTrue(lastState())
 body=900;clock=clock+1000;fire('seatbelt:DoHarnessDamage');h.assertFalse(lastState());h.assertEqual(removals,1)
end)
h.test('cancellation, vehicle changes and failed mutations do not grant harness state',function()
 local token=begin(5);fire('qbsmallresources:server:cancelHarness',token);h.assertFalse(finish(token));h.assertEqual(writes,0)
 token=begin(5);vehicle=71;h.assertFalse(finish(token));h.assertEqual(writes,0)
 token=begin(5);failWrite=true;h.assertFalse(finish(token));h.assertEqual(writes,0)
end)
h.test('leave, disconnect and dependency stop invalidate pending and in-flight authority',function()
 local token=begin(5);duringWrite=function() fire('qbsmallresources:server:leaveVehicle') end
 h.assertFalse(finish(token));h.assertFalse(lastState())
 token=begin(5);source=1;lifecycle.playerDropped();h.assertFalse(finish(token))
 token=begin(5);lifecycle.onResourceStop('kora_inventory');h.assertFalse(finish(token))
end)
h.test('expired actions and removed items cannot be equipped',function()
 local token=begin(5);clock=clock+31000;h.assertFalse(finish(token));h.assertEqual(writes,0)
 token=begin(5);item=nil;h.assertFalse(finish(token))
end)
h.report('seatbelt server')
