---
title: "API reference"
sidebar_position: 1
---

# API reference

| Module | Namespace | Realms |
| --- | --- | --- |
| [Legacy controls & HUD (qb-smallresources compatibility)](./legacy-controls-hud.md) | `exports.kora_utils` | client |
| [Seatbelt & harness](./seatbelt-exports.md) | `exports.kora_utils` | client |
| [Timed jobs (qb-smallresources compatibility)](./timed-jobs.md) | `exports.kora_utils` | server |

## Registration and qb-smallresources republishing

Every export below is registered on `kora_utils` and republished under `qb-smallresources` through `Kora.compat.provideExport`, so `exports['qb-smallresources']:Name()` works unchanged. The manifest also declares `provide 'qb-smallresources'`.

## Additional behaviour (from code)

### Controls

- `addDisableControls(controls)` - disable control group 2 actions every frame. `controls` is a number or a dense array of non-negative integers. Invalid input is ignored. Entries are owned by the calling resource.
- `removeDisableControls(controls)` - removes one matching entry for each control.
- `getDisableControls()` - returns the current list of control ids.

Entries owned by a resource are dropped when that resource stops. The frame task is paused when the list is empty.

### HUD, ammo and density

- `addDisableHudComponents(ids)`, `removeDisableHudComponents(ids)`, `getDisableHudComponents()` - hide HUD components every frame (`HideHudComponentThisFrame`). Accepts a number or a dense array of non-negative integers.
- `setDisplayAmmo(boolean)` and `getDisplayAmmo()` - control `DisplayAmmoThisFrame`. Non-boolean values are ignored. Default is `true` and costs nothing until set.
- `DecorSet(kind, value)` - set a per-frame density multiplier. `kind` is one of `parked`, `vehicle`, `multiplier`, `peds`, `scenario`; `value` is a number from 0 to 1, or `nil` to clear. Other input is ignored.
- `getHandsup()` - returns `true` when the local ped is playing the `missminuteman_1ig_2` / `handsup_base` animation.

There is no default hidden component list and no default density.

### Seatbelt

Only registered when `Config.seatbelt.enabled` is true.

### Server (timed jobs)

- `CreateTimedJob(hour, min, cb)` - run `cb(day, hour, min)` at the given server local time (`os.date`), once per day. `day` is the Lua `wday` (1 is Sunday). Returns a numeric id, or `nil` (with a console warning) if arguments are invalid. Jobs share a single loop aligned to the minute.
- `ForceRunTimedJob(id)` - run the job now.
- `StopTimedJob(id)` - remove the job.

Ids are never reused. Callback errors are caught and printed. Jobs of a stopped resource are removed. There is no network event for these; only server resources can call them.

## Not provided here

`AddFood`, `AddDrink`, `AddAlcohol` and `AddCustom` are not defined in this resource.
