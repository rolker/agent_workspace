# Git Worktree Guide

**Purpose**: Enable parallel development through isolated working directories. Each
worktree has its own branch, uncommitted changes, and build artifacts — completely
separate from the main workspace.

## Quick Start

`--type` is **required** on all worktree scripts (create, enter, remove).

```bash
# Infrastructure work (docs, scripts, skills)
.agent/scripts/worktree_create.sh --issue 42 --type workspace
source .agent/scripts/worktree_enter.sh --issue 42 --type workspace
# work, commit, push
.agent/scripts/worktree_remove.sh --issue 42 --type workspace

# Project repo work
.agent/scripts/worktree_create.sh --issue 42 --type project
source .agent/scripts/worktree_enter.sh --issue 42 --type project
# work in the project/ worktree, commit, push to project repo
.agent/scripts/worktree_remove.sh --issue 42 --type project

# Skill worktrees (no GitHub issue needed)
.agent/scripts/worktree_create.sh --skill research --type workspace
source .agent/scripts/worktree_enter.sh --skill research --type workspace
.agent/scripts/worktree_remove.sh --skill research --type workspace
```

For Codex or any tool that runs each shell command independently, use one of
the execution-safe entry modes:

```bash
WT_PATH=$(.agent/scripts/worktree_enter.sh --issue 42 --type workspace --print-path)
# WT_PATH is just the resolved path; it does not change directories:
git -C "$WT_PATH" status

eval "$(.agent/scripts/worktree_enter.sh --issue 42 --type workspace --shell-snippet)"
```

## Why Worktrees?

Git worktrees create separate checkouts of the same repository:
- Each worktree is a separate directory
- Each has its own branch, builds, and uncommitted files
- All worktrees share the same git history
- No conflicts between concurrent agents

## Directory Structure

