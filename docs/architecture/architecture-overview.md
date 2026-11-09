# CHEENA OS architecture overview

Status: **Proposed**, 10 November 2026. Nothing described here has been built or tested. Sources are in [references.md](../references.md).

## Summary

| Area | Proposal | Record |
|---|---|---|
| Base | Ubuntu 26.04 LTS archive; Debian 13 as fallback | [ADR 0001](decisions/0001-base-distribution.md) |
| Desktop | KDE Plasma 6.6, Wayland only, CHEENA shell layer on top | [ADR 0002](decisions/0002-desktop-environment.md) |
| Storage | UEFI/GPT; unencrypted `/boot`; one LUKS2 vault with Btrfs subvolumes | [ADR 0003](decisions/0003-storage-and-encryption.md) |
| Install | Calamares for fresh install; separate tool for Safe Reinstall | [ADR 0004](decisions/0004-installer-and-safe-reinstall.md) |
| Updates | Signed apt + Flatpak; snapshot before update | [ADR 0005](decisions/0005-updates-rollback-and-packaging.md) |
| Build | Scripted ISO build on GitHub Actions | [ADR 0006](decisions/0006-image-build-tooling.md) |

## Layers

```
┌──────────────────────────────────────────────────────────────┐
│ CHEENA apps: Control Center · Search · Recovery · AI (optional)│  unprivileged, QML/Qt
├──────────────────────────────────────────────────────────────┤
│ CHEENA shell: theme · panel/dock · launcher (Plasma plasmoids)│
├──────────────────────────────────────────────────────────────┤
│ CHEENA services (D-Bus, polkit-gated):                        │
│   system-health · update-manager · backup-manager · app-restore│
├──────────────────────────────────────────────────────────────┤
│ Upstream desktop: KWin · Plasma · SDDM · PipeWire ·           │
│   NetworkManager · BlueZ · xdg-desktop-portal · Flatpak       │
├──────────────────────────────────────────────────────────────┤
│ Upstream base: systemd · apt · cryptsetup · btrfs-progs       │
├──────────────────────────────────────────────────────────────┤
│ Ubuntu kernel (unpatched) · shim · signed GRUB · UEFI         │
└──────────────────────────────────────────────────────────────┘
```

## Rules that hold across the design

1. **CHEENA apps never run as root.** Anything privileged goes through a small system service over D-Bus, authorised by polkit, with a fixed list of operations. No "run this command" interface.
2. **The AI component is one more unprivileged client.** It can call the same service operations a user could approve, never more. When the global AI switch is off, its service unit is masked and nothing AI-related is running. Core functions have no dependency on it.
3. **Real data or "not available".** A UI element reads from a service or sensor, or shows that the value is unavailable. No placeholder numbers.
4. **Reuse upstream first.** CHEENA code exists only where it adds product value: shell, Control Center, Safe Reinstall, restore manifest, recovery flow.
5. **User data is never a side effect.** Only Safe Reinstall, backup and restore touch `@home` or `@data` at the system level, and each has a preflight and a log.

## The five core modules in the first release

| Module | First-release scope | Deferred |
|---|---|---|
| Self-Healing | Detect failed update or failed boot; offer snapshot rollback; Emergency Recovery with data export | Automatic diagnosis and repair of arbitrary faults |
| Universal Search | Apps, settings, file names and indexed document text through an existing indexer; exclusions respected | Semantic / AI search |
| Control Center | Network, display, audio, power, storage, updates, security, AI switch | Deep per-device tuning |
| Smart Performance Manager | Live CPU, RAM, disk, battery and thermal readings where sensors exist; plain-language explanations | Automated tuning; any action without consent |
| Developer Mode | Terminal, toolchain install, logs export, container runtime where supported | SDK, packaging tools |

This table is a proposal for the owner to cut or extend.

## Application restore manifest

Stored in `@data` so it survives reinstall. One record per application:

```
id            org.mozilla.firefox           # stable ID, independent of source
source        flatpak:flathub | apt:<repo> | manual
channel       stable
arch          x86_64
data_paths    [~/.var/app/org.mozilla.firefox]
restore       Restorable | Needs reinstall | Incompatible | Not backed up | Requires sign-in
verified      <date of last launch-and-data check, or empty>
```

Binaries are never copied. After a reinstall the tool reinstalls from `source`, then reports status per app. "Restored" is shown only after a launch check passes.

## What can be done where

| Work | Owner's Windows PC | GitHub Actions runner | Local Linux VM | Physical PC |
|---|---|---|---|---|
| Docs, scripts, unit tests | Yes | Yes | Yes | n/a |
| Build ISO | No (ADR 0006) | Yes, disk-limited | Yes | n/a |
| Boot ISO in a VM | No | Yes; speed depends on KVM | Yes | n/a |
| LUKS/Btrfs tests on virtual disks | No | Yes (loop devices, root) | Yes | n/a |
| Installer and reinstall flows | No | Scripted runs only | Yes, including by hand | Yes |
| Secure Boot with real firmware | No | OVMF only | OVMF only | **Required** |
| GPU, Wi-Fi, Bluetooth, audio, suspend | No | No | No | **Required** |

A VM pass never counts as hardware compatibility.

## Unknowns

- Whether Calamares can be configured to produce the ADR 0003 layout without patches.
- Whether snapshot rollback can be made reliable with a separate `/boot`.
- Real memory and disk needs of the CHEENA desktop.
- Legal position on the Ubuntu trademark policy.
- Whether standard GitHub runners expose KVM.
- Language for privileged services (Rust or Python), decided per service with a recorded reason.
