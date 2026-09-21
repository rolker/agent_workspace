---
issue: 297
---

# Issue #297 — script tests: mktemp sandboxes registered inside $() never get cleaned — ~100 leaked into /tmp per run, stalling boot 2 min

## Issue Review
**Status**: complete
**When**: 2026-09-21 09:49 -0400
**By**: Claude Code Agent (claude-sonnet-5)

**Issue**: #297

### Scope Assessment

**Well-scoped?** Mostly, but the fix list is incomplete. Verified against
the code on `main`: `test_ros2_colcon.sh`, `test_merge_pr.sh`, and
`test_precommit_hook_path.sh` all have the reported bug (`SANDBOXES+=`
inside a `make_sandbox`/`mk_ws` helper that's only ever invoked as
`sb="$(helper)"`, so the append happens in the command-substitution
subshell and never reaches the parent's array). But three more suites in
the same directory have the **identical** pattern and are not in the
issue's fix list:

- `test_project_registry.sh` — `make_sandbox()` (line 59) appends inside
  the function; every call site is `sb="$(make_sandbox)"` (7+ sites,
  e.g. lines 114, 122, 132, 142...). Same bug, same leak.
- `test_adapter.sh` — identical `make_sandbox()` shape, same
  `sb="$(make_sandbox)"` call pattern (lines 113, 121, 143...).
- `test_merge_pr_gate.sh` — `make_sandbox()` (line 135) does
  `sb="$(mktemp -d)"; SANDBOXES+=("$sb")` internally, called as
  `sb="$(make_sandbox ...)"` at 25+ sites. Same bug.

A fourth, different-shaped leak: `test_dispatch_phase.sh`'s `mk_sandbox()`
(line 27) creates a sandbox with `sb="$(mktemp -d)"` and returns it, but
never registers it in any array or under the file's own `$TMPD` (which
only covers fixture files, cleaned via its own `trap ... EXIT`) — every
call unconditionally leaks, no subshell involved at all.

If the goal is to stop the boot-stalling leak, fixing 3 of at least 7
affected suites leaves the other 4 leaking on every commit. Recommend
widening scope to all suites with this shape, or explicitly scoping this
issue to the reported 3 and opening a follow-up for the rest — right now
neither is stated.

**Right repo?** Yes — `.agent/scripts/tests/` is workspace test
infrastructure.