Worktrees live under whichever root owns them (issue #265). The workspace's
own worktrees stay inside the workspace checkout; a registered project's
worktrees live under that project's own root, wherever it is on disk:

```
agent_workspace/
├── worktrees/
│   ├── workspace/                 # Workspace repo worktrees
│   │   └── issue-workspace-42/
│   │       └── ... (workspace files)
│   └── project/                   # TRANSITION FALLBACK only: an
│       └── <name>/                # unregistered project (legacy project/
│           └── issue-<name>-42/   # symlink) still lands here. Dropped in
│               └── ...            # PR 4 together with project/ itself.

/anywhere/on/disk/<registered-root>/   # e.g. ~/src/gz4d, ~/project11-ng/rolling
└── worktrees/                         # <root>/worktrees/ by default; a
    └── issue-<name>-42/               # registry `worktrees=` field overrides
        └── ...                        # the location per project
```

`registry_worktree_dir` (`.agent/scripts/_project_registry.sh`) is the single
source of truth for where a project's worktrees live: a registered name
resolves to its own root (or its `worktrees=` override); an unregistered name
falls back to the pre-#265 `worktrees/project/<name>/` shape shown above, so
legacy projects keep working mid-rollout. On first worktree creation under a
registered root, the workspace appends `worktrees/` to that root's own
`.git/info/exclude` (never a tracked file) so the worktree dir never shows up
in the project's own `git status`. Type-specific markers are the adapter's
job (ADR-0012): the `ros2_colcon` adapter's `worktree_env` verb writes an
untracked `worktrees/COLCON_IGNORE` so colcon never descends into a package
worktree's own colcon workspace(s).

**Transition.** Worktrees created before a project was registered stay at
`worktrees/project/<name>/` and remain discoverable: `worktree_list.sh`,
`dashboard.sh`, and `merge_pr.sh` enumerate that location alongside the
registered dir, and `worktree_enter.sh` / `worktree_remove.sh` search it
after the registered dir (with a notice). Remove and recreate to move a
worktree under the project root; nothing migrates it silently.

## Worktree Types

### Workspace Worktrees

For infrastructure changes: `.agent/`, `docs/`, `.claude/skills/`, `Makefile`, etc.

```bash
.agent/scripts/worktree_create.sh --issue <N> --type workspace
```

- Created in: `worktrees/workspace/issue-<slug>-<N>/`
- Git worktree of the **workspace repo**
- Branch: `feature/issue-<N>` in the workspace repo
- PRs target the workspace repo

### Project Worktrees

For changes to a project repo — registered in `.agent/projects.local`, or the
legacy `project/` checkout.

```bash
.agent/scripts/worktree_create.sh --issue <N> --type project
```

- Created in: `<registered root>/worktrees/issue-<slug>-<N>/` (or, for an
  unregistered project, the transition fallback
  `worktrees/project/<repo>/issue-<slug>-<N>/`)
- Git worktree of the **project repo**
- Branch: `feature/issue-<N>` in the project repo
- PRs target the project repo with `-R <project-remote>`

## Naming Convention

| Mode | Directory name |
|------|----------------|
| Issue | `issue-<repo_slug>-<N>` |
| Skill | `skill-<repo_slug>-<YYYYMMDD-HHMMSS>` |

`<repo_slug>` is auto-detected from the remote URL (e.g., `workspace`, `myproject`).
For registry-selected projects (see below) the registry name is used instead.
Use `--repo-slug` to override.

## Disambiguation

Since `--type` is mandatory, workspace vs. project is never ambiguous.

For multiple registered projects, use `--project`:

```bash
.agent/scripts/worktree_create.sh --issue 42 --type project --project <name>
source .agent/scripts/worktree_enter.sh --issue 42 --type project --project <name>
.agent/scripts/worktree_remove.sh --issue 42 --type project --project <name>
```

On `worktree_create.sh`, `--project <name>` selects a registered project from
`.agent/projects.local` (issue #227); the worktree is created under that
project's own root (`registry_worktree_dir`, issue #265) so `enter`/`remove
--project <name>` find it by the same key. Without `--project`, the legacy `project/` checkout is used; when
`project/` is absent and exactly one project is registered, that project is
auto-selected (multiple registrations require `--project`). Parent roots
(registry pseudo-type `project`, issue #265) are never auto-selected;
`--project <parent>` resolves to the parent's `default_instance`, else its
only instance, and the worktree is keyed by the instance name.

`--repo` remains accepted as a silent alias for `--project` on all three
worktree scripts.

For multiple worktrees of the same type with different repo slugs, use `--repo-slug`:

```bash
source .agent/scripts/worktree_enter.sh --issue 42 --type workspace --repo-slug workspace
```

## Package Worktrees (`ros2_colcon`, ADR-0012)

For a hosted `ros2_colcon` instance, worktree one or more package repos inside
one layer instead of the whole hosting dir. Nothing is inferred — layer,
package repos, and issue are all explicit:

```bash
.agent/scripts/worktree_create.sh --type project --project p11-jazzy \
    --issue rolker/cube_bathymetry#111 \
    --layer platforms --package-repos cube_bathymetry,marine_msgs
```

- `--issue` **must** be the qualified `owner/repo#N` form for a package
  worktree (a bare number is a usage error — the qualified ref is how
  `worktree_repos` tells the issue's own repo from its siblings).
- `--package-repos` takes package-repo **directory names** (what
  `.agent/scripts/adapter repos` prints), not ROS package names.
- `--layer`/`--package-repos` are creation-only, like `--branch`/`--plan-file`
  (see the SKILL.md compatibility note below); re-entry and removal use the
  qualified `--issue owner/repo#N --type project --project <name>` form only.
- Branch names: the repo that owns the issue gets `feature/issue-<N>`; every
  other named repo gets `feature/<repo>-issue-<N>` (e.g.
  `feature/cube_bathymetry-issue-111` in `marine_msgs`).
- Directory: `<project root>/worktrees/issue-<project>-<owner>-<repo>-<N>/`
  (under the instance's own worktree dir, issue #265) — cosmetic only. Every
  script that needs project/issue/layer reads the `.worktree-repos` manifest
  header, never this name.
- Untouched sibling packages and lower/other layers are **not symlinked** —
  colcon's own overlay resolves them via the hosted instance's already-built
  installs (design B in the issue #252 plan). No code path in this workflow
  ever falls back to `ln -s`; a `git worktree add` failure on any named repo
  rolls back every repo already added in the same run and hard-stops.
- If the worktree has anything to overlay, `worktree_create.sh` also writes:
  - `env.sh` — sourceable; the entry point for a shell that needs to keep
    the overlay (`source env.sh`).
  - `build.sh` — one-shot `colcon build` wrapper (sources `env.sh`, builds).
  - `test.sh` — one-shot: builds if not yet built, **re-sources `env.sh`**
    so the fresh overlay is on top, then `colcon test` +
    `colcon test-result --verbose`.
  - Both pass `--allow-overriding` to `colcon build`, computed at **run
    time** from `colcon list --names-only --base-paths src` (never
    hard-coded at generation time — this always matches whatever's under
    `src/`, including packages added after the worktree was created).
    Overriding the hosted instance's same-layer install is the entire
    reason a package worktree exists; without `--allow-overriding` colcon
    warns on every build (`colcon-override-check`) and may hard-error in a
    future release.
- `--plan-file` draft-PR creation is not supported for package worktrees (the
  aggregate dir is not itself a git repo); open PRs per package repo by hand.

### Merging Package-Worktree PRs

Each package repo's PR is a normal `gh` PR against its own repo — merge it with
`merge_pr.sh`'s repo-qualified resolution, not the plain `--pr <N>` form (PR
numbers are repo-local, and a package repo is never the workspace or the
registered project's own remote):

```bash
.agent/scripts/merge_pr.sh --pr owner/marine_msgs#57
# equivalently:
.agent/scripts/merge_pr.sh --pr 57 --repo owner/marine_msgs

make merge-pr PR=owner/marine_msgs#57
# equivalently:
make merge-pr PR=57 REPO=owner/marine_msgs
```

- `--repo owner/repo` (or the equivalent qualified `--pr owner/repo#N`) skips
  the workspace/`project/` auto-detection entirely and queries only that repo.
- The worktree is found by scanning every `.worktree-repos` manifest for an
  entry whose repo and branch match the merged PR — never by parsing the
  worktree's directory name. If the same repo and branch are worktreed under
  more than one registered instance, the merge is refused until you pass
  `--project <name>` to say which worktree it cleans up.
- A head branch GitHub already auto-deleted on merge counts as cleaned up; only
  a branch that is still on origin goes through `push --delete`.
- Merging one package repo's PR does **not** remove the worktree by itself.
  After deleting that repo's remote branch and fast-forwarding its own main
  checkout, `merge_pr.sh` checks every *other* repo named in the manifest for
  an open PR on its branch (`gh pr list`). If any sibling PR is still open,
  the worktree is kept and the blocking repo/branch is printed; the local
  branch just merged stays checked out too, since it's still part of the kept
  worktree. Only once no other named repo has an *open* PR on its branch
  (merged, closed without merging, or never opened all count as "not open")
  does the aggregate worktree (and its local branches) actually get removed,
  via the normal `worktree_remove.sh` preflight-and-remove path.
- The sibling-PR check fails **closed**: if `gh pr list` itself fails for a
  repo (network, auth, rate limit), the worktree is kept — not removed on the
  optimistic assumption that no PR was open — and the message names which
  repo's check failed and why, with the `worktree_remove.sh` command to rerun
  once you've confirmed by hand that repo has no open PR.
- When the worktree is finally removed (no sibling PR open, or none left
  unchecked), `merge_pr.sh` sweeps *every* named repo's local branch, not just
  the one just merged — a repo whose PR merged earlier, while a sibling PR
  was still open, only had its remote branch deleted at the time (its local
  branch was deferred, since it was still checked out). The sweep deletes a
  local branch only when its remote ref is gone *and* git's safe delete
  accepts it; a branch still on origin, or one holding unmerged work (a
  sibling PR closed without merging), is reported and left in place with the
  command to delete it by hand.
- The final banner says what actually happened: cleaned up and synced; merged
  with the worktree kept pending sibling PRs; or merged with cleanup
  incomplete (a failed branch delete, sync, or worktree removal is never
  reported as success).
- The roadmap update (`update_roadmap.sh`) is skipped for a package-repo PR
  with a one-line note — the roadmap file lives in this repo, not the package
  repo, so there's nothing to commit there.
- Both branch shapes are recognized when extracting the issue number:
  `feature/issue-<N>` (the repo that owns the issue) and
  `feature/<repo>-issue-<N>` (every other named repo).

## Draft PRs with Plan File

Pass `--plan-file` to create a draft PR immediately and post the plan as a PR comment:

```bash
.agent/scripts/worktree_create.sh --issue 42 --type workspace --plan-file /tmp/plan.md
.agent/scripts/worktree_create.sh --issue 42 --type project --plan-file /tmp/plan.md
```

## Sub-Issue Worktrees (Stacked PRs)

Use `--parent-issue` to branch from a parent issue's feature branch and target the
draft PR at that branch:

```bash
.agent/scripts/worktree_create.sh --issue 43 --type workspace --parent-issue 42
```

## Troubleshooting

**"Worktree already exists"**: The directory already exists. Use `worktree_enter.sh`
to enter it, or `worktree_remove.sh` to clean it up.

**"Your shell is currently inside this worktree"**: `cd` to the workspace root first:
```bash
cd ~/agent_workspace
.agent/scripts/worktree_remove.sh --issue 42 --type workspace
```

**"No worktree found"**: Check `worktree_list.sh` to see what exists. The slug
may differ from what you expect — use `--repo-slug` to disambiguate.

**`gh pr merge --delete-branch` fails with "main is already used by worktree"**:
`gh` tries to checkout `main` after merging, but the main tree already has it.
Use `make merge-pr PR=<N>` or `gh pr merge <N> --merge` (without `--delete-branch`).

**Branch already exists**: The script reuses an existing local branch, or tracks
the remote branch if one exists.

**"Found worktree in legacy location"**: Worktrees created before issue #25 live in
`.workspace-worktrees/` or `project/worktrees/`. They still work but should be removed
(`git worktree remove <path>`) and recreated to use the new `worktrees/` layout.
