local dir=debug.getinfo(1,'S').source:match('@?(.*/)');local resource=dir..'../../';local inv=dofile(resource..'test/resource_path.lua')(resource,'kora_inventory')
local function copy(v) if type(v)~='table' then return v end local out={} for k,x in pairs(v) do out[k]=copy(x) end return out end
local player={citizenid='HARNESS',items={[3]={name='harness',amount=1,slot=3,info={uses=5,label='keep'},metadata={uses=99}}}}
local writes, usable, callback, now = 0,nil,nil,0
function GetCurrentResourceName() return 'kora_utils' end
function GetInvokingResource() return 'kora_utils' end
function GetGameTimer() return now end
function CreateThread() end
function AddEventHandler() end
function RegisterNetEvent() end
function RegisterCommand() end
function TriggerEvent() end
function TriggerClientEvent() end
function SetTimeout() end
function GetPlayerPed() return 10 end
function GetVehiclePedIsIn() return 70 end
function DoesEntityExist() return true end
function GetPlayerRoutingBucket() return 0 end
function GetEntityRoutingBucket() return 0 end
function GetVehicleType() return 'automobile' end
function GetVehicleBodyHealth() return 1000 end
Kora={resources={serverRegistry=function() return {track=function() end,untrack=function() end} end},
 callback={register=function(name,fn) if name=='qbsmallresources:server:finishHarness' then callback=fn end end}}
local core={
 getShared=function(_,_,name) return name=='harness' and {name='harness',weight=1000,unique=true,useable=true,type='item'} or nil end,
 getPlayerData=function(_,src,path) return src==1 and copy(path and player[path[1]] or player) end,
 getItemBySlot=function(_,src,slot) return src==1 and copy(player.items[slot]) end,
 setPath=function(_,src,path,value) assert(src==1 and #path==1 and path[1]=='items');player.items=copy(value);writes=writes+1;return true end,
 createUseable=function(_,_,fn) usable=fn end,
}
exports=setmetatable({kora_core=core},{__call=function() end})
dofile(inv..'config.lua');dofile(inv..'shared.lua');Config.qbinventory.cash.asItem=false
dofile(inv..'server.lua');dofile(inv..'server/compat/qb.lua')
exports['qb-inventory']={SetItemData=function(_,...) return QbInventory.compat.qb.SetItemData(...) end}
Config.HarnessUses=20;Config.seatbelt={enabled=true,equipDuration=5000,actionLifetime=30000,crashCooldown=1000}
dofile(resource..'modules/seatbelt/server.lua')
usable(1,{slot=3});now=5000
assert(callback(1,{slot=3})==true,'actual authority must accept equipment')
assert(writes==1,'one mutation through core setPath')
assert(player.items[3].info.uses==4,'new info durability preserved')
assert(player.items[3].metadata.uses==4,'stale metadata rebuilt from new authoritative info')
assert(player.items[3].info.label=='keep','other metadata retained')
print('harness/inventory authority integration: 5 checks passed')
