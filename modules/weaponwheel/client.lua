if not Config.weaponWheel.disable then return end

if Config.weaponWheel.blockAutoSwap then
    Small.onSpawn(function()
        SetWeaponsNoAutoswap(true)
    end)
end

local function disableWeaponWheel()
    SetPedConfigFlag(Kora.cache.ped(), 48, true)
end

disableWeaponWheel()
Small.onSpawn(disableWeaponWheel)
Small.onInterval(10000, disableWeaponWheel)
