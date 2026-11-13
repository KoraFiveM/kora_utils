if not Config.seatbelt.enabled then return end

local seatbelt, harness, harnessUses, busy = false, false, 0, false
local harnessConfig = Config.seatbelt.harness or {}
local separateHarness = harnessConfig.separateFromSeatbelt ~= false
local vehicle, velocity = nil, nil
local nextSample, peakSpeed, previousBody, frameBodyChange, peakTicks, damageDone = 0, 0, 0, 0, 0, false

local function announce()
    LocalPlayer.state:set('seatbelt', seatbelt, false)
    TriggerEvent('seatbelt:client:ToggleSeatbelt', seatbelt)
    TriggerEvent('hud:client:UpdateHarness', harnessUses)
    LocalPlayer.state:set('harness', harness, false)
    TriggerEvent('seatbelt:client:ToggleHarness', harness, harnessUses)
end

local function reset()
    vehicle, velocity = nil, nil
    nextSample, peakSpeed, previousBody, frameBodyChange, peakTicks, damageDone = 0, 0, 0, 0, 0, false
    seatbelt, harness, harnessUses = false, false, 0
    announce()
    TriggerServerEvent('kora_utils:server:leaveVehicle')
end

local function allowedVehicle(value)
    if not value or value == 0 then return nil end
    local class = GetVehicleClass(value)
    if class == 8 or class == 13 or class == 14 then return nil end
    return value
end

local setFrameActive

local function changed(value)
    local current = allowedVehicle(value)
    if current == vehicle then return end
    reset()
    vehicle = current
    if vehicle then
        velocity = GetEntityVelocity(vehicle)
        if setFrameActive then
            setFrameActive(true)
        end
    end
end
local function watchVehicle()
    Kora.cache.onChange('vehicle', changed)
    changed(Kora.cache.vehicle())
end
announce()
watchVehicle()
AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'kora_lib' then
        watchVehicle()
    end
end)

local function toggleSeatbelt()
    if not vehicle or IsPauseMenuActive() then return end
    if not separateHarness and Config.seatbelt.removeEmptyHarness and harness and harnessUses == 0 then
        TriggerServerEvent('kora_utils:server:removeHarness')
        return
    end
    seatbelt = not seatbelt
    announce()
    TriggerServerEvent('InteractSound_SV:PlayWithinDistance', 5.0, seatbelt and 'carbuckle' or 'carunbuckle', 0.25)
end
RegisterCommand('toggleseatbelt', toggleSeatbelt, false)
RegisterKeyMapping('toggleseatbelt', Kora.lang('toggle_seatbelt'), 'keyboard', Config.seatbelt.keybind)
AddEventHandler('kora_utils:client:toggleSeatbelt', toggleSeatbelt)

local compatibilityExports = {
    HasHarness = function()
        return harness
    end,
    HasSeatbeltOn = function()
        return seatbelt
    end,
}

for name, handler in pairs(compatibilityExports) do
    exports(name, handler)
    Kora.compat.provideExport('qb-smallresources', name, handler)
end

RegisterNetEvent('kora_utils:client:harnessState', function(enabled, uses)
    if source ~= 65535 then return end
    if enabled == true and vehicle then
        if not harness and not separateHarness then
            seatbelt = true
        end
        harness, harnessUses = true, math.max(0, tonumber(uses) or 0)
    else
        if harness and not separateHarness then
            seatbelt = false
        end
        harness, harnessUses = false, 0
    end
    announce()
end)

RegisterNetEvent('seatbelt:client:UseHarness', function(item, token)
    if type(item) ~= 'table' then return end
    if busy or LocalPlayer.state.inv_busy or not vehicle then
        if token ~= nil then
            TriggerServerEvent('kora_utils:server:cancelHarness', token)
        end
        return
    end
    busy = true
    local selected = vehicle
    local lockInventory = harnessConfig.lockInventory == true
    if lockInventory then
        LocalPlayer.state:set('inv_busy', true, true)
    end
    local label = Kora.lang(harness and 'remove_harness' or 'attach_harness')
    local ok, completed = pcall(Kora.progressbar.start, {
        label = label,
        duration = Config.seatbelt.equipDuration,
        canCancel = true,
        disable = {
            combat = true,
        },
    })
    if lockInventory then
        LocalPlayer.state:set('inv_busy', false, true)
    end
    busy = false
    if not ok or not completed or vehicle ~= selected then
        TriggerServerEvent('kora_utils:server:cancelHarness', token)
        return
    end
    if Kora.callback.trigger('kora_utils:server:finishHarness', { slot = item.slot }, token) ~= true then
        Kora.notify.send({
            title = Kora.lang('harness'),
            message = Kora.lang('harness_equip_failed'),
            type = 'error',
        })
    end
end)

