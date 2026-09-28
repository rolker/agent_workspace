# Inspiration Digest: claude-code

Type: inspiration
Last checked: 2026-09-22
Repo: anthropics/claude-code @ 56f36532530f88b572854538d685fcf781141e8 (CHANGELOG.md head, version 2.1.280)

## Survey Summary

Survey source: `CHANGELOG.md` in the public repo mirror (surveyed at v2.1.280,
2026-09-22) plus the installed CLI on this host (`claude --version` → 2.1.280).
This survey's question is **"what can we retire"**, not "what can we borrow" —
Claude Code is the framework this workspace already runs on, so the interest
is native capabilities that make hand-rolled workspace tooling redundant.

### Capability map

| Workspace tool / process | Native Claude Code feature | Verdict |
|---|---|---|
| `.claude/skills/run-issue` + `.agent/scripts/dispatch_phase.sh` (hand-rolled phase state machine, handoff blocks, model-tier table) | Workflow tool (`agent()`/`parallel()`/`pipeline()`, resume) + `.claude/agents/*.md` model/tools frontmatter + SendMessage-resume of a sub-agent | **keep for now — revisit**: the durable `progress.md` timeline is what native cannot replace; the dispatcher/handoff/tier table could become agent files + a Workflow script reading/writing the same timeline. Evidence: resuming a reviewer for rounds 2–3 today halved those phases (≈3 min vs ≈6) — which is what issue #314 item 3 re-implements by hand. |
| `worktree_create.sh` / `worktree_enter.sh` / `worktree_remove.sh` / `/start-task` | `EnterWorktree`/`ExitWorktree` + Agent `isolation: "worktree"` | **keep — native cannot do this** for the policy layer (issue checks, branch naming) and multi-repo composition (ADR-0012); retire the single-repo mechanics over time. Confirmed: `EnterWorktree` operates per-repo (CHANGELOG 2432, 3175) and only accepts worktrees of the *current* repo — matching CLAUDE.md's own rationale for using `cd` uniformly. |
| One-driver-per-issue / standing rules reaching one terminal only (issue #321) | `ListAgents` / `SendMessage` cross-session (CHANGELOG 1303: added on Bedrock/Vertex/Foundry and with telemetry disabled; 738, 1019: session identity/dedup fixes) | **retire** the inference-from-file-timestamps approach; hosts can ask each other directly. |
| `.claude/hooks/block-bash-tool-mapping.sh` | Auto mode's own dedicated-tool guidance | **retire** — now fights the tool; blocked `cat`/`tail` repeatedly during this very run (multi-line Bash calls got denied instead of routed to Read/Edit). |
| `/analyze-permissions` skill | Built-in `/fewer-permission-prompts` (listed as an available skill on this host) | **retire or fold** — confirmed present as a first-party skill on this install. |
| `make sync` periodic reconciliation | `/schedule` / `CronCreate` (CHANGELOG 347, 1125, 1267, 4684: routines and `CronCreate` scheduled-task markers) | **keep for now — revisit**. |
| `set_git_identity_env.sh` sourced in every command chain | Claude Code's own commit/PR attribution | **keep — native cannot do this** while Codex/Gemini sessions are supported. Flag: the multi-framework requirement is the largest source of clunkiness here — no Codex/Gemini session has driven the loop in the observed period (per memory: `project-run-issue-port-no-container-baggage`, `feedback-run-issue-project-issues-primary`). |
| `review-code` skill's Claude specialists (static, governance, plan-drift, adversarial) | Built-in `/code-review` (high effort) and `ultra`/`/ultrareview` (CHANGELOG 380: `/code-review` now uses leaner inline prompts instead of spawning many review subagents; extensive `/ultrareview` entries throughout) | **keep for now — revisit**: governance/plan-drift checks are workspace-specific; the adversarial pass overlaps with native `ultra`. |
| `.agent/scripts/cross_model_review.sh` (Gemini/Codex/Copilot reviewers) | Nothing native — Claude Code only reviews with Claude | **keep**. |
| `progress.md` timeline (ADR-0013), ADRs, principles guide | Native memory (`/memory`, per-machine, per-user memory files with frontmatter timestamps — CHANGELOG 2180, 5025) | **keep — native cannot do this**: durable, cross-session, cross-framework, human-readable, git-tracked and PR-reviewable; native memory is local-file, single-user, single-framework. |
| `_agy_review.sh` / multi-framework adapter files (CODEX.md, gemini instructions, copilot instructions) | None | **keep**, but list under "revisit the multi-framework requirement" below. |

### Verdict counts

- **retire**: 3 (`block-bash-tool-mapping.sh`; `/analyze-permissions`; one-driver-per-issue inference)
- **keep**: 4 (`worktree_create.sh` family; `set_git_identity_env.sh`; `cross_model_review.sh`; `progress.md`/ADRs/principles guide)
- **keep for now — revisit**: 4 (`run-issue`/`dispatch_phase.sh`; `make sync`; `review-code` specialists; multi-framework adapter files)

### Dropped / could not verify

- **Persistent memory cross-machine sync claim**: CHANGELOG shows memory file
  frontmatter/timestamps (2180, 5025) but nothing confirming memory syncs
  across machines for one account — dropped that specific comparison point,
  kept the weaker (verified) claim that it's per-machine/per-user.
- **Skills/plugins packaging vs. workspace skill format**: no changelog
  evidence was strong enough to state a verdict (marketplace/plugin entries
  describe distribution mechanics, not a direct format comparison to
  `.claude/skills/*/SKILL.md`) — left out of the capability map table
  rather than guess.
- Did not run any prompts against the installed `claude` CLI beyond
  `--version` and `--help`, per instructions.

## Activity Snapshot

- 11,510 open issues, 704 open PRs (GitHub search API, 2026-09-22)
- 51 PRs merged/closed in the last 30 days as of survey date
- Notable open items surfaced during this survey: subagent idle/notification
  relay bug (#96109), background subagent completion messages disrupting the
  transcript (#96107) — both touch the sub-agent dispatch area this workspace
  also relies on.

## Pending Review

- `retire-bash-tool-mapping-hook` — the hook fights auto mode's own
  dedicated-tool guidance and fired repeatedly during this survey run (2026-09-22)
- `dispatcher-to-workflow-and-agent-files` — replace `dispatch_phase.sh`'s
  hand-rolled state machine with Workflow tool scripts + `.claude/agents/*.md`,
  keeping `progress.md` as the durable timeline (2026-09-22)
- `cross-session-claim-via-listagents` — feeds #321; replace file-timestamp
  inference for one-driver-per-issue with `ListAgents`/`SendMessage` (2026-09-22)
- `revisit-multi-framework-requirement` — no Codex/Gemini session has driven
  the review loop in the observed period; re-evaluate whether the
  multi-framework adapter/identity layer still earns its complexity (2026-09-22)

## Roadmapped

(none yet — pending owner triage)

## Skipped

(none yet)

## Deferred

(none yet)
