# Plan: Owner's email addresses are hardcoded in the identity hook and scripts

## Issue

https://github.com/rolker/agent_workspace/issues/455

## Context

The hook, the framework table, the fallback in `detect_agent_identity.sh`, usage text and the
`CLAUDE.md` / `CODEX.md` setup lines carry the owner's addresses as literals. Direction (owner):
derive everything from `git config user.email`, no config file, no override; different machines may
use different addresses; handle an unset email; honour a clone-level `user.email`.

Rule: base = `git config user.email` as resolved in the checkout (clone value over global, never
`--global`), with any `+suffix` removed from the local part. Accepted commit email = base, or
`<local>+<anything>@<domain>`. Agent email = `<local>+<framework>@<domain>`. An agent-configured clone
(`configure_git_identity.sh` writes `local+claude-code@domain` into the clone) therefore still yields
the same base.

## Approach

1. **Shared helper `.agent/scripts/identity_base.py`** (one parser for hook and shell). Functions:
   `configured_email(cwd)` (plain `git config user.email`, never `--global`), `split_base(email)` (strip
   `+suffix`; reject no `@`, empty local part, empty domain), `agent_email(suffix)`. CLI: `identity_base.py
   base` and `identity_base.py agent <suffix>` print the address; on an unset or malformed email print to
   stderr "git user.email is not set (or has no valid address). Run `git config --global user.email
   <your-address>` (or without `--global` for this clone only)" and exit 1.
2. **`framework_config.sh`**: `FRAMEWORK_EMAILS` becomes `FRAMEWORK_SUFFIXES` (`copilot-cli`, `codex`,
   `gemini-cli`, `antigravity`, `claude-code`); header rewritten (pattern `<local>+<suffix>@<domain>`, base
   from git config, no owner address); new bash function `framework_email <key>` calling the helper.
3. **`set_git_identity_env.sh`, `configure_git_identity.sh`, `detect_agent_identity.sh`**: use
   `framework_email` (aliases included; `AI Agent` fallback suffix `ai-agent`); on helper failure print its
   message and `return 1` / `exit 1`, never a partial `AGENT_EMAIL`. New optional model argument:
   `set_git_identity_env.sh --agent <framework> ["<model-id>"]` (default stays the table model), so a session
   can name its real model without an address. The 2/3-arg explicit forms keep working. Usage text uses
   `<you>+codex@<domain>`.
4. **Hook `.agent/hooks/check-commit-identity.py`**: drop `ACCEPTED_PATTERNS` literals; import the helper
   (scripts dir on `sys.path`). Commit email stays `GIT_AUTHOR_EMAIL` first, then git config; the accepted
   set derives from the configured base only, never from the env. Unset or malformed configured email:
   helper message, exit 1 (blocking, ADR-0004/0005). Failure output prints `<local>@<domain>` /
   `<local>+*@<domain>` built from the base.
5. **Test `.agent/scripts/tests/test_commit_identity.sh`** (`chmod +x`; hermetic: temp repos,
   `GIT_CONFIG_GLOBAL` at a temp file, `GIT_CONFIG_NOSYSTEM=1`, `HOME` isolated; fixtures use
   `example.org`). Cases: arbitrary base passes as human and as `local+x@domain`; another local part and
   another domain fail; unset email gives the message and exit 1 (hook, `--agent`,
   `configure_git_identity.sh`); malformed (`foo`, `@d`) fails; repo-local `user.email` beats global;
   configured `local+claude-code@d` normalises to base and `--agent codex` yields `local+codex@d`;
   `--agent claude-code "<model>"` sets that model; `GIT_AUTHOR_EMAIL` on another base fails. Map the new
   suite in `.agent/scripts/tests/suites_for_files.sh` for the hook, the helper, `framework_config.sh` and
   the three scripts (and check `test_script_tests_hook_scope.sh` stays green).
6. **Literal addresses out of every caller (all grep-verified, full list)**: `CLAUDE.md` and `CODEX.md`
   setup lines (owner-approved 2026-11-12) become `source .agent/scripts/set_git_identity_env.sh --agent
   claude-code "<your-model-id>"` / `--agent codex "<your-model-id>"` with prose saying the address is
   derived from the machine's git email; `.claude/skills/run-issue/SKILL.md:253` and its handoff
   description (line 339) and `.claude/skills/onboard-project/SKILL.md` (lines 381, 409, 450) switch from
   `"<agent name>" "<agent email>" "<model-id>"` to `--agent <framework> "<model-id>"`, with
   `.agent/scripts/tests/test_skill_paths.sh:492` (asserts the old line) updated to match;
   `.claude/skills/orchestrator/SKILL.md` has no explicit email (checked: it defers to run-issue), so no
   edit unless the grep at implementation time finds one; `dispatch_phase.sh` only prints the already
   exported `AGENT_EMAIL` (derived at source time), so its code is unchanged; only its header comment
   (line 37) and `test_dispatch_phase.sh:442-446` change (fixture swapped to an `example.org` address).
   `.github/copilot-instructions.md` and `.agent/instructions/` hold no address (checked).
7. **Docs without addresses**: `.agent/AI_IDENTITY_STRATEGY.md` (16, 47-50, 68, 86, 219) to placeholder
   form plus the derive-from-git rule; `docs/design.md` Identity section (662, 671-672) and Rules row
   (160); `script_reference.md` entries (helper, `--agent` model argument; verify text first);
   `docs/roadmap.md:420` reworded. The inspiration digest is a past record, left alone unless it holds a
   real owner address, then reworded.
8. **Acceptance check**: grep tracked files for the owner's local part and the two domains (pattern
   assembled in the command, never written into a file), excluding tests, work-plans and
   `.claude/skills/brand-guidelines/SKILL.md`. That file holds a public institutional contact address,
   not the owner's, and is expected to match; leave it alone. Run the new test, `test_dispatch_phase.sh`,
   `test_skill_paths.sh`, `make lint`.

## Commit order and identity (no commit is ever blocked)

On a machine whose git email base differs from the old literal (this one), the old literal passes the old
hook and fails the new one; the derived form does the opposite. The hook is therefore the pivot:

| # | Commit | Identity used by the committing agent |
|---|---|---|
| C1 | Helper + `framework_config.sh` + three scripts + `--agent <fw> [model]` (steps 1-3). Old hook still in the tree. | Old literal 3-arg line from the current `CLAUDE.md` (unchanged so far) |
| C2 | Doc rewrites (step 7) and `test_dispatch_phase.sh` fixture | Same literal line |
| C3 | **Pivot, atomic**: hook (step 4) + new test and `suites_for_files.sh` mapping (step 5) + `CLAUDE.md`, `CODEX.md`, run-issue, onboard-project and `test_skill_paths.sh` (step 6) | Derived: `source .agent/scripts/set_git_identity_env.sh --agent claude-code "<model-id>"` (works from C1's committed scripts; the new hook runs on this commit and accepts it) |
| C4+ | Every later commit (plan sync, review fixes), and every host / phase / progress-entry commit | Derived form only |

Rules: the hook file is edited in the working tree last, and C3 is the first commit made with the derived
form. The test lives in C3 because it exercises the new hook (it would fail in C1/C2). The new
instruction-file lines never land after the hook, so no later session is blocked. The run-issue host
sources `--agent claude-code "<model-id>"` before C3's phase and for all phases after; the handoff then
prints the derived `agent_email=`, which phases may pass through unchanged. Before C3 the host keeps the
literal. Concrete line for phases after the switch (starting every chain with `cd <worktree> &&`):
`source .agent/scripts/set_git_identity_env.sh --agent claude-code "<model-id>" && git commit ...`.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/identity_base.py` | New: shared derivation |
| `.agent/hooks/check-commit-identity.py` | Accepted set from base |
| `.agent/scripts/framework_config.sh` | Suffix table, `framework_email`, header |
| `.agent/scripts/set_git_identity_env.sh`, `configure_git_identity.sh`, `detect_agent_identity.sh` | `framework_email`, fail loudly, `--agent <fw> [model]` |
| `.agent/scripts/tests/test_commit_identity.sh`, `suites_for_files.sh` | New hermetic test and mapping |
| `CLAUDE.md`, `CODEX.md` | Setup line without address (approved) |
| `.claude/skills/run-issue/SKILL.md`, `.claude/skills/onboard-project/SKILL.md`, `.agent/scripts/tests/test_skill_paths.sh` | Derived identity form |
| `.agent/scripts/dispatch_phase.sh` (comment), `.agent/scripts/tests/test_dispatch_phase.sh` | Comment; `example.org` fixture |
| `.agent/AI_IDENTITY_STRATEGY.md`, `docs/design.md`, `.agent/knowledge/script_reference.md`, `docs/roadmap.md` | Remove addresses, describe derivation |