local harnessCommand = harnessConfig.command
if type(harnessCommand) == 'string' and harnessCommand ~= '' then
    local requesting = false
    RegisterCommand(harnessCommand, function()
        if requesting or busy or not vehicle or IsPauseMenuActive() then return end
        requesting = true
        CreateThread(function()
            local ok, result = pcall(Kora.callback.trigger, 'kora_utils:server:toggleHarness')
            requesting = false
            if ok and result == 'noitem' then
                Kora.notify.send({
                    title = Kora.lang('race_harness'),
                    message = Kora.lang('harness_required'),
                    type = 'error',
                })
            end
        end)
    end, false)
    RegisterKeyMapping(harnessCommand, Kora.lang('toggle_race_harness'), 'keyboard', harnessConfig.keybind or '')
end

local function eject(ped)
    local coords = GetOffsetFromEntityInWorldCoords(vehicle, 1.0, 0.0, 1.0)
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetPedToRagdoll(ped, 5511, 5511, 0, false, false, false)
    if velocity then
        SetEntityVelocity(ped, velocity.x * 4, velocity.y * 4, velocity.z * 4)
    end
    SetEntityHealth(ped, math.max(0, GetEntityHealth(ped) - math.ceil(GetEntitySpeed(ped) * 8)))
end

setFrameActive = Small.onFrame(function()
    if not vehicle then
        if setFrameActive then
            setFrameActive(false)
        end
        return
    end
    if seatbelt or harness then
        DisableControlAction(0, 75, true)
        DisableControlAction(27, 75, true)
    end
    local now = GetGameTimer()
    if now < nextSample then return end
    local ped = Kora.cache.ped()
    if GetVehiclePedIsIn(ped, false) ~= vehicle or IsEntityDead(ped) then
        changed(nil)
        return
    end
    local speed, body = GetEntitySpeed(vehicle) * 3.6, GetVehicleBodyHealth(vehicle)
    if body == 1000 and frameBodyChange ~= 0 then
        frameBodyChange = 0
    end
    if frameBodyChange ~= 0 then
        if peakSpeed > 110 and speed < peakSpeed * 0.75 and not damageDone then
            local threshold = not (seatbelt or harness) and 60 or (frameBodyChange > 18 and 150 or 200)
            local minimum = not (seatbelt or harness) and 110 or (frameBodyChange > 18 and 150 or 120)
            if peakSpeed > minimum and math.random(math.ceil(peakSpeed)) > threshold then
                if harness then TriggerServerEvent('seatbelt:DoHarnessDamage', harnessUses, {slot=false})
                else eject(ped) end
            end
            damageDone = true
            SetVehicleEngineOn(vehicle, false, true, true)
        end
        if body < 350 and not damageDone then
            damageDone = true
            SetVehicleEngineOn(vehicle, false, true, true)
            nextSample = now + 1000
        end
    end
    if peakSpeed < 100 then
        nextSample = math.max(nextSample, now + 100)
        peakTicks = 0
    end
    frameBodyChange = previousBody - body
    if peakTicks > 0 then
        peakTicks = peakTicks - 1
        if peakTicks == 1 then
            peakSpeed = speed
        end
    else
        if damageDone then
            damageDone = false
            frameBodyChange = 0
            peakSpeed = speed
        end
        if speed > peakSpeed then
            peakSpeed = speed
        end
        if speed < peakSpeed then
            peakTicks = 25
        end
    end
    previousBody, velocity = body, GetEntityVelocity(vehicle)
end)
if setFrameActive and not vehicle then
    setFrameActive(false)
end
AddEventHandler('QBCore:Client:OnPlayerUnload', reset)
AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if busy then
        Kora.progressbar.cancel()
        if harnessConfig.lockInventory == true then
            LocalPlayer.state:set('inv_busy', false, true)
        end
    end
    reset()
end)
