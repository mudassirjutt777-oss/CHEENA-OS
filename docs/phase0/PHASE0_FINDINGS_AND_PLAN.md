# CHEENA OS — Phase 0 Findings, Gap Analysis and Implementation Plan

Status: **DRAFT FOR APPROVAL. Nothing in here has been built yet.**
Prepared: 9 November 2026
Source document: `CHEENA_OS_Master_Engineering_Workflow_2026-11-09.txt` (all 1,080 lines read)
Method: I read the master workflow, inspected the repository, and ran read-only commands on the host machine. I installed nothing, changed no system settings, and ran nothing that needs admin rights or touches a disk.

How to read the labels:
- **[Observed]** — I checked this directly in this session.
- **[Known]** — Established upstream fact that I'm confident about. Phase 0 will still cite a primary source for it in an ADR.
- **[To verify]** — Plausible, but not confirmed. It must be checked against official documentation before anyone relies on it.

---

## 1. Executive summary

1. The vision is coherent and responsibly scoped. It's a KDE-based Linux distribution, not a new kernel, and the honesty rules are already strong. The requirements are good. The plan has a few real technical gaps (section 4) and one major environment mismatch (section 2.2).
2. **Biggest architectural question:** the data-first requirements fit an image-based (atomic) OS better than a traditional apt-based one. Those requirements are verified rollback, Safe Reinstall, a clean split between system and data, and signed system images. Ubuntu 26.04 + apt + Btrfs snapshots can meet them, but needs much more custom engineering. This has to be settled in ADR-001 with a proof of concept, not assumed. See section 3.
3. **Biggest technical trap I found:** Ubuntu 26.04's signed GRUB cannot unlock LUKS2 keyslots that use Argon2id. Upstream GRUB 2.14 added Argon2, but Ubuntu's signed build lacks it, and Ubuntu doesn't support GRUB-unlocked `/boot` at all **[Verified in research: see `docs/references.md` S4, S5]**. The encrypted layout the document hints at needs a decision here: an unencrypted `/boot` (with UKI or signed kernels) or PBKDF2 keyslots. Choosing wrong breaks booting or weakens the encryption.
4. **Biggest practical blocker:** this machine can't currently build or boot-test an ISO. It has 18.3 GB of free disk, 7.8 GB of RAM, no admin rights, and no QEMU or VirtualBox. Phase 1 needs a Linux build environment decision (section 2.3).
5. Phase 0 itself is documentation and research only. I propose 12 bounded tasks (section 6) that deliver the five documents the master workflow requires, plus ADRs, a risk register and a hardware matrix.

---

## 2. Repository and environment audit

### 2.1 Repository [Observed]
| Item | State |
|---|---|
| Remote | `github.com/mudassirjutt777-oss/CHEENA-OS` |
| Commits | 2 (`Initial commit`, `Add files via upload`) |
| Files | `README.md` (1 line), master workflow `.txt` |
| Code / build config / licence / CLAUDE.md | **None** |
| Working copy | Git worktree `cheena-os-repo-0c30da` on the user's Windows laptop |

There's no existing work at risk. There's also **no LICENSE file**, which blocks any public distribution (see M-03 in section 4).

### 2.2 Environment mismatch [Observed]
The master workflow assumes **Claude Code Cloud** (a Linux VM). This session actually runs in **Claude Code desktop on the user's own Windows 11 laptop**. That matters because:
- Any command I run here affects the user's real, daily-use PC. The workflow's safety rules (section 5.4) are therefore *more* important here, not less.
- Linux-only tooling isn't available directly: `debootstrap`, `live-build`, `mkosi`, `xorriso`, loop devices, `chroot`, `cryptsetup`.
- Decision needed: continue locally, move build work to Claude Code Cloud or GitHub Actions, or both (section 2.3).

