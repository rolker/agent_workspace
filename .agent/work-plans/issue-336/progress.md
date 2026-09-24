---
issue: 336
---

# Issue #336 — Gemini (agy) reviews fail on real branches: headless read_file denied, output-token limit on large prompts

## Issue Review
**Status**: complete
**When**: 2026-09-23 14:31 -04:00
**By**: Claude Code Agent (claude-sonnet-5)

**Issue**: #336

### Scope Assessment

**Well-scoped?** Yes, for the primary Gemini fix — two concrete failure modes (headless `read_file` denial, output-token-limit truncation) with a clear acceptance test (a Deep-tier branch review completing with a real Gemini review). The owner-approved addendum (claude arm of `_cli_review.sh` misreading `.error` vs `.errors`) is a distinct root cause bundled into the same issue; verified against `.agent/scripts/_cli_review.sh` lines ~332-334 (fails on non-zero exit before reading JSON) and ~367 (`read_claude_field ERROR_MSG '(.error // "") | ...'`) — the comment's description matches the code exactly. Bundling is defensible (same failure class: helper misreads its CLI's real output) but the two fixes touch different scripts (`_agy_review.sh`/`cross_model_review.sh` vs `_cli_review.sh`) and should land as separate commits/PRs-worth of diff within the branch so review isn't conflating two root causes. The comment already declines a retitle — noted as an accepted decision, not a gap.

**Right repo?** Yes — workspace infra (`.agent/scripts/`).

**Dependencies**: #320 (already merged per current `main`), #313, #288 (both referenced, prior art for the denial-handling pattern), #340 (source of the claude-arm addendum), #342 (broader external-reviewer contract, explicitly ordered *after* this issue — correct sequencing, #336 should not absorb #342's isolation/schema/size-gate scope).

### Correction to prior framing

One piece of context this review was given is inaccurate against current code: the "## Tool Use" section containing "You may read files in the repository for surrounding context" is **not** shared across all agents. In `cross_model_review.sh` (~line 1113), that block is appended only when `agent == "gemini"`, with an explicit comment: "Not added for codex/claude/copilot — codex reads files through the shell, so the line would cost it context." So a Gemini-only prompt change (e.g., removing the file-read line, per the issue's own second option) carries no risk to codex/claude/copilot — the isolation is already in place. The plan should not spend effort re-deriving or preserving this isolation; it already exists.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Test what breaks | OK | Issue explicitly requires mock coverage for both new failure shapes and replacing the claude mocks with live-captured shapes (confirmed stale: `test_cross_model_review.sh` ~line 3266 encodes an `.error` shape not reproduced against claude 2.1.280's actual `.errors` array). |
| Enforcement over documentation | OK | Fix targets the helper scripts and their test mocks directly, not a doc-only change. |
| A change includes its consequences | Watch | Per the review guide's consequences map, touching `cross_model_review.sh` should also prompt a check of `.agent/knowledge/review_depth_classification.md` — likely a no-op here since this is a bug fix, not a depth-tier change, but the plan should confirm rather than assume. |
| Human control and transparency | OK | The `~/.gemini/antigravity-cli/settings.json` permission-allow option is correctly framed in the issue as the owner's machine-config call, not something to be silently added by the agent. |
| Only what's needed | Watch | The issue leaves both the read_file-permission route and the prompt-change route open ("decide in the plan"); the plan-review gate should confirm the implementer picked one deliberately rather than doing both, and that it didn't reach for #342's fuller contract (no-file-tools + size gate) when the narrower prompt tweak suffices for #336. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0015 — Parallel sync is the only review dispatch mode | Yes | Touches `cross_model_review.sh` and `_agy_review.sh`/`_cli_review.sh` (per-agent helpers). Fix must preserve one background job per agent, per-agent timeout, and the own-marker/own-`EXIT=`-line failure contract — nothing here appears to require changing that shape, but the plan should say so explicitly. |
| 0013 — progress.md entry-type vocabulary | No | No progress.md schema change implied. |
| 0009 — Python package management | No | Not applicable (bash/jq). |

### Consequences

