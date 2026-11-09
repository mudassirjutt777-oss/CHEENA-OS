# ADR 0006: Image build tooling and build host

Status: **Proposed** (tool choice to be confirmed by a build spike in Phase 1)
Date: 10 November 2026

## Decision

- **Build host:** GitHub Actions standard Linux runner, triggered manually.
- **Build tool:** a short, explicit script: `mmdebstrap` (or `debootstrap`) to make the root filesystem, `mksquashfs` to pack it, `xorriso` with shim and signed GRUB from the archive to assemble a UEFI-bootable ISO. Compare against `live-build` in a one-off spike before locking.

## Why not build locally

The owner's PC, measured on 10 November 2026: Windows 11 Pro, Intel i5-10310U (4 cores), 7.8 GB RAM, 20.3 GB free disk, session not elevated, no Docker, QEMU, VirtualBox or ISO tools, and no usable Linux WSL distribution. A desktop image build needs tens of GB of scratch space and root-level operations (loop devices, chroot). This machine cannot do it without installing software and freeing disk, which is outside Phase 0.

## Why GitHub Actions

- Free minutes for public repositories; fresh VM for each job with root access.
- Standard Linux x64 runner: 4 CPU / 16 GB RAM for public repos, 2 CPU / 8 GB for private, both with a 14 GB SSD [R13].
- The reference page says Linux runners support hardware acceleration for Android tools [R13], which suggests KVM is available, but it does not say so directly.

Constraints this creates:

- **14 GB disk** is tight. The workflow must remove preinstalled toolchains first and record free space.
- **KVM is unconfirmed.** A probe step checks `/dev/kvm`. Without it the boot test runs in software emulation with a longer timeout and says so in the evidence.
- **Artifacts** are the ISO checksum, build info, package list, SBOM and boot log. The ISO itself is kept only when needed.
- Whether the repository is public or private changes runner size and cost. Owner decision.

## Why a plain script over live-build

- Ubuntu's own image pipeline has moved ISO assembly out of live-build [R15], and a bug report says live-build on 26.04 still expects `grub-legacy` [R16, grade C]. Depending on it means carrying workarounds.
- An explicit script is easier to audit for reproducibility: pinned archive snapshot date, fixed `SOURCE_DATE_EPOCH`, sorted file lists.
- The cost is that CHEENA owns more boot-assembly detail. The spike decides whether that cost is real.

`mkosi` and `ubuntu-image` were not evaluated in depth; no current source on their fit for a classic live desktop ISO was found.

## Reproducibility target

Two builds from the same commit and the same archive snapshot date produce the same package list and, as a stretch goal, the same ISO checksum. Differences are investigated with `diffoscope`.

## Relationship to existing work

Branch `phase1a/image-build` on the remote already contains build scripts and a workflow from an earlier session. This ADR was written without relying on them. Before Phase 1 starts, the owner chooses whether to continue that branch, replace it, or merge the two.
