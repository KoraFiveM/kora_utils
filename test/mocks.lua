-- Minimal FiveM native stand-ins for smoke-testing qbsmallresources under plain
-- Lua. Only the natives the tested modules actually touch are mocked; anything
-- unused is deliberately absent so an accidental new dependency surfaces as a
-- nil-call failure rather than passing silently.
local M = {}

---Installs mocked globals into _G and returns a handle for driving/inspecting
---the simulated runtime. Mirrors qblib/test/mocks.lua's shape (step/fire) so the
---one-shot-thread convention is the same across both test suites.
function M.install()
    local threads = {}
    local eventHandlers = {}

    -- --- Scheduling ---------------------------------------------------------
    -- CreateThread resumes the body once (like FiveM): a one-shot thread runs to
    -- completion, a `while true ... Wait() end` thread runs one iteration then
    -- sits suspended. step() resumes every still-suspended thread once more, so
    -- tick loops are testable without hanging.
    function _G.CreateThread(fn)
        local co = coroutine.create(fn)
        threads[#threads + 1] = co
        local ok, err = coroutine.resume(co)
        if not ok then error(("CreateThread body errored: %s"):format(tostring(err)), 0) end
    end

    function _G.Wait(_) coroutine.yield() end

    function _G.AddEventHandler(name, cb)
        eventHandlers[name] = eventHandlers[name] or {}
        table.insert(eventHandlers[name], cb)
    end

    -- Same registry as AddEventHandler: the only difference in the real runtime
    -- is that this one marks the name safe to receive over the network, and the
    -- harness has no network. Modules must still use it for server-fired events
    -- (e.g. QBCore:Client:OnPlayerLoaded) or CFX silently skips the handler.
    _G.RegisterNetEvent = _G.AddEventHandler

    function _G.TriggerEvent(name, ...)
        for _, fn in ipairs(eventHandlers[name] or {}) do fn(...) end
    end

    -- --- Hashing ------------------------------------------------------------
    -- Deterministic 32-bit FNV-1a so name->hash is stable within a test run.
    -- Real joaat differs, but the modules only ever compare hash-to-hash, so any
    -- consistent function is a faithful stand-in.
    function _G.joaat(str)
        local hash = 2166136261
        for i = 1, #str do
            hash = (hash ~ str:byte(i)) & 0xFFFFFFFF
            hash = (hash * 16777619) & 0xFFFFFFFF
        end
        return hash
    end
    _G.GetHashKey = _G.joaat

    -- --- Misc natives used by modules under test ---------------------------
    _G.__cancelled = false
    function _G.CancelEvent() _G.__cancelled = true end

    _G.__entityModel = 0
    function _G.GetEntityModel(_) return _G.__entityModel end
    function _G.DoesEntityExist(e) return e ~= nil and e ~= 0 end
    function _G.GetGamePool(_) return {} end
    function _G.SetPedDropsWeaponsWhenDead(_, _) end

    -- Player / weapon natives (blacklist client, wantedlevel, healthregen).
    _G.__ped = 10
    _G.__selectedWeapon = 0
    _G.__removedWeapons = {}
    function _G.PlayerPedId() return _G.__ped end
    function _G.PlayerId() return 0 end
    function _G.GetSelectedPedWeapon(_) return _G.__selectedWeapon end
    function _G.RemoveWeaponFromPed(_, hash) _G.__removedWeapons[hash] = true end
    function _G.GetPlayers() return {} end
    function _G.GetPlayerPed(_) return 0 end

    -- Everything below is a no-op the scheduling/feature natives call; recorded
    -- only where a test asserts on it.
    for _, name in ipairs({
        "SetMaxWantedLevel", "SetPoliceIgnorePlayer", "GetPlayerWantedLevel",
        "SetPlayerWantedLevel", "SetPlayerWantedLevelNow", "EnableDispatchService",
        "InvalidateIdleCam", "InvalidateVehicleIdleCam", "BlockWeaponWheelThisFrame",
        "DisableControlAction", "SetWeaponsNoAutoswap",
        "SetPlayerHealthRechargeMultiplier", "SetPlayerHealthRechargeLimit",
        "SetCreateRandomCops", "SetCreateRandomCopsNotOnScenarios",
        "SetCreateRandomCopsOnScenarios", "DistantCopCarSirens", "SetGarbageTrucks",
        "SetAudioFlag", "SetRelationshipBetweenGroups", "SetPlayerCanDoDriveBy",
    }) do
        if _G[name] == nil then _G[name] = function() end end
    end
    -- GetPlayerWantedLevel needs a real return; default 0 (no level).
    _G.GetPlayerWantedLevel = function() return _G.__wantedLevel or 0 end

    -- Minimal QB.notify used by blacklist client.
    _G.QB = _G.QB or {}
    _G.QB.cache = _G.QB.cache or {}
    function _G.QB.cache.ped() return _G.__ped end
    function _G.QB.cache.playerId() return 0 end
    function _G.QB.cache.weapon() return _G.__selectedWeapon end
    _G.QB.notify = _G.QB.notify or {}
    _G.__notifications = {}
    function _G.QB.notify.send(payload) table.insert(_G.__notifications, payload) end

    return {
        ---Resume every suspended tick thread once (one more loop iteration each).
        step = function()
            for _, co in ipairs(threads) do
                if coroutine.status(co) == "suspended" then
                    local ok, err = coroutine.resume(co)
                    if not ok then error(("thread errored on step: %s"):format(tostring(err)), 0) end
                end
            end
        end,
        ---Dispatch a lifecycle/game event into any AddEventHandler listeners.
        fire = function(name, ...) _G.TriggerEvent(name, ...) end,
    }
end

return M
