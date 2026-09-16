# Plan: Port the review loop from ros2_agent_workspace: progress entry vocabulary, convergence verdict, integrated triage, address-findings, merge gate

**Revision 6 (merge-record fallback → PR comment; pre-commit cost stated)** — revision 5's plan review left one must-fix: the cross-repo merge-record fallback file could never be committed (protected `main`, `no-commit-to-branch` hook); it is now posted as a comment on the merged PR. The `always_run` hook's per-commit cost and `SKIP=validate-script-tests` are stated. Applied directly by the host with the owner's approval (2026-09-16), no further review round.

**Revision 5 (CI wiring, B2/B3 split)** — revision 4's plan review
(`## Plan Review`, revision 4, in `progress.md`) found four must-fixes:
`test_checkpoint_269.sh` was never actually wired into anything that runs
it (a verifiable, not judgment-call, gap); nothing stopped a PR from
editing or deleting the checkpoint test itself; the two new durable-record
entry types (`## Merge (report-only)`, `## Merge (unreviewed)`) didn't say
which `progress.md` they target for project/package-scope PRs; and the
`PROGRESS_PERSISTENCE_STRICT` env-var carrier was justified by a claim
(`review-code` "not a CLI command with a stable flag surface") that
`review-code`'s own existing `--no-progress` flag contradicts. This
revision resolves all four: PR A now adds a `.pre-commit-config.yaml`
local hook running every `.agent/scripts/tests/test_*.sh` (including
`test_checkpoint_269.sh`) inside the existing Lint job, with no
`validate.yml` edit and measured runtime low enough to need no two-tier
split; the runner both globs and explicitly names
`test_checkpoint_269.sh` so its own deletion breaks the runner rather than
silently dropping coverage; the durable-record entries now resolve their
target `progress.md` the same way `merge_pr.sh`'s existing roadmap-update
step already resolves a PR's worktree, with a documented workspace-local
fallback when no worktree is open for it; and the switch is now both an
invocation flag (`--strict-progress`, mirroring `--no-progress`) and an
env-var default-setter, each named for the different job it does. B2 is
also split: it is now only the default flip (one line per skill, three
lines, one commit, cleanly revertible); deleting the compatibility path
and its tests is deferred to a new **B3**, opened only after B2 has been
in use. See the `## Plan Authored` entry appended for this revision for a
one-line-per-finding summary and where each landed, and "Blast radius"
below for the updated per-PR worst-case table. Revisions 2–4's own
findings remain applied; this revision layers on top of them, it does not
re-open them.

## Issue

https://github.com/rolker/agent_workspace/issues/269

## Context

PR #266 (issue #265) was reviewed by hand-emulating the fork's review loop:
fresh-context `review-code`, typed `progress.md` entries, an integrated
triage of Copilot + local findings, address-findings, and a round-2
re-review with a convergence verdict. Round 2 caught two round-1 fixes that
were incomplete and a "parity" test that exercised only one parser —
material defects Copilot plus a single fresh review had not caught.
Emulating the loop by hand costs three subagent runs and manual bookkeeping
per PR, and drifts (this workspace's `triage-reviews` still writes the
retired `## External Review` heading; see Non-migration and Evidence
below). The owner (2026-09-16) wants to read a decision summary, not the
diff, and keeps the merge decision — this port is what makes that summary
trustworthy and repeatable without hand-emulation.

The `review-issue` evaluation of #269 (posted to the issue) found the
8-item scope too large for one PR, a hidden dependency on a
`progress_read.py` port, and a real ADR-0004 gap (merge-gate enforcement
is a single, local-only layer as scoped). The owner's decision comment
(2026-09-16) adopted the split and added six binding adjustments,
folded into this plan:

1. One issue, a PR sequence (mirrors #265).
2. `progress_read.py` (or a minimal parser) is in scope.
3. Refactoring existing inline `git add`/commit call sites onto
   `progress_append.sh` is explicit scope.
4. #265 is a dependency for `progress.md` path resolution; the plan states
   how the timeline is located in both the pre-#265 and design-B layouts.
5. The merge gate is presented as two enforcement layers; the CI /
   branch-protection layer is Ask-First, not assumed.
6. Existing non-conformant `progress.md` files are declared explicitly
   non-migrated.

A second owner decision, same day (2026-09-16), accepted four blast-radius
containment measures after reviewing revision 2 — folded below as
decisions, not options:

1. **Merge gate ships report-only first.** PR F's Layer 1 prints what it
   would have refused and why, never blocks, until a `--enforce` flag is
   passed; the flip to enforce-by-default is a separate, later one-line
   PR after the owner has watched the report on several merges.
2. **Gate scoped to workspace PRs at first.** For project PRs, Layer 1
   only ever prints the report line — never refuses, report-only or
   enforced — until #265 PRs 2–4 settle where project timelines live.
3. **Checkpoint after PRs A and B.** The sequence pauses after B; A+B are
   exercised on PR 2 of #265 (a real project-affecting workspace PR)
   before C–F start.
4. **Degradation test for no-issue / skill-worktree cases.** The move to
   the fail-loud `resolve_work_plans_dir()` in `review-code`/
   `triage-reviews` must keep skill worktrees and no-issue branches
   degrading with a clear "Progress persistence skipped (<reason>)"
   message, never an abort mid-review.

See "Blast radius" below for what the port does not touch and how each
of the three risk points the owner discussed is contained.

## PR sequence

Six independently mergeable PRs, in order. Later PRs build on earlier
ones; nothing here needs #265's remaining PRs 2–4 to merge first (see
"#265 dependency and progress.md path resolution" below), so this
sequence can start immediately.

**Checkpoint after PR B (owner's containment measure 3, mechanically
enforced from revision 4):** the sequence pauses once PR B merges. Before
PR C starts, A+B are exercised on PR 2 of #265 (a real project-affecting
workspace PR) — see "Checkpoint after PR B" under Estimated Scope for
what "exercised" means concretely, and "New vocabulary: `## Checkpoint`
and `## Merge (report-only)`" under PR A for the entry type and the CI
check (`test_checkpoint_269.sh`) that refuses to let any PR touching a
C–F file merge until that entry exists on `main`. This is no longer
discipline-only: revision 3's plan review found the checkpoint unenforced
and PR B's own live exposure ungated by it; both gaps are closed below
(PR B ships its persistence-path change behind a switch defaulting to
today's behavior, and the checkpoint's existence is a mechanical
precondition, not a note someone might forget to write).

### PR A — ADR + `progress_append.sh` + `progress_read.py`

**Lands**: new ADR (vocabulary: `## Issue Review`, `## Plan Authored`,
`## Plan Review`, `## Local Review`, `## Local Review (Pre-Push)`,
`## Integrated Review`, `## External Review` as recognized predecessor,
`## Implementation`, `## Merge (unreviewed)` — added for PR F's
`--force-unreviewed` audit record, not present in the fork's own
ADR-0013 (this workspace's Layer-1 gate is new work, not a port; see PR
F), `## Merge (report-only)` — added in revision 4 for every report-only
gate refusal, not just the bypass case (see PR F), and `## Checkpoint` —
added in revision 4 as the durable, machine-checkable record that the
owner's containment measure 3 (checkpoint after PR B) has been exercised
(see "New vocabulary: `## Checkpoint` and `## Merge (report-only)`"
below); header schema with offset-bearing `**When**`;
correlation-key table; checkbox findings schema), citing fork ADR-0013 as
source. `.agent/scripts/progress_append.sh` (append + commit in one
prompt-free step, writable-type whitelist, identity fail-loud, idempotency
guard). `.agent/scripts/progress_read.py` (JSON parse of entries,
`--type` filter, correlation-key extraction, fence-aware parsing,
predecessor recognition for `## External Review`).
`.agent/scripts/tests/test_checkpoint_269.sh` (new, revision 4) — the
mechanical enforcement for the checkpoint; see below.
`.agent/scripts/tests/run_script_tests.sh` (new, revision 5) — the runner
that gives the checkpoint test (and the seven pre-existing `test_*.sh`
scripts that had no CI wiring at all) something that actually executes
them; see "Checkpoint enforcement" below. A new `.pre-commit-config.yaml`
local hook invokes it.

