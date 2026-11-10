# Phase 1b boot and rollback proof of concept: run log

`tests/boot-poc/run.sh` builds a minimal Ubuntu 26.04 system into a disposable image file with the layout from ADR-003 and ADR-004, boots it in QEMU under OVMF, applies a real kernel update, and rolls the system subvolume back. It runs through `.github/workflows/boot-poc.yml`. It never touches a real disk.

Layout in the image: ESP (FAT32), `/boot` (ext4, unencrypted), LUKS2 Argon2id vault holding Btrfs with `@`, `@home` and `@snapshots`. Boot path: OVMF, shim, Ubuntu's signed GRUB, kernel, initramfs passphrase prompt on the serial console.

## Runs

| Run | Commit | Result | What happened |
|---|---|---|---|
| [42712538277](https://github.com/mudassirjutt777-oss/CHEENA-OS/actions/runs/42712538277) | 47bdc60 | Failed in setup | `losetup -P` gave no partition devices on the runner |
| [42713289129](https://github.com/mudassirjutt777-oss/CHEENA-OS/actions/runs/42713289129) | d8ddb51 | Failed in setup | `partx` reported no partitions in the image. The cause was not established; the script now uses a fixed partition table and one loop device per partition |
| [42713732664](https://github.com/mudassirjutt777-oss/CHEENA-OS/actions/runs/42713732664) | c496d9d | Failed at first boot | GRUB stopped at a `grub>` prompt. `grub-install --removable` had installed the CD-style GRUB image, which looks for `/.disk/info` and does not read a `grub.cfg` beside itself |
| [42715327695](https://github.com/mudassirjutt777-oss/CHEENA-OS/actions/runs/42715327695) | 2e309eb | Failed in the test driver | The guest booted in 13 s, but the driver read a partial marker line |
| [42770581675](https://github.com/mudassirjutt777-oss/CHEENA-OS/actions/runs/42770581675) | cd3b253 | **Passed** | Results below |

## Run 42770581675

Environment: GitHub-hosted `ubuntu-24.04` runner, kernel 7.0.0-1017-azure, QEMU 8.2.2 with KVM, OVMF without enrolled Secure Boot keys. Guest: Ubuntu 26.04 minbase, signed GRUB 2.14, shim-signed. Job time about 10 minutes.

| ID | Result | What the run showed |
|---|---|---|
| INIT-01 | Pass | The initramfs for 7.0.0-14-generic contains `cryptsetup` |
| BOOT-01 | Pass | Booted through shim and signed GRUB; vault unlocked from the initramfs; `/`, `/home`, `/boot` and `/boot/efi` mounted; 12 s with KVM |
| BOOT-02 | Pass | Wrong passphrase at the boot prompt was rejected and the prompt repeated |
| UPD-01 | Pass | After a real update from 7.0.0-14-generic to 7.0.0-43-generic the system booted the new kernel |
| RB-02 | Observed | **Naive rollback does not boot.** With `@` restored from the pre-update snapshot and `/boot` left alone, GRUB started 7.0.0-43, the system had modules only for 7.0.0-14, mounting `/boot/efi` failed ("FAT-fs: IO charset iso8859-1 not found") and systemd entered emergency mode |
| RB-03 | Pass | With the boot entry pointing at 7.0.0-14, the kernel that matches the snapshot and was still in `/boot`, the rolled-back system booted normally |
| HOME-01 | Pass | A marker in `/home` was identical across the install, update and rollback boots |
| SEC-02 | Pass | No passphrase in the script log, package logs or serial logs |
| SB-01 | Not run | Secure Boot enforcement |
| PWR-01 | Not run | Power cut during update |

## What this means for the design

1. **The ADR-003 boot chain works in a VM.** Unencrypted `/boot`, Argon2id vault unlocked in the initramfs, shim and signed GRUB. Risk R-02 can be treated as tested in a VM without Secure Boot enforcement.
2. **Risk R-03 is real, not theoretical.** Restoring the system subvolume without also choosing the matching kernel produces a machine that drops to emergency mode. A rollback feature that only restores `@` would turn a bad update into an unbootable system.
3. **The mitigation in the risk register works here.** Rollback must (a) keep the snapshot's kernel and initramfs in `/boot`, and (b) switch the default boot entry to that kernel in the same operation. The snapshot tool therefore has to record the kernel version with each snapshot and must stop kernel clean-up from deleting a kernel that any kept snapshot needs.
4. **Removable-media GRUB differs from installed GRUB.** The installer must place the normal signed image and its `grub.cfg` under `EFI/<id>/`. This matters for the recovery USB too.

## Limits

- One passing run. Not repeated, and not run on real firmware.
- Secure Boot signatures were not enforced, so the signed chain was loaded but not verified.
- The guest is a minimal system with no desktop. The CHEENA live image was not used.
- Rollback was done from the host between boots, not by a tool inside the running system or from the boot menu.
- `grub.cfg` was written by the test, not by `update-grub`. How Ubuntu's own GRUB scripts behave with snapshots is untested.
- Removing the old kernel after the update, which Ubuntu's clean-up eventually does, was not simulated. In that case the mitigation in point 3 fails unless clean-up is blocked.
- The archive's GRUB is now 2.14, which upstream says can unlock Argon2 LUKS2. Whether Ubuntu's signed build can, and so whether an encrypted `/boot` is possible after all, was not tested here.

No ADR status changes on the strength of one VM run. The owner decides.
