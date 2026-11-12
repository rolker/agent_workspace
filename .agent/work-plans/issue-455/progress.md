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
