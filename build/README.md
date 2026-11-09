# CHEENA OS image build (Phase 1a)

Status: **first version, not yet proven.** Results from the CI runs are recorded in `docs/phase1a/`.

| Path | Purpose |
|---|---|
| `image/config.env` | Release, pinned archive snapshot, fixed timestamp, ISO label |
| `image/packages.txt` | Smallest package set that should reach a KDE Plasma login screen |
| `image/overlay/` | Files copied into the image (casper live-session settings, boot-test marker) |
| `image/os-release.in` | CHEENA OS identity. The base-files copy is diverted, not overwritten |
| `scripts/build-iso.sh` | debootstrap → chroot → squashfs → GRUB hybrid ISO. **CI only** (needs root; refuses to run without `CHEENA_CI_BUILD=1`) |
| `scripts/boot-test.sh` | Boots the ISO in QEMU/OVMF and checks that SDDM came up. VM evidence only |
| `scripts/probe-runner.sh` | Read-only facts about the build machine |

Runs through `.github/workflows/image-build.yml` on pushes to `phase1a/**` branches. The ISO itself is **not kept**, because of the 500 MB artifact limit. Only evidence is uploaded.

## Known limitations of this first version
- This is the hand-assembled debootstrap method. The plan's second candidate tool (mkosi or live-build) is not built yet (ADR-007 is pending).
- GRUB for the ISO comes from the **runner's** Ubuntu 24.04 packages and is unsigned. **Secure Boot boot is not tested yet.**
- Calamares (the installer), CHEENA theme and CHEENA apps are not included yet.
- Reproducibility is not yet measured (needs two builds compared).
- Package names have not yet been checked against the 26.04 archive. The first run will show any that are wrong.
