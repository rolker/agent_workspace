# Inspiration Digest: gstack

Type: inspiration
Last checked: 2026-09-14
Repo: garrytan/gstack @ 71f6048e8ada25180e61438abc1d98cb151fe9a7
Previously checked: 2026-07-14 @ 7c9df1c; 2026-05-07 @ 443bde0; 2026-04-19 @ 22a4451; 2026-03-31 @ db35b8e

## Changelog (2026-07-14 → 2026-09-14)

62 commits, 300+ files (7c9df1c..71f6048; the compare API caps the file
list at 300). v1.58.5 → v1.84.1 in ~8 weeks. Cadence shifted from
per-feature releases to large squash-merged **waves** — "tracker waves"
(v1.64: 90 fixes, 52 issues closed, ~50 community PRs absorbed; v1.68:
90 stale PRs closed with receipts), "silent-failure waves" (v1.61, v1.69),
and two "GStack 2 fork port" waves (v1.63, v1.65) pulling audited work
back from a downstream fork. Free suite grew to ~9,200 tests. The
project's own framing for the period: *every guard that said it was
protecting you now provably does* — the recurring bug class was tools
reporting success while doing nothing.

### Host adapters as a typed factory (v1.64.1, v1.67.2, v1.69) — #172-relevant

`hosts/*.ts` (claude, codex, cursor, factory, gbrain, hermes, kiro,
openclaw, opencode, slate) collapsed from 595 hand-copied lines to 285
via a `defineHost()` factory: a host declares only what differs
(`name`, `displayName`, optional overrides); paths, frontmatter policy,
suppressed resolvers, runtime-asset lists and install strategy derive
from defaults. Proven byte-identical by a JSON dump-diff of all ten
configs + zero-diff regeneration. Five `HostConfig` fields nothing read
were deleted. `docs/ADDING_A_HOST.md` (182 lines) is the recipe. v1.69
added a **zero-dispatch guard**: a host that passes `--host` validation
without an install arm errors loudly, and a test pins accept-list ⊆
dispatch-arms against `hosts/index.ts`. v1.67.2 added
`HostConfig.defaultModel` + per-model overlays (`model-overlays/*.md`:
fable-5, opus-4-8, gpt-5.6-sol, gemini, …), rendered at `./setup` time
from the host's own config file — one template, host × model variants.

