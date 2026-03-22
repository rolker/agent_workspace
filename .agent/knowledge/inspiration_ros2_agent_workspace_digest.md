# Inspiration Digest: ros2_agent_workspace

Type: fork
Last checked: 2026-03-22
Repo: rolker/ros2_agent_workspace @ 54a2ef469eeaddc7aa30f11ff34078aa94836e74

## Fork Comparison Summary

### Scripts (.agent/scripts/)
- **18 upstream-only**: build_report_generator.py, docker_run_agent.sh, get_repo_info.py,
  issue_request.sh, list_overlay_repos.py, push_gateway.sh, push_request.sh,
  read_feature_status.py, setup.bash, setup.sh, setup_layers.sh, sync_repos.py,
  test_identity_introspection.sh, tests/, validate_repos.py, verify_change.sh,
  PR_STATUS_README.md, README.md — *most are domain-specific (ROS/layer management)*
- **2 local-only**: setup_project.sh, sync_project.py
- **17 shared with differences**: agent, bootstrap.sh, build.sh, configure_git_identity.sh,
  dashboard.sh (+172 lines upstream), discover_governance.sh, framework_config.sh,
  gh_create_issue.sh, git_bug_setup.sh, lib/, pr_status.sh, test.sh,
  validate_workspace.py, worktree_create.sh, worktree_enter.sh, worktree_list.sh,
  worktree_remove.sh

### Skills, ADRs, Templates, Knowledge
- Upstream-only skills: document-package (domain-specific)
- Upstream-only ADRs: 0008 (ROS conventions, domain), 0010 (git-bug adoption — diverged)
- Upstream-only templates: ci_workflow.yml, package_documentation.md, pre-commit-config.yaml
- Upstream-only knowledge: 4 ROS-specific pattern docs (domain-specific)

### Makefile
- Upstream-only targets: agent-build, agent-run, agent-shell, push-gateway,
  setup-all, skip-bootstrap
- Local-only targets: setup

### Config
- AGENTS.md: upstream=297L (+74L for layer worktrees, Gemini adapter)
- ARCHITECTURE.md: upstream=256L (+125L for ROS layer details)

## Dashboard & Tmux Focus

### Web-Based Agent Dashboard (PR #402, Issue #400)
- +3498 lines, Python stdlib only (zero pip dependencies)
- ThreadingHTTPServer + SSE for real-time updates
- Tabbed sessions: Terminal + Plan + Context panels per session
- Session discovery: correlates worktree_list.sh --json with tmux list-panes
- File structure: .agent/tools/dashboard/ (routes/, services/, static/, tests/)
- REST API: /api/sessions, /api/terminal/:id, /api/context/:id, /api/plan/:id, /api/events (SSE)
- Terminal: capture-pane for read, send-keys for write
- Status detection: reads tmux pane output (working/waiting/done/error)

### tmux Session Strategy (Issue #403)
- Agent sessions: named (agent-issue-N), bidirectional, lifecycle tied to worktree
- App sessions: named (issue-N-label), read-only, via tmux_app.sh helper
- ADR planned but not yet written

### Local-First Orchestration Vision (Issue #385)
- Workflow modes: autonomous / collaborative / pair
- Permission profiles: task-scoped auto-approvals
- Docker sandbox option for fully autonomous agents
- Post-merge skill to automate cleanup ritual
- Git as coordination layer, not a custom message bus

## Activity Snapshot

- 20 open issues, 1 open PR (#402 — dashboard Phase 1)
- Key: #400 (dashboard), #398 (design), #403 (tmux ADR), #385 (orchestration),
  #395 (multi-specialist review), #407 (model self-reporting bug)

## Pending Review

(none)

## Issued

- `web-dashboard-phase1` — Issue #64: port web-based agent dashboard from upstream (2026-03-22)
- `tmux-session-strategy` — Issue #65: tmux session strategy for agents and applications (2026-03-22)
- `agent-start-task-tmux` — Issue #66: enhanced agent start-task with tmux session creation (2026-03-22)
- `local-orchestration-modes` — Issue #67: workflow modes autonomous/collaborative/pair (2026-03-22)

## Ported/Adapted

- `worktree_list.sh --json` — adapted in PR #15 (2026-03-21)
- `gh_create_issue.sh` git-bug offline fallback — adapted in PR #15 (2026-03-21)

## Skipped

(none)

## Deferred

- `dashboard-sh-enhancements` — Upstream dashboard.sh has +172 lines: additional tool checks, layer sync status. Non-domain portions may be portable. (2026-03-22)
- `tests/` directory for scripts — upstream has tests for generic scripts (2026-03-21)
- `ci_workflow.yml` template — CI workflow template for project repos (2026-03-21)
- `pre-commit-config.yaml` template — pre-commit config template for project repos (2026-03-21)
- `.github/copilot-instructions.md` — GitHub Copilot adapter file (2026-03-21)
