---
name: review-code
description: Lead reviewer that orchestrates specialist sub-reviews (static analysis, governance, plan drift, adversarial) to evaluate a PR. Scales review depth to change risk. Produces a unified structured report.
session_scope: both
---

# Review Code

## Workspace root

This skill can run in a **project** session — a session started in a project
checkout, not in the workspace. There, `$WS_ROOT/.agent/scripts/...` does not resolve:
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
relative path it replaced. With the fallback, `$WS_ROOT` is `.` and a
workspace session behaves exactly as it did before this idiom existed.

## Usage

```
# PR mode (default — review an open PR)
/review-code <pr-number-or-url> [light|standard|deep] [--skip-static]

# Branch mode (local pre-push self-review)
/review-code --branch [<base-ref>] [--issue <N>] [--no-progress] [--strict-progress] [--skip-static] [light|standard|deep]
```

Optional depth keyword overrides automatic classification. `--skip-static`
suppresses the static-analysis specialist in either mode (useful when
pre-commit was clean). `--no-progress` (branch mode only) skips the
progress.md persistence step — used for skill worktrees and one-off
branches that don't have an issue to track against. `--strict-progress`
forces step 8's strict persistence path (`resolve_work_plans_dir()` +
`progress_append.sh`, fail-loud) for this one run regardless of the
ambient `PROGRESS_PERSISTENCE_STRICT` default — see step 8.

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

**Depth tiers** (see `$WS_ROOT/.agent/knowledge/review_depth_classification.md`):
- **Light** — static analysis only (small, low-risk changes)
- **Standard** — Static Analysis, Governance, Plan Drift, Claude adversarial + cross-model adversarial (every available non-caller CLI agent, in one `--agents` call) (medium or governance-touching)
- **Deep** — same specialists and same report sections as Standard (large, security, or cross-layer)

Since #320 the Deep tier dispatches exactly what Standard does; the tiers
differ only in the classification thresholds that select them. Light is
unchanged: static analysis only, no cross-model dispatch.

**Specialists**:
- **Static Analysis** — runs linters on changed files using project or workspace configs
- **Governance** — evaluates against principles, ADRs, and consequences
- **Plan Drift** — compares implementation against the work plan (if one exists)
- **Claude Adversarial** — fresh subagent, independent review for missed issues (Standard + Deep)
- **Cross-model Adversarial** — independent reviews by the non-caller CLI agents (Gemini via agy, Codex, Copilot), run in parallel by `cross_model_review.sh` (Standard + Deep)

