-- Minimal FiveM native stand-ins for smoke-testing kora_utils under plain
-- Lua. Only the natives the tested modules actually touch are mocked; anything
-- unused is deliberately absent so an accidental new dependency surfaces as a
-- nil-call failure rather than passing silently.
local M = {}

---Installs mocked globals into _G and returns a handle for driving/inspecting
---the simulated runtime. Mirrors kora_lib/test/mocks.lua's shape (step/fire) so the
---one-shot-thread convention is the same across both test suites.
function M.install()
    local threads = {}
    local eventHandlers = {}
    local cacheChangeHandlers = {}

    -- Scheduling
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

    -- Hashing
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

    -- Misc natives used by modules under test
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
    _G.__vehicleRewardDisables = 0
    function _G.PlayerPedId() return _G.__ped end
    function _G.PlayerId() return 0 end
    function _G.GetSelectedPedWeapon(_) return _G.__selectedWeapon end
    function _G.RemoveWeaponFromPed(_, hash) _G.__removedWeapons[hash] = true end
    function _G.GetPlayers() return {} end
    function _G.GetPlayerPed(_) return 0 end

    -- Movement-state natives used by crouch. These deliberately record the
    -- active clipset/animation so its smoke test exercises transitions rather
    -- than merely checking that callbacks did not error.
    _G.__movementClipset = nil
    _G.__strafeClipset = nil
    _G.__lastAnimation = nil
    _G.__controlsPressed = {}
    _G.__gameTimer = 0
    _G.__heading = 0.0
    function _G.IsEntityDead(_) return false end
    function _G.IsPedRagdoll(_) return false end
    function _G.IsPedFalling(_) return false end
    function _G.IsPedJumping(_) return false end
    function _G.IsPedClimbing(_) return false end
    function _G.IsPedSwimming(_) return false end
    function _G.IsPedInAnyVehicle(_, _) return false end
    function _G.RequestAnimSet(_) end
    function _G.HasAnimSetLoaded(_) return true end
    function _G.RemoveClipSet(_) end
    function _G.RequestAnimDict(_) end
    function _G.HasAnimDictLoaded(_) return true end
    function _G.DoesAnimDictExist(_) return true end
    function _G.RemoveAnimDict(_) end
    function _G.SetPedMovementClipset(_, clipset, _) _G.__movementClipset = clipset end
    function _G.SetPedStrafeClipset(_, clipset) _G.__strafeClipset = clipset end
    function _G.ResetPedMovementClipset(_, _) _G.__movementClipset = nil end
    function _G.ResetPedStrafeClipset(_) _G.__strafeClipset = nil end
    function _G.SetPedUsingActionMode(_, _, _, _) end
    function _G.TaskPlayAnim(_, dict, clip, _, _, _, flag, _, _, _, _) _G.__lastAnimation = { dict = dict, clip = clip, flag = flag } end
    function _G.TaskPlayAnimAdvanced(_, dict, clip, _, _, _, _, _, _, _, _, _, flag, animTime, _, _)
        _G.__lastAnimation = { dict = dict, clip = clip, flag = flag, animTime = animTime }
    end
    function _G.StopAnimTask(_, _, _, _) _G.__lastAnimation = nil end
    function _G.GetEntityCoords(_) return { x = 1.0, y = 2.0, z = 3.0 } end
    function _G.GetEntityHeading(_) return _G.__heading end
    function _G.SetEntityHeading(_, heading) _G.__heading = heading end
    function _G.IsControlPressed(_, control) return _G.__controlsPressed[control] == true end
    function _G.GetGameTimer() return _G.__gameTimer end
    function _G.GetResourceState(_) return 'missing' end

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
    function _G.DisablePlayerVehicleRewards(_) _G.__vehicleRewardDisables = _G.__vehicleRewardDisables + 1 end
    -- GetPlayerWantedLevel needs a real return; default 0 (no level).
    _G.GetPlayerWantedLevel = function() return _G.__wantedLevel or 0 end

    -- Minimal Kora.notify used by blacklist client.
    _G.Kora = _G.Kora or {}
    _G.Kora.cache = _G.Kora.cache or {}
    function _G.Kora.cache.ped() return _G.__ped end
    function _G.Kora.cache.playerId() return 0 end
    function _G.Kora.cache.weapon() return _G.__selectedWeapon end
    function _G.Kora.cache.onChange(key, handler)
        cacheChangeHandlers[key] = cacheChangeHandlers[key] or {}
        table.insert(cacheChangeHandlers[key], handler)
    end
    _G.Kora.notify = _G.Kora.notify or {}
    _G.__notifications = {}
    function _G.Kora.notify.send(payload) table.insert(_G.__notifications, payload) end
    _G.Kora.stream = _G.Kora.stream or {}
    function _G.Kora.stream.loadClipSet(name) return name end
    function _G.Kora.stream.loadAnimDict(name) return name end
    _G.__keybinds = {}
    _G.Kora.keybind = _G.Kora.keybind or {}
    function _G.Kora.keybind.add(options)
        _G.__keybinds[options.name] = options
        return { remove = function() return true end }
    end

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
        cacheChange = function(key, value, oldValue)
            if key == "weapon" then _G.__selectedWeapon = value end
            for _, handler in ipairs(cacheChangeHandlers[key] or {}) do handler(value, oldValue) end
        end,
        keybind = function(name, phase)
            local binding = _G.__keybinds[name]
            assert(binding, ('unknown keybind: %s'):format(name))
            binding[phase == 'pressed' and 'onPressed' or 'onReleased']()
        end,
        control = function(control, pressed) _G.__controlsPressed[control] = pressed end,
        advanceTime = function(ms) _G.__gameTimer = _G.__gameTimer + ms end,
    }
end

return M
