---
title: kora_utils
sidebar_position: 1
---

# kora_utils

`kora_utils` is a bundle of small, always-on world and player tweaks for Kora servers, in the spirit of `qb-smallresources` / `qbx_smallresources`. It disables the idle camera and the weapon wheel, zeroes passive health regeneration, thins ambient police and NPC chaos, blacklists weapons, vehicles and peds, and adds crouch/prone and a seatbelt/race-harness system. It also provides the `qb-smallresources` exports (control disabling, HUD components, density, timed jobs) so stock callers keep working.

All client features run through one shared tick coordinator (`client/core.lua`). A feature that is disabled in `config.lua` returns early and registers nothing.

Current version: see `version` in `fxmanifest.lua`.

## Documentation map

- [Installation](./installation.md) - dependencies, load order, OneSync, compatibility and tests.
- [How to use](./how-to-use.md) - the tick coordinator, feature catalogue, seatbelt and race harness.
- [Commands](./commands.md) - `toggleseatbelt`, the race harness command, crouch and prone keybinds.
- [API reference](./api/index.md) - client and server exports, also published as `qb-smallresources`.
  - [Legacy controls & HUD](./api/legacy-controls-hud.md) - control disabling, HUD components, density, ammo, hands-up.
  - [Seatbelt & harness](./api/seatbelt-exports.md) - `HasSeatbeltOn` and `HasHarness`.
  - [Timed jobs](./api/timed-jobs.md) - `CreateTimedJob`, `ForceRunTimedJob`, `StopTimedJob`.
- [Features](./features.md) - what each module does and which natives it uses.
- [Configuration](./configuration.md) - every `Config` option and its default.
- [Events](./events.md) - net events, local events, callbacks and state bags.
- [Items](./items.md) - the `harness` item and its durability.
- [Architecture](./architecture.md) - the `Small.*` tick coordinator and how to add a module.
- [Troubleshooting](./troubleshooting.md) - common problems and known limitations.

## Notes

- The resource declares `provide 'qb-smallresources'`.
- It has no database tables and no ACE permissions.
- Its test scenarios live in `tests/*.feature` (loaded by `kora_qa`), and plain Lua smoke tests in `test/`.
