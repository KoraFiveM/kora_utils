-- blacklist (client) -- strip weapons the player is never allowed to hold. If a
-- blacklisted weapon becomes equipped anyway (a menu, a cheat, a buggy give),
-- it's removed and -- if configured -- the player is notified.
--
-- Mechanism matches qb-smallresources' ignore.lua: on an interval, read the
-- currently-selected weapon with GetSelectedPedWeapon (returns the hash
-- directly, cleaner than GetCurrentPedWeapon's out-param) and, if it's in the
-- blacklist set, RemoveWeaponFromPed. An interval rather than per-frame: a
-- weapon can't be fired between two half-second ticks fast enough to matter,
-- and the sweep is far cheaper off the frame thread.
--
-- Vehicle/ped model blacklisting is enforced SERVER-side (server.lua) via
-- entityCreating -- a client-only spawn check is trivially bypassed, so it
-- would be security theatre here.

local blacklistedWeapons = Small.hashSet(Config.blacklist.weapons)

-- next() on an empty set is nil -- if nothing is blacklisted, register no tick.
if not next(blacklistedWeapons) then return end

Small.onInterval(Config.blacklist.weaponSweepInterval, function()
    local ped = QB.cache.ped()
    local weapon = QB.cache.weapon()

    if blacklistedWeapons[weapon] then
        RemoveWeaponFromPed(ped, weapon)

        if Config.blacklist.notifyOnStrip then
            QB.notify.send({
                title = "Weapon removed",
                message = "That weapon isn't allowed on this server.",
                type = "error",
            })
        end
    end
end)
