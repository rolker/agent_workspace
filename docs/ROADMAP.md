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
| Cognitive review patterns | #54 | done | gstack | Reusable checklists for common mistake types |
| Fix-first review workflow | #52 | done | gstack | Fix issues during review, don't just report |
| Spec compliance vs quality split | #27 | done | superpowers | Separate "does it meet spec" from "is it good" |
| Adversarial self-review | #55 | done | gstack | Agent challenges its own work |
| Review summary in plan files | #83 | done | brainstorm | Append review findings to plan file; lighter alternative to JSONL |
| JSONL review tracking | #51 | deferred | gstack | Machine-queryable layer; reconsider if plan-file approach (#83) isn't sufficient |
| Plan status tracking in reviews | #49 | subsumed by #88 | gstack | Reviews update progress.md instead of tracking in plan file |
| Continual learning from reviews | #42 | done | microsoft/skills | Misses feed back into local review patterns |
| JS/web static analysis profile | #81 | done | review session | JS/TS added to linter tables (PR #94); no-match fallback message added (PR #100) |
| Copilot review loop automation | #69 | done | brainstorm | Autonomous push/review/fix cycle |
| Anti-sycophancy patterns | #48 | done | gstack | Banned phrases, worked pushback examples; general patterns applied to AGENTS.md |
| AI slop detection in design review | #61 | done | gstack | Check for generic AI patterns (hero sections, card grids, stock imagery) |
| Diff-aware test targeting | #53 | done | gstack | Map git diff to affected test targets, focus QA on what changed |
| Two-mode push policy | — | planned | 2026-04-19 session | Mode 1 push-early vs Mode 2 push-when-ready; doc change + `unpushed_branches.sh` helper |
| Add branch mode to /review-code | #3 | planned | 2026-04-19 session | Pre-push local review via `/review-code --branch <ref>`; `cross_model_review.sh --branch` too. Subsumes prior "review-branch skill" scope of #3. Must work for workspace AND project from day one |
| Feed shell-surface misses back into /review-code | — | planned | 2026-04-19 session | Specific patterns: echo-concat (bash -n accepts), `set -u` + `$1` before check, flag-as-value parsing, gh-failure fall-through. Formalize the Copilot-miss capture loop |
| Flag script/skill changes without tests | #136 | planned | — | review-code enhancement |
| Verification-before-completion skill | #29 | planned | superpowers | Observable verification before marking tasks done |

## Priority: Reduce Agent Coordination Overhead

Roland runs 4-5 concurrent agents. Coordination is currently manual: browser
for Copilot status, telling agents to cleanup/sync, permission prompts.

| Item | Issue | Status | Source | Notes |
|------|-------|--------|--------|-------|
| Web dashboard | #64 | done | ros2_agent_workspace | Anchor for multi-agent visibility; inspired by upstream #398 |
| Agent health monitoring | #34 | done | gastown | Dashboard surfaces agent status |
| Lifecycle progress tracking | #88 | done | brainstorm | progress.md + workflow templates by involvement level; consolidates #33, #36, #49 |
| Persistent work state | #33 | subsumed by #88 | gastown | Survives crashes; progress.md is the persistent state |
| Session continuity | #36 | subsumed by #88 | gastown + brainstorm | progress.md gives new sessions full context |
| Inter-agent messaging | #35 | done | gastown | Structured communication between agents |
| Structured agent handoffs | #40 | done | microsoft/skills | Tool scoping per agent role |
| Permission prompt reduction | #110 | planned | brainstorm | Share workspace-level rules and automate analysis; #1 friction point |
| Morning status / standup skill | — | planned | brainstorm | Gather PR, review, issue, worktree state; suggest prioritized work plan (scenario 4) |
| Post-PR merge/cleanup/sync | #38 | done | session friction | `merge_pr.sh` + `make merge-pr PR=<N>` automates merge, worktree removal, branch cleanup, and sync |
| Crash recovery skill | #70 | done | brainstorm | Session-specific scratchpad subdirs |
| Agent friction self-reporting | #58 | done | gstack | Agent rates experience 0-10 after workflow steps, files field reports when not 10 |
| tmux session strategy | #65 | done | ros2_agent_workspace | Named sessions for agents and applications, dashboard integration |
| Enhanced start-task with tmux | #66 | done | ros2_agent_workspace | Worktree + tmux session + agent launch in one command |
| Workflow modes | #67 | done | ros2_agent_workspace | Autonomous / collaborative / pair per-session, with permission implications |
| Port tmux session management | #2 | revisit | ros2_agent_workspace | **Motivation review pending (2026-04-19 session)**: ros2 ATC protocol solves multi-machine visibility, which we don't have. Narrow use cases here: session persistence, dashboard pane capture, long-lived services. Close or rescope based on concrete motivation |
| Draft zones | #87 | planned | — | Human-edited paths with agent-driven PR incorporation |
| Local integration branches | — | planned | 2026-04-19 session | Per-type dedicated worktrees (`worktrees/workspace/integration/`, `worktrees/project/<repo>/integration/`), declarative config per type, local-only branches, `integration_rebuild.sh --type workspace\|project\|both`. Lets multi-feature integration testing happen without merging to main or pushing prematurely. Unlocks Mode 2 |
| Coordinator agent (simmering) | — | deferred | 2026-04-19 session | Question triage + context restoration across parallel agents. **Hard constraints**: additive-only (never a filter — Roland debugs by watching terminals); cannot handle permission prompts (per-session). Scope = design/scope/confirmation questions (~1/3 of interrupts). Not implementing yet. MVP mechanism: shared question file → coordinator skill → ranked summary. Revisit after other items land |

