# Initial threat model

Status: Phase 0 draft. Method: STRIDE per asset (S = Spoofing, T = Tampering, R = Repudiation, I = Information disclosure, D = Denial of service, E = Elevation of privilege). Review it at each phase gate, and fully before the AI phase (8) and before any public release.

## Assets
| ID | Asset | Why it matters |
|---|---|---|
| A1 | User files in `@home` | The core promise is "data-first" |
| A2 | LUKS passphrase, recovery key, header | Losing them means losing the data. Leaking them exposes the data |
| A3 | CHEENA release signing key | Compromise means every CHEENA system can be fed malicious updates |
| A4 | System integrity (kernel, initramfs, `@`) | Basis for trusting everything else |
| A5 | Keyring and app credentials | Protects the user's accounts |
| A6 | Logs and support bundles | Can leak personal data and secrets |
| A7 | AI context (screen, files, history), from Phase 8 | Highly sensitive and open to manipulation |

## Adversaries
- **T1:** thief or finder of a powered-off laptop
- **T2:** someone with brief physical access (an "evil maid")
- **T3:** a malicious network or package mirror
- **T4:** a malicious app or Flatpak
- **T5:** malicious content (web page, document, email) aimed at the AI
- **T6:** an attacker who compromises the CHEENA build or signing infrastructure
- **T7:** the user's own mistakes or bugs (accidental erase, a wrong disk)

## Threats and mitigations
| # | Threat (STRIDE) | Asset | Adversary | Mitigation (planned) | Residual risk / note |
|---|---|---|---|---|---|
| 1 | Read the disk offline (I) | A1 | T1 | LUKS2 Argon2id (ADR-003) | Weak passphrase. Mitigate with a strength meter |
| 2 | Tamper with the unsigned initramfs to capture the passphrase (T, I) | A2, A4 | T2 | Secure Boot covers shim, GRUB and kernel only | **Accepted for v1, documented.** Fix with signed UKIs later |
| 3 | Malicious update via a hostile mirror (T) | A4 | T3 | apt / Flatpak signature checks. CHEENA repo signed | Depends on key custody (row 4) |
| 4 | Signing key theft (S, T) | A3 | T6 | Release key offline, separate dev/test/release keys, CI signs only with a test key | Rotation and revocation process needed before release |
| 5 | **Safe Reinstall formats the wrong volume** (T, D) | A1 | T7 | Fail-closed identification (ADR-004), no format code path, preflight summary, VM-only tests | **Highest-impact bug class.** Release blocker until tested |
| 6 | Recovery key leaks through logs or screenshots (I) | A2 | T7 | Redaction filter, a grep test in CI, key shown once | — |
| 7 | Privilege escalation via a CHEENA D-Bus service (E) | A4 | T4 | Polkit on every method, minimal methods, systemd hardening, fuzz input parsing | Needs code review per service |
| 8 | A Flatpak app reads home files (I) | A1 | T4 | Flatpak sandbox + portals. Show the permissions in the store UI | Many Flathub apps request broad filesystem access |
| 9 | Prompt injection makes the AI delete or send data (T, I, E) | A1, A7 | T5 | AI is off by default, no root, approval for sensitive actions, external content treated as data, audit log | Covered in full in Phase 8 |
| 10 | Support bundle uploaded with personal data (I) | A6 | T7 | No automatic upload. Redaction. The user previews the bundle | — |
| 11 | Snapshot mistaken for a backup → data loss on disk failure (D) | A1 | T7 | UI messaging. Backup status always visible | User behaviour |
| 12 | Repudiation: no record of who ran destructive actions (R) | A1, A4 | T7 | Transaction logs in `@cheena-data/logs`, admin auth logged by polkit | — |

## Out of scope for v1 (stated honestly)
Hardware and firmware attacks (DMA, malicious firmware), state-level adversaries, and side channels. CHEENA must not be marketed as "unhackable" (§2.7).
