-- idlecamera -- suppress GTA's cinematic idle camera.
--
-- InvalidateIdleCam() resets the engine's idle timer. Deliberately an interval,
-- not per-frame: the idle threshold is tens of seconds.

if not Config.idleCamera.disable then return end

Small.onInterval(Config.idleCamera.interval, function()
    InvalidateIdleCam()
    InvalidateVehicleIdleCam()
end)
