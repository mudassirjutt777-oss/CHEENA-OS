# Phase 1b storage proof of concept: run log

One row per `storage-poc` CI run, recording only what the run showed. The test and its limits are described in [tests/storage-poc/README.md](../../tests/storage-poc/README.md).

| Run | Commit | Result | Notes |
|---|---|---|---|
| [42709082205](https://github.com/mudassirjutt777-oss/CHEENA-OS/actions/runs/42709082205) | 0167a83 | 11 pass, 0 fail, 2 not run | First run. Annotation carried no per-check detail |
| [42710914650](https://github.com/mudassirjutt777-oss/CHEENA-OS/actions/runs/42710914650) | 71e7be1 | 11 pass, 0 fail, 2 not run | Detail added to the annotation; guard against an empty checksum set |

## Run 42710914650 in detail

Environment: GitHub-hosted `ubuntu-24.04` runner, kernel 7.0.0-1017-azure. Loop devices over image files in `/tmp`. Job time 33 seconds.

| ID | Result | What the run showed |
|---|---|---|
| ENC-01 | Pass | LUKS2 vault created; 2 key slots, both Argon2id |
| ENC-02 | Pass | Wrong passphrase refused |
| ENC-03 | Pass | Passphrase and recovery key each unlock |
| ID-01 | Pass | Single genuine vault identified |
| ID-02 | Pass | Refused: "marker missing" |
| ID-03 | Pass | Refused: "2 vault candidates" |
| RI-01 | Pass | System subvolume replaced with no `mkfs`; 3 files in `@home` (about 201 MB) identical by SHA-256; LUKS and Btrfs UUIDs unchanged; vault reopened with the recovery key |
| RB-01 | Pass | Rollback restored the system subvolume; `@home`, including a file written after the snapshot, unchanged |
| DF-01 | Pass | Pool filled to 100%; snapshot delete, file delete, new write and remount all worked; data intact |
| HD-01 | Pass | Zeroed header made the vault unopenable; header backup restored access and data |
| SEC-01 | Pass | No secret in the script log, `dmesg` or journal |
| PWR-01 | Not run | Power cut during write needs a VM |
| BOOT-01 | Not run | Secure Boot on/off and kernel-versus-snapshot match need a bootable image |

## What this supports

- LUKS2 with Argon2id and a second recovery slot works with the kernel and cryptsetup on the runner (ADR-003).
- The system subvolume can be swapped and rolled back without touching `@home` (ADR-004), using only rename and snapshot operations.
- A LUKS header backup is a working recovery path, so taking one at install time is worth adding to the design.
- The three-part identity check refuses in the two ambiguous cases tried.

## What it does not show

- Nothing about booting. Risk R-03 (kernel in `/boot` out of step with the rolled-back system) is untouched and remains the main open question for ADR-003 and ADR-004.
- The runner kernel and tools are Ubuntu 24.04's with an Azure kernel, not the CHEENA image's.
- The data set is three files. It is a mechanism check, not a stress test.
- Argon2id ran at a fixed low cost.
- The identity check and reinstall steps here are test code, not the Safe Reinstall tool.
- One disk-full attempt passed. Btrfs behaviour at 100% varies with metadata layout, so one pass is weak evidence.

No ADR status changes on the strength of this run.
