---
name: audit-project
description: Check the project at this session's root against workspace and project conventions. Reports governance coverage, documentation and test gaps, the hygiene checklist (pre-commit, CI, branch protection, Copilot review, component labels, git-bug bridge, license headers; items the project's facts make moot are reported skipped) and the integration audit. Report-only; an optional final step answers each finding with fix now, open issue, queue in the roadmap, or skip, every write after a yes.
session_scope: project
---

# Audit Project

## Workspace root

This skill can run in a **project** session — a session started in a project
checkout, not in the workspace. There, `.agent/scripts/...` does not resolve:
those paths belong to the workspace, and the cwd is somewhere else entirely.

Every workspace path below is therefore written `$WS_ROOT/.agent/...`.
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
/agent-workspace:audit-project
```

No repository argument: the project audited is the one whose root this
session was started in (at a parent root, the instance chosen in step 1).

## Overview

**Lifecycle position**: Utility/periodic — run before or after work on the
project, and offered at the end of `onboard-project` (#332 D4). Not tied to
the per-issue lifecycle.

Check the project against workspace standards and its own governance docs:
governance coverage, the agent guide, component metadata, tests,
documentation, the hygiene checklist and the integration audit (how the
project and the workspace fit together). Reports what's present, what's
missing, what was skipped and why, and what may have drifted.

**Not the same as `audit-workspace`** — that checks workspace-level governance.
This checks one project.

**Report-only by default.** Steps 1 to 9 read and report; they write
nothing. Step 10 is optional and offered at the end: it answers each
finding with fix now, open issue, queue in the roadmap, or skip, and
**every write waits for a yes**. The writes step 10 can make:

- changes to the GitHub repository itself: branch protection and Copilot
  review (`gh api`), labels (`gh label create`), and a git-bug bridge
  (`git bug bridge new`, then a first pull);
- a project worktree and its branch, files and commits on it (an
  `## Onboarding` roadmap section among them), and a push;
- an issue and a pull request on the project's repository.

Each is shown before it is made, and made only on the user's yes to that
write: a yes to the batch, or to one item, covers nothing else.

## Steps

### 1. Resolve the project

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
"$WS_ROOT/.agent/scripts/session_root.sh"
```

It prints `root=`, `type=` and `project=`. Keep `project=` as `<name>` and
`root=` as `<repo-dir>` for the rest of the run.

- **Exit 1** (this directory is no session's root, or a session here does
  not read the root's settings): stop and report its message. If the
  project is not registered, say so: registration comes first, from a
  workspace session: `$WS_ROOT/.agent/scripts/register_project.sh <path>`,
  run in the workspace checkout.
- **`type=workspace`**: stop. This skill audits a project from a session
  started at the project's root, not from the workspace; register the
  project first if it is not, then start a session there.

**A parent root** (a root that groups instances, such as one per ROS
distro) has no settings, adapter or repository content of its own: they
belong to its instances. Find out whether `<name>` is one from its
registered type, and list its instances:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
source "$WS_ROOT/.agent/scripts/_project_registry.sh"
registry_lookup "$WS_ROOT" <name> | cut -f1
registry_instances "$WS_ROOT" <name>
registry_default_instance "$WS_ROOT" <name>
```

- **A type other than `project`**: `<name>` is no parent root.
  `<settings-name>` below is `<name>`.
- **Type `project`, no instance listed**: stop. There is no repository to
  audit yet; say to register an instance first, from a workspace session:
  `$WS_ROOT/.agent/scripts/register_project.sh <path> --parent <name>`.
- **Type `project`, instances listed**: `<settings-name>` is the instance
  audited. Propose the one `registry_default_instance` prints (the default,
  else the only instance); when it prints an error instead (several
  instances, no default), ask which. Say plainly that this run reads,
  reports and fixes the chosen instance's repository alone, and that the
  parent root's own files are not audited, because a fix can only be
  written in the instance's repository. `<repo-dir>` is the instance's
  root:

  ```bash
  WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
  source "$WS_ROOT/.agent/scripts/_project_registry.sh"
  registry_lookup "$WS_ROOT" <settings-name> | cut -f2
  ```

Every check below reads `<repo-dir>`.

### 2. Read the facts

