# Plan: sitrep: report the session's own root, so a project session gets the project's sit-rep

## Issue

https://github.com/rolker/agent_workspace/issues/418

## Context

`/sitrep` (`session_scope: both`) reads the workspace root for every fact, so in a
project session it answers about the workspace. Owner direction (2026-11-09): the
sit-rep covers the session's own root only. A combined workspace-plus-projects view
is out of scope; it belongs to a later personal-root skill. `sitrep_checks.sh
--root <dir> --roadmap <file>` already runs unchanged against a project roadmap, so
the change is in the skill's root handling plus one small testable helper.

## Approach

One PR, five commits. No gate on #388: #418 lands first and #388 (inbox read once
under a lock; no branch, worktree or PR yet) is planned against the post-#418 steps.
To keep #388 the same size, S4 reuses step 2's existing listing pass: the root's
inbox lines are shown first inside that pass, with no extra read of the inbox.

1. **`.agent/scripts/sitrep_root.sh` (new, read-only, `chmod +x`)** -- the one place
   the root is decided. Justification: it removes root logic that six step blocks
   would otherwise each repeat (shell state does not persist between tool calls),
   so the decisions are made once and one test covers them. (Skill blocks themselves
   are testable through `skill_step`; see Tests.) It calls `session_root.sh` and
   prints `key=value` lines: `root=`, `type=`, `project=`, `record_name=` (the
   registered name; `workspace` for the workspace; a project literally named
   `workspace` is printed `project:workspace` so it cannot collide with the run-record
   column), `roadmap=` (first existing of `docs/roadmap.md`, `ROADMAP.md`, else
   empty), `own_repo=yes|no`, `default_branch=`, `pr_source=`, and one
   `check_<name>=run` or `check_<name>=skipped (<file> not in this root)` line per
   workspace-shaped check. When `session_root.sh` exits 1 (outside the workspace and
   every registered root) the helper prints nothing on stdout, says why on stderr and
   exits 1; the skill stops and says "no sit-rep: this directory is outside every
   root", never falling back to the workspace. A second mode, `sitrep_root.sh
   --worktrees`, reads `worktree_list.sh --json` and prints the same shape,
   `{"worktrees": [...]}`, so step 3's `jq '.worktrees[]?'` and step 5's python read
   it unchanged. One rule for both root types: it keeps (a) the entries whose path is
   under the root's worktree directories (`wt_registry_worktree_dirs`, as
   `worktree_list.sh` does; this covers a parent root's instances and package
   worktrees whose `repo` comes from the manifest header, which a `repo == <project>`
   test would miss) plus (b) the worktrees this root's own Direction lines name: an
   `adapter --project <name>` check keeps that project's worktrees, a
   `<owner/repo>#N` check keeps the worktree for that issue. For the workspace root,
   part (a) is the workspace's own worktree folder, `worktrees/workspace/` (from
   `wt_workspace_base`; `wt_registry_worktree_dirs` lists only project roots' folders,
   so the helper adds it). **This is narrower than today's workspace report, and the
   plan says so.** Today step 3's filter (`.type != "main" and .issue`, SKILL.md line
   223) keeps every worktree with an issue from `worktree_list.sh --json`, which walks
   every root's folders (line 359), so project worktrees no Direction line names show
   too (as "no path (serves a project goal)"). Under the rule they drop out of the
   workspace report. Owner decision (2026-11-09): the acceptance bullet "From the
   workspace root the report is unchanged from today" is narrowed to "the workspace
   report lists the workspace's own worktrees plus project work its Direction lines
   name; project worktrees no workspace Direction line names drop out", in line with
   his word that a sit-rep in the workspace is just for the workspace. The issue's
   acceptance bullet is to be edited to match by the host when the PR is opened. A
   project session lists its own worktrees plus any its Direction names. An error from `worktree_list.sh`
   (non-zero exit or non-JSON output) is passed through on stderr with its exit
   status, never printed as an empty list; the skill shows it as a problem, not as
   "no worktrees".
