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
