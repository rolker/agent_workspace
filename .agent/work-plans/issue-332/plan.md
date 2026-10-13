# Plan: onboard-project registers projects and audits workspace integration

## Issue

https://github.com/rolker/agent_workspace/issues/332

## Context

Inputs, in order of authority: the owner's 2026-10-13 re-scope comment (D1 to D5), his D2a comment, the
Issue Review (`20cbbd3c`) and his Checkpoint (`c29d533f`) accepting actions A1 to A4, then the issue body.
No owner decision is reopened.

**This plan builds on the Target in `docs/design.md#worktrees`** (status `proposed`): the settings
`location` and `tracking`, the four-row combination table, the three mechanisms, the one rule (when
records exist in two places, the setting names the source of truth) and the acceptance test by shape. The
footprint choice is stored in those two settings, not in a parallel `records=` word list. The Target said
they live "in its registry entry"; D2 moves them to the per-project file.

Today: registration is by hand (a `projects.local` line, an optional `projects.d/<name>.sh` the adapters
`source`, a clone). `single_project` runs `exec $BUILD_CMD "$@"` (word-split, no shell), so a value like
`cmake -S . -B build && cmake --build build` never worked as a command: `&&` arrives as an argument. The
registry grammar forbids spaces in values. `onboard-project` and `audit-project` both still find the repo
as `project/<repo-name>`. Scripts run from a workspace worktree see no registry (it is gitignored,
per machine), so the new writers act on the main checkout and refuse from a linked worktree.

## Approach

Four PRs in the owner's order, each reviewable and mergeable alone. A fifth piece (the records lookup) is
a separate issue. Each PR carries the design-doc edit that makes its statements true (ADR-0017) and one
change-log row.

### PR 1 — the per-project file and its keys

`.agent/projects.d/<name>` (no extension; gitignored already via `.agent/projects.d/`).

