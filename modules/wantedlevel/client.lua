if not Config.wantedLevel.disable then return end

-- The star hide is a ...ThisFrame native. It shares the coordinator frame
-- thread and only runs while a wanted level has leaked through the cap, so a
-- player without stars pays no per-frame cost (F#200).
local setStarHidden
if Config.wantedLevel.hideHudStar ~= false then
    setStarHidden = Small.onFrame(function()
        HideHudComponentThisFrame(1) -- Wanted stars
    end)
    setStarHidden(false)
end

local function capWantedLevel()
    SetMaxWantedLevel(0)

    local id = PlayerId()
    local leaked = GetPlayerWantedLevel(id) > 0
    if leaked then
        SetPlayerWantedLevel(id, 0, false)
        SetPlayerWantedLevelNow(id, false)
        ClearPlayerWantedLevel(id)
    end
    -- Hide until the next tick confirms the level stayed at 0.
    if setStarHidden then setStarHidden(leaked) end
end

-- Ped flags reset only when the ped is recreated and dispatch is global, so
-- both are applied on spawn rather than on every tick (F#203).
local function applyOnSpawn()
    SetPedConfigFlag(Kora.cache.ped(), 42, true) -- Disable wanted level increase
    capWantedLevel() -- SetMaxWantedLevel is player-scoped and resets with the ped

    if Config.wantedLevel.disableDispatch then
        for service = 1, 15 do
            EnableDispatchService(service, false)
        end
    end
end

applyOnSpawn()
Small.onSpawn(applyOnSpawn)
Small.onInterval(Config.wantedLevel.interval or 2000, capWantedLevel)
