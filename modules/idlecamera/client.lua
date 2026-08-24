-- idlecamera -- suppress GTA's cinematic idle camera (the slow pan-away that
-- triggers after the player stops giving input for a while).
--
-- Mechanism: InvalidateIdleCam() resets the engine's idle timer; called on a
-- modest interval it never reaches the threshold that starts the camera.
-- InvalidateVehicleIdleCam() does the same for the in-vehicle variant. This is
-- deliberately an INTERVAL, not a per-frame call -- the idle threshold is tens
-- of seconds, so a 1s tick is many times more often than needed and costs
-- almost nothing, whereas doing it every frame (as several stock resources do)
-- is pure waste.

if not Config.idleCamera.disable then return end

Small.onInterval(Config.idleCamera.interval, function()
    InvalidateIdleCam()
    InvalidateVehicleIdleCam()
end)
