if Config.healthRegen.multiplier == 1.0 and Config.healthRegen.limit == 0.0 then
    return
end

Small.onSpawn(function()
    local playerId = Kora.cache.playerId()
    SetPlayerHealthRechargeMultiplier(playerId, Config.healthRegen.multiplier + 0.0)
    SetPlayerHealthRechargeLimit(playerId, Config.healthRegen.limit + 0.0)
end)