**Not ported from ros2_agent_workspace** (issue #269 PR B, documented so
nobody looks for them): the Ollama `local_review.sh` / `--local`
specialist (no local-model serving story here), the Copilot-CLI
`--copilot` specialist and its untrusted-PR gate (no `copilot` CLI
integration), and the container dispatcher (`dispatch_subagent.sh --mode
container`). This skill is invoked directly; nothing dispatches it. Each
would need its own issue if wanted.

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
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
# Resolve base ref. Explicit `--branch <base>` arg wins; otherwise
# the helper consults the per-project manifest (when wired — see #172),
# falls back to `git symbolic-ref refs/remotes/origin/HEAD`, then `main`.
source $WS_ROOT/.agent/scripts/_resolve_default_branch.sh
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
# branches. If neither resolves and `--no-progress` not passed, the
# review still runs; step 8 records "Progress persistence skipped (no
# linked issue)" instead of writing. Also capture `--strict-progress`
# here: it is consumed in step 8 (passed through as `--strict`).
```

Identify (both modes):
- What repo this affects (workspace or project)
- What files changed and in which directories
- The linked issue and its requirements (or `--no-progress` if no issue applies)
- Whether a work plan exists (`$WS_ROOT/.agent/work-plans/issue-*/plan.md`)

Read the **full content** of each changed file (not just the diff hunks) to
understand surrounding context.

### 2. Classify review depth

Load `$WS_ROOT/.agent/knowledge/review_depth_classification.md` and apply the risk
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

(The **File location** column holds repo-relative path *patterns* to match
changed files against — as a diff reports them. They are not commands, so
they carry no `$WS_ROOT` prefix.)

<!-- skill-paths: patterns-not-commands -->

| File location | Language detection | Linter config profile |
|---|---|---|
| `.agent/scripts/*.py`, `.agent/hooks/*.py` | Python | workspace (max-line-length=100, Black compat) |
| `project/**/*.py` | Python | project config or workspace defaults |
| `*.cpp`, `*.hpp`, `*.h`, `*.cc`, `*.cxx` | C++ | cppcheck; clang-tidy if compile_commands.json exists |
| `*.sh` | Shell | shellcheck --severity=warning |
| `*.yaml`, `*.yml` | YAML | yamllint (max-line-length=120) |
| `*.xml` | XML | xmllint |
| `*.js`, `*.ts`, `*.jsx`, `*.tsx` | JS/TS | project ESLint config if available |

See `$WS_ROOT/.agent/knowledge/review_static_analysis.md` for full tool configs.

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
- **5e. Cross-Model Adversarial Specialist(s)** — one `cross_model_review.sh --agents <non-caller agents>` call

#### Deep tier

Run all of Standard. Deep dispatches no additional specialist (#320); the
difference is only in which changes get classified into it.

---

#### 5a. Static Analysis Specialist

Run linters on **changed files only**, using the config profile from step 4.
See `$WS_ROOT/.agent/knowledge/review_static_analysis.md` for exact commands and flags.

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
- `$WS_ROOT/.agent/knowledge/principles_review_guide.md` — evaluation criteria
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
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
$WS_ROOT/.agent/scripts/fetch_pr_reviews.sh --pr <N>
```

Note unresolved human comments (high priority), valid bot findings, and false
positives. Skip this sub-step in branch mode — there's no PR yet.

#### 5c. Plan Drift Specialist

If a work plan exists (`$WS_ROOT/.agent/work-plans/issue-*/plan.md`):
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

