---
issue: 309
---

# Issue #309

## Issue Review
**Status**: complete
**When**: 2026-09-23 14:08-04:00
**By**: Codex CLI Agent (gpt-6)
**Issue**: #309

### Scope Assessment

**Well-scoped?** Yes — a shared coverage predicate and regression tests fit one PR.
**Right repo?** Yes — review-loop infrastructure belongs to agent_workspace.
**Dependencies**: None identified.

### Principle Alignment

| Principle | Status | Notes |
| --- | --- | --- |
| Only what's needed | OK | Reuse merge-gate equivalence without changing CI policy. |
| Test what breaks | OK | Real Git histories cover silent loss and stale-review rejection. |
| A change includes its consequences | OK | Update triage's sources contract and preserve merge callers. |

### ADR Applicability

| ADR | Triggered | Notes |
| --- | --- | --- |
| 0002 | Yes | Isolated feature/issue-309 worktree. |
| 0011 | Yes | Generic Git logic, no project-shape assumptions. |
| 0013 | Yes | Preserve entry vocabulary and original SHA provenance. |

### Consequences

- The gate now allows the issue's whole work-plan directory; use that current policy consistently.
- Regression tests belong in test_triage_reviews_integration.sh, which owns sources coverage.
- Codex observations remain work-plan evidence, not instruction or orchestrator changes.

### Recommendations

None beyond the implementation plan.

### Actions
- [x] No actions needed.

## Plan Authored
**Status**: complete
**When**: 2026-09-23 14:10-04:00
**By**: Codex CLI Agent (gpt-6)
**Plan**: `.agent/work-plans/issue-309/plan.md` at `bed79ef`

Share the existing merge-gate coverage rule with sources; preserve original review
SHAs and test real-history boundaries. Draft PR deferred until the fix is reviewable.
User authorized implementation and the workspace workflow in this session.

## Plan Review
**Status**: complete
**When**: 2026-09-23 14:10-04:00
**By**: Codex CLI Agent (gpt-6; independent plan_review subagent)
**Verdict**: ready
**Issue**: #309
**Plan**: `.agent/work-plans/issue-309/plan.md` at `bed79ef`

### Evaluation

Scope, issue alignment, file targeting, consequences, principle alignment, and
ADR compliance: Good. ROS conventions: not applicable.
Independent fresh-context reviewer read the committed plan and relevant source.
No blocking findings. Update all literal same-head descriptions in the triage
skill, including classification and report templates, as planned.

### Recommended Actions

- [x] No pre-implementation blockers.

## Checkpoint
**Status**: complete
**When**: 2026-09-23 14:29 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

Approve, as described (Recommended): Codex's plan (bed79ef; Codex plan review: ready) is approved. Driver handed over from Codex (quota exhausted) to a Claude drive. Implementer: commit Codex's staged, uncommitted implementation first as a labelled WIP snapshot (authored as found), merge main, then finish and verify the plan; coordinate with #334 (docs reorganisation), which adds docs/roadmap.md to merge_pr.sh's bookkeeping lists — whichever lands second carries docs/roadmap.md into the new shared helper; keep codex-workflow-notes.md in the work-plan folder.

## Implementation
**Status**: complete
**When**: 2026-09-23 14:54 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Branch**: feature/issue-309 at `40f4e7d`

Handover from Codex CLI (quota exhausted mid-implementation), per the checkpoint at `5ae7c73`.

**Handover commits.** Codex's staged, uncommitted work committed as found under its own identity: `544bde2` (8 files, +241/-59; full pre-commit suite passed, no SKIP needed) and its workflow notes `bc6979d`. Merged origin/main (`92c57ce`): no conflicts.

**Codex's snapshot contained:** `_bookkeeping.sh` (the gate's `_only_bookkeeping_between` moved out of `merge_pr.sh` verbatim, a `_review_bookkeeping_between` review policy, a bash bridge for Python); gate switched to it; `sources` coverage (exact / bookkeeping, per-SHA cache, cwd repository, issue from the canonical progress path, original `sha` kept, `covers_head` + `coverage` fields); real-history tests; fixture copies of the helper in both merge suites; triage-reviews contract text.

**Kept:** the extraction and gate wiring, the coverage model (endpoint tree diff, ancestor required, issue-scoped work-plan dir, cwd repository, exact-match fast path), the provenance fields, the fixture updates, most test cases, most of the skill text. The core logic held up against its own cases.

