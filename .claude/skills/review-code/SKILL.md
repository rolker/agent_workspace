---
name: review-code
description: Lead reviewer that orchestrates specialist sub-reviews (static analysis, governance, plan drift, adversarial) to evaluate a PR. Scales review depth to change risk. Produces a unified structured report.
---

# Review Code

## Usage

```
# PR mode (default — review an open PR)
/review-code <pr-number-or-url> [light|standard|deep] [--skip-static]

# Branch mode (local pre-push self-review)
/review-code --branch [<base-ref>] [--issue <N>] [--no-progress] [--skip-static] [light|standard|deep]
```

Optional depth keyword overrides automatic classification. `--skip-static`
suppresses the static-analysis specialist in either mode (useful when
pre-commit was clean). `--no-progress` (branch mode only) skips the
progress.md persistence step — used for skill worktrees and one-off
branches that don't have an issue to track against.

## Overview

**Lifecycle position**:

```
review-issue → plan-task → review-plan → implement
   → review-code --branch  (local pre-push self-review)
   → push
   → review-code (PR mode)
   → triage-reviews
```

The two `review-code` entry points share specialists, depth classification,
the silence filter, and the report format. They differ only in where the
diff and metadata come from (local git vs. open PR) and whether the
"Existing review comments" sub-step runs (no PR comments to fetch
pre-push).

Multi-specialist code review system. A lead reviewer gathers context,
classifies review depth based on change risk, dispatches specialist
sub-reviews in parallel, collects findings, deduplicates, applies a
silence filter, and produces a unified report. Does not post comments or
modify the PR unless the user asks.

**Depth tiers** (see `.agent/knowledge/review_depth_classification.md`):
- **Light** — static analysis only (small, low-risk changes)
- **Standard** — Static Analysis, Governance, Plan Drift + Claude adversarial (medium or governance-touching)
- **Deep** — Standard tier + Gemini adversarial (large, security, or cross-layer)

**Specialists**:
- **Static Analysis** — runs linters on changed files using project or workspace configs
- **Governance** — evaluates against principles, ADRs, and consequences
- **Plan Drift** — compares implementation against the work plan (if one exists)
- **Claude Adversarial** — fresh subagent, independent review for missed issues (Standard + Deep)
- **Gemini Adversarial** — cross-model review via Gemini CLI in tmux (Deep only)

## Steps

### 1. Gather review context

The two modes draw their inputs from different sources. Pick the
sub-step that matches the invocation.

#### 1a. PR mode (default)

```bash
# PR metadata
gh pr view <N> --json title,body,baseRefName,headRefName,headRefOid,files,additions,deletions,url,comments,reviews

# Full diff
gh pr diff <N>

# Linked issue
gh pr view <N> --json body --jq '.body' | grep -o '#[0-9]*'
```

#### 1b. Branch mode (--branch [<base-ref>])

This snippet is illustrative pseudo-code; the skill body describes
behavior, not a copy-pastable shell block. `$BASE_REF_FROM_USER` is a
placeholder for whatever value the user passed to `--branch <base>`
(empty string when `--branch` was passed bare).

```bash
# Resolve base ref. Explicit `--branch <base>` arg wins; otherwise
# the helper consults the per-project manifest (when wired — see #172),
# falls back to `git symbolic-ref refs/remotes/origin/HEAD`, then `main`.
source .agent/scripts/_resolve_default_branch.sh
BASE_REF_FROM_USER=""  # set to `--branch` arg value if user passed one
if [[ -n "$BASE_REF_FROM_USER" ]]; then
    BASE="$BASE_REF_FROM_USER"
else
    BASE=$(resolve_default_branch)
fi

# Branch metadata
BRANCH=$(git branch --show-current)
HEAD_SHA=$(git rev-parse --short HEAD)

# Files and diff
git diff --name-only "$BASE"...HEAD
git diff "$BASE"...HEAD

# Linked issue: parse `feature/issue-<N>` or `feature/ISSUE-<N>-<desc>`
# from the branch name. `--issue <N>` overrides; `--no-progress`
# opts out of progress.md persistence for skill worktrees / one-off
# branches. If neither resolves and `--no-progress` not passed, hard
# error with remediation.
```

