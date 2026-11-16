# Research Digest: Workspace

<!-- Last full refresh: 2026-10-15 (all 19 entries re-surveyed; claims not verifiable against a primary source are marked "unverified") -->
<!-- Run /research --refresh periodically to re-survey stale entries -->

## Permission Prompt Reduction Patterns (Claude Code)

**Added**: 2026-04-19 | **Last verified**: 2026-10-15 | **Sources**: [Configure permissions — Claude Code Docs](https://code.claude.com/docs/en/permissions), [Claude Code auto mode](https://www.anthropic.com/engineering/claude-code-auto-mode), [Claude Code changelog 2026](https://claudefa.st/blog/guide/changelog), [managed-settings.json guide](https://managed-settings.com/), [--dangerously-skip-permissions: 5 modes](https://www.morphllm.com/claude-code-dangerously-skip-permissions), [bug #18160 — allow permissions ignored in global settings](https://github.com/anthropics/claude-code/issues/18160)

Key takeaways:
- **Auto mode is now the default starting mode** (Claude Code v2.1.283+, interactive terminal and VS Code, all plans and providers; the built-in default needs v2.1.228+). A classifier model reviews actions instead of a human prompt; if the model or availability requirements are not met the session falls back to Manual. Mode set: default (Manual), `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions`. Config: [auto-mode-config](https://code.claude.com/docs/en/auto-mode-config).
- `bypassPermissions` skips prompts even for protected paths (`.git`, `.claude`); `permissions.disableBypassPermissionsMode` / `permissions.disableAutoMode` = `"disable"` turn the modes off.
- **Built-in read-only allowlist** (not configurable; use an ask/deny rule to force a prompt): `ls`, `cat`, `echo`, `pwd`, `head`, `tail`, `grep`, `find`, `wc`, `which`, `diff`, `stat`, `du`, `cd`, and read-only forms of `git`. Unquoted globs are allowed when every flag is read-only.
- **Project-level `.claude/settings.json` allowlists** are committed to share decisions across a team.
- **Path patterns**: `~/path` is now a documented home-relative anchor (e.g. `Read(~/Documents/*.pdf)`); `//path` is absolute; `path` or `/path` is relative to the settings file. The older "tilde is not expanded" theory is unconfirmed: [#18160](https://github.com/anthropics/claude-code/issues/18160) (allow rules in global settings ignored) is still open with no root cause or Anthropic response (last comment 2026-05-01, v2.1.126). Workaround seen in the thread: a PreToolUse hook returning `permissionDecision: allow`. "Always allow" prompts can also write mangled patterns (e.g. `/tmp` becoming `tmp/`), so review generated rules.
- `/fewer-permission-prompts` (scans transcripts, proposes allowlist additions) is present locally in `.claude/skills/`; its docs page could not be found (unverified link).

**Relevance**: Prompt load is the main friction in multi-agent workflows. With auto mode the default, the allowlist matters mostly for sessions where auto mode is unavailable and for background agents. Keep absolute paths or `//` anchors in committed allowlists, and re-audit generated rules for mangled patterns.

---

## Mode-Posture Preservation in Multi-Mode Skills

**Added**: 2026-04-19 | **Last verified**: 2026-10-15 | **Sources**: [gstack #1065 — mode-posture energy fix](https://github.com/garrytan/gstack/pull/1065), [Prompt Engineering Guide — priming and style control](https://www.promptingguide.ai/techniques), [Mirascope — LLM prompt best practices](https://mirascope.com/blog/llm-prompt), [Palantir Foundry — LLM prompt best practices](https://www.palantir.com/docs/foundry/aip/best-practices-prompt-engineering)

Key takeaways:
- **Problem**: When a skill has multiple "modes" (e.g., scope expansion vs. holding, forcing question vs. softening, wild-builder vs. structured-PRD), a generic style rule in a shared preamble can silently flatten all of them toward whichever framing the examples favor. Gstack documented this across `/plan-ceo-review` and `/office-hours` in early 2026 (PR #1065 merged 2026-04-18; the author notes the evals test prose markers more than decision quality and no transcript proves the original regression, so treat the evidence as one case study).
- **Root cause** is a well-known LLM property: **few-shot examples dominate abstract rules.** Psychological/linguistic priming research shows even small phrasings activate different knowledge areas — so any one-sided example set becomes a strong attractor.
- **Fix pattern** (gstack #1065):
  1. **Paired examples** in shared preambles — cover the full range of postures the skill spans (pain / upside / forcing), not just the most common one.
  2. **Inline exemplars** anchored on stable headings in each skill template (so the mode-specific energy survives the preamble).
  3. **Gate-tier regression tests** with judge rubrics on distinct axes (surface framing + decision preservation; stacking + domain match; excitement over optimization). Pass threshold ~4/5 per axis.
- Anthropic's [skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices) endorse input/output example pairs but say nothing explicit about examples over-anchoring; that claim rests on the gstack PR. They also advise testing skills on Haiku, Sonnet and Opus.
- Newer models follow instructions more literally (see the model entry), so one-sided examples plausibly anchor more strongly; unverified for the 5.x models.

**Relevance**: Directly applicable to this workspace's existing multi-mode skills:
- **#56 "Explicit scope modes for planning"** (done) — four modes: expansion, selective expansion, hold, reduction. At risk if any shared preamble examples favor one mode.
- **#71 "Brainstorm multi-level modes"** (done) — vision / strategy / architecture / design. Same risk.
- **`/plan-task`** skill — currently single-mode, but if we ever split by task type, this constraint applies.

Recommended follow-ups: audit those skills for preamble examples that bias toward one mode; add paired examples where mode-spanning preambles exist; consider gate-tier judge-rubric tests.

---

## Claude Model Lineup and Migration Notes (Opus 4.7 → 5.5)

**Added**: 2026-04-19 | **Last verified**: 2026-10-15 | **Sources**: [What's new in Claude Opus 4.7 (Anthropic API Docs)](https://platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-7), [GitHub Changelog — Opus 4.7 GA April 16, 2026](https://github.blog/changelog/2026-04-16-claude-opus-4-7-is-generally-available/), [Verdent — What Changed for Coding Agents](https://www.verdent.ai/guides/what-is-claude-opus-4-7), [Labellerr — 4.7 vs 4.6 comparison](https://www.labellerr.com/blog/claude-opus-4-7-vs-opus-4-6-comparison/amp/), [Apiyi — Launch-day in-depth review](https://help.apiyi.com/en/claude-opus-4-7-vs-4-6-real-performance-review-en.html)

Key takeaways:
- **Lineup (Oct 2026, [models overview](https://platform.claude.com/docs/en/models/overview))**: Fable 5.1 (`claude-fable-5-1`, default effort high), Opus 5.5 (`claude-opus-5-5`, medium, released 2026-09-22), Sonnet 5.5 (`claude-sonnet-5-5`, high), Haiku 5.5 (`claude-haiku-5-5`, medium). All four: 1M-token context, 128K max output, Jun 2026 knowledge cutoff. Older Opus 4.5-4.8, Opus 5, Fable 5, Sonnet 4.6/5 and Haiku 4.5 remain available as legacy.
- **Effort levels** `low`, `medium`, `high`, `xhigh`, `max` are general; `xhigh` (introduced with Opus 4.7) is no longer special. Set effort explicitly and re-run an effort sweep on your own evals when migrating.
- **Opus 5.5 breaking changes** ([migration guide](https://platform.claude.com/docs/en/models/opus-5-5/migration-guide)): adaptive thinking is always on (manual `budget_tokens` rejected); `temperature`/`top_p`/`top_k` must stay at defaults; assistant prefill rejected; forced tool use errors; text between tool calls arrives in `thinking` blocks (empty at default `display`); at `xhigh`/`max` start `max_tokens` at 64k+.
- Anthropic's migration help in Claude Code: `/claude-api migrate`; there is a dedicated "Prompting Claude Opus 5.5" page (not read in this refresh).
- Carried over from the 4.7 generation, **not re-verified for 5.x**: more literal instruction following (prompts that relied on the model filling gaps need review), more direct tone, ~3.75 MP vision, new cybersecurity safeguards.

**Relevance**: Skill templates and prompts written against 4.6-era looseness may under-perform on literal models; audit them when moving to a new generation. Hardcoded model IDs in docs go stale quickly; the 3-arg identity form (exact ID passed in) avoids detection drift. Entry renamed from "Claude Opus 4.7 — Behavioral Changes Since 4.6" on 2026-10-15 because the 4.7 framing is superseded.

---

## Command Runner Alternatives to Make

**Added**: 2026-02-27 | **Last verified**: 2026-11-15 | **Sources**: [just](https://github.com/casey/just), [just releases](https://github.com/casey/just/releases), [Task](https://github.com/go-task/task), [Task remote Taskfiles GA](https://taskfile.dev/blog/remote-taskfiles), [mise](https://github.com/jdx/mise), [task-mcp](https://docs.rs/crate/task-mcp/0.5.0/source/README.md)

Key takeaways:
- Versions on 2026-11-15: just 1.59.0 (2026-10-15), Task v3.54.0 (2026-10-01), mise v2026.11.8 (2026-11-13, calendar versioning); all actively developed (~36.7k, ~16.4k, ~36.2k stars)
- `just` is the strongest candidate for replacing Make as a command runner — closest syntax, built-in `just --list`, no `.PHONY` needed, multi-language recipes. Since July: `[timestamp]` recipe attribute (1.58), `[cache(environment)]` cache keys and `--usage` for whole modules (1.59), markdown justfiles found by name (1.57). 1.59 is breaking: justfile paths must be Unicode
- Task: remote Taskfiles went GA in v3.53 and gained a per-command `timeout` (exit 124); v3.54 adds per-host `remote.headers` and fixes a remote Git Taskfile cache-poisoning advisory (GHSA-679p-658w-m3wr), relevant only if remote includes are used
- MCP adapters for just: [PromptExecution/just-mcp](https://github.com/PromptExecution/just-mcp) is still low-traffic (60 stars, last push 2026-07-15, last release v0.1.5 on 2025-11-15); [toolprint/just-mcp](https://github.com/toolprint/just-mcp) has been dormant since 2025-08; `task-mcp` (crate 0.5.1, 2026-04-28) runs on just and hides recipes from agents unless they carry an `allow-agent` attribute, an opt-in model that fits this workspace's permission posture better
- `task` (Go/YAML) offers namespace includes but is more verbose; `mise` (Rust/TOML) bundles tool version management but adds little for ROS 2 where `apt`/`rosdep` manage toolchains
- `colcon defaults.yaml` can absorb build flags currently hardcoded in scripts, regardless of which runner is chosen

**Relevance**: The workspace uses Make purely as a command runner, not for dependency-based builds. Switching to `just` would reduce boilerplate and provide a pathway to MCP-accessible commands (an allowlisting adapter such as task-mcp would keep agent access opt-in per recipe).

---

## AGENTS.md — Cross-Platform Agent Instruction Standard

**Added**: 2026-02-27 | **Last verified**: 2026-11-15 | **Sources**: [agents.md spec](https://agents.md/), [GitHub repo](https://github.com/agentsmd/agents.md), [OpenAI Codex guide](https://learn.chatgpt.com/docs/agent-configuration/agents-md), [Claude Code memory docs](https://code.claude.com/docs/en/memory), [AAIF — Measuring AGENTS.md (2026-07-22)](https://aaif.io/blog/measuring-agents-md-what-five-runs-show-that-one-doesn-t), [AAIF — Writing an effective AGENTS.md (2026-08-13)](https://aaif.io/blog/writing-an-effective-agents-md), [Agentic AI Foundation](https://openai.com/index/agentic-ai-foundation/), [sync strategy](https://kau.sh/blog/agents-md/)

Key takeaways:
- Vendor-neutral spec stewarded by the Agentic AI Foundation (Linux Foundation; "a Series of LF Projects, LLC"), which also stewards MCP and goose. A Technical Charter was added to the repo on 2026-09-10; the spec itself has no version number and the site has had no content change since March
- agents.md still claims "60k+" open-source projects (unchanged since April). Efficiency figures now verified via AAIF: Lulla et al. (124 PR tasks, 10 repos) report 28.64% lower median runtime and 16.58% fewer median output tokens (efficiency only, not correctness); Gloaguen et al. find context files do not significantly raise task success, increase steps and cost, and that developer-written files beat LLM-generated ones. AAIF's own five-run test: a 12-line file cut wall time by 27% on an ambiguous task, where a single-run pilot pointed the opposite way, so compare medians over several runs
- Supported by Codex, Cursor, Devin, Gemini CLI, GitHub Copilot, Jules, Junie, Augment Code, VS Code, Windsurf, Aider, Zed, Amp, Warp, goose and more. **Claude Code reads AGENTS.md natively** (v2.1.277+): by default (`claude-md-or-agents-md`) it reads AGENTS.md only when no CLAUDE.md, `.claude/CLAUDE.md` or CLAUDE.local.md exists in or above the working directory. A **Project instructions** setting (`/config`, or `pluginConfigs` → `cc-plugin-agents-md@builtin`, honoured only in user/managed/`--settings` files; ID was `agents-md@builtin` before v2.1.285) adds `claude-md-and-agents-md`, which loads both and dedupes an imported AGENTS.md. AGENTS.md read via the setting does not fire `InstructionsLoaded` hooks
- Size: the spec sets no limit (the earlier "≤150 lines" claim had no primary source and is dropped). Tool limits: Claude Code targets <200 lines per CLAUDE.md, Cursor suggests <500 lines, and Codex caps combined content at 32 KiB (`project_doc_max_bytes`). Closest `AGENTS.md` to the edited file wins; user prompts override all. Codex also honours `AGENTS.override.md` and walks from the root down to the working directory, one file per directory
- AAIF guidance: include structure-with-meaning, exact commands, boundaries and a definition of done; leave out what's discoverable, generic advice, copied docs, linter-enforceable rules and secrets. AGENTS.md guides but does not enforce — enforcement belongs in CI, branch protection and sandboxing
- For multi-tool workspaces, the `@AGENTS.md` import in CLAUDE.md remains right whenever a CLAUDE.md exists; the Claude Code docs say keeping the import never double-loads AGENTS.md under either setting

**Relevance**: Already adopted in this workspace. AGENTS.md consolidates shared rules; framework-specific files contain only agent-specific behavioral rules. This eliminated the previous four-file duplication problem. The AAIF "guide, don't enforce" line matches this workspace's hook-based enforcement; the 200-line AGENTS.md budget sits within the published tool limits.

---

## AI Agent Spec Writing Best Practices

**Added**: 2026-02-27 | **Last verified**: 2026-11-15 | **Sources**: [Osmani, "How to Write a Good Spec for AI Agents" (O'Reilly, Jan 2026)](https://www.oreilly.com/radar/how-to-write-a-good-spec-for-ai-agents/), [addyosmani.com](https://addyosmani.com/blog/good-spec/), [github/spec-kit](https://github.com/github/spec-kit), [Kiro specs docs](https://kiro.dev/docs/specs/), [Böckeler, "Understanding SDD: Kiro, spec-kit, and Tessl" (martinfowler.com, 2025-10-15)](https://www.martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html)

Key takeaways:
- Informed by GitHub's analysis of 2,500+ agent configuration files (Osmani's article, dated 2026-01-13, still resolves with no revision noted)
- **Three-tier boundary system**: categorize rules as "Always" (autonomous), "Ask first" (human approval), or "Never" (hard stop) — more effective than flat rule lists
- **Self-audit instruction**: tell agents to compare results against the spec and list unmet items
- **SPEC.md as session anchor**: persistent spec file survives context resets across sessions
- **Conformance suites**: language-independent tests that any implementation must pass
- **Two-phase task pattern**: draft spec first (plan mode), then execute incrementally
- **Spec-driven tooling has gone mainstream**: github/spec-kit (~150k stars, v1.4.0 on 2026-11-10, near-daily releases; now maps reasoning effort and context size for Copilot, Codex and Claude Code). Kiro specs are requirements.md (or bugfix.md for Bugfix Specs) + design.md + tasks.md, with Requirements-First/Design-First variants and a one-pass Quick Spec; the docs no longer mention EARS notation (EARS status unverified). Kiro ships a CLI (3.3.0, 2026-11-12) and mobile app; no GA date on its changelog
- **Counterpoint (Böckeler)**: one heavy workflow doesn't fit every change size (a small bug became 4 user stories / 16 acceptance criteria); verbose spec markdown can be harder to review than code; specs don't guarantee determinism (agents ignored notes and duplicated classes; regeneration from one spec varied). Scale spec depth to change risk

**Relevance**: The Always/Ask/Never taxonomy was adopted directly into AGENTS.md. The self-audit pattern maps to our post-task verification checklist. Böckeler's sizing critique supports keeping plan/review depth proportional to risk (as review-code already does), and Kiro's separate Bugfix Spec suggests a lighter plan template for bug fixes.

---

## Harness Engineering — Production-Scale Agent-First Development

**Added**: 2026-02-27 | **Last verified**: 2026-11-16 | **Sources**: [OpenAI blog (Lopopolo, Feb 2026)](https://openai.com/index/harness-engineering/), [Böckeler analysis (martinfowler.com)](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html), [InfoQ coverage](https://www.infoq.com/news/2026/02/openai-harness-engineering-codex/), [Addy Osmani — Agent Harness Engineering](https://addyosmani.com/blog/agent-harness-engineering/) (secondary), [dev.to — "Harness Engineering" Has a Definition Problem](https://dev.to/kenimo49/harness-engineering-5-companies-5-definitions-why-everyone-disagrees-on-what-it-means-531h) (secondary)

Key takeaways:
- Team of 3–7 engineers built ~1M LOC product with zero human-written code over 5 months using Codex; 3.5 PRs/engineer/day
- The **harness** (environment, constraints, feedback loops) matters more than the agent's capabilities — early slowness came from an underspecified environment, not incapable models
- Three harness components: **context engineering** (instruction files), **architectural constraints** (linters, structural tests), **garbage collection** (background agents fighting entropy)
- AGENTS.md should be a ~150-line **map** (table of contents), not an encyclopedia — deep rules live in referenced knowledge files
- **Lint error messages as agent teaching**: custom linters should include remediation instructions so failures become learning context
- **Garbage collection agents**: background tasks that scan for drift and open small fix-up PRs on a recurring cadence
- **"Anything not in-context doesn't exist"**: only repo-local versioned artifacts are visible to agents; knowledge in chat, docs, or heads is invisible
- **"Corrections are cheap, waiting is expensive"**: favor fast feedback loops over blocking gates for agent-generated work
- **Newer framing (Böckeler, 2026-04-02, [Harness engineering for coding agent users](https://martinfowler.com/articles/harness-engineering.html))**: a harness is feedforward guides plus feedback sensors, each computational (linters, tests) or inferential (LLM review). Anthropic's [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) (2025-11-26) and a later planner/generator/evaluator post (about 2026-03, seen only in secondary coverage) argue for separating the evaluator from the generator.
- **Term is now contested.** Secondary coverage (2026-11-16 search) says OpenAI, Anthropic, Thoughtworks and LangChain each use "harness" from their own product angle. Common core: Agent = Model + Harness (attributed to Mitchell Hashimoto, early 2026). Emphasis differs: OpenAI stresses environment design (docs, architectural constraints, observability); Anthropic stresses runtime control for long-running agents (context-window coherence, "context anxiety"); Böckeler stresses the codebase itself as part of the harness; a linter or type checker is a sensor, a rules file only a guide. Two secondary-source claims were not checked against primary pages and are unverified: that Anthropic moved toward a single agent with a good harness as models improved; and that harness setup alone can swing benchmarks by 5 or more points (attributed to Anthropic's 2026 Agentic Coding Trends Report).
- Verification note: OpenAI post returned HTTP 403 on 2026-10-15 and again on 2026-11-16; content rests on earlier verification plus Böckeler/InfoQ coverage.

**Relevance**: Validates several workspace patterns (worktree isolation, progressive disclosure, artifact-based communication). The map-vs-encyclopedia principle guides AGENTS.md/CLAUDE.md sizing. Garbage collection agents are a future pattern once multi-agent workflows are adopted. The guide-versus-sensor split suggests auditing which workspace rules are only guides (AGENTS.md text) and which have sensors (hooks, pre-commit, CI).

---

## Multi-Agent Engineering Patterns

**Added**: 2026-02-27 | **Last verified**: 2026-11-16 | **Sources**: [GitHub blog, "Multi-agent workflows often fail" (Feb 2026)](https://github.blog/ai-and-ml/generative-ai/multi-agent-workflows-often-fail-heres-how-to-engineer-ones-that-dont/), [digitalapplied — Data contracts for AI agent pipelines (2026-07-28)](https://www.digitalapplied.com/blog/data-contracts-for-ai-agent-pipelines) (secondary), [MLflow — Multi-agent workflows](https://mlflow.org/articles/multi-agent-workflows/) (secondary)

Key takeaways:
- Core thesis: most multi-agent failures come from **missing structure**, not model capability — treat agents as distributed system components
- **Typed schemas** for inter-agent data: machine-checkable contracts (Zod, JSON Schema) prevent field name drift and ambiguous types
- **Action schemas** (discriminated unions): constrain what agents can do — prevents contradictory actions like one agent closing an issue another just opened
- **MCP as enforcement layer**: validates tool inputs/outputs before execution, making instruction-level rules mechanically enforceable
- **Distributed systems principles apply**: design for failure, validate at boundaries, constrain before scaling, log intermediate state, design for idempotency
- **Constrain the solution space** to increase trust (Böckeler): restrict what agents can do to increase confidence in what they do

- Verified 2026-11-16: the GitHub post (Gwen Davis, 2026-02-24, no revision noted) was re-fetched and resolves; it still recommends typed schemas at every boundary, action schemas (exactly one valid action), and MCP as the enforcement layer, with schema violations treated as contract failures to retry, repair or escalate. Anthropic's harness posts (separate generator and evaluator) are the closest newer authoritative material.
- **MCP enforcement is partly client-side.** A targeted search on 2026-11-16 found no formal 2026 standard or official guidance on typed-schema or MCP enforcement for multi-agent systems; only practitioner posts. digitalapplied notes MCP's optional `outputSchema` has MUST-level conformance language, but clients only SHOULD validate results; treat "MCP validates" as best-effort, not guaranteed (one secondary source; the MCP spec text was not checked). Provider-side strict tool use and structured outputs constrain sampling to schema-valid tokens, but a knowlee.ai piece advises validating at the application layer regardless. MLflow's guide recommends JSON Schema or Protobuf for every handoff. Role split from secondary sources: structured outputs for an agent talking to itself, MCP for agent to tool, A2A for agent to agent.

**Relevance**: Not immediately actionable for single-agent workflows, but provides the engineering framework for when Agent Teams or multi-agent orchestration is adopted. The workspace's worktree isolation already maps well to distributed systems best practices. When this workspace relies on MCP or hooks for enforcement, keep a validation step it controls (hook, CI) rather than trusting the protocol layer alone.

---

## Claude Code Agent Teams

**Added**: 2026-02-27 | **Last verified**: 2026-11-16 | **Sources**: [Claude Code Agent Teams docs](https://code.claude.com/docs/en/agent-teams), [Claude Code Agent Teams: Setup & Usage Guide 2026](https://claudefa.st/blog/guide/agents/agent-teams), [Anthropic — Building a C compiler with parallel Claudes](https://www.anthropic.com/engineering/building-c-compiler), [Turing College guide](https://www.turingcollege.com/blog/claude-agent-teams-explained), [alexop.dev — From Tasks to Swarms](https://alexop.dev/posts/from-tasks-to-swarms-agent-teams-in-claude-code/)

Key takeaways:
- Shipped **alongside Opus 4.6** in February 2026. Still flagged as experimental but used for Anthropic's own production work (parallel Claudes built a C compiler, per their engineering blog).
- **Enable**: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in env or `settings.json`.
- **Architecture**: one Claude Code session acts as team lead; spawns independent teammates each with its own context window and tool access. Peer-to-peer communication via a **mailbox system** + shared task list (not purely lead-dispatched).
- **Coordination patterns**: leader / swarm / pipeline / watchdog — orchestration style is prompt-selected, not a different runtime.
- **Status 2026-11-16**: [docs](https://code.claude.com/docs/en/agent-teams) (re-read in full) still say "experimental and disabled by default", with known limitations around session resumption, task coordination and shutdown; not GA. Enable with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. With the flag on, any named subagent launches as a teammate, so teams can form unprompted. Setting the variable to `0` in user settings reverts this live without a new session, though project, local, `--settings` and managed settings can override that. Spawning needs an interactive session (not `-p` or the Agent SDK).
- **Config/architecture**: `teammateMode` (`in-process` default, `auto`, `tmux`, `iterm2`); shared task list with file-locked claiming; JSON mailboxes under `~/.claude/teams/`; teammates inherit the lead's permission mode; hooks `TeammateIdle`, `TaskCreated`, `TaskCompleted`; in auto mode the classifier reviews inter-agent messages.
- **Limits**: the docs say no hard teammate limit and recommend starting with 3-5 (5-6 tasks each). Other limits: one team per session; no nested teams; the lead is fixed; no resume of in-process teammates; in-process teammates cannot run background subagents; task status can lag; shutdown can be slow; split panes need tmux or iTerm2 (so no split panes in VS Code/Windows Terminal/Ghostty).
- **Hooks and storage** (re-confirmed 2026-11-16): hooks `TeammateIdle`, `TaskCreated`, `TaskCompleted`; `~/.claude/teams/{team}/config.json` is removed at session end; `~/.claude/tasks/{team}/` is kept on disk.
- **Changes since the October entry** (in the 2026-11-16 docs):
  - Mailboxes: validated on read; malformed entries are reported and removed. A message counts as sent only after the mailbox write succeeds.
  - Permissions: teammates start in the lead's permission mode (including `bypassPermissions`); no per-teammate mode at spawn. If the lead is in `dontAsk`, a teammate starts in Manual (v2.1.317+ for split-pane). In-process teammates follow the lead's live allow and deny rules. For split-pane teammates, `--allowedTools` is not passed, so use `permissions.allow` via `--settings`; `--disallowedTools` and `--tools` are passed from v2.1.309. Teammate permission prompts surface in the lead session.
  - Auto-mode classifier: reviews every inter-agent message before delivery; treats approval claims relayed from another agent as untrusted; a teammate cannot supply consent on the owner's behalf.
  - Plan mode: a teammate spawned while the lead is in plan mode works in plan mode, but Claude Code auto-approves its plan unless that teammate's permission mode was changed afterwards. The lead reviews only if a running in-process teammate is put into plan mode via Shift+Tab.
  - Model selection: order is spawn-prompt model, then the subagent definition's `model`, then `CLAUDE_CODE_SUBAGENT_MODEL`, then the lead's model. `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` (v2.1.257+) overrides the first two. `teammateDefaultModel` was removed in v2.1.234.
  - Subagent definitions as teammate roles: applied: `tools`, `model`, body, and (in-process only) `effort`, `autoCompactWindow` (v2.1.296+) and `disallowedTools`. Not applied: `skills`; `mcpServers` applies to split-pane teammates only. Restored teammates re-apply a project-defined agent only if its folder is trusted.
  - Display modes: `teammateMode` values `in-process` (default), `auto`, `tmux`, `iterm2`; the `--teammate-mode` flag is undocumented in `--help`.
  - Docs now suggest checking subagents or cross-session messaging first.
  - Prompt cache: in-process teammates' prompt cache TTL is 5 minutes by default; the `subagentPromptCacheTtl` setting can raise it to 1 hour.

**Relevance**: The workspace's worktree infrastructure provides the isolation layer Agent Teams assumes. The feature maps well onto Roland's concerns about coordinating parallel agents BUT intersects with two session decisions: (1) D5 — we want coordinator-as-additive, not intermediated. Agent Teams is an intermediated model where the team lead dispatches. Evaluate only if teammate visibility is preserved (each teammate's terminal is watchable). (2) Permission prompts — teammates are separate sessions with separate tool trust, so permission-prompt load would grow with team size unless each teammate has tight allowlists. Team-lead permission inheritance matters here: a teammate inherits `bypassPermissions` or auto mode from the lead, so allowlists should be set on the lead before spawning.

---

## Model Context Protocol (MCP) — Industry Standard

**Added**: 2026-02-27 | **Last verified**: 2026-10-15 | **Sources**: [MCP spec](https://spec.modelcontextprotocol.io/), [Agentic AI Foundation](https://www.linuxfoundation.org/press/linux-foundation-launches-the-agentic-ai-foundation)

Key takeaways:
- Donated to the Linux Foundation's Agentic AI Foundation (Dec 2025) — now the cross-vendor standard adopted by OpenAI, Google, Anthropic, and others
- **Current spec revision is 2026-07-28** (previous 2025-11-25; [changelog](https://modelcontextprotocol.io/specification/2026-07-28/changelog)). Major changes: protocol sessions and `Mcp-Session-Id` removed; no `initialize` handshake (each request carries version and capabilities in `_meta`); new required `server/discover`; Tasks moved to an official extension; required `resultType` on results. Deprecated: Roots, Sampling, Logging, the HTTP+SSE transport, and Dynamic Client Registration (in favor of Client ID Metadata Documents), under a new 12-month minimum deprecation policy. Extensions listed: Tasks, Skills over MCP, MCP Apps. Servers written to the 2025 spec need a compatibility review
- Thousands of community servers; universal protocol for connecting agents to tools and data
- **ROS 2-specific MCP servers** emerging: ROSBag MCP Server (natural language queries over bag files, [arXiv:2511.03497](https://arxiv.org/abs/2511.03497), verified; no code repo found), plus [robotmcp/ros-mcp-server](https://github.com/robotmcp/ros-mcp-server) (~1.5k stars, active) and [wise-vision/ros2_mcp](https://github.com/wise-vision/ros2_mcp)
- Beyond tool connection, MCP adds a **validation layer** — can enforce contracts that soft instruction rules cannot

**Relevance**: Strategic for this workspace. `just-mcp` could expose workspace commands to any agent. ROS 2 MCP servers could enable runtime system inspection during development. MCP enforcement is the cross-agent equivalent of Claude Code hooks.

---

## ROS 2 Agent Frameworks

**Added**: 2026-02-27 | **Last verified**: 2026-10-15 (reference only — no ROS project currently managed) | **Sources**: [ROSA (NASA JPL)](https://github.com/nasa-jpl/rosa), [RAI (RobotecAI)](https://github.com/RobotecAI/rai), [ROS-LLM (Auromix)](https://github.com/Auromix/ROS-LLM), [EmbodiedAgents (Automatika)](https://automatika-robotics.github.io/embodied-agents/)

Key takeaways:
- **ROSA** (NASA JPL): natural language interaction with ROS 1/2 systems — inspect nodes, query topics, diagnose issues; published at IROS 2024. v1.0.10 (2026-03-17), no pushes since: quiet for 7 months
- **RAI** (RobotecAI): vendor-agnostic agentic framework for Physical AI; integrates with ROS 2 navigation, manipulation, perception. Most active: 2.12.4 (2026-09-08), pushed 2026-10-12
- ~~ROS-LLM~~ (Auromix): pruned 2026-10-15; last push 2023-07, no releases, effectively abandoned
- **EmbodiedAgents**: production-grade deployment of Physical AI on real robots via ROS 2. 0.5.1 (2026-02-16), pushed 2026-10-15
- These operate at **runtime** (inspect, diagnose, operate robots) vs. our workspace which operates at **development-time** (write code, manage PRs) — complementary, not competing
- ROS 2 MCP servers (see the MCP entry) now offer a lighter route to runtime inspection than a dedicated framework
- MCP bridges the gap: a development agent could invoke a ROSA MCP server to inspect a running system while debugging

**Relevance**: ROSA is the most immediately relevant for diagnosing integration issues by querying a running simulation from within a coding session. Others are worth monitoring.

---

## Agentic Coding Market and Tool Landscape

**Added**: 2026-02-27 | **Last verified**: 2026-10-15 | **Sources**: [GitHub blog](https://github.blog/ai-and-ml/generative-ai/multi-agent-workflows-often-fail-heres-how-to-engineer-ones-that-dont/), [Anthropic engineering](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)

Key takeaways:
- Market-size, adoption and analyst-inquiry statistics (previously: $550M to $4B growth, 57% of companies running agents in production, Gartner's 1,445% multi-agent inquiry surge) could not be traced to a primary source on 2026-10-15 and are removed as unverified
- Quality concern: 40% quality deficit projected — more code enters pipelines than reviewers can validate; Google DORA 2025 found (no 2026 DORA edition found as of 2026-10-15; the 2025 AI-assisted-development figures below are carried over, not re-verified) 90% AI adoption increase correlates with 9% higher bug rates, 91% more review time, 154% larger PRs
- **Worktree isolation is converging as an industry standard** (convergence claim not independently re-verified in this refresh): ccswarm, agentree, git-worktree-runner, Cursor 2.0, OpenAI Codex all independently adopted it
- **mini-swe-agent** ([SWE-agent/mini-swe-agent](https://github.com/SWE-agent/mini-swe-agent), ~8.5k stars, active; scores on the [SWE-bench Bash Only leaderboard](https://www.swebench.com/bash-only.html); the earlier 65–74% figure was not re-verified) validates radical simplicity — a minimal harness with good context engineering outperforms complex frameworks
- **GitHub Agentic Workflows** (technical preview announced 2026-02-13; no GA announcement found; `github/gh-aw` at v0.92.0, still pre-1.0): define CI automation in Markdown instead of YAML; AI agents figure out execution

**Relevance**: The convergence on worktree isolation validates our architecture. The quality deficit numbers reinforce the importance of the harness (lints, CI, structural enforcement) over raw agent throughput. GitHub Agentic Workflows are worth monitoring for issue triage and CI failure investigation automation.

---

## GitHub Outage Resilience and Offline Development

**Added**: 2026-03-04 | **Last verified**: 2026-10-15 | **Sources**: [SecureSlate: GitHub outage resilience](https://getsecureslate.com/blog/what-the-github-outage-taught-us-about-resilience-and-compliance-2026), [GitHub down Feb 2026](https://serenitiesai.com/articles/github-down-ai-coding-tools-dependency-2026), [GitHub June 2025 outage](https://www.webpronews.com/githubs-june-2025-outage-how-a-routine-database-migration-cascaded-into-a-platform-wide-crisis/), [Self-hosted git platforms 2026](https://dasroot.net/posts/2026/01/self-hosted-git-platforms-gitlab-gitea-forgejo-2026/)

Key takeaways:
- GitHub has had multiple major outages in 2025–2026, partly due to its ongoing datacenter-to-Azure migration; Feb 2026 outage blocked pushes, CI, and PR reviews globally
- **Recent incidents** ([githubstatus.com history](https://www.githubstatus.com/history), most recent entries only): Actions on 2026-08-06, 08-18, 08-26 and 10-05; GitHub.com 08-17; Git Operations, Pull Requests and Actions on 10-06 and 10-07 (one also hit Issues). Jun-Jul 2026 was not covered by the data retrieved. GitHub's [August 2026 availability report](https://github.blog/news-insights/company-news/github-availability-report-august-2026/) says the first production MySQL primary ran from Azure on 08-11; secondary reports say the stated goal is to exit its own data centers by end of 2026. No GitHub-issued resilience guidance for users found
- **Multi-remote strategy** is the most common resilience pattern: keep GitHub as primary, add a secondary remote (Forgejo, GitLab, Gitea) as failover — preserves existing integrations while enabling continued work during outages
- **Forgejo** (community fork of Gitea; v17.0.0 on 2026-10-15) is lightweight, self-hostable, and has Forgejo Actions (GitHub Actions–compatible but not identical; some workflow tweaks needed). Supports offline runner registration.
- **Gitea** offers a plugin-based microservices model; Gitea Actions provides closer GitHub Actions compatibility
- Alternative workflows mentioned by developers during outages: `git-send-email`, Radicle (decentralized git protocol)
- Core git operations (commit, branch, merge, diff, log) are fully local and unaffected by outages — the pain points are CI, PRs, issues, and code review

**Relevance**: This workspace depends on GitHub for issues, PRs, CI, and Copilot reviews. During outages, local coding continues but the issue-first workflow, worktree scripts (which use `gh`), and the PR-based review process are blocked. A resilience strategy should address these specific dependencies.

---

## git-bug — Distributed Offline-First Issue Tracker

**Added**: 2026-03-04 | **Last verified**: 2026-10-15 | **Sources**: [git-bug repo (git-bug/git-bug)](https://github.com/git-bug/git-bug), [Releases](https://github.com/git-bug/git-bug/releases), [BrightCoding overview](https://www.blog.brightcoding.dev/2025/06/01/git-bug-a-distributed-offline-first-bug-tracker-embedded-in-git/), [HN discussion](https://news.ycombinator.com/item?id=43971620), [ros2_agent_workspace #418 — v0.10.1 syntax-drift lesson](https://github.com/rolker/ros2_agent_workspace/issues/418)

Key takeaways:
- Stores issues as git objects (under `refs/bugs`), not files — no clutter in working tree, full version history, distributed by default.
- **Offline-first**: create, edit, comment without network; syncs via `git push/pull` to any remote.
- **Bidirectional bridges**: GitHub, GitLab, Jira, Launchpad.
- Multiple interfaces: CLI, TUI, web UI.
- **v0.11.0 released 2026-09-22** (first release since v0.10.1, May 2025; [release notes](https://github.com/git-bug/git-bug/releases/tag/v0.11.0)): rewritten web UI, code browser, cache correctness fixes, a formal on-disk spec, forward-compatible handling of unknown operations, packaged builds. It fixes #1582 (a GitHub-bridge push followed by a pull duplicated every comment), which v0.10.1 users may have hit. Default branch is now `trunk`; an unreleased change replacing the bleve index with SQLite landed 2026-10-15, so the cache layer may change again. The nested `git bug bug ...` CLI form still appears in trunk docs; v0.11.0 itself was not run here.
- **v0.10.1 syntax migration** (lesson from ros2 #418): commands moved from top-level (`git bug select/show`) to nested under `git bug bug` in v0.10.1. Scripts written for earlier versions silently fall back to whatever wraps them (`2>/dev/null`) without complaint — the ros2 workspace's scripts fell back to `gh` for ~2 weeks before someone noticed. verified 2026-04-19 that this workspace's scripts use the correct `git bug bug ...` form (not re-checked against v0.11.0 binaries). Check the installed version before upgrading: if the installed git-bug is v0.10.1, the duplicate-comment bridge bug applies.
- **git-issue** (Spinellis) is a simpler alternative storing issues as files in a dedicated branch.

**Relevance**: Our workspace has adopted git-bug as the first read path (ADR-0010). 96 issues cached locally as of 2026-04-19. Two gaps remain vs. an ideal offline-first story: (1) visible fallback warnings when git-bug is unavailable (roadmap item in PR #157); (2) writes still go through `gh issue create` — offline issue creation exists via `GITBUG_CREATE=1` but hasn't been exercised end-to-end. Forgejo as an alternative remote has been explicitly declined this session (D6).

---

## Local CI with Act (nektos/act)

**Added**: 2026-03-04 | **Last verified**: 2026-10-15 | **Sources**: [nektos/act repo](https://github.com/nektos/act), [CICube guide](https://cicube.io/blog/run-github-actions-locally/), [Microsoft guide](https://techcommunity.microsoft.com/blog/azureinfrastructureblog/using-act-to-test-github-workflows-locally-for-azure-deployments-cicd/4414310)

Key takeaways:
- Latest release v0.2.89 (2026-06-01); no release or master commit since, after monthly releases earlier in 2026, so activity has slowed (not archived, ~72k stars). Compatibility changes in 2026 were not reviewed.
- Runs GitHub Actions workflows locally using Docker — reads `.github/workflows/` and spins up containers matching the GitHub environment
- **Works offline** with cached Docker images; no GitHub connectivity needed for execution
- Eliminates the commit-push-wait cycle for CI feedback; saves GitHub Actions minutes
- Can serve as a local task runner alongside or instead of Make
- Limitations: not 100% compatible with all GitHub Actions features (marketplace actions may need adaptation), requires Docker

**Relevance**: The workspace already generates CI workflow templates (`.agent/templates/ci_workflow.yml`) for project repos. `act` could run these locally as a pre-push check or during outages. Combined with pre-commit hooks (already in place), this would provide full local CI coverage. The ROS 2 container images used in CI (`ros:jazzy-ros-core`) work with `act` since they're standard Docker images.

---

## ROS 2 Offline Development Patterns

**Added**: 2026-03-04 | **Last verified**: 2026-10-15 (reference only — no ROS project currently managed) | **Sources**: [rosdep offline mirror PR](https://github.com/ros-infrastructure/rosdep/pull/839), [ROS Answers: rosdep offline](https://answers.ros.org/question/276942/can-sudo-rosdep-init-and-rosdep-update-be-done-offline/), [rosdep mirror guide](https://answers.ros.org/question/338122/how-do-i-deploy-a-rosdep-mirror/)

Key takeaways:
- Distro state (2026-10-15): **Lyrical Luth** shipped May 2026 as an LTS supported to May 2031 ([release page](https://docs.ros.org/en/lyrical/Releases/Release-Lyrical-Luth.html)); Jazzy (to May 2029) and Lyrical are the current LTS pair; Kilted Kaiju reaches end of life in November 2026 (REP-2000 on master did not yet list Lyrical).
- Source note: the rosdep mirror PR #839 is still open and unmerged (last updated 2022); answers.ros.org is now a static archive, so the two ROS Answers links may need re-checking one by one.
- `rosdep` can work offline by setting `ROSDISTRO_INDEX_URL=file:///path/to/local/index-v4.yaml` — clone the `rosdistro` repo locally and point to it
- All ROS 2 binary packages can be cached via a local apt mirror or pre-installed in Docker images
- `colcon build` and `colcon test` are fully local — no network needed once dependencies are installed
- The main online dependencies are: initial `rosdep init/update`, `apt install` for new packages, and `git clone` for source dependencies not yet in rosdep

**Relevance**: ROS 2 development is inherently local-friendly. The workspace's build/test workflow (`make build`, `make test`) works offline once dependencies are installed. The gap is in the governance layer (issues, PRs, reviews), not the build layer.

---

## Lightweight Self-Hosted Git Forges (Forgejo / Gitea)

**Added**: 2026-03-04 | **Last verified**: 2026-10-15 (Forgejo/Gitea explicitly declined 2026-04-19 — see session D6; entry retained as reference in case constraints change) | **Sources**: [Self-hosted git platforms 2026](https://dasroot.net/posts/2026/01/self-hosted-git-platforms-gitlab-gitea-forgejo-2026/), [Forgejo comparison](https://forgejo.org/compare/), [Forgejo vs Gitea](https://forgejo.org/compare-to-gitea/), [Gitea comparison](https://docs.gitea.com/installation/comparison)

Key takeaways:
- **Gitea** and **Forgejo** (community fork of Gitea) are functionally near-identical: ~200MB RAM, single binary or Docker one-liner, run on Raspberry Pi
- Versions 2026-10-15: Forgejo v17.0.0 (the older v15.0 LTS reportedly shipped 2026-04-16, unverified); Gitea moved from the 1.27 line (last 1.27.3, 2026-08-29) to v28.0.0 (2026-09-29) and v28.1.0 (2026-10-06). No 2026 Forgejo governance change found; Actions-compatibility status not re-verified.
- Both offer: repo hosting, built-in issue tracker, web UI, wiki, Actions-compatible CI runners
- **GitLab CE** requires 4-8GB+ RAM — roughly 40x heavier for the same core git hosting role
- Forgejo is community-governed (no corporate entity); Gitea has Gitea Ltd behind it. Forgejo is the safer long-term bet for governance stability
- Forgejo Actions are GitHub Actions–compatible but not identical — minor workflow tweaks typically needed
- Both support offline runner registration for CI in disconnected environments

**Relevance**: The workspace uses a GitLab instance on the robot network for repo sync. Forgejo/Gitea could replace it at a fraction of the resource cost while adding a built-in issue tracker and web UI. Combined with git-bug for distributed issue sync, this enables a fully local-first development workflow where GitHub becomes a publication channel rather than a dependency. See [#345](https://github.com/rolker/ros2_agent_workspace/issues/345).

---

## Agent Orchestrators for Parallel Coding Agents

**Added**: 2026-03-11 | **Last verified**: 2026-10-15 | **Sources**: [ComposioHQ/agent-orchestrator](https://github.com/ComposioHQ/agent-orchestrator), [Vibe Kanban](https://vibekanban.com/), [Superset orchestrator comparison](https://superset.sh/compare/best-ai-coding-agents-2026), [Visual Studio multi-agent in VS Code 1.109](https://visualstudiomagazine.com/articles/2026/02/09/hands-on-with-new-multi-agent-orchestration-in-vs-code.aspx), [Addy Osmani — The Code Agent Orchestra](https://addyosmani.com/blog/code-agent-orchestra/), [From Conductor to Orchestrator (2026 practical guide)](https://htdocs.dev/posts/from-conductor-to-orchestrator-a-practical-guide-to-multi-agent-coding-in-2026/), [CodeMachine-CLI (Apr 2026)](https://www.blog.brightcoding.dev/2026/04/14/codemachine-cli-the-revolutionary-ai-agent-orchestrator), [Catalyst & Code — 2026 orchestration frameworks](https://www.catalystandcode.com/blog/ai-agent-orchestration-frameworks)

Key takeaways:
- **The category keeps shifting**: agent-orchestrator (ComposioHQ, ~13k stars) and Superset (~15k stars) are active as of 2026-10-15. **Vibe Kanban was sunset commercially** (Bloop announced shutdown 2026-04-10, hosted services ended after 30 days) but continues as a community-maintained, local-only open-source project (~28k stars). Capy, CodeMachine-CLI and Overstory status could not be verified. VS Code 1.109 added native multi-agent orchestration in Feb 2026; Claude Code, Codex and Copilot native parallel-agent features were not surveyed this round (unverified).
- **Three-tier pattern is now the standard framing** for 2026 developer workflows: Tier 1 interactive (Copilot/Cursor at the cursor), Tier 2 parallel sprints (Claude Code + multiple worktrees), Tier 3 overnight backlog drain (orchestrator + agents spawned by issue). Most developers will use all three.
- **Convergent architecture** (unchanged from 2026-03-11): (1) git worktree isolation per agent, (2) supervisor/coordinator that decomposes tasks, (3) event-driven reactions to CI/review, (4) dashboard for human oversight, (5) YAML-based configuration.
- **Agent-agnostic adapters are now table-stakes** — orchestrators target Claude Code, Codex, Aider, Cursor agents via the same surface. Runtime-agnostic (tmux/Docker/K8s) and tracker-agnostic (GitHub/Linear) likewise.
- **"Code Agent Orchestra" / "Conductor to Orchestrator"** writeups (Osmani + others) frame the pattern as a distributed-systems design problem: constrain the agent space, design for failure, validate at boundaries.

**Relevance**: This workspace already has the foundational primitives all orchestrators build on: worktree isolation, draft-PR visibility, workforce protocol, multi-framework identity. Gaps vs. agent-orchestrator still stand: (1) no reaction system for CI/review events, (2) no unified agent-status dashboard tuned to parallel operation, (3) no automated task decomposition, (4) no inter-agent messaging. Of these, the reaction system remains the most immediate value. The 2026-04-19 update: our rejection of "coordinator-intermediated" designs (session decision D5) means we'd want an orchestrator that is **additive**, not between us and our agents. Most 2026 orchestrators are intermediated — worth evaluating each carefully before adoption.

---

## Potential Inspiration Tracker Candidates

**Added**: 2026-03-22 | **Last verified**: 2026-10-15 (updated: gastown + microsoft-skills dropped from registry per 2026-04-19 inspiration-tracker run — see their digests for archival reason) | **Sources**: [obra/superpowers](https://github.com/obra/superpowers), [obra/superpowers-lab](https://github.com/obra/superpowers-lab), [steveyegge/gastown](https://github.com/steveyegge/gastown), [microsoft/skills](https://github.com/microsoft/skills), [wshobson/agents](https://github.com/wshobson/agents), [hesreallyhim/awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code), [ComposioHQ/agent-orchestrator](https://github.com/ComposioHQ/agent-orchestrator)

Survey of repos that could be tracked via `/inspiration-tracker add` for portable patterns and enhancements. Assessed against this workspace's concerns: skills architecture, governance, worktree isolation, multi-agent coordination, and multi-framework identity.

### Strong candidates (inspiration type)

- **obra/superpowers** (~300k stars, active 2026-10) — The dominant Claude Code skills framework. TDD-enforced workflow, composable skills, subagent-driven review, skill authoring skill. Interest areas: skills architecture, TDD methodology, subagent patterns, review workflows. Already listed as an example in the skill's SKILL.md but not yet in the registry.
- **steveyegge/gastown** (~18k stars, active 2026-10; archived in the registry per 2026-04-19 run) — Multi-agent workspace manager with git-backed persistent work tracking, web dashboard, and hook-based coordination. Interest areas: multi-agent coordination, work state persistence, dashboard patterns, hook-based propulsion.
- **microsoft/skills** (~3k stars, active; archived in the registry per 2026-04-19 run) — 126 modular skills + MCP server configs + agent persona definitions. Official reference for the Agent Skills open standard. Interest areas: skill format conventions, MCP server configuration patterns, agent persona definitions, skill discovery/registry.

### Worth monitoring (inspiration type)

- **obra/superpowers-lab** (~430 stars, last push 2026-06-01, quiet 4+ months; consider dropping) — Experimental skills incubator for superpowers. New techniques tested here before promotion. Interest areas: emerging skill patterns, experimental workflows.
- **wshobson/agents** (~41k stars, active) — 112 agents, 146 skills, 79 tools in 72 plugins. Massive but well-organized plugin architecture with model-tier optimization (Sonnet/Haiku routing). Interest areas: plugin organization, model routing patterns, agent team presets.
- **ComposioHQ/agent-orchestrator** — Already covered in research digest (Agent Orchestrators entry). Pluggable adapters for runtime/agent/workspace/tracker/notifier. Interest areas: reaction system for CI/review, adapter architecture, task decomposition.

### Reference only (not worth tracking)

- **hesreallyhim/awesome-claude-code**, **VoltAgent/awesome-claude-code-subagents**, **rohitg00/awesome-claude-code-toolkit** — Curated lists / catalogs. Useful for one-off browsing but too broad and fast-churning for structured tracking. Better used as discovery sources when searching for a specific pattern.

**Relevance**: The inspiration tracker currently only tracks `ros2_agent_workspace` (fork) and `gstack` (inspiration). Adding 2–3 of the strong candidates would broaden the workspace's awareness of evolving patterns in skills architecture, multi-agent coordination, and governance enforcement. Recommended priority: **superpowers** first (most relevant to skills and review workflows), then **gastown** (most relevant to multi-agent coordination).

**Star counts and activity refreshed 2026-10-15 via `gh api`** (hesreallyhim/awesome-claude-code ~56k, agent-orchestrator ~13k; none archived).

**Update 2026-04-19**: Registry evolved since this survey — superpowers added, gastown + microsoft-skills added then archived (low signal-to-noise per 2026-04-19 inspiration-tracker run). New candidates surfaced during 2026-04-19 research refresh, not yet triaged:

- **Vibe Kanban** ([vibekanban.com](https://vibekanban.com/); commercially sunset 2026-04, community-maintained) — Visual Kanban UI for orchestrating AI coding agents. May not fit our CLI-first preference but worth looking at the task-decomposition model.
- **Superset** ([superset.sh](https://superset.sh/)) — Orchestrator stack pattern (Superset/Capy for orchestration + Claude Code/Codex for primary + Copilot/Cursor for editor-side).
- **Capy** — Orchestrator, mentioned alongside Superset as the other leading 2026 orchestration platform.
- **CodeMachine-CLI** ([BrightCoding article](https://www.blog.brightcoding.dev/2026/04/14/codemachine-cli-the-revolutionary-ai-agent-orchestrator)) — New AI agent orchestrator (April 2026).

None pursued as inspiration-tracker entries yet. Triage on next brainstorm.