- **Workspace relevance**: High for #172. Our ADR-0011 adapter contract
  (`.agent/project_types/<type>/adapter.sh` + `validate_adapter.sh`) is
  the same shape at an earlier stage: two types today (single_project,
  ros2_colcon), each a full copy. The portable pieces: (1) defaults +
  override factory so a new project type declares only its deltas;
  (2) "registry accept-list ⊆ dispatch arms" as a test, not a convention;
  (3) an unread-field audit as part of the contract; (4) variants
  (role/distro in #172 terms) rendered from one source at setup time,
  keyed off a config file the project owns, rather than maintained as
  parallel copies.

### State-root discipline for multi-project machines (v1.68.0, v1.68.1, v1.80, #2728, #2858) — #172-relevant

A cluster of bugs, all from per-project state on a shared machine:
feature markers written into project-local checkouts (#2728 → moved
into gstack's own state root, with an upgrade migration); `/freeze`'s
hook reading a different state root than its writer whenever
`GSTACK_HOME` was set, so the boundary silently allowed everything
(v1.80 → one resolver, `bin/gstack-paths`, shared by hooks and
writers); one project's remote-brain registration reclassifying every
other project on the machine (v1.68.0); a stray `~/.git` misfiling
decisions into the wrong project store, fixed with a self-healing
canonical-slug cache (v1.68.0); slug cache poisoning via env leaks
(#2858, open). v1.68.1 made hook registration **canonical-only** —
setup never bakes a worktree's physical path into global settings, and
`prune-stale --repoint` heals dead entries left by deleted worktrees.

- **Workspace relevance**: High for #172's multi-tenant project
  registry. Design rules to carry in: one state-root resolver for
  readers and writers; per-project state keyed by a canonical slug with
  a self-heal path; never write machine/agent state into a project
  checkout; registration of project A must not alter classification of
  project B. The settings.json self-heal is Low for us — our hooks are
  registered by repo-relative path (`.claude/hooks/*.sh`), so deleted
  worktrees can't leave dead absolute entries.

### Ownership gate — never clobber a foreign skill (v1.80, v1.81, #2119)

`setup` writes a `.gstack-owned` marker into every skill directory it
creates and only deletes or links over an entry it can *prove* is its
own (symlink into gstack, marker, or a byte-identical/bannered generated
file). A generated file the user has customized is moved to a backup
before being linked over; foreign same-name skills are skipped and
named in the setup summary. v1.81 extended the same strong/weak proof
split to retired-skill pruning across every host install dir.

- **Workspace relevance**: Medium-High. Our workspace layers generated
  content onto a project checkout (`make generate-skills` writes
  `/make_*` slash commands; project worktrees get workspace files). #172
  per-project manifests widen that surface. A provenance marker +
  "prove ownership before overwrite, back up customized files, report
  foreign entries" rule is cheap and prevents the silent-clobber class.

### Spawned-session contract for subagents (v1.76, v1.78, v1.79)

`GSTACK_SESSION_KIND=spawned` marks a subagent per-command. In a
spawned session every ask-the-user gate auto-resolves to its
recommended option **except destructive ones**, which resolve to the
conservative choice and are recorded; auto-chosen gates come back to
the parent in a `decisions` array that is printed, so nothing is
decided invisibly. v1.78 fixed the abuse case: the v1.76 rule let the
model *infer* "nobody is watching" from any scripted-looking prompt and
plan reviews collapsed to zero questions — the trigger is now exactly
one machine-verifiable signal (the preamble's own echoed status line);
text from prompts, files or pages can never flip it. v1.79: Claude Code
2.1.198 made Agent-tool subagents background-by-default, stranding
/ship on a JSON handoff that never arrived; every synchronous dispatch
site now carries `run_in_background: false`, pinned per file by a
structural test (third recurrence of that bug class).

- **Workspace relevance**: High. This exact run is a spawned,
  non-interactive execution of an interactive skill. Extends the
  roadmapped `auq-fallback-and-auto-decide` item with the missing
  half: how a *dispatcher* declares spawned-ness, the destructive
  carve-out, the decisions-array return contract, and the lesson that
  the trigger must be a verified signal, never inferred from prose.
  The `run_in_background` pin applies to `/review-code`'s specialist
  dispatches.

### Tracker text as data — trust envelope (v1.66.1, v1.68.0, open #2818)

PR bodies, PR comments and model-judged issue titles enter agent
context only through `bin/gstack-issue-guard`: content is enveloped
even when clean, injection-shaped lines are labelled through
fullwidth/invisible-character evasion, forged envelope banners are
defused, and a CI scanner fails the suite on any raw tracker-text read
at all 8 ingress points. Write-backs keep a raw artifact so envelope
markup never reaches a live PR. v1.68.0 extended the untrusted-content
rules to `/scrape` and `/skillify`; open PR #2818 applies the same to
design docs and handoff notes read by plan reviews.

- **Workspace relevance**: High. `triage-reviews`, `review-issue`,
  `issue-triage`, `fetch_pr_reviews.sh` and `cross_model_review.sh` all
  read tracker text straight into context. The pattern (one ingress
  helper + a scanner that fails on bypass) is directly portable and
  complements the `project-codeguard` source's secure-by-default rules.

### Content-bound evidence: "tests passed" means *this* tree (v1.66.1, v1.69)

`bin/gstack-wtree` fingerprints working-tree content (~0.1s warm);
`bin/gstack-evidence run <cmd>` records a run bound to that
fingerprint + command hash + max-age, and `check` grades FRESH / STALE
/ MISSING. Review records stamp the fingerprint, so a review of
identical content grades CURRENT through rebases/amends/squashes and a
rebased-away commit grades UNKNOWN instead of erroring. /ship cites
fresh evidence instead of re-running and re-runs when anything moved.
v1.69 found the ledger certifying runs CI never performs because bun
auto-loaded `.env` into children — fixed with a value-equality scrub.

- **Workspace relevance**: Medium. New signal for the deferred JSONL
  review-tracking item (#51): staleness by *content* rather than by
  commit is the piece that was missing. Cheap to adopt in
  `merge_pr.sh`'s CI wait and review-code's "reviewed at SHA" note.

### Test-suite honesty tripwires (v1.64.0, v1.64.1, v1.66.0, v1.74, v1.77)

The free suite exited green after running ~4% of itself (a delayed
`process.exit(0)` in one file). Three CI eval jobs ran zero tests and
passed on every PR; four paid test files fell outside the run globs
forever; six merge-blocking gate "tests" existed only as map keys; the
fail-closed report's exit code was read from `tee` (always 0) because
the CI shell has no pipefail. Fixes each ship with a tripwire: strict
output contract (a shard without bun's summary line fails), reverse
invariants (every census key names a living test; every paid file is in
some lane), tier-alignment as a hard failure, "green-by-skip" census,
flake ledger + `eval:flake-rank`, sync-spawn timeout ratchet (499 → 0).

- **Workspace relevance**: Medium. Convergent with the roadmapped
  `fail-closed-hook-audit` and `test-coverage-catalog`. Concrete adds
  for us: every test/validation script is invoked by some Make/CI lane
  (a listing-vs-lane check), and exit codes survive pipes
  (`PIPESTATUS[0]` in any `| tee`). Recent PR #235 gated adapter suites
  in CI — the "is every suite actually gated" question is live.

### Context-budget ratchet (v1.63, v1.71) — enforcement for the carving item

`bin/gstack-context-bill` prints a token bill-of-materials for a skills
tree (always-on vs per-invocation, `--diff`, `--budget`);
`test/catalog-budget.test.ts` *enforces* an aggregate cap on frontmatter
name+description (every host loads the catalog every session);
`test/context-budget-ratchet.test.ts` pins per-skill eager tokens
against a committed fixture — growth fails, a reduction re-captures and
locks. v1.71 moved the shared preamble bash into two runtime scripts
and cut per-invocation cost ~50% across 62 skills, with an A/B eval
proving behavior parity before landing; repo CLAUDE.md trimmed 32%.

- **Workspace relevance**: Medium-High. This is the enforcement
  mechanism the roadmapped `skill-carving-token-reduction` item and
  ros2's #564 ("slim AGENTS.md via an enforcement-backed criterion")
  both lack: a committed size fixture + ratchet test. Fold in rather
  than track separately.

### Simplification lens, reuse ladder, shortcut debt ledger (v1.75)

/review gained an advisory eighth lens with a closed five-tag
vocabulary (`delete:` / `stdlib:` / `native:` / `speculative:` /
`shrink:`), excluded from the quality score, never auto-applied, and a
"lean already — nothing to cut" line on clean diffs. Every tier-2+ skill
gained a **reuse ladder** (repo helper → stdlib → native platform →
installed dependency → then build the complete remainder) and a bounded
closer. Accepted shortcuts leave a durable trail: a decision-ledger
entry plus a `gstack-shortcut(dec-<id>)` marker in code, harvested by
/retro; an orphan marker with no ledger id is reported as a forged
suppression. Also: a 1.8KB committed "instruction-tier digest" for
hosts that only read a rules file.

- **Workspace relevance**: Medium. Claude Code now ships `/simplify`
  natively, so the lens itself is covered; the portable bits are the
  reuse ladder (one paragraph for AGENTS.md / plan-task's
  search-before-building step) and the shortcut-debt marker ↔ ledger
  join, which gives "Deferred" decisions a code-side anchor.

### Fail-closed guard wave (v1.61, v1.64.0, v1.66.1) — signal for roadmapped item

More instances of the class the 2026-07-14 `fail-closed-hook-audit`
item was raised on: `/freeze` deny and `/careful` ask decisions were
emitted in a payload shape Claude Code ignores (deny meant allow);
`/freeze` silently no-op'd on quote/newline paths and passed edits
through when a helper file was missing; the AUQ preference hook
returned `permissionDecision:'defer'`, whose semantics changed in CC
2.1.89 and orphaned every question card. Fixes add a hard-deny tier to
`/careful` and an EXIT backstop that denies on any unexpected death.

- **Workspace relevance**: reinforces the existing roadmap item; no new
  item. Concrete test shapes to borrow: hostile-path fixtures, "helper
  missing" fixture, payload-shape pin against the host's current hook
  protocol.

### Gstack-domain (skip)

Aside AI browser as first driver (v1.72, v1.81); impeccable design
detector + open DESIGN.md (v1.84); Memorable recall bridge (v1.83);
egress-receipt ledger (v1.63 — hash-chained receipts before every
off-machine send; our off-machine surface is `gh`/`git`/model CLIs
only); redaction engine calibration waves (pre-commit covers our
never-commit-secrets rule); iOS QA / Apple release flow; gbrain sync
integrity, thin-client, XProtect self-heal; Windows lane; OSV lane;
browse daemon/tunnel/pairing security; supply-chain CI pins (v1.65 —
SHA-pinned actions, PR-diff secret scan; worth a glance when we touch
CI, but not a tracked item).

### Deferred-item signals (no status change)

- `claude-outside-voice-skill` — new signal: v1.78 #2735 relabels the
  same-family Claude fallback honestly ("not cross-model coverage");
  open PR #2850 routes outside reviews by harness; v1.84.1 defaults
  Codex/Claude voices to frontier models via env. Our
  `cross_model_review.sh` (Gemini via agy) should label any same-model
  fallback the same way if it has one. Stays deferred.
- `gbrain-federation-surface` — still churning (thin-client state,
  brain-sync spool, trust policy at the import chokepoint). Stays
  deferred.
- `deploy-pipeline-automation` — no change.
- `gstack-ux-behavioral-foundations` — v1.75 writing-style V1 + bounded
  closer are the latest iteration; still no felt skill-prose problem
  here. Stays deferred.

### Activity Snapshot (2026-09-14)

- 30 open issues sampled (heavily gstack-domain: Aside probe under zsh,
  Codex probe caching, browse daemon, Windows hooks). Notable for us:
  #2851 (generated preamble claims skill precedence over host
  restrictions — an instruction-hierarchy honesty bug), #2803 (review
  log stamps content-current on an unconverged review loop), #2776
  (hard-coded 300s Bash timeout kills the outside voice, silently
  replaced by same-model fallback).
- 30 open PRs sampled; relevant: #2818 (design docs / handoff notes as
  data, not instructions), #2819 (every plan approach states whether
  its phases are independently mergeable), #2861 (a new negative
  assertion is a decision, not coverage), #2813 (structured review gate
  reads a terminated run as a clean pass), #2814 (Bash gates above
  600000 ms silently lowered, inverting the wrapper invariant).