### 2.3 Host capability [Observed]
| Capability | Result | Impact |
|---|---|---|
| Machine | HP EliteBook 840 G7, Intel Core i5-10310U (4C/8T), UEFI firmware | Good candidate for an *Intel-only* physical test device |
| RAM | 7.8 GB | Tight. A KDE guest VM needs about 4 GB, leaving about 4 GB for Windows plus the build |
| Free disk | **18.3 GB of 237 GB** on C: | **Blocker.** An Ubuntu-based ISO build typically needs 20–40 GB of working space. A test VM disk needs 25+ GB |
| Admin rights | **No** | Can't enable features, install hypervisors, or read the TPM, Secure Boot or BitLocker state |
| Hypervisor | Present (Hyper-V/WSL2 layer active) | Hyper-V VMs may be possible but need admin |
| WSL2 | One distro, `ContentPilotVPN` (stopped), unrelated to this project | A dedicated Ubuntu WSL2 instance could build images, but would also need disk space |
| QEMU / VirtualBox / Docker / Podman | Not found | No local VM boot testing today |
| Git / Python | Git ✓, Python 3.15 ✓ | Fine for docs and tooling |
| TPM / Secure Boot / BitLocker | **Unknown** (needs admin) | Must be known before any boot-related testing on this laptop |

**Build-environment options for Phase 1 (decision needed):**
- **A. GitHub Actions** (recommended starting point). A free Ubuntu runner has limited free disk, so space has to be reclaimed or a larger runner used **[To verify current limits]**. Builds are reproducible and logged, and nothing touches the laptop. No KVM boot test on a standard runner **[To verify]**.
- **B. Claude Code Cloud VM.** As the workflow intended, but its privileges (loop devices, chroot, KVM) must be audited first.
- **C. Dedicated Linux machine or external SSD.** The most capable option for both builds and VM boot tests.
- **D. This laptop.** Only realistic after freeing disk space plus admin installation of a hypervisor. Not recommended as the primary build host.

### 2.4 Physical test device assessment — HP EliteBook 840 G7 [Observed devices]
| Component | Detected | Expected Linux status |
|---|---|---|
| CPU / GPU | i5-10310U / Intel UHD (Comet Lake) | Generally well supported by mainline kernel i915 **[Known]** |
| Wi-Fi | Intel Wi-Fi 6 AX200 | iwlwifi supported since kernel 5.1 **[Known]**; needs linux-firmware |
| Bluetooth | Intel Wireless Bluetooth | Usually works with btintel + firmware **[To verify on device]** |
| Audio | Realtek codec + Intel Smart Sound Technology | Needs SOF firmware. Microphones are the common failure point **[To verify on device]** |
| Fingerprint | Synaptics FS7605 | **Likely unsupported** by libfprint. Must be tested, never promised **[To verify]** |
| Camera | HP HD Camera | Probably UVC and supported **[To verify]** |
| Storage | Toshiba KBG30 256 GB NVMe | Supported **[Known]** |

**Rule I'll follow:** this laptop is the user's working Windows PC. Testing on it means **booting a live USB only** (read-only to the internal disk). There will be no installs, partitioning or Secure Boot changes without explicit approval. Before *any* firmware or Secure Boot change, the user must have their **BitLocker recovery key** saved, because firmware changes can trigger BitLocker recovery. This PC alone also gives **zero coverage** of AMD or NVIDIA hardware.

---

## 3. Architecture analysis

### 3.1 Proposed baseline (from the workflow) and my assessment
| Layer | Workflow candidate | Assessment |
|---|---|---|
| Base | Ubuntu 26.04 LTS | Sound default: LTS lifecycle, hardware enablement, signed kernels and shim for Secure Boot. **Concern:** Ubuntu ships Firefox and other components as **Snaps** **[Known]**, which conflicts with the "one package policy" rule and a Flatpak strategy. A Snap policy has to be decided explicitly |
| Desktop | KDE Plasma (Wayland) | Strong choice: configurable, Qt/QML fits the CHEENA apps (Control Center modules as KCMs, KRunner plugins for search). Kubuntu exists as a reference. NVIDIA on Wayland still needs a separate test track |
| Installer | Ubuntu installer stack or Calamares | Calamares fits better: LUKS, LUKS2 and Btrfs subvolumes, KDE integration, used by Debian live images **[Known]**. Ubuntu's Flutter installer is GNOME-oriented, and its Btrfs-subvolume support is **[To verify]**. **Neither has a Safe Reinstall feature**: a custom Calamares module plus a separate storage-detection service will be needed |
| Encryption | LUKS2 | Correct. **Boot chain conflict:** GRUB can't open Argon2id keyslots **[Known]**. Options: (a) unencrypted `/boot` with signed kernel and initramfs; (b) PBKDF2 keyslots (weaker); (c) systemd-boot with UKIs (diverges from Ubuntu's supported GRUB/shim path). Needs an ADR |
| Filesystem | Btrfs subvolumes + snapshots | Workable. Snapper/grub-btrfs on Ubuntu are community-maintained, not Canonical-supported **[To verify]**. Kernel/initramfs version skew between `/boot` and a rolled-back root is a classic failure mode. Disk-full behaviour on Btrfs needs testing |
| Updates | "supported upstream mechanism" | Underspecified. Who hosts the CHEENA apt repository, signs it, mirrors it and handles security embargoes? |
| Languages | Python / Rust / QML | Reasonable. Privileged services need a clear D-Bus + polkit boundary |

