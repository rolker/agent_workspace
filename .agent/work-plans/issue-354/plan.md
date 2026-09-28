# Plan: Pre-commit: run the script test suites only when a commit touches what they test

## Issue

https://github.com/rolker/agent_workspace/issues/354

## Context

`.pre-commit-config.yaml`'s `validate-script-tests` hook runs
`.agent/scripts/tests/run_script_tests.sh` (all 29 `test_*.sh`/`.py` suites)
on every commit via `always_run: true` — measured ~133 s today, up from
~18 s / 10 suites at #269. CI's `Lint (pre-commit)` job (`make lint` →
`pre-commit run --all-files`) already runs the full suite unconditionally
per commit-pushed-to-PR, and stays that way (it operates over the whole
tree regardless of `files:`). The fix is scoping the hook's `files:` regex
the way `validate-adapter-contract` already is, so local commits only pay
the cost when they touch something a suite actually reads.

## Approach

1. **Derive the covered path set from every suite, not by inspection of a
   few.** Read all 29 files in `.agent/scripts/tests/` and classified every
   reference to a *real* (non-sandboxed) repository path — i.e. anything
   read directly via `$WS_ROOT/...` / `$REAL_ROOT/...` rather than copied
   into a `mktemp -d` sandbox and then mutated. Evidence per family:

   | Path family | Suites that read it directly | How |
   |---|---|---|
   | `.agent/**` (whole tree) | `test_user_tier_guard.sh`, `test_user_tier_install.sh` | `cp -r "$WS_ROOT/.agent" "$WSC/.agent"` — the sandbox is a full snapshot of the real tree, so *any* file under `.agent/` can change what these suites assert (new/moved/edited scripts, manifest, project_types, templates, knowledge, work-plans) |
   | `.agent/scripts/**`, `.agent/scripts/tests/**`, `.agent/scripts/lib/**` | `test_adapter.sh`, `test_merge_pr.sh`, `test_merge_pr_gate.sh`, `test_project_registry.sh`, `test_ros2_colcon.sh`, `test_dispatch_phase.sh`, `test_issue_review_entry.sh`, `test_precommit_hook_path.sh`, others | explicit `cp "$REAL_ROOT/.agent/scripts/<file>"` / `"$SCRIPT_DIR/../<file>"` lines naming individual scripts (adapter, `_project_registry.sh`, `validate_adapter.sh`, `merge_pr.sh`, `_bookkeeping.sh`, `worktree_*.sh`, `_issue_helpers.sh`, `_resolve_default_branch.sh`, `review_progress.sh`, `progress_read.py`, `progress_append.sh`, `dispatch_phase.sh`, `_real_case_path.sh`, `_bookkeeping.sh`, `validate_workspace.py`) — already subsumed by the `.agent/**` row above but recorded so a narrower alternative regex isn't tempting |
   | `.agent/project_types/**` | `test_adapter.sh`, `test_project_registry.sh`, `test_ros2_colcon.sh`, `test_dispatch_phase.sh`, `test_precommit_hook_path.sh` | `cp -r "$REAL_ROOT/.agent/project_types/<type>"` |
   | `.claude/**` (whole tree) | `test_user_tier_guard.sh`, `test_user_tier_install.sh` | `cp -r "$WS_ROOT/.claude" "$WSC/.claude"` — same whole-tree argument as `.agent/**` |
   | `.claude/skills/*/SKILL.md` | `test_skill_paths.sh` | reads `$WS_ROOT/.claude/skills` directly (no copy) to lint for bare workspace-relative paths |
   | `.claude/hooks/session_start_project_layer.sh` | `test_session_start_layer.sh` | reads `$WS_ROOT/.claude/hooks/session_start_project_layer.sh` directly |
   | `AGENTS.md` (repo root) | `test_session_start_layer.sh` | reads `$WS_ROOT/AGENTS.md` directly — the suite asserts the hook's pinned heading list still exists verbatim in it; a rename/deletion here breaks the suite, not a rebuild-from-sandbox copy |
   | `Makefile` (repo root) | `test_precommit_hook_path.sh` | `cp "$REAL_ROOT/Makefile"`, then runs `make -pn -f <copy>` and asserts on `VENV_DIR`/`STAMP`/`PRE_COMMIT`/lock-recipe output |
   | `.pre-commit-config.yaml` (repo root) | none today reads its *content* | included anyway per the issue's acceptance criteria — it is the hook's own wiring; a future suite validating `.pre-commit-config.yaml` shape (or a person editing the hook itself) should keep the suite live |

   Everything any suite reads that is **not** covered by the rows above is a
   synthetic sandbox path (`$sb/...`, `$wt/...`, `mktemp` output) or a
   literal test-data string (e.g. `".pre-commit-config.yaml"` used only as
   a mock finding path in `test_triage_reviews_integration.sh`) — confirmed
   by grepping every suite for `$WS_ROOT/`, `$REAL_ROOT/`, and repo-root
   filenames (`README.md`, `CODEX.md`, `.github/copilot-instructions.md`,
   `docs/*.md`) and finding no non-sandbox hits outside the rows above.

