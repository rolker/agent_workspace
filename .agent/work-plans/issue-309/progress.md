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

## Checkpoint
**Status**: complete
**When**: 2026-09-24 12:33 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: rounds
**Decision**: publish

Recorded from the owner's earlier answer at the round-4 rounds checkpoint: "Fix + test, then publish (Recommended) — publish without a 5th pre-push round; the PR-mode re-review checks it." The fix pass (1593fd1) is complete; publishing now, then a PR-mode review of the last fix before triage.

## Local Review
**Status**: complete
**When**: 2026-09-24 12:41 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**PR**: #349 at `df33a3f`
**Depth**: Deep (reason: whole-PR re-review; enforcement script merge_pr.sh plus governance files AGENTS.md, ADR-0013, triage-reviews SKILL.md; 1401+/80- over 12 files)
**Must-fix**: 1 | **Suggestions**: 5

Last fix checked: 910b0d4 (only a complete Integrated/External Review supersedes; h27) and 257bb7f (h28) behave as claimed. The main merge at df33a3f touched none of this PR's files (only #336's reviewer scripts, their test and issue-336 work-plans; #334 was already in the branch). Tests: triage integration 51/0, merge gate 89/0, merge_pr 91/0, convergence 31/0; shellcheck clean. Reviewers: Claude adversarial ran; Codex completed; Gemini failed (empty response, one RunCommand auto-denied headlessly, even with #336's no-tools prompt); Copilot skipped (quota).

### Findings
- [ ] (must-fix) Non-ASCII paths break coverage: `git diff --name-only` quotes them under the default `core.quotePath=true`, so a bookkeeping-only file such as `.agent/work-plans/issue-7/notes/café.md` fails the allowlist match. The helper then returns rc 1 (stale): `sources` drops current findings as stale, and the gate refuses valid coverage. Read NUL-delimited output (`--name-only -z`), keep the diff-failure check, apply the same change to the CI walk-back (`merge_pr.sh:1099`), and add a test. Codex reproduced it; the local repro was blocked by permissions. — `.agent/scripts/_bookkeeping.sh:73`
- [ ] (suggestion) Two central supersession invariants have no test. Mutating `j > i` to `j != i`, so a triage entry supersedes later Local Reviews, still passes 51/51. Dropping the covering check from `triage_covering`, so a stale Integrated Review supersedes, also passes 51/51. Add a Local Review after a complete Integrated Review, and a complete Integrated Review at a code-changed SHA followed by a covering Local Review. Found by the Claude adversarial reviewer. — `.agent/scripts/review_progress.sh:438-447`
- [ ] (suggestion) A review entry whose correlation line does not parse is filtered out before classification. Examples are `**PR**: 9 at` with no `#`, and every real legacy External Review, which has no `at <sha>`. Its open findings appear in neither `local_findings` nor `dropped_entries`, with no warning. This was already the behaviour before this PR, but it now contradicts the new `dropped_entries` contract. List these entries as `unverifiable` ("no PR/Branch correlation SHA") and warn. Claude adversarial, reproduced. — `.agent/scripts/review_progress.sh:433`
- [ ] (suggestion) A legacy `## External Review` counts as triage for supersession, but ADR-0013 defines it as a single-source GitHub findings table that never ruled on Local Review findings. Against the owner's rule verbatim ("only a newer Integrated Review drops..."), letting it supersede drops findings without a decision. Real exposure is small (see the previous finding). Either take it out of the triage set, updating h28, or record in SKILL.md and the ADR addendum that the owner accepts this approximation. Owner call. Found by the Claude adversarial reviewer. — `.agent/scripts/review_progress.sh:437`
- [ ] (suggestion) The merge gate does not read `**Status**`. A `partial` or `failed` latest Integrated Review with no open must-fix passes gate condition (a), while `sources` (after 910b0d4) still lists the older Local Review's open must-fix findings. The gate and the integrator input now disagree. Require `status == complete` for a non-Local latest entry, or open a follow-up issue. This comes from reading the code; it was not run through the gate harness. Found by the Claude adversarial reviewer. — `.agent/scripts/merge_pr.sh:712-716`, `:755-757`
- [ ] (suggestion) The h21 header comment still cites the retired owner decision "Newest current review wins". Update it to "Only triage supersedes". — `.agent/scripts/tests/test_triage_reviews_integration.sh:457`

