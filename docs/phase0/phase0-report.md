# Phase 0 report: repository and feasibility audit

Date: 10 November 2026
Branch: `phase0/audit-redo`
Scope: master workflow section 11, Phase 0 only. Documents were written; nothing was built, installed or tested.

## 1. Repository state

- Remote: `github.com/mudassirjutt777-oss/CHEENA-OS`.
- `main` holds two commits: a README and the master workflow file.
- A remote branch, `phase1a/image-build`, is three commits ahead of `main`. It holds an earlier Phase 0 document set and Phase 1a build scripts with a GitHub Actions workflow. The same commits are checked out in a local worktree under `.claude/worktrees/`.
- At the owner's request this audit was **redone from scratch** on a new branch from `main`. The earlier branch and worktree were not modified. Only its report file was read; its decision records and scripts were not used.
- No fetch from the remote was run, so remote state is as last known locally.

Two Phase 0 document sets now exist. Several file paths are the same on both branches (for example `docs/security/threat-model.md`), so they will conflict if both are merged. See decision 1 below.

## 2. Environment

The audit ran on the owner's Windows PC, not in Claude Code Cloud. Measurements are in [build-and-release.md](../operations/build-and-release.md). In short: 4 cores, 7.8 GB RAM, 20.3 GB free disk, not elevated, no VM or container tooling. It can edit and unit-test. It cannot build or boot an ISO or run disk tests.

A Claude Code Cloud session was not inspected. Its capabilities (root, loop devices, KVM) are unknown and must be probed when first used.

## 3. Recommended architecture

All items are proposals awaiting owner approval. Details and trade-offs are in the [architecture overview](../architecture/architecture-overview.md) and the [decision records](../architecture/decisions/README.md).

| Area | Recommendation |
|---|---|
| Base | Ubuntu 26.04 LTS archive, with Debian 13 kept buildable as a fallback |
| Desktop | KDE Plasma 6.6 on Wayland, with a CHEENA theme, panel, launcher and Control Center on top |
| Boot | UEFI only; shim and the distribution's signed GRUB; `/boot` unencrypted |
| Storage | One LUKS2 vault (passphrase plus generated recovery key) containing Btrfs subvolumes; `@home` and `@data` preserved on reinstall |
| Installer | Calamares for fresh installs; a separate fail-closed tool for Safe Reinstall |
| Updates | Signed apt plus Flatpak; Btrfs snapshot before each update |
| Build | Scripted ISO build and QEMU boot test on GitHub Actions |

## 4. Findings that shaped the design

1. **Encrypted `/boot` is not practical on this base.** Ubuntu 26.04's signed GRUB is reported to reject Argon2 LUKS2 keyslots [R8]. The design keeps `/boot` outside the vault and accepts an evil-maid limitation for now.
2. **KDE support is shorter than base support.** Kubuntu 26.04 is supported to April 2029; the Ubuntu base to April 2031 [R1][R3].
3. **Trademark policy is a release risk.** Canonical's policy restricts use of its trademarks on modified versions [R14]. Legal advice is needed. The earlier report did not list this.
4. **Calamares is not suited to keep-data reinstall.** Community reports describe failures with existing `@`/`@home` subvolumes and opened LUKS volumes [R10]. Safe Reinstall is designed as its own tool.
5. **Rollback with a separate `/boot` is the hardest technical problem.** Kernel files and the system snapshot must stay matched. Test this first.
6. **Fedora's image-based model fits rollback best** [R6][R7] but its ~13-month lifecycle [R5] rules it out for a small team.
7. **CI limits.** Standard GitHub runners have a 14 GB disk; KVM availability is not documented [R13].

Evidence quality varies. [references.md](../references.md) grades each source and lists what could not be confirmed.

## 5. Decisions needed from the owner

