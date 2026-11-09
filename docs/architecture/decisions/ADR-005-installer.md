# ADR-005: Installer and Safe Reinstall approach

- **Status:** Proposed
- **Date:** 2026-11-09

## Context
The installer must support:
- UEFI and Secure Boot
- LUKS2
- Btrfs subvolumes
- Detecting an existing install
- Safe data preservation
- Accessibility and localisation
- Maintainability

Findings:
- Kubuntu 26.04 and Debian 13 live images use **Calamares** [S2][S10, installer version to verify for Kubuntu].
- Calamares can be set to create LUKS2 containers (`luksGeneration: luks2`) and lists Btrfs subvolumes in `mount.conf` [S8].
- Community reports say Calamares **fails when `@`/`@home` already exist** and doesn't detect Btrfs inside an unopened LUKS2 container [S9]. Neither installer has a "keep my data" reinstall mode.
- Ubuntu's own desktop installer offers TPM-backed FDE [S7]. Its Btrfs support is unconfirmed, and it is GNOME- and Snap-oriented.

## Decision (proposed)
1. **Fresh install:** Calamares (the Kubuntu/Debian-packaged version) with CHEENA branding and configuration:
   - partition layout per ADR-004
   - LUKS2 with Argon2id
   - a recovery-key generation step
   - a recovery-key confirmation step: the user must re-enter part of the key
2. **Safe Reinstall ("Repair existing system — keep personal data"):** a **separate CHEENA tool** (`cheena-reinstall`) that runs from the live/recovery environment. It is **not** a checkbox inside the normal install flow. It can later be packaged as a Calamares view module.
   1. Discover disks and show an identity summary: model, serial, size, partitions, LUKS UUIDs and labels.
   2. Find candidate vaults using the ADR-004 identity rules. If there are zero or several matches → **STOP**.
   3. Ask the user to unlock with a passphrase or recovery key. If that fails → STOP.
   4. Run checks before changing anything: a read-only Btrfs check (`btrfs check --readonly` or scrub status), free space, the date of the last successful backup, and a warning if there is no backup.
   5. Show a preflight summary listing the exact operations, and require explicit confirmation.
   6. Snapshot the current `@` to `@snapshots/pre-reinstall-<ts>`. Create a new `@`. Install the system into it. Preserve `@home` and `@cheena-data`.
   7. Write a transaction log to `@cheena-data/logs/` that contains no secrets. Reboot. Run app restore (Phase 7).
   - **Never** touch `@home`, `@cheena-data` or other partitions. The code paths that format or repartition must not exist in this tool at all.
3. **Fresh install that erases everything** is a separate Calamares path with a strong warning and a second confirmation.

## Consequences
- `cheena-reinstall` is high-risk code. It needs its own tests on disposable virtual disks, its own threat model entry and independent review.
- Calamares is GPL-3.0. Any custom Calamares modules carry its licence obligations (see licensing doc).
- Dual-boot with Windows is **out of v1 scope** (proposed, M-14). The installer should refuse to install on disks that contain a BitLocker or NTFS system unless the user chooses "erase entire disk".
