# ADR-004: Storage layout

- **Status:** Proposed. Do not finalise until the Phase 1b, 4 and 5 tests pass (master workflow §3.4).
- **Date:** 2026-11-09

## Context
The layout has to meet five requirements:
- The user sees one main storage space.
- System files are logically separate from personal data.
- System snapshots and rollback are possible.
- Safe Reinstall replaces system files without formatting user data.
- Encryption is in place (ADR-003).

## Decision (proposed)
```
GPT disk
├── p1  ESP          FAT32   1 GiB   /boot/efi
├── p2  BOOT         ext4    2 GiB   /boot              (unencrypted, see ADR-003)
├── p3  RECOVERY     ext4    4 GiB   CHEENA recovery image (read-only use)
└── p4  CHEENA-VAULT LUKS2 (Argon2id)
        └── Btrfs  label "cheena-pool"
            ├── @                  /                   system (replaceable)
            ├── @home              /home               user data (PRESERVED)
            ├── @cheena-data       /var/lib/cheena     identity marker, app-restore manifest (PRESERVED)
            ├── @snapshots         /.snapshots         system snapshots
            ├── @var-log           /var/log            excluded from rollback
            ├── @var-cache         /var/cache          excluded from rollback
            └── @var-tmp           /var/tmp            excluded from rollback
```

### Why one container and not two
| | One container (chosen) | Separate system and data containers |
|---|---|---|
| User sees one storage pool | **Yes**: subvolumes share free space | No: fixed split between system and data |
| Safe Reinstall blast radius | Must recreate `@` *inside* an unlocked filesystem. Higher stakes | Can reformat the system container without touching data. Safer |
| Unlock prompts | One | Two, or a keyfile chain |

One container meets the product requirement. The extra risk is handled by **fail-closed volume identification** (below). If Phase 5 testing can't make it reliable, switch to two containers.

### Volume identity (fail closed)
Safe Reinstall may proceed only if **all** of the following match. Otherwise it **stops**:
1. LUKS2 header UUID and label `CHEENA-VAULT`
2. Btrfs label `cheena-pool` and filesystem UUID
3. The marker file `@cheena-data/identity.json` exists, holding the install ID, creation date, layout version and filesystem UUIDs
4. The user successfully unlocks with a passphrase or recovery key
5. Exactly **one** candidate volume matches

## Risks and required tests
- Snapshots are **not backups**. They share the same disk (same failure domain).
- `/boot` is outside the snapshots. Rolling back `@` can mismatch kernel modules → R-03. Phase 1b must test this.
- Btrfs out-of-space (ENOSPC) behaviour, plus snapshot growth limits and cleanup policy, must be tested.
- Swap: use a swap file on a `@swap` subvolume or zram. Hibernation with encrypted swap is **deferred**.
- A community report says Calamares fails when `@`/`@home` already exist [S9]. That affects ADR-005.