**Dependencies**: None blocking, but one worth flagging for merge
ordering: `test_worktree_enter_stderr.sh` on the not-yet-merged
`feature/issue-194` branch already uses the pattern this issue should
converge everything on — a single `SANDBOX="$(mktemp -d)"` assigned
directly at top level (no wrapper function, no `$()` around a
multi-statement helper) with `trap 'rm -rf "$SANDBOX"' EXIT`. Whichever
of #194 / #297 merges first, the other should match this shape rather
than inventing a second "correct" pattern.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Enforcement over documentation | Action needed | The issue's second bullet ("Consider a suite-level guard... run the suite under a per-run `TMPDIR`... and sweep it at the end") is the only mechanism that would catch a *future* suite reintroducing this bug, and it's phrased as optional. Given 4 of ~23 suites already have it independently, an opt-in per-file discipline has already failed twice over. This should be a required part of the fix, not a "consider." |
| A change includes its consequences | Action needed | See Scope Assessment above — `test_project_registry.sh`, `test_adapter.sh`, `test_merge_pr_gate.sh`, and `test_dispatch_phase.sh` share the reported defect (or a variant of it) and aren't in the fix list. Leaving them means the "assert dir is empty after `TMPDIR`-redirected run" bar from the issue's own Fix section wouldn't actually pass suite-wide even after this PR lands. |
| Capture decisions | Watch | The correct pattern (register in the caller's shell, never inside a `$()` capture; prefer one top-level `mktemp -d` + `trap ... EXIT` over a per-call array where a single sandbox suffices) isn't written down anywhere discoverable before suite #24 gets added. Worth a short convention note — a comment block in `run_script_tests.sh`, or a line in the script-test entry of `AGENTS.md`'s reference table — pointing at `test_worktree_enter_stderr.sh` as the reference shape. |
| Test what breaks | OK | The issue's own verification step (re-run under an empty `TMPDIR`, assert empty afterward) directly targets the regression rather than just re-running the existing suites, which pass today despite leaking. |
| Only what's needed | OK | The 3 named fixes are proportionate to the files named; the "widen scope" concern above is about completeness, not over-building. |
| Improve incrementally | OK | Bounded, mechanical fix; no rewrite. |
| Human control and transparency | OK | No hidden behavior change — cleanup traps start doing what they already claimed to do. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0011 — Project-type adapter contract | No — but the issue's proposed runner path is wrong | The issue's second bullet says the guard belongs in ".agent/scripts/test.sh → adapter test". That's the **project's** test command (`TEST_CMD` from `project_config.sh`, dispatched per project type) — unrelated to this repo's own script-test suite. The suite that actually runs `test_*.sh` under `.agent/scripts/tests/` is `run_script_tests.sh`, wired directly into pre-commit as the `validate-script-tests` hook (`.pre-commit-config.yaml` line 57-59) — it never goes through the adapter. A TMPDIR sweep belongs in `run_script_tests.sh` (or the hook invocation), not in the adapter/`test.sh` path. Worth correcting before implementation starts so effort isn't spent wiring the guard into the wrong runner. |
| 0013 — `progress.md` entry-type vocabulary | Yes (mechanically, for this review) | This review's own persistence uses the canonical `## Issue Review` heading via `review_progress.sh persist`. No action needed from the issue itself. |

### Consequences

- If `run_script_tests.sh` gains a TMPDIR-sweep guard, its one-line
  description in `AGENTS.md`'s Script Reference table should note the
  guard so the table stays accurate (Consequences Map: "A script in
  `.agent/scripts/` → Script reference table in `AGENTS.md`").
- If the fix set is widened per the Scope Assessment above, the issue
  body's own repro table and fix bullet list should be updated (or a
  follow-up issue opened) so the tracked scope matches what actually
  ships.

### Recommendations

- Widen the fix to all suites sharing this shape — at minimum add
  `test_project_registry.sh`, `test_adapter.sh`, `test_merge_pr_gate.sh`,
  and `test_dispatch_phase.sh` to the file list, or explicitly split them
  into a tracked follow-up issue before closing this one.
- Make the "suite-level `TMPDIR` guard" a required part of this issue's
  fix, not an optional "consider" — it's the only enforcement-layer
  defense against a fifth suite reintroducing the same bug.
- Point the guard at `run_script_tests.sh` (the actual suite runner wired
  into the `validate-script-tests` pre-commit hook), not at
  `.agent/scripts/test.sh` / `adapter test`, which runs the project's own
  `TEST_CMD` and has nothing to do with this repo's script-test suite.
- Standardize on the single-`mktemp`-plus-`trap`-at-top-level shape
  already used by `test_worktree_enter_stderr.sh` (`feature/issue-194`,
  unmerged) rather than inventing a new correct pattern in this PR —
  reference it explicitly so whichever branch merges second reconciles
  onto the same convention instead of a second bespoke fix.

### Actions
- [ ] The issue's second bullet ("Consider a suite-level guard... run the suite under a per-run `TMPDIR`... and sweep it at the end") is the only mechanism that would catch a *future* suite reintroducing this bug, and it's phrased as optional. Given 4 of ~23 suites already have it independently, an opt-in per-file discipline has already failed twice over. This should be a required part of the fix, not a "consider."
- [ ] See Scope Assessment above — `test_project_registry.sh`, `test_adapter.sh`, `test_merge_pr_gate.sh`, and `test_dispatch_phase.sh` share the reported defect (or a variant of it) and aren't in the fix list. Leaving them means the "assert dir is empty after `TMPDIR`-redirected run" bar from the issue's own Fix section wouldn't actually pass suite-wide even after this PR lands.
- [ ] Widen the fix to all suites sharing this shape — at minimum add `test_project_registry.sh`, `test_adapter.sh`, `test_merge_pr_gate.sh`, and `test_dispatch_phase.sh` to the file list, or explicitly split them into a tracked follow-up issue before closing this one.
- [ ] Make the "suite-level `TMPDIR` guard" a required part of this issue's fix, not an optional "consider" — it's the only enforcement-layer defense against a fifth suite reintroducing the same bug.
- [ ] Point the guard at `run_script_tests.sh` (the actual suite runner wired into the `validate-script-tests` pre-commit hook), not at `.agent/scripts/test.sh` / `adapter test`, which runs the project's own `TEST_CMD` and has nothing to do with this repo's script-test suite.
- [ ] Standardize on the single-`mktemp`-plus-`trap`-at-top-level shape already used by `test_worktree_enter_stderr.sh` (`feature/issue-194`, unmerged) rather than inventing a new correct pattern in this PR — reference it explicitly so whichever branch merges second reconciles onto the same convention instead of a second bespoke fix.
