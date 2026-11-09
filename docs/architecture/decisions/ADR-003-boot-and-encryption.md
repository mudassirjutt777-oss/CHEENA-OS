# ADR-003: Boot chain and disk encryption

- **Status:** Proposed. Must be proven in Phase 1b and Phase 4a on virtual disks.
- **Date:** 2026-11-09

## Context
The requirements are:
- LUKS2 encryption
- Secure Boot where possible
- A separate recovery key
- No backdoor
- TPM never the only route

Facts found in Phase 0:
- Ubuntu 26.04's signed GRUB **cannot unlock LUKS2 keyslots that use Argon2**. Ubuntu **does not support** GRUB-unlocked encrypted `/boot` and **does not sign the luks2 GRUB module** [S4].
- Upstream GRUB 2.14 added Argon2 [S5], but distro builds lag behind it.
- Ubuntu's own TPM-backed FDE uses a signed UKI with the key sealed to the TPM. It is only available through Ubuntu's own installer, and requires Secure Boot and TPM 2.0 [S6][S7].

## Options
| Option | Secure Boot with Ubuntu-signed parts | Argon2id | Protects kernel/initrd from tampering | Complexity |
|---|---|---|---|---|
| **1. Unencrypted ext4 `/boot` + LUKS2 (Argon2id) root, unlocked in the initramfs** | Yes | Yes | Kernel signed. **Initramfs not signed**, a known gap [S4] | Low. This is the standard Ubuntu layout |
| 2. GRUB-unlocked encrypted `/boot` (PBKDF2 keyslot) | No. luks2 module not signed [S4] | No | Partial | Unsupported by Ubuntu. **Rejected** |
| 3. systemd-boot + signed UKIs (CHEENA signing key, MOK) | Needs CHEENA key enrolment | Yes | Yes | High. Diverges from Ubuntu's supported path |
| 4. Ubuntu TPM-backed FDE | Yes | n/a | Yes | Only through Ubuntu's installer + snapd stack. Conflicts with Calamares/KDE and the Snap policy |

## Decision (proposed for v1)
**Option 1:**
- ESP + unencrypted ext4 `/boot`
- Shim + Ubuntu-signed GRUB + Ubuntu-signed kernel
- One LUKS2 container using **Argon2id** for passphrase keyslots, unlocked in the initramfs by cryptsetup

Key slots:
- **Slot A:** the user passphrase.
- **Slot B:** a randomly generated **recovery key**, at least 128 bits of entropy, shown once in a human-friendly format. It is never written unencrypted to the disk.
- The LUKS2 **header backup** is offered for export to external media during setup.

**TPM2 unlock is deferred from v1.** Revisit it in Phase 9 together with option 3 (signed UKIs), which also closes the unsigned-initramfs gap.

## Known limitations to state honestly
- The unsigned initramfs on an unencrypted `/boot` is open to an "evil maid" attack by someone with physical access. Encryption protects data **at rest when powered off**. It does not protect against a tampered boot chain.
- Losing both the passphrase and the recovery key means the data is **unrecoverable**. There is no vendor key.

## Tests required (Phase 4a, disposable virtual disks only)
1. Boot with the passphrase.
2. A wrong passphrase is rejected.
3. The recovery key unlocks the container.
4. Restoring the header backup works.
5. Secure Boot enabled in OVMF still boots.
6. Grep all logs and journals for passphrase or recovery-key material and find **zero** hits.
7. Kernel update keeps the system bootable.
