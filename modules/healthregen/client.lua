-- healthregen -- zero GTA's passive health regeneration so damage sticks until
-- an item or medic heals it.
--
-- NOTE: not inherited from qb-/qbx_smallresources (there it lives in the medical
-- resource). If a medical resource also manages recharge, pick ONE owner.
--
-- The natives are player-scoped and reset on respawn, hence Small.onSpawn.

-- Stock regen (multiplier 1.0, no limit change): register nothing.
if Config.healthRegen.multiplier == 1.0 and Config.healthRegen.limit == 0.0 then
    return
end

Small.onSpawn(function()
    local playerId = Kora.cache.playerId()
    -- + 0.0 forces a float; the natives expect a float and an integer 0 can be
    -- marshalled as the wrong type by some FXServer builds.
    SetPlayerHealthRechargeMultiplier(playerId, Config.healthRegen.multiplier + 0.0)
    SetPlayerHealthRechargeLimit(playerId, Config.healthRegen.limit + 0.0)
end)
