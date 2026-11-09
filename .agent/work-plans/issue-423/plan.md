# Plan: Promote ADR-0016 to Accepted: the GeoZui4D acceptance run passed the merge checkpoint (2026-11-09)

## Issue

https://github.com/rolker/agent_workspace/issues/423

## Context

ADR-0016 says "Provisional" until the full `/run-issue` loop runs from a project root through the merge
checkpoint. On 2026-11-09 it did, twice: GeoZui4D issues rolker/geozui4d#9 (closed 16:43Z, PR 14 merged
16:43:45Z) and rolker/geozui4d#7 (closed 17:40Z, PR 15 merged 17:40:25Z). Owner decision, 2026-11-09:
"promote adr 0016". The ADR itself says the flip is a status-line edit permitted by ADR-0008. One PR,
docs only, no Decision changes.

## Approach

1. **ADR-0016 Status** (`docs/decisions/0016-session-roots-and-the-user-tier.md`). Replace only the first
   Status paragraph. Start it `**Accepted.**` (`adr-status` reads the first word). One sentence names what
   satisfied the condition: the full loop driven from the project root through the merge checkpoint on
   2026-11-09 for rolker/geozui4d#9 (PR 14) and rolker/geozui4d#7 (PR 15), owner decision the same day.
   Keep the second paragraph (ADR-0008 note), the ADR-0018 paragraph, Decision, Consequences, Alternatives
   untouched. Only issue and PR references, no mechanism (project-agnostic rule: a record may name them).