**Activates at**: Standard + Deep (Light never dispatches cross-model, #320)

Determine the calling agent's framework and dispatch all available non-caller
agents. Use `$AGENT_FRAMEWORK` if set; fall back to
`source $WS_ROOT/.agent/scripts/detect_cli_env.sh || true` if unset or "unknown". Normalize
the framework key (lowercase) and apply explicit aliases to match the agent
keys used by the script: `claude-code` → `claude`, `gemini-cli` → `gemini`,
`codex-cli` → `codex`, `copilot-cli` → `copilot`. The canonical keys are:
`gemini`, `codex`, `claude`, `copilot`.

Launch the cross-model review script **once**, passing every non-caller
agent in `--agents`; the script runs them in parallel and blocks until
the last one finishes (ADR-0015). Use `--pr <N>` in PR mode and
`--branch [<ref>]` in branch mode (mutually exclusive — passing both is a
hard error).

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
# PR mode — example: Claude is the caller, dispatch gemini, codex, copilot
$WS_ROOT/.agent/scripts/cross_model_review.sh --pr <N> --agents gemini,codex,copilot --repo owner/repo

# Branch mode — runs locally, no --repo needed in most cases
$WS_ROOT/.agent/scripts/cross_model_review.sh --branch --agents gemini,codex,copilot
$WS_ROOT/.agent/scripts/cross_model_review.sh --branch <base> --agents gemini,codex
$WS_ROOT/.agent/scripts/cross_model_review.sh --branch --agents gemini,codex,copilot --no-progress  # skill worktrees
```

Omit an agent from the list when its CLI is known to be unavailable
(e.g. Copilot while its quota is exhausted); a listed agent whose CLI is
missing fails only itself, not the run.

Pass `--repo <owner/repo>` (PR mode) when the PR lives in a different repo
than the current working directory (e.g., reviewing a project PR from the
workspace tree). Pass `--work-dir <path>` to place artifacts in a specific
worktree instead of the current `git rev-parse --show-toplevel`.

**Depth keywords are skill-level only.** `cross_model_review.sh` itself
does not parse `light`/`standard`/`deep` — those control which
specialists this skill dispatches. Passing them to the script will
trigger an "Unknown argument" error.

There is one execution mode: every agent runs synchronously in its own
background job, all in parallel, each bounded by a per-agent timeout
(`AGENT_TIMEOUT`, default 30 minutes; Gemini primarily by its helper's own
`AGY_PRINT_TIMEOUT`, which reports the expiry with a reason, plus an outer
backstop derived above it so a wedged helper is still cut off). There is
no tmux mode and no `--sync` flag any more
(#206, ADR-0015; `--sync` is rejected with exit 2). For each listed
agent, the script:
1. Writes a review prompt to `$WS_ROOT/.agent/work-plans/issue-<issue>/review-<agent>-prompt.md`
2. Runs the agent
3. Agent writes findings to `$WS_ROOT/.agent/work-plans/issue-<issue>/review-<agent>-findings.md`,
   and the script appends `--- Review complete ---` or `--- Review failed ---`
   the moment that agent finishes

The prompt and findings files are not committed (see #193) — gitignored when written under `$WS_ROOT/.agent/work-plans/`, or outside the repo when `--no-progress` puts them in a `/tmp` dir. Regenerated each run, not part of the audit trail. Durable findings belong in `progress.md`.

**Reading the result**: with `--agents`, stdout carries `MODE=parallel-sync`
and then one `AGENT=` / `FINDINGS_FILE=` / `EXIT=` triplet per agent. Key
on each agent's `EXIT=` line, not on the script's overall exit status:
the script exits 3 whenever *any* agent failed, and a failed agent
(CLI not installed, timeout, non-zero exit, empty response, or a
structured error from the CLI) is noted in the report while the others'
findings are used as normal. Note the deliberate gap: a CLI that exits 0
and answers with a quota or auth message is reported as a *completed*
review holding that message — text is never used to fail a run (#313),
so read a suspiciously short "review" before trusting it. `EXIT=` is the agent *job's* status: every agent runs through
a helper that validates its result (`_agy_review.sh` for gemini,
`_cli_review.sh` for codex/claude/copilot), so a failed review is
`EXIT=1` with the CLI's own status and the reason written into the
findings file, and `EXIT=124` means the outer timeout cut it off. One agent's failure does not
block the others and does not fail the review. Exit 3 with **no**
`AGENT=` triplets means the shared prompt could not be built (diff fetch
failed or empty): nothing ran, every listed findings file holds a
`--- Review error: ... ---` marker, and there is nothing to read. Exit 1
means a dependency was missing and nothing was written: either no listed
agent had a usable CLI (each unavailable agent is named on stderr with its
reason), or — in PR mode only — `gh` itself is missing, which aborts
before agent resolution and prints a single `gh not installed` warning
with no per-agent lines. Either way the cross-model specialist is
reported as unavailable. Informational
lines naming each findings file are printed before the agents launch
(for `tail -f`); parse by line prefix, not by position.

**Collecting findings**: After other specialists complete, read each
agent's findings file (look for `--- Review complete ---` or
`--- Review failed ---` markers; a failed file carries the reason on the
lines above the marker — e.g. a headless permission denial, an empty
response, a quota / rate-limit / auth error, a timeout, or a missing CLI
— so report that reason, not an empty review. A findings file never
holds a half-review: each agent's helper truncates it first and then
writes either the review text or the failure reason). The script
blocks until all agents are done, so no review is "still running" when
it returns; for live observation while it runs, `tail -f` the findings
file. Incorporate completed findings into the unified report.

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

**Convergence assessment (branch mode only).** Before writing the report,
assess whether the review loop is converging, so the operator gets a
ship-vs-continue signal instead of looping indefinitely. Both numbers come
from `$WS_ROOT/.agent/scripts/review_progress.sh` (tested in
`test_review_code_convergence.sh`), not from memory:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
# Round = prior `## Local Review (Pre-Push)` entries for THIS branch + 1;
# prev_must_fix = must-fix count of the newest such entry ("-" if none).
$WS_ROOT/.agent/scripts/review_progress.sh round --issue <N> --branch "$BRANCH"

# Ship verdict from the counts. Pass --mechanical only when EVERY must-fix
# is a precise file:line fix with an obvious correction (no design question).
$WS_ROOT/.agent/scripts/review_progress.sh verdict --must-fix <count> --round <R> \
    --prev-must-fix <P> [--mechanical]
```

The rule the script applies:
- **recommended** when there are no must-fix findings.
- **recommended** at round ≥ 2 when must-fix is ≤ 2, not rising versus the
  previous round, and every must-fix is mechanical — fix and ship rather
  than pay for another full dispatch cycle.
- **continue** otherwise: rising, high (> 2), or any design/correctness
  concern that warrants another independent read.

Surface the round, verdict, and reason in the report header (`**Round**`),
the Decision summary, and the `progress.md` entry (step 8). The verdict is
advisory; the operator decides. This skill never blocks a ship. In PR mode
there is no round counter; omit the `**Round**` line.

### 7. Produce the report

Every report opens with a **Decision summary** — the section the owner
reads instead of the diff. It is additional to, not a replacement for, the
findings tables below. This is the one pinned shape (PR F's merge gate and
PR template consume the same headings; do not vary them):

```markdown
## Decision summary

**What changed**: <1-3 sentences, plain language, no diff references>

**Reviews and outcomes**: <round/ship verdict if branch mode; findings
count and verdict if PR mode>

**Open human calls**: <anything requiring a human decision, or "None">

**Verified**: <what was actually run/checked to confirm the above, e.g.
"tests pass; grep confirmed X">

**Recommendation**: <merge / needs-work / hold, one line>
```

Then the header for the mode:

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
**Round**: <R> — **Ship: <recommended | continue>** (<one-line reason; see Convergence assessment>)
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

<!-- Present at Standard and Deep alike (#320); only the Light condensed
     format below omits it, because Light dispatches no cross-model agent. -->

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
and Existing Review Comments sections. The Decision summary still opens
the report. Use:

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

**No findings format** — if no findings exist across all sections (the
Decision summary still opens the report, with Recommendation: merge):

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
entry to `progress.md` so findings persist across sessions. The append,
the commit, and the skip/notice logic all go through one tested call:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
$WS_ROOT/.agent/scripts/review_progress.sh persist --issue "<N or empty>" \
    --branch "$BRANCH" --title "<issue title>" \
    [--strict] [--no-progress] <<'ENTRY'
## Local Review (Pre-Push)
...the entry as specified below...
ENTRY
```

Echo the single line the script prints into the report's Summary. The
script decides which of these happens, in this order:

- **`--no-progress`** (branch mode) — nothing is written; the line reads
  "Progress persistence skipped (--no-progress)".
- **No issue number resolvable** (step 1 found none: a `skill/…` branch,
  or an ordinary branch with no `feature/issue-<N>` shape and no
  `--issue`) — pass `--issue ""`; nothing is written and nothing aborts;
  the line reads "Progress persistence skipped (no linked issue — skill
  worktree)" or "Progress persistence skipped (no linked issue)".
