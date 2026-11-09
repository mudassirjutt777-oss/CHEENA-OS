# References

Checked on 10 November 2026. Each entry carries a grade so readers know how far to trust it:

- **A**: official page, fetched and read in this audit.
- **B**: official page, seen only through a search-result summary. Re-read before relying on it.
- **C**: community or secondary report (bug report, forum, news). Treat as a lead to test, not a fact.
- **D**: listed in the master workflow, not re-read in this audit.

| ID | Source | Grade | Used for |
|---|---|---|---|
| R1 | [Ubuntu 26.04 LTS release notes](https://documentation.ubuntu.com/release-notes/26.04/) | A | Release date 23 April 2026; standard support to April 2031; desktop needs 2 GHz dual-core, 6 GB RAM, 25 GB disk |
| R2 | [Ubuntu 26.04 release announcement](https://lists.ubuntu.com/archives/ubuntu-announce/2026-April/000323.html) | B | Linux 7.0, systemd 259, APT 3.2, GNOME 50, Wayland-only desktop |
| R3 | [Kubuntu 26.04 LTS release notes](https://kubuntu.org/news/kubuntu-26-04-release-notes/) | A | Plasma 6.6, Qt 6.10.2, Frameworks 6.24.0, Gear 25.12.3, kernel 7.0; flavour support to April 2029; Wayland default, X11 session unsupported |
| R4 | [Debian "trixie" release information](https://www.debian.org/releases/trixie/) | B | Released 9 August 2025; full support to August 2028; LTS to 30 June 2030; kernel 6.12; Plasma 6.3 |
| R5 | [Fedora Linux release life cycle](https://docs.fedoraproject.org/en-US/releases/lifecycle/) | B | New release about every 6 months; each maintained about 13 months |
| R6 | [Fedora Atomic Desktops: updates, upgrades and rollbacks](https://docs.fedoraproject.org/en-US/atomic-desktops/updates-upgrades-rollbacks/) | B | Image-based updates keep the previous deployment for rollback; no skipping major releases |
| R7 | [Fedora bootc documentation](https://docs.fedoraproject.org/en-US/bootc/) | B | `bootc rollback` reorders deployments; `/etc` changes do not carry back |
| R8 | [Launchpad bug 2141233](https://bugs.launchpad.net/bugs/2141233), read through a [mail-archive copy](https://go.mail-archive.com/ubuntu-bugs@lists.ubuntu.com/msg6238305.html) | C | Ubuntu 26.04 signed GRUB fails with "Argon2 not supported" on a LUKS2 `/boot`. Status "New" when read |
| R9 | [Calamares documentation](https://calamares.io/docs/) | D | Installer candidate |
| R10 | Community reports on Calamares with existing Btrfs/LUKS: [Launchpad list post](https://archive.lists.launchpad.net/ubuntustudio-bugs/msg12576.html), [Kubuntu forum](https://www.kubuntuforums.net/forum/current-supported-releases/kubuntu-25-04-plucky-puffin/687389-calamares-crash-attempting-to-install-into-in-use-btrfs), [EndeavourOS forum](https://forum.endeavouros.com/t/fresh-endeavouros-installation-on-existing-btrfs-within-a-luks2-volume/81092) | C | Install fails when `@` or `@home` already exist; opened LUKS volumes not offered as targets |
| R11 | [Subiquity releases](https://github.com/canonical/subiquity/releases) | B | Subiquity 26.04 adds work on TPM-backed disk encryption for Ubuntu Desktop |
| R12 | [systemd-cryptenroll manual](https://www.freedesktop.org/software/systemd/man/latest/systemd-cryptenroll.html) | B | `--recovery-key`; TPM2 enrolment defaults to PCR 7; LUKS2 only |
| R13 | [GitHub-hosted runners reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) | A | Linux x64: 4 CPU / 16 GB / 14 GB SSD (public repos), 2 CPU / 8 GB / 14 GB (private). "Hardware acceleration for Android SDK tools" on Linux runners; KVM not named |
| R14 | [Canonical intellectual property rights policy](https://canonical.com/legal/intellectual-property-policy) | B | Modified versions need Canonical approval to use the trademarks; open-source licence rights are unaffected |
| R15 | [Ubuntu image builds](https://ubuntu.com/project/docs/how-ubuntu-is-made/processes/image-builds/) and [livecd-rootfs history](https://git.lubuntu.me/Lubuntu/livecd-rootfs/commits/tag/26.04.19) | B | Ubuntu builds images with livecd-rootfs; ISO assembly has moved out of live-build |
| R16 | [Launchpad bug 2154055](https://lists.snapcraft.io/archives/foundations-bugs/2026-May/549038.html) | C | live-build on 26.04 still expects `grub-legacy` |
| R17 | [Btrfs documentation](https://btrfs.readthedocs.io/) | D | Subvolumes, snapshots |
| R18 | [cryptsetup wiki](https://gitlab.com/cryptsetup/cryptsetup/-/wikis/home) | D | LUKS2 |
| R19 | [NIST SSDF](https://csrc.nist.gov/Projects/ssdf) | D | Secure development reference |
| R20 | [NIST AI RMF](https://www.nist.gov/itl/ai-risk-management-framework) | D | AI risk reference |

## Gaps in the evidence

- Kernel and systemd versions for Ubuntu 26.04 come from R2 and R3, not from the main release notes page, which does not state them.
- No official Calamares statement was found on reusing an existing encrypted Btrfs layout. Everything on that point is grade C.
- The Ubuntu installer's encryption and filesystem options for 26.04 were not confirmed from an official page.
- Whether a standard GitHub runner exposes `/dev/kvm` is not stated in R13. It must be measured.
- Fedora 45's release and end-of-life dates conflict across secondary sources and are not used.
