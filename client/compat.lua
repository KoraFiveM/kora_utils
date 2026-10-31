-- The legacy controls API shares the existing frame coordinator. Harness and
-- seatbelt gameplay are separate contracts and are not fabricated here.
local disabled, scheduled = {}, false

local function visitControls(value, handler)
    if type(value) == 'number' then value = { value } end
    if type(value) ~= 'table' then return end
    local count = 0
    for key, control in pairs(value) do
        count = count + 1
        if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 or key > #value
            or type(control) ~= 'number' or control < 0 or control % 1 ~= 0 then return end
    end
    if count ~= #value then return end
    for index = 1, #value do handler(value[index]) end
end

local function addDisableControls(controls)
    local owner = GetInvokingResource() or GetCurrentResourceName()
    visitControls(controls, function(control)
        disabled[#disabled + 1] = { control = control, owner = owner }
    end)
    if scheduled or #disabled == 0 then return end
    scheduled = true
    Small.onFrame(function()
        for index = 1, #disabled do DisableControlAction(2, disabled[index].control, true) end
    end)
end

local function removeDisableControls(controls)
    visitControls(controls, function(control)
        for index = 1, #disabled do
            if disabled[index].control == control then table.remove(disabled, index); break end
        end
    end)
end

local function getDisableControls()
    local controls = {}
    for index = 1, #disabled do controls[index] = disabled[index].control end
    return controls
end

for name, handler in pairs({ addDisableControls = addDisableControls,
    removeDisableControls = removeDisableControls, getDisableControls = getDisableControls }) do
    exports(name, handler)
    Kora.compat.provideExport('qb-smallresources', name, handler)
end

AddEventHandler('onClientResourceStop', function(resource)
    for index = #disabled, 1, -1 do
        if resource == GetCurrentResourceName() or disabled[index].owner == resource then
            table.remove(disabled, index)
        end
    end
end)