## Implementation
**Status**: complete
**When**: 2026-09-24 13:11 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #349 at `1458639`
**Addressed**: Local Review at `df33a3f` (2026-09-24 12:41 -04:00), with the owner's decisions: "Fix all (Recommended)"; finding 4: "No, remove it (Recommended) — Only a complete Integrated Review supersedes; test h28 flips to 'does not supersede'."; finding 5: "Gate requires complete, here (Recommended) — A non-Local latest entry must be **Status**: complete for gate condition (a); add a gate test." Standing rule: "Only triage supersedes — only a newer Integrated Review drops older review entries' open findings; nothing vanishes without a decision."
**Commits**: 489a7ca, 41de3b7, 67700d4, 6aec69f, f214382, 1458639

### Actions
- [x] (must-fix) Non-ASCII paths: `_bookkeeping.sh` and the `merge_pr.sh` CI walk-back read `git diff --name-only -z` (NUL-delimited; --no-renames --no-relative --ignore-submodules=none kept; git's exit status arrives as an `rc=<N>` trailer after the last NUL, so a failed diff is still rc 3 / stops the walk). Tests: sources h29 (non-ASCII work-plan file covered; non-ASCII code file stale and named as spelled, under forced core.quotePath=true), gate g13 and CI walk-back ci-31d — `.agent/scripts/_bookkeeping.sh:73`, `.agent/scripts/merge_pr.sh:1099` (489a7ca)
- [x] (suggestion) Supersession invariants pinned: h30 (a Local Review written after a complete Integrated Review is not superseded by it), h31 (a complete Integrated Review at a pre-change SHA covers nothing and supersedes nothing) — `.agent/scripts/review_progress.sh:438-447` (41de3b7)
- [x] (suggestion) Entries whose PR/Branch line does not parse are listed in `dropped_entries` as `unverifiable` (sha "", "no PR/Branch correlation SHA") with a stderr warning; test h32; SKILL.md, AGENTS.md row and ADR-0013 addendum updated — `.agent/scripts/review_progress.sh:433` (67700d4)
- [x] (suggestion, owner: remove) A legacy External Review no longer supersedes; h28 flipped to "does not supersede"; triage-reviews SKILL.md superseded bullet and the ADR-0013 addendum say so (the AGENTS.md row already named only a complete Integrated Review) — `.agent/scripts/review_progress.sh:437` (6aec69f)
- [x] (suggestion, owner: gate requires complete) Gate condition (a) refuses a non-Local latest entry whose **Status** is not complete ("has **Status**: <s>, not complete — a partial or failed triage decided nothing"); tests d3/d4 (report-only) and d3 (enforce); triage-reviews SKILL.md next-step note updated — `.agent/scripts/merge_pr.sh:712-716`, `:755-757` (f214382)
- [x] (suggestion) h21 header cites "Only triage supersedes" — `.agent/scripts/tests/test_triage_reviews_integration.sh:457` (1458639)

### Notes
- Mutation checks (each fails only the new tests, restored after): newline-read without -z in `_bookkeeping.sh` fails h29 x2 and g13 (h18 too, since that mutation also dropped the rc check); the same in the walk-back fails ci-31d; `j > i` -> `j != i` fails h30; dropping the covering check from `triage_covering` fails h31; skipping the uncorrelated loop fails h32; restoring the predecessor match in `is_triage` fails h28; disabling the status branch in the gate fails d3, d4 and enforce d3.
- Suites: triage integration 56/0, merge gate 94/0, merge_pr 91/0, convergence 31/0, address_findings 15/0; shellcheck (warning) clean.
- The source entry's boxes are not ticked: `review_progress.sh check` only targets the latest Integrated Review / Local Review (Pre-Push), and the source here is a post-PR `## Local Review`. The next triage rules on them.

## Local Review
**Status**: complete
**When**: 2026-09-24 13:17 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent aea98abffc0d1b756, resume 1 of 3)

