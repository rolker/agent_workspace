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
