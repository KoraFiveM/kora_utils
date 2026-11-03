if not Config.weaponWheel.disable then return end

if Config.weaponWheel.blockAutoSwap then
    Small.onSpawn(function()
        SetWeaponsNoAutoswap(true)
    end)
end

-- Ped config flags reset only when the ped is recreated, and onSpawn fires on
-- every ped handle change, so no interval is needed (F#203).
local function disableWeaponWheel()
    SetPedConfigFlag(Kora.cache.ped(), 48, true) -- Disable weapon wheel
end

disableWeaponWheel()
Small.onSpawn(disableWeaponWheel)
