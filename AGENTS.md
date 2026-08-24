# qbsmallresources agent guide

## What this resource is
A collection of small, always-on world/player tweaks — the qb-smallresources /
qbx_smallresources category of behaviour (idle-camera kill, weapon-wheel
removal, wanted-level suppression, health-regen zeroing, weapon/vehicle
blacklists), rebuilt on `qblib`. It is a **qblib consumer** (like `qbtarget`),
not a qblib module: it has its own resource namespace (`Small`), loads
`@qblib/init.lua` for `QB.*`, and owns its own `config.lua`.

Scope is deliberately the *passive tweak* half of the originals. Feature-sized
things the originals also bundle — consumables, carwash, seatbelt physics,
binoculars, pointing, discord presence, fireworks, teleports — are intentionally
OUT of scope here; they deserve their own resources. Don't grow this resource
into a monolith just because the originals were one.

## The core design decision: one tick coordinator
The defining constraint is performance. A "small resources" bundle is a pile of
tiny always-on tweaks, and the naive shape — one `CreateThread`/`while true ...
Wait(0) end` per feature — means a server pays N coroutine resumes every frame,
most doing one cheap native call. That is exactly the "running hot" pattern we
optimised out of baseevents.

So every client feature schedules through `client/core.lua`:
- `Small.onFrame(fn)` — ONE shared frame thread for the whole resource. Only for
  natives that truly need per-frame reassertion (`BlockWeaponWheelThisFrame`,
  `DisableControlAction`). Reaching for this when an interval would do is the
  main mistake to avoid.
- `Small.onInterval(ms, fn)` — one thread per DISTINCT interval, shared. The
  default cadence for everything else.
- `Small.onSpawn(fn)` — first spawn + every respawn, for player-scoped natives
  the engine resets on ped recreation. Fires on `playerSpawned` /
  `QBCore:Client:OnPlayerLoaded` AND on a watched ped-handle change, so it works
  even on spawn flows that raise no event.
- `Small.once(fn)` — one-shot yielding setup.

A feature disabled in config must register NOTHING — return early at the top of
the module file before any `Small.on*` call. That is what makes "cost is zero
when off" literally true.

## Layout
```
config.lua                      -- one flat Config table, one section per feature
client/core.lua                 -- the tick coordinator (Small.on*)
client/util.lua                 -- Small.hash / Small.hashSet
modules/<feature>/client.lua    -- one folder per feature
modules/<feature>/server.lua    -- only where a feature needs server authority
test/{harness,mocks,run.sh}     -- copied/adapted from qblib's suite
test/smoke/<name>.lua           -- one per module with real logic
```
`fxmanifest.lua` lists every file explicitly, never globbed — `core.lua` and
`util.lua` MUST load before any module that uses them, and an alphabetical glob
would load `blacklist` first. Same discipline as qblib's own manifest.

## Adding a feature
1. Add a `Config.<feature>` section with an enable toggle and commented values.
2. Create `modules/<feature>/client.lua` (and `server.lua` if it needs server
   authority — anything a client could cheat, e.g. spawn blocking, goes server
   side via OneSync `entityCreating`).
3. Return early if disabled. Schedule real per-frame work through
   `Small.onFrame`, everything else through `Small.onInterval`/`Small.onSpawn`.
4. Add the file(s) to `fxmanifest.lua` in the right order.
5. If the feature has branching logic (not just unconditional native calls), add
   `test/smoke/<feature>.lua` in the SAME change — mirror the existing tests'
   mock-install + dofile + step/fire shape.
6. Update the feature table in `docs.md`.

## Native cadence rules of thumb
- Per-frame (`onFrame`): only natives with a `...ThisFrame` name or a control
  disable — they wear off every frame by design.
- Player-scoped setters reset on respawn (`SetMaxWantedLevel`,
  `SetPlayerHealthRechargeMultiplier`, `SetPoliceIgnorePlayer`): `onSpawn`.
- Everything else (sweeps, dispatch toggles, ambient kills): `onInterval`, with
  the slowest interval that still works. The idle-cam threshold is tens of
  seconds, so a 1s tick is already generous.

## Testing
`test/run.sh` runs every `test/smoke/*.lua` under plain Lua (no busted). Mocks
(`test/mocks.lua`) follow qblib's convention: `CreateThread` resumes a thread
once, `handle.step()` resumes suspended tick loops one more iteration, and
`handle.fire(name, ...)` dispatches a lifecycle event. Only the natives the
tested modules actually call are mocked — a new native dependency should surface
as a nil-call failure, not pass silently. A `[qbsmallresources] onSpawn handler
errored: boom` line in test output is the intended pcall negative-path
assertion, not a failure.

## Compatibility notes
- `healthregen` is NOT inherited from either original (there it lives in the
  medical resource). It's here by explicit request. Flag the double-owner risk
  if a medical resource is also present.
- The weapon/vehicle/ped blacklist is split by trust boundary on purpose:
  weapons are stripped client-side (the client holds them), vehicle/ped spawns
  are refused server-side (only the server can reliably refuse a networked
  entity). Don't "simplify" the vehicle block into a client loop — it would be
  security theatre.
