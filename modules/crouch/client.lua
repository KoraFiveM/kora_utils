if not Config.crouch.enabled then return end

-- Prone movement is read from key mappings; controller sticks are read from the prone
-- frame task only (config.proneControllerSupport).
-- Loop budget for this module:
--   standing         no frame work. GTA's own duck (stealth) is undone when the crouch key is
--                    pressed, plus a 1500 ms stealth check as a backstop ('event' mode). The
--                    'frame' mode instead disables control 36 every frame on foot.
--   crouched         one SetTimeout chain at config.reassertInterval (no thread, no Wait)
--   prone            the same chain, plus a frame task on the shared frame thread that only
--                    disables sprint/jump and applies turning while A/D are held
-- Prone movement keys are key mappings (press/release events), not IsControlPressed polling.
-- Emotes are detected from the replicated state bag, not read every frame.

local config = Config.crouch
-- blockStockDuck: 'event' (default; `true`/nil mean the same), 'frame', or false.
local stockDuckMode = config.blockStockDuck
if stockDuckMode == true or stockDuckMode == nil then stockDuckMode = 'event' end
if stockDuckMode ~= false and stockDuckMode ~= 'frame' then stockDuckMode = 'event' end
-- true when the stock duck is handled module-wide (either mode), so stance changes
-- need no frame task of their own for it.
local blockStock = stockDuckMode ~= false
local EMOTE_KEY = 'qbemotemenu:active'

local stance = 'standing'
local keyHeld = false
local pressId = 0
local heldPressId = nil
local loadedClipsets = {}
local proneAnimationLoaded = false
local proneMotion = nil
local proneStepEndsAt = 0
local idleBlocked = false
local emoteActive = false
local tickId = 0
local stepToken = 0

-- Physical state of the prone movement keys, kept current by the key mappings below.
local moveKeys = { forward = false, backward = false, left = false, right = false }

-- Controller sticks cannot be bound with RegisterKeyMapping (PAD_ANALOGBUTTON is
-- triggers only), so they are read from the prone frame task, which already runs
-- every frame while prone. Nothing is polled outside prone.
local padSupport = config.proneControllerSupport ~= false
local padKeys = { forward = false, backward = false }

local proneStepDuration = {
    forward = 820,
    backward = 990,
}

local function refreshEmote()
    emoteActive = (LocalPlayer and LocalPlayer.state and LocalPlayer.state[EMOTE_KEY]) and true or false
end

local function canChangeStance(ped)
    return DoesEntityExist(ped)
        and not IsEntityDead(ped)
        and not IsPedRagdoll(ped)
        and not IsPedFalling(ped)
        and not IsPedJumping(ped)
        and not IsPedClimbing(ped)
        and not IsPedSwimming(ped)
        and not IsPedInAnyVehicle(ped, false)
        and not emoteActive
end

local function clearStockStance(ped)
    SetPedUsingActionMode(ped, false, -1, 0)
    if GetPedStealthMovement(ped) then SetPedStealthMovement(ped, false, 'DEFAULT_ACTION') end
end

local stand, playProneIdle, playProneStep, syncProne

-- Per-frame work. Only registered while something genuinely needs a frame:
-- prone (sprint/jump must be disabled every frame, and A/D turn the ped), or a
-- held/active stance when the stock duck is not already blocked globally.
local setFrameActive = Small.onFrame(function()
    if not blockStock then DisableControlAction(0, 36, true) end
    if stance ~= 'prone' then return end

    DisableControlAction(0, 21, true)
    DisableControlAction(0, 22, true)

    local padLeft, padRight = false, false
    if padSupport then
        local forward = IsControlPressed(0, 32)
        local backward = IsControlPressed(0, 33)
        if forward ~= padKeys.forward or backward ~= padKeys.backward then
            padKeys.forward, padKeys.backward = forward, backward
            syncProne()
        end
        padLeft = IsControlPressed(0, 34)
        padRight = IsControlPressed(0, 35)
    end

    if moveKeys.left or padLeft then
        local ped = PlayerPedId()
        SetEntityHeading(ped, GetEntityHeading(ped) + config.proneTurnSpeed)
    elseif moveKeys.right or padRight then
        local ped = PlayerPedId()
        SetEntityHeading(ped, GetEntityHeading(ped) - config.proneTurnSpeed)
    end
end)
setFrameActive(false)

local function refreshFrame()
    setFrameActive(stance == 'prone' or (not blockStock and (stance ~= 'standing' or keyHeld)))
end

-- Interrupt / reassert tick: a SetTimeout chain that exists only while crouched
-- or prone. Ragdoll, falling, swimming, climbing, death and vehicles have no
-- event to hook, so they are checked here, off the frame path.
local function tickPeriod()
    local interval = config.reassertInterval or 0
    return interval > 0 and interval or 250
