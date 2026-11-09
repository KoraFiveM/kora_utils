---
layout: default
title: kora_utils
---

A bundle of small, always-on world and player tweaks built on `kora_lib` — the
kind of passive behaviour that qb-smallresources / qbx_smallresources ship,
rebuilt around a single shared tick coordinator so ten features cost one
frame thread instead of ten. It bundles six mini-features:

- **idlecamera** — kills GTA's cinematic idle camera (the pan-away after ~30s of no input)
- **weaponwheel** — removes the radial weapon-select wheel and optionally stops weapon auto-swap
- **wantedlevel** — forces the NPC-police wanted level to 0 and silences NPC dispatch
- **healthregen** — zeroes GTA's passive health regeneration so damage sticks
- **blacklist** — strips disallowed weapons client-side; refuses disallowed vehicle/ped spawns server-side
- **worlddepop** — thins ambient chaos: no random cops, calmer NPCs, dead peds don't drop weapons

Every feature is independently toggleable in `config.lua`, and a feature
turned off registers **nothing** at runtime — no thread, no tick, no event
handler — so trimming the config has a real performance payoff, not just a
cosmetic one.

## Requirements

- [kora_lib](https://qbcore2.github.io/kora_lib/) — this resource loads `@kora_lib/init.lua` for `Kora.cache.ped()` and `Kora.notify`

## Installation

`server.cfg`, in this order:
```
ensure kora_lib
ensure kora_utils
```
The server-side vehicle/ped blacklist relies on OneSync (`entityCreating`),
which is assumed on — the same assumption kora_core makes.

## Usage examples

This resource ships no exports, commands, or client/server events of its
own — every mini-feature is switched on and tuned entirely through
`config.lua`. "Using" kora_utils means editing that file. A few
concrete slices of it:

### Kill the idle camera and the weapon wheel
```lua
-- config.lua
Config.idleCamera = {
    disable = true,   -- true = the idle camera never engages
    interval = 10000, -- ms between InvalidateIdleCam calls
}

Config.weaponWheel = {
    disable = true,       -- true = the weapon wheel never opens
    blockAutoSwap = true, -- also stop the engine auto-equipping a newly picked-up weapon
}
```

### Suppress the vanilla wanted system in favour of your own law RP
```lua
-- config.lua
Config.wantedLevel = {
    disable = true,          -- wanted level forced to 0 and capped at 0
    disablePolice = true,    -- switch off AI police dispatch (false = stock)
    disableFire = true,      -- switch off AI fire department dispatch
    disableAmbulance = true, -- switch off AI ambulance dispatch
    interval = 2000,         -- ms between belt-and-braces clears of any level that slipped through
    hideHudStar = false,     -- true = hide the HUD wanted-star component every frame (off: stars never show at max level 0)
}
```

### Make damage stick (no passive health regen)
```lua
-- config.lua
Config.healthRegen = {
    multiplier = 0.0,  -- 0.0 = no passive healing at all; 1.0 = stock GTA behaviour
    limit = 0.0,        -- HP ceiling regen restores up to; 0.0 pairs with multiplier 0.0
}
```
If a medical/ambulance resource on your server also drives
`SetPlayerHealthRechargeMultiplier`, pick one owner — leave this section at
`multiplier = 1.0, limit = 0.0` to fully defer to it.

### Blacklist weapons and vehicles
```lua
-- config.lua
Config.blacklist = {
    weapons = { 'WEAPON_RAILGUN', 'WEAPON_RPG', 'WEAPON_MINIGUN' }, -- stripped when kora_lib reports it selected
    serverWeaponSweepInterval = 250,
    notifyOnStrip = true,  -- Kora.notify the player when a blacklisted weapon is taken away

    vehicles = { 'rhino', 'lazer', 'hydra', 'oppressor2' },  -- refused server-side via entityCreating
    peds = {},
}
```
Entries accept readable names (`'WEAPON_RPG'`, `'rhino'`) or raw hashes
interchangeably — names are joaat-hashed once at load.

### Thin out ambient world chaos
```lua
-- config.lua
Config.worldDepop = {
    disableRandomCops = true,  -- no ambient NPC police spawns / distant sirens
    disablePedDrops = true,    -- killed NPCs don't drop their weapon on the ground
    calmNpcs = true,           -- ambient gangs/cops/medics won't turn hostile to players on sight
    disableDriveby = false,    -- true = players can't fire from inside a vehicle
    reassertInterval = 10000,  -- ms between reasserts of the natives the engine resets
}
```

### Add your own passive tweak through the same tick coordinator
The bundled modules are a template — `client/core.lua`'s `Small.*` API is how
any new `modules/<feature>/client.lua` file plugs into the one shared thread
instead of spawning its own:
```lua
-- modules/mytweak/client.lua
if not Config.myTweak.disable then return end

-- reassert-occasionally work shares one thread per distinct interval
Small.onInterval(Config.myTweak.interval, function()
    SetPedCanRagdoll(PlayerPedId(), false)
end)

-- player-scoped natives the engine resets on respawn
Small.onSpawn(function()
    SetPlayerCanDoDriveBy(PlayerId(), true)
end)
```
Remember to list the new file explicitly in `fxmanifest.lua` after
`client/core.lua` and `client/util.lua` — module load order is never globbed.

## API reference

kora_utils has no `exports`, no `RegisterCommand`, and no
`RegisterNetEvent` surface — it's entirely config-driven. What follows is the
mechanism and native calls behind each feature, and the internal tick
coordinator that ties them together.

### `idlecamera` (client)
`Config.idleCamera` — `disable`, `interval`. Natives: `InvalidateIdleCam`,
`InvalidateVehicleIdleCam`, reasserted on `Config.idleCamera.interval` via
`Small.onInterval`.

### `weaponwheel` (client)
`Config.weaponWheel` — `disable`, `blockAutoSwap`. Natives:
`BlockWeaponWheelThisFrame`, `DisableControlAction(0, 37, true)` (per-frame,
via `Small.onFrame`); `SetWeaponsNoAutoswap(true)` (per-spawn, via
`Small.onSpawn`, when `blockAutoSwap` is set).

### `wantedlevel` (client)
`Config.wantedLevel` — `disable`, `disablePolice`, `disableFire`, `disableAmbulance`, `interval`, `hideHudStar`. Natives:
`SetMaxWantedLevel(0)` on spawn; `HideHudComponentThisFrame(1)` every frame (when `hideHudStar`);
`SetMaxWantedLevel(0)`, `SetPlayerWantedLevel`/`SetPlayerWantedLevelNow`/`ClearPlayerWantedLevel`
clear (only when the level is above 0), and `EnableDispatchService(1..15, false)` (when
the dispatch toggles) on `Config.wantedLevel.interval`.

### `healthregen` (client)
`Config.healthRegen` — `multiplier`, `limit`. Natives:
`SetPlayerHealthRechargeMultiplier`, `SetPlayerHealthRechargeLimit`, applied
on every spawn via `Small.onSpawn` (player-scoped, reset by the engine on
respawn). Registers nothing when left at stock (`multiplier = 1.0, limit =
0.0`).

### `blacklist` (client + server)
`Config.blacklist` — `weapons`, `serverWeaponSweepInterval`,
`notifyOnStrip`, `vehicles`, `peds`.
- Client: subscribes to `Kora.cache.onChange('weapon')` and calls
  `RemoveWeaponFromPed` on a match, notifying via `Kora.notify.send` when
  `notifyOnStrip` is true. This reuses kora_lib's shared weapon cache instead of
  running another client sweep.
- Server: `entityCreating` + `CancelEvent()` refuses blacklisted
  vehicle/ped models outright (requires OneSync); a second server-side
  sweep on `serverWeaponSweepInterval` re-checks every connected player's
  held weapon so a modified client can't bypass the client sweep.

### `worlddepop` (client)
`Config.worldDepop` — `disableRandomCops`, `disablePedDrops`, `calmNpcs`,
`disableDriveby`, `reassertInterval`. Natives: `SetCreateRandomCops` (+
`...NotOnScenarios`/`...OnScenarios`), `DistantCopCarSirens`,
`SetGarbageTrucks`, `SetAudioFlag('PoliceScannerDisabled', true)` (when
`disableRandomCops`); `SetRelationshipBetweenGroups` toward `PLAYER_GROUP`
for a fixed list of ambient gang/service groups (when `calmNpcs`);
`SetPlayerCanDoDriveBy(PlayerId(), false)` (when `disableDriveby`); a
`GetGamePool('CPed')` sweep calling `SetPedDropsWeaponsWhenDead(ped, false)`
(when `disablePedDrops`, spread 32 peds per frame rather than one burst).
Applied once on spawn and reasserted on `reassertInterval`.

### Tick coordinator (`client/core.lua`)
The internal scheduling API every module above is built on:
```lua
Small.onFrame(fn)      -- fn runs every frame (Wait(0)); one shared thread for the whole resource; returns setActive(bool) to pause/resume
Small.onInterval(ms, fn) -- fn runs every ms; one thread per DISTINCT interval, shared across features
Small.onSpawn(fn)      -- fn runs on first spawn and every respawn (playerSpawned / QBCore:Client:OnPlayerLoaded / ped-handle watch)
Small.once(fn)         -- fn runs once, now, in its own thread (for yielding one-shot setup)
```
`Small.hash(value)` and `Small.hashSet(list)` (`client/util.lua`) normalise
weapon/model names or hashes into joaat-hashed lookup tables, used by
`blacklist`.

## Config highlights (`config.lua`)

One flat `Config` table, one section per feature — see `config.lua` for the
authoritative, fully-commented list. Weapon/vehicle/ped entries accept
readable names (`'WEAPON_RPG'`, `'rhino'`) or raw hashes interchangeably;
names are joaat-hashed once at load so hot comparisons stay
integer-vs-integer.

## Related resources

Part of the [qbcore2](https://github.com/qbcore2) resource set:

- [kora_lib](https://qbcore2.github.io/kora_lib/) — shared helper library
- [qbsql](https://qbcore2.github.io/kora_sql/) — database driver
- [qbcore](https://qbcore2.github.io/kora_core/) — framework core
- [qbinventory](https://qbcore2.github.io/kora_inventory/) — headless inventory
- [qbtarget](https://qbcore2.github.io/kora_target/) — targeting/interaction
- [full resource list ↗](https://github.com/orgs/qbcore2/repositories)