## Priority: Improve How Agents Think

How agents approach problems at different levels of abstraction.

| Item | Issue | Status | Source | Notes |
|------|-------|--------|--------|-------|
| Brainstorm multi-level modes | #71 | done | gstack | Vision/strategy/architecture/design with auto-detection |
| Success indicators in AGENTS.md | #43 | done | microsoft/skills | Observable behaviors confirming principles work |
| Systematic debugging | #31 | done | superpowers + gstack | "No fixes without root cause" discipline |
| Explicit scope modes for planning | #56 | done | gstack | Four modes: expansion, selective expansion, hold, reduction |
| Search-before-building step | #50 | done | gstack | Search for runtime built-ins and best practices before recommending infrastructure |
| Completeness principle | #59 | done | gstack | Prefer full implementation when AI compresses effort 10-100x |

## Priority: Skill Infrastructure

Foundation pieces that make the skill library scalable and reliable.

| Item | Issue | Status | Source | Notes |
|------|-------|--------|--------|-------|
| Progressive skill disclosure | #39 | done | microsoft/skills | Three-level loading (metadata/body/references) to reduce context pressure |
| Skill chaining / proactive suggestions | #60 | done | gstack + superpowers | Skills suggest next skill; gstack's `benefits-from` + superpowers' auto-triggering |
| Headless integration tests | #28 | done | superpowers | Run skills in headless mode, parse JSONL transcripts |
| YAML scenario-based skill testing | #41 | planned | microsoft/skills | Declarative YAML scenarios; complementary approach to #28 |
| Prevent gh CLI wrong-repo targeting | #72 | done | brainstorm | Always use -R, added safeguard to gh_create_issue.sh |
| PreToolUse safety hooks | #57 | done | gstack | Three-tier hierarchy: careful (warn), freeze (block edits outside path), guard (both) |
| Auto-triggering skills | #26 | planned | superpowers | Trigger skills based on context |
| Design skill | #74 | planned | — | Design skill for the workspace |
| Visual companion UI | #30 | planned | superpowers | Interactive skills with visual companion |

## Priority: Challenge Existing Solutions

Evaluate whether ecosystem developments replace or reshape what we
already do. Drives from the 2026-04-19 research refresh + inspiration
scan + meta-reflection session. Each row is a one-time decision;
Status column records the outcome.

**Decision vocabulary**:
- **Absorb** — port patterns into existing tooling; keep our surface
- **Sweep** — one-time audit/update pass across existing files
- **Evaluate** — timeboxed spike; keep or kill based on feel
- **Defer** — revisit on specific trigger criteria
- **Decline** — explicit "not pursuing," reason recorded

