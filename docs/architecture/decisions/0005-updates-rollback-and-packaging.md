# ADR 0005: Updates, rollback and application delivery

Status: **Proposed**
Date: 10 November 2026

## Decision

| Concern | Choice |
|---|---|
| OS and core components | `apt` from the base distribution's signed archive |
| CHEENA's own packages | A separate signed `apt` repository, pinned so it cannot replace base packages unintentionally |
| Desktop applications | Flatpak as the default route in the software interface; `.deb` for system-level tools |
| Rollback | Btrfs snapshot of `@system` before every update transaction; boot menu entry to start the previous snapshot |
| Update owner | One CHEENA update manager drives both apt and Flatpak so the user sees one update flow |

## Reasons

- Signed apt archives are the base distribution's supported mechanism. This meets the "signed updates through supported upstream mechanism" requirement without inventing one.
- Flatpak gives per-app sandboxing and portals, and a stable application ID independent of the OS. That ID is what the application restore manifest records.
- Snapshot-then-update is the smallest rollback design that works on a package-based system. A fully image-based system (as in Fedora's atomic desktops [R6][R7]) is stronger but is a different base (ADR 0001).

## Limits to state honestly

- Snapshot rollback restores `@system` only. Because `/boot` is a separate partition (ADR 0003), the kernel in `/boot` and the modules in the snapshot must match. The snapshot tool must save and restore the matching kernel files, or rollback can produce an unbootable system. This is the highest-risk part of the design and is tested first.
- Rollback does not undo changes in `/home` or database format upgrades made by newer application versions.
- Snapshots are on the same disk and are not backups.

## Open decision for the owner: Snap

Ubuntu delivers some desktop software, including its default browser, as Snap packages. Running Snap and Flatpak together means two sandbox systems and two updaters, which the master workflow warns against. Options:

1. Remove Snap and take the browser from Flatpak or the vendor's apt repository.
2. Keep Snap for the items Ubuntu ships that way.

Recommendation: option 1, decided before Phase 2 because it changes the package list.

## Signing keys

- Development, test and release keys are separate.
- No private key enters the repository or CI logs. Release signing happens outside CI or with a hardware-backed key.
- Custody and repository hosting are owner decisions, needed before Phase 3.

## Tests required

- Update with snapshot, then roll back; system boots and package database matches the snapshot.
- Interrupted update (process killed, power cut); system boots into old or repaired state.
- Tampered package or metadata is rejected.
- Disk full during update.
