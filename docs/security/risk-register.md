# Risk register

L = likelihood, I = impact (H/M/L). Review this at every phase gate.

| ID | Risk | L | I | Mitigation | Owner | Status |
|---|---|---|---|---|---|---|
| R-01 | Safe Reinstall misidentifies the data volume and erases user data | M | **H** | Fail-closed identification (ADR-004), no format code path (ADR-005), VM-only tests, independent review | Architect | Open |
| R-02 | Boot chain incompatible with LUKS2/Argon2 (signed GRUB lacks Argon2 [S4]) | Was H, now L | H | ADR-003 option 1: unencrypted `/boot`, initramfs unlock | Architect | Mitigated on paper. Prove in P1b |
| R-03 | Rollback mismatches the `/boot` kernel with `@` modules | M | H | Keep previous kernels, per-snapshot boot entries, test in P1b | Architect | Open |
| R-04 | User loses passphrase and recovery key | M | H | Mandatory key confirmation, export options, clear warning | Product | Open |
| R-05 | No AMD/NVIDIA test hardware → false claims | H | M | Hardware matrix shows only tested entries | Owner | **Open: hardware needed** |
| R-06 | Build environment too small or unprivileged | M | M | **GitHub Actions chosen (2026-11-09).** Reclaim disk, prove KVM in the first run | Owner + agent | Partly mitigated |
| **R-20** (new) | GitHub Free limits: 500 MB artifact storage, $12/month compute [S19]. A 3–4 GB ISO can't be kept as an artifact | M | M | Boot-test in the same job, upload evidence only. **Repo made public 2026-11-10**: compute limit lifted for standard runners. Artifact quota for public repos to recheck | Owner | Partly mitigated |
| R-07 | Testing harms the owner's daily laptop or BitLocker | L | H | Live-USB only, BitLocker key first, no firmware changes without approval | Owner + agent | Open |
| R-08 | Snap/apt/Flatpak conflicts | M | M | ADR-006 package policy | Architect | Open: owner decision |
| R-09 | Upstream changes break CHEENA customisations | M | M | Minimal patches, pinned archive snapshots, upstream-first | Architect | Open |
| R-10 | Scope creep delays a working base | H | H | Enforce §7 MVP. AI only in Phase 8 | Owner | Open |
| R-11 | Signing key compromise or loss | L | H | Offline key, separate keys, rotation plan | Owner | Open |
| R-12 | Licence non-compliance | M | H | SBOM + licence report per build, trademark review | Owner | Open |
| R-13 | AI prompt injection or escalation | M | H | Off by default, no root, approval gates (Phase 8) | Architect | Deferred to P8 |
| R-14 | No independent reviewer | H | M | Define a review model (M-17) | Owner | Open |
| R-15 | Upstream hardware limits read as CHEENA bugs | M | L | Separate "upstream limitation" category in reports | QA | Open |
| **R-16** (new) | KDE packages in universe → security fixes not from Canonical without Pro [S14]. Kubuntu support ends Apr 2029 [S2] | M | H | Confirm policy. Consider Ubuntu Pro or Debian 13 (ADR-001). Track KDE CVEs | Owner + architect | **Open: confirm** |
| **R-17** (new) | Calamares fails on existing `@`/`@home` [S9] → Safe Reinstall can't simply reuse it | H | M | Separate `cheena-reinstall` tool (ADR-005) | Architect | Mitigated on paper |
| **R-18** (new) | Unsigned initramfs on unencrypted `/boot` (evil-maid) | L | M | Document it. Signed UKIs in a later phase | Architect | Accepted for v1 (pending owner) |
| **R-19** (new) | Phase 0 sources partly secondary or community-grade (see references) | M | M | Re-verify primary docs before each ADR is accepted | Agent | Open |