Identify (both modes):
- What repo this affects (workspace or project)
- What files changed and in which directories
- The linked issue and its requirements (or `--no-progress` if no issue applies)
- Whether a work plan exists (`.agent/work-plans/issue-*/plan.md`)

Read the **full content** of each changed file (not just the diff hunks) to
understand surrounding context.

### 2. Classify review depth

Load `.agent/knowledge/review_depth_classification.md` and apply the risk
signals from step 1:

1. Count total lines changed (additions + deletions)
2. Count files changed
3. Check file paths against override-trigger lists (enforcement + governance files)
4. Check for Deep promotion triggers (security-relevant, cross-layer)
5. Apply tier promotion logic — highest tier wins

**User override**: If the `/review-code` invocation includes a depth keyword
(`light`, `standard`, or `deep`), use that tier instead of the automatic
classification.

Record the tier and the primary signal that determined it for the report header.

### 3. Load project context

For project repo PRs:
- Read `.agents/README.md` for architecture overview, key files, cross-layer
  dependencies, and pitfalls
- Check for `.agents/review-context.yaml` — if present, use it for the compact
  relevance map (packages, topics, dependencies)
- **Staleness check**: If `review-context.yaml` exists, compare its
  `context_generated_from_sha` field against the current HEAD of the project
  repo. If they differ, include a warning in the report header:

  > ⚠ Review context is stale (generated from `<sha>`; repo HEAD is `<sha>`).
  > Consider running `/gather-project-knowledge` to refresh.

  If `review-context.yaml` does not exist, note this in the report header:

  > ℹ No review-context.yaml found. Review proceeds with .agents/README.md only.

- Read project `PRINCIPLES.md` if it exists
- Check `.agent/project_knowledge/` symlink for workspace-level project summaries

### 4. Classify changed files

Determine the review profile for each changed file:

| File location | Language detection | Linter config profile |
|---|---|---|
| `.agent/scripts/*.py`, `.agent/hooks/*.py` | Python | workspace (max-line-length=100, Black compat) |
| `project/**/*.py` | Python | project config or workspace defaults |
| `*.cpp`, `*.hpp`, `*.h`, `*.cc`, `*.cxx` | C++ | cppcheck; clang-tidy if compile_commands.json exists |
| `*.sh` | Shell | shellcheck --severity=warning |
| `*.yaml`, `*.yml` | YAML | yamllint (max-line-length=120) |
| `*.xml` | XML | xmllint |
| `*.js`, `*.ts`, `*.jsx`, `*.tsx` | JS/TS | project ESLint config if available |

See `.agent/knowledge/review_static_analysis.md` for full tool configs.

### 5. Dispatch specialists

Dispatch specialists based on the depth tier from step 2. Run independent
specialists in parallel (use Agent tool with subagents when available,
otherwise evaluate sequentially).

#### Light tier

Run only:
- **5a. Static Analysis Specialist**

#### Standard tier

Run all of:
- **5a. Static Analysis Specialist**
- **5b. Governance Specialist**
- **5c. Plan Drift Specialist**
- **5d. Claude Adversarial Specialist**

#### Deep tier

Run all of Standard, plus:
- **5e. Gemini Adversarial Specialist** (via cross-model review script)

---

#### 5a. Static Analysis Specialist

Run linters on **changed files only**, using the config profile from step 4.
See `.agent/knowledge/review_static_analysis.md` for exact commands and flags.

If **no linter profile matches any changed file**, report this explicitly:
"No static analysis profile configured for these file types (`.ext1`, `.ext2`)."
Do not silently produce an empty findings section — the reviewer and user need
to know that absence of findings means "not checked", not "code is clean."

Report each finding as:
- File, line number, tool name, message
- Skip findings on lines not touched by this PR (context-only lines)

**`--skip-static` flag** (both modes): skip this specialist entirely.
Useful when pre-commit was clean and the user wants a faster review, or
when the user has already run linters separately. Note that skipping
this at Light tier leaves the review with no specialists; the silence
filter will produce the "No findings" output, which is the documented
behavior.

#### 5b. Governance Specialist

Load governance context:
- `.agent/knowledge/principles_review_guide.md` — evaluation criteria
- `docs/PRINCIPLES.md` — workspace principles
- `docs/decisions/*.md` — ADRs (scan titles, read those triggered by this change)
- Project-level governance (if applicable)

**Principle evaluation**: For each relevant principle, assess the PR:

