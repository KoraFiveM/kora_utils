---
title: Features
sidebar_position: 6
---

# Features

Each module is toggled in `config.lua`; see [Configuration](./configuration.md).

| Module | Realm | What it does |
| --- | --- | --- |
| `idlecamera` | client | Calls `InvalidateIdleCam` and `InvalidateVehicleIdleCam` every `Config.idleCamera.interval` ms. |
| `weaponwheel` | client | Sets ped config flag 48 on the player ped (on load, on spawn and every 10 s) to stop the weapon wheel; optionally `SetWeaponsNoAutoswap(true)` on spawn. |
| `vehiclerewards` | client | Calls `DisablePlayerVehicleRewards` on spawn so entering service vehicles gives no weapon. |
| `wantedlevel` | client | Sets the max wanted level to 0 and switches off AI dispatch services. See the note below. |
| `healthregen` | client | Applies `SetPlayerHealthRechargeMultiplier` and `SetPlayerHealthRechargeLimit` on every spawn. |
| `crouch` | client | Tap the crouch key to toggle crouch, hold it to go prone. |
| `blacklist` | client and server | Strips blacklisted weapons; refuses blacklisted vehicle and ped spawns. |
| `worlddepop` | client | Disables random cops, calms ambient groups, stops ped weapon drops, optionally disables drive-by. |
| `seatbelt` | client and server | Seatbelt, race harness with durability, crash ejection. |
| compat exports | client and server | `qb-smallresources` exports. See [API reference](./api/index.md). |

## wantedlevel

The module file does not read `Config.wantedLevel.disable`, `interval` or `hideHudStar`. When the file loads it runs once: `SetMaxWantedLevel(0)` and, for each of `disablePolice`, `disableFire`, `disableAmbulance` that is not `false`, `EnableDispatchService(id, false)`. It does not re-run on respawn and has no interval. Dispatch groups: police `1, 2, 4, 6-15`, fire `3`, ambulance `5`.

## healthregen

The module registers nothing only when `multiplier` is exactly `1.0` and `limit` is exactly `0.0`. With the default `0.0` and `0.0` the zeroed regen applies on spawn. If a medical/ambulance resource also manages the recharge multiplier, choose one owner.

## crouch

- Default key `LCONTROL` (`Config.crouch.keybind`), registered with `Kora.keybind.add` as `kora_utils_crouch`, so players can rebind it.
- Tap toggles crouch; holding for `holdDuration` ms goes prone. Tapping while crouched or prone stands up.
- Prone movement uses four rebindable key mappings (`kora_utils_prone_forward`, `_backward`, `_left`, `_right`), default W, S, A, D. Sprint and jump are disabled while prone. With `proneControllerSupport` the controls for movement (32 to 35) are also read while prone, since sticks cannot be key-mapped.
- Stance changes are refused while dead, ragdolling, falling, jumping, climbing, swimming, in a vehicle, or while an emote is active. The emote flag is the player state bag `kora_emotemenu:active`; starting an emote stands the player up.
- `blockStockDuck` controls GTA's own duck stance: `'event'` (default), `'frame'` (disable control 36 every frame on foot) or `false`.
- On spawn the stance resets. On resource stop the ped stands up.

## blacklist

- Client: watches `Kora.cache.onChange('weapon')`, removes a blacklisted weapon with `RemoveWeaponFromPed` and notifies when `notifyOnStrip` is true. Registers nothing for weapons if the list is empty.
- Server: `entityCreating` cancels creation when the model hash is in `Config.blacklist.vehicles` or `Config.blacklist.peds` (the check applies to any entity model, not only vehicles). If `notifyOnVehicleBlock` is true and the entity is a vehicle with a real owner (not an ambient population type 1 to 5), the owner gets the local event `kora_utils:blacklist:vehicleBlocked`, rate limited to once per second per player.
- Server weapon sweep: every `serverWeaponSweepInterval` ms (default 250) the server removes a blacklisted selected weapon from every player ped.
- Names and raw hashes are accepted; names are `joaat` hashed once at load.

## worlddepop

Applied on spawn and, when any of `disableRandomCops`, `calmNpcs`, `disableDriveby` is on, every `reassertInterval` ms:

- `disableRandomCops`: `SetCreateRandomCops` (three variants), `DistantCopCarSirens(false)`, `SetGarbageTrucks(false)`, audio flag `PoliceScannerDisabled`.
- `calmNpcs`: relationship 1 (companion) between a fixed list of ambient gang, `FIREMAN`, `MEDIC`, `COP` and `PRISONER` groups and `PLAYER`.
- `disableDriveby`: `SetPlayerCanDoDriveBy(false)`.
- `disablePedDrops`: a sweep of `GetGamePool("CPed")` every `reassertInterval` ms calling `SetPedDropsWeaponsWhenDead(ped, false)` on peds not yet flagged, yielding a frame every 32 peds. `reassertInterval` must be a positive number or the module asserts.

## seatbelt

Enabled by `Config.seatbelt.enabled`. See [Commands](./commands.md), [Events](./events.md) and [Items](./items.md).

- Only applies to vehicles that are not class 8 (motorcycles), 13 (cycles) or 14 (boats). Server side, bikes and boats are also refused for harness actions.
- B (`toggleseatbelt`) toggles the belt. While the belt or harness is on, exit control 75 is disabled.
- Crash ejection: the client samples speed and body health on the shared frame task. At high deceleration with a seatbelt or harness it uses higher thresholds. Without a belt or harness a crash can eject the player (ragdoll, forward velocity, health loss). With a harness, a crash sends `seatbelt:DoHarnessDamage` so the server can spend a harness use. A heavy crash (body health below 350) also stops the engine.
- Harness: attached through the `harness` usable item or the race harness command. Equipping takes `equipDuration` ms with a progress bar and consumes one use through the server only after completion.
- `separateFromSeatbelt` (default `true`): the harness is independent of the belt. When `false`, attaching the harness also buckles the belt and removing it unbuckles it.
- Seatbelt state is exposed as `LocalPlayer.state.seatbelt` and `LocalPlayer.state.harness` (not replicated), and through local events for a HUD.
- State resets on vehicle change, death, logout (`QBCore:Client:OnPlayerUnload`) and resource stop.

## Out of scope

Consumables (`AddFood` and similar) are not in this resource. See [API reference](./api/index.md).
