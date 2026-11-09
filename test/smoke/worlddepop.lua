local scriptDir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"
package.path = scriptDir .. "../?.lua;" .. package.path
local mocks = require("mocks")
local handle = mocks.install()
dofile(scriptDir .. "../../client/core.lua")

local pool, flagged = {}, 0
for i = 1, 70 do pool[i] = i end
function GetGamePool(name) assert(name == "CPed"); return pool end
function SetPedDropsWeaponsWhenDead(_, drops) assert(drops == false); flagged = flagged + 1 end

Config = { worldDepop = { disableRandomCops = false, calmNpcs = true, disableDriveby = false,
    disablePedDrops = true, reassertInterval = 10000 } }
dofile(scriptDir .. "../../modules/worlddepop/client.lua")

assert(flagged == 32, "first frame flags one batch, got " .. flagged)
handle.step()
assert(flagged == 64, "second frame flags the next batch, got " .. flagged)
handle.step()
assert(flagged == 70, "remainder finishes the sweep, got " .. flagged)
for _ = 1, 10 do handle.step() end
assert(flagged == 70, "an unchanged pool costs no further native writes, got " .. flagged)

for i = 71, 110 do pool[i] = i end
local before = flagged
for _ = 1, 10 do handle.step() end
assert(flagged == 110, "only the new peds are flagged, got " .. flagged)
assert(flagged > before, "new peds picked up on the next sweep")

pool[110] = nil
for _ = 1, 10 do handle.step() end
pool[110] = 110
for _ = 1, 10 do handle.step() end
assert(flagged == 111, "a handle that left the pool and returned is re-flagged, got " .. flagged)
print("PASS worlddepop: ped-drop sweep is batched across frames")
