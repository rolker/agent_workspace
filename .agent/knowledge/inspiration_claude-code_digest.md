# Inspiration Digest: claude-code

Type: inspiration
Last checked: 2026-11-13
Repo: anthropics/claude-code @ 14bb83918b8682ca5ef2fb2f2add778eb745ee62 (CHANGELOG.md head, version 2.1.323)
Previously checked: 2026-09-22 @ 56f3653 (version 2.1.280; the SHA was
recorded with its last character missing as `...781141e8`, the full SHA
is `56f36532530f88b572854538d685fcf781141e8c`)

## Changelog (2026-09-22 → 2026-11-13)

Compare `56f3653...14bb839`: 118 commits (complete), file list truncated
at 300 files. Of the 118 commits, 40 are "Update CHANGELOG.md" and 39 are
"Update mods/" — the public repo is a mirror that publishes the changelog,
plugins and the source of the built-in "mods"; it does not show the CLI's
own source. So the **`CHANGELOG.md` in the clone is the real source**: 43
versions, 2.1.281 → 2.1.323 (about 2,980 bullet lines; `gh release list`
latest is v2.1.323, 2026-11-12). I did not read every bullet: I searched
the bullets by the registry's interest areas (workflow, worktree, hook,
memory, schedule, skill, plugin, subagent, auto mode, code-review,
cross-session) and read the matches. `claude --version` on this host is
2.1.323, matching the clone head. Survey question remains "what can we
retire".

What the new facts say about the capability map above:

- **Worktrees (interest area: worktree isolation)**: v2.1.323 changes the
  macOS/Linux Bash sandbox so `git worktree add`, `move` and `remove` fail
  read-only, as do commits in a worktree the session was not started in or
  given, even one inside the project; worktree creation also refuses
  checkouts whose `.git` is a link or holds hard links. 2.1.319 fixed a
  sandbox escape on worktree creation; 2.1.314 fixed sandbox protections
  not applying to a worktree entered by `--resume`/`--continue`; 2.1.305
  fixed new worktrees in a bare repository starting from local HEAD.
  The sandbox is a setting; `~/.claude/settings.json` on this host has
  `"sandbox": {"enabled": false}`, so these only bite where it is on
  (not checked: whether any other host or the cloud runs this workspace
  with the sandbox on). The "keep worktree scripts" verdict stands, but the
  `cd`-into-a-worktree pattern is exactly the case the new commit rule
  targets.
