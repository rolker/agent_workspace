# How it works

Written last; see the change log.

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

## Change log

One row per change to this file, appended in the same change that alters a section: date, section, one
line, issue, and the line count of the document after the change.

| Date | Section | Change | Issue | Lines |
|---|---|---|---|---|
| 2026-10-09 | Whole file | Skeleton. Rewrite starts from the plan's section table: `# How it works` is a stub (written last), `# The design` opens with the admission rule and the Status key, and everything the old file held that now lives next to the code is gone (destinations landed in #377) | #335 | 40 |
| 2026-10-09 | Purpose | What the file is for, with pointers to the README goals and the principles | #335 | 54 |
| 2026-10-09 | Documentation layers | The seven roles and the workspace's mapping, with the two gaps (healthy, measures) shown; per-project mapping as a proposal | #335 | 94 |
| 2026-10-09 | Rules | Rules table with the enforced-by column: 14 rules, each with the check checked against the hook, script or CI file | #335 | 129 |
