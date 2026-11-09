# CHEENA OS architecture overview

Status: Proposed (Phase 0). Every component below is **planned**. None of it exists yet.

## 1. Layers
```
┌──────────────────────────────────────────────────────────────────────┐
│ CHEENA apps (Qt6/QML, unprivileged)                                  │
│  Control Center · Universal Search UI · Performance Manager ·        │
│  Recovery/Backup UI · Developer Mode · AI Assistant (optional)       │
├──────────────────────────────────────────────────────────────────────┤
│ KDE Plasma 6.6 (Wayland): KWin, Plasma shell, KRunner, Dolphin,      │
│ System Settings KCMs, SDDM            + CHEENA theme/layout/KCMs     │
├───────────────────────── D-Bus (system bus) + polkit ────────────────┤
│ CHEENA system services (privileged, narrow, audited)                 │
│  cheena-health · cheena-update · cheena-snapshot · cheena-backup ·   │
│  cheena-apprestore · cheena-ai (sandboxed, optional, OFF by default) │
├──────────────────────────────────────────────────────────────────────┤
│ Base OS: Ubuntu 26.04 LTS userspace, systemd, apt, Flatpak,          │
│ NetworkManager, PipeWire, BlueZ, UPower, cryptsetup, btrfs-progs     │
├──────────────────────────────────────────────────────────────────────┤
│ Linux kernel 7.0 (Ubuntu-signed) · shim · GRUB · UEFI                │
├──────────────────────────────────────────────────────────────────────┤
│ Storage: ESP │ /boot │ RECOVERY │ LUKS2 → Btrfs subvolumes (ADR-004)  │
└──────────────────────────────────────────────────────────────────────┘
```

## 2. Security boundary (applies to every module)
- UI apps run **unprivileged**. Privileged operations go through **D-Bus methods on CHEENA services**, authorised by **polkit** rules. Destructive actions need interactive admin authentication each time.
- Each service runs as a systemd unit with hardening options: `ProtectSystem`, `PrivateTmp`, `NoNewPrivileges`, a restricted capability set, and `ReadWritePaths` limited to what the service needs.
- **AI never holds root.** `cheena-ai` runs as its own user in a sandbox. Its only route to the system is the same D-Bus API that users have, under the same polkit rules, plus an approval UI (Phase 8).
- Logs go to journald with a **redaction filter** for secrets. Support bundles go through the same redaction.

## 3. The five core modules mapped to the architecture
| Module | v1 scope (proposed, owner to confirm, M-20) | Built on | Phase |
|---|---|---|---|
| A. Self-Healing | Integrity check (`dpkg --verify`, failed systemd units, boot-failure detection), **tested** snapshot rollback, Safe Reinstall. No speculative filesystem repair | cheena-health, cheena-snapshot, `cheena-reinstall` | 3, 5, 6 |
| B. Universal Search | Non-AI: apps, settings (KCMs), files (Baloo), respecting Baloo exclusions. Semantic search only when AI is enabled | KRunner plugins + CHEENA UI | 3 (AI part: 8) |
| C. Control Center | One app that hosts KDE KCMs plus CHEENA KCMs (storage/vault, updates, backup, performance, AI). Unavailable hardware is shown honestly | Qt/QML + KCMs | 3 |
| D. Smart Performance Manager | Real CPU, RAM, storage, thermal, battery and GPU (where exposed) readings. Explanations. Recommendations only, with no automatic process killing | `/proc`, lm-sensors, UPower, DRM/hwmon | 3 |
| E. Developer Mode | Opt-in toggle: dev tools meta-package, container tooling (Podman), virtualisation check, log/diagnostic export. Separate polkit group | apt meta-package + Control Center KCM | 3–9 |

## 4. Implementation languages (proposed)
- **Qt 6 / QML + C++** for KCMs and KRunner plugins, which KDE's plugin APIs require.
- **Python** for prototypes, build tooling and unprivileged utilities.
- **Rust** for privileged services and `cheena-reinstall`, because they are security- and data-critical and memory safety matters.
- **Shell** only for small, tested build steps.

## 5. Out of scope for v1
Custom kernel, custom compositor, app store, Android companion, cloud sync service, autonomous AI agents, activity timeline, dual-boot (proposed).

## Related documents
- [Storage and encryption](storage-and-encryption.md)
- [Installer and recovery](installer-and-recovery.md)
- [Update and rollback](update-and-rollback.md)
- [Threat model](../security/threat-model.md)
