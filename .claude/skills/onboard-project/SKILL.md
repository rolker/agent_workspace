---
name: onboard-project
description: Onboard a registered project from a session at its root. Shows the recorded choices, asks the footprint questions not yet answered, runs the integration audit (how the project and the workspace fit together), makes the offers the footprint allows, and answers each finding with fix now, open issue, queue in the roadmap, or skip. Every write waits for a yes.
session_scope: project
---

# Onboard Project

## Workspace root

This skill can run in a **project** session — a session started in a project
checkout, not in the workspace. There, `.agent/scripts/...` does not resolve:
those paths belong to the workspace, and the cwd is somewhere else entirely.

Every workspace path below is therefore written `$WS_ROOT/.agent/scripts/...`.
Resolve `$WS_ROOT` at the head of each command chain, because shell state does
not persist between tool calls:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
"$WS_ROOT/.agent/scripts/<script>" ...
```

`~/.claude/agent-workspace-root` is written by
`.agent/scripts/user_tier_install.sh`. It is a plain file, not an environment
variable and not `SessionStart` hook output — hook stdout is context text and
never reaches a tool call's shell (ADR-0016).

**The `|| echo .` fallback is required, not decoration.** The user tier is
optional — `--check` and ADR-0016 both say so — and on a machine without it
the file does not exist. A bare `cat` would leave `$WS_ROOT` empty and turn
every command below into `/.agent/scripts/...`, which is worse than the
relative path it replaced. With the fallback, `$WS_ROOT` is `.` and the
root check in step 1 says this is no project session.

## Usage

```
/agent-workspace:onboard-project [--dry-run] [--reask <key>]
```

No repository argument: the project is the one whose root this session was
started in.

- `--dry-run` — run the checks and show the recorded choices, the audit, the
  questions it would ask and the offers it would make. Write nothing: no
  setting stored, no file, branch, issue or pull request, nothing queued.
- `--reask <key>` — ask a footprint question again although its answer is
  recorded. `<key>` is `instructions` or `records`.

## Overview

**Lifecycle position**: Utility. Adding a project is two steps (#332 D1):
**register** from the workspace (`register_project.sh <path>`, in a workspace
session; it writes the registry line and the project's settings file and
enables the plugin at the root, and writes nothing into the project), then
**onboard** from the project, here, in a session at the project root with
the project's own instructions loaded.

What a project must carry is **nothing** (D3): the registry line and the
settings file are enough, a project with no footprint is fully usable, and
onboarding only offers.

**Re-runs** (D5): onboarding can be run again at any time, and is how a
moved, renamed or changed project is re-checked. A re-run shows the
recorded choices and the audit result, re-asks nothing unless `--reask`
says so, and changes nothing without a yes.

**Every write waits for a yes.** The writes this skill can make are:

- a setting in the project's settings file (through
  `$WS_ROOT/.agent/scripts/project_setting.sh set`);
- a line in the clone's `.git/info/exclude`;
- a project worktree and its branch, files and commits on it, and a push;
- an issue and a pull request on the project's repository;
- from the hygiene checklist, changes to the GitHub repository itself:
  branch protection and Copilot review (`gh api`), labels
  (`gh label create`), and a git-bug bridge (`git bug bridge new`, then a
  first pull).

Each is shown before it is made, and made only on the user's yes to that
write: a yes to the batch, or to one checklist item, covers nothing else.

The settings file `.agent/projects.d/<name>` (at a parent root, the
chosen instance's) lives in the workspace checkout, outside this session's
root. It is the one thing a project session
writes outside its root: per-machine, gitignored workspace configuration that
the project's onboarding owns, not a tracked change to the workspace
(`docs/design.md`, Sessions and roots). `project_setting.sh set` refuses to
write any other project's file from here (at a parent root, it writes only
its instances').

## Steps

### 1. Resolve the project

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
"$WS_ROOT/.agent/scripts/session_root.sh"
```

It prints `root=`, `type=` and `project=`. Keep `project=` as `<name>` for
the rest of the run.

