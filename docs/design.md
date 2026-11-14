# How it works

The workspace helps one person manage many AI agents across one or more projects, so the results can be
trusted and the user stays informed and in control.

Agents are strong within one piece of work and weak across time. So the workspace has two halves: a
day-to-day harness around each piece of work, and a long view of where each project is going. The
principles in [`docs/principles.md`](principles.md) connect them.

**The day-to-day harness.** Work happens in an isolated worktree, never in the main tree
([Worktrees](#worktrees)). An issue passes through eight phases. The host does two of them itself, the
push (`publish`) and the merge; each of the others is run by a fresh sub-agent (a repeat of a phase may
resume the earlier one, and the owner may have the host take over a failed one) and leaves one entry in
the issue's progress timeline, which is the only record of where the issue stands
([Review loop and timeline](#review-loop-and-timeline)). The loop stops at checkpoints. The owner
answers the ones that touch his goals; the host answers the rest under his standing rules, from a fixed
set of answers, and lists each decision for his veto. The owner decides every merge, and no phase moves
on by its own judgment ([Merge gate](#merge-gate)).

**What agents may do alone.** Agents decide small things within their limits and record them. Limits
start strict, and only the user relaxes them. Changing instruction files, CI or branch protection, or the
project remote URL needs the owner's approval first, and an agent never commits to `main` or skips hooks,
so it cannot do lasting damage unasked. Where a rule matters it is backed by the simplest check that
fails when it is broken, and [Rules](#rules) shows which rules have one.

**Projects.** The workspace is project-agnostic. What differs per kind of project sits behind adapters,
and a project's own remote is its URL ([Registry and adapters](#registry-and-adapters)). Each project
is meant to choose how much footprint the workspace leaves in it: agent instructions and records go into a
project only if the user chose that, and a project can be developed without the agents. Today an issue's
records are always committed in the repository that owns the issue; the choice is proposed under
[Worktrees](#worktrees). A session starts in the workspace or in a project's own root,
and a user tier gives a project session the workspace's skills and rules; that is built and has passed
its acceptance run ([Sessions and roots](#sessions-and-roots)).

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
| `decided, not proven` | Decided and built, but the acceptance test named in the deciding ADR's Status has not run; that ADR stays Provisional at least until it does |
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
| Direction | What is planned and in what order | [`docs/roadmap.md`](roadmap.md). Its `## Direction` section, at the top, holds the lines that must be true for the current acceptance case, each with a check, and the deferrals, each with a revisit check; the sit-rep (`/sitrep`) runs those checks through `sitrep_checks.sh`, names the first line not yet true as the next step, and also reports problems from the Decision register's Re-examined dates, the research digest's entry dates and the commits since `docs/design.md` last changed; in a workspace session it may start a due read-only check in the background. A Paths paragraph names the two paths the owner runs in parallel; the sit-rep marks each piece of work in flight with the path it serves and asks which to focus on, a choice that is not stored |
| Measures | How anyone tells whether a change helped | A first form: the sit-rep's run record, one machine-local line per run, per root, with the counts of lines true and deferrals due, so the next run says what moved for that root |

Two of the seven were gaps (`README.md`, "The long view": each project, and the workspace, says what
healthy and the right direction mean and that it is known whether a change helped). Both are narrower
now (#386), neither is closed. The Direction section says what must be true for one acceptance case,
not what healthy means for the workspace in general; the sit-rep's Problems section (dates and
work since for the audit, research and the design document, judged each run with no stored threshold)
is a first form of health signals. The run record counts lines true from
run to run, which shows net change only (one line going true while another goes false reads as no
change) and says nothing about whether a change helped beyond that case. Status and dates are measured
by each run and stay on the machine; the roadmap holds no status column. The result words (`true`,
`false`, `partial`, `unknown`, `unchecked`) are a trial.

`.agent/scripts/discover_governance.sh` lists the governance files it finds in the workspace root and in
the legacy `project/` checkout, under six types: `principles`, `architecture`, `agents-config`,
`agent-guide`, `adr` and `workspace-context`. It does not scan registered projects and does not know
the seven roles (checked in the script's `scan_scope`).

**Target**

Status: `proposed`

Proposed: a project records its own mapping of the seven roles, seeded from the types that
`discover_governance.sh` already finds, and never forced on it: a convention is encouraged where a
project has no documentation (owner goal of 2026-09-23, issue #335), and a project may leave a role
unmapped. Where that mapping is kept is not decided. A project's roadmap may carry a `## Direction`
section in the workspace's format, by its own choice: `onboard-project` offers one to a project whose
settings say `instructions=tracked`, and never requires it (#332 D3). The sit-rep reads the session's
own root (#418): in a project session it checks that project's Direction section (`docs/roadmap.md`,
else `ROADMAP.md`), lists its worktrees and pull requests and reports the problems its own files allow,
and in the workspace it reports the workspace, with project work only where a workspace Direction line
names it; `sitrep_root.sh` decides the root once. A view that combines the workspace and every project
is not part of it (owner, 2026-11-09); it belongs with a later skill for the personal root.

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
| Commits carry an agent or owner identity | Leave a trail; start limits strict | `hook` | `.agent/hooks/check-commit-identity.py` fails a commit whose author or committer email, as git will record it (`git var`), is neither the checkout's configured git email (`<local>@<domain>` from the config files, `git -c` ignored, any `+suffix` removed) nor `<local>+<anything>@<domain>`, and fails when that git email is unset; local only |
| Hooks are not skipped (no `--no-verify`) | Enforce what matters, as simply as possible | `CI` | The Lint job runs `make lint`, which runs every hook on all files; the four local-state hooks above are skipped there. A local `--no-verify` is not detected |
| Issue number matches the branch | Leave a trail; start limits strict | `nothing` | `.agent/hooks/verify-issue-branch.py` prints the issue's title and state and always returns 0 (its docstring: "Informational only") |
| A progress entry has the ADR-0013 shape | Leave a trail; start limits strict | `script` | `_progress_entry.sh` validates the heading, the entry type, fences and title in every writer (`progress_append.sh`, `review_progress.sh persist`); editing the file by hand is not checked |
| Merge only after a current review and a decision summary | Leave a trail; start limits strict | `script` | The gate in `merge_pr.sh` refuses by default on workspace PRs and is report-only for project PRs. It is local only: the script's own comment says a Merge click on GitHub bypasses it, and the server-side complement is not built |
| The owner decides every merge; the loop pauses at a merge checkpoint and no phase merges on its own judgment | Leave a trail; start limits strict | `review only` | `run-issue/SKILL.md` step 11 stops the loop at the `merge` checkpoint and passes the gate-relaxing flags only on the owner's answer; `merge_pr.sh` does not check who runs it (its gate checks the review and the decision summary, not the person), so a reviewer checks the host against the skill |
| The host answers a checkpoint only with the answers the `/orchestrator` table allows it, and never does a phase's work | Ask about what matters, and show how much | `review only` | Each `## Checkpoint` entry records `**Decided-by**: owner` or `host (<reason>)`; `dispatch_phase.sh` routes on `**After**` and `**Decision**` only and does not read who decided, so a reviewer checks host answers against the table |
| Every project type implements every adapter verb | Put each thing at the level it applies to | `hook` | `validate_adapter.sh` (`validate-adapter-contract`), also its own CI job |
| Design anchors resolve | Keep one current design | `hook` | `check_design_anchors.sh` (`check-design-anchors`); `make lint` and CI run it again |
| `AGENTS.md` stays at most 200 lines | Only what's needed | `hook` | `check_agents_md_budget.sh` (`agents-md-line-budget`), run only when `AGENTS.md`, the script or `.pre-commit-config.yaml` is staged; `make lint` and CI run it again |
| A change that alters how the parts fit updates this file | Keep one current design | `review only` | Review guide rows "Keep one current design" and ADR-0017 |
| Nothing committed to the workspace names a particular project, except history (ADRs, roadmap, work plans), comments saying where code or a bug came from, test fixtures and `tools/ros-manifest/` prose; examples and guidance use synthetic names | Put each thing at the level it applies to | `review only` | Review guide row "Put each thing at the level it applies to" (search the diff for project names; a real project name only for a public repository). The exceptions are the owner decision of 2026-10-09 (#335), with work plans added on 2026-10-12; from 2026-10-12 a new mention names only a public repository, and existing mentions are not scrubbed |
| Work happens in a worktree, not the main tree | ADR-0002 | `review only` | The main tree stays on `main`, so `no-commit-to-branch` stops the usual slip; nothing stops a branch switch there. The guide's ADR-0002 row says the worktree scripts and hooks enforce it; the hooks do not |
| Ask first: instruction files, CI or branch protection, the project remote URL | Leave a trail; start limits strict | `review only` | Review guide row "Name the rule before bending it" (an Ask-First rule treated as bendable). No code-owner file or hook watches those paths |
| A pull request or an issue carries the AI signature | Leave a trail; start limits strict | `script` | `gh_create_pr.sh` and `gh_create_issue.sh` append it to a given body and exit 2 when `AGENT_NAME` and `AGENT_MODEL` are unset (`--no-signature` skips it); a body gh would write itself (`--fill` and its variants or `--template` with no body flag, `--recover` with or without one) also exits 2 without `--no-signature`. An issue made with `gh issue create` directly is not checked. Comments are signed by habit only: no wrapper signs them |
| No secrets in a commit | Enforce what matters, as simply as possible | `nothing` | No hook scans for secrets; `check-added-large-files` is the only content check on file size |

## Sessions and roots

**Now**

Status: `decided`

A session runs in one of two places, the workspace checkout or a project's own root; the user tier in
`~/.claude` is the layer injected into those sessions, not a place a session runs (ADR-0016 decisions 1
and 3). The mechanisms below are built and tested
hermetically. [ADR-0016](decisions/0016-session-roots-and-the-user-tier.md) is Accepted (2026-11-09,
#423): a `/run-issue` run started from a project root passed through the merge checkpoint, the
acceptance test named in #317. [ADR-0018](decisions/0018-plugin-based-skill-delivery.md), which
supersedes ADR-0016 decision 3 for skills, is Accepted too (2026-11-09, #425): its promotion condition
was the same run. [ADR-0020](decisions/0020-plugin-enabled-once-at-user-scope.md) (2026-11-12, #446)
supersedes ADR-0018 decisions 3 and 4: the plugin is enabled once, at user scope.
[Open questions](#open-questions) OQ-2 records where that run was tracked and who ran it.
[ADR-0021](decisions/0021-a-project-session-may-register-its-own-folder.md) (2026-11-13, #466)
supersedes ADR-0016 decision 5: a session may register the folder it was started in.

- The workspace and each project are separate session roots. A session is in exactly one, found from
  its cwd by the longest-prefix match against the registry; registered project roots are checked before
  the workspace checkout, so a project registered inside the workspace tree is still a project
  (`registry_resolve_from_dir` and `registry_derive_type_from_dir` in `_project_registry.sh`;
  ADR-0016 decision 1).
- A session works only under its root, the directory it was launched in (owner, 2026-10-13). Work
  that belongs to another root becomes an issue there, or an inbox line, and a session started in that
  root picks it up; reading across roots is allowed. A multi-repo project's root is its registered
  hosting directory, never a package repository nested in it. `session_root.sh` prints a directory's
  root and refuses an issue of another root, naming the directory to start in; `run-issue` and
  `/start-task` run it before anything is created. Worktrees live under their root (a root's
  `worktrees=` directory counts as its own, for the `SessionStart` hook too), so the directory a run
  starts from names its root, and nothing records where a session started. `session_root.sh` refuses
  two directories under a root, each for its own reason: a package repository nested in it (a
  multi-repo project's root is its registered hosting directory, above), and a subdirectory of a root
  in no git repository (a session started outside git reads the settings of its own directory, so the
  root's `.claude/settings.json` and `.claude/settings.local.json`, its hooks and permission rules,
  never reach a session in a subdirectory of the root). Neither refusal is about the plugin, which
  reaches both (ADR-0018 decision 6, ADR-0020).
- Two exceptions to working only under the root, both per-machine, gitignored workspace configuration
  the project's onboarding owns, not tracked changes to the workspace. A project session writes its own
  project's settings file `.agent/projects.d/<name>` in the workspace checkout, through
  `project_setting.sh set`, which calls `registry_require_root` and, from a project root, refuses any
  other project's file (#332). And a session started in a folder that is not registered may register
  that folder, its registry line and settings file, through `register_session_root.sh` (#466,
  ADR-0021): no path argument, it refuses a folder inside or over a registered root or the workspace,
  and it is not promoted to the user tier, so each call asks for permission (registration is what lets
  the promoted scripts, `build.sh` among them, run in a folder, so a session in an untrusted folder
  must not register it without the owner seeing the command). Nothing else a project session does
  leaves its root.
- When `--type` is omitted, the worktree scripts and `dispatch_phase.sh` take the type and project
  from the cwd the same way (`registry_derive_type_from_dir`; ADR-0016, "Multi-project machines need
  disambiguation").
- The user tier is installed from a workspace checkout by `.agent/scripts/user_tier_install.sh`: a
  `SessionStart` hook, a `PreToolUse` hook, permission rules for the promoted scripts, and the plugin
  enabled at user scope (below). It recognises
  its own hook commands by their path (the `claude plugin` commands drop any marker in the file), so
  install is repeatable, `--check` tells another checkout's hooks from the user's own, and
  `--uninstall` removes only its own commands (`user_tier_install.sh` header).
- Registration is done from the workspace, or from a session in the folder itself (ADR-0021,
  superseding ADR-0016 decision 5): `register_project.sh`, run from the workspace's main checkout,
  registers a project and, when the user tier is installed from that checkout, checks it reaches the new root
  (`registration_verify.sh --user-tier`, read-only); nothing is enabled per root. See
  [Registry and adapters](#registry-and-adapters).
- Onboarding is the project side (#332 D1): `/agent-workspace:onboard-project`, in a session started at
  the project root, finds the project through `session_root.sh` (a workspace session is sent to the
  project's root; in a folder that is not registered it shows `register_session_root.sh --dry-run`, asks
  one yes in text (the real call's permission prompt is not guaranteed, so it is a second gate), then
  registers the folder and carries on, with the build and test not run; a folder in no git repository
  is refused by registration's gate, a known gap, although its dry run looks clean), shows the recorded
  choices, asks only the footprint
  questions not yet answered (`instructions`, and the records settings, whose default is provisional and
  of which only (project, project) is stored until #393), runs `project_integration_audit.sh` (read-only;
  six categories of how the project and the workspace fit together), and makes offers only when
  `instructions=tracked`. A project need carry nothing (D3). Every finding or accepted offer is answered
  fix now, open issue, queue in the roadmap (an `## Onboarding` section of the project's roadmap) or
  skip, and every write waits for a yes; a re-run re-asks nothing unless told (D5). The fix-now batch
  is one pull request from a project worktree: on the onboarding issue's `feature/issue-<N>`, or, for a
  project that uses no issues, on a `skill/onboard-project-<timestamp>` branch (`onboard-project` is on
  `worktree_create.sh`'s skill allowlist; its project skill worktree is of the root's own repository). At a
  parent root the run reads, reports and fixes one repository, the chosen instance's: the batch can only
  write there, so the parent root's own files are not audited. The audit,
  `registration_verify.sh` and `project_setting.sh` are promoted to the user tier for it.
- Onboarding ends by offering `/agent-workspace:audit-project` (#332 D4), which also runs any time in a
  session at the project root and holds the hygiene checklist: pre-commit, CI, branch protection,
  Copilot review, component labels, git-bug bridge and license headers. The items a fact makes moot are
  reported skipped with the reason, never dropped; the facts are read by `project_integration_audit.sh
  --facts` (`github`, `issues`, `prs`, `windows`, `multi_component`, from the remote, `gh` and `uname`),
  which onboarding also reads to know whether the project uses issues. It is report-only and runs the
  integration audit as well; an optional final step answers findings the four ways onboarding does, and
  every write waits for a yes.
- Skills reach project sessions through the `agent-workspace` Claude Code plugin, whose marketplace is
  the workspace checkout (`.claude-plugin/`). It ships every skill that declares
  `session_scope: project` or `session_scope: both` (`make generate-user-tier-skills`, checked by
  `test_plugin_manifest.sh`). The installer enables it once, at user scope (`claude plugin ... --scope
  user`, recorded in `~/.claude/settings.json` and the CLI's `~/.claude/plugins/`), and writes nothing
  into a project checkout; it migrates the per-root entries the earlier installer left (`--scope
  local`, run only from a root that is its own git toplevel, not a linked worktree, or in no git
  repository; anywhere else it names the removal by hand). A project that does not want the plugin
  sets it to false in its own settings. The workspace checkout's tracked `.claude/settings.json` sets
  it to false, so a session at the checkout's root or in a worktree of it lists each shipped skill
  once, bare. A session started in
  a subdirectory of the checkout (a plain subdirectory, or a registered root inside its tree with no
  `.git` of its own) lists each shipped skill under both names, bare and `/agent-workspace:<skill>`;
  both run the same skill, and the owner accepted this on 2026-11-12 (live suite, U2 and U4). Anywhere
  else a session names the skills `/agent-workspace:<skill>`; `skill_prefix.sh` says which for a
  directory (bare in the workspace's repository, the prefix elsewhere), and the `SessionStart` header
  states it. The old `~/.claude/skills/` symlinks are removed by install and reported by `--check`
  (ADR-0018, ADR-0020).
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
- A workspace with no registered project and no `project/` is a complete workspace (#295): `make
  validate`, `make setup` (no prompt), `make dashboard` and `make sync` succeed and point at
  `register_project.sh`, and the repo-safety check of `gh_create_pr.sh` and `gh_create_issue.sh`
  accepts every registered root's repository (`registry_repo_slugs` in `_project_registry.sh`), so a
  project session needs no `project/` symlink (`test_fresh_clone_no_project.sh`).

**Target (decided, not built)**

Status: `decided, not built`

- Discovery becomes registry-only: PR 4 of #265 removes the legacy `project/` step. The dispatcher
  still has it as step 3 of its resolution order (`adapter` header; ADR-0016, "ADR-0011's discovery
  order will be superseded").
- The workspace tree hosts no project, and the workspace writes nothing into a project checkout beyond
  `.git/info/exclude` and an untracked `COLCON_IGNORE` (ADR-0016 decision 2). The registry's default
  hosting directory is still `projects/<name>` under the workspace (`_project_registry.sh` header);
  `register_project.sh` always writes an absolute path, so nothing it registers relies on it.
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
  the header of `_project_registry.sh` and in `.agent/projects.local.example`. Beside it,
  `.agent/settings.local` (per machine, gitignored, read and never sourced by `_settings.sh`) names
  the machine's inbox and sit-rep run record; a script run from a worktree falls back to the main
  checkout's copy. The registry has no such fallback, except in two scripts that read the main
  checkout's registry the same way: `capture.sh`, so a thought captured from a worktree copy is tagged
  with its project, and `project_setting.sh`, which reads the main checkout's settings files too and
  refuses to write them from a worktree (#332).
- Registration is `register_project.sh <path>`, run from the main checkout (#332). It writes the
  registry line, always with an absolute path, and the settings file (commands from `--set`, else the
  legacy `.sh`, else `--detect`, which proposes only a single correct command), then runs the
  read-only gate `registration_verify.sh` (each command the type requires is the project's own or
  `none`; a shared-config fallback or a missing test command is refused), the type's build and test,
  and only then, when the user tier is installed from this checkout, the read-only
  `registration_verify.sh --user-tier`; the user-tier installer runs only with `--install-user-tier`,
  and nothing is enabled per root (the plugin is at user scope, ADR-0020). A failure removes the line
  and the file; a settings file changed during the run is kept, and a cleanup step that fails is
  reported, never a clean result; a hosting directory `setup` created is kept and reported. A line
  written by hand is adopted by the same command, kept as it is, and reported `NOT READY` rather
  than removed when a check fails. `--remove` refuses live worktrees, removes the line and the settings
  file, and leaves the project root, its records, its memory and the user tier alone. The script header
  holds the order and the output lines. From a session in a folder that is not registered,
  `register_session_root.sh` registers that folder alone (#466, ADR-0021): it takes no path and only
  `--dry-run` and `--set build=`/`test=`, refuses a folder already registered (before handing over,
  since `register_project.sh` would adopt it and write the `--set` keys), inside or over a registered root
  or the workspace, not its repository's top, a linked worktree or an invalid or registered name, then
  runs `register_project.sh <folder> --skip-run`, never `--install-user-tier`. Registration needs a git
  repository today (`adapter validate`), although any registered folder is a project (owner,
  2026-11-12): a folder in no git repository is refused and rolled back, a named gap.
- A registered project may have a settings file, `.agent/projects.d/<name>` (per machine, gitignored,
  read and never sourced; #332): its own `build`, `test` and `install` commands, `bootstrap_url`,
  `source`, `source_ref` and `source_path` (where its source description lives, #436), the records
  settings `location`, `location_path` and `tracking` (see [Worktrees](#worktrees), Target),
  and `instructions`. A command is split into words and run without a shell, or is `none` for "this
  project has none"; anything that needs a shell is a script the key points at. A command set in the
  file runs without sourcing the legacy or shared config below, so nothing they export (an SDK path,
  `PATH`) reaches it: environment setup belongs in the script the key points at. The grammar and keys
  are in the header of `_project_registry.sh`, `project_setting.sh` reads and writes the file, and a
  malformed file stops every adapter verb and fails `make validate`. The writer locks a
  `.lock.<basename>` file beside the file, or beside the target of a linked one, and never removes it,
  so settings kept in a git checkout through a link leave that untracked file there. A key the
  project's type never reads is refused the same way: each type lists such keys in
  `.agent/project_types/<type>/unused_settings` (`ros2_colcon`: `build` and `test`, which colcon
  owns; `single_project`: `bootstrap_url`, `source`, `source_ref` and `source_path`), so no setting
  is stored and silently ignored. Per
  setting, the adapters read the file; for a setting it leaves unset, the legacy
  `projects.d/<name>.sh` (a sourced shell file, which also keeps variables such as `ROS_ROOT_DIR`)
  when it exists, otherwise the shared `.agent/project_config.sh`. An existing legacy file is the
  whole legacy layer, as before #332: the shared file is not consulted for a variable it leaves
  unset. The adapters say on stderr when a registered project falls through to the shared file.
- Behaviour that differs per project shape sits behind a 13-verb adapter contract, one `adapter.sh` per
  type in `.agent/project_types/<type>/` (ADR-0011, extended by ADR-0012 from 10 verbs to 12 and by
  ADR-0019 to 13). The 13th, `repo_pin <repo> [--layer <l>]`, prints the ref the project pins a
  repository at and its kind (`branch`, `tag`, `commit` or `unknown`, judged by origin, from local refs
  and marked unverified when origin cannot be asked): `ros2_colcon` reads the `.repos` files, and
  `single_project` answers its default branch from `origin/HEAD` (#429).
  `REQUIRED_VERBS` in `.agent/scripts/adapter` is the one list, and `validate_adapter.sh` checks that
  every type implements every verb, in pre-commit and in CI. Beside the contract, each type has a
  `registration.conf` (#332): the commands a project of the type must have of its own, whether
  registration runs `setup` for a missing hosting directory, and the verbs it runs, so
  `register_project.sh` names no type; `validate_adapter.sh` checks it too.
- Workflow scripts call adapter verbs and do not branch on the project type: a grep of `.agent/scripts/`
  for the two type names finds only help text and docstrings, and the `single_project` default in
  `_resolve_project_type` (`adapter:80`) (2026-10-09).
- Two types exist. `single_project` is one repository at the hosting directory. `ros2_colcon` is ordered
  colcon layers driven by a manifest directory, `configs/manifest` or the generated
  `configs/manifest-resolved`, and its `adapter.sh` header holds the layers, the bootstrap URL order
  and the distro rule.
- `ros2_colcon` has two routes to that directory (#436), chosen by one fact, the settings file setting
  `source`. The bootstrap route is the `bootstrap.yaml` flow. On the manifest route the manifest, in the
  new format, is an absolute path read in place or a git repository (an `https://` or `file://` URL with
  no credentials; the fetch allows the https, ssh and file transports only) fetched afresh by each
  `setup` and `sync` into a temporary directory removed afterwards (`source_ref`, `source_path`, default
  `manifest.yaml`), resolved for the
  registry line's `role=` and `distro=` (both required) by the workspace-installed resolver,
  `<main checkout>/.venv/bin/ros-manifest` from `make install-ros-manifest`, called by CLI only, into a
  new generated directory that `configs/manifest-resolved` is relinked to; every verb reads the
  directory the same way on both routes. One source only: `source` beside any other bootstrap source is
  a hard error that names it. Never silently stale: `setup` and `sync` fetch the ref's commit afresh and
  keep no clone (owner, 2026-11-13), and clone every `extends` base afresh (the resolver's clone runs no
  user hook or filter driver and is bounded by `ROS_MANIFEST_GIT_TIMEOUT`); a failed fetch or resolve
  keeps the previous directory. Local manifest work uses the path form. `setup` and
  `sync` fetch and resolve holding a flock on `configs/.lock.source`, never removed, and every verb
  reads one generated directory throughout, never removed while a run reads it (without `flock`, the
  one before the live one is kept instead). `validate` also fails when the directory was resolved from
  another source, ref, role or distro, and names checkouts the manifest no longer lists; the adapter
  removes none.
  Network is needed at `setup` and `sync` (the source, every `extends` host, every package host) and
  for the resolver's install. A package worktree's `env.sh` is not rewritten when `sync` changes the
  layers; `sync` says to recreate it. The adapter edits no ignore file. Registration works for a path
  that does not exist yet (`register_project.sh <path> ros2_colcon --role --distro --set source=...`
  runs `setup`); `source` does not choose the type, and onboarding an empty session folder from a
  source is #473's.
- The active project is resolved in this order: `--project`, then the cwd inside a registered hosting
  directory (longest match), then the legacy `project/` checkout (`adapter` header, "Multi-tenant
  resolution").
- The project's own `remote.origin.url` is its URL, and the project stays usable without the
  workspace. ADR-0011 supersedes ADR-0003 and carries that project-agnostic doctrine forward.
- GitHub is not a project dependency; the workspace uses it for now (owner, 2026-10-05).

**Inventory: where the workspace path differs from the registered-project path**

Owner decision 2026-10-09 (C2). It is here so the open question of making the workspace a registered
project (#295) is decided by reading these two tables after the ADR-0016 acceptance run of 2026-11-09, not by a hunch.
The tables are cut back once #295 is decided. Line numbers are as of this commit; they are a dated
probe, not a description to keep current.

*Table 1: places where the scripts take a different path for the workspace than for a registered project.*

| Script | What differs | Lines |
|---|---|---|
| `worktree_create.sh` | `--type` derived from the cwd when omitted; `--layer` and `--package-repos` project only; project fetches its PR slug from the project's `origin`; the repo manifest comes from the adapter's `worktree_repos` for a project only, and the workspace case never calls the adapter; worktree base is `wt_project_base` (the registry entry's own root) or the legacy glob versus `wt_workspace_base` (`worktrees/workspace`); the draft PR targets `$PROJECT_GH_SLUG` versus the workspace remote | 301-313, 351-357, 511-516, 600-613, 635-647, 1109-1115 |
| `worktree_enter.sh`, `worktree_remove.sh` | The same `--type` derivation and check; `--project` is valid only with `--type project` | enter 143-174, remove 130-157 |
| `merge_pr.sh` | A project PR needs a resolved project root with an `origin` remote; PR-owner auto-detect queries both remotes; the Step 1 roadmap worktree lookup and the gate's timeline lookup both use `PJ_ROOT_EFFECTIVE` (`PJ_REPO_ROOT`, else the legacy `project/`), and both main-tree guards include it; the gate enforces on workspace PRs only and is report-only for project PRs "until #265 settles project timelines"; cleanup deletes the branch in `PJ_REPO_ROOT` and pulls the project too | 243-287, 391-436, 608, 741, 875 and 1182, 1472 and 1485, 2274-2294 |
| `dispatch_phase.sh` | `resolve_worktree`: workspace uses `wt_workspace_base`; project uses `derive_project_name` (from `--project` or the cwd) and then `wt_project_base`; `--type` is validated in every mode (`where` and, since issue 429, `base` too) | 222, 283-332, 507, 649, 737, 769, 908 |
| `gh_create_pr.sh` | The repo-safety check accepts the workspace slug, the slug of the legacy `project/` checkout and, since #295, every registered root's slug (`registry_repo_slugs`); the `project/` branch goes with the legacy fallbacks (#265) | 131-184 |
| `worktree_list.sh` | A workspace worktree is recognised by the path `*/worktrees/workspace/*` or `*/.workspace-worktrees/*` | 149-150 |
| `_project_registry.sh` | `registry_derive_type_from_dir`: `project <name>` when the cwd is under a registered root, else `workspace` when inside the workspace checkout | 485-500 |
| `run-issue` skill and `agent start-task` | `--type` defaults to `workspace` and is passed on to `dispatch_phase.sh`, `worktree_create.sh`, `gh_create_pr.sh` targeting and `merge_pr.sh --type` | `SKILL.md` 47-54; `agent` 63, 90 |

Checked and found with no workspace-or-project branch: `review_progress.sh` (it finds the records from
the cwd's git top level, through the records gate, lines 138-140 and 340-350), `progress_append.sh` (lines 78,
93-94 and 107-108),
`_resolve_work_plans_dir.sh` and `_bookkeeping.sh`.

*Table 2: the 13 adapter verbs, if the workspace were a registered project.* "Real" means the workspace
needs logic of its own; "thin wrapper" means a script or target that already exists does the work;
"no-op" means the `adapter` header allows doing nothing.

| Verb | For the workspace | Based on |
|---|---|---|
| `setup` | thin wrapper | The `git-bug` and `ros-manifest` stamps (`Makefile` line 100; the header lists `setup-dev`, `ros-manifest` and `git-bug`; `make setup` configures no project since #295); `single_project/setup.sh` clones a project, which the workspace does not need |
| `sync` | thin wrapper | `single_project/sync.py` already syncs the workspace repo with the project |
| `validate` | thin wrapper, with care | `validate_workspace.py` checks the whole workspace and calls this verb for each registry entry, so the workspace's own implementation must not call back into it |
| `build` | no-op | Nothing is built; `make build` runs the project's `BUILD_CMD` |
| `test` | thin wrapper | `.agent/scripts/tests/run_script_tests.sh`, the `validate-script-tests` hook's entry (`.pre-commit-config.yaml`) |
| `install` | thin wrapper | `user_tier_install.sh` (`make user-tier-install`, `Makefile` line 173) |
| `env` | no-op | The `adapter` header: a type with no environment to expose emits nothing |
| `project_root` | real, trivial | Prints the workspace root |
| `repos` | real, trivial | One `name:path` line |
| `scope_for_pr` | real, small | Origin URL to `owner/repo`; `single_project`'s verb already does this generically |
| `worktree_repos` | real, trivial | One line `<root>`, `.`, `feature/issue-<N>`; `worktree_create.sh` does not call it for the workspace today |
| `worktree_env` | no-op | No per-worktree environment |
| `repo_pin` | real, small | Its default branch; `single_project`'s verb already reads it from `origin/HEAD` generically (#429, 2026-11-12) |

Tally: 3 no-op, 5 thin wrapper, 5 real. No conclusion is drawn from it here; that is the #295 decision.

**Target**

Status: `proposed`

A project is added in two steps (#332 D1), and both are built: registration, from the workspace
(`register_project.sh`) or from a session in the folder itself (`register_session_root.sh`, ADR-0021;
see Now), and onboarding at the project root (`onboard-project`, see
[Sessions and roots](#sessions-and-roots)). Registering and unregistering on one machine are defined
(Now). Proposed: one project on two machines, not defined yet. Mixed-flavour projects, a repository carrying tools of another flavour, are supported
(#310). [Open questions](#open-questions) C4 holds what is unsettled. The legacy `project/` shape is dropped with the registry-only change
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
  worktrees of the current repository and a project is a separate repository (`.agent/WORKTREE_GUIDE.md`,
  "Worktree Entry").
- Agents work concurrently in separate worktrees. Work in progress is made visible by a draft pull
  request, which `worktree_create.sh --plan-file` opens, and an agent checks for one before starting
  (`WORKFORCE_PROTOCOL.md` sections 1 to 3). `make lock` is an advisory note shown by the dashboard and
  stops nothing (`lock.sh` header).
- **Records.** An issue's work plan and progress timeline are committed in the repository that owns the
  issue (the workspace repository for a workspace issue, the project's repository for a project issue),
  on the issue's feature branch, under `.agent/work-plans/issue-N/` (owner decision 2026-10-09, C3).
  An issue in a package repository (`--issue owner/repo#N`, worked in a package worktree, a folder of
  several repositories) has its timeline in the checkout of the repository that owns it inside that
  worktree: the `.worktree-repos` entry on `feature/issue-N`, under the default records setting (issue
  429). `dispatch_phase.sh` decides that directory in one place (`resolve_issue_dir`, with
  `issue_checkout_of` from `_resolve_work_plans_dir.sh`): the handoff names it as `worktree=`, and
  `run-issue` step 1 moves the host there with `dispatch_phase.sh where`, which with the handoff also
  refuses when `gh` there resolves another repository. Inside a package worktree every records read
  and write refuses every other checkout, a sibling with the same issue number and the worktree's top
  folder alike. The check sits in one place, the records gate (`records_path` and `records_dir` in
  `_resolve_work_plans_dir.sh`), and every script path to a timeline goes through it:
  `resolve_work_plans_dir`, `progress_append.sh`, each `review_progress.sh` subcommand that takes or
  builds a records path (`round`, `persist`, `sources`, `findings`, `check`, `plan-sha`),
  `dispatch_phase.sh` (`resolve_issue_dir` and `next --progress`) and `merge_pr.sh`'s gate lookup (an
  owning package pull request's read of the committed copy passes the gate's checkout rule,
  `issue_checkout_guard`, on the checkout itself). It
  does not cover a file an agent opens directly, the sit-rep's survey (it reads each listed checkout's
  `progress.md` with `progress_read.py` directly), or `worktree_create.sh --workflow`'s scaffold (#393).
  A write that changes a timeline (an entry, its commit, a ticked box) is refused unless the file it
  writes, every symlink resolved, sits at the place its path names in the issue's own checkout,
  wherever the command runs; reads are not (issue 437): the gate's `--write`
  rule, which `progress_append.sh`, `review_progress.sh persist` and `check` state, refuses a main
  checkout on its default branch and another issue's worktree (header of `_resolve_work_plans_dir.sh`).
  Workspace worktrees and single-repository project worktrees write no manifest, so the package rule
  changes nothing for them. `merge_pr.sh`'s gate reads the owning repository's pull request
  (`feature/issue-N`) in that checkout and commits and pushes its record there: the matched manifest
  entry's path travels with the match (`PKG_OWN_REL`, lines 535-558) and becomes the gate's worktree
  (lines 719-743). The gate reads that checkout's timeline only when the checkout is its repository's
  top folder, has the pull request's branch checked out and its HEAD equals origin's copy of it (a
  bounded fetch); otherwise it gives the reason and the record goes on the pull request (lines
  744-811). It then reads the committed `progress.md` at that commit, never the working copy, so
  nothing uncommitted in the checkout changes what it reads; none committed means no timeline (lines
  812-864). The record is committed there only when the working copy's `progress.md` is the committed
  one (`_gate_rec_not_committed`), else it goes on the pull request. A sibling
  repository's pull request reads no timeline there; its reason names the owning checkout and its
  record goes on its own pull request (lines 896-903 and 1305-1306). Package pull requests stay
  report-only. `progress_append.sh` lines 107-108 write
  `<repo-root>/.agent/work-plans/issue-<N>/progress.md`, and ADR-0013 names that path. For a project
  pull request, `merge_pr.sh` looks up the gate's timeline in the project's own repository: its
  registry-aware root (`PJ_ROOT_EFFECTIVE`, line 287: the resolved project root, else the legacy
  `project/` checkout) is what both the Step 1 roadmap worktree lookup and the gate use (lines 608 and
  741), and the main-tree guards include it, so the project's main checkout never takes the record
  commit (lines 875 and 1182). The gate is still report-only for project pull requests (lines 1472 and
  1485).
- **Base branch** (issue 429). The pull request of a package issue's owning repository targets the
  branch the project pins that repository at (`adapter repo_pin`, ADR-0019), never the forge's default
  branch; the owner's `--base <branch>` overrides the pin. `dispatch_phase.sh base` and
  `worktree_create.sh` decide it (`pr_base_for` in `_pr_base.sh`) and refuse a pin that is a tag, a
  commit or unknown (saying whether origin answered), or one the adapter cannot read; an issue whose
  worktree is no package worktree has none. Creating a package worktree's new owning branch always
  resolves a base, so it is never started from origin's default branch by omission (`--branch` is
  refused for a package worktree, since the adapter names its branches); with `--parent-issue` the pin is
  not read, the branch starts from the parent's branch as a sub-issue's always has, and `base=` records
  the parent's branch when it is found, the branch a sub-issue's draft pull request targets. The owning
  repository's new `feature/issue-N` starts from origin's copy of that branch, fetched at creation,
  with no upstream (the strict start path in `_wt_add_repo`): origin lacking it or not answering stops
  creation, also with `--allow-unverified-branch`, and the local copy is never used; sibling
  repositories start from their default branch as before. The `.worktree-repos` header records it as
  `base=` (every header field is read unanchored, so a reader skips the fields it does not know). For a
  branch this workspace did not start (an owning branch that already existed at creation, or a worktree
  made before the field, on resume) where it started cannot be known, so the pin is never recorded for
  it: the owner names the base with `--base`, and it is recorded after two checks
  (`wt_check_named_base`): origin has the branch (bounded), and the issue branch shares history with
  it. Without `--base`, or when a check fails or origin does not answer, nothing is recorded and the run
  refuses, saying which. The one exception is creation with `--parent-issue` (where `--base` is refused):
  an owning branch that already exists is accepted, no `base=` is recorded and a note says so, and
  `dispatch_phase.sh base --base <branch>` records one later. `run-issue` passes it to
  `gh_create_pr.sh --base`, diffs the pre-push review against `origin/<base>` (the `review-code`
  handoff from `dispatch_phase.sh`) and checks and merges it before that review
  (`check_branch_updates.sh --base`, `run-issue` step 8); `merge_pr.sh` reports an owning pull request whose base differs from it
  (report-only, like every package reason) and, at cleanup, fast-forwards the owning repository's own
  checkout from origin's base by name (never the branch's configured upstream) only when it is clean
  and on that base, fetching only otherwise.

**Target**

Status: `proposed`

Proposed: a project carries its records by choice, through two settings in its settings file
`.agent/projects.d/<name>` (not its registry entry, #332). Built in #332: the settings, their validation,
and the refusal to store any combination but the default, so until the records lookup (#393) lands only
(project, project) is honoured and `project_setting.sh check` flags a hand-written other one. Built by
#393: mechanisms 1 to 3 below, and honouring the other combinations.

- `location`: `project`, in the project repository, or `outside`, at `location_path`; when that is
  omitted, a provisional default from `project_records_default` in `_project_registry.sh` (a sibling
  `<clone>-records` of the clone, or a hosting directory holding both clones), chosen when #393 is built
  (owner, 2026-10-13: where the defaults should be is not settled).
- `tracking`: `untracked`; `project`, tracked in the project repository (the default when the location
  is in the project repository); or `repo`, tracked in a separate records repository the user names. A
  records repository must not be a workspace (owner, 2026-10-13): a fork of the workspace would carry
  other projects' records, and a pull request sent back would bring them past the merge gate's
  bookkeeping exemption. `project_records_check` refuses one by its remote URL, by a local-path or
  `file://` remote at the workspace checkout or one of its worktrees, and by its contents (the
  workspace's marker files, `.claude-plugin/plugin.json` naming the plugin and
  `.agent/user_tier_scripts.txt`), so a clone of a fork under any owner is caught offline. Untracked
  records under the workspace's ignored scratchpad are allowed.

| location | tracking | What it is |
|---|---|---|
| in the project repository | tracked in the project repository | Today. The records travel with the feature branch |
| outside | untracked | No footprint in the project; one machine |
| outside | tracked in a named repository | No footprint in the project; portable |
| in the project repository | untracked, through the clone's `.git/info/exclude` | Behaves like outside and untracked |

The settings validator refuses every other combination: `outside` with `tracking=project`, `project`
with `tracking=repo`, `location_path` without `outside`, and `outside` without `tracking`. Every default
is provisional and comes from `project_records_default`: (project, project) for a project whose file
says nothing, which is what every reader does today, and the zero-footprint proposal onboarding makes.
Three mechanisms would do it, each built by #393:

1. One lookup, "where are the records for this project and issue", fed by the settings file and used
   by every reader and writer. Today each one writes the path out itself: `dispatch_phase.sh` (lines
   555, 601, 603, 665, 940: the round count, the exit contract, `--check-exit` and `next`, which is
   what a resumed session reads), `merge_pr.sh` (719-864, 1145-1320: the gate's lookup and its `Merge`
   entry), `review_progress.sh` (140, 306, 350) and `progress_append.sh` (107). `_resolve_work_plans_dir.sh` is
   the nearest lookup that exists, and `cross_model_review.sh --work-plans-dir` already feeds it an
   override. The seven skills that cite the path follow it.
2. The merge gate's "same reviewed state" rule (`_bookkeeping.sh`, shared with `review_progress.sh
   sources`) reads the record from where it lives and checks the project commit the entry names, so the
   walk changes repository.
3. Untracked records are per machine and per clone. A second machine or a fresh clone starts with no
   timeline, and losing the directory loses the history. That is the cost of the combination.

One rule: when records exist in two places, the setting names the source of truth.

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
| `review-issue` | An `## Issue Review` entry and a comment on the issue | Open `### Actions` boxes go to an `issue-actions` checkpoint; with none open the loop moves on to `plan-task` |
| `plan-task` | `plan.md`, committed on the feature branch, and a `## Plan Authored` entry | `review-plan` runs next, no decision |
| `review-plan` | A `## Plan Review` entry | The `plan` checkpoint follows every plan review, whatever its verdict: proceed, revise or stop |
| `implement` | Commits on the branch and an `## Implementation` entry; it never pushes | `review-code` on the branch runs next, no decision |
| `review-code` | `## Local Review (Pre-Push)` before the push, `## Local Review` after it | Pre-push: an approved verdict goes to the `publish` checkpoint; otherwise `address-findings` runs, and after 3 rounds (`MAX_ROUNDS`) of the current pull request without approval the `rounds` checkpoint is raised. Post-push: approved goes on to `triage-reviews`, otherwise `address-findings` |
| `publish` | The push and the pull request, whose body carries a `## Decision summary` heading | `publish` has just been answered; the host does the push (`run-issue/SKILL.md` step 7) |
| `triage-reviews` | An `## Integrated Review` entry: every review source combined into one list of findings with a verdict on each | Open findings go to the `findings` checkpoint, where merging past them is the owner's answer only; with none open, the `merge` checkpoint |
| `merge` | The merge by `merge_pr.sh`, its worktree removal and branch cleanup | The owner decides at the `merge` checkpoint. The gate in `merge_pr.sh` refuses a gap on a workspace PR; a merge that does not end merged, after the run recorded a merge entry, goes to `merge-refused`. A merge on an issue that stays open was an earlier part: with no pull request open, the `plan` checkpoint plans or implements the next one |

- **One entry per dispatched phase, in `progress.md`.** `.agent/work-plans/issue-<N>/progress.md` is the
  only place loop state lives: not the conversation, not a lock file. `publish` writes no entry, and
  `merge` writes one only when the gate finds a gap and does not refuse it (a relaxing flag, or a project
  pull request); a gate that passes records nothing (`merge_pr.sh`, Step 1.5; `run-issue/SKILL.md` step
  11). When no worktree on the pull request's branch can commit and push that entry (none open, a
  sibling repository's pull request in a package worktree, the main tree, an owning checkout that is not
  its repository's top folder, not on that branch or not equal to origin's copy of it (behind, ahead
  or diverged), or whose working-copy `progress.md` is not the committed one, a `progress.md` that
  is a symlink, no agent identity, the commit refused, the push refused, or timed out with origin's
  branch not shown to contain it), it is posted as a
  comment on the pull request instead (`_gate_record` in `merge_pr.sh`). The directory sits in the
  repository that owns the issue, on the issue's feature branch ([Worktrees](#worktrees), Records).
  Entries have a fixed vocabulary and header (`**Status**`, `**When**`, `**By**`, a correlation to an
  issue, a plan or a commit; ADR-0013), are written by `progress_append.sh`, checked by
  `_progress_entry.sh` and read by `progress_read.py`.
- **The next step is routed on the newest entry.** `dispatch_phase.sh next` routes on the newest entry
  and, as its one other input, the pull request state; it reads earlier entries for three things only:
  the count of completed pre-push reviews on the branch of the current pull request (`round_count`),
  whether a failed `Implementation` entry belongs to `address-findings` (`skill_for`), both from where
  the current pull request's work starts, and whether a `merge` answer stands with no new work after it.
  It makes no `gh` call and returns one action from a 28-row table plus row 3a (`dispatch_phase.sh`
  header). A partial or failed newest entry is always a `phase-failed` checkpoint, never a silent retry.
- **An issue can be delivered in several pull requests** (owner decision 2026-11-13, #459). Where a pull
  request starts is one rule in `pr_start.py`: after a `merge` answer, the first `## Plan Authored`, or
  `**Addressed**`-less `## Implementation` on the branch or on another pull request than the merged one
  (a fix on the merged one is none); a non-`merge` answer at `merge`, `findings` or `merge-refused`
  withdraws it, a `## Merge (...)` record does nothing, and a hand merge leaves none until the host
  records a `merge` answer. Rounds (`next`, `review_progress.sh round`) count from the newer of it and a
  `restart` (no boundary); `sources` cuts only at it. A landed merge ends the run; the next part is a
  fresh `/run-issue`, which asks the issue's state first (closed ends it; unreadable stops it), takes a
  merged pull request as an earlier part, and with none open gets the `plan` checkpoint (row 3a), where
  `proceed` is offered only for a plan unchanged since its review that names a part not yet delivered.
  `--pr merged` (row 1, `done`) is given only by hand. The last part's `Closes #N` closes the issue on
  the default branch; elsewhere the owner closes it; the loop never does (`run-issue/SKILL.md` step 13).
- **Each phase but `publish` and `merge` runs in a fresh sub-agent**, except that a repeat of a phase in
  the same drive may resume the earlier agent (`run-issue/SKILL.md` 4a), and a failed phase the owner
  hands to the host runs in the host (`mode=inline`, step 5). The host does the push and the merge
  itself (steps 7 and 11). `dispatch_phase.sh --issue <N> --skill <phase>` prints the
  handoff, and the host pastes it into a new Agent call, in this process only. The sub-agent fetches its
  own inputs with `gh` and never pushes (ADR-0014; `dispatch_phase.sh` exit contract). Reviewers outside
  Claude run in parallel and synchronously through `cross_model_review.sh` (ADR-0015).
- **The host checks the exit, not the sub-agent's word.** `dispatch_phase.sh --check-exit` compares the
  count of entries of the phase's type before and after, and returns `OK`, `PARTIAL`, `FAILED` or
  `MISSING`; anything but `OK` goes to the `phase-failed` checkpoint: retry or stop, or take over, which
  only the owner answers. What it
  checks is that an entry of the right type appeared, its `**Status**` and, for an `## Implementation`
  entry, its `**PR**` or `**Branch**` line. It does not check whether a review's findings are right; the
  merge gate reads the `**Verdict**` and the open boxes a reviewer wrote.
- **Nine checkpoint kinds stop the loop**: `issue-actions`, `plan`, `publish`, `rounds`,
  `findings`, `merge`, `merge-refused`, `phase-failed` and `unexpected`. Each answer is recorded as a
  `## Checkpoint` entry before the loop moves on: `**Decided-by**: owner` for his answer, or
  `**Decided-by**: host (<reason>)` when the host answers within the `/orchestrator` skill's checkpoint
  table, which keeps `merge`, `merge-refused`, `takeover` at `phase-failed` and `merge` at `findings`
  for the owner (owner decision 2026-10-15, #321; `run-issue/SKILL.md`, "No auto-chaining"). The owner
  answers what touches his goals; the host decides the rest and lists each decision for his veto, under
  the standing rules in `.agent/knowledge/host_standing_rules.md`. An answer outside a checkpoint's
  fixed vocabulary routes to `unexpected`. No phase advances on its own judgment, and a host answer
  never lets the host do a phase's work (`review_loop_lifecycle.md`).
- **One driver per issue.** There is no lock; a second driver or a hand edit shows only as an unexpected
  entry at the next check (ADR-0014).

**Target**

Status: `proposed`

- Proposed: the design says, for each claim in the loop, whether code verifies it or the
  agent reports it. Today the shape of an entry, the exit count and status, and the gate's conditions are
  verified in code, and the content of a review is reported.
- Proposed: a new session finds the records for its issue through the one lookup in the
  Target of [Worktrees](#worktrees), so the path is not written out in each reader.
- Proposed: a size bound on records. This issue's own `progress.md` is more than 800
  lines (2026-10-09), and every reader parses the whole file.

**Target (open)**

Status: `open`

What a review finding must contain, and how independent the reviewers are: C5 in
[Open questions](#open-questions).

## Merge gate

**Now**

Status: `decided`

- The owner decides every merge. The loop stops at the `merge` checkpoint, and the flags that relax the
  gate (`--report-only`, `--no-wait`, `--allow-pending-review`) are passed only on the owner's answer for
  that merge, never on the host's judgment (`run-issue/SKILL.md` step 11; see
  [Review loop and timeline](#review-loop-and-timeline)). `--force-unreviewed` is the fourth bypass; step
  11 mentions it only as the flag that records a `## Merge (unreviewed)` entry.
- `merge_pr.sh` checks two things before it merges. (a) The newest review entry (`## Local Review`,
  `## Integrated Review` or a legacy `## External Review`) is at the pull request's head, and is approved, or for an Integrated Review is
  complete with no open must-fix or cross-confirmed finding. (b) The pull request body or a comment has
  a `## Decision summary` heading (`merge_pr.sh`, Step 1.5).
- A review at an earlier commit still counts when only bookkeeping changed since: that issue's
  `.agent/work-plans/issue-N/` files and the roadmap. `_bookkeeping.sh` holds that one rule; the merge
  gate, the CI target and `review_progress.sh sources` all use it.
- The script then waits for CI on the reviewed head, not on whatever the head has moved to. A review
  check-run that is still running (Copilot's) holds the merge unless `--allow-pending-review` is passed;
  its conclusion is never read as CI. A review state that could not be read holds it too: the script
  refuses at the CI grace deadline rather than merge past a review it never saw.
- The gate enforces by default on workspace pull requests: a gap refuses with exit 1 and no entry.
  Project and package pull requests are report-only: the gap is printed and recorded as a
  `## Merge (report-only)` entry and the merge goes ahead. For a package issue the gate reads the
  owning repository's pull request from the owning checkout's committed timeline at origin's branch
  head, and records there only when the working copy's `progress.md` is the committed one; a sibling repository's pull
  request reads none, and its record goes on that pull request ([Worktrees](#worktrees), Records). `--force-unreviewed` bypasses both conditions
  with a banner and a `## Merge (unreviewed)` entry. A merge that does not end merged after one of
  those entries goes to the `merge-refused` checkpoint.
- The gate's calls to origin (its fetch, the CI-target fetch, the record push) are time-limited
  (`wt_bounded_git`: `WT_FETCH_TIMEOUT`, default 60 s, no terminal prompt), so an SSH passphrase or
  host-key prompt with no agent fails at the limit instead of prompting. The gate then judges from the
  commits already present locally: a head that is not there is a reason, never a pass.
- The record is committed and pushed only from a checkout that is its repository's top folder, has the
  pull request's branch checked out and, for a package pull request, has its HEAD equal to origin's
  copy of it (so the record push never carries unpushed commits) and a working-copy `progress.md` that
  is the committed one (or absent from both the commit and the working copy; the gate itself reads
  only the committed copy, so an uncommitted approval never passes), and only when `progress.md` and its folders are a regular
  file and folders (a symlink is left as found); otherwise it goes on the pull request with the reason
  and the checkout is left as found. A workspace or project pull request's worktree is not checked for
  either. When a hook refuses the commit or origin
  refuses the push, `progress.md` is put back as it was first. A push that times out is settled by a
  bounded fetch of the branch: when origin's branch contains the record commit (its tip, or an ancestor
  of it after a push on top) it is kept; otherwise, whether origin answers without it or cannot be
  asked, it is undone and the record goes on the pull request, at worst as a second copy, never only in
  a local commit. If that comment cannot be posted either, the script says the record could not be
  written anywhere and goes on to the merge. A package pull request's duplicate check compares with the
  newest record across its timeline and the pull request's comments, by the entries' own `**When**`; a
  tie or an unreadable time records again rather than skip. With no timeline read, the newest record
  comment of either type is compared, and only a record of the same type with the same conditions
  is a duplicate. A comment is a record only when its first line is exactly one of the two headings
  (an empty or null body is not one; comments that cannot be read are said, and the record is
  written), and its values are compared with trailing blanks and a carriage return trimmed.
- The gate is local only. A Merge click on GitHub bypasses it, and the server-side complement, a required
  status check, is not built; building it changes CI and branch protection, which is Ask First
  (`merge_pr.sh`, Step 1.5 comment; [Rules](#rules)).

## Identity

**Now**

Status: `decided`

- An agent signs its work with a framework identity: a name, an email of the form
  `<local>+<framework>@<domain>`, a model name and a framework key. No address is stored: `<local>@<domain>`
  is the checkout's configured `git config user.email` (a clone value wins over the global one) with any
  `+suffix` removed, derived by `.agent/scripts/identity_base.py` for the scripts and the hook alike, and
  an unset or malformed git email fails with the fix. The table of frameworks and suffixes is
  `.agent/scripts/framework_config.sh`; the strategy and the reasons are in
  [`.agent/AI_IDENTITY_STRATEGY.md`](../.agent/AI_IDENTITY_STRATEGY.md). The identity is on the commit
  and, through `AGENT_NAME` and `AGENT_MODEL`, in the signature on GitHub text.
- On an agent that runs on the host, the identity is ephemeral: `set_git_identity_env.sh` is sourced
  into the session, sets the `GIT_AUTHOR_*` and `GIT_COMMITTER_*` variables and the `AGENT_*` variables,
  and leaves `.git/config` alone, so the owner commits as himself afterwards. Shell state does not
  carry between tool calls, so it is sourced in the same call as the command that needs it.
- Three things refuse to run without an identity or with a wrong one: the `check-commit-identity` hook
  (accepted emails are derived from the configured git email: the base or `<local>+<anything>@<domain>`), `dispatch_phase.sh` (exit 2
  when `AGENT_NAME` or `AGENT_EMAIL` is unset, with no fallback to the owner's git config) and
  `progress_append.sh` (fails loudly when unset). `gh_create_pr.sh` and `gh_create_issue.sh` exit 2
  for an unsigned body ([Rules](#rules)).
- The work is kept tool-neutral (principle "Use the main tool fully; keep the work tool-neutral"):
  plans, reviews and progress are plain files any tool reads. What needs Claude Code is the
  `/run-issue` and `/start-task` skills (their descriptions say so), the user tier in `~/.claude`
  ([Sessions and roots](#sessions-and-roots)) and the Agent tool that dispatches phases. Without it, a
  Codex or Gemini session walks the same phases by hand, one `SKILL.md` at a time
  ([Review loop and timeline](#review-loop-and-timeline)). Each framework has an
  adapter file listed in `AGENTS.md`.

## Instruction layers

**Now**

Status: `decided`

This file describes the four layers an agent's instructions load in, and gives the first a budget.

1. Always loaded. For Claude Code that is `CLAUDE.md`, which imports `AGENTS.md` with `@AGENTS.md`;
   `AGENTS.md` is 10,513 bytes and 199 lines, `CLAUDE.md` 42 lines (`wc`, 2026-11-02; `AGENTS.md` was
   33,047 bytes and 448 lines before #259 moved its reference material out). A session under a
   registered project root gets nine pinned `AGENTS.md` sections instead, rendered by the
   `SessionStart` hook ([Sessions and roots](#sessions-and-roots)).
2. Path-scoped. Rules that load only when the agent works on matching files. The workspace has none
   (`.claude/` holds `hooks`, `settings.json` and `skills`).
3. Skill. A `SKILL.md` loads when its skill is invoked (22 skills in `.claude/skills/`).
4. On demand. Files an agent opens because a pointer sent it there: this file, the ADRs, the
   knowledge files. This file is not always loaded.

The always-loaded layer has a budget, so that every added rule has to displace or justify itself:
`AGENTS.md` stays at most 200 lines, and says so in its References section. It holds rules and
pointers; reference material lives behind the pointers, in `.agent/knowledge/` (the script reference,
GitHub CLI patterns, the git-bug-first pattern, build and test configuration) and
`.agent/WORKTREE_GUIDE.md` (the worktree commands and entry). The `agents-md-line-budget` pre-commit
hook (`check_agents_md_budget.sh`) fails a commit that takes the file past 200 lines; it runs only
when `AGENTS.md`, the script or `.pre-commit-config.yaml` is staged, and `make lint` runs it again in
CI. The number follows the vendor guidance for Claude Code, a target of under 200 lines per instruction
file, as recorded in the prior-art notes (`prior-art-comparison-2026-10-08/summary.md` item 5;
`prior-art-alignment-agent-frameworks.md`, Claude Code entry). The host set it on 2026-11-02 (#259),
closing OQ-4, for the owner's confirmation at the merge. `CLAUDE.md` and the other adapter files have
no budget of their own.

## Decision register

**Now**

Status: `decided`

Purpose: tell a reader which ADR still governs, so nobody follows a superseded or drifted one. One row
per ADR in `docs/decisions/` (21), in order. The ADRs are history and none is edited here (owner
decision 2026-10-09, C1-c); this table is the only place the standing below is recorded.

Standing takes one of four values. `in force`: the ADR's Status line says Accepted and nothing found
contradicts it; the cell may carry an owner-decided note on a detail that differs here without
contradicting the decision. `superseded`: a later ADR replaced it, as its Status line says. `superseded in
practice`: the ADR is Accepted but the code does something else, stated in the cell. `Provisional`: the
ADR's own Status line. Re-examined is `yes <date>` when the ADR was checked against the code, while
this document was rewritten or since by `/audit-workspace`, and `not yet` when it was not; the date is
the checked-date. The audit does not edit this table: its report lists the cells to change, and a small
pull request applies them, with its own change-log row. A section link of `#decision-register` means
no section of this file carries that ADR.

| ADR | Decision | Standing | Section | Re-examined |
|---|---|---|---|---|
| [0001](decisions/0001-adopt-architecture-decision-records.md) | Record decisions as short dated ADRs in `docs/decisions/`; accepted ADRs are history, superseded and not edited. Its trigger is scoped by ADR-0017 | in force | [Decision register](#decision-register) | yes 2026-10-27 |
| [0002](decisions/0002-worktree-isolation-over-branch-switching.md) | All feature work happens in git worktrees, not by switching branches; the worktree scripts take `--type workspace\|project` | superseded in practice: project worktrees live under the registered root's own `worktrees/` (or `worktrees=`), and `worktrees/project/<repo>/` is only the legacy fallback; `--type` is derived from the cwd when omitted | [Worktrees](#worktrees) | yes 2026-10-09 |
| [0003](decisions/0003-workspace-infrastructure-is-project-agnostic.md) | The workspace stays project-agnostic for a single-repo project | superseded by ADR-0011, which carries the doctrine forward | [Registry and adapters](#registry-and-adapters) | yes 2026-10-09 |
| [0004](decisions/0004-enforcement-hierarchy-for-agent-compliance.md) | A rule that matters is enforced at more than one layer; instruction files alone are not enough | in force | [Rules](#rules) | yes 2026-10-27 |
| [0005](decisions/0005-layered-enforcement-strategy.md) | CI is the enforcement layer, pre-commit hooks the local mirror, framework hooks the early feedback; new rules go CI-first | in force | [Rules](#rules) | yes 2026-10-27 |
| [0006](decisions/0006-adopt-agents-md-as-shared-instruction-file.md) | `AGENTS.md` holds the shared rules and each framework gets a thin adapter file | in force | [Decision register](#decision-register) | yes 2026-10-27 |
| [0007](decisions/0007-retain-make-with-dependency-tracking.md) | Keep Make as the task runner, with stamp files for setup dependencies | in force (its "key behaviours" list describes the ROS fork's bootstrap/manifest/layer chain; here the stamps are setup-dev, then git-bug and ros-manifest (no project stamp since #295), and make test does not depend on build) | [Decision register](#decision-register) | yes 2026-10-27 |
| [0008](decisions/0008-permit-cross-reference-addendums-in-adrs.md) | An accepted ADR may gain a status note, a references list or link and typo fixes; anything else needs a superseding ADR | in force | [Documentation layers](#documentation-layers) | yes 2026-10-27 |
| [0009](decisions/0009-python-package-management-policy.md) | Python tools go in the workspace `.venv` (from `requirements.txt`) or in pipx; PEP 668 is the guardrail | in force | [Decision register](#decision-register) | yes 2026-10-27 |
| [0010](decisions/0010-git-bug-is-optional.md) | git-bug is installed by default and `skip-git-bug` opts out; scripts work without it | in force | [Decision register](#decision-register) | yes 2026-10-27 |
| [0011](decisions/0011-project-type-adapter-contract.md) | Behaviour that differs per project shape sits behind a fixed adapter contract per project type; workflow scripts never branch on the type | superseded in practice: the dispatcher resolves `--project`, then the cwd inside a registered directory, then the legacy `project_config.sh`; the verb count is not drift, its Status already says 13 (ADR-0019) | [Registry and adapters](#registry-and-adapters) | yes 2026-10-09 |
| [0012](decisions/0012-worktree-composition-is-an-adapter-concern.md) | Worktree composition is an adapter concern: the `worktree_repos` and `worktree_env` verbs | in force | [Registry and adapters](#registry-and-adapters) | yes 2026-10-09 |
| [0013](decisions/0013-progress-md-entry-type-vocabulary.md) | `progress.md` has a fixed entry vocabulary and header, with a correlation key per entry type | superseded in practice: its writer table says `address-findings` and "any future implement skill" write `## Implementation`; there is no implement skill, and the dispatched implement pass writes it | [Review loop and timeline](#review-loop-and-timeline) | yes 2026-10-09 |
| [0014](decisions/0014-in-process-phase-handoff.md) | Each phase runs in a fresh in-process sub-agent through `dispatch_phase.sh`, and the host checks the exit instead of trusting the sub-agent | superseded in practice: its Decision calls `implement` the inline pass; since #314 `implement` is dispatched like every other phase and only a `takeover` answer runs a phase inline | [Review loop and timeline](#review-loop-and-timeline) | yes 2026-10-09 |
| [0015](decisions/0015-parallel-sync-is-the-only-review-dispatch-mode.md) | Cross-model reviewers run in parallel and synchronously; there is no tmux mode | in force | [Review loop and timeline](#review-loop-and-timeline) | yes 2026-10-09 |
| [0016](decisions/0016-session-roots-and-the-user-tier.md) | The workspace and each project are separate session roots, and a user tier carries the workspace layer to project sessions. Decision 3 is superseded for skills by ADR-0018; decision 5 (registration is a workspace script) by ADR-0021 | in force | [Sessions and roots](#sessions-and-roots) | yes 2026-10-09 |
| [0017](decisions/0017-design-document-is-the-current-picture.md) | This file is the current picture and the authority; an ADR is written only when two parts could otherwise choose incompatibly | in force | [The design](#the-design) | yes 2026-10-09 |
| [0018](decisions/0018-plugin-based-skill-delivery.md) | Workspace skills reach project sessions through the `agent-workspace` Claude Code plugin, not `~/.claude/skills/` symlinks. Decisions 3 and 4 (enabled at local scope per registered root; the exception to ADR-0016 decision 2) and decision 6's paragraph on how `run-issue` decides the prefix (`skill_prefix.sh` refusing and `run-issue` stopping) are superseded by ADR-0020 | in force | [Sessions and roots](#sessions-and-roots) | yes 2026-11-12 |
| [0019](decisions/0019-repo-pin-verb.md) | The `repo_pin` adapter verb: the ref a repository is pinned at and whether it is a branch, tag, commit or unknown, so a base never comes from the forge's default branch | in force | [Registry and adapters](#registry-and-adapters) | yes 2026-11-12 |
| [0020](decisions/0020-plugin-enabled-once-at-user-scope.md) | The plugin is enabled once, at user scope; nothing is written into a project checkout; the workspace checkout's tracked settings set it to false, and a session in a subdirectory of the checkout lists each shipped skill under both names (accepted, 2026-11-12) | in force | [Sessions and roots](#sessions-and-roots) | yes 2026-11-12 |
| [0021](decisions/0021-a-project-session-may-register-its-own-folder.md) | A session started in a folder that is not registered may write that folder's own registry line and settings file through one guarded script, `register_session_root.sh`, and nothing else in the workspace; the script is not promoted, so each call asks for permission; registration from the workspace keeps working | in force | [Sessions and roots](#sessions-and-roots) | yes 2026-11-13 |

Plan-level decisions that never got an ADR: none are listed. The plan for this rewrite names none that
is not already stated in a section above with its issue.

**For the owner, one at a time (C1-c).** Four ADRs are `superseded in practice` (0002, 0011, 0013,
0014). Each is a candidate for a superseding ADR, and each supersession is the owner's call, made one
ADR at a time; none is made here.

## Open questions

**Now**

Status: `open`

Questions this file raised and nobody has answered. An `open` block elsewhere in the file points here
or to an issue. Each row says who decides and what the answer changes. Wire-in questions about
ADR pointers and the roadmap belong to the pull request that does that wiring, not to this table.

| ID | Question | Who decides | What it changes |
|---|---|---|---|
| OQ-1 | Where does a project record its own mapping of the seven documentation roles? | Owner | The Target of [Documentation layers](#documentation-layers); nothing built depends on it yet |
| OQ-2 | ADR-0016 stayed Provisional until the `/run-issue` acceptance run from a project root, and its promotion condition names #317, which closed on 2026-09-23. Where is the acceptance run tracked, and who runs it? Answered by #423: the run was tracked in the roadmap's Direction section, and the owner ran it, through `/orchestrator` and `/run-issue` in a session started at the registered project's root, answering the merge checkpoint himself; it passed on 2026-11-09 and ADR-0016 is Accepted | Owner | The [Sessions and roots](#sessions-and-roots) Now block is `decided`; the Registry inventory can now be read to settle #295 |
| C4 | How does one project live on two machines? How are mixed-flavour projects (#310) described? Answered by #332: a project is registered by `register_project.sh` from the workspace (or, since #466, by `register_session_root.sh` from a session in its own folder) and onboarded at its root, and a line written by hand is adopted by the same script; unregistering removes the registry line and the settings file, and leaves the project, its plans, timelines and memory, and the user tier (the plugin is at user scope since #446) alone | Owner | The Target of [Registry and adapters](#registry-and-adapters); no code depends on the open part yet |
| C5 | What must a review finding contain (a principle, a row in the review guide, or design text only), and how independent must its reviewers be? If design text only it goes in [Review loop and timeline](#review-loop-and-timeline); if a principle, it is a separate change | Owner | Whether `## Review loop and timeline` gains a rule, or `docs/principles.md` and the review guide change |
| OQ-3 | Where do "healthy" and the measures live for the workspace (the Direction and Measures roles have no home for them), and how will anyone tell a change helped? Partly answered (#386): the roadmap's Direction section and the sit-rep run record. Still open: what healthy means beyond the acceptance case, and a measure beyond counts of lines true | Owner | The two gap rows of [Documentation layers](#documentation-layers); the long-view goal in the README |
| OQ-4 | What budget does the always-loaded instruction layer get (the reference point is under 200 lines per file)? Answered by #259, a host decision of 2026-11-02 for the owner's confirmation at the merge: `AGENTS.md` stays at most 200 lines, held by the `agents-md-line-budget` hook | Owner | [Instruction layers](#instruction-layers); changing `AGENTS.md` is Ask First (the owner's go-ahead for the #259 drive is approval in principle; the final approval is his at the merge) |
| OQ-5 | Should the merge gate get a server-side complement, a required status check asserting the same two conditions? | Owner | [Merge gate](#merge-gate); it changes CI and branch protection, which is Ask First (`merge_pr.sh`, Step 1.5 comment) |

## Change log

**Now**

Status: `decided`

One row per change to this file, appended in the same change that alters a section: date, section, one
line, issue, and the line count of the document after the change. The line count is how growth shows up
as a number (principle "Know whether it works"); a section past about 60 lines says in its row whether
its detail should move next to the code. A change that builds a Target also edits the sentence it
makes untrue in the same change (ADR-0017).

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
| 2026-10-09 | Decision register | 17 rows, standing and re-examined, four rows superseded in practice (0002, 0011, 0013, 0014) with what the code does; no ADR file edited; both checker guards are live from here. Section is 46 lines | #335 | 583 |
| 2026-10-09 | Open questions | Table finished: OQ-1 to OQ-5, C4 and C5 | #335 | 588 |
| 2026-10-09 | Change log | Now block: the rule for rows and the line count | #335 | 596 |
| 2026-10-09 | Glossary | Added as the last section: 15 settled entries (7 own terms, 8 standard), the admission rule, WIP limit and appetite left out | #335 | 650 |
| 2026-10-09 | How it works | Agent draft from the fact list and the owner's recorded phrasings, no new ideas, replacing the stub; owner to edit | #335 | 688 |
| 2026-10-09 | How it works, Registry and adapters, Review loop and timeline, Merge gate, Decision register | Review fixes: the next-step routing wording (newest entry, earlier entries for round count and failed-Implementation skill), the repeat-phase resume exception, the `setup` row's stamps, the `merge-refused` condition, the gate flags step 11 lists, the progress.md line count, gate (a) with `External Review`, the worktree_list second path, the `adapter:73` default, the ADR-0011 and ADR-0012 register rows, the register section length; three Review-loop proposals accepted by the owner 2026-10-09 ("candidate" marker dropped) | #335 | 695 |
| 2026-10-09 | Rules, Review loop and timeline | Rules table gains the row for the owner deciding every merge (`review only`; `merge_pr.sh` has no owner check), making 15 rules; the Target's `progress.md` size is stated as more than 800 lines, so it does not go stale with each entry | #335 | 697 |
| 2026-10-12 | How it works, Sessions and roots, Worktrees, Review loop and timeline | Review fixes: `publish` and `merge` are host steps, `publish` writes no entry and `merge` one only when its gate is relaxed, and the owner may have the host take over a failed phase; the per-project footprint is a proposal, and records today sit in the repository that owns the issue; two session roots, with the user tier as the layer injected into them | #335 | 706 |
| 2026-10-12 | Rules | The project-names row states the 2026-10-09 boundary (history, code-origin comments, test fixtures, `tools/ros-manifest/` prose keep real names; examples and guidance use synthetic ones) and the owner's rule of 2026-10-12, a real name only for a public repository; the review guide row it cites gains the same clause, and the worktree guide and review-plan examples drop a real package name | #335 | 707 |
| 2026-10-12 | Review loop and timeline | Review fix: `merge` writes an entry when its gate finds a gap and does not refuse it (a relaxing flag, or a project pull request), not whenever a flag is passed, as the first 2026-10-12 row put it | #335 | 708 |
| 2026-10-12 | Rules | Review fix: the project-names row credits work plans as history to the owner's decision of 2026-10-12, not to the 2026-10-09 boundary, which does not name them | #335 | 709 |
| 2026-10-12 | Review loop and timeline | Review fix: a `merge` entry that no worktree on the pull request's branch can commit and push is posted as a comment on the pull request (`_gate_record` in `merge_pr.sh`) | #335 | 713 |
| 2026-10-12 | Worktrees | Review fix: the Records bullet says an issue in a package repository has no timeline, since a package worktree is a folder of several repositories and `merge_pr.sh` posts its gate record on the pull request | #335 | 717 |
| 2026-10-12 | Glossary | "progress timeline" says the loop records each step and decision, not that every phase writes an entry, which the Review loop section no longer holds (`publish` writes none); owner decision 2026-10-12, revising his C6 wording | #335 | 718 |
| 2026-10-12 | Decision register | `/audit-workspace` reports the `Re-examined` and `Standing` cells to change when it checks an ADR against the code, whenever the standing it finds differs from the cell, and offers a small pull request that applies them; it does not edit the table, and the paragraph says so | #335 | 720 |
| 2026-10-12 | Registry and adapters, Worktrees, Merge gate, Change log | `merge_pr.sh` looks up a project pull request's timeline at the registry-aware project root, the same one the Step 1 roadmap lookup uses, and its main-tree guards include it; the #379 gap text is gone from the Records bullet, Target items 1 and 2, the Merge gate bullets, the `merge_pr.sh` row and the change-log rule, and every `merge_pr.sh` line number is refreshed | #379 | 718 |
| 2026-10-12 | Documentation layers, Registry and adapters, Open questions | Direction row: the roadmap's `## Direction` section, read by the sit-rep; Measures row: the sit-rep run record, a first form; the gaps paragraph says both gaps narrowed and neither closed, status stays machine-local and the five result words are a trial; the Target sentence notes a project may carry the same section; `settings.local` beside the registry; OQ-3 partly answered | #386 | 730 |
| 2026-10-13 | Decision register | Row for ADR-0018 (workspace skills reach project sessions through the `agent-workspace` plugin; Provisional, not yet re-examined), making 18 rows | #345 | 732 |
| 2026-10-13 | Sessions and roots | The root rule (owner, 2026-10-13): a session works only under the root it was launched in, cross-root work is an issue or an inbox line, and `run-issue` and `/start-task` refuse an issue of another root through `session_root.sh`; the user-tier bullet drops the `~/.claude/skills/` symlinks and a new bullet describes plugin skill delivery (ADR-0018). Section is 79 lines, past the 60-line prompt: asked whether the detail moves next to the code; the two new bullets are the interface between the installer, the hook, `run-issue`, `/start-task` and the two location scripts, which no one script header shows, so they stay | #345 | 748 |
| 2026-10-13 | Sessions and roots | Review fixes: the installer refuses a root that is a plain directory inside another repository (its sessions read that repository's settings); the directory a run starts from names its root, rather than the current directory at any point; the `SessionStart` hook counts a root's `worktrees=` directory as the root's; `session_root.sh` and `skill_prefix.sh` refuse the same directories | #345 | 753 |
| 2026-10-15 | Documentation layers | Direction row: the sit-rep names the first Direction line not yet true as the next step and reports problems from the Decision register's Re-examined dates, the research digest's entry dates and the commits since this file last changed, and may start a due read-only check in the background in a workspace session; the gaps paragraph calls that Problems section a first form of health signals | #395 | 756 |
| 2026-10-21 | Registry and adapters, Worktrees | The per-project settings file `.agent/projects.d/<name>` (commands, `bootstrap_url`, the records settings, `instructions`), read before the legacy `.sh` and the shared config (an existing legacy `.sh` is the whole legacy layer, as before), with a fall-through to the shared config reported, a command set in the file run without either config's environment (environment setup goes in the script the key points at), the writer's lock file beside the file or its link target and never removed, `project_setting.sh` named beside `capture.sh` as reading the main checkout's registry from a worktree, and a key the project's type never reads refused (`unused_settings` per type); the Worktrees Target's `location` and `tracking` move from the registry entry to that file, what #332 builds and what the records lookup (#393) builds are marked, every default is provisional and held by `project_records_default`, the refused combinations are named, the "don't prohibit" sentence is replaced by the owner's refusal (a records repository must not be a workspace: remote URL, local path, contents) with its fork-and-pull-request reason, and the mechanism-1 `dispatch_phase.sh` line numbers and the `adapter:73` default citation are refreshed. Registry and adapters is 109 lines, past the 60-line prompt: the new bullet is one paragraph that points at the `_project_registry.sh` header, where the grammar and keys live, so it stays. Worktrees is 95 lines and its Target 57, under the 60-line split point set on 2026-10-09, so it stays one section | #332 | 790 |
| 2026-10-15 | How it works, Documentation layers, Rules, Review loop and timeline, Glossary | Who answers a checkpoint (owner decision 2026-10-15): the owner answers what touches his goals and every merge, the host the rest within `/orchestrator`'s table, recorded `**Decided-by**: host (<reason>)` and listed for veto; the phase table's who-decides wording, the exit-check bullet (take over is the owner's), the checkpoint bullet and the glossary entry follow; a Rules row for host answers (`review only`); the Direction row names the roadmap's two paths and the sit-rep's path word and focus question | #321 | 800 |
| 2026-10-28 | Sessions and roots, Registry and adapters, Open questions | Registration is built (#332 PR 2): `register_project.sh` (register, adopt a hand-written line, `--remove`, `--detect`, `--dry-run`, rollback of a failed registration) and its read-only gate `registration_verify.sh` replace "Registration is by hand"; each type's `registration.conf` sits beside the 12-verb contract, checked by `validate_adapter.sh`; the Sessions and roots registration bullet moves from Target to Now; the Registry Target names the two steps (register from the workspace, onboard at the root); C4 keeps only one project on two machines and mixed-flavour projects | #332 | 819 |
| 2026-10-28 | Documentation layers, Sessions and roots, Registry and adapters | Onboarding is built (#332 PR 3): Sessions and roots names the one exception to working only under the root (a project session writes its own project's settings file through `project_setting.sh set`, guarded to that project) and gains the onboarding bullet (`/agent-workspace:onboard-project`, the footprint questions, `project_integration_audit.sh`, offers only with `instructions=tracked`, the four answers and the `## Onboarding` roadmap section, every write waits for a yes); the Registry Target says both steps are built; Documentation layers says onboarding offers a project's Direction section. Sessions and roots is 101 lines, past the 60-line prompt: the two bullets name how the session-root rule is bent and what the project side does, which no single script header shows, so they stay; the onboarding steps themselves live in the skill | #332 | 836 |
| 2026-10-28 | Sessions and roots | Review fix: the onboarding bullet says where the fix-now batch goes, the onboarding issue's feature branch or, for a project that uses no issues, a `skill/onboard-project-<timestamp>` branch from a project skill worktree (`onboard-project` joins `worktree_create.sh`'s skill allowlist) | #332 | 840 |
| 2026-10-29 | Sessions and roots | Review fix (host decision, listed for the owner's veto): at a parent root onboarding reads, reports and fixes the chosen instance's repository alone (audit categories 1 to 5 read only the instance; category 6 verifies the instance's registration beside the parent's) and does not audit the parent root's own files | #332 | 843 |
| 2026-10-30 | Decision register | Nine Re-examined cells (0001, 0004, 0005, 0006, 0007, 0008, 0009, 0010, 0018) set to `yes 2026-10-27` from the 2026-10-27 audit, each checked against code; 0007 stays in force with a note on how its key behaviours differ here (owner, 2026-10-27); the `in force` definition now admits such a note | #405 | 845 |
| 2026-10-30 | Sessions and roots | `audit-project` takes the hygiene checklist (#332 PR 4, D4): a bullet says onboarding ends by offering it, that it holds the checklist with the items a fact makes moot reported skipped (`project_integration_audit.sh --facts`: `github`, `issues`, `prs`, `windows`, `multi_component`), that onboarding reads the same facts for issues, and that it is report-only with an optional final step answering findings the four ways onboarding does. Sessions and roots is 114 lines, past the 60-line prompt: the bullet names which skill holds the checklist and what decides a skip, which no single script header shows, so it stays; the checklist itself lives in the skill | #332 | 854 |
| 2026-11-02 | Rules, Identity | `gh_create_issue.sh` signs an issue body as `gh_create_pr.sh` signs a pull request (`--no-signature`, exit 2 without an identity): the Rules row is retitled to cover issues and still says comments are signed by habit only, and the Identity bullet names both wrappers | #323 | 855 |
| 2026-11-02 | Registry and adapters, Worktrees | Line citations of `worktree_create.sh`, `merge_pr.sh` and `gh_create_pr.sh` refreshed after #323 moved them (a new branch's start point; the CI target's bookkeeping set and the review-hold SHA; the signing wrappers' shared argument parser, `_gh_create_args.sh`); no statement changes | #323 | 856 |
| 2026-11-02 | Merge gate, Registry and adapters, Worktrees | Review fix: an unreadable review state holds the merge (refused at the CI grace deadline); `merge_pr.sh` line citations refreshed again | #323 | 858 |
| 2026-11-02 | Registry and adapters | `worktree_create.sh` line citations refreshed after its branch fetch was bounded like the default-branch fetch; no statement changes | #323 | 859 |
| 2026-11-02 | Rules | Review fix: the signing row says both wrappers refuse a body gh writes itself (`--fill`, `--template`, `--recover`) without `--no-signature` | #323 | 860 |
| 2026-11-02 | Rules | Review fix: `--recover` is refused even with a body flag (gh loads the recovered input over it) | #323 | 861 |
| 2026-11-02 | Instruction layers, Rules, Open questions, Worktrees | `AGENTS.md` trimmed from 448 lines (33,047 bytes) to 199 (10,513) by moving its reference material to `.agent/knowledge/` and `.agent/WORKTREE_GUIDE.md`; the section's status goes from `proposed` to `decided` with the budget set at most 200 lines (host decision for the owner's confirmation, closing OQ-4) and held by the new `agents-md-line-budget` hook, which gets a Rules row; the Worktrees citation for entering with `cd` now names `WORKTREE_GUIDE.md` | #259 | 860 |
| 2026-11-09 | Documentation layers | The sit-rep reads the session's own root (owner, 2026-11-09): a project session gets the project's Direction lines, worktrees, pull requests and the problems its own files allow, the workspace report lists project work only where a workspace Direction line names it, and a combined view is left to a later personal-root skill; the Measures row says the run record is per root; `sitrep_root.sh` named | #418 | 865 |
| 2026-11-09 | How it works, The design (Status key), Sessions and roots, Registry and adapters, Decision register, Open questions | ADR-0016 is Accepted (owner, 2026-11-09): the `/run-issue` acceptance run from a project root passed the merge checkpoint. How it works says the user tier has passed its acceptance run, no longer that it is not yet proven; the Status key's `decided, not proven` row names no ADR and no longer says a Provisional ADR is untested; Sessions and roots is `decided`, its Now block says ADR-0016 is Accepted and ADR-0018 is still Provisional with its own promotion condition (the same run) met; the Registry inventory sentence names the run's date; register row 0016 is `in force` and notes ADR-0018's supersession of decision 3 for skills; the C1-c sentence keeping ADR-0016 Provisional is dropped; OQ-2 is answered in place (tracked in the roadmap's Direction section, run by the owner through `/orchestrator` and `/run-issue` from the project root). Sessions and roots grows by two lines and is a status edit, so no detail moves | #423 | 867 |
| 2026-11-09 | Sessions and roots, Decision register | ADR-0018 is Accepted (owner, 2026-11-09): its promotion condition, ADR-0016's acceptance run, passed the same day. The Sessions and roots Now block says ADR-0018 is Accepted too, no longer that it is Provisional with promoting it the owner's call; register row 0018 is `in force`. Sessions and roots is 116 lines, past the 60-line prompt; its length is unchanged and this is a status edit, so no detail moves | #425 | 868 |
| 2026-11-10 | Registry and adapters | `worktree_create.sh` line citations refreshed after an existing branch's parent-branch fetch was made to warn when it times out; no statement changes | #323 | 876 |
| 2026-11-10 | Registry and adapters | `worktree_create.sh` line citations refreshed after the named-branch lookup was redesigned (an explicit refspec, the outcome set present / absent / unknown, `--allow-unverified-branch`); no statement changes | #323 | 877 |
| 2026-11-10 | Registry and adapters | `worktree_create.sh` line citations refreshed after review fixes to the named-branch lookup (a branch on origin gets its own upstream settings, not a fetch refspec; a skill branch is not looked up; the project path warns on an existing branch's parent); no statement changes | #323 | 878 |
| 2026-11-10 | Documentation layers | The roadmap's acceptance case is no longer ADR-0016's (met 2026-11-09): the sentence on what the Direction section says drops "(ADR-0016's)" and keeps "one acceptance case", now project11 on a second machine against ROS 2 Rolling | #432 | 869 |
| 2026-11-10 | Registry and adapters, Worktrees | An issue in a package repository has a timeline (issue 429, first pull request): the Records bullet no longer says it has none, and says the records are committed in the owning repository's checkout inside the package worktree under the default records setting, that `dispatch_phase.sh` decides that directory in one place and `run-issue` moves the host there with its `where` subcommand, that every records read and write passes one records gate (`records_path`), which refuses a sibling checkout and the worktree's top folder, and what the gate does not cover, and that the merge gate does not read that timeline yet; the cited line numbers of `dispatch_phase.sh`, `merge_pr.sh`, `review_progress.sh` and `progress_append.sh` are refreshed in the Registry inventory table and sentence, the Records bullet and the Target's mechanism 1. Worktrees is 104 lines, past the 60-line prompt: the bullet names the functions whose headers hold the rule and the guard, and the mechanics stay there, so no detail moves | #429 | 896 |
| 2026-11-10 | Registry and adapters, Worktrees | A timeline write from outside the issue's checkout is refused (issue 437): the Records bullet no longer lists "a write from outside any worktree, which commits on that checkout's own branch" among what the records gate does not cover, and says that a write that changes a timeline is refused unless its target is the issue's own checkout, wherever the command runs, and that reads are not; the cited line numbers of `review_progress.sh` and `progress_append.sh` are refreshed in the Registry inventory sentence, the Records bullet and the Target's mechanism 1. Worktrees grows by four lines and stays past the 60-line prompt: the bullet names the gate whose header holds the rule, and the mechanics stay there, so no detail moves | #437 | 901 |
| 2026-11-12 | Registry and adapters, Worktrees | Review fix (issue 437): the Records bullet states the write rule as one statement, the file a write changes, every symlink resolved, sits at the place its path names in the issue's own checkout, after a file symlink and a records folder linked to a main-checkout folder got past the checkout test; the cited `progress_append.sh` gate lines are refreshed. Worktrees grows by one line and stays past the 60-line prompt: the mechanics stay in the gate's header | #437 | 903 |
| 2026-11-12 | Sessions and roots, Registry and adapters | A fresh clone works with no project (#295, first pull request; part of #265): a Sessions and roots Now bullet says a workspace with no registered project and no `project/` validates, sets up without a prompt, shows its dashboard and syncs, and that the `gh_create_*` repo-safety check accepts every registered root's repository; Table 1's `gh_create_pr.sh` row says registered roots are consulted (lines refreshed); Table 2's `setup` row names the stamps `make setup` depends on now (`git-bug` and `ros-manifest`, no `project`) and the Makefile lines of `setup` and `user-tier-install` are refreshed; Table 1's `worktree_create.sh` line citations are refreshed after this change moved them; the ADR-0007 register row names the setup stamps as they are now. Sessions and roots is 121 lines and Registry and adapters 125, past the 60-line prompt: the bullet names the test and the helper that hold the detail, so no detail moves | #295 | 910 |
| 2026-11-12 | Rules, Identity | No owner address in the infrastructure (#455): the Rules row for commit identity says the hook accepts the checkout's configured git email (`+suffix` removed) or `<local>+<anything>@<domain>` and fails when that email is unset; the Identity bullets say the agent email is `<local>+<framework>@<domain>` derived from `git config user.email` by `identity_base.py` (clone value over global, unset or malformed fails with the fix) and the hook's accepted set is derived the same way | #455 | 914 |
| 2026-11-12 | Registry and adapters, Decision register | The adapter contract gains a 13th verb, `repo_pin` (issue 429, part 2, first pull request; ADR-0019): the contract bullet says 13 verbs and what the verb prints for each type, Table 2 gains its row (tally 5 real), and the decision register gains ADR-0019's row and ADR-0011's verb count. Registry and adapters is past the 60-line prompt: the bullet names the verb, and its rules stay in the ADR and the adapters' headers, so no detail moves | #429 | 921 |
| 2026-11-12 | Worktrees | A package issue's pull request has a base branch (issue 429, part 2, second pull request): a Worktrees bullet says it comes from the owning repository's pin through `repo_pin` (or the owner's `--base`), never the forge's default branch, that a pin that is no branch is refused, that the owning repository's new branch starts from origin's copy of it with no fallback (also with `--allow-unverified-branch`), that the `.worktree-repos` header records it as `base=` (every field read unanchored) and gets it on resume once origin confirms it, and what publish and merge do with it; ADR-0012 gets a cross-reference addendum, its decision text unchanged; the `merge_pr.sh` and `dispatch_phase.sh` line citations in the Records bullet and the Target's mechanism 1 are refreshed. Worktrees grows by 14 lines and stays past the 60-line prompt: the bullet names the functions whose headers hold the mechanics, so no detail moves. Revised after the branch's pre-push reviews: creation of a new owning branch always resolves a base (`--base`, else the pin; with `--parent-issue` the parent's branch), a branch this workspace did not start gets `base=` only from a named `--base` that origin has and that shares history with it, the cleanup pulls origin's base by name, and Table 1's `dispatch_phase.sh` line numbers are made true | #429 | 936 |
| 2026-11-12 | Sessions and roots, Registry and adapters, Decision register, Open questions | The plugin is enabled once, at user scope (#446, ADR-0020, superseding ADR-0018 decisions 3 and 4): the plugin bullet says the installer enables it with `--scope user`, writes nothing into a project checkout and migrates the per-root entries, that the checkout's tracked `.claude/settings.json` sets it to false so a session at the checkout's root or in a worktree lists each skill once, bare, and that a session in a subdirectory of the checkout lists each shipped skill under both names, accepted by the owner on 2026-11-12; the user-tier bullet lists the plugin; the registration bullets say registration runs only the read-only user-tier check (the installer only with `--install-user-tier`) and `--remove` leaves the root alone; the root-rule text gives each `session_root.sh` refusal its own reason, no longer "sessions do not read the root's local settings", and no longer says `skill_prefix.sh` refuses them; register row 0018 notes the supersession (decisions 3 and 4, and decision 6's paragraph on how `run-issue` decides the prefix) and row 0020 is added, making 20 rows; C4 no longer says unregistering removes a plugin enable. Sessions and roots is 137 lines, past the 60-line prompt, and grows by 15: the bullets name the scripts and the ADR that hold the mechanics, so no detail moves | #446 | 928 |
| 2026-11-13 | Worktrees, Review loop and timeline, Merge gate, Registry and adapters | The merge gate reads and records a package issue in its owning checkout (issue 429, part 2, last pull request): the Records bullet no longer says `merge_pr.sh` does not read that timeline, and says the owning repository's pull request is gated and recorded there while a sibling repository's reads none and records on its own pull request; the Base branch bullet adds that the pre-push review diffs against `origin/<base>` and `run-issue` step 8 checks and merges that base (`check_branch_updates.sh --base`); the Review loop's comment-fallback list and a Merge gate bullet say the same; Table 1's `merge_pr.sh` and `dispatch_phase.sh` line numbers, the Records bullet's and the Target's mechanism 1 citations are refreshed. Worktrees grows by six lines and stays past the 60-line prompt: the bullets name the variables and lines that hold the rule, so no detail moves | #429 | 959 |
| 2026-11-13 | Merge gate, Review loop and timeline | Review fix (issue 429): two Merge gate bullets and the Review loop's comment-fallback list say the gate's calls to origin are time-limited, so an SSH prompt with no agent fails at the limit, and when the record is committed in a checkout and when it goes on the pull request with `progress.md` put back | #429 | 968 |
| 2026-11-13 | Merge gate, Review loop and timeline, Worktrees, Registry and adapters | Second review fix (issue 429): the owning checkout's timeline is read only when it is on the pull request's branch and contains origin's copy; a symlinked `progress.md` is left as found; a timed-out record push is settled by `ls-remote`; a package pull request's duplicate check reads its comments; every `merge_pr.sh` line citation (Table 1, the Records bullet, mechanism 1) is refreshed | #429 | 979 |
| 2026-11-13 | Merge gate, Review loop and timeline, Worktrees, Registry and adapters | Third review fix (issue 429): a record push that times out is kept only when origin's branch contains the record commit, else undone and posted on the pull request, also when origin cannot be asked; an owning pull request's duplicate check compares with the newest record across both stores; `merge_pr.sh` citations refreshed | #429 | 983 |
| 2026-11-13 | Merge gate | Triage fix (issue 429, pull request 461): with no timeline read, the duplicate check compares with the newest record comment of either type; `merge_pr.sh` citations refreshed | #429 | 986 |
| 2026-11-13 | Merge gate, Review loop and timeline, Worktrees, Registry and adapters | Second triage fix (issue 429, pull request 461): the owning checkout is read, and the record committed there, only when its HEAD equals origin's copy of the branch and its `progress.md` has no uncommitted change; a record comment is matched only on an exact heading, with trimmed values; the workspace path is unchanged; `merge_pr.sh` citations refreshed | #429 | 993 |
| 2026-11-13 | Merge gate, Review loop and timeline, Worktrees, Registry and adapters | Third triage fix (issue 429, pull request 461): the owning checkout's timeline is not read when its `progress.md` has an uncommitted change or an assume-unchanged or skip-worktree flag; an empty or null comment body is not a record, and unreadable comments are said and recorded over; every `merge_pr.sh` citation refreshed, including the Records bullet's main-tree guard and report-only lines | #429 | 999 |
| 2026-11-13 | Merge gate, Review loop and timeline, Worktrees, Registry and adapters | Owner's decision (issue 429, pull request 461): for a package issue the gate reads the committed `progress.md` at origin's branch head, never the working copy; the record is committed in the owning checkout only when the working copy's file is the committed one; the working-copy read conditions are gone; every `merge_pr.sh` citation refreshed | #429 | 1003 |
| 2026-11-13 | Change log | Main merged into issue 429's branch (pull request 461) after #446 landed: the rows of both sides are kept in date order (#446's 2026-11-12 row before issue 429's 2026-11-13 rows), and their line counts are each side's own file at the time; this row's count is the merged file's | #429 | 1022 |
| 2026-11-13 | Worktrees, Registry and adapters | `merge_pr.sh` citations refreshed after the owning record check came to compare mode as well as content with `git diff` (issue 429, pull request 461); the rule's wording, that the record is committed only when the working copy's `progress.md` is the committed one, does not change | #429 | 1023 |
| 2026-11-13 | Review loop and timeline | An issue delivered in several pull requests (#459, owner decision 2026-11-13): the `review-code` row counts `MAX_ROUNDS` per pull request; the `merge` row says a merge on an open issue was an earlier part and the `plan` checkpoint follows; the routing bullet says `next` reads where the current pull request's work starts and whether a `merge` answer stands (row 3a); a new bullet states the boundary rule (`pr_start.py`, shared by `next`, `round` and `sources`), the issue-state check before the probe, what `proceed` relies on, and who closes the issue. The section grows by 13 lines and stays past the 60-line prompt: the rule's detail is in `pr_start.py`'s docstring and `run-issue/SKILL.md` step 13, so no further detail moves | #459 | 981 |
| 2026-11-13 | Change log | Main merged into issue 459's branch (pull request 467) after issue 429's last pull request (461) landed: the rows of both sides are kept, issue 429's 2026-11-13 rows (already on main) before #459's, and their line counts are each side's own file at the time; the `dispatch_phase.sh` line numbers in Table 1 and the Target's mechanism 1 are refreshed for the merged script (#459 had moved them by six to twenty lines); this row's count is the merged file's | #459 | 1038 |
| 2026-11-13 | Sessions and roots, Registry and adapters, Decision register, Open questions | A project session may register its own folder (#466, ADR-0021, superseding ADR-0016 decision 5): the Sessions and roots Now block names ADR-0021; the exceptions bullet becomes two exceptions, the settings file and a session registering the folder it was started in through `register_session_root.sh`, which is not promoted, so each call asks for permission; the registration bullet says registration is done from the workspace or from the folder's own session; the onboarding bullet says an unregistered folder is offered registration (dry run, one yes in text, the real call's permission prompt as a second gate, build and test not run) and names the no-git gap; Registry and adapters Now says what `register_session_root.sh` takes, refuses and hands over, and that registration needs a git repository today; its Target names both ways to register; register row 0016 notes decision 5 superseded, row 0021 is added and the count says 21 (it said 19, two rows behind); C4's answer names the new way. Sessions and roots is 149 lines and Registry and adapters 139, both past the 60-line prompt, and grow by 12 and 8: the bullets name the script and the ADR that hold the rules, so no detail moves | #466 | 1060 |
| 2026-11-13 | Worktrees, Registry and adapters | `merge_pr.sh` line numbers in Table 1, the Records bullet and the Target's mechanism 1 refreshed after the owning checkout's reason came to cap each value rather than the whole sentence (issue 444, pull request 468: a comment of six lines moved everything after line 750); no statement changes | #444 | 1061 |
| 2026-11-13 | Registry and adapters | The settings keys `source`, `source_ref` and `source_path` (refused for `single_project` through its `unused_settings`), and the `ros2_colcon` manifest route: `source` selects it, the workspace-installed `ros-manifest` resolves the manifest for the registry line's role and distro into `configs/manifest-resolved`, one source only, never silently stale, its network needs and its registration limit. Section is 161 lines, past the 60-line prompt: asked whether the detail moves next to the code; the route's mechanics are in the `ros2_colcon/adapter.sh` header and the key grammar in the `_project_registry.sh` header, and the bullet keeps only what crosses them (the settings file, the registry line, the resolver install and registration) | #436 | 1084 |
| 2026-11-13 | Registry and adapters | The manifest route's fetch and resolve hold a flock on `configs/.lock.source`, never removed, unlocked without `flock` as the settings writer is. One sentence in the existing bullet; the rules live in the `ros2_colcon/adapter.sh` header | #436 | 1086 |
| 2026-11-13 | Registry and adapters | Every verb on the manifest route reads one generated directory throughout, never removed while a run reads it; unguarded without `flock`. The lock sentence grows by one line; the rules live in the `ros2_colcon/adapter.sh` header | #436 | 1088 |
| 2026-11-13 | Registry and adapters | No kept clone (owner's decisions at the rounds checkpoints): a git `source` is fetched afresh by each `setup` and `sync` into a temporary directory removed afterwards, local manifest work uses the path form, and without `flock` the directory before the live one is kept; a URL `source` is `https://` or `file://` with no credentials and the fetch allows the https, ssh and file transports only. The rules live in the `ros2_colcon/adapter.sh` header | #436 | 1092 |
| 2026-11-13 | Registry and adapters | The resolver's clone of an `extends` base runs no user hook or filter driver and is bounded by `ROS_MANIFEST_GIT_TIMEOUT` (owner's decision on pull request 480: in the resolver). One clause in the manifest-route bullet; the rules live in the `ros2_colcon/adapter.sh` header and the `tools/ros-manifest` README | #436 | 1094 |

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
- **checkpoint**: a point where the loop stops for an answer (after the plan, before publish,
  before merge). The owner answers the ones that touch his goals and every merge; the host answers
  the rest under his standing rules.
- **progress timeline**: the per-issue file where the loop records each step and decision, so a new
  session can see what happened without re-reading the chat.
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