| Candidate | Our current solution | Decision | Notes |
|-----------|----------------------|----------|-------|
| `just` + `just-mcp` as Make replacement | Make + .PHONY + generated /make_* skills | **Defer** | Motivation is framework resilience (Claude outages force fallback to Gemini/Codex/Copilot). Revisit trigger: concrete Claude-outage or multi-framework moment where `make`-based commands aren't framework-agnostic enough. Parallel adapter-file sweep (CODEX.md, Gemini, Copilot) covers ~80% of the same motivation cheaper |
| Session Intelligence Layer (`/focus` + `/context-save` + `/context-restore`) | progress.md + plan.md | **Absorb** | Don't replace — add discipline. `/focus` = condensed "you are here" peek; `/context-save` replaces top `## Checkpoint (latest)` block in progress.md; `/context-restore` rehydrates on return. Subsumes prior "per-session context card" Consider item. Source: gstack #733, #1064 |
| `/review-code` absorb anti-skip + subagent isolation + cross-review dedup + swarm-of-personas | Existing /review-code with silence filter | **Absorb** | All additive. Anti-skip forces reviews to actually execute. Subagent isolation mitigates context-rot. Cross-review dedup refines silence filter. Swarm-of-personas (shell, security, logic, docs) spawns parallel adversarial reviewers — addresses today's shell-surface misses. Source: gstack #804, #1030, #760 + Row 7 extract |
| Opus 4.7 prompt audit sweep | Prompts written for 4.6 judgment-filling | **Sweep** | One-time pass across AGENTS.md + skill SKILL.md files + prompt-like knowledge docs. Find wiggle words ("when appropriate") and mode-biased example sets; tighten or add paired examples. Structured as 3 PRs (AGENTS.md needs "Ask First" approval per our boundaries). Anthropic explicitly warns 4.6-era prompts need review |
| MCP layer exposure of workspace commands | Per-framework adapter files | **Defer** | Cross-framework standard, but infrastructure investment without concrete non-Claude driver yet. Revisit on (a) adapter files proving inadequate during outage, or (b) non-Claude agent becoming primary driver |
| Tier 3 orchestration (overnight backlog drain) | Tier 2 (parallel supervised sprints) | **Defer** | Most of our backlog isn't mechanical — benefits from Roland's eye. Revisit trigger: concrete mechanical-backlog forcing function (e.g., 50 stacked dep-bump PRs) |
| Agent Teams (experimental) | Manual per-terminal | **Decline**; absorb concepts | Unique Agent Teams value (persistence, peer mailbox, shared task list) doesn't map to our patterns. Extracted concepts: **swarm-of-personas** → rolled into /review-code absorb above; **watchdog alerts** → separate small item below, implemented as file-polling bash not Agent Teams infrastructure |
| Ultraplan evaluation | No inline-plan-comments UI | **Evaluate** | Anthropic early preview (Week 15 Apr 2026) ships CLI→web-editor→run-or-pull-back-local flow. Matches the Antigravity-style inline-plan-review UX Roland described wanting. 1-hour spike on a real issue. Subsumes prior "inline-comment review UI" Consider item |
| Prompt cache 1h (`ENABLE_PROMPT_CACHING_1H`) | Default 5m | **Adopt** | Immediate win for long sessions. Set in `.claude/settings.json` |
| Away summary (`CLAUDE_CODE_ENABLE_AWAY_SUMMARY`) | Unclear default behavior | **Investigate first** | May already be active via telemetry path. Understand interaction with /focus before enabling |

### Related new roadmap items (simpler-tool implementations)

| Item | Source | Status | Notes |
|------|--------|--------|-------|
| File-polling watchdog helper | Row 7 extract | planned | `.agent/scripts/watch_progress.sh` — polls progress.md across worktrees, terminal bell / notification on status change. ~50 LOC bash. Implements watchdog pattern without Agent Teams |
| Swarm-of-personas for /review-code | Row 7 extract | planned | Already captured as sub-item of the /review-code enhancement row above. Parallel `Agent()` subagents with distinct personas |
| Run `/fewer-permission-prompts` on recent transcripts | session catch-up | planned | Immediate win; feeds #110 |
| Apply gstack #993 tilde-in-assignment fix | session catch-up | planned | Concrete permission-prompt reduction pattern |
| Audit #56 scope modes + #71 brainstorm for mode-posture bias | session catch-up | planned | Paired-examples pattern check on known multi-mode skills. Becomes more important under Opus 4.7 literal-following |

### Principles to add (not roadmap items, but design constraints)

- **Framework resilience** — Skills and commands should work under any supported framework. Adapter files (CLAUDE.md, CODEX.md, Gemini, Copilot) must cover the same ground. Motivation: Claude outages force fallback
- **CLI-first** — Augment the terminal; don't replace it. Management-layer tools live alongside direct observation, never between user and agents (D5 visibility)
- **Workspace/project parity** — Every practical tool handles both types. `--type workspace|project` is the canonical shape

These go in AGENTS.md under a new "Design principles for new tooling" section (separate PR — AGENTS.md changes require "Ask First" approval).

## Unphased

Small fixes that can be done anytime.

