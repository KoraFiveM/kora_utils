if not Config.weaponWheel.disable then return end

while true do
    SetPedConfigFlag(QB.cache.ped(), 48, true) -- Disable weapon wheel
    Wait(2000)
    
end