end

local function stopTick()
    tickId = tickId + 1
end

local function startTick()
    tickId = tickId + 1
    local myId = tickId

    local function tick()
        if tickId ~= myId or stance == 'standing' then return end

        local ped = PlayerPedId()
        if not canChangeStance(ped) then
            stand(ped)
            return
        end

        clearStockStance(ped)
        if stance == 'crouched' and (config.reassertInterval or 0) > 0 then
            SetPedMovementClipset(ped, config.crouchClipset, 0.25)
            SetPedStrafeClipset(ped, config.crouchStrafeClipset)
            if idleBlocked then SetPedCanPlayAmbientIdles(ped, true, true) end
        end

        SetTimeout(tickPeriod(), tick)
    end

    SetTimeout(tickPeriod(), tick)
end

-- Applies the current forward/backward key state to the prone animation. Called
-- on key press/release and by its own step timer; never polls.
syncProne = function()
    if stance ~= 'prone' then return end

    stepToken = stepToken + 1
    local ped = PlayerPedId()
    local direction = ((moveKeys.forward or padKeys.forward) and 'forward')
        or ((moveKeys.backward or padKeys.backward) and 'backward')
        or nil

    if direction then
        local now = GetGameTimer()
        if proneMotion ~= direction or now >= proneStepEndsAt then
            playProneStep(ped, direction, now)
        end

        -- Step clips hold their last frame, so replay when the step ends while
        -- the key is still down. The token drops this timer if anything else
        -- (a key change, standing up) syncs first.
        local token = stepToken
        SetTimeout(math.max(proneStepEndsAt - GetGameTimer(), 1), function()
            if token == stepToken then syncProne() end
        end)
    elseif proneMotion ~= 'idle' then
        local clip = proneMotion == 'backward' and config.proneBackwardAnim or config.proneForwardAnim
        playProneIdle(ped, clip)
    end
end

local function restoreWalkStyle(ped)
    ResetPedMovementClipset(ped, 0.25)
    ResetPedStrafeClipset(ped)

    local savedWalk = LocalPlayer and LocalPlayer.state and LocalPlayer.state['qbemotemenu:walk']
    if savedWalk and GetResourceState('kora_emotemenu') == 'started' then
        pcall(function() exports.kora_emotemenu:setWalk(savedWalk, true) end)
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
    clearStockStance(ped)
    if idleBlocked then
        SetPedCanPlayAmbientIdles(ped, false, false)
        idleBlocked = false
    end
    releaseAssets()
    stance = 'standing'
    stepToken = stepToken + 1
    padKeys.forward, padKeys.backward = false, false
    stopTick()
    refreshFrame()
end

local function loadClipset(name)
    local loaded = Kora.stream.loadClipSet(name)
    if loaded ~= false then loadedClipsets[name] = true end
    return loaded ~= false
end

local function crouch(ped)
    refreshEmote()
    if not canChangeStance(ped)
        or not loadClipset(config.crouchClipset)
        or not loadClipset(config.crouchStrafeClipset) then
        return false
    end

    if stance == 'prone' then stopProneAnimation(ped) end
    clearStockStance(ped)
    SetPedMovementClipset(ped, config.crouchClipset, 0.25)
    SetPedStrafeClipset(ped, config.crouchStrafeClipset)
    if config.blockIdleClips ~= false then
        SetPedCanPlayAmbientIdles(ped, true, true)
        idleBlocked = true
    end
    stance = 'crouched'
    startTick()
    refreshFrame()
    return true
end

local function prone(ped)
    refreshEmote()
    if not canChangeStance(ped) then return false end
    local dict = Kora.stream.loadAnimDict(config.proneAnimDict)
    if dict == false then return false end
    proneAnimationLoaded = true

    clearStockStance(ped)
    ResetPedMovementClipset(ped, 0.25)
    ResetPedStrafeClipset(ped)
    local coords = GetEntityCoords(ped)
    TaskPlayAnimAdvanced(ped, config.proneAnimDict, config.proneForwardAnim,
        coords.x, coords.y, coords.z, 0.0, 0.0, GetEntityHeading(ped),
        8.0, -8.0, -1, 2, 1.0, false, false)
    proneMotion = 'idle'
    proneStepEndsAt = 0
    stance = 'prone'
    startTick()
    refreshFrame()
    -- A movement key may already be held when prone starts.
    syncProne()
    return true
end

playProneIdle = function(ped, clip)
    local coords = GetEntityCoords(ped)
    TaskPlayAnimAdvanced(ped, config.proneAnimDict, clip,
        coords.x, coords.y, coords.z, 0.0, 0.0, GetEntityHeading(ped),
        8.0, -8.0, -1, 2, 1.0, false, false)
    proneMotion = 'idle'
    proneStepEndsAt = 0
end