- If the output-token-limit fix adds a length instruction to the gemini prompt or a continue/retry path in `_agy_review.sh`, confirm `.agent/knowledge/review_depth_classification.md` doesn't need a corresponding note (Deep-tier prompt size is the trigger condition here).
- The claude-arm mock replacement (owner's addendum) should record the CLI version alongside each captured shape, as the comment itself specifies — this is a testable acceptance item, not just a nice-to-have.

### Recommendations

- Keep the Gemini fix and the claude-arm `.error`/`.errors` fix as clearly separable diffs/commits inside one branch, since they are unrelated root causes bundled by convenience, not by shared code path.
- Have the plan state explicitly which of the two Gemini options (permission allow-rule vs. prompt change) it is taking, and why — the issue defers this decision to the plan, so review-plan should treat an unaddressed choice as a gap.
- When replacing the claude test mocks, keep the existing `.error`-shape assertions if they still exercise a real (if rarer) shape, rather than deleting the only coverage for a string-valued `.error`; add the newly-discovered `.errors` array as additional cases.

### Actions
- [ ] Keep the Gemini fix and the claude-arm `.error`/`.errors` fix as clearly separable diffs/commits inside one branch, since they are unrelated root causes bundled by convenience, not by shared code path.
- [ ] Have the plan state explicitly which of the two Gemini options (permission allow-rule vs. prompt change) it is taking, and why — the issue defers this decision to the plan, so review-plan should treat an unaddressed choice as a gap.
- [ ] When replacing the claude test mocks, keep the existing `.error`-shape assertions if they still exercise a real (if rarer) shape, rather than deleting the only coverage for a string-valued `.error`; add the newly-discovered `.errors` array as additional cases.

## Checkpoint
**Status**: complete
**When**: 2026-09-23 14:38 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

Owner chose "Prompt change (Recommended)" for the Gemini fix: give Gemini the diff and plan inline with no file tools (a "do not simulate tools; name missing context" instruction), a concise-output instruction, and treat an output-token cutoff as a clear failure; no change to machine config (no agy read_file allow rule). The three review actions stand: separate commits for the Gemini fix and the claude-arm .errors fix; the plan states this chosen option; keep the old .error mock cases and add live-captured .errors shapes.

## Plan Authored
**Status**: complete
**When**: 2026-09-23 14:46 -04:00
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-336/plan.md` at `a122288`

Two separable fixes on this branch: (1) Gemini prompt change — no file-reading
instruction, an explicit "no file tools, do not simulate, name missing
context" instruction plus a concise-output instruction, and a precise
output-token-cutoff reason in `_agy_review.sh` — matching the owner's
checkpoint decision; no read_file permission allow-rule. (2) claude arm of
`_cli_review.sh` parses its JSON result before failing on exit status and
prefers `.errors` (array) over `.error`, using three live-captured claude
2.1.281 failure shapes (bad `--model` 404, `--max-turns`, `--max-budget-usd`)
captured in this session, all of which exit 1 with the real reason only in
the JSON body. Tests add matching mock cases for both fixes while keeping
existing `.error`-shape coverage. Acceptance includes one live
`cross_model_review.sh --branch --agents gemini` run on a Deep-sized diff.

## Plan Review
**Status**: complete
**When**: 2026-09-23 14:51 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #336 — Gemini (agy) reviews fail on real branches: headless read_file denied, output-token limit on large prompts
**Plan**: `.agent/work-plans/issue-336/plan.md` at `a122288`
**Branch**: `feature/issue-336`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Four files, two separable commits, no #342 (isolation / schema / pinned model) or #344 (Copilot removal) content. |
| Issue alignment | Needs work | Owner's "Prompt change" option taken as decided. Gaps: the issue's reason fields `terminal_reason` / `api_error_status` are dropped; the "success" shape asked for in the mock replacement is not captured; the live acceptance step cannot produce a Deep-sized diff as written. |
| File targeting | Needs work | Right four files, but the stale gemini-block comment in `cross_model_review.sh` and the existing gemini/codex prompt-isolation test are not listed. |
| Consequences | Needs work | "None identified" misses the comment at `cross_model_review.sh` ~1111-1114 ("Reading files is permitted, so the reviewer keeps that"), which the change makes false. |
| Principle alignment | Needs work | "Test what breaks": the no-truncated-review guarantee and the non-JSON + non-zero-exit path are untested. "Verify against source": the plan claims `.error` is "still real" for `error_during_execution` with no capture to back it. |
| ADR compliance | Good | ADR-0015 per-agent job, timeout and `EXIT=` contract unchanged; ADR-0013 not triggered. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Principle alignment — claude arm reorder]** Moving the `CLI_EXIT -ne 0` check after the JSON-object check changes the reason for a CLI that dies with no JSON output (e.g. SIGKILL/OOM → exit 137, empty stdout). The reason goes from `claude exited 137` plus `bound_note` / `marker_note` to `claude did not emit a JSON result object`, and the exit code and bound are lost. That is the same kind of reason-loss this issue fixes. The non-JSON branch must keep `claude exited ${CLI_EXIT}$(bound_note)$(marker_note …)` when the exit status is non-zero, with a mock test (`MOCK_CLAUDE_RAW=''` or non-JSON plus `MOCK_CLAUDE_EXIT=137`). Also include the exit code in the is_error/subtype reason when it is non-zero.
2. **[Issue alignment — reason fields]** The issue's fix checklist says to take the reason from `.errors | join("; ")` (with `.error` as fallback), **`terminal_reason`, `api_error_status`** and `.result`. The plan reads only `.errors`, `.error` and `.result`. The captured bad-model shape carries `api_error_status: 404`, and that should appear in the reason. Add both fields to `CLAUDE_DETAIL`, only when present, and assert `404` in the bad-model test.
3. **[Principle alignment — robust `.errors` read]** `(.errors // []) | join("; ")` makes jq fail when `.errors` holds non-strings (jq `join` rejects objects), or when `.errors` is a string, not an array. `read_claude_field` would then turn a real `is_error` reason into the generic "could not be read (.errors)". Use `(.errors // []) | if type == "array" then map(if type == "string" then . else tojson end) | join("; ") else tostring end`, and add one test with an object element.
4. **[Issue alignment — verbatim captures]** The plan's three shapes are abbreviated (`"result": "There's an issue with the selected model ..."`, and only 4-5 of the object's fields), so the implementer cannot paste them verbatim. Re-capture all three against claude 2.1.281 (installed here; each capture costs almost nothing). Also capture a **success** result, which the issue lists. Paste each full JSON object as the `MOCK_CLAUDE_RAW` value, with the `claude --version` string in each test's comment. Session ids or cost fields may be scrubbed, but no field may be dropped or restructured.
5. **[Principle alignment — unverified `.error` claim]** The plan says the kept `.error` mocks exercise "a real shape (`error_during_execution`)". Nothing captured supports that. The existing `error_max_turns` + `.error: "max turns exceeded"` mock (test file ~line 3278) directly contradicts the live max-turns capture (`.errors` array, `result: null`). Keep both cases, as the owner decided, but relabel their comments as synthetic fallback coverage for the `.error` branch. Do not describe them as observed CLI output.
6. **[Principle alignment — the output-cutoff case must never pass as a review]** The existing `MOCK_AGY_ERROR` mock always sends `response: ""`. A real cutoff probably comes with a **partial, non-empty** `.response`. Add a mock case with `status: "ERROR"`, a non-empty partial response and the cutoff message. Assert `EXIT=1`, assert the findings file holds the failure reason, and assert it does **not** contain the partial response text as a review. Say explicitly that agy's continue/retry path is not taken; a cut-off turn is always a failure.
7. **[Approach — cutoff detection source]** Match the cutoff phrase against `ERROR_MSG` and the agy stderr only, not `.response`. A review of a diff that contains the phrase (this branch's own diff does) would otherwise get the token-limit reason for an unrelated ERROR. The plan also does not record where agy actually puts the cutoff text (`.error` string vs `.error.message` vs stderr). Mirror the real #320-run shape if it can be recovered; otherwise say the mock is modelled on the issue text.
8. **[Consequences — stale comment]** Update the comment above the gemini heredoc in `cross_model_review.sh` (~lines 1111-1114: "Reading files is permitted, so the reviewer keeps that."). After this change it is false. List it in Files to Change.
9. **[Approach — prompt wording accuracy]** "Has no file-reading tool available" is inaccurate: agy has `ViewFile`, and headless mode denies it. Word the instruction as "do not call any tools (file reads and shell commands are denied in this headless session and end the review with no output)", and keep the existing "Do NOT run shell commands" sentence. Say where missing context goes (the `### Summary`, or a `suggestion` row), so it cannot add a section outside the Output Format that the parser expects. Keep the concise-output text in the gemini-only heredoc; do not edit the shared `PROMPT_FOOTER`.
10. **[File targeting — prompt isolation test]** The plan lists no test for the prompt change. Extend the existing gemini-vs-codex prompt test (test file ~lines 1185-1210). Assert that the gemini prompt contains the new no-tools and concise instructions and no longer contains "You may read files". Assert that the codex and claude prompts contain neither instruction. That makes "stays Gemini-only" enforced, not just asserted.
11. **[Issue alignment — live acceptance not executable as written]** This branch's diff will be a few hundred lines, far from #320's ~57 KB Deep-tier prompt. "Pad by including this plan's own diff history" cannot work, because `.agent/work-plans/**` is excluded from the embedded diff. Make the step concrete. Create a detached scratch worktree at #320's branch tip (`48b0d82^2`). From it, run this branch's script by absolute path: `…/issue-workspace-336/.agent/scripts/cross_model_review.sh --branch 48b0d82^1 --agents gemini --no-progress`. The implementer confirms the base argument accepts a SHA and that helpers resolve from the script's own dir. Record the prompt size in bytes, the `agy --version`, `EXIT=`, and the first lines of the findings file in the progress entry, then remove the scratch worktree. If the run fails, the entry says so; it is not recorded as accepted.
12. **[Issue alignment — optional claude live check]** No live check is planned for the claude arm. It is cheap to add one: a two-line wrapper bin that execs `claude --model no-such-model "$@"`, passed as `<bin>` to `_cli_review.sh claude`. The findings file should then carry the 404 reason rather than `claude exited 1`. Record the result alongside the gemini acceptance.

### Summary

The owner's option is followed correctly. The Gemini change stays Gemini-only, and nothing from the reviewer-isolation work (#342) or the Copilot CLI removal (#344) leaks in. Any non-SUCCESS agy status still fails, so a cutoff cannot pass today. But the plan's claude-arm reorder would lose the exit code for a no-JSON crash. The plan also omits `api_error_status` / `terminal_reason`, gives the "verbatim" captures only in abbreviated form, leaves the partial-response cutoff case and the prompt isolation untested, and has a live acceptance step that cannot produce a Deep-sized diff. Fix these in the plan (or as implementer instructions) before implementation.

### Recommended Actions

- [ ] Keep `claude exited ${CLI_EXIT}` plus `bound_note` / `marker_note` in the reason when stdout is not a JSON object and the exit status is non-zero, and include the exit code in the is_error/subtype reason. Add a mock test for no JSON + exit 137.
- [ ] Add `api_error_status` and `terminal_reason` to the claude reason detail (when present), and assert `404` in the bad-model test.
- [ ] Read `.errors` type-safely (array of any element type, or a string) so a real is_error reason never degrades into "could not be read". Add one object-element test.
- [ ] Re-capture the bad-model, max-turns and max-budget shapes plus a success shape against the installed claude (2.1.281). Use the full JSON objects verbatim as `MOCK_CLAUDE_RAW`, with the CLI version in each test comment.
- [ ] Relabel the two kept `.error` mock cases as synthetic fallback coverage, not observed CLI output.
- [ ] Add an agy mock case with status ERROR, a non-empty partial `.response` and the cutoff message. Assert EXIT=1 and that the partial text is not recorded as a review. State that agy's continue path is not taken.
- [ ] Match the cutoff phrase on `ERROR_MSG` and stderr only, not `.response`. Record where agy actually puts the cutoff text, or say the mock is modelled on the issue text.
- [ ] Update the stale "Reading files is permitted" comment above the gemini heredoc in `cross_model_review.sh`, and list it in Files to Change.
- [ ] Reword the Gemini instruction to "do not call any tools" (not "no file-reading tool available"). Direct missing-context notes into the Summary. Keep the concise-output text in the gemini-only heredoc, not the shared footer.
- [ ] Extend the existing gemini-vs-codex prompt test: the gemini prompt has the new instructions and no "You may read files"; the codex and claude prompts have neither.
- [ ] Replace the live acceptance step with a concrete run of this branch's script against #320's range (`--branch 48b0d82^1` from a detached scratch worktree at `48b0d82^2`, `--agents gemini --no-progress`). Record the prompt size, `agy --version`, `EXIT=` and the head of the findings file, then remove the scratch worktree.
- [ ] (Optional) Add a live claude check through `_cli_review.sh` with a bad-model wrapper bin, confirming the 404 reason reaches the findings file.

## Checkpoint
**Status**: complete
**When**: 2026-09-23 14:55 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: plan
**Decision**: revise

Revise the plan (Recommended): fold in all 12 items from the plan review at ce728e4, including the optional live claude bad-model check; then one more plan review.

## Plan Authored
**Status**: complete
**When**: 2026-09-23 15:04 -04:00
**By**: Claude Code Agent (claude-sonnet-5)
**Dispatch**: resumed (agent a77946816a6f43db3, resume 1 of 3)
**Plan**: `.agent/work-plans/issue-336/plan.md` at `3f4249c`

Revision 2, folding in all 12 Recommended Actions from the `## Plan Review`
at `ce728e4` per the owner's checkpoint. Key changes from revision 1: the
claude-arm reorder now keeps `claude exited ${CLI_EXIT}` (with bound/marker
notes) when stdout is not JSON and the exit is non-zero, and adds a new
terminal check for a clean-looking JSON result that still exited non-zero;
`api_error_status` and `terminal_reason` are added to the reason; the
`.errors` read is type-safe against non-string array elements; all three
claude failure shapes (bad `--model` 404, `--max-turns`, `--max-budget-usd`)
plus a success shape were re-captured in full against the installed claude
2.1.281 (pasted verbatim into the plan, session_id/uuid scrubbed) via
`claude --version`; the two kept `.error` mocks are now labelled synthetic
fallback coverage, not observed output; the agy cutoff phrase now matches
only `ERROR_MSG`/stderr (never the model's own response text), with a new
partial-response test and an explicit note that the real agy field
placement could not be captured live and the mock is modelled on the
issue's quoted text; the stale "Reading files is permitted" comment is now
in Files to Change; the Gemini instruction is reworded to "do not call any
tools" with missing-context routed to the Summary, and the concise-output
text stays in the gemini-only heredoc; the existing prompt-isolation test
is extended to assert the new/removed instructions rather than just the
old ones; and the live acceptance step is now concrete — a detached scratch
worktree at `48b0d82^2` reviewed against base `48b0d82^1` (#320's merge,
verified this session at 268,391 bytes of diff, Deep-tier), plus the
optional live claude bad-model wrapper check via `_cli_review.sh` directly.

## Plan Review
**Status**: complete
**When**: 2026-09-24 10:16 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #336 — Gemini (agy) reviews fail on real branches: headless read_file denied, output-token limit on large prompts
**Plan**: `.agent/work-plans/issue-336/plan.md` at `3f4249c`
**Branch**: `feature/issue-336`

Round 2. The 12 items from the round-1 review at `ce728e4` are all addressed in the plan text; item 7's control test is weak (finding 1 below). Main's state: the branch's merge-base is `48b0d82`. Everything on `origin/main` since then (#334's docs moves and roadmap/governance script changes) leaves the four files this plan edits untouched: `cross_model_review.sh`, `_agy_review.sh`, `_cli_review.sh` and `test_cross_model_review.sh`. The plan references none of the renamed docs, so nothing in it is invalidated. Merge main before the PR as usual.

### Round-1 items

| # | Item | Addressed |
|---|---|---|
| 1 | No-JSON + non-zero exit keeps `claude exited N` + bound/marker; exit code in is_error/subtype reason; exit-137 test | Yes |
| 2 | `api_error_status` / `terminal_reason` in reason; `404` asserted | Yes |
| 3 | Type-safe `.errors` read; object-element test | Yes |
| 4 | Full verbatim captures (3 failures + success), CLI version in test comments | Yes (see finding 5 on a provenance claim) |
| 5 | Relabel kept `.error` mocks as synthetic | Yes |
| 6 | Partial-response cutoff mock; not recorded as review; continue path never taken | Yes |
| 7 | Match cutoff on `ERROR_MSG`/stderr only; say mock is modelled on issue text | Yes in approach; the control test cannot exercise it (finding 1) |
| 8 | Stale "Reading files is permitted" comment in Files to Change | Yes |
| 9 | "Do not call any tools" wording; missing context to Summary / suggestion row; gemini-only heredoc | Yes |
| 10 | Extend `test_prompt_tool_use_guidance` for gemini/codex/claude | Yes (`make_mock_agent claude` already exists) |
| 11 | Concrete detached-worktree acceptance run against #320's range | Yes (verified `--branch <sha-expr>` resolves via `git rev-parse --verify`; size figure wrong, finding 3) |
| 12 | Optional claude bad-model wrapper check | Yes |

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Four files, two commits, nothing from the reviewer-isolation work (#342) or the Copilot CLI removal (#344). |
| Issue alignment | Good | Owner's "Prompt change" option, both failure shapes, and the live Deep-sized acceptance all covered. |
| File targeting | Good | One missed line in `_agy_review.sh` (finding 2), already inside a listed file. |
| Consequences | Good | Stale comment now listed; `review_depth_classification.md` correctly ruled out; AGENTS.md Script Reference text for `_cli_review.sh` stays accurate (failure signals unchanged). |
| Principle alignment | Needs work (minor) | "Test what breaks": the phrase-source control test cannot fail (finding 1). |
| ADR compliance | Good | ADR-0015 per-agent job / timeout / `EXIT=` contract unchanged; ADR-0013 not triggered. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Principle alignment — vacuous cutoff control test]** (medium) Approach 4's third case uses agy status `SUCCESS` with the phrase in the diff. The cutoff matcher only runs inside the `STATUS != "SUCCESS"` branch (`_agy_review.sh:249`), so this test passes whether the matcher reads `RESPONSE` or not. It cannot detect the regression round-1 item 7 was about. Replace it with, or add, a case that has status `ERROR`, an unrelated `MOCK_AGY_ERROR` (e.g. "quota exceeded for model"), and a `MOCK_AGY_ERROR_RESPONSE` containing "response was cut off because it exceeded the output token limit". Assert the reason is the generic `result status ERROR: …quota exceeded…` and does not contain the cutoff reason line.
2. **[File targeting — denial reason text]** (low-medium) `_agy_review.sh:254` explains every empty-response denial with "The reviewer needs the diff only; it must not run shell commands." For the issue's own failure (a `ViewFile` / `read_file` denial) that text is wrong. Reword it to the new policy, e.g. "it must not call any tools (file reads and shell commands are both denied headlessly)". Assert the new wording in the planned ViewFile denial test. That test also needs a mock knob for the denied action's name, because `MOCK_AGY_DENY` hardcodes `RunCommand` (test file ~line 99). The plan adds a knob for the partial response but not this one.
3. **[Issue alignment — acceptance size claim]** (low) 268,391 bytes is the two-dot `git diff 48b0d82^1 48b0d82^2`. The script embeds a three-dot diff (`${BASE_REF}...HEAD`, `cross_model_review.sh:938`) with `.agent/work-plans/**` filtered out. For this range that is about 83.7 KB (`git diff 48b0d82^1...48b0d82^2 -- . ':(exclude).agent/work-plans/**'`: 11 files, +2635/−48). That is still above the issue's ~57 KB reference, so the step stays valid as a Deep-sized run. Correct the figure, and treat the prompt size the script actually reports as the number of record.
4. **[Consequences — acceptance cleanup and stale wording]** (low) `--no-progress` leaves its `mktemp -d` artifact dir behind by design (`cross_model_review.sh:655-669`). Remove it once the prompt size and findings head are recorded. Put the scratch worktree under the session scratchpad, not `/tmp/...`. The phrase "`48b0d82` (current `main` tip)" is now stale: `origin/main` is `529ffa8` after #334. The SHAs themselves are still right.
5. **[Principle alignment — capture provenance]** (low) The plan says the captures ran with "no CLAUDE.md". The max-turns shape's `permission_denials` holds an `agent-status` Bash call, which shows the user-global `~/.claude/CLAUDE.md` was loaded. Correct the claim. When pasting that object into the committed test, consider scrubbing the `tool_input` values and `tool_use_id` (replace the values; keep the fields) so a personal tool path does not land in a public test file. This does not change which branch the shape exercises.

### Summary

Revision 2 addresses all 12 round-1 items. The claude-arm reorder is sound: every live-captured failure still lands in the `is_error` / `subtype` branches, now with the reason; a no-JSON crash keeps its exit code; and every existing `MOCK_CLAUDE_EXIT` use (`test_cli_no_temp_leak`, exit 4 with a success-looking JSON) still fails, through the new terminal branch. What remains is one ineffective control test, one stale denial reason line, and small accuracy fixes in the acceptance and capture notes. The implementer can fold these in without another plan round.

### Recommended Actions

- [ ] Replace or supplement the SUCCESS-status phrase control with an ERROR-status case: an unrelated error message plus a partial response containing the cutoff phrase. Assert the generic reason, not the cutoff reason.
- [ ] Reword the denial reason at `_agy_review.sh:254` to the no-tools policy. Add a mock knob for the denied action name, and assert `ViewFile` and the new wording in the ViewFile test.
- [ ] Correct the acceptance diff size to the script's real embedded diff (~84 KB), and record the script-reported prompt size.
- [ ] Remove the `--no-progress` artifact dir after the acceptance run. Keep the scratch worktree under the session scratchpad. Drop "current main tip" for `48b0d82`.
- [ ] Correct the "no CLAUDE.md" capture claim. Consider scrubbing `permission_denials[].tool_input` / `tool_use_id` values in the committed mock.

## Checkpoint
**Status**: complete
**When**: 2026-09-24 10:22 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

Implement, fold in all 5 (Recommended) — dispatch the implementation in the background; the implementer applies the 5 notes from the round-2 Plan Review at 9865e58 as it goes.

## Implementation
**Status**: complete
**When**: 2026-09-24 10:48 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-336 at `1ce2404`

Merged `origin/main` first (`91cc114`, clean, no conflicts). Plan revision 2 implemented with all 5 round-2 Plan Review findings (`9865e58`) folded in.

- `37ddf47` plan: fold round-2 plan review into #336 plan. Adds the ERROR-status phrase control, the denial reword and its mock knob, the ~83.7 KB three-dot diff size, acceptance cleanup under the scratchpad, and corrected capture provenance. The max-turns `permission_denials` values are now scrubbed in the plan text too.
- `b918899` Gemini reviews: no tools, concise output, name the token cutoff (`cross_model_review.sh`, `_agy_review.sh`, tests).
  - Gemini-only Tool Use section: no tools may be called; the diff and Plan Context are the only material; concise-output instruction. The stale comment above the loop is updated.
  - Precise output-token-cutoff reason, matched on `.error` and stderr only, never on the response.
  - Denial reason reworded to the no-tools policy.
  - New mock knobs: `MOCK_AGY_DENY_ACTION`, `MOCK_AGY_ERROR_RESPONSE`, `MOCK_AGY_ERROR_STDERR`.
- `1ce2404` Claude reviews: read the JSON result before failing on exit status (`_cli_review.sh`, tests).
  - Reports `.errors`, then `.error`, then `.result`, plus `api_error_status` and `terminal_reason`.
  - The exit code is never lost: it is the reason when there is no JSON, it is appended as "(claude also exited N)", and a success-looking JSON with a non-zero exit fails.
  - Type-safe `.errors` read.
  - The four live captures are embedded with ids and tool inputs scrubbed. The two `.error` mocks are relabelled synthetic.

Tests: `test_cross_model_review.sh` 648 passed, 0 failed; hooks passed on every commit. shellcheck `--severity=warning` is clean on all four files. Mutation checks: 14 of 14 caught:
- cutoff matcher also reading RESPONSE
- cutoff detection removed
- stderr channel dropped
- old denial text
- "You may read files" restored
- concise line removed
- tool-use block for all agents
- exit check before the JSON read
- no-JSON exit branch removed
- terminal exit check removed
- naive `.errors` join
- `api_error_status` dropped
- `.errors` dropped from the detail
- exit note dropped

Live acceptance, Gemini (agy 1.2.10, not the 1.2.9 the plan recorded):
- Ran from a detached scratch worktree at `48b0d82^2`: `--branch 48b0d82^1 --agents gemini --no-progress`.
- The embedded diff is 83,710 bytes. The prompt the script wrote is 85,989 bytes; the script does not print the size, so it was measured with `wc -c`.
- Result: `EXIT=0`, completed in about 3 minutes, 492-byte findings. Findings head: "### Findings / No issues found. / ### Summary / The implementation in `_plan_approach.py` and `cross_model_review.sh` is robust ...".
- The failure mode is fixed: no denial, no cutoff. But a no-findings verdict on an 84 KB diff is a thin review; the concise instruction may be over-compressing.
- The run-banner prints an empty branch name ("for branch  (no-progress mode)") from a detached HEAD. This is cosmetic and was already there.
- The artifact dir and the scratch worktree were removed.

Live acceptance, claude bad-model wrapper:
- `EXIT=1`.
- Reason: "claude returned is_error=true (subtype success): There's an issue with the selected model (no-such-model-xyz) ... (api_error_status: 404) (terminal_reason: api_error) (claude also exited 1)".
- The wrapper was removed.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-24 10:53 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-336 at `8176942`
**Base**: main
**Depth**: Standard (reason: behavioural change to the cross-model review helpers, 4 script files, ~370 changed lines excluding work-plans)
**Must-fix**: 0 | **Suggestions**: 3
**Round**: 1 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

### Findings
- [x] (suggestion) Cutoff match ORs "cut off" and "output token limit" across the whole ERROR_MSG + 20-line stderr blob, so unrelated lines (e.g. "connection was cut off" + a stderr banner mentioning the token limit) mislabel the failure as a cutoff; require both phrases on one line and add a test for the split case (failure still fails; only the reason is wrong) — `.agent/scripts/_agy_review.sh:256`
- [x] (suggestion) Soften the concise-output wording: keep "do not restate the diff / cite file:line" (the real token sink), drop the "the whole review is lost" threat, and add "report every finding you have; keep each row short" so brevity applies per row, not to the number of findings — `.agent/scripts/cross_model_review.sh:1140`
- [x] (suggestion) The cutoff shape is modelled on the issue's quoted text, not a live capture; the one case still able to count a truncated reply as a complete review is agy returning status SUCCESS with a cut-off response. State this residual in the PR body and track a live capture as follow-up (not blocking: every non-SUCCESS status already fails) — `.agent/scripts/_agy_review.sh:249` (deferred: owner: goes in the PR body; live capture tracked as follow-up)

### Notes
- Specialists: static analysis (shellcheck --severity=warning on all 4 scripts: clean); governance (AGENTS.md script-table entries for `_agy_review.sh` / `_cli_review.sh` remain accurate; no ADR triggered beyond ADR-0015, which is complied with); plan drift (implementation matches Approach items 1-6; no unplanned files); Claude adversarial (fresh subagent, ran the suite: 648/648 passed; source of the cutoff-match finding; claude JSON-before-exit reorder traced against all four live shapes, no regressions).
- Cross-model (run from this branch, so the Gemini arm ran the NEW `_agy_review.sh` and the new prompt): Gemini failed — API 503 "No capacity available for model gemini-3.8-flash-high"; correctly reported as a failed review through the generic `result status ERROR` path, so it produced no review of this branch. Codex ran — "No issues found" + 2-sentence summary; prompt 47.9 KB. Copilot skipped — quota exhausted this month.
- Flagged point 2 (history): the pre-scrub `permission_denials` object (a `~/.claude/bin/agent-status` command with its status text, and a `tool_use_id`) is in plan commits a122288 / 3f4249c; the tip (37ddf47 onward) and the test file are scrubbed. The branch is not on origin yet, so nothing is public. Low sensitivity (a home-relative path; the id is an opaque, non-credential value; `/home/roland` paths already appear on main in about 10 work-plan files). Owner's call before the first push: push as-is, or rewrite only the unpushed plan commits (non-interactive filter/rebase over main..HEAD, which contains a merge commit) before pushing. A squash merge would not help, because the repo uses merge commits.

## Checkpoint
**Status**: complete
**When**: 2026-09-24 11:09 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: publish
**Decision**: address

Fix 1+2 first (Recommended) — short fix pass: one-line cutoff match + test, softer concise wording; then review round 2 and publish. Suggestion 3 goes in the PR body. History: "Push as is (Recommended)" — do not rewrite the plan commits that hold the agent-status command text and tool-call id.

## Implementation
**Status**: complete
**When**: 2026-09-24 11:23 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-336 at `4b1b0f8`
**Addressed**: Local Review (Pre-Push) at `8176942` (2026-09-24 10:53 -04:00)
**Commits**: 6061321, 7310f24, 4b1b0f8

### Actions
- [x] Cutoff reason now requires "cut off" and "output token limit" on the same line of ERROR_MSG / stderr tail; new test `test_agy_cutoff_halves_on_separate_lines_not_misread` (split case → generic reason, still exit 3); mutation (cross-blob match restored) fails it — `.agent/scripts/_agy_review.sh:256`
- [x] Gemini concise-output wording softened: "whole review is lost" dropped, "Report every finding you have; keep each row short" added, restate-diff / file:line kept; `test_prompt_tool_use_guidance` pins all four; mutation (threat restored) fails it — `.agent/scripts/cross_model_review.sh:1140`
- [x] Live-capture residual (agy SUCCESS with a truncated reply) — `.agent/scripts/_agy_review.sh:249` (deferred: owner: goes in the PR body; live capture tracked as follow-up)

Tests: test_cross_model_review.sh 657 passed, 0 failed; shellcheck --severity=warning clean. Branch history not rewritten (owner decision); nothing pushed.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-24 11:32 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent a128dbd21cf1b0ffa, resume 1 of 3)

**Branch**: feature/issue-336 at `9c03610`
**Base**: main
**Depth**: Standard (reason: behavioural change to the cross-model review helpers, 4 script files; whole-branch classification per #320)
**Must-fix**: 1 | **Suggestions**: 1
**Round**: 2 | **Ship**: continue — round 2: 1 must-fix is a design/correctness concern (not mechanical)

### Findings
- [x] (must-fix) The concise-output prompt does not reliably prevent agy's output-token cutoff: this round's live Gemini run from this branch (50.8 KB prompt, softened wording, gemini-3.8-flash-high) failed with the cutoff, so the issue's core goal (Gemini reviews complete on Deep-sized branches) holds in 1 of 2 live runs. Detection worked exactly as designed. Design call needed: take agy's continue path (its error offers "Please continue ... keeping your response shorter / Retries remaining: 3"), use a lower-thinking model or level for reviews, shrink the Gemini prompt, or accept this and track it as a follow-up — `.agent/scripts/_agy_review.sh:249` / `.agent/scripts/cross_model_review.sh:1140` (deferred: owner: ship detection; reliability tracked in #347)
- [x] (suggestion) The cutoff ERROR shape is now captured live (channel: `.error` as a plain string; text "Your previous response was cut off because it exceeded the output token limit\nPlease continue from where you left off, keeping your response shorter\nRetries remaining: 3"). Replace the "not captured live / not observed" comments with this capture, and add it as a verbatim fixture (a string `.error`, not the mock's `{code,message}` object) — `.agent/scripts/_agy_review.sh:255`, `.agent/scripts/tests/test_cross_model_review.sh:1116`

### Notes
- Fixes from round 1 verified: the cutoff reason now needs both phrases on one line (`grep -qiE`, per-line; spot-checked on 4 strings, including the split case). The Gemini wording drops the "whole review is lost" threat and adds "Report every finding you have; keep each row short". Both are pinned by tests.
- Specialists: shellcheck --severity=warning clean on the 3 changed scripts. Fresh Claude adversarial subagent: no must-fix, 657/657 tests pass, no temp leaks. Its two observations were dropped (pre-existing / harmless).
- Cross-model (run from this branch, so the Gemini arm ran the NEW helper and the softened prompt): Gemini failed — output-token cutoff, named precisely by the new code (live capture above). Codex ran — "No issues found"; it did not run the test suite. Copilot skipped — quota exhausted this month.
- The history point is closed (owner: push as is). The live-capture residual for a SUCCESS status with a truncated reply is still deferred to the PR body; this round's capture covers only the ERROR shape.

## Implementation
**Status**: complete
**When**: 2026-09-24 11:50 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent af505968a635cb8f0, resume 1 of 3)

**Branch**: feature/issue-336 at `a8507c9`
**Addressed**: Local Review (Pre-Push) at `9c03610` (2026-09-24 11:32 -04:00)
**Commits**: 6f95663, a8507c9

Owner decision: "Ship detection, follow-up" — output-token cutoff reliability moves to follow-up issue #347.

### Actions
- [x] Concise-output prompt does not reliably prevent agy's output-token cutoff (live run failed; detection worked) — `.agent/scripts/_agy_review.sh:249` / `.agent/scripts/cross_model_review.sh:1140` (deferred: owner: ship detection; reliability tracked in #347)
- [x] Live cutoff shape recorded: "not captured live / not observed" comments replaced with the capture (`.error` as a plain string, verbatim three-line text); new mock mode `MOCK_AGY_ERROR_STRING=1` and verbatim fixture test `test_agy_live_cutoff_fixture` asserting the cutoff reason; existing object/stderr mock tests kept — `.agent/scripts/_agy_review.sh:255`, `.agent/scripts/tests/test_cross_model_review.sh:1116`

Tests: test_cross_model_review.sh 662 passed, 0 failed; shellcheck --severity=warning clean. Mutations: dropping `.error` from the cutoff source fails 2 (incl. the fixture); reading only `.error.message` fails the fixture's 2 assertions while the object mocks pass. Nothing pushed.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-24 11:55 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved
**Dispatch**: resumed (agent a128dbd21cf1b0ffa, resume 2 of 3)

**Branch**: feature/issue-336 at `3ee52b4`
**Base**: main
**Depth**: Standard (reason: behavioural change to the cross-model review helpers, 4 script files; whole-branch classification per #320)
**Must-fix**: 0 | **Suggestions**: 1
**Round**: 3 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

### Findings
- [ ] (suggestion) The claude "JSON result could not be read" failure omits the exit code and the claude stderr excerpt; before the reorder a non-zero exit was reported first, so this path lost that context. Append the exit note and `log_excerpt 'claude stderr'` (in practice near-unreachable: every field expression is type-safe on a JSON object) — `.agent/scripts/_cli_review.sh:385`

### Notes
- Fix pass verified: the live cutoff shape (`.error` as a plain three-line string) is documented in `_agy_review.sh` and replayed verbatim by `test_agy_live_cutoff_fixture` through the new `MOCK_AGY_ERROR_STRING` mode; the mock shape matches the round-2 capture. shellcheck --severity=warning clean.
- Fresh Claude adversarial subagent: no findings; 662/662 tests pass; no temp leaks.
- Cross-model (run from this branch, so the Gemini arm ran the NEW helper and the softened prompt): Gemini ran and completed on a 52.9 KB prompt with a 6-row review, so the softened wording did not suppress findings. Row 1 was downgraded to the suggestion above. Rows 2-6 were dropped: (2) the `| result:` suffix is empty on every live `.errors` shape and is the planned design; (3) a double space when only api_error_status exists is cosmetic; (4) broadening the cutoff regex to "cutoff" / "cut-off" is not supported by the live capture and widens the false-positive surface; (5) is false, since `assert_not_contains` uses `grep -E`, so `|` is alternation; (6) is not vacuous: "whole review is lost" was this branch's round-1 text, and the assertion guards its removal. Codex ran — "No issues found" (diff only; it did not run tests). Copilot skipped — quota exhausted this month.
- Deferred, per the owner: cutoff reliability goes to #347 ("Gemini (agy) reviews still cut off at the output-token limit on Deep-sized prompts"). The SUCCESS-status truncated-reply residual goes in the PR body.

## Checkpoint
**Status**: complete
**When**: 2026-09-24 12:01 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: publish
**Decision**: publish

Publish now (Recommended) — push and open the PR; body names #347 and the SUCCESS-with-truncated-reply residual; the near-unreachable claude JSON-read suggestion is noted, not fixed.

## Integrated Review
**Status**: complete
**When**: 2026-09-24 12:04 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #348 at `a01b23b`
**Sources**: 2 (Local Review (Pre-Push) round 3 @ `3ee52b4` — head delta to `a01b23b` is progress.md only; CI rollup)
**Cross-source confirmations**: 0
**CI**: pending

### Findings
- [ ] (suggestion, Local Review (Pre-Push) r3) The claude "JSON result could not be read" failure omits the exit code and the claude stderr excerpt; append the exit note and `log_excerpt 'claude stderr'` (near-unreachable: every field expression is type-safe on a JSON object; owner chose to publish without it) — `.agent/scripts/_cli_review.sh:385`

### False positives

### Notes
- GitHub side: 0 reviews, 0 inline comments, 0 conversation comments at `a01b23b`. Copilot quota exhausted for September; its check-run is not a review source.
- Verified the round-3 suggestion still applies at head: the `fail` call at `_cli_review.sh:385` carries only the jq error and claude stdout excerpts.
- Owner-deferred, already ticked in earlier entries: output-token cutoff reliability → #347; agy SUCCESS-with-truncated-reply residual → #347 (both named in the PR body's Decision summary).
- CI at 12:04: Validate Documentation, Validate Adapter Contract, ros-manifest tests pass; Lint (pre-commit) pending (both runs).
- PR body already carries a `## Decision summary`.
