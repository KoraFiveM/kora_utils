-- blacklist (server) -- authoritative block on spawning blacklisted vehicle and
-- ped models. Only the server can reliably refuse a networked entity.
--
-- OneSync raises `entityCreating` BEFORE the entity is networked, and
-- CancelEvent() there stops the spawn entirely. Requires OneSync.

-- Build the lookup once at load so the hot handler is a single table read.
local function toHash(value)
    if type(value) == "number" then return value end
    return joaat(value)
end

local blacklisted = {}
local blacklistedWeapons = {}

local function addAll(list)
    if not list then return end
    for i = 1, #list do
        blacklisted[toHash(list[i])] = true
    end
end

addAll(Config.blacklist.vehicles)
addAll(Config.blacklist.peds)

for _, weapon in ipairs(Config.blacklist.weapons or {}) do
    blacklistedWeapons[toHash(weapon)] = true
end

-- Nothing blacklisted -> don't even register the handler.
local lastNotified = {}

-- Tell the spawning player their vehicle was refused. At entityCreating the
-- entity's owner is the client that requested it. Throttled per player so a
-- spawn loop can't spam events.
local function notifyBlocked(entity)
    if not Config.blacklist.notifyOnVehicleBlock then return end
    if GetEntityType(entity) ~= 2 then return end

    -- Ambient traffic/parked/scenario/blimp spawns (population types 1-5) are
    -- created by the game on a nearby client, not requested by the player.
    -- Still refused, but the owner didn't ask for it so don't tell them.
    local popType = GetEntityPopulationType(entity)
    if popType >= 1 and popType <= 5 then return end

    local owner = NetworkGetEntityOwner(entity)
    if not owner or owner <= 0 then return end

    local now = GetGameTimer()
    if lastNotified[owner] and now - lastNotified[owner] < 1000 then return end
    lastNotified[owner] = now

    TriggerClientEvent("kora_utils:blacklist:vehicleBlocked", owner)
end

AddEventHandler("playerDropped", function()
    lastNotified[source] = nil
end)

if next(blacklisted) then
    AddEventHandler("entityCreating", function(entity)
        if blacklisted[GetEntityModel(entity)] then
            CancelEvent()
            notifyBlocked(entity)
        end
    end)
end

-- Client stripping is immediate feedback, not authority. Re-check the weapon
-- held by every connected player's server-owned ped so a modified client
-- cannot retain and fire a prohibited weapon by disabling its local sweep.
if next(blacklistedWeapons) then
    CreateThread(function()
        while true do
            for _, rawSource in ipairs(GetPlayers()) do
                local ped = GetPlayerPed(tonumber(rawSource))
                if ped ~= 0 then
                    local weapon = GetSelectedPedWeapon(ped)
                    if blacklistedWeapons[weapon] then RemoveWeaponFromPed(ped, weapon) end
                end
            end
            Wait(Config.blacklist.serverWeaponSweepInterval or 250)
        end
    end)
end
