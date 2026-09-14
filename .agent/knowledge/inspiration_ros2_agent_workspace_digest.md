# Inspiration Digest: ros2_agent_workspace

Type: fork
Last checked: 2026-09-14
Repo: rolker/ros2_agent_workspace @ 3b365a53bcdf47892f8b76425650ac40454d00bf
Previously checked: 2026-07-14 @ b64640f14f05799796164dd7fe07cd8b583541dc

## Changelog (2026-07-14 → 2026-09-14)

355 commits since the last check. Framing question for this round: does
anything upstream change the path of the #172 workspace redesign
(adapters, multi-tenant hosting, manifests, role/distro variants,
absorbing this fork)? Short answer: **no — it confirms it.** Three of the
largest upstream efforts this period are patches for problems the
registry + adapter model removes structurally, and one upstream change
(manifest fallback) converges on what #237 just landed here.

### Root/manifest resolution without `layers/` (#569 → open PR #625)

Upstream's janitor-sweep PR adds three resolution scripts —
`workspace_root.sh`, `manifest_fallback.sh`, `resolve_repo_checkout.sh`
(+ 32 tests) — because `layers/` and the `configs/manifest` symlink
exist only in the main checkout, so every skill run from a worktree,
fresh clone, or container had nothing to read. `manifest_fallback.sh`
shallow-clones the manifest repo from the tracked bootstrap pointer and
reads `bootstrap.yaml` (same four keys) to find the `.repos` files.

