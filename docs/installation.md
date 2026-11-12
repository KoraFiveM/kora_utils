---
title: "Installation"
sidebar_position: 2
---


# Installation

Kora Utils is a bundle of small, always-on world and player tweaks built on kora_lib — the kind of passive behavior qb-smallresources/qbx_smallresources ship, rebuilt around one shared tick coordinator so ten features cost one frame thread instead of ten. Every feature is independently toggleable in config.lua, and a feature turned off registers nothing at runtime (no thread, no tick, no event handler), so trimming the config has a real performance payoff.

## Install Kora Utils

1. **Add the folder** — Place `kora_utils` in your resources directory (on the Kora recipe it is `resources/[kora]/kora_utils`).

2. **Start it after kora_lib** — Kora Utils declares `dependency 'kora_lib'`, `dependency 'kora_core'` and `dependency 'kora_inventory'` (it loads `@kora_lib/init.lua` for `Kora.notify` and other proxy calls, and the inventory/core dependencies back the seatbelt harness item and its server-side checks). Start it after all three:

   ```bash title="server.cfg"
   ensure kora_lib
   ensure kora_core
   ensure kora_inventory
   ensure kora_utils
   ```

3. **OneSync must be on** — The vehicle/ped spawn blacklist is enforced server-side with the OneSync event `entityCreating`, cancelling the spawn before the entity is networked. Without OneSync that module's server half never fires (the client-side weapon strip still works regardless).

## Legacy compatibility

Kora Utils `provide`s `qb-smallresources`, so resources written against that name resolve to it, and it answers the same client/server export names stock qb-smallresources did (see Functions / exports). `AddFood`, `AddDrink`, `AddAlcohol` and `AddCustom` are NOT here — those moved to `kora_consumables`.

## Dependency details
Declared in `fxmanifest.lua`: `kora_lib`, `kora_core`, `kora_inventory`.

| Resource | Used for |
| --- | --- |
| `kora_lib` | `@kora_lib/init.lua` (`Kora.*`): cache (`ped`, `weapon`, `vehicle`, `playerId`), notify, keybind, callback, progressbar, stream, compat exports. |
| `kora_core` | Seatbelt server: `createUseable`, `getItemBySlot`, `getItemsByName`, `removeItem`. |
| `kora_inventory` | Provides the `qb-inventory` export `SetItemData` used to save harness durability. |

Optional or external, not declared: `kora_emotemenu` (crouch reads its state bag and calls `exports.kora_emotemenu:setWalk` if present), and a sound resource handling `InteractSound_SV:PlayWithinDistance`.

## Notes

- Add a `harness` item to your shared items if you use the harness (see [Items](./items.md)).
- Edit `config.lua` (see [Configuration](./configuration.md)).
- OneSync is also needed for server routing buckets used by the harness checks.

## Compatibility notes

The resource provides `qb-smallresources`, so remove the original resource. `healthregen` is not part of the original bundle; avoid a second owner (for example a medical resource) of the recharge multiplier. Behavioural reference for the seatbelt: `qbcore-fivem/qb-smallresources`.

## Tests

`test/run.sh` runs `test/smoke/*.lua` under plain Lua. Manual scenarios are in `tests/checklist-core-and-libraries.feature` for `kora_qa`.
