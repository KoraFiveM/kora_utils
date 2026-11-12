---
title: "Legacy controls & HUD (qb-smallresources compatibility)"
sidebar_position: 2
---


# Legacy controls & HUD (qb-smallresources compatibility)

Flat exports reproducing stock qb-smallresources' control-disabling and HUD-presentation API, each scheduled lazily on `client/core.lua`'s shared frame thread the first time a caller actually changes something.

Namespace: `exports.kora_utils` · Source: `client/compat.lua, client/hud.lua`

## How it works

Every call tracks the invoking resource (`GetInvokingResource()`); entries are removed automatically when that resource (or kora_utils) stops, so a misbehaving or restarted consumer can never leave a control stuck disabled or a HUD component stuck hidden.

## Functions

Seven exports: three for controls, four for HUD/ammo/density presentation.

### `exports['kora_utils']:addDisableControls(controls)`

Legacy qb-smallresources export. Disables one or more game control actions (input group 2) every frame, via the shared frame coordinator. Accepts a single control id or a dense array of them.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `controls` | integer \| integer[] | One control-action id, or a dense (1-indexed, no gaps) array of them. Any malformed shape (non-numeric, non-dense, negative, non-integer) is silently ignored. |

**Returns**

- **Nothing. Legacy API has no success return.**

**Example**

```lua
exports.kora_utils:addDisableControls(24) -- disable INPUT_ATTACK
```

**Representative console output**

```text
Tracks which resource added each entry (`GetInvokingResource()`); the entry is dropped automatically when that resource (or kora_utils itself) stops.
```

### `exports['kora_utils']:removeDisableControls(controls)`

Removes previously disabled control(s) added by `addDisableControls`. Removes one matching entry per requested control (so duplicates must be removed once each).

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `controls` | integer \| integer[] | Same shape as `addDisableControls`. |

**Returns**

- **Nothing.**

**Example**

```lua
exports.kora_utils:removeDisableControls(24)
```

### `exports['kora_utils']:getDisableControls()`

Returns every control id currently disabled by any resource through this API.

**Parameters**



**Returns**

- **controls** — a plain array of control-action ids (may contain duplicates if several resources disabled the same control).

**Example**

```lua
local disabled = exports.kora_utils:getDisableControls()
```

### `exports['kora_utils']:addDisableHudComponents(ids)`

Legacy qb-smallresources HUD-component hiding, same add/remove/get shape as the controls API above, scheduled on the same frame coordinator the first time a component is hidden. Unlike stock there is no default hidden-component list — an untouched server hides nothing.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `ids` | integer \| integer[] | One HUD component id, or a dense array of them. |

**Returns**

- **add/remove** — nothing. get — a plain array of the currently hidden component ids.

**Example**

```lua
exports.kora_utils:addDisableHudComponents(7) -- hide the weapon-wheel stats panel
```

### `exports['kora_utils']:DecorSet(kind, value)`

Legacy qb-smallresources population-density setter. Sets one density multiplier, reasserted every frame once any density value has been set.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `kind` | string | One of `'parked'`, `'vehicle'`, `'multiplier'`, `'peds'`, `'scenario'`. Any other value is ignored. |
| `value` | number | A multiplier in `[0, 1]`, or `nil` to clear that kind. Out-of-range values are ignored. |

**Returns**

- **Nothing.**

**Example**

```lua
exports.kora_utils:DecorSet('peds', 0.3)
```

**Representative console output**

```text
Unlike stock there is no default density — an untouched server changes nothing until this is called.
```

### `exports['kora_utils']:setDisplayAmmo(value)`

`setDisplayAmmo` turns the ammo HUD on/off (`DisplayAmmoThisFrame`, reasserted every frame once set); `getDisplayAmmo` reads the last value set (defaults to `true` even before any call).

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `value` | boolean | `setDisplayAmmo` only: `true` shows ammo, `false` hides it. A non-boolean value is ignored. |

**Returns**

- **setDisplayAmmo** — nothing.
- **getDisplayAmmo** — boolean, the current value.

**Example**

```lua
exports.kora_utils:setDisplayAmmo(false)
```

### `exports['kora_utils']:getHandsup()`

Reports whether the local ped is currently playing the stock hands-up animation. Read-only; there is no `setHandsup` (stock tracked its own `/hu` command, which is out of this resource's scope).

**Parameters**



**Returns**

- **boolean** — `true` while the hands-up anim is playing.

**Example**

```lua
if exports.kora_utils:getHandsup() then ... end
```

## Limits and related APIs

Client only. No success/failure return values — these mirror the original qb-smallresources contract exactly, including its lack of one.
