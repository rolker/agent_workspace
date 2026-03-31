# Workspace UX Roadmap

Living document tracking planned improvements, prioritized by pain relief.
Maintained through `/brainstorm` sessions; fed by `/inspiration-tracker` findings.

**Guiding goal** (from initial brainstorm on #63): "How I interact with the system
and keep track of what's relevant while not needing to micromanage."

## User Scenarios

These scenarios describe the target experience. Roadmap items are prioritized
by how much they improve these workflows.

### 1. Feature implementation (end-to-end)

Agent searches before recommending, pushes back honestly, carries context
through brainstorm -> plan -> implement. Runs local pre-flight review before
pushing. When Copilot finds something local review missed, it becomes a
learning signal that improves future local reviews. PRs open clean.

### 2. Design iteration (symptom-driven)

Triggered by issue accumulation suggesting the higher-level design has gaps.
Agent reads design docs + open issues, identifies root causes across issues
(not treating them individually), challenges assumptions, updates the design
doc, and opens issues for fixes.

### 3. Managing concurrent agents

Dashboard replaces terminal tabs + browser for monitoring. Permission profiles
reduce interrupts. Agents self-manage review loops. One place to look instead
of 5 terminals + a browser.

### 4. Monday morning bootstrap

Start of day: need to figure out what to work on. Currently requires manually
checking PRs, reviews, issues, worktree state, and uncommitted changes across
repos. A morning status skill gathers all state, surfaces pending decisions
(PRs needing review response, stale worktrees, ready-to-start issues), and
suggests a prioritized work plan for the day.

### Pain points (ranked by severity)

1. **Permission interrupts** across 4-5 agents — constant tab-switching to approve routine ops
2. **Copilot review loop** — push, switch to browser, wait, check if review triggered (manually trigger if not), read findings, switch to terminal, relay findings, fix, repeat 2-3 times per PR
3. **Browser + terminals** — two separate interfaces to monitor
4. **Agent sycophancy** — wastes brainstorm/planning rounds
5. **No context carryover** between skill invocations
6. **Manual cleanup** after merges

### Key insight: Copilot learning loop

The goal isn't to replace Copilot review — it's to pre-clear locally so PRs
pass on first try. Misses become learning signals:

```
Local pre-flight review -> Fix locally
    |
    v
Push -> Copilot review
    |
    v
Clean? -> Merge
Findings? -> Fix + "Why did local review miss this?" -> Update local patterns
    |
    v
Push again (should be clean)
```

Over time, local review gets smarter. Copilot round-trips go from 2-3 per PR
to 0-1.

## Priority: Improve Local Reviews

The biggest actionable time sink: push -> wait for Copilot review -> triage
findings -> fix -> push again. If local pre-flight review catches what Copilot
would flag, PRs pass on first try.

| Item | Issue | Status | Source | Notes |
|------|-------|--------|--------|-------|
| Adaptive review depth | #47 | done | gstack | Scale effort to change risk; cross-model via Gemini CLI (PR #76) |
| Cognitive review patterns | #54 | planned | gstack | Reusable checklists for common mistake types |
| Fix-first review workflow | #52 | planned | gstack | Fix issues during review, don't just report |
| Spec compliance vs quality split | #27 | planned | superpowers | Separate "does it meet spec" from "is it good" |
| Adversarial self-review | #55 | planned | gstack | Agent challenges its own work |
| Review summary in plan files | #83 | planned | brainstorm | Append review findings to plan file; lighter alternative to JSONL |
| JSONL review tracking | #51 | deferred | gstack | Machine-queryable layer; reconsider if plan-file approach (#83) isn't sufficient |
| Plan status tracking in reviews | #49 | subsumed by #88 | gstack | Reviews update progress.md instead of tracking in plan file |
| Continual learning from reviews | #42 | planned | microsoft/skills | Misses feed back into local review patterns |
| JS/web static analysis profile | #81 | planned | review session | review-code linter table missing vanilla JS; silent skip with no report |
| Copilot review loop automation | #69 | planned | brainstorm | Autonomous push/review/fix cycle (after local review is solid) |

## Priority: Reduce Agent Coordination Overhead

Roland runs 4-5 concurrent agents. Coordination is currently manual: browser
for Copilot status, telling agents to cleanup/sync, permission prompts.

| Item | Issue | Status | Source | Notes |
|------|-------|--------|--------|-------|
| Web dashboard | #64 | planned | ros2_agent_workspace | Anchor for multi-agent visibility; inspired by upstream #398 |
| Agent health monitoring | #34 | planned | gastown | Dashboard surfaces agent status |
| **Lifecycle progress tracking** | **#88** | **in progress** | **brainstorm** | **progress.md + workflow templates by involvement level; consolidates #33, #36, #49** |
| Persistent work state | #33 | subsumed by #88 | gastown | Survives crashes; progress.md is the persistent state |
| Session continuity | #36 | subsumed by #88 | gastown + brainstorm | progress.md gives new sessions full context |
| Inter-agent messaging | #35 | planned | gastown | Structured communication between agents |
| Structured agent handoffs | #40 | planned | microsoft/skills | Tool scoping per agent role |
| Permission prompt reduction | — | in progress | brainstorm | #1 friction point; tool-use logging hook deployed, analyze then build targeted allowlist |
| Morning status / standup skill | — | planned | brainstorm | Gather PR, review, issue, worktree state; suggest prioritized work plan (scenario 4) |
| Crash recovery skill | #70 | planned | brainstorm | Session-specific scratchpad subdirs |

## Priority: Improve How Agents Think

How agents approach problems at different levels of abstraction.

| Item | Issue | Status | Source | Notes |
|------|-------|--------|--------|-------|
| Brainstorm multi-level modes | #71 | planned | gstack | Vision/strategy/architecture/design with auto-detection. Inspired by gstack's office-hours -> CEO review -> eng review -> design review hierarchy, adapted as modes within a single skill. |
| Success indicators in AGENTS.md | #43 | planned | microsoft/skills | Observable behaviors confirming principles work |
| Systematic debugging | #31 | planned | superpowers + gstack | "No fixes without root cause" discipline. superpowers' 4-phase investigation + gstack's "Iron Law: no fixes without root cause" |

## Priority: Skill Infrastructure

Foundation pieces that make the skill library scalable and reliable.

| Item | Issue | Status | Source | Notes |
|------|-------|--------|--------|-------|
| Progressive skill disclosure | #39 | planned | microsoft/skills | Three-level loading (metadata/body/references) to reduce context pressure; prerequisite for skill chaining |
| Skill chaining / proactive suggestions | #60 | planned | gstack + superpowers | Skills suggest next skill; gstack's `benefits-from` + superpowers' auto-triggering (#26) |
| Headless integration tests | #28 | planned | superpowers | Run skills in headless mode, parse JSONL transcripts |
| YAML scenario-based skill testing | #41 | planned | microsoft/skills | Declarative YAML scenarios; complementary approach to #28 |
| Prevent gh CLI wrong-repo targeting | #72 | planned | brainstorm | Bug fix: always use -R, add safeguard to gh_create_issue.sh |

## Unphased

Small fixes that can be done anytime.

| Item | Issue | Status | Notes |
|------|-------|--------|-------|
| Research skill worktree fix | #45 | planned | Fix project worktree path + staleness tracking |
| Gemini CLI PATH resilience | #82 | planned | cross_model_review.sh fails when gemini not on session PATH |

## Decided Against

Items considered and rejected, with reasons.

(None yet.)

## To Consider

New findings from inspiration tracker, not yet discussed in a brainstorm session.

### Review & Quality Patterns
- **Anti-sycophancy patterns** (#48) — Banned phrases, worked pushback examples for brainstorm/review skills. General patterns applied to AGENTS.md; skill-specific patterns (gated escape hatch) still to consider. Source: gstack
- **Explicit scope modes for planning** (#56) — Four modes: expansion, selective expansion, hold, reduction. Source: gstack plan-ceo-review
- **AI slop detection in design review** (#61) — Check for generic AI patterns (hero sections, card grids, stock imagery). Source: gstack design-review
- **Diff-aware test targeting** (#53) — Map git diff to affected test targets, focus QA on what changed. Source: gstack

### Agent Discipline & Self-Improvement
- **Search-before-building step** (#50) — Search for runtime built-ins and best practices before recommending infrastructure. Three-layer knowledge framework. Source: gstack
- **Completeness principle** (#59) — Prefer full implementation when AI compresses effort 10-100x. "Lake vs ocean" distinction. Source: gstack
- **Agent friction self-reporting** (#58) — Agent rates experience 0-10 after workflow steps, files field reports when not 10. Source: gstack

### Safety & Guardrails
- **PreToolUse safety hooks** (#57) — Three-tier hierarchy: careful (warn), freeze (block edits outside path), guard (both). Source: gstack

### Multi-Agent Infrastructure
- **tmux session strategy** (#65) — Named sessions for agents (`agent-issue-N`) and applications, dashboard integration. Source: ros2_agent_workspace
- **Enhanced start-task with tmux** (#66) — Worktree + tmux session + agent launch in one command. Source: ros2_agent_workspace
- **Workflow modes** (#67) — Autonomous / collaborative / pair per-session, with permission implications. Source: ros2_agent_workspace

## Cross-cutting Decisions

Decisions that apply across multiple items.

### Storage model

Two files per issue in `.agent/work-plans/issue-N/`:
- `plan.md` — what we're going to do (reference document, stable after approval)
- `progress.md` — what actually happened (append-only log, updated by skills)

Previously (#83), review-code appended summaries to plan.md. Going forward,
all lifecycle tracking moves to progress.md. Plan.md stays clean as a
reference. Review summaries in plan.md continue to work until skills are
updated to write to progress.md instead.

JSONL (#51) remains a future option for machine-queryable cross-issue queries.

Git refs (`refs/agent-state/issue-N/reviews`) explored in depth — crash-safe,
worktree-shared, per-issue scoped — but deferred as premature complexity.

### Review architecture (5-layer model)

Unifies review-related items from superpowers (#27), gstack (#47, #49, #51,
#52, #54, #55), and brainstorm into a single coherent system:

```
Layer 1: Adaptive depth (#47)
  Scale review effort to change risk (diff size, file type, complexity)

Layer 2: Cognitive patterns (#54) + spec/quality split (#27) + adversarial (#55)
  What to look for, organized by concern type. Spec compliance (does it
  meet requirements?) separated from code quality (is it well-written?).
  Adversarial pass challenges the agent's own work.

Layer 3: Fix-first (#52)
  Fix mechanical issues during review, only flag judgment calls.

Layer 4: Tracking (#51) + plan status (#49)
  JSONL records what was found and fixed. Plan file shows whether the
  review addressed all planned items.

Layer 5: Continual learning (#42 -> #69)
  Misses feed back into cognitive patterns. Copilot review findings
  that local review missed become learning signals.
```

### Progress as lifecycle record

progress.md replaces the plan-as-accumulator pattern. All lifecycle steps
(brainstorm, plan, implement, review, test) append to progress.md rather
than to plan.md. The plan stays a stable reference; progress tells the
full story. Workflow templates (`.agent/workflows/`) define the available
steps and human involvement level per workflow type.

### Roadmap over issues for planning

Inspiration tracker adds findings to the "To Consider" section instead of
creating GitHub issues. Issues are created only when work is ready to begin.
This keeps brainstorming local (no GitHub API calls to fetch 25 issue bodies)
and reduces issue noise.

### Triage-and-fix sessions

During brainstorm or triage sessions, obviously correct fixes (doc updates,
config, skill text) can be included in the same PR rather than opening
separate issues. Harder fixes that need verification stay as issues. The
draft PR serves as the review checkpoint — review the diff and let Copilot
check it before merging. Review layers are batched, not bypassed.

### Permission prompt reduction strategy

1. Log all tool use via PreToolUse hook to `~/.claude/tool-use-log.jsonl`
2. After a week, analyze patterns to find always-approve commands
3. Build targeted allowlist (e.g., read-only git commands)
4. Migrate multi-step skill sequences to scripts (fewer permission checks
   + fewer tokens)
5. Add explicit progress reporting to skills to replace the visibility
   lost from fewer prompts

## Design History

### Original C->B->A phasing

The initial brainstorm organized items into three phases based on dependency
reasoning: Phase C (Honest Advisor — how agent thinks) must come first
because everything downstream benefits from better thinking. Phase B
(Careful Builder — how agent works) depends on honest thinking. Phase A
(Diligent Reviewer — how agent evaluates) depends on careful building.

This was revised to pain-first prioritization because the C->B->A ordering
optimized for architectural elegance but scheduled the biggest pain points
(permission prompts, Copilot review loop) last. The dependency reasoning
remains valid — items within each priority group are still sequenced so
foundations come before things that depend on them.

### Inspiration sources

This roadmap draws from four external projects tracked by `/inspiration-tracker`:

- **gstack** (garrytan/gstack) — Skills framework with hierarchical review
  pipeline (office-hours -> CEO review -> eng review -> design review -> ship),
  anti-sycophancy patterns, completeness principle, safety hooks, friction
  self-reporting, JSONL analytics
- **superpowers** (obra/superpowers) — Headless skill testing, spec/quality
  review split, auto-triggering skills, systematic debugging, verification
  before completion
- **microsoft/skills** — Progressive skill disclosure, YAML scenario testing,
  structured agent handoffs, success indicators, continual learning
- **gastown** — Git-backed persistent work state ("beads"), agent health
  monitoring, inter-agent messaging (nudge/mail), session continuity ("seance")
- **ros2_agent_workspace** (rolker/ros2_agent_workspace) — Fork origin of this
  workspace. Web dashboard, tmux session strategy, workflow modes, enhanced
  start-task

Several roadmap items blend ideas from multiple sources. Key blends:
- **5-layer review architecture**: superpowers spec/quality split + gstack
  adaptive depth, cognitive patterns, fix-first, JSONL tracking, adversarial
  review
- **Systematic debugging** (#31): superpowers 4-phase investigation + gstack
  "Iron Law: no fixes without root cause"
- **Skill chaining** (#60): gstack `benefits-from` field + superpowers
  auto-triggering
- **Brainstorm multi-level modes** (#71): gstack's 4-skill hierarchy (office-hours,
  plan-ceo-review, plan-eng-review, plan-design-review) adapted as modes within
  a single skill with auto-detection
- **Session continuity** (#36 + #70): gastown's "seance" cross-session query +
  workspace-specific crash recovery needs
- **Skill testing** (#28 + #41): superpowers headless JSONL transcript parsing +
  microsoft declarative YAML scenarios as complementary approaches