- **Strict path** (`--strict-progress` was passed, so pass `--strict`; or
  the ambient `PROGRESS_PERSISTENCE_STRICT=1`) — the target directory is
  resolved with `resolve_work_plans_dir()` from
  `$WS_ROOT/.agent/scripts/_resolve_work_plans_dir.sh`, which refuses (exit 4, with
  remediation) when the current worktree is not issue `<N>`'s; the entry is
  then appended and committed by `progress_append.sh`, which creates the
  file with frontmatter and the `--title` heading, commits only that file,
  and fails loud if agent identity is unset.
- **Compatibility path** (the default: `PROGRESS_PERSISTENCE_STRICT` unset
  or `0`) — what this step did before issue #269 PR B: the current
  worktree's `$WS_ROOT/.agent/work-plans/issue-<N>/progress.md` is created if
  absent, the entry is appended inline, and `git add` + `git commit` run
  there. The strict path's refusal condition is still *evaluated*, and if
  it would have refused, the script prints "Progress persistence notice:
  would have aborted (resolve_work_plans_dir: <reason>) — running in
  compatibility mode (PROGRESS_PERSISTENCE_STRICT=0)" before proceeding.
  Copy that line into the Summary verbatim; it is the signal PR B2 uses to
  decide when the default can flip.

Fetch the issue title for `--title` via
`gh issue view <issue> --repo <owner/repo> --json title --jq '.title'`.

