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
if next(blacklisted) then
    AddEventHandler("entityCreating", function(entity)
        if blacklisted[GetEntityModel(entity)] then
            CancelEvent()
        end
    end)
end

-- Client stripping is immediate feedback, not authority. Damage from a
-- blacklisted weapon is cancelled here, so a modified client that skips its
-- strip still can't hurt anyone with it (F#201).
if next(blacklistedWeapons) then
    AddEventHandler("weaponDamageEvent", function(_, data)
        if type(data) == "table" and blacklistedWeapons[data.weaponType] then
            CancelEvent()
        end
    end)
end

-- Slow backstop sweep removing the weapon from every player's server ped.
-- 0 turns it off and relies on the damage cancel above.
local sweepInterval = Config.blacklist.serverWeaponSweepInterval or 2000
if next(blacklistedWeapons) and sweepInterval > 0 then
    CreateThread(function()
        while true do
            for _, rawSource in ipairs(GetPlayers()) do
                local ped = GetPlayerPed(tonumber(rawSource))
                if ped ~= 0 then
                    local weapon = GetSelectedPedWeapon(ped)
                    if blacklistedWeapons[weapon] then RemoveWeaponFromPed(ped, weapon) end
                end
            end
            Wait(sweepInterval)
        end
    end)
end
