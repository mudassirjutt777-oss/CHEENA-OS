# Hardware and VM test matrix

Only rows with test evidence may be called "supported". Everything else is **untested**.

## Devices

### HW-01: HP EliteBook 840 G7 (owner's daily Windows laptop)
- **Allowed use:** live-USB boot only, which doesn't write to the internal disk.
- **Before testing:** save the BitLocker recovery key and record the Secure Boot state.
- **Status:** Untested.

Components were detected in Windows on 2026-11-09. The Linux status column is an *expectation*, not a result.

| Component | Detected | Expected Linux status | Tested? |
|---|---|---|---|
| CPU | Intel i5-10310U | Supported (mainline) | No |
| GPU | Intel UHD (Comet Lake) | Supported (i915) | No |
| Wi-Fi | Intel AX200 | Supported (iwlwifi, needs firmware) | No |
| Bluetooth | Intel Wireless BT | Likely supported | No |
| Audio | Realtek codec + Intel SST | Needs SOF firmware. Microphone uncertain | No |
| Fingerprint | Synaptics FS7605 | **Likely unsupported** (libfprint, to verify) | No |
| Camera | HP HD Camera | Likely UVC | No |
| NVMe | Toshiba KBG30 256 GB | Supported | No |
| TPM / Secure Boot | Unknown (needs admin) | — | No |

### Other devices
| ID | Device | Vendor coverage | Status |
|---|---|---|---|
| HW-02 | *(none identified)* | AMD GPU | **Gap.** Owner to supply |
| HW-03 | *(none identified)* | NVIDIA GPU | **Gap.** Owner to supply |
| HW-04 | *(none identified)* | Desktop PC, legacy-BIOS assessment | **Gap** |

## Virtual machines (planned)
| ID | Config | Purpose |
|---|---|---|
| VM-01 | QEMU/KVM, OVMF, Secure Boot **off**, 4 GB RAM, 40 GB virtio disk | Baseline install and boot |
| VM-02 | Same as VM-01 with Secure Boot **on** (Microsoft keys enrolled) | Shim/GRUB/kernel chain |
| VM-03 | Two disks, one with an existing CHEENA vault, plus a decoy LUKS volume | Safe Reinstall ambiguity tests |
| VM-04 | Small 20 GB disk | Disk-full, snapshot pressure |
