if not Config.wantedLevel.disable then return end

local function capWantedLevel()
    SetMaxWantedLevel(0)

    local id = PlayerId()
    if GetPlayerWantedLevel(id) > 0 then
        SetPlayerWantedLevel(id, 0, false)
        SetPlayerWantedLevelNow(id, false)
        ClearPlayerWantedLevel(id)
    end
end

local function disableWantedLevel()
    SetPedConfigFlag(Kora.cache.ped(), 42, true) -- Disable wanted level increase
    capWantedLevel()

    if Config.wantedLevel.disableDispatch then
        for service = 1, 15 do
            EnableDispatchService(service, false)
        end
    end
end

disableWantedLevel()
Small.onSpawn(capWantedLevel) -- SetMaxWantedLevel is player-scoped and resets with the ped
Small.onInterval(Config.wantedLevel.interval or 2000, disableWantedLevel)

if Config.wantedLevel.hideHudStar ~= false then
    CreateThread(function()
        while true do
            HideHudComponentThisFrame(1) -- Wanted stars
            Wait(0)
        end
    end)
end
