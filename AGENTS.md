# kora_utils agent guide

## What this resource is
A collection of small, always-on world/player tweaks — the qb-smallresources /
qbx_smallresources category of behaviour (idle-camera kill, weapon-wheel
removal, wanted-level suppression, health-regen zeroing, weapon/vehicle
blacklists), rebuilt on `kora_lib`. It is a **kora_lib consumer** (like `kora_target`),
not a kora_lib module: it has its own resource namespace (`Small`), loads
`@kora_lib/init.lua` for `Kora.*`, and owns its own `config.lua`.

Scope is deliberately the *passive tweak* half of the originals. Feature-sized
things the originals also bundle — consumables, carwash, seatbelt physics,
binoculars, pointing, discord presence, fireworks, teleports — are normally
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
test/{harness,mocks,run.sh}     -- copied/adapted from kora_lib's suite
test/smoke/<name>.lua           -- one per module with real logic
```
`fxmanifest.lua` lists every file explicitly, never globbed — `core.lua` and
`util.lua` MUST load before any module that uses them, and an alphabetical glob
would load `blacklist` first. Same discipline as kora_lib's own manifest.

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
6. Update the matching page in `docs/` (see Documentation below).

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
(`test/mocks.lua`) follow kora_lib's convention: `CreateThread` resumes a thread
once, `handle.step()` resumes suspended tick loops one more iteration, and
`handle.fire(name, ...)` dispatches a lifecycle event. Only the natives the
tested modules actually call are mocked — a new native dependency should surface
as a nil-call failure, not pass silently. A `[kora_utils] onSpawn handler
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

## Authorized compatibility extension
The QBCore backwards-compatibility implementation explicitly added `modules/seatbelt` with real harness item authority and lifecycle. Keep its client work on the existing coordinator; preserve server ownership, elapsed-time checks and inventory mutations. This user-authorized exception does not turn unrelated feature work into scope.

## Documentation

User-facing documentation lives in `docs/` (Markdown, published via the Kora Docusaurus site, kora_docs_next). Read `docs/index.md` first (it has a documentation map). Layout: `installation.md` (dependencies, setup), `how-to-use.md` (coordinator, feature catalogue, seatbelt), `commands.md` (commands and keybinds), `api/` (`index.md` plus one page per export group: legacy-controls-hud, seatbelt-exports, timed-jobs), and topic pages (`features.md`, `configuration.md`, `events.md`, `items.md`, `architecture.md`, `troubleshooting.md`). Exports belong in `api/`, not a separate page.

When you add, change, or remove a feature, config option, command, export, event, item, permission, or database table/column, update the matching page in `docs/` in the same change. Keep docs accurate to the code; do not document behaviour that does not exist.

Docs rules: plain Markdown with `title`/`sidebar_position` front matter (no `id`/`slug`), relative links only between docs pages, assets inside `docs/`, fenced code blocks with a language, and no raw `<`, `>`, `{`, `}` outside code (pages are parsed as MDX). The release version comes from `fxmanifest.lua`'s `version` field.
