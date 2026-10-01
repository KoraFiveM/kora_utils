if not Config.wantedLevel.disable then return end

while true do
    SetPedConfigFlag(QB.cache.ped(), 42, true) -- Disable wanted level increase
    if Config.wantedLevel.disableDispatch then
        for service = 1, 15 do
            EnableDispatchService(service, false)
        end
    end
    Wait(2000)
end