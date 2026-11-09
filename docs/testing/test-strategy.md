# Test strategy

Status: Phase 0 draft. Implements master workflow §9.

## Principles
1. Run destructive storage tests **only on disposable virtual disks** (QEMU `qcow2`/raw image files). Never on a host disk.
2. A VM pass is **not** a hardware pass. Hardware claims come only from the [hardware matrix](hardware-matrix.md).
3. Every result is recorded with: ID, build/commit, environment, steps, expected, actual, pass/fail, evidence (log/screenshot path), limitation.
4. No result is written down unless the test actually ran.

## Test levels and where they run
| Level | Examples | Tooling (proposed) | Runs on | From phase |
|---|---|---|---|---|
| 1 Unit | Volume identity logic, redaction filter, manifest parser | pytest / cargo test / Qt Test | CI | 1 |
| 2 Integration | D-Bus service + polkit rules, KCM ↔ service | dbus-run-session, systemd-nspawn | CI or Linux host | 3 |
| 3 Image/build | Package manifest diff, ISO checksum, reproducibility (two builds compared) | build scripts + diffoscope | CI | 1a |
| 4 VM boot/install | Live boot, install to blank disk, reboot, login | QEMU + OVMF (Secure Boot on and off), openQA later if worth it | Linux host with KVM | 1a/5 |
| 5 Installer safety | Ambiguous disks refused, "keep data" never formats `@home` | QEMU with prepared multi-disk images | Linux host | 5 |
| 6 Encryption/recovery | Wrong passphrase, recovery key, header restore, no secrets in logs | cryptsetup on loop-backed images (in VM) | Linux host | 1b/4a |
| 7 Update/rollback | Broken kernel update, interrupted update, disk full | QEMU snapshots + fault injection | Linux host | 1b/6 |
| 8 App restoration | Firefox profile, a Flatpak app, game save folder | Scripted VM scenario | Linux host | 7 |
| 9 Security | Dependency CVE scan, SBOM, lintian, secret scanning, polkit review | e.g. grype/trivy, syft, gitleaks (to evaluate) | CI | 1a+ |
| 10 Physical hardware | Boot, Wi-Fi, audio, Bluetooth, suspend, display scaling | Manual checklist from a **live USB** | Owner's devices | 2+ |

## Minimum scenario list
All 19 scenarios from master workflow §9 are adopted unchanged. Each will get an ID `TS-xx` in `release-acceptance.md` when Phase 1a starts.

## Phase 0 checks actually performed
- Repository inspection and host capability inspection (read-only).
- **No builds, boots or storage tests were run in Phase 0.**