**PR**: #349 at `9dc974f`
**Depth**: Deep (reason: whole-PR re-review; enforcement script merge_pr.sh plus governance files AGENTS.md, ADR-0013, triage-reviews SKILL.md)
**Must-fix**: 1 | **Suggestions**: 2

All six findings from the Local Review at `df33a3f` are closed in the code:
- 489a7ca: `-z` diffs with an rc trailer. The adversarial reviewer probed empty diffs, newline and `rc=0` filenames, glob-like names, a failed diff, user diff config and set -euo pipefail. It found the trailer cannot be spoofed.
- 41de3b7: h30/h31.
- 67700d4: h32.
- 6aec69f: h28 flipped.
- f214382: the gate requires a complete status, tested by d3/d4. Every Integrated/External Review in the repo is complete, so no legitimate flow is newly blocked.
- 1458639: the h21 comment.

Suites: triage integration 56/0, merge gate 94/0, merge_pr 91/0, convergence 31/0. shellcheck is clean. There has been no merge from main since `df33a3f`.

Reviewers:
- Claude adversarial: ran fresh; no must-fix.
- Codex: completed; found 1 must-fix.
- Gemini: failed; the response hit the output token limit.
- Copilot: skipped (quota).

### Findings
- [ ] (must-fix) The coverage bridge decodes the helper's stdout strictly as UTF-8 (`text=True`). The helper's rc-1 reason quotes the raw git path. A code file whose name is not valid UTF-8 (e.g. `bad-\xff.sh`) then raises `UnicodeDecodeError`, a ValueError that `except OSError` does not catch, so `sources` exits 1 with a traceback and no JSON. Codex reproduced it; the decode failure was confirmed locally. Fix: decode with `errors="backslashreplace"` (or catch ValueError and report unverifiable), and add a regression test — `.agent/scripts/review_progress.sh:389-392`
- [ ] (suggestion) The gate's status branch has no test for a mixed-case or padded `Complete`, nor for an Integrated Review with no `**Status**` line, which should refuse and name `<missing>`. Both behave correctly today; this was checked only against the jq expressions. Found by the Claude adversarial reviewer — `.agent/scripts/tests/test_merge_pr_gate.sh` (near d3/d4)
- [ ] (suggestion) An entry with no parseable PR/Branch SHA can never be superseded. A pre-ADR-0013 entry with open boxes is therefore re-listed as `unverifiable` on every future triage, which follows the owner's rule. Say in the triage-reviews SKILL.md that this is expected and that the triager rules on it once. Found by the Claude adversarial reviewer — `.claude/skills/triage-reviews/SKILL.md` (unverifiable bullet)

## Implementation
**Status**: complete
**When**: 2026-09-24 13:31 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent af3d391529e7ce405, resume 1 of 3)

**PR**: #349 at `1a15852`
**Addressed**: Local Review at `9dc974f` (2026-09-24 13:17 -04:00), under the owner's standing "fix it completely" standard (no new owner decision needed)
**Commits**: efffa60, e86ac56, 1a15852

### Actions
- [x] (must-fix) The coverage bridge decodes the helper's stdout and stderr with `encoding="utf-8", errors="backslashreplace"`. A non-UTF-8 code path is reported stale (shown as `bad-\xff.sh`) instead of crashing with a traceback. That subprocess call is the bridge's only read of git output. Test h33 — `.agent/scripts/review_progress.sh:389-392` (efffa60)
- [x] (suggestion) Gate tests d5 (no `**Status**` line: refused, named `<missing>`) and e5 (`**Status**:  Complete  ` passes) — `.agent/scripts/tests/test_merge_pr_gate.sh` (e86ac56)
- [x] (suggestion) triage-reviews SKILL.md unverifiable bullet: an entry with no parseable SHA can never be superseded, so it is re-listed as unverifiable every triage. This is expected; the triager rules on it once and cites that ruling afterwards — `.claude/skills/triage-reviews/SKILL.md` (1a15852)

### Notes
- Mutation checks:
  - Restoring `text=True` fails h33 with a traceback.
  - Dropping `ascii_downcase` in the gate fails e5.
  - Dropping the `<missing>` placeholder fails d5.
  - Dropping the gate's jq whitespace trim does not fail e5. progress_read.py already strips field values, so that trim is redundant defence; e5 pins the end-to-end behaviour.