### 3.2 The key decision: package-based vs image-based
| | **Option A — Ubuntu 26.04 + apt + Btrfs/snapper** | **Option B — Image-based (e.g. Fedora Kinoite/bootc-style)** |
|---|---|---|
| Rollback | Snapshot-based. Needs careful `/boot` handling | Built-in atomic A/B deployments **[Known for rpm-ostree/bootc]** |
| Safe Reinstall | Custom: identify the data subvolume, recreate the system subvolume | Simpler: system is a replaceable image, user data is separate by design |
| Signed images | apt repo signing, plus image signing to add | Native container/OSTree signing **[To verify for bootc]** |
| Support lifecycle | ~5 years LTS **[Known]** | Fedora ~13 months per release **[Known]**: faster churn |
| Packaging familiarity | Very high (deb) | Lower; app delivery mostly via Flatpak |
| KDE | Kubuntu reference exists | Fedora KDE / Kinoite reference exists |
| Engineering load for data-first features | **Higher** | **Lower** |

**Recommendation for ADR-001:** keep Ubuntu 26.04 LTS as the leading candidate, as the workflow directs. But make the Phase 0 comparison *specifically* score each option against Safe Reinstall, verified rollback and signed images, not just popularity. Debian 13 is the conservative third option (Calamares-native, very stable, slower hardware enablement). **Don't lock the base until the storage/rollback proof of concept (Phase 1b, section 7) passes.**

### 3.3 Candidate storage layout (to validate, not to implement)
```
GPT
├─ ESP          FAT32  ~1 GB    (shim/GRUB or UKIs)
├─ /boot        ext4   ~2 GB    unencrypted, signed kernels (if GRUB path chosen)
├─ RECOVERY     ~3–4 GB         CHEENA recovery environment (read-only image)
└─ LUKS2 (Argon2id)  "cheena-vault"
   └─ Btrfs
      ├─ @            system root      ← replaced on Safe Reinstall
      ├─ @home        user data        ← NEVER formatted on Safe Reinstall
      ├─ @snapshots   system snapshots
      ├─ @var_log, @cache, @tmp  excluded from snapshots
      └─ @cheena-state  app-restore manifest + install metadata (with UUID marker)
```
- **One container (above):** gives one storage pool, matching the "one main storage space" requirement. Safe Reinstall must then recreate `@` *inside* an unlocked container: high stakes, needs fail-closed identification (UUID + marker file + label + signature).
- **Two containers (system / data):** reinstall can wipe the system container without touching data, which is safer. Cost: fixed split, which contradicts the single-pool UX.
- My lean is one container plus strict identification, but this **must** be decided by testing in Phases 4 and 5.

---

## 4. Missing or underspecified requirements

