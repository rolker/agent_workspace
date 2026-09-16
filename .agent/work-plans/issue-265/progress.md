---
issue: 265
---

# Issue #265 — Step 5: hosted projects under projects/ with project-rooted sessions and per-project CLAUDE.md

## Plan
**Status**: complete
**When**: 2026-09-15 14:29
**By**: Claude Code Agent (claude-sonnet-5)

Plan file: `.agent/work-plans/issue-265/plan.md`.

Formalizes `projects/<name>/` as the primary hosting shape: `adapter setup`
renders a per-project `CLAUDE.md` from a per-type template; the legacy
`project/` symlink gets a deprecate-and-warn path (not hard removal) with
a migration helper; out-of-tree projects use a physical bind-mount under
`projects/<name>/` (per the logical-vs-physical-path test in the issue
comment) rather than a symlink, since Claude Code resolves `process.cwd()`
past symlinks and never walks the logical ancestor chain; the `.claude/`
launch-dir limitation (skills/hooks/commands not ancestor-walked) is
documented, not worked around.

## Plan (revision 2)

**Status**: complete
**When**: 2026-09-16
**By**: Claude Code Agent (claude-fable-5-1)

Plan rewritten as the design-B definition after the owner's 2026-09-16
direction (issue comments) and the eight-experiment spike
(`spike-results.md`, Claude Code 2.1.273; four experiments re-run by the
owner with real credentials). Projects live anywhere; separate session
roots; worktrees under each root; workspace + project layers injected by a
registry-gated user-tier SessionStart hook (ancestor loading does not cross
a worktree boundary, so ancestry is not relied on); registry gains
`parent`/`worktrees`/`role`/`distro`; `project/` and `projects/` retired
outright; four additive PRs; acceptance test on real `gz4d` issues. Design A
recorded as set aside with the finding that removed its advantage. Manifest
support (step 4) re-scoped to #267 (general ROS manifest resolver).

## Plan review

**Status**: complete (findings applied)
**When**: 2026-09-16
**By**: independent Sonnet reviewer via /review-plan; findings applied by Claude Code Agent (claude-fable-5-1)

Nine findings, one Concern (user-tier allow-rules for scripts with no
registry awareness). Applied: `require_registered_root` guard + generated
allow-list manifest + behaviour test; legacy no-entry worktree fallback for
the PR 2→4 window; heading-drift test for the SessionStart renderer;
`dashboard.sh` substring logic called out; parent-root instance selection
decided (pending owner confirmation); project11 cycle stated as not
depending on #267; `registry_resolve_from_dir` claim corrected; discovery-
order change moved into the new ADR; PR title fixed. Review posted on PR
#266.

## Implement — PR 1 of 4 (registry)

**Status**: complete
**When**: 2026-09-16
**By**: Claude Code Agent (claude-fable-5-1)

Commit `35ea1ed`: trailing `key=value` registry fields (`parent`,
`worktrees`, `role`, `distro`, `default_instance`), parent roots
(pseudo-type `project`), `registry_entries_full` / `registry_field` /
`registry_instances` / `registry_default_instance` /
`registry_worktree_dir` (legacy fallback until PR 4) /
`registry_require_root`; adapter parent→instance resolution and
`ACTIVE_PROJECT_ROLE/DISTRO`; ros2_colcon distro from the registry with
manifest-mismatch hard error; worktree_create parent handling; validate and
dashboard parent awareness; Python parser parity. 15 new tests; all suites
green; pre-commit clean. Docs: ARCHITECTURE.md, WORKTREE_GUIDE.md,
projects.local.example, ROADMAP rows for steps 4/5 and cutover rows 1–3.

## Local Review
**Status**: complete
**When**: 2026-09-16 17:40 -04:00
**By**: independent reviewer (claude-sonnet-5), fresh context, in-process
**Verdict**: changes-requested

**PR**: #266 at `90b8c62`
**Mode**: post-PR
**Depth**: standard (reason: registry/adapter/worktree-lifecycle infrastructure)
**Must-fix**: 6 | **Suggestions**: 5
**Round**: 1 | **Ship**: continue — six open must-fixes incl. a parser whose result depends on the caller's cwd

### Findings
- [x] (must-fix) unquoted `$rest` word-splits with pathname expansion — `_project_registry.sh:97`
- [x] (must-fix) CRLF: shell keeps `\r` in paths, Python strips it (parity) — `_project_registry.sh:72`
- [x] (must-fix) absolute `worktrees=` outside the root passes parse but fails `registry_require_root` — `_project_registry.sh:130`
- [x] (must-fix) legacy fallback concatenates an unvalidated name (`../../outside`) — `_project_registry.sh:348`
- [x] (must-fix) parent→instance resolution only in create; enter/remove use the raw name — `worktree_enter.sh:167`, `worktree_remove.sh:144`
- [x] (must-fix) dashboard reports a parent with zero instances as healthy — `dashboard.sh:160`
- [x] (suggestion) two entries resolving to one canonical path accepted — `_project_registry.sh:360`
- [x] (suggestion) registry `distro=` regex allows hyphens; adapter's does not — `ros2_colcon/adapter.sh:158`
- [x] (suggestion) plan names `require_registered_root`; code is `registry_require_root` — `plan.md:249`
- [ ] (suggestion) workflow script branches on the pseudo-type vs ADR-0011 — `worktree_create.sh:337` (deferred to the new ADR, PR 3)
- [x] (suggestion) "first definition wins" stated only in the Python parser — `_project_registry.sh` header