- 38 merged PRs since 2026-07-14; all consolidated into the wave
  releases above.

## Pending Review (2026-09-14 round)

Framing for this round: the lead is checking whether anything changes
the path of the workspace redesign (issue #172: project-type adapters,
multi-tenant project registry, per-project manifests, role/distro
variants). Items marked **#172** speak to that directly.

- `hosts-definehost-adapter-factory` **#172** — `defineHost()`
  defaults+overrides factory for host configs; byte-identical proof via
  dump-diff; accept-list ⊆ dispatch-arms pinned by test; unread-field
  audit; `docs/ADDING_A_HOST.md` recipe. Source: garrytan/gstack
  v1.64.1.0, v1.69.0.0 (#2361), `hosts/define-host.ts` (2026-09-14)
- `setup-time-variant-rendering` **#172** — host × model variants
  rendered from one template at setup, keyed off a config file the
  project owns (`HostConfig.defaultModel`, `model-overlays/*.md`,
  `./setup --host codex --model <id>`), not maintained as parallel
  copies. Source: garrytan/gstack v1.67.2.0 (#2633), v1.84.1.0 (2026-09-14)
- `state-root-discipline-multi-project` **#172** — one state-root
  resolver shared by hook readers and writers; per-project state keyed
  by canonical slug with self-heal; never write agent state into a
  project checkout; project A's registration can't reclassify project
  B. Source: garrytan/gstack v1.80.0.0 (#1459), v1.68.0.0, #2728/#2748,
  #2858 (2026-09-14)
- `ownership-gate-generated-files` **#172** — provenance marker on
  generated dirs; prove ownership before delete/overwrite; back up
  customized generated files; report foreign same-name entries.
  Applies to `make generate-skills` output and #172 per-project
  manifests. Source: garrytan/gstack v1.80.0.0 / v1.81.0.0 (#2119) (2026-09-14)
- `spawned-session-dispatch-contract` — `SESSION_KIND=spawned` marker
  set by the dispatcher; gates auto-resolve to the recommended option
  except destructive ones (conservative + recorded); `decisions` array
  returned and printed by the parent; trigger must be a verified signal,
  never inferred from prose; `run_in_background: false` pinned at every
  sync dispatch site. Extends roadmapped `auq-fallback-and-auto-decide`.
  Source: garrytan/gstack v1.76.0.0 (#2733), v1.78.0.0, v1.79.0.0
  (#497/#2440) (2026-09-14)
- `tracker-text-trust-envelope` — PR bodies/comments/issue titles enter
  context only through one ingress helper that envelopes and labels;
  scanner fails CI on raw reads; write-backs use a raw artifact. Targets
  `triage-reviews`, `review-issue`, `issue-triage`,
  `fetch_pr_reviews.sh`, `cross_model_review.sh`. Source: garrytan/gstack
  v1.66.1.0 (`lib/tracker-guard.ts`, `bin/gstack-issue-guard`), v1.68.0.0
  (#2441), open PR #2818 (2026-09-14)
- `content-bound-review-evidence` — working-tree content fingerprint
  binds "tests passed" / "reviewed" to content + command + max-age;
  staleness graded by content, not commit count. Revives deferred #51
  (JSONL review tracking) with the missing piece. Source:
  garrytan/gstack v1.66.1.0 (`bin/gstack-wtree`, `bin/gstack-evidence`),
  v1.69.0.0 (#2652) (2026-09-14)
- `test-lane-honesty-tripwires` — every test/validation script provably
  runs in some lane (listing-vs-lane reverse invariant); exit codes
  survive `| tee` (`PIPESTATUS[0]`); zero-test green jobs deleted;
  green-by-skip census. Extends roadmapped `test-coverage-catalog` and
  `fail-closed-hook-audit`. Source: garrytan/gstack v1.64.0.0,
  v1.66.0.0, v1.74.0.0, v1.77.0.0 (2026-09-14)
- `context-budget-ratchet` — committed size fixture + ratchet test
  (growth fails, reductions re-lock) for always-on instruction mass and
  per-skill eager tokens; token bill-of-materials tool. The enforcement
  half of roadmapped `skill-carving-token-reduction` / ros2 #564. Source:
  garrytan/gstack v1.63.0.0 (`gstack-context-bill`,
  `test/catalog-budget.test.ts`), v1.71.0.0 (#2691) (2026-09-14)
- `reuse-ladder-and-shortcut-debt-markers` — reuse ladder paragraph
  (repo → stdlib → native → installed dep → build the rest) for
  AGENTS.md / plan-task; accepted shortcuts leave a decision-ledger id +
  in-code marker harvested at retro, orphan markers flagged as forged
  suppression. Simplification lens itself is covered by native
  `/simplify`. Source: garrytan/gstack v1.75.0.0 (#2722) (2026-09-14)

## Changelog (2026-05-07 → 2026-07-14)

64 merged PRs, 300+ files (443bde0..7c9df1c). v1.28 → v1.58 in ~9 weeks.
Cadence has slowed from the ~1.5 releases/day peak but the project now runs
recurring "community bug waves" (Daegu: 23 bugs, windhoek: 9, plus external
audits) fed by its field-report pipeline — the friction-reporting system we
tracked in the initial survey, now operating at scale.

### Token reduction / skill carving (v1.46, v1.54, v1.56, v1.57.0)

The dominant portable theme. "gstack v2 foundation" cut skill-catalog
tokens 56% and put an eval-first floor under all 51 skills; /ship was
carved into a skeleton + on-demand sections (−59% always-loaded); a
"carve-guard" system protects the carved structure; more skills carved
since (cso, document-release, design-consultation). Open issues extend it:
#2214 (1839-line autoplan SKILL.md → router + `references/`), #2238 (audit:
~120 lines of boilerplate duplicated across 51/56 skills, over-prescriptive
STRICT recipes).

- **Workspace relevance**: High. Our skill bodies keep growing (this
  skill's own SKILL.md included), and ros2's open #564 (slim AGENTS.md via
  an enforcement-backed criterion) is the same concern arriving from the
  fork side — convergent evidence that always-loaded instruction mass is
  a real cost. The router + on-demand-references pattern is portable.

### AskUserQuestion reliability saga (v1.31 → v1.48 → v1.56 → v1.57.2 → v1.58.1)

A full arc worth recording: v1.31 **deleted** the AUQ prose fallback
("root cause of forever war" — the fallback let skills silently bypass the
tool); v1.48 added a question **split rule** + an explicit `AUTO_DECIDE`
carve-out (agent may self-decide only in a declared class of cases); v1.56
added a "paranoid safety net"; v1.57.2 **re-introduced** a prose fallback,
but only for genuine runtime tool failure; v1.58.1/#2206/#2207 deal with
host variants (Conductor) breaking native AUQ. Net lesson: gates must
fail loud, fallbacks get abused unless scoped to verified tool failure,
and self-decide needs an explicit contract.

- **Workspace relevance**: Medium. Complements the already-roadmapped
  AUQ cadence/Pros-Cons item and the plan-* STOP-gate item (both
  2026-05-07): this adds the fallback-abuse failure mode and the
  AUTO_DECIDE contract idea.

### Cross-session decision memory (v1.57.5) + brain-aware planning (v1.52.1)

Skills record decisions durably across sessions; 5 planning skills now
read structured memory context *before* asking the user anything ("don't
ask what the brain already knows").

- **Workspace relevance**: Medium. The ask-side rule is portable to our
  skills: consult memory/progress.md/ROADMAP before AskUserQuestion.
  Storage side is gbrain-domain.

### Review-loop refinements

- v1.57.7 — review report must **declare unresolved decisions** (nothing
  silently dropped between review rounds). Same concern as ros2's open
  #527 (surface deferred findings across rounds) — convergent.
- v1.57.10 — **Codex review default-on** across review/ship/plan/docs.
  Notable contrast: ros2 made Copilot Adversarial **opt-in** after
  measuring context cost, same month. The two forks of "external
  second-model review" pricing landed on opposite defaults.
- v1.39.1 — EXIT PLAN MODE GATE for plan-mode review skills.

- **Workspace relevance**: Medium for unresolved-decisions declaration
  (cheap addition to review-code/triage-reviews report formats);
  informational for the Codex-default contrast (feeds our own
  cross-model cost tuning).

### Safety guards failing open (v1.57.6)

A community bug wave found **4 security guards failing open** (guard
hooks that silently passed when their precondition machinery broke).
Fix wave + tests.

- **Workspace relevance**: Medium as a lesson: we have enforcement hooks
  (block-bash-tool-mapping, pre-commit) — worth an explicit fail-closed
  audit/test pass. Cheap, concrete.

### Gstack-domain (skip)

gbrowser stealth/anti-detection + headed-mode woes (#2242, #2219, #2220),
iOS device-farm (v1.43), persistent design-board daemon (v1.45), sidebar
keepalive (v1.44), PGLite/voyage-code-3 embeddings, split-engine gbrain
(v1.37) + sync hardening waves, submodule/factory-export packaging
(v1.34), Windows/CI hardening, /make-pdf emoji, redaction guard (v1.53 —
document-pipeline specific), /spec skill (v1.47 — our plan-task +
brainstorm cover this), translations, telemetry consent.

### Deferred-item signals (no status change)

- `claude-outside-voice-skill` — v1.57.10's Codex-default-on is new
  signal but our single-voice `cross_model_review.sh` friction hasn't
  changed. Stays deferred.
- `opus-4-7-migration-patterns` — likely obsolete as framed: the model
  landscape moved on (gstack #2238 flags their own hardcoded "Claude Opus
  4.7" trailer as a defect). Candidate to close next run.
- `gbrain-federation-surface` — still evolving fast upstream; still no
  concrete local failure case. Stays deferred.

## Pending Review (2026-07-14 round)

(none — all items triaged below)

## Roadmapped (2026-07-14 decisions)

All five 2026-07-14 findings added to ROADMAP.md "To Consider" under
"From gstack (2026-07-14)":

- `skill-carving-token-reduction` (2026-07-14)
- `auq-fallback-and-auto-decide` (2026-07-14)
- `consult-memory-before-asking` (2026-07-14)
- `unresolved-decisions-in-review-reports` (2026-07-14)
- `fail-closed-hook-audit` (2026-07-14)

## Survey Summary

gstack is an opinionated Claude Code skills framework that organizes AI-assisted
development into role-based slash commands (CEO, eng manager, designer, QA lead,
release engineer). 25+ skills, TypeScript/Bun-based, MIT license.

### Review & QA Workflow

- **/review**: Staff Engineer persona. Two-pass review (CRITICAL + INFORMATIONAL).
  Fix-First heuristic: AUTO-FIX mechanical issues, ASK for judgment calls. Includes
  scope drift detection, design-review-lite for frontend changes, Greptile comment
  triage, and optional Codex adversarial review.
- **/qa**: QA Lead + Bug-Fix Engineer. Opens real browser (Playwright), finds bugs,
  fixes with atomic commits, re-verifies with screenshots. Three tiers (quick/standard/
  exhaustive). Diff-aware mode auto-detects affected pages from branch changes.
  Auto-generates regression tests for every fix.
- **/qa-only**: Same methodology as /qa but report-only (never edits files).
- **/design-review**: Senior Product Designer. 11 phases from first impression
  through fix loop with before/after screenshots. AI slop detection. Design score
  + AI slop score baselines.
- **Review logs**: JSONL at `~/.gstack/projects/{slug}/{branch}-reviews.jsonl`.
  Each entry records skill, timestamp, status, findings count, commit SHA.
  Staleness detection compares stored SHA to HEAD.
- **Review Readiness Dashboard**: Built into /ship. Shows all review statuses,
  staleness indicators, and CLEARED/NOT CLEARED verdict. Eng review is required
  gate; CEO/design/codex are informational.

### Planning Methodology

- **/office-hours**: YC office hours partner. Two modes: Startup (interrogative,
  six hard questions exposing real vs hypothetical demand) and Builder (generative
  design partner). Produces versioned design docs. "Push twice on each answer" —
  first is polished, real answer comes 2-3 pushes in.
- **/plan-ceo-review**: CEO persona with 18 cognitive patterns. Four scope modes
  (expansion/selective/hold/reduction). Includes adversarial spec review loop via
  independent subagent scoring on 5 dimensions. Error Rescue Map forces explicit
  exception classes and rescue actions.
- **/plan-eng-review**: Senior eng manager with 15 cognitive patterns. Scope
  challenge (8+ files = red flag), architecture review with ASCII diagrams, test
  plan generation, performance review.
- **/plan-design-review**: Senior product designer. 7 review passes each rated
  0-10 and looped until 8+. AI slop detection. Responsive/accessibility checks.
  Edits plan in-place with missing design decisions.
- **Skill chaining**: office-hours -> plan-ceo-review -> plan-eng-review ->
  [build] -> review -> qa -> ship. Each reads outputs from previous skills.
- **Completeness principle ("Boil the Lake")**: AI compresses effort 10-100x,
  so prefer complete implementation over shortcuts when cost is minutes more.

### Release Engineering

- **/ship**: Fully automated release conductor. Merge base -> run tests -> pre-landing
  review -> Greptile triage -> Codex review -> version bump -> CHANGELOG -> cross-doc
  consistency -> TODOS cleanup -> commit & push -> PR creation. Smart versioning:
  auto-decides MICRO/PATCH, asks for MINOR/MAJOR. Multi-gate review readiness.
- **/document-release**: Post-ship documentation updater. Per-file audit of README,
  ARCHITECTURE, CONTRIBUTING, CLAUDE.md, CHANGELOG. Auto-updates factual corrections,
  asks about risky narrative changes.
- **/land-and-deploy**: Post-merge deployment. Auto-detects platform, runs canary
  verification. Offers revert at every failure point.
- **/canary**: Post-deploy monitoring loop. Screenshots, baseline comparison, anomaly alerts.
- **/benchmark**: Performance regression detection. Core Web Vitals, bundle sizes.

### Safety Controls

- **/careful**: PreToolUse hook on Bash. Warns before destructive commands (rm -rf,
  DROP TABLE, git push --force, etc.). User can override. Safe exceptions for
  build artifacts (node_modules, dist, etc.).
- **/freeze**: PreToolUse hook on Edit/Write. Blocks edits outside a specified
  directory. State file at `~/.gstack/freeze-dir.txt`. Returns "deny" not "ask".
- **/guard**: Combination of careful + freeze. Single command for maximum safety.
- **/unfreeze**: Clears freeze boundary.
- Three-tier hierarchy: Light (careful/warn) -> Medium (freeze/block edits) ->
  Heavy (guard/both).

### Agent Friction Reporting ("See Something, Say Something")

- **Contributor mode**: Opt-in via `gstack-config set gstack_contributor true`.
- **Mechanism**: At end of each major workflow step, agent rates experience 0-10.
  If not 10, files a field report to `~/.gstack/contributor-logs/{slug}.md`.
- **Report template**: Title, what tried, what happened, rating, repro steps,
  raw output, "what would make this a 10", date/version/skill metadata.
- **Constraints**: Max 3 reports per session, non-blocking, skip existing slugs.
- **Key innovation**: Agents self-report tooling friction with reproduction steps
  pre-written. Barrier to contribution is removed.

## Changelog Since Last Check (v0.9.9.0 - v0.11.6.0)

68 commits, 291 files changed.

- v0.10.0.0: /autoplan — auto-review pipeline
- v0.10.1.0: Test coverage catalog — shared audit across plan/ship/review
- v0.10.2.0: /retro global — cross-project AI coding retrospective
- v0.11.1.1: Plan files always show review status
- v0.11.2.0: Codex compatibility (1024-char cap, Kiro support)
- v0.11.3.0: Design outside voices — cross-model design critique
- v0.11.4.0: Codex second opinion in /office-hours
- v0.11.6.0: /cso v2 — infrastructure-first security audit
- v0.9.9.1: Cross-model outside voice in plan reviews

## Activity Snapshot

- 700+ issues, very active community
- Rapid versioning: v0.9.9.0 -> v0.11.6.0 in ~9 days
- Multi-model integration (Codex, cross-model critique) is a major theme

## Pending Review

(none)

## Issued

- `auto-scaled-adversarial-review` — Issue #47: adaptive review depth based on diff size (2026-03-22)
- `anti-sycophancy-patterns` — Issue #48: anti-sycophancy patterns for brainstorm/review skills (2026-03-22)
- `plan-file-review-report` — Issue #49: embed review status in work plan files (2026-03-22)
- `search-before-building` — Issue #50: search-before-building step in recommendation skills (2026-03-22)
- `review-log-system` — Issue #51: JSONL review tracking with staleness detection (2026-03-22)
- `fix-first-heuristic` — Issue #52: fix-first heuristic for review skills (2026-03-22)
- `diff-aware-qa` — Issue #53: diff-aware test targeting from branch changes (2026-03-22)
- `cognitive-patterns-for-review` — Issue #54: cognitive pattern lists for review personas (2026-03-22)
- `adversarial-spec-review` — Issue #55: adversarial spec review subagent for plan review (2026-03-22)
- `scope-mode-selection` — Issue #56: explicit scope modes for planning reviews (2026-03-22)
- `safety-hooks-careful-freeze` — Issue #57: PreToolUse safety hooks hierarchy (2026-03-22)
- `agent-friction-reporting` — Issue #58: agent friction self-reporting with field reports (2026-03-22)
- `completeness-principle` — Issue #59: completeness principle for AI-assisted development (2026-03-22)
- `skill-chaining-pipeline` — Issue #60: skill chaining pipeline with handoff context (2026-03-22)
- `design-review-ai-slop-detection` — Issue #61: AI slop detection in design review (2026-03-22)
- `gstack-inspiration-revisit` — Issue #19: revisit all 11 deferred gstack findings (2026-03-21)

## Roadmapped

- `cross-project-retrospective` — Cross-workspace retrospective analyzing friction patterns across repos, starting with fork sources (2026-03-31)
- `test-coverage-catalog` — Shared audit of test status across skills and scripts as dashboard layer (2026-03-31)
- `plan-stop-gates-floor-tests` (2026-05-07) — Added to ROADMAP.md "To Consider"
  under "From gstack (2026-05-07)". Anti-shortcut clause + AskUserQuestion
  floor tests for `/plan-task` and `/review-plan`. Source: gstack
  v1.21–v1.27 (#1255, #1296, #1313, #1354).
- `askuserquestion-cadence-prosconsformat` (2026-05-07) — Added to
  ROADMAP.md. Knowledge-doc entry on AskUserQuestion cadence + Pros/Cons
  format. Source: gstack v1.10.0.0 (#1178).
- `operational-learning-vs-layer5` (2026-05-07) — Added to ROADMAP.md
  as a research item. Clarify whether gstack's gbrain operational-learning
  pattern adds anything beyond our Layer 5 (#42 → #69) review architecture.
  Resolves prior `gstack-recursive-self-improvement` deferral. Source:
  gstack #647 + gbrain federation surface (v1.9–v1.27).

## Skipped

- `/autoplan` — Automated plan generation pipeline; already covered by workflow templates from #88 (2026-03-31)
- `gstack-multi-host-platform` — Declarative multi-host platform + OpenCode/Slate/Cursor/OpenClaw integration (#793, #816, #832). We're Claude Code–focused; multi-host targeting isn't our concern (2026-04-19)
- `gstack-browser-data-platform` — Browser data platform for AI agents (#907). Gstack domain, not ours (2026-04-19)
- `gstack-team-install-mode` — Team-friendly install mode (#809). Solo-user here (2026-04-19)
- `gstack-security-waves` — Security fix waves 1/3 (#810, #988). Gstack-specific vulnerabilities (2026-04-19)
- `gstack-design-html` — /design-html from any starting point (#734). Gstack domain (2026-04-19)
- `gstack-aquavoice-triggers` — Voice-friendly skill triggers for AquaVoice (v0.14.6.0). Gstack domain (2026-04-19)
- `gstack-cookie-picker` — Cookie picker auth token leak fix (#904). Gstack domain (2026-04-19)
- `gstack-plan-devex-review` — New /plan-devex-review persona (#784). Pattern interesting but not a current need; no analogue motivated in this workspace (2026-04-19)
- `gstack-relationship-closing` (2026-05-07) — Office-hours adapts to repeat
  users (#937). Auto-memory `user_workflow_patterns` + `user_agent_personality`
  already cover this at the memory layer; no skill-level adaptation needed.
  Closes the prior 2026-04-19 deferral.
- `opus-4-7-migration-patterns` (2026-07-14) — closed from Deferred: the
  model landscape moved past 4.7 (gstack #2238 flags their own hardcoded
  "Claude Opus 4.7" trailer as a defect). Model-migration friction, if it
  recurs, will be model-specific and re-triaged fresh.

## Deferred

- `deploy-pipeline-automation` — /land-and-deploy + /canary + /benchmark full
  deploy pipeline. Deferred 2026-03-22 and re-confirmed 2026-05-07; project
  is private/pre-distribution — no deploy story yet. Resurface when packaging
  becomes real.
- `cross-model-outside-voices` (2026-03-31) — Superseded 2026-05-07 by the
  `claude-outside-voice-skill` deferral below; tracked as one item now.
- `claude-outside-voice-skill` (2026-05-07) — gstack v1.13.0.0 #1212.
  Generalize `cross_model_review.sh` into a named-config outside-voice
  dispatcher. Existing single-voice script works for now; revisit when the
  single-voice limitation creates concrete friction.
- `gbrain-federation-surface` (2026-05-07) — gstack v1.9–v1.27. Cross-machine
  knowledge layer with per-skill manifests, transcript ingest, retrieval surface.
  Architecturally interesting but no clear failure case in our scattered-knowledge
  model. Revisit when concrete friction emerges.
- `gstack-ux-behavioral-foundations` (2026-05-07) — gstack #1000. Was on
  prior pending-roadmap list but didn't make PR #157 reshape. AGENTS.md
  Communication Standards already covers the spirit; resurface if skill-prose
  drift becomes a felt problem.

## Changelog (2026-03-31 → 2026-04-19)

55 commits, 300 files. v0.11.6.0 → v1.3.0.0+. Very active; ~30 versioned
releases in 19 days. Major themes:

### Session intelligence and context

- **v0.15.0.0 (#733)** — Session Intelligence Layer: /checkpoint + /health + context recovery
- **v1.0.1.0 (#1064)** — Renamed /checkpoint → /context-save + /context-restore
- **v0.18.1.0 (#1030)** — Context rot defense for /ship: subagent isolation, clean step numbering

### Review quality and reliability

- **v0.15.2.0 (#760)** — Adaptive gating + cross-review dedup for review army
- **v0.15.6.1 (#804)** — Anti-skip rule for all review skills (forces reviews to actually run)
- **v1.3.0.0 (#1040)** — Open agents learnings + cross-model benchmark skill

### UX for agent-user interactions

- **v0.17.0.0 (#1000)** — UX behavioral foundations + ux-audit command
- **v1.1.2.0 (#1065)** — Mode-posture energy fix for /plan-ceo-review and /office-hours: generic writing-style rules were flattening distinct mode personalities (expansion / forcing / wild) into diagnostic-pain framing. Fix uses paired examples + gate-tier tests so regression can't silently ship

### Permission prompt friction

- **v0.15.12.0 (#993)** — Avoid tilde-in-assignment to silence Claude Code permission prompts

### Multi-host platform (out of scope for us)

- **v0.15.5.0 (#793)** — Declarative multi-host + OpenCode, Slate, Cursor, OpenClaw
- **v0.15.9.0 (#816)** — OpenClaw integration v2: prompt is the bridge
- **v0.15.10.0 (#832)** — Native OpenClaw skills + ClaHub publishing
- **v0.18.0.0 (#1005)** — Confusion Protocol, Hermes + GBrain hosts, brain-first resolver

### New skills and roles

- **v0.15.3.0 (#784)** — /plan-devex-review + /devex-review
- **v0.16.0.0 (#907)** — Browser data platform for AI agents
- **v0.13.8.0 (#647)** — Recursive self-improvement: operational learning + full skill wiring

### Meta / release engineering

- **v1.0.0.0 (#1039)** — gstack v1: simpler prompts + real LOC receipts
- **v0.15.15.1 (#868)** — Pair-agent tunnel 15-second drop fix
- **v1.1.1.0 (#1063)** — Detect + repair VERSION/package.json drift in /ship

## Pending roadmap add disposition (post-#157 audit, 2026-05-07)

PR #157 merged 2026-04-19. Audit of which "pending roadmap add" items
landed in `docs/ROADMAP.md`:

- `gstack-session-intelligence-layer` (#733, #1064) → **landed** at
  ROADMAP.md row 174 ("Absorb" decision: `/focus` + `/context-save` +
  `/context-restore` integrated with progress.md / plan.md).
- `gstack-adaptive-gating-review-dedup` (#760) → **landed** at row 175
  (rolled into `/review-code` absorption alongside anti-skip and
  subagent isolation).
- `gstack-anti-skip-rule-for-reviews` (#804) → **landed** at row 175.
- `gstack-mode-posture-preservation` (#1065) → **landed** at row 192
  (planned audit of #56 + #71 for paired-examples bias).
- `gstack-ux-behavioral-foundations` (#1000) → **NOT landed.** Did not
  make it into the post-#157 ROADMAP.md. Re-triaged in 2026-05-07
  decisions below.

## Changelog Since Last Check (2026-04-19 → 2026-05-07)

35 commits, 300 files (22a4451..443bde0). v1.4.0.0 → v1.28.0.0 — ~24
versioned releases in 19 days. Continued rapid iteration.

### Major themes

**Plan-* skill reliability (high relevance for our /plan-task and /review-plan):**

- v1.21.1.0 #1255 — tighten plan-ceo-review smoke (Step 0 must fire)
- v1.25.1.0 #1296 — office-hours Phase 4 STOP gate + AskUserQuestion
  recommendation judge (LLM judges whether a recommendation actually
  appeared before allowing pass)
- v1.26.2.0 #1313 — plan-eng-review STOP gates always fire
  AskUserQuestion + report-at-bottom contract enforcement
- v1.27.1.0 #1354 — anti-shortcut clause + gate-tier AskUserQuestion
  floor tests for ALL plan-* skills (forcing-function pattern)

**AskUserQuestion mechanics:**

- v1.10.0.0 #1178 — AskUserQuestion cadence fix + Pros/Cons format upgrade
- v1.25.0.0 #1287 — AskUserQuestion resolves to host MCP variant when
  native is disallowed

**Outside voices / cross-model:**

- v1.13.0.0 #1212 — `/claude-outside-voice` skill (paired with prior
  Codex outside-voice). Resolves our deferred `cross-model-outside-voices`
  item from 2026-03-31.

**Opus 4.7 migration:**

- v1.5.2.0 #1117 — Opus 4.7 migration: model overlay, voice, routing
- v1.10.1.0 #1166 — overlay efficacy harness + Opus 4.7 fanout-nudge removal

**Gbrain federation surface (mostly gstack-domain):**

- v1.9.0.0 #1151 — gbrain-sync (cross-machine gstack memory)
- v1.12.0.0 #1183, v1.17.0.0 #1234 — /setup-gbrain coding-agent onboarding
- v1.20.0.0 #1233 — browser-skills runtime + gbrain-support carryover
- v1.26.0.0 #1298 — V1 transcript ingest + per-skill gbrain manifests +
  retrieval surface
- v1.26.3.0 #1314 — /sync-gbrain skill + native code-surface orchestrator
- v1.27.0.0 #1351 — /setup-gbrain Path 4 (remote MCP) + brain → artifacts rename

**Security (gstack-internal):**

- v1.4.0.0 #1089 — ML prompt-injection defense for sidebar
- v1.6.0.0 #1137 — tunnel dual-listener + SSRF + envelope + path wave
  (security)

**Cross-platform / packaging:**

- v1.24.0.0 #1252 — cross-platform hardening (curated Windows lane)
- v1.11.0.0 #1168 — workspace-aware version allocation in /ship
- v1.15.0.0 #1215 — slim preamble + real-PTY plan-mode E2E harness

**Misc:**

- v1.6.4.0 #1135 — Haiku classifier FP cut from 44% → 23%, gate enforced
- v1.6.3.0 #1149 — plan-reviews: RECOMMENDATION + Completeness split + Codex ELI10
- v1.4.0.0 #1086, v1.4.1.0 #1098 — `/make-pdf` markdown-to-PDF (out of scope)
- v1.16.0.0 #1253 — tunnel allowlist 17→26 (gstack runtime)
- v1.23.0.0 #1284 — always prefix PR titles with v\<VERSION>

### Activity Snapshot (2026-05-07)

- Open issues are heavily gstack-domain: gbrain ingest, /browse Chromium,
  host adapters (Cursor/Forge/Cowork), tunnel security
- ~30 open issues, ~10 open PRs sampled. Translation contributions appearing.
- Rapid versioning continues: v1.4 → v1.28 in 19 days

## Pending Review

(none — all 2026-05-07 items triaged below)

## Tightened interest_areas (2026-04-19)

Updated in registry same PR. Dropped "browser-based QA" and
de-emphasized release engineering; added "session and context management"
and "agent-user UX patterns". See inspiration_registry.yml for comments
explaining the change.
