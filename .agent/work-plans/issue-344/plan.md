# Plan: Drop the Copilot CLI as a cross-model reviewer (keep the hosted Copilot PR review as a triage source)

## Issue

https://github.com/rolker/agent_workspace/issues/344

## Context

The Copilot CLI is one of four cross-model reviewers (`gemini`, `codex`,
`claude`, `copilot`) in `cross_model_review.sh`. Owner decision, 2026-10-13:
"It uses the same models under the hood as we already use, so let's stop using
copilot cli and only use copilot on github." The owner also approved editing
the two AGENTS.md Script Reference rows (`cross_model_review.sh`,
`_cli_review.sh`) in this PR; any other AGENTS.md edit stays Ask-First. All
eight Issue Review actions (90b4d026) proceed. The hosted Copilot PR review
(merge_pr.sh check-run handling, run-issue wait step, triage-reviews bot
source) is untouched. Nothing new is built.

## Approach

Four commits on this branch, each reviewable alone. Line numbers are from the
Issue Review grep and re-checked while planning; the implementer re-greps
`copilot` in each file before editing.

1. **Scripts** — `_cli_review.sh`: delete the `copilot)` arm (including the
   PENDING-LIVE-CONFIRMATION note), narrow the agent whitelist to
   `codex|claude` and its error text, fix the usage line, header and the
   "Verified against ... copilot 1.0.61" paragraph. `cross_model_review.sh`:
   delete `["copilot"]="copilot"` from `AGENT_BINS`, drop `copilot` from the
   helper-availability condition (line ~602) and from the comments/usage text
   (13, 19, 39, 54, 195, 324, 1444). With the key gone, `--agents copilot` and
   `--agent copilot` already reach the existing "Unknown agent" exit-2 path.
   Make the "Supported agents:" line deterministic: print the keys sorted
   (`printf '%s\n' "${!AGENT_BINS[@]}" | sort | paste -sd,` style) at both
   call sites (lines ~497 and ~513) instead of associative-array order.
2. **Tests** (`.agent/scripts/tests/test_cross_model_review.sh`, ~73 mentions)
   — delete the `copilot)` mock (2803-2823), `test_copilot_stdin_contract`
   (4110) and its call (5568), `copilot` from `CLI_AGENTS` (3300), the
   copilot error-marker/empty cases (3465-3495), and the copilot-only
   assertions in the argv/EXIT/findings tests (2868-2915). Rework, not delete,
   the tests that pair `codex,copilot` so they keep a two-agent case with
   `codex,claude`: timeout (2944), concurrency (2966, three agents become
   `codex,claude` plus gemini only if the mock exists, otherwise two), missing
   CLI (3153-3169), interrupted-run signal test (3236-3263), partial failure
   (4219-4228). Add regression tests: (a) `--agents copilot` exits 2 and the
   message names `claude, codex, gemini` (sorted); (b) `--agents codex,copilot`
   exits 2 before any agent runs; (c) `--agent copilot` exits 2 with the same
   list; (d) `_cli_review.sh copilot <bin> <prompt> <findings>` is rejected as
   an unsupported agent (run the helper directly; check its usage-failure exit
   code in the script before asserting). Each new test must also assert no
   findings file was written and no copilot mock was invoked.
3. **Skill** (`.claude/skills/review-code/SKILL.md`) — agent list at 93 drops
   Copilot; the "Not ported" note (97-98) is reworded so the Copilot-CLI
   specialist is "not ported, and dropped by owner decision (#344)"; remove the
   `copilot-cli` → `copilot` alias and `copilot` from the canonical keys
   (364-365), and add one sentence saying a Copilot CLI session as the caller
   maps to no reviewer to exclude, so it dispatches all three; the three
   example `--agents` lines (376-381) become `gemini,codex` style; the "e.g.
   Copilot while its quota is exhausted" example (385) uses another agent;
   helper description (425) says codex/claude. Leave the run-issue,
   triage-reviews and onboard-project Copilot text alone (hosted review).
