---
title: "Timed jobs (qb-smallresources compatibility)"
sidebar_position: 4
---


# Timed jobs (qb-smallresources compatibility)

A daily wall-clock scheduler: register a callback for an hour/minute and it fires once a day at that time. One shared thread for every job, started lazily on the first `CreateTimedJob` call and aligned to the top of the next minute.

Namespace: `exports.kora_utils` · Source: `server/timedjobs.lua`

## Functions

Three exports: create, force-run, stop.

### `exports['kora_utils']:CreateTimedJob(hour, min, cb)`

Legacy qb-smallresources export. Registers a job run once a day at the given wall-clock hour/minute, checked on a shared minute-aligned thread (started on first use).

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `hour` | integer | Hour (server local time, from `os.date`). |
| `min` | integer | Minute. |
| `cb` | function | Called as `cb(day, hour, min)` when due. Errors inside `cb` are caught and logged, never crash the scheduler. |

**Returns**

- **id** — an integer job id (never reused), or `nil` if `hour`/`min` were not numbers or `cb` was not callable (also prints a `WARN:` line).

**Example**

```lua
local jobId = exports.kora_utils:CreateTimedJob(6, 0, function(day, hour, min)
    print('daily 6am job ran')
end)
```

**Representative console output**

```text
The job is dropped automatically when the resource that created it stops (tracked via `GetInvokingResource()`). Server-only: there is no network event, so only another server resource can create or run one.
```

### `exports['kora_utils']:ForceRunTimedJob(id)`

Runs a registered job immediately, once, with the current day/hour/minute — without waiting for its scheduled time.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `id` | integer | The id returned by `CreateTimedJob`. |

**Returns**

- **Nothing. Silently does nothing if `id` does not match a registered job.**

**Example**

```lua
exports.kora_utils:ForceRunTimedJob(jobId)
```

### `exports['kora_utils']:StopTimedJob(id)`

Unregisters a job so it never fires again.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `id` | integer | The id returned by `CreateTimedJob`. |

**Returns**

- **Nothing.**

**Example**

```lua
exports.kora_utils:StopTimedJob(jobId)
```

## Limits and related APIs

Server only. No network event — this is a server-to-server API, not something a client can trigger.
