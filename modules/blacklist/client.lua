RegisterNetEvent('kora_utils:blacklist:vehicleBlocked', function()
    if not Config.blacklist.notifyOnVehicleBlock then return end
    Kora.notify.send({
        title = Kora.lang('vehicle_blacklist'),
        message = Kora.lang('vehicle_blocked'),
        type = 'error',
    })
end)

local blacklistedWeapons = Small.hashSet(Config.blacklist.weapons)

if not next(blacklistedWeapons) then return end

local function enforceWeaponBlacklist(weapon)
    if not blacklistedWeapons[weapon] then return end

    RemoveWeaponFromPed(Kora.cache.ped(), weapon)

    if Config.blacklist.notifyOnStrip then
        Kora.notify.send({
            title = Kora.lang('weapon_removed'),
            message = Kora.lang('weapon_blocked'),
            type = 'error',
        })
    end
end

local function watchWeapon()
    Kora.cache.onChange('weapon', enforceWeaponBlacklist)
    enforceWeaponBlacklist(Kora.cache.weapon())
end
watchWeapon()
AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'kora_lib' then
        watchWeapon()
    end
end)
