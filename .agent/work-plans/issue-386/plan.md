# Plan: Direction section in the roadmap, a one-line inbox, and a sit-rep skill that answers what's next from checked facts

## Issue

https://github.com/rolker/agent_workspace/issues/386

## Context

Nothing in the repo says what must be true for the owner's acceptance cases, whether each line is true today, or what was set aside on purpose. The issue as written is trimmed by the owner's checkpoint (449ca34): no "sweep due?", no tooling-vs-project share, no resume cards. Decided and not reopened: the authored Direction section sits at the top of each root's roadmap; status and dates are measured by the sit-rep and kept machine-local; the four status words are a trial; no gz4d roadmap here (footprint is an onboarding question); one inbox per machine, its path from a machine-local setting the repo never publishes.

## Revision log

Revision 2, answering the Plan Review (c103ef0) and the owner's "revise" (bcfe261):

- F1: `script` checks match three exact argument vectors, run from the runner's own directory; `read -ra` under `set -f`; `grep -qF --`; marker-file tests for the disallowed forms.
- F2, F3: Deferrals table fixed as `| Deferral | Revisit check |` (no bare `#N` cell, no checklist items); every deferral carries a check or is `unchecked`; the runner prints a `kind` column and picks tables by header; fixture extended.
- F4: `gh-issue` uses the roadmap root's own remote, with an explicit `owner/repo#N` form; ADR-0010 row added (direct `gh`, with the reason).
- F5: `capture.sh` edge cases stated and tested (relative inbox, missing or unwritable inbox echoes the text, CRLF, worktree fallback to the main checkout's settings).
- F6: counts go in the run record (`--summary`), so "what moved" is built.
- F7: combination rule stated and tested. F8: the every-root loop and paused branches moved to follow-ups. F9: test paths written in full.

## Approach

Five commits after this plan, ordered so the work splits after commit 1 (A = commit 1; B = commits 2-5). Revision 2 changes are listed under Revision log below.

**A. Setting and capture**

1. **Settings file and `capture.sh`.**
   - New `.agent/scripts/_settings.sh`: `settings_get <root> <key>` reads `key=value` lines with `grep`/`sed`, never sourcing the file. Rules: first match wins; a leading `~/` expands to `$HOME`; a trailing CR and trailing spaces are stripped (CRLF files work); absent file or key prints nothing and returns 1.
   - File lookup, `settings_file <root>`: `$AGENT_SETTINGS_FILE` (tests), else `<root>/.agent/settings.local`; when that is absent and `<root>` is a linked worktree (`git rev-parse --git-common-dir` differs from `--git-dir`), the same path under the main checkout (the parent of the common dir). Neither found: `settings_get` returns 1, and `capture.sh` fails naming both paths it looked in. The skill reaches the scripts through `$WS_ROOT`, which is the main checkout.
   - Keys: `inbox` and `run_record`. A relative value resolves against the directory of the settings file that supplied it (never the caller's cwd, so lines cannot scatter). Add `.agent/settings.local.example` (comments only, no invented default path) and `.agent/settings.local` to `.gitignore`.
   - New `.agent/scripts/capture.sh "<text>"`. It appends one line: `date<TAB>project<TAB>issue<TAB>text`.
     - `inbox` unset: exit 1, print how to set it, and echo the text back. Empty text is a usage error.
     - Inbox directory missing or not writable (the script creates the file, never the directory): exit non-zero and print `not saved:` followed by the text, so the thought can be pasted elsewhere.
     - Text has tabs and newlines collapsed to single spaces.
     - Project comes from `registry_derive_type_from_dir "$root" "$PWD"`: a registered name, else `workspace`, else `none`; a registry parse error or a failed source gives `unknown`. The line is still written; a thought is never lost to a lookup failure.
     - Issue is `$WORKTREE_ISSUE`, else the N in a `feature/issue-N` or `feature/ISSUE-N-...` branch name of the cwd, else `-`.
     - The line goes out as one `printf '%s\n' >> file` (single write, `O_APPEND`). The script never calls `gh`, git-bug or any issue creator.
   - New `.agent/scripts/tests/test_capture.sh` (`chmod +x`), synthetic sandbox workspace made with `mktemp -d` under `TMPDIR`, a copied registry and a stub `HOME`:
     - unset setting fails with the instruction text, echoes the text, writes nothing;
     - fields for a registered cwd, a workspace cwd, an outside cwd (`none`), and a malformed registry (`unknown`, still appended);
     - issue from the env variable, from a branch name, and absent;
     - tab/newline collapse, so exactly one line per call;
     - two parallel calls give two intact lines;
     - relative `inbox=notes/in.txt` lands under the settings file's directory whatever the cwd; a missing inbox directory and an unwritable inbox (a read-only directory) exit non-zero and print `not saved:` plus the text;
     - a CRLF settings file works for both keys;
     - a sandbox git repo with a linked worktree that has no `settings.local`: `settings_get` finds the main checkout's; with neither, `capture.sh` fails naming both paths;
     - settings reader: `~` expansion, a value containing `=`, and a line that looks like shell (`inbox=$(touch x)`) is not executed.

**B. Direction, checks, skill, design**

2. **`.agent/scripts/sitrep_checks.sh [--root <dir>] [--roadmap <file>] [--summary]`** (read-only; default roadmap `<root>/docs/roadmap.md`).
   - Reads the `## Direction` section only, and picks tables by header: `| Line | Check |` gives `line` rows; `| Deferral | Revisit check |` gives `deferral` rows; any other table in the section is ignored. Prints one TAB row each: `kind`, `item`, `result`, `check`, `date` (today). An absent section prints a single row `section`, `(no Direction section)`, `unchecked`, `none`, date. A checklist item (`- [ ]` / `- [x]`) inside the section prints a `format` row, `unchecked`, so misuse is visible. Exit 0 whenever rows were printed.
   - `--summary` prints one line from the same rows: `lines <true>/<total> deferrals <true>/<total>` (a deferral whose check is true is "due"). This is what the run record stores.
   - Check kinds, parsed by `read -ra` under `set -f` (no glob expansion, no `eval`):
     - `file-exists <relpath>`
     - `file-contains <relpath> <fixed string>`: the string is the rest of the cell, run as `grep -qF -- "$s" "$file"`
     - `gh-issue <N> <open|closed>`: runs `gh -R <owner/repo> issue view <N> --json state`, with the repo derived from the roadmap root's own remote (`git -C "$root" remote get-url origin`, through `extract_gh_slug` from `_issue_helpers.sh`); `gh-issue <owner/repo>#<N> <open|closed>` names the repo explicitly. A root with no GitHub remote gives `unknown`. Never the cwd's remote.
     - `script <form>`, an exact whole-argument-vector match against the list below, run from the runner's own `.agent/scripts/` directory (`$SCRIPT_DIR`; tests override it with `SITREP_SCRIPTS_DIR`). A project root's `.agent/scripts` is never consulted.
       - `adapter --project <name> validate` (`<name>` matches `^[A-Za-z0-9._-]+$`)
       - `user_tier_install.sh --check` and `user_tier_install.sh --check --require`
       - `check_design_anchors.sh` (no arguments)
   - Everything else is `unchecked`: a path that is absolute or contains `..`, an unknown kind, any other `script` form (bare `user_tier_install.sh`, `--uninstall`, `adapter ... build|test|sync|install|setup`, extra arguments), a bare `#N`, an empty check.
   - `true` is exit 0 and `false` is exit 1, from the kind's own exit status. Anything else (gh missing or failing, script missing or exit above 1, grep exit 2, timeout, `file-contains` on an unreadable file) is `unknown`, never `false`. Every external call runs under `timeout`.
   - A cell of several checks joined by ` ; ` combines in this order: any `unknown` gives `unknown`; else any `unchecked` gives `partial`; else all `true` gives `true`, all `false` gives `false`, mixed gives `partial`. Word set (a trial): true / false / partial / unknown / unchecked.
   - Reads issues with `gh` directly, not `issue_lookup` (ADR-0010 row below).
   - New `.agent/scripts/tests/test_sitrep_checks.sh` (`chmod +x`): a stub `gh` on `PATH`, stub scripts that write a marker file, sandbox roots from `mktemp -d` under `TMPDIR`:
     - no check gives `unchecked`; cannot-run gives `unknown` (failing `gh`, missing script, exit 2); true/false come only from exit 0/1; no row lacks its check field (`none` printed explicitly);
     - never run (marker file absent): `user_tier_install.sh` bare, `--uninstall`, `adapter --project x build|test|sync|install|setup`, a `script` form with an extra argument, and a stub `adapter` inside the sandbox root's own `.agent/scripts`; a `*` in a cell is not globbed;
     - allowed forms do run (marker present) and map exit 0/1/2 to true/false/unknown;
     - `gh-issue 5 closed` calls `gh` with `-R` taken from the root's remote, not the cwd's (stub records its args); the `owner/repo#N` form overrides it; a root without a remote gives `unknown`;
     - the combination rule on every pair: true+unknown, false+unknown, true+unchecked, false+unchecked, true+false, true+true, false+false;
     - a second table inside Direction (other header) is not read as Line or Deferral rows; deferral rows print kind `deferral` and a deferral with no check is `unchecked`; a checklist item gives a `format` row; a missing Direction heading; rows after the section end are ignored; `--summary` counts match the rows.
3. **Direction section at the top of `docs/roadmap.md`** (above `## User Scenarios`).
   - Its header states the grammar, the allowed check kinds with the three `script` forms, the Deferral format, and the reader (the sit-rep); there is no status column.
   - Format rules in the header, so `update_roadmap.sh` cannot touch the section: check cells start with their kind word, never a bare `#N`; the Deferrals table is `| Deferral | Revisit check |` with the first cell prose and issue references inline in prose like `(#345)`, never a cell that is exactly `#N`; no checklist-form deferrals.
   - Contents: purpose (ADR-0016 acceptance run, design OQ-2, gz4d named as the run's target as the Workspace Redesign row already does); a short `| Line | Check |` table of workspace-checkable lines (for example the registry validates through `script adapter --project gz4d validate`; the merge gate finds a project PR's records through `gh-issue 379 closed`; `script user_tier_install.sh --check`; and "the run reaches the merge checkpoint" with no check, so `unchecked`); a short Deferrals table, each row with a check or `unchecked`; a pointer to Decided Against. No gz4d-owned facts.
   - Extend `.agent/scripts/tests/test_update_roadmap.sh` with a Direction fixture: a Line row (`(#N)` in the Line cell, `gh-issue N closed` check), a Deferrals row (`(#N)` in prose, check `gh-issue N closed`) and a `- [ ] ... (#N)` line. `update_roadmap.sh --issue N` leaves the Line row and the Deferrals row byte-identical, a control row elsewhere is still flipped to `done`, and the checklist line is pinned as flipped (which is why the header forbids that form and the runner flags it).
   - Add the Direction section to `what-next`'s skip list.
   - Add a roadmap row for #386 and link scenario 4 (Monday morning bootstrap) to it.
4. **`.claude/skills/sitrep/SKILL.md`** (`session_scope: both`, all workspace paths as `$WS_ROOT/.agent/scripts/...`; `test_skill_paths.sh` enforces this). First mode only. The skill formats and does not decide.
   - It runs `sitrep_checks.sh` for the workspace root only (`--root "$WS_ROOT"`) and says in one line that registered project roots are not read in this mode.
   - It reads the inbox (count, oldest date, new since the last run record) via `settings_get`, and `worktree_list.sh --json` plus open PRs (last commit or PR state in place of resume cards).
   - It prints four sections on one screen: where the acceptance case stands (lines true of total, blocked on, what moved since the last run record); inbox count plus a proposed sort for the owner to answer in batches (now / next / someday / decided-against with a revisit condition / delete; never "never"); in flight; deferrals whose check is `true` (those `unchecked` are listed as unchecked, never as due).
   - It ends with at most one question. It states nothing it did not check this run, and memory notes are not a source.
   - It writes one dated line to the `run_record` file and nothing to the repo: `date<TAB>workspace<TAB>` plus the `--summary` text plus `<TAB>inbox <lines>`. The next run diffs the last line for the root against the current counts to say what moved (for example `lines 3/5 -> 4/5`). Chosen over a follow-up because the counts come from the same rows at no extra cost and it makes the Measures row honest. With `run_record` unset it says so and skips the write; with no earlier line it says "first run".
   - `what-next` gets a one-line pointer to `/sitrep`; no retirement.
5. **`docs/design.md`** (same change, ADR-0017):
   - Documentation layers: Direction row (the roadmap's `## Direction` section, read by the sit-rep), Measures row (the sit-rep run record, a first form); rewrite "Two of the seven are gaps" (the "healthy" gap stays open or narrows; the measures gap is partly closed); update the Target sentence.
   - OQ-3 partly answered.
   - One sentence in Registry and adapters for `settings.local` (read from the checkout, falling back to the main checkout's copy from a worktree).
   - Change-log row with the new line count (first form; the four status words are a trial).
   - Refresh any line numbers `docs/design.md` cites for scripts touched.
   - Run `check_design_anchors.sh` and `make lint`.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/_settings.sh` (new) | `settings_get`, `settings_file` (worktree fallback), no sourcing |
| `.agent/settings.local.example` (new), `.gitignore` | example, ignore `.agent/settings.local` |
| `.agent/scripts/capture.sh` (new), `.agent/scripts/tests/test_capture.sh` (new) | the inbox writer and its tests |
| `.agent/scripts/sitrep_checks.sh` (new), `.agent/scripts/tests/test_sitrep_checks.sh` (new) | check runner and its tests |
| `docs/roadmap.md` | Direction section, #386 row, scenario 4 link |
| `.agent/scripts/tests/test_update_roadmap.sh` | Direction fixture: Line row, Deferrals row, checklist line |
| `.claude/skills/sitrep/SKILL.md` (new) | the skill |
| `.claude/skills/what-next/SKILL.md` | skip Direction; pointer to `/sitrep` |
| `docs/design.md` | rows above |

## Prior Art

Existing code only: `registry_derive_type_from_dir` (cwd to project), `review_progress.sh`'s read-without-sourcing style, `worktree_list.sh --json`, `update_roadmap.sh`'s row matching (read to find the collision), `extract_gh_slug` in `_issue_helpers.sh`. The fork's health report and sweep do not exist here (hence the trim). No new dependency.

## Serves

Goals "Easy to use" (work is easy to come back to) and "The long view" (day-to-day work stays connected to direction); `docs/design.md#documentation-layers`, `docs/design.md#registry-and-adapters`.

## Design Picture

Changes Documentation layers (Direction and Measures rows, the gaps paragraph, Target, OQ-3) and adds one sentence to `docs/design.md#registry-and-adapters` for the machine-local settings file. Both in commit 5 of this PR.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Test what breaks | The one rule is mechanical: the runner prints the rows and its tests pin unchecked / unknown / exit-status; the skill only formats |
| Enforce what matters, as simply as possible | Read-only check kinds, three exact `script` argument vectors run from the runner's own directory, no `eval`, no globbing, one fixed grammar stated in the section header |
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
| ADR-0010 | Yes | `gh-issue` reads state with `gh -R` directly, not `issue_lookup`: the line's status must be checked this run, and a git-bug cache can lag the bridge; a `gh` failure is `unknown`, never a stale answer. Departure from git-bug-first, recorded in the script header |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| `docs/roadmap.md` rows | `update_roadmap.sh` collision (check cells never a bare `#N`; Deferrals table and checklist form) | Yes, fixture in commit 3 |
| `what-next` section parsing | skip list gains Direction | Yes |
| `docs/design.md` text | line counts, change-log row, anchors check | Yes |
| New scripts | `AGENTS.md` Script Reference row | No, Ask First; follow-up |

## Follow-ups (one line each; file as issues, not in this PR)

- Sit-rep over every registered root with a Direction section (first mode reads the workspace root only; no registered root has one today).
- Paused branches named in Deferrals (needs a branch column in the Deferrals table).
- "Sweep due?" once a sweep skill and a health report exist.
- Tooling-versus-project share line in the sit-rep.
- Resume cards written at park time (draft question S-c; overlaps the host protocol, #321).
- `what-next`: fold into the sit-rep or retire (decision: after the sit-rep has run a few weeks).
- `AGENTS.md` Script Reference rows for `capture.sh` and `sitrep_checks.sh` (Ask First).
- User-tier promotion of `capture.sh`: decide `inert` marker (it appends outside every repo) versus guarded (refuses the `none` case).

## Open Questions

None blocking. Defaults chosen, change on request: settings file name `.agent/settings.local` with keys `inbox` and `run_record`; `partial` produced only by multi-check lines; the three `script` forms are `adapter --project <name> validate`, `user_tier_install.sh --check [--require]` and `check_design_anchors.sh`; the run record holds counts (`lines t/n deferrals t/n inbox n`).

## Estimated Scope

Single PR, five commits. If review runs past one round on either half, split after commit 1.
