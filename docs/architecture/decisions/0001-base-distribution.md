# ADR 0001: Base distribution

Status: **Proposed** (needs owner approval and the Phase 1b proof of concept)
Date: 10 November 2026

## Decision

Use **Ubuntu 26.04 LTS** package archives as the base, with KDE packages from the same archive. Keep **Debian 13** as a prepared fallback until two open questions below are closed.

## Comparison

| | Ubuntu 26.04 LTS | Debian 13 "trixie" | Fedora-based (Kinoite / bootc) |
|---|---|---|---|
| Released | 23 April 2026 [R1] | 9 August 2025 [R4] | Every ~6 months [R5] |
| Security support | Main archive to April 2031 [R1]. Kubuntu flavour to April 2029 [R3] | Full to August 2028, LTS to June 2030 [R4] | ~13 months per release [R5] |
| Kernel | 7.0 [R2][R3] | 6.12 [R4] | Newest of the three |
| Plasma | 6.6 [R3] | 6.3 [R4] | Current upstream |
| Update model | apt packages | apt packages | Image-based with built-in rollback [R6][R7] |
| Rebranding rules | Canonical policy restricts trademark use on modified versions [R14] | Permissive trademark policy (not re-read here) | Fedora trademark rules apply (not re-read here) |

## Reasons

- Newest kernel and Plasma among the two long-support options, which matters for laptop hardware and Wayland.
- Five years of archive support against Fedora's 13 months. A small team cannot rebase a whole OS every year.
- Largest pool of third-party packages and documentation for a `.deb` base.

## Why this is conditional

1. **KDE security coverage ends earlier than the base.** The Kubuntu flavour is supported to April 2029, two years short of the base archive [R1][R3]. CHEENA would have to carry KDE security fixes itself from 2029, or rebase.
2. **Trademark policy.** Canonical's policy requires approval for modified versions that use Ubuntu trademarks [R14]. Community readings say this can mean removing Ubuntu branding and rebuilding packages. This is a legal question, not an engineering one, and it needs a written answer before any public release. Debian does not raise the same concern.

Fedora's image-based model is the best technical fit for Self-Healing and rollback, but the 13-month lifecycle rules it out for a first release.

## Consequences

- Build scripts must keep the distribution name, suite and mirror in one config file so a switch to Debian is a config change plus package-name fixes.
- Nothing CHEENA-specific may depend on Snap or other Ubuntu-only services.
- Owner must decide on legal advice for [R14] before Phase 9.

## What would change this decision

- Legal advice that the trademark policy requires rebuilding the archive.
- The Phase 1b proof of concept failing on Ubuntu's boot chain in a way Debian's does not (see ADR 0003).