The facts decide which hygiene items are moot (step 8). They are read, not
guessed:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
"$WS_ROOT/.agent/scripts/project_integration_audit.sh" --facts --format text [--instance <settings-name>]
```

`--instance` only at a parent root. Each line is `fact: value -- evidence`,
the value `yes`, `no` or `unknown`:

| Fact | Means |
|------|-------|
| `github` | The repository's remote (origin, else its first) is on github.com, read by the host's name: `no` means no remote is github.com by name, so a GitHub Enterprise server, or an ssh host alias with no "github" in its name, reads as `no` (its evidence ends `not github.com by name`); the evidence names the remote and `github.com/<owner>/<repo>` (`remote '<remote>' is github.com/<owner>/<repo>`), and for a network remote only host and path, never a user part, query or fragment (a local remote's path is printed whole, on purpose: it names no server). When `git push` sends that remote somewhere else (a `pushurl`, `insteadOf` or `pushInsteadOf`), the evidence ends `; its push URL differs: <where>`, and the push step asks before pushing. The gh calls below name that host: `-R github.com/<owner>/<repo>`, `gh repo view github.com/<owner>/<repo>` and `gh api --hostname github.com`, since a bare `<owner>/<repo>` goes to `$GH_HOST` when that is set |
| `issues` | It uses GitHub issues: enabled, and at least one ever opened |
| `prs` | It uses pull requests: at least one ever opened |
| `windows` | This machine runs Windows (`uname -s`) |
| `multi_component` | Component manifests in two or more directories; the evidence lists them |

`unknown` makes nothing moot: the item is checked, and its line says the
fact could not be read. Which facts go `unknown`, and for what:

- `github` and `multi_component`: the repository cannot be read — at a
  parent root with no instance chosen (several, none the default: pass
  `--instance`) or none registered, or the root not on disk. `github` is
  also `unknown` when its remote's host only looks like GitHub (an ssh
  host alias such as `github.com-work`, GitHub Enterprise), when it is on
  github.com but its path is not `<owner>/<repo>` or it has none
  (`https://github.com`), when its URL could not be cut to host and path
  safely (a remote-helper `<transport>::<address>`, an scp-form host that
  is not a plain name — `x:y@github.com:o/r`, where git contacts host
  `x` — a user part holding `/`, `?` or `#`, an `@` in a path, in an
  scp-form remote's query, or in a query with no path before it,
  or a host or path not in plain characters, such as one holding a space
  or a quote: the URL is not printed and the server it names is not
  read), or when that remote is not on GitHub but another one is or may
  be. `multi_component` is also `unknown` when the manifest scan fails
  (`git ls-files` or `find` exits non-zero, or a `CMakeLists.txt` cannot
  be read) before it has found two directories.
- `issues` and `prs`: whenever `github` is `unknown`, and on any gh
  problem — gh or jq missing, gh not signed in or offline, an answer
  without the counts or the list asked for. A gh problem leaves `github`,
  `windows` and `multi_component` as they were read. A failed gh call's
  evidence is `gh failed, exit <N>: <the call>`, and an answer that does
  not parse is named with a fixed phrase: none of gh's own text is
  printed, since it can quote a URL holding a credential, only at most
  its first word when that is one of a fixed list (`HTTP`, `GraphQL`,
  `error`, ...). Run the call by hand to see gh's message.
- `windows`: `uname -s` gave nothing.

### 3. Check governance coverage

Using the governance template (`$WS_ROOT/.agent/templates/project_governance.md`)
as reference, check what exists in `<repo-dir>`:

| Item | Status | Path |
|---|---|---|
| `.agents/README.md` | Present / Missing | ... |
| `PRINCIPLES.md` / `docs/principles.md` | Present / Missing | ... |
| `ARCHITECTURE.md` / `docs/design.md` | Present / Missing | ... |
| `docs/decisions/` | Present / Missing (N ADRs) | ... |
| `.agents/workspace-context/` | Present / Missing | ... |

This is a **coverage report**, not a mandate — not every repo needs full
governance. But missing items should be noted.

### 4. Check agent guide quality

If `.agents/README.md` exists, check it against the template
(`$WS_ROOT/.agent/templates/project_agents_guide.md`):

- Does it have the expected sections? (Component inventory, layout,
  architecture, build & test, pitfalls)
