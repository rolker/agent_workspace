# Plan: merge_pr.sh: gate record push moves the PR head after the CI wait; retries duplicate the Merge entry

## Issue

https://github.com/rolker/agent_workspace/issues/284 (folds in #271, the
"no checks reported" race — same code path)

## Context

`merge_pr.sh` Step 1.5 records a `## Merge (report-only)` entry in the PR's
worktree and pushes it. That push moves the PR head. Step 2 then runs
`gh pr checks --watch` against whatever runs exist, which right after a push
are the *old* head's runs, reports success, and `gh pr merge` fails because
the new head's mergeability is still being recomputed. Re-running records a
second entry (new head SHA, so the tail-idempotency guard does not match)
and pushes again; it never converges. PR #282 needed a manual merge and
carries two duplicate entries.

Owner decision (recorded on #284, 2026-09-18): keep GitHub's server-side
protection (`require_pr` ruleset, no bypass actors). The script may merge
**without waiting for CI on the new head** when the only difference from the
last CI-verified head is the document files the script itself updates once
the merge is approved: the roadmap commit (Step 1, `docs/ROADMAP.md`) and
the issue's `progress.md` (Step 1.5). GitHub currently requires no status
checks on `main`, so the CI wait is entirely this script's policy and it
can make this exemption itself.

## Approach

1. **Capture the reviewed head once, before any push.** Read
   `headRefOid` at the top of the script (before Step 1) into
   `HEAD_REVIEWED`. Step 1.5 already reads it for the gate; reuse one read.
2. **Make the Merge record idempotent per PR and per outcome, not per
   head.** Before appending, parse the timeline with `progress_read.py`
   and take the *latest* `## Merge (report-only)` / `## Merge (unreviewed)`
   entry whose correlation is this PR number. Skip the append and the push
   only when that entry's type **and** its `**Conditions**` line equal the
   freshly computed ones (print "already recorded at `<sha>`, same
   conditions"). When the reasons differ (a review was added, a new gap
   appeared), append a fresh entry so the timeline reflects the run that
   actually merged. The entry's `**PR**` SHA stays the reviewed head, which
   is the SHA the review entries correlate with. Same rule for the
   PR-comment fallback: compare against the latest PR comment carrying the
   heading.
3. **Decide the CI target in Step 2 from what actually changed, after
   verifying ancestry.** After Steps 1 and 1.5, `git fetch origin
   <PR branch>` in the PR's worktree and re-read `headRefOid` as
   `HEAD_NOW`. The exemption applies only when all of these hold:
   `HEAD_NOW != HEAD_REVIEWED`; `HEAD_NOW` resolves locally after the
   fetch; `git merge-base --is-ancestor HEAD_REVIEWED HEAD_NOW` (so a
   force-push or an unrelated concurrent push never qualifies); and every
   path in `git diff --name-only HEAD_REVIEWED HEAD_NOW` is one the script
   committed itself in this run (Step 1 records the roadmap path it
   committed, Step 1.5 records `.agent/work-plans/issue-<N>/progress.md`;
   the set is built from what was actually committed, not a hardcoded
   list). Then the target is `HEAD_REVIEWED` and the script prints why the
   new head is exempt. In every other case, including a concurrent push by
   another agent, a SHA the fetch did not bring in, or any path the script
   did not write, the target is `HEAD_NOW` and the script says which
   condition failed.
4. **Wait for CI on the target SHA, not on "whatever runs exist".**
   Replace `gh pr checks --watch` with a bounded poll of
   `gh api repos/<slug>/commits/<sha>/check-runs` plus the
   `/commits/<sha>/status` endpoint for legacy commit statuses. Rules:
   - **No CI configured**: if `gh api repos/<slug>/actions/workflows`
     reports zero active workflows and the target SHA has no check runs
     and no statuses, print "no CI configured for <slug>; nothing to wait
     for" and proceed. This keeps project repos without workflows and test
     sandboxes mergeable (today they fail on "no checks reported").
   - **CI configured, nothing registered yet**: keep polling for a grace
     window (`MERGE_PR_CI_GRACE_SECONDS`, default 120). If still nothing
     after the window, error out with no merge: "no checks registered for
     <sha> after N s; if this commit is excluded by workflow path filters,
     re-run with --no-wait". Explicit, never a silent pass (fixes #271
     without hiding a real gap).
   - **Registered**: fail on any `conclusion` in failure / cancelled /
     timed_out / action_required, succeed when every run and status is
     completed and successful, otherwise keep polling until
     `MERGE_PR_CI_TIMEOUT_SECONDS` (default 1800) and then error.
   Poll interval is `MERGE_PR_CI_POLL_SECONDS` (default 10) so tests can
   run with zero. `--no-wait` still skips the whole step.