The entry. Use `## Local Review` for PR mode and
`## Local Review (Pre-Push)` for branch mode so the same issue can carry
both a pre-push and a post-PR entry on its timeline without one
overwriting the other. One heading per entry; `**When**` carries a numeric
UTC offset (ADR-0013):

```markdown
## Local Review              <!-- PR mode -->
## Local Review (Pre-Push)   <!-- branch mode -->
**Status**: complete
**When**: <YYYY-MM-DD HH:MM ±HH:MM>
**By**: <agent name> (<model>)
**Verdict**: <approved|changes-requested>

**PR**: #<N> at `<short-sha>`        <!-- PR mode -->
**Branch**: <name> at `<short-sha>`  <!-- branch mode -->
**Base**: <base-ref>                 <!-- branch mode -->
**Depth**: <tier> (reason: <signal>)
**Must-fix**: <count> | **Suggestions**: <count>
**Round**: <R> | **Ship**: <recommended | continue> — <one-line reason>  <!-- branch mode only -->

### Findings
- [ ] (must-fix) <one-line summary> — `file:line`
- [ ] (suggestion) <one-line summary> — `file:line`
```

If no findings survived the silence filter, set `**Verdict**: approved`,
`**Must-fix**: 0 | **Suggestions**: 0`, and write a single checkbox item
under `### Findings` so the section stays parseable per ADR-0013:
`- [ ] No issues found. LGTM.`

Key points:
- Use `- [ ]` checkboxes so findings can be checked off as addressed.
- Include only the one-line summary and location, not the full description.
- The `**Branch**` line is what the next round's `review_progress.sh round`
  matches on; write the exact branch name.
- Never inline `cat >>` + `git commit` yourself; the script owns both
  paths so the switch is one place, not two.

**Next step.** Verdict `approved` → push (branch mode) or hand to
`triage-reviews` (PR mode). Verdict `changes-requested` → the open boxes
in this entry are the fix plan; print `/address-findings` as the next
command, then this skill runs again to re-review. Never chain it yourself.

**Before the merge.** `merge_pr.sh`'s review gate checks two things on the
PR: this entry (at the PR head, approved) and a `## Decision summary` on
the PR itself, in the body or a comment. Post the Decision summary from
step 7 on the PR (`gh pr comment <N> --body-file ...`) or fill the PR
template's section; a summary that only exists in the conversation does
not count. The gate enforces by default on workspace
PRs (`--report-only` opts out, recording a `## Merge (report-only)` entry
and proceeding) and is local-only (a GitHub "Merge" click bypasses it).

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
- **Graceful degradation** — cross-model failure is per agent. An agent
  whose CLI is missing, that times out, or that exits non-zero carries a
  non-zero `EXIT=` and fails only itself; the review proceeds with
  whichever agents completed, noting the failed one and its reason. If no
  listed agent is usable at all (script exit 1), report the cross-model
  specialist as unavailable and proceed with the Claude adversarial
  specialist. Never fail a review because an optional tool is missing.
