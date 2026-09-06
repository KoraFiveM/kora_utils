# qbsmallresources

A bundle of small, always-on world and player tweaks built on `qblib` — the kind
of passive behaviour that qb-smallresources / qbx_smallresources ship, but
rebuilt around a single shared tick coordinator so ten features cost one frame
thread instead of ten.

Every feature is independently toggleable in `config.lua`, and a feature turned
off registers **nothing** at runtime — no thread, no tick, no event handler. So
trimming the config has a real performance payoff, not just a cosmetic one.

## Features

| Module | Realm | What it does | Key natives |
|---|---|---|---|
| `idlecamera` | client | Kills GTA's cinematic idle camera (the pan-away after ~30s of no input) | `InvalidateIdleCam`, `InvalidateVehicleIdleCam` |
| `weaponwheel` | client | Removes the radial weapon-select wheel; optionally stops weapon auto-swap | `BlockWeaponWheelThisFrame`, `DisableControlAction(0,37)`, `SetWeaponsNoAutoswap` |
| `wantedlevel` | client | Forces the NPC-police wanted level to 0 and (optionally) silences NPC dispatch | `SetMaxWantedLevel(0)`, `EnableDispatchService`, `SetPoliceIgnorePlayer` |
| `healthregen` | client | Zeroes GTA's passive health regeneration so damage sticks | `SetPlayerHealthRechargeMultiplier`, `SetPlayerHealthRechargeLimit` |
| `crouch` | client | Replaces GTA's combat/action stance with real crouching; tap to toggle, hold for prone | `SetPedMovementClipset`, `SetPedStrafeClipset`, `TaskPlayAnim` |
| `blacklist` | client + server | Strips disallowed weapons client-side; refuses disallowed vehicle/ped spawns server-side | `GetSelectedPedWeapon`/`RemoveWeaponFromPed`, `entityCreating`+`CancelEvent` |
| `worlddepop` | client | Thins ambient chaos: no random cops, calmer NPCs, dead peds don't drop weapons | `SetCreateRandomCops`, `SetRelationshipBetweenGroups`, `SetPedDropsWeaponsWhenDead` |

### Note on `healthregen`
This module is a value-add, **not** inherited from either original — in both
qb-smallresources and qbx_smallresources, health-regen tuning lives in the
ambulance/medical resource. If a medical resource on your server also manages
the recharge multiplier, pick one owner so the two don't fight.

## Config

One flat `Config` table, one section per feature, each value commented. See
`config.lua` for the authoritative list. The headline knobs:

```lua
Config.idleCamera.disable   = true      -- kill the idle camera
Config.weaponWheel.disable  = true      -- remove the weapon wheel
Config.wantedLevel.disable  = true      -- suppress the NPC wanted level
Config.healthRegen.multiplier = 0.0     -- 0.0 = no passive healing; 1.0 = stock
Config.crouch.keybind         = 'LCONTROL' -- tap = crouch toggle; hold = prone
Config.blacklist.weapons    = { 'WEAPON_RAILGUN', ... }   -- stripped client-side
Config.blacklist.vehicles   = { 'rhino', 'lazer', ... }   -- refused server-side
Config.worldDepop.disableRandomCops = true
```

Weapon/vehicle/ped entries accept readable names (`'WEAPON_RPG'`, `'rhino'`) or
raw hashes interchangeably — names are joaat-hashed once at load, so hot
comparisons stay integer-vs-integer.

## Setup

`qblib` must be started first (this resource pulls in `@qblib/init.lua` for
`QB.notify`). In `server.cfg`:

```
ensure qblib
ensure qbsmallresources
```

The server-side vehicle/ped blacklist relies on OneSync (`entityCreating`),
which is assumed on — the same assumption qbcore makes.

## Architecture

All client features schedule through `client/core.lua`'s coordinator rather than
each spawning its own loop:

- `Small.onFrame(fn)` — one shared `Wait(0)` thread drains every per-frame task.
  Reserved for natives that genuinely must be reasserted each frame
  (`BlockWeaponWheelThisFrame`, disabling a control).
- `Small.onInterval(ms, fn)` — one thread per **distinct** interval, shared by
  every feature that asked for that cadence. The default home for
  reassert-occasionally work (clearing the wanted level, sweeping for
  blacklisted weapons).
- `Small.onSpawn(fn)` — runs on first spawn and every respawn, for player-scoped
  natives the engine resets when the ped is recreated (`SetMaxWantedLevel`,
  `SetPlayerHealthRechargeMultiplier`, `SetPoliceIgnorePlayer`).

See `AGENTS.md` for why this shape was chosen and how to add a feature.
