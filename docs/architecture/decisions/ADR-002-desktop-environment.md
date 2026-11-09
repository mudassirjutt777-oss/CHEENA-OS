# ADR-002: Desktop environment

- **Status:** Proposed
- **Date:** 2026-11-09

## Context
The master workflow (§3.2) proposes KDE Plasma on Wayland. It also rules out a custom compositor for v1 and rules out shipping KDE defaults unchanged.

## Decision (proposed)
Use **KDE Plasma 6.6 on Wayland** [S2][S3], with no X11 session. Kubuntu 26.04 doesn't support X11 [S2]. XWayland provides compatibility for legacy X11 apps.

## What CHEENA builds versus what it reuses
| CHEENA builds | Reuses from KDE upstream |
|---|---|
| Global theme: colours, Plasma style, window decoration, icons (licence-reviewed), cursor, SDDM and splash themes | KWin compositor, Plasma shell, SDDM |
| Default panel/dock layout script (Plasma layout JavaScript) with distinctive behaviour | Dolphin file manager, Konsole, Discover (for evaluation) |
| CHEENA Control Center: a Qt/QML app that embeds KDE System Settings modules (KCMs) and adds CHEENA KCMs (storage/vault, backup, updates, AI) | Existing KCMs for network, audio, display, Bluetooth, accessibility |
| CHEENA Universal Search: KRunner plugins (apps, settings, files via Baloo, CHEENA actions) plus an optional AI back end | KRunner, Baloo file indexer |
| Smart Performance Manager: reads real sensors (lm-sensors, UPower, `/proc`, GPU interfaces) and shows "Not available" when a reading is missing | KSysGuard/Plasma System Monitor as a reference |

## Graphics validation (no claims without tests)
- Intel: test on the owner's EliteBook (UHD, Comet Lake).
- AMD: **no test hardware identified yet.**
- NVIDIA: **no test hardware identified yet.** The proprietary driver interacts with Secure Boot (MOK enrolment) and with Wayland behaviour. It needs its own test track and policy (M-07).

## Consequences
- Qt 6 / QML / KDE Frameworks 6 is the UI stack for CHEENA apps (see the architecture overview).
- Upgrades must re-test CHEENA theme and layout scripts against each Plasma point release.
- Accessibility can build on KDE's existing screen reader (Orca), keyboard navigation and scaling support. CHEENA's own apps must meet the target set in M-09.
