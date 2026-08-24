-- healthregen -- control GTA's passive health regeneration. By default the
-- engine slowly heals the player back toward full; zeroing the multiplier makes
-- damage stick until an item or a medic script heals it, which is what most RP
-- servers want.
--
-- NOTE: unlike the other modules here, this is NOT inherited from either
-- qb-smallresources or qbx_smallresources -- in both, health-regen tuning lives
-- in the ambulance/medical resource, not smallresources. It's included here
-- because it's an explicit requested feature and it's a natural fit for a
-- "passive player tweaks" bundle. If a medical resource on your server also
-- manages recharge, pick ONE owner to avoid the two fighting each other.
--
-- Mechanism: SetPlayerHealthRechargeMultiplier / SetPlayerHealthRechargeLimit
-- are player-scoped and reset when the ped is recreated on respawn, so they're
-- reapplied on every spawn via Small.onSpawn rather than set once at load
-- (set-once silently wears off the first time the player dies).

-- Nothing to do if the config leaves regen at stock (multiplier 1.0 with no
-- limit change) -- avoid registering a spawn handler that would only ever
-- reassert engine defaults.
if Config.healthRegen.multiplier == 1.0 and Config.healthRegen.limit == 0.0 then
    return
end

Small.onSpawn(function()
    local playerId = PlayerId()
    -- + 0.0 forces a float; the natives expect a float and an integer 0 can be
    -- marshalled as the wrong type by some FXServer builds.
    SetPlayerHealthRechargeMultiplier(playerId, Config.healthRegen.multiplier + 0.0)
    SetPlayerHealthRechargeLimit(playerId, Config.healthRegen.limit + 0.0)
end)