| Verdict | Meaning |
|---|---|
| **Pass** | PR clearly adheres |
| **Watch** | Not a violation, but worth noting |
| **Concern** | Potential violation that should be addressed |
| **N/A** | Principle doesn't apply |

Skip principles that clearly don't apply.

**ADR compliance**: Using the ADR applicability table, identify triggered ADRs.
For each: does the PR comply with the key requirement?

**Consequence check**: Using the consequences map, check if this PR changes
something in the "If you change..." column. Are the corresponding "Also update..."
items addressed? Mark each as Done or Missing.

**Existing review comments** (PR mode only): Check for unresolved human
and bot comments:

```bash
.agent/scripts/fetch_pr_reviews.sh --pr <N>
```

Note unresolved human comments (high priority), valid bot findings, and false
positives. Skip this sub-step in branch mode — there's no PR yet.

#### 5c. Plan Drift Specialist

If a work plan exists (`.agent/work-plans/issue-*/plan.md`):
- Read the plan's "Approach" and "Files to Change" sections
- Compare against the actual diff:
  - Files listed in plan but not changed? (incomplete)
  - Files changed but not in plan? (scope creep or oversight)
  - Approach deviations? (different from what was planned)
- Report deviations as suggestions (not must-fix — plans are guides, not contracts)

If no work plan exists, skip this specialist.

#### 5d. Claude Adversarial Specialist

**Activates at**: Standard, Deep

Launch as a **fresh subagent** with no context from the other specialists.
The adversarial reviewer reads the diff and full changed files independently.

Focus areas:
- Missed edge cases and boundary conditions
- Security implications (injection, auth bypass, data exposure)
- Assumption violations (what does the code assume that might not hold?)
- Subtle bugs (off-by-one, race conditions, resource leaks)
- Logic errors (does the code actually do what the PR claims?)

Report findings in the same format as other specialists (file, line, severity,
description). The silence filter will deduplicate any overlap with other
specialists' findings.

The fresh-context model is deliberate: an independent reviewer that agrees
with the governance specialist is a stronger signal than one told what to
look for.

#### 5e. Cross-Model Adversarial Specialist(s)

**Activates at**: Deep only

Determine the calling agent's framework and dispatch all available non-caller
agents. Use `$AGENT_FRAMEWORK` if set; fall back to
`source .agent/scripts/detect_cli_env.sh || true` if unset or "unknown". Normalize
the framework key (lowercase) and apply explicit aliases to match the agent
keys used by the script: `claude-code` → `claude`, `gemini-cli` → `gemini`,
`codex-cli` → `codex`, `copilot-cli` → `copilot`. The canonical keys are:
`gemini`, `codex`, `claude`, `copilot`.

For each non-caller agent, launch the cross-model review script. Use
`--pr <N>` in PR mode and `--branch [<ref>]` in branch mode (mutually
exclusive — passing both is a hard error).

```bash
# PR mode — example: Claude is the caller, dispatch gemini, codex, copilot
.agent/scripts/cross_model_review.sh --pr <N> --agent gemini --repo owner/repo
.agent/scripts/cross_model_review.sh --pr <N> --agent codex --repo owner/repo
.agent/scripts/cross_model_review.sh --pr <N> --agent copilot --repo owner/repo

# Branch mode — runs locally, no --repo needed in most cases
.agent/scripts/cross_model_review.sh --branch --agent gemini
.agent/scripts/cross_model_review.sh --branch <base> --agent codex
.agent/scripts/cross_model_review.sh --branch --agent copilot --no-progress  # skill worktrees
```

Pass `--repo <owner/repo>` (PR mode) when the PR lives in a different repo
than the current working directory (e.g., reviewing a project PR from the
workspace tree). Pass `--work-dir <path>` to place artifacts in a specific
worktree instead of the current `git rev-parse --show-toplevel`.

**Depth keywords are skill-level only.** `cross_model_review.sh` itself
does not parse `light`/`standard`/`deep` — those control which
specialists this skill dispatches. Passing them to the script will
trigger an "Unknown argument" error.