## Integrated Review
**Status**: complete
**When**: 2026-09-16 17:45 -04:00
**By**: Claude Code Agent (claude-fable-5-1)

**PR**: #266 at `90b8c62`
**Sources**: Copilot round 1 (4, at `9b790c5`), Copilot round 2 (6, at `90b8c62`), Local Review round 1 (11)
**Cross-source confirmations**: 5 — unquoted glob, `worktrees=` root bound, legacy-fallback name, create/enter/remove inconsistency, stale plan name (Copilot r2 ∩ Local Review r1); dashboard empty-parent (Copilot r2 ∩ Local Review r1)
**Local-only**: CRLF parity, aliased paths, distro regex parity, config-fallback comment, doc asymmetry
**False positives**: none

### Fix plan
- [x] all six must-fixes (see Local Review round 1)
- [x] aliased/duplicate canonical paths rejected in both parsers
- [x] distro regex aligned with ros2_colcon; role keeps hyphens
- [x] ros2_colcon comment: ROS_DISTRO config is a pure fallback
- [x] plan.md helper name
- [ ] ADR-0011 pseudo-type branch — carried to the new ADR (PR 3)

## Implementation
**Status**: complete
**When**: 2026-09-16 17:58 -04:00
**By**: Claude Code Agent (claude-fable-5-1)

**PR**: #266 at `063b76b`
Addressed every open item of the Integrated Review in one commit
(`063b76b`) with tests: glob safety, CRLF, worktrees bound, fallback name
validation, aliased paths, distro/role regexes, create/enter/remove round
trip via the shared `registry_resolve_project_arg`; Python parity test
extended. Registry suite 146, adapter 86, ros2_colcon 184; pre-commit and
CI green. Next: re-review (round 2) for the ship verdict.

## Local Review
**Status**: complete
**When**: 2026-09-16 13:17 -04:00
**By**: independent reviewer (claude-sonnet-5), fresh context, round 2
**Verdict**: changes-requested

**PR**: #266 at `063b76b`
**Mode**: post-PR
**Depth**: standard (reason: registry/adapter/worktree-lifecycle infrastructure)
**Must-fix**: 2 | **Suggestions**: 3
**Round**: 2 | **Ship**: recommended (must-fix count down from 6 to 2, both mechanical, not rising) — apply the two fixes in this round, then merge

### Findings
- [ ] (must-fix) `_registry_field_of` still does unquoted `for f in $fields` (word-splitting/pathname expansion on every getter call — `registry_field`, `worktrees`/`parent`/`default_instance` lookups all go through it) — `_project_registry.sh:230`
- [ ] (must-fix) root-bound check (`_registry_path_under`, both parsers) is lexical only; `worktrees=../outside` is accepted and resolves one level above the workspace root (confirmed empirically in both the shell and Python parser) — `_project_registry.sh:165`, `lib/workspace.py:168`
- [ ] (suggestion) plan.md still names the guard `require_registered_root` at one of its three mentions; the other two were fixed to `registry_require_root` — `plan.md:247`
- [ ] (suggestion) the "python parser agrees with the shell parser" test never runs the shell parser — it only runs `workspace.read_projects_registry()` and diffs against a hard-coded string, so a shell-side regression would not be caught — `test_project_registry.sh:811`
- [ ] (suggestion, carried from round 1, unchanged) `worktree_create.sh` branches directly on the `project` pseudo-type instead of routing through the adapter, per ADR-0011 — deferred to the new ADR (PR 3) — `worktree_create.sh:339`

## Implementation
**Status**: complete
**When**: 2026-09-16 18:40 -04:00
**By**: Claude Code Agent (claude-fable-5-1)

**PR**: #266 (round-2 fixes)
Both round-2 must-fixes closed: `_registry_field_of` iterates an array
(no globbing on any getter call); `worktrees=` and entry paths are
lexically normalized before the containment check in both parsers, so
`../outside` is rejected and an in-root `..` is kept normalized. The two
suggestions closed too: the last stale `require_registered_root` mention
in plan.md; the parity test now runs BOTH parsers on one sandbox (13
lines incl. CRLF, alias collision, `..` escape, distro regex) and asserts
identical entries and errors. Deferred, unchanged: the ADR-0011
pseudo-type note (new ADR, PR 3). Registry suite 154, adapter 86,
ros2_colcon 184, merge_pr 5; pre-commit clean.