- **Exit 1** (this directory is no session's root, or a session here does
  not read the root's settings): stop and report its message. If the
  project is not registered, say so: registration comes first, from a
  workspace session: `$WS_ROOT/.agent/scripts/register_project.sh <path>`,
  run in the workspace checkout. Its last line `NEXT=` says to start a
  session at the root and run this skill.
- **`type=workspace`**: stop. Onboarding runs in a session started at the
  project's root, not in the workspace; register the project first if it
  is not, then start a session there.

**A parent root** (a root that groups instances, such as one per ROS
distro) has no settings, adapter or worktrees of its own: they belong to
its instances, and `project_setting.sh set <name>` refuses a parent's
name. Find out whether `<name>` is one:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
source "$WS_ROOT/.agent/scripts/_project_registry.sh"
registry_instances "$WS_ROOT" <name>
registry_default_instance "$WS_ROOT" <name>
```

- **No instance listed**: `<name>` is no parent root. `<settings-name>`
  below is `<name>`.
- **Instances listed**: `<settings-name>` is the instance this run's
  settings, branch and pull request belong to. Show the instances and
  propose the one `registry_default_instance` prints (the default, else
  the only instance); when it prints an error instead (several instances,
  no default), ask which. The user may pick any listed instance. Say
  plainly that the parent root's own settings do not exist, and that this
  run reads, reports and fixes the chosen instance's repository alone:
  every setting below is the instance's, and the parent root's own files
  are not audited, because the fix batch can only write in the
  instance's repository.

### 2. Show the recorded choices and the audit

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
"$WS_ROOT/.agent/scripts/project_setting.sh" list <settings-name>
"$WS_ROOT/.agent/scripts/project_integration_audit.sh" --format text [--instance <settings-name>]
```

`--instance` only at a parent root: the audit then reads that instance's
settings and repository, for categories 1 to 5 alike (without it, the
default or only instance's), and verifies its registration beside the
parent's. `list` prints the
stored keys and the resolved records settings, marking a default as
provisional. The audit prints its findings grouped by category, and a
count. Show both to the user as they are, then a short summary: which
footprint answers are recorded, and how many findings of each severity.

A category 6 `error` means the registration does not work as it stands (a
missing build or test command, the user tier out of date, a root that does
not resolve). Name the fix the finding gives. For a `single_project`
project, a command it lacks is a setting this session may store, after a
yes (`project_setting.sh set <settings-name> build=<command>` or
`test=none`). A `ros2_colcon` project has no `build` or `test` setting:
colcon owns both, and `set` refuses them (the type's
`$WS_ROOT/.agent/project_types/ros2_colcon/unused_settings` says why), so
its fix is the one the finding names. The user tier and the registry line
are fixed from a workspace session.

### 3. Ask the footprint questions not yet answered

Ask only for a key with no recorded value, or the one `--reask` names. Ask
each question on its own, with what it changes, and store the answer only
when the user picks an option that stores it. With `--dry-run`, show the
questions and store nothing.

**a. `instructions`** — "May the workspace offer agent instructions in
tracked files of this project (an agent guide, a Direction section, a
roadmap section)?"

- `tracked`: offers are made (step 5), each still a yes or no.
- `none`: nothing is offered in tracked files; findings whose fix is a
  tracked file are reported as `info`.
- leave unset: the question comes back on the next run, and offers wait
  for it.

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
"$WS_ROOT/.agent/scripts/project_setting.sh" set <settings-name> instructions=<tracked|none>
```

The setting records the answer; readers key off the files themselves,
never this key.

**b. Records** (`location`, `tracking`) — where the loop's work plans and
progress timelines for this project's issues live. The four places (D2a):

| Place | `location` | `tracking` |
|---|---|---|
| Committed in the project, on each issue's feature branch | `project` | `project` |
| In the project, ignored through the clone's `.git/info/exclude` | `project` | `untracked` |
| A separate records repository the user names (never a workspace) | `outside` | `repo` |
| Untracked, on this machine only | `outside` | `untracked` |

Show the default from the one function that holds it, and say that it is
**provisional** (owner, 2026-10-13: not settled) and can be overridden:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
source "$WS_ROOT/.agent/scripts/_project_registry.sh"
project_records_default "$WS_ROOT" <settings-name> accepts-footprint
project_records_default "$WS_ROOT" <settings-name> zero-footprint
```

Each prints `location`, `tracking`, the outside layout and `provisional`.
The first is the default for a project that accepts footprint, and what
a project with no records settings resolves to; the second is the
proposal for a project that wants none.

Say plainly which places are not available yet: **until the records lookup
(#393) lands, only (project, project) is stored**, and `project_setting.sh
set` refuses the other three. A user who wants zero footprint is told that
records still land on each issue's feature branch, under the project's
`<root>/.agent/work-plans/issue-N/`, until then. Storing (project, project)
explicitly is optional: a file without the keys already resolves to it.

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
"$WS_ROOT/.agent/scripts/project_setting.sh" set <settings-name> location=project tracking=project
```

When a setting changed, run the audit again (step 2's command): severities
follow `instructions`, and the records checks follow the records settings.

### 4. Judge the findings

The script reports; this step judges. Go through the findings by category.

- **1, overrides.** A project skill or command with a workspace skill's
  name no longer shadows it in a project session (the workspace's is
  `/agent-workspace:<skill>`), so a duplicate is optional: say whether the
  copy is identical (drop it, or keep it on purpose) or differs (which is
  the project's own version). Hooks, allow rules, MCP servers and `@`
  imports are reported so the user knows what loads beside the workspace;
  name any that would block or change a workspace script.
- **2, process candidates.** Read each candidate line in its context and
  say whether it really disagrees with the workspace's process (worktrees,
  an issue first, the signature lines, the project's own build and test
  commands). Workspace principles govern process and project rules govern
  the domain; when the two conflict on process, **flag it with both sides
  quoted and never pick one** (Governance Layering in
  `$WS_ROOT/.agent/knowledge/principles_review_guide.md`). The user decides.
- **3 to 6.** Mechanical: the finding's detail names the fix.

### 5. Offers — only when `instructions=tracked`

When `instructions` is unset, ask question 3a first. When it is `none`,
make no offer of a tracked file, and say so. Each offer is its own yes or
no:

1. **Agent guide** — `.agents/README.md` from
   `$WS_ROOT/.agent/templates/project_agents_guide.md`, filled in by reading
   the project's code; every claim verified against source
   (`$WS_ROOT/.agent/knowledge/documentation_verification.md`).
2. **Direction section** — a `## Direction` section in the project's own
   roadmap: an existing `docs/roadmap.md` or `ROADMAP.md`, else a new
   `docs/roadmap.md`. Its format is the workspace's (the Format paragraph
   of the Direction section in `$WS_ROOT/docs/roadmap.md`, the grammar in
   the header of `$WS_ROOT/.agent/scripts/sitrep_checks.sh`): the lines that
   must be true for the project's current goal, each with a check.
3. **Hygiene checklist** — the section below, until `audit-project` takes it
   (#332 PR 4).

Whatever `instructions` says, offer to run `/agent-workspace:audit-project`
at the end: it writes nothing.

### 6. Answer each finding and each accepted offer

Every audit finding the user did not set aside in step 4, and every offer
accepted in step 5, gets one of four answers:

- **Fix now** — added to the batch of step 7.
- **Open issue** — an issue on the project describing it (step 8).
- **Queue in the roadmap** — a row in the project's roadmap, below.
- **Skip** — nothing done, nothing tracked.

Owner, verbatim (#332 D6): "all that work should be cued up in the roadmap,
if the user approves, so that it can get tackled maybe as other issues are
resolved".

**Queue in the roadmap.** Queued items become rows of an `## Onboarding`
section in the project's roadmap (an existing `docs/roadmap.md` or
`ROADMAP.md`, else a new `docs/roadmap.md`):

```markdown
## Onboarding

Queued by /agent-workspace:onboard-project on <date>; picked up like any
other open roadmap row.

| Item | Issue |
|------|-------|
| <the finding or offer, in plain words> | <#N, or none> |
```

When the project uses issues, each row gets its issue; until
`audit-project` reports whether it does (#332 PR 4), ask. Writing the
section is itself a write: it waits for the same yes and rides in the same
batched pull request as the fix-now items. How many queued rows to take on
alongside other work is a later rule, not this skill's.

A zero-footprint project (`instructions=none`) keeps its roadmap with its
records, so **until the records lookup (#393) lands, queue in the roadmap
is not offered to it**: say so, and offer open issue or skip instead. For
such a project, fix now is offered only for a fix that touches no tracked
file (a setting, a `.git/info/exclude` line).

Fixes that touch no tracked file are made as soon as the user says yes:

- a setting: `project_setting.sh set <settings-name> <key>=<value>`;
- the worktrees directory: add its line (the finding names it, e.g.
  `worktrees/`) to the file `git rev-parse --git-path info/exclude` prints,
  the same line `worktree_create.sh` adds when it creates the first
  worktree.

### 7. Make the fix-now batch — one pull request

Show the whole batch (files to add or change, the roadmap section) and ask
once more before creating anything. Then:

1. Create the project worktree and work there. If the project uses
   issues, open one issue for the onboarding work first (step 8's
   pattern, title "Onboard the project with the workspace") and create
   the worktree for it, on `feature/issue-<N>`:

   ```bash
   WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
   "$WS_ROOT/.agent/scripts/worktree_create.sh" --issue <N> --type project --project <settings-name>
   ```

   A project that uses no issues gets a skill worktree instead, on a
   `skill/onboard-project-<timestamp>` branch with no issue behind it
   (`onboard-project` is on `worktree_create.sh`'s skill allowlist for
   this):

   ```bash
   WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
   "$WS_ROOT/.agent/scripts/worktree_create.sh" --skill onboard-project --type project --project <settings-name>
   ```

   It is a worktree of the root's own repository, so a root that is not
   the top of a git repository gets none: for such a project nothing goes
   on a branch, and only fixes that touch no tracked file are made.

   `--project` is required: with `--type` given, `worktree_create.sh`
   does not look at the current directory, so without it it would take a
   legacy `project/` checkout (the wrong repository) or stop when several
   projects are registered. `<settings-name>` is step 1's: `<name>` from
   `session_root.sh`, or at a parent root the chosen instance, whose
   repository the worktree is of, and the one repository the audit read
   (the parent root's own files were not audited). Enter the worktree
   with `cd` to the path it prints.
2. Make the changes, commit them (one commit per logical change), and show
   the commits. Each commit carries the agent's identity: shell state does
   not persist between tool calls, so source it in the same command chain
   as every `git commit`, with this session's own agent name, email and
   model ID (the three-argument form, as `/run-issue` does):

   ```bash
   WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
   source "$WS_ROOT/.agent/scripts/set_git_identity_env.sh" "<agent name>" "<agent email>" "<model-id>" \
     && git commit -m "<what changed>"
   ```
3. Push and open the pull request only on a yes. For a project with no
   GitHub remote, leave the edits on the branch, push nothing, and say
   where the branch is.

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
source "$WS_ROOT/.agent/scripts/set_git_identity_env.sh" "<agent name>" "<agent email>" "<model-id>" || exit 1
[ -n "${AGENT_NAME:-}" ] && [ -n "${AGENT_MODEL:-}" ] || { echo "AGENT_NAME/AGENT_MODEL not set: no signature" >&2; exit 1; }
PR_BODY_FILE="$(mktemp)"
cat > "$PR_BODY_FILE" <<'EOF'
## Summary

Onboarding with the workspace:

- <each item>

Closes #<N>
EOF
printf '\n---\n**Authored-By**: `%s`\n**Model**: `%s`\n' "$AGENT_NAME" "$AGENT_MODEL" >> "$PR_BODY_FILE"
gh pr create -R <owner>/<repo> --title "Onboard the project with the workspace" \
  --body-file "$PR_BODY_FILE"
rm -f "$PR_BODY_FILE"
```

`<owner>/<repo>` comes from the project's `git remote get-url origin`.
Leave out the `Closes #<N>` line when step 1 opened no issue.

The body's heredoc is quoted (`<<'EOF'`): finding text often carries
backticked commands and `$`, which an unquoted heredoc would run or
expand. The signature is appended after it by `printf`, from the
`AGENT_NAME` and `AGENT_MODEL` the `source` line has just set in the same
shell, and the run stops before creating anything when they are not set,
so a signature is never empty.

### 8. Open the issues

For each "open issue" answer, after showing the title and body:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
source "$WS_ROOT/.agent/scripts/set_git_identity_env.sh" "<agent name>" "<agent email>" "<model-id>" || exit 1
[ -n "${AGENT_NAME:-}" ] && [ -n "${AGENT_MODEL:-}" ] || { echo "AGENT_NAME/AGENT_MODEL not set: no signature" >&2; exit 1; }
BODY_FILE="$(mktemp)"
cat > "$BODY_FILE" <<'EOF'
## <item>

<what the audit found, where, and the fix it suggests>

Found by the `onboard-project` skill.
EOF
printf '\n---\n**Authored-By**: `%s`\n**Model**: `%s`\n' "$AGENT_NAME" "$AGENT_MODEL" >> "$BODY_FILE"
gh issue create -R <owner>/<repo> --title "<item title>" --body-file "$BODY_FILE"
rm -f "$BODY_FILE"
```

The same rules as step 7's pull request: a quoted heredoc for the text, the
signature appended from the identity sourced in the same shell.

### 9. Summary

Report, each line saying whether it is done or still to do:

```markdown
## Onboarding: <name>

### Recorded choices
- instructions: <value, or not set>
- records: <location, tracking> (<default, provisional | stored>)

### Done
- <item> — <PR link | setting stored | exclude line added>

### Still to do
- <item> — <issue link | queued in the roadmap>

### Skipped
- <item>

### Next
- /agent-workspace:audit-project (writes nothing)
```

Look every link up with `gh` (`gh pr view <N> --json url`); never build a
URL by hand.

## Hygiene checklist (moves to audit-project, #332 PR 4)

Kept here until `audit-project` takes it, so it always has a home. Offered
in step 5; each gap found gets the step 6 answers. For a project with
`instructions=none`, items that add tracked files are offered as open
issue or skip only.

| Item | Check | Fix approach |
|------|-------|-------------|
| **Pre-commit config** | `.pre-commit-config.yaml` exists at the root | Write one for the project's languages, with `no-commit-to-branch` set to the default branch; the workspace has no template, and its own `$WS_ROOT/.pre-commit-config.yaml` is an example |
| **CI workflow** | `.github/workflows/*.yml` with build and test steps | Write a workflow on the default branch that runs the project's own build and test commands (`project_setting.sh get <settings-name> build` and `test`); the workspace has no template |
| **Branch protection** | A ruleset requires pull requests on the default branch | `gh api` — needs admin access |
| **Copilot auto-review** | Copilot reviews pull requests | `gh api` — needs admin access |
| **Component labels** | `component:` labels (multi-component repositories only) | `gh label create` per component |
| **git-bug bridge** | `git bug bridge` lists a GitHub bridge | `git bug bridge new` and a first pull |
| **License headers** | Source files carry copyright and license headers | Too invasive for a batch: always open issue or queue |

Before a GitHub settings item, check the access:

```bash
gh api repos/<owner>/<repo> --jq '.permissions.admin'
```

Without admin access, say that branch protection and Copilot review need it
and move on; a permission problem never fails the run. Labels need write
access only:

```bash
gh label create "component:<name>" --description "<what it is>" --color "5319E7" -R <owner>/<repo>
```

Skip an item already in place, and items that do not apply (no GitHub
remote: protection, Copilot, labels, bridge; no git-bug installed: bridge).
Generated CI workflows and pre-commit configs must work in the project on
their own, with no dependency on workspace scripts or paths.

## Guidelines

- **Interactive, not autonomous**: the skill presents and offers; the user
  decides, and every write waits for a yes.
- **One project, the session's own**: no repository argument; another root
  is onboarded from a session started there.
- **Re-runnable**: recorded choices are shown, not re-asked; items already in
  place are reported and skipped.
- **One pull request**: every fix-now item and the roadmap section go into
  one pull request on the project.
- **Defaults are provisional**: say so whenever a records default is shown.
