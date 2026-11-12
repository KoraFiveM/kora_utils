Config = {}

Config.idleCamera = {
    disable = true,
    interval = 10000,
}

Config.weaponWheel = {
    disable = true,
    blockAutoSwap = true,
}

Config.vehicleRewards = {
    disable = true,
}

Config.wantedLevel = {
    disable = true,
    -- Toggles: true = that AI service is switched off, false = stock GTA behaviour.
    disablePolice = true,    -- AI police (cars, helicopters, SWAT, roadblocks, boats, army, gangs, bikers)
    disableFire = true,      -- AI fire department
    disableAmbulance = true, -- AI ambulance / paramedics
    interval = 2000,
    hideHudStar = false,
}

Config.healthRegen = {
    multiplier = 0.0,
    limit = 0.0,
}

Config.crouch = {
    enabled = true,
    keybind = 'LCONTROL',
    holdDuration = 500,
    crouchClipset = 'move_ped_crouched',
    crouchStrafeClipset = 'move_ped_crouched_strafing',
    proneAnimDict = 'move_crawl',
    proneForwardAnim = 'onfront_fwd',
    proneBackwardAnim = 'onfront_bwd',
    proneTurnSpeed = 1.0,
    proneForwardKey = 'W',
    proneBackwardKey = 'S',
    proneLeftKey = 'A',
    proneRightKey = 'D',
    proneControllerSupport = true, -- read the stick in the prone frame task (sticks can't be key-mapped); false = keyboard mappings only
    reassertInterval = 100,
    blockIdleClips = true,
    -- How GTA's own duck/stealth stance (control 36, also LCONTROL) is stopped:
    --   'event' undo it when the crouch key is pressed, plus a 1500 ms check; no per-frame cost
    --   'frame' disable control 36 every frame on foot (the old behaviour; use if 'event' flickers)
    --   false   leave the stock duck alone
    blockStockDuck = 'event',
}

Config.blacklist = {
    weapons = {
        'WEAPON_RAILGUN',
        'WEAPON_RPG',
        'WEAPON_GRENADELAUNCHER',
        'WEAPON_GRENADELAUNCHER_SMOKE',
        'WEAPON_MINIGUN',
        'WEAPON_FIREWORK',
        'WEAPON_RAYMINIGUN',
        'WEAPON_STINGER',
    },
    serverWeaponSweepInterval = 250,
    notifyOnStrip = true,

    vehicles = {
        'rhino', 'lazer', 'hydra', 'savage', 'buzzard',
        'oppressor', 'oppressor2', 'scramjet', 'deluxo', 'insurgent',
        'blimp', 'blimp2', 'blimp3',
    },

    notifyOnVehicleBlock = true,

    peds = {
    },
}

Config.worldDepop = {
    disableRandomCops = true,
    disablePedDrops = true,
    calmNpcs = true,
    disableDriveby = false,
    reassertInterval = 10000,
}

Config.HarnessUses = 20
Config.seatbelt = {
    enabled = true,
    keybind = 'B',
    equipDuration = 5000,
    actionLifetime = 30000,
    crashCooldown = 1000,
    removeEmptyHarness = true,
    harness = {
        separateFromSeatbelt = true,
        command = 'raceharness',
        keybind = '',
        lockInventory = false,
    },
}

if Kora and Kora.config and Kora.config.adopt then Config = Kora.config.adopt(Config) end
