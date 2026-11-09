local M = {}

---Installs mocked globals into _G and returns a handle for driving/inspecting
---the simulated runtime. Mirrors kora_lib/test/mocks.lua's shape (step/fire) so the
---one-shot-thread convention is the same across both test suites.
function M.install()
    local threads = {}
    local eventHandlers = {}
    local cacheChangeHandlers = {}

    function _G.CreateThread(fn)
        local co = coroutine.create(fn)
        threads[#threads + 1] = co
        local ok, err = coroutine.resume(co)
        if not ok then error(("CreateThread body errored: %s"):format(tostring(err)), 0) end
    end

    function _G.Wait(_) coroutine.yield() end

    local timers = {}
    function _G.SetTimeout(ms, fn)
        timers[#timers + 1] = { at = _G.__gameTimer + ms, fn = fn }
    end

    local stateBagHandlers = {}
    function _G.AddStateBagChangeHandler(key, bagFilter, fn)
        stateBagHandlers[#stateBagHandlers + 1] = { key = key, bagFilter = bagFilter, fn = fn }
    end
    function _G.GetPlayerServerId(_) return 1 end
    _G.LocalPlayer = { state = {} }

    function _G.AddEventHandler(name, cb)
        eventHandlers[name] = eventHandlers[name] or {}
        table.insert(eventHandlers[name], cb)
    end

    _G.RegisterNetEvent = _G.AddEventHandler

    function _G.TriggerEvent(name, ...)
        for _, fn in ipairs(eventHandlers[name] or {}) do fn(...) end
    end

    function _G.joaat(str)
        local hash = 2166136261
        for i = 1, #str do
            hash = (hash ~ str:byte(i)) & 0xFFFFFFFF
            hash = (hash * 16777619) & 0xFFFFFFFF
        end
        return hash
    end
    _G.GetHashKey = _G.joaat

    _G.__cancelled = false
    function _G.CancelEvent() _G.__cancelled = true end

    _G.__entityModel = 0
    function _G.GetEntityModel(_) return _G.__entityModel end
    function _G.DoesEntityExist(e) return e ~= nil and e ~= 0 end
    function _G.GetGamePool(_) return {} end
    function _G.SetPedDropsWeaponsWhenDead(_, _) end

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

    _G.__movementClipset = nil
    _G.__strafeClipset = nil
    _G.__lastAnimation = nil
    _G.__controlsPressed = {}
    _G.__gameTimer = 0
    _G.__heading = 0.0
    function _G.IsEntityDead(_) return false end
    function _G.IsPedRagdoll(_) return _G.__ragdoll == true end
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
    function _G.SetPedCanPlayAmbientIdles(_, block, _) _G.__idlesBlocked = block == true end
    function _G.ResetPedMovementClipset(_, _) _G.__movementClipset = nil end
    function _G.ResetPedStrafeClipset(_) _G.__strafeClipset = nil end
    function _G.SetPedUsingActionMode(_, _, _, _) end
    _G.__stealth = false
    function _G.GetPedStealthMovement(_) return _G.__stealth end
    function _G.SetPedStealthMovement(_, enabled, _) _G.__stealth = enabled == true end
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

    for _, name in ipairs({
        "SetMaxWantedLevel", "SetPoliceIgnorePlayer", "GetPlayerWantedLevel",
        "SetPlayerWantedLevel", "SetPlayerWantedLevelNow", "ClearPlayerWantedLevel", "HideHudComponentThisFrame", "EnableDispatchService",
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
    _G.GetPlayerWantedLevel = function() return _G.__wantedLevel or 0 end

    _G.Kora = _G.Kora or {}
    _G.Kora.cache = _G.Kora.cache or {}
    function _G.Kora.cache.ped() return _G.__ped end
    function _G.Kora.cache.playerId() return 0 end
    function _G.Kora.cache.weapon() return _G.__selectedWeapon end
    function _G.Kora.cache.vehicle() return _G.__vehicle end
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
        ---Advance the game clock and run every SetTimeout that came due (including ones they schedule).
        advanceTime = function(ms)
            _G.__gameTimer = _G.__gameTimer + ms
            local ran = true
            while ran do
                ran = false
                for i, timer in ipairs(timers) do
                    if timer.at <= _G.__gameTimer then
                        table.remove(timers, i)
                        timer.fn()
                        ran = true
                        break
                    end
                end
            end
        end,
        pendingTimers = function() return #timers end,
        ---Fire a state bag change for `key` on `bagName` into matching handlers.
        stateBag = function(key, bagName, value)
            if bagName == 'player:1' then _G.LocalPlayer.state[key] = value end
            for _, handler in ipairs(stateBagHandlers) do
                if handler.key == key then handler.fn(bagName, key, value, 0, true) end
            end
        end,
    }
end

return M
