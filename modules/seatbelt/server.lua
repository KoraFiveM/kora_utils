if not Config.seatbelt.enabled then return end

local pending, equipped, busy = {}, {}, {}
local sequence = 0

local function currentVehicle(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local vehicle = GetVehiclePedIsIn(ped, false)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return nil end
    if GetPlayerRoutingBucket(src) ~= GetEntityRoutingBucket(vehicle) then return nil end
    local kind = GetVehicleType(vehicle)
    if kind == 'bike' or kind == 'boat' then return nil end
    return vehicle
end

local function harnessItem(src, slot)
    if type(slot) ~= 'number' or slot < 1 or slot % 1 ~= 0 then return nil end
    local item = exports.kora_core:getItemBySlot(src, slot)
    if not item or item.name ~= 'harness' or (item.amount or 0) < 1 then return nil end
    local uses = item.info and item.info.uses
    if uses == nil then uses = Config.HarnessUses end
    if type(uses) ~= 'number' or uses < 1 or uses % 1 ~= 0 or uses > Config.HarnessUses then return nil end
    return item, uses
end

local function publish(src)
    local state = equipped[src]
    TriggerClientEvent('kora_utils:client:harnessState', src, state ~= nil, state and state.uses or 0)
end
 
local function clear(src)
    if type(src) ~= 'number' or src < 1 then return end
    pending[src], equipped[src], busy[src] = nil, nil, nil
    publish(src)
end

local function consumeUse(src, item, uses)
    if uses <= 1 then
        return exports.kora_core:removeItem(src, 'harness', 1, item.slot, 'seatbelt-harness') == true, 0
    end
    local info = {}
    for key, value in pairs(item.info or {}) do info[key] = value end
    info.uses = uses - 1
    local ok = exports['qb-inventory']:SetItemData(src, 'harness', 'info', info, item.slot)
    return ok == true, info.uses
end

local function startAction(src, vehicle, item)
    sequence = sequence + 1
    local action = { token = tostring(sequence), slot = item and item.slot or false, vehicle = vehicle,
        started = GetGameTimer(), remove = equipped[src] ~= nil }
    pending[src] = action
    SetTimeout(Config.seatbelt.actionLifetime, function()
        if pending[src] == action then pending[src] = nil end
    end)
    TriggerClientEvent('seatbelt:client:UseHarness', src, item or { name = 'harness', slot = false }, action.token)
end

local function beginUse(src, supplied)
    if busy[src] or pending[src] then return end
    local vehicle = currentVehicle(src)
    local item = vehicle and type(supplied) == 'table' and harnessItem(src, supplied.slot)
    if not item then return end
    startAction(src, vehicle, item)
end

local function ownedHarness(src)
    local ok, list = pcall(function() return exports.kora_core:getItemsByName(src, 'harness') end)
    if not ok or type(list) ~= 'table' then return nil end
    local best
    for _, entry in pairs(list) do
        local item = type(entry) == 'table' and harnessItem(src, entry.slot)
        if item and (not best or item.slot < best.slot) then best = item end
    end
    return best
end

local function toggle(src)
    if busy[src] or pending[src] then return 'busy' end
    local vehicle = currentVehicle(src)
    if not vehicle then return 'novehicle' end
    if equipped[src] then
        if equipped[src].vehicle ~= vehicle then clear(src); return 'removed' end
        startAction(src, vehicle, nil)
        return 'removing'
    end
    local item = ownedHarness(src)
    if not item then return 'noitem' end
    startAction(src, vehicle, item)
    return 'attaching'
end

local function finish(src, supplied, token)
    local action = pending[src]
    if busy[src] or not action or type(supplied) ~= 'table' or (supplied.slot or false) ~= action.slot then return false end
    if token ~= nil and token ~= action.token then return false end
    pending[src] = nil
    local elapsed = GetGameTimer() - action.started
    if elapsed < Config.seatbelt.equipDuration or elapsed > Config.seatbelt.actionLifetime
        or currentVehicle(src) ~= action.vehicle then return false end
    if action.remove then equipped[src] = nil; publish(src); return true end
    local item, uses = harnessItem(src, action.slot)
    if not item then return false end
    busy[src] = action
    local ok, saved, remaining = pcall(consumeUse, src, item, uses)
    if busy[src] ~= action then return false end
    busy[src] = nil
    if not ok or not saved then return false end
    if currentVehicle(src) ~= action.vehicle then return false end
    equipped[src] = { slot = action.slot, uses = remaining, vehicle = action.vehicle,
        body = GetVehicleBodyHealth(action.vehicle), damagedAt = -Config.seatbelt.crashCooldown }
    publish(src)
    return true
end

Kora.callback.register('kora_utils:server:finishHarness', finish, {rateLimit={max=4,window=10000}})
local harnessCommand = (Config.seatbelt.harness or {}).command
if type(harnessCommand) == 'string' and harnessCommand ~= '' then
    Kora.callback.register('kora_utils:server:toggleHarness', toggle, {rateLimit={max=4,window=10000}})
end
RegisterNetEvent('equip:harness', function(item) finish(source, item) end)
RegisterNetEvent('kora_utils:server:cancelHarness', function(token)
    local action = pending[source]
    if action and action.token == token then pending[source] = nil end
end)
RegisterNetEvent('kora_utils:server:removeHarness', function()
    local src = source
    local state = equipped[src]
    if not Config.seatbelt.removeEmptyHarness or not state or state.uses ~= 0 or busy[src] or pending[src] then return end
    clear(src)
end)
RegisterNetEvent('kora_utils:server:leaveVehicle', function() clear(source) end)

RegisterNetEvent('seatbelt:DoHarnessDamage', function()
    local src, now = source, GetGameTimer()
    local state = equipped[src]
    if not state or busy[src] then return end
    if currentVehicle(src) ~= state.vehicle then clear(src); return end
    local body = GetVehicleBodyHealth(state.vehicle)
    if type(body) ~= 'number' or body >= state.body or now - state.damagedAt < Config.seatbelt.crashCooldown then return end
    state.body, state.damagedAt = body, now
    if state.uses == 0 then clear(src); return end
    local item, uses = harnessItem(src, state.slot)
    if not item then clear(src); return end
    busy[src] = state
    local ok, saved, remaining = pcall(consumeUse, src, item, uses)
    if busy[src] ~= state then return end
    busy[src] = nil
    if not ok or not saved then clear(src); return end
    if equipped[src] ~= state then return end
    state.uses = remaining
    if remaining == 0 then equipped[src] = nil end
    publish(src)
end)

local function registerUsable() exports.kora_core:createUseable('harness', beginUse) end
registerUsable()
AddEventHandler('playerDropped', function() pending[source], equipped[source], busy[source] = nil, nil, nil end)
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src) clear(src or source) end)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() and resource ~= 'kora_core' and resource ~= 'kora_inventory' then return end
    for src in pairs(equipped) do clear(src) end
    pending, busy = {}, {}
end)
AddEventHandler('onResourceStart', function(resource)
    if resource == 'kora_core' then registerUsable() end
end)
