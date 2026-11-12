---
title: Architecture
sidebar_position: 9
---

# Architecture

Client features schedule work through `client/core.lua` instead of each running its own loop.

| API | Behaviour |
| --- | --- |
| `Small.onFrame(fn)` | Runs `fn` every frame on one shared thread. Returns `setActive(bool)`; when no task is active the thread exits. |
| `Small.onInterval(ms, fn)` | One thread per distinct interval, shared. `ms` must be a positive number. |
| `Small.onSpawn(fn)` | Runs on `playerSpawned`, `QBCore:Client:OnPlayerLoaded`, and when the cached ped changes. Errors are caught and printed. |
| `Small.once(fn)` | Runs `fn` once in a new thread. |
| `Small.hash(v)`, `Small.hashSet(list)` | In `client/util.lua`. Hash names to `joaat` and build lookup sets. |

## Adding a module

1. Add a `Config.<feature>` section.
2. Create `modules/<feature>/client.lua` (and `server.lua` if the client could cheat), returning early when disabled.
3. List the file explicitly in `fxmanifest.lua` after `client/core.lua` and `client/util.lua`. Files are never globbed.
4. Add `test/smoke/<feature>.lua` for branching logic.
5. Update these docs.

## Layout

```text
config.lua              shared Config
client/                 core, util, compat (controls), hud (HUD/density/ammo)
server/timedjobs.lua    timed jobs exports
modules/<name>/         client.lua, and server.lua for blacklist and seatbelt
test/                   harness and smoke tests
tests/                  kora_qa feature file
```
