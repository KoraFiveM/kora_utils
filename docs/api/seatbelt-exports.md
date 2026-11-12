---
title: "Seatbelt & harness"
sidebar_position: 3
---


# Seatbelt & harness

Two read-only exports for whatever reads vehicle-safety state (the HUD, another resource's logic). The belt and harness themselves are driven by the `toggleseatbelt` command and the harness command/item (see Commands and How to use).

Namespace: `exports.kora_utils` · Source: `modules/seatbelt/client.lua`

## Functions

Two boolean readers.

### `exports['kora_utils']:HasSeatbeltOn()`

Reads the local seatbelt state.

**Parameters**



**Returns**

- **boolean** — `true` while buckled.

**Example**

```lua
if exports.kora_utils:HasSeatbeltOn() then ... end
```

### `exports['kora_utils']:HasHarness()`

Reads whether the race harness is currently attached (independent of the belt when `Config.seatbelt.harness.separateFromSeatbelt` is true).

**Parameters**



**Returns**

- **boolean** — `true` while the harness is attached.

**Example**

```lua
if exports.kora_utils:HasHarness() then ... end
```

## Limits and related APIs

Client only, and only `Config.seatbelt.enabled = true`. Local presentation state — not the server's authoritative harness durability (see How to use for how the server verifies and consumes harness uses).
