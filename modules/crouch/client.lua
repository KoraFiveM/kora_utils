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
local proneMotion = nil
local proneStepEndsAt = 0
local frameWatcherActive = false

local proneStepDuration = {
    forward = 820,
    backward = 990,
}

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

-- Forward declared: stand() stops the frame watcher, and the watcher itself
-- can call stand() when canChangeStance fails mid-loop.
local stand

local function stopFrameWatcher()
    frameWatcherActive = false
end

local function startFrameWatcher()
    if frameWatcherActive then return end
    frameWatcherActive = true

    CreateThread(function()
        while frameWatcherActive do
            -- INPUT_DUCK (36) is the stock action/fighting stance. It must be
            -- disabled every frame the watcher is running so the keybind
            -- never leaves the player in that stance.
            DisableControlAction(0, 36, true)

            if stance ~= 'standing' then
                local ped = PlayerPedId()
                if not canChangeStance(ped) then
                    stand(ped)
                else
                    SetPedUsingActionMode(ped, false, -1, 0)
                    if stance == 'prone' then
                        DisableControlAction(0, 21, true) -- INPUT_SPRINT
                        DisableControlAction(0, 22, true) -- INPUT_JUMP

                        local forward = IsControlPressed(0, 32) -- INPUT_MOVE_UP_ONLY
                        local backward = IsControlPressed(0, 33) -- INPUT_MOVE_DOWN_ONLY
                        local now = GetGameTimer()

                        if forward then
                            if proneMotion ~= 'forward' or now >= proneStepEndsAt then
                                playProneStep(ped, 'forward', now)
                            end
                        elseif backward then
                            if proneMotion ~= 'backward' or now >= proneStepEndsAt then
                                playProneStep(ped, 'backward', now)
                            end
                        elseif proneMotion ~= 'idle' then
                            local clip = proneMotion == 'backward' and config.proneBackwardAnim or config.proneForwardAnim
                            playProneIdle(ped, clip)
                        end

                        if IsControlPressed(0, 34) then -- INPUT_MOVE_LEFT_ONLY
                            SetEntityHeading(ped, GetEntityHeading(ped) + config.proneTurnSpeed)
                        elseif IsControlPressed(0, 35) then -- INPUT_MOVE_RIGHT_ONLY
                            SetEntityHeading(ped, GetEntityHeading(ped) - config.proneTurnSpeed)
                        end
                    end
                end
            end

            Wait(0)
        end
    end)
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
    for clipset in pairs(loadedClipsets) do RemoveClipSet(clipset) end
    loadedClipsets = {}
    if proneAnimationLoaded then RemoveAnimDict(config.proneAnimDict) end
    proneAnimationLoaded = false
end

local function stopProneAnimation(ped)
    if not proneAnimationLoaded then return end
    StopAnimTask(ped, config.proneAnimDict, config.proneForwardAnim, -4.0)
    StopAnimTask(ped, config.proneAnimDict, config.proneBackwardAnim, -4.0)
    proneMotion = nil
    proneStepEndsAt = 0
end

stand = function(ped)
    if stance == 'prone' then stopProneAnimation(ped) end
    restoreWalkStyle(ped)
    stopFrameWatcher()
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

    if stance == 'prone' then stopProneAnimation(ped) end
    SetPedUsingActionMode(ped, false, -1, 0)
    SetPedMovementClipset(ped, config.crouchClipset, 0.25)
    SetPedStrafeClipset(ped, config.crouchStrafeClipset)
    stance = 'crouched'
    startFrameWatcher()
    return true
end

local function prone(ped)
    if not canChangeStance(ped) then return false end
    local dict = QB.stream.loadAnimDict(config.proneAnimDict)
    if dict == false then return false end
    proneAnimationLoaded = true

    SetPedUsingActionMode(ped, false, -1, 0)
    -- `move_crawl` is an animation dictionary, not a movement clipset. Passing
    -- it to SetPedMovementClipset leaves the skeleton without valid locomotion
    -- clips and produces a T-pose. Clear any crouch clipsets, then hold the end
    -- of a real crawl animation as the prone idle pose.
    ResetPedMovementClipset(ped, 0.25)
    ResetPedStrafeClipset(ped)
    local coords = GetEntityCoords(ped)
    TaskPlayAnimAdvanced(ped, config.proneAnimDict, config.proneForwardAnim,
        coords.x, coords.y, coords.z, 0.0, 0.0, GetEntityHeading(ped),
        8.0, -8.0, -1, 2, 1.0, false, false)
    proneMotion = 'idle'
    proneStepEndsAt = 0
    stance = 'prone'
    startFrameWatcher()
    return true
end

function playProneIdle(ped, clip)
    local coords = GetEntityCoords(ped)
    TaskPlayAnimAdvanced(ped, config.proneAnimDict, clip,
        coords.x, coords.y, coords.z, 0.0, 0.0, GetEntityHeading(ped),
        8.0, -8.0, -1, 2, 1.0, false, false)
    proneMotion = 'idle'
    proneStepEndsAt = 0
end

function playProneStep(ped, direction, now)
    local clip = direction == 'forward' and config.proneForwardAnim or config.proneBackwardAnim
    TaskPlayAnim(ped, config.proneAnimDict, clip, 8.0, -8.0, -1, 2, 0.0, false, false, false)
    proneMotion = direction
    proneStepEndsAt = now + proneStepDuration[direction]
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
            if prone(PlayerPedId()) then heldPressId = currentPress end
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

Small.onSpawn(function()
    -- A respawn creates a new ped with stock movement. Forget the old ped's
    -- state so a held/released key cannot apply a stale stance to the new one,
    -- and stop the watcher so it isn't left running against the new ped.
    stance = 'standing'
    keyHeld = false
    heldPressId = nil
    stopFrameWatcher()
    releaseAssets()
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    local ped = PlayerPedId()
    if DoesEntityExist(ped) then stand(ped) end
end)