## Prior Art

`configure_git_identity.sh` already writes the agent address into the clone's `user.email`, which is
why suffix stripping is needed. The hook already reads `git config user.email`. `dispatch_phase.sh`
deliberately avoids the owner's git config (design.md); unaffected. Nothing external taken.

## Serves

Workspace goal "Modular" (`README.md#modular`: project-agnostic, no owner-specific data in the infrastructure) — `docs/design.md#identity`.

## Design Picture

Text change only: `docs/design.md#identity` says accepted emails are "the agent pattern and the owner's
two addresses"; updated in this change to "derived from the configured git email". No structural change.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Only what's needed | No config file, question or override; one helper |
| Enforcement over documentation | Hook stays blocking; accepted set derived, tested |
| Fail loudly | Unset or malformed email: clear message, nonzero, no partial address |
| Per-clone behaviour | Plain `git config user.email`, never `--global`; test with repo-local value |
| Agent commits distinguishable (#359) | Not widened: bare base from env still passes as today; #359 owns it |
| Privacy | No personal address written; messages say "the machine's git email" |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0003 | Yes | Removes owner-specific data from infrastructure |
| ADR-0004/0005 | Yes | Hook remains the blocking layer |
| ADR-0017 | Yes | Identity section of design.md updated in the same change |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| `FRAMEWORK_EMAILS` table | three consumers, aliases | Yes (step 3) |
| Hook accepted set | design.md Rules row and Identity | Yes (step 7) |
| Setup lines / skill identity lines | CLAUDE.md, CODEX.md, run-issue, onboard-project, test_skill_paths.sh | Yes, in C3 with the hook |
| New `test_*.sh` | exec bit, `suites_for_files.sh` | Yes (step 5) |
| CI has no `user.email` | test builds its own config | Yes |

## Open Questions

- None blocking. Instruction-file edits approved by the owner (2026-11-12); multiple machines with
  different emails are accepted as-is.

## Estimated Scope

Single PR, commits in the order above.
