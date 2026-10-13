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
`copilot` in each file before editing. Amended after the Plan Review
(06246fa0): test (d)'s findings-file assertion, the stand-in copilot
marker, the corrected test-rework list, the ADR-0015 note's placement and
wording, and the exact "Supported agents" format.

1. **Scripts** — `_cli_review.sh`: delete the `copilot)` arm (including the
   PENDING-LIVE-CONFIRMATION note), narrow the agent whitelist to
   `codex|claude` and its error text, fix the usage line, header and the
   "Verified against ... copilot 1.0.61" paragraph. `cross_model_review.sh`:
   delete `["copilot"]="copilot"` from `AGENT_BINS`, drop `copilot` from the
   helper-availability condition (line ~602) and from the comments/usage text
   (13, 19, 39, 54, 195, 324, 1444). With the key gone, `--agents copilot` and
   `--agent copilot` already reach the existing "Unknown agent" exit-2 path.
   Make the "Supported agents:" line deterministic: one helper prints the
   keys sorted under `LC_ALL=C`, joined with ", ", and both call sites
   (lines ~497 and ~513) use it instead of associative-array order. The
   exact line is `Supported agents: claude, codex, gemini`.
   Also reword `_cli_review.sh`'s header count ("these three ... a fourth
   case" → two / third) and `cross_model_review.sh`'s "the three agents
   that helper serves" (line ~603).
2. **Tests** (`.agent/scripts/tests/test_cross_model_review.sh`, ~73 mentions)
   — delete the `copilot)` mock (2803-2823), `test_copilot_stdin_contract`
   (4110) and its call (5568), `copilot` from `CLI_AGENTS` (3300) and from
   the mock setup of `test_cli_no_prompt_size_ceiling` (4136). Rework, not
   delete, every test that names copilot as a second or third agent, so
   each keeps its multi-agent case:
   - all-succeed (2865-2918): `gemini,codex,copilot` → `gemini,codex,claude`;
     the copilot argv assertions become claude's (`-p --output-format json
     --permission-prompts none`, prompt not on argv), triplet order and
     findings checks name claude;
   - one-agent-fails (2921-2938): `gemini,codex,copilot` →
     `gemini,codex,claude`;
   - timeout (2941-2960): `codex,copilot` → `codex,claude`;
   - concurrency (2963-2987): two agents, `codex,claude` (the agy mock
     writes `agy.pid`/`agy.end` but no `.start`, so gemini cannot join the
     overlap check); its PASS text becomes "both agents started before the
     first finished";
   - missing CLI and none-usable (3149-3173): the hidden agent is claude,
     `codex,claude`;
   - interrupted-run signal test (3231-3271): `codex,claude`;
   - review-text-never-reclassified (3460-3497): the same four cases run
     against codex (its `-o` final message) instead of copilot, so the
     "text never fails a run" coverage survives;
   - `test_cli_no_temp_leak` (4216-4231): `codex,claude` with the empty and
     non-zero-exit failure modes; its label "success + three failure
     modes" was already wrong after #313 (copilot's ERRMARK case is passed
     through, not failed) and becomes "success + two failure modes";
   - `test_cli_helper_missing_is_unavailable` (4233): its title names
     codex/claude only.

   Add regression tests, each with a stand-in `copilot` script in
   `MOCK_BIN` that only touches a marker file, so "copilot was never
   invoked" is asserted as the marker's absence:
   (a) `--agents copilot` exits 2, stderr names `Unknown agent 'copilot'`
   and the exact line `Supported agents: claude, codex, gemini`;
   (b) `--agents codex,copilot` exits 2 before any agent runs (no codex
   `.start`/`.argv` file either);
   (c) `--agent copilot` exits 2 with the same exact supported line (the
   second print site);
   (a)–(c) exit during argument parsing, so each also asserts no findings
   file was written.
   (d) `_cli_review.sh copilot <bin> <prompt> <findings>` run directly exits
   2 and its findings file holds `unsupported agent 'copilot'` with the
   new "(codex and claude run here; ...)" text: the helper truncates the
   findings file first (line 136) and `usage_fail` writes the reason into
   it before exiting 2 (lines 155-165), so (d) asserts the reason rather
   than an absent file.
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
   "copilot's `-s` response". ADR-0015: append one sentence to the existing
   Status paragraph, after the #363 sentence (ADR-0008 cross-reference
   addendum): the Copilot CLI was dropped as a reviewer by owner decision
   2026-10-13 (#344), the dispatch structure is unchanged, and the Copilot
   mentions in Context, Decision item 3 and the first and last Consequences
   bullets record what was true when the decision was made. The body stays
   as written.
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

- None. The helper's exit code for an unsupported agent is 2, with the
  reason written into the findings file (`usage_fail`, lines 155-165);
  test (d) asserts both.

## Estimated Scope

Single PR, four commits.