- Suites: triage integration 57/0, merge gate 96/0, merge_pr 91/0, convergence 31/0; shellcheck (warning) clean.
- The source entry's boxes are not ticked, for the same reason as last pass: `check` targets only Integrated Review / Local Review (Pre-Push) entries.

## Local Review
**Status**: complete
**When**: 2026-09-24 13:37 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent aea98abffc0d1b756, resume 2 of 3)

**PR**: #349 at `f2118b0`
**Depth**: Deep (reason: whole-PR re-review; enforcement script merge_pr.sh plus governance files AGENTS.md, ADR-0013, triage-reviews SKILL.md)
**Must-fix**: 1 | **Suggestions**: 0

The three findings from the Local Review at `fabaa34` are closed:
- efffa60: the bridge decodes with errors="backslashreplace", tested by h33. The adversarial reviewer checked every other decode point in cmd_sources; none can crash.
- e86ac56: d5 (`<missing>` refused) and e5 (mixed-case/padded Complete).
- 1a15852: the SKILL.md text matches the code.

The surviving mutation (the gate's jq whitespace trim) does not matter. progress_read.py's `_field` already strips the value, so the trim is redundant defence, and d5 asserts the exact refusal text.

Suites: triage integration 57/0, merge gate 96/0, merge_pr 91/0, convergence 31/0. shellcheck is clean. There has been no merge from main since `df33a3f`.

Reviewers:
- Claude adversarial: ran fresh; found 1 must-fix.
- Codex: completed; no issues.
- Gemini: failed; the response hit the output token limit.
- Copilot: skipped (quota).

### Findings
- [ ] (must-fix) Raw path bytes from the `-z` diff can corrupt progress.md through the merge gate.
  - Since 489a7ca, the helper's stale reason quotes the path unescaped; only `\n` is escaped. Before, git C-quoted it as ASCII (`"bad-\377.sh"`). efffa60 fixed only the Python bridge; the bash gate passes the raw reason on.
  - Path: `_gate_why`, then `_gate_record`, then `**Conditions**: ${why}` (`merge_pr.sh:792`, from `:908` / `:924`). Under `--report-only` (also the project-PR default) or `--force-unreviewed`, this commits a `## Merge (...)` entry holding byte 0xff.
  - Effect: after that, progress_read.py fails to decode the file. `sources` exits 2, and every later gate run reports progress.md unparseable. Under `--force-unreviewed` the corrupt file reaches main.
  - A `\r` or ESC in a path goes raw too: it splits the Conditions line or reaches the terminal.
  - Fix: escape the displayed path in the helper (`printf %q`, or C-quote it like core.quotePath), keeping `-z` for matching. Add a gate test as the counterpart of h33.
  - Claude adversarial, reproduced (rc 1 reason contains byte 0xff; progress_append commits it; progress_read.py then raises UnicodeDecodeError). — `.agent/scripts/_bookkeeping.sh:103`

## Implementation
**Status**: complete
**When**: 2026-09-24 13:47 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent af3d391529e7ce405, resume 2 of 3)

**PR**: #349 at `31d484a`
**Addressed**: Local Review at `f2118b0` (the newest PR-mode review, recorded in a8ea93e), under the owner's standing "fix it completely" standard
**Commits**: 31d484a

### Actions
- [x] (must-fix) Raw path bytes can no longer reach progress.md. A new `_bk_display` in `_bookkeeping.sh` C-quotes every value a reason quotes, like core.quotePath:
  - backslash, double quote, `\t`, `\n` and `\r` get C escapes;
  - a backtick becomes `\140`;
  - every other non-printable or non-ASCII byte becomes a three-digit octal escape.
  - The quoted values are the path, the SHAs, git's error line, the worktree path and the issue argument.
  - Matching still uses the raw `-z` path.
  - Tests: h34 (the escaping itself) and g14 (gate counterpart of h33: a code file named `bad-<0xff><CR><ESC>.sh` under `--report-only` gives the reason `touches bad-\377\r\033.sh`; the record holds no byte >= 0x80, CR or ESC, and progress_read.py still parses the file). h29 and h33 now expect the C-quoted form. — `.agent/scripts/_bookkeeping.sh:103` (31d484a)

