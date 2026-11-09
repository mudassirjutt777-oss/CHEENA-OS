# Risk register

Opened 10 November 2026. Likelihood and impact are judgements (Low / Medium / High), not measurements. Review at the end of each phase.

| ID | Risk | L | I | Response | Decide or test by |
|---|---|---|---|---|---|
| K-01 | Safe Reinstall erases or corrupts user data | M | H | Dedicated fail-closed tool; no partitioning calls; checksum tests; independent review | Phase 5 |
| K-02 | Snapshot rollback leaves an unbootable system because `/boot` and `@system` drift apart | M | H | Save and restore matching kernel files with each snapshot; test first in Phase 1b | Phase 1b |
| K-03 | Signed GRUB cannot unlock Argon2 LUKS2; design depends on an unencrypted `/boot` | H | M | Accepted in ADR 0003; re-check upstream status; consider signed unified kernel images later | Phase 1b |
| K-04 | KDE security updates on Ubuntu end April 2029, before the base | H | M | Plan a rebase or own KDE patching; keep Debian fallback | Before first release |
| K-05 | Canonical trademark policy requires rebuilding packages or blocks distribution as planned | M | H | Get legal advice; keep Debian fallback buildable | Before Phase 9 |
| K-06 | Calamares cannot produce the proposed layout without patches | M | M | Spike early; fall back to pre-partitioning script plus Calamares on prepared mounts | Phase 5 start |
| K-07 | No hardware to test AMD and NVIDIA graphics, Wi-Fi, Bluetooth, suspend | H | H | Declare a small support matrix; borrow or buy test machines; claim nothing untested | Phase 2 |
| K-08 | Owner's PC cannot build or boot images; all evidence depends on CI | H | M | GitHub Actions; consider a second-hand test machine or cloud VM for manual testing | Phase 1 |
| K-09 | GitHub runner disk (14 GB) or missing KVM makes builds or boot tests fail or run too slowly | M | M | Probe job; free disk first; software emulation fallback; larger runner if needed | Phase 1 |
| K-10 | Scope: 10 phases and five modules exceed what one owner and an AI agent can finish to release quality | H | H | Hold the strict MVP list; cut module scope as in the architecture overview; one milestone per PR | Every phase |
| K-11 | Users lose passphrase and recovery key | M | H | Clear setup wording; forced acknowledgement; recovery key verification step | Phase 4 |
| K-12 | Evil-maid attack through unverified initramfs | L | H | Documented limitation; owner acceptance; later mitigation | Owner decision |
| K-13 | Signing key leak or loss | L | H | Custody decision; offline or hardware-backed key; rotation procedure | Before Phase 3 |
| K-14 | Licence non-compliance (missing source offer, notices, non-free firmware or codecs) | M | H | SBOM and licence inventory per build; review before release | Phase 9 |
| K-15 | AI feature leaks data or acts on injected instructions | M | H | Off by default; read-only first; permission manager; tests for AI-off | Phase 8 |
| K-16 | Plasma or kernel update breaks CHEENA shell components | M | M | Pin to archive versions; test updates in a VM before publishing CHEENA packages | Ongoing |
| K-17 | Two Phase 0 document sets now exist on different branches and may conflict or confuse later work | H | L | Owner picks one branch as the baseline before Phase 1 | Now |
| K-18 | Evidence in this audit is partly secondary; some facts may be out of date | M | M | Grades in references.md; re-verify grade B and C items when the related phase starts | Each phase |
| K-19 | Minimum hardware turns out higher than target users' PCs (Ubuntu Desktop states 6 GB RAM, 25 GB disk) | M | M | Measure idle memory in Phase 2; publish honest minimums | Phase 2 |