2. **Set the `files:` regex** on `validate-script-tests` in
   `.pre-commit-config.yaml`, following the `validate-adapter-contract`
   pattern already in the file:

   ```yaml
   files: ^(\.agent/|\.claude/|AGENTS\.md$|Makefile$|\.pre-commit-config\.yaml$)
   ```

   Remove `always_run: true` from the hook (mutually exclusive with
   `files:` — `always_run` would otherwise override the filter).

3. **Add a regression test** —
   `.agent/scripts/tests/test_script_tests_hook_scope.sh` — that keeps the
   regex honest as suites change:
   - Parses the `validate-script-tests` hook's `files:` value out of the
     real `.pre-commit-config.yaml` (a small YAML-free line scan, matching
     the existing style of other suites that read `.pre-commit-config.yaml`
     — no new YAML dependency needed for one field).
   - Statically scans every `.agent/scripts/tests/test_*.sh` (and `.py`)
     for the two idioms that name a *real* (non-sandbox) path: `cp
     ".../$REAL_ROOT/<path>"` / `cp -r "$WS_ROOT/<path>"` and a direct
     `"$WS_ROOT/<path>"` / `"$REAL_ROOT/<path>"` variable assignment used
     as a file argument (excluding the `SCRIPT_DIR`/`REAL_ROOT`/`WS_ROOT`
     definition lines themselves).
     Also matches the equivalent `"$SCRIPT_DIR/../<path>"` idiom used by
     several suites in place of `$REAL_ROOT`.
   - Asserts every extracted path matches the parsed regex. A new suite
     that reads a real path outside `.agent/`, `.claude/`, `AGENTS.md`,
     `Makefile`, or `.pre-commit-config.yaml` fails this suite loudly,
     instead of the hook silently skipping it — this is the acceptance
     criterion "the regex covers every path any suite reads" turned into
     an enforced check rather than a one-time audit.
   - This test necessarily lives *inside* `.agent/scripts/tests/`, so it is
     itself covered by the `^\.agent/` branch of the regex — adding a
     suite there always re-triggers the hook.

4. **Update stale guidance.** Searched every currently-live doc
   (`AGENTS.md`, `docs/roadmap.md`, `docs/design.md`, `.claude/skills/**`)
   for an "~18 s" / fixed-suite-count claim about this hook: none exists.
   The only "~18 s" text is in `.agent/work-plans/issue-269/{plan,progress}.md`
   — committed history of the original decision, not live guidance, and is
   left untouched. No doc edit is needed for this acceptance item; noted
   here so a reviewer doesn't go looking for a doc that isn't there.

## Files to Change

| File | Change |
|------|--------|
| `.pre-commit-config.yaml` | Add `files:` regex to `validate-script-tests`, remove `always_run: true` |
| `.agent/scripts/tests/test_script_tests_hook_scope.sh` (new, `chmod +x`) | Regression test: parses the hook's `files:` regex and asserts it covers every real path referenced by the other suites |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Enforcement over documentation | Hook keeps running automatically on any matching commit; nothing moves from a hook into a doc. CI's unconditional `--all-files` run is the backstop layer regardless of local scoping. |
| Test what breaks | New regression test directly targets the risk the issue calls out: a suite drifting outside the regex, silently skipping a broken test on commit. |
| Only what's needed | Regex derived from actual suite reads, not padded with speculative future paths. |
| A change includes its consequences | Confirmed no live doc states a stale per-commit cost figure (see Approach step 4); nothing else references hook suite-count/timing. |
| Improve incrementally | Single-file config change plus one small, self-contained test suite. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0004/0005 — Enforcement hierarchy / layered enforcement | Yes | Pre-commit (local, fast feedback) is scoped; CI (`make lint --all-files`, authoritative) is untouched and still runs every suite on every push. |
| ADR-0013 — progress.md entry-type vocabulary | Yes (process only) | `## Plan Authored` / future review entries use `review_progress.sh persist`. |
| Others | No | No adapter-contract, worktree, dispatch, or session-root changes. |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| A script in `.agent/scripts/` (new test suite) | `AGENTS.md` script reference table if it has a `make`/top-level target | No — new suite is picked up automatically by `run_script_tests.sh`'s existing `test_*.sh` glob; no new table row needed |
| `.pre-commit-config.yaml` | Nothing else references this hook's shape outside the suite itself | Yes — new regression test is the dependent reference |

## Open Questions

- None — the derivation resolved the one real open question (whether any
  suite reads a real path outside `.agent/`/`.claude/`, which it does:
  `AGENTS.md` and `Makefile` at repo root, both now covered).

## Estimated Scope

Single PR.
