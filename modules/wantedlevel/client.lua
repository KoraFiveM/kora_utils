if not Config.wantedLevel.disable then return end

while true do
    SetPedConfigFlag(QB.cache.ped(), 42, true) -- Disable wanted level increase
    Wait(10000)
end