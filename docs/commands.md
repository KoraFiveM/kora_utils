---
title: Commands and keybinds
sidebar_position: 4
---

# Commands and keybinds

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
