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

local lastNotified = {}

local function notifyBlocked(entity)
    if not Config.blacklist.notifyOnVehicleBlock then return end
    if GetEntityType(entity) ~= 2 then return end

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
