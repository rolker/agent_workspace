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
   `configured_email(cwd)` (runs plain `git config user.email`), `split_base(email)` (strip `+suffix`;
   reject no `@`, empty local part, empty domain), `agent_email(suffix)`. CLI: `identity_base.py base`
   and `identity_base.py agent <suffix>` print the address on stdout; on an unset or malformed email
   print to stderr "git user.email is not set (or has no valid address). Run
   `git config --global user.email <your-address>` (or without `--global` for this clone only)" and exit 1.
2. **Hook `.agent/hooks/check-commit-identity.py`**: drop `ACCEPTED_PATTERNS` literals; import the helper
   (add the scripts dir to `sys.path`). Commit email stays `GIT_AUTHOR_EMAIL` first, then git config
   (unchanged); the accepted set derives from the configured base only, never from the env. Unset or
   malformed configured email gives the helper's message and exit 1 (blocking, ADR-0004/0005). Failure
   output prints the accepted forms as `<local>@<domain>` / `<local>+*@<domain>` built from the base.
3. **`framework_config.sh`**: replace `FRAMEWORK_EMAILS` with `FRAMEWORK_SUFFIXES` (suffixes only:
   `copilot-cli`, `codex`, `gemini-cli`, `antigravity`, `claude-code`); rewrite the header (pattern
   `<local>+<suffix>@<domain>`, base from git config, no owner address). Add a small bash function
   `framework_email <key>` that calls the helper, so consumers stop indexing an email table.
4. **`set_git_identity_env.sh`, `configure_git_identity.sh`, `detect_agent_identity.sh`**: replace
   `FRAMEWORK_EMAILS[...]` lookups (incl. the `copilot-cli`/`gemini-cli` aliases) with `framework_email`;
   the `AI Agent` fallback uses suffix `ai-agent`. On helper failure: print its message, `return 1`
   (sourced) / `exit 1` (executed), never set a partial `AGENT_EMAIL`. The explicit 2/3-arg forms keep
   working unchanged. Reword usage/error examples to `<you>+codex@<domain>`.
5. **Test `.agent/scripts/tests/test_commit_identity.sh`** (hermetic: temp repos, `GIT_CONFIG_GLOBAL`
   pointed at a temp file, `HOME` isolated; `chmod +x`). Cases: arbitrary base passes as human and as
   `local+x@domain`; another local part and another domain fail; unset email gives the message and exit 1
   (hook and `set_git_identity_env.sh --agent`, `configure_git_identity.sh`); malformed (`foo`, `@d`) fails;
   repo-local `user.email` overrides the global one; configured `local+claude-code@d` normalises to base
   `local@d` and `--agent codex` yields `local+codex@d`; `GIT_AUTHOR_EMAIL` on another base fails.
   Register with whatever `run_script_tests.sh` / `suites_for_files.sh` needs (check mapping for the
   hook and helper).
6. **Docs without addresses**: `.agent/AI_IDENTITY_STRATEGY.md` (lines 16, 47-50, 68, 86, 219) to the
   placeholder form and the derive-from-git rule; `docs/design.md` Identity section (lines 662, 671-672
   "the owner's two addresses") and the Rules row at 160; `script_reference.md` entries for the helper
   and changed scripts (verify the text first). `docs/roadmap.md:420` and the inspiration digest hold
   addresses/slugs as history: reword the roadmap line if it names an address; leave the digest and
   `test_dispatch_phase.sh` values (tests and past records are exempt per the issue) unless they are
   real addresses of the owner, in which case swap to `example.org` in the test.
7. **Acceptance check**: grep tracked non-test, non-work-plan files for the owner's local part and the
   two domains (pattern assembled in the command, not written into any file); run the new test,
   `test_dispatch_phase.sh`, `make lint`, shellcheck via pre-commit.
8. **LAST STEP, ONLY IF THE OWNER APPROVES (Ask First, separate commit): instruction files.** Change the
   `CLAUDE.md` "Environment Setup" line to `source .agent/scripts/set_git_identity_env.sh --agent
   claude-code` form (or a suffix-only 3-arg form) naming no address, and the matching `CODEX.md` line
   (and check `.github/copilot-instructions.md` and the gemini instruction file for the same literal).
   Not done without a yes. Until then the existing 3-arg line still works on the owner's machine and
   steps 1-7 stand alone; on another machine the literal in `CLAUDE.md` is the one thing left, so the
   issue is not closed until step 8 lands or the owner declines.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/identity_base.py` | New: shared base/agent-email derivation |
| `.agent/hooks/check-commit-identity.py` | Derive accepted set from base |
| `.agent/scripts/framework_config.sh` | Suffix table, `framework_email`, header |
| `.agent/scripts/set_git_identity_env.sh`, `configure_git_identity.sh`, `detect_agent_identity.sh` | Use `framework_email`, fail loudly, placeholder text |
| `.agent/scripts/tests/test_commit_identity.sh` | New hermetic test |
| `.agent/AI_IDENTITY_STRATEGY.md`, `docs/design.md`, `.agent/knowledge/script_reference.md`, `docs/roadmap.md` | Remove addresses, describe derivation |
| `CLAUDE.md`, `CODEX.md` (+ other adapter files if they hold the literal) | Step 8 only, after approval |

## Prior Art

`configure_git_identity.sh` already writes the agent address into the clone's `user.email`, which is
why suffix stripping is needed. The hook already reads `git config user.email`. `dispatch_phase.sh`
deliberately avoids the owner's git config (design.md); unaffected. Nothing external taken.

## Serves

Workspace usable by anyone who clones it (agent identity and attribution) — `docs/design.md#identity`.

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
| `FRAMEWORK_EMAILS` table | all three consumers, aliases | Yes (step 4) |
| Hook accepted set | design.md Rules row and Identity | Yes (step 6) |
| Setup lines in CLAUDE.md/CODEX.md | needs owner approval | Step 8, conditional |
| New `test_*.sh` | exec bit, suite mapping | Yes (step 5) |
| CI has no `user.email` | test builds its own config | Yes |

## Open Questions

- Owner approval for step 8 (instruction files). Needed to close the issue.
- Is `example.org`-style replacement in `test_dispatch_phase.sh` wanted, or leave as is (exempt)?

## Estimated Scope

Single PR; step 8 as a separate commit in it.
