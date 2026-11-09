# Update and rollback design

Status: Proposed. The policy decisions are in [ADR-006](decisions/ADR-006-updates-and-packaging.md).

## Update sources and trust
| Source | Verification |
|---|---|
| Ubuntu archive | Ubuntu archive signing keys (apt) |
| CHEENA apt repo | CHEENA release key. The public key ships in the `cheena-keyring` package |
| Flatpak (Flathub) | Flatpak repository GPG verification |

## Sequence (one update transaction)
```
check → download → verify signatures → pre-update snapshot (@ only)
      → apply → record transaction (id, packages, snapshot id)
      → reboot (if needed) → post-boot health check
          ├─ healthy  → mark snapshot "known-good", retire older per policy
          └─ unhealthy → notify user, offer rollback (never automatic, never silent)
```

## Health check (initial definition, refined in Phase 3)
- Reached `graphical.target` or `multi-user.target`
- No CHEENA-critical units failed (display manager, NetworkManager, cheena services)
- Free space above a threshold

## Snapshot retention (proposal)
Keep the last 5 pre-update snapshots plus the last 2 marked "known-good". Snapshots older than 30 days are pruned, unless the user pins them. Free-space guard: if the free space would drop below 10 % of the pool, refuse the snapshot and tell the user. **Do not** silently delete user-pinned snapshots.

## Open technical questions for Phase 1b
- Use snapper with an apt hook, or a small CHEENA snapshot service? (Check snapper's status in Ubuntu 26.04.)
- `/boot` is outside the snapshots. How does rollback restore the matching kernel and initramfs? Options: keep the previous kernel packages installed and pin a boot entry to each snapshot, or move kernels into UKIs on the ESP later (ADR-003, option 3).
