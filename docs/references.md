# Sources used in Phase 0

Other documents cite these as `[S#]`. Everything was retrieved on **9 November 2026**. Each source is marked with how much weight it can bear:

- **Primary**: official project documentation, release notes or bug tracker.
- **Secondary**: news coverage, or a project-affiliated blog. Use it only together with a primary source.
- **Community**: forum posts and third-party configs. These are evidence to check, never a basis for a decision.

Re-verify every source before locking a decision. Versions and support terms change.

| ID | Source | Weight | What it supports |
|---|---|---|---|
| S1 | Ubuntu 26.04 LTS release notes: https://documentation.ubuntu.com/release-notes/26.04/ | Primary | Released 23 Apr 2026. Standard support to **April 2031**; ESM (Ubuntu Pro) up to 10 years. Desktop needs 2 GHz dual-core, **6 GB RAM, 25 GB storage** |
| S2 | Kubuntu 26.04 LTS release notes: https://kubuntu.org/news/kubuntu-26-04-release-notes/ | Primary | Plasma 6.6, Qt 6.10.2, KDE Frameworks 6.24.0, Gear 25.12.3. Linux **7.0** kernel. Wayland is default and **X11 is not supported** by the Kubuntu team. Firefox 150 ships as a **Snap**. Kubuntu flavour support runs to **April 2029** |
| S3 | Kubuntu news, "Beyond Ubuntu long-term support: introducing KDE's LTS software to Kubuntu 26.04 LTS": https://kubuntu.com/news/plasma-6.6-lts/ | Primary | Plasma 6.6 is treated as a KDE LTS line in Kubuntu 26.04 |
| S4 | Launchpad bug #2141233 (grub2-signed, 26.04): https://bugs.launchpad.net/ubuntu/+bug/2141233 | Primary | Ubuntu 26.04 signed GRUB (snapshot `2.14~git20250718`) **cannot unlock Argon2 LUKS2 keyslots**. Ubuntu maintainer: Ubuntu **does not support GRUB-unlocked encrypted /boot** and **does not sign the luks2 module**. Bug closed Invalid |
| S5 | Phoronix, "GRUB 2.14 Bootloader Released": https://phoronix.com/news/grub-2.14-released | Secondary | Upstream GRUB 2.14 (14 Jan 2026) added Argon2 KDF, TPM2 key protector and BLS/UKI support |
| S6 | Ubuntu security docs, Full disk encryption: https://documentation.ubuntu.com/security/security-features/storage/encryption-full-disk/ | Primary | LUKS passphrase FDE is supported. TPM-backed FDE uses a UKI and seals the key to TPM PCRs. It needs Secure Boot + TPM 2.0. The page covers up to 24.04 |
| S7 | Help Net Security, Ubuntu 26.04 LTS launch: https://www.helpnetsecurity.com/2026/04/24/ubuntu-26-04-lts-resolute-raccoon-released/ | Secondary | TPM-backed FDE becomes generally available in the 26.04 desktop installer. Recovery key generated. Passphrase LUKS still offered |
| S8 | Calamares documentation: https://calamares.io/docs/ (plus `src/modules/partition/partition.conf` and `src/modules/mount/mount.conf` in the Calamares source) | Primary (to be read in P0 follow-up) | `luksGeneration: luks2` option. Btrfs subvolume list defined in `mount.conf` |
| S9 | Community reports on Calamares and existing Btrfs/LUKS layouts (EndeavourOS forum, Launchpad ubuntustudio-bugs archive) | Community | Calamares does not detect Btrfs inside an unopened LUKS2 container. Installation **fails when `@`/`@home` already exist**. Custom subvolume lists can crash. **Must be reproduced in Phase 1b** |
| S10 | Debian 13 "trixie" release announcement: https://www.debian.org/News/2025/20250809 and release notes https://www.debian.org/releases/trixie/ | Primary | Released 9 Aug 2025. 5 years of support (security team + LTS). First Debian with Plasma 6 (6.3.6). Live images include **Calamares**. Current point release 13.7 |
| S11 | Fedora Kinoite: https://fedoraproject.org/atomic-desktops/kinoite/ and Updates/Upgrades/Rollbacks: https://docs.fedoraproject.org/en-US/atomic-desktops/updates-upgrades-rollbacks/ | Primary | Atomic rpm-ostree KDE desktop. Rollback from the boot menu or `rpm-ostree rollback`. Keeps 2 deployments by default. Upgrades go one major release at a time |
| S12 | Fedora bootc docs: https://docs.fedoraproject.org/en-US/bootc/ | Primary (**blocked by bot protection during research; not read**) | Image-based alternative named in the master workflow. Still to be read |
| S13 | GitHub-hosted runners reference: https://docs.github.com/en/actions/reference/runners/github-hosted-runners and larger runners: https://docs.github.com/en/actions/reference/runners/larger-runners | Primary | Standard Linux runner lists **14 GB SSD**. Larger runners offer more (e.g. 150 GB for a 4-core Ubuntu runner). ubuntu-26.04 label in public preview |
| S14 | Ubuntu Discourse / Launchpad discussion on universe security coverage | Community | Canonical's security team covers **main/restricted**. KDE/Kubuntu packages live in **universe**, where security fixes rely on the community unless Ubuntu Pro `esm-apps` is enabled. **Must be confirmed against Canonical's official docs** |
| S15 | Linux kernel licence (COPYING, GPL-2.0-only): https://www.kernel.org/doc/html/latest/process/license-rules.html | Primary (known) | Kernel source and notice obligations |
| S16 | cryptsetup / LUKS2 documentation: https://gitlab.com/cryptsetup/cryptsetup/-/wikis/home | Primary (to be read in P1b) | LUKS2 keyslots, Argon2id, header backup |
| S17 | Btrfs documentation: https://btrfs.readthedocs.io/ | Primary (to be read in P1b) | Subvolumes, snapshots, ENOSPC behaviour |
| S19 | GitHub Actions billing / product usage included: https://docs.github.com/en/billing/reference/product-usage-included | Primary | GitHub Free includes $12/month of compute (≈2,000 min on a 2-core Linux runner). **500 MB artifact storage** shared with Packages. 10 GB cache per repo. Usage blocked without a payment method |
| S20 | GitHub changelog, hardware-accelerated Android virtualization (2 Apr 2024): https://github.blog/changelog/2024-04-02-github-actions-hardware-accelerated-android-virtualization-now-available/ | Primary (dated) | KVM acceleration on Linux runners. The runner user must be added to the kvm group. Recheck against current runner images |
| S18 | NIST SSDF: https://csrc.nist.gov/Projects/ssdf; NIST AI RMF: https://www.nist.gov/itl/ai-risk-management-framework | Primary | Secure development and AI risk references |

## Research not finished in Phase 0

- S8, S12, S16, S17 were identified but not read in full. They're needed before Phase 1b closes.
- Snapper and grub-btrfs support status on Ubuntu 26.04 has not been checked.
- Whether the Ubuntu 26.04 desktop installer offers Btrfs layouts has not been confirmed (S7 does not say).
- Whether libfprint supports the Synaptics FS7605 fingerprint reader has not been checked.
- Mozilla's official APT repository terms (as an alternative to the Firefox Snap) have not been checked.
