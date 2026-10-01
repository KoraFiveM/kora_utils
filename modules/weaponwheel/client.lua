if not Config.weaponWheel.disable then return end

if Config.weaponWheel.blockAutoSwap then
    Small.onSpawn(function()
        SetWeaponsNoAutoswap(true)
    end)
end

while true do
    SetPedConfigFlag(QB.cache.ped(), 48, true) -- Disable weapon wheel
    Wait(2000)
    
end