# Storage and encryption design

Status: Proposed. The decisions themselves are in [ADR-003](decisions/ADR-003-boot-and-encryption.md) and [ADR-004](decisions/ADR-004-storage-layout.md). This document covers the user-facing behaviour and the test obligations.

## What the user sees
- **One storage space** ("CHEENA Storage") with used and free space. Users organise their own folders: Gaming, Design, Jobs, Business, Personal, and so on.
- A note in Control Center explaining that the disk still has internal technical areas for boot, recovery and encryption, even though the user sees one space.
- Status cards, all showing real values:
  - encryption on/off
  - recovery key confirmed yes/no
  - last snapshot
  - last **external** backup ("Never" if none)
  - Btrfs health from the last scrub result

## CHEENA Secure Data Vault: setup flow (Phase 4)
1. The user picks a passphrase. A strength meter checks it locally, and nothing is sent anywhere.
2. CHEENA generates a recovery key and shows it once. The user can export it in one of these ways:
   - print it
   - save it to a USB drive (not the internal disk)
   - scan a QR code with their phone
3. The user must re-enter part of the key before setup continues.
4. Plain-language warning: *"If you lose both your password and your recovery key, nobody, including CHEENA, can recover your files."*
5. Optional: export the LUKS header backup to external media.

## Rules
- No vendor master key and no backdoor.
- Secrets never go into logs, crash reports, Git, or AI prompts.
- The recovery key is **never** stored unencrypted on the same disk.
- Encryption protects data at rest. **It is not a backup.** Snapshots are not backups either. Both statements appear in the UI.

## Test obligations
See ADR-003 (encryption tests) and ADR-004 (layout tests). All of them run on **disposable virtual disks**, as listed in [test-strategy.md](../testing/test-strategy.md).