The script auto-detects the execution mode: tmux (background) when available,
sync (blocking) when tmux is unavailable or in sandboxed environments. Use
`--sync` to force synchronous execution. For each target agent, the script:
1. Writes a review prompt to `.agent/work-plans/issue-<issue>/review-<agent>-prompt.md`
2. Runs the agent (in tmux session `review-<agent>-<issue>` or synchronously)
3. Agent writes findings to `.agent/work-plans/issue-<issue>/review-<agent>-findings.md`

The prompt and findings files are not committed (see #193) — gitignored when written under `.agent/work-plans/`, or outside the repo when `--no-progress` puts them in a `/tmp` dir. Regenerated each run, not part of the audit trail. Durable findings belong in `progress.md`.

**If the script exits non-zero** for a given agent (CLI not installed or
unavailable), note it in the report and continue with other agents. One
agent's unavailability does not block the others. Do not fail the review.

**Collecting findings**: After other specialists complete, check each
dispatched agent's findings file (look for `--- Review complete ---` or
`--- Review failed ---` markers). If a review is still running, note this
and tell the user which tmux session to check. Incorporate completed
findings into the unified report.

### 6. Apply silence filter

Collect all findings from all dispatched specialists and filter:

1. **Deduplicate** — if multiple specialists flag the same issue (common
   between adversarial and governance), keep the more specific one
2. **Drop linter-enforced nits** — if pre-commit or CI already catches it,
   don't report it again (the author will see it when they commit/push)
3. **Merge related findings** — group findings about the same logical issue
4. **Classify severity**:
   - **Must-fix** — bugs, security issues, principle violations, missing
     consequences
   - **Suggestion** — improvements worth the author's time
   - Drop anything below suggestion threshold
5. **Silence check** — if no findings survive the filter, report "No issues
   found." Do not invent feedback to fill the report. Target: >=85% of
   reported findings should be actionable.

### 7. Produce the report

PR-mode header:

```markdown
## Code Review: #<N> — <title>

**PR**: <url>
**Issue**: #<issue> — <issue-title>
**Repo**: workspace | <project-repo>
**Files changed**: <count> (+<additions> -<deletions>)
**Review depth**: <Light|Standard|Deep> (reason: <primary signal>)
**Context**: <status of review-context.yaml — fresh / stale / not found>
```

