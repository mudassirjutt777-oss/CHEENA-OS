# Build, release, licensing and SBOM

Status: Phase 0 draft. Nothing here has been built yet.

## 1. Image build tooling (to be decided in Phase 1a)
| Candidate | Fit | Notes |
|---|---|---|
| **live-build** (Debian/Ubuntu) | Mature live-ISO tool for deb distros | Ubuntu's own images use livecd-rootfs/ubuntu-image, so check compatibility with 26.04 |
| **mkosi** (systemd project) | Modern, declarative, reproducible, supports Ubuntu | Strong for reproducibility. The live-ISO + Calamares flow must be checked |
| Ubuntu `livecd-rootfs` | Exactly what Kubuntu uses | Heavier, closely tied to Launchpad infrastructure |

**Phase 1a task:** build the smallest bootable image with the two leading candidates on the chosen build host. Pick one by reproducibility and maintenance cost. Record the result as ADR-007.

## 2. Build principles
- Everything is declared in the repo: package manifest, configuration, hooks and pinned snapshot dates of the Ubuntu archive (via `snapshot.ubuntu.com`, availability to verify).
- Each build produces:
  - the ISO
  - SHA256 checksums
  - a build-info file (git commit, tool versions, archive snapshot date)
  - an SBOM
  - a licence report
- **Reproducibility check:** build twice, compare with diffoscope, and record the differences honestly.
- CI never holds the release signing key (ADR-006).

## 3. Release process (outline)
1. Feature freeze, then a full test suite run, then the acceptance report.
2. The owner reviews known issues and approves.
3. Offline signing of checksums and repo metadata.
4. Publishing, **only with explicit owner approval** (master workflow §5.4).

## 4. Licensing obligations
| Component class | Licence examples | Obligation |
|---|---|---|
| Linux kernel | GPL-2.0-only [S15] | Provide the corresponding source (or a written offer). Keep the notices |
| Ubuntu/Debian packages | Mixed (GPL, LGPL, MIT, BSD, Apache…) | Ship `/usr/share/doc/*/copyright`. Provide source for GPL packages (mirror the source packages used in each release) |
| KDE Plasma / Frameworks / Qt | LGPL/GPL (Qt under LGPL-3 / GPL options) | Same. Respect KDE trademarks: CHEENA may say "based on KDE Plasma" |
| Calamares + CHEENA modules | GPL-3.0 | CHEENA Calamares modules must be GPL-3.0-compatible |
| Firmware (linux-firmware) | Various redistributable, non-free | Check redistribution terms per blob. Policy M-07 |
| Fonts, icons, themes | OFL, CC-BY-SA, GPL… | Review each one. Never copy Windows/macOS assets |
| Codecs | Patent-encumbered formats | Policy M-07. Possibly install on demand only |
| Ubuntu trademark | Canonical trademark policy | **Remove or replace Ubuntu branding** in a derivative and don't imply endorsement (policy text to review) |
| CHEENA's own code | **Not chosen (M-03)** | Must be decided before the first public commit of code |

## 5. SBOM approach (proposed)
- Generate an **SPDX or CycloneDX** SBOM from the dpkg database of the built root filesystem, plus Flatpak manifests. Candidate tool: `syft`, to evaluate.
- Generate a licence report from `debian/copyright` files (machine-readable DEP-5 where available).
- Vulnerability scan against the SBOM in CI (candidate: `grype`). Results are informational until a policy exists.
- Store the SBOM, licence report and scan report next to each ISO.
