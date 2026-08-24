-- weaponwheel -- remove the radial weapon-select wheel. Weapons remain
-- switchable by script/inventory; only the built-in HUD wheel is suppressed.
--
-- Mechanism: BlockWeaponWheelThisFrame() is the engine's own "don't show the
-- wheel this frame" call and is the cleanest block there is; it must be
-- reasserted every frame, which is exactly what onFrame is for. Disabling
-- control 37 (INPUT_SELECT_WEAPON) is a second line that stops the key that
-- opens the wheel from registering at all. Both are genuine per-frame natives
-- -- there is no set-once form -- so this is one of the few features that
-- legitimately belongs on the frame tick.

if not Config.weaponWheel.disable then return end

Small.onFrame(function()
    BlockWeaponWheelThisFrame()
    DisableControlAction(0, 37, true)  -- INPUT_SELECT_WEAPON (opens the wheel)
end)

-- Stop the engine auto-equipping a freshly picked-up weapon. This is a sticky
-- global flag, not ped-scoped, but the engine clears it across some session
-- transitions, so reassert on each spawn rather than only once at load.
if Config.weaponWheel.blockAutoSwap then
    Small.onSpawn(function()
        SetWeaponsNoAutoswap(true)
    end)
end
