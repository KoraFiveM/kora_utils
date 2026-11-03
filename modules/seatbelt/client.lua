if not Config.seatbelt.enabled then return end

local seatbelt, harness, harnessUses, busy = false, false, 0, false
local vehicle, velocity = nil, nil
local nextSample, peakSpeed, previousBody, frameBodyChange, peakTicks, damageDone = 0, 0, 0, 0, 0, false

local function announce()
    -- Local presentation state only; never replicated as inventory authority.
    LocalPlayer.state:set('seatbelt', seatbelt, false)
    TriggerEvent('seatbelt:client:ToggleSeatbelt', seatbelt)
    TriggerEvent('hud:client:UpdateHarness', harnessUses)
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
        if setFrameActive then setFrameActive(true) end
    end
end
-- onChange registrations die with kora_lib, so re-register and re-seed from the
-- current vehicle whenever it restarts (changed() ignores an unchanged vehicle).
local function watchVehicle()
    Kora.cache.onChange('vehicle', changed)
    changed(Kora.cache.vehicle())
end
announce()
watchVehicle()
AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'kora_lib' then watchVehicle() end
end)

local function toggleSeatbelt()
    if not vehicle or IsPauseMenuActive() then return end
    seatbelt = not seatbelt
    announce()
    TriggerServerEvent('InteractSound_SV:PlayWithinDistance', 5.0, seatbelt and 'carbuckle' or 'carunbuckle', 0.25)
end
RegisterCommand('toggleseatbelt', toggleSeatbelt, false)
RegisterKeyMapping('toggleseatbelt', 'Toggle Seatbelt', 'keyboard', Config.seatbelt.keybind)
AddEventHandler('qbsmallresources:client:toggleSeatbelt', toggleSeatbelt)

for name, handler in pairs({HasHarness=function() return harness end, HasSeatbeltOn=function() return seatbelt end}) do
    exports(name, handler)
    Kora.compat.provideExport('qb-smallresources', name, handler)
end

RegisterNetEvent('kora_utils:client:harnessState', function(enabled, uses)
    if source ~= 65535 then return end
    if enabled == true and vehicle then
        if not harness then seatbelt = not seatbelt end
        harness, harnessUses = true, math.max(0, tonumber(uses) or 0)
    else harness, harnessUses = false, 0 end
    announce()
end)

RegisterNetEvent('seatbelt:client:UseHarness', function(item, token)
    if busy or LocalPlayer.state.inv_busy or not vehicle or type(item) ~= 'table' then return end
    busy = true
    local selected = vehicle
    LocalPlayer.state:set('inv_busy', true, true)
    local ok, completed = pcall(Kora.progressbar.start, {
        label = harness and 'Removing Race Harness' or 'Attaching Race Harness',
        duration = Config.seatbelt.equipDuration, canCancel = true, disable = { combat = true },
    })
    LocalPlayer.state:set('inv_busy', false, true)
    busy = false
    if not ok or not completed or vehicle ~= selected then
        TriggerServerEvent('kora_utils:server:cancelHarness', token)
        return
    end
    if Kora.callback.trigger('kora_utils:server:finishHarness', {slot=item.slot}, token) ~= true then
        Kora.notify.send({title='Harness',message='The harness could not be equipped.',type='error'})
    end
end)

local function eject(ped)
    local coords = GetOffsetFromEntityInWorldCoords(vehicle, 1.0, 0.0, 1.0)
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetPedToRagdoll(ped, 5511, 5511, 0, false, false, false)
    if velocity then SetEntityVelocity(ped, velocity.x * 4, velocity.y * 4, velocity.z * 4) end
    SetEntityHealth(ped, math.max(0, GetEntityHealth(ped) - math.ceil(GetEntitySpeed(ped) * 8)))
end

-- Stock crash thresholds: a >25% speed drop from >110 km/h plus body damage;
-- ordinary belts retain stock high-speed ejection risk, harnesses absorb it.
-- Existing coordinator supplies the only frame worker; the task pauses itself
-- on foot and is resumed by `changed` on entering an allowed vehicle.
setFrameActive = Small.onFrame(function()
    if not vehicle then
        if setFrameActive then setFrameActive(false) end
        return
    end
    local ped = PlayerPedId()
    if GetVehiclePedIsIn(ped, false) ~= vehicle or IsEntityDead(ped) then changed(nil); return end
    if seatbelt or harness then
        DisableControlAction(0, 75, true)
        DisableControlAction(27, 75, true)
    end
    local now = GetGameTimer()
    if now < nextSample then return end
    local speed, body = GetEntitySpeed(vehicle) * 3.6, GetVehicleBodyHealth(vehicle)
    if body == 1000 and frameBodyChange ~= 0 then frameBodyChange = 0 end
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
    if peakSpeed < 100 then nextSample = math.max(nextSample, now + 100); peakTicks = 0 end
    -- Preserve upstream's 25-sample retained speed peak and delayed body delta;
    -- a collision often decelerates over several frames before body damage arrives.
    frameBodyChange = previousBody - body
    if peakTicks > 0 then
        peakTicks = peakTicks - 1
        if peakTicks == 1 then peakSpeed = speed end
    else
        if damageDone then damageDone = false; frameBodyChange = 0; peakSpeed = speed end
        if speed > peakSpeed then peakSpeed = speed end
        if speed < peakSpeed then peakTicks = 25 end
    end
    previousBody, velocity = body, GetEntityVelocity(vehicle)
end)
if setFrameActive and not vehicle then setFrameActive(false) end
AddEventHandler('QBCore:Client:OnPlayerUnload', reset)
AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if busy then Kora.progressbar.cancel() end
    LocalPlayer.state:set('inv_busy', false, true)
    reset()
end)
