---
title: Troubleshooting
sidebar_position: 11
---

# Troubleshooting

## wantedLevel.disable = false does not restore the wanted level

The wanted level module does not read `disable`, `interval` or `hideHudStar`. It always runs `SetMaxWantedLevel(0)` and applies the three dispatch toggles once at load. The dispatch toggles can be set to `false` to restore stock dispatch, but the max wanted level of 0 cannot be turned off through config.

## Blacklisted vehicles still appear

Needs OneSync. Names must be valid model names or hashes. `entityCreating` only sees entities created after the server started handling them.

## Weapon is removed repeatedly

It is in `Config.blacklist.weapons`. Both the client cache watcher and the server sweep remove it.

## Health does not regenerate

Intended with the default `multiplier = 0.0`. Set `multiplier = 1.0` and `limit = 0.0` to skip the module.

## Harness cannot be attached

Check: the item is named `harness`, `info.uses` is between 1 and `Config.HarnessUses`, the vehicle is not a bike, cycle or boat, the progress bar was not cancelled, and `kora_core` and `kora_inventory` are running.

## Console line "onSpawn handler errored"

A spawn handler raised an error; the others still run.

## Crouch does nothing

The module needs `Config.crouch.enabled`, and stance changes are refused in vehicles, while ragdolling, or during an emote.
