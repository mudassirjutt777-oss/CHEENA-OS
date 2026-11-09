# Build and test environment report

Status: Phase 0 audit, 9 November 2026. Every item below was checked with **read-only** commands. Items marked "Unknown" need admin rights or a different host.

## 1. Current session host (observed)

| Item | Value | Consequence |
|---|---|---|
| Host type | Owner's Windows 11 Pro laptop (10.0.26200). Claude Code desktop runs in a git worktree | This is **not** the Linux cloud VM the master workflow assumes (§5.1). Treat it as a production machine |
| Model | HP EliteBook 840 G7 | See the hardware matrix |
| CPU | Intel Core i5-10310U, 4 cores / 8 threads | Enough for builds, but slow |
| RAM | 7.8 GB | Ubuntu 26.04 desktop needs **6 GB** [S1]. A KDE guest VM and Windows can't both run comfortably |
| Free disk | **18.3 GB** of 237 GB (C:) | Below the **25 GB** that Ubuntu 26.04 desktop alone needs [S1]. **Blocker** for local image builds or VM tests |
| Firmware | UEFI | Matches the planned UEFI/GPT path |
| Admin rights | **No** | Can't install a hypervisor, enable Windows features, or read the TPM, Secure Boot or BitLocker state |
| Hypervisor layer | Present (Hyper-V/WSL2) | A Hyper-V VM might be possible with admin rights |
| WSL2 | One unrelated distro (`ContentPilotVPN`, stopped) | No Ubuntu build environment exists. Don't touch the existing distro |
| QEMU / VirtualBox / Docker / Podman / xorriso | Not installed | No local ISO creation or boot testing |
| Git / Python | Git ✓, Python 3.15 ✓ | Enough for docs and tooling scripts |
| TPM / Secure Boot / BitLocker | **Unknown** | Must be known before any physical boot testing on this laptop |

**Conclusion:** this host is suitable only for documentation, planning and non-privileged tooling. It must not be the primary build host.

## 2. Build-host options for Phase 1

| Option | Builds ISO? | VM boot test? | Cost / effort | Risk to owner's PC | Notes |
|---|---|---|---|---|---|
| **A. GitHub Actions, standard runner** | Probably, after reclaiming disk space. The official spec lists 14 GB SSD [S13], which is tight | Not reliably. KVM on standard runners is unverified | Free tier minutes | None | Good for reproducible, logged builds |
| **B. GitHub Actions, larger runner** | Yes. E.g. 150 GB on a 4-core runner [S13] | Must be verified | Paid per minute | None | Most reproducible option |
| **C. Claude Code Cloud VM** | Unknown until its privileges are audited (loop devices, chroot, KVM) | Unknown | Included with plan | None | The setup the master workflow intended |
| **D. Dedicated Linux PC or spare SSD** | Yes | Yes (KVM/QEMU) | Hardware cost | None | Best for P1b, P4 and P5 storage tests on virtual disks |
| **E. This laptop** | Only after freeing more than 40 GB and an admin installing WSL2-Ubuntu or Hyper-V | Possibly | Owner's time | **Medium** | Not recommended |

**Decision (owner, 2026-11-09): GitHub Actions is the build host for Phase 1a.**

## 2a. GitHub Actions constraints that apply to CHEENA
**Update 2026-11-10: the owner made the repository public.** The public-repo row below now applies: a 4 vCPU / 16 GB runner, with standard-runner minutes not billed. Whether the 500 MB artifact quota applies to public repositories still needs to be checked against S19. The ISO stays out of artifacts until it is.

Consequences of going public:
- Build logs and artifacts still need a GitHub login to view. The workflow therefore also publishes its key results as check-run annotations, which the public API serves without a login.
- **No licence is chosen yet (M-03).** Public code without a licence is "all rights reserved": visible, but nobody may legally reuse it. This decision is now more urgent.

The original assessment, written while the repository was private, follows:

| Constraint | Value | Source | Impact on Phase 1a |
|---|---|---|---|
| Standard Linux runner, private repo | 2 vCPU, 8 GB RAM, 14 GB SSD | [S13] | Builds are slow. Disk must be reclaimed by removing preinstalled toolchains |
| Standard Linux runner, public repo | 4 vCPU, 16 GB RAM, 14 GB SSD | [S13] | Faster, and doesn't use paid minutes |
| Included compute on GitHub Free | $12/month, about 2,000 min on a 2-core Linux runner. Usage is **blocked** when it runs out and no payment method is on file | [S19] | About 30–60 full ISO builds a month, at an estimated 30–60 min each (estimate, not measured) |
| **Artifact storage on GitHub Free** | **500 MB**, shared with Packages | [S19] | **A KDE ISO (≈3–4 GB) can't be stored as a workflow artifact.** See below |
| KVM in the runner | Hardware acceleration has been available on Linux runners since 2024. The runner user must be added to the `kvm` group in each job | [S20] | VM boot tests inside the job are **probably** possible. To be proven in the first workflow run |
| Larger runners | Paid plans only | [S13] | Not assumed |

**How Phase 1a handles the 500 MB limit:** build the ISO and **boot-test it inside the same job**. Upload only the small evidence: checksums, build-info, SBOM, boot log and a screenshot. Then discard the ISO. There are three ways to download ISOs later, all needing owner approval: make the repo public, upload to a GitHub Release (that counts as publishing), or use external object storage.

**Still the owner's to decide:** whether the repo stays private, and whether to add a payment method or spending limit.

Option D, or C if KVM is confirmed, stays the recommendation for the heavier storage tests in Phases 1b, 4 and 5 if runner time or disk proves too small.

## 3. Commands used for this audit (all read-only)
- `git remote -v`, `git log`, `ls`
- PowerShell `Get-CimInstance` (Win32_ComputerSystem, Win32_Processor, Win32_OperatingSystem, Win32_LogicalDisk, Win32_VideoController, Win32_NetworkAdapter, Win32_DiskDrive)
- `Get-PnpDevice` (Bluetooth, Biometric, Camera, Media), `wsl.exe -l -v`, `Get-Command` for each tool, `Get-ComputerInfo -Property BiosFirmwareType`

No packages were installed. No settings or files outside the repository were changed.