- **Workspace relevance**: **Confirms the redesign.** Here the hosting
  dir is an absolute registry path resolved by the adapter dispatcher,
  independent of which checkout the caller stands in, and `adapter
  setup` already bootstraps the manifest from the same pointer (#237).
  The one place we still have the upstream shape of the bug is the
  Makefile's worktree-root guess — filed as #239 this round; their
  `workspace_root.sh` rule (validated env var → script's own location →
  hop to the main checkout via `--git-common-dir`, gated on the
  destination being a workspace root) is the reference for the #239
  fix. Also relevant to **step 4 (manifests)**: both repos now consume
  the manifest independently of the layer tree, so moving it to a
  standalone / orphan-branch manifest (Pattern A) is viable on both
  sides.

### False-green sweep: sync/pull/validate (#609 → PR #611)

`make sync` reported success and exited 0 when repos failed to update.
Fixed with an outcome classification per repo (updated / skipped /
FAILED with cause), "no repos enumerated" is not all-clear, an
unreadable tree is FAILED not clean, and exit-code contract documented.

- **Workspace relevance**: **High — same bug exists here.** Our
  `ros2_colcon` `adapter_sync` prints `pull failed (continuing)` /
  `fetch failed (continuing)` to stderr and then `Sync complete.` with
  exit 0; `single_project` sync should be checked for the same shape.
  Quality Standard says silent failures are not nits. Direct fix
  candidate with tests in the existing adapter suites.

### Local-first quality gates (#572 umbrella; ADR-0018, ci_local.sh #573/#578)

A containerized local CI runner mirrors each repo's `ci.yml` from a
pristine `git archive HEAD` snapshot and writes an attestation (image,
packages, scope, log sha) to a git note at `refs/notes/ci-local`.
ADR-0018 accepts a full-scope attestation as merge verification for
project-repo PRs, hosted CI kept for environment diversity. Motivation:
2h21m hosted runs, field hosts with no GitHub credentials.

- **Workspace relevance**: Medium. The ROS container runner is domain,
  but the *shape* — a per-project-type "verify in a clean environment
  and attest" step that `merge_pr.sh` could accept instead of waiting
  on hosted CI — is an adapter-verb candidate (`ci` or `attest`) once
  a second project type needs it. Not now; note for the ADR-0011 verb
  list.

### Dispatch default flipped to in-process; what a container contains (#607 → ADR-0019)

Auto mode removed the prompt-cost argument for container dispatch. Six
review rounds on the launcher found the "sandbox" mounts the whole
workspace read-write, forwards Claude credentials, and withholds GitHub
write auth only by configuration. ADR-0019 names it: containers isolate
*machine state*; untrusted input is handled by the `--context-file`
data fence, orthogonal to mode.

- **Workspace relevance**: Low-Medium. We have no dispatcher (Tier-3
  deferred). Updates the reference design entry already on the roadmap:
  the container is not the containment story. Informational.

### `progress_append.sh` + ADR-0013 lifecycle plumbing (#594/#596/#592)

Prompt-free finish-phase processing, a plan-task "Documentation &
Instruction Impact" section with matching review-plan dimension and
review-code governance check, and repo-qualified re-orientation context
required in every run-issue `AskUserQuestion`.

- **Workspace relevance**: Medium. The doc-impact seam is a cheap port
  into our `plan-task` / `review-plan` (we already have a Consequences
  Map in the principles guide). Re-orientation context in questions is
  already user policy here (CLAUDE.md). ADR-0013 vocabulary stays
  deferred (tracked as #190).

### review-code: record lane for lifecycle-record diffs (#601, open)

Proposal: `.agent/work-plans/**` diffs (plans, progress, spike findings)
get one accuracy round and fast convergence; reference docs keep full
depth. Motivated by three Deep review rounds polishing citations on a
findings document whose verdict never moved.

- **Workspace relevance**: Medium. Same depth heuristic here (ported
  `review_depth_classification.md`); our progress-only PRs would hit
  the same loop. Candidate.

### ADR 'Provisional' status proposal (#620, open)

A third ADR status for decisions that are made and binding but whose
details are still being proven by implementation, so refinements don't
need a superseding ADR. Motivating case is a project-repo ADR.

- **Workspace relevance**: Medium. ADR-0011 (adapter contract) is in
  exactly that state — verbs are being proven project type by project
  type (#235/#237). Cheap governance port if #620 lands; watch.

### Worktree hazards (#598 open; #621 open; #618 open)

`worktree_create.sh` silently symlinks the real repo into the worktree
when `git worktree add` fails (stderr discarded), which let a dispatched
phase switch the main clone's branch. Relative paths resolve in the
wrong worktree when a compound command's `cd` is undone by a later
failure. `merge_pr.sh` cwd mode resolves a non-canonical worktree it
cannot clean up.

- **Workspace relevance**: #598 is a **phase 3 design constraint** for
  #172 step 6 (package-level worktrees for nested repos must hard-stop
  on `git worktree add` failure, never symlink a git repo). #621 is a
  knowledge note (this session hit the cwd-reset shape several times).
  #618 mirrors gaps our own `merge_pr.sh` may share; check when #191
  lands.

### Field / ROS / container domain (skipped)

#602/#604/#606 container volume ownership, #582–#584 sync throttle,
#577/#578 upstream.repos underlay deps, #612/#613 refs/bugs push +
git-bug staleness on the boat, #619/#622 import-field-changes and
push_remote layer defaults, #605/#585/#590 local Ollama adversarial
specialist (made opt-in), #623 file_clock gotcha, #617 layer-keyed
lookups knowledge, Gazebo research (#369).

### Open issues worth watching

- **#564** slim AGENTS.md via enforcement-backed criterion — still open,
  now sequenced before the janitor (#569). Same growth problem here.
- **#562** `merge_pr.sh --skill` — still open; this digest PR again
  needs manual worktree cleanup. Shared gap.
- **#569/#625** janitor sweep — report-only skill chaining
  audit-workspace / audit-project rotation / issue-triage / digest
  freshness into one timestamped local report; publish + trigger
  deferred. Their research digest sat 59 days past its nag. Ours has
  the same detectors and the same missing loop.

### Bidirectional note

Upstream's digest of *us* (checked 2026-07-14) records the #172 push and
their own #208/#209-equivalents porting field mode in reverse. Nothing
new to pull back; their next check of us will see #226/#232/#236/#238.

## Pending Review (2026-09-14 round)

- `adapter-sync-false-green` — our `adapter_sync` verbs report "Sync
  complete." exit 0 after per-repo failures; port #609's outcome
  classification + exit contract (2026-09-14)
- `janitor-sweep` — scheduled staleness/drift loop over our existing
  detectors; #569 shape, report-only first (2026-09-14)
- `doc-impact-seam` — plan-task "Documentation & Instruction Impact"
  section + review-plan dimension + review-code governance check (#596)
  (2026-09-14)
- `review-code-record-lane` — lighter lane for `.agent/work-plans/**`
  diffs (#601) (2026-09-14)
- `adr-provisional-status` — third ADR status for decided-but-proving
  decisions (#620); ADR-0011 is the local case (2026-09-14)
- `worktree-no-symlink-fallback` — constraint for #172 step 6 phase 3
  package worktrees (#598) (2026-09-14)
- `local-ci-attestation-verb` — adapter-verb candidate mirroring
  ADR-0018's attest-then-merge shape (2026-09-14)
- `merge-pr-skill-worktrees` — `merge_pr.sh --skill` (#562); shared gap
  (2026-09-14)

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

- **Workspace relevance**: High. The project repo gets Copilot PR
  reviews with zero instructions today. Template + ADR + skill wiring are
  all domain-neutral. Direct port candidate.

### Script tests in CI (#509 → PR #510)

`make test-scripts` runs `.agent/scripts/tests/` (shell via bash, python
via pytest) in a dedicated CI job. Tests are hermetic (temp git sandboxes,
stubbed `gh`, no network), so the job needs only git + pytest.

- **Workspace relevance**: High, cheap. We have 4 hermetic test scripts
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

- **Workspace relevance**: Split. ADR-0013 vocabulary + progress_read
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

- **Workspace relevance**: Medium. Same failure mode exists here when
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

- **Workspace relevance**: Medium. The convergence/ship-signal pattern
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

- **Workspace relevance**: Low (field-ops domain). The two lessons
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

(none — all items triaged below)

## Roadmapped (2026-07-14 decisions)

- `per-repo-agents-md` — added to ROADMAP.md "To Consider" (2026-07-14)
- `script-tests-ci-job` — added to ROADMAP.md "To Consider" (2026-07-14)
- `identity-ci-check` — added to ROADMAP.md "To Consider" (2026-07-14)
- `review-convergence-signal` — added to ROADMAP.md "To Consider" (2026-07-14)
- `dispatch-run-issue-reference` — added to ROADMAP.md "To Consider" as a
  reference design updating the agent-orchestrator Tier-3 stance, not a
  port candidate (2026-07-14)

## Ported/Adapted (2026-07-14)

- `gitignore-claude-locks` — `.claude/scheduled_tasks.lock` generalized to
  `.claude/*.lock` directly in this digest PR (trivial fix, no issue)
  (2026-07-14)

## Deferred (2026-07-14)

- `progress-entry-vocabulary` — ADR-0013 canonical entry types +
  progress_read.py. Revisit when our workflow-skill count grows enough
  for entry-name drift to bite (2026-07-14)

## Skipped (2026-07-14 decisions)

- `deployment-mode` — ADR-0014 + /start-deployment + /wrap-up-deployment +
  dlog.sh: field-ops domain (live boat deployments). Lessons noted in
  changelog (fabricated timestamps; prompt-free append helper).
- `ros-domain-2026-07` — ADR-0016 layer chaining, setup.bash O(N²) fix,
  rosdep bake, LD_LIBRARY_PATH shadowing, agent Docker image,
  verify_change.sh (colcon-specific).
- `merge-pr-root-fixes` — their #507/#508/#511 mirror problems we already
  solved (#146/#155, test_merge_pr_root_resolution.sh).
- `git-bug-per-repo-bridge-#476` / `ssh-agent-#502` — field/multi-repo
  workflow we don't have.

## Changelog (2026-04-19 → 2026-04-26)

53 commits, 28 files. Major themes:

### Field Mode (#445 → PR #448, ADR-0011)

Carve-out from "never edit files in the main tree" (ADR-0002) for repos
whose `origin` host is not on the GitHub allowlist (`github.com`,
`ssh.github.com`). Adds `.agent/scripts/field_mode.sh` (host-allowlist
detector), `.agent/scripts/tests/test_field_mode.sh`, and a hotfix
walkthrough at `.agent/knowledge/field_mode_hotfix.md`. AGENTS.md grew a
"Field Mode" section.

- **Workspace relevance**: Low. The project repo's origin is GitHub.
  No second remote planned. Skip unless we add a non-GitHub deploy target.

### ADR-0012 — Permit Cross-Reference Addendums in ADRs

Narrows ADR-0001's immutability rule to allow purely navigational
addendums: a Status-line note pointing at a later superseding/scoped
ADR, or a References section listing related ADRs. Substantive edits
still require superseding.

- **Workspace relevance**: Medium. We inherited `docs/decisions/` from
  ros2; the discoverability gap (older ADRs don't link forward to newer
  ones that scope them) applies to us too. Cheap port.

### `/import-field-changes` skill (#432 → PR #440)

Batch-imports remote-ahead commits from a secondary remote (gitcloud) back
to GitHub: per-repo issue creation, draft PR, and pre-review against the
Quality Standard. Depends on `pull_remote.py --json`.

- **Workspace relevance**: Low. Pairs with field-mode; same scope. Skip
  unless field deploys are added.

### AGENTS.md "Quality Standard" section (#437 → PR #438)

Adds a top-level Quality Standard with rules: fix bugs completely (test +
edge case + lifecycle), don't dismiss reviewer concerns about silent
failures or stale data as "nits", don't offer to "table this for later"
when the permanent solve is minutes away. Originally framed for "robot
boats on open water" but the substance is domain-neutral.

- **Workspace relevance**: High. Principles transfer to any public-release
  project. Direct port with framing adjusted.

### plan-task — "During implementation" guidance + `--no-pr` (#449 → PR #450)

Adds a sizable "During implementation" section: anti-"append-only
changelog" rule for plan files. Inline edits to the plan are the default
when implementation diverges; an `## Implementation Notes` section at the
bottom is allowed only for rationale-bearing design pivots whose *why*
isn't obvious from the diff. Also adds `--no-pr` flag for offline planning.

- **Workspace relevance**: High. Our `plan-task` skill is in active use;
  drift between plan and landed code is a recurring concern. Cheap port.

### triage-reviews — "Require justification for false positives" (#439 → PR #441)

Renames the dismissal table column from "Reasoning" to "Justification",
tightens example wording from "Why it's not applicable" to "Specific
reason the failure mode cannot occur". Forces dismissals to articulate
the absent failure mode, not vibes.

- **Workspace relevance**: Medium. Our local `triage-reviews` already
  has additional logic upstream lacks (Update progress.md step). Small
  additive port.

### Identity scripts (#407 → PR #443)

`set_git_identity_env.sh` and `framework_config.sh` revised so agents
self-report their model via the 3rd argument; the table now functions
as documented fallbacks only.

- **Workspace status**: Already in place. Local versions diverged to use
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

- **Already decided on workspace side**: roadmap #64 "Web dashboard" is
  `done`. No re-port planned (see "CLI-first architecture note" below).

### Git-bug v0.10.1 syntax fix (PR #419 closes #418)

Scripts were written for older v0.9 top-level commands (`git bug select/show`);
v0.10.1 nested them under `git bug bug`. Every call silently fell back to `gh`
for ~2 weeks before the regression was caught. Key lesson: **silent fallbacks
hide breakage.**

- **Workspace status**: we got the syntax right first try (our AGENTS.md +
  `_issue_helpers.sh` use `git bug bug ...`). Verified live 2026-04-19 —
  96 local issues cached, bridge configured.
- **Gap**: we don't warn on fallback. Captured in PR #157 roadmap as
  "Git-bug fallback warnings + smoke test" under Unphased.

### Secondary remote sync (#422) — push/pull to non-GitHub remote

Four new scripts (677 LOC): `add_remote.py`, `push_remote.py`, `pull_remote.py`,
`lib/remote_utils.py`. Forgejo-aware; supports pushing to gitcloud or similar
from field machines.

- **Workspace status**: **Skip.** Backup for us = `git push origin <branch>`;
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
  to #422 push/pull scripts. This workspace doesn't have that workflow need.
- **#435 — Deployment debrief skill** — field-ops specific (bag analysis
  with noise filtering). Skip.
- **#427, #429, #430, #431, #434** — ROS-domain or field-specific. Skip.

### Earlier items from 2026-03-22 digest — revisit

| Item | Prior status | New status (2026-04-19) |
|---|---|---|
| `dashboard-sh-enhancements` | deferred | **Skip** — ros2 moved to Python web dashboard; our CLI-first preference makes re-port a bad fit |
| `tests/` directory for scripts | deferred | **Ported/Adapted** — we started this session (test_cross_model_review, test_resolve_work_plans_dir, test_merge_pr_root_resolution) |
| `ci_workflow.yml` template | deferred | **Skip** — template targets ROS repos; the managed project isn't ROS |
| `pre-commit-config.yaml` template | deferred | **Skip** — same reason |
| `.github/copilot-instructions.md` adapter | deferred | **Skip** — we have Copilot review working via default behavior |

## CLI-first architecture note (2026-04-19 session)

A common thread through recent decisions: the ros2 workspace has chosen
a web dashboard + intermediated review UI direction. This workspace's
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
- `git-bug-in-devcontainer` — ros2-specific devcontainer; this workspace
  uses host install per ADR-0010.
- `--symlink-install-doc` — ROS colcon-specific; not applicable.
- `adr-0001/0002-status-line-addendums` — depends on ADR-0012 landing
  first; will be addressed as housekeeping after the bundled PR merges.
- `ros2-internal-issues` — #427/#429/#430/#431/#436/#444/#454/#452/#453
  domain-specific or upstream-internal.

## Skipped (2026-04-19 decisions)

- `secondary-remote-sync` — ros2 #422 `push_remote.py`/`pull_remote.py`.
  Backup via `git push origin <branch>`; Forgejo declined; no multi-repo
  manifest. This workspace doesn't need it.
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
