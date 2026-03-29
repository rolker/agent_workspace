---
name: review-code
description: Lead reviewer that orchestrates specialist sub-reviews (static analysis, governance, plan drift, adversarial) to evaluate a PR. Scales review depth to change risk. Produces a unified structured report.
---

# Review Code

## Usage

```
/review-code <pr-number-or-url> [light|standard|deep]
```

Optional depth keyword overrides automatic classification.

## Overview

**Lifecycle position**: review-issue → plan-task → review-plan → implement → **review-code**

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
- **Static Analysis** — runs linters with ament-aligned configs on changed files
- **Governance** — evaluates against principles, ADRs, and consequences
- **Plan Drift** — compares implementation against the work plan (if one exists)
- **Claude Adversarial** — fresh subagent, independent review for missed issues (Standard + Deep)
- **Gemini Adversarial** — cross-model review via Gemini CLI in tmux (Deep only)

## Steps

### 1. Gather PR context

```bash
# PR metadata
gh pr view <N> --json title,body,baseRefName,headRefName,headRefOid,files,additions,deletions,url,comments,reviews

# Full diff
gh pr diff <N>

# Linked issue
gh pr view <N> --json body --jq '.body' | grep -o '#[0-9]*'
```

Identify:
- What repo the PR targets (workspace or project repo?)
- What files changed and in which directories
- The linked issue and its requirements
- Whether a work plan exists (`.agent/work-plans/issue-*/plan.md` in the PR's target repo)

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
| `layers/*/src/**/*.py` | Python | ament (max-line-length=99, ament ignores) |
| `layers/*/src/**/*.cpp`, `*.hpp` | C++ | ament (cpplint, cppcheck) |
| `.agent/scripts/*.py` | Python | workspace (max-line-length=100, Black compat) |
| `.agent/scripts/*.sh` | Shell | workspace (shellcheck --severity=warning) |
| `*.yaml`, `*.yml` | YAML | yamllint (max-line-length=120) |
| `*.xml`, `*.launch.xml` | XML | xmllint |

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

Report each finding as:
- File, line number, tool name, message
- Skip findings on lines not touched by this PR (context-only lines)

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

**Existing review comments**: Check for unresolved human and bot comments:

```bash
.agent/scripts/fetch_pr_reviews.sh --pr <N>
```

Note unresolved human comments (high priority), valid bot findings, and false
positives.

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

#### 5e. Gemini Adversarial Specialist

**Activates at**: Deep only

Launch the cross-model review script:

```bash
.agent/scripts/cross_model_review.sh --pr <N>
```

This starts a Gemini CLI session in a tmux window. The script resolves the
issue number from the PR body (falling back to the PR number). It then:
1. Writes a review prompt to `.agent/work-plans/issue-<issue>/review-gemini-prompt.md`
2. Launches Gemini in tmux session `review-gemini-<issue>`
3. Gemini writes findings to `.agent/work-plans/issue-<issue>/review-gemini-findings.md`

**If the script exits non-zero** (tmux or gemini unavailable), note in the
report: "Cross-model review unavailable — proceeding with Claude-only
adversarial." Do not fail the review.

**Collecting findings**: After other specialists complete, check if the Gemini
findings file has been populated (look for the `--- Review complete ---`
marker or `--- Review failed ---` marker at the end). If the review is still
running, note this in the report and tell the user they can check the tmux
session. If it failed, note the failure. If complete, read the findings file
and incorporate results into the unified report.

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

```markdown
## Code Review: #<N> — <title>

**PR**: <url>
**Issue**: #<issue> — <issue-title>
**Repo**: workspace | <project-repo>
**Files changed**: <count> (+<additions> -<deletions>)
**Review depth**: <Light|Standard|Deep> (reason: <primary signal>)
**Context**: <status of review-context.yaml — fresh / stale / not found>

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

### Cross-Model Review (Gemini)

<Gemini findings if Deep tier and review completed, or status note>

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

### 8. Persist review summary to plan file

After outputting the report to the conversation, append a compact review
summary to the plan file so findings persist across sessions.

**Locate the plan file**: Use the issue number resolved in step 1. Check
`.agent/work-plans/issue-<issue>/plan.md` in the current worktree. If the
PR targets a project repo, also check the workspace repo's work-plans
directory. If both locations have a plan file, prefer the workspace copy
(canonical location for workspace issues) and note the duplicate in the
conversation.

**If no plan file exists**: Skip with a note in the conversation: "No plan
file found — review summary not persisted." Do not create a plan file.

**If a plan file exists**: Read it and check for existing review blocks
(sections starting with `## Review:`). For each existing review block whose
`**Status**:` is not already `Superseded`, change its `**Status**:` line to
`Superseded by review on <YYYY-MM-DD>`.

Then append this block to the end of the plan file:

```markdown

## Review: <tier> — <YYYY-MM-DD>

**PR**: #<N> at `<short-sha>` (use `headRefOid` from step 1, truncated to 7 chars)
**Must-fix**: <count> | **Suggestions**: <count>
**Status**: Pending

### Findings
- [ ] (must-fix) <one-line summary> — `file:line`
- [ ] (suggestion) <one-line summary> — `file:line`
```

Key points:
- Use `- [ ]` checkboxes so findings can be checked off as addressed
- Include only the one-line summary and location, not the full description
  (the full report is in the conversation and optionally posted as a PR comment)
- If no findings survived the silence filter, use `**Must-fix**: 0 |
  **Suggestions**: 0`, set `**Status**: Approved`, and write under Findings:
  ```
  No issues found. LGTM.
  ```
- **Do not commit** the updated plan file automatically. The author decides
  when to commit (they may want to address findings first and commit the
  checked-off version).

## Guidelines

- **Report first, then persist** — output the review in the conversation and
  append a summary to the plan file (step 8). The plan-file write is the only
  autonomous side effect; the user decides whether to post it as a PR comment,
  request changes, or act on findings.
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
- **Context-aware linting** — use ament configs for ROS package code, pre-commit
  configs for workspace infrastructure code. Never mix them.
- **Depth is transparent** — always show the tier and reason in the report
  header. If the user disagrees with the classification, they can re-run with
  an explicit depth keyword.
- **Graceful degradation** — if Gemini is unavailable at Deep tier, proceed
  with Claude-only adversarial. Never fail a review because an optional
  tool is missing.