2. **Roadmap Direction checks** (`docs/roadmap.md`, lines ~76-78).
   - Onboarding line: `gh-issue 332 closed ; gh-issue rolker/geozui4d#8 closed`. Reasoning: the line is
     about the onboarding of the project. geozui4d#8 "Onboard the project with the workspace" is the run's
     own issue; it closed 2026-11-02T17:47:42Z by merging geozui4d PR 10 ("Onboard the project with the
     workspace", merged 17:47:40Z). That is the real record. `gh-issue 332` stays as the second check since
     the line names parts 3 and 4 of #332's plan (closed 2026-10-30), but alone it shows only that the
     issue closed. `gh-issue` reads issue state only, so the check names issue #8, not PR 10 (state
     MERGED, not `closed`); PR 10 is cited in the PR description.
   - Loop line: `gh-issue rolker/geozui4d#9 closed`; evidence in the PR description: PRs 14 and 15 merged
     (issues #9 and #7 closed 2026-11-09).
   - Acceptance-case paragraph (owner's words, smallest edit), line ~21-23.
     Before: "Until that run passes the merge checkpoint, ADR-0016 (Session roots and the user tier) stays Provisional ([Sessions and roots](design.md#sessions-and-roots))."
     After: "That run passed the merge checkpoint on 2026-11-09, and ADR-0016 (Session roots and the user tier) is Accepted ([Sessions and roots](design.md#sessions-and-roots))."
     Next paragraph, before: "Design question OQ-2 ... asks where that run is tracked: here."
     After: "... asked where that run was tracked: here."
   - Deferral rows (#265, #295) untouched; their `adr-status ... accepted` check turns true and the
     sit-rep lists them as due.
3. **`docs/design.md`**, each spot (line numbers as of now):
   - Glossary row ~70: `decided, not proven` becomes general and names no ADR: "Decided and built, but the acceptance test named in the deciding ADR's Status has not run (that ADR is `Provisional` until it does)". Found while planning: ADR-0018's own promotion condition is "when ADR-0016's own acceptance run passes", so that run also meets ADR-0018's condition. Promoting ADR-0018 is not in this issue and is the owner's call (see Open Questions); this PR leaves it Provisional and the text must not call it unproven by a run that has happened.
   - Sessions and roots Status ~181: `decided, not proven` becomes `decided`; the Now-block sentence ~185-188 ("is Provisional until ... so none of this is marked `decided` yet. OQ-2 asks where...") is rewritten: ADR-0016 Accepted 2026-11-09 after the run; mention ADR-0018 is still Provisional, without claiming the block's mechanisms are unproven. Keep the ADR-0018 mentions elsewhere in the section as they are.
   - Line ~362 ("after the ADR-0016 acceptance run"): tense change to past ("after the ADR-0016 acceptance run of 2026-11-09"); #295 still decides it.
   - Register row ~723: Status cell `Provisional` becomes `Accepted` (vocabulary at ~699: use the word the other Accepted rows use, `in force`, if that is the register's term; read ~695-700 first).
   - C1-c paragraph ~732: the sentence "ADR-0016 stays `Provisional` until the acceptance run (...)" is dropped or made past tense ("ADR-0016 was promoted to Accepted on 2026-11-09 after the acceptance run").
   - OQ-2 ~748: answered: the run was tracked in the roadmap's Direction section and passed 2026-11-09; follow the C4/OQ-4 pattern of "Answered by ..." and the row's "What it changes" cell. If the table keeps answered rows (C4, OQ-4 do), keep the row with the answer.
   - Change log: one row dated 2026-11-09 for Sessions and roots, Decision register, Open questions, Glossary; cites #423; line count refreshed after edits (`wc -l`).
4. **Deferral comments** (host posts at publish; outside this phase's boundary). Text, signed with the AI signature
   (`$AGENT_NAME` / `$AGENT_MODEL`):
   - On #265: "ADR-0016 (Session roots and the user tier) is now Accepted (promoted 2026-11-09 after the GeoZui4D acceptance run, #423). PR 4 of this issue, which waited on it, is unblocked: retiring the legacy `project/` symlink and the `projects/<name>` paths, together with the worktree fallback that keeps them working, and registering the `~/project11-ng/<distro>` instance. The registration script itself already exists (`register_project.sh`, built by #332). The roadmap Direction deferral reads as due in the next sit-rep."
   - On #295: "ADR-0016 (Session roots and the user tier) is now Accepted (promoted 2026-11-09 after the GeoZui4D acceptance run, #423). The deferral of making the workspace a registered project, set to be settled once ADR-0016 was, is now due; the Registry inventory in `docs/design.md` can now be read to decide it."
5. **Final pass** in the worktree: `grep -rniE "provisional" docs/ ` and read each hit for any remaining claim about ADR-0016 (ADR-0018 hits are fine, as is the vocabulary definition at ~699); `.agent/scripts/check_design_anchors.sh` exits 0; `.agent/scripts/sitrep_checks.sh --root <worktree>`: the three Direction lines (onboarding, loop, promoted) read true, the two deferrals read as due, the acceptance paragraph still parses (first sentence unchanged); `adr-status` returns true.

## Files to Change

| File | Change |
|------|--------|
| `docs/decisions/0016-session-roots-and-the-user-tier.md` | First Status paragraph only: `**Accepted.**` plus the evidence sentence |
| `docs/roadmap.md` | Two Direction check cells, acceptance-case sentence, OQ-2 tense |
| `docs/design.md` | Glossary row, Sessions and roots Status and Now sentence, ~362 tense, register row, C1-c, OQ-2, Change log row |

## Prior Art

Nothing new is built. Follows the ADR's own promotion rule and the design.md Change log convention; the
OQ-2 edit follows how C4 and OQ-4 record an answer in place.

## Serves

The long view (README Workspace goals): the acceptance case is visibly met and what it unblocks is
visible. `docs/design.md#sessions-and-roots`, `docs/design.md#open-questions`.

## Design Picture

Yes: `docs/design.md#sessions-and-roots` (Status and Now sentence), the Decision register, the status
vocabulary glossary and `#open-questions` OQ-2 change in this PR (ADR-0017). No Decision changes.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Keep one current design | Every ADR-0016 Provisional claim in design.md and roadmap moves in this PR; final grep proves it |
| Verify before claiming | Onboarding check tied to the run's record (geozui4d#8, PR 10); dates and merges checked with `gh` today; the sit-rep run is the proof |
| Only what's needed | Status flip and dependent lines; deferred work stays out |
| Workspace is project-agnostic | GeoZui4D appears only as record (ADR Status, roadmap Direction), as issue and PR references |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0008 | Yes | Status-line edit only; ADR-0018 paragraph and all other sections kept |
| ADR-0016 | Yes | Subject |
| ADR-0017 | Yes | design.md and Change log row updated in the same PR |
| ADR-0018 | Watch | Stays Provisional; glossary and Sessions and roots text must not imply otherwise |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| ADR Status word | `adr-status` checks, sit-rep Direction line, deferral due state | Yes (step 5 verifies) |
| design.md lines | Change log line count; anchors | Yes (anchor script, `wc -l`) |
| Roadmap acceptance paragraph | Sit-rep `acceptance_rest` | Yes (sit-rep run) |
| ADR-0016 Accepted | #265 PR 4 and #295 deferrals | Comments (step 4, host posts); the work itself is out of scope |

## Open Questions

- For the owner: ADR-0018's promotion condition ("when ADR-0016's own acceptance run passes") is now met by the same run. Promote it in a follow-up issue, or leave it Provisional for now? This PR does not touch it either way (its Status paragraph and design.md register row stay).
- Mechanism choices (onboarding check = geozui4d#8 plus #332, register Status word) are made above and open to veto.

## Estimated Scope

Single PR, docs only.