playProneStep = function(ped, direction, now)
    local clip = direction == 'forward' and config.proneForwardAnim or config.proneBackwardAnim
    TaskPlayAnim(ped, config.proneAnimDict, clip, 8.0, -8.0, -1, 2, 0.0, false, false, false)
    proneMotion = direction
    proneStepEndsAt = now + proneStepDuration[direction]
end

local function inVehicle()
    -- Kora.cache.vehicle() is `false` on foot (not nil or 0), so test truthiness.
    local vehicle = Kora.cache.vehicle()
    return vehicle ~= nil and vehicle ~= false and vehicle ~= 0
end

local function clearStealth()
    if inVehicle() then return end
    local ped = PlayerPedId()
    if GetPedStealthMovement(ped) then clearStockStance(ped) end
end

-- 'event' mode: the crouch key is normally the same key as GTA's own duck
-- (INPUT_DUCK, LCONTROL), so its press is exactly when the stock stealth stance
-- can start. Undo it on the press and a couple of times shortly after (the game
-- may apply it a frame or two later) instead of disabling control 36 every frame.
local STOCK_DUCK_RECHECKS = { 0, 50, 150 }
local function suppressStockDuck()
    if stockDuckMode ~= 'event' then return end
    for i = 1, #STOCK_DUCK_RECHECKS do SetTimeout(STOCK_DUCK_RECHECKS[i], clearStealth) end
end

local function toggleCrouch()
    local ped = PlayerPedId()
    if stance == 'crouched' or stance == 'prone' then
        stand(ped)
    else
        crouch(ped)
    end
end

Kora.keybind.add({
    name = 'qbsmallresources_crouch',
    description = 'Toggle crouch / hold prone',
    defaultKey = config.keybind,
    onPressed = function()
        if keyHeld then return end
        keyHeld = true
        suppressStockDuck()
        refreshFrame()
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
        refreshFrame()
        if heldPressId == pressId then
            heldPressId = nil
            return
        end
        toggleCrouch()
    end,
})

-- Prone movement: rebindable press/release mappings instead of IsControlPressed
-- polling. Forward/backward drive the crawl animation directly; left/right only
-- set a flag the prone frame task reads.
for _, bind in ipairs({
    { dir = 'forward',  key = config.proneForwardKey  or 'W', label = 'Prone: crawl forward' },
    { dir = 'backward', key = config.proneBackwardKey or 'S', label = 'Prone: crawl backward' },
    { dir = 'left',     key = config.proneLeftKey     or 'A', label = 'Prone: turn left' },
    { dir = 'right',    key = config.proneRightKey    or 'D', label = 'Prone: turn right' },
}) do
    local dir = bind.dir
    local drivesAnimation = dir == 'forward' or dir == 'backward'

    Kora.keybind.add({
        name = 'qbsmallresources_prone_' .. dir,
        description = bind.label,
        defaultKey = bind.key,
        onPressed = function()
            moveKeys[dir] = true
            if drivesAnimation then syncProne() end
        end,
        onReleased = function()
            moveKeys[dir] = false
            if drivesAnimation then syncProne() end
        end,
    })
end

-- An emote takes over the ped: stand up the moment it starts instead of
-- noticing on the next poll. The flag also replaces a per-frame statebag read.
AddStateBagChangeHandler(EMOTE_KEY, nil, function(bagName, _, value)
    if bagName ~= ('player:%d'):format(GetPlayerServerId(PlayerId())) then return end
    emoteActive = value and true or false
    if emoteActive and stance ~= 'standing' then stand(PlayerPedId()) end
end)

if stockDuckMode == 'frame' then
    local setBlocking = Small.onFrame(function()
        DisableControlAction(0, 36, true)
    end)

    local function vehicleChanged()
        setBlocking(not inVehicle())
    end
    local function watchVehicle()
        Kora.cache.onChange('vehicle', vehicleChanged)
        vehicleChanged()
    end
    watchVehicle()
    AddEventHandler('onClientResourceStart', function(resource)
        if resource == 'kora_lib' then watchVehicle() end
    end)
end

if blockStock then
    -- Backstop for stealth that did not come from the crouch key (e.g. the crouch
    -- key was rebound away from LCONTROL). Tighter in 'event' mode since nothing
    -- blocks the control itself there.
    Small.onInterval(stockDuckMode == 'event' and 1500 or 2000, function()
        if stance ~= 'standing' then return end
        clearStealth()
    end)
end

Small.onSpawn(function()
    stance = 'standing'
    idleBlocked = false
    keyHeld = false
    heldPressId = nil
    stepToken = stepToken + 1
    padKeys.forward, padKeys.backward = false, false
    stopTick()
    releaseAssets()
    refreshFrame()
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    local ped = PlayerPedId()
    if DoesEntityExist(ped) then stand(ped) end
end)
