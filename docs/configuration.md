---
title: Configuration
sidebar_position: 3
---

# Configuration

`config.lua` is a shared script and defines one global `Config` table. The last line adopts the table through `Kora.config.adopt` when `kora_lib` provides it. Defaults below are the values in `config.lua`.

## idleCamera

| Key | Default | Meaning |
| --- | --- | --- |
| `disable` | `true` | Kill the idle camera. When `false` the module registers nothing. |
| `interval` | `10000` | Milliseconds between calls. |

## weaponWheel

| Key | Default | Meaning |
| --- | --- | --- |
| `disable` | `true` | Remove the weapon wheel. |
| `blockAutoSwap` | `true` | Call `SetWeaponsNoAutoswap(true)` on spawn. |

## vehicleRewards

| Key | Default | Meaning |
| --- | --- | --- |
| `disable` | `true` | Call `DisablePlayerVehicleRewards` on spawn. |

## wantedLevel

| Key | Default | Meaning |
| --- | --- | --- |
| `disablePolice` | `true` | Switch off AI police dispatch services. `false` leaves them at stock. |
| `disableFire` | `true` | Switch off AI fire department dispatch. |
| `disableAmbulance` | `true` | Switch off AI ambulance dispatch. |
| `disable` | `true` | Present in config but not read by the code. See [Troubleshooting](./troubleshooting.md). |
| `interval` | `2000` | Present in config but not read by the code. |
| `hideHudStar` | `false` | Present in config but not read by the code. |

## healthRegen

| Key | Default | Meaning |
| --- | --- | --- |
| `multiplier` | `0.0` | Recharge multiplier. `0.0` means no passive healing, `1.0` is stock. |
| `limit` | `0.0` | Recharge limit passed to `SetPlayerHealthRechargeLimit`. |

The module is skipped only when `multiplier == 1.0` and `limit == 0.0`.

## crouch

| Key | Default | Meaning |
| --- | --- | --- |
| `enabled` | `true` | Enable the module. |
| `keybind` | `'LCONTROL'` | Default crouch/prone key (keyboard). |
| `holdDuration` | `500` | Milliseconds to hold for prone. |
| `crouchClipset` | `'move_ped_crouched'` | Movement clipset. |
| `crouchStrafeClipset` | `'move_ped_crouched_strafing'` | Strafe clipset. |
| `proneAnimDict` | `'move_crawl'` | Prone animation dictionary. |
| `proneForwardAnim` | `'onfront_fwd'` | Crawl forward clip. |
| `proneBackwardAnim` | `'onfront_bwd'` | Crawl backward clip. |
| `proneTurnSpeed` | `1.0` | Heading change per frame while turning. |
| `proneForwardKey`, `proneBackwardKey`, `proneLeftKey`, `proneRightKey` | `'W'`, `'S'`, `'A'`, `'D'` | Default keys for the prone key mappings. |
| `proneControllerSupport` | `true` | Also read controller sticks in the prone frame task. |
| `reassertInterval` | `100` | Milliseconds between stance checks while crouched or prone. `0` or less falls back to 250. |
| `blockIdleClips` | `true` | Block idle clips while crouched (anything other than `false` enables it). |
| `blockStockDuck` | `'event'` | `'event'`, `'frame'` or `false`. `true`, `nil` and unknown values behave as `'event'`. |

## blacklist

| Key | Default | Meaning |
| --- | --- | --- |
| `weapons` | railgun, RPG, grenade launchers, minigun, firework, ray minigun, stinger | Weapons stripped client-side and by the server sweep. |
| `serverWeaponSweepInterval` | `250` | Milliseconds between server weapon sweeps. |
| `notifyOnStrip` | `true` | Notify the player when a weapon is removed. |
| `vehicles` | rhino, lazer, hydra, savage, buzzard, oppressor, oppressor2, scramjet, deluxo, insurgent, blimp, blimp2, blimp3 | Models refused by `entityCreating`. |
| `notifyOnVehicleBlock` | `true` | Notify the owner of a blocked vehicle. |
| `peds` | empty | Ped models refused by `entityCreating`. |

Entries can be names or raw hashes.

## worldDepop

| Key | Default | Meaning |
| --- | --- | --- |
| `disableRandomCops` | `true` | Disable ambient cops, sirens, garbage trucks and the police scanner. |
| `disablePedDrops` | `true` | Dead peds do not drop weapons. |
| `calmNpcs` | `true` | Ambient groups stop being hostile to players. |
| `disableDriveby` | `false` | Players cannot drive-by. |
| `reassertInterval` | `10000` | Milliseconds between reasserts. |

## Harness and seatbelt

| Key | Default | Meaning |
| --- | --- | --- |
| `Config.HarnessUses` | `20` | Default and maximum uses of a harness. |
| `seatbelt.enabled` | `true` | Enable client and server seatbelt modules. |
| `seatbelt.keybind` | `'B'` | Default key for `toggleseatbelt`. |
| `seatbelt.equipDuration` | `5000` | Progress bar duration and minimum server-side elapsed time (ms). |
| `seatbelt.actionLifetime` | `30000` | Time (ms) a pending harness action stays valid. |
| `seatbelt.crashCooldown` | `1000` | Minimum ms between harness damage events. |
| `seatbelt.removeEmptyHarness` | `true` | Allows removing a harness with zero uses through the belt key when `separateFromSeatbelt` is false. |
| `seatbelt.harness.separateFromSeatbelt` | `true` | Harness independent of the belt. |
| `seatbelt.harness.command` | `'raceharness'` | Command name; empty string disables the command, key mapping and callback. |
| `seatbelt.harness.keybind` | `''` | Default key for the race harness mapping (unbound). |
| `seatbelt.harness.lockInventory` | `false` | Set `inv_busy` on the local player state during the progress bar. |

Hardcoded values (not configurable): the weapon wheel flag is reasserted every 10 s, the prone step durations, and the ambient group list in `worlddepop`.
