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
last CI-verified head is that issue's `progress.md`. GitHub currently
requires no status checks on `main`, so the CI wait is entirely this
script's policy and it can make this exemption itself.

## Approach

1. **Capture the reviewed head once, before any push.** Read
   `headRefOid` at the top of the script (before Step 1) into
   `HEAD_REVIEWED`. Step 1.5 already reads it for the gate; reuse one read.
2. **Make the Merge record idempotent per PR, not per head.** Before
   appending, parse the timeline with `progress_read.py` and, if the
   *latest* entry is a `## Merge (report-only)` or `## Merge (unreviewed)`
   whose correlation is this PR number, print "already recorded at
   `<sha>`" and skip both the append and the push. The entry's `**PR**` SHA
   stays the reviewed head, which is the SHA the review entries correlate
   with. Applies to the PR-comment fallback too (skip when the latest PR
   comment already carries the heading for the same conditions).
3. **Decide the CI target in Step 2 from what actually changed.** After
   Steps 1 and 1.5, re-read `headRefOid` as `HEAD_NOW`. If
   `HEAD_NOW == HEAD_REVIEWED`, the target is `HEAD_NOW`. Otherwise compute
   `git diff --name-only HEAD_REVIEWED..HEAD_NOW` in the PR's worktree
   (both commits are local because this script made them). If every path
   equals `.agent/work-plans/issue-<N>/progress.md`, the target is
   `HEAD_REVIEWED` and the script prints why the new head is exempt. Any
   other path (including the Step 1 roadmap commit, see open questions)
   makes the target `HEAD_NOW`.
4. **Wait for CI on the target SHA, not on "whatever runs exist".**
   Replace `gh pr checks --watch` with a bounded poll of
   `gh api repos/<slug>/commits/<sha>/check-runs` (plus the legacy
   `/status` endpoint for commit statuses): treat "zero check runs
   registered" as *not started yet* and keep polling (fixes #271), fail on
   any `conclusion` in failure/cancelled/timed_out, succeed when all are
   completed and successful. Poll interval and overall timeout come from
   env vars (`MERGE_PR_CI_POLL_SECONDS`, default 10; `MERGE_PR_CI_TIMEOUT_SECONDS`,
   default 1800) so tests can run with a zero interval. A timeout with no
   checks ever registered is a clear error and no merge. `--no-wait` still
   skips the whole step.
5. **Let mergeability settle before `gh pr merge`.** Poll
   `gh pr view --json mergeable,mergeStateStatus` until `mergeable` is not
   `UNKNOWN` (bounded by the same timeout). Then merge. If GitHub's GraphQL
   merge refuses an `UNSTABLE` head (pending non-required checks on a
   progress-only commit), fall back to the REST merge
   (`gh api -X PUT repos/<slug>/pulls/<N>/merge -f merge_method=merge`),
   which accepts unstable. Verify which of the two GitHub refuses during
   implementation against a throwaway PR rather than from memory, and keep
   only the path that is needed.
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
   - entry push plus a roadmap commit: the check-runs call targets the new
     SHA;
   - check-runs empty for the first N calls then green: merges (#271);
   - check-runs never appear: timeout error, no `pr merge` call;
   - a failed check-run: error, no merge;
   - `mergeable: UNKNOWN` for the first N `pr view` calls then
     `MERGEABLE`: merge proceeds.
   Update `test_merge_pr.sh`'s stub comment ("`pr checks` is never actually
   invoked") to match.
8. **Docs**: `agent_wait_patterns.md` rows that name
   `gh pr checks --watch --fail-fast` as the script's wait mechanism; the
   `merge_pr.sh` row in the AGENTS.md script table (Ask-First, see open
   questions).

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/merge_pr.sh` | Reviewed-head capture; per-PR idempotent record; diff-based CI target; SHA-targeted CI poll with "not started" handling; mergeability settle; header comments |
| `.agent/scripts/tests/test_merge_pr_gate.sh` | Stub for `gh api` check-runs / status and mergeability; seven new cases above |
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
| Only what's needed | No new flags; two env vars exist only so tests do not sleep |

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
| `merge_pr.sh` behaviour summary | AGENTS.md script table row | Yes, pending Ask-First |
| Merge gate enforce-by-default decision (#269 follow-up) | Nothing here; the "Pre-Push at head" question stays open on #269 | No — out of scope |

## Open Questions

- **Roadmap commit exemption.** Step 1 also pushes a commit (docs/ROADMAP.md
  only) before the wait. The owner's rule names only `progress.md`, so the
  plan waits for full CI after a roadmap commit. Extend the exemption to
  the roadmap file? Default: no.
- **AGENTS.md row edit** (Ask-First): change "waits for CI on the latest
  HEAD before merging" to "waits for CI on the reviewed head; a
  progress.md-only record commit is exempt". Yes/no.
- Which merge call GitHub refuses on an `UNSTABLE` head is verified during
  implementation (step 5); if GraphQL accepts it, no REST fallback lands.

## Estimated Scope

Single PR.
