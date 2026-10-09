# How it works

The workspace helps one person manage many AI agents across one or more projects, so the results can be
trusted and the user stays informed and in control.

Agents are strong within one piece of work and weak across time. So the workspace has two halves: a
day-to-day harness around each piece of work, and a long view of where each project is going. The
principles in [`docs/principles.md`](principles.md) connect them.

**The day-to-day harness.** Work happens in an isolated worktree, never in the main tree
([Worktrees](#worktrees)). An issue passes through eight phases, each run by a fresh sub-agent, and each
phase leaves one entry in the issue's progress timeline, which is the only record of where the issue
stands ([Review loop and timeline](#review-loop-and-timeline)). The loop stops at checkpoints and asks the
owner. The owner decides every merge, and no phase moves on by its own judgment
([Merge gate](#merge-gate)).

**What agents may do alone.** Agents decide small things within their limits and record them. Limits
start strict, and only the user relaxes them. Changing instruction files, CI or branch protection, or the
project remote URL needs the owner's approval first, and an agent never commits to `main` or skips hooks,
so it cannot do lasting damage unasked. Where a rule matters it is backed by the simplest check that
fails when it is broken, and [Rules](#rules) shows which rules have one.

**Projects.** The workspace is project-agnostic. What differs per kind of project sits behind adapters,
and a project's own remote is its URL ([Registry and adapters](#registry-and-adapters)). Each project
chooses how much footprint the workspace leaves in it: agent instructions and records go into a project
only if the user chose that, and a project can be developed without the agents. How far that is built is
described under [Worktrees](#worktrees). A session starts in the workspace or in a project's own root,
and a user tier gives a project session the workspace's skills and rules; that is built and not yet
proven ([Sessions and roots](#sessions-and-roots)).

**Tools.** The work is tool-neutral. Plans, reviews and progress are plain files any tool can read, and a
Codex or Gemini session walks the phases by hand ([Identity](#identity)). GitHub is not a project
dependency; the workspace uses it for now.

**Reports.** Agents lead with what the work is and what they need from the user, in plain words.

**The long view.** Each project, and the workspace, is meant to say what healthy and the right direction
mean, and it should be known whether a change helped. The workspace does not yet have a home for either
of those ([Documentation layers](#documentation-layers)). This file is the current picture of how the
parts fit; the ADRs in `docs/decisions/` record what was decided and when, and are history.

# The design

This part of the file is the current picture of how the workspace's parts fit together, and it is the
authority for it (ADR-0017). A fact is in only if two parts could otherwise choose incompatibly, or a
newcomer cannot see it from the code; detail that belongs next to the code (a script header, a
document beside it) stays there and is linked, not copied. The file holds the current picture, the
ADRs in `docs/decisions/` hold the reasons and the history of each decision, and each issue's
`progress.md` holds that issue's history. A change that alters how the parts fit updates the matching
section here in the same change, so the file is checked at merge. Where this file and an ADR disagree,
this file wins; the Decision register says which ADRs still govern.

Every `##` section below has a `Now` block: what the code does today, each line followed by the
script, ADR or file it was checked against. A section has a `Target` block only where the target
differs from what is built. Each block opens with one `Status:` line taking exactly one of these five
values, and a block holds statements of one status. A question goes to Open questions with a pointer,
never into a block that claims a status. `Now` states only what the code does today; the one
exception is a part with nothing built, whose single block is labelled `Now` and carries `proposed`.
Each proposal inside a `Target` block starts with "Proposed:" and moves to `Now` in the change that
builds it.

| Status | Means |
|---|---|
| `decided` | An owner decision is on record, cited (ADR number or issue and date), and the code does it |
| `decided, not built` | Decided and cited; the code does not do it yet |
| `decided, not proven` | Decided and built, but the acceptance test has not run (ADR-0016 is Provisional until the `/run-issue` run from a project root in #317) |
| `proposed` | Agent or owner suggestion, not decided |
| `open` | A question, listed under Open questions. An `open` block holds only a pointer to where the question is tracked (an issue number or the Open questions row), no question text |

## Purpose

**Now**

Status: `decided`

This file says how the workspace's parts fit together today, so a change to one part can be checked
against the others. A change that alters the picture updates the matching section here in the same
change, which is how the file stays current (ADR-0017, Decision; principle "Keep one current design").
It does not restate the goals or the principles. The goals are in
[`README.md`](../README.md) under `## Workspace goals`, the principles in
[`docs/principles.md`](principles.md); this file says how the parts serve them.

## Documentation layers

**Now**

Status: `decided`

The documentation has seven roles. Each project maps each role to a file, a section of a file, a place
outside the repository, or nothing. This table is the workspace's own mapping (owner decision
2026-10-08, #335; the roles are the plan's, the files were checked by listing `docs/`, the repository
root and `.agent/knowledge/`).

| Role | What it is for | Where it lives for the workspace |
|---|---|---|
| Goals | Why the workspace exists and what it should be | [`README.md`](../README.md), `## Workspace goals` |
| How it works | The core ideas, short | `# How it works`, at the top of this file |
| Principles | How work is judged | [`docs/principles.md`](principles.md), applied through [`.agent/knowledge/principles_review_guide.md`](../.agent/knowledge/principles_review_guide.md) |
| Design | How the parts fit today | This file, from `# The design` on |
| Decisions | What was decided, why, and when | [`docs/decisions/`](decisions/) (ADRs), plus each issue's `progress.md`; history, never rewritten |
| Direction | What is planned and in what order | [`docs/roadmap.md`](roadmap.md). What "healthy" means for the workspace has no home yet |
| Measures | How anyone tells whether a change helped | None yet |

Two of the seven are gaps, and the table shows them: the README's long-view goal says each project,
and the workspace, says what healthy and the right direction mean and that it is known whether a change
helped (`README.md`, "The long view"). The roadmap covers direction only, and no file holds a measure.

`.agent/scripts/discover_governance.sh` lists the governance files it finds in the workspace root and in
the legacy `project/` checkout, under six types: `principles`, `architecture`, `agents-config`,
`agent-guide`, `adr` and `workspace-context`. It does not scan registered projects and does not know
the seven roles (checked in the script's `scan_scope`).

**Target**

Status: `proposed`

Proposed: a project records its own mapping of the seven roles, seeded from the types that
`discover_governance.sh` already finds, and never forced on it: a convention is encouraged where a
project has no documentation (owner goal of 2026-09-23, issue #335), and a project may leave a role
unmapped. Where that mapping is kept is not decided.

## Rules

**Now**

Status: `decided`

Each rule below is stated in [`AGENTS.md`](../AGENTS.md) or the principles; this table adds the one thing
they do not say, which check stands behind it. Rules are listed only where there is an enforcement fact
to give. The principle column cites the principle by name and does not restate it. The "Enforced by"
column takes exactly one of five values: `hook` (a pre-commit hook that fails the commit), `script` (a
workspace script refuses), `CI` (the validation workflow fails), `review only` (a reviewer checks it
against [`.agent/knowledge/principles_review_guide.md`](../.agent/knowledge/principles_review_guide.md))
or `nothing`. Each row was checked against the file it names; the four hooks that read local state
(`check-commit-identity`, `no-commit-to-branch`, `check-branch-updates`, `verify-issue-branch`) are
skipped in CI (`SKIP` in `.github/workflows/validate.yml`), so they run on the committer's machine
only.

| Rule | Principle or ADR | Enforced by | The check |
|---|---|---|---|
| No commit to `main` | Leave a trail; start limits strict | `hook` | `no-commit-to-branch` (`.pre-commit-config.yaml`), local only. GitHub also refuses a direct push: the repository ruleset `require_pr` is active on `main` (`gh api repos/rolker/agent_workspace/rules/branches/main`, 2026-10-09) |
| Commits carry an agent or owner identity | Leave a trail; start limits strict | `hook` | `.agent/hooks/check-commit-identity.py` fails a commit whose author email matches none of its accepted patterns, local only |
| Hooks are not skipped (no `--no-verify`) | Enforce what matters, as simply as possible | `CI` | The Lint job runs `make lint`, which runs every hook on all files; the four local-state hooks above are skipped there. A local `--no-verify` is not detected |
| Issue number matches the branch | Leave a trail; start limits strict | `nothing` | `.agent/hooks/verify-issue-branch.py` prints the issue's title and state and always returns 0 (its docstring: "Informational only") |
| A progress entry has the ADR-0013 shape | Leave a trail; start limits strict | `script` | `_progress_entry.sh` validates the heading, the entry type, fences and title in every writer (`progress_append.sh`, `review_progress.sh persist`); editing the file by hand is not checked |
| Merge only after a current review and a decision summary | Leave a trail; start limits strict | `script` | The gate in `merge_pr.sh` refuses by default on workspace PRs and is report-only for project PRs. It is local only: the script's own comment says a Merge click on GitHub bypasses it, and the server-side complement is not built |
| Every project type implements every adapter verb | Put each thing at the level it applies to | `hook` | `validate_adapter.sh` (`validate-adapter-contract`), also its own CI job |
| Design anchors resolve | Keep one current design | `hook` | `check_design_anchors.sh` (`check-design-anchors`); `make lint` and CI run it again |
| A change that alters how the parts fit updates this file | Keep one current design | `review only` | Review guide rows "Keep one current design" and ADR-0017 |
| Nothing committed to the workspace names a particular project | Put each thing at the level it applies to | `review only` | Review guide row "Put each thing at the level it applies to" (search the diff for project names) |
| Work happens in a worktree, not the main tree | ADR-0002 | `review only` | The main tree stays on `main`, so `no-commit-to-branch` stops the usual slip; nothing stops a branch switch there. The guide's ADR-0002 row says the worktree scripts and hooks enforce it; the hooks do not |
| Ask first: instruction files, CI or branch protection, the project remote URL | Leave a trail; start limits strict | `review only` | Review guide row "Name the rule before bending it" (an Ask-First rule treated as bendable). No code-owner file or hook watches those paths |
| A pull request carries the AI signature | Leave a trail; start limits strict | `script` | `gh_create_pr.sh` appends it and exits 2 when `AGENT_NAME` and `AGENT_MODEL` are unset. Issues and comments are signed by habit only: `gh_create_issue.sh` does not add one |
| No secrets in a commit | Enforce what matters, as simply as possible | `nothing` | No hook scans for secrets; `check-added-large-files` is the only content check on file size |

## Sessions and roots

**Now**

Status: `decided, not proven`

A session runs in one of three places: the workspace checkout, a project's own root, or (for the layer
that reaches project sessions) the user tier in `~/.claude`. The mechanisms below are built and tested
hermetically. [ADR-0016](decisions/0016-session-roots-and-the-user-tier.md) is Provisional until a
`/run-issue` run started from a project root passes through the merge checkpoint (the acceptance test
named in #317), so none of this is marked `decided` yet. [Open questions](#open-questions) OQ-2 asks
where that run is tracked.

- The workspace and each project are separate session roots. A session is in exactly one, found from
  its cwd by the longest-prefix match against the registry; registered project roots are checked before
  the workspace checkout, so a project registered inside the workspace tree is still a project
  (`registry_resolve_from_dir` and `registry_derive_type_from_dir` in `_project_registry.sh`;
  ADR-0016 decision 1).
- When `--type` is omitted, the worktree scripts and `dispatch_phase.sh` take the type and project
  from the cwd the same way (`registry_derive_type_from_dir`; ADR-0016, "Multi-project machines need
  disambiguation").
- The user tier is installed from a workspace checkout by `.agent/scripts/user_tier_install.sh`: a
  `SessionStart` hook, a `PreToolUse` hook, permission rules for the promoted scripts, and a symlink in
  `~/.claude/skills/` for every skill that declares `session_scope: project` or `session_scope: both`.
  Everything it writes is tagged with the checkout, so install is repeatable and `--uninstall` removes
  only its own entries (`user_tier_install.sh` header).
- The `SessionStart` hook (`.claude/hooks/session_start_project_layer.sh`) gives a session under a
  registered root the workspace layer, rendered from nine pinned `AGENTS.md` headings, and the project
  layer, built from the registry entry and the project's own agent guide. Outside every registered root
  and the workspace checkout it prints nothing. Because the layer is rendered from pinned headings,
  those `AGENTS.md` headings are an interface: renaming one would empty the layer silently, so
  `test_session_start_layer.sh` fails if one goes missing.
- An entry reaches the user tier only if it does nothing outside the workspace checkout and the
  registered roots. `.agent/user_tier_scripts.txt` lists the promoted set, and
  `test_user_tier_guard.sh` fails on an entry that has no guard or does not refuse from an unregistered
  repository (ADR-0016 decision 6).
- A skill finds workspace scripts from a project cwd through the file `~/.claude/agent-workspace-root`,
  not an environment variable: hook output is text for the model and never reaches a tool call's
  shell. Workspace scripts do not read the file; they resolve their own root from their location and the
  project from their `$PWD` (ADR-0016 decision 7; `run-issue/SKILL.md` reads it at the head of a command
  chain).

**Target (decided, not built)**

Status: `decided, not built`

- Discovery becomes registry-only: PR 4 of #265 removes the legacy `project/` step. The dispatcher
  still has it as step 3 of its resolution order (`adapter` header; ADR-0016, "ADR-0011's discovery
  order will be superseded").
- Registration is a workspace script, `register_project.sh`, also PR 4 (ADR-0016 decision 5). It does
  not exist yet (`.agent/scripts/` has no such file).
- The workspace tree hosts no project, and the workspace writes nothing into a project checkout beyond
  `.git/info/exclude` and an untracked `COLCON_IGNORE` (ADR-0016 decision 2). The registry's default
  hosting directory is still `projects/<name>` under the workspace (`_project_registry.sh` header).
- A project's memory attaches to its own root, not to the workspace (ADR-0016 decision 4). No workspace
  script implements or checks this.

**Target (open)**

Status: `open`

The workspace as a registered project: #295.

## Registry and adapters

**Now**

Status: `decided`

- The registry, `.agent/projects.local` (per machine, gitignored), maps a project name to a hosting
  directory and a project type, plus optional `key=value` fields. A parent root (pseudo-type `project`)
  groups the instances of one project, such as one per ROS distro, and has no adapter. The syntax is in
  the header of `_project_registry.sh` and in `.agent/projects.local.example`.
- Registration is by hand. No script writes the registry, and `onboard-project` does not mention it
  (grep of `.agent/scripts/` and `.claude/skills/*/SKILL.md`, 2026-10-09).
- Behaviour that differs per project shape sits behind a 12-verb adapter contract, one `adapter.sh` per
  type in `.agent/project_types/<type>/` (ADR-0011, extended by ADR-0012 from 10 verbs to 12).
  `REQUIRED_VERBS` in `.agent/scripts/adapter` is the one list, and `validate_adapter.sh` checks that
  every type implements every verb, in pre-commit and in CI.
- Workflow scripts call adapter verbs and do not branch on the project type: a grep of `.agent/scripts/`
  for the two type names finds only help text and docstrings (2026-10-09).
- Two types exist. `single_project` is one repository at the hosting directory. `ros2_colcon` is ordered
  colcon layers driven by a manifest, and its `adapter.sh` header holds the layers, the bootstrap URL
  order and the distro rule.
- The active project is resolved in this order: `--project`, then the cwd inside a registered hosting
  directory (longest match), then the legacy `project/` checkout (`adapter` header, "Multi-tenant
  resolution").
- The project's own `remote.origin.url` is its URL, and the project stays usable without the
  workspace. ADR-0011 supersedes ADR-0003 and carries that project-agnostic doctrine forward.
- GitHub is not a project dependency; the workspace uses it for now (owner, 2026-10-05).

**Inventory: where the workspace path differs from the registered-project path**

Owner decision 2026-10-09 (C2). It is here so the open question of making the workspace a registered
project (#295) is decided by reading these two tables after the ADR-0016 acceptance run, not by a hunch.
The tables are cut back once #295 is decided. Line numbers are as of this commit; they are a dated
probe, not a description to keep current.

*Table 1: places where the scripts take a different path for the workspace than for a registered project.*

| Script | What differs | Lines |
|---|---|---|
| `worktree_create.sh` | `--type` derived from the cwd when omitted; `--layer` and `--package-repos` project only; project fetches its PR slug from the project's `origin`; the repo manifest comes from the adapter's `worktree_repos` for a project only, and the workspace case never calls the adapter; worktree base is `wt_project_base` (the registry entry's own root) or the legacy glob versus `wt_workspace_base` (`worktrees/workspace`); the draft PR targets `$PROJECT_GH_SLUG` versus the workspace remote | 248-260, 298-304, 452-457, 541-553, 575-587, 1028-1034 |
| `worktree_enter.sh`, `worktree_remove.sh` | The same `--type` derivation and check; `--project` is valid only with `--type project` | enter 143-174, remove 130-157 |
| `merge_pr.sh` | A project PR needs a resolved project root with an `origin` remote; PR-owner auto-detect queries both remotes; the roadmap-commit worktree lookup uses `PJ_REPO_ROOT`; the gate's timeline lookup is anchored at `$ROOT_DIR/project`, the legacy checkout, not `PJ_REPO_ROOT` (tracked as #379); the gate enforces on workspace PRs only and is report-only for project PRs "until #265 settles project timelines"; cleanup deletes the branch in `PJ_REPO_ROOT` and pulls the project too | 236-270, 379-418, 555, 670, 916 and 929, 1612-1628 |
| `dispatch_phase.sh` | `resolve_worktree`: workspace uses `wt_workspace_base`; project uses `derive_project_name` (from `--project` or the cwd) and then `wt_project_base`; `--type` is validated in all three modes | 122, 183-208, 302, 369, 461 |
| `gh_create_pr.sh` | The repo-safety check accepts the workspace slug or the slug of the legacy `project/` checkout; registered projects are not consulted | 205-232 |
| `worktree_list.sh` | A workspace worktree is recognised by the path `*/worktrees/workspace/*` | 149-150 |
| `_project_registry.sh` | `registry_derive_type_from_dir`: `project <name>` when the cwd is under a registered root, else `workspace` when inside the workspace checkout | 485-500 |
| `run-issue` skill and `agent start-task` | `--type` defaults to `workspace` and is passed on to `dispatch_phase.sh`, `worktree_create.sh`, `gh_create_pr.sh` targeting and `merge_pr.sh --type` | `SKILL.md` 47-54; `agent` 63, 90 |

Checked and found with no workspace-or-project branch: `review_progress.sh` (it finds the records from
the cwd's git top level, lines 110-112 and 288-291), `progress_append.sh` (line 85-88),
`_resolve_work_plans_dir.sh` and `_bookkeeping.sh`.

*Table 2: the 12 adapter verbs, if the workspace were a registered project.* "Real" means the workspace
needs logic of its own; "thin wrapper" means a script or target that already exists does the work;
"no-op" means the `adapter` header allows doing nothing.

| Verb | For the workspace | Based on |
|---|---|---|
| `setup` | thin wrapper | The `setup-dev` and `git-bug` stamps (`Makefile` header, line 98); `single_project/setup.sh` clones a project, which the workspace does not need |
| `sync` | thin wrapper | `single_project/sync.py` already syncs the workspace repo with the project |
| `validate` | thin wrapper, with care | `validate_workspace.py` checks the whole workspace and calls this verb for each registry entry, so the workspace's own implementation must not call back into it |
| `build` | no-op | Nothing is built; `make build` runs the project's `BUILD_CMD` |
| `test` | thin wrapper | `.agent/scripts/tests/run_script_tests.sh`, the `validate-script-tests` hook's entry (`.pre-commit-config.yaml`) |
| `install` | thin wrapper | `user_tier_install.sh` (`make user-tier-install`, `Makefile` line 164) |
| `env` | no-op | The `adapter` header: a type with no environment to expose emits nothing |
| `project_root` | real, trivial | Prints the workspace root |
| `repos` | real, trivial | One `name:path` line |
| `scope_for_pr` | real, small | Origin URL to `owner/repo`; `single_project`'s verb already does this generically |
| `worktree_repos` | real, trivial | One line `<root>`, `.`, `feature/issue-<N>`; `worktree_create.sh` does not call it for the workspace today |
| `worktree_env` | no-op | No per-worktree environment |

Tally: 3 no-op, 5 thin wrapper, 4 real. No conclusion is drawn from it here; that is the #295 decision.

**Target**

Status: `proposed`

Proposed: `onboard-project` is the one way a project is registered and adapted (#332). A project's
life from register to unregister is defined, including one project on two machines. Mixed-flavour
projects, a repository carrying tools of another flavour, are supported (#310). [Open questions](#open-questions)
C4 holds what is unsettled. The legacy `project/` shape is dropped with the registry-only change
described under [Sessions and roots](#sessions-and-roots).

## Worktrees

**Now**

Status: `decided`

- All feature work happens in an isolated git worktree, never by switching branches in the main tree
  (ADR-0002). There are two kinds, and the worktree scripts take `--type workspace|project`, derived
  from the cwd when it is omitted (`worktree_create.sh`, `worktree_enter.sh`, `worktree_remove.sh`; see
  [Registry and adapters](#registry-and-adapters), Table 1).
- A workspace worktree is a worktree of the workspace repository, under `worktrees/workspace/`. A
  project worktree is a worktree of the project's repository, under the registered root's own
  `worktrees/` or its `worktrees=` override, resolved by `registry_worktree_dir`. An unregistered
  project falls back to `worktrees/project/<repo>/`, dropped with the legacy `project/` checkout.
  Naming, the `.git/info/exclude` line the workspace adds to a project root, and the `COLCON_IGNORE`
  marker a `ros2_colcon` worktree writes are in `.agent/WORKTREE_GUIDE.md` and `_worktree_helpers.sh`.
- A worktree is entered with `cd`, not the native `EnterWorktree` tool, because that tool accepts only
  worktrees of the current repository and a project is a separate repository (`AGENTS.md`, "Worktree
  Entry").
- Agents work concurrently in separate worktrees. Work in progress is made visible by a draft pull
  request, which `worktree_create.sh --plan-file` opens, and an agent checks for one before starting
  (`WORKFORCE_PROTOCOL.md` sections 1 to 3). `make lock` is an advisory note shown by the dashboard and
  stops nothing (`lock.sh` header).
- **Records.** An issue's work plan and progress timeline are committed in the project repository on
  the issue's feature branch, under `.agent/work-plans/issue-N/` (owner decision 2026-10-09, C3).
  `progress_append.sh` line 87 writes `<repo-root>/.agent/work-plans/issue-<N>/progress.md`, and ADR-0013
  names that path. One gap shows in the project case: `merge_pr.sh` looks up the gate's timeline at
  `$ROOT_DIR/project` (line 670), the legacy checkout, and the gate is report-only for project pull
  requests (lines 916 and 929). That is tracked as #379 ("merge_pr.sh review gate looks up a project
  PR's timeline at the legacy project/ path, not the registry root"). Its fix is one line, using the
  registry-aware root that line 555 already uses (`${PJ_REPO_ROOT:-$ROOT_DIR/project}`), and it does not
  wait for the Target below. The change that fixes #379 edits this paragraph in the same change.

**Target**

Status: `proposed`

Proposed: a project carries its records by choice, through two settings in its registry entry, each with
a default derived when the entry omits it.

- `location`: in the project repository (the default), or an outside path. The default outside path is
  a fixed derived one, such as a sibling directory of the project root; the exact path is chosen when
  this is built.
- `tracking`: untracked; tracked in the project repository (the default when the location is in the
  project repository); or tracked in a repository the user names. This document gives no example of
  that repository being `agent_workspace` (owner: "I don't want to prohibit it, but I also don't want to
  encourage it").

| location | tracking | What it is |
|---|---|---|
| in the project repository | tracked in the project repository | Today. The records travel with the feature branch |
| outside | untracked | No footprint in the project; one machine |
| outside | tracked in a named repository | No footprint in the project; portable |
| in the project repository | untracked, through the clone's `.git/info/exclude` | Behaves like outside and untracked |

Other combinations are not named as working; whether the registry rejects them is decided when this is
built. Three mechanisms would do it, each a later build:

1. One lookup, "where are the records for this project and issue", fed by the registry entry and used
   by every reader and writer. Today each one writes the path out itself: `dispatch_phase.sh` (lines
   342, 344, 387, 479: the exit contract, `--check-exit` and `next`, which is what a resumed session
   reads), `merge_pr.sh` (674-675, 829-837: the gate and its `Merge` entry), `review_progress.sh` (112,
   268, 290) and `progress_append.sh` (87). `_resolve_work_plans_dir.sh` is the nearest lookup that
   exists, and `cross_model_review.sh --work-plans-dir` already feeds it an override. The seven skills
   that cite the path follow it. The gate's lookup at `merge_pr.sh` line 670 is the first to be wrong
   for a registered project (#379).
2. The merge gate's "same reviewed state" rule (`_bookkeeping.sh`, shared with `review_progress.sh
   sources`) reads the record from where it lives and checks the project commit the entry names, so the
   walk changes repository. Finding the record at all is #379, which comes before this.
3. Untracked records are per machine and per clone. A second machine or a fresh clone starts with no
   timeline, and losing the directory loses the history. That is the cost of the combination.

One rule: when records exist in two places, the registry setting names the source of truth.

Acceptance test for this Target: a colleague's project, by shape only: a single-repository web app
developed in a different style, with no GitHub issues or pull requests, and records where its developer
chooses. Both settings must be able to describe it. Because it has no pull requests it exercises the
lookup and the tracking and not the merge gate (mechanism 2), which a project with pull requests has to
exercise.

## Review loop and timeline

**Now**

Status: `decided`

An issue passes through eight phases in this order. `review-code` runs twice, once on the unpushed
branch and once on the pull request, and `address-findings` fixes what a review found between its runs.
The `/run-issue` skill (Claude Code only) walks the order with `dispatch_phase.sh`; Codex and Gemini
sessions walk the same order by hand, one `SKILL.md` at a time
(`.agent/knowledge/review_loop_lifecycle.md`; ADR-0013, ADR-0014).

| Phase | What it produces | What follows, and who decides |
|---|---|---|
| `review-issue` | An `## Issue Review` entry and a comment on the issue | Open `### Actions` boxes go to the owner at an `issue-actions` checkpoint; with none open the loop moves on to `plan-task` |
| `plan-task` | `plan.md`, committed on the feature branch, and a `## Plan Authored` entry | `review-plan` runs next, no decision |
| `review-plan` | A `## Plan Review` entry | The owner decides at the `plan` checkpoint after every plan review, whatever its verdict: proceed, revise or stop |
| `implement` | Commits on the branch and an `## Implementation` entry; it never pushes | `review-code` on the branch runs next, no decision |
| `review-code` | `## Local Review (Pre-Push)` before the push, `## Local Review` after it | Pre-push: an approved verdict goes to the owner at the `publish` checkpoint; otherwise `address-findings` runs, and after 3 rounds (`MAX_ROUNDS`) without approval the owner is asked at `rounds`. Post-push: approved goes on to `triage-reviews`, otherwise `address-findings` |
| `publish` | The push and the pull request, whose body carries a `## Decision summary` heading | The owner has just decided at `publish`; the host does the push (`run-issue/SKILL.md` step 7) |
| `triage-reviews` | An `## Integrated Review` entry: every review source combined into one list of findings with a verdict on each | Open findings go to the owner at `findings`; with none open the owner is asked at `merge` |
| `merge` | The merge by `merge_pr.sh`, its worktree removal and branch cleanup | The owner decides at the `merge` checkpoint. The gate in `merge_pr.sh` refuses a gap on a workspace PR; a merge that does not end merged goes to `merge-refused` |

- **One entry per phase, in `progress.md`.** `.agent/work-plans/issue-<N>/progress.md` is the only place
  loop state lives: not the conversation, not a lock file. The directory sits in the repository that
  owns the issue, on the issue's feature branch ([Worktrees](#worktrees), Records). Entries have a fixed
  vocabulary and header (`**Status**`, `**When**`, `**By**`, a correlation to an issue, a plan or a
  commit; ADR-0013), are written by `progress_append.sh`, checked by `_progress_entry.sh` and read by
  `progress_read.py`.
- **The next step is read from the newest entry.** `dispatch_phase.sh next` reads only the newest entry
  and, as its one other input, the pull request state; it makes no `gh` call and returns one action from a
  28-row table (`dispatch_phase.sh` header). A partial or failed newest entry is always a `phase-failed`
  checkpoint, never a silent retry.
- **Each phase runs in a fresh sub-agent.** `dispatch_phase.sh --issue <N> --skill <phase>` prints the
  handoff, and the host pastes it into a new Agent call, in this process only. The sub-agent fetches its
  own inputs with `gh` and never pushes (ADR-0014; `dispatch_phase.sh` exit contract). Reviewers outside
  Claude run in parallel and synchronously through `cross_model_review.sh` (ADR-0015).
- **The host checks the exit, not the sub-agent's word.** `dispatch_phase.sh --check-exit` compares the
  count of entries of the phase's type before and after, and returns `OK`, `PARTIAL`, `FAILED` or
  `MISSING`; anything but `OK` goes to the owner at `phase-failed` to retry, take over or stop. What it
  checks is that an entry of the right type appeared, its `**Status**` and, for an `## Implementation`
  entry, its `**PR**` or `**Branch**` line. It does not check whether a review's findings are right; the
  merge gate reads the `**Verdict**` and the open boxes a reviewer wrote.
- **Nine checkpoint kinds stop for the owner**: `issue-actions`, `plan`, `publish`, `rounds`,
  `findings`, `merge`, `merge-refused`, `phase-failed` and `unexpected`. Each answer is recorded as a
  `## Checkpoint` entry (`**Decided-by**: owner`) before the loop moves on, and an answer outside a
  checkpoint's fixed vocabulary routes to `unexpected`. No phase advances on its own judgment
  (`review_loop_lifecycle.md`).
- **One driver per issue.** There is no lock; a second driver or a hand edit shows only as an unexpected
  entry at the next check (ADR-0014).

**Target**

Status: `proposed`

- Proposed (candidate): the design says, for each claim in the loop, whether code verifies it or the
  agent reports it. Today the shape of an entry, the exit count and status, and the gate's conditions are
  verified in code, and the content of a review is reported.
- Proposed (candidate): a new session finds the records for its issue through the one lookup in the
  Target of [Worktrees](#worktrees), so the path is not written out in each reader.
- Proposed (candidate): a size bound on records. This issue's own `progress.md` is 726 lines
  (`wc -l`, 2026-10-09), and every reader parses the whole file.

**Target (open)**

Status: `open`

What a review finding must contain, and how independent the reviewers are: C5 in
[Open questions](#open-questions).

## Merge gate

**Now**

Status: `decided`

- The owner decides every merge. The loop stops at the `merge` checkpoint, and the flags that relax the
  gate (`--report-only`, `--no-wait`, `--allow-pending-review`, `--force-unreviewed`) are passed only on
  the owner's answer for that merge, never on the host's judgment (`run-issue/SKILL.md` step 11; see
  [Review loop and timeline](#review-loop-and-timeline)).
- `merge_pr.sh` checks two things before it merges. (a) The newest review entry (`## Local Review` or
  `## Integrated Review`) is at the pull request's head, and is approved, or for an Integrated Review is
  complete with no open must-fix or cross-confirmed finding. (b) The pull request body or a comment has
  a `## Decision summary` heading (`merge_pr.sh`, Step 1.5).
- A review at an earlier commit still counts when only bookkeeping changed since: that issue's
  `.agent/work-plans/issue-N/` files and the roadmap. `_bookkeeping.sh` holds that one rule; the merge
  gate, the CI target and `review_progress.sh sources` all use it.
- The script then waits for CI on the reviewed head, not on whatever the head has moved to. A review
  check-run that is still running (Copilot's) holds the merge unless `--allow-pending-review` is passed;
  its conclusion is never read as CI.
- The gate enforces by default on workspace pull requests: a gap refuses with exit 1 and no entry.
  Project and package pull requests are report-only: the gap is printed and recorded as a
  `## Merge (report-only)` entry and the merge goes ahead. `--force-unreviewed` bypasses both conditions
  with a banner and a `## Merge (unreviewed)` entry. A merge that does not end merged after one of
  those entries goes to the `merge-refused` checkpoint.
- The gate is local only. A Merge click on GitHub bypasses it, and the server-side complement, a required
  status check, is not built; building it changes CI and branch protection, which is Ask First
  (`merge_pr.sh`, Step 1.5 comment; [Rules](#rules)).
- For a project pull request the gate's timeline lookup is anchored at the legacy `project/` checkout.
  That is #379, described under [Worktrees](#worktrees).

## Identity

**Now**

Status: `decided`

- An agent signs its work with a framework identity: a name, an email of the form
  `roland+<framework>@<domain>`, a model name and a framework key. The table of frameworks is
  `.agent/scripts/framework_config.sh`; the strategy and the reasons are in
  [`.agent/AI_IDENTITY_STRATEGY.md`](../.agent/AI_IDENTITY_STRATEGY.md). The identity is on the commit
  and, through `AGENT_NAME` and `AGENT_MODEL`, in the signature on GitHub text.
- On an agent that runs on the host, the identity is ephemeral: `set_git_identity_env.sh` is sourced
  into the session, sets the `GIT_AUTHOR_*` and `GIT_COMMITTER_*` variables and the `AGENT_*` variables,
  and leaves `.git/config` alone, so the owner commits as himself afterwards. Shell state does not
  carry between tool calls, so it is sourced in the same call as the command that needs it.
- Three things refuse to run without an identity or with a wrong one: the `check-commit-identity` hook
  (accepted emails are the agent pattern and the owner's two addresses), `dispatch_phase.sh` (exit 2
  when `AGENT_NAME` or `AGENT_EMAIL` is unset, with no fallback to the owner's git config) and
  `progress_append.sh` (fails loudly when unset). `gh_create_pr.sh` exits 2 for an unsigned body
  ([Rules](#rules)).
- The work is kept tool-neutral (principle "Use the main tool fully; keep the work tool-neutral"):
  plans, reviews and progress are plain files any tool reads. What needs Claude Code is the
  `/run-issue` and `/start-task` skills (their descriptions say so), the user tier in `~/.claude`
  ([Sessions and roots](#sessions-and-roots)) and the Agent tool that dispatches phases. Without it, a
  Codex or Gemini session walks the same phases by hand, one `SKILL.md` at a time
  ([Review loop and timeline](#review-loop-and-timeline)). Each framework has an
  adapter file listed in `AGENTS.md`.

## Instruction layers

**Now**

Status: `proposed`

Nothing here is built. This section is a proposal, so its one block is labelled `Now` and carries
`proposed`.

Proposed: this file describes the four layers an agent's instructions load in, and gives the first a
budget.

1. Always loaded. For Claude Code that is `CLAUDE.md`, which imports `AGENTS.md` with `@AGENTS.md`;
   `AGENTS.md` is 26,564 bytes and 442 lines, `CLAUDE.md` 42 lines (`wc`, 2026-10-09). A session under a
   registered project root gets nine pinned `AGENTS.md` sections instead, rendered by the
   `SessionStart` hook ([Sessions and roots](#sessions-and-roots)).
2. Path-scoped. Rules that load only when the agent works on matching files. The workspace has none
   (`.claude/` holds `hooks`, `settings.json` and `skills`).
3. Skill. A `SKILL.md` loads when its skill is invoked (22 skills in `.claude/skills/`).
4. On demand. Files an agent opens because a pointer sent it there: this file, the ADRs, the
   knowledge files. This file is not always loaded.

Proposed: a budget for the always-loaded layer, so that every added rule has to displace or justify
itself. No number is set here. The reference point is the vendor guidance for Claude Code, a target of
under 200 lines per instruction file, as recorded in the prior-art notes
(`prior-art-comparison-2026-10-08/summary.md` item 5; `prior-art-alignment-agent-frameworks.md`, Claude
Code entry). Changing `AGENTS.md` is Ask First and is not part of this change.

## Decision register

**Now**

Status: `decided`

Purpose: tell a reader which ADR still governs, so nobody follows a superseded or drifted one. One row
per ADR in `docs/decisions/` (17), in order. The ADRs are history and none is edited here (owner
decision 2026-10-09, C1-c); this table is the only place the standing below is recorded.

Standing takes one of four values. `in force`: the ADR's Status line says Accepted and nothing found
contradicts it. `superseded`: a later ADR replaced it, as its Status line says. `superseded in
practice`: the ADR is Accepted but the code does something else, stated in the cell. `Provisional`: the
ADR's own Status line. Re-examined is `yes <date>` when the ADR was checked against the code while
this document was rewritten, and `not yet` when it was not; the date is the checked-date, and
`/audit-workspace` is meant to refresh it. A section link of `#decision-register` means no section of
this file carries that ADR.

| ADR | Decision | Standing | Section | Re-examined |
|---|---|---|---|---|
| [0001](decisions/0001-adopt-architecture-decision-records.md) | Record decisions as short dated ADRs in `docs/decisions/`; accepted ADRs are history, superseded and not edited. Its trigger is scoped by ADR-0017 | in force | [Decision register](#decision-register) | not yet |
| [0002](decisions/0002-worktree-isolation-over-branch-switching.md) | All feature work happens in git worktrees, not by switching branches; the worktree scripts take `--type workspace\|project` | superseded in practice: project worktrees live under the registered root's own `worktrees/` (or `worktrees=`), and `worktrees/project/<repo>/` is only the legacy fallback; `--type` is derived from the cwd when omitted | [Worktrees](#worktrees) | yes 2026-10-09 |
| [0003](decisions/0003-workspace-infrastructure-is-project-agnostic.md) | The workspace stays project-agnostic for a single-repo project | superseded by ADR-0011, which carries the doctrine forward | [Registry and adapters](#registry-and-adapters) | yes 2026-10-09 |
| [0004](decisions/0004-enforcement-hierarchy-for-agent-compliance.md) | A rule that matters is enforced at more than one layer; instruction files alone are not enough | in force | [Rules](#rules) | not yet |
| [0005](decisions/0005-layered-enforcement-strategy.md) | CI is the enforcement layer, pre-commit hooks the local mirror, framework hooks the early feedback; new rules go CI-first | in force | [Rules](#rules) | not yet |
| [0006](decisions/0006-adopt-agents-md-as-shared-instruction-file.md) | `AGENTS.md` holds the shared rules and each framework gets a thin adapter file | in force | [Decision register](#decision-register) | not yet |
| [0007](decisions/0007-retain-make-with-dependency-tracking.md) | Keep Make as the task runner, with stamp files for setup dependencies | in force | [Decision register](#decision-register) | not yet |
| [0008](decisions/0008-permit-cross-reference-addendums-in-adrs.md) | An accepted ADR may gain a status note, a references list or link and typo fixes; anything else needs a superseding ADR | in force | [Documentation layers](#documentation-layers) | not yet |
| [0009](decisions/0009-python-package-management-policy.md) | Python tools go in the workspace `.venv` (from `requirements.txt`) or in pipx; PEP 668 is the guardrail | in force | [Decision register](#decision-register) | not yet |
| [0010](decisions/0010-git-bug-is-optional.md) | git-bug is installed by default and `skip-git-bug` opts out; scripts work without it | in force | [Decision register](#decision-register) | not yet |
| [0011](decisions/0011-project-type-adapter-contract.md) | Behaviour that differs per project shape sits behind a fixed adapter contract per project type; workflow scripts never branch on the type | superseded in practice: the dispatcher resolves `--project`, then the cwd inside a registered directory, then the legacy `project_config.sh`, and the contract has 12 verbs, not the 10 its Decision lists | [Registry and adapters](#registry-and-adapters) | yes 2026-10-09 |
| [0012](decisions/0012-worktree-composition-is-an-adapter-concern.md) | Worktree composition is an adapter concern: the `worktree_repos` and `worktree_env` verbs | in force | [Worktrees](#worktrees) | yes 2026-10-09 |
| [0013](decisions/0013-progress-md-entry-type-vocabulary.md) | `progress.md` has a fixed entry vocabulary and header, with a correlation key per entry type | superseded in practice: its writer table says `address-findings` and "any future implement skill" write `## Implementation`; there is no implement skill, and the dispatched implement pass writes it | [Review loop and timeline](#review-loop-and-timeline) | yes 2026-10-09 |
| [0014](decisions/0014-in-process-phase-handoff.md) | Each phase runs in a fresh in-process sub-agent through `dispatch_phase.sh`, and the host checks the exit instead of trusting the sub-agent | superseded in practice: its Decision calls `implement` the inline pass; since #314 `implement` is dispatched like every other phase and only a `takeover` answer runs a phase inline | [Review loop and timeline](#review-loop-and-timeline) | yes 2026-10-09 |
| [0015](decisions/0015-parallel-sync-is-the-only-review-dispatch-mode.md) | Cross-model reviewers run in parallel and synchronously; there is no tmux mode | in force | [Review loop and timeline](#review-loop-and-timeline) | yes 2026-10-09 |
| [0016](decisions/0016-session-roots-and-the-user-tier.md) | The workspace and each project are separate session roots, and a user tier carries the workspace layer to project sessions | Provisional | [Sessions and roots](#sessions-and-roots) | yes 2026-10-09 |
| [0017](decisions/0017-design-document-is-the-current-picture.md) | This file is the current picture and the authority; an ADR is written only when two parts could otherwise choose incompatibly | in force | [The design](#the-design) | yes 2026-10-09 |

Plan-level decisions that never got an ADR: none are listed. The plan for this rewrite names none that
is not already stated in a section above with its issue.

**For the owner, one at a time (C1-c).** Four ADRs are `superseded in practice` (0002, 0011, 0013,
0014). Each is a candidate for a superseding ADR, and each supersession is the owner's call, made one
ADR at a time; none is made here. ADR-0016 stays `Provisional` until the acceptance run
([Sessions and roots](#sessions-and-roots)).

## Open questions

**Now**

Status: `open`

Questions this file raised and nobody has answered. An `open` block elsewhere in the file points here
or to an issue. Each row says who decides and what the answer changes. Wire-in questions about
ADR pointers and the roadmap belong to the pull request that does that wiring, not to this table.

| ID | Question | Who decides | What it changes |
|---|---|---|---|
| OQ-1 | Where does a project record its own mapping of the seven documentation roles? | Owner | The Target of [Documentation layers](#documentation-layers); nothing built depends on it yet |
| OQ-2 | ADR-0016 stays Provisional until the `/run-issue` acceptance run from a project root, and its promotion condition names #317, which closed on 2026-09-23. Where is the acceptance run tracked, and who runs it? | Owner | When the [Sessions and roots](#sessions-and-roots) Now block becomes `decided`, and when the Registry inventory is read to settle #295 |
| C4 | Is `onboard-project` the only path that registers and adapts a project (#332) and is hand registration retired? What does unregistering do to a project's plans, timelines and memory, and how does one project live on two machines? How are mixed-flavour projects (#310) described? | Owner | The Target of [Registry and adapters](#registry-and-adapters); no code depends on it yet |
| C5 | What must a review finding contain (a principle, a row in the review guide, or design text only), and how independent must its reviewers be? If design text only it goes in [Review loop and timeline](#review-loop-and-timeline); if a principle, it is a separate change | Owner | Whether `## Review loop and timeline` gains a rule, or `docs/principles.md` and the review guide change |
| OQ-3 | Where do "healthy" and the measures live for the workspace (the Direction and Measures roles have no home for them), and how will anyone tell a change helped? | Owner | The two gap rows of [Documentation layers](#documentation-layers); the long-view goal in the README |
| OQ-4 | What budget does the always-loaded instruction layer get (the reference point is under 200 lines per file; `AGENTS.md` is 442)? | Owner | [Instruction layers](#instruction-layers); changing `AGENTS.md` is Ask First |
| OQ-5 | Should the merge gate get a server-side complement, a required status check asserting the same two conditions? | Owner | [Merge gate](#merge-gate); it changes CI and branch protection, which is Ask First (`merge_pr.sh`, Step 1.5 comment) |

## Change log

**Now**

Status: `decided`

One row per change to this file, appended in the same change that alters a section: date, section, one
line, issue, and the line count of the document after the change. The line count is how growth shows up
as a number (principle "Know whether it works"); a section past about 60 lines says in its row whether
its detail should move next to the code. A change that fixes #379 or builds a Target also edits the
sentence it makes untrue in the same change (ADR-0017).

| Date | Section | Change | Issue | Lines |
|---|---|---|---|---|
| 2026-10-09 | Whole file | Skeleton. Rewrite starts from the plan's section table: `# How it works` is a stub (written last), `# The design` opens with the admission rule and the Status key, and everything the old file held that now lives next to the code is gone (destinations landed in #377) | #335 | 40 |
| 2026-10-09 | Purpose | What the file is for, with pointers to the README goals and the principles | #335 | 54 |
| 2026-10-09 | Documentation layers | The seven roles and the workspace's mapping, with the two gaps (healthy, measures) shown; per-project mapping as a proposal | #335 | 94 |
| 2026-10-09 | Rules | Rules table with the enforced-by column: 14 rules, each with the check checked against the hook, script or CI file | #335 | 129 |
| 2026-10-09 | Open questions | Section started with the first gap found while writing: where a project records its role mapping | #335 | 143 |
| 2026-10-09 | Sessions and roots | Three session places, the user-tier mechanisms that are built, the PR 4 items decided but not built, #295 as an open pointer; OQ-2 added. Section is 63 lines, past the 60-line prompt: asked whether the detail moves next to the code; it stays, because the pinned `AGENTS.md` headings, the user-tier rule and the root file are interfaces between the hook, the installer, the skills and `AGENTS.md`, and no one script header shows all four | #335 | 208 |
| 2026-10-09 | Registry and adapters | Registry, the 12-verb contract, resolution, the C2 inventory (8 script rows, 4 scripts without a branch, 12 verbs classified), Target from #332 and #310; C4 added. Section is 83 lines, past the 60-line prompt: asked whether the detail moves next to the code; the registry and contract text already lives there and is one sentence each here, and the rest is the owner-directed inventory, a dated probe for the #295 decision that is cut back once #295 is decided | #335 | 293 |
| 2026-10-09 | Worktrees | Two kinds and where they live, entering, concurrency, the Records Now text citing #379, and the C3 Target (location and tracking, the four combinations, three mechanisms, source-of-truth rule, acceptance test by shape). Section is 79 lines, past the 60-line prompt: asked whether the detail moves next to the code; the layout detail already lives in the worktree guide and is one bullet here, and the Target is design for something not built, so no code or script header can hold it yet. Stays; it splits into its own Records section if the Target grows past 60 lines | #335 | 374 |
| 2026-10-09 | Review loop and timeline | The eight phases in order with what each produces and who decides, the timeline as the only loop state, fresh sub-agent per phase, the exit check, nine checkpoints; Target candidates and the C5 pointer; C5 added. Also the review guide's work-plan row now names this section instead of the removed directory tree. Section is about 70 lines, past the 60-line prompt: asked whether the detail moves next to the code; the lifecycle file and dispatch_phase.sh header already hold the mechanics, so the section keeps only the phase table and one bullet per mechanism, and what it adds is the who-decides column and the code-versus-reported line, which no one file shows | #335 | 446 |
| 2026-10-09 | Merge gate | Who decides a merge, the two conditions, the bookkeeping rule, the CI wait, enforce versus report-only, local-only, the #379 gap | #335 | 478 |
| 2026-10-09 | Identity | Framework identity, ephemeral per session, what refuses to run without it, and what needs Claude Code versus what any tool can do | #335 | 507 |
| 2026-10-09 | Instruction layers | The four layers an agent's instructions load in and a budget for the always-loaded one, all proposed; AGENTS.md is 442 lines against the under-200 target | #335 | 536 |
| 2026-10-09 | Decision register | 17 rows, standing and re-examined, four rows superseded in practice (0002, 0011, 0013, 0014) with what the code does; no ADR file edited; both checker guards are live from here. Section is 40 lines | #335 | 583 |
| 2026-10-09 | Open questions | Table finished: OQ-1 to OQ-5, C4 and C5 | #335 | 588 |
| 2026-10-09 | Change log | Now block: the rule for rows and the line count | #335 | 596 |
| 2026-10-09 | Glossary | Added as the last section: 15 settled entries (7 own terms, 8 standard), the admission rule, WIP limit and appetite left out | #335 | 650 |
| 2026-10-09 | How it works | Agent draft from the fact list and the owner's recorded phrasings, no new ideas, replacing the stub; owner to edit | #335 | 688 |

## Glossary

**Now**

Status: `decided`

One line per term, in plain words, for a reader who has never seen the workspace. A term is here if it
appears in a situation report or a checkpoint, except the eight phase names (`review-issue`,
`plan-task`, `review-plan`, `implement`, `review-code`, `publish`, `triage-reviews`, `merge`). Those are
the workflow, not vocabulary, and are described in order in
[Review loop and timeline](#review-loop-and-timeline). The terms and their definitions were settled
with the owner on 2026-10-09 (C6).

Our own terms:

- **phase**: one of the eight steps an issue passes through (names and order in the Review loop section).
- **round**: one pass of a review phase. Round 2 is the re-review after fixes.
- **convergence**: rounds converge when each finds fewer must-fix items than the last. When they stop
  converging the loop steps back.
- **checkpoint**: a point where the loop stops and asks the owner (after the plan, before publish,
  before merge).
- **progress timeline**: the per-issue file where every phase writes an entry, so a new session can see
  what happened without re-reading the chat.
- **Integrated Review**: the entry `triage-reviews` writes, with all review sources combined into one
  list of findings and a verdict on each.
- **must-fix / suggestion**: a review finding that blocks the next phase, versus one the implementer may
  take or leave with a reason.

Standard terms:

- **stage gate**: work passes through fixed phases, and a check at each boundary decides whether it goes
  on. Our loop is one.
- **Definition of Done**: the agreed list of what must be true before work counts as finished. Ours is
  the principles "A change includes its consequences" and "Verify before claiming".
- **proposal status**: the labels a proposal carries through its life. Kubernetes uses provisional,
  implementable, implemented; our ADRs use proposed, accepted, superseded; this document uses decided,
  decided not built, decided not proven, proposed, open.
- **ADR, Architecture Decision Record**: a short dated note recording one decision, its context and its
  consequences. It is a record of history, not the current picture.
- **spike**: a short, throwaway experiment that answers one question, usually whether an approach works
  or what it would cost, before committing to it. Ours: the plugin spike (#345) and the interop spike
  (Codex and agy as headless phase workers). It is not the same as prior-art research, which reads what
  others did.
- **backlog**: the ordered list of work not yet started. Ours is the roadmap plus the open issues.
- **circuit breaker**: a rule that stops work automatically when it exceeds a budget. We have none; the
  nearest is the review-round limit, `MAX_ROUNDS`.
- **reference versus record**: a reference says what is true now and is kept current; a record says what
  was decided when and is never rewritten. This document is the reference; the ADRs and the progress
  timeline are records.

Left out on purpose: WIP limit and appetite. The workspace has neither: a search of `docs/`,
`.agent/knowledge/`, `AGENTS.md` and the skills finds no use of either as a workspace term.