1. **Grammar** — one `key=value` per line; split at the first `=`; blank lines and lines starting `#`
   ignored (no trailing comments, a command may contain `#`); CRLF tolerated. A key not in the list,
   a duplicate key and an empty value are errors naming the file, line and the known keys, like the
   registry. A malformed file stops the dispatcher and `validate` (never resolve silently). Same
   splitting, key list and error style as the registry fields; the value type is per key, and for
   a command key the value is the rest of the line, because a file with one key per line has no
   other fields to separate (the registry's no-space rule exists only for that reason).
2. **Keys, first set** (everything else stays out until a use justifies it):

   | Key | Value | Meaning |
   |---|---|---|
   | `build`, `test`, `install` | a command, or `none` | `none` is a recorded "this project has none" |
   | `bootstrap_url` | http(s) URL | replaces `MANIFEST_BOOTSTRAP_URL` for `ros2_colcon` |
   | `location` | `project` (default) or `outside` | where the records live (Target) |
   | `location_path` | absolute path | only with `outside`; default the sibling `<project clone>-records` in the clone's parent directory (D2a layout: a hosting directory holding the project clone and the records clone as sibling children) |
   | `tracking` | `project` (default when location is `project`), `untracked`, `repo` | Target's tracking choices; `repo` means the outside directory is a clone of a repository the user names |
   | `instructions` | `none` or `tracked` | recorded answer to "may the workspace offer agent instructions in tracked files"; readers key off the files, never this key |

   `ROS_ROOT_DIR` and any other variable stay in the legacy `.sh`.
3. **Commands** — the value is split on whitespace into argv and run without a shell, the same
   semantics as today minus globbing. Quotes, `& | ; < > $ ( ) \`` and backslash are refused with the message
   "point the key at a script": anything that is a list is a script, so `build=/path/to/build.sh`
   or `build=./scripts/build.sh` (relative to the project root, where every adapter already `cd`s).
   No separate pointer syntax: a script is a command whose first word is a path. A zero-footprint
   project keeps its script anywhere on the machine, by absolute path.
4. **Records combinations** — valid: (project, project) committed in the project; (project, untracked)
   in the project, ignored through `.git/info/exclude`; (outside, repo) a separate records
   repository; (outside, untracked) untracked on this machine. Refused by the validator, and the
   Target said to decide this when built: (outside, project), (project, repo), `location_path` without
   `outside`, a `location_path` inside the workspace checkout (D2a: records never go into the workspace
   repository; supersedes the Target's "don't prohibit" sentence).
   Mapping to D2a's four places and defaults: committed = (project, project), the default when the
   project accepts footprint; in-project-ignored = (project, untracked); records repo = (outside, repo),
   the opt-in that adds tracking; untracked on this machine = (outside, untracked), the default for zero
   footprint.
5. **What this issue writes (A2)** — the validator accepts all four combinations; the only
   combination any script of this issue writes is (project, project), i.e. nothing, the defaults.
   `project_setting.sh set` refuses a write that would store any other combination, naming the
   follow-up issue ("not honoured until the records lookup lands: every reader and writer still
   builds `<worktree>/.agent/work-plans/issue-N/`"). A hand-written file with another combination
   validates but `project_setting.sh check` and `register_project.sh --verify` flag it "not yet
   honoured". Settings are set in pairs, `set <name> location=outside tracking=untracked`, validated
   as the resulting whole file.
6. **Readers and precedence** — functions in `_project_registry.sh` (`project_file_path`,
   `project_file_entries`, `project_file_get`, `project_file_set`, `project_file_unset`), one writer
   (atomic temp file and rename, comments kept) and a thin CLI `project_setting.sh get|set|unset|list|check <name>`.
   The dispatcher parses the file once and sets `ACTIVE_PROJECT_BUILD/_TEST/_INSTALL/_BOOTSTRAP_URL`
   (shell variables, not exported, as `ACTIVE_PROJECT_ROLE` is). Per setting the order is: project file
   key, then the legacy `projects.d/<name>.sh` variable, then the shared `.agent/project_config.sh`.
   `single_project` (`_single_project_load_cmd`, `adapter_install`) and `ros2_colcon` (`_rc_bootstrap_url`,
   `adapter_install`) read the variable first. For a registered project that falls through to the
   shared file, the adapter prints one stderr note ("project 'x' has no build command of its own; using
   the shared .agent/project_config.sh"), so the gz4d-style silent fallback becomes loud now; the
   register gate (PR 2) refuses it. The `.sh` keeps working (p11 uses it); it is documented as legacy.
   `.sh` migration: PR 2's adoption copies its command/URL values into the project file and leaves
   the file alone; deleting the `.sh` reading belongs with #265 PR 4's p11 migration (see Consequences).
7. **Registry parser** — a name ending in `.sh` is refused (the project `x.sh` file would collide with
   project `x`'s legacy `.sh`).
8. **Design doc** — Registry and adapters Now gains the project file bullet; the Worktrees Target is
   rewritten: `location`/`tracking` move from "its registry entry" to the per-project file, a
   "built in #332 / built by the records lookup" marking per item (settings, validation, refusal to
   write: this issue; mechanisms 1 to 3 and honouring the values: the follow-up), the D2a layout
   sentence, the sentence on the named repository updated to D2a, and the mechanism-1 line numbers
   refreshed (the design text cites 342/344/387/479 for `dispatch_phase.sh`; the current ones are
   362, 364, 407, 499). The one rule and the acceptance test by shape stay.

### PR 2 — `register_project.sh` (workspace side, D1 step 1; owns unregister, A4)

Runs only from the main checkout (refuses from a linked worktree: no registry there), is not promoted to
the user tier (it writes the registry; `user_tier_scripts.txt`'s comment about "deferred to PR 4"
is edited). It never writes into the project, never relies on the `projects/<name>` default path
(#265 PR 4 drops it): the path is always written absolute.

- `register_project.sh <path|name> [<type>] [--name N] [--parent P] [--distro D] [--role R] [--worktrees W] [--set k=v]... [--no-setup] [--skip-run] [--install-user-tier] [--dry-run]`
  - Type omitted: `configs/manifest/` or a bootstrap URL means `ros2_colcon`, else `single_project`
    (#265's rule). The pseudo-type `project` (parent root) is accepted with `--default-instance`.
  - **Adopting a hand-registered project** is the same command on an existing path or name: the
    existing line is kept as is; a different type or path for a registered name is refused
    (no silent rewrite); a project with no file gets one (`.sh` values copied, detection below).
    Idempotent: a second identical run changes nothing and says so.
  - Registry line: written to a temp copy, re-parsed with `registry_entries_full`, then renamed.
  - Project file: command keys from `--set`, else from the legacy `.sh`, else `--detect` proposals
    (`register_project.sh --detect <path>`, read-only): only a single correct command is proposed
    (Makefile, Cargo, go.mod, package.json scripts, a `pytest` config); CMake needs configure then
    build, which is not one command, so nothing is proposed and the gate refuses until `build=` points
    at a script. That is the gz4d finding reproduced.
  - Per-type facts live in `.agent/project_types/<type>/registration.conf` (`required_commands`,
    whether `setup` runs, which verbs the gate runs), so the script does not branch on a type name
    (the design says workflow scripts do not). `single_project`: build and test required, run both,
    never `setup` (the clone is the user's; the checkout is verified: a git repo at the root; a missing
    remote is a warning, since a project without GitHub is supported). `ros2_colcon`: `setup` when the
    hosting directory is missing (needs `bootstrap_url`), `validate` only.
  - **Gate** (`registration_verify.sh <name> [--run]`, a new read-only script marked
    `# user-tier: inert`, also called by PR 3's audit): entry parses; project file valid; every required
    command is the project's own or declared `none` (the shared-fallback or missing is a refusal: a
    missing test command is refused); scoped `adapter --project N validate`; with `--run`, `adapter build`
    and `test`. A newly added entry that fails the gate is rolled back (line and file, restored on
    interrupt by a trap); an adopted one is reported NOT READY and kept. `--skip-run` ends in
    status `registered, build and test not run`.
  - **User tier**: if `~/.claude/agent-workspace-root` names this checkout, re-run
    `user_tier_install.sh` (ADR-0018: registration reuses the installer) and `--check`; a failure
    fails the gate. If the tier is not installed, a warning and the next-step line, not a failure, unless
    `--install-user-tier`. Last output lines are stable `STATUS=`, `NAME=`, `ROOT=`, `NEXT=` (D1 step 2:
    start a session at the root and run `/agent-workspace:onboard-project`).
  - `--dry-run` prints every step it would take, including the installer call, and writes nothing.
- `register_project.sh --remove <name> [--keep-settings] [--dry-run]`: refuses while the root has live
  worktrees (listed) or is a parent with instances; first disables the plugin in the root
  (`user_tier_install.sh` gains `--disable-root <name>`, reusing `uninstall_plugin_from`), then removes the
  line and the project file (printing its content so it can be restored). It leaves the project, its
  records (they are in the project, or outside it by the project's own setting) and memory alone, and says
  so; that answers the first half of C4.
- **#265 PR 4's plan is edited in this PR** (`.agent/work-plans/issue-265/plan.md`): delete the
  `register_project.sh` and `~/.claude/commands/register-project.md` rows in Files to Change and the
  §2 bootstrap-command bullet (D1: registration runs in a workspace session); replace §5 bullet 1
  and the §4 unregister bullet with "built by #332"; PR sequence item 3 loses the bootstrap-command
  clause and item 4 loses "`register_project.sh`" and gains "migrate p11 instances with #332's
  adoption path (their `.sh` values become project-file keys), then delete the `.sh` reading and the
  shared-config fallback for registered projects"; the Consequences row for `onboard-project` loses it
  (#332 PRs 3 and 4 rewrite that skill and `audit-project`; `gather-project-knowledge` remains #265's).
  ADR-0016 decision 5's parenthetical ("PR 4 scope") is changed to name #332 (a pointer, no decision).
- Design doc: Registry and adapters Now ("Registration is by hand" replaced), Sessions and roots Target
  (registration bullet moves to Now), Registry Target sentence, C4 narrowed (answered: yes, and what
  unregister does; left open: one project on two machines, mixed-flavour #310).

### PR 3 — the `onboard-project` rewrite (project side, D1 step 2, D3, D5)

1. **`project_integration_audit.sh [--dir D | --project N] [--format tsv|text]`** (read-only; promoted
   to the user tier with `project_setting.sh` and `registration_verify.sh`, each with the guard marker
   and a `test_user_tier_guard.sh` row; the writer `project_setting.sh set` carries the
   `registry_require_root` guard and writes only the file of the project whose root contains the cwd).
   Output: `category<TAB>id<TAB>severity<TAB>subject<TAB>detail`; it reports, never exits non-zero for
   findings. Categories 1 to 6 (7, skills with no `session_scope`, is not a per-project check):
   1. Project config overriding workspace config: same-named project skills/commands (identical or
      differing, line counts), `.claude/settings*.json` hooks and allow-rules, `.mcp.json`, `@` imports in
      CLAUDE.md.
   2. Instruction files that disagree on process: candidate lines only (feature branch vs worktree, "issue
      when one exists", commit/PR signature, build commands that differ from the project file's). The
      skill judges (Governance Layering: flag, never pick).
   3. Files the workspace writes into the project: the worktrees directory ignored; `.agent/work-plans/`
      accepted or ignored as the `location`/`tracking` pair says; no older `docs/work-plans/`; **records in
      two places** (the Target's one rule: the setting names the source of truth, a second copy is
      a finding).
   4. Ignore rules hiding agent files: `git ls-files --others --ignored --exclude-standard` over `.claude/**`,
      `.agents/**`, `AGENTS.md`, `CLAUDE.md`, plus `git check-ignore` probes of the paths the workspace
      would add (the `build/` rule that hid `.claude/skills/build/SKILL.md`).
   5. Conventions where workspace tools do not read them: rules in skills/instruction files with no
      `.agents/README.md` or `.agents/review-context.yaml`.
   6. Registration that does not work: `registration_verify.sh` (no `--run`), `session_root.sh --dir`
      names the project, user tier `--check`.
   Findings that would offer tracked files are `info` when `instructions=none`.
2. **Skill** (`session_scope: project` already; no manifest change): `/agent-workspace:onboard-project
   [--dry-run] [--reask <key>]`, no repo argument. Steps: resolve through `session_root.sh` (a workspace
   session, or an unregistered root, is told to run `register_project.sh` first); show the recorded
   choices and the audit summary; ask the footprint questions only for keys not yet set
   (`instructions`; records with the four D2a places, their defaults, and which are not yet
   available: until the lookup lands only (project, project) is stored and a zero-footprint answer is
   told plainly that records still land on feature branches); run the script; the judgement
   categories; offers (agent guide from the template, Direction section in the project's own roadmap,
   run `audit-project`), each a yes/no, "fix now" items batched into one project PR as today (for a
   project with no GitHub: edits left on a branch, nothing pushed); every write waits for a yes (D5).
   The hygiene checklist is kept in a labelled section until PR 4 moves it, so no merge leaves it homeless.
3. Design doc: Registry Target ("one way a project is registered and adapted" becomes register
   (workspace) plus onboard (project)); Sessions and roots Now gains the onboarding bullet; Documentation
   layers/roadmap line (`docs/roadmap.md`: "waits until onboarding asks") edited: the Direction section
   is an offer. `skill_workflows.md` rows and the AGENTS.md Script Reference rows (separate commit, Ask First).

### PR 4 — `audit-project` takes the hygiene checklist (D4)

- Pre-commit, CI, branch protection, Copilot auto-review, component labels, git-bug bridge, license
  headers move in with their fix approaches; `project/<repo-name>` lookup replaced by `session_root.sh`;
  the stale step 7 (workspace manifest, `project_knowledge` symlink) replaced by the integration
  script, report-only.
- **Style facts, not guesses**: `project_integration_audit.sh --facts` prints `github`, `issues`, `prs`,
  `windows`, `multi_component` from the remote, `gh repo view`, and `uname`. A table in the skill maps facts to the items
  they make moot (no GitHub: protection, Copilot, labels, bridge; no issues/PRs: labels, Copilot, bridge;
  Windows: git-bug and shell-hook items). Each skipped item is reported "skipped: <reason>", never dropped.
- Default stays report-only; the old fix now / open issue / skip flow moves with the checklist as the
  optional final step. Onboarding ends by offering this skill (D4).
- Design doc and `skill_workflows.md`: audit-project's job; change-log row.

### Follow-up issues to open (not in this issue)

1. **The records lookup** (Target mechanism 1, with 2 and 3): one function answering "where are the
   records for this project and issue", fed by the project file and used by every reader and writer:
   `progress_append.sh:87`, `review_progress.sh:112,268,290`, `dispatch_phase.sh:362,364,407,499`,
   `merge_pr.sh:682-683,839-847`, `_resolve_work_plans_dir.sh:66,90,97`, and the skills that cite the
   path; the gate's same-reviewed-state walk (`_bookkeeping.sh`) changing repository; untracked records as
   per machine and per clone; losing the history when `merge_pr.sh` removes the worktree. Its acceptance
   is the Target's: a single-repository web app with no GitHub issues or pull requests, records where its
   developer chooses; it exercises the lookup and tracking, not the merge gate. When it lands, onboarding
   and `project_setting.sh` accept the other combinations.
2. **Category 7 to #331** (comment on it, not a new issue): a test or `--check` for skills that touch
   project work but declare no `session_scope` (9 of 22 have none today, several by intent).

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/_project_registry.sh` | project-file reader/writer/validator; `.sh` name refusal; header |
| `.agent/scripts/project_setting.sh` (new, +x) | get/set/unset/list/check; the A2 refusal |
| `.agent/scripts/adapter` | parse project file once, `ACTIVE_PROJECT_*` variables; stop on malformed |
| `.agent/project_types/{single_project,ros2_colcon}/adapter.sh` | read the variables first; fallback note |
| `.agent/project_types/<type>/registration.conf` (new, 2) | per-type registration facts (PR 2) |
| `.agent/scripts/register_project.sh`, `registration_verify.sh` (new, +x) | PR 2 |
| `.agent/scripts/user_tier_install.sh` | `--disable-root <name>` (PR 2) |
| `.agent/scripts/project_integration_audit.sh` (new, +x) | PR 3, `--facts` in PR 4 |
| `.agent/user_tier_scripts.txt` | `project_setting.sh`, `registration_verify.sh`, audit script (PR 3); comment fixed (PR 2) |
| `.agent/scripts/dashboard.sh`, `validate_workspace.py` | report a malformed project file (validate through the adapter's delegation) |
| `.agent/projects.local.example` | the project file, keys, precedence, `.sh` as legacy |
| `.claude/skills/onboard-project/SKILL.md`, `audit-project/SKILL.md` | rewrite (PR 3), checklist move (PR 4) |
| `docs/design.md`, `docs/roadmap.md`, `.agent/knowledge/skill_workflows.md`, `.agent/work-plans/issue-265/plan.md`, ADR-0016 decision 5 pointer | per PR, as above |
| `AGENTS.md` | Script Reference rows (Ask First; own commit in PR 2 and PR 3) |
| `.agent/scripts/tests/` | `test_project_file.sh`, `test_register_project.sh`, `test_integration_audit.sh` (all new, `chmod +x`); extend `test_user_tier_guard.sh`, `test_user_tier_install.sh`, `test_project_registry.sh`, `test_skill_paths.sh` |

## Prior Art

The D2 check (git config and `info/exclude`, direnv, VS Code, Claude Code scopes, systemd/sysctl `conf.d`,
EditorConfig) is recorded on the issue. Taken from this repository: the registry parser's error style and
key list, `_settings.sh`'s main-checkout handling, `user_tier_install.sh` (reused, not duplicated), the
sandbox-with-stub-`claude` test pattern, `wt_ensure_exclusion` for `.git/info/exclude`. Rejected: shell
quoting inside values (a second grammar to get wrong), a type branch in `register_project.sh`
(replaced by `registration.conf`), sourcing the project file (it is data, not code).

## Serves

Light touch on projects and Easy to use (`README.md#workspace-goals`); `docs/design.md#registry-and-adapters`,
with `docs/design.md#sessions-and-roots` and `docs/design.md#worktrees`.

## Design Picture

Changes it, in four sections, each in the PR that makes it true: Registry and adapters (Now and Target),
Sessions and roots (Target to Now), Worktrees (Target: settings move to the project file, built versus
follow-up marked), Open questions C4 (narrowed, not closed: two machines and #310 remain), plus change-log rows.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Leave in a project only what it chose to carry | `register_project.sh` writes nothing in a project; D3 minimum is nothing; footprint is asked, defaults derived |
| Enforce what matters, as simply as possible | one grammar, validated key list, unknown keys fail; the gate is a script; scripts not prose |
| Only what's needed | six keys; `ROS_ROOT_DIR`, `role`, `distro`, `worktrees` untouched |
| Put each thing at the level it applies to | per-type facts in `registration.conf`; machine settings per machine; the audit shared by two skills |
| Keep one current design / A change includes its consequences | per-PR design edits, #265 plan, ADR pointer, user tier, tests |
| Test what breaks | synthetic sandbox projects and a stub `claude` only; never a real checkout |
| Small steps | four PRs, then a separate lookup issue |
| Verify before claiming | line numbers re-grepped for this plan; design text's stale ones refreshed |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0011 adapter contract | Yes | verbs unchanged; `validate_adapter.sh` passes; `registration.conf` is data, not a verb |
| 0013 progress.md | Yes | shape unchanged; location is the follow-up |
| 0016 session roots, user tier | Yes | decision 5 built; new promoted scripts guarded and inert outside roots |
| 0017 design document | Yes | per-PR edits |
| 0018 plugin delivery | Yes | registration re-runs the installer; onboarding runs at the project root |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| Registry grammar / project file | example file, header, dashboard, validate | Yes (PR 1) |
| `register_project.sh` ownership | #265 plan PR 4 scope, ADR-0016 pointer, design | Yes (PR 2) |
| Skill rewrites | `skill_workflows.md`, `test_skill_paths.sh`, `make generate-user-tier-skills` (no scope change) | Yes (PR 3, 4) |
| Reading `.sh` and the shared fallback | removal after p11 migrates | No: #265 PR 4 (edited in PR 2) |
| `role`/`distro`/`worktrees` into the project file | | No: later cleanup (owner) |
| Records lookup, `sitrep` over every root with a Direction section | | No: follow-up / existing roadmap row |

## Open Questions

- **Q1 — which directory is registered when records sit beside the project (D2a layout).** I assume the
  project clone stays the registered root and the records clone is its sibling `<clone>-records` in the
  clone's parent; no change to session roots. The alternative, registering the hosting directory that
  holds both, needs `single_project` to support a nested checkout. Confirm the first.
- **Q2 — `registration.conf` per type** instead of a type branch inside `register_project.sh`. Say if you prefer the branch.
- **Q3 — `audit-project` after D4** stays report-only by default and offers the old fix now / open issue /
  skip flow at the end, so hygiene fixes still have an owner. Confirm.
- **Q4 — where a project's Direction section lives** (offer in PR 3): I propose asking, defaulting to
  an existing `docs/roadmap.md` or `ROADMAP.md`, else creating `docs/roadmap.md`; `sitrep` over project roots is a separate roadmap row.

## Estimated Scope

Four PRs (about: PR 1 medium, PR 2 large, PR 3 large, PR 4 small), plus two follow-ups. Gate for each: its
own suite and `run_script_tests.sh` green, `make validate`, `check_design_anchors.sh`.
