---
title: "Commands"
sidebar_position: 4
---


# Commands

Kora Utils registers one in-game command, driven by the seatbelt module, plus an optional second command for the race harness if `Config.seatbelt.harness.command` is set.

## Built-in commands

### `toggleseatbelt`

Toggles the local seatbelt state. Refused while the pause menu is open or the player is not in an allowed vehicle (motorcycles, cycles and boats — vehicle classes 8/13/14 — never arm a seatbelt).

| Field | Details |
| --- | --- |
| Context | In-game · client command (default key B) |
| Arguments | No arguments. Bound via `RegisterKeyMapping` to `Config.seatbelt.keybind` (default `B`); rebindable in FiveM's own Key Bindings settings. |
| Access | Anyone in an allowed vehicle. |

**Example**

```text
toggleseatbelt (or press B)
```

**Result**

Buckles/unbuckles; plays the buckle/unbuckle sound via InteractSound, updates `LocalPlayer.state.seatbelt` and fires `seatbelt:client:ToggleSeatbelt`.

### `<Config.seatbelt.harness.command> (default raceharness)`

Attaches or removes the race harness while seated in an allowed vehicle. Set `Config.seatbelt.harness.command` to `false`/`''` to disable both the command and its key mapping.

| Field | Details |
| --- | --- |
| Context | In-game · client command, unbound key by default |
| Arguments | No arguments. |
| Access | Attaching requires owning a valid `harness` item; removing does not. |

**Example**

```text
raceharness
```

**Result**

Starts the same server-driven progress bar as the usable item; shows an error notification if no valid harness item is owned.

## Timed jobs are not a chat command

`CreateTimedJob`, `ForceRunTimedJob` and `StopTimedJob` are server-side exports only (see Functions / exports) — there is no network event and no in-game command to reach them.

## Registration details

All commands are client-side and registered without restriction (`RegisterCommand(..., false)`). There are no server commands and no ACE permissions.

| Command | Key mapping | Default key | Description |
| --- | --- | --- | --- |
| `toggleseatbelt` | "Toggle Seatbelt" | `B` (`Config.seatbelt.keybind`) | Toggle the seatbelt while in an eligible vehicle. Ignored when the pause menu is open. |
| `raceharness` (`Config.seatbelt.harness.command`) | "Toggle Race Harness" | unbound (`Config.seatbelt.harness.keybind`) | Ask the server to attach or remove the harness. Shows an error if the player has no harness item. |

Both are only registered when `Config.seatbelt.enabled` is true. The harness command is only registered when the configured name is a non-empty string.

## Keybinds registered through Kora.keybind

| Name | Default | Description |
| --- | --- | --- |
| `kora_utils_crouch` | `LCONTROL` | Tap to toggle crouch, hold for prone. |
| `kora_utils_prone_forward` | `W` | Crawl forward while prone. |
| `kora_utils_prone_backward` | `S` | Crawl backward while prone. |
| `kora_utils_prone_left` | `A` | Turn left while prone. |
| `kora_utils_prone_right` | `D` | Turn right while prone. |

Players can rebind all of these in the FiveM keybind settings.
