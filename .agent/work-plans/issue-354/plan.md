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

2. **Set the `files:`/`exclude:` regex** on `validate-script-tests` in
   `.pre-commit-config.yaml`, following the `validate-adapter-contract`
   pattern already in the file:

   ```yaml
   files: ^(\.agent/|\.claude/|AGENTS\.md$|Makefile$|\.pre-commit-config\.yaml$)
   exclude: ^\.agent/work-plans/
   ```

   Remove `always_run: true` from the hook (mutually exclusive with
   `files:` — `always_run` would otherwise override the filter).

   **`exclude: ^\.agent/work-plans/` is required, not optional.** Of the
   last 300 non-merge commits on `main`, 262 touch only
   `.agent/work-plans/` (review-loop `progress.md` / plan commits via
   `review_progress.sh persist` and `progress_append.sh`, which run
   `git commit` and so trigger local hooks) — without the exclude, the
   plain `^\.agent/` branch would still catch nearly every one of those
   and the hook would keep paying ~133 s on the commits it fires most
   often, defeating the issue's goal. Verified no suite needs
   `.agent/work-plans/` in the working tree to pass:
   - `test_user_tier_guard.sh` / `test_user_tier_install.sh` `cp -r` the
     whole `.agent/` tree into their sandbox, but only *read*
     `.agent/user_tier_scripts.txt`, `.agent/scripts/**`, and
     `.agent/projects.local` (which they overwrite) — never anything
     under `.agent/work-plans/`.
   - `test_checkpoint_269.sh` is the one suite that reads a
     `work-plans/issue-269/progress.md` path, but via
     `git -C "$repo" show "${base_ref}:.agent/work-plans/issue-269/progress.md"`
     — a read of `base_ref`'s committed history, not the working tree's
     staged file, so a branch commit under `.agent/work-plans/` cannot
     change what this assertion sees.
   - No other suite references `.agent/work-plans/` at all (grepped).

   Checked whether other doc-only `.agent/` subtrees should also be
   excluded: `.agent/scratchpad/` is gitignored except its `README.md`
   (`.gitignore` lines 38–39), so it almost never reaches a commit —
   excluding it would have no measurable effect. No suite reads
   `.agent/templates/` or `.agent/knowledge/` content directly; the only
   hits are a `test_skill_paths.sh` comment noting that some `SKILL.md`
   files *cite* those paths as strings, which is a `.claude/skills/**`
   concern already covered by the `^\.claude/` branch. Neither is added —
   no suite reads them, so excluding them buys nothing, and adding
   excludes without evidence of benefit is scope creep.

   **Acceptance check for this step**: a commit touching only a file under
   `.agent/work-plans/<issue>/` (e.g. a `progress.md` append via
   `progress_append.sh` or `review_progress.sh persist`) must skip the
   `validate-script-tests` hook. Verified manually post-implementation with
   `git commit --dry-run` / `pre-commit run validate-script-tests --files
   .agent/work-plans/issue-354/progress.md` (expect: hook not run /
   "Skipped"), in addition to the regression test in step 3 covering the
   regex-vs-reads invariant statically.

3. **Add a regression test** —
   `.agent/scripts/tests/test_script_tests_hook_scope.sh` — that detects
   drift by what a suite *could* reach outside the sandbox, not by
   re-confirming today's path idioms (a path-idiom scan only proves
   today's suites read paths under `.agent/`/`.claude/`; it doesn't stop a
   future suite from reading, say, `docs/` or `project/` through some
   idiom the scan wasn't taught):
   - Parses the `validate-script-tests` hook's `files:`/`exclude:` values
     out of the real `.pre-commit-config.yaml` (a small YAML-free line
     scan — no new YAML dependency needed for two fields; unlike the
     first draft, no other suite already reads this file's content, so
     this is new, not "matching existing style").
   - **Detects every suite that computes a real repo root**, by scanning
     `.agent/scripts/tests/test_*.sh` and `.py` for any of the idioms
     actually in use today (confirmed by grep across all 30 suites):
     `$SCRIPT_DIR/../../..` (triple `../`), a triple-nested
     `dirname "$(dirname "$(dirname ...`, `rev-parse --show-toplevel`,
     and `Path(__file__)...parent.parent` (or further `.parent`s). This
     is deliberately idiom-*shaped* (how a root is derived) rather than
     path-shaped (what gets read next) — a new suite that invents a new
     root-deriving expression is still caught because its shape matches
     one of the above; only entirely novel root-derivation techniques
     would slip through, which is a materially smaller gap than trusting
     path prefixes to stay put.
   - **Requires an allowlist** (a small associative array in the new
     test) mapping each root-deriving suite to the out-of-tree path
     prefixes it actually reads from that root, e.g.:
     ```bash
     declare -A ROOT_READERS=(
       [test_adapter.sh]=".agent/scripts .agent/project_types"
       [test_checkpoint_269.sh]="git-history:.agent/work-plans"
       [test_user_tier_guard.sh]=".agent/user_tier_scripts.txt .agent/scripts .agent/projects.local"
       # ... one entry per suite the scan finds; the suite itself errors
       # out (not just fails) if a scanned suite has no entry, and the
       # error names the suite so a contributor knows to add one.
     )
     ```
     A `git-history:` prefix marks a read that goes through `git show
     <ref>:<path>` against a fixed base ref rather than the working
     tree — such a read is exempt from needing regex coverage, since the
     commit under test cannot change what it sees (this is exactly the
     `test_checkpoint_269.sh` case).
   - For every non-`git-history:` prefix in the allowlist, asserts it
     matches the parsed `files:` regex and does **not** match `exclude:`.
     A prefix that fails either check fails the suite loudly, naming the
     suite and the uncovered prefix.
   - For every suite matched by the root-derivation scan, asserts it has
     an allowlist entry. An unlisted root-deriving suite fails the suite
     loudly (new suite drift), rather than silently reading outside the
     regex.
   - This test necessarily lives *inside* `.agent/scripts/tests/`, so it
     is itself covered by the `^\.agent/` branch of the regex (and is not
     under `.agent/work-plans/`) — adding it always re-triggers the hook.

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
| `.pre-commit-config.yaml` | Add `files:`/`exclude:` regex to `validate-script-tests`, remove `always_run: true` |
| `.agent/scripts/tests/test_script_tests_hook_scope.sh` (new, `chmod +x`) | Regression test: parses the hook's `files:`/`exclude:` regex, detects every suite that computes a real repo root, requires each in an allowlist of the out-of-tree prefixes it reads, and asserts every allowlisted prefix is covered by the regex |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Enforcement over documentation | Hook keeps running automatically on any matching commit; nothing moves from a hook into a doc. CI's unconditional `--all-files` run is the backstop layer regardless of local scoping. |
| Test what breaks | New regression test targets the risk the issue calls out at the mechanism level (root-derivation idiom + declared-reads allowlist), not just today's observed paths, so a future suite reaching outside `.agent/`/`.claude/` fails loudly instead of silently skipping. |
| Only what's needed | Regex (and exclude) derived from actual suite reads and actual commit-frequency data (262/300 commits are work-plans-only), not padded with speculative future paths. |
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

- None — the derivation resolved the two real open questions: (1) whether
  any suite reads a real path outside `.agent/`/`.claude/` (yes: `AGENTS.md`
  and `Makefile` at repo root, both covered by `files:`), and (2) whether
  `.agent/work-plans/` needs to stay in scope (no: no suite reads a
  branch's working-tree copy of it, so it's excluded — see Approach step 2).

## Estimated Scope

Single PR.
