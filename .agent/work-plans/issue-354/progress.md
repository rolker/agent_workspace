---
issue: 354
---

# Issue #354 — Pre-commit: run the script test suites only when a commit touches what they test (~133 s on every commit today)

## Issue Review
**Status**: complete
**When**: 2026-09-28 11:31 -0400
**By**: Claude Code Agent (claude-sonnet-5)

**Issue**: #354

### Scope Assessment

**Well-scoped?** Yes — single, bounded change: add a `files:` regex to the
`validate-script-tests` pre-commit hook, following the existing
`validate-adapter-contract` pattern in the same file. The acceptance criteria
are concrete and checkable (regex coverage, docs-only skip, CI unaffected,
stale-cost text updated).

**Right repo?** Yes — `.pre-commit-config.yaml` and `.agent/scripts/tests/`
are workspace infrastructure, not project content.

**Dependencies**: None identified. Builds on #269 (which introduced the
always_run hook) but doesn't require any other open issue.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Enforcement over documentation | OK | Narrows *when* the hook runs, doesn't remove it; CI (`make lint`) stays unconditional per ADR-0005's layering, so nothing is enforced only in docs. |
| Only what's needed | OK | Directly targets a measured, growing cost (10 suites/~18 s at #269 to 29 suites/~133 s today) rather than speculative tuning. |
| A change includes its consequences | Action needed | Issue names updating stale "~18 s" guidance but should also confirm no other doc/skill references the always-run cost or count (see below). |
| Test what breaks | Action needed | The acceptance criteria call for deriving the regex from what suites actually read, but the real risk — a future suite silently drifting outside the regex — needs its own regression test, not just careful derivation. Plan should name it explicitly. |
| Improve incrementally | OK | Small, reviewable, single-file-plus-tests change. |
| Workspace vs. project separation | OK | Pure workspace-infra change. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0004/0005 — Enforcement hierarchy / layered enforcement | Yes | Directly on point: local pre-commit is fast local feedback, CI is authoritative. Scoping the local hook while CI keeps running all suites is exactly the intended layering — issue already states this correctly. |
| ADR-0013 — progress.md entry-type vocabulary | Yes (process, not content) | Any progress.md entries this work produces must use canonical entry types via `review_progress.sh persist` / `progress_append.sh`. No effect on the fix itself. |
| Others (0001–0003, 0006–0012, 0014–0016) | No | Not a design-decision record, not adapter/project-type, not worktree/dispatch/session-root machinery. |

### Consequences

- Confirmed: no currently-live guidance doc (AGENTS.md, docs/roadmap.md,
  docs/design.md) states an "~18 s" or fixed suite-count figure for this
  hook — only the immutable issue-269 work-plan/progress history does,
  which is a historical record and shouldn't be rewritten. The issue's
  "update stale ~18 s guidance" acceptance item may therefore have no live
  target; the plan should confirm this rather than edit history.
- `.agent/scripts/tests/tests/test_pre_commit_config` or equivalent (none
  currently exists) — worth checking whether any script test already
  asserts on `.pre-commit-config.yaml` hook shape, since this change edits
  that shape.

### Recommendations

- In the plan, enumerate the path-family evidence per suite (script,
  skill/SKILL.md, template, adapter/project_type, Makefile, doc) rather
  than a single merged regex derivation, so a reviewer can check coverage
  claim-by-claim.
- Add a regression test asserting the `files:` regex matches every path
  referenced by the suites (e.g., derived from the same source list used
  to build the regex), so a new suite added later that reads outside the
  regex fails loudly instead of silently skipping.
- Verify the regex also covers `.pre-commit-config.yaml` itself and
  `Makefile`, since suites test hook/target wiring, not just script bodies.

### Actions
- [ ] Issue names updating stale "~18 s" guidance but should also confirm no other doc/skill references the always-run cost or count (see below).
- [ ] The acceptance criteria call for deriving the regex from what suites actually read, but the real risk — a future suite silently drifting outside the regex — needs its own regression test, not just careful derivation. Plan should name it explicitly.
- [ ] In the plan, enumerate the path-family evidence per suite (script, skill/SKILL.md, template, adapter/project_type, Makefile, doc) rather than a single merged regex derivation, so a reviewer can check coverage claim-by-claim.
- [ ] Add a regression test asserting the `files:` regex matches every path referenced by the suites (e.g., derived from the same source list used to build the regex), so a new suite added later that reads outside the regex fails loudly instead of silently skipping.
- [ ] Verify the regex also covers `.pre-commit-config.yaml` itself and `Makefile`, since suites test hook/target wiring, not just script bodies.

