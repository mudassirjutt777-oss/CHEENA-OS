# ADR 0004: Installer and Safe Reinstall

Status: **Proposed**
Date: 10 November 2026

## Decision

1. **Fresh installation** uses **Calamares**, configured to produce the layout in ADR 0003.
2. **Safe Reinstall** ("Repair Existing System, Keep Personal Data") is a **separate CHEENA tool**, not a Calamares mode.

## Options considered

| Option | For | Against |
|---|---|---|
| Ubuntu's installer (Subiquity with the desktop front end) | Maintained by the base distribution; active work on TPM-backed encryption [R11] | Built around Ubuntu's own layouts and Snap delivery. Custom Btrfs-on-LUKS layouts and rebranding were not confirmed from official documentation in this audit |
| Calamares | Distribution-neutral, themeable, module-based, used by Kubuntu-family and many other distributions | No official support found for reusing an existing encrypted Btrfs layout. Community reports say it fails when `@` or `@home` exist and does not offer opened LUKS volumes as targets [R10, grade C] |
| Custom installer | Full control | Large, risky, unnecessary for fresh installs |

## Why Safe Reinstall is separate

The master workflow says Safe Reinstall must not be "skipping a format checkbox". The reported Calamares behaviour [R10] points the same way: a general partitioner is the wrong tool for an operation whose whole purpose is to *not* partition. A small dedicated tool can be tested exhaustively and can refuse to run.

### Safe Reinstall sequence

1. **Discover** disks read-only. List every disk with model, serial, size and partition table.
2. **Identify** a CHEENA vault by LUKS UUID plus label. Zero or more than one match: stop.
3. **Authenticate.** User enters passphrase or recovery key. Failure: stop. Nothing is written before this point.
4. **Verify** the marker file in `@data`, the layout version, and that `@home` exists. Run a read-only filesystem check. Any mismatch: stop.
5. **Preflight summary** on screen: disk, partitions, what will be replaced (`@system`, boot, ESP contents), what will be kept (`@home`, `@data`), last backup date if known. User confirms by typing a phrase.
6. **Execute.** Create a new system subvolume beside the old one, install into it, then switch. The old `@system` is renamed and kept until first successful boot. `@home` and `@data` are never opened for writing by the installer except to update the restore manifest.
7. **Log** every step to the recovery partition without secrets.

No partition table write and no `mkfs` occur anywhere in this path. That is a property the test suite can assert.

"Fresh Installation, Erase Everything" stays a separate Calamares path with its own warning and second confirmation.

## Consequences

- Two code paths to maintain and test.
- The dedicated tool is security-sensitive. Language choice (Rust or carefully tested Python) is decided in Phase 5 with a recorded reason.
- Calamares behaviour with the ADR 0003 layout is unproven and is the first thing Phase 5 tests.

## Tests required

- Fresh install to a blank virtual disk, Secure Boot on.
- Safe Reinstall preserving files with known checksums and a browser profile.
- Refusal cases: two vaults present, wrong passphrase, missing marker, unknown layout version, foreign LUKS volume.
- Power cut at each step of the execute phase; system recovers to old or new state, never neither.
