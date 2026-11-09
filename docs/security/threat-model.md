# Initial threat model

Status: first draft, 10 November 2026. It covers the proposed design in the [architecture overview](../architecture/architecture-overview.md). No control listed here has been implemented or tested.

## What we protect

| Asset | Why it matters |
|---|---|
| User data in `@home` | The product's central promise |
| Passphrase, recovery key, LUKS header | Loss or leak defeats the vault |
| Keyring contents (saved credentials) | Access to the user's other accounts |
| System integrity (boot chain, packages) | Everything else depends on it |
| Update and release signing keys | A leaked key lets an attacker ship malware to every user |
| AI history and any indexed content | Can contain anything the user has seen or typed |

## Who we defend against

| Actor | Capability |
|---|---|
| Thief or finder | Has the powered-off device |
| "Evil maid" | Brief physical access, device later returned to the user |
| Remote attacker | Network position, malicious website or file |
| Malicious or compromised app | Runs as the user |
| Supply-chain attacker | Tampers with a package, mirror, dependency or the build |
| Hostile content | Web page, document or email that tries to instruct the AI |
| The user by mistake | Wrong disk, wrong button, lost recovery key |

Out of scope for the first release: attackers with unlimited physical access and lab equipment, compromised firmware, and nation-state adversaries.

## Threats and controls

### Storage and boot

| ID | Threat | Control | Residual risk |
|---|---|---|---|
| S-01 | Thief reads the disk | LUKS2 vault, Argon2id | Weak passphrase |
| S-02 | Evil maid replaces kernel or initramfs on the unencrypted `/boot` to capture the passphrase | Secure Boot verifies shim, GRUB and kernel. The initramfs is **not** verified in this design | **Accepted for v1, owner to confirm.** Later fix: signed unified kernel images |
| S-03 | Recovery key stored on the same disk | Setup shows it once and offers print or save to removable media only; refuses to save inside the vault's own disk | User photographs it or stores it badly |
| S-04 | Secrets leak into logs or crash reports | Passphrases read through the kernel keyring or a no-echo prompt; log filter; automated grep test over journal and installer logs | New code path bypasses the filter |
| S-05 | LUKS header damage | Header backup at install, kept with recovery material | Backup lost with the key |
| S-06 | TPM-only unlock locks the user out after firmware change | TPM deferred; never the only slot | None in v1 |
| S-07 | Backdoor or vendor key | None exists by design; key slots are listed in the storage UI | None |

### Installer and recovery

| ID | Threat | Control | Residual risk |
|---|---|---|---|
| I-01 | Wrong disk erased | Disk shown with model, serial and size; typed confirmation; erase path separate from repair path | User confirms the wrong disk anyway |
| I-02 | Safe Reinstall formats user data | Path contains no partitioning or `mkfs` calls; fail-closed identity check; asserted by tests | Tool bug |
| I-03 | Recovery environment exposes data without credentials | Vault stays locked until passphrase or recovery key is entered | None beyond S-01 |
| I-04 | Interrupted install leaves no bootable system | Old `@system` kept until the new one boots | Failure in the bootloader switch |

### Updates and supply chain

| ID | Threat | Control | Residual risk |
|---|---|---|---|
| U-01 | Tampered package or mirror | apt signature verification; HTTPS mirrors | Compromised upstream key |
| U-02 | CHEENA signing key stolen | Key held outside the repo and CI; separate dev, test and release keys; documented rotation | Custody not yet decided |
| U-03 | Malicious dependency in CHEENA code | Pinned versions, lockfiles, vulnerability scan in CI, SBOM per build | Zero-day in a pinned version |
| U-04 | Compromised build | Builds from a tagged commit on a fresh runner; third-party Actions pinned by commit hash; reproducibility check | Runner platform compromise |
| U-05 | Third-party repositories added by the user | Clear warning; outside CHEENA's support | User choice |

### Applications and desktop

| ID | Threat | Control | Residual risk |
|---|---|---|---|
| A-01 | App reads other apps' data | Flatpak sandbox and portals for Flatpak apps | `.deb` apps and apps with broad permissions run unsandboxed |
| A-02 | Privilege escalation through a CHEENA service | Fixed operation list, input validation, polkit, no shell execution of client-supplied strings | Implementation bugs; needs review |
| A-03 | Silent microphone, camera or screen capture | Portal prompts and visible indicators | X11 apps under XWayland have weaker isolation |
| A-04 | Open network listener | Default-deny inbound firewall; no CHEENA service listens on the network in v1 | User-installed software |

### AI

| ID | Threat | Control | Residual risk |
|---|---|---|---|
| AI-01 | Prompt injection from a page, document or email makes the AI act | Content from files, pages and tools is passed as data and never as instructions; every action goes through the permission manager; sensitive actions need explicit confirmation showing exactly what will happen | Model follows injected text within read-only scope (for example, a misleading summary) |
| AI-02 | AI runs privileged commands | AI process is unprivileged and can call only the published service operations | Service bug (see A-02) |
| AI-03 | Data sent to a cloud model without consent | Cloud use off by default; per-request label when cloud is used; local-only mode | User misunderstands the label |
| AI-04 | Hidden recording or activity history | No capture unless invoked; timeline feature not in v1 | None in v1 |
| AI-05 | AI runs when "off" | Global switch masks the service units; test checks no AI process, socket or network call exists | Regression |
| AI-06 | Stored AI history leaks | Kept inside the vault; viewable and deletable in Control Center | Running-system compromise |

## Decisions the owner must make

1. Accept S-02 for the first release, or require signed unified kernel images before release.
2. Signing key custody (U-02).
3. Whether `.deb` applications appear in the software interface at all, given A-01.

## Before public release

- Independent security review of the Safe Reinstall tool, the privileged services and the AI permission manager.
- A published security contact and vulnerability reporting process.
- No "unhackable", "100% secure" or "never lose data" wording anywhere.
