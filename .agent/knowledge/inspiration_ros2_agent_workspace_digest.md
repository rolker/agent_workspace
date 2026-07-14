# Inspiration Digest: ros2_agent_workspace

Type: fork
Last checked: 2026-07-14
Repo: rolker/ros2_agent_workspace @ b64640f14f05799796164dd7fe07cd8b583541dc
Previously checked: 2026-04-26 @ 395b1c5e26c82a7b032738adc0d4a03269e48035

## Changelog (2026-04-26 → 2026-07-14)

511 commits, 179 files — by far the biggest round since tracking began.
Upstream pace increased sharply (June deployment freeze drove a burst of
field tooling, then a large orchestration build-out). Major themes:

### Per-repo root AGENTS.md (#563 → PR #567, ADR-0017)

GitHub Copilot code review now reads a repo's root `AGENTS.md`
(2026-06-18) and applies it when generating review feedback. Upstream
measured ~200 false-positive Copilot findings across 18 repos with no
instructions and responded with: a thin (~40–60 line) per-project-repo
`AGENTS.md` instantiated from `.agent/templates/project_agents_md.md`,
ADR-0017 ("reference, never fork" — the per-repo file points at workspace
rules, adds only repo-specific content plus a standalone context block for
Copilot which can't see the workspace), and wiring into `onboard-project`
(offers the file) and `audit-project` (checks presence/currency).

- **Daddy_camp relevance**: High. The project repo gets Copilot PR
  reviews with zero instructions today. Template + ADR + skill wiring are
  all domain-neutral. Direct port candidate.

### Script tests in CI (#509 → PR #510)

`make test-scripts` runs `.agent/scripts/tests/` (shell via bash, python
via pytest) in a dedicated CI job. Tests are hermetic (temp git sandboxes,
stubbed `gh`, no network), so the job needs only git + pytest.

- **Daddy_camp relevance**: High, cheap. We have 4 hermetic test scripts
  in `.agent/scripts/tests/` that run manual-only; our `validate.yml` has
  lint + docs jobs but no script-tests job. Direct port.

### Composable-timeline orchestration (#470/#481 → ADRs 0013, 0015; PRs #519–#557)

The largest theme (~15 PRs). Three layers:

1. **ADR-0013 — progress.md entry-type vocabulary.** Canonical entry
   types (`## Issue Review`, `## Plan`, `## Plan Review`,
   `## Implementation`, `## Local Review (Pre-Push)`,
   `## Integrated Review`, …) so six skills write one grep-able timeline.
   Duplicate findings across sources are kept and surfaced as
   "cross-source confirmations" at integration time. `progress_read.py`
   parses the timeline.
2. **`dispatch_subagent.sh` + ADR-0015 (handoff context contract).**
   Runs any workflow phase in a fresh-context sub-agent — in-process
   (Agent tool) or headless container (subscription token, no GitHub
   auth in either direction). Host fetches inputs (`--context-file`) and
   publishes outputs; container's canonical record is the committed
   progress.md entry. Exit contract: host reads the phase's last entry to
   route. Extensive test coverage (5 test files).
3. **`/run-issue` host orchestrator + `/address-findings`.** Drives
   review-issue → plan-task → review-plan → implement → review-code →
   triage-reviews → address-findings, each a fresh-context dispatch, with
   `AskUserQuestion` checkpoints gating every push/PR/merge. Local-first:
   PR created at the end. `/address-findings` is a deliberately thin
   "work the agreed fix plan" phase.

- **Daddy_camp relevance**: Split. ADR-0013 vocabulary + progress_read
  pattern is Medium — we already write progress.md entries in
  triage-reviews and the drift risk is real. The dispatch/run-issue
  machinery is the "orchestrator" category we deferred (Tier 3, D5
  additive-only constraint) — but notably upstream's take is local-first,
  checkpointed, and terminal-based, i.e. it satisfies much of our
  CLI-first constraint. Worth a roadmap entry as a reference design
  rather than a port.

### Identity enforcement (#468 → PR #471; hooks)

Sub-agent commits were landing authored as the human user (env vars not
surviving subshells). Three mechanisms: `check-commit-identity.py`
pre-commit hook (strict on agent branches when `$AGENT_NAME` set,
permissive otherwise), `identity_patterns.py` (shared patterns),
`check_pr_authors.py` CI check (Mechanism C — env-independent,
load-bearing: rejects PRs where an agent-convention branch has commits
whose primary author matches a human pattern; Co-Authored-By trailers
deliberately not evaluated).

- **Daddy_camp relevance**: Medium. Same failure mode exists here when
  sub-agents commit. The CI-side check is the portable part (no env
  dependency); patterns would need adapting to rolker.net emails.

### review-code refinements (#467 → PR #517; #537 → PR #543; #460 → PR #462)

- Copilot Adversarial made **opt-in** (`--copilot`), replaced by default
  with a **dual-lens Claude pass** (Lens A + Lens B) after context-cost
  evaluation.
- **Convergence/ship signal** (pre-push): round = count of prior
  `## Local Review (Pre-Push)` entries + 1; verdict "ship recommended"
  when no must-fixes, or at round ≥ 2 when must-fix count is low (≤2),
  not rising, and mechanical. Gives the orchestrator (or human) a
  ship-vs-continue signal instead of looping reviews indefinitely.
  Includes a lighter severity bar for agent-guidance docs (SKILL.md).
- `--skip-static` / `--no-progress` / `--issue` overrides.

- **Daddy_camp relevance**: Medium. The convergence/ship-signal pattern
  is portable to our review-code/cross_model_review loop and addresses a
  real cost (each re-review round is expensive). Copilot-opt-in decision
  is an interesting data point for our own external-review cost tuning.

### Deployment mode (ADR-0014, #495/#499–#557 cluster)

Behavioral operating mode for live field deployments: urgency contract
(anti-rabbit-holing under live time pressure, grounded in incident-command
/ sterile-cockpit practice) + lifecycle tooling (`/start-deployment`,
`/wrap-up-deployment`, `dlog.sh` prompt-free timestamped logging,
`deployment_config.yaml`). Notable lessons: agents fabricate timestamps
(fix: forbid typed timestamps, use a helper); log-append via `printf >>`
hits a permission prompt per entry (fix: dlog helper).

- **Daddy_camp relevance**: Low (field-ops domain). The two lessons
  (fabricated timestamps; prompt-free append helper) are worth remembering
  if we ever build session-logging tooling. Skip.

### Upstream-internal / ROS-domain (skipped)

- ADR-0016 runtime-vs-baked layer chaining, setup.bash O(N²) fix (#559),
  rosdep bake (#520–#523), LD_LIBRARY_PATH shadowing (#484), agent Docker
  image + `docker_run_agent.sh` (#566 open bug), `verify_change.sh`
  (colcon-specific) — all ROS/container domain.
- `make merge-pr` (#488 → PR #494) — adapted **from us**; their #507/#508
  ROOT-resolution fixes mirror problems we already solved (#146/#155,
  `test_merge_pr_root_resolution.sh`). No action.
- git-bug per-repo bridge setup (#476), SSH-agent persistence (#502) —
  field/multi-repo workflow we don't have.

### Open issues worth watching

- **#564** — Slim workspace AGENTS.md to a map using an
  enforcement-backed criterion (ADR + restructure). Our AGENTS.md has the
  same growth problem; watch for their criterion.
- **#562** — merge_pr.sh `--skill` support (skill worktrees currently
  need manual cleanup). We share this gap — this very digest PR will be
  merged from a skill worktree.
- **#558** — background-dispatch completion notifications don't wake an
  idle agent; **#527** — surface deferred findings across review rounds.
  Both are orchestration-polish; informational.

### Bidirectional note

Upstream checked *us* today (PR #560 "Update inspiration digest:
agent_workspace (2026-07-14 check)") and continues porting our
review-skill improvements (#452/#453). `make merge-pr` and the
inspiration-tracker skill itself both flowed from us to them.

## Pending Review (2026-07-14 round)

- `per-repo-agents-md` — ADR-0017 + project_agents_md.md template +
  onboard/audit wiring (2026-07-14)
- `script-tests-ci-job` — make test-scripts + CI job for
  .agent/scripts/tests/ (2026-07-14)
- `progress-entry-vocabulary` — ADR-0013 canonical entry types +
  progress_read.py (2026-07-14)
- `dispatch-run-issue-reference` — dispatch_subagent.sh + /run-issue +
  ADR-0015 as reference design for eventual orchestration (2026-07-14)
- `identity-ci-check` — check_pr_authors.py CI mechanism + pre-commit
  identity hook (2026-07-14)
- `review-convergence-signal` — round counting + ship-vs-continue verdict
  in review-code (2026-07-14)
- `gitignore-claude-locks` — generalize `.claude/scheduled_tasks.lock` to
  `.claude/*.lock` (2026-07-14)

## Changelog (2026-04-19 → 2026-04-26)

53 commits, 28 files. Major themes:

### Field Mode (#445 → PR #448, ADR-0011)

Carve-out from "never edit files in the main tree" (ADR-0002) for repos
whose `origin` host is not on the GitHub allowlist (`github.com`,
`ssh.github.com`). Adds `.agent/scripts/field_mode.sh` (host-allowlist
detector), `.agent/scripts/tests/test_field_mode.sh`, and a hotfix
walkthrough at `.agent/knowledge/field_mode_hotfix.md`. AGENTS.md grew a
"Field Mode" section.

- **Daddy_camp relevance**: Low. The project repo's origin is GitHub.
  No second remote planned. Skip unless we add a non-GitHub deploy target.

### ADR-0012 — Permit Cross-Reference Addendums in ADRs

Narrows ADR-0001's immutability rule to allow purely navigational
addendums: a Status-line note pointing at a later superseding/scoped
ADR, or a References section listing related ADRs. Substantive edits
still require superseding.

- **Daddy_camp relevance**: Medium. We inherited `docs/decisions/` from
  ros2; the discoverability gap (older ADRs don't link forward to newer
  ones that scope them) applies to us too. Cheap port.

### `/import-field-changes` skill (#432 → PR #440)

Batch-imports remote-ahead commits from a secondary remote (gitcloud) back
to GitHub: per-repo issue creation, draft PR, and pre-review against the
Quality Standard. Depends on `pull_remote.py --json`.

- **Daddy_camp relevance**: Low. Pairs with field-mode; same scope. Skip
  unless field deploys are added.

### AGENTS.md "Quality Standard" section (#437 → PR #438)

Adds a top-level Quality Standard with rules: fix bugs completely (test +
edge case + lifecycle), don't dismiss reviewer concerns about silent
failures or stale data as "nits", don't offer to "table this for later"
when the permanent solve is minutes away. Originally framed for "robot
boats on open water" but the substance is domain-neutral.

- **Daddy_camp relevance**: High. Principles transfer to a public-release
  game project. Direct port with framing adjusted.

### plan-task — "During implementation" guidance + `--no-pr` (#449 → PR #450)

Adds a sizable "During implementation" section: anti-"append-only
changelog" rule for plan files. Inline edits to the plan are the default
when implementation diverges; an `## Implementation Notes` section at the
bottom is allowed only for rationale-bearing design pivots whose *why*
isn't obvious from the diff. Also adds `--no-pr` flag for offline planning.

- **Daddy_camp relevance**: High. Our `plan-task` skill is in active use;
  drift between plan and landed code is a recurring concern. Cheap port.

### triage-reviews — "Require justification for false positives" (#439 → PR #441)

Renames the dismissal table column from "Reasoning" to "Justification",
tightens example wording from "Why it's not applicable" to "Specific
reason the failure mode cannot occur". Forces dismissals to articulate
the absent failure mode, not vibes.

- **Daddy_camp relevance**: Medium. Our local `triage-reviews` already
  has additional logic upstream lacks (Update progress.md step). Small
  additive port.

### Identity scripts (#407 → PR #443)

`set_git_identity_env.sh` and `framework_config.sh` revised so agents
self-report their model via the 3rd argument; the table now functions
as documented fallbacks only.

- **Daddy_camp status**: Already in place. Local versions diverged to use
  rolker.net emails, list Codex CLI, and document the "FALLBACKS ONLY"
  stance per `feedback_model_detection.md`. No port.

### Repo-cosmetic upstream changes (skipped here)

- `git-bug` added to agent Docker image: ros2-specific devcontainer.
- `--symlink-install` doc tightening in AGENTS.md Build & Test: ROS-domain.
- ADR-0001/0002 status-line addendums: meta-port that depends on
  adopting ADR-0012 first.

### New issues since last check (upstream-internal)

- **#454** — triage-reviews post dismissal rationale to PR (proposal).
  Adjacent to our progress.md step. Watch.
- **#452/#453** — Port review-skill improvements *from agent_workspace
  → them*. Inverse direction; informational only.
- **#444** — review-plan reads stale PR body (bug). Upstream-internal.
- **#406** — Investigate gstack (already in our registry).

### Earlier deferrals — status

All items from the 2026-04-19 round have been resolved (ported/skipped).
No carry-over.

## Pending Review (this round)

(none — all items triaged below)

## Changelog (2026-03-22 → 2026-04-19)

65 commits, 53 files. Major themes:

### Agent Dashboard Phase 1 (#400/#402) — shipped

~3498 LOC Python web dashboard (ThreadingHTTPServer + SSE, Playwright tests,
CSRF hardening, static-file containment). ~20 commits over review iterations.

- **Already decided on daddy_camp side**: roadmap #64 "Web dashboard" is
  `done`. No re-port planned (see "CLI-first architecture note" below).

### Git-bug v0.10.1 syntax fix (PR #419 closes #418)

Scripts were written for older v0.9 top-level commands (`git bug select/show`);
v0.10.1 nested them under `git bug bug`. Every call silently fell back to `gh`
for ~2 weeks before the regression was caught. Key lesson: **silent fallbacks
hide breakage.**

- **daddy_camp status**: we got the syntax right first try (our AGENTS.md +
  `_issue_helpers.sh` use `git bug bug ...`). Verified live 2026-04-19 —
  96 local issues cached, bridge configured.
- **Gap**: we don't warn on fallback. Captured in PR #157 roadmap as
  "Git-bug fallback warnings + smoke test" under Unphased.

### Secondary remote sync (#422) — push/pull to non-GitHub remote

Four new scripts (677 LOC): `add_remote.py`, `push_remote.py`, `pull_remote.py`,
`lib/remote_utils.py`. Forgejo-aware; supports pushing to gitcloud or similar
from field machines.

- **daddy_camp status**: **Skip.** Backup for us = `git push origin <branch>`;
  Forgejo declined (D6); no multi-repo manifest need. Ros2's scripts solve a
  problem we don't have.

### ROOT_DIR symlink fix

Similar problem space as our recent #146/#155. They used realpath containment
check; we used `git worktree list`. Both work; no port needed.

### CCOM/JHC presentation slides (#250)

7 commits of domain docs. Skip.

### Layer/manifest fixes (#417, #425)

ROS-domain. Skip.

### Inspiration-tracker skill import (#408/#409)

They imported the skill **from us**. No action.

### New issues since last check

- **#436 — Formalize multi-agent coordination learnings from field
  operations** — triaged in 2026-04-19 session. Portable patterns captured
  in PR #157 roadmap under "Port ros2 #436 behavioral-patterns knowledge."
- **#423 — Git-bug and offline agent workflow for field deployments** —
  read 2026-04-19. Still design-stage (Forgejo bridge planned, not built).
- **#432 — Merging field changes from gitcloud back to GitHub** — related
  to #422 push/pull scripts. Daddy_camp doesn't have this workflow need.
- **#435 — Deployment debrief skill** — field-ops specific (bag analysis
  with noise filtering). Skip.
- **#427, #429, #430, #431, #434** — ROS-domain or field-specific. Skip.

### Earlier items from 2026-03-22 digest — revisit

| Item | Prior status | New status (2026-04-19) |
|---|---|---|
| `dashboard-sh-enhancements` | deferred | **Skip** — ros2 moved to Python web dashboard; our CLI-first preference makes re-port a bad fit |
| `tests/` directory for scripts | deferred | **Ported/Adapted** — we started this session (test_cross_model_review, test_resolve_work_plans_dir, test_merge_pr_root_resolution) |
| `ci_workflow.yml` template | deferred | **Skip** — template targets ROS repos; daddy_camp isn't ROS |
| `pre-commit-config.yaml` template | deferred | **Skip** — same reason |
| `.github/copilot-instructions.md` adapter | deferred | **Skip** — we have Copilot review working via default behavior |

## CLI-first architecture note (2026-04-19 session)

A common thread through recent decisions: the ros2 workspace has chosen
a web dashboard + intermediated review UI direction. Daddy_camp's
single-user, single-machine, CLI-intensive workflow goes the opposite way.
The user:

- Watches agents in action, scrolls back to inspect process
- Catches errors visually from terminal output
- Uses direct typing, CLI keybindings, terminal tab-switching
- Values management-layer tools that **augment** the terminal, not replace it

This is a cross-cutting design constraint that applies to multiple
concurrent ideas:

- **Dashboard**: don't re-port ros2 Phase 1 (web-UI model doesn't fit)
- **Coordinator agent**: must be additive, not intermediated (simmering —
  PR #157)
- **Per-session context card**: unsolved valid need — when switching
  between parallel agent tabs, rapidly re-ground in that agent's issue +
  plan + open questions. Implementation candidates: tmux status bar,
  `focus.md` header in progress.md, `make focus` command, terminal title
  updates. Not a dashboard.

## Activity Snapshot (2026-04-19)

- 10 open issues (from recon scan earlier in session): #434, #435, #436,
  #432, #431, #430, #429, #428, #427, #423
- 1 open PR (#428, layer worktree Python paths)
- Upstream is notably less active than gstack or superpowers — single
  contributor pace

## Pending Review

(none — all items from this changelog triaged)

## Issued

- `quality-doctrine-batch` — agent_workspace #164 bundling four ports
  (AGENTS.md Quality Standard, plan-task During implementation + --no-pr,
  ADR-0012 cross-reference addendums, triage-reviews justification
  tightening) (2026-04-26)
- `web-dashboard-phase1` — Issue #64: ported web-based agent dashboard from upstream (2026-03-22) — **but see "CLI-first" note; may need rethinking**
- `tmux-session-strategy` — Issue #65: tmux session strategy (2026-03-22) — **see #2 revisit in PR #157**
- `agent-start-task-tmux` — Issue #66 (2026-03-22)
- `local-orchestration-modes` — Issue #67 (2026-03-22)
- `port-ros2-436-behavioral-patterns` — roadmap entry in PR #157 (2026-04-19)
- `git-bug-fallback-warnings` — roadmap entry in PR #157 (2026-04-19)

## Ported/Adapted

- `worktree_list.sh --json` — adapted in PR #15 (2026-03-21)
- `gh_create_issue.sh` git-bug offline fallback — adapted in PR #15 (2026-03-21)
- `tests/` for scripts — in progress 2026-04-19 session (PRs #148, #152, #155)

## Pending roadmap add (after PR #157 merges)

- `per-session-context-card` — **To Consider** — CLI-first context card
  for rapid tab-switching refocus. Tmux status bar + `focus.md` header +
  `make focus`. Addresses same pain as ros2 dashboard, stays in terminal.
- `inline-comment-review-ui` — **To Consider** — Antigravity-style
  inline-comments-on-plan interface. Let user comment per-line on long
  agent responses, agent addresses each. Implementation space to be
  explored (dashboard render / TUI / static HTML). Parked pending design.

## Skipped (2026-04-26 decisions)

- `field-mode-literal-port` — ADR-0011 + `field_mode.sh` + `/import-field-changes`.
  Project repo origin is GitHub; no field deploy planned. Comment posted
  on agent_workspace #87 (Draft Zones) noting ADR-0011 as a structural
  template for the eventual draft-zones ADR.
- `field-mode-knowledge-doc` — `field_mode_hotfix.md` pairs with field
  mode → skipped together.
- `identity-script-revisions-#407` — already in place locally with
  rolker.net emails, Codex CLI listed, FALLBACKS-ONLY stance documented
  (per `feedback_model_detection.md`).
- `git-bug-in-devcontainer` — ros2-specific devcontainer; daddy_camp
  uses host install per ADR-0010.
- `--symlink-install-doc` — ROS colcon-specific; not applicable.
- `adr-0001/0002-status-line-addendums` — depends on ADR-0012 landing
  first; will be addressed as housekeeping after the bundled PR merges.
- `ros2-internal-issues` — #427/#429/#430/#431/#436/#444/#454/#452/#453
  domain-specific or upstream-internal.

## Skipped (2026-04-19 decisions)

- `secondary-remote-sync` — ros2 #422 `push_remote.py`/`pull_remote.py`.
  Backup via `git push origin <branch>`; Forgejo declined; no multi-repo
  manifest. Daddy_camp doesn't need it.
- `dashboard-phase1-re-port` — web-UI model doesn't fit CLI-centric
  workflow. Valid need (attention handoff) tracked as context-card concept.
- `root-dir-symlink-fix` — solved differently in our #146/#155.
- `ci_workflow.yml` — ROS-targeted template.
- `pre-commit-config.yaml` — ROS-targeted template.
- `copilot-instructions.md-adapter` — not needed for our setup.
- `dashboard-sh-enhancements` — subsumed by CLI-first rethink.
- `#250-presentation-slides` — domain (CCOM/JHC).
- `#417/#425-layer-bootstrap` — ROS domain.
- `#423-forgejo-bridge` — Forgejo declined (D6).
- `#435-deployment-debrief` — field-ops specific.

## Deferred

(none active — all prior deferrals have been resolved to ported/skipped
this round)