1. **Which Phase 0 is the baseline**: this branch, the earlier `phase1a/image-build` branch, or a merge of the two.
2. Approve or change ADRs 0001 to 0006.
3. Ubuntu or Debian, in light of findings 2 and 3; whether to seek legal advice now.
4. Accept the unverified-initramfs limitation for the first release (threat S-02).
5. Remove Snap (ADR 0005).
6. Repository public or private (affects CI size and cost).
7. Licence for CHEENA's own code.
8. Signing key custody and package repository hosting.
9. Test hardware: a spare machine for install tests, and access to AMD and NVIDIA systems.
10. First-release scope of the five modules (table in the architecture overview).

## 6. Implementation plan

Each step is one branch and one pull request. No step starts before the one above it has evidence.

| Step | Goal | Done when |
|---|---|---|
| 1a | Minimal reproducible live ISO in CI | ISO builds from a tagged commit; checksum, package list and SBOM recorded; boots to a serial marker in QEMU with OVMF |
| 1b | Storage and rollback proof of concept on virtual disks | The eight tests in ADR 0003 pass; ADR 0003 and 0005 accepted or revised |
| 2 | Desktop baseline | Plasma session with CHEENA theme, panel and launcher; idle memory measured; first real-hardware boot |
| 3 | Control Center, search, update manager, health | Settings persist; update with snapshot and rollback tested |
| 4 | Vault setup and recovery-key flow | Encryption tests pass; no secret in logs |
| 5 | Calamares fresh install and Safe Reinstall tool | Checksum-verified data preservation; all refusal cases pass |
| 6 | Recovery environment, backup and restore | Data export from an unbootable system; restore verified |
| 7 | Application restore | Manifest plus two app adapters, with launch checks |
| 8 | Optional AI behind a permission manager | AI-off test passes; read-only assistant only |
| 9 | Hardening, licence and SBOM review, compatibility matrix | No unexplained critical issue; independent review planned |
| 10 | Release candidate | Full acceptance suite with records |

Step 1b comes before any desktop work because it decides whether the storage design stands.

## 7. Files created

- `docs/references.md`
- `docs/architecture/architecture-overview.md`
- `docs/architecture/decisions/README.md` and `0001` to `0006`
- `docs/security/threat-model.md`, `docs/security/risk-register.md`
- `docs/testing/test-strategy.md`
- `docs/operations/build-and-release.md` (includes environment, licensing obligations and SBOM approach)
- `docs/phase0/phase0-report.md` (this file)

No existing file was changed. No `CLAUDE.md` was created; that is a small follow-up once the baseline branch is chosen.

## 8. Checks run

- Read-only inspection of the repository and the host PC.
- Web research; two official pages read in full (Ubuntu release notes, GitHub runners), one flavour page (Kubuntu), the rest through search summaries.
- Internal link check across the new documents.
- **No build, boot, install, encryption, storage or security test was run, and none is claimed.**

## 9. Blockers

- Owner decision 1 (baseline branch) blocks Phase 1.
- No local build capability; all build evidence depends on CI.
- No test hardware beyond the owner's working PC.

## 10. Exact next task

After decisions 1, 2 and 6:

> "Phase 1a only. On a new branch, implement the minimal reproducible live ISO build described in ADR 0006 as a manually triggered GitHub Actions workflow: capability probe, disk reclaim, root filesystem from a pinned archive snapshot with a minimal Plasma package list, CHEENA os-release, UEFI ISO assembly with the archive's shim and signed GRUB, SHA-256, build info, package list and SBOM, then a QEMU/OVMF boot test that waits for a serial marker. Upload evidence only. Do not touch host disks, publish a release or merge. Report exact evidence and every failure."

If the owner keeps the earlier branch as baseline instead, the next task is to review its existing Phase 1a workflow against ADR 0006 and run it.

## Exit checklist (master workflow section 15)

- [x] Repository audited
- [x] Environment audited (owner's PC; cloud environment not used)
- [x] Architecture candidates and risks documented
- [x] No existing work destroyed
- [x] Next task defined
- [ ] Owner approval: pending
