---
workflow: collaborative
issue: 487
---

# Issue #487 — Manifest support in the workspace: goals, design and roadmap for how it uses ros-manifest (first sub-roadmap)

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-18 10:39 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Verdict**: changes-requested

**Branch**: feature/issue-487 at `d924aec2`
**Base**: origin/main
**Depth**: Standard (reason: 320 changed lines, docs only, governance file docs/design.md)
**Must-fix**: 9 | **Suggestions**: 9
**Round**: 1 | **Ship**: continue — 9 must-fix

Specialists: Claude adversarial (facts against source, governance), Gemini, Codex (all complete). Static analysis: no profile for Markdown. Plan drift: no work plan. All findings below were addressed in 60361bdd, which no reviewer has read yet.

### Findings
- [x] (must-fix) sync is described as fetching every repo outside the pull case; a repo with uncommitted changes is skipped with no fetch (adversarial, codex) — `docs/manifest/design.md:73`
- [x] (must-fix) The target design mixes one directory per distro with single-distro layout, config and build (gemini, adversarial) — `docs/manifest/design.md:148`
- [x] (must-fix) The design depends on a tool design change (#495) it does not state, and contradicts the tool's design as merged (adversarial) — `docs/manifest/design.md:141`
- [x] (must-fix) Facts removed from the docs/design.md bullet appear nowhere: no credentials and no plain http in a source URL, which hosts need network, local manifest work uses the path form, the owner's attribution (adversarial, gemini) — `docs/manifest/design.md:38`
- [x] (must-fix) validate's pass/fail contract is undefined in the mapping to status (codex) — `docs/manifest/design.md:160`
- [x] (must-fix) setup mapped to init drops the repair of an existing instance (codex) — `docs/manifest/design.md:157`
- [x] (must-fix) Concurrency and failure guarantees overstated: the lock is released before import, a failed import leaves the new directory active (codex) — `docs/manifest/design.md:87`
- [x] (must-fix) The roadmap's order is inverted in two places and omits show and the session's distro (gemini) — `docs/manifest/roadmap.md:26`
- [x] (must-fix) A date inside the Direction section against its own rule (gemini) — `docs/manifest/roadmap.md:20`
- [x] (suggestion) The resolver command leaves out --cache-dir (adversarial) — `docs/manifest/design.md:64`
- [x] (suggestion) The mapping must always pass --manifest-path (adversarial) — `docs/manifest/design.md:180`
- [x] (suggestion) Reading config.yaml couples the workspace to the tool's files, against "called by CLI only" (gemini, adversarial) — `docs/manifest/design.md:172`
- [x] (suggestion) Today's guarantees and adapter verbs are not mapped to the target (gemini) — `docs/manifest/design.md:155`
- [x] (suggestion) validate softened to a comparison; a mismatch is a failure (gemini) — `docs/manifest/design.md:77`
- [x] (suggestion) The two main roadmap rows keep stale text and were to become a pointer (gemini, adversarial) — `docs/roadmap.md:187`
- [x] (suggestion) docs/design.md reads as if source_path were required, and cites the part rule as settled (codex, adversarial) — `docs/design.md:447`
- [x] (suggestion) The change-log row gives neither the section's size nor whether detail should move (adversarial) — `docs/design.md:1105`
- [ ] (suggestion) The check for the Rolling instance is an issue closing, not a live validation (codex) — `docs/manifest/roadmap.md:33`
