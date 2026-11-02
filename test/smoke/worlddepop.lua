-- worlddepop: the ped-drop sweep must be spread across frames, not one burst.
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
handle.step()
assert(flagged == 70 + 32, "next interval starts a fresh batched sweep")
print("PASS worlddepop: ped-drop sweep is batched across frames")
