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
    TriggerClientEvent('qbsmallresources:client:harnessState', src, state ~= nil, state and state.uses or 0)
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

local function beginUse(src, supplied)
    if busy[src] or pending[src] then return end
    local vehicle = currentVehicle(src)
    local item = vehicle and type(supplied) == 'table' and harnessItem(src, supplied.slot)
    if not item then return end
    sequence = sequence + 1
    local action = { token = tostring(sequence), slot = item.slot, vehicle = vehicle,
        started = GetGameTimer(), remove = equipped[src] ~= nil }
    pending[src] = action
    SetTimeout(Config.seatbelt.actionLifetime, function()
        if pending[src] == action then pending[src] = nil end
    end)
    -- Keep the legacy item argument. The extra token is used by this native
    -- client; unchanged stock clients still complete through equip:harness.
    TriggerClientEvent('seatbelt:client:UseHarness', src, item, action.token)
end

local function finish(src, supplied, token)
    local action = pending[src]
    if busy[src] or not action or type(supplied) ~= 'table' or supplied.slot ~= action.slot then return false end
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
    -- The last consumed item still provides the one equipped protection, as
    -- stock does. Another crash removes that protection without inventing an item.
    equipped[src] = { slot = action.slot, uses = remaining, vehicle = action.vehicle,
        body = GetVehicleBodyHealth(action.vehicle), damagedAt = -Config.seatbelt.crashCooldown }
    publish(src)
    return true
end

QB.callback.register('qbsmallresources:server:finishHarness', finish, {rateLimit={max=4,window=10000}})
RegisterNetEvent('equip:harness', function(item) finish(source, item) end)
RegisterNetEvent('qbsmallresources:server:cancelHarness', function(token)
    local action = pending[source]
    if action and action.token == token then pending[source] = nil end
end)
RegisterNetEvent('qbsmallresources:server:leaveVehicle', function() clear(source) end)

-- Client hp/metadata are deliberately ignored. A report can only consume the
-- sender's equipped item after a new body-health loss on that same vehicle.
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
