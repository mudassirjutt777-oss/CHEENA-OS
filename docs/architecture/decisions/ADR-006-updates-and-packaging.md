# ADR-006: Updates, rollback and package policy

- **Status:** Proposed. Several items need an owner decision (marked **DECIDE**).
- **Date:** 2026-11-09

## Context
The master workflow sets these rules:
- Updates must be signed.
- A snapshot is taken before updates.
- The package manager has a clear owner.
- No conflicting update mechanisms (§3.6).

Ubuntu 26.04/Kubuntu ships Firefox as a Snap [S2].

## Decision (proposed)
| Layer | Mechanism | Owner |
|---|---|---|
| Base OS (Ubuntu archive) | apt, Ubuntu-signed repositories | Ubuntu |
| CHEENA packages (themes, Control Center, services, defaults) | apt, **CHEENA-signed repository** | CHEENA |
| Third-party desktop apps | **Flatpak** (Flathub, with a curated default set) | Flathub / app vendors |
| Snap | **DECIDE:** proposed **remove snapd from the default image** and provide Firefox from Mozilla's official APT repository or Flathub (licence and terms to verify) | — |

### Update flow (CHEENA Update Manager, Phase 3 + 6)
1. Refresh metadata and verify signatures. apt does this natively.
2. **Pre-update snapshot** of `@` (snapper or a CHEENA hook, to be decided in Phase 1b).
3. Apply updates. Log results without secrets.
4. Health check after the update: boot target reached and core services running.
5. If the health check fails on next boot, offer rollback to the pre-update snapshot. Never roll back silently.
- The UI always shows the last successful update, the snapshot age and a reminder that "snapshots are not backups".

### Signing keys (DECIDE M-05)
- Separate **development, test and release** keys (master workflow §10).
- Keep the release key **offline** (hardware token or air-gapped machine). It is never stored in the repo or in CI secrets in plain form. CI signs only with a test key.
- Document a key rotation and revocation procedure before any public release.

### Upgrades between CHEENA releases
Out of v1 scope, but it needs a design before the second release (M-21).

## Consequences
- CHEENA needs hosting for its apt repository (GitHub Pages, object storage or a Launchpad PPA, **DECIDE**).
- The app-restore manifest records the install method (`apt` | `flatpak`) for each app (Phase 7).
- Discover (KDE's software centre) can manage both apt and Flatpak. Whether it is the "curated software interface" or CHEENA builds its own is decided in Phase 3.