**New vocabulary: `## Checkpoint` and `## Merge (report-only)` (revision
4, resolving must-fix 2 and must-fix 3 of revision 3's plan review)**:

- **`## Checkpoint`** — written once, by the owner (the host who ran the
  #265 PR 2 exercise, not by any script — this is a human attestation
  that the three observations happened, same "human writes it" pattern
  as every other entry in this file), to
  `.agent/work-plans/issue-269/progress.md`. Required fields:
  `**PR**` (the #265 PR 2 number), `**Review entry SHA**` (the
  correlation SHA of the `## Local Review (Pre-Push)` entry
  `progress_append.sh` wrote during the exercise), `**Resolver-hit**`
  (one line confirming `resolve_work_plans_dir()` — run with
  `--strict-progress` for this one exercise, see PR B below —
  resolved correctly from #265 PR 2's real project worktree, quoting its
  output), and `**Decision summary URL**` (the PR comment URL where the
  pinned decision-summary template appeared). This is the same three
  observations Estimated Scope's "Checkpoint after PR B" already
  describes; revision 4 adds the required-fields schema and a consumer
  that checks for it (below) instead of leaving the record informal.
- **`## Merge (report-only)`** — written by `merge_pr.sh` itself (via
  `progress_append.sh`, same helper the `## Merge (unreviewed)` bypass
  entry uses) every time a report-only run (no `--enforce`) evaluates
  Layer 1 and at least one condition fails. Fields: which condition(s)
  failed, the PR head SHA. See PR F for why this closes must-fix 3 (the
  report-only observation window previously left no durable record of
  its own stated purpose).

**Checkpoint enforcement — CI wiring (revision 5, resolving revision 4's
must-fix 1: "picked up by the existing test harness" was false)**:

Revision 4 claimed `test_checkpoint_269.sh` would be "picked up by the
existing test harness the same way every other PR's new `test_*.sh` file
is." Verified false against this tree: `.github/workflows/validate.yml`
calls out exactly **three** of this repo's **ten** existing
`.agent/scripts/tests/test_*.sh` files by explicit, individually-named
`run:` steps — `test_adapter.sh`, `test_project_registry.sh`,
`test_ros2_colcon.sh` (`validate.yml:38,41,44`). The other seven —
`test_merge_pr.sh`, `test_merge_pr_root_resolution.sh`,
`test_resolve_work_plans_dir.sh`, `test_gh_create_pr.sh`,
`test_block_bash_tool_mapping.sh`, `test_cross_model_review.sh`,
`test_sync_gitbug.sh` — are not referenced anywhere in `validate.yml`,
`.pre-commit-config.yaml`, or the Makefile. There is no auto-discovery
loop anywhere in `.agent/scripts/` that globs `test_*.sh` and runs it;
`make test` dispatches to the project adapter's `TEST_CMD`, not this
workspace's own test scripts. Dropping `test_checkpoint_269.sh` into
`.agent/scripts/tests/` as revision 4 designed it would have gotten it
exactly nothing running it in CI.

**Decision**: PR A adds a `.pre-commit-config.yaml` local hook —
`validate-script-tests`, `always_run: true`, `pass_filenames: false` —
that runs a new runner, `.agent/scripts/tests/run_script_tests.sh`,
executing **every** `test_*.sh` in `.agent/scripts/tests/`. Because the
hook is `always_run`, its ~18 s cost lands on **every** commit in every
worktree regardless of the diff (revision 6, from the revision-5 review);
that is accepted for the enforcement it buys, and
`SKIP=validate-script-tests git commit …` is the sanctioned escape for
work-in-progress commits — the same `SKIP=` mechanism this repo's CI
already uses for other local hooks. The runner's own output states the
elapsed time so drift above ~30 s is noticed. This hook runs
inside the existing `Lint (pre-commit)` job (`validate.yml:10-25`, `run:
make lint`) exactly the way `validate-adapter-contract`
(`.pre-commit-config.yaml:50-55`) already does — no `validate.yml` edit at
all. This closes the wider gap the plan review's evidence exposed (seven
of ten existing suites never ran in CI; the roadmap already lists "Run
`.agent/scripts/tests/` in CI" as a To Consider item, tracing to the
fork's #509/#510), and it carries `test_checkpoint_269.sh` along with it
as one more suite the runner executes — the checkpoint gate is a
consequence of fixing the wider gap, not a special case bolted on. The
false "picked up automatically" sentence above is corrected by this
section, not carried forward.

**Runtime cost, measured**: each of the ten existing `test_*.sh` scripts
was timed with `time bash .agent/scripts/tests/test_*.sh` in this
worktree (all passing, `rc=0`):

| Script | Seconds |
|---|---|
| `test_adapter.sh` | 1.18 |
| `test_block_bash_tool_mapping.sh` | 1.27 |
| `test_cross_model_review.sh` | 0.38 |
| `test_gh_create_pr.sh` | 0.32 |
| `test_merge_pr_root_resolution.sh` | 0.05 |
| `test_merge_pr.sh` | 2.74 |
| `test_project_registry.sh` | 3.22 |
| `test_resolve_work_plans_dir.sh` | 0.05 |
| `test_ros2_colcon.sh` | 7.65 |
| `test_sync_gitbug.sh` | 0.17 |
| **Total** | **~17.0s** |

~17 seconds is not too slow for a pre-commit hook (this repo's existing
`Lint (pre-commit)` job already runs `black`/`flake8`/`pylint`/`shellcheck`
across the tree in the same job). **No two-tier split is needed**: every
`test_*.sh`, including `test_checkpoint_269.sh` and the new
`test_run_script_tests.sh` (below), runs in the single pre-commit hook,
with no CI-only Makefile target and no `validate.yml` change. Per the
instruction that made this a hard requirement regardless of runtime:
`test_checkpoint_269.sh` is one of the fast suites (0.05–7.65s range, well
under a "too slow for pre-commit" threshold), so this holds even under the
stricter reading.

**Protecting the checkpoint test from edit/deletion (revision 5, resolving
revision 4's must-fix 2 — nothing stopped a PR from routing around the
gate by editing or deleting it)**: defense in depth, stated plainly as
that and not as proof:

1. `run_script_tests.sh` globs `.agent/scripts/tests/test_*.sh` for
   general coverage (any new suite is picked up automatically) **and**
   separately asserts, by explicit filename, that
   `test_checkpoint_269.sh` is present in that glob result and was
   executed. If the file is deleted, the runner itself fails — the
   check doesn't just silently lose one suite's coverage, the whole
   pre-commit hook goes red, which is a much louder signal than a
   glob quietly running one fewer script.
2. `test_checkpoint_269.sh` itself asserts its own filename appears (by
   exact string) in `run_script_tests.sh`'s explicit checkpoint-presence
   assertion — a PR that edits the runner to drop the explicit check
   (leaving only the glob) fails the checkpoint test's own self-check.
3. A CODEOWNERS-free social rule, since this workspace has no file-level
   review-gating mechanism: any PR touching `run_script_tests.sh` or
   `test_checkpoint_269.sh` must say so plainly in its decision summary
   (see PR B's pinned template), and the reviewer (human or fresh-context
   `review-code`) checks that claim against the diff.

None of these three are proof against a determined or careless PR — (1)
and (2) are both ordinary repo files a PR could still edit together in
one diff, and (3) is discipline, not mechanism. This is exactly the same
honest limit PR F's own Layer 1 reasons through for the merge gate
itself: pre-Layer-2, human review is the actual backstop for any
self-referential gate in this repo, and this section says that plainly
rather than implying the runner+self-check pair is unbreakable.

Because B2 (below) touches `triage-reviews/SKILL.md` and
`plan-task/SKILL.md` to flip `PROGRESS_PERSISTENCE_STRICT`'s default, B2
is still gated by `test_checkpoint_269.sh` with no special-casing — that
part of revision 4's design is unchanged, only how the test actually runs
is corrected. **What removes the check**: nothing needs to — once the
`## Checkpoint` entry is committed to `main`, the check is permanently
satisfied for every later PR (it checks for the entry's existence, not
currency). PR F's cleanup step deletes `test_checkpoint_269.sh` (and its
explicit mention in `run_script_tests.sh`) once F merges, since its one
job (gating C–F/B2 until the checkpoint is recorded) is then complete;
`run_script_tests.sh` itself stays, continuing to run the other nine (by
then possibly more) suites.

Adaptations from fork source:
- Both scripts are read as-is from
  `~/project11/.agent/scripts/{progress_append.sh,progress_read.py}` —
  they're generic over `.agent/work-plans/issue-<N>/`, no fork-specific
  paths. The only changes are the entry-type whitelist comment
  cross-reference (points at this workspace's new ADR number, not
  fork ADR-0013) and dropping any fork-only `run-issue`/orchestrator
  references from comments.
- `progress_append.sh`'s `-C <dir>` targets a worktree directly; it does
  not resolve `.agent/work-plans/issue-<N>/progress.md` through the
  design-B `resolve_work_plans_dir` helper. PR A ships it as-is (the
  fork has no design-B equivalent); callers in PR B–F pass `-C` as
  `$WORK_PLANS_DIR`'s containing worktree, resolved by the caller.

**Tests**: `progress_append.sh` — writable-type rejection, idempotent
re-append-after-failed-commit, identity fail-loud when unset, commits
only the one file. `progress_read.py` — one hermetic fixture per entry
type, fence-aware parsing (a `## Foo` heading inside a fenced block does
not produce a phantom entry), predecessor-recognition filter
(`--type "Integrated Review"` also returns `## External Review`),
offset-missing `when_has_offset: false` case. `test_checkpoint_269.sh`
(revision 4) — a synthetic PR diff touching each gated file (one case
per file named above) fails against a fixture `progress.md` with no
`## Checkpoint` entry, and passes against a fixture with a complete one;
a fixture with a `## Checkpoint` entry missing one required field still
fails, asserting the check reads fields, not just heading presence.
`.agent/scripts/tests/test_run_script_tests.sh` (new, revision 5) —
asserts the runner (a) discovers and runs a synthetic `test_*.sh` fixture
dropped into a scratch copy of the tests dir (glob coverage), (b) fails
loudly when `test_checkpoint_269.sh` is absent from that scratch copy
(explicit-presence assertion), and (c) exits non-zero as soon as any one
suite fails, without silently continuing past it.

**Enforcement**: mechanical (test suite, plus the new pre-commit hook
that actually runs the suite — see "Checkpoint enforcement" above); the
whitelist is itself the enforcement for "only ADR-0013-vocabulary types
get committed."

### PR B — `review-code`: `progress_append.sh` refactor + convergence + decision summary

**Lands**: (a) refactors this workspace's existing step-8 inline
`git add && git commit` (already present, already writing
`## Local Review` / `## Local Review (Pre-Push)` with ADR-0013-conformant
headings — see Evidence) onto `progress_append.sh`; (a2) replaces the ad
hoc "owning repo's worktree, else current worktree, else create" prose
(`review-code/SKILL.md:504-506`) with a sourced
`resolve_work_plans_dir()` call from `.agent/scripts/_resolve_work_plans_dir.sh`
— see "#265 dependency and progress.md path resolution" above; this is
the consequence of the `progress_append.sh` refactor, done in the same PR
rather than left to drift; (b) adds the convergence assessment
(Round = prior `## Local Review (Pre-Push)` entries for this branch + 1;
Ship: recommended with no must-fix, or at round ≥ 2 with ≤ 2 mechanical
non-rising must-fixes; continue otherwise), surfaced in the report header
(`**Round**`, `**Ship**`) and the `progress.md` entry; (c) the
decision-summary report shape using the single pinned
"Decision-summary template" below, as an additional top-of-report
section, alongside — not replacing — the existing findings tables.

