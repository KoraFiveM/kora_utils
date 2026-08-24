-- wantedlevel -- stop the player ever accruing a vanilla GTA NPC-police wanted
-- level, and (optionally) switch off the NPC dispatch services so no cops,
-- helis or SWAT auto-spawn. RP servers run their own law systems; the star
-- system just fights them.
--
-- Mechanism, matching what qb-smallresources (ignore.lua) and qbx_smallresources
-- (disableservices) both do:
--   * SetMaxWantedLevel(0) -- the engine will not let the level rise above 0.
--     Sticky and global, but reasserted on the interval and on spawn because
--     some session transitions reset it.
--   * EnableDispatchService(1..15, false) -- silences each NPC dispatch service.
--     These DO get re-enabled by the engine over time, so they live on the
--     interval, not a one-shot.
--   * Belt-and-braces: if a level ever does slip through (a script granted it),
--     clear it immediately. Neither original does this, but it's cheap and
--     closes the gap where another resource calls SetPlayerWantedLevel.

if not Config.wantedLevel.disable then return end

-- SetPoliceIgnorePlayer is ped-scoped and reset on respawn, so it belongs on the
-- spawn hook. SetMaxWantedLevel is global but reasserted here too so a fresh
-- spawn is immediately covered without waiting for the first interval tick.
Small.onSpawn(function()
    SetMaxWantedLevel(0)
    SetPoliceIgnorePlayer(PlayerId(), true)
end)

Small.onInterval(Config.wantedLevel.interval, function()
    SetMaxWantedLevel(0)

    local playerId = PlayerId()
    if GetPlayerWantedLevel(playerId) > 0 then
        SetPlayerWantedLevel(playerId, 0, false)
        SetPlayerWantedLevelNow(playerId, false)
    end

    if Config.wantedLevel.disableDispatch then
        for service = 1, 15 do
            EnableDispatchService(service, false)
        end
    end
end)
