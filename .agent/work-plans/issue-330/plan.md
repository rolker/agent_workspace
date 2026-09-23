# Plan: validate: the global validator requires .git at every project root (fails ros2_colcon), and single_project validate checks the whole workspace

## Issue

https://github.com/rolker/agent_workspace/issues/330

## Context

`validate_workspace.py`'s registry loop (`.agent/scripts/validate_workspace.py`
~L100-129) hard-codes `path/.git` as the checkout-shape check for every
registry entry, regardless of `ptype`. A `ros2_colcon` hosting dir is a
layered ROS workspace with no `.git` at its root, so it always fails this
check even when the checkout is healthy — the shape check that type actually
needs already exists in `ros2_colcon/adapter.sh`'s `adapter_validate()`
(L567+, checks manifest/layers/repos, not `.git`).

Separately, `single_project/adapter.sh`'s `adapter_validate()` (L85-87) is a
one-line `exec python3 validate_workspace.py "$@"` — it ignores
`ACTIVE_PROJECT_NAME`/`ACTIVE_PROJECT_ROOT` and always re-validates the whole
registry, so `adapter --project <single_project-name> validate` fails on an
unrelated project's broken checkout. `ros2_colcon`'s `adapter_validate`
already checks only its own checkout.

Owner decisions (recorded in progress.md's `## Checkpoint` entry, answering
the Issue Review's actions):
- `make validate` with no project named stays a whole-workspace check (it
  already calls `validate_workspace.py` directly, not through the adapter —
  Makefile L125-126 — so this needs no change).
- When the registry loop delegates a shape check to a type's adapter, the
  output must still name the failing project (`project '<name>': ...`), not
  raw adapter stderr passed through.
- Update `AGENTS.md`'s script-reference row for `validate_workspace.py` and
  the `make validate` description.
- Scope stays the two defects plus tests — no broader adapter audit.

**This revision** addresses the five must-fix findings and two suggestions
from the `## Plan Review` entry in progress.md (verdict: needs-work): a
registry-parse-error interaction that would misattribute failures to healthy
projects, an imprecise spec for the single_project git check, two doc updates
the prior plan wrongly called out of scope (ARCHITECTURE.md, the validator's
own docstring), and a corrected test location.

## Approach

1. **Add a scoped, non-recursive shape check to `single_project/adapter.sh`.**
   Replace `adapter_validate()`'s `exec python3 validate_workspace.py "$@"`
   with a check of `adapter_project_root()` (L130; resolves to
   `ACTIVE_PROJECT_ROOT` when `--project` was given, else the legacy
   `$WORKSPACE_ROOT/project`) — so this covers both the scoped and legacy
   cases without a separate branch. The check must be **presence of `.git` at
   the root, symlink-resolved** — the same test `validate_workspace.py`
   already uses (`(root / ".git").exists() or (root.resolve() / ".git").exists()`)
   — not `git -C "$root" rev-parse --git-dir`, the idiom in this same file's
   `adapter_repos` (L139). A bare `rev-parse --git-dir` succeeds for any
   directory *inside* another repo (walks up to a parent `.git`), so a
   non-git hosting dir nested under the workspace checkout, or under a git
   sandbox root (as in `test_precommit_hook_path.sh`'s `mk_ws`), would pass
   when it shouldn't. Print pass/fail the same shape `ros2_colcon`'s
   `adapter_validate` uses (`❌ ...` to stderr, `✅ ... checkout matches ...`
   to stdout). This removes the whole-workspace recursion and gives
   `validate_workspace.py` something non-recursive to delegate to in step 2.

2. **Delegate the registry loop's per-entry shape check in
   `validate_workspace.py`, with a registry-parse-error guard.** In the loop
   at ~L100-129:
   - Keep the existing `path.exists()` pre-check (hosting dir missing) ahead
     of any delegated call — an adapter can't usefully validate a directory
     that isn't there.
   - **Only delegate when `registry_errors` (already collected earlier in
     `validate_workspace()`, ~L65) is empty.** `registry_lookup` in
     `_project_registry.sh` (L310-312) calls `registry_entries` →
     `registry_entries_full`, and `registry_entries_full` returns rc=2 for
     *every* call whenever *any* line in `projects.local` is malformed — even
     though it still prints the valid lines (per its own doc comment,
     L66: "Malformed lines → diagnostics on stderr, return 2 (valid lines
     still print)"). So `adapter --project <name> validate` would exit
     non-zero for every healthy entry too, and the delegation would add a
     spurious `project '<healthy>': <parse diagnostic>` for each valid
     project on top of the existing `projects.local: <err>` issue —
     misattributing an unrelated line's parse error to healthy projects.
     When `registry_errors` is non-empty, keep the existing `path.exists()`
     result as the entry's shape check (do not delegate) rather than
     reporting a false per-project failure; the parse error itself is
     already reported once via `issues.append(f"projects.local: {err}")`.
   - When delegation runs, call `adapter --project <name> validate` (via
     `subprocess.run`, cwd=`workspace_root`) for entries whose `ptype` has a
     known adapter file (the existing `adapter_file.is_file()` check right
     above already guards unknown types — keep it, skip delegation when it
     fails since there's no adapter to call).
   - On non-zero exit, append one `issues` entry **per non-empty stderr
     line**, each prefixed `f"project '{name}': {line}"` (adopts Plan
     Review suggestion 6 — `ros2_colcon`'s `adapter_validate` can emit
     several `❌ ...` lines plus a `"Validation failed: N issue(s)."`
     summary line, and reporting only the first would hide the rest behind
     `make validate`'s output). If stderr is empty, append a single fixed
     fallback: `f"project '{name}': checkout shape check failed (adapter
     validate exited {code})"`.

3. **Guard against recursion / infinite loops.** Since
   `validate_workspace.py` now shells out to `adapter --project <name>
   validate`, and `single_project`'s `adapter_validate` (post step 1) no
   longer calls back into `validate_workspace.py`, there's no cycle for
   `single_project` entries. `ros2_colcon`'s `adapter_validate` is already
   self-contained (verified in the issue review). No other registered
   project type exists in this workspace today, so no further type needs
   auditing (kept in scope per the owner's "only what's needed").

4. **Update docs that describe the changed behavior.**
   - `ARCHITECTURE.md` L98-100 currently reads: "`validate_workspace.py`
     understands both shapes: legacy `project/` (valid git repo with a
     remote) and registry entries (well-formed, known project type, checkout
     present)." This is still true but no longer says *how* a registry
     entry's checkout is shape-checked; update it to note that each entry's
     checkout-shape check is delegated to that entry's type via
     `adapter --project <name> validate` (falling back to hosting-dir
     presence when the registry has parse errors), rather than a hard-coded
     `.git` check for every type.
   - `validate_workspace.py`'s own module docstring (L5-12), item 2:
     "Configured checkouts are valid git repos" — update to reflect that
     only the legacy `project/` checkout (and, via delegation, `single_project`
     registry entries) require `.git`; other types are validated by their own
     adapter's `validate` verb.
   - `AGENTS.md`: script-reference table row for `validate_workspace.py`
     (change from "Validate project/ configuration" to name the actual
     split — e.g. "Validate workspace configuration (whole-registry check;
     delegates per-entry checkout-shape checks to each project type's
     adapter)"), and confirm the `make validate` line under Build & Test
     still reads correctly for a whole-workspace check (no wording change
     expected there, but verify).

5. **Tests** — add to `.agent/scripts/tests/test_project_registry.sh`, next
   to the existing `test_validate_*` cases (L314-373), reusing
   `make_validate_sandbox` (L307-312):
   - `make_validate_sandbox`'s underlying `make_sandbox` (L58-68) copies only
     `single_project` into `$sb/.agent/project_types/`. For the `ros2_colcon`
     case, also `cp -r "$REAL_ROOT/.agent/project_types/ros2_colcon" "$sb/.agent/project_types/"`.
     Build a minimal real `ros2_colcon` checkout using the fixture pattern
     already established in `test_ros2_colcon.sh`'s validate-verb tests
     (~L1323, e.g. `test_validate_passes_matching_checkout`) — a manifest
     plus an empty/matching layer — rather than stubbing `adapter_validate`,
     so the test proves the real verb accepts a non-git root (defect 1).
   - Registry test: a `ros2_colcon`-typed entry with a matching minimal
     checkout and no `.git` at its root passes whole-workspace validation.
   - Registry test: a `ros2_colcon`-typed entry with a checkout that fails
     its own `adapter_validate` (e.g. missing a pinned repo) reports
     `project '<name>': ...` in the output, not raw unprefixed adapter
     stderr, and reports each `❌` line from the adapter (not just the
     first) — proves the per-line prefixing from step 2.
   - Registry test: one malformed `projects.local` line plus one healthy
     `single_project` entry — the healthy entry must NOT be reported as
     broken (proves the registry-parse-error guard from step 2; the
     existing `test_validate_malformed_registry` at L345 has only the
     malformed line, so this is a new case, not a modification of it).
   - `single_project` scoped `adapter --project <name> validate` test (new,
     in the same file or `test_adapter.sh` — colocate with
     `test_validate_*`): passes when the named project's root is a git repo
     even when a sibling registry entry (any type, broken) exists — proves
     defect 2 is fixed. Add a companion case for the nested-repo false-pass
     this plan calls out in step 1: a plain (non-git) directory located
     inside another git repo must FAIL the scoped check, proving the fix
     doesn't use bare `rev-parse`.
   - Re-run the existing `test_validate_registry_only`,
     `test_validate_missing_checkout`, `test_validate_unknown_type`,
     `test_validate_malformed_registry`, `test_validate_legacy_still_works`,
     `test_validate_neither_shape`, and `test_validate_parent_root` cases —
     they now exercise the subprocess-delegation path for any `single_project`
     entries among their fixtures and must still pass unchanged.

## Files to Change

| File | Change |
|------|--------|
| `.agent/project_types/single_project/adapter.sh` | `adapter_validate()`: scope to `adapter_project_root()`, checking `.git` at the root (symlink-resolved), not `exec`-ing the whole `validate_workspace.py` and not using bare `rev-parse` |
| `.agent/scripts/validate_workspace.py` | Registry loop: delegate the per-entry checkout-shape check to `adapter --project <name> validate` when the registry has no parse errors; fall back to the existing `path.exists()` result when it does; wrap each stderr line of a failure as `project '<name>': <line>`; update module docstring item 2 |
| `.agent/scripts/tests/test_project_registry.sh` | Add registry-loop tests (ros2_colcon non-git entry passes; ros2_colcon failure keeps `project '<name>':` prefix per-line; malformed-registry-line does not blame a healthy entry); add single_project scoped-validate tests (sibling-broken-entry case; nested-non-git-dir-inside-a-repo false-pass case); confirm existing `test_validate_*` cases still pass |
| `ARCHITECTURE.md` | L98-100: describe delegated per-entry checkout-shape checks instead of implying a single hard-coded check |
| `AGENTS.md` | Script-reference row for `validate_workspace.py`; confirm `make validate` description matches the split |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Enforcement over documentation | Fix is code + tests, not a doc-only note; doc updates (`AGENTS.md`, `ARCHITECTURE.md`, docstring) follow the code change, don't substitute for it |
| A change includes its consequences | `AGENTS.md`, `ARCHITECTURE.md`, and the validator's own docstring all updated in the same PR |
| Test what breaks | Tests target the two defects plus the registry-parse-error interaction and the nested-repo false-pass this revision found — not framework glue |
| Only what's needed | No audit of other adapters' `validate` implementations; `ros2_colcon` confirmed already correct, not touched beyond being exercised by the new tests |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0011 — Project-type adapter contract | Yes | Both fixes move shape-specific behavior into the per-type adapter's `validate` verb (as the contract already specifies) and stop the generic registry walker from embedding a single_project-shaped assumption. `validate_adapter.sh`'s 12-verb signature check is unaffected — no verb signatures change. |
| 0013 — progress.md entry-type vocabulary | No | No workflow-skill changes |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `single_project/adapter_validate()` no longer calls `validate_workspace.py` | Nothing else calls this verb expecting whole-workspace output — confirmed only `make validate` (bypasses adapter) and the `adapter --project <name> validate` path use it | Yes — verified in exploration |
| `validate_workspace.py` registry loop shells out to `adapter` | Adds a subprocess dependency inside the whole-workspace validator; must handle a missing/non-executable `adapter` script gracefully (existing `adapter_file.is_file()` check already gates this) and must not misattribute registry parse errors to healthy projects (new guard, step 2) | Yes |
| Delegated shape check replaces the hard-coded `.git` check for registry entries | `ARCHITECTURE.md` L98-100 (describes `validate_workspace.py`'s shape checks) and `validate_workspace.py`'s own docstring item 2 both need to describe the delegation, not a single hard-coded rule | Yes — both added to Files to Change |
| `AGENTS.md` script-reference wording | No other doc separately describes `validate_workspace.py`'s registry-entry behavior beyond ARCHITECTURE.md (now covered) | Yes |
| `adapter validate` with no `--project` on a registry-only machine (cwd not in a hosting dir → legacy resolution) now fails on a missing legacy `project/` where it previously passed via the whole-workspace check | No in-repo caller invokes it that way today: `make validate` and `dashboard.sh` call `validate_workspace.py` directly (Makefile L125-126), and `session_start_project_layer.sh` L168 uses `--project`. Note the behavior change explicitly in the PR description (Plan Review suggestion 7) so it's visible to reviewers even though nothing in-repo breaks | Yes |

## Open Questions

- None outstanding — the owner's Checkpoint entries answered all three
  Issue Review actions (whole-workspace `make validate` scope, project-name
  preservation, `AGENTS.md` update) and directed all seven Plan Review
  findings to be addressed, which this revision does.

## Estimated Scope

Single PR.
