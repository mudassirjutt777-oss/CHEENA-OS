# Test strategy

Status: plan only, 10 November 2026. **No test has been run.**

## Principles

- A feature is "working" only when it has an implementation, an automated or recorded manual test, and stored evidence.
- Destructive tests run only on disposable virtual disks. Never on a real disk in CI, never on the owner's PC.
- VM results are labelled as VM results. Hardware support is claimed per tested model only.
- Safety refusals (wrong disk, ambiguous layout, wrong passphrase) are tested as carefully as success paths.

## Where each level runs

| Level | What | Where | When |
|---|---|---|---|
| 1 Unit | Logic in CHEENA tools and services | Anywhere, including the owner's PC | Every push |
| 2 Integration | UI-to-service over D-Bus, polkit rules | CI container or VM | Every push |
| 3 Image | Build succeeds; package list, checksum, SBOM produced; two builds compared | GitHub Actions | Manual trigger and before release |
| 4 VM boot | ISO boots under QEMU with OVMF to a marker on the serial console; Secure Boot off and on | GitHub Actions | After each image build |
| 5 Installer safety | Fresh install; every refusal case | QEMU with blank and prepared virtual disks | Phase 5 onward |
| 6 Encryption and recovery | Lock, unlock, wrong passphrase, recovery key, header restore, secret-in-logs scan | Loop devices and QEMU | Phase 4 onward |
| 7 Update and rollback | Update, failed update, interrupted update, rollback, disk full | QEMU with snapshots | Phase 3 and 6 |
| 8 App restore | Reinstall and data check for the selected apps | QEMU | Phase 7 |
| 9 Security | Dependency scan, licence scan, service fuzzing, AI-off check | CI | Phase 3 onward |
| 10 Hardware | Boot, graphics, Wi-Fi, Bluetooth, audio, suspend, external display, real Secure Boot | Physical PCs | Phase 2 onward, required before release |

## Automating VM tests

- The live image writes a marker line to the serial console when the desktop session is up. The boot test waits for it with a timeout.
- Installer runs use an answer file and are checked by booting the result and reading a second marker.
- Fault injection: kill QEMU at a chosen point for power-cut tests; pre-fill disks for disk-full tests; corrupt bytes on a copy of the image for header tests.
- If `/dev/kvm` is missing the tests run in software emulation and record that in the evidence.

## Data-preservation tests

Before reinstall, the test writes a known file tree into `@home` and `@data`, including a browser profile and a large file, and records SHA-256 for each file. After reinstall it recomputes them. Any difference fails the test. The same method checks that a refused reinstall changed nothing, by comparing a whole-disk checksum before and after.

## Hardware matrix (to be filled)

| Class | Example target | Status |
|---|---|---|
| Intel integrated graphics laptop | Owner's i5-10310U laptop is a candidate, but it is the owner's working PC with real data | Not tested |
| AMD graphics | None available | Not tested |
| NVIDIA graphics | None available | Not tested |
| Desktop with Ethernet only | None available | Not tested |

Installing on the owner's working PC is not recommended. A spare machine or external disk is needed for hardware tests.

## Minimum scenarios

The list in master workflow section 9 is the release checklist. Each scenario gets a test ID when its phase starts.

## Test record format

```
Test ID:        ENC-003
Build / commit: <ISO sha256> / <git sha>
Environment:    QEMU <version>, OVMF, 4 GB RAM, 32 GB virtio disk, KVM yes/no   (or hardware model)
Steps:          …
Expected:       …
Actual:         …
Result:         Pass / Fail
Evidence:       path or artifact link to logs and screenshots
Limitations:    …
```

Records live under `tests/records/` once testing starts.

## Release gates

No release if any of these is true:

- Safe Reinstall can lose data in any tested scenario.
- Encryption recovery is untested.
- A critical or high defect is open without a written owner decision.
- Any UI control in the release has no working behaviour.
- A claim in release notes has no matching test record.
