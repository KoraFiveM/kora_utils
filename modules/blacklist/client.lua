-- blacklist (client) -- strip weapons the player is never allowed to hold. If a
-- blacklisted weapon becomes equipped anyway (a menu, a cheat, a buggy give),
-- it's removed and -- if configured -- the player is notified.
--
-- kora_lib already owns the selected-weapon poll. Subscribe to its change edge
-- instead of scheduling another 500ms sweep in this resource.
--
-- Vehicle/ped model blacklisting is enforced SERVER-side (server.lua) via
-- entityCreating -- a client-only spawn check is trivially bypassed, so it
-- would be security theatre here.

-- Server refused a blacklisted vehicle spawn (see server.lua) -- tell the player.
-- Registered before the weapon early-return so it works with no weapons listed.
RegisterNetEvent("kora_utils:blacklist:vehicleBlocked", function()
    if not Config.blacklist.notifyOnVehicleBlock then return end
    Kora.notify.send({
        title = "Vehicle Blacklist",
        message = "That vehicle is not allowed on this server.",
        type = "error",
    })
end)

local blacklistedWeapons = Small.hashSet(Config.blacklist.weapons)

-- next() on an empty set is nil -- if nothing is blacklisted, register no listener.
if not next(blacklistedWeapons) then return end

local function enforceWeaponBlacklist(weapon)
    if not blacklistedWeapons[weapon] then return end

    RemoveWeaponFromPed(Kora.cache.ped(), weapon)

    if Config.blacklist.notifyOnStrip then
        Kora.notify.send({
            title = "Weapon removed",
            message = "That weapon isn't allowed on this server.",
            type = "error",
        })
    end
end

-- onChange registrations die with kora_lib, so re-register and re-check the
-- current weapon whenever it restarts.
local function watchWeapon()
    Kora.cache.onChange('weapon', enforceWeaponBlacklist)
    enforceWeaponBlacklist(Kora.cache.weapon())
end
watchWeapon()
AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'kora_lib' then watchWeapon() end
end)
