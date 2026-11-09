# ADR-001: Base distribution

- **Status:** Proposed. Awaiting owner approval. Lock only after Phase 1b (storage/rollback proof of concept) passes.
- **Date:** 2026-11-09

## Context
CHEENA OS must be built on a mature upstream distribution (master workflow §2.1, §3.1). The base is chosen against these requirements:
- KDE Plasma on Wayland (ADR-002)
- LUKS2 encryption
- Btrfs or another rollback mechanism
- An installer that can be extended for Safe Reinstall
- Signed updates and Secure Boot
- Hardware enablement
- A long support life
- A workload a small team can maintain

## Options compared

| Criterion | Ubuntu 26.04 LTS (Kubuntu package set) | Debian 13 "trixie" | Fedora Kinoite (atomic KDE) |
|---|---|---|---|
| Release / support | Apr 2026. Ubuntu standard support to Apr 2031 [S1]. **Kubuntu flavour support to Apr 2029** [S2] | Aug 2025. 5 years (security + LTS) [S10] | About 13 months per release (known; recheck). Upgrade one release at a time [S11] |
| KDE Plasma | 6.6, a KDE LTS line in Kubuntu [S2][S3]. Wayland only, X11 unsupported [S2] | 6.3.6 [S10], older | Current Plasma, fast cadence |
| **Security support for KDE packages** | KDE is in **universe**. Canonical's security team covers main/restricted. Universe fixes are community-provided unless Ubuntu Pro `esm-apps` is used [S14, unconfirmed] | Debian security team covers all of `main`, including KDE [S10] | Fedora updates the whole repo |
| Kernel / hardware enablement | Linux 7.0 [S2]. HWE kernels | Older kernel. Backports needed for newer hardware | Very current |
| Secure Boot | Signed shim/GRUB/kernel | Signed shim/GRUB/kernel | Signed shim/GRUB/kernel |
| Encrypted /boot via GRUB | **Not supported by Ubuntu**. Signed GRUB lacks luks2/Argon2 [S4] | Separate check needed | Not the default model |
| Installer | Calamares in Kubuntu (version to verify). TPM-FDE only in Ubuntu's own installer [S7] | Calamares in live images [S10] | Anaconda |
| Rollback | Not built in. Needs Btrfs + snapper (community tooling, to verify) | Not built in. Same as Ubuntu | **Built-in atomic deployments + rollback** [S11] |
| Safe Reinstall fit | Custom engineering needed | Custom engineering needed | Easier: system image is separate from `/var`/`/home` by design |
| Snap | Firefox is a Snap by default [S2]. Needs a policy | No Snap | No Snap. Flatpak-first |
| Packaging familiarity | deb, very common | deb, very common | rpm-ostree + Flatpak. Less common |

## Decision (proposed)
**Ubuntu 26.04 LTS, built from the Kubuntu package set, stays the leading candidate.** The master workflow says to proceed with it "if evidence does not justify a different base" (§3.1), and the evidence is **close, not decisive**:

- **For Ubuntu:** newest hardware enablement (Linux 7.0), Plasma 6.6 LTS, the largest documentation base, and a 5-year Ubuntu archive lifecycle.
- **Against Ubuntu:**
  1. KDE packages sit in universe, which **may mean** no Canonical security coverage without Ubuntu Pro [S14, to confirm].
  2. Kubuntu's own support ends in April 2029 [S2].
  3. A Snap policy is needed.
  4. Rollback needs custom work.
- **Debian 13** is the strongest fallback. It has full security-team coverage of KDE and is Calamares-native, but ships an older Plasma and kernel.
- **Fedora Kinoite** best fits rollback and Safe Reinstall, but its short lifecycle and different packaging raise the maintenance workload.

## Conditions before this ADR becomes "Accepted"
1. Confirm Canonical's official policy on universe security coverage and whether CHEENA can use Ubuntu Pro (S14).
2. Phase 1b shows Btrfs snapshot rollback and the chosen boot chain (ADR-003) working on Ubuntu 26.04 in a VM.
3. The owner accepts that CHEENA takes on KDE security tracking for the 2029–2031 window, or chooses Debian 13.

If condition 2 fails, revisit with Debian 13 (same deb tooling) first, and Fedora Kinoite second.

## Consequences
- Build tooling: Ubuntu live image tooling (see `docs/operations/build-and-release.md`).
- CHEENA must run its own signed apt repository for its packages (ADR-006).
- The KDE security-tracking process must be part of the vulnerability response plan.
