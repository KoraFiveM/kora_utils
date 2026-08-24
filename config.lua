-- qbsmallresources configuration.
--
-- One flat table, one section per feature, a trailing comment on every value --
-- matching qblib's config.lua style. Every feature is independently toggleable;
-- a feature turned off here registers NOTHING at runtime (no thread, no tick, no
-- event handler), so trimming this file to taste has a real performance payoff,
-- not just a cosmetic one. See each module's docs.md for the natives involved.

Config = {}

-- ===========================================================================
-- Idle camera -- kill GTA's cinematic "idle" camera that swings away from the
-- player after ~30s of no input. This is the "anti idle" most servers want:
-- the passive camera drift, not an AFK kick (that's a server policy, left to
-- txAdmin / your admin resource).
-- ===========================================================================
Config.idleCamera = {
    disable = true,   -- true = the idle camera never engages
    interval = 1000,  -- ms between InvalidateIdleCam calls; anything < 30000 prevents it, 1000 is cheap and safe
}

-- ===========================================================================
-- Weapon wheel -- remove the radial weapon-select wheel entirely. Weapons are
-- still switchable by script/inventory; only the built-in HUD wheel is blocked.
-- ===========================================================================
Config.weaponWheel = {
    disable = true,      -- true = the weapon wheel never opens
    blockAutoSwap = true, -- also stop the engine auto-equipping a newly picked-up weapon
}

-- ===========================================================================
-- Wanted level -- never let the player accrue a vanilla NPC-police wanted
-- level (server RP jobs handle the law, not GTA's star system). Also silences
-- the NPC dispatch services (no auto-spawned cops/helis/swat).
-- ===========================================================================
Config.wantedLevel = {
    disable = true,          -- true = wanted level is forced to 0 and capped at 0
    disableDispatch = true,  -- true = NPC dispatch services (cops, ambulance, fire, ...) are switched off
    interval = 2000,         -- ms between clears of any level that slipped through (SetMaxWantedLevel(0) alone covers most, this is the belt-and-braces sweep)
}

-- ===========================================================================
-- Health regen -- GTA slowly auto-heals the player back toward full. Zeroing
-- the multiplier makes damage stick until something (an item, a medic script)
-- heals it. multiplier = 1.0 restores stock behaviour.
-- ===========================================================================
Config.healthRegen = {
    multiplier = 0.0,  -- passive-regen rate multiplier; 0.0 = no passive healing at all
    limit = 0.0,       -- HP ceiling the passive regen restores up to; 0.0 pairs with multiplier 0.0
}

-- ===========================================================================
-- Blacklist / ignore -- things the player is simply never allowed to have or
-- do. Weapons are stripped client-side; vehicle spawns are refused
-- server-side (a client-only check is trivially bypassed).
-- ===========================================================================
Config.blacklist = {
    -- Weapons a player may never hold. If one becomes equipped anyway (menu,
    -- cheat, a buggy give), it's removed and -- if notify is set -- the player
    -- is told. Names (readable) or raw hashes both work.
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
    weaponSweepInterval = 500,  -- ms between checks of the currently-held weapon
    serverWeaponSweepInterval = 250,
    notifyOnStrip = true,       -- QB.notify the player when a blacklisted weapon is taken away

    -- Vehicle models a player may not spawn. Enforced SERVER-side (via OneSync's
    -- entityCreating) so a client can't just skip the check. Names or hashes.
    vehicles = {
        'rhino', 'lazer', 'hydra', 'savage', 'buzzard',
        'oppressor', 'oppressor2', 'scramjet', 'deluxo', 'insurgent',
    },

    -- Ped models a player may not spawn (cop/military models used for griefing).
    -- Same server-side entityCreating enforcement as vehicles.
    peds = {
        -- 's_m_y_cop_01', 's_m_y_sheriff_01', 's_m_y_ranger_01',
    },
}

-- ===========================================================================
-- World de-population -- thin out GTA's ambient chaos: no random NPC police,
-- no distant cop sirens, garbage trucks, or far-drawn traffic, and dead NPCs
-- stop dropping their weapons on the ground (a common source of players
-- picking up blacklisted guns). Purely cosmetic/ambient; toggle freely.
-- ===========================================================================
Config.worldDepop = {
    disableRandomCops = true,  -- no ambient NPC police spawns / distant sirens
    disablePedDrops = true,    -- NPCs killed nearby don't drop their weapon on the ground
    calmNpcs = true,           -- ambient gangs/cops/medics won't turn hostile to players on sight
    disableDriveby = false,    -- true = players can't fire from inside a vehicle
    reassertInterval = 10000,  -- ms; some population natives get reset by the engine, so reassert periodically
}
