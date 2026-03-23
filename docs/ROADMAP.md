# Workspace UX Roadmap

Living document tracking planned improvements, prioritized by pain relief.
Maintained through `/brainstorm` sessions; fed by `/inspiration-tracker` findings.

See [#63](https://github.com/rolker/agent_workspace/issues/63) for brainstorm history.

## Priority: Improve Local Reviews

The biggest actionable time sink: push -> wait for Copilot review -> triage
findings -> fix -> push again. If local pre-flight review catches what Copilot
would flag, PRs pass on first try.

| Item | Issue | Status | Notes |
|------|-------|--------|-------|
| Adaptive review depth | #47 | planned | Scale effort to change risk |
| Cognitive review patterns | #54 | planned | Reusable checklists for common mistake types |
| Fix-first review workflow | #52 | planned | Fix issues during review, don't just report |
| Spec compliance vs quality split | #27 | planned | Separate "does it meet spec" from "is it good" |
| Adversarial self-review | #55 | planned | Agent challenges its own work |
| JSONL review tracking | #51 | planned | Track findings for learning; start with JSONL, migrate to git refs later |
| Plan status tracking in reviews | #49 | planned | Reviews check progress against the plan |
| Continual learning from reviews | #42 | planned | Misses feed back into local review patterns |
| Copilot review loop automation | #69 | planned | Autonomous push/review/fix cycle (after local review is solid) |

## Priority: Reduce Agent Coordination Overhead

Roland runs 4-5 concurrent agents. Coordination is currently manual: browser
for Copilot status, telling agents to cleanup/sync, permission prompts.

| Item | Issue | Status | Notes |
|------|-------|--------|-------|
| Web dashboard | #64 | planned | Anchor for multi-agent visibility; inspired by ros2 workspace #398 |
| Agent health monitoring | #34 | planned | Dashboard surfaces agent status |
| Persistent work state | #33 | planned | Survives crashes; feeds into crash recovery |
| Session continuity | #36 | planned | Cross-session context recovery |
| Inter-agent messaging | #35 | planned | Structured communication between agents |
| Structured agent handoffs | #40 | planned | Tool scoping per agent role |
| Permission prompt reduction | — | in progress | #1 friction point; tool-use logging hook deployed, analyze then build targeted allowlist |
| Crash recovery skill | #70 | planned | Session-specific scratchpad subdirs |

## Priority: Improve How Agents Think

How agents approach problems at different levels of abstraction.

| Item | Issue | Status | Notes |
|------|-------|--------|-------|
| Brainstorm multi-level modes | #71 | planned | Vision/strategy/architecture/design with auto-detection |
| Success indicators in AGENTS.md | #43 | planned | Observable behaviors confirming principles work |
| Systematic debugging | #31 | planned | "No fixes without root cause" discipline |

## Priority: Skill Infrastructure

Foundation pieces that make the skill library scalable and reliable.

| Item | Issue | Status | Notes |
|------|-------|--------|-------|
| Progressive skill disclosure | #39 | planned | Three-level loading to reduce context pressure; prerequisite for skill chaining |
| Skill chaining / proactive suggestions | #60 | planned | Skills suggest next skill; includes #26 |
| Headless integration tests | #28 | planned | Quality gate for skill changes |
| YAML scenario-based skill testing | #41 | planned | Complementary to #28 |
| Prevent gh CLI wrong-repo targeting | #72 | planned | Bug fix: always use -R, add safeguard to gh_create_issue.sh |

## Unphased

Small fixes that can be done anytime.

| Item | Issue | Status | Notes |
|------|-------|--------|-------|
| Research skill worktree fix | #45 | planned | Fix project worktree path + staleness tracking |
| Tag skill-generated issues | #46 | planned | Better labels for inspiration-tracker/research issues |

## Decided Against

Items considered and rejected, with reasons.

(None yet.)

## To Consider

New findings from inspiration tracker, not yet discussed in a brainstorm session.

(Empty — all current findings have been triaged.)

## Cross-cutting Decisions

Decisions that apply across multiple items:

- **Storage model**: JSONL first for review tracking (#51), migrate to git refs
  later when the schema stabilizes.
- **Review architecture**: 5-layer model (adaptive depth -> cognitive patterns ->
  fix-first -> tracking -> learning). Posted to #27, #47, #49, #51, #52, #54, #55.
- **Plan as review accumulator**: All review types append status to the plan file,
  making it the single artifact showing the full story.
- **Roadmap over issues for planning**: Inspiration tracker adds findings to the
  "To Consider" section instead of creating GitHub issues. Issues are created only
  when work is ready to begin.
- **Permission prompt reduction strategy**: (1) Log all tool use via PreToolUse
  hook to `~/.claude/tool-use-log.jsonl`. (2) After a week, analyze patterns to
  find always-approve commands. (3) Build targeted allowlist (e.g., read-only git
  commands). (4) Migrate multi-step skill sequences to scripts (fewer permission
  checks + fewer tokens). (5) Add explicit progress reporting to skills to replace
  the visibility lost from fewer prompts.