### Notes
- Other routes checked:
  - The CI walk-back prints only SHAs, never a path.
  - `sources` warnings print the helper's reason, now ASCII (the bridge's backslashreplace decode stays as a second layer), plus entry type and When read from the UTF-8 progress.md.
  - merge_pr.sh's own gate reasons quote only hex SHAs from progress_read.py, entry types from progress.md, and workspace-managed worktree paths. None of them come from diff output.
- Mutation checks:
  - Quoting the raw path in the stale reason fails h29, h33 and g14.
  - Making `_bk_display` the identity fails h34, h29, h33 and g14.
  - Dropping the backtick escape fails h34.
- Suites: triage integration 58/0, merge gate 97/0, merge_pr 91/0, convergence 31/0; shellcheck (warning) clean.
- The source entry's box is not ticked: `check` targets only Integrated Review / Local Review (Pre-Push) entries.

## Local Review
**Status**: complete
**When**: 2026-09-24 13:54 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved
**Dispatch**: resumed (agent aea98abffc0d1b756, resume 3 of 3)

**PR**: #349 at `3d30684`
**Depth**: Deep (reason: whole-PR re-review; enforcement script merge_pr.sh plus governance files AGENTS.md, ADR-0013, triage-reviews SKILL.md)
**Must-fix**: 0 | **Suggestions**: 4

The must-fix from the Local Review at `a8ea93e` is closed by 31d484a (`_bk_display`, tests h34/g14):
- **Byte sweep:** every byte 0x01-0xff escapes to printable ASCII; \t \n \r get C escapes; backtick becomes \140; multibyte UTF-8 is escaped byte by byte; no sign-extension.
- **Locale:** LC_ALL=C does not leak to the caller.
- **Idempotency:** the escaped Conditions text round-trips through progress_read.py and jq, so `_gate_already_recorded` still matches.
- **Coverage:** every value the helper quotes is escaped: $wt, SHAs, issue, git stderr, and the CI-target reason.

The fixer's claim that merge_pr.sh's own reasons are safe unescaped is only partly true (suggestions 1-2).

Suites: triage integration 58/0, merge gate 97/0, merge_pr 91/0, convergence 31/0. shellcheck is clean. There has been no merge from main since `df33a3f`.

Reviewers:
- Claude adversarial: ran fresh; no must-fix.
- Codex: completed; no issues.
- Gemini: failed; the response hit the output token limit, for the third round in a row.
- Copilot: skipped (quota).

### Findings
- [ ] (suggestion) Gate reasons carry branch-committed text raw: the entry heading (`_gate_r_type`), plus the **Status** and **Verdict** values via `jq -r`. progress_read.py accepts any `(...)` heading suffix. The heading `## Local Review (x\x1b]0;pwned\x07)` parses as Local Review, and its ESC/BEL bytes reach the operator's terminal and the Merge record's **Conditions**. The record stays valid UTF-8, but this breaks the commit's "safe ASCII reason" invariant. Wrap these three in `_bk_display`. Claude adversarial, reproduced — `.agent/scripts/merge_pr.sh:757`, `:765` and the Verdict reason
- [ ] (suggestion) Operator-local paths (`$PKG_WT_DIR`, `$_gate_wt`, `$_gate_progress`, `$_ci_wt`) enter gate reasons raw, while the helper escapes the same worktree path, so a non-ASCII root prints two ways. Escape them too, or narrow the stated claim to "the helper's reasons are safe ASCII". Claude adversarial — `.agent/scripts/merge_pr.sh:702`, `:704`, `:710`, `:722`, `:741`
- [ ] (suggestion) `_bk_display` is quadratic in length (`${s:i:1}` rescans the string). Measured: 64 KiB takes 8.7 s. A committed 80 KB path (git update-index --cacheinfo) makes `--review` take 10.4 s and prints an 80 KB reason line into **Conditions**. Cap the displayed value (e.g. 256 bytes plus an ellipsis) before the loop. Claude adversarial, measured — `.agent/scripts/_bookkeeping.sh:36-52`
- [ ] (suggestion) The bridge comment still says the reason quotes a raw non-UTF-8 path. After 31d484a the helper output is always ASCII; say that `errors="backslashreplace"` is only a backstop now. h34 could also pin 0x01 and 0x7f, which the byte sweep shows are handled. Claude adversarial — `.agent/scripts/review_progress.sh:393-395`

