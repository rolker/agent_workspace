# Plan: Direction section in the roadmap, a one-line inbox, and a sit-rep skill that answers what's next from checked facts

## Issue

https://github.com/rolker/agent_workspace/issues/386

## Context

Nothing in the repo says what must be true for the owner's acceptance cases, whether each line is true today, or what was set aside on purpose. The issue as written is trimmed by the owner's checkpoint (449ca34): no "sweep due?", no tooling-vs-project share, no resume cards. Decided and not reopened: the authored Direction section sits at the top of each root's roadmap; status and dates are measured by the sit-rep and kept machine-local; the four status words are a trial; no gz4d roadmap here (footprint is an onboarding question); one inbox per machine, its path from a machine-local setting the repo never publishes.

## Approach

Five commits after this plan, ordered so the work splits after commit 1 (A = commit 1; B = commits 2-5).

**A. Setting and capture**

1. **Settings file and `capture.sh`.**
   - New `.agent/scripts/_settings.sh`: `settings_get <root> <key>` reads `key=value` lines from `.agent/settings.local` (file override: `$AGENT_SETTINGS_FILE`, for tests) with `grep`/`sed`, never sourcing it; a leading `~/` expands to `$HOME`; the first match wins; absent file or key prints nothing and returns 1.
   - Keys: `inbox` and `run_record`. Add `.agent/settings.local.example` (comments only, no invented default path) and `.agent/settings.local` to `.gitignore`.
   - New `.agent/scripts/capture.sh "<text>"`. With `inbox` unset it exits 1 and prints how to set it. It appends one line: `date<TAB>project<TAB>issue<TAB>text`.
     - Text has tabs and newlines collapsed to single spaces; empty text is a usage error.
     - Project comes from `registry_derive_type_from_dir "$root" "$PWD"`: a registered name, else `workspace`, else `none`; a registry parse error or a failed source gives `unknown`. The line is still written, and a thought is never lost.
     - Issue is `$WORKTREE_ISSUE`, else the N in a `feature/issue-N` or `feature/ISSUE-N-...` branch name of the cwd, else `-`.
     - The line goes out as one `printf '%s\n' >> file` (single write, `O_APPEND`). The script never calls `gh`, git-bug or any issue creator.
   - New `tests/test_capture.sh` (exec bit, `chmod +x`), synthetic sandbox workspace with a copied registry and a stub `HOME`:
     - unset setting fails with the instruction text and writes nothing;
     - fields for a registered cwd, a workspace cwd, an outside cwd (`none`), and a malformed registry (`unknown`, still appended);
     - issue from the env variable, from a branch name, and absent;
     - tab/newline collapse, so exactly one line per call;
     - two parallel calls give two intact lines;
     - settings reader: `~` expansion, a value containing `=`, and a settings line that looks like shell (`inbox=$(touch x)`) is not executed.

**B. Direction, checks, skill, design**

2. **`.agent/scripts/sitrep_checks.sh [--root <dir>] [--roadmap <file>]`** (read-only).
   - Takes the table in the roadmap's `## Direction` section, header `| Line | Check |`, and prints one TAB row per line: `line`, `result`, `check`, `date` (today). An absent section prints a single row `(no Direction section)`, `unchecked`, `none`, date. It exits 0 whenever rows were printed.
   - Check kinds, each parsed by word splitting and run directly, never `eval`: `file-exists <relpath>`, `file-contains <relpath> <fixed string>`, `gh-issue <N> <open|closed> [owner/repo]`, and `script <name> [args]` where `<name>` is in an allowlist at the top of the script (first entries: `adapter`, `user_tier_install.sh`, `check_design_anchors.sh`, resolved under `$root/.agent/scripts/`).
   - A path that is absolute or contains `..`, an unknown kind or script, a bare `#N` and an empty check are all `unchecked`.
   - `true` is exit 0 and `false` is exit 1, from the kind's own exit status. Anything else (gh missing or failing, script missing or exit above 1, grep exit 2, timeout) is `unknown`, never `false`. `file-contains` on an unreadable file is `unknown`.
   - A cell of several checks joined by ` ; ` is `partial` when the results mix true and false, `unknown` if any is unknown and none is false, otherwise the common result (trial word set: true / false / partial / unknown, plus `unchecked`).
   - Every external call runs under `timeout`.
   - New `tests/test_sitrep_checks.sh` (exec bit): no check gives `unchecked`; cannot-run gives `unknown` (stub `gh` that fails, a missing script, exit 2); true/false come only from exit 0/1; no row lacks its check field (`none` is printed explicitly); path escape and non-allowlisted script give `unchecked`; `partial`; a section with a missing Direction heading; rows after the section end are ignored.
3. **Direction section at the top of `docs/roadmap.md`** (above `## User Scenarios`).
   - Its header states the grammar, the allowed check kinds and the reader (the sit-rep), and has no status column.
   - Contents: purpose (ADR-0016 acceptance run, design OQ-2, gz4d named as the run's target as the Workspace Redesign row already does); a short `| Line | Check |` table of workspace-checkable lines (for example the registry validates through `script adapter --project gz4d validate`; the merge gate finds a project PR's records through `gh-issue 379 closed`; `script user_tier_install.sh --check`; and "the run reaches the merge checkpoint" with no check, so `unchecked`); deferrals with revisit conditions; a pointer to Decided Against. No gz4d-owned facts.
   - Every check cell starts with its kind word, never a bare `#N`.
   - Add a Direction fixture to `tests/test_update_roadmap.sh`: a Direction table whose lines mention issue numbers is left byte-identical when `update_roadmap.sh --issue N` runs for those numbers, and a control row elsewhere is still flipped to `done`.
   - Add the Direction section to `what-next`'s skip list.
   - Add a roadmap row for #386 and link scenario 4 (Monday morning bootstrap) to it.
