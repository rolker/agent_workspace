---
issue: 455
---

# Issue #455 — Owner's email addresses are hardcoded in the identity hook and scripts

## Issue Review
**Status**: complete
**When**: 2026-11-12 12:00 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #455

### Scope Assessment

**Well-scoped?** Yes — one PR: hook, `framework_config.sh`, `detect_agent_identity.sh`, usage text in `set_git_identity_env.sh` / `configure_git_identity.sh`, plus `CLAUDE.md` / `CODEX.md` setup lines, with a test. The issue body plus the owner's follow-up comment (unset email; clone-specific email) cover the cases.
**Right repo?** Yes — all affected files are workspace infrastructure.
**Serves**: Workspace works for anyone who clones it (agent identity and commit attribution) — `docs/design.md#rules` (identity enforcement section of the design).
**Design picture?** No change, provided the design's identity text names no address; check `docs/design.md` mentions of `framework_config` / the hook and update only if they cite the addresses.
**Dependencies**: none blocking. Related: #359 (hook lets agent commits through under the owner's name) and #430 (second-machine install, where this was found).

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Only what's needed | OK | Deriving from `git config user.email` adds no config file, question or override, as the owner directed. |
| Enforcement over documentation | Action needed | Base derivation must strip any `+suffix` from the configured local part. `configure_git_identity.sh` (lines 127-128) writes the agent address into the clone's `user.email`, so in an agent-configured clone the raw configured value is `local+claude-code@domain`. Treating that as the base would build `local+claude-code+codex@domain` and make the hook accept only that family. Base = configured address with any `+...` removed from the local part; accepted = base, or `local+<anything>@domain`. |
| Fail loudly | Action needed | Unset `user.email` (fresh machine) must give a clear message in the hook, `set_git_identity_env.sh`, `configure_git_identity.sh` and `detect_agent_identity.sh` saying to run `git config --global user.email <address>`; no crash, no half-built address (e.g. `+claude@`). Also reject a configured value with no `@` or an empty local part. |
| Per-clone behavior | Action needed | Use plain `git config user.email` run in the checkout (repo-level over global), never `--global`. The hook currently does this but lets `GIT_AUTHOR_EMAIL` win for the commit email; the issue's "configured one, not an environment override" applies to the base, and the commit email checked stays the env one. Keep that split, and test both with a repo-local `user.email`. |
| Agent commits distinguishable (#359) | Watch | If the base is the human's address, a bare `GIT_AUTHOR_EMAIL=<base>` still passes; that is existing behaviour and #359 owns it, but do not widen it. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0004 / ADR-0005 (enforcement layering) | Yes | The hook is the enforcement layer; keep it blocking, only its accepted set changes. |
| ADR-0003 (infrastructure project-agnostic) | Yes | This is the motivation: no owner-specific data in tracked infrastructure. |
| ADR-0017 (design document) | Check | Only if `docs/design.md` quotes addresses. |

### Consequences

- `CLAUDE.md` and `CODEX.md` "Environment Setup" lines change; `CLAUDE.md` is on the Ask First list and needs the owner's yes (also `CODEX.md`, an instruction file). `AGENTS.md` links to them but holds no address.
- `.agent/AI_IDENTITY_STRATEGY.md` (lines 16, 47, 68) uses the owner's addresses as examples; the issue's "no address remains" acceptance covers it, so it is in scope.
- `.agent/knowledge/script_reference.md` and `docs/design.md` mention these scripts; recheck their text.
- `.agent/knowledge/inspiration_ros2_agent_workspace_digest.md`, `docs/roadmap.md`, work-plan records and `test_dispatch_phase.sh` hold addresses or `rolker/` repo slugs; the repo slugs are not email addresses, and the digest/test need a decision (the issue exempts tests and past records).
- CI skips `check-commit-identity` (no `user.email` there), so the new test must set up its own git config in a temp repo.

### Recommendations

- Add a hermetic script test (e.g. `.agent/scripts/tests/test_commit_identity.sh`) covering: arbitrary email passes as human and as `local+x@domain`; another base fails; unset email gives the clear message; repo-local email overrides global; a configured email already carrying a `+suffix` is normalised to the base.
- Put the base-derivation in one place (a small shared helper that the hook and the shell scripts both call) rather than duplicating the parsing in Python and bash.
- Keep the `framework_config.sh` table to suffixes only and update its "Currently configured for" header, and reword the `set_git_identity_env.sh` / `configure_git_identity.sh` examples to a placeholder such as `<you>+codex@<domain>`.
- Ask the owner to approve the `CLAUDE.md` / `CODEX.md` edit (new text: source the script with `--agent claude` / `--detect` or a suffix-only form, naming no address).
- Include a private-data check in the acceptance run: grep tracked non-test files for the owner's local part and domains.

## Plan Authored
**Status**: complete
**When**: 2026-11-12 17:26 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-455/plan.md` at `6415a8ff`

Shared helper derives the base from the checkout's git user.email (suffix stripped, clone value wins, loud failure when unset); hook, config table and three scripts use it; hermetic test; address-free docs; the CLAUDE.md/CODEX.md edit is a last, owner-approval-gated commit.

## Plan Review
**Status**: complete
**When**: 2026-11-12 17:27 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #455 — Owner's email addresses are hardcoded in the identity hook and scripts
**Plan**: `.agent/work-plans/issue-455/plan.md` at `6415a8ff`
**Branch**: `feature/issue-455`

**Owner direction (2026-11-12, received during this review)**: "yes, remove the addresses from CLAUDE.md and CODEX.md". Step 8 is approved for `CLAUDE.md` and `CODEX.md` and is no longer conditional. His yes covers only those two files. `.github/copilot-instructions.md` and `.agent/instructions/` were checked and hold no owner address, so nothing there needs a further yes.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One PR: helper, hook, config table, three scripts, one test, address-free docs; instruction files as a gated last commit. |
| Issue alignment | Needs work | Covers every location in the issue and all review-issue findings (suffix stripping, unset/malformed email, clone-level config, #359 not widened, one shared helper, hermetic test, privacy grep). Serves as written: "Workspace usable by anyone who clones it (agent identity and attribution) — `docs/design.md#identity`". The anchor exists, but the goal is not a section of `README.md#workspace-goals` (finding 3). |
| File targeting | Needs work | All `FRAMEWORK_EMAILS` consumers found (`worktree_create.sh` sources the config but reads only names/models, so it is safe). Missing: `.claude/skills/run-issue/SKILL.md:253`, which has hosts source the identity with an explicit `"<agent email>"`; the host takes that address from `CLAUDE.md` (finding 2). |
| Consequences | Concern | The claim that steps 1-7 stand alone and "the existing 3-arg line still works on the owner's machine" is false on this machine (finding 1). |
| Principle alignment | Good | Fail loudly, only what's needed, enforcement kept blocking, design picture text updated (ADR-0017), test planned; prior art stated. |
| ADR compliance | Good | ADR-0003, ADR-0004/0005 and ADR-0017 are each addressed. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Consequences] (high)**: Step 8 cannot be separated from steps 1-7. I checked without printing the address: this machine's configured `user.email` (global scope, no clone value) has a different base from the address in the `CLAUDE.md` / `CODEX.md` setup lines. Once the new hook is committed on this branch, pre-commit runs it from the working tree. Every commit from an agent that sources the `CLAUDE.md` 3-arg line would then be blocked: the rest of this PR's own implement, review and triage commits, and after merge every Claude and Codex session on this machine. The run-issue host passes the same literal to each phase in `agent_email=`. Resolution: (a) the owner has now approved step 8 (quote above). Land the `CLAUDE.md` / `CODEX.md` edit in the same PR, in the same commit as the hook change or before it, never after it; (b) from the hook commit on, the implementer and host use the derived form (`--agent claude-code` / `--detect`) for their own commits; (c) correct the plan's "stands alone" statement.
2. **[File targeting] (medium)**: `.claude/skills/run-issue/SKILL.md` (identity paragraph, around line 253) tells the host to source `set_git_identity_env.sh "<agent name>" "<agent email>" "<model-id>"`, and the host fills in the email from the instruction file. Switch it to the derived form (`--agent <framework>` plus the model), or document where the email now comes from. Also check `orchestrator/SKILL.md` and `dispatch_phase.sh`'s `agent_email=` handoff text for the same assumption. This is a skill, not an instruction file, so it is not Ask First.
3. **[Issue alignment] (low)**: The `## Serves` line names a goal, "Workspace usable by anyone who clones it", that is not a section of `README.md#workspace-goals`. Name the actual section, likely "Modular" (project-agnostic) or "Easy to use" (setting up is something an agent can do), and keep `docs/design.md#identity`.
4. **[Consequences] (low)**: The step 7 acceptance grep on the two domains also matches a non-owner institutional address in `.claude/skills/brand-guidelines/SKILL.md` (a public contact address, not the owner's). Say that it is expected, so the implementer does not "fix" it. Also, `test_dispatch_phase.sh` (around lines 442 and 446) does hold the owner's real agent address, so the plan's conditional applies: swap it to an `example.org` value.
5. **[Principle alignment] (low)**: For the hermetic test, also set `GIT_CONFIG_NOSYSTEM=1` (alongside `GIT_CONFIG_GLOBAL` and `HOME`), so a system-level `user.email` cannot make the unset-email case pass or fail depending on the machine. Map the new suite in `suites_for_files.sh` for the hook, the helper, `framework_config.sh` and the three scripts.

### Summary

The approach is sound and matches the owner's direction: one helper, derived from the checkout's git email, with clear failures and per-clone config honoured. But the plan's sequencing rests on a false premise. On this machine the hardcoded setup line does not share a base with the configured email, so the hook change blocks agent commits until the instruction-file edit lands. Step 8 is now approved by the owner, so it moves from a conditional last step to a required step ordered with the hook change. The run-issue skill's identity line also belongs in scope.

### Recommended Actions

- [ ] Make step 8 unconditional (owner approved `CLAUDE.md` / `CODEX.md`). Order it with or before the hook commit, and remove the "stands alone" statement.
- [ ] State that from the hook commit on, the implementer and host use `--agent claude-code` (derived email) for their own commits.
- [ ] Add `.claude/skills/run-issue/SKILL.md` (and check `orchestrator/SKILL.md` and the `dispatch_phase.sh` handoff text) to the file list.
- [ ] Fix the Serves goal name to a real `README.md#workspace-goals` section.
- [ ] Note the brand-guidelines grep hit as expected. Swap the `test_dispatch_phase.sh` address to `example.org`. Add `GIT_CONFIG_NOSYSTEM=1` to the test.

## Checkpoint
**Status**: complete
**When**: 2026-11-12 17:28 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (plan review verdict needs-work; first revise at this checkpoint)
**After**: plan
**Decision**: revise

Plan review found one high finding: the instruction-file setup lines and the hook change must land together, because on a machine whose git email has another base the new hook blocks every agent commit that still uses the literal setup line, this pull request's own later phases included. Also: run-issue's skill text and the dispatch handoff pass an explicit agent email and are not in the plan; three low findings. The owner approved the instruction-file edits on 2026-11-12: "yes, remove the addresses from CLAUDE.md and CODEX.md". Revise the plan to address all five findings.

## Plan Authored
**Status**: complete
**When**: 2026-11-12 17:29 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-455/plan.md` at `f93a2b6f`

Revision after plan review: the hook, instruction files, run-issue/onboard-project skill text and the test land in one pivot commit (C3) after the helper and script commits; commits from C3 on use the derived `--agent claude-code "<model-id>"` form. Caller list completed, Serves names the Modular goal, test hermetic with example.org fixtures and a suites_for_files mapping.

## Plan Review
**Status**: complete
**When**: 2026-11-12 17:32 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #455 — Owner's email addresses are hardcoded in the identity hook and scripts
**Plan**: `.agent/work-plans/issue-455/plan.md` at `f93a2b6f`
**Branch**: `feature/issue-455`

Second review, after the revision. The five earlier findings are resolved, checked against the plan and the code. 1 (pivot): the hook, `CLAUDE.md` / `CODEX.md`, the skill text and the new test land together in C3, and the "stands alone" claim is gone. 2 (callers): run-issue:253 and its handoff text, onboard-project:381/409/450 and `test_skill_paths.sh` are in C3. orchestrator has no email. `dispatch_phase.sh` only prints `AGENT_EMAIL` (lines 503-514), so its code needs no change. 3: Serves names "Modular", a real section of `README.md#workspace-goals`. 4: the brand-guidelines hit is marked as expected, and `test_dispatch_phase.sh` gets an `example.org` fixture. 5: the test sets `GIT_CONFIG_NOSYSTEM=1` and is mapped in `suites_for_files.sh`. The two new findings below are about which identity the run uses and when, around the pivot and after the merge.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One PR in four ordered commits. |
| Issue alignment | Good | Every location in the issue and every owner direction is covered: derive from git, no config file, unset email, clone-level email, instruction files. The unset case is tested for the hook, `--agent` and `configure_git_identity.sh`. The clone-level case is tested with a repo-local value over global, and a `+claude-code` clone value normalises to the base. Serves: Workspace goal "Modular" (`README.md#modular`: project-agnostic, no owner-specific data in the infrastructure) — `docs/design.md#identity`. |
| File targeting | Good | A grep of every `set_git_identity_env` caller finds the rest are placeholders or `--agent` / `--detect` (copilot, gemini, `AGENT_ONBOARDING.md`, the `gh_create_*` hints) and hold no owner address. `worktree_create.sh` reads only names and models. |
| Consequences | Needs work | Findings 1 and 2: the host's identity script path during the run, and in-flight branches after the merge. Finding 3: the `docs/design.md` change-log row. |
| Principle alignment | Good | Fails loudly, keeps the hook blocking, adds no config, plans a test, states its prior art, updates the design text. |
| ADR compliance | Good | ADR-0003, ADR-0004/0005 and ADR-0017 are addressed. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Consequences] (medium)**: The host lines in the commit-order section do not match how run-issue sources identity. The run-issue host sources `$WS_ROOT/.agent/scripts/set_git_identity_env.sh` (SKILL.md:253), and `$WS_ROOT` is the main checkout. Until this merges, main's script has the literal table and refuses `--agent <fw> "<model>"` (`$# -ne 2`). So the plan's "the host sources `--agent claude-code "<model-id>"` before C3's phase" cannot work as written. C1, C2 and C3 are one implement phase, and that phase is dispatched before C1 exists. Resolution: say that the implement phase is dispatched with the literal identity and switches to the derived one inside the phase, at C3. From C3 until the merge, the host sources the worktree's script (`<worktree>/.agent/scripts/set_git_identity_env.sh --agent claude-code "<model>"`), not `$WS_ROOT`'s. The phases after that get the derived `agent_email=` and use it in the 3-arg form, which works.
2. **[Consequences] (medium)**: The plan does not handle the reverse case after the merge. Once main has the new instruction lines and script, sessions on this machine derive the address from the machine's git email. Any branch not yet updated from main keeps the old hook in its working tree, and pre-commit runs the hook from there (`entry: python3 .agent/hooks/check-commit-identity.py`). Today that includes `worktrees/workspace/issue-workspace-429`. The old hook rejects the derived address, and its "To fix" advice (`--agent` / `--detect`) produces the same derived address again, so the session loops with no clear way out. The opposite case also needs care: a session still holding the old `CLAUDE.md` text sources the literal and is rejected by the new hook. Resolution: (a) the PR description and the merge step tell the owner to update in-flight branches from main (merge or rebase) before their next commit, naming the open worktrees. (b) The new hook's failure output keeps a "To fix" block that names the configured base and the exact derived command (`source .agent/scripts/set_git_identity_env.sh --agent <framework> "<model-id>"`), and says that an old literal setup line is the likely cause. Add a test assertion for that message.
3. **[Consequences] (low)**: `docs/design.md` requires one change-log row for each change to a section, appended in the same change (the change-log table, around line 790). Step 7 edits Identity (662, 671-672) and the Rules row (160) but plans no row. Add a row for "Rules, Identity" for #455, with the new line count.
4. **[Issue alignment] (low)**: The unset-email test covers the hook, `--agent` and `configure_git_identity.sh`. It does not cover `set_git_identity_env.sh --detect` or `detect_agent_identity.sh`, which are also on the issue review's fail-loudly list. Add one assertion each (exit nonzero, no `AGENT_EMAIL` exported).