Branch-mode header (replace **PR** with **Branch**/**Base**, and the
title-line PR number with the branch name):

```markdown
## Code Review (Pre-Push): <branch-name>

**Branch**: <branch-name> at `<short-sha>`
**Base**: <base-ref>
**Issue**: #<issue> — <issue-title>  <!-- or "Skipped (--no-progress)" -->
**Repo**: workspace | <project-repo>
**Files changed**: <count> (+<additions> -<deletions>)
**Review depth**: <Light|Standard|Deep> (reason: <primary signal>)
**Context**: <status of review-context.yaml — fresh / stale / not found>
```

The body sections (Must-Fix, Suggestions, Governance, Plan Adherence,
Cross-Model Reviews, Existing Review Comments, Summary, Recommended
Actions) are identical between modes — except **Existing Review Comments**
is omitted in branch mode (no PR yet).

PR-mode template body:

```markdown

### Must-Fix

| # | Source | File | Line | Finding |
|---|--------|------|------|---------|
| 1 | <specialist> | `path` | 42 | Description |

### Suggestions

| # | Source | File | Line | Finding |
|---|--------|------|------|---------|
| 1 | <specialist> | `path` | 10 | Description |

### Governance

| Principle | Verdict | Notes |
|---|---|---|
| ... | ... | ... |

| ADR | Triggered | Compliant | Notes |
|---|---|---|---|
| ... | ... | ... | ... |

| Changed | Required update | Status |
|---|---|---|
| ... | ... | Done / Missing |

### Plan Adherence

<comparison summary, or "No work plan found">

### Cross-Model Reviews

<For each dispatched agent, a sub-section with its findings or status note>

#### <Agent Name>
<Findings if review completed, or status (running / unavailable / failed)>

### Existing Review Comments

- <summary of unresolved comments, if any>

### Summary

<1-3 sentence overall assessment>

### Recommended Actions

- [ ] <specific action items, if any>
```

**Light tier condensed format** — skip Governance, Plan Adherence, Cross-Model,
and Existing Review Comments sections. Use:

```markdown
## Code Review: #<N> — <title>

**PR**: <url>
**Review depth**: Light (reason: <primary signal>)

### Static Analysis

| # | File | Line | Finding |
|---|------|------|---------|
| 1 | `path` | 42 | Description |

No governance concerns for a change of this scope.
```

**No findings format** — if no findings exist across all sections:

```markdown
## Code Review: #<N> — <title>

**PR**: <url>
**Review depth**: <tier> (reason: <signal>)
No issues found. LGTM.
```

**Branch-mode equivalents**: for both the Light condensed and No-findings
formats, swap the title line for `## Code Review (Pre-Push): <branch-name>`
and replace the `**PR**: <url>` line with
`**Branch**: <name> at <sha>` and `**Base**: <base-ref>`. Other content
unchanged.

### 8. Persist review summary to progress file

After outputting the report to the conversation, append a review-step
entry to `progress.md` so findings persist across sessions.

**Skip this entire step** if branch mode was invoked with
`--no-progress` — that flag explicitly opts out of progress.md writes
(skill worktrees and one-off branches without an issue context).

**Locate or create progress.md**: Use the issue number resolved in step 1.
Determine which repo owns the linked issue (workspace repo for workspace
issues, project repo for project issues). Check
`.agent/work-plans/issue-<issue>/progress.md` in the owning repo's worktree
first. If not found there, fall back to the current worktree. If it does not
exist in either location, create it in the owning repo's worktree (or the
current worktree if no owning worktree exists) with frontmatter. Fetch the
issue title via
`gh issue view <issue> --repo <owner/repo> --json title --jq '.title'`:

```yaml
---
issue: <issue>
---

# Issue #<issue> — <issue title>
```

Append this step entry. Use `## Local Review` for PR mode and
`## Local Review (Pre-Push)` for branch mode so the same issue can carry
both a pre-push and a post-PR entry on its timeline without one
overwriting the other:

```markdown

## Local Review              <!-- PR mode -->
## Local Review (Pre-Push)   <!-- branch mode -->
**Status**: complete
**When**: <YYYY-MM-DD HH:MM>
**By**: <agent name> (<model>)
**Verdict**: <approved|changes-requested>

**PR**: #<N> at `<short-sha>`        <!-- PR mode -->
**Branch**: <name> at `<short-sha>`  <!-- branch mode -->
**Base**: <base-ref>                 <!-- branch mode -->
**Depth**: <tier> (reason: <signal>)
**Must-fix**: <count> | **Suggestions**: <count>

### Findings
- [ ] (must-fix) <one-line summary> — `file:line`
- [ ] (suggestion) <one-line summary> — `file:line`
```

If no findings survived the silence filter, set `**Verdict**: approved`,
`**Must-fix**: 0 | **Suggestions**: 0`, and write `No issues found. LGTM.`
under Findings.

Key points:
- Use `- [ ]` checkboxes so findings can be checked off as addressed
- Include only the one-line summary and location, not the full description
- Commit progress.md after appending. Run `git add` and `git commit` in the
  worktree where progress.md was found or created (which may differ from the
  current working directory):
  `git -C <worktree-path> add .agent/work-plans/issue-<issue>/progress.md && git -C <worktree-path> commit -m "progress: local review for #<issue>"`

## Guidelines

- **Report first, then persist** — output the review in the conversation,
  append a step to progress.md, and commit it (step 8). The user decides
  whether to post it as a PR comment, request changes, or act on findings.
- **Be specific** — "Must-fix: null check missing before `result.data` access
  at line 42" is useful. "Watch: could add more error handling" is not.
- **Read the code** — don't just check file names. Read full files and the diff
  to evaluate correctness and principle adherence.
- **Silence is a feature** — saying nothing when there's nothing to say is
  better than generating low-value comments. If the code is fine, say so briefly.
- **Project governance** — for project repo PRs, apply both workspace and project
  governance. Note conflicts between them if any.
- **Severity matters** — every finding must be classified as must-fix or
  suggestion. Unclassified findings are noise.
- **Context-aware linting** — use project-specific configs for project code,
  pre-commit configs for workspace infrastructure code. Never mix them.
- **Depth is transparent** — always show the tier and reason in the report
  header. If the user disagrees with the classification, they can re-run with
  an explicit depth keyword.
- **Graceful degradation** — if Gemini is unavailable at Deep tier, proceed
  with Claude-only adversarial. Never fail a review because an optional
  tool is missing.