- Are empty sections present? (Should be removed per template instructions)
- Do listed file paths actually exist in the repo?
- Does the component inventory match actual source modules?

### 5. Check project metadata

For each component/module in the repo:

- Is the description filled in (not empty or placeholder)?
- Are dependencies listed?
- Does it have a license?
- Is the maintainer field populated?

### 6. Check test status

For each component:

- Do test files exist? (`test/`, `tests/`, `*_test.py`, `*_test.cpp`, `*_test.go`, `*.test.*`)
- Report test existence, not test quality. Run the tests only if the user
  asks, with the project's own test command:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
"$WS_ROOT/.agent/scripts/project_setting.sh" get <settings-name> test
```

### 7. Check documentation

- Does a top-level `README.md` exist?
- Do components have individual READMEs?
- Are entry points and interfaces documented?
- Are public APIs documented?

### 8. Hygiene checklist

Every item gets one status: **in place**, **missing**, **skipped:
<reason>**, or **not checked: <reason>** (a check that could not run, such
as a GitHub call without access). An item is never dropped from the report.

| Item | Check | Fix approach |
|------|-------|-------------|
| **Pre-commit config** | `.pre-commit-config.yaml` exists at the root | Write one for the project's languages, with `no-commit-to-branch` set to the default branch; the workspace has no template, and its own `$WS_ROOT/.pre-commit-config.yaml` is an example |
| **CI workflow** | `.github/workflows/*.yml` with build and test steps | Write a workflow on the default branch that runs the project's own build and test commands (`project_setting.sh get <settings-name> build` and `test`); the workspace has no template |
| **Branch protection** | A rule requires pull requests on the default branch (`pull_request` in the branch's rules) | `gh api` — needs admin access |
| **Copilot auto-review** | Copilot reviews pull requests (`copilot_code_review` in the branch's rules) | `gh api` — needs admin access |
| **Component labels** | `component:` labels, one per component | `gh label create` per component |
| **git-bug bridge** | `git bug bridge`, run in `<repo-dir>`, lists a GitHub bridge | `git bug bridge new` and a first pull |
| **License headers** | Source files carry copyright and license headers | Too invasive for a batch: always open issue or queue |

**What the facts make moot.** Skip these items and report each as
`skipped: <reason>`, the reason naming the fact:

| Fact | Items skipped | Reason line |
|------|---------------|-------------|
| `github=no` | Branch protection, Copilot auto-review, Component labels, git-bug bridge | `skipped: no remote is github.com by name (github=no)` |
| `issues=no` | git-bug bridge (it carries issues) | `skipped: the project uses no GitHub issues (issues=no)` |
| `prs=no` | Copilot auto-review (it reviews pull requests) | `skipped: the project uses no pull requests (prs=no)` |
| `issues=no` and `prs=no` | Component labels (they label issues and pull requests) | `skipped: the project uses no issues or pull requests (issues=no, prs=no)` |
| `multi_component=no` | Component labels | `skipped: one component (multi_component=no)` |
| `windows=yes` | git-bug bridge | `skipped: Windows (windows=yes)` |

`windows=yes` skips only part of the pre-commit item, so the item is not
reported as skipped: it keeps its **in place** or **missing** status, and
its line ends `(windows=yes: language-native hooks only)`. When it is
missing, the fix offers language-native hooks and no shell-script hook;
when it is in place, the line also names each hook that runs a shell
script, since such a hook may not run on this machine.

Also skip, with its reason, the git-bug bridge when git-bug is not
installed (`git bug version` fails): `skipped: git-bug is not installed`.
With `prs=no`, branch protection that requires pull requests would change
how the project works: report the item, and in step 10 ask rather than
recommend it.

With `github=unknown`, the GitHub checks have no repository to read: ask
which repository on github.com it is, or report branch protection, Copilot
auto-review and component labels as `not checked: github=unknown (<the
fact's evidence>)`.

The GitHub checks only read. The default branch and the rules on it:

```bash
gh repo view github.com/<owner>/<repo> --json defaultBranchRef --jq .defaultBranchRef.name
gh api --hostname github.com repos/<owner>/<repo>/rules/branches/<default-branch> --jq '.[].type'
gh label list -R github.com/<owner>/<repo> --search "component:" --json name --jq '.[].name'
```

The rules call shows rulesets and needs read access only. A
`pull_request` rule there puts branch protection **in place**, whatever
classic protection says. Otherwise classic branch protection decides, and
GitHub answers its call with 404 both when the branch is not protected and
when the caller lacks admin access, so ask for admin access first:

```bash
gh api --hostname github.com repos/<owner>/<repo> --jq '.permissions.admin'
gh api --hostname github.com repos/<owner>/<repo>/branches/<default-branch>/protection --jq '.required_pull_request_reviews != null'
```

| Admin access | Protection call | Branch protection |
|--------------|-----------------|-------------------|
| `true` | `true` | **in place** |
| `true` | `false` (protected, no pull request required) | **missing** |
| `true` | 404 with the message `Branch not protected` (gh prints `Branch not protected (HTTP 404)`) | **missing** |
| `true` | any other failure | `not checked: <the call's error>` |
| anything but `true` (`false`, or `null` from a token whose answer has no permissions object) | not made | `not checked: classic branch protection needs admin access` |
| the access call fails | not made | `not checked: <the call's error>` |

A 404 is never read as missing without admin access: without it the same
404 hides a protected branch. Only `true` counts as admin access: an
access call that succeeds and prints `false`, `null` or anything else
leaves the item `not checked: classic branch protection needs admin
access`. When the rules call itself fails (offline), the item is
`not checked: <reason>` unless the protection call shows required pull
request reviews. Copilot auto-review lives only in the
rules, so a failed rules call leaves it `not checked: <reason>`; a
permission problem never fails the run.

### 9. Integration audit

How the project and the workspace fit together, report-only (the same
script `onboard-project` runs):

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
"$WS_ROOT/.agent/scripts/project_integration_audit.sh" --format text [--instance <settings-name>]
```

Report its findings as printed, grouped by category, with the count.
Category 2 lines are candidates: quote each in its context; when one
really disagrees with the workspace's process, **flag it with both sides
quoted and never pick one** (Governance Layering in
`$WS_ROOT/.agent/knowledge/principles_review_guide.md`). The detail of
each finding in categories 1 and 3 to 6 names its fix.

### The report

```markdown
## Project Audit: <settings-name>

**Location**: `<repo-dir>`
**Components**: N components (list)

### Facts

| Fact | Value | Evidence |
|---|---|---|
| github | yes / no / unknown | ... |
| ... | ... | ... |

### Governance Coverage

| Item | Status |
|---|---|
| `.agents/README.md` | Present / Missing |
| `PRINCIPLES.md` / `docs/principles.md` | Present / Missing |
| ... | ... |

### Agent Guide

<findings if .agents/README.md exists, or "No agent guide — consider
creating one with the project_agents_guide.md template">

### Component Metadata

| Component | Description | License | Maintainer | Tests |
|---|---|---|---|---|
| `component_name` | OK / Missing | OK / Missing | OK / Missing | Exist / Missing |

### Documentation

| Item | Status |
|---|---|
| Top-level README | Present / Missing |
| ... | ... |

### Hygiene

| Item | Status |
|---|---|
| Pre-commit config | in place / missing / skipped: <reason> / not checked: <reason> |
| ... | ... |

### Workspace Integration

<the integration audit's findings by category, and its count>

### Recommended Actions

- [ ] <specific action items>
```

Each line says whether it is the current state or still to do.

### 10. Optional: answer the findings

After the report, offer once: answer the findings now? Nothing is written
unless the user says yes, and then each write still waits for its own yes.
A no ends the run with the report.

Every finding the user wants answered gets one of four answers:

- **Fix now** — made now (a GitHub setting) or added to the batch below.
- **Open issue** — an issue on the project describing it.
- **Queue in the roadmap** — a row in the project's roadmap, below.
- **Skip** — nothing done, nothing tracked.

Owner, verbatim (#332 D6): "all that work should be cued up in the roadmap,
if the user approves, so that it can get tackled maybe as other issues are
resolved".

**Queue in the roadmap.** Queued items become rows of the same
`## Onboarding` section `onboard-project` writes, in the project's roadmap
(an existing `docs/roadmap.md` or `ROADMAP.md`, else a new
`docs/roadmap.md`); a section already there gains rows:

```markdown
## Onboarding

Queued by /agent-workspace:onboard-project or /agent-workspace:audit-project
on <date>; picked up like any other open roadmap row.

| Item | Issue |
|------|-------|
| <the finding, in plain words> | <#N, or none> |
```

Each queued row is its own yes. When the project uses issues (`issues=yes`),
each row gets its issue; with `issues=no` the cell says `none`; when the
fact is `unknown`, ask. Writing the section is itself a write: it waits for
the same yes and rides in the same batched pull request as the fix-now
items.

**A project that takes no footprint.** Read its `instructions` setting:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
"$WS_ROOT/.agent/scripts/project_setting.sh" get <settings-name> instructions
```

With `instructions=none`, an item that adds or changes a tracked file is
offered as open issue or skip only, and queue in the roadmap is not offered
**until the records lookup (#393) lands** (such a project keeps its roadmap
with its records): say so.

**GitHub settings** (branch protection, Copilot review, labels, git-bug
bridge) touch no tracked file, so each is made as soon as the user says yes
to it, one item at a time. Check access first:

```bash
gh api --hostname github.com repos/<owner>/<repo> --jq '.permissions.admin'
```

Without admin access, say that branch protection and Copilot review need it
and move on. Labels need write access only:

```bash
gh label create "component:<name>" --description "<what it is>" --color "5319E7" -R github.com/<owner>/<repo>
```

**The fix-now batch and the issues.** Follow `onboard-project`'s steps 7
and 8 as written (`$WS_ROOT/.claude/skills/onboard-project/SKILL.md`,
"7. Make the fix-now batch — one pull request" and "8. Open the issues"):
show the whole batch and ask once more, one project worktree, one commit
per logical change with the identity sourced in the same command chain, the
branch pushed and the pull request opened only on a yes, signed issues and
pull request bodies from quoted heredocs. With these changes:

- the issue and pull request title is "Fix what the project audit found";
- the pull request body's summary line is "Fixes from the project audit:"
  where step 7's reads "Onboarding with the workspace:", followed as there
  by one `- <each item>` line per change and `Closes #<N>` (left out, as
  there, when no issue was opened):

  ```markdown
  ## Summary

  Fixes from the project audit:

  - <each item>

  Closes #<N>
  ```
- an issue body ends "Found by the `audit-project` skill." where step 8's
  ends "Found by the `onboard-project` skill.";
- `gh pr create` and `gh issue create` take `-R github.com/<owner>/<repo>`,
  and the branch is pushed to `<remote>`, both as the `github` fact names
  them (`remote '<remote>' is github.com/<owner>/<repo>`);
- the worktree: on the issue's `feature/issue-<N>` when the project uses
  issues; for a project that uses none, the `onboard-project` skill
  worktree (`--skill onboard-project`), because this hygiene work is
  onboarding work and `onboard-project` is the project skill on
  `worktree_create.sh`'s allowlist;
- `github=no`: leave the edits on the branch, push nothing, and say where
  the branch is;
- `github=unknown` (a host that only looks like GitHub, a github.com path
  that is not `<owner>/<repo>`, a URL that could not be printed safely, or
  GitHub on another remote): ask which repository on github.com and which
  remote it is before any issue, push or pull request, and use the
  answer; without one, open nothing, push nothing, and say where the
  branch is.

Generated CI workflows and pre-commit configs must work in the project on
their own, with no dependency on workspace scripts or paths.

End with what was done, what is still to do (issue links, queued rows) and
what was skipped, each line saying which. Look every link up with `gh`;
never build a URL by hand.

## Guidelines

- **Report-only by default** — steps 1 to 9 write nothing; step 10 is
  optional and every write in it waits for a yes.
- **One project, the session's own** — no repository argument; another root
  is audited from a session started there.
- **Skipped, never dropped** — every checklist item has a status line, a
  skipped one with the fact that made it moot.
- **Coverage, not quality** — check what exists, not whether it's good.
  "README exists" is objective; "README is well-written" is subjective.
- **Flag adoption level** — reference the governance template's adoption
  levels (minimal/standard/full) and note where this repo falls.
- **Don't run tests by default** — only run tests if the user asks. Just
  check whether test files exist.