2. **S2 pull-request source and git facts** -- `own_repo` is `yes` only when
   `git -C <root> rev-parse --show-toplevel` equals the root itself (a hosting
   directory, or a registered root inside the workspace tree, with no repository of
   its own would otherwise resolve upward into the workspace repository or a nested
   package). `pr_source` is the GitHub slug of `origin` when `own_repo=yes`, else
   `none`; the report says "pull requests: no pull-request source for this root",
   never a guess. Step 3 and step 5's `gh pr list -R` use it. Step 6's git facts
   (`since`, `sha_at`, `show`, main-behind-origin) use the same test: with
   `own_repo=no` they are skipped with one line, never read from the enclosing
   repository. `default_branch` is `origin/HEAD`'s target when set, else `main` or
   `master` if exactly one exists, else empty; step 6 replaces its hard-coded `main`
   with it, and with it empty prints "cannot tell" for main-behind-origin and for the
   commit counts, not a wrong number.
3. **S1/S6 root and roadmap** -- steps 1, 5, 6 take `ROOT` from the helper instead of
   `$WS_ROOT` (`$WS_ROOT` stays for scripts). Step 1 passes `--root "$ROOT"
   --roadmap "$roadmap"`; with `roadmap=` empty the runner's `section` row already
   says why and the report says "no Direction section in this project; onboarding
   offers one" and invents nothing. Acceptance paragraph, Paths and Suggested next
   read the same file; no Paths paragraph gives the existing `paths=none` branch.
4. **Step 3 path words and step 5 titles for a project root** -- worktrees come from
   `sitrep_root.sh --worktrees` (step 3's `.type != "main" and .issue` filter keeps
   applying to its output). Step 5's `type == "workspace"` filter (SKILL.md line 579)
   is replaced by a match on the root's own worktrees only, part (a) of Approach 1
   (the helper marks each entry `own=yes|no`; for a package worktree, `own=yes` when
   its manifest-header slug equals `pr_source`). Reason: step 5's numbers come from
   `(#N)` and `gh-issue N`, which are issues of the root's own repository, and the
   (b) worktrees of other repositories can carry the same number; matching them would
   print another repository's branch as this issue's. Step 3 keeps (a) and (b), since
   its path words come from the Direction lines that name (b). The workspace set is
   the narrowed one of Approach 1. In a project session: Path 1 when
   this root's Direction lines name the issue (`(#N)`, `gh-issue N`, `<slug>#N`, same
   matching as now but for any worktree of this root, not only `type = workspace`;
   a Direction-named worktree of another repository is matched by its `<slug>#N` or
   `adapter --project` line only, never by a bare `(#N)`);
   Path 2 is not said, because it is defined by the workspace README's goals, so a
   worktree that serves a goal reads "no path (serves a project goal)" as today; the
   `serves` words for `none`/`unstated`/`unreviewed` are unchanged; with `paths=none`
   no path words are printed at all. Step 5's issue-title lookup uses `pr_source` in
   place of `$WS_REPO` and looks up git-bug at `$ROOT` instead of `$WS_ROOT`; with
   `pr_source=none` the title is "unknown (no repository to read it from)". Step 5's
   ADR-title lookup (`os.environ["WS_ROOT"]/docs/decisions`, SKILL.md ~lines 623-630)
   reads `$ROOT/docs/decisions`, so a project's "ADR-0003" never prints the
   workspace's title; when that directory is absent the ADR number is printed bare.
