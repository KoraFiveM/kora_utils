if not Config.wantedLevel.disable then return end

local function disableWantedLevel()
    SetPedConfigFlag(Kora.cache.ped(), 42, true) -- Disable wanted level increase
    if Config.wantedLevel.disableDispatch then
        for service = 1, 15 do
            EnableDispatchService(service, false)
        end
    end
end

disableWantedLevel()
Small.onInterval(2000, disableWantedLevel)