| ID | Gap | Why it matters | Decision owner |
|---|---|---|---|
| M-01 | **Supported hardware definition:** x86_64 only? Minimum RAM/CPU/disk? UEFI-only? | Drives every test matrix and installer check | User |
| M-02 | **Test hardware inventory:** which physical AMD/NVIDIA/Intel machines exist? | Without them, nothing beyond Intel can be claimed | User |
| M-03 | **Licence for CHEENA's own code** (GPL-3.0 / Apache-2.0 / MIT …) | Calamares modules are GPL-3.0 **[Known]**; KDE components carry their own licences; affects distribution | User (legal) |
| M-04 | **"CHEENA" trademark/name clearance** | Avoid forced renaming later | User |
| M-05 | **Repository/update hosting and signing-key custody** (HSM? offline key? who signs?) | The core of "signed updates"; can't live in the repo | User + architect |
| M-06 | **Snap policy** (keep, remove, or replace with Flatpak/deb) | Ubuntu base ships Snaps; conflicts with "one package policy" | Architect → user approval |
| M-07 | **Proprietary drivers/firmware/codecs policy** (NVIDIA, Wi-Fi firmware, multimedia) | Licensing, Secure Boot MOK enrolment, UX | User |
| M-08 | **Release channels and cadence** (stable/beta, point releases, HWE kernels) | Update design and support burden | User |
| M-09 | **Supported languages/locales for v1** and an accessibility target (e.g. a WCAG 2.2 level for CHEENA apps) | Workflow says accessibility "from the beginning" but sets no target | User |
| M-10 | **Telemetry and crash reporting decision** (default: none) | Workflow requires documented fields if any | User |
| M-11 | **Backup targets:** which cloud providers, if any, in v1? | Scope of the Phase 6 backup work | User |
| M-12 | **Recovery-key UX:** print/QR/USB export, re-verification flow | Highest-impact user decision in the product | Architect → user |
| M-13 | **TPM2 unlock in v1: yes or deferred?** | Interacts with Secure Boot, BitLocker-style recovery prompts, firmware updates | User |
| M-14 | **Dual-boot with Windows: supported in v1 or not?** | Changes installer risk profile drastically (BitLocker, shared ESP) | User |
| M-15 | **Brand assets** (logo, typeface licence, colours) | Phase 2 can't start without them | User |
| M-16 | **CI/build infrastructure and budget** (runner sizes, storage for ISOs, artifact retention) | See section 2.3 | User |
| M-17 | **Team and review model:** who reviews PRs, who approves releases, security reviewer? | Workflow requires independent review before stable | User |
| M-18 | **Data retention for logs and AI history** (durations, defaults) | Privacy-by-design needs numbers | Architect → user |
| M-19 | **IPC and privilege model for CHEENA services** (D-Bus + polkit, sandboxing of AI service) | Security boundary for all five modules | Architect (ADR) |
| M-20 | **Definition of the "five modules" for v1 specifically:** which subset of each is MVP | Section 7 MVP lists them only partially (e.g. Self-Healing = tested rollback only) | User + architect |
| M-21 | **Upgrade path between CHEENA releases** (e.g. 26.04-based → 28.04-based) | Not covered anywhere | Architect |
| M-22 | **Export controls / crypto notices** for distributing encryption software | Legal check before public release **[To verify]** | User (legal) |

---

## 5. Risk register (initial)

Likelihood (L) and Impact (I): H/M/L.

| ID | Risk | L | I | Mitigation |
|---|---|---|---|---|
| R-01 | Safe Reinstall misidentifies the data volume and erases user data | M | **H** | Fail-closed multi-factor identification; destructive-path separation; tests on disposable virtual disks only; release blocker |
| R-02 | GRUB / LUKS2 Argon2id incompatibility leaves systems unbootable | H if ignored | H | ADR on boot chain before Phase 4; boot test in VM for every layout change |
| R-03 | Snapshot rollback leaves kernel/initramfs mismatched with root | M | H | Keep kernels inside snapshot scope or version-pin `/boot`; simulated failed-update tests |
| R-04 | Recovery key lost → permanent data loss | M | H | Mandatory key export + verification step in setup; clear warnings |
| R-05 | No access to AMD/NVIDIA hardware → false compatibility claims | H | M | Publish a hardware matrix with only tested entries; community test program later |
| R-06 | Build environment insufficient (disk, privileges, no KVM) | **H (observed)** | M | Decide build host before Phase 1 (section 2.3) |
| R-07 | Testing on the user's daily laptop damages Windows/BitLocker state | L | **H** | Live-USB only; BitLocker key saved first; no firmware changes without approval |
| R-08 | Snap/Flatpak/apt mixing creates conflicting updates | M | M | ADR on package policy (M-06) |
| R-09 | Upstream changes (Ubuntu installer, Plasma, Calamares) break CHEENA customisations | M | M | Minimise patches; pin versions per release; upstream-first contributions |
| R-10 | Scope creep (AI, connectivity, app store) delays a working base | H | H | Enforce section 7 MVP; AI at Phase 8 only |
| R-11 | Signing key compromise or loss | L | H | Offline/HSM keys, separate dev/test/release keys, rotation plan |
| R-12 | Licence non-compliance (GPL source offers, fonts, codecs, firmware) | M | H | SBOM + licence inventory from Phase 1 |
| R-13 | AI component prompt injection or privilege escalation | M | H | Phase 8 threat model; no root; polkit-gated actions; audit log |
| R-14 | Single-person project → no independent review | H | M | Define reviewer model (M-17); external security review before stable |
| R-15 | Fingerprint/audio/mic issues on test laptop misread as CHEENA bugs | M | L | Separate "upstream hardware limitation" category in test reports |

