# kora_utils

A bundle of small, always-on world and player tweaks built on `kora_lib` — the kind
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
| `vehiclerewards` | client | Stops GTA awarding a weapon for entering service vehicles, including police cars | `DisablePlayerVehicleRewards` |
| `wantedlevel` | client | Forces the NPC-police wanted level to 0 and (optionally) silences NPC dispatch | `SetMaxWantedLevel(0)`, `EnableDispatchService`, `SetPoliceIgnorePlayer` |
| `healthregen` | client | Zeroes GTA's passive health regeneration so damage sticks | `SetPlayerHealthRechargeMultiplier`, `SetPlayerHealthRechargeLimit` |
| `crouch` | client | Replaces GTA's combat/action stance with real crouching; tap to toggle, hold for prone | `SetPedMovementClipset`, `SetPedStrafeClipset`, `TaskPlayAnim` |
| `blacklist` | client + server | Strips disallowed weapons client-side; refuses disallowed vehicle/ped spawns server-side | `GetSelectedPedWeapon`/`RemoveWeaponFromPed`, `entityCreating`+`CancelEvent` |
| `worlddepop` | client | Thins ambient chaos: no random cops, calmer NPCs, dead peds don't drop weapons | `SetCreateRandomCops`, `SetRelationshipBetweenGroups`, `SetPedDropsWeaponsWhenDead` |

### QBCore compatibility exports

Provided under `qb-smallresources` (and `qbsmallresources`), so stock callers run unmodified:

- Client: `addDisableControls`, `removeDisableControls`, `getDisableControls`, and `addDisableHudComponents`,
  `removeDisableHudComponents`, `getDisableHudComponents`, `setDisplayAmmo`, `getDisplayAmmo`, `DecorSet`
  (density types `parked`, `vehicle`, `multiplier`, `peds`, `scenario`, values 0-1), `getHandsup`.
  They share the one frame coordinator and schedule nothing until a caller uses them. Unlike stock there
  is no default hidden-component list and no default density, so an untouched server changes nothing.
  `getHandsup` reports whether the ped is playing the hands-up animation (stock tracked its own `/hu` command).
- Server: `CreateTimedJob(hour, min, cb)`, `ForceRunTimedJob(id)`, `StopTimedJob(id)`. One loop, started on the
  first job and aligned to the minute; ids are never reused, callback errors are caught, and a stopped
  resource's jobs are dropped. There is no network event, only server resources can use them.
- `AddFood`, `AddDrink`, `AddAlcohol` and `AddCustom` live in `kora_consumables`.

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
Config.vehicleRewards.disable = true    -- stop GTA police-car weapon rewards
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

`kora_lib` must be started first (this resource pulls in `@kora_lib/init.lua` for
`Kora.notify`). In `server.cfg`:

```
ensure kora_lib
ensure kora_utils
```

The server-side vehicle/ped blacklist relies on OneSync (`entityCreating`),
which is assumed on — the same assumption kora_core makes.

## Architecture

All client features schedule through `client/core.lua`'s coordinator rather than
each spawning its own loop:

- `Small.onFrame(fn)` — one shared `Wait(0)` thread drains every per-frame task.
  Reserved for natives that genuinely must be reasserted each frame
  (`BlockWeaponWheelThisFrame`, disabling a control).
  Returns `setActive(bool)` so a conditional task (seatbelt on foot) can pause
  itself; with no active task the thread idles at a 100 ms poll.
- `Small.onInterval(ms, fn)` — one thread per **distinct** interval, shared by
  every feature that asked for that cadence. The default home for
  reassert-occasionally work (clearing the wanted level, sweeping for
  blacklisted weapons).
- `Small.onSpawn(fn)` — runs on first spawn and every respawn, for player-scoped
  natives the engine resets when the ped is recreated (`SetMaxWantedLevel`,
  `SetPlayerHealthRechargeMultiplier`, `SetPoliceIgnorePlayer`).

See `AGENTS.md` for why this shape was chosen and how to add a feature.

## Legacy controls compatibility

`qb-smallresources:addDisableControls`, `removeDisableControls` and `getDisableControls` use the existing frame coordinator to apply input group 2 suppression. Number and dense-array arguments are accepted; removal removes one matching entry for each requested control, as upstream. Stopping the caller releases its entries. These APIs return no success placeholder. Harness and seatbelt gameplay now live in `modules/seatbelt`; see the lifecycle contract below.

## Seatbelts and harnesses

`Config.seatbelt.enabled` enables the real vehicle lifecycle and `toggleseatbelt` (B). `HasHarness` and `HasSeatbeltOn` are native and `qb-smallresources` client exports. Vehicle exit, death, logout and resource stop clear state and exit-control suppression. The HUD consumes `seatbelt:client:ToggleSeatbelt`; its former cosmetic B-key state is removed.

The server registers the existing `harness` usable item. It validates the actual slot, supported vehicle and routing bucket, issues a short-lived action, enforces the five-second equip duration and consumes a use through inventory authority before publishing equipped state. Cancellation never consumes a use. Pending actions cannot be replayed or substituted. Legacy `equip:harness(item)` and `seatbelt:DoHarnessDamage(hp, item)` are supported, but hp/item metadata from clients are never trusted; only the server's equipped item can lose durability after a fresh server-observed body-health loss. The last equipped use consumes its item and provides one final protection. Errors, dependency restarts and disconnects revoke pending authority.

With `Config.seatbelt.harness.separateFromSeatbelt` (default true) the harness is independent of the belt: attaching/removing it never changes the belt, B never touches the harness, and an attached harness alone blocks exiting. `Config.seatbelt.harness.command` (`raceharness`) plus a "Toggle Race Harness" key mapping (default key `Config.seatbelt.harness.keybind`, unbound) attach or remove it while seated through the same server action and progress bar: attaching needs a valid owned harness item (lowest slot), removing needs none, so a harness whose last use was consumed can always be taken off. The HUD gets the attached flag from the local `seatbelt:client:ToggleHarness(attached, uses)` event and `LocalPlayer.state.harness` (not replicated). The harness bar no longer writes `inv_busy` (kora_inventory owns it and already blocks use during any progress bar) unless `Config.seatbelt.harness.lockInventory` is true.

Crash ejection follows the pinned stock speed-drop/body-damage probability thresholds. Local movement physics and suppression run through the existing frame coordinator, with no vehicle natives while on foot. The sampler preserves upstream's retained 25-frame speed peak and delayed body-damage delta for multi-frame deceleration. Client collision physics, input remapping, audio and two-player item transfers still need connected FXServer validation.

Behavioral reference: qbcore-fivem/qb-smallresources at e69a95786ef29e53d962e4e0ec57eef36e195561, client/seatbelt.lua and server/main.lua. Native server API availability checked against https://runtime.fivem.net/doc/natives_cfx.json.
