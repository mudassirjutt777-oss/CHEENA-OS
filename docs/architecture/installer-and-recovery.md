# Installer, Safe Reinstall and Emergency Recovery

Status: Proposed. The installer decision is in [ADR-005](decisions/ADR-005-installer.md).

## Three separate paths (never combined in one screen)
| Path | Tool | Destructive? | Confirmation |
|---|---|---|---|
| Fresh install, erase entire disk | Calamares (CHEENA config) | **Yes** | Disk identity shown (model, serial, size) + typed confirmation |
| Repair existing system, keep personal data | `cheena-reinstall` | System subvolume only | Unlock + preflight summary + confirmation. Stops on any ambiguity |
| Emergency Recovery | CHEENA recovery environment (RECOVERY partition or USB) | No by default. Destructive repair is a separate, explicit menu | Unlock required before any user data is shown |

## Emergency Recovery environment (Phase 6)
A minimal, read-only image containing:
- Diagnostics:
  - disk SMART status (where available)
  - Btrfs read-only check
  - boot log viewer
  - list of failed units in the installed system
- Unlock the vault, with passphrase or recovery key.
- **Copy data to external drive.** This is the most important function: users can always get their files out.
- Roll back the system to a chosen snapshot (with confirmation).
- Repair the boot entries: reinstall shim/GRUB to the ESP (with confirmation).
- Start Safe Reinstall.
- Export a support bundle (redacted) to USB.

It must work **offline** and with **AI disabled**.

## Failure simulations required (Phase 6)
1. A kernel update that leaves the system unbootable
2. An update interrupted mid-way (VM power cut)
3. Deleted or corrupted system files in `@`
4. A full disk during an update
5. Recovery USB booting a machine whose ESP was wiped (virtual disk)

## Never
- Guess which volume is the user's data volume.
- Run `btrfs check --repair` automatically (speculative repair is forbidden in §2.3A).
- Show encrypted user data before successful authentication.
