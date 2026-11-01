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
            SetRelationshipBetweenGroups(1, joaat(calmGroups[i]), PLAYER_GROUP)
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
if cfg.disablePedDrops then
    Small.onInterval(cfg.reassertInterval, function()
        for _, ped in ipairs(GetGamePool("CPed")) do
            if DoesEntityExist(ped) then
                SetPedDropsWeaponsWhenDead(ped, false)
            end
        end
    end)
end