4. **`.claude/skills/sitrep/SKILL.md`** (`session_scope: both`, all workspace paths as `$WS_ROOT/.agent/scripts/...`; `test_skill_paths.sh` enforces this). First mode only. The skill formats and does not decide.
   - It runs `sitrep_checks.sh` for the workspace root, then for each registered root that has a Direction section (a root without one is reported "no direction record", never invented).
   - It reads the inbox (count, oldest date, new since the last run record) via `settings_get`, and `worktree_list.sh --json` plus open PRs and paused branches named in Deferrals (last commit or PR state in place of resume cards).
   - It prints four sections on one screen: where each acceptance case stands (lines true of total, blocked on); inbox count plus a proposed sort for the owner to answer in batches (now / next / someday / decided-against with a revisit condition / delete; never "never"); in flight; deferrals whose revisit condition holds.
   - It ends with at most one question. It states nothing it did not check this run, and memory notes are not a source.
   - It writes one dated line to the `run_record` file and nothing to the repo. With `run_record` unset it says so and skips the write.
   - `what-next` gets a one-line pointer to `/sitrep`; no retirement.
5. **`docs/design.md`** (same change, ADR-0017):
   - Documentation layers: Direction row (the roadmap's `## Direction` section, read by the sit-rep), Measures row (the sit-rep run record, a first form); rewrite "Two of the seven are gaps" (the "healthy" gap stays open or narrows; the measures gap is partly closed); update the Target sentence.
   - OQ-3 partly answered.
   - One sentence in Registry and adapters for `settings.local`.
   - Change-log row with the new line count (first form; the four status words are a trial).
   - Refresh any line numbers `docs/design.md` cites for scripts touched.
   - Run `check_design_anchors.sh` and `make lint`.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/_settings.sh` (new) | `settings_get`, no sourcing |
| `.agent/settings.local.example` (new), `.gitignore` | example, ignore `.agent/settings.local` |
| `.agent/scripts/capture.sh` (new), `tests/test_capture.sh` (new) | the inbox writer and its tests |
| `.agent/scripts/sitrep_checks.sh` (new), `tests/test_sitrep_checks.sh` (new) | check runner and its tests |
| `docs/roadmap.md` | Direction section, #386 row, scenario 4 link |
| `.agent/scripts/tests/test_update_roadmap.sh` | Direction fixture |
| `.claude/skills/sitrep/SKILL.md` (new) | the skill |
| `.claude/skills/what-next/SKILL.md` | skip Direction; pointer to `/sitrep` |
| `docs/design.md` | rows above |

## Prior Art

Existing code only: `registry_derive_type_from_dir` (cwd to project), `review_progress.sh`'s read-without-sourcing style, `worktree_list.sh --json`, `update_roadmap.sh`'s row matching (read to find the collision). The fork's health report and sweep do not exist here (hence the trim). No new dependency.

## Serves

Goals "Easy to use" (work is easy to come back to) and "The long view" (day-to-day work stays connected to direction); `docs/design.md#documentation-layers`, `docs/design.md#registry-and-adapters`.

## Design Picture

Changes Documentation layers (Direction and Measures rows, the gaps paragraph, Target, OQ-3) and adds one sentence to `docs/design.md#registry-and-adapters` for the machine-local settings file. Both in commit 5 of this PR.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Test what breaks | The one rule is mechanical: the runner prints the rows and its tests pin unchecked / unknown / exit-status; the skill only formats |
| Enforce what matters, as simply as possible | Read-only check kinds, an allowlisted script set, no `eval`, one fixed grammar stated in the section header |
| Leave in a project only what it chose to carry | Nothing is written to any project; no gz4d roadmap; lines are about the workspace's own acceptance case |
| Put each thing at the level it applies to | Authored direction is tracked; status, inbox and run record are machine-local |
| Keep one current design | `docs/design.md` updated in the same PR; setting documented once |
| Only what's needed | Four output sections; trimmed items are follow-ups |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0017 | Yes | commit 5 |
| ADR-0016 | Yes | `session_scope: both` and `$WS_ROOT` idiom for the skill; `capture.sh` stays out of `user_tier_scripts.txt` here (follow-up) |
| ADR-0011 | Watch | cwd mapping goes through the registry helpers; no branching on project type |
| ADR-0013 | No | the run record is not a timeline entry |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| `docs/roadmap.md` rows | `update_roadmap.sh` collision (check cells never a bare `#N`) | Yes, fixture in commit 3 |
| `what-next` section parsing | skip list gains Direction | Yes |
| `docs/design.md` text | line counts, change-log row, anchors check | Yes |
| New scripts | `AGENTS.md` Script Reference row | No, Ask First; follow-up |

## Follow-ups (one line each; file as issues, not in this PR)

- "Sweep due?" once a sweep skill and a health report exist.
- Tooling-versus-project share line in the sit-rep.
- Resume cards written at park time (draft question S-c; overlaps the host protocol, #321).
- `what-next`: fold into the sit-rep or retire (decision: after the sit-rep has run a few weeks).
- `AGENTS.md` Script Reference rows for `capture.sh` and `sitrep_checks.sh` (Ask First).
- User-tier promotion of `capture.sh`: decide `inert` marker (it appends outside every repo) versus guarded (refuses the `none` case).

## Open Questions

None blocking. Defaults chosen, change on request: settings file name `.agent/settings.local` with keys `inbox` and `run_record`; `partial` produced only by multi-check lines; allowlist starts with `adapter`, `user_tier_install.sh`, `check_design_anchors.sh`.

## Estimated Scope

Single PR, five commits. If review runs past one round on either half, split after commit 1.
