local cfg = Config.vehicleRewards

if not cfg.disable then return end

Small.onSpawn(function()
    DisablePlayerVehicleRewards(Kora.cache.playerId())
end)