- **Workflows**: 2.1.305 fixed Workflow resume re-running completed
  `pipeline()`/`parallel()` agents (now served from the run's journal);
  2.1.318 fixed re-running finished agents after a usage limit; 2.1.296
  added `CLAUDE_CODE_WORKFLOW_SUBAGENT_MODEL` (one model for every workflow
  agent, other subagents keep theirs); 2.1.323 pauses workflows at a usage
  limit in the desktop app and stops telling the agent to do the work
  itself after safeguards stop a workflow agent. 2.1.323 also adds **Code
  Mode** (experimental, Claude writes JavaScript to call tools; not
  evaluated). These remove resume and model-tier gaps that the
  `run-issue` dispatcher reasoning leaned on; the durable `progress.md`
  point is unchanged.
- **Sub-agents and messaging**: `SendMessage` to a running background agent
  now arrives earlier (2.1.317); 2.1.319 adds an "Earlier in this session"
  row in `/tasks` to reopen and message finished subagents; 2.1.302 made
  fork subagents (`subagent_type: "fork"`) default-on in `-p`, SDK, desktop
  and VS Code; 2.1.292 added an `effort` parameter to the Agent tool and
  2.1.316 `CLAUDE_CODE_SUBAGENT_EFFORT`; subagent frontmatter gained
  `autoCompactWindow` (2.1.296). No change to `ListAgents` itself in the
  changelog; the open issue list shows the desktop app's cross-session
  tools (`get_session`, `start_session`, `delete_session`) being extended
  by requests, and a bug about offline Remote Control sessions persisting
  in `ListAgents` (issue 109652).
- **Hooks and permissions**: 2.1.319 adds `permissions.denyInsteadOfPrompting`
  (a call that would wait on a permission prompt is denied and the turn
  continues, in terminal sessions, subagents and teammates); 2.1.323 changes
  what happens when a permission check fails after a `PreToolUse` hook said
  "allow" (decided as if no hook answered) and when a `PermissionRequest`
  hook rewrote the input; 2.1.317 adds `onFailure: "block"` for SDK hook
  callbacks; 2.1.299 runs `UserPromptSubmit` hooks before skill/command
  expansion.
- **Mods (new surface)**: a "mod" is a plugin whose behaviour is a
  TypeScript hooks module hooking engine events (`mods/README.md` in the
  clone). Five ship built in (`sec-default`, `diff`, `telemetry`,
  `agents-md`, `privacy`). Tooling: `claude plugin validate`
  (type-checks the hooks module as of 2.1.323), `claude plugin test`,
  the built-in `plugin-authoring` skill, `engines["claude-code"]` in
  `plugin.json` (2.1.323), `claude plugin install --marketplace`
  (2.1.292). Relevant to the open packaging question recorded above.
- **`AGENTS.md`**: the built-in `agents-md` mod reads `AGENTS.md` where a
  project has no `CLAUDE.md`, or beside it under the option
  `claude-md-and-agents-md` (`mods/agents-md/README.md`). Whether that
  option is user-settable on the installed CLI was not checked.
- **Prompt audit**: `/doctor prompt-audit` (2.1.283) audits CLAUDE.md files,
  skills, agents and commands for prompting patterns written for older
  models.
- **Scheduling**: only routine/cloud-session UI changes and `/loop` fixes
  (self-paced `/loop` now ends if a turn does not reschedule, 2.1.319); no
  change that moves the `make sync` verdict.
- **Persistent memory**: nothing relevant beyond Auto-memory being blocked
  from background sessions (2.1.285) and stale MEMORY.md/CLAUDE.md after
  compaction fixed (2.1.311); the "keep `progress.md`" verdict stands.
- **Code review**: `/code-review` gained effort levels (first argument),
  `--max-findings` (2.1.288), cleanup/CLAUDE.md-convention findings at
  medium effort (2.1.290); `/ultrareview` got trust checks and upload
  restrictions. No change to the `review-code` "keep for now — revisit"
  verdict beyond more native review surface to compare against.
- **Skill size after compaction**: the superpowers digest (2026-11-13)
  cites a Claude Code behaviour that skills are cut off at 20,000
  characters when re-attached after compaction. This changelog does not
  state that: the only compaction/skills entry found is 2.1.304
  ("compaction sends Claude the skill list again; `/reload-skills`
  sends only new or changed skills"). So the 20,000-character claim is
  not confirmed here.

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
  rather than guess. *Update 2026-10-08:* the plugin spike for workspace
  issue #345 (claude 2.1.281) confirmed a local-scope directory marketplace
  plus plugin works end to end — plugin root at the repo root with
  `"skills": "./.claude/skills"`, namespaced skills beside a project's own
  same-named skills, worktrees of the enabled project see it, `bin/` on the
  Bash PATH, edits apply next session without reinstall. Packaging is a
  viable replacement for the user-tier skill symlinks; the format question
  stays open for the next survey.
- Did not run any prompts against the installed `claude` CLI beyond
  `--version` and `--help`, per instructions.

## Activity Snapshot

- **2026-11-13**: 16,517 open issues and 639 open PRs (GitHub search API);
  4 PRs merged since 2026-10-14 (the public repo is a mirror). The 40 most
  recent open issues are mostly desktop/Cowork/Remote Control bugs and
  desktop "Code tab" cross-session tool requests (`get_session`,
  `start_session`, `set_session_directory`); one auto-mode classifier
  report (issue 109636) and one report that CLAUDE.md rules are ignored in
  long rule-heavy sessions (issue 109619). Open PRs are mostly small
  plugin fixes (plugin-dev, pr-review-toolkit, code-review plugin
  confidence scoring).
- *Earlier snapshot (2026-09-22):*
- 11,510 open issues, 704 open PRs (GitHub search API, 2026-09-22)
- 51 PRs merged/closed in the last 30 days as of survey date
- Notable open items surfaced during this survey: subagent idle/notification
  relay bug (#96109), background subagent completion messages disrupting the
  transcript (#96107) — both touch the sub-agent dispatch area this workspace
  also relies on.

## Pending Review

- `cc-1` `sandbox-worktree-commit-rule` — v2.1.323 sandbox: `git worktree
  add/move/remove` read-only and no commits in a worktree the session was
  not started in or given. Matters if the sandbox is ever turned on for
  sessions that create worktrees and `cd` into them (it is off in this
  host's user settings); the worktree scripts and `/start-task` `cd`
  pattern are the affected case (2026-11-13)
- `cc-4` `mods-and-plugin-engines` — mods (TypeScript hooks plugins),
  `claude plugin validate/test`, and `engines["claude-code"]` in
  `plugin.json`; bears on the plugin-packaging format question left open
  above and on whether shell hooks should stay shell (2026-11-13)

Carried over from 2026-09-22 (still pending):

- `retire-bash-tool-mapping-hook` — the hook fights auto mode's own
  dedicated-tool guidance and fired repeatedly during this survey run
  (2026-09-22). **Done 2026-09-23**: hook and its registration deleted on
  main in 599a10f (#328); noted here 2026-10-08.
- `dispatcher-to-workflow-and-agent-files` — replace `dispatch_phase.sh`'s
  hand-rolled state machine with Workflow tool scripts + `.claude/agents/*.md`,
  keeping `progress.md` as the durable timeline (2026-09-22)
- `cross-session-claim-via-listagents` — feeds #321; replace file-timestamp
  inference for one-driver-per-issue with `ListAgents`/`SendMessage` (2026-09-22)
- `revisit-multi-framework-requirement` — no Codex/Gemini session has driven
  the review loop in the observed period; re-evaluate whether the
  multi-framework adapter/identity layer still earns its complexity (2026-09-22)

## Roadmapped

- `cc-3` `doctor-prompt-audit` — run `/doctor prompt-audit` once on the
  workspace, read the report, then decide whether `/audit-workspace` should
  use it. Owner's note: "it might become part of the janitor routines" —
  cross-referenced to the roadmap's "Janitor sweep" line. Added to
  docs/roadmap.md (2026-11-13)
- `cc-5` `workflow-resume-and-model-env` — note on the existing
  `dispatcher-to-workflow-and-agent-files` item (no matching line existed in
  docs/roadmap.md, so one short line stating the item and the note was
  added): Workflow resume serves finished agents from the run's journal
  (2.1.305, 2.1.318) and `CLAUDE_CODE_WORKFLOW_SUBAGENT_MODEL` sets one
  model for workflow agents, so two reasons for the hand-written dispatcher
  are weaker; read from the changelog, not tried here. Added to
  docs/roadmap.md (2026-11-13)

## Skipped

- `cc-2` `deny-instead-of-prompting-for-background-agents` — measured
  2026-11-13: 683 background-agent transcripts (2026-10-14 to 2026-11-13,
  about 31,000 tool calls), 159 permission refusals, median 0.06 s, max
  16 s, none waited on a prompt; background agents are already refused at
  once. The setting applies to the whole session per the changelog, so it
  would also turn the owner's own prompts into refusals (2026-11-13)
- `cc-6` `native-agents-md` — informational: whether the option can be set on
  the installed CLI was not checked, and the Claude-specific setup content
  in `CLAUDE.md` would stay either way (2026-11-13)

## Deferred

(none yet)