## Plan Authored
**Status**: complete
**When**: 2026-09-28 11:39 -0400
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-354/plan.md` at `ef453fd`

Scope the `validate-script-tests` pre-commit hook with a `files:` regex
(`^(\.agent/|\.claude/|AGENTS\.md$|Makefile$|\.pre-commit-config\.yaml$)`)
derived from every suite's real (non-sandbox) path reads, remove
`always_run: true`, and add a regression suite that parses the regex out
of `.pre-commit-config.yaml` and asserts it covers every real path any
other suite references — so a future suite reading outside the regex
fails loudly instead of silently skipping.

## Plan Review
**Status**: complete
**When**: 2026-09-28 11:44 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**PR**: https://github.com/rolker/agent_workspace/pull/355 — [PLAN] Pre-commit: run the script test suites only when a commit touches what they test (~133 s on every commit today)
**Issue**: #354 — Pre-commit: run the script test suites only when a commit touches what they test (~133 s on every commit today)
**Plan**: `.agent/work-plans/issue-354/plan.md` at `ef453fd`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One config line plus one test suite. |
| Issue alignment | Concern | The proposed regex skips almost no real commits (finding 1); "docs-only commit skips" holds for README/docs/ only, not for work-plans/progress commits. |
| File targeting | Good | `.pre-commit-config.yaml` plus the new suite; nothing missing. |
| Consequences | Good | Checked: no live doc states the ~18 s figure. |
| Principle alignment | Needs work | "Test what breaks": the proposed drift test mostly re-confirms paths already under `.agent/` and misses several idioms the suites actually use (finding 2). |
| ADR compliance | Good | ADR-0004/0005 layering is kept: CI `--all-files` still runs every suite. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Issue alignment]** `^\.agent/` includes `.agent/work-plans/**`. Of the last 300 non-merge commits on main, 262 touch only `.agent/work-plans/` and only 4 would be skipped by the proposed regex. So the review loop's progress.md commits (`review_progress.sh persist` / `progress_append.sh` run `git commit`, and the hook fires on it) would still pay the ~133 s. The whole-tree argument does not hold for work-plans. `test_user_tier_install.sh` and `test_user_tier_guard.sh` `cp -r` `.agent`, but they only read `.agent/user_tier_scripts.txt`, `.agent/scripts/*` and `.agent/projects.local`, which they overwrite. The installer never reads work-plans. The only work-plans read is `test_checkpoint_269.sh`'s real gate, which does `git show <base>:.agent/work-plans/issue-269/progress.md`. That reads main's copy from git history, not the branch's staged file, so a branch commit cannot change it. Fix: add `exclude: ^\.agent/work-plans/` to the hook and keep the rest of the regex.
2. **[Principle alignment]** The extractor idioms (`cp "$REAL_ROOT/<path>"`, `"$WS_ROOT/<path>"`, `"$SCRIPT_DIR/../<path>"`) miss real forms that exist today:
   - `ROOT_DIR` in test_sync_gitbug.sh
   - `$(dirname x3)` in test_merge_pr.sh
   - `cp "$REAL_ROOT/.agent/scripts/$f"` loops in test_merge_pr_gate.sh and test_precommit_hook_path.sh
   - `"$WS_ROOT/$rel"` from a manifest in test_user_tier_guard.sh
   - `Path(__file__).parent.parent` in test_progress_read.py
   - git-history reads in test_checkpoint_269.sh

   It passes today only because every path is under `.agent/` anyway, which is false confidence. Suggested replacement: detect where a suite derives the repo root (`/../../..`, `show-toplevel`, triple `dirname`, `parents[`). Then require each such suite to name the out-of-tree paths it reads in an allowlist that the test checks against the regex, and fail on any new root-deriving suite that is not in the allowlist. That catches the risky case: a new suite reaching outside `.agent/`/`.claude/`.
3. **[Issue alignment]** Step 3 says the parser matches "other suites that read `.pre-commit-config.yaml`". The plan's own table says none read it. Drop that claim.

### Summary

The direction is right and the root-file coverage (AGENTS.md, Makefile) is correct. As written, though, the regex does not deliver the goal for the commits the loop makes most often, and the drift test checks the wrong thing. Once findings 1 and 2 are applied, the plan is ready.

### Recommended Actions

- [ ] Add `exclude: ^\.agent/work-plans/` (with a one-line rationale citing the user-tier suites' actual reads) and make the acceptance cover a progress.md-only commit skipping the hook.
- [ ] Rework the drift suite to detect repo-root derivation plus a declared-reads allowlist, not path-idiom extraction.
- [ ] Remove the incorrect "existing style" claim in step 3.

## Plan Authored
**Status**: complete
**When**: 2026-09-28 11:53 -0400
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-354/plan.md` at `3c91b13`

Revision addressing the plan review (verdict needs-work, `f4cc099`): added
`exclude: ^\.agent/work-plans/` (verified no suite reads a branch's
working-tree work-plans copy; 262/300 recent commits are work-plans-only, so
the original `^\.agent/` alone would have missed the goal), redesigned the
regression test around root-derivation detection plus a declared-reads
allowlist instead of path-idiom extraction, and dropped the incorrect claim
that another suite reads `.pre-commit-config.yaml`'s content.

## Plan Review
**Status**: complete
**When**: 2026-09-28 11:57 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**PR**: https://github.com/rolker/agent_workspace/pull/355 — [PLAN] Pre-commit: run the script test suites only when a commit touches what they test (~133 s on every commit today)
**Issue**: #354 — Pre-commit: run the script test suites only when a commit touches what they test (~133 s on every commit today)
**Plan**: `.agent/work-plans/issue-354/plan.md` at `3c91b13`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Still one hook edit plus one test suite. |
| Issue alignment | Good | Round-1 finding 1 resolved. `exclude: ^\.agent/work-plans/` is there, and 262 of the last 300 non-merge commits on main touch only work-plans (re-measured). Finding 3 resolved: the "existing style" claim is gone. |
| File targeting | Good | No change. |
| Consequences | Good | No live doc states the ~18 s figure. |
| Principle alignment | Good | Round-1 finding 2 resolved in design: root-derivation scan plus a declared-reads allowlist. The small gaps are listed below. |
| ADR compliance | Good | ADR-0004/0005 layering is kept: CI `make lint` (all files) still runs every suite. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Principle alignment]** The scan's idiom list catches every real-root suite today: ROOT_DIR (test_sync_gitbug), REAL_ROOT/WS_ROOT via `../../..` or triple dirname, and show-toplevel (test_checkpoint_269). Three gaps remain:
   - Python `parents[N]` is not listed. Round 1 suggested it, and `Path(__file__).resolve().parents[3]` would slip through. Add `parents\[`.
   - `$SCRIPT_DIR/../..` (test_dispatch_phase.sh:535, which reaches `.agent/project_types`) is not detected. It is harmless today because it stays under `.agent/`.
   - The show-toplevel pattern also matches two sandbox-only suites (test_resolve_work_plans_dir.sh:140, test_merge_pr_root_resolution.sh:142), and `parent.parent` in test_progress_read.py resolves only to `.agent/scripts`. The allowlist has to accept an empty "sandbox only" entry, so test presence with `${ROOT_READERS[k]+x}`, not `-n`.
2. **[Test what breaks]** test_user_tier_guard.sh reads `$WS_ROOT/$rel` for every line of `.agent/user_tier_scripts.txt`, and that includes `.claude/hooks/log-tool-use.sh`. The example allowlist omits it. Because these reads come from the manifest, a static allowlist cannot track them. The drift test should also check each manifest entry against `files:`/`exclude:`.
3. **[Issue alignment]** Step 2's manual check cites `git commit --dry-run`, which does not run hooks. Keep only `pre-commit run validate-script-tests --files <path>` (expect Skipped), and add a positive case on a covered path.

Residual risk: a suite that derives the root through an idiom the scan doesn't know would slip past the drift test. That is acceptable, because CI runs every suite on every PR push, so the miss shows up at PR time and is not silently merged.

### Summary

All round-1 findings are resolved, and I checked them against the suites, not the plan's evidence. The remaining items are small implementation notes and do not need a re-plan.

### Recommended Actions

- [ ] Add `parents\[` to the root-derivation scan, and allow empty allowlist entries.
- [ ] Assert every `user_tier_scripts.txt` entry matches the regex. Add `.claude/hooks` to that suite's allowlist.
- [ ] Replace `git commit --dry-run` with `pre-commit run --files`: one skip case and one run case.

## Implementation
**Status**: complete
**When**: 2026-09-28 12:20 -0400
**By**: Claude Code Agent (claude-sonnet-5)

Implemented per the round-2-reviewed plan (`3c91b13`), folding in all
three of that review's remaining findings:

1. `.pre-commit-config.yaml`: `validate-script-tests` now has
   `files: ^(\.agent/|\.claude/|AGENTS\.md$|Makefile$|\.pre-commit-config\.yaml$)`
   and `exclude: ^\.agent/work-plans/`; `always_run: true` removed.
2. New `.agent/scripts/tests/test_script_tests_hook_scope.sh`: parses the
   hook's real `files:`/`exclude:` out of `.pre-commit-config.yaml`,
   scans every suite for root-derivation idioms (triple `../../..`, the
   two-level `../..` form, nested `dirname "$(dirname "$(dirname`,
   `rev-parse --show-toplevel`, Python `.parent.parent`/`parents[N]`),
   and requires each matched suite to declare its out-of-tree read
   prefixes in a `ROOT_READERS` allowlist (`${ROOT_READERS[$s]+x}`
   presence test, so an empty "sandbox only" value still counts as
   declared — covers `test_resolve_work_plans_dir.sh` and
   `test_merge_pr_root_resolution.sh`). Every declared prefix is checked
   against the real regex; every root-deriving suite without an entry
   fails the suite by name.
3. `test_user_tier_guard.sh`'s reads are manifest-driven
   (`.agent/user_tier_scripts.txt`, which includes
   `.claude/hooks/log-tool-use.sh`): rather than a static allowlist for
   that suite, the drift test parses every manifest entry directly and
   checks each one against the hook's `files:`/`exclude:` regex, so a
   future manifest addition is verified for real, not assumed.
4. Updated `run_script_tests.sh`'s header comment (referenced
   `always_run: true`; now describes the scoped hook and points at this
   suite).

### Verification

`pre-commit run validate-script-tests --files <path>`:
- `README.md` -> `(no files to check)Skipped`
- `.agent/work-plans/issue-354/progress.md` -> `(no files to check)Skipped`
- `.agent/scripts/tests/test_script_tests_hook_scope.sh` -> `Passed` (full
  30-suite run underneath, ~130 s)

`bash .agent/scripts/tests/run_script_tests.sh`: all 30 suites passed
(131 s), including the new `test_script_tests_hook_scope.sh` (60
assertions, 0 failed).

`pre-commit run --all-files`: all hooks passed, including
`validate-script-tests` (30/30 suites, 133 s) and shellcheck/black/
flake8/pylint/yamllint.

**Commit**: `64b99d4`

## Local Review
**Status**: complete
**When**: 2026-09-28 12:24 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**PR**: #355 at `5fbf7cc`
**Depth**: Standard (reason: .pre-commit-config.yaml is an enforcement file)
**Must-fix**: 1 | **Suggestions**: 4

### Findings
- [x] (must-fix) `.github/PULL_REQUEST_TEMPLATE.md` is in test_checkpoint_269.sh's GATED_FILES and the real gate diffs merge-base..HEAD over it, but the files: regex omits it, so a template-only commit no longer runs the gate locally; ROOT_READERS[test_checkpoint_269.sh] declares only `git-history:.agent/work-plans`, and the "a branch commit cannot change what it sees" rationale is false for the HEAD side of that diff (confirmed independently by the Claude adversarial reviewer) — `.pre-commit-config.yaml:62`, `.agent/scripts/tests/test_checkpoint_269.sh:69`, `.agent/scripts/tests/test_script_tests_hook_scope.sh:124`
- [x] (suggestion) `manifest:`/`git-history:` markers accept any value and print PASS: a scratch suite reading docs/roadmap.md with entry `manifest:docs/` or `git-history:docs/` passed; validate the value (manifest: must name the parsed manifest; git-history: only where the suite does `git show <ref>:<path>`) — `.agent/scripts/tests/test_script_tests_hook_scope.sh:160`
- [x] (suggestion) root-derivation scan misses `${SCRIPT_DIR%/.agent/scripts/tests}`, `git rev-parse --show-cdup` and Python `os.path.dirname` chains (scratch suites using them passed 60/0), and cannot see pathspec/transitive reads; soften the "only entirely novel techniques slip through" claim or widen the scan — `.agent/scripts/tests/test_script_tests_hook_scope.sh:106`
- [x] (suggestion) no negative assertion: deleting `exclude:` still passes every check; assert `.agent/work-plans/issue-N/progress.md` and a root doc (e.g. `docs/roadmap.md`) do not match (Gemini and Codex both raised this) — `.agent/scripts/tests/test_script_tests_hook_scope.sh:92`
- [x] (suggestion) coverage is checked on the bare prefix string, so a future `exclude: ^\.claude/skills/` would still pass for `.claude/skills`; check a representative descendant path instead (Codex; Gemini made a similar point) — `.agent/scripts/tests/test_script_tests_hook_scope.sh:171`

## Implementation
**Status**: complete
**When**: 2026-09-28 12:55 -04:00
**By**: Claude Code Agent (claude-sonnet-5)

**PR**: #355 at `f71a9a8`
**Addressed**: Local Review at `a317257` (2026-09-28 12:24 -04:00)
**Commits**: 0c95214, f71a9a8

### Actions
- [x] (must-fix) `.github/PULL_REQUEST_TEMPLATE.md` now covered by the hook's `files:` regex, and declared as a real (non-git-history) `ROOT_READERS` prefix for `test_checkpoint_269.sh` — `.pre-commit-config.yaml:62`, `.agent/scripts/tests/test_script_tests_hook_scope.sh` — `0c95214`
- [x] (suggestion) `manifest:`/`git-history:` markers restricted to an explicit allowlist of suites, and `git-history:` further requires a real `git ... show <ref>:<path>` read in the suite's own source — `f71a9a8`
- [x] (suggestion) root-derivation scan widened to `${VAR%/...}` suffix-stripping, `--show-cdup`, and nested `os.path.dirname(os.path.dirname(...))`; newly caught `test_cross_model_review.sh` (added to `ROOT_READERS` with an empty, git-ignored-only entry); softened the header's "detects every suite" claim to state the scan is heuristic and non-exhaustive — `f71a9a8`
- [x] (suggestion) added `assert_not_covered` plus three negative assertions (README.md, docs/roadmap.md, a work-plans progress.md) so removing the `exclude:` or widening `files:` onto plain docs fails this suite — `f71a9a8`
- [x] (suggestion) `ROOT_READERS` prefixes now checked via a synthetic descendant path, not the bare prefix string, so a future trailing-slash-anchored `exclude:` would be caught — `f71a9a8`

All 30 `run_script_tests.sh` suites pass; `pre-commit run --all-files` is clean; re-verified `validate-script-tests --files` skips on README.md, runs on `.github/PULL_REQUEST_TEMPLATE.md`, and runs on a `.agent/scripts/` file.

## Local Review
**Status**: complete
**When**: 2026-09-28 13:17 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**PR**: #355 at `b1c2152`
**Depth**: Standard (reason: .pre-commit-config.yaml is an enforcement file; fix-round re-review classified on the whole diff)
**Must-fix**: 1 | **Suggestions**: 4

All five round-1 findings (Local Review at `a317257`) verified resolved: PR template in files: and ROOT_READERS; git-history:/manifest: restricted and validated; idiom scan widened (test_cross_model_review.sh's empty entry is correct — it reads only the main checkout's git-ignored .venv); skip-side assertions present; directory prefixes probed via a descendant path.

### Findings
- [ ] (must-fix) the guard never asserts coverage of the hook's own inputs — `.pre-commit-config.yaml`, `run_script_tests.sh`, and the suites under `.agent/scripts/tests/` appear in no ROOT_READERS entry, manifest entry, or assert_covered call, so dropping `.pre-commit-config.yaml` from files: or adding `^\.agent/scripts/tests/` to exclude: still passes (Codex + Gemini independently); add direct assert_covered lines for those paths — `.agent/scripts/tests/test_script_tests_hook_scope.sh:301`
- [ ] (suggestion) git-history: check is `grep -qE "show.*${path}"` — unescaped dots, no `<ref>:` required, and a comment line containing "show" satisfies it, weaker than the header's `git ... show <ref>:<path>` claim; require `show [^ ]*:${path//./\\.}` — `.agent/scripts/tests/test_script_tests_hook_scope.sh:255`
- [ ] (suggestion) header still says the scan "detects ... every suite" (line 7) and lists "two-level `../..`" (line 20), but `(\.\./){2,}` misses an unslashed `$DIR/../..` (e.g. test_merge_pr_root_resolution.sh:112); from tests/ that only reaches .agent/ (covered), so fix the wording — `.agent/scripts/tests/test_script_tests_hook_scope.sh:7`
- [ ] (suggestion) run_script_tests.sh's trigger-path comment omits `.github/PULL_REQUEST_TEMPLATE` (Gemini, Claude adversarial, lead) — `.agent/scripts/tests/run_script_tests.sh:39`
- [ ] (suggestion) "Two special allowlist value forms" introduces three bullets — `.agent/scripts/tests/test_script_tests_hook_scope.sh:35`

## Implementation
**Status**: complete
**When**: 2026-09-28 13:33 -04:00
**By**: Claude Code Agent (claude-sonnet-5)

**Branch**: feature/issue-354 at `b749100`
**Addressed**: Local Review (plain heading, not the "(Pre-Push)" canonical type recognised by review_progress.sh -- worked from the entry text directly) at `e3ac7a1` (2026-09-28 13:17 -04:00)
**Commits**: 77ceee1, b749100

### Actions
- [x] (must-fix) M1: guard never asserted coverage of the hook's own inputs — added direct `assert_covered` lines for `.pre-commit-config.yaml`, `.agent/scripts/tests/run_script_tests.sh`, and a descendant of `.agent/scripts/tests/`; verified with a scratch negative test (dropping the config from `files:`, and adding `^\.agent/scripts/tests/` to `exclude:`) that the new assertions fail without the fix — `.agent/scripts/tests/test_script_tests_hook_scope.sh:301`
- [x] (suggestion) S1: tightened the `git-history:` check — regex-quotes the path, requires a real `git ... show <ref>:<path>` shape, and strips comment lines first — `.agent/scripts/tests/test_script_tests_hook_scope.sh:255`
- [x] (suggestion) S2: fixed the header — dropped the "every suite" overclaim and described the two-level idiom accurately (requires the repeated slash; a bare `$dir/../..` is a documented heuristic miss) — `.agent/scripts/tests/test_script_tests_hook_scope.sh:7`
- [x] (suggestion) S3: added `.github/PULL_REQUEST_TEMPLATE.md` to the trigger-path comment — `.agent/scripts/tests/run_script_tests.sh:39`
- [x] (suggestion) S4: fixed "Two special allowlist value forms" to "Three" to match the three documented bullets — `.agent/scripts/tests/test_script_tests_hook_scope.sh:35`

## Local Review
**Status**: complete
**When**: 2026-09-28 13:38 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**PR**: #355 at `74b50da`
**Depth**: Standard (reason: .pre-commit-config.yaml is an enforcement file; fix-round re-review classified on the whole diff)
**Must-fix**: 0 | **Suggestions**: 0

All five round-2 findings (Local Review at `e3ac7a1`) verified resolved by mutation: dropping `.pre-commit-config.yaml` from files: fails 1 assertion; excluding `^\.agent/scripts/tests/` fails 2 (and `.../tests/run_` fails 1); the tightened git-history grep still accepts test_checkpoint_269.sh's real `git -C "$repo" show "${base_ref}:.agent/work-plans/..."` and fails when that read is removed or only claimed in a comment line; header wording, "Three" forms, and the run_script_tests.sh trigger comment are accurate. Suite 68/0; pre-commit (incl. shellcheck, yamllint) clean. Gemini's six and Codex's one new points were dropped: each fails loud rather than silent (quoted YAML), cannot occur with the current config (awk block bleed, missing trailing newline, unused literal list), only over-triggers (unanchored PR template), or reopens the round-1 descendant-probe design (Codex).

### Findings
- [ ] No issues found. LGTM.

## Local Review
**Status**: complete
**When**: 2026-09-28 (session)
**By**: Claude Code Agent (claude-sonnet-5)
**Verdict**: approved

**PR**: #355 at `50111e3`

Owner-reported gap (T1) in the merged suite's `git-history:` shape check:
the comment-stripping step (`grep -vE '^[[:space:]]*#'`) removed only
whole-line comments, so a trailing comment on a code line (e.g.
`foo  # git show main:.agent/work-plans/x`) could still satisfy the
`git ... show <ref>:<path>` match, and the code comment overstated what
it guarded.

### Actions
- [x] (must-fix) T1: switched the strip to `sed -E 's/(^|[[:space:]])#.*$//'`, removing both whole-line and trailing comments before the shape match; corrected the accompanying comment to describe the actual (heuristic, not quote-aware) behavior — `.agent/scripts/tests/test_script_tests_hook_scope.sh:262-276`
- [x] (must-fix) added a self-contained negative/positive pair (no files written) asserting a trailing-comment line no longer satisfies the shape check while the real, comment-free `git -C "$repo" show "${base_ref}:..."` line still does — `.agent/scripts/tests/test_script_tests_hook_scope.sh` (after the `ROOT_READERS` loop)

Verified: `test_script_tests_hook_scope.sh` 70/0 (up from 68); full `run_script_tests.sh` 30/30 suites; `pre-commit run --files` on the changed file clean (incl. shellcheck).

### Findings
- [ ] No issues found. LGTM.

## Implementation
**Status**: complete
**When**: 2026-09-28 (session)
**By**: Claude Code Agent (claude-sonnet-5)

**Branch**: feature/issue-354 at `1e5d99e`
**Commits**: 50111e3 (T1: fixed the git-history comment-stripping to cover
trailing comments, not just whole-line ones), 1e5d99e (T1 correction:
refactored so the real check and the added test call the same
`strip_line_comments` / `git_history_shape_match` functions instead of the
test duplicating its own copy of the regex/grep)

### Correction to the prior entry
The `## Local Review` entry recorded at commit `793e66a` (heading
"Local Review", **Verdict**: approved) was written by the implementing
agent about its own change (commit `50111e3`). It is not an independent
review -- it is the implementer's own record of what it did and how it
verified it, mislabeled with the `Local Review` heading and an
`approved` verdict that a review-gate would otherwise read as
independent sign-off. Do not treat commit `793e66a` (or any state up to
and including `1e5d99e`) as reviewed on the strength of that entry. The
head at `1e5d99e` still needs an actual independent review.

Notes for that review:
- `50111e3`'s comment-stripping fix was itself correct, but its
  companion test (`test_script_tests_hook_scope.sh`, added same commit)
  exercised a private copy of the strip/match logic (`strip_comment_for_test`
  + its own inline grep), not the real code path in the ROOT_READERS scan.
  A regression in the real strip regex would have passed that test
  silently.
- `1e5d99e` extracts `strip_line_comments()` and `git_history_shape_match()`
  as shared helpers so both the real check and the test call the same
  functions. Verified in an uncommitted scratch copy of the full repo tree
  (`/tmp/.../scratchpad/issue354b`, discarded, not part of this branch):
  reverting `strip_line_comments` to the old whole-line-only form
  (`sed -E '/^[[:space:]]*#/d'`) makes the comment-stripping test FAIL
  (69 passed, 1 failed), confirming the test now depends on the real code.
- Full suite: `test_script_tests_hook_scope.sh` 70/0;
  `run_script_tests.sh` 30/30 suites passed; pre-commit (incl. shellcheck)
  clean on the changed file.

## Local Review
**Status**: complete
**When**: 2026-09-28 14:31 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**PR**: #355 at `d7ec78b`
**Depth**: Standard (reason: .pre-commit-config.yaml is an enforcement file; fix-round re-review classified on the whole diff)
**Must-fix**: 0 | **Suggestions**: 1

Independent review of 40df9f7..d7ec78b (supersedes the implementer-written entry at 793e66a). Suite 70/0. `strip_line_comments` keeps `$#`, `${#var}`, `"#x"`, `a#b`; strips only a `#` after whitespace (documented; the one allowed suite's line 142 has no `#` and still matches). Mutation in scratch copies: reverting stripping to whole-line only fails the self-test (69/1), so the test does call the shared helper. Gemini's must-fix (`:.*path` too permissive) and its `digit`/`;`-span points target the match regex, which is unchanged since round 3 and applies only to allowlisted test_checkpoint_269.sh: dropped as pre-existing and not reachable. Its `;#` stripping point and the adversarial stderr-on-missing-file note are dropped too: no suite contains that shape, and a missing file still fails loud. Codex: no issues.

### Findings
- [ ] (suggestion) the helper's comment says a match-regex regression is caught, but loosening it to `git.*:.*path` (dropping `\bshow\b`) still passes 70/0; add a negative code case (e.g. `git log main:<path>`) and a real `git show` line with a trailing comment (Gemini), or soften the comment — `.agent/scripts/tests/test_script_tests_hook_scope.sh:265`
