# Storage proof of concept (Phase 1b)

`run.sh` tests the vault design proposed in ADR-003 and ADR-004 on image files attached as loop devices. It runs in CI through `.github/workflows/storage-poc.yml`. It never opens a real disk: every device it formats is a loop device it created under `/tmp/cheena-storage-poc`.

Do not run it on a personal machine. It needs root and is meant for a throwaway VM.

## Checks

| ID | Check |
|---|---|
| ENC-01 | LUKS2 vault with a passphrase slot and a recovery-key slot, both Argon2id |
| ENC-02 | Wrong passphrase is refused |
| ENC-03 | Passphrase and recovery key each unlock |
| ID-01 | A single genuine vault passes the identity check |
| ID-02 | Identity check refuses when the marker file is missing |
| ID-03 | Identity check refuses when two devices carry the vault label |
| RI-01 | System subvolume replaced with no `mkfs`; `@home` byte-identical by SHA-256; LUKS and Btrfs UUIDs unchanged |
| RB-01 | Snapshot rollback restores the system subvolume and leaves `@home` alone |
| DF-01 | After filling the pool: snapshot delete, file delete, new write and remount work; data intact |
| HD-01 | Zeroed LUKS header blocks access; restoring the header backup recovers the data |
| SEC-01 | No secret in the script log, `dmesg` or the journal |

## Not covered

- **PWR-01** power cut during a write.
- **BOOT-01** booting with Secure Boot on and off, and whether the kernel in `/boot` still matches the system subvolume after a rollback (risk R-03). This is the hardest open question and needs a bootable image in QEMU.
- The real installer, the real Safe Reinstall tool, and real hardware.
- Argon2id runs with a fixed low cost here to keep CI fast. Real installs use cryptsetup's benchmarked defaults.
- The recovery key is added with `cryptsetup luksAddKey`. The product may use `systemd-cryptenroll --recovery-key` instead; that path is not tested here.

A pass here supports the storage design. It does not prove the product protects user data.

## Reading results

The job writes a results table to the run summary and one annotation listing every result. Record each run in `docs/phase1b/storage-poc-runs.md`.