### Summary

The revision resolves all five earlier findings, and the pivot-commit design is correct: C1 and C2 pass the old hook with the literal, and C3 passes the new hook with the derived address. What remains is operational. The host's identity during the run has to come from the worktree's script, because main's script cannot take the new form. After the merge, branches not yet updated keep the old hook, which rejects the derived address and gives looping advice. Both need a sentence in the plan and the PR, plus a clear new-hook message, before implementation starts.

### Recommended Actions

- [ ] Rewrite the host lines in the commit-order section. The implement phase is dispatched with the literal and switches to the derived identity at C3. From C3 until the merge, the host sources `<worktree>/.agent/scripts/set_git_identity_env.sh`, not `$WS_ROOT`'s.
- [ ] Add a post-merge step: update in-flight branches from main before their next commit (say so in the PR body). Make the new hook's failure text name the derived command and the stale-literal cause, and test it.
- [ ] Add the `docs/design.md` change-log row for #455.
- [ ] Extend the unset-email test to `--detect` and `detect_agent_identity.sh`.

## Checkpoint
**Status**: complete
**When**: 2026-11-12 17:33 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (second plan review verdict needs-work; second host revise in a row, so the next answer at this checkpoint is the owner's)
**After**: plan
**Decision**: revise

Second plan review: the five earlier findings are resolved. Two new medium findings: (1) the host and the implement phase cannot use the derived identity form from the main checkout's script before the merge, so the plan must say the implement phase starts with the literal form and switches at the pivot commit, and that from then until the merge the host sources the worktree's copy of the script; (2) branches still in flight after the merge run the old hook or hold the old setup line, so the plan needs a post-merge step (update in-flight branches from main before their next commit, also in the pull request body) and new-hook failure text that names the exact derived command and the likely cause, with a test. Two low findings: a docs/design.md change-log row; the unset-email test must also cover set_git_identity_env.sh --detect and detect_agent_identity.sh. Owner, 2026-11-12: "You can update all instruction files if necessary"; "I'm transitioning from using my ccom.unh.edu email address to my unh.edu address, so both are fine."

## Plan Authored
**Status**: complete
**When**: 2026-11-12 17:34 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-455/plan.md` at `fff4b3fa`

Second revision. Run identity: implement pass starts literal (C1, C2) and switches to the derived form from the worktree's script at the pivot commit C3, and the host does the same until the merge. Post-merge step (update in-flight branches from main, also in the PR body) with a new-hook failure message naming the derived command, tested. Design change-log row added. Unset-email test also covers --detect and detect_agent_identity.sh.

## Plan Review
**Status**: complete
**When**: 2026-11-12 17:35 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #455 — Owner's email addresses are hardcoded in the identity hook and scripts
**Plan**: `.agent/work-plans/issue-455/plan.md` at `fff4b3fa`
**Branch**: `feature/issue-455`

Third review, a convergence check. All four findings of the second review are resolved, checked against the plan and the code. 1 (run identity): the commit-order section now says the implement phase is one dispatched pass, started with the literal identity because the main checkout's `set_git_identity_env.sh` refuses `--agent <fw> "<model>"` (`$# -ne 2`, line 108). C1 and C2 use the literal. C3 and every later commit source the worktree's own script in the derived form, and the host does the same from C3 until the merge. The old hook passes C1 and C2, and the new hook (run from the working tree, `.pre-commit-config.yaml:28`) accepts C3, so no commit is blocked. 2 (after the merge): a post-merge section, also in the PR body, says in-flight branches are updated from main before their next commit and names issue 429's worktree. Step 4 has the hook's failure text print the base, the exact derived command and the stale-literal / not-updated-from-main cause, and step 5 tests that text. 3: step 7 and C2 add one `docs/design.md` change-log row for "Rules, Identity" (#455). 4: step 5's unset-email case now covers `--detect` and `detect_agent_identity.sh`. Nothing the earlier reviews confirmed has regressed: Serves still names "Modular", the brand-guidelines hit is still marked as expected, the test is still hermetic with `GIT_CONFIG_NOSYSTEM=1` and `example.org` fixtures and is mapped in `suites_for_files.sh`, and run-issue, onboard-project and `test_skill_paths.sh` are still in C3.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One PR in ordered commits C1..C4+. |
| Issue alignment | Good | Covers every owner direction: derived from git config with no config file, unset email handled, clone-level email honoured, both of the owner's domains accepted through the machine's base, instruction files edited. Serves: Workspace goal "Modular" (`README.md#modular`: project-agnostic, no owner-specific data in the infrastructure) — `docs/design.md#identity`. |
| File targeting | Good | Unchanged from the second review, which confirmed it. |
| Consequences | Good | The run identity, post-merge branches and the change-log row are all covered. |
| Principle alignment | Good | Fails loudly, keeps the hook blocking, adds no config, plans a test, updates the design text. |
| ADR compliance | Good | ADR-0003, ADR-0004/0005 and ADR-0017 are addressed. |
| ROS conventions | N/A | Workspace plan. |

### Findings

None.

### Summary

The plan is ready for implementation. The pivot-commit sequencing works with the scripts as they are today, the post-merge risk is stated and tested, and the earlier findings stay resolved.

### Recommended Actions

- [ ] None before implementation.

## Checkpoint
**Status**: complete
**When**: 2026-11-12 17:36 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

Proceed (Recommended)

## Implementation
**Status**: complete
**When**: 2026-11-12 18:07 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-455 at `d4b4edc3`

Implemented in the plan's commit order; C1 and C2 used the literal setup line, C3 and after the derived `--agent claude-code` form from the worktree's script, and the new hook accepted C3.

- `628aaaef` (C1): new `.agent/scripts/identity_base.py` (base = checkout's `git config user.email`, `+suffix` removed; `agent <suffix>`; unset/malformed exits 1 with the `git config --global user.email` fix). `framework_config.sh` holds `FRAMEWORK_SUFFIXES` plus `framework_email` / `agent_email_for_suffix`; `set_git_identity_env.sh` (`--agent <fw> ["<model>"]`), `configure_git_identity.sh` and `detect_agent_identity.sh` derive through it and fail with nothing exported or written. The `copilot-cli` / `gemini-cli` aliases now also carry the table model (they had none).
- `ff897b1e` (C2): `AI_IDENTITY_STRATEGY.md` gets a "Where the Email Comes From" section and placeholder examples; `docs/design.md` Rules row and Identity section, change-log row for #455 (914 lines); `script_reference.md` rows for the helper, `framework_config.sh`, `configure_git_identity.sh` and the model argument; `docs/roadmap.md` entry reworded; `dispatch_phase.sh` header comment; `test_dispatch_phase.sh` uses an `example.org` fixture.
- `4ffa4b68` (C3, pivot): hook derives its accepted set via the helper and blocks on an unset/malformed configured email; failure text prints the base, `source .agent/scripts/set_git_identity_env.sh --agent <framework> "<model-id>"` and the stale-literal / not-updated-from-main cause. `CLAUDE.md`, `CODEX.md`, run-issue (identity line and `agent_email=` description), onboard-project (3 lines) and `test_skill_paths.sh` switch to `--agent`. New hermetic `test_commit_identity.sh` (39 assertions).
- `d4b4edc3`: `ROOT_READERS` entry for the new suite in `test_script_tests_hook_scope.sh` (found by the final pre-commit run).

Deviation: `suites_for_files.sh` needed no edit; the new suite maps by derivation for the hook, helper, `framework_config.sh` and the three scripts (checked per file).

Checks: final `pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP passed, running all 48 suites (`set_git_identity_env.sh` is a full-run trigger). An earlier run failed once in `test_cross_model_review.sh` (>64 KiB Approach case); the same case also failed once on an export of main and passed on rerun, so it is an intermittent failure not caused by this branch. Acceptance grep for the owner's addresses (excluding tests, work-plans, brand-guidelines) finds none; the inspiration digest keeps three domain-only mentions in a past record, left as the plan says.

Post-merge (for the PR body): update every in-flight branch or worktree from main before its next commit (issue 429's worktree exists today).

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-12 18:13 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-455 at `1886212f`
**Base**: main
**Depth**: Deep (reason: commit-identity hook and identity scripts, enforcement layer plus instruction files, 21 files)
**Must-fix**: 2 | **Suggestions**: 7
**Round**: 1 | **Ship**: continue — round 1: 2 must-fix; first round always re-reviews after fixes

Specialists: static (shellcheck --severity=warning, flake8 on changed files: clean); governance; plan drift; Claude adversarial (empirical probes in temp repos); cross-model gemini (complete), codex (complete); Copilot skipped (disabled for quota). `test_commit_identity.sh`: 39 passed, 0 failed. CI skips the hook (`.github/workflows/validate.yml:24`, verified). Issue 359 (agent commits under the owner's plain address): unchanged, the configured base is still accepted when nothing was sourced. The intermittent `test_cross_model_review.sh` >64 KiB Approach case: not plausibly affected, that suite does not touch the identity scripts or the hook, and this diff does not change `cross_model_review.sh`. Plan drift: none material (`suites_for_files.sh` maps the new suite by derivation, checked per file).

### Findings
- [x] (must-fix) Hook's accepted base can come from the environment: `git -c user.email=X` (GIT_CONFIG_PARAMETERS / GIT_CONFIG_COUNT) with a matching author passes any domain, contradicting the docstring "base never comes from the environment"; read config with those vars stripped and add a test — `.agent/scripts/identity_base.py:36`, `.agent/hooks/check-commit-identity.py:11`
- [x] (must-fix) `detect_agent_identity.sh` assigns AGENT_NAME/AGENT_MODEL (and detect_cli_env exports AGENT_FRAMEWORK) before the email check, so a sourced failure leaves a mixed identity despite the "nothing is exported" contract; derive the email first, test with a pre-exported identity (codex + Claude) — `.agent/scripts/detect_agent_identity.sh:56-76,169`
- [x] (suggestion) A failed re-source of `set_git_identity_env.sh --agent/--detect` leaves the previous session's GIT_*/AGENT_* values exported; unset them on failure or document it — `.agent/scripts/set_git_identity_env.sh:131`
- [x] (suggestion) Tighten `split_base`/`is_accepted`: malformed values report "not set" without the value; `<dev@x>`, `dev@.`, trailing comma accepted; internal whitespace not rejected in `is_accepted` (gemini); shell metacharacters reach the unquoted `.agent/.identity` file (codex) — `.agent/scripts/identity_base.py:61,90`
- [x] (suggestion) GIT_COMMITTER_EMAIL is never checked (pre-existing, cheap to add) — `.agent/hooks/check-commit-identity.py:26`
- [x] (suggestion) `configure_git_identity.sh` derives once from the cwd and writes that address into every `project/*` repo, overriding a repo's own clone-level base; derive per repo — `.agent/scripts/configure_git_identity.sh:146`
- [x] (suggestion) Derivation follows the cwd, not the repo committed in; say "source in the checkout you commit in" in CLAUDE.md / AI_IDENTITY_STRATEGY.md — `.agent/AI_IDENTITY_STRATEGY.md:16`
- [x] (suggestion) Literal "<name>" "<email>" form still the primary instruction in AGENT_ONBOARDING.md and the gh_create_pr/issue unset-identity hints; point to `--agent <framework> "<model>"` — `.agent/AGENT_ONBOARDING.md:16`, `.agent/scripts/gh_create_pr.sh:219`, `.agent/scripts/gh_create_issue.sh:148`
- [x] (suggestion) Empty framework key (`--agent ""`, or `--detect` with an empty detection) hits "bad array subscript" before the friendly error (gemini, Claude) — `.agent/scripts/set_git_identity_env.sh:125,157`

## Implementation
**Status**: complete
**When**: 2026-11-12 18:31 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-455 at `897f03ff`
**Addressed**: Local Review (Pre-Push) at `1886212f` (2026-11-12 18:13 -05:00)
**Commits**: fff11d19, 202514b2, e10719ac, c39a6d58, 3d274ea0, 0d4a9721, fe136d9b, ee80f07c, 897f03ff

### Actions
- [x] (must-fix) Base read from git's config files only: `GIT_CONFIG_PARAMETERS`, `GIT_CONFIG_COUNT`/`KEY_n`/`VALUE_n` and `GIT_CONFIG` stripped (`GIT_CONFIG_GLOBAL`/`NOSYSTEM` kept); the hook checks the effective (`-c`) email as the commit email; tests for COUNT and PARAMETERS injection, helper derivation and an injected value never standing in for an unset base — `.agent/scripts/identity_base.py`, `.agent/hooks/check-commit-identity.py` (fff11d19)
- [x] (must-fix) `detect_agent_identity.sh` detects the framework in a subshell and assigns every AGENT_* only after the email is derived; test: a pre-exported codex identity in a Claude Code session is unchanged after a failed sourced `--export` — `.agent/scripts/detect_agent_identity.sh` (202514b2)
- [x] (suggestion) `set_git_identity_env.sh` unsets the GIT_*/AGENT_* variables it owns on every failure path, documented in its header; test: four failure modes with a pre-exported identity leave all eight unset — `.agent/scripts/set_git_identity_env.sh` (e10719ac)
- [x] (suggestion) Plain-address validation (one `@`, local `[A-Za-z0-9._%+-]`, dot-separated domain labels), used for the base and the accepted check; a malformed value gets its own message that shows it; suffix restricted; `.agent/.identity` written with `printf %q`; tests for 14 malformed values, 3 good ones, rejected commit emails and an `.identity` round trip that runs nothing — `.agent/scripts/identity_base.py`, `.agent/scripts/detect_agent_identity.sh` (c39a6d58)
- [x] (suggestion) Hook also checks `GIT_COMMITTER_EMAIL` when set; tests for a foreign and an accepted committer — `.agent/hooks/check-commit-identity.py` (3d274ea0)
- [x] (suggestion) `configure_git_identity.sh` derives per repository it writes to, all before any write; tests: a clone with its own email keeps its base, one underivable repo writes nothing anywhere; script_reference.md updated — `.agent/scripts/configure_git_identity.sh` (0d4a9721)
- [x] (suggestion) "Source it in the checkout you commit in" in CLAUDE.md, CODEX.md and AI_IDENTITY_STRATEGY.md (with the config-file base, committer check and cleared identity); design.md Rules row updated — `.agent/AI_IDENTITY_STRATEGY.md` (ee80f07c)
- [x] (suggestion) AGENT_ONBOARDING.md and the gh_create_pr.sh / gh_create_issue.sh hints name `--agent <framework> "<model-id>"`; their suites assert the hint — `.agent/AGENT_ONBOARDING.md`, `.agent/scripts/gh_create_pr.sh`, `.agent/scripts/gh_create_issue.sh` (897f03ff)
- [x] (suggestion) Empty framework key tested before indexing in set_git_identity_env.sh, configure_git_identity.sh and framework_email; tests for `--agent ""`, a detection normalising to an empty key, `framework_email ""` and detect_agent_identity.sh's fallback — `.agent/scripts/set_git_identity_env.sh` (fe136d9b)

### Checks
- `pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP: exit 0.
- `test_commit_identity.sh`: 79 passed, 0 failed; `test_gh_create_pr.sh` and `test_gh_create_issue.sh`: 0 failed.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-12 18:36 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent afbf6f45826febd3e, resume 1 of 3)

**Branch**: feature/issue-455 at `7057833f`
**Base**: main
**Depth**: Deep (reason: commit-identity hook and identity scripts, enforcement layer plus instruction files; whole-diff classification kept for round 2)
**Must-fix**: 2 | **Suggestions**: 4
**Round**: 2 | **Ship**: continue — round 2: 2 must-fix include a design/correctness concern (not mechanical)

Scope: the nine round-1 findings and the fix diff `39af5058..7057833f`. All nine are addressed in code with tests; two fixes opened new gaps (findings 1 and 2 below). Specialists: governance and plan drift (no new drift); fresh Claude adversarial (empirical, temp repos, git 2.53.0); cross-model gemini (complete, no issues) and codex (complete, 1 must-fix = finding 2); Copilot skipped (disabled for quota). `test_commit_identity.sh`: 79 passed, 0 failed. Coordinator's checks: (a) uppercase, existing `+suffix`, subdomains, hyphens and digits in the domain and `localhost` are accepted and match the email git uses; apostrophe and non-ASCII addresses are rejected (finding 1); (b) `include.path` and `includeIf "gitdir:"` resolve for the base, also from a linked worktree; `git -c user.email=<base>+x` passes, a foreign `-c` value is rejected with a clear message; a `-c`-only email gets a misleading "not set" (finding 4); (c) no script sources `set_git_identity_env.sh` programmatically (`cross_model_review.sh`, `_cli_review.sh`, `_agy_review.sh` and `dispatch_phase.sh` only read `AGENT_*`); skill snippets chain with `&&` / `|| exit 1`, so clearing on failure cannot clobber a caller mid-flow; (d) `configure_git_identity.sh` writes nothing anywhere when the workspace or any `project/*` repo is underivable, verified; (e) nothing in the tree reads `.agent/.identity`, only docs (`source`, bash): bash reads `%q` back exactly, dash misreads `$'...'` forms (finding 6). Not counted: `--detect` / 2-arg form abort under `set -eu` in `detect_cli_env.sh:23`, unchanged by this branch.

### Findings
- [x] (must-fix) Address validation rejects real addresses (`o'brien@x.ie`, `jürgen@x.de`, `u@bücher.de`; IDN derived correctly in round 1), so the hook blocks every commit in such a checkout, the human's included; the message says "letters" but rejects ü and the limit is stated nowhere. Accept `'` and non-ASCII (the `.identity` file is now `%q`-quoted, so shell safety no longer needs the narrow set) or state the limit in the message and AI_IDENTITY_STRATEGY.md — `.agent/scripts/identity_base.py:41-53`
- [x] (must-fix) The committer is checked only via `GIT_COMMITTER_EMAIL`; git does not export the committer to the pre-commit hook, so `git -c committer.email=foreign@...` or a `committer.email` config passes while the commit records the foreign committer (codex + Claude, both reproduced). Resolve it with `git var GIT_COMMITTER_IDENT` and test — `.agent/hooks/check-commit-identity.py:53`
- [x] (suggestion) A configured `u+@x.org` (empty suffix) gives base `u@x.org`, and the hook rejects the `u+@x.org` git commits with; accept the configured email verbatim — `.agent/scripts/identity_base.py:169`
- [x] (suggestion) An email set only via `git -c` / `GIT_CONFIG_*` gets "git user.email is not set"; say that `-c` values are ignored for the base and it must come from a config file — `.agent/scripts/identity_base.py:35`
- [x] (suggestion) `set_git_identity_env.sh` clears eight variables on failure while `detect_agent_identity.sh` keeps the caller's; state the difference (and the clearing) in `--help` or align them — `.agent/scripts/set_git_identity_env.sh:46`
- [x] (suggestion) `.agent/.identity` via `printf %q` emits `$'...'` for tabs, newlines and non-ASCII under `LC_ALL=C`, which a POSIX sh misreads; write single-quoted values (`'` as `'\''`) or document "bash only"; `AI_IDENTITY_STRATEGY.md` still says to "read" the file, which now shows backslash escapes — `.agent/scripts/detect_agent_identity.sh:206`

## Implementation
**Status**: complete
**When**: 2026-11-12 18:51 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a8ac6eac32c162da8, resume 1 of 3)

**Branch**: feature/issue-455 at `66847592`
**Addressed**: Local Review (Pre-Push) at `7057833f` (2026-11-12 18:36 -05:00)
**Commits**: 356e421e, f5a19d85, 610ba87c, 05f28f52, c2a717c2, 66847592

### Actions
- [x] (must-fix) Validation refuses only what breaks the structure: not exactly one `@`, an empty local part or domain, whitespace or control characters, angle brackets, commas; apostrophes and non-ASCII accepted, and the message states that rule. Tests: `o'brien@x.ie`, `jürgen@x.de` and `u@bücher.de` end to end (base, agent address, set_git_identity_env.sh, hook for human and agent), plus the malformed list and the message text. AI_IDENTITY_STRATEGY.md states the rule. — `.agent/scripts/identity_base.py` (356e421e)
- [x] (must-fix) The hook checks author and committer as git will record them (`git var GIT_AUTHOR_IDENT` / `GIT_COMMITTER_IDENT`, full environment). Tests: `GIT_COMMITTER_EMAIL`, `git -c committer.email=<foreign>`, injected `author.email`, and `committer.email` in config (foreign rejected, accepted agent address passes). Strategy doc and design Rules row updated. — `.agent/hooks/check-commit-identity.py` (f5a19d85)
- [x] (suggestion) The configured address is accepted verbatim. Tests: configured `u+@example.org` passes for human and agent `u+codex@`; an unconfigured `someone+@` is still rejected. — `.agent/scripts/identity_base.py` (610ba87c)
- [x] (suggestion) An email given only through `git -c` / `GIT_CONFIG_*` gets its own message: those values are ignored for the base, which must come from a config file. Tests: hook with `GIT_CONFIG_PARAMETERS`, helper with `GIT_CONFIG_COUNT`, and plain unset keeping the plain message. — `.agent/scripts/identity_base.py` (05f28f52)
- [x] (suggestion) Aligned: `detect_agent_identity.sh` unsets its AGENT_* on failure, like `set_git_identity_env.sh` (and returns rather than exits when sourced without framework_config.sh). Both headers and both `--help` texts state it. Tests: the failed sourced `--export` leaves all four unset; both `--help` outputs checked. — `.agent/scripts/detect_agent_identity.sh`, `.agent/scripts/set_git_identity_env.sh` (c2a717c2)
- [x] (suggestion) `.agent/.identity` is written POSIX single-quoted (`'` as `'\''`). The strategy doc says to source the file. Test: round trip with `bash` and `sh`, written under `LC_ALL=C.UTF-8` and `LC_ALL=C`, with an apostrophe in the email, and an apostrophe, non-ASCII, tab, newline and command substitutions in the model; nothing runs. — `.agent/scripts/detect_agent_identity.sh` (66847592)

### Notes
- Two old hook-reject cases were dropped: `someone+x@example.org,` and `<someone@example.org>` as GIT_AUTHOR_EMAIL. Git strips those characters itself before it records the ident, so the commit carries the clean, accepted address. Both values stay covered as malformed configured emails.

### Checks
- `pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP: exit 0, including the `.agent/scripts/tests/` suite hook (Passed).
- `test_commit_identity.sh`: 92 passed, 0 failed.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-12 18:53 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved
**Dispatch**: resumed (agent afbf6f45826febd3e, resume 2 of 3)

**Branch**: feature/issue-455 at `8a5f68ce`
**Base**: main
**Depth**: Deep (reason: round 3 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 1
**Round**: 3 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Scope: the six round-2 findings and the fix diff `df0c64fd..8a5f68ce` (356e421e, f5a19d85, 610ba87c, 05f28f52, c2a717c2, 66847592). Cross-model: skipped (round-3 convergence check, per handoff). All six round-2 findings are resolved:
- Addresses with apostrophes and non-ASCII characters are accepted, and an end-to-end test covers them.
- Author and committer are resolved through `git var GIT_*_IDENT`.
- A configured address is accepted verbatim.
- The `-c`-only case has its own message.
- The two scripts now behave the same on failure, and `--help` says so.
- `.agent/.identity` is written POSIX single-quoted.

Probed in temp repos (git config isolated via HOME / GIT_CONFIG_GLOBAL / GIT_CONFIG_NOSYSTEM):
- With `user.name` unset, `git var` falls back to the passwd name and the hook passes.
- In a linked worktree, an agent author and committer pass, and a foreign `GIT_COMMITTER_EMAIL` is rejected with a clear labelled message.
- `git -c committer.email=<foreign>` and `committer.email` in config are rejected; the tests cover this.
- Fix-agent claim verified: git strips the trailing `,` and the enclosing `<>`, and `GIT_AUTHOR_EMAIL='<u+a@x.org>,'` is recorded as `u+a@x.org`. Dropping those two hook cases is therefore correct.
- An inner comma (`u+a,b@x.org`) is kept by git and rejected by the hook. That is the safe direction.
- A configured `<u@x.org>` is refused with a message that shows the value.

`detect_agent_identity.sh` returns when sourced and exits when run. No script sources or calls it; only docs and comments name it.

Tests:
- `test_commit_identity.sh`: 92 passed, 0 failed.
- `test_dispatch_phase.sh`: 140 passed, 0 failed.
- `test_skill_paths.sh`: 136 passed, 0 failed.
- `test_gh_create_pr.sh` and `test_gh_create_issue.sh`: exit 0.
- shellcheck and flake8: clean.

No round-1 or round-2 regression found.

### Findings
- [ ] (suggestion) With `user.useConfigOnly=true` and no `user.name`, `git var` fails, and the hook prints "Author email: (not set) / Committer email: (not set)" while the email is set. Git would refuse the commit anyway, but the message points at the wrong cause. Pass through `git var`'s stderr, or say the name is missing — `.agent/scripts/identity_base.py:131`
