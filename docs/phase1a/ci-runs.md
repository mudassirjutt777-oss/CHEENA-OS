# Phase 1a CI run log

One row per `image-build` run, recording only what the run actually showed.

| Run | Commit | Result | Failed at | Cause | Fix |
|---|---|---|---|---|---|
| [42581421390](https://github.com/mudassirjutt777-oss/CHEENA-OS/actions/runs/42581421390) | 8710506 | ✗ | Build ISO (~11 min in) | Unknown: logs need a login, and the repo was private at the time | Added login-free annotations (acfea7f) |
| [42692379459](https://github.com/mudassirjutt777-oss/CHEENA-OS/actions/runs/42692379459) | acfea7f | ✗ | Build ISO → `mksquashfs` | `FATAL ERROR: SOURCE_DATE_EPOCH and command line options can't be used at the same time` | Unset the variable for mksquashfs only. Also added `zstd` and used `dpkg-divert --no-rename` |

## Facts established by run 42692379459
- The runner (public repo) is Ubuntu 24.04.5, kernel 7.0.0-1017-azure, 4× AMD EPYC 7763, 15 GiB RAM, **114 GB free disk** after cleanup, **`/dev/kvm` writable**, loop devices present, passwordless sudo.
- debootstrap of `resolute` from `snapshot.ubuntu.com` (2026-11-01) **worked**.
- All packages in `build/image/packages.txt` **resolved and installed**: kernel `7.0.0-42-generic`, Plasma 6.6.6, KF6 6.24.0, Gear 25.12.3, glibc 2.43.
- CHEENA overlay, os-release diversion, locale and initramfs generation **worked**.
- Not yet reached: squashfs creation, ISO creation, boot test.
