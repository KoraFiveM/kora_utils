-- worlddepop -- thin out GTA's ambient chaos so the city feels like an RP
-- server rather than singleplayer: no random NPC police, no distant cop
-- sirens, no garbage trucks, dead NPCs don't litter the ground with weapons,
-- and (optionally) ambient peds stop treating players as enemies on sight.
--
-- Two kinds of native here, handled differently:
--   * One-shot ambient kills (SetCreateRandomCops, SetGarbageTrucks, the
--     relationship calming) -- applied once on spawn. A few of these are reset
--     by the engine over time, so they're ALSO reasserted on a slow interval.
--   * "Peds don't drop weapons" -- a slow sweep of the ped pool setting the
--     flag. The originals hook populationPedCreating, but that event fires
--     BEFORE the ped exists and exposes only model/position/heading setters
--     (no drops-weapon setter), so they end up GetClosestPed-guessing anyway.
--     A periodic GetGamePool('CPed') sweep is simpler and actually reliable;
--     SetPedDropsWeaponsWhenDead is idempotent, so re-flagging a ped is a
--     no-op, and the sweep runs off the frame thread on the slow interval.

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
        SetPlayerCanDoDriveBy(PlayerId(), false)
    end
end

Small.onSpawn(applyAmbient)

-- Reassert the subset the engine resets. Guarded so a fully-default config
-- (everything off) registers no interval at all.
if cfg.disableRandomCops or cfg.calmNpcs or cfg.disableDriveby then
    Small.onInterval(cfg.reassertInterval, applyAmbient)
end

-- Peds don't drop their weapon when killed -- closes off a common route to
-- players picking up blacklisted guns off the street. Swept on the same slow
-- reassert interval: SetPedDropsWeaponsWhenDead is idempotent, so re-flagging an
-- already-flagged ped costs nothing and newly-streamed peds get caught within
-- one interval.
if cfg.disablePedDrops then
    Small.onInterval(cfg.reassertInterval, function()
        for _, ped in ipairs(GetGamePool("CPed")) do
            if DoesEntityExist(ped) then
                SetPedDropsWeaponsWhenDead(ped, false)
            end
        end
    end)
end
