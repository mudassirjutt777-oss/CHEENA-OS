# Build and release

Status: plan only, 10 November 2026. No image has been built.

## Environment measured in this audit

The audit ran on the owner's PC, not in Claude Code Cloud.

| Item | Value |
|---|---|
| OS | Windows 11 Pro 10.0.26200, 64-bit |
| CPU | Intel Core i5-10310U, 4 cores / 8 threads |
| RAM | 7.8 GB |
| Free disk | 20.3 GB on C: |
| Privileges | Not elevated |
| Virtualization | A hypervisor is active (Windows features); no QEMU, VirtualBox, VMware or Docker installed |
| WSL | WSL 2 present; the only distribution is unrelated to this project and was not started |
| Tools found | git, Python, Node.js |
| Tools missing | gh, xorriso, 7z, make, cmake, Rust toolchain, Docker, Podman |
| Network | Outbound web access works |

Conclusion: this machine can edit documents and scripts and run unit tests. It cannot build or boot an ISO, or run loop-device, chroot or disk tests.

## Build pipeline (proposed, see [ADR 0006](../architecture/decisions/0006-image-build-tooling.md))

Manually triggered GitHub Actions workflow:

1. **Probe**: record CPU, RAM, free disk, kernel and whether `/dev/kvm` is usable.
2. **Prepare**: free runner disk space; install build tools from the runner's own archive.
3. **Build root filesystem** from a pinned archive snapshot date with the package list in the repo.
4. **Apply CHEENA overlay**: os-release, branding, default settings, CHEENA packages.
5. **Assemble ISO** with shim and signed GRUB from the archive.
6. **Record**: SHA-256, build info (commit, archive snapshot, tool versions), installed package list, SBOM.
7. **Boot test** in QEMU with OVMF.
8. **Upload evidence**. Upload the ISO only when asked.

The workflow never touches a real disk and never publishes a release.

## Reproducibility

- Archive snapshot date, `SOURCE_DATE_EPOCH` and package list are committed.
- Third-party Actions are pinned by commit hash.
- Two builds of the same commit are compared; differences are investigated before a release.

## Licensing obligations

CHEENA will redistribute thousands of upstream packages. The main obligations:

| Obligation | How it is met |
|---|---|
| GPL and LGPL source availability (kernel is GPL-2.0-only) | Each release records the exact archive snapshot and source package versions; CHEENA hosts or mirrors corresponding source for the release, or includes a written offer. Relying only on the upstream archive is not enough once the archive moves on |
| Copyright notices and licence texts | Kept in `/usr/share/doc/*/copyright` as shipped by packages; not stripped from the image |
| CHEENA's own code | Licence to be chosen by the owner; every file carries an SPDX identifier; licence texts in `LICENSES/` |
| Trademarks of the base distribution | See risk K-05. Remove base-distribution branding from the image; get legal advice on Canonical's policy [R14] |
| Fonts, icons, themes, wallpapers | Only assets with a recorded licence; no Windows or macOS assets |
| Firmware, codecs, GPU drivers | Many are non-free or patent-encumbered. Inventory each; decide per item whether to ship, offer at install, or omit |
| Flatpak apps | Distributed by their remote, not by CHEENA, unless preinstalled. Preinstalled apps enter the inventory |

This is an engineering summary, not legal advice. A licence review is required before public release.

## SBOM approach

- **Source of truth:** the package database of the built image (`dpkg-query` with name, version, architecture, source package), plus the Flatpak list. This is exact and needs no extra tool.
- **Format:** convert to SPDX or CycloneDX JSON with an established generator (Syft is the likely choice; evaluate at Phase 1) and attach to every build.
- **Licence data:** extracted from each package's machine-readable `copyright` file where present; gaps listed for manual review.
- **CHEENA code:** language lockfiles feed the same SBOM.
- **Use:** vulnerability scan per build; diff between releases to see what changed.

## Release process (later phases)

1. Feature freeze and full acceptance suite.
2. Release candidate built from a tag.
3. Evidence bundle reviewed.
4. Owner approval.
5. Signing with the release key, outside CI.
6. Publish ISO, checksums, signature, SBOM, source location, release notes and known issues.

No merge to `main` and no publication without owner approval.
