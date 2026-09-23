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

## Approach

1. **Add a scoped, non-recursive shape check to `single_project/adapter.sh`.**
   Replace `adapter_validate()`'s `exec python3 validate_workspace.py "$@"`
   with: when `ACTIVE_PROJECT_NAME` is set, check only
   `adapter_project_root()` is a git repository (mirrors the existing
   `project/`-is-a-git-repo check already in `validate_workspace.py`, but
   scoped to the one project) and print a pass/fail message the same shape
   `ros2_colcon`'s `adapter_validate` uses (`❌ ...` to stderr, `✅ ...
   checkout matches ...` on success). When `ACTIVE_PROJECT_NAME` is unset
   (legacy `project/` shape, no `--project`), keep checking only the legacy
   `project/` checkout — not the whole registry. This removes the
   whole-workspace recursion and gives `validate_workspace.py` something
   non-recursive to delegate to in step 2.

2. **Delegate the registry loop's per-entry shape check in
   `validate_workspace.py`.** In the loop at ~L100-129, replace the
   hard-coded `if not (path / ".git").exists() and not
   (path.resolve() / ".git").exists(): issues.append(...)` with a call to
   `adapter --project <name> validate` (via `subprocess.run`, cwd=
   `workspace_root`) for entries whose `ptype` has a known adapter file
   (the existing `adapter_file.is_file()` check right above already guards
   unknown types — keep that check and skip delegation when it fails, since
   there's no adapter to call). On non-zero exit, append
   `f"project '{name}': {summary}"` to `issues`, where `summary` is derived
   from the subprocess's stderr — first non-empty line, or a fixed fallback
   (`"checkout shape check failed (adapter validate exited {code})"`) if
   stderr is empty — so the project name always identifies the failure
   without dumping the adapter's full raw output. Keep the existing
   `path.exists()` pre-check (hosting dir missing) ahead of the delegated
   call, since an adapter can't usefully validate a directory that isn't
   there.

3. **Guard against recursion / infinite loops.** Since
   `validate_workspace.py` now shells out to `adapter --project <name>
   validate`, and `single_project`'s `adapter_validate` (post step 1) no
   longer calls back into `validate_workspace.py`, there's no cycle for
   `single_project` entries. Confirm `ros2_colcon`'s `adapter_validate` is
   already self-contained (it is — verified in the issue review). No other
   registered project type exists in this workspace today, so no further
   type needs auditing (kept in scope per the owner's "only what's needed").

4. **Tests** (`.agent/scripts/tests/test_adapter.sh` and/or a validate-focused
   test file):
   - `single_project` scoped `adapter --project <name> validate`: passes when
     the named project's root is a git repo, even when a sibling registry
     entry (of any type, including a non-git `ros2_colcon`-shaped one) is
     broken — proves defect 2 is fixed.
   - `validate_workspace.py` registry test: a `ros2_colcon`-typed entry whose
     root has no `.git` must not fail whole-workspace validation (proves
     defect 1 is fixed) — build a minimal fake `ros2_colcon` checkout (or
     stub `adapter_validate` in a sandboxed copy of the type, matching the
     stubbing pattern already used in `test_adapter.sh` L133) so the test
     doesn't depend on a real ROS checkout.
   - `validate_workspace.py` registry test: a broken entry's failure message
     still contains `project '<name>':` when the shape check is delegated
     (not raw adapter stderr) — proves the owner's "keep the project name in
     output" decision is honored.
   - Reuse the sandbox-building helpers already in `test_adapter.sh`
     (`REAL_ROOT`, sandbox copy of `.agent/project_types/`, etc.) rather than
     inventing a new fixture style.

5. **Update `AGENTS.md`.** Script-reference table row for
   `validate_workspace.py`: change from "Validate project/ configuration" to
   something naming the actual split — e.g. "Validate workspace configuration
   (whole-registry check; delegates per-entry checkout-shape checks to each
   project type's adapter)". Confirm the `make validate` line under Build &
   Test still reads correctly (it already says "check workspace configuration
   is valid" / "Check workspace configuration is valid" — verify no wording
   implies per-project scoping was ever claimed there, and leave it if it's
   already accurate for a whole-workspace check).

## Files to Change

| File | Change |
|------|--------|
| `.agent/project_types/single_project/adapter.sh` | `adapter_validate()`: scope to `ACTIVE_PROJECT_ROOT` (or legacy `project/`) instead of `exec`-ing the whole `validate_workspace.py` |
| `.agent/scripts/validate_workspace.py` | Registry loop: delegate the per-entry checkout-shape check to `adapter --project <name> validate` instead of hard-coding `.git`; wrap failures as `project '<name>': <summary>` |
| `.agent/scripts/tests/test_adapter.sh` | Add scoped-validate test(s) for `single_project` (sibling-broken-entry case) |
| `.agent/scripts/tests/test_adapter.sh` (or a new `test_validate_workspace.sh`) | Add registry-loop tests: non-git `ros2_colcon` entry passes; failure messages keep `project '<name>':` prefix |
| `AGENTS.md` | Script-reference row for `validate_workspace.py`; confirm `make validate` description matches the split |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Enforcement over documentation | Fix is code + tests, not a doc-only note; `AGENTS.md` update follows the code change, doesn't substitute for it |
| A change includes its consequences | `AGENTS.md` script-reference row updated in the same PR per owner decision |
| Test what breaks | Tests target exactly the two defects (non-git `ros2_colcon` entry; cross-project validate scoping), not framework glue |
| Only what's needed | No audit of other adapters' `validate` implementations; `ros2_colcon` confirmed already correct, not touched |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0011 — Project-type adapter contract | Yes | Both fixes move shape-specific behavior into the per-type adapter's `validate` verb (as the contract already specifies) and stop the generic registry walker from embedding a single_project-shaped assumption. `validate_adapter.sh`'s 12-verb signature check is unaffected — no verb signatures change. |
| 0013 — progress.md entry-type vocabulary | No | No workflow-skill changes |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `single_project/adapter_validate()` no longer calls `validate_workspace.py` | Nothing else calls this verb expecting whole-workspace output — confirmed only `make validate` (bypasses adapter) and the `adapter --project <name> validate` path use it | Yes — verified in exploration |
| `validate_workspace.py` registry loop shells out to `adapter` | Adds a subprocess dependency inside the whole-workspace validator; must handle a missing/non-executable `adapter` script gracefully (existing `adapter_file.is_file()` check already gates this) | Yes — step 2 keeps the existing guard |
| `AGENTS.md` script-reference wording | `ARCHITECTURE.md` / `.agent/WORKTREE_GUIDE.md` don't separately describe `validate_workspace.py` (not referenced there) — no further doc updates needed | Yes — verified no other doc claims |

## Open Questions

- None outstanding — the owner's Checkpoint entry answered all three
  Issue Review actions (whole-workspace `make validate` scope, project-name
  preservation, `AGENTS.md` update).

## Estimated Scope

Single PR.
