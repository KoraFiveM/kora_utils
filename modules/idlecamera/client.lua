if not Config.idleCamera.disable then return end

Small.onInterval(Config.idleCamera.interval, function()
    InvalidateIdleCam()
    InvalidateVehicleIdleCam()
end)