**Changed, and why:**
- Silent fallback (Quality Standard, and the issue's own complaint that "the helper gave no signal"): Codex's bridge collapsed every failure (no repo, missing object, missing helper) to "not covered" with stderr discarded. Now the helper returns 1 stale / 3 unverifiable with a reason, and `sources` emits `dropped_entries` (entry, sha, open count, reason, why) plus a stderr warning for unverifiable ones.
- Roadmap set: one `BOOKKEEPING_ROADMAP_PATHS` in `_bookkeeping.sh`, including `docs/roadmap.md` (#334), used by the review policy and by the CI walk-back list in `merge_pr.sh`. #334 edits both lines, so whichever lands second resolves a trivial conflict by keeping the shared array.
- Hex-only SHA resolution in the review policy: Codex's resolved any revision, so a ref name such as `HEAD` counted as a recorded review.
- `set -e` safety: resolution rewritten as if-blocks (merge_pr.sh runs `set -eo pipefail`).
- Tests: added the lowercase roadmap, nested work-plan files, issue-70 prefix boundary, `dropped_entries` reasons, bridge usage and non-hex checks (h1-h15). The no-repository case is now pinned with `GIT_CEILING_DIRECTORIES` so it holds even if TMPDIR sits inside a checkout. Gate g7 (docs/roadmap.md), g8 (another issue's dir, pinning existing behaviour), CI walk-back ci-30b.
- triage-reviews skill: documented `dropped_entries` (unverifiable means read the entry by hand, never treat it as resolved). Also fixed the `sources` call's `--progress` path. #317 prefixed it with `$WS_ROOT` (the main checkout), which does not hold an in-flight branch's timeline. It now uses the worktree toplevel, which is where step 7 persists. Codex's comment in cmd_sources ("comment ... cover the current head") was corrected: a candidate needs the GitHub comment *at* the head.

**Verification:** run_script_tests.sh: all 26 suites green. test_triage_reviews_integration 36/36, test_merge_pr_gate 81/81. Fail-without-fix proof on scratch copies: pre-fix `review_progress.sh` (`5ae7c73`) fails 19 of the new cases, including h1, the #309 checkpoint regression. Codex's snapshot fails 13, from the lowercase roadmap onward plus the dropped-entry reporting. main's `merge_pr.sh` fails g7 and ci-30b.

**Not done (Ask First):** AGENTS.md's script table still describes `sources` as "correlated by head SHA" and does not list `_bookkeeping.sh`. That is an instruction file, so it is left for the owner.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-24 10:12 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-309 at `b4ca2ea`
**Base**: main
**Depth**: Deep (reason: 719 changed lines across 10 files; merge_pr.sh gate and a SKILL.md touched)
**Must-fix**: 3 | **Suggestions**: 1
**Round**: 1 | **Ship**: continue — round 1: 3 must-fix; first round always re-reviews after fixes

Reviewers: static (shellcheck --severity=warning + bash -n: clean), governance, plan drift (no drift; all planned files changed), Claude adversarial (fresh; ran, 0 must-fix, 1 suggestion; gate suite 83/83, triage suite 36/36; merge-conflict resolution in merge_pr.sh and test_merge_pr_gate.sh verified equivalent to main, nothing lost or duplicated).
- Gemini (agy): failed — empty response; headless mode auto-denied a read_file (ViewFile) tool action.
- Codex: ran — 2 must-fix (both reproduced/confirmed below).
- Copilot: skipped — quota exhausted (September 2026).

### Findings
- [x] (must-fix) Rename detection hides the source path: `git diff --name-only` reports only the destination, so moving a code file into `.agent/work-plans/issue-<N>/` counts as bookkeeping-only (reproduced: helper rc 0). Use `--no-renames`; add a rename test to both the sources suite and the gate suite. Codex must-fix, Claude adversarial suggestion — `.agent/scripts/_bookkeeping.sh:42`
- [x] (must-fix) Git errors are classified as "stale" (rc 1), not "unverifiable" (rc 3): any non-zero `merge-base --is-ancestor` (including 128 on a missing object) and a failed `git diff` both return 1, so `sources` lists them as verified-stale with no stderr warning. That is the silent path this issue exists to remove. Return 3 for is-ancestor rc other than 0/1, for a diff failure, and for a non-ancestor in a shallow repository; add tests. Merge gate behaviour is unchanged (1 and 3 are both "not covered"). Codex — `.agent/scripts/_bookkeeping.sh:38-45`
- [x] (must-fix) Missing consequence: the AGENTS.md Script Reference still says `sources` is "correlated by head SHA" and has no row for the new `_bookkeeping.sh`. AGENTS.md is Ask First, so this needs the owner's go-ahead — `AGENTS.md:419`
- [x] (suggestion) ADR-0013 References says one helper applies the rule "for both the gate and the CI target". Add `review_progress.sh sources` (#309) and the helper's new home, `_bookkeeping.sh`, as a cross-reference addendum (ADR-0008) — `docs/decisions/0013-progress-md-entry-type-vocabulary.md:209-216`

## Implementation
**Status**: complete
**When**: 2026-09-24 10:39 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-309 at `65ecdb7`
**Addressed**: Local Review (Pre-Push) at `b4ca2ea` (2026-09-24 10:12 -04:00)
**Commits**: 88cd46c, 6aed940, 7ce5bae, a724ecb, 65ecdb7

### Actions
- [x] (must-fix) Rename blind spot: `git diff --no-renames` so a code file renamed into `.agent/work-plans/issue-<N>/` names its old path; tests h16 (sources) and g9 (gate) — `.agent/scripts/_bookkeeping.sh:42` (88cd46c)
- [x] (must-fix) Git failures are unverifiable (rc 3), not stale: an ancestry check that errors or reports an unreadable commit on stderr (git exits 1 in that case), a failed diff, and a non-ancestor in a shallow repository; `sources` lists them as unverifiable with its warning; gate unchanged (1 and 3 both "not covered"); tests h17-h20 (sources) and g10 (gate) — `.agent/scripts/_bookkeeping.sh:38-45` (6aed940)
- [x] (must-fix) AGENTS.md Script Reference: `review_progress.sh` row's `sources` clause rewritten; new **(source)** row for `_bookkeeping.sh`; table rows only (owner standing rule, #269 rule 2) — `AGENTS.md:419` (a724ecb)
- [x] (suggestion) ADR-0013 References: cross-reference addendum for #309 and `_bookkeeping.sh` (ADR-0008) — `docs/decisions/0013-progress-md-entry-type-vocabulary.md:209-216` (65ecdb7)

### Notes
- Same rename blind spot found and fixed beyond the cited line: the CI walk-back in `merge_pr.sh` (`_ci_walk_bookkeeping`) listed paths with `git diff --name-only`; now `--no-renames`, test ci-31b (7ce5bae).
- Mutation checks: removing `--no-renames` fails h16 and g9; restoring the pre-fix `_bookkeeping.sh` fails h17-h20 and g10; ci-31b failed before its fix.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-24 10:49 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent a54034ed4b2be2139, resume 1 of 3)

**Branch**: feature/issue-309 at `0d59d41`
**Base**: main
**Depth**: Deep (reason: whole-branch diff 900+ lines across 12 files, including merge_pr.sh, AGENTS.md, an ADR and a SKILL.md)
**Must-fix**: 2 | **Suggestions**: 1
**Round**: 2 | **Ship**: continue — round 2: 2 must-fix include a design/correctness concern (not mechanical)

All round-1 findings are verified closed:
- Renames: `--no-renames` in `_bookkeeping.sh` and in the CI walk-back. A rename whose two paths are both exempt (docs/ROADMAP.md to docs/roadmap.md) is still accepted.
- git failures now return 3 (unverifiable). Tests h16-h20, g9, g10 and ci-31b cover both fixes.
- AGENTS.md now has the two Script Reference rows, and ADR-0013 has the References addendum. Their claims match the code.

The out-of-findings CI walk-back change (7ce5bae) only makes the walk more conservative, and ci-31b pins it.

Static checks are clean (shellcheck, bash -n). The adversarial reviewer ran the suites: triage 41/41, gate 86/86.

Reviewers:
- Gemini (agy): failed — empty response; headless mode auto-denied a read_file (ViewFile) tool action (same as round 1).
- Codex: ran — 1 must-fix (confirmed by code reading, below).
- Copilot: skipped — quota exhausted (September 2026).
- Claude adversarial (fresh): ran — 1 must-fix (reproduced), 1 suggestion.

### Findings
- [x] (must-fix) Bookkeeping coverage resurrects findings a later `## Integrated Review` already disposed of. triage-reviews and address-findings never tick the original Local Review's boxes, so after the Integrated Review's own progress commit the older Local Review still covers the head and `sources` re-lists its closed, deferred or false-positive findings as open on every later triage. Needs a supersession rule: the newest covering review entry wins, and older covering entries are reported in `dropped_entries` (e.g. reason `superseded`). Add a regression test. Design call. Codex — `.agent/scripts/review_progress.sh:418-431`
- [x] (must-fix) A verified non-ancestor (git exit 1) is misreported as unverifiable whenever git writes any stderr. Reproduced with `GIT_TRACE=1`: rc 3 instead of rc 1, plus a false warning. Treat exit 1 as a git failure only when stderr carries a git error line (`^(error|fatal):`), or run the check with `GIT_TRACE*` unset; add a test. Claude adversarial — `.agent/scripts/_bookkeeping.sh:48-53`
- [x] (suggestion) The gate's refusal still labels an unverifiable coverage check "stale review". The decision is right, but an operator reading "stale" may reach for `--force-unreviewed`. Word it by rc (e.g. "review coverage could not be confirmed: …"), and update g10's expected text — `.agent/scripts/merge_pr.sh:743`

## Implementation
**Status**: complete
**When**: 2026-09-24 11:08 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a7d34766692007bc4, resume 1 of 3)

**Branch**: feature/issue-309 at `5c4b64c`
**Addressed**: Local Review (Pre-Push) at `0d59d41` (2026-09-24 10:49 -04:00)
**Commits**: d01d088, 5ce465d, 5c4b64c

Owner decision (finding 1): "Newest current review wins" — only the newest review entry that covers the head (via the bookkeeping rule) feeds `sources`; older covering review entries are reported in `dropped_entries` with reason `superseded`.

### Actions
- [x] (must-fix) Supersession: of the review entries `sources` reads (Local Review, Local Review (Pre-Push), Integrated Review) with a PR/branch correlation, only the newest covering one feeds `local_findings` (even when it has no open findings); older covering entries with open findings are dropped as `superseded`. Tests h21 (Local Review then Integrated Review + its progress commit) and h22 (newest covering review fully addressed); the existing single-review cases h1-h20 still pass. triage-reviews SKILL.md, the AGENTS.md `review_progress.sh` row and the ADR-0013 addendum updated — `.agent/scripts/review_progress.sh:418-431` (d01d088)
- [x] (must-fix) A verified non-ancestor stays rc 1 when git writes non-error stderr: only `^(error|fatal):` lines make exit 1 a failure, and GIT_TRACE* is unset for the check. Tests h23 (GIT_TRACE=1; a shim printing a warning) — `.agent/scripts/_bookkeeping.sh:48-53` (5ce465d)
- [x] (suggestion) Gate refusal worded by rc: rc 3 reads "review coverage could not be confirmed: …", rc 1 keeps "stale review"; g10 updated — `.agent/scripts/merge_pr.sh:743` (5c4b64c)

### Notes
- Mutation checks: disabling supersession fails h21 and h22; the pre-fix helper fails both h23 cases; removing only the error-line rule (trace unset kept) fails the shim h23 case; dropping the rc-3 label fails g10.
- Unverifiable warnings are now printed only for entries whose open findings are dropped (the classification pass checks every review entry).
- The gate's pre-helper reasons (no local worktree, review SHA or head not resolvable) still say "stale review"; the finding scoped the rewording to the helper's rc.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-24 11:15 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent a54034ed4b2be2139, resume 2 of 3)

**Branch**: feature/issue-309 at `c022692`
**Base**: main
**Depth**: Deep (reason: whole-branch diff 1000+ lines across 12 files, including merge_pr.sh, AGENTS.md, an ADR and a SKILL.md)
**Must-fix**: 2 | **Suggestions**: 1
**Round**: 3 | **Ship**: recommended — round 3: 2 mechanical must-fix (prev 2), not rising — fix and ship rather than another full round

All round-2 findings are verified closed:
- Supersession is implemented to the owner's rule, with tests h21/h22.
- The adversarial reviewer probed the edge cases; all behave as intended:
  - A newest covering entry with zero open findings still supersedes.
  - An unverifiable newer entry does not supersede a verified older one.
  - At the same SHA, file order decides.
  - Implementation and Checkpoint entries, and entries with no correlation, cannot enter the pool (`--type` filter plus the kind check).
- GIT_TRACE no longer misclassifies (h23); only `^(error|fatal):` lines count, which also covers trace variables not in the `env -u` list.
- The gate wording now depends on the helper's rc (g10).

Static checks are clean (shellcheck). The adversarial reviewer ran the suites: triage 45/45, gate 86/86.

Reviewers:
- Gemini (agy): failed — empty response; headless mode auto-denied a read_file (ViewFile) tool action (third round running).
- Codex: ran — 1 must-fix (reproduced for diff.relative).
- Copilot: skipped — quota exhausted (September 2026).
- Claude adversarial (fresh): ran — 1 must-fix.

### Findings
- [x] (must-fix) Git config can filter the coverage diff. With `diff.relative=true`, running from a subdirectory lists only that subdirectory's paths (reproduced), so a code change elsewhere reads as covered. `diff.ignoreSubmodules=all` likewise hides a submodule pointer change (Codex reproduced). Add `--no-relative --ignore-submodules=none` to both diffs, plus tests. Codex — `.agent/scripts/_bookkeeping.sh:70`, `.agent/scripts/merge_pr.sh:1097`
- [x] (must-fix) The gate's three pre-helper not-covered branches still say "stale review" for conditions that are really unchecked: no local worktree, review SHA not resolvable, head not present locally. That is the operator risk this PR's own comment names. Use the "review coverage could not be confirmed" label for them too, plus a test. It is in scope here, not a follow-up. Claude adversarial — `.agent/scripts/merge_pr.sh:726-737`
- [x] (suggestion) The supersession rationale in the triage skill says a newer review "already disposed of" the older one's findings. That holds for a newer Integrated Review. It does not hold for a newer PR-mode `## Local Review` after a pre-push review: that review re-reads the code independently, and the pre-push entry's unaddressed suggestions are now dropped as `superseded`. The behaviour follows the owner's rule, but the text should say what actually happens (or the owner confirms this case) — `.claude/skills/triage-reviews/SKILL.md:182-187`

## Checkpoint
**Status**: complete
**When**: 2026-09-24 11:39 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: rounds
**Decision**: address

Review round 4, then publish (Recommended) — fix both mechanical must-fix (git-config-proof diffs; gate "could not be confirmed" labels), then pre-push round 4. Supersession: "Only triage supersedes" — only a newer Integrated Review drops older review entries' open findings; nothing vanishes without a decision (replaces the earlier "newest current review wins" rule).

## Implementation
**Status**: complete
**When**: 2026-09-24 11:57 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a7d34766692007bc4, resume 2 of 3)

