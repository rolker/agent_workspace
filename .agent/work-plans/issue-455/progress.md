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
