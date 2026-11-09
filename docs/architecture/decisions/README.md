# Architecture decision records

All records are **Proposed** until the owner approves them. A record marked Proposed must not be treated as settled by later work.

| No. | Decision | Status |
|---|---|---|
| [0001](0001-base-distribution.md) | Base distribution: Ubuntu 26.04 LTS, Debian 13 fallback | Proposed |
| [0002](0002-desktop-environment.md) | Desktop: KDE Plasma 6.6 on Wayland | Proposed |
| [0003](0003-storage-and-encryption.md) | Storage: LUKS2 vault, Btrfs subvolumes, unencrypted `/boot` | Proposed |
| [0004](0004-installer-and-safe-reinstall.md) | Installer: Calamares plus a separate Safe Reinstall tool | Proposed |
| [0005](0005-updates-rollback-and-packaging.md) | Updates: signed apt and Flatpak, snapshot before update | Proposed |
| [0006](0006-image-build-tooling.md) | Build: scripted ISO on GitHub Actions | Proposed |

Citations such as [R8] refer to [references.md](../../references.md).

To change a decision, add a new record that supersedes the old one. Do not rewrite an accepted record.
