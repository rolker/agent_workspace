# Inspiration Digest: ros2_agent_workspace

Type: fork
Last checked: 2026-04-26
Repo: rolker/ros2_agent_workspace @ 395b1c5e26c82a7b032738adc0d4a03269e48035
Previously checked: 2026-04-19 @ 8465ebd838f8257fc5074c00fd0aa15c83516f3d

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
