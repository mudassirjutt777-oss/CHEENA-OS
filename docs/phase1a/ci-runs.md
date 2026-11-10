# Phase 1a CI run log

One row per `image-build` run, recording only what the run actually showed.

| Run | Commit | Result | Failed at | Cause | Fix |
|---|---|---|---|---|---|
| [42581421390](https://github.com/mudassirjutt777-oss/CHEENA-OS/actions/runs/42581421390) | 8710506 | ✗ | Build ISO (~11 min in) | Unknown: logs need a login, and the repo was private at the time | Added login-free annotations (acfea7f) |
| [42692379459](https://github.com/mudassirjutt777-oss/CHEENA-OS/actions/runs/42692379459) | acfea7f | ✗ | Build ISO → `mksquashfs` | `FATAL ERROR: SOURCE_DATE_EPOCH and command line options can't be used at the same time` | Unset the variable for mksquashfs only. Also added `zstd` and used `dpkg-divert --no-rename` |
| [42699368379](https://github.com/mudassirjutt777-oss/CHEENA-OS/actions/runs/42699368379) | 8dc5e92 | ✓ (boot test pass) | — | Three issues found, not failures: boot ran under TCG not KVM; `casper-md5check.service` failed; build step took 105 min | KVM step moved after qemu install; `md5sum.txt` added to ISO; squashfs zstd level 15 → 9 |
| [42770580111](https://github.com/mudassirjutt777-oss/CHEENA-OS/actions/runs/42770580111) | ce74d1e | ✓ (boot test pass) | — | `failed=none` (md5 fix worked). Build step 10.7 min (was 105). **Still `accel=tcg`**: `/dev/kvm` was 0666 at 06:49, but the boot test at 06:59 found it not writable | Record `/dev/kvm` state after the build; restore 0666 before boot; `CHEENA_REQUIRE_KVM=1` so a silent TCG fallback fails the job |
| [42773655881](https://github.com/mudassirjutt777-oss/CHEENA-OS/actions/runs/42773655881) | dc213d9 | ✗ | Build ISO → debootstrap (1 s in) | `E: Failed getting release file .../dists/resolute/Release` from snapshot.ubuntu.com. The same URL answered HTTP 200 from another network minutes later: a transient archive or network error. KVM diagnostics not reached | Retry debootstrap up to 3 times; `Acquire::Retries=5` for apt |

## Facts established by run 42770580111
- ISO 1,669,455,872 bytes (+35 MB from squashfs level 9), sha256 `5c5975a8…dd84e`. Same 930 packages and kernel.
- Boot test passed: marker after 145 s, `sddm=active`, **no failed units**. Still TCG, Secure Boot off.
- Build ISO step: 10 min 40 s. Whole job about 20 min.
- Open: what changes `/dev/kvm` during the build is not yet known. The next run records it.

## Facts established by run 42699368379 (first passing run)
- ISO built: `cheena-os-0.1.0-dev-amd64.iso`, 1,634,115,584 bytes, sha256 `fae506e4…c629b`. squashfs 1,524,817,920 bytes. 930 packages. Kernel `7.0.0-42-generic`.
- Boot test `TS-boot-live-uefi-sb-off` **passed**: QEMU q35 + OVMF, Secure Boot **off**, `accel=tcg`, 2 vCPU, 3 GB. The serial marker appeared after 145 s with `sddm=active`.
- At marker time systemd reported `starting` (not yet `running`), and the one failed unit was `casper-md5check.service` (no `md5sum.txt` on the ISO).
- `/dev/kvm` was writable at the probe, but the boot test fell back to TCG. Most likely cause: installing `qemu-system-x86` re-applied udev rules after our KVM rule ran.
- Timing: Build ISO step 105 min (21:08 → 22:54 UTC), boot test 3 min, SBOM 2 min.
- Not proven: what SDDM showed on screen. The screenshot is in the evidence artifact, which needs a GitHub login to download. Secure Boot, real hardware, installer: not tested.

## Facts established by run 42692379459
- The runner (public repo) is Ubuntu 24.04.5, kernel 7.0.0-1017-azure, 4× AMD EPYC 7763, 15 GiB RAM, **114 GB free disk** after cleanup, **`/dev/kvm` writable**, loop devices present, passwordless sudo.
- debootstrap of `resolute` from `snapshot.ubuntu.com` (2026-11-01) **worked**.
- All packages in `build/image/packages.txt` **resolved and installed**: kernel `7.0.0-42-generic`, Plasma 6.6.6, KF6 6.24.0, Gear 25.12.3, glibc 2.43.
- CHEENA overlay, os-release diversion, locale and initramfs generation **worked**.
- Not yet reached: squashfs creation, ISO creation, boot test.
