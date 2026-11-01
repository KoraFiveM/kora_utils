local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)')
local root = scriptDir .. '../../'
local frame, events, provided, hidden, density, ammo, owner, anim = nil, {}, {}, {}, {}, {}, 'hudres', false
local scheduledFrames = 0
function GetCurrentResourceName() return 'kora_utils' end
function GetInvokingResource() return owner end
function AddEventHandler(name, fn) events[name]=fn end
function exports(name, fn) provided[name]=fn end
function PlayerPedId() return 1 end
function IsEntityPlayingAnim(_, dict, name) return anim and dict == 'missminuteman_1ig_2' and name == 'handsup_base' end
function HideHudComponentThisFrame(id) hidden[#hidden+1]=id end
function DisplayAmmoThisFrame(v) ammo[#ammo+1]=v end
function SetParkedVehicleDensityMultiplierThisFrame(v) density.parked=v end
function SetVehicleDensityMultiplierThisFrame(v) density.vehicle=v end
function SetRandomVehicleDensityMultiplierThisFrame(v) density.multiplier=v end
function SetPedDensityMultiplierThisFrame(v) density.peds=v end
function SetScenarioPedDensityMultiplierThisFrame(a, b) density.scenario={a,b} end
Small = { onFrame=function(fn) scheduledFrames=scheduledFrames+1; frame=fn end }
Kora = {compat=dofile(root .. '../kora_lib/compat/provider.lua')()}
dofile(root .. 'client/hud.lua')
local function legacy(name)
 local fn; events['__cfx_export_qb-smallresources_'..name](function(value) fn=value end); return fn
end
for _, name in ipairs({'DecorSet','addDisableHudComponents','removeDisableHudComponents','getDisableHudComponents','setDisplayAmmo','getDisplayAmmo','getHandsup'}) do
 assert(legacy(name)==provided[name], name..' provided under qb-smallresources')
end
assert(scheduledFrames==0 and frame==nil, 'nothing scheduled until used')
assert(provided.getDisplayAmmo()==true and #provided.getDisableHudComponents()==0)
provided.addDisableHudComponents('bad'); provided.addDisableHudComponents({1,'x'}); assert(frame==nil, 'invalid input ignored')
provided.addDisableHudComponents({1,2}); provided.addDisableHudComponents(7)
assert(scheduledFrames==1 and #provided.getDisableHudComponents()==3)
frame(); assert(#hidden==3 and hidden[3]==7 and #ammo==0 and next(density)==nil)
provided.removeDisableHudComponents({1,7}); hidden={}; frame(); assert(#hidden==1 and hidden[1]==2)
provided.setDisplayAmmo('yes'); assert(provided.getDisplayAmmo()==true)
provided.setDisplayAmmo(false); assert(provided.getDisplayAmmo()==false); frame(); assert(ammo[1]==false)
provided.DecorSet('peds', 0.2); provided.DecorSet('scenario', 0.1); provided.DecorSet('bogus', 0.5); provided.DecorSet('vehicle', 5)
frame(); assert(density.peds==0.2 and density.scenario[2]==0.1 and density.vehicle==nil)
assert(scheduledFrames==1, 'single shared frame task')
owner='other'; provided.addDisableHudComponents(9); events.onClientResourceStop('other')
hidden={}; frame(); assert(#hidden==1 and hidden[1]==2, 'stopped owner components removed')
assert(provided.getHandsup()==false); anim=true; assert(provided.getHandsup()==true)
print('qbsmallresources legacy hud: all checks passed')