**Branch**: feature/issue-309 at `5b518cf`
**Addressed**: Local Review (Pre-Push) at `c022692` (2026-09-24 11:15 -04:00), with the owner's Checkpoint (2026-09-24 11:39 -04:00)
**Commits**: 93dd42a, 83e641d, 5b518cf

Owner decision (replaces "newest current review wins"): "Only triage supersedes — only a newer Integrated Review drops older review entries' open findings; nothing vanishes without a decision."

### Actions
- [x] (must-fix) Coverage diffs immune to user git config: `--no-relative --ignore-submodules=none` on the `_bookkeeping.sh` diff and the CI walk-back diff. Tests h24 (diff.relative=true, sources run from the work-plan dir), h25 (diff.ignoreSubmodules=all, submodule pointer bump via the bridge) and ci-31c (walk-back over a submodule bump) — `.agent/scripts/_bookkeeping.sh:70`, `.agent/scripts/merge_pr.sh:1097` (93dd42a)
- [x] (must-fix) Gate label: "stale review" only for helper rc 1; no local worktree, unresolvable review SHA, head not present locally and rc 3 all read "review coverage could not be confirmed: …". Tests g11 (unresolvable review SHA) and g12 (PR head not present locally) — `.agent/scripts/merge_pr.sh:726-737` (83e641d)
- [x] (suggestion) Supersession rationale, rewritten for the owner's changed rule: only a newer covering Integrated Review (or legacy External Review) supersedes; a newer Local Review / Local Review (Pre-Push) supersedes nothing. h21/h22 kept (h22 relabelled); new h26 (pre-push suggestion survives a later PR-mode Local Review with no findings). triage-reviews SKILL.md, AGENTS.md row and ADR-0013 addendum updated — `.claude/skills/triage-reviews/SKILL.md:182-187` (5b518cf)

