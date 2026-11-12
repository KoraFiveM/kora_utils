---
title: "How to use"
sidebar_position: 3
---


# How to use

There is nothing to call to "start" Kora Utils — every feature in config.lua that is enabled schedules itself when the resource loads. Most of the resource is tweak-and-forget: edit config.lua, restart the resource, and the behavior changes. A few modules (the legacy qb-smallresources exports, the seatbelt/harness item, and the timed-job helper) are a real API other resources can call.

## The shared tick coordinator (why this exists)

A "small resources" bundle is naturally a pile of tiny always-on tweaks. The naive shape — one `CreateThread`/`while true do ... Wait(0) end` per feature — means the client pays one coroutine resume per feature, every frame, mostly for one cheap native call. `client/core.lua` fixes that: every feature schedules through one of three primitives instead of spawning its own loop.

- `Small.onFrame(fn)` — one shared `Wait(0)` thread for the whole resource. Reserved for natives that must be reasserted every frame (`BlockWeaponWheelThisFrame`-style natives, disabling a control action). Returns `setActive(bool)` so a feature that is only conditionally relevant (seatbelt logic while on foot) can pause itself and cost nothing until resumed.
- `Small.onInterval(ms, fn)` — one thread per distinct interval, shared by every feature that asked for that cadence. Two features both wanting a 2000 ms tick share one thread and one `Wait(2000)`, not two. The default home for "reassert occasionally" work.
- `Small.onSpawn(fn)` — runs on first spawn and every respawn, for player-scoped natives the engine resets when the ped is recreated (`SetPlayerHealthRechargeMultiplier`, `SetWeaponsNoAutoswap`). Fires on the `playerSpawned` event, on the net event `QBCore:Client:OnPlayerLoaded`, and — as the reliable fallback for spawn flows that raise neither — on a watched change of `Kora.cache.ped()`.
- `Small.once(fn)` — runs `fn` once, now, in its own thread. For one-shot setup that yields and should not block the load of the next module file.

## Small.hash and Small.hashSet

Two small resource-local helpers used by more than one module (`client/util.lua`). Not part of `Kora.*` — general-purpose enough helpers belong in kora_lib, these are specific to this resource.

```lua title="client/util.lua"
-- Small.hash(value): string|integer -> integer
-- Normalises a weapon/model identifier to its joaat hash. A string name
-- ('WEAPON_PISTOL', 'police') is hashed; a number is returned unchanged.

-- Small.hashSet(list): (string|integer)[]? -> table<integer, true>
-- Builds a hash-keyed lookup set from a config list, for O(1) membership
-- tests instead of scanning the array every check. nil/empty input -> {}.
```

## Feature catalogue

Each module file checks its own `Config.<feature>` and returns immediately (registering nothing) when disabled. Toggle them in config.lua; no manifest or code change is needed.

- `idlecamera` — kills GTA's cinematic idle camera (`InvalidateIdleCam`/`InvalidateVehicleIdleCam` on an interval).
- `weaponwheel` — removes the radial weapon-select wheel (`SetPedConfigFlag(ped, 48, true)` on an interval) and, optionally, stops weapons auto-equipping on pickup (`SetWeaponsNoAutoswap`).
- `vehiclerewards` — suppresses GTA's native weapon grant for entering certain service vehicles (`DisablePlayerVehicleRewards`), since kora_inventory is the sole item authority.
- `wantedlevel` — forces the NPC wanted level to 0 (`SetMaxWantedLevel(0)`, once when the file loads) and, optionally, disables the 15 NPC dispatch services. It does not hide the HUD wanted stars, and `Config.wantedLevel.disable`, `interval` and `hideHudStar` are not read (see [Features](./features.md)).
- `healthregen` — zeroes (or retunes) GTA's passive health-regen multiplier/limit so damage sticks until something heals it. Registers nothing when both values equal the stock defaults (multiplier 1.0, limit 0.0). Not inherited from qb-/qbx_smallresources — there it lives in the medical resource; pick one owner if a medical resource also manages recharge.
- `crouch` — replaces GTA's action-mode "duck" with real crouched locomotion clipsets, with hold-to-prone. Keybind-driven only (see Commands); no exports.
- `blacklist` — strips disallowed weapons client-side the instant they become selected (subscribing to kora_lib's own selected-weapon cache instead of polling), and refuses disallowed vehicle/ped model spawns server-side via OneSync's `entityCreating` (a client-only spawn check would be trivially bypassed). The server also re-sweeps every connected player's held weapon on an interval, so a modified client cannot retain a stripped weapon by disabling its local check.
- `worlddepop` — thins ambient chaos: no random NPC police/sirens/garbage trucks, calms ambient gangs/cops/medics toward the player, optionally blocks drive-by shooting, and stops killed NPCs from dropping their weapon (closing a route to picking up blacklisted guns).
- `seatbelt` — a full seatbelt and race-harness lifecycle (see below); the one module with real exports and a server-owned inventory item.

## Seatbelt and race harness

The seatbelt itself is a purely local, cosmetic toggle (no item, no server round-trip) that disables bailing out (`INPUT_VEH_EXIT`) while buckled and arms the stock-style crash-ejection/damage check. The race harness is a real inventory item (`harness`) with server-owned durability and equip authority.

- Toggle the belt with the `toggleseatbelt` command (default key `B`, see Commands). `HasSeatbeltOn()` and `HasHarness()` are client exports other resources (and the HUD) can read.
- With `Config.seatbelt.harness.separateFromSeatbelt` (default `true`), the harness is independent of the belt: attaching/removing it never changes the belt, the belt key never touches it, and an attached harness alone blocks exiting. Set it `false` for the old coupled behavior.
- Attaching the harness needs a real `harness` item in inventory (lowest slot, found server-side via `getItemsByName`); removing it does not, so a harness whose last use was already consumed can always be taken off. Both paths run the same server-driven progress bar as using the item directly.
- The server is the only thing that can consume a durability use: a body-health loss on the player's own vehicle, sampled server-side, both decrements `info.uses` on the item (via `kora_core`'s item APIs) and republishes the equipped state to the client. Client-reported hp/item metadata is never trusted.
- The harness can also be worn via the usable item itself (`exports.kora_core:createUseable('harness', ...)`), independent of the `raceharness` command.

## Legacy controls and HUD compatibility

`client/compat.lua` and `client/hud.lua` reimplement stock qb-smallresources' presentation exports on top of the same frame coordinator. An untouched server that never calls these pays nothing: nothing is scheduled until a caller actually hides a HUD component, disables a control, or sets a density value.