---

## 6. Phase 0 implementation plan (requires approval)

All tasks: documentation and read-only research only. Each produces a file under `docs/`, cites official sources, and records unknowns. One PR at the end of Phase 0 (or one per group, your choice). **No commits or pushes without your approval.**

| # | Task | Deliverable | Acceptance |
|---|---|---|---|
| P0-01 | Write `CLAUDE.md` (short; links to docs, permission boundaries, honesty rules) | `CLAUDE.md` | Under ~60 lines; matches master workflow section 5 |
| P0-02 | Environment capability report: this host + chosen build host | `docs/operations/build-environment.md` | Every capability marked observed / unknown |
| P0-03 | Base distribution comparison: Ubuntu 26.04, Debian 13, Fedora KDE/Kinoite, scored on lifecycle, Secure Boot, installer, rollback, Safe Reinstall fit, packaging, maintenance load | `docs/architecture/decisions/ADR-001-base-distribution.md` | Sources cited; recommendation + rejected alternatives |
| P0-04 | Desktop: KDE Plasma Wayland; NVIDIA/AMD/Intel caveats; CHEENA customisation surface (theme, Plasma shell layout, KCMs, KRunner) | `ADR-002-desktop-environment.md` | Lists what CHEENA builds vs reuses |
| P0-05 | Boot chain + encryption: GRUB/shim vs systemd-boot/UKI; LUKS2 KDF; TPM2 policy | `ADR-003-boot-and-encryption.md` + `docs/architecture/storage-and-encryption.md` | Explicit answer to R-02 |
| P0-06 | Storage layout: one vs two LUKS containers; subvolume naming; snapshot scope; disk-full behaviour | `ADR-004-storage-layout.md` | Trade-off table; test list for Phase 4 |
| P0-07 | Installer: Calamares vs Ubuntu installer; Safe Reinstall design sketch (fail-closed identification) | `ADR-005-installer.md` + `docs/architecture/installer-and-recovery.md` | Lists required custom modules |
| P0-08 | Update, rollback and package policy (incl. Snap decision, repo hosting, signing) | `ADR-006-updates-and-packaging.md` + `docs/architecture/update-and-rollback.md` | Answers M-05, M-06 as proposals |
| P0-09 | Architecture overview (components, boundaries, D-Bus/polkit model, the five modules mapped to KDE integration points) | `docs/architecture/architecture-overview.md` | One diagram; each module has a v1 scope line |
| P0-10 | Initial threat model (installer, storage, updates, recovery, AI placeholder) | `docs/security/threat-model.md` | STRIDE-style table; AI marked deferred |
| P0-11 | Test strategy + hardware/VM matrix + release-acceptance skeleton | `docs/testing/test-strategy.md`, `hardware-matrix.md` | Matches section 9 test levels; EliteBook entry from section 2.4 |
| P0-12 | Build & release, licensing and SBOM approach (e.g. SPDX/CycloneDX tooling), risk register | `docs/operations/build-and-release.md`, `docs/security/risk-register.md` | Covers GPL source obligations; R-01…R-15 carried over |

