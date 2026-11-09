# Phase 0 report

Date: 9 November 2026. This report follows master workflow §11, point 15.

## 1. Repository state
- 2 commits, a README and the master workflow file. No prior code. Nothing was deleted or overwritten.
- Phase 0 added documentation only. It is **uncommitted** and waiting for owner review.

## 2. Environment capabilities
The session host is the owner's Windows laptop: 7.8 GB RAM, 18.3 GB free disk, no admin rights, no hypervisor tooling. It **cannot build or boot-test an ISO.** Details are in [build-environment.md](../operations/build-environment.md).

## 3. Recommended architecture (all "Proposed")
| Area | Recommendation | ADR |
|---|---|---|
| Base | Ubuntu 26.04 LTS with the Kubuntu package set. **Conditional**: Debian 13 is a close fallback because of the KDE security-coverage question | [ADR-001](../architecture/decisions/ADR-001-base-distribution.md) |
| Desktop | KDE Plasma 6.6, Wayland only | [ADR-002](../architecture/decisions/ADR-002-desktop-environment.md) |
| Boot / encryption | Shim + Ubuntu-signed GRUB, **unencrypted /boot**, one LUKS2 (Argon2id) container, recovery-key slot, TPM deferred | [ADR-003](../architecture/decisions/ADR-003-boot-and-encryption.md) |
| Storage | ESP / boot / recovery / LUKS2 → Btrfs subvolumes. `@home` and `@cheena-data` preserved. Fail-closed identity | [ADR-004](../architecture/decisions/ADR-004-storage-layout.md) |
| Installer | Calamares for fresh installs. A **separate `cheena-reinstall` tool** for keep-data repair | [ADR-005](../architecture/decisions/ADR-005-installer.md) |
| Updates | apt (Ubuntu + signed CHEENA repo) + Flatpak. Snapshot before update. No Snap (pending decision) | [ADR-006](../architecture/decisions/ADR-006-updates-and-packaging.md) |

## 4. Important findings from research
1. Ubuntu 26.04 signed GRUB can't unlock Argon2 LUKS2, and Ubuntu doesn't support GRUB-unlocked `/boot` [S4]. This drove ADR-003.
2. Kubuntu flavour support ends **April 2029**, while Ubuntu's ends April 2031. KDE packages live in universe [S2][S14]. New risk R-16.
3. Community reports say Calamares fails if `@`/`@home` already exist [S9]. That is why Safe Reinstall is a separate tool (R-17).
4. Ubuntu 26.04 desktop needs 6 GB RAM and 25 GB of disk [S1]. Set CHEENA's minimum specs at or above this (M-01).
5. A standard GitHub runner lists 14 GB SSD [S13]. Image builds will need disk reclaiming or a larger runner.

## 5. Unresolved decisions (owner)
1. ~~Build host~~: **decided 2026-11-09: GitHub Actions.** Constraints are in build-environment.md §2a. Follow-ups: repo private or public, and the budget
2. Licence for CHEENA code (M-03)
3. Ubuntu vs Debian 13 given R-16, and whether to use Ubuntu Pro
4. Snap removal and the Firefox source (ADR-006)
5. Dual-boot out of v1 scope (proposed: yes, out of scope)
6. Test hardware for AMD/NVIDIA (R-05)
7. Signing-key custody and apt repo hosting (M-05)
8. Accept the evil-maid limitation for v1 (R-18)
9. v1 scope of the five modules (architecture overview §3)

## 6. Files created or changed
- `CLAUDE.md` (new)
- `docs/references.md` (new)
- `docs/phase0/PHASE0_FINDINGS_AND_PLAN.md` (created in the planning turn; one statement corrected after research)
- `docs/phase0/PHASE0_REPORT.md` (this file)
- `docs/architecture/architecture-overview.md`, `storage-and-encryption.md`, `installer-and-recovery.md`, `update-and-rollback.md`
- `docs/architecture/decisions/README.md`, `ADR-001` … `ADR-006`
- `docs/security/threat-model.md`, `risk-register.md`
- `docs/testing/test-strategy.md`, `hardware-matrix.md`
- `docs/operations/build-environment.md`, `build-and-release.md`

## 7. Tests and checks run
- Read-only repository and host inspection only.
- Web research on official sources. Some sources are secondary or community-grade and are labelled as such.
- **No build, boot, install, encryption or storage test was run.** None is claimed.

## 8. Blockers
- No build host capable of producing an ISO (R-06).
- Owner decisions 1–3 above are needed before Phase 1a.

## 9. Exact next task: Phase 1a (after approval and a build-host decision)
> "Implement the minimal reproducible image build foundation on the approved build host.
> Steps: (a) add the build configuration for the two candidate tools (live-build and mkosi) targeting Ubuntu 26.04 with a minimal KDE Plasma package set and CHEENA os-release branding; (b) build both, record build time, size and reproducibility (two builds plus diffoscope); (c) produce the ISO, SHA256, build-info and SBOM; (d) boot the ISO in QEMU/OVMF with Secure Boot off and on, if KVM is available; (e) write ADR-007 choosing the tool.
> Do not alter host disks. Do not claim hardware support. Report the exact evidence."

**GitHub Actions specifics (build host decided):**
- One workflow, `.github/workflows/image-build.yml`, triggered **manually** (`workflow_dispatch`) so it doesn't burn minutes on every push.
- Steps: reclaim runner disk, then build, then boot-test in QEMU (KVM if `/dev/kvm` works, otherwise TCG with a longer timeout, recorded honestly), then upload **evidence only** (under 500 MB).
- Before the first build, a cheap "capability probe" job records free disk, CPU, RAM and `/dev/kvm` availability as evidence.
- Getting the workflow onto GitHub requires a **commit and push of a branch**, which needs the owner's explicit approval. No merge to `main` and no Release.

Then Phase 1b: the storage/rollback/boot-chain proof of concept on virtual disks, which decides ADR-001/003/004.

## Phase 0 exit checklist (master workflow §15)
- [x] Repository audited
- [x] Session environment audited (the cloud environment was not used. Noted)
- [x] Architecture candidates and risks documented
- [x] No existing work destroyed
- [x] Next implementation task clearly defined
- [ ] Owner approval of the ADRs: **pending**
