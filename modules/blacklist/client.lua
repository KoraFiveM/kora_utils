-- blacklist (client) -- strip weapons the player is never allowed to hold. If a
-- blacklisted weapon becomes equipped anyway (a menu, a cheat, a buggy give),
-- it's removed and -- if configured -- the player is notified.
--
-- qblib already owns the selected-weapon poll. Subscribe to its change edge
-- instead of scheduling another 500ms sweep in this resource.
--
-- Vehicle/ped model blacklisting is enforced SERVER-side (server.lua) via
-- entityCreating -- a client-only spawn check is trivially bypassed, so it
-- would be security theatre here.

local blacklistedWeapons = Small.hashSet(Config.blacklist.weapons)

-- next() on an empty set is nil -- if nothing is blacklisted, register no listener.
if not next(blacklistedWeapons) then return end

local function enforceWeaponBlacklist(weapon)
    if not blacklistedWeapons[weapon] then return end

    local ped = QB.cache.ped()
    RemoveWeaponFromPed(ped, weapon)

    if Config.blacklist.notifyOnStrip then
        QB.notify.send({
            title = "Weapon removed",
            message = "That weapon isn't allowed on this server.",
            type = "error",
        })
    end
end

QB.cache.onChange('weapon', enforceWeaponBlacklist)
enforceWeaponBlacklist(QB.cache.weapon())