**Behind a switch, defaulting to today's behavior (revision 4, resolving
must-fix 1 of revision 3's plan review — "PR B does not actually contain
PR B")**: (a) and (a2) above are the risky part of this PR — a daily-use
skill's fail-loud resolver call and its swap onto `progress_append.sh`
(whose identity check itself fail-loud-aborts when git identity is
unset, a new abort path this workspace's existing inline `git add &&
git commit` never had). Revision 3's checkpoint paused *starting PR C*
on this being exercised first, but did nothing to stop PR B's own
change from going live workspace-wide the moment PR B merges — every
other in-flight PR's `review-code` invocation hits the new code
immediately, before the #265 PR 2 exercise even runs. PR B closes that
gap by shipping (a)/(a2) behind an environment variable,
`PROGRESS_PERSISTENCE_STRICT` (default unset, treated as `0`), read at
the top of step 8:
- **`0` (default — what PR B ships with)**: step 8 keeps today's ad hoc
  resolution prose and today's inline `git add && git commit`, exactly
  as before PR B. It additionally evaluates (does not act on)
  `resolve_work_plans_dir()`'s own abort condition against the current
  worktree/branch, and if that check would have aborted, prints one line
  to the report — `"Progress persistence notice: would have aborted
  (resolve_work_plans_dir: <reason>) — running in compatibility mode
  (PROGRESS_PERSISTENCE_STRICT=0)"` — then proceeds with the old path
  regardless. The convergence fields and decision-summary section (b)/(c)
  still land in the entry via the old commit mechanism; only the
  resolution/commit *mechanism* is switched, not the entry content.
- **`1`**: step 8 uses `resolve_work_plans_dir()` and `progress_append.sh`
  for real — this is the code path B2 (below) makes the default.
- **Carrier (revision 5, correcting revision 4's must-fix 4): both a
  skill flag and an env var, each doing a different job.** Revision 4
  justified the env-var-only design with "`review-code` is invoked as a
  skill..., not a CLI command with a stable flag surface..., so a flag
  can't be threaded through invocation the way PR F's `--enforce` can" —
  that claim is false against this tree: `review-code/SKILL.md` already
  has exactly such a flag today, `--no-progress`
  (`review-code/SKILL.md:15,20,108,110,117,392,498`), documented in the
  skill's own invocation line (`/review-code --branch [<base-ref>]
  [--issue <N>] [--no-progress] [--skip-static] [light|standard|deep]`).
  A flag can and does thread through this exact skill's invocation. The
  premise is dropped; the design is corrected to carry the switch two
  ways, matched to two different needs:
  - **`--strict-progress`** (a skill flag, consistent with the existing
    `--no-progress` naming and placement in the invocation line) — an
    agent invoking `/review-code --strict-progress` for a single run
    forces the strict path (`resolve_work_plans_dir()` +
    `progress_append.sh`) for that run only, regardless of the ambient
    default. This is what the #265 PR 2 checkpoint exercise uses instead
    of an out-of-band `export` (see PR A's `## Checkpoint` entry's
    `**Resolver-hit**` field): the flag is discoverable from the
    invocation line itself, the same way `--no-progress` already is,
    so nothing has to separately tell the invoking agent to set an
    environment variable it has no reason to know about.
  - **`PROGRESS_PERSISTENCE_STRICT`** (an env var, unchanged from
    revision 4) — remains the mechanism because B2 needs to flip a
    *default* across every ordinary invocation, and a flag cannot do
    that without editing every call site's invocation text; the env var
    is what the skill's step-6/step-8 logic reads to decide which path
    to take when `--strict-progress` is not passed, and it is this env
    var's default (unset/`0` pre-B2, `1` post-B2) that B2's one-line
    change actually flips. In short: `--strict-progress` is a per-run
    override for the one-off exercise case; `PROGRESS_PERSISTENCE_STRICT`
    is the ambient default B2 flips for every other invocation. Both are
    documented in the skill's invocation line and step-6/step-8 logic so
    neither is a hidden mechanism.
- PR C reuses the same switch for the identical risk in `triage-reviews`
  (see PR C below); PR E reuses it for `plan-task`'s persistence swap
  specifically (see PR E below) — `review-plan`'s change is a new
  capability, not a swap of an existing mechanism, so it doesn't need the
  switch (see PR E for why its failure mode is instead made non-fatal).

**Decision-summary template** (the one concrete shape PR B and PR F both
produce/consume — referenced, not re-described, by PR F's PR-template
section and its Layer-1 comment check):

```markdown
## Decision summary

**What changed**: <1-3 sentences, plain language, no diff references>

**Reviews and outcomes**: <round/ship verdict if review-code; findings
count and verdict if triage-reviews/integrated review>

**Open human calls**: <anything requiring a human decision, or "None">

**Verified**: <what was actually run/checked to confirm the above, e.g.
"tests pass; grep confirmed X">

**Recommendation**: <merge / needs-work / hold, one line>
```

**Dropped, documented as absent**: Ollama `local_review.sh` / the
`--local` specialist (workspace has no local-model serving story; would
need its own issue if wanted), the Copilot-CLI `--copilot` specialist and
its untrusted-PR gate (workspace has no `copilot` CLI integration
today — separate scope), and the container dispatcher
(`dispatch_subagent.sh --mode container`) — this workspace has no
container-mode orchestrator; `review-code` stays a directly-invoked skill,
not something a `run-issue`-style host dispatches.

**Evaluate while porting**:
- Convergence (#537 in the fork) — cited in fork ADR/SKILL text as the
  origin of the round/ship logic; UNVERIFIED beyond that citation (no
  access to fork's own issue tracker from this repo to confirm outcome
  metrics; taken on the fork SKILL.md's own account).
- `progress_append.sh` adoption (#594) — same: cited in the fork
  SKILL.md, not independently re-verified here.
- What changes here: the entry heading is already correct in this
  workspace (unlike `triage-reviews`, which needs a rename — see PR C);
  this PR's real work is the convergence math and decision-summary shape,
  plus the mechanical swap to `progress_append.sh`.

**Tests**: convergence round-counting against a fixture `progress.md`
with 0/1/2 prior `## Local Review (Pre-Push)` entries; ship-verdict cases
(no must-fix → recommended; round 2, 2 mechanical must-fixes → recommended;
round 1, 3 must-fixes → continue); a `resolve_work_plans_dir()` unification
test asserting the step aborts (non-zero, remediation message) rather than
silently falling back to the current worktree when `WORKTREE_ISSUE` is set
but mismatched, or is unset and neither the worktree path nor the branch
encodes an issue number, and cwd is outside the owning worktree — this
case is run under `PROGRESS_PERSISTENCE_STRICT=1` (the mode the abort
path is reachable in). **Switch tests (revision 4)**: with
`PROGRESS_PERSISTENCE_STRICT` unset, the same mismatched-worktree fixture
completes (no abort), the entry is committed via the old inline
mechanism, and the report contains the "would have aborted" notice line;
with it set to `1`, the same fixture aborts as described above. A third
case asserts a *matching*-worktree fixture under `0` produces no notice
line (the compatibility-mode check doesn't false-positive when there is
nothing to warn about).

**Degradation test (owner's containment measure 4)**: `resolve_work_plans_dir()`
requires an issue number as input, so the call site in `review-code`'s
step 8 must decide, before calling it, whether an issue is resolvable at
all. Two hermetic cases, neither aborting: (a) a skill-worktree branch
(`skill/{name}-{timestamp}`, no `WORKTREE_ISSUE`, no
`feature/issue-<N>`-shaped branch) — `review-code` detects no issue
number is derivable, skips the `resolve_work_plans_dir()` call entirely,
and prints "Progress persistence skipped (no linked issue — skill
worktree)" to its report, then completes the review with no
`progress.md` write; (b) an ordinary branch with no linked issue (not a
`feature/issue-<N>` shape, `WORKTREE_ISSUE` unset) — same detection,
same skip, message reads "Progress persistence skipped (no linked
issue)". Both are distinct from the existing mismatched-worktree case
above, which still aborts (fail-loud, per issue #147) because an issue
number *is* resolvable there, just the wrong worktree. `--no-progress`
(if passed) short-circuits to the same skip path without needing the
detection step.

**Enforcement**: mechanical (round-counting test, switch-mode tests);
decision-summary shape is prose guidance (Suggestion-tier per the
guidance-doc calibration this workspace already applies), no new
mechanical check.

### PR C — `triage-reviews`: `## Integrated Review`

**Lands**: renames the write target from `## External Review` to
`## Integrated Review` (the current, non-transitional ADR-0013 name —
this workspace never went through the fork's phase-A/phase-B split, so
there is no transitional period to model); reads prior
`## Local Review` / `## Local Review (Pre-Push)` entries via
`progress_read.py --type` filters instead of only GitHub-side reviews;
adds the cross-source-confirmation table (same correlation-key-at-head-SHA
rule as the fork); refactors its existing inline commit onto
`progress_append.sh`; replaces its own copy of the ad hoc
"owning repo's worktree, else current worktree, else create" prose
(`triage-reviews/SKILL.md:197-199`) with a sourced
`resolve_work_plans_dir()` call, same as PR B does for `review-code` — see
"#265 dependency and progress.md path resolution" above.

**Behind the same switch as PR B (revision 4)**: `triage-reviews`'s
resolver call and `progress_append.sh` swap carry the identical risk PR
B's must-fix 1 resolution describes (daily-use skill, new fail-loud
abort path) — they're gated by the same `PROGRESS_PERSISTENCE_STRICT`
env var, checked at the top of `triage-reviews`'s commit step: `0`
(default) keeps today's ad hoc resolution and inline commit, with the
same "would have aborted" notice line when `resolve_work_plans_dir()`
would have refused; `1` uses the new mechanism for real. This is why
Blast radius's per-PR table (below) can give PR C the same worst case as
PR B instead of "breaks a daily-use skill."

**Dropped**: none — this item is a rename + integration, not new
capability the fork gates behind other absent infrastructure.

**Evaluate while porting**: the fork's own ADR-0013 records `## External
Review` as a *predecessor* it once wrote and retired (#470 phase B,
#485/#486) — this workspace instead goes straight to `## Integrated
Review` for new writes, since it never had a phase-A period to
transition from. `## External Review` is read-only-predecessor from day
one here (see Non-migration).

**Tests**: a fixture `progress.md` with one `## Local Review` and one
GitHub Copilot finding at the same head SHA asserts the pair surfaces as
a single cross-source-confirmed row, not two; the same
`resolve_work_plans_dir()` silent-fallback-is-gone test as PR B, run
against `triage-reviews`'s resolution step under
`PROGRESS_PERSISTENCE_STRICT=1`; the same degradation test as PR B
(owner's containment measure 4) — skill-worktree branch and
no-linked-issue branch both skip the resolver call and print "Progress
persistence skipped (<reason>)" rather than aborting or writing into the
wrong worktree — run against `triage-reviews`'s own call site
(`triage-reviews/SKILL.md:197-199`), since PR C changes that call site
independently of PR B's; the same switch-mode tests as PR B (default `0`
completes with the old commit mechanism and a "would have aborted"
notice, `1` aborts for real, a matching-worktree fixture under `0`
produces no notice).

**Enforcement**: mechanical (fixture test, switch-mode tests); no
whitelist gate on `triage-reviews`'s own write (it always writes the one
type).

### PR D — `address-findings` (new skill)

**Lands**: ported largely as-is from
`~/project11/.claude/skills/address-findings/SKILL.md` — reads the latest
`## Integrated Review` or `## Local Review (Pre-Push)` entry via
`progress_read.py`, works each unchecked finding (fix-and-check or
defer-and-check-with-reason), commits atomically, writes
`## Implementation` via `progress_append.sh`.

**Dropped**: the `#492`-flagged disambiguation note about a future
`run-issue` orchestrator needing to tell an `implement`-skill
`## Implementation` apart from an `address-findings` `## Implementation`
by what precedes it — no orchestrator exists here, so this is dropped as
inapplicable (there is no automatic router to disambiguate for). The
dispatcher invocation line (`dispatch_subagent.sh --mode ...`) is dropped;
this workspace's lifecycle skills hand off by printing the next command
for a human or the calling session to run, not via a subagent dispatcher.

**Evaluate while porting**: no fork issue/PR citation available for this
skill specifically beyond the SKILL.md's own framing (#481 phase C) —
UNVERIFIED as an outcome claim; the port is taken on the shape of the
skill, not a track record.

**Tests**: a fixture progress.md with 2 unchecked findings (1 must-fix, 1
suggestion) exercises fix-and-check and defer-and-check paths, and asserts
the resulting `## Implementation` entry's `**Addressed**` field points at
the source entry.

**Enforcement**: mechanical (fixture test) for the entry-shape contract;
"never fake resolution" (every checkbox real or deferred-with-reason)
stays instructions-only, same as the fork.

### PR E — `plan-task` / `review-plan` entry headings

**Lands**: `plan-task` step 6 writes `## Plan Authored` (not the current
`## Plan`), with the `**Plan**: \`<path>\` at \`<plan-commit-sha>\`` field
(the plan-commit SHA — the commit that last touched `plan.md` — not the
PR head); refactors its existing `resolve_work_plans_dir()`-based append
onto `progress_append.sh` (a heading/field change, not a new mechanism —
`plan-task` already has an append step). `review-plan` writes
`## Plan Review` (not the current `## Plan Review: PR #<N> — <title>` as
a heading — the title moves into the entry body, the heading becomes the
plain ADR-0013 type) with the same `**Plan**:` correlation field — **and**,
corrected from this plan's earlier draft (see "#265 dependency and
progress.md path resolution" above), *adds* `review-plan`'s first
automated progress.md append step: today `review-plan/SKILL.md` ends at
"Produce the report" (step 5) with no commit mechanism at all (verified:
no `resolve_work_plans_dir` call, no `git add`/`commit`, no
`progress_append.sh` reference anywhere in the file); the `## Plan Review`
entries in this file and in `issue-265/progress.md` were appended by
hand. PR E gives `review-plan` a new step 6 that sources
`resolve_work_plans_dir()` and calls `progress_append.sh`, bringing it in
line with `plan-task`, `review-code`, and `triage-reviews`.

**Behind the same switch as PR B/C, `plan-task` only (revision 4)**:
`plan-task` already has an append step today (unlike `review-plan`), so
its `progress_append.sh` swap carries the same new-abort-path risk as PR
B/C in a third daily-use skill (every issue starts with `plan-task`).
Gated by the same `PROGRESS_PERSISTENCE_STRICT` env var at `plan-task`'s
step 6: `0` (default) keeps `plan-task`'s current commit mechanism with
the same "would have aborted" notice when applicable; `1` switches to
`progress_append.sh` for real. `review-plan`'s new step 6 does *not* use
this switch — it isn't replacing an existing mechanism, so there's
nothing to preserve compatibility with. Instead its failure mode is made
non-fatal: if `resolve_work_plans_dir()` or `progress_append.sh` fails,
`review-plan` prints "Progress persistence failed: <reason> — the report
above is unaffected" and exits 0 (the report, step 5's actual product,
has already been produced by the time step 6 runs) rather than turning a
successful review into a failed skill invocation. This keeps PR E's
worst case at "notice printed," not "blocks a daily-use skill," for both
halves of the PR — see Blast radius below.

**Dropped**: none.

**Evaluate while porting**: this workspace's #265 timeline
(`.agent/work-plans/issue-265/progress.md`, evidence below) shows both
skills already run and already produce useful entries under the old
headings (`## Plan`, `## Plan review`). For `plan-task` this PR is a
rename + correlation-field addition, not new capability. For
`review-plan` it is larger than a rename: today's entries under
`## Plan review` were written by hand outside the documented flow, so
this PR both renames the heading and adds the first automated append
step that makes future entries land without manual intervention. No fork
issue/PR citation beyond ADR-0013 itself (the plan-commit-SHA
distinction, "not the PR head, not the file's blob SHA," is ADR-0013's
own text, ported verbatim as the schema requirement).

**Tests**: `plan-task`/`review-plan` fixture entries parsed by
`progress_read.py --type "Plan Authored" --type "Plan Review"` and their
`correlation.sha` asserted against the plan-commit SHA of a synthetic
two-commit fixture repo (one commit touches `plan.md`, a second touches
something else — the correlation must key off the first, not HEAD). The
same switch-mode tests as PR B/C, run against `plan-task`'s step 6.
`review-plan`'s new step 6 non-fatal path: a fixture where
`resolve_work_plans_dir()` fails asserts the skill still exits 0 with the
report intact and the "Progress persistence failed" notice present, and
a second fixture where it succeeds asserts the `## Plan Review` entry is
written with the correlation field.

**Enforcement**: mechanical (correlation-parsing test, switch-mode
tests, non-fatal-path test).

### PR F — merge gate (local + Ask-First CI decision) + PR template

**Verified premise** (full-file grep of `.agent/scripts/merge_pr.sh`, 766
lines, for `confirm`/`read -p`/`MERGE`/`WARNING`): there is **no**
interactive "type MERGE to confirm" banner in this repo's `merge_pr.sh`.
The script has no `read -p` prompt anywhere. Today's actual human gate is
narrower and weaker than the plan's prior draft claimed: it is simply the
human's decision to run `make merge-pr PR=<N>` (or `merge_pr.sh`
directly) in the first place — there is no in-script confirmation step
between invocation and the merge call. Once invoked, the script proceeds
through Step 1 (roadmap update), Step 2 (`gh pr checks --watch
--fail-fast`, `merge_pr.sh:512`), and Step 3 (`gh pr merge ... --merge`,
`merge_pr.sh:540-547`) without pausing for confirmation.