## Integrated Review
**Status**: complete
**When**: 2026-09-24 13:58 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #349 at `1b488b5`
**Sources**: 2 (Local Review @ `3d30684`, covering head `1b488b5` by bookkeeping-only coverage; CI rollup). Copilot: 7 reviews, all quota notices with no comments, not sources. No human reviews or conversation comments.
**Cross-source confirmations**: 0
**CI**: pending

Sources were read with this branch's own `review_progress.sh sources` (the worktree's scripts, since the PR changes that helper). It listed the 4 open suggestions from the Local Review at `3d30684` and dropped the three earlier PR-mode Local Reviews as `stale`. Each suggestion was checked against the code at `1b488b5` and is accurate.

### Prior entries ruled on
The earlier PR-mode Local Reviews have open boxes because address-findings cannot tick a Local Review. Ruling on each once, from the later reviews and the code:
- Local Review at `df33a3f` (6 open): all closed. `-z` diff in `_bookkeeping.sh:117` and `merge_pr.sh:1117` (489a7ca, h29/g13/ci-31d). Invariant tests h30/h31 (41de3b7). Unparseable-SHA entries listed as unverifiable, h32 (67700d4). External Review no longer supersedes, per the owner's "No, remove it", h28 flipped (6aec69f). The gate requires a complete Integrated Review, per the owner's "Gate requires complete, here" (f214382). The h21 header cites "Only triage supersedes" (1458639). The `fabaa34` review confirmed these.
- Local Review at `9dc974f` (3 open): all closed. backslashreplace decode, h33 (efffa60). Gate d5/e5 (e86ac56). SKILL.md "can never be superseded" note (1a15852). The `f2118b0` review confirmed these.
- Local Review at `f2118b0` (1 open must-fix): closed by `_bk_display` (31d484a, h34/g14). The `3d30684` review verified it by a byte sweep and approved.

### Findings
- [ ] (suggestion, Local Review @ `3d30684`) Gate reasons carry branch-committed text raw. The `_gate_r_type` heading and the **Status** / **Verdict** values from `jq -r` reach the terminal and the Merge record's **Conditions** unescaped, so ESC/BEL in a heading suffix pass through. Confirmed at `merge_pr.sh:760-765`. Fix: wrap all three in `_bk_display`, and add a gate test with a control byte in the heading suffix — `.agent/scripts/merge_pr.sh`
- [ ] (suggestion, Local Review @ `3d30684`) Operator-local paths (`$PKG_WT_DIR`, `$_gate_wt`, `$_gate_progress`, `$_ci_wt`) enter gate reasons raw, while the helper escapes the same worktree path. A non-UTF-8 worktree root could put invalid bytes into a committed **Conditions** line, the failure 31d484a closed for diff paths. Confirmed at `merge_pr.sh:702-741`. Fix: pass them through `_bk_display` (preferred over narrowing the claim) — `.agent/scripts/merge_pr.sh`
- [ ] (suggestion, Local Review @ `3d30684`) `_bk_display` is quadratic: `${s:i:1}` in a per-character loop took 10.4 s on a committed 80 KB path, and it prints the whole value into **Conditions**. Fix: cap the input (e.g. 256 bytes plus a marker) before the loop, and add a test — `.agent/scripts/_bookkeeping.sh:36-52`
- [ ] (suggestion, Local Review @ `3d30684`) The bridge comment still says the reason quotes a raw non-UTF-8 path. Since 31d484a the output is ASCII, so `errors="backslashreplace"` is only a backstop. Reword the comment. Optionally, h34 can also pin 0x01 and 0x7f — `.agent/scripts/review_progress.sh:393-395`

### False positives
- None.