**Phase 0 exit gate:** all five deliverables required by the master workflow exist, every decision has sources, unknowns are listed, and the next task (Phase 1a) is defined precisely.

What I need to research online during P0-03…P0-08 (official docs only): Ubuntu 26.04 release notes and lifecycle, Kubuntu/Calamares installer status, Calamares LUKS2/Btrfs module docs, cryptsetup and GRUB LUKS2 support, Btrfs/snapper docs, Fedora bootc/Kinoite docs, Debian 13 release notes.

---

## 7. Development roadmap

Phases follow the master workflow. I've added two small sub-phases (1b, 4a) to retire the biggest risks early.

```
P0 Audit & ADRs ──► P1a Reproducible build ──► P1b Storage/rollback PoC ──► [LOCK BASE + LAYOUT]
                                                                             │
        ┌────────────────────────────────────────────────────────────────────┘
        ▼
P2 Desktop foundation ──► P3 Core management (Control Center, search, updates, health)
        │
        ▼
P4a Boot/encryption PoC on virtual disks ──► P4 Data Vault ──► P5 Installer + Safe Reinstall
                                                                 │
                                                                 ▼
                                    P6 Recovery/snapshots/backup ──► P7 App restoration
                                                                 │
                                                                 ▼
                                   P8 Optional AI (read-only first) ──► P9 Hardening & compatibility ──► P10 RC
```

| Phase | Goal | Gate to exit | Hard dependencies | Can run on |
|---|---|---|---|---|
| 0 | Verified plan | Section 6 exit gate | — | Here (docs only) |
| 1a | Minimal reproducible live ISO | Same inputs → same manifest; checksum; boots in VM | Build host decision (M-16) | CI / Linux host |
| **1b (new)** | Throwaway PoC: LUKS2 + Btrfs layout + snapshot rollback on a **virtual disk** | Rollback survives a simulated failed update; boot chain works | 1a, ADR-003/004 | Linux host with KVM |
| 2 | Real KDE-based CHEENA desktop | Login, apps launch, settings work, no dead controls | 1a, brand assets (M-15) | VM + EliteBook live USB |
| 3 | Manageability | Section 6 Phase 3 acceptance | 2 | VM |
| **4a (new)** | Recovery-key + wrong-password + log-scrubbing tests | All pass on disposable disks | 1b | VM |
| 4 | Data Vault | Section 6 Phase 4 acceptance | 4a | VM |
| 5 | Installer + Safe Reinstall | Fresh install + keep-data reinstall pass; ambiguous layouts refused | 4 | VM only (never a real disk) |
| 6 | Recovery & backup | Failed update recovered; data export from recovery works | 5 | VM + USB |
| 7 | App restoration (1–2 adapters) | Honest per-app status | 6 | VM |
| 8 | Optional AI | AI fully disableable; offline OS works; no root | 3 | VM |
| 9 | Hardening + compatibility | Signed updates verified; SBOM; matrix with evidence | 1–8 | VM + physical |
| 10 | Release candidate | Full acceptance suite; publish only on approval | 9 | VM + physical |

**Critical path:** build host → 1a → 1b → 4a → 4 → 5 → 6. The storage and encryption chain is where the project succeeds or fails. The desktop (2, 3) can proceed in parallel once 1a exists.

**Effort:** I won't invent durations. Each phase gets a bounded task list and estimate when it's approved, once the build host and hardware are known.

---

## 8. Decisions I need from you before implementation

1. **Approve this Phase 0 plan** (section 6), or tell me what to change.
2. **Where should builds run?** GitHub Actions / Claude Code Cloud / a dedicated Linux machine / this laptop after freeing space and admin installs (section 2.3).
3. **Licence** for CHEENA's own code (M-03).
4. **Is dual-boot with Windows in v1 scope?** (M-14). My recommendation: no, for v1.
5. **What test hardware is available** beyond this Intel EliteBook? (M-02)
6. **May I use web research** against official documentation for the ADRs? The workflow requires sources.
7. **Commit policy:** create a branch and commit Phase 0 docs as I go, or leave everything uncommitted for your review?

Other gaps in section 4 can be recorded as open questions in the ADRs. They don't block Phase 0.
