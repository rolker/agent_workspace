# Inspiration Digest: ros2_agent_workspace

Type: fork
Last checked: 2026-04-19
Repo: rolker/ros2_agent_workspace @ 8465ebd838f8257fc5074c00fd0aa15c83516f3d
Previously checked: 2026-03-22 @ 54a2ef469eeaddc7aa30f11ff34078aa94836e74

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
