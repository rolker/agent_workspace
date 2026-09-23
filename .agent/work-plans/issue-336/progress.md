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