5. **S3 Problems** -- per-check file-exists tests in the helper: Decision register
   (`docs/design.md`), research digest (`.agent/knowledge/research_digest.md`),
   design anchors (`check_design_anchors.sh` and `docs/design.md`), and the
   Documentation fact (days since `docs/design.md` changed, commits since touching
   `.agent .claude docs`; needs `docs/design.md` and `own_repo=yes`). A check whose
   file is absent prints one skip line naming the check and the file. Direction
   `format`/`unknown` rows and local-main-behind run for any root with `own_repo=yes`.
   The Problems rule "in a project session the section is the workspace's only" is
   replaced by this. Step 7: start a due check only in a workspace session. In a
   project session, step 7 offers nothing for a due design-decision review or a due
   research digest: the report states the fact, and no skill checks them for a project
   (`/audit-project` does not read the Decision register's Re-examined column;
   `/audit-workspace` audits the wrong root; the `research` skill's tracked digest is
   the workspace's). It offers nothing for a check whose file is absent either. If
   `/audit-project` later gains such a check, step 7 can name it then. The report template's
   Documentation wording (~line 873, "<c> commits since changed the workspace's
   scripts, skills or docs") names the root instead: "<c> commits since changed this
   project's scripts, skills or docs" / "the workspace's ..." chosen by `type`.
6. **S4/S5 inbox and run record** -- step 2 shows inbox lines whose `project` field
   equals `record_name` first, inside the existing listing pass (workspace:
   unchanged). The run record's column 2 is `record_name`; `awk '$2 == "workspace"'`
   in step 2 and the `printf` in step 4 use it, so "since last run" compares with the
   last line for the same root and old records stay valid.
7. **S7 docs** -- drop "This first mode reads the workspace root only" (line 38),
   the report template's "Workspace root only: registered project roots are not read
   in this mode..." paragraph (~line 890), step 3's "`-R` names the workspace
   repository ... so a project session does not list the project's pull requests by
   mistake" (~line 193; now: `-R` names the session root's repository from
   `pr_source`), and step 8's "A project worktree's pull requests are not looked up"
   (~lines 965-969; now: looked up from `pr_source` when the root's own repository
   has one, else the line says nothing). Step 3's and step 8's text and example
   (`myproject/feature/issue-12`) about project worktrees in the workspace report now
   cover only Direction-named ones. Frontmatter description gains "for the
   session's own root". `docs/design.md`: Documentation layers says the sit-rep reads
   the session's own root and a combined view is not part of it; the Measures row
   says "one machine-local line per run, per root"; a Change log row (date, sections,
   one line, #418, line count after the change). Roadmap: delete the deferral row and
   add a Decided Against entry whose Reason quotes the owner (2026-11-09: "a sit rep
   in gz4d is just for that project and one in the workspace is just for the
   workspace. The idea of having a personal assistant type skill or something for ~ is
   where a sitrep that combines workspace and all projects might belong") and names
   the personal-root skill as where the idea went (the inbox line that first held it
   is machine-local, so the roadmap carries the record). Decided Against, not a
   revisit check: there is nothing to test until that skill exists.
8. **S8 tests** -- see Tests; all on synthetic sandbox roots.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/sitrep_root.sh` | New helper (steps 1-5); `chmod +x` |
| `.claude/skills/sitrep/SKILL.md` | Steps 1-8 (lines ~38, 193, 890, 965-969 named above), usage line, frontmatter description |
| `.agent/scripts/tests/test_sitrep_root.sh` | New, `chmod +x`: sandbox registry, project root with `.git`, `HOME` redirected |
| `.agent/scripts/tests/test_skill_paths.sh` | Guard: sitrep no longer says "workspace root only"; calls the helper |
| `.agent/scripts/tests/test_sitrep_checks.sh` | Project-shaped `ROADMAP.md` via `--roadmap`; project-sandbox cases through `skill_step` (section 13 pattern) |
| `docs/design.md` | Documentation layers sentence, Measures row ("per root"), Change log row |
| `docs/roadmap.md` | Remove deferral row; Decided Against entry; roadmap row for #418 |
| `.agent/knowledge/script_reference.md` | List `sitrep_root.sh` |

## Tests (one case per acceptance bullet, sandbox only, ADR-0003)

Helper and runner (`test_sitrep_root.sh`, `test_sitrep_checks.sh`):
- Project root with a Direction section in `docs/roadmap.md`: `roadmap=` set, `type=project`, `record_name=<name>`, workspace-shaped checks skipped with named reasons (including the Documentation fact); runner returns that project's rows.
- Project root without a Direction section: runner emits a `section` row, no lines invented.
- Workspace root (sandbox copy of the layout): `record_name=workspace`, all checks `run`, unchanged output.
- Order: both `docs/roadmap.md` and `ROADMAP.md` present gives `docs/roadmap.md`; only `ROADMAP.md` gives it.
- Hosting root with no repository, and a registered root inside the sandbox workspace tree with no repository of its own: `own_repo=no`, `pr_source=none`, step 6 git facts skipped. Project named `workspace`: `project:workspace`.
- Default branch `trunk` (no `main`): `default_branch=trunk`, behind-check works; no `origin/HEAD` and neither `main` nor `master`: "cannot tell".
- Directory outside every root: exit 1, nothing on stdout, no workspace fallback.
- `--worktrees`: a parent root's instance worktree and a package worktree are kept; another root's worktree is dropped.
- `--worktrees` from the workspace root with a worktree in `worktrees/workspace/`, a project worktree named by an `adapter --project <name>` Direction line (and one named by a `<owner/repo>#N` line), and a project worktree no workspace Direction line names: the first three are kept, the un-named project worktree is dropped (the narrowed acceptance bullet). For a project root session, a worktree of another root that its Direction does not name is dropped. Output is `{"worktrees": [...]}`; a failing `worktree_list.sh` gives a non-zero exit and its stderr, never `{"worktrees": []}`.
- Step 5 in a project sandbox with its own `docs/decisions`: the ADR title comes from the project's directory, not the workspace's; with a Decision register and a research digest in the project that are due, step 7 states the facts and offers nothing, and does not offer `/audit-workspace`.

The skill's own blocks for a project sandbox, run through `skill_step` as section 13 does for the workspace:
- Step 2: the last-record filter picks the last line whose column 2 is the project's `record_name`, ignoring workspace lines; project-first inbox lines come first with the same single pass.
- Step 4: the record line written has the project's `record_name` in column 2 and leaves workspace lines alone.
- Step 3: the worktree filter keeps only the root's worktrees; path words: Path 1 from the project's Direction, "no path (serves a project goal)", and none printed when `paths=none`.
- Step 5: title lookup uses `pr_source` (`none` gives the "unknown" title); the issue match uses only the root's own worktrees: a Direction-named worktree of another repository carrying the same issue number as a `(#N)` line is not printed as that issue's branch, in both a workspace and a project sandbox.

## Prior Art

`session_root.sh` (root, type, project), `_settings.sh`, `worktree_list.sh --json`,
`extract_gh_slug` and the runner's existing `--root/--roadmap` are reused. Nothing
else is built; the helper only gathers decisions now scattered through prose.

## Serves

Goals "Easy to use" and "The long view"; `docs/design.md#documentation-layers`,
`docs/design.md#sessions-and-roots`.

## Design Picture

Changes `docs/design.md#documentation-layers` (the "reads only the workspace root so
far" sentence), in this PR. `docs/design.md#sessions-and-roots` is unchanged.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| A change includes its consequences | Step 7 and the Consequences table cover description, Problems rule, the four workspace-only sentences, awk/printf/worktree filters, path words, record-name collision, Change log row |
| Test what breaks | One test per acceptance bullet plus the two edge cases |
| Only what's needed | No combined view; one helper, justified by removing root logic repeated across six step blocks |
| Leave in a project only what it chose to carry | Nothing written to the project; no Direction section reports and invents nothing |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0003 project-agnostic | Yes | Sandbox roots only; no project names in skill, helper or tests |
| 0016 session roots | Yes | Root from `session_root.sh`; hosting directory is the root, never a nested package |
| 0017 design current | Yes | `docs/design.md` updated in the same PR |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| Skill description and usage line | `test_skill_paths.sh` trigger-phrase guard (phrases kept) | Yes |
| Run-record column 2 | Step 2 awk filter, step 4 printf | Yes |
| Worktree filter | Steps 3 and 5 join rule text; the workspace report narrows to its own worktrees plus Direction-named ones (acceptance bullet on the issue edited by the host at PR time); step 5 matches own worktrees only; step 5 ADR-title path; step 3/step 8 text and example | Yes |
| New script | `script_reference.md`, exec bit | Yes |
| Inbox listing (#388 follows) | S4 reuses the existing pass so #388 stays the same size | Yes |
| Path words, title lookup, step 6 git facts | Approach 2 and 4 | Yes |
| Design Documentation layers and Measures | Change log row | Yes |

## Open Questions

None for the owner. Decided as mechanism, listed for veto: new helper script despite
the issue's "no new script"; deferral becomes Decided Against; #418 lands before #388. Out of scope, per the owner: any combined cross-root view. Decided by the owner (2026-11-09): the acceptance bullet "unchanged from today" is narrowed as in Approach 1; the host edits the issue's bullet at PR time.

## Estimated Scope

Single PR (~8 files). Still one PR: every part is the same change to the skill's root and shares the tests.
