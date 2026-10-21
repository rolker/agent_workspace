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

Revision 1 (after plan review round 1, see "Plan Review Resolution"): the mechanism is settled (two settings,
four combinations, one lookup) but **the default combination and the default layout of an outside path are
open by owner decision** (issue note, 2026-10-13): they are provisional, held in one function, and chosen
when this is built. Records in the workspace repository are **refused** by owner decision (checked by the
named repository's remote URL).

Revision 2 (owner's checkpoint `21c8e15f`, "Proceed; fold D6, Q5 and the suggestions into the plan first"; no
third plan review, the pre-push code review sees it): **D6**, onboarding work is queued in the project's
roadmap when the user approves (PR 3 offers, PR 4 audit outcome); **Q5**, the records-repository refusal
also recognises a copy of the workspace by its contents (a records repository must not be a workspace);
and plan review round 2's four suggestions (an absent records pair resolves to (project, project); a
local-path or `file://` remote at the workspace is refused; where `ros2_colcon` `setup` sits in
registration and what a failure keeps; where each of the three gz4d findings the audit script does not
reproduce is covered).

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

0. **First step: open the records-lookup follow-up issue** (full text in "Follow-up issues" below), so
   `project_setting.sh`'s refusal message and the Worktrees Target edit cite its real number.

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
   | `location_path` | any absolute path | only with `outside`; when omitted the **provisional** default comes from `project_records_default` (item 4). Candidates for that default, none decided: a sibling `<clone>-records` (the Target's wording) or a hosting directory holding the project clone and the records clone as children. Either is just another `location_path` value later; the registered root stays the project clone |
   | `tracking` | `project`, `untracked`, `repo` | Target's tracking choices (default: provisional, item 4); `repo` means the outside directory is a clone of a repository the user names, never the workspace's own (item 4) |
   | `instructions` | `none` or `tracked` | recorded answer to "may the workspace offer agent instructions in tracked files"; readers key off the files, never this key |

   `ROS_ROOT_DIR` and any other variable stay in the legacy `.sh`.
3. **Commands** — the value is split on whitespace into argv and run without a shell, the same
   semantics as today minus globbing. Quotes, `& | ; < > $ ( ) \`` and backslash are refused with the message
   "point the key at a script": anything that is a list is a script, so `build=/path/to/build.sh`
   or `build=./scripts/build.sh` (relative to the project root, where every adapter already `cd`s).
   No separate pointer syntax: a script is a command whose first word is a path. A zero-footprint
   project keeps its script anywhere on the machine, by absolute path.
4. **Records combinations and the provisional default** — valid: (project, project) committed in the
   project; (project, untracked) in the project, ignored through `.git/info/exclude`; (outside, repo) a
   separate records repository; (outside, untracked) untracked on this machine (D2a's four places).
   Refused by the validator (the Target left this to be decided when built): (outside, project),
   (project, repo), `location_path` without `outside`.
   - **Workspace repository refused (owner, 2026-10-13: a fork of the workspace would carry other
     projects' records, and a PR sent back would bring them past the merge gate's bookkeeping
     exemption). The plain rule: a records repository must not be a workspace.** `project_records_check`
     refuses `tracking=repo` when the records clone at `location_path` is recognised as the workspace or
     a copy of it, by any of three checks, with a message that names the check and points at a separate
     records repository or the machine-local option:
     1. *Remote URL*: `git remote get-url` for every remote of the records clone and of the workspace
        checkout, normalised to host and `owner/repo` (https, ssh and scp forms, trailing `.git`, case);
        a match refuses.
     2. *Local path* (round-2 suggestion): a records remote that is a local path or a `file://` URL is
        resolved, and its git common directory compared with the workspace checkout's; a remote pointing
        at the workspace checkout or one of its worktrees refuses (`git clone ~/agent_workspace records`).
     3. *Contents* (owner answer to Q5, "Contents: it IS a workspace"): the records repository contains the
        workspace's marker files, `.claude-plugin/plugin.json` naming the `agent-workspace` plugin or
        `.agent/user_tier_scripts.txt`, in its working tree or its `HEAD` commit. Either marker refuses.
        This catches a clone of a fork under any owner or host, offline. No root-commit or `gh` lineage
        check (owner).
     The checks are about the records repository, never a path rule on `location_path`, so untracked
     records under the workspace's ignored scratchpad (`.agent/scratchpad/`, where the inbox and sit-rep
     record already live) validate. A records directory not yet cloned is "unverifiable until cloned",
     reported by `check`, not refused.
   - **Defaults are provisional and live in one place.** `project_records_default <root> <name>
     [accepts-footprint|zero-footprint]` in `_project_registry.sh` returns the default combination and the
     outside-path layout for a project. The validator (to fill omitted keys), the audit (to compare what
     a project does with what the default would be) and the later lookup all call it; no other file
     writes a default or a layout. For this issue it returns (project, project) for a project that accepts
     footprint and nothing else is claimed: the zero-footprint combination and the outside layout are
     returned as marked-provisional values (their initial values are chosen when this is built, with the
     owner), and changing them touches that function and its test only. **An absent `location`/`tracking`
     pair always resolves to (project, project)** (round-2 suggestion): the validator and every reader
     fill omitted keys in accepts-footprint mode, which is the Target's default and what every reader
     does today; nothing stored says a project is zero-footprint, so the zero-footprint mode only feeds
     onboarding's proposal (PR 3) and is never used to resolve a file. `test_project_file.sh` asserts it
     (a file with neither key reads back (project, project) through the resolver). Tests assert
     through the function, never a literal path or combination. The design text, onboarding wording and
     `projects.local.example` call every default "provisional"; they may be revised after the first real
     onboarding.
5. **What this issue writes (A2)** — the validator accepts all four combinations; the only
   combination any script of this issue writes is (project, project), i.e. nothing, the defaults.
   `project_setting.sh set` refuses a write that would store any other combination, naming the
   follow-up issue ("not honoured until the records lookup lands: every reader and writer still
   builds `<worktree>/.agent/work-plans/issue-N/`"). A hand-written file with another combination
   validates but `project_setting.sh check` and `register_project.sh --verify` flag it "not yet
   honoured". Settings are set in pairs, `set <name> location=outside tracking=untracked`, validated
   as the resulting whole file. The refusal message names the follow-up issue, which is opened as PR 1's first
   step so the number exists to cite.
6. **Readers and precedence** — functions in `_project_registry.sh` (`project_file_path`,
   `project_file_entries`, `project_file_get`, `project_file_set`, `project_file_unset`), one writer
   (atomic temp file and rename, comments kept) and a thin CLI `project_setting.sh get|set|unset|list|check <name>`.
   The dispatcher parses the file once and sets `ACTIVE_PROJECT_BUILD/_TEST/_INSTALL/_BOOTSTRAP_URL`
   (shell variables, not exported, as `ACTIVE_PROJECT_ROLE` is). Per setting the order is: project file
   key; for a key the file leaves unset, the legacy `projects.d/<name>.sh` variable when that file
   exists, otherwise the shared `.agent/project_config.sh`. An existing legacy `.sh` stays the whole
   legacy layer, as on main (amended 2026-10-21 in the pre-push fix round, host's choice: the `.sh`
   reading goes with #265 PR 4, and a per-variable fall-through would change legacy behaviour here).
   `single_project` (`_single_project_load_cmd`, `adapter_install`) and `ros2_colcon` (`_rc_bootstrap_url`,
   `adapter_install`) read the variable first. For a registered project that falls through to the
   shared file, the adapter prints one stderr note ("project 'x' has no build command of its own; using
   the shared .agent/project_config.sh"), so the gz4d-style silent fallback becomes loud now; the
   register gate (PR 2) refuses it. The `.sh` keeps working (p11 uses it); it is documented as legacy.
   `.sh` migration: PR 2's adoption copies its command/URL values into the project file and leaves
   the file alone; deleting the `.sh` reading belongs with #265 PR 4's p11 migration (see Consequences).
7. **Registry parser** — a name ending in `.sh` is refused (the project `x.sh` file would collide with
   project `x`'s legacy `.sh`).
8. **AGENTS.md** — a Script Reference row for `project_setting.sh` in its own commit (Ask First; owner
   approval on the PR), as PR 2 and PR 3 do for theirs.
9. **Design doc** — Registry and adapters Now gains the project file bullet; the Worktrees Target is
   rewritten: `location`/`tracking` move from "its registry entry" to the per-project file, a
   "built in #332 / built by the records lookup" marking per item (settings, validation, refusal to
   write: this issue; mechanisms 1 to 3 and honouring the values: the follow-up), every default and layout marked provisional (naming `project_records_default`), the
   Target's "I don't want to prohibit it, but I also don't want to encourage it" sentence rewritten:
   a records repository must not be a workspace (refused by remote URL, local path and contents), with the
   fork and PR reason, and the mechanism-1 line numbers
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
    `register_project.sh` refuses a type that has no `registration.conf`; `validate_adapter.sh` checks
    that every type has one with the required keys (so it runs in pre-commit and CI, with a case in its
    test); the Registry and adapters Now bullet names the file beside the 12-verb contract.
  - **Order (so a failed registration leaves nothing behind)**: (1) write the registry line and the
    project file; (2) static gate `registration_verify.sh <name>`; (3) `register_project.sh` itself
    runs `adapter --project N build` and `test` (the verbs `registration.conf` names; skipped with
    `--skip-run`); (4) only then the user-tier installer and `registration_verify.sh <name> --user-tier`.
    Build or test fail in (2) or (3): the line and file are removed (restored on interrupt by a trap) and
    the installer never ran, so no plugin enable exists in the root.
    **`ros2_colcon` `setup`** (round-2 suggestion) runs between (1) and (2), when `registration.conf` says
    the type runs `setup` and the hosting directory is missing: the adapter needs the registry line to
    resolve `--project`, and the static gate's `validate` needs the checkout. A later failure removes the
    line and file as above, but **keeps a hosting directory that `setup` created** and reports it on the
    last lines (`KEPT=<dir>`, "created by setup; remove it, or re-run register_project.sh to reuse it"):
    its clones are slow to redo, removing a tree is not undoable, and a re-run adopts it because `setup`
    is a no-op on an existing manifest. A directory that existed before the run is never touched.
    `test_register_project.sh` covers it with a stub `setup` that creates the directory and a failing
    `validate`: no registry line, no project file, the directory present and named. The installer fails in (4):
    the rollback also calls `user_tier_install.sh --disable-root <name>` before removing the line (the
    installer can fail after a partial enable). An adopted (already registered) project is reported NOT
    READY and kept, never rolled back. `--skip-run` ends in status `registered, build and test not run`.
  - **Static gate** `registration_verify.sh <name> [--user-tier]` is **read-only** (M5): it never runs the
    project's build or test, so it keeps the `# user-tier: inert` marker and is promoted in PR 3 for the
    audit's category 6. It checks: entry parses; project file valid (and a records combination other than
    the default flagged "not yet honoured"); every command the type requires is the project's own or
    declared `none` (the shared-fallback or missing is a refusal: a missing test command is refused);
    `registration.conf` exists; scoped `adapter --project N validate` (read-only); with `--user-tier`,
    `user_tier_install.sh --check` and `session_root.sh --dir <root>` naming the project.
  - **User tier**: if `~/.claude/agent-workspace-root` names this checkout, run `user_tier_install.sh`
    (ADR-0018: registration reuses the installer; step 4 above). If the tier is not installed, a warning
    and the next-step line, not a failure, unless `--install-user-tier`. Last output lines are stable
    `STATUS=`, `NAME=`, `ROOT=`, `NEXT=` (D1 step 2: start a session at the root and run
    `/agent-workspace:onboard-project`).
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
   to the user tier with `project_setting.sh` and the read-only `registration_verify.sh`, each with its
   guard or inert marker and a `test_user_tier_guard.sh` row; the writer `project_setting.sh set` carries
   the `registry_require_root` guard and writes only the file of the project whose root contains the cwd).
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
   6. Registration that does not work: `registration_verify.sh --user-tier` (read-only), `session_root.sh --dir`
      names the project, user tier `--check`.
   Findings that would offer tracked files are `info` when `instructions=none`.
2. **Skill** (`session_scope: project` already; no manifest change): `/agent-workspace:onboard-project
   [--dry-run] [--reask <key>]`, no repo argument. Steps: resolve through `session_root.sh` (a workspace
   session, or an unregistered root, is told to run `register_project.sh` first); show the recorded
   choices and the audit summary; ask the footprint questions only for keys not yet set
   (`instructions`; records with the four D2a places and the **provisional** default from
   `project_records_default`, saying it is provisional and overridable, and which places are not yet
   available: until the lookup lands only (project, project) is stored and a zero-footprint answer is
   told plainly that records still land on feature branches); run the script; the judgement
   categories; offers, **only when `instructions=tracked`** (when unset the question is asked first;
   `none` means no offers): agent guide from the template, Direction section in the project's own roadmap
   (an existing `docs/roadmap.md` or `ROADMAP.md`, else a new `docs/roadmap.md`; design.md already says a
   project's roadmap may carry `## Direction` by its own choice), and run `audit-project` (always
   offered, it writes nothing), each a yes/no, "fix now" items batched into one project PR as today (for a
   project with no GitHub: edits left on a branch, nothing pushed); every write waits for a yes (D5).
   **Queue in the roadmap (D6)** — owner, verbatim: "all that work should be cued up in the roadmap, if the
   user approves, so that it can get tackled maybe as other issues are resolved". Every audit finding
   and every accepted offer is answered with one of **fix now / open issue / queue in the roadmap /
   skip**. Queued items become rows of an `## Onboarding` section in the project's roadmap table (an
   existing `docs/roadmap.md` or `ROADMAP.md`, else a new `docs/roadmap.md`; for a zero-footprint
   project, the roadmap is kept with the records, so until the records lookup lands that choice is not
   offered to a zero-footprint project and the skill says so), with an issue per row when the project
   uses issues (the `--facts` `issues` fact once PR 4 adds it; until then the skill asks). Rows are picked
   up like any other open roadmap row. Writing the section is itself a write, so it waits for the same
   yes and rides in the same batched project PR. A pace rule (how many queued rows to take on alongside
   other work) is a later item, not this issue.
   The hygiene checklist is kept in a labelled section until PR 4 moves it, so no merge leaves it homeless.
3. Design doc: **Sessions and roots Now names the exception to "a session works only under its root"**:
   a project session writes `.agent/projects.d/<name>` in the workspace checkout (through
   `project_setting.sh set`, guarded to the session's own project) because that file is per-machine,
   gitignored workspace configuration the project's onboarding owns, not a tracked change to the
   workspace; nothing else a project session does leaves its root. Registry Target ("one way a project is registered and adapted" becomes register
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
  optional final step and gains **queue in the roadmap** (D6): the same `## Onboarding` roadmap section
  and issue-per-row rule as PR 3, each queued row a yes. Onboarding ends by offering this skill (D4).
- Design doc and `skill_workflows.md`: audit-project's job; change-log row.

### Follow-up issues to open (not in this issue)

1. **The records lookup — opened as PR 1's first step.** Text (the issue body):
   - *Mechanism 1, one lookup*: "where are the records for this project and issue", fed by the project
     file (`location`, `location_path`, `tracking`, defaults from `project_records_default`) and used by
     every reader and writer: `progress_append.sh:87`, `review_progress.sh:112,268,290`,
     `dispatch_phase.sh:362,364,407,499`, `merge_pr.sh:682-683,839-847`,
     `_resolve_work_plans_dir.sh:66,90,97`, and the skills that cite the path.
   - *Mechanism 2*: the merge gate's same-reviewed-state rule (`_bookkeeping.sh`, shared with
     `review_progress.sh sources`) reads the record from where it lives and checks the project commit the
     entry names, so the walk changes repository.
   - *Mechanism 3*: untracked records are per machine and per clone; a second machine or a fresh clone
     starts with no timeline; `merge_pr.sh` removing the issue worktree must not lose a timeline that lives
     in the worktree (the `.git/info/exclude` case).
   - *The one rule*: when records exist in two places, the setting names the source of truth.
   - *Acceptance by shape* (the Target's, both halves): a colleague's single-repository web app with no
     GitHub issues or pull requests, records where its developer chooses; it exercises the lookup and
     tracking, **not the merge gate (mechanism 2), which a project with pull requests has to exercise**.
   - *Unsettled, to decide there*: for `tracking=repo`, who commits to the records repository, on which
     branch, and when it is pushed; `cross_model_review.sh --work-plans-dir` as an existing override of
     `_resolve_work_plans_dir.sh`; package-repository issues (`owner/repo#N`), which have no timeline today
     and stay so; the default combination and outside layout (provisional, one function, owner undecided).
   - *Rules carried*: the records location counts as the root's own, as a `worktrees=` override already does
     (`registry_worktree_dir`, `session_root.sh`), so a session writing records there keeps "works only
     under its root" (named as a bend of that rule); a records repository must not be a workspace
     (owner, 2026-10-13; refused by remote URL, local path and contents, built in #332 PR 1); until it lands
     only (project, project) is written.
   - *Zero-footprint roadmap (D6)*: a zero-footprint project's `## Onboarding` roadmap rows live with its
     records, so onboarding offers "queue in the roadmap" to such a project only once this lands.
   - *When it lands*: onboarding and `project_setting.sh` accept the other combinations.
2. **Category 7 to #331** (comment on it, not a new issue): a test or `--check` for skills that touch
   project work but declare no `session_scope` (9 of 22 have none today, several by intent).

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/_project_registry.sh` | project-file reader/writer/validator; `project_records_default` (the one provisional-default function) and `project_records_check` (combinations; a records repository that is a workspace refused by remote URL, local path or contents); `.sh` name refusal; header |
| `.agent/scripts/project_setting.sh` (new, +x) | get/set/unset/list/check; the A2 refusal |
| `.agent/scripts/adapter` | parse project file once, `ACTIVE_PROJECT_*` variables; stop on malformed |
| `.agent/project_types/{single_project,ros2_colcon}/adapter.sh` | read the variables first; fallback note |
| `.agent/project_types/<type>/registration.conf` (new, 2) | per-type registration facts (PR 2) |
| `.agent/scripts/register_project.sh`, `registration_verify.sh` (new, +x) | PR 2; `registration_verify.sh` read-only |
| `.agent/scripts/validate_adapter.sh` | every type has a `registration.conf` with the required keys (PR 2) |
| `.agent/scripts/user_tier_install.sh` | `--disable-root <name>` (PR 2) |
| `.agent/scripts/project_integration_audit.sh` (new, +x) | PR 3, `--facts` in PR 4 |
| `.agent/user_tier_scripts.txt` | `project_setting.sh`, `registration_verify.sh`, audit script (PR 3); comment fixed (PR 2) |
| `.agent/scripts/dashboard.sh`, `validate_workspace.py` | report a malformed project file (validate through the adapter's delegation) |
| `.agent/projects.local.example` | the project file, keys, precedence, `.sh` as legacy |
| `.claude/skills/onboard-project/SKILL.md`, `audit-project/SKILL.md` | rewrite (PR 3), checklist move (PR 4) |
| `docs/design.md`, `docs/roadmap.md`, `.agent/knowledge/skill_workflows.md`, `.agent/work-plans/issue-265/plan.md`, ADR-0016 decision 5 pointer | per PR, as above |
| `AGENTS.md` | Script Reference rows (Ask First; own commit in each of PR 1, PR 2, PR 3) |
| `.agent/scripts/tests/` | `test_project_file.sh`, `test_register_project.sh`, `test_integration_audit.sh` (all new, `chmod +x`); extend `test_user_tier_guard.sh`, `test_user_tier_install.sh` (`--disable-root`), `test_project_registry.sh`, `test_skill_paths.sh`, the `validate_adapter.sh` suite. See "Acceptance to test" |

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
| Leave in a project only what it chose to carry | `register_project.sh` writes nothing in a project; D3 minimum is nothing; footprint is asked, the records default is provisional and overridable |
| Enforce what matters, as simply as possible | one grammar, validated key list, unknown keys fail; the gate is a script; scripts not prose |
| Only what's needed | six keys; `ROS_ROOT_DIR`, `role`, `distro`, `worktrees` untouched |
| Put each thing at the level it applies to | per-type facts in `registration.conf`; machine settings per machine; the audit shared by two skills |
| Keep one current design / A change includes its consequences | per-PR design edits, #265 plan, ADR pointer, user tier, tests; defaults marked provisional, not recorded as decided |
| Name the rule before bending it | two bends of "a session works only under its root" named: a project session writing `.agent/projects.d/<name>` (PR 3 design edit), and an outside records path counting as the root's own like `worktrees=` (follow-up issue text) |
| Test what breaks | synthetic sandbox projects and a stub `claude` only; never a real checkout |
| Small steps | four PRs, then a separate lookup issue |
| Verify before claiming | line numbers re-grepped for this plan; design text's stale ones refreshed |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0011 adapter contract | Yes | verbs unchanged; `validate_adapter.sh` passes; `registration.conf` is data, not a verb |
| 0013 progress.md | Yes | shape unchanged; location is the follow-up |
| 0016 session roots, user tier | Yes | decision 5 built; decision 6: `project_setting.sh` and the audit carry a `registry_require_root` guard or the inert marker, `registration_verify.sh` is read-only so its inert marker is true |
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
| Records lookup | follow-up issue, opened as PR 1's first step | No: follow-up |
| `sitrep` over every root with a Direction section | existing roadmap row; the row notes a project's roadmap may be `ROADMAP.md` | No: existing row, edited in PR 3 |

## Acceptance to test

Every fixture is synthetic and built in a sandbox workspace with a stub `claude` (never a real checkout).
The "hand-registered fixture" is a synthetic project shaped like gz4d on 2026-09-23: a one-line registry
entry and no project file or `.sh`; a CMake layout; four project skills sharing names with workspace
skills; an instruction file that says feature branches and "issue when one exists"; a `.gitignore` with
an unanchored `build/` that hides a committed-looking `.claude/skills/build/SKILL.md`; no ignore rule for the
worktrees directory; a `docs/work-plans/`; no `.agents/`, pre-commit or CI.

| Issue acceptance item | Test |
|---|---|
| Registering a new `single_project` needs no hand edits to `projects.local` or `projects.d/` | `test_register_project.sh`: one call produces the registry line and project file; the files are asserted, nothing hand-written |
| Run against the 2026-09-23 gz4d shape reproduces every listed finding without being told | `test_integration_audit.sh` on the hand-registered fixture: one asserted finding id per category (duplicate skills, process disagreement, unignored worktrees dir, `build/` hiding agent files, rules not in `.agents/`, `docs/work-plans/`, fallback commands / no test command); a clean fixture yields none |
| The three listed gz4d findings the audit script does not reproduce (round-2 suggestion; "reproduces every finding" claims only what is tested) | not script-tested here, each covered elsewhere: **no pre-commit or CI** → the hygiene checklist `audit-project` takes in PR 4 (skill text, not a script test); **`validate` failing on unrelated projects** → fixed by #330 (scoped `adapter validate`, already merged); **`research` missing in project sessions** → audit category 7, carried by #331 |
| Idempotent re-run | `test_register_project.sh`: second identical call changes no byte and says so; adopting the hand-registered fixture is the same path |
| Dry-run makes no changes | `test_register_project.sh`: `--dry-run` for register and remove; registry, project file, stub-claude log and `~/.claude` all unchanged |
| Missing test command refused | `test_register_project.sh`: no `test=` and no detection means refusal; `test=none` accepted; the CMake fixture is refused until `build=` names a script |
| A failing check blocks "registered" | `test_register_project.sh`: failing `validate`, failing build, failing test each leave no registry line, no project file and no plugin enable (stub-claude log empty); installer failure after a passing build triggers `--disable-root` and the same cleanup |
| Works from a project-rooted session for a project registered outside the workspace | `test_integration_audit.sh` and `test_user_tier_guard.sh`: audit, `project_setting.sh`, `registration_verify.sh` run with the cwd in a sandbox project outside the sandbox workspace; refuse from an unregistered directory |
| Records settings (acceptance by shape: single repository, no GitHub issues or PRs) | `test_project_file.sh`: a no-remote web-app-shaped fixture validates with every combination; a records repository that is a workspace is refused three ways (its remote URL is the sandbox workspace's; its remote is a local path or `file://` URL to the sandbox workspace or one of its worktrees; it contains the workspace marker files, with an unrelated remote); untracked records under the sandbox scratchpad validate; a file with no `location`/`tracking` resolves to (project, project); defaults asserted through `project_records_default` |
| `ros2_colcon` `setup` kept on a later failure (PR 2) | `test_register_project.sh`: stub `setup` creates the hosting directory, `validate` fails; no registry line or project file, the directory kept and named on `KEPT=` |
| The first real use (gz4d onboarding run) | not a test: the separate run you named, after PR 3 |

## Open Questions

- **Q1 — withdrawn.** The project clone stays the registered root (the review found no reason that forces
  a change); a hosting-directory layout is just another `location_path` value later, and the layout default
  is provisional and open (owner note).
- **Q2 — `registration.conf` per type: confirmed** by plan review (consistent with "workflow scripts do not
  branch on the project type"); now checked to exist (`register_project.sh`, `validate_adapter.sh`).
- **Q3 — `audit-project` report-only by default, fix flow at the end: confirmed** by plan review.
- **Q4 — Direction section location: kept** (existing `docs/roadmap.md` or `ROADMAP.md`, else a new
  `docs/roadmap.md`), and offered only when `instructions=tracked`.
- **Q5 — answered** (owner, "Contents: it IS a workspace"): a records repository must not be a workspace,
  recognised by its contents (the workspace's marker files) beside the remote-URL and local-path checks;
  no root-commit or `gh` lineage check. See PR 1 item 4.
- **Open by the owner, not a question to him now:** the provisional default combination and outside layout;
  chosen when this is built, revisable after the first real onboarding.

## Plan Review Resolution

Round 1 (`dc77392d`) and the owner's checkpoint (`b9ab8403`).

| Finding | Resolution |
|---|---|
| M1 defaults decided | Mechanism kept; one function `project_records_default` in `_project_registry.sh` returns the provisional default combination and outside layout, called by validator, audit and later the lookup; tests assert through it; design text, onboarding wording and example file say "provisional"; every sentence presenting the sibling layout or (outside, untracked) as decided is gone; Q1 withdrawn |
| M2 workspace repository | Refused by remote URL (`project_records_check`), not by path; scratchpad-untracked allowed; the old path check and "supersedes" sentence are gone; PR 1's design edit rewrites the Target's "don't prohibit" sentence with the fork and PR reason; known fork limit stated (Q5) |
| M3 unnamed bends of the session-root rule | PR 3's design edit names the `.agent/projects.d/<name>` write from a project session; the follow-up issue text states outside records paths count as the root's own like `worktrees=` |
| M4 rollback leaves the plugin enabled | Installer runs only after static gate, build and test pass; rollback after an installer failure also calls `--disable-root`; tests for both paths |
| M5 promoted script not inert | `registration_verify.sh` is read-only (no `--run`; `--user-tier` only reads); `register_project.sh` runs build and test itself; the inert marker stays true |
| S6 follow-up text | Full text in "Follow-up issues" (both halves of the acceptance, the one rule, the unsettled points, the override and package-repo cases); opened as PR 1's first step so PR 1 cites its number |
| S7 `registration.conf` unchecked | `register_project.sh` refuses a type without it; `validate_adapter.sh` checks it; Registry and adapters Now names it beside the verb contract |
| S8 AGENTS.md row in PR 1 | PR 1 item 8, own commit |
| S9 acceptance mapping | "Acceptance to test" table and the hand-registered synthetic fixture |
| S10 offers gated | Offers only when `instructions=tracked`; sit-rep follow-up row notes `ROADMAP.md` |

Round 2 (`2bf12b40`, ready, four suggestions) and the owner's checkpoint (`21c8e15f`).

| Finding | Resolution |
|---|---|
| R2-1 absent records pair | Always (project, project); zero-footprint mode feeds only onboarding's proposal; `test_project_file.sh` case (PR 1 item 4) |
| R2-2 local-path remotes; Q5 | Local-path and `file://` remotes resolved and compared with the workspace's git common directory; Q5 answered by the owner: contents check on the marker files; no lineage check (PR 1 item 4) |
| R2-3 `ros2_colcon` `setup` | Runs between registration steps (1) and (2); a directory it created is kept and reported on `KEPT=`; test (PR 2) |
| R2-4 gz4d findings not reproduced | Acceptance table row naming PR 4, #330 and #331 |
| D6 (owner) | "Queue in the roadmap" beside fix / issue / skip in PR 3 and PR 4; `## Onboarding` roadmap section, issue per row when the project uses issues; pace rule later |

## Estimated Scope

Four PRs (about: PR 1 medium, PR 2 large, PR 3 large, PR 4 small), plus the records-lookup follow-up
(opened first) and the #331 comment. Gate for each: its own suite and `run_script_tests.sh` green,
`make validate`, `check_design_anchors.sh`.
