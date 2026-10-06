if not Config.weaponWheel.disable then return end

if Config.weaponWheel.blockAutoSwap then
    Small.onSpawn(function()
        SetWeaponsNoAutoswap(true)
    end)
end

local function disableWeaponWheel()
    SetPedConfigFlag(QB.cache.ped(), 48, true) -- Disable weapon wheel
end

disableWeaponWheel()
Small.onInterval(2000, disableWeaponWheel)
