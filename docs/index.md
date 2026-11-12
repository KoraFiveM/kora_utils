---
title: kora_utils
sidebar_position: 1
---

# kora_utils

`kora_utils` is a bundle of small, always-on world and player tweaks for Kora servers, in the spirit of `qb-smallresources` / `qbx_smallresources`. It disables the idle camera and the weapon wheel, zeroes passive health regeneration, thins ambient police and NPC chaos, blacklists weapons, vehicles and peds, and adds crouch/prone and a seatbelt/race-harness system. It also provides the `qb-smallresources` exports (control disabling, HUD components, density, timed jobs) so stock callers keep working.

All client features run through one shared tick coordinator (`client/core.lua`). A feature that is disabled in `config.lua` returns early and registers nothing.

Current version: see `version` in `fxmanifest.lua`.

## Pages

- [Features](./features.md) - what each module does and which natives it uses.
- [Configuration](./configuration.md) - every `Config` option and its default.
- [Commands and keybinds](./commands.md) - `toggleseatbelt`, the race harness command, crouch and prone keys.
- [Exports](./exports.md) - client and server exports, also published as `qb-smallresources`.
- [Events](./events.md) - net events, local events, callbacks and state bags.
- [Items](./items.md) - the `harness` item and its durability.
- [Dependencies and installation](./installation.md) - required resources, load order, OneSync.
- [Architecture](./architecture.md) - the `Small.*` tick coordinator and how to add a module.
- [Troubleshooting](./troubleshooting.md) - common problems and known limitations.

## Notes

- The resource declares `provide 'qb-smallresources'`.
- It has no database tables and no ACE permissions.
- Its test scenarios live in `tests/*.feature` (loaded by `kora_qa`), and plain Lua smoke tests in `test/`.
