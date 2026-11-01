-- Legacy qb-smallresources presentation exports. Nothing is scheduled until a
-- caller changes a value, so an untouched server pays no per-frame cost.
local hidden, owners = {}, {}
local density, displayAmmo, ammoTouched = {}, true, false
local scheduled = false

local function schedule()
    if scheduled then return end
    scheduled = true
    Small.onFrame(function()
        for index = 1, #hidden do HideHudComponentThisFrame(hidden[index]) end
        if ammoTouched then DisplayAmmoThisFrame(displayAmmo) end
        if density.parked then SetParkedVehicleDensityMultiplierThisFrame(density.parked) end
        if density.vehicle then SetVehicleDensityMultiplierThisFrame(density.vehicle) end
        if density.multiplier then SetRandomVehicleDensityMultiplierThisFrame(density.multiplier) end
        if density.peds then SetPedDensityMultiplierThisFrame(density.peds) end
        if density.scenario then
            SetScenarioPedDensityMultiplierThisFrame(density.scenario, density.scenario)
        end
    end)
end

local function components(value)
    if type(value) == 'number' then value = { value } end
    if type(value) ~= 'table' then return {} end
    local list = {}
    for index = 1, #value do
        local id = value[index]
        if type(id) ~= 'number' or id < 0 or id % 1 ~= 0 then return {} end
        list[#list + 1] = id
    end
    return list
end

local function addDisableHudComponents(value)
    local owner = GetInvokingResource() or GetCurrentResourceName()
    for _, id in ipairs(components(value)) do
        hidden[#hidden + 1] = id
        owners[#hidden] = owner
    end
    if #hidden > 0 then schedule() end
end

local function removeDisableHudComponents(value)
    for _, id in ipairs(components(value)) do
        for index = 1, #hidden do
            if hidden[index] == id then
                table.remove(hidden, index)
                table.remove(owners, index)
                break
            end
        end
    end
end

local function getDisableHudComponents()
    local copy = {}
    for index = 1, #hidden do copy[index] = hidden[index] end
    return copy
end

local densityTypes = { parked = true, vehicle = true, multiplier = true, peds = true, scenario = true }

local function decorSet(kind, value)
    if not densityTypes[kind] then return end
    if value ~= nil and (type(value) ~= 'number' or value < 0 or value > 1) then return end
    density[kind] = value
    schedule()
end

local function setDisplayAmmo(value)
    if type(value) ~= 'boolean' then return end
    displayAmmo, ammoTouched = value, true
    schedule()
end

local function getDisplayAmmo() return displayAmmo end

local function getHandsup()
    return IsEntityPlayingAnim(PlayerPedId(), 'missminuteman_1ig_2', 'handsup_base', 3) == true
end

for name, handler in pairs({ DecorSet = decorSet, addDisableHudComponents = addDisableHudComponents,
    removeDisableHudComponents = removeDisableHudComponents, getDisableHudComponents = getDisableHudComponents,
    setDisplayAmmo = setDisplayAmmo, getDisplayAmmo = getDisplayAmmo, getHandsup = getHandsup }) do
    exports(name, handler)
    Kora.compat.provideExport('qb-smallresources', name, handler)
end

AddEventHandler('onClientResourceStop', function(resource)
    for index = #hidden, 1, -1 do
        if resource == GetCurrentResourceName() or owners[index] == resource then
            table.remove(hidden, index)
            table.remove(owners, index)
        end
    end
end)
