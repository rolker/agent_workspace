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

One PR, five commits. Gate: start after #388 (inbox read once under a lock) merges;
it rewrites step 2 and step 4's inbox reads, which S4/S5 also touch. If #388 is
still open when work starts, rebase onto it before editing steps 2 and 4 and apply
S4/S5 to the snapshot values, not the old four passes.

1. **`.agent/scripts/sitrep_root.sh` (new, read-only, `chmod +x`)** — the one place
   the root is decided, so tests can reach it (skill prose cannot be tested; the
   issue's "no new script" would leave S1/S2/S3/S5 untested). It calls
   `session_root.sh` and prints `key=value` lines: `root=`, `type=`, `project=`,
   `record_name=` (the registered name; `workspace` for the workspace; a project
   literally named `workspace` is printed `project:workspace` so it cannot collide
   with the run-record column), `roadmap=` (first existing of `docs/roadmap.md`,
   `ROADMAP.md`, else empty), `pr_source=` (see 2), and one `check_<name>=run` or
   `check_<name>=skipped (<file> not in this root)` line per workspace-shaped check.
2. **S2 pull-request source** — `pr_source` is the GitHub slug of `origin` only when
   `git -C <root> rev-parse --show-toplevel` equals the root itself (a hosting
   directory with no repository of its own would otherwise resolve upward into the
   workspace repository, or a nested package). Otherwise `pr_source=none` and the
   report says "pull requests: no pull-request source for this root", never a guess.
   Step 3 and step 5's `gh pr list -R` use it. Worktrees come from
   `worktree_list.sh --json` filtered to the root: `type == "workspace"` for the
   workspace, `type == "project" and repo == <project>` for a project (replaces the
   hard-coded `type == "workspace"` filters in steps 3 and 5 and the join rule's
   wording).
3. **S1/S6 root and roadmap** — steps 1, 5, 6 take `ROOT` from the helper instead of
   `$WS_ROOT` (`$WS_ROOT` stays for scripts). Step 1 passes `--root "$ROOT"
   --roadmap "$roadmap"`; with `roadmap=` empty the runner's `section` row already
   says why and the report says "no Direction section in this project; onboarding
   offers one" and invents nothing. Acceptance paragraph, Paths and Suggested next
   read the same file; no Paths paragraph gives the existing `paths=none` branch.
4. **S3 Problems** — per-check file-exists tests in the helper: Decision register
   (`docs/design.md`), research digest (`.agent/knowledge/research_digest.md`),
   design anchors (`check_design_anchors.sh` and `docs/design.md`). A check whose
   file is absent prints one skip line naming the check and the file. Direction
   `format`/`unknown` rows and local-main-behind run for any root. The Problems rule
   "in a project session the section is the workspace's only" is replaced by this.
   Step 7 stays: start a due check only in a workspace session, offer otherwise.
5. **S4/S5 inbox and run record** — step 2 shows inbox lines whose `project` field
   equals the root's registered name first (workspace: unchanged). The run record's
   column 2 is `record_name`; `awk '$2 == "workspace"'` in step 2 and the `printf`
   in step 4 use it, so "since last run" compares with the last line for the same
   root and old records stay valid.
6. **S7 docs** — drop "This first mode reads the workspace root only" and fix the
   frontmatter description ("in a workspace session it may start..." keeps its
   meaning but adds "for the session's own root"). `docs/design.md` Documentation
   layers: the sit-rep reads the session's own root; a combined view is not part of
   it. Roadmap: delete the deferral row and add a Decided Against entry (combined
   cross-root sit-rep stays out of `/sitrep`; the owner placed it with a personal-
   root skill, 2026-11-09). Decided Against, not a revisit check: there is nothing
   to test for until that skill exists, and a blank check is what the row has today.
7. **S8 tests** — see Files; all on a synthetic sandbox root.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/sitrep_root.sh` | New helper (step 1-4); `chmod +x` |
| `.claude/skills/sitrep/SKILL.md` | Steps 1-7, usage line, frontmatter description |
| `.agent/scripts/tests/test_sitrep_root.sh` | New, `chmod +x`: sandbox registry, project root with `.git`, `HOME` redirected |
| `.agent/scripts/tests/test_skill_paths.sh` | Guard: sitrep no longer says "workspace root only"; calls the helper |
| `.agent/scripts/tests/test_sitrep_checks.sh` | Case: project-shaped `ROADMAP.md` run via `--roadmap` |
| `docs/design.md` | Documentation layers sentence |
| `docs/roadmap.md` | Remove deferral row; Decided Against entry; roadmap row for #418 |
| `.agent/knowledge/script_reference.md` | List `sitrep_root.sh` |

## Tests (one case per acceptance bullet, sandbox only, ADR-0003)

- Project root with a Direction section in `docs/roadmap.md`: `roadmap=` set, `type=project`, `record_name=<name>`, workspace-shaped checks skipped with named reasons; runner returns that project's rows.
- Project root without a Direction section: `roadmap=` set or empty, runner emits a `section` row, no lines invented.
- Workspace root (sandbox copy of the layout): `record_name=workspace`, all checks `run`, unchanged output.
- Order: both `docs/roadmap.md` and `ROADMAP.md` present gives `docs/roadmap.md`; only `ROADMAP.md` gives it.
- Hosting root with no repository: `pr_source=none`. Project named `workspace`: `project:workspace`.

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
| A change includes its consequences | Step 6 and the Consequences table cover description, Problems rule, awk/printf/worktree filters, record-name collision |
| Test what breaks | One test per acceptance bullet plus the two edge cases |
| Only what's needed | No combined view; one helper, justified because prose is untestable |
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
| Worktree filter | Steps 3 and 5 join rule text | Yes |
| New script | `script_reference.md`, exec bit | Yes |
| Inbox reads (#388) | Rebase order above | Yes |

## Open Questions

None for the owner. Decided as mechanism, listed for veto: new helper script despite
the issue's "no new script"; deferral becomes Decided Against; #388 lands first.

## Estimated Scope

Single PR (~8 files). Split only if the #388 rebase becomes tangled.
