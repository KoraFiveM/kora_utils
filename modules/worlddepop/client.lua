-- worlddepop -- thin out GTA's ambient chaos: no random cops, sirens or garbage
-- trucks, no weapon drops, optionally calmed ambient peds.
--
-- One-shot ambient natives run on spawn and, since the engine resets some, again
-- on a slow interval. Weapon drops use a GetGamePool('CPed') sweep because
-- populationPedCreating fires before the ped exists and has no drops-weapon setter.

local cfg = Config.worldDepop

-- Ambient gangs/services that vanilla GTA makes hostile to the player. 1 =
-- "Respect" (friendly) in SetRelationshipBetweenGroups. Mirrors calmai.lua.
local calmGroups = {
    "AMBIENT_GANG_LOST", "AMBIENT_GANG_MEXICAN", "AMBIENT_GANG_FAMILY",
    "AMBIENT_GANG_BALLAS", "AMBIENT_GANG_MARABUNTE", "AMBIENT_GANG_CULT",
    "AMBIENT_GANG_SALVA", "AMBIENT_GANG_WEICHENG", "AMBIENT_GANG_HILLBILLY",
    "GANG_1", "GANG_2", "GANG_9", "GANG_10",
    "FIREMAN", "MEDIC", "COP", "PRISONER",
}
local PLAYER_GROUP = joaat("PLAYER")
-- Hash once at load; applyAmbient reruns every reassertInterval.
for i = 1, #calmGroups do calmGroups[i] = joaat(calmGroups[i]) end

local function applyAmbient()
    if cfg.disableRandomCops then
        SetCreateRandomCops(false)
        SetCreateRandomCopsNotOnScenarios(false)
        SetCreateRandomCopsOnScenarios(false)
        DistantCopCarSirens(false)
        SetGarbageTrucks(false)
        SetAudioFlag("PoliceScannerDisabled", true)
    end

    if cfg.calmNpcs then
        for i = 1, #calmGroups do
            SetRelationshipBetweenGroups(1, calmGroups[i], PLAYER_GROUP)
        end
    end

    if cfg.disableDriveby then
        SetPlayerCanDoDriveBy(Kora.cache.playerId(), false)
    end
end

Small.onSpawn(applyAmbient)

-- Reassert the subset the engine resets; nothing registered when all are off.
if cfg.disableRandomCops or cfg.calmNpcs or cfg.disableDriveby then
    Small.onInterval(cfg.reassertInterval, applyAmbient)
end

-- Peds don't drop weapons when killed, closing off a route to picking up
-- blacklisted guns. SetPedDropsWeaponsWhenDead is idempotent, so re-flagging is free.
-- The sweep is spread over frames (SWEEP_BATCH peds per frame) instead of
-- flagging the whole pool in one burst on the reassert tick. Its own sleeping
-- thread rather than the shared interval bucket, because a yielding task would
-- stall the bucket's other tasks.
local SWEEP_BATCH = 32

if cfg.disablePedDrops then
    local interval = cfg.reassertInterval
    assert(type(interval) == "number" and interval > 0, "worldDepop.reassertInterval must be a positive number")
    Small.once(function()
        while true do
            local peds = GetGamePool("CPed")
            for i = 1, #peds do
                local ped = peds[i]
                if DoesEntityExist(ped) then
                    SetPedDropsWeaponsWhenDead(ped, false)
                end
                if i % SWEEP_BATCH == 0 then Wait(0) end
            end
            Wait(interval)
        end
    end)
end