### Notes
- Mutation checks: flags removed fails h24, h25, ci-31c; old gate label default fails g11, g12; old newest-wins code fails h26; supersession disabled fails h21, h22; any-newer-entry-supersedes fails h26.
- The "no local worktree" gate branch is reachable only for package worktrees (without a worktree the progress file cannot be read), so it has no dedicated test; it shares the default label with g11/g12.
- Suites: triage 48/48, gate 89/89, merge_pr 91/91.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-24 12:07 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent a54034ed4b2be2139, resume 3 of 3)

**Branch**: feature/issue-309 at `9fed386`
**Base**: main
**Depth**: Deep (reason: whole-branch diff 1000+ lines across 12 files, including merge_pr.sh, AGENTS.md, an ADR and a SKILL.md)
**Must-fix**: 1 | **Suggestions**: 1
**Round**: 4 | **Ship**: recommended — round 4: 1 mechanical must-fix (prev 2), not rising — fix and ship rather than another full round

All round-3 findings are verified closed:
- Both coverage diffs pass `--no-relative --ignore-submodules=none`. The adversarial reviewer also re-probed color.diff, diff.external, diff.noprefix and a path with a space; none hides a change.
- The gate label defaults to "review coverage could not be confirmed"; "stale review" appears only on helper rc 1.
- "Only triage supersedes" is implemented, and SKILL.md, AGENTS.md and ADR-0013 describe it consistently with the code.