**Lands**:
- **Layer 1 (this repo's scope, done in this PR), report-only by default
  (owner's containment measure 1)**: `merge_pr.sh` gains a new pre-merge
  check — a "Step 2.5" inserted after the existing `# --- Step 2: Wait
  for CI ---` block ends (`merge_pr.sh:538`) and before
  `# --- Step 3: Merge ---` begins (`merge_pr.sh:540`), i.e. immediately
  before the `gh pr merge` call at `merge_pr.sh:544`. It reads the
  target PR's linked issue `progress.md` via `progress_read.py --type
  "Local Review" --type "Integrated Review"` and evaluates **both** of
  issue #269's original two conditions — restored here after the plan
  review flagged their earlier silent drop:
  (a) the latest `## Local Review` / `## Integrated Review` entry's
  correlation SHA matches the PR head SHA and its status is not
  `changes-requested`-equivalent (i.e., `**Verdict**: approved` for
  `## Local Review`, or an `## Integrated Review` with no unchecked
  must-fix findings); **and**
  (b) a PR comment containing the decision-summary marker — the fixed
  `## Decision summary` heading the PR template provides (see the
  pinned template in PR B, "Decision-summary template" below) — exists
  on the PR, checked via `gh pr view <N> --json comments --jq
  '.comments[].body' | grep -qF "## Decision summary"` (`gh pr view
  --comments` alone prints comments but doesn't give a greppable exit
  code cleanly, hence `--json comments`).

  **Default mode (no `--enforce`): report-only.** If either (a) or (b)
  is missing, the script prints exactly what it would have refused and
  why — naming which condition(s) failed — and proceeds to Step 3
  anyway; it never blocks a merge in this PR's shipped default. This
  mirrors the fork's own `janitor-sweep` precedent (report-only,
  publish-nothing, on its first slice — confirmed by reading
  `~/project11/.claude/skills/janitor-sweep/SKILL.md`: "Report-only —
  opens no PRs, files no issues, and publishes nothing"): land the
  detector, let the owner watch its output on real merges, flip to
  enforcement only once its signal is trusted.

  **Durable record for every report-only refusal (revision 4, resolving
  must-fix 3 of revision 3's plan review)**: a stdout line is only ever
  seen synchronously by whoever ran `make merge-pr`, which undercuts
  report-only mode's own stated purpose — letting the owner review its
  output *retrospectively* across several merges before flipping
  `--enforce`. So every report-only run where (a) or (b) is missing also
  appends a `## Merge (report-only)` entry to the target issue's
  `progress.md` via `progress_append.sh` — same helper, same file, as
  the `--force-unreviewed` bypass's `## Merge (unreviewed)` entry below
  — recording which condition(s) failed and the PR head SHA. A
  report-only run where both conditions pass appends nothing (nothing to
  observe). This makes the observation window something the owner can
  review after the fact across every workspace PR, not just the one
  terminal it happened to run in.

  **Target `progress.md` for project/package-scope PRs (revision 5,
  resolving revision 4's must-fix 3b)**: revision 4 said "every
  report-only run... appends" without saying which `progress.md` that is
  for a PR whose issue lives outside the workspace worktree — the exact
  case PR F's own refusal-scoping (containment measure 2) already flags
  as unresolved ("project-repo `progress.md` location is not yet stable,"
  see above). This is resolved by reusing `merge_pr.sh`'s own existing
  worktree-resolution pattern rather than inventing a new one: Step 1
  (roadmap update) already resolves the worktree that has `$PR_BRANCH`
  checked out via `find_worktree_for_branch()` (`merge_pr.sh:176`,
  called at `merge_pr.sh:457`), choosing `_WT_REPO="$ROOT_DIR"` for
  `$WORKTREE_TYPE == "workspace"` or `"$ROOT_DIR/project"` for
  `"project"` (`merge_pr.sh:455-456`), and for package PRs the script has
  already resolved `$PKG_WT_DIR` earlier in the same run
  (`merge_pr.sh:389-436`, the qualified `owner/repo#N` /
  `--repo owner/repo` handling) if a package worktree happens to be open.
  Step 2.5's durable-record append reuses exactly this: resolve the PR's
  worktree via `find_worktree_for_branch()` (workspace/project) or
  `$PKG_WT_DIR` (package), and if found, append to that worktree's
  `.agent/work-plans/issue-<N>/progress.md` — the issue's own timeline,
  in the repo that owns it, precisely as Step 1 already does for the
  roadmap update. **When that timeline is unreachable from the host** —
  `find_worktree_for_branch()` returns empty and `$PKG_WT_DIR` is unset,
  meaning no local worktree is open for the PR's repo — the record is
  **not written to any file** (revision 6: the workspace's main tree sits
  on protected `main`, and this repo's `no-commit-to-branch` hook plus
  branch protection make a commit there impossible; the earlier
  `.agent/work-plans/merges/` fallback could never have been committed).
  Instead the same entry text is **posted as a comment on the merged PR**
  via `gh pr comment <N> -R <owner/repo>` — the PR is already the durable
  artifact for that merge, the script is already authenticated to it, and
  nothing needs a commit. The stdout report line names the fallback when
  it's taken (e.g. "no open worktree for `rolker/some-project` — merge
  record posted as a comment on rolker/some-project#42"), so a report-only
  observer never has to guess where the record is. Tests in PR F stub
  `gh` and assert the comment body carries the same fields as the
  timeline entry.
  This is consistent with the refusal-scoping section immediately above:
  refusal itself stays scoped to `$WORKTREE_TYPE == "workspace"` only,
  but the durable *record* of a report-only pass/fail is written for
  every scope (workspace, project, package) using this resolve-or-fallback
  rule, so the observation window PR F exists to serve isn't silently
  empty for project/package PRs.

  **`--enforce` mode**: the same two-condition check, but on failure the
  script refuses to proceed (exit non-zero, explicit message naming
  which condition(s) failed, no merge attempted). A CLI flag was chosen
  over a `.agent/project_config.sh` config switch or a `make` variable
  because (i) `merge_pr.sh` already parses several behavior-changing CLI
  flags this way (`--type`, `--no-wait`, `--no-roadmap-update`), so
  `--enforce` is consistent with the script's existing interface rather
  than a new configuration surface; (ii) `project_config.sh` is
  gitignored and per-developer (see "Build & Test" in AGENTS.md) — a
  switch there would not give the owner one shared, reviewable point of
  truth for when enforcement turned on across the team; (iii) the later
  flip to enforce-by-default is then a literal one-line diff (the
  default value the flag parser assigns `ENFORCE_MERGE_GATE`), visible
  and reviewable in its own PR, rather than a docs/config change that
  could drift from the code. **The flip to enforce-by-default is a
  separate, later one-line PR, opened only after the owner has watched
  the report-only output on several real merges — not part of this PR
  sequence.**

  **Invocation path (revision 4 suggestion 1, re-verified against this
  worktree)**: `--enforce` and `--force-unreviewed` reach `merge_pr.sh`
  via `make merge-pr PR=<N> MERGE_PR_ARGS=--enforce` — confirmed at
  `Makefile:132-134` (the `merge-pr:` target passes `$(MERGE_PR_ARGS)`
  through verbatim to `.agent/scripts/merge_pr.sh`; the target's own
  usage line at `Makefile:133` already documents
  `[MERGE_PR_ARGS=...]`). The one gap: the `make help` utilities listing
  at `Makefile:70` documents `make merge-pr PR=<N|owner/repo#N>
  [REPO=owner/repo]` but omits `MERGE_PR_ARGS`, so the flag isn't
  rediscoverable from `make help` alone. PR F updates `Makefile:70`'s
  help text to add `[MERGE_PR_ARGS=--enforce|--force-unreviewed]`.

  **Gate scoped to workspace PRs at first (owner's containment measure
  2).** By the time Step 2.5 runs, `merge_pr.sh` has already set
  `$WORKTREE_TYPE` to `"workspace"`, `"project"`, or `""` (the empty
  case is a package-repo PR resolved via `--repo owner/repo#N` or a
  qualified `--pr owner/repo#N`, which sets `REPO_KIND="package"` and
  clears `WORKTREE_TYPE` at `merge_pr.sh:296-297`) — this is the exact
  detection the script already has; Step 2.5 reads it, it does not add
  a new one. Step 2.5's refusal path (the `--enforce`-mode block above)
  only ever fires when `$WORKTREE_TYPE == "workspace"`. For `"project"`
  or `""` (project PRs via `--type project`, project auto-detection, or
  any package-worktree/qualified-repo PR), Step 2.5 **always** stays in
  report-only mode — it prints the same "would have refused because..."
  line but never refuses, regardless of `--enforce` — until #265 PRs
  2–4 settle where project timelines live (see "#265 dependency and
  progress.md path resolution" below: project-repo `progress.md`
  location is not yet stable, so a project-PR refusal could be reading
  a soon-to-move path). Widening enforcement to project PRs is a later,
  separate PR once #265 PRs 2–4 land, not part of this sequence.

  **Both modes, all scopes**: `--force-unreviewed` bypasses both
  conditions together (not selectively) with a loud warning banner
  printed to stdout/stderr, following the same `echo "⚠️  ..."` idiom the
  script already uses elsewhere for non-fatal warnings (e.g.
  `merge_pr.sh:498, 501, 618`) — this is a new banner for a new check,
  not a pre-existing confirmation gate; the plan no longer claims one
  exists. `--force-unreviewed` is meaningful even in report-only mode
  (it still suppresses the "would have refused" print and instead prints
  the bypass banner) so its behavior doesn't silently change the day
  `--enforce` becomes default. The bypass also appends a
  `## Merge (unreviewed)` entry to the target issue's `progress.md` via
  `progress_append.sh` (see "Estimated Scope" above for why this, not a
  git note, is the durable record) before proceeding to Step 3, using the
  same resolve-via-`find_worktree_for_branch()`/`$PKG_WT_DIR`-or-fallback
  rule as the `## Merge (report-only)` entry above (see "Target
  `progress.md` for project/package-scope PRs" above) — a bypass on a
  project/package PR with no open worktree is posted as a comment on the
  merged PR (revision 6), not silently nowhere. Never auto-merges anything it wasn't already going to merge: the actual
  human gate remains "a human chose to run `make merge-pr`" — this check
  only adds a refusal *precondition* (when `--enforce`d and scoped to a
  workspace PR) before Step 3 is reached, it does not add or remove any
  interactive confirmation (there was none to begin with).
- **Layer 2 (Ask-First, NOT implemented in this PR — see Open
  Questions)**: a GitHub required status check or branch-protection rule
  enforcing the same precondition server-side, so a direct "Merge" click
  on GitHub bypasses nothing. AGENTS.md requires owner approval before
  changing CI or branch-protection config; this PR documents the design
  (what check would run, what it would assert) but does not implement or
  enable it. Flagged for the owner at plan read (see Open Questions).
- PR template gains a "## Decision summary" section using the single
  pinned template defined in PR B ("Decision-summary template" below) —
  augmenting, not replacing, the current "Documentation and test impact"
  / "Architecture impact" checklists, which stay (see Files to Change).
  This heading is the literal string Layer 1's check (b) greps for, so
  the template and the check must not drift independently.

**UNVERIFIED against fork source (nothing dropped from issue #269's own
spec — both the review-entry check and the decision-summary-comment
check are implemented; see must-fix 3 resolution above)**: the fork's own
`merge_pr.sh`
(`~/project11/.agent/scripts/merge_pr.sh`) has **no such gate today** —
grepping it for "Local Review" / "progress" / "force-unreviewed" /
"decision summary" returns nothing (confirmed by direct read). This item
is therefore not a straight port: issue #269's own body describes the
target behavior ("`merge_pr.sh` refuses ... unless `--force-unreviewed`
... no `## Local Review` entry ... no decision summary comment"), but no
fork source file implements it. Cite: UNVERIFIED against fork source; the
design below is authored fresh from the issue body's spec. This
workspace's `merge_pr.sh` has no pre-existing review/progress gate of any
kind (confirmed by the same grep as the fork check above) — PR F's Layer 1
is new work end to end, not a port and not a precondition bolted onto an
existing confirmation step. It follows the script's existing
warning-banner idiom (plain `echo "⚠️  ..."` to stderr on a non-fatal
path, e.g. `merge_pr.sh:498, 501, 618`) for the `--force-unreviewed`
bypass message, since that is the one existing pattern in this script
worth reusing; it does not reuse a merge-confirmation pattern because
none exists.

**Tests**: both modes and both in-scope/out-of-scope cases are covered,
against a sandbox workspace-type PR with the same four gap fixtures used
throughout — (a) no `## Local Review` entry at any SHA, (b) a
`## Local Review` at a stale SHA, (c) a `## Local Review` with
`**Verdict**: changes-requested`, (d) a matching-SHA
`**Verdict**: approved` entry but no `## Decision summary` PR comment:
- **Report-only mode (default, no `--enforce`)**: each of (a)–(d)
  proceeds to Step 3 (the `gh pr merge` call is reached) with the
  "would have refused because..." line present in stdout naming the
  failing condition(s), **and (revision 4) a `## Merge (report-only)`
  entry appended to `progress.md` naming the same failing condition(s)
  and the PR head SHA**; a fifth fixture (matching-SHA approved entry
  **and** decision-summary comment present) proceeds with no such line
  and appends no entry.
- **`--enforce` mode, `$WORKTREE_TYPE == "workspace"`**: `merge_pr.sh`
  refuses (exit non-zero, no worktree/branch mutation, no `gh pr merge`
  call reached) against each of (a)–(d); proceeds past the check (reaches
  Step 3) only with both a matching-SHA `**Verdict**: approved` entry
  **and** a `## Decision summary` comment present.
- **`--enforce` mode, `$WORKTREE_TYPE == "project"` and `""` (package/
  qualified-repo PR)**: fixture (a) (no review entry at all) still
  reaches Step 3 with the report-only "would have refused" line present
  — `--enforce` has no refusal effect outside `WORKTREE_TYPE ==
  "workspace"`, asserted explicitly so scope-widening can't regress
  silently.
- `--force-unreviewed` bypasses all four refusal cases together (tested
  under `--enforce` + workspace scope, where it has a refusal to bypass)
  with the warning banner present in its output **and** asserts a
  `## Merge (unreviewed)` entry was appended to `progress.md` naming
  which check(s) were bypassed; a further case asserts
  `--force-unreviewed` under report-only mode still prints the bypass
  banner and appends `## Merge (unreviewed)` instead of the "would have
  refused" line.

**Enforcement**: mechanical (Layer 1, this PR) — but the enforcement
itself ships off by default (report-only) and scoped to workspace PRs
only, per the owner's containment measures 1–2; the later flip to
`--enforce`-by-default and, separately, to project-PR scope, are each
their own one-line follow-up PR, not part of this sequence. Layer 2 is
explicitly **not yet enforced** pending the Ask-First decision (ADR-0004
gap, noted honestly rather than assumed either way).

### PR B2 — flip `PROGRESS_PERSISTENCE_STRICT`'s default (revision 4, not part of the A–F sequence)

**Lands (revision 5, resolving revision 4's suggestion on B2's revert
framing): the default flip only, nothing else.** A one-line default-value
change in each of `review-code/SKILL.md`, `triage-reviews/SKILL.md`, and
`plan-task/SKILL.md`'s step-6/step-8 switch checks, from
`PROGRESS_PERSISTENCE_STRICT` defaulting to `0` to defaulting to `1` — the
fail-loud `resolve_work_plans_dir()` call and `progress_append.sh`'s
commit mechanism become each skill's real, default behavior (still
overridable per-run the other direction if ever needed, since the switch
itself isn't removed).

Revision 4 also had B2 delete the compatibility-mode "would have
aborted" notice path, the old ad hoc resolution/inline-commit code it
guarded, and the switch-mode tests that exercised it — that is a second,
different kind of change (code removal) bundled into what revision 4
called "a one-line default-value change... revertible back to `0` in a
single follow-up commit." Those two claims don't square: a one-line
default flip is trivially revertible; deleting the code that flip
depended on is not — a regression found after B2 would need the deleted
code restored, not just the default flipped back. **Revision 5
un-bundles them**: B2 is now only the default flip (one line per skill,
three lines total, one commit), and the old compatibility-mode code
stays in place, untouched, after B2 merges — genuinely one-line and
genuinely one-commit-revertible, as originally claimed. Removing the
now-dead compatibility path and its tests is deferred to **PR B3**
(below).

**Gate**: `test_checkpoint_269.sh` (PR A) blocks this PR from merging
until `main`'s `.agent/work-plans/issue-269/progress.md` contains a
`## Checkpoint` entry with all four evidence fields — the same
mechanism that gates C–F, triggered here because B2 touches
`triage-reviews/SKILL.md` and `plan-task/SKILL.md`, both on the gated
file list. No separate check needed.

**When it's opened**: after the checkpoint entry exists (mechanically
required) and, as a matter of judgment the mechanical check can't
enforce, after the owner has seen the "would have aborted" notice line
stay silent (or print only expected, understood cases) across enough
real report-only invocations of `review-code`/`triage-reviews`/
`plan-task` to trust the strict path — this is the one place in the
sequence where human judgment, not just a mechanical gate, decides
timing; see Blast radius's B2 row above for the worst case this doesn't
eliminate.

**Tests**: the default-value assertion for all three call sites only.
The compatibility-mode notice tests from PR B/C/E are **not** touched by
B2 — they keep passing because the code they test is still present, just
no longer reached by default (it stays reachable via the switch's `0`
override, unused day to day after B2).

**Enforcement**: mechanical (the checkpoint-entry precondition via
`test_checkpoint_269.sh`); the "has the owner watched enough" judgment
call is explicitly not mechanized — see "When it's opened" above.

### PR B3 — remove the compatibility-mode path (revision 5, later, opened only after B2 has been in use)

**Not part of this plan's committed sequence** — named here so the
cleanup B2 no longer carries isn't lost, and so nobody mistakes B2's
"one-line flip" framing for "the compatibility path is gone." **Lands**
(when opened): deletes the `PROGRESS_PERSISTENCE_STRICT == 0`
compatibility-mode branch (old ad hoc resolution prose, old inline
`git add && git commit`, the "would have aborted" notice line) from
`review-code/SKILL.md`, `triage-reviews/SKILL.md`, and
`plan-task/SKILL.md`'s step-6/step-8 logic, and retires the
compatibility-mode notice tests from PR B/C/E along with it (or repoints
them to assert the path no longer exists, per whatever this workspace's
convention is for retiring a test — confirmed at B3 implementation time).
**Opened**: only after B2 has been in ordinary use long enough that the
owner is confident nothing needs the `0` fallback — B2's own default flip
is the exercise period for B3, the same relationship the checkpoint has
to B2. Not gated by `test_checkpoint_269.sh` (B3 doesn't touch any of the
checkpoint-gated files unless it also happens to touch
`triage-reviews/SKILL.md`/`plan-task/SKILL.md`, which it does — so in
practice it stays gated by the same mechanism, no special-casing needed
either way, since the checkpoint entry is already on `main` by the time
B3 is opened).

## #265 dependency and progress.md path resolution

#265 (open; design B) will move worktrees — and therefore, per design B's
own text, the natural home for per-issue artifacts — out from under the
workspace's own tree and root them under whichever repo/root owns the
worktree, once PRs 2–4 land. #265 PR 1 (registry + resolution) is merged;
PRs 2–4 are not.

**Verified reality (this section previously claimed "every skill resolves
progress.md the same way today" — false; three different mechanisms
coexist in this codebase right now)**, confirmed by reading each skill's
`SKILL.md` and grepping the repo for `resolve_work_plans_dir`:

- **`plan-task`** sources `.agent/scripts/_resolve_work_plans_dir.sh` and
  calls `resolve_work_plans_dir <N>` (`.claude/skills/plan-task/SKILL.md:
  102-104`) — the shared, fail-loud helper from #265 PR 1 / issue #147.
  It aborts with remediation guidance rather than silently falling back
  when the worktree doesn't match.
- **`review-code`** and **`triage-reviews`** do *not* call the shared
  resolver. Each duplicates its own ad hoc prose inline
  (`review-code/SKILL.md:504-506`, `triage-reviews/SKILL.md:197-199`):
  "check `.agent/work-plans/issue-<issue>/progress.md` in the owning
  repo's worktree first; if absent, fall back to the current worktree;
  create in the owning worktree if neither exists." Unlike
  `resolve_work_plans_dir()`, this never aborts — a mismatched worktree
  silently falls back to the current one instead of failing loudly, which
  is exactly the failure mode issue #147 introduced the shared resolver
  to close.
- **`review-plan`** is a further, distinct case, found only while
  verifying this section: its `SKILL.md` has **no** progress.md
  append/commit step at all today (no `resolve_work_plans_dir` call, no
  `git add`/`commit`, no `progress_append.sh` reference — confirmed by a
  full-file read; `grep -rl resolve_work_plans_dir` across the repo does
  not include `review-plan/SKILL.md`). Step 5 ("Produce the report") ends
  the skill's documented flow; the `## Plan Review` entries visible in
  this very file and in `.agent/work-plans/issue-265/progress.md` were
  appended by hand, outside the documented skill mechanism. This is a
  third, undocumented pattern, not a fail-loud one.

**Decision**: PR B and PR C unify `review-code` and `triage-reviews` onto
the shared `resolve_work_plans_dir()` helper — replacing their ad hoc
prose with a sourced call, same as `plan-task` already does — as part of
their existing `progress_append.sh` refactor (an in-scope consequence of
that refactor, per "a change includes its consequences," not a new
seventh PR). Each adds a test asserting the silent fallback is gone:
invoking the skill's progress.md-resolution step with `WORKTREE_ISSUE`
unset/mismatched and the cwd outside the owning worktree must abort
(non-zero exit, remediation message) rather than silently writing into
the wrong worktree. PR E is corrected to match: `review-plan` does not
merely "rename" an existing append step (it has none) — it *adds* its
first automated append step, sourcing `resolve_work_plans_dir()` and
`progress_append.sh` together, bringing all four skills onto one
mechanism. See PR E below for the corrected scope.

**Path-resolution conclusion, re-verified after the unification
decision**: `resolve_work_plans_dir()` is itself already
path-convention-agnostic (per its own header comment — rule 2 keys off
`git rev-parse --show-toplevel` relative to whatever worktree the caller
is in, not a hardcoded `<ws>/worktrees/...` string), and
`progress_append.sh`'s `-C <dir>` / `progress_read.py`'s plain file-path
argument both take a worktree path as an argument rather than
reconstructing one. Unifying B/C/E onto the shared resolver does not
introduce a new #265 dependency — it uses the same #265-PR-1-delivered
helper `plan-task` already depends on today, and that helper already
works under both today's layout and design B's post-PR-4 layout. The
plan's bottom-line conclusion therefore still holds: **no PR in this
sequence blocks on #265 PRs 2–4 landing first**, and none needs to change
once they do. This is a design property to verify, not just assert — PR
A's test suite includes one case that invokes `progress_append.sh -C
<dir>` from a `-C` path outside the conventional `<ws>/worktrees/...`
tree (a plain `mktemp -d` git repo) to confirm nothing in the script
assumes the workspace-relative layout, and PR B/C/E's new
`resolve_work_plans_dir()` tests reuse the same synthetic-repo pattern.

## Non-migration statement

Existing `progress.md` files predate this port and use non-conformant
headings: `.agent/work-plans/issue-265/progress.md` (on `main`, merged)
has `## Plan`, `## Plan review`, `## Implement — PR 1 of 4 (registry)` —
none of which match the new ADR's vocabulary (`## Plan Authored`,
`## Plan Review`, `## Implementation`). Per the fork's own ADR-0013
precedent ("Predecessor recognition" / "no migration of historical
files"), **this port performs no migration of existing `progress.md`
files**. They remain as historical artifacts, readable by eye but not
guaranteed to parse cleanly under `progress_read.py`'s correlation-key
extraction (e.g., `## Plan` won't match a `--type "Plan Authored"`
filter — there is no predecessor-recognition entry for it, unlike
`## External Review` → `## Integrated Review`, because #265's headings
were never a *named* predecessor type, just ad hoc prose). New entries
from PR B onward, on any issue, use the new vocabulary; issue #265's file
is not touched by this port.

## Blast radius

**What this port does not touch** (verified by listing `.claude/skills/`,
20 entries total; this port's PR sequence touches 4 existing skills
plus 1 new one):

- **The 16 skills outside the lifecycle chain**: `analyze-permissions`,
  `audit-project`, `audit-workspace`, `brainstorm`, `brand-guidelines`,
  `document-project`, `gather-project-knowledge`, `inspiration-tracker`,
  `issue-triage`, `onboard-project`, `research`, `review-issue`,
  `skill-importer`, `start-task`, `test-engineering`, `what-next`.
  **Scoped precisely (revision 4 suggestion 2)**: none of these writes
  any ADR-0013 entry type, calls `progress_append.sh`/`progress_read.py`,
  or is edited by any PR in this sequence — but one is not clean of
  `progress.md` outright: `start-task/SKILL.md:156` documents that
  `--workflow` initializes `progress.md`'s front-matter and an H1 title,
  delegated to `worktree_create.sh:797-816` (confirmed unmodified by this
  port, and confirmed to write only front-matter + an H1, no ADR-0013
  `##` entry heading — so it doesn't collide with the vocabulary rename
  in "risk point 3" below, but the flat "none of these read or write
  progress.md" claim in revision 3 was overstated and is corrected here).
- **Adapters** (`.agent/scripts/adapter`, `.agent/project_types/*/adapter.sh`,
  ADR-0011) — this port adds no new adapter verb and does not change
  `build`/`test`/`install`/`setup` dispatch.
- **Worktree scripts** (`worktree_create.sh`, `worktree_enter.sh`,
  `worktree_remove.sh`, `worktree_list.sh`) — PR B/C read worktree state
  (`WORKTREE_ISSUE`, branch name, `git rev-parse --show-toplevel`) through
  the existing `resolve_work_plans_dir()` helper; none of these scripts'
  own logic is modified.
- **The registry** (`.agent/scripts/_project_registry.sh` and the #265
  registry work) — this port reads through #265 PR 1's shared resolver
  as a consumer, same as `plan-task` already does; it does not modify
  registry logic, and no PR in this sequence depends on #265 PRs 2–4
  (see "#265 dependency and progress.md path resolution" below).
- **Hosting** — no CI workflow, branch-protection rule, or GitHub App/
  webhook configuration is changed by this port. PR F's Layer 2 (server-
  side enforcement) is explicitly not implemented (Open Questions); Layer
  1 is a local script change only.

**The three risk points the owner discussed, and how each is contained**:

1. **The gate hits project PRs before #265 settles project timelines.**
   Contained by containment measure 2: Step 2.5 reads the exact
   `$WORKTREE_TYPE` value `merge_pr.sh` already computes (`"workspace"` /
   `"project"` / `""` for package-repo PRs) and only ever refuses when it
   is `"workspace"`; `"project"` and `""` stay report-only regardless of
   `--enforce`, until a follow-up PR widens scope after #265 PRs 2–4
   land.
2. **The fail-loud `resolve_work_plans_dir()` change (and the
   `progress_append.sh` swap alongside it) breaks daily-use skills —
   `review-code`, `triage-reviews`, `plan-task`.** Revision 3 credited
   the checkpoint (measure 3) with containing this; revision 3's own plan
   review (must-fix 1) correctly found that wrong — the checkpoint pauses
   *PR C's start*, not PR B's exposure, so PR B's change would have gone
   live workspace-wide the instant PR B merged, before the #265 PR 2
   exercise the checkpoint waits for even ran. **Corrected containment
   (revision 4)**: this risk is contained by the
   `PROGRESS_PERSISTENCE_STRICT` switch (PR B/C/E, default `0` = today's
   behavior + a notice, detailed in each PR's section above), not by the
   checkpoint. The checkpoint's role is narrower and honestly stated:
   it's the gate on *flipping the switch's default* (B2, below) and on
   *starting PR C onward*, not on PR B's own merge. The skill-worktree/
   issue-less-branch case (containment measure 4) is a second, additive
   protection for the same call sites, independent of the switch: even
   under `PROGRESS_PERSISTENCE_STRICT=1`, PR B and PR C each add a
   call-site check before invoking the resolver — if no issue number is
   derivable, the skill prints "Progress persistence skipped (<reason>)"
   and completes the review with no `progress.md` write, rather than
   aborting mid-review. The resolver's existing fail-loud abort (issue
   #147) is preserved for the case it was built for — a resolvable issue
   number in the wrong worktree — and is not weakened by either
   protection.
3. **The vocabulary rename (`## External Review` → `## Integrated
   Review`, `## Plan` → `## Plan Authored`, `## Plan Review: PR #<N> —
   <title>` → `## Plan Review`) breaks readers of the old headings.**
   Contained by scope, verified with `grep -rn "## External
   Review\|## Plan Review:\|^## Plan$" .agent/ .claude/ .github/`: the
   only files that *write* these headings today are the three SKILL.md
   files this port already edits — `triage-reviews/SKILL.md:216`
   (`## External Review`), `review-plan/SKILL.md:181,217,227` (`## Plan
   Review: ...`), `plan-task/SKILL.md:211` (`## Plan`) — plus
   `progress_read.py` itself as the one automated *reader*, which PR A
   ships with predecessor recognition for `## External Review` from day
   one, and human eyes reading `progress.md` files directly. The grep's
   other hits are not readers of this vocabulary and are contained by
   being out of namespace or out of scope, not by this port touching
   them: the ~30 `.agent/work-plans/issue-<N>/progress.md` files it
   also matches are historical *data*, not code — covered by the
   Non-migration statement above, which keeps their old headings
   unrewritten rather than treating them as something to fix;
   `.github/ISSUE_TEMPLATE/feature_track.md:22`'s `## Plan` is a
   different namespace entirely (an issue-body planning checklist
   section, unrelated to `progress.md` entry types — confirmed by
   reading it: `### Phase 1: {Name}` subsections, no `**Status**`/
   `**When**`/`**By**` fields); and `.agent/workflows/README.md:65`'s
   `## Plan` is an illustrative worked example that already predates
   ADR-0013 (it also shows `## Brainstorm` and `## Implement`, neither
   of which is ADR-0013 vocabulary either) — real but pre-existing
   documentation drift this port neither causes nor is positioned to
   fix; left as a residual gap, not silently claimed clean.

**Per-PR worst case (revision 4, resolving must-fix 1's demand for an
honest table, not the prose containment claims above)**: every row below
must read "notice printed" or "test fails in CI" — except one, named
plainly rather than forced into that shape.

| PR | Worst case |
|---|---|
| A | Test fails in the new pre-commit hook (revision 5: `validate-script-tests`, running every `test_*.sh` including the seven that previously ran nowhere). New ADR + two new scripts + a new runner + new tests only; no existing skill's live behavior changes. |
| B | Notice printed (the "would have aborted" compatibility-mode line) or test fails in CI. `PROGRESS_PERSISTENCE_STRICT=0` is the ship default — `review-code`'s resolution and commit mechanism are unchanged from today; only the entry's new fields (convergence, decision summary) and the notice line are new, and a wrong field value is a misleading report, not a blocked skill. |
| C | Same as B, same switch, same default. Notice printed or test fails in CI. |
| D | Test fails in CI. New skill, not invoked by anything automatically — no existing skill's behavior is touched, and a human chooses each invocation. |
| E | Notice printed or test fails in CI. `plan-task`'s persistence swap is gated by the same switch (default `0`) as B/C; `review-plan`'s new append step is made non-fatal (a failure there prints a notice and exits 0 — the report it produces is unaffected), so neither half of this PR can turn a working skill invocation into a failed one. |
| F | Notice printed (report-only "would have refused" line, now also durably recorded as `## Merge (report-only)`) or test fails in CI. Ships report-only by default, scoped to `$WORKTREE_TYPE == "workspace"` only; `--enforce` is opt-in, not this PR's default. |
| **B2** | **Not bounded to notice/test-fails — stated plainly, not hand-waved.** B2 flips `PROGRESS_PERSISTENCE_STRICT`'s default from `0` to `1` for `review-code`, `triage-reviews`, and `plan-task` at once. That is the point at which the fail-loud resolver and `progress_append.sh`'s identity check go live by default in three daily-use skills. If the `#265` PR 2 exercise (or the smaller, organic exercise PR C/E get in report-only mode before B2) missed an edge case, B2 is what actually exposes it — a hard abort in a skill that previously always completed. This is contained, not eliminated: B2 touches `triage-reviews/SKILL.md` and `plan-task/SKILL.md`, both on the checkpoint-gated file list, so `test_checkpoint_269.sh` blocks B2 from merging until the `## Checkpoint` entry exists on `main` (same mechanism as C–F, no special-casing); the exercise happens on a real, non-trivial PR first, not a synthetic fixture; and the flip is genuinely a one-line diff, reviewable and revertible back to `0` in a single follow-up commit if it regresses something the checkpoint didn't catch — true as of revision 5, because B2 no longer deletes the compatibility-mode code it flips away from (see PR B2/B3 split above; that deletion is B3's job, opened only after B2 has been trusted in use). |
| **B3** | Test fails in CI (its own removed-path assertions) or a straightforward code-review catch — B3 deletes dead code (the `PROGRESS_PERSISTENCE_STRICT == 0` branch, unreachable by default after B2) and its own now-obsolete tests; no skill's default behavior changes, since B2 already made `1` the default. Opened only after B2 has been in use, per B2's own risk profile above serving as B3's exercise window. |

## Files to Change

| File | Change |
|------|--------|
| `docs/decisions/0013-progress-md-entry-type-vocabulary.md` (new; number TBD at commit time — next available) | New ADR, vocabulary + schema, cites fork ADR-0013 as source (PR A) |
| `.agent/scripts/progress_append.sh` (new) | Ported from fork, comment cross-references updated (PR A) |
| `.agent/scripts/progress_read.py` (new) | Ported from fork as-is (PR A) |
| `.agent/scripts/tests/test_progress_append.sh`, `.agent/scripts/tests/test_progress_read.py` (new) | Hermetic fixtures per entry type, whitelist, idempotency, fence-awareness, offset detection (PR A) |
| `.claude/skills/review-code/SKILL.md` | Convergence assessment, decision-summary section, `progress_append.sh` swap, documented absences (Ollama/Copilot/container) (PR B) |
| `.agent/scripts/tests/test_review_code_convergence.sh` (new) | Round-counting + ship-verdict fixture cases (PR B) |
| `.claude/skills/triage-reviews/SKILL.md` | `## External Review` → `## Integrated Review`, prior-entry integration, cross-source table, `progress_append.sh` swap (PR C) |
| `.agent/scripts/tests/test_triage_reviews_integration.sh` (new) | Cross-source-confirmation fixture (PR C) |
| `.claude/skills/address-findings/SKILL.md` (new) | Ported from fork, dispatcher references dropped (PR D) |
| `.agent/scripts/tests/test_address_findings.sh` (new) | Fix/defer fixture (PR D) |
| `.claude/skills/plan-task/SKILL.md` | `## Plan` → `## Plan Authored`, plan-commit-SHA correlation field, `progress_append.sh` swap (PR E) |
| `.claude/skills/review-plan/SKILL.md` | `## Plan Review: PR #<N> — <title>` → `## Plan Review` (title moves to body), correlation field, `progress_append.sh` swap (PR E) |
| `.agent/scripts/tests/test_plan_correlation.sh` (new) | Plan-commit-SHA correlation fixture (PR E) |
| `.agent/scripts/merge_pr.sh` | Layer-1 gate: `progress_read.py`-backed precondition check, report-only by default with `--enforce` flag, scoped to `$WORKTREE_TYPE == "workspace"`, `--force-unreviewed` bypass, `## Merge (report-only)` durable record for every refusal (PR F, revision 4) |
| `.agent/scripts/tests/test_merge_pr_gate.sh` (new) | Refusal/pass/bypass cases, `## Merge (report-only)` entry assertions (PR F) |
| `.github/PULL_REQUEST_TEMPLATE.md` | Decision-summary section (PR F) |
| `Makefile` (help text, `:70`) | Add `MERGE_PR_ARGS` to the `make merge-pr` help line (PR F, revision 4) |
| `.agent/scripts/tests/test_checkpoint_269.sh` (new) | Hermetic CI check: refuses PRs touching C–F/B2 files without a `## Checkpoint` entry on `main` (PR A, revision 4) |
| `.agent/scripts/tests/run_script_tests.sh` (new) | Runner: globs and executes every `.agent/scripts/tests/test_*.sh`, plus an explicit presence assertion for `test_checkpoint_269.sh` (PR A, revision 5) |
| `.agent/scripts/tests/test_run_script_tests.sh` (new) | Fixture tests for the runner's glob discovery, explicit-presence check, and fail-fast behavior (PR A, revision 5) |
| `.pre-commit-config.yaml` | New local hook `validate-script-tests` (`always_run: true`, `pass_filenames: false`) invoking `run_script_tests.sh` inside the existing `Lint (pre-commit)` job; no `validate.yml` edit (PR A, revision 5) |
| `.github/copilot-instructions.md`, `.agent/instructions/gemini-cli.instructions.md`, `.agent/AGENT_ONBOARDING.md` | Add `address-findings` to skill lists (PR D) |
| `.agent/knowledge/principles_review_guide.md` | New ADR row in the ADR-applicability table (PR A) |
| `.agent/knowledge/review_depth_classification.md` | Note convergence/round fields now appear in the review-code report header (PR B) |
| `.agent/scripts/cross_model_review.sh` | Confirm no `progress.md`-header assumptions break (spot-check only; PR B) |
| `ARCHITECTURE.md` | `.agent/work-plans/issue-<N>/progress.md` entry-type vocabulary note, cross-reference the new ADR (PR A) |
| `Makefile` | New `.PHONY` test targets if the test harness needs one per PR; run `make generate-skills` if any `.PHONY` target changes (each PR, as needed) |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Enforcement over documentation | Every PR pairs its behavior change with a hermetic test (PR A's whitelist test + `test_checkpoint_269.sh` + `run_script_tests.sh`'s own tests, PR B's round-counting + degradation + switch-mode tests, PR C's cross-source fixture + degradation + switch-mode tests, PR D's fix/defer fixture, PR E's correlation + switch-mode + non-fatal-path tests, PR F's report-only/enforce/scope/bypass + durable-record cases). Revision 4 closed the checkpoint's paper-only gap (revision 3's must-fix 2) with `test_checkpoint_269.sh`; revision 5 closes the layer under that — the test existing is not the same as the test running, and revision 4's `test_checkpoint_269.sh` ran nowhere until revision 5's pre-commit hook wired it (and seven pre-existing suites) in. PR F Layer 2, PR F Layer 1's enforce-by-default flip, and B2's judgment-call timing (see PR B2) remain the deliberately-unenforced-so-far items, and all are called out, not hidden. |
| Capture decisions, not just implementations | PR A puts the vocabulary in an ADR, not five SKILL.md copies (the exact failure mode ADR-0013 itself documents and this workspace already exhibits: `triage-reviews` still says `## External Review`). |
| A change includes its consequences | Files to Change lists every skill-list/knowledge-doc consequence flagged by the `review-issue` comment and the Consequences Map. |
| Only what's needed | Ollama, Copilot-CLI, and container-dispatch specialists are explicitly dropped, not silently ported as dead code. |
| Improve incrementally | Six independently mergeable PRs, each with its own tests, per the owner's adjustment #1; the checkpoint after PR B (containment measure 3) and the report-only-before-enforce sequencing (measure 1) are the same principle applied a second time, at the gate's rollout rather than at the PR split. |
| Test what breaks | Each PR's Tests subsection is concrete (fixture shape, not "add tests"). |
| Human control and transparency | Merge gate never auto-merges; ships report-only so the owner sees its verdicts before it can block anyone (measure 1); the CI/branch-protection layer is Ask-First, not assumed; convergence verdicts are advisory, never blocking. |
| Workspace vs. project separation | Nothing project-specific introduced; all vocabulary and scripts are generic over any `.agent/work-plans/issue-<N>/`; the merge gate additionally stays out of project-PR enforcement entirely at first (measure 2), on top of that existing separation. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0001 (Adopt ADRs) | Yes | PR A is a new ADR, ordinary authorship — no addendum mechanics needed. |
| ADR-0004 (Enforcement hierarchy) | Yes | PR F's merge gate is explicitly presented as two layers; Layer 1 (local script) ships in this sequence, Layer 2 (CI/branch-protection) is named as a real gap and routed through Ask-First rather than assumed done or assumed out of scope. |
| ADR-0008 (Cross-reference addendums) | No, not yet | PR A authors a brand-new ADR (ordinary ADR-0001 process), not an edit to an accepted one — ADR-0008 doesn't apply to authorship. It will apply the first time this new ADR needs a navigational update after landing (e.g., if a future skill adds a new consumer of the vocabulary) — flagged for later, not actionable now. |
| ADR-0011 (Adapter contract) | Watch, not blocking | `merge_pr.sh`'s existing gate/banner logic and the new Layer-1 check are not adapter-verb-routed (same ad hoc-per-repo pattern the #265 plan's own review already flagged as pre-existing, not a regression this PR introduces). Not fixed here — out of scope for a review-loop port. |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `progress.md` entry-type vocabulary (new ADR) | `.agent/knowledge/principles_review_guide.md` ADR-applicability table | Yes (PR A) |
| `review-code` Step 8 / report shape | `.agent/knowledge/review_depth_classification.md`, `.agent/scripts/cross_model_review.sh` | Yes (PR B) |
| New `address-findings` skill | Framework adapter skill lists (`.github/copilot-instructions.md`, `.agent/instructions/gemini-cli.instructions.md`, `.agent/AGENT_ONBOARDING.md`) | Yes (PR D) |
| Work-plan progress-entry schema (headings, correlation fields) | `plan-task`, `review-plan`, `triage-reviews`, `review-code` skills; `ARCHITECTURE.md` directory-tree/vocabulary reference | Yes (PRs A/B/C/E; `ARCHITECTURE.md` in PR A) |
| Merge-gate behavior | PR template (decision summary), `merge_pr.sh` docs/help text | Yes (PR F) |
| Merge-gate enforcement layer 2 (CI/branch protection) | Branch-protection config, CI workflow | **Not included** — Ask-First, owner decision required before any implementation (Open Questions) |

## Open Questions

- **Layer 2 (CI/branch-protection) for the merge gate** — implement now as
  a follow-up issue after PR F, or defer indefinitely and accept
  local-only (bypassable via direct GitHub UI merge) enforcement? This is
  an AGENTS.md Ask-First item; the owner must decide before any CI/
  branch-protection change is made, per the host decision comment's
  adjustment #5.
- **New ADR number** — this plan doesn't pin the exact ADR number (next
  available at PR A's commit time is 0013 as of this writing, matching the
  fork's own number coincidentally, but that's not guaranteed if another
  ADR lands first). Confirm at PR A implementation time, not now.
- **Test-harness convention for the six new `.agent/scripts/tests/test_*`
  files** — this workspace's existing test runner conventions should be
  followed exactly (shell vs. Python per script under test) for the files
  themselves. **Resolved (revision 5), no longer open**: how they get
  *executed* in CI is the new `.pre-commit-config.yaml` local hook running
  `run_script_tests.sh` (see "Checkpoint enforcement — CI wiring" above)
  — not an entry-point question, since neither `make test` nor
  `.agent/scripts/adapter test` was ever going to pick up this workspace's
  own `.agent/scripts/tests/` scripts (those dispatch to the *project*
  adapter's `TEST_CMD`, confirmed by reading `.agent/scripts/test.sh`).

## Estimated Scope

**Checkpoint after PR B (owner's containment measure 3, mechanically
enforced from revision 4)**: the sequence pauses after PR B merges.
Before PR C starts, PR A + PR B are exercised on PR 2 of #265 (a real
project-affecting workspace PR, not a synthetic fixture) — concretely,
all three of the following must be observed on that PR before the pause
lifts:

1. **`review-code` writes its entry via `progress_append.sh` with the
   convergence verdict** — the `## Local Review (Pre-Push)` (or
   `## Local Review`) entry `progress_append.sh` commits for #265 PR 2
   carries the `**Round**`/`**Ship**` fields PR B adds, and the commit
   is the one `progress_append.sh` made (not a hand-typed entry
   resembling one).
2. **The fail-loud `resolve_work_plans_dir()` path is hit from a
   worktree** — for this one exercise run, `review-code` is invoked with
   `--strict-progress` (revision 5; PR B's ambient default stays `0` for
   every other invocation; see PR B above) so `resolve_work_plans_dir()`
   runs
   for real against #265 PR 2's actual project worktree (per #265's
   design), not just PR B's own hermetic test fixtures; any resolution
   failure on this real PR is the checkpoint's signal to fix PR B before
   the default flips (B2) or C starts, not to route around it.
3. **The decision summary is produced from the pinned template** —
   `review-code`'s report on #265 PR 2 includes the "Decision summary"
   section using the exact template pinned in PR B ("Decision-summary
   template" above), confirming the shape holds on a real, non-trivial
   PR before PR F is built to consume it.

Only once all three are observed does the owner write a `## Checkpoint`
entry to this `progress.md` (schema and required fields — `**PR**`,
`**Review entry SHA**`, `**Resolver-hit**`, `**Decision summary
URL**` — defined in PR A above). This is no longer a note that might be
forgotten: `test_checkpoint_269.sh` (PR A) mechanically refuses to let
any PR touching a C–F file (or B2) merge without that entry present on
`main` — see "Blast radius" above for the finding this closes (revision
3's must-fix 2) and PR A for the check itself. This holds PR E back too,
despite PR E depending only on PR A structurally — the owner's
sequencing measure names "C–F," which includes E; see the
adjusted dependency note below.

**Merge-adjacent-seams check** (owner's 2026-09-16 decision comment: "merge
adjacent seams where a PR would otherwise be trivial"), applied explicitly
rather than restated from the original A-F split:

- **PR C into PR D?** Not merged. PR C (`triage-reviews`) is not trivial on
  its own merits — beyond the `## External Review` → `## Integrated Review`
  rename it lands the cross-source-confirmation table, the
  `progress_read.py`-backed prior-entry integration, and (per the must-fix
  2 resolution above) the `resolve_work_plans_dir()` unification, each with
  its own fixture test. PR D (`address-findings`) is a new skill with its
  own fix/defer fixture. Merging them would make one PR review two
  unrelated skills' worth of new mechanical tests at once, which cuts
  against "each independently mergeable and individually tested." They
  stay split.
- **PR D's dependency on PR B** — re-examined per the plan review's finding.
  The plan previously stated PR D depends on both PR C and PR B, because
  `address-findings` reads either `## Integrated Review` (PR C) or
  `## Local Review (Pre-Push)` as its source entry. But PR B's own "Lands"
  section confirms `review-code` **already** writes
  `## Local Review (Pre-Push)` with conformant headings today, before PR B
  lands — PR B only swaps the commit mechanism onto `progress_append.sh`
  and adds convergence fields. PR D can therefore land on PR A + PR C
  alone, reading today's already-conformant `## Local Review (Pre-Push)`
  entries; PR B is not a hard dependency, only a soft one (once PR B lands,
  those same entries also carry `**Round**`/`**Ship**` fields that
  `address-findings` should read defensively — i.e. tolerate their absence
  — rather than require).

Six PRs (A–F) remain, each independently mergeable and individually
tested, per the owner's adjustment #1. PR A is the foundation (nothing
downstream compiles/tests cleanly without it). Structurally, PR B and PR
E depend only on PR A and could land in either order relative to each
other; PR C depends on PR A (reads `## Local Review` via
`progress_read.py`) but not on PR B; PR D depends on PR A and PR C
(`## Integrated Review`), with PR B a soft, not hard, dependency (see
above — PR D must read `## Local Review (Pre-Push)` defensively whether
or not PR B's round/ship fields are present); PR F depends on PR A
(`progress_read.py`) only, not on B–E. **The checkpoint above overrides
this structural freedom**: per the owner's containment measure 3, C
through F — which includes E, despite E's structural dependency being on
A alone — do not start until PR B has merged and been exercised on #265
PR 2. So the only real ordering freedom left is A → B, then the
checkpoint, then C/D/E/F in the dependency order above, with B2 (the
`PROGRESS_PERSISTENCE_STRICT` default flip only, revision 4/5 — not part
of the six-PR count, see PR B2 above) landing any time after the
checkpoint is recorded, independent of where C–F are in their own
sequence, and **B3** (revision 5 — deleting the now-dead compatibility
path B2 leaves in place, see PR B3 above) landing later still, opened
only once B2 has been trusted in ordinary use; B3 is not gated by the
checkpoint mechanism's C–F file list directly, but touches the same two
skill files B2 does, so it stays behind `test_checkpoint_269.sh` anyway
by the time it's opened, with no special-casing needed. No PR in this
sequence is blocked on #265 PRs 2–4 merging (the checkpoint uses
#265 PR 2 as a real-world exercise target, which is independent of
whether #265 PRs 2–4 land first).

**`--force-unreviewed` audit record**: the bypass gets a durable,
git-tracked record rather than terminal-only stdout — PR F's Layer 1 check
appends a `## Merge (unreviewed)` entry to the target issue's `progress.md`
via `progress_append.sh` at bypass time (not a git note), recording who
bypassed, when, the PR head SHA, and which of the two checks (review-entry
and/or decision-summary-comment) were missing. `progress.md` is chosen
over a git note because it is already this whole port's single audit
trail — every other gate-relevant fact (`## Local Review`,
`## Integrated Review`, `## Decision summary`) lives there, and
`progress_read.py`/`gh` tooling already reads it; a git note would be a
second, un-queried record type that nothing else in this plan consumes.
This satisfies ADR-0004's "human control and transparency" lineage the
plan review cited: the bypass is visible in the same place a human already
looks to confirm a PR was reviewed.

**Decision-summary shape**: pinned to the single template in PR B
("Decision-summary template" above); PR F's PR-template section and
Layer-1 comment check both reference that one block rather than each
carrying their own prose description.
