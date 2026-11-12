---
title: Items
sidebar_position: 9
---

# Items

The seatbelt module registers one usable item: `harness`, via `exports.kora_core:createUseable('harness', ...)`. It is registered at start and again when `kora_core` restarts. The item definition itself is not in this resource; it must exist in your shared items.

## Durability

- Uses are stored in the item metadata as `info.uses`. A missing value means `Config.HarnessUses` (default 20).
- A stack is only valid when `uses` is a whole number from 1 to `Config.HarnessUses`.
- Equipping consumes one use after the progress bar completes: the server writes `info.uses - 1` using `exports['qb-inventory']:SetItemData`, or removes the item with `exports.kora_core:removeItem` when the last use is spent.
- A crash while the harness is attached spends one more use (server verified, with a cooldown). A crash with zero uses left detaches the harness; the item is removed when the last use is spent.
- Cancelling never consumes a use.

## Race harness command

The command picks the lowest-slot valid harness (`getItemsByName`). Removing an attached harness needs no item.

## Security

The client slot and metadata are not trusted. The server re-reads the slot, checks vehicle and routing bucket, issues a token, and requires the full `equipDuration` to have passed.