4. **Docs** — AGENTS.md, the two approved rows only: `_cli_review.sh` for
   codex/claude (drop `/copilot`); `Codex / Claude turn` and remove
   "copilot's `-s` response". ADR-0015: add a Status-line note (ADR-0008
   cross-reference addendum), "Copilot CLI dropped as a reviewer by owner
   decision 2026-10-13 (#344); the dispatch structure is unchanged", leaving
   Context, Decision item 3 and the Consequences as the record of what was
   true then.
5. **Verify** — `grep -rIi copilot` outside `work-plans/` and the
   inspiration digests and classify every remaining hit as framework identity,
   hosted review, or history; run `.agent/scripts/tests/run_script_tests.sh`
   (name the suites that ran, including `test_cross_model_review.sh`); run
   `shellcheck` on the two scripts if the pre-commit config does; run
   pre-commit. In the PR description list the two AGENTS.md edits (already
   approved), state that hosted Copilot review wiring is intentionally
   untouched, and note #342's title still lists Copilot (retitle after merge).

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/_cli_review.sh` | Delete copilot arm, whitelist entry, usage/header/verified-against text |
| `.agent/scripts/cross_model_review.sh` | Remove `AGENT_BINS` entry, helper condition, comments/usage; sorted "Supported agents" list |
| `.agent/scripts/tests/test_cross_model_review.sh` | Remove copilot mock/tests; rework `codex,copilot` pairs to `codex,claude`; add four rejection regression tests |
| `.claude/skills/review-code/SKILL.md` | Step 5e agent list, alias table, examples, not-ported note, helper description |
| `AGENTS.md` | Two Script Reference rows only (owner-approved) |
| `docs/decisions/0015-parallel-sync-is-the-only-review-dispatch-mode.md` | Status-line addendum note |

No change: `.agent/knowledge/review_depth_classification.md` (its only hit is
the adapter file path; the issue's bullet is a no-op), `docs/design.md`,
`docs/roadmap.md` (`update_roadmap.sh` marks done at merge),
`.github/copilot-instructions.md` and the Copilot identity rows
(`framework_config.sh`, `detect_*`, `set_git_identity_env.sh`,
`check-commit-identity.py`), `merge_pr.sh`, `run-issue`, `triage-reviews`.

## Prior Art

Nothing new is built. The removal follows the earlier pattern of withdrawing a
reviewer path (the `AGENT_KILL_AFTER=0` exception in ADR-0015, #363, recorded
as a Status-line note rather than a body rewrite) and reuses the existing
generic "Unknown agent" validation instead of adding a copilot-specific
error. Rejected: a dedicated "copilot was removed" error message (extra code
for a reviewer nobody invokes; the sorted supported list is enough and is what
the issue asks for), and rewording ADR-0015's body (ADR-0008 allows only
cross-reference addenda).

## Serves

Quality of the work (reviewers that add independent signal, not same-model
repeats) — `docs/design.md#review-loop-and-timeline`.

## Design Picture

No change to the design picture. `docs/design.md` names no Copilot CLI reviewer
(line 448 says only "Reviewers outside Claude"); the ADR-0015 register row
("in force") stays accurate.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Only what's needed | Removes an unverified, redundant reviewer arm on a recorded owner decision |
| A change includes its consequences | Table above lists every file naming the CLI as a reviewer; step 5 greps for leftovers |
| Test what breaks | Rejection regression tests for both flags and the helper; paired-agent tests reworked so two-agent coverage survives |
| Know whether it works | Full `run_script_tests.sh` run, suites named in the report |
| Tool-neutral | Copilot stays as framework identity/adapter and hosted reviewer; only the CLI reviewer role goes |
| Verify before claiming | Helper exit code and line numbers re-read from the code before asserting |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0015 (parallel sync dispatch) | Yes | Dispatch structure unchanged; Status-line note only |
| ADR-0008 (cross-reference addenda) | Yes | Governs why the ADR-0015 edit is a Status note, not a body rewrite |
| ADR-0013 (progress.md vocabulary) | No | Hosted Copilot review still consumed as External Review |
| ADR-0017 (design doc current picture) | Checked, no | No design section changes |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Reviewer set in `cross_model_review.sh` | review-code step 5e, AGENTS.md rows, ADR-0015, tests | Yes |
| `AGENT_BINS` key list | "Supported agents" message (now sorted) | Yes |
| Caller alias table | Copilot-CLI caller maps to no exclusion | Yes (one sentence) |
| Reviewer roster | #342 title/body still lists Copilot | No — follow-up after merge (PR note) |

## Open Questions

- None blocking. The helper's exit code for an unsupported agent is read from
  `_cli_review.sh` at implementation time and asserted as found.

## Estimated Scope

Single PR, four commits.