5. **Let mergeability settle before `gh pr merge`.** Poll
   `gh pr view --json mergeable,mergeStateStatus` until `mergeable` is not
   `UNKNOWN`, bounded by the grace window; if it never settles, error out
   with the PR URL and no merge. Then merge (GraphQL, via `gh pr merge
   --merge`); if that refuses with "not mergeable", re-poll mergeability
   once more and retry the merge once, then error. See Implementation
   Notes: the REST fallback described in an earlier revision of this step
   was not implemented — see there for why.
6. **Update the header comments** in `merge_pr.sh` (Steps list, the Step
   1.5 note that the push "is covered by" the CI wait, the #186 manual
   verification block, which becomes an automated test).
7. **Tests** in `test_merge_pr_gate.sh` (extend the `gh` stub with
   `api .../check-runs`, `api .../status`, and `pr view` mergeability
   fields, driven by fixture files and a call log):
   - second invocation on the same PR appends no second Merge entry and
     pushes nothing;
   - entry push moves the head, diff is progress-only: the check-runs call
     targets the reviewed SHA and the merge proceeds;
   - entry push plus the script's own roadmap commit: still exempt, the
     check-runs call targets the reviewed SHA;
   - a commit touching a path the script did not write (e.g. a `.sh`
     alongside progress.md): no exemption, the check-runs call targets the
     new SHA;
   - check-runs empty for the first N calls then green: merges (#271);
   - check-runs never appear: timeout error, no `pr merge` call;
   - a failed check-run: error, no merge;
   - `mergeable: UNKNOWN` for the first N `pr view` calls then
     `MERGEABLE`: merge proceeds;
   - `mergeable: UNKNOWN` for the whole grace window: error, no merge;
   - repo with zero workflows and no runs on the target: proceeds with the
     "no CI configured" note;
   - CI configured, checks never register: grace-window error, no merge
     (distinct from the no-CI case);
   - second invocation with *different* gate reasons: a fresh entry is
     appended; with identical reasons: none;
   - PR-comment fallback (no open worktree) run twice: one comment, and a
     differing-reasons run posts a second;
   - concurrent push: the fixture's `headRefOid` after the record push is
     a commit not descended from the reviewed head; the check-runs call
     targets that new SHA (no exemption) and the output names the failed
     ancestry condition;
   - a check-run stuck pending forever (registered, never resolves): the
     overall timeout error, distinct from the never-registered case.
   Landed as 15 cases in `test_merge_pr_gate.sh` (four idempotency + eleven
   CI-target/wait/mergeability) plus a header/comment update in
   `test_merge_pr.sh` ("`pr checks` is never actually invoked" -> the
   script doesn't call `pr checks` at all any more; replaced by the
   SHA-targeted `gh api` poll, which this suite's --no-wait cases never
   exercise either).
8. **Docs**: every mention of `gh pr checks --watch --fail-fast` as the
   script's wait mechanism in `agent_wait_patterns.md` (five places: the
   prose around lines 31 and 40, the table row, and the two list items near
   lines 57 to 65); the `merge_pr.sh` row in the AGENTS.md script table
   (Ask-First, see open questions).

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/merge_pr.sh` | Reviewed-head capture; per-PR, per-conditions idempotent record; fetch + ancestry + script-written-paths CI target; SHA-targeted CI poll with no-CI / not-started / registered rules; mergeability settle; header comments |
| `.agent/scripts/tests/test_merge_pr_gate.sh` | Stub for `gh api` check-runs / status / workflows and mergeability; fifteen new cases above |
| `.agent/scripts/tests/test_merge_pr.sh` | Stub comment about `pr checks` |
| `.agent/knowledge/agent_wait_patterns.md` | Wait mechanism is now a SHA-targeted poll |
| `AGENTS.md` | Script-table row for `merge_pr.sh` (Ask-First; one phrase) |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Human control and transparency | Server-side protection stays; the exemption is narrow (one file, the issue's own timeline) and printed when applied |
| Enforcement over documentation | The exemption and the idempotency rule are code plus tests, not a note telling agents to re-run carefully |
| Test what breaks | Every failure mode observed on #266 and #282 gets a hermetic case with the stubbed `gh` |
| A change includes its consequences | Header comments, wait-patterns doc, script table, and the stale `pr checks` stub comment are in scope |
| Only what's needed | No new flags; three env vars (poll, grace, timeout) exist only so tests do not sleep |
| Workspace serves the product | Project repos without workflows keep merging via the script instead of failing on "no checks" |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0013 (progress.md vocabulary) | Yes | Entry shape unchanged; idempotency keyed on the PR correlation key the ADR already defines for Merge entries |
| ADR-0004 (enforcement hierarchy) | Yes | Layer 1 (local script) only; no CI or branch-protection change, so no Ask-First trigger from the fix itself |
| ADR-0010 (git-bug optional) | No | PR operations stay `gh`-only |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| The CI wait mechanism | `agent_wait_patterns.md`, `merge_pr.sh` header, `#186` manual-verification block | Yes |
| Merge record idempotency | `test_merge_pr_gate.sh` report-only cases (still one entry each) | Yes |
| The CI wait now handles repos with no workflows | Nothing else; `--no-wait` semantics unchanged | Yes |
| Exemption depends on the worktree having fetched the PR branch | A `git fetch` in the script; no user-visible change | Yes |
| `merge_pr.sh` behaviour summary | AGENTS.md script table row | Yes, pending Ask-First |
| Merge gate enforce-by-default decision (#269 follow-up) | Nothing here; the "Pre-Push at head" question stays open on #269 | No — out of scope |

## Open Questions

- ~~Roadmap commit exemption~~ — answered 2026-09-18: yes, any document
  file the script updates once the merge is approved is exempt; the plan
  now keys the exemption on the paths the script committed itself.
- ~~AGENTS.md row edit~~ (Ask-First) — approved 2026-09-18: changed "waits
  for CI on the latest HEAD before merging" to "waits for CI on the
  reviewed head; the script's own roadmap and progress.md commits are
  exempt".
- ~~Which merge call GitHub refuses on an `UNSTABLE` head~~ — resolved
  during implementation without a throwaway PR: see Implementation Notes.

## Implementation Notes

- **REST merge fallback not implemented.** Step 5's `gh pr merge` retry
  path is GraphQL-only (`gh pr merge --merge`, re-poll mergeability once,
  retry once), not the GraphQL-then-REST fallback this plan originally
  described. The observed #282 failure mode was `gh pr view`'s
  `mergeable` field reading `UNKNOWN` right after the push — a
  recompute-in-flight race, not GitHub refusing an `UNSTABLE` merge. The
  mergeability-settle poll (wait until `mergeable != UNKNOWN`) directly
  addresses that race, so the REST fallback (`gh api -X PUT
  repos/<slug>/pulls/<N>/merge -f merge_method=merge`, which accepts
  `UNSTABLE`) had nothing left to cover and was left out rather than
  built speculatively. If a future merge is ever refused specifically
  because `mergeStateStatus` settled to `UNSTABLE` (not `UNKNOWN`) and
  GraphQL's `pr merge` still refuses it, that observation is the trigger
  for adding the REST fallback — not before.

## Estimated Scope

Single PR.
