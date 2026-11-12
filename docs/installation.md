---
title: Dependencies and installation
sidebar_position: 8
---

# Dependencies and installation

## Dependencies

Declared in `fxmanifest.lua`: `kora_lib`, `kora_core`, `kora_inventory`.

| Resource | Used for |
| --- | --- |
| `kora_lib` | `@kora_lib/init.lua` (`Kora.*`): cache (`ped`, `weapon`, `vehicle`, `playerId`), notify, keybind, callback, progressbar, stream, compat exports. |
| `kora_core` | Seatbelt server: `createUseable`, `getItemBySlot`, `getItemsByName`, `removeItem`. |
| `kora_inventory` | Provides the `qb-inventory` export `SetItemData` used to save harness durability. |

Optional or external, not declared: `kora_emotemenu` (crouch reads its state bag and calls `exports.kora_emotemenu:setWalk` if present), and a sound resource handling `InteractSound_SV:PlayWithinDistance`.

## Installation

1. Put `kora_utils` in your resources folder.
2. In `server.cfg`, after its dependencies:

```cfg
ensure kora_lib
ensure kora_core
ensure kora_inventory
ensure kora_utils
```

3. Add a `harness` item to your shared items if you use the harness.
4. Edit `config.lua`.

OneSync is required for the server-side vehicle and ped blacklist (`entityCreating`) and for server routing buckets.

## Compatibility

The resource provides `qb-smallresources`, so remove the original resource. `healthregen` is not part of the original bundle; avoid a second owner (for example a medical resource) of the recharge multiplier. Behavioural reference for the seatbelt: `qbcore-fivem/qb-smallresources`.

## Tests

`test/run.sh` runs `test/smoke/*.lua` under plain Lua. Manual scenarios are in `tests/checklist-core-and-libraries.feature` for `kora_qa`.
