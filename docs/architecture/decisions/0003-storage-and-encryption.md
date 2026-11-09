# ADR 0003: Storage layout and encryption

Status: **Proposed**. Not final until the Phase 1b proof of concept passes on virtual disks.
Date: 10 November 2026

## Decision

UEFI and GPT only for the first release. One LUKS2 container holding one Btrfs filesystem with separate subvolumes for system and user data. `/boot` stays outside the encrypted container.

| # | Partition | Size (starting point) | Format | Purpose |
|---|---|---|---|---|
| 1 | EFI System Partition | 1 GiB | FAT32 | shim, GRUB |
| 2 | Boot | 2 GiB | ext4, unencrypted | kernels, initramfs |
| 3 | Recovery | 6 GiB | read-only image | Emergency Recovery environment |
| 4 | CHEENA vault | rest of disk | LUKS2 → Btrfs | everything else |

Btrfs subvolumes inside the vault:

| Subvolume | Mount | Reinstall behaviour |
|---|---|---|
| `@system` | `/` | replaced |
| `@home` | `/home` | **preserved** |
| `@data` | `/var/lib/cheena` (restore manifest, backup state) | **preserved** |
| `@snapshots` | `/.snapshots` | system snapshots only; cleared on reinstall |
| `@log` | `/var/log` | kept across rollback so failures can be diagnosed |

Sizes and names are a hypothesis to test, not a commitment.

## Key decisions and why

**Unencrypted `/boot`.** Ubuntu 26.04's signed GRUB is reported to fail on LUKS2 keyslots that use Argon2, with the error "Argon2 not supported" [R8, grade C]. The alternatives are both worse: weaken the key derivation to PBKDF2 for the whole vault, or ship a self-built GRUB and lose the Secure Boot signature. The cost is that kernel and initramfs are readable and, without further measures, modifiable by someone with physical access (risk S-02 in the threat model).

**One container, not two.** A single passphrase prompt, and free space is shared between system and user data, which matches the "one storage pool" requirement. The cost: a damaged LUKS header loses both, so a **header backup** is taken at install and stored with the recovery material.

**Key slots.** Slot 0: user passphrase (Argon2id). Slot 1: a generated recovery key, created with `systemd-cryptenroll --recovery-key` [R12], shown once for the user to print or save off the PC. No vendor key. TPM2 unlock is **deferred**: it defaults to binding on PCR 7 [R12], which changes with Secure Boot state, and it must never be the only way in.

**Fail-closed identity.** The vault and its subvolumes are identified by LUKS UUID, a CHEENA label and a marker file inside `@data` recording layout version. If any of the three disagree, Safe Reinstall stops (ADR 0004).

## Stated limits

- Snapshots live on the same disk. They are not backups.
- Losing both passphrase and recovery key means the data is gone. Setup must say so plainly.
- Encryption protects a powered-off or locked-out machine, not a running, unlocked one.

## Tests required before this is accepted

All on disposable virtual disks:

1. Wrong passphrase is refused; recovery key unlocks.
2. Boot with Secure Boot on and off.
3. Replace `@system`, confirm `@home` and `@data` are byte-identical (checksums).
4. Roll back `@system` to a snapshot after a simulated failed update.
5. Fill the disk to 100% and confirm the system still boots and can delete snapshots.
6. Power-cut during a write; filesystem mounts cleanly.
7. Corrupt the LUKS header; restore from header backup.
8. Search logs and journal for passphrase or key material.

## Open questions

- Legacy BIOS support: assessed separately, not in the first release.
- Swap and hibernation with encryption: not designed yet.
- Whether the upstream GRUB limitation in [R8] has been fixed in a 26.04 update. Re-check at Phase 1b.