| Item | Issue | Status | Notes |
|------|-------|--------|-------|
| Research skill worktree fix | #45 | done | Fix project worktree path + staleness tracking |
| Gemini CLI PATH resilience | #82 | done | Fallback path detection added (PR #99) |
| Stale venv/hook detection after rename | #13 | done | `make validate` detects, `make repair` fixes (PR #101) |
| worktree_list.sh stray local_porcelain | #134 | planned | Bug: command-not-found error |
| cross_model_review.sh outside worktree | #133 | planned | Bug: fails when invoked outside target repo worktree |
| Git-bug fallback warnings + smoke test | — | planned | Lesson from ros2 #418 silent-fallback trap. `_issue_helpers.sh` falls through to `gh` silently; add visible warning on miss. Smoke-test `git bug bug --format json` in `make validate` |
| Workspace/project parity audit | — | planned | Generalize workspace-only tooling: `dashboard.sh`, `update_roadmap.sh`, `validate_workspace.py`. Per 2026-04-19 session principle: every practical tool works with both types |
| Port ros2 #436 behavioral-patterns knowledge | — | planned | From 2026-04-19 reflection on ros2 field work. New knowledge docs: agent behavioral patterns (time blindness, spec rigidity, unauthorized policy decisions), autonomous logging, discuss-before-editing, approval scope discipline. Port concept-not-mechanism: coordinator role, research-agent-as-shared-resource |

## Decided Against

Items considered and rejected, with reasons.

| Item | Considered | Reason |
|------|-----------|--------|
| Forgejo / local self-hosted git forge | 2026-04-19 session (prompted by ros2 #423/#355) | Ros2 needs it because field machines can't reach GitHub. We have no comparable constraint — always-online single-machine setup. Hosting cost + new dependency without addressing real pain here. Revisit only if GitHub-dependency friction grows materially |
| Coordinator-intermediated mode | 2026-04-19 session | Would require the coordinator to sit between Roland and sub-agents. Incompatible with direct terminal visibility that Roland uses for debugging (watch agents in action, scroll back to see process). Any coordinator must be additive-only |
| Ros2 tmux ATC protocol (verbatim port) | 2026-04-19 session | Solves multi-machine/remote-agent visibility problem. daddy_camp is single-machine local — agents don't drive each other's tmux panes. Protocol would add overhead without fitting the actual failure mode |
| Mandatory commit squashing before push | 2026-04-19 session | We merge with `--merge` (not `--squash`), so branch history = PR history. Squashing would hide useful intermediate state. Commits are cheap; keep them honest. `fixup!` autosquash remains optional per-developer |

## To Consider

New findings from inspiration tracker, not yet discussed in a brainstorm session.

### Cross-Workspace Analysis
- **Cross-project retrospective** — Analyze git history, PR reviews, and issue patterns across workspaces to surface recurring friction and coordination issues. Start with fork-type sources (ros2_agent_workspace) where history is deeper. Source: gstack /retro global
- **Test coverage catalog** — Shared audit showing test status across skills and scripts. Aggregates what's tested, what's missing, as a dashboard layer on top of skill testing (#41). Source: gstack test coverage catalog

### From session reflection (2026-04-19)

Cherry-picked from a recon scan of tracked inspirations since last refresh (2026-03-31). Not yet triaged — evaluate during a future brainstorm.

- **Tilde-in-assignment permission-prompt fix** — Bash pattern change that silences Claude Code permission prompts on common script patterns. Concrete, portable. Source: gstack #993. Feeds #110
- **Subagent isolation for context rot** — Strengthen `/review-code`'s adversarial specialist against long-context degradation. Source: gstack #1030
- **`/context-save` + `/context-restore` skill pair** — Compare against our `progress.md` pattern; may offer a formalization or complementary capability. Source: gstack #1064 (renamed from `/checkpoint`)
- **Cross-model benchmark skill** — Compare outputs across models for the same review/task. Possible enhancement to `cross_model_review.sh`. Source: gstack #1040
- **Worktree consent pattern during implementation** — Adds a confirmation gate we don't have. Source: superpowers #1124
- **Multi-repo worktree guidance** — Their docs may be sharper than ours. Source: superpowers #1123
- **Agent behavioral patterns (from ros2 field experience)** — Time blindness, spec rigidity, unauthorized policy decisions, inventing causal narratives. Source: ros2 #436
- **Autonomous logging during operations** — Batch-write findings without per-entry commits. Source: ros2 #436
- **Discuss design before editing** — For content/creative changes; direct edits are fine for code fixes. Source: ros2 #436
- **Approval scope discipline** — One approved command ≠ approval for follow-ups. Source: ros2 #436
- **Research-agent-as-shared-resource** — One agent does research while another implements. Source: ros2 #436

### Research topics to add (not tracker items)

Candidates for `.agent/knowledge/research_digest.md`, separate from roadmap items.

- **Claude Opus 4.7 behavioral changes since 4.6** — What shifted, especially for cache-warm session management, subagent dispatch, context handling. New topic.
- **Permission prompt patterns across frameworks** — Cross-reference gstack #993 + our #110. What do other frameworks do? New topic.
- **Git-bug v0.10.1 syntax drift lesson** — Brief entry capturing what ros2 #418 found and how we avoided it (for future-us when we upgrade git-bug again)

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
