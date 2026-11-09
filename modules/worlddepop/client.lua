local cfg = Config.worldDepop

local calmGroups = {
    "AMBIENT_GANG_LOST", "AMBIENT_GANG_MEXICAN", "AMBIENT_GANG_FAMILY",
    "AMBIENT_GANG_BALLAS", "AMBIENT_GANG_MARABUNTE", "AMBIENT_GANG_CULT",
    "AMBIENT_GANG_SALVA", "AMBIENT_GANG_WEICHENG", "AMBIENT_GANG_HILLBILLY",
    "GANG_1", "GANG_2", "GANG_9", "GANG_10",
    "FIREMAN", "MEDIC", "COP", "PRISONER",
}
local PLAYER_GROUP = joaat("PLAYER")
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

if cfg.disableRandomCops or cfg.calmNpcs or cfg.disableDriveby then
    Small.onInterval(cfg.reassertInterval, applyAmbient)
end

local SWEEP_BATCH = 32

if cfg.disablePedDrops then
    local interval = cfg.reassertInterval
    assert(type(interval) == "number" and interval > 0, "worldDepop.reassertInterval must be a positive number")
    local flagged = {}
    Small.once(function()
        while true do
            local peds = GetGamePool("CPed")
            local seen = {}
            for i = 1, #peds do
                local ped = peds[i]
                if flagged[ped] then
                    seen[ped] = true
                elseif DoesEntityExist(ped) then
                    SetPedDropsWeaponsWhenDead(ped, false)
                    seen[ped] = true
                end
                if i % SWEEP_BATCH == 0 then Wait(0) end
            end
            flagged = seen
            Wait(interval)
        end
    end)
end