The new rule's edge cases were probed in real repos and hold:
- Two covering Local Reviews both feed `local_findings`.
- A newer Local Review is not superseded by an older Integrated Review.
- Of two Integrated Reviews, the older is superseded.
- A legacy External Review supersedes (via progress_read's predecessor mapping).

Tests h24-h26, g11, g12 and ci-31c fail on the pre-fix commit. Static checks are clean (shellcheck). The adversarial reviewer ran the suites: triage 48/48, gate 89/89.

Reviewers:
- Gemini (agy): failed — empty response; headless mode auto-denied a read_file (ViewFile) tool action (fourth round running).
- Codex: ran — 1 must-fix (confirmed by code reading, below).
- Copilot: skipped — quota exhausted (September 2026).
- Claude adversarial (fresh): ran — 0 must-fix, 1 suggestion.

### Findings
- [x] (must-fix) Supersession ignores the Integrated Review's `**Status**`. A `partial` or `failed` triage entry (both allowed by ADR-0013) still suppresses every older covering finding as `superseded`. Codex reproduced this with a partial Integrated Review that has no findings. This breaks the owner's "nothing vanishes without a decision" rule. Only a `complete` Integrated/External Review should supersede. Add tests for partial and failed, and say so in the triage-reviews SKILL.md `superseded` bullet. Codex — `.agent/scripts/review_progress.sh:436-438`
- [x] (suggestion) No test pins supersession by a legacy `## External Review`; it was verified only by hand. Add a copy of h21 with an `## External Review (Round N)` heading — `.agent/scripts/tests/test_triage_reviews_integration.sh`

## Checkpoint
**Status**: complete
**When**: 2026-09-24 12:21 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: rounds
**Decision**: address

Fix + test, then publish (Recommended) — fix pass for the round-4 must-fix (only a complete Integrated/External Review supersedes) including the optional External Review test; then publish without a 5th pre-push round; the PR-mode re-review checks it.

## Implementation
**Status**: complete
**When**: 2026-09-24 12:30 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a7d34766692007bc4, resume 3 of 3)

**Branch**: feature/issue-309 at `257bb7f`
**Addressed**: Local Review (Pre-Push) at `9fed386` (2026-09-24 12:07 -04:00), with the owner's Checkpoint "Fix + test, then publish" (2026-09-24 12:21 -04:00)
**Commits**: 910b0d4, 257bb7f

### Actions
- [x] (must-fix) Only an Integrated Review (or legacy External Review) with `**Status**: complete` supersedes; a partial or failed one decided nothing and supersedes nothing. Tests h27 (partial, failed: the older finding is still listed next to the triage entry's own). triage-reviews SKILL.md `superseded` bullet, the AGENTS.md row and the ADR-0013 addendum say "complete" — `.agent/scripts/review_progress.sh:436-438` (910b0d4)
- [x] (suggestion) h28: a complete `## External Review (Round 2)` supersedes the older Local Review (Pre-Push) — `.agent/scripts/tests/test_triage_reviews_integration.sh` (257bb7f)

### Notes
- Mutation checks: dropping the status filter fails both h27 cases; dropping the predecessor mapping from the triage check fails h28.
- Suites: triage 51/51, gate 89/89, merge_pr 91/91; shellcheck clean.
