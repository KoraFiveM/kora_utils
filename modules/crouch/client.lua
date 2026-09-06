-- crouch -- a real crouched locomotion state, with hold-to-prone. GTA's
-- built-in INPUT_DUCK toggles action mode, which is a fighting stance rather
-- than a crouch. This module owns that control and substitutes the proper
-- movement clipsets instead.

if not Config.crouch.enabled then return end

local config = Config.crouch
local stance = 'standing'
local keyHeld = false
local pressId = 0
local heldPressId = nil
local loadedClipsets = {}
local proneAnimationLoaded = false

local function canChangeStance(ped)
    return DoesEntityExist(ped)
        and not IsEntityDead(ped)
        and not IsPedRagdoll(ped)
        and not IsPedFalling(ped)
        and not IsPedJumping(ped)
        and not IsPedClimbing(ped)
        and not IsPedSwimming(ped)
        and not IsPedInAnyVehicle(ped, false)
        and not (LocalPlayer and LocalPlayer.state and LocalPlayer.state['qbemotemenu:active'])
end

local function restoreWalkStyle(ped)
    ResetPedMovementClipset(ped, 0.25)
    ResetPedStrafeClipset(ped)

    -- qbemotemenu owns an optional player walk style. Restore it after we
    -- release our temporary movement clipset instead of silently resetting it
    -- to GTA's default walk.
    local savedWalk = LocalPlayer and LocalPlayer.state and LocalPlayer.state['qbemotemenu:walk']
    if savedWalk and GetResourceState('qbemotemenu') == 'started' then
        pcall(function() exports.qbemotemenu:setWalk(savedWalk, true) end)
    end
end

local function releaseAssets()
    for clipset in pairs(loadedClipsets) do RemoveAnimSet(clipset) end
    loadedClipsets = {}
    if proneAnimationLoaded then RemoveAnimDict(config.proneAnimDict) end
    proneAnimationLoaded = false
end

local function stand(ped)
    if stance == 'prone' then
        StopAnimTask(ped, config.proneAnimDict, config.proneAnim, -4.0)
    end

    restoreWalkStyle(ped)
    SetPedUsingActionMode(ped, false, -1, 0)
    releaseAssets()
    stance = 'standing'
end

local function loadClipset(name)
    local loaded = QB.stream.loadClipSet(name)
    if loaded ~= false then loadedClipsets[name] = true end
    return loaded ~= false
end

local function crouch(ped)
    if not canChangeStance(ped)
        or not loadClipset(config.crouchClipset)
        or not loadClipset(config.crouchStrafeClipset) then
        return false
    end

    if stance == 'prone' then StopAnimTask(ped, config.proneAnimDict, config.proneAnim, -4.0) end
    SetPedUsingActionMode(ped, false, -1, 0)
    SetPedMovementClipset(ped, config.crouchClipset, 0.25)
    SetPedStrafeClipset(ped, config.crouchStrafeClipset)
    stance = 'crouched'
    return true
end

local function prone(ped)
    if not canChangeStance(ped) or not loadClipset(config.proneClipset) then return false end
    local dict = QB.stream.loadAnimDict(config.proneAnimDict)
    if dict == false then return false end
    proneAnimationLoaded = true

    SetPedUsingActionMode(ped, false, -1, 0)
    SetPedMovementClipset(ped, config.proneClipset, 0.25)
    SetPedStrafeClipset(ped, config.proneClipset)
    TaskPlayAnim(ped, config.proneAnimDict, config.proneAnim, 8.0, -8.0, -1, 2, 0.0, false, false, false)
    stance = 'prone'
    return true
end

local function toggleCrouch()
    local ped = PlayerPedId()
    if stance == 'crouched' or stance == 'prone' then
        stand(ped)
    else
        crouch(ped)
    end
end

QB.keybind.add({
    name = 'qbsmallresources_crouch',
    description = 'Toggle crouch / hold prone',
    defaultKey = config.keybind,
    onPressed = function()
        if keyHeld then return end
        keyHeld = true
        pressId = pressId + 1
        local currentPress = pressId

        Small.once(function()
            Wait(config.holdDuration)
            if not keyHeld or pressId ~= currentPress then return end
            heldPressId = currentPress
            prone(PlayerPedId())
        end)
    end,
    onReleased = function()
        keyHeld = false
        if heldPressId == pressId then
            heldPressId = nil
            return
        end
        toggleCrouch()
    end,
})

-- INPUT_DUCK (36) is the stock action/fighting stance. It must be disabled
-- every frame so the keybind above never leaves the player in that stance.
Small.onFrame(function()
    DisableControlAction(0, 36, true)

    if stance == 'standing' then return end
    local ped = PlayerPedId()
    if not canChangeStance(ped) then
        stand(ped)
        return
    end

    SetPedUsingActionMode(ped, false, -1, 0)
    if stance == 'prone' then
        DisableControlAction(0, 21, true) -- INPUT_SPRINT
        DisableControlAction(0, 22, true) -- INPUT_JUMP
    end
end)

Small.onSpawn(function()
    -- A respawn creates a new ped with stock movement. Forget the old ped's
    -- state so a held/released key cannot apply a stale stance to the new one.
    stance = 'standing'
    keyHeld = false
    heldPressId = nil
    releaseAssets()
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    local ped = PlayerPedId()
    if DoesEntityExist(ped) then stand(ped) end
end)
