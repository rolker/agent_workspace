# Plan: Consolidate worktree directories and make --type mandatory

## Issue

https://github.com/rolker/agent_workspace/issues/25

## Context

Worktree directories are currently split across two locations:
- Workspace worktrees: `.workspace-worktrees/` (dotdir at repo root)
- Project worktrees: `project/worktrees/` (inside the project git repo)

`worktree_enter.sh` and `worktree_remove.sh` don't require `--type`, causing
silent disambiguation failures when both workspace and project worktrees exist
for the same issue (hit during issue #21).

Per discussion with Roland, the new directory layout should include a repo-name
tier under `project/` to support future multi-project workspaces.

## Approach

### 1. Update directory layout in `_worktree_helpers.sh`

Define the new base paths as functions/variables:
- Workspace: `worktrees/workspace/`
- Project: `worktrees/project/<repo_name>/`

The repo name comes from the existing `REPO_SLUG` (already derived from
`project_config.sh` or git remote). Add a helper that resolves the project
worktree base given a repo slug.

### 2. Update `worktree_create.sh` path construction

Change the two path-building blocks (currently lines ~312-314):
- Workspace: `.workspace-worktrees/issue-workspace-<N>` -> `worktrees/workspace/issue-workspace-<N>`
- Project: `project/worktrees/issue-<slug>-<N>` -> `worktrees/project/<repo_name>/issue-<slug>-<N>`

Same pattern for skill worktrees.

Ensure `mkdir -p` creates the intermediate `worktrees/project/<repo_name>/`
directory.

### 3. Make `--type` mandatory in `worktree_enter.sh`

- Remove the project-first-then-workspace fallback search (current lines 150-193)
- Require `--type workspace|project` as a mandatory argument
- Search only the specified type's directory
- Error clearly if `--type` is missing

### 4. Make `--type` mandatory in `worktree_remove.sh`

- Same change: require `--type`, remove dual-search fallback
- Update `find_worktree()` to only search the specified base directory

### 5. Add `--repo` flag for multi-project disambiguation

Add an optional `--repo <name>` flag to `worktree_enter.sh`, `worktree_remove.sh`,
and `worktree_list.sh`. For `--type project`:
- If `--repo` provided: search `worktrees/project/<repo>/`
- If `--repo` omitted and only one project configured: use it (current behavior)
- If `--repo` omitted and multiple projects exist: error with available repos

This keeps the single-project workflow frictionless while supporting multi-project.

### 6. Update `worktree_list.sh` search paths

- Workspace: scan `worktrees/workspace/` instead of `.workspace-worktrees/`
- Project: scan `worktrees/project/*/` (glob across all project repos)
- Group output by type and repo name

### 7. Update `find_worktree` and `find_worktree_by_skill` in `_worktree_helpers.sh`

Update all path references. The search logic stays the same (glob for
`issue-*-<N>`, handle multiple matches), just the base directories change.

### 8. Update `.gitignore`

- Add: `worktrees/`
- Remove: `.workspace-worktrees/`
- No change needed to `project/.gitignore` (project worktrees no longer live there)

### 9. Update documentation

- `AGENTS.md` — worktree workflow section: update example paths, mention `--type`
  is required on all three scripts, add `--repo` flag
- `.agent/WORKTREE_GUIDE.md` — update directory layout diagram, troubleshooting
- `docs/decisions/0002-worktree-isolation-over-branch-switching.md` — update path
  references in the Decision section

### 10. Remove `--type` default from `worktree_create.sh`

Currently defaults to `workspace` (line 44). Remove the default so all three
scripts consistently require explicit `--type`. Update usage/help text.

### 11. Migration note

No migration script. Document in WORKTREE_GUIDE that existing worktrees in old
locations should be removed (`git worktree remove`) and recreated. `worktree_list.sh`
should check both old and new locations during a transition period (with a deprecation
warning for old-location worktrees). Remove the legacy fallback in a follow-up.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/_worktree_helpers.sh` | Update base paths, `find_worktree`, `find_worktree_by_skill` |
| `.agent/scripts/worktree_create.sh` | New output paths with repo-name tier, remove `--type` default |
| `.agent/scripts/worktree_enter.sh` | Require `--type`, add `--repo`, update search paths |
| `.agent/scripts/worktree_remove.sh` | Require `--type`, add `--repo`, update search paths |
| `.agent/scripts/worktree_list.sh` | Update search paths, scan `worktrees/project/*/` |
| `.gitignore` | Add `worktrees/`, remove `.workspace-worktrees/` |
| `AGENTS.md` | Update worktree section: paths, mandatory `--type`, `--repo` flag |
| `.agent/WORKTREE_GUIDE.md` | Update layout diagram and troubleshooting |
| `docs/decisions/0002-worktree-isolation-over-branch-switching.md` | Update path references |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| A change includes its consequences | Docs, ADR, and gitignore all updated in same PR |
| Workspace vs. project separation | Worktree dirs move out of `project/` — better separation |
| Workspace infrastructure is project-agnostic | `--repo` flag keeps scripts generic; repo name is derived, not hardcoded |
| Only what's needed | `--repo` flag is optional for single-project; no extra complexity until needed |
| Improve incrementally | Legacy fallback in list script eases migration |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0002 (Worktree isolation) | Yes | Path references updated to match new layout |
| ADR-0003 (Project-agnostic) | Yes | Repo-name tier keeps the structure generic; works for any number of projects |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Worktree base paths | All 5 worktree scripts | Yes |
| `--type` becomes mandatory | AGENTS.md usage examples, WORKTREE_GUIDE | Yes |
| `.workspace-worktrees/` removed | `.gitignore`, ADR-0002 | Yes |
| New `--repo` flag | Help text in scripts, AGENTS.md | Yes |
| Existing worktrees in old locations | Deprecation warning in list script | Yes |
| `--type` default removed from create | AGENTS.md examples, help text | Yes |

## Resolved Questions

1. **Legacy worktree migration**: No migration script. Document that old worktrees
   should be removed and recreated. List script gets temporary legacy fallback with
   deprecation warning.

2. **ADR-0003 scope**: Leave as-is. Update when multi-project is actually implemented.

3. **`--type` default on create**: Remove the default. All three scripts require
   explicit `--type`.

## Estimated Scope

Single PR. All changes are tightly coupled — the path changes, mandatory `--type`,
and doc updates need to ship together.
