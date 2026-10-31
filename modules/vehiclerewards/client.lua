-- GTA grants weapons for entering certain service vehicles (notably police
-- cars). kora_inventory owns weapons on this server, so suppress the native grant.

local cfg = Config.vehicleRewards

if not cfg.disable then return end

Small.onSpawn(function()
    DisablePlayerVehicleRewards(Kora.cache.playerId())
end)
