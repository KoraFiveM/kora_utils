---
title: Events
sidebar_position: 8
---

# Events

## Net events handled by the server

| Event | Sent by | Notes |
| --- | --- | --- |
| `kora_utils:server:leaveVehicle` | client | Clears harness state for the source. Sent whenever the client resets (vehicle change, death, resource stop). |
| `kora_utils:server:removeHarness` | client | Clears an empty harness (zero uses). Needs `removeEmptyHarness`. |
| `kora_utils:server:cancelHarness` | client | Cancels the pending action when the token matches. |
| `equip:harness` | client | Legacy. Completes a pending action; the item argument is only used to compare the slot. Needs a pending server-issued action and the elapsed time. |
| `seatbelt:DoHarnessDamage` | client | Legacy. Arguments are ignored. The server checks the harness is equipped, the vehicle matches, body health dropped, and the crash cooldown elapsed, then spends one use. |

## Net events handled by the client

| Event | Sent by | Notes |
| --- | --- | --- |
| `kora_utils:client:harnessState` | server only (source must be 65535) | `(enabled, uses)`. Publishes harness state. |
| `seatbelt:client:UseHarness` | server | `(item, token)`. Starts the equip progress bar. |
| `kora_utils:blacklist:vehicleBlocked` | server | Shows the "Vehicle Blacklist" notification if `notifyOnVehicleBlock` is true. |

## Callbacks (Kora.callback)

| Name | Direction | Description |
| --- | --- | --- |
| `kora_utils:server:finishHarness` | client to server | `(slotTable, token)`. Completes equip or removal after the progress bar. Rate limit 4 per 10 s. |
| `kora_utils:server:toggleHarness` | client to server | Starts attach or remove. Returns `busy`, `novehicle`, `removed`, `removing`, `noitem` or `attaching`. Registered only if the harness command is set. Rate limit 4 per 10 s. |

## Local events triggered for other resources (HUD)

| Event | Arguments |
| --- | --- |
| `seatbelt:client:ToggleSeatbelt` | `(seatbeltOn)` |
| `seatbelt:client:ToggleHarness` | `(harnessOn, uses)` |
| `hud:client:UpdateHarness` | `(uses)` |

## Local events handled

- `kora_utils:client:toggleSeatbelt` (client) - same as pressing the seatbelt key.
- `playerSpawned`, `QBCore:Client:OnPlayerLoaded` - run spawn handlers. A ped handle change also triggers them.
- `QBCore:Client:OnPlayerUnload` - resets seatbelt state.
- `QBCore:Server:OnPlayerUnload` - clears harness state on the server.

## External events

The belt toggle triggers the server event `InteractSound_SV:PlayWithinDistance` (an external sound resource, not declared in the manifest).

## State bags

- Sets `LocalPlayer.state.seatbelt` and `LocalPlayer.state.harness` (not replicated).
- Optionally sets `LocalPlayer.state.inv_busy` (replicated) during the progress bar when `lockInventory` is true.
- Reads the player state bag `kora_emotemenu:active` (crouch).
