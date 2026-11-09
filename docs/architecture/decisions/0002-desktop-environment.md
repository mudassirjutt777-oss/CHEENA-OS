# ADR 0002: Desktop environment

Status: **Proposed**
Date: 10 November 2026

## Decision

Use **KDE Plasma 6.6 on Wayland** as shipped in the Ubuntu 26.04 archive. Do not ship or support an X11 session. Legacy X11 applications run through XWayland.

## Reasons

- Plasma 6.6 with Qt 6.10.2 is in the 26.04 archive and Wayland is its default, fully supported session [R3].
- Upstream no longer supports the X11 session on this release [R3]. Supporting it ourselves would double the graphics test matrix.
- Plasma's panels, launcher, theme and settings modules are replaceable through documented extension points (QML plasmoids, look-and-feel packages, KCM modules). CHEENA can build its own shell layout without writing a compositor.

## What "CHEENA desktop" means in the first release

| Layer | Approach |
|---|---|
| Compositor, session, login | Upstream KWin, Plasma session and SDDM, unmodified |
| Theme | CHEENA look-and-feel package: colours, fonts, icons, window decoration |
| Panel / dock and launcher | CHEENA plasmoids in QML, replacing the default panel layout |
| Settings | CHEENA Control Center as a front end that calls the same system services as System Settings |
| File manager | Dolphin, themed |

Shipping stock Plasma with a wallpaper change does not meet the master workflow's requirement. The table above is the minimum.

## Risks

- **NVIDIA on Wayland** has historically lagged Intel and AMD. Each vendor is tested separately (see hardware section of the test strategy). Nothing is claimed until tested on real hardware.
- **Plasma minor updates** can break custom plasmoids. Pin to the archive version and test before each update.
- **KDE support window** ends April 2029 on Ubuntu (ADR 0001).
- **Memory**: Ubuntu Desktop states 6 GB RAM for a comfortable experience [R1]. CHEENA's minimum is not known until measured.

## Not doing

- No custom compositor or window manager.
- No copying of Windows, macOS or ChromeOS assets or layouts.
