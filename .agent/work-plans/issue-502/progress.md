---
issue: 502
---

# Issue #502 — repos-manifest: status shows what differs from the manifest

## Issue Review
**Status**: complete
**When**: 2026-11-20 11:25 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #502

### Scope Assessment

**Well-scoped?** Yes, with one gap — one PR can hold it, and it should: `status` reads what `sync` already knows (per-repo `HEAD`, `state.yaml` records, the rule ladder in `update.py`: `find_version`, `same_version`, `commit_on_origin`, `tracked_changes`, `ancestor`, `count`) and changes nothing on disk. The gap is that the issue's "What to build" lists states and facts (commits not on `origin`, where it was fetched from, the several-distro default) that `tools/repos-manifest/docs/design.md#status` (three sentences) does not yet describe, and the script-readable form is unsettled (below).
**Right repo?** Yes — the code and design are under `tools/repos-manifest/` in the workspace repo. The issue still says `tools/ros-manifest/`; the tool is now `tools/repos-manifest/` and `cli.py` has `resolve`, `validate`, `init`, `sync`, `build` but no `status`.
**Serves**: Easy to use (and Trust, control and information) — `tools/repos-manifest/docs/design.md#status`, within `docs/manifest/design.md` ("What the tool has to give")
**Design picture?** Changes `tools/repos-manifest/docs/design.md#status`. The section is too thin to build from: it lacks the extra states, where each repo was fetched from, the several-distro default, and a script-readable form with an exit status. #495 (closed) settled the distro layout, not these, so the issue's own condition for building the script form here is not met. The same change must update that section (ADR-0017) and tick the roadmap row.
**Dependencies**: none open. Builds on #500 / PR #535 (`sync` over existing clones). `docs/manifest/design.md` and the workspace `validate` row depend on this: the adapter cannot become thin until a script-readable status exists.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Keep one current design | Action needed | `tools/repos-manifest/docs/design.md#status` does not cover what the issue asks (states, origin-fetched-from, script form, exit status). Owner decision needed: build the script-readable form and exit status in this issue, or only the human form now and a follow-up for the script form. The plan should state the answer and the design update lands in the same change. |
| Verify before claiming / tests | OK | Acceptance asks for tests with local git repos per state; the existing `sync` tests show how to build them. |
| Only what's needed | Watch | `status` should reuse the `update.py` rule ladder read-only rather than a second classifier, so `status` and `sync` cannot disagree on what "expected version" means. Do not copy the rules. |
| Put each thing at the level it applies to | OK | Tool-level work; the workspace `validate` change stays with the thin-adapter step. |
| Ask about what matters | Watch | Accepted by hand on project11 is on the owner's machine; the owner has an agent working in ~/project11, so that check is not run by agents. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0017 design is the current picture | Yes | Update `tools/repos-manifest/docs/design.md#status` in the same change. |
| ADR-0022 a part owns its inside | Yes | The design change stays in the part's design; the root's `docs/manifest/design.md` changes only where what crosses the boundary changes (the script form it asks for). |
| ADR-0013 progress entries | Yes | This entry. |

### Consequences

- Tool design `#status` section, `tools/repos-manifest/docs/roadmap.md` row "`status` shows what differs from the manifest", `tools/repos-manifest/README.md` command list, and `docs/manifest/roadmap.md` / `docs/manifest/design.md` lines that say "there is no `repos-manifest status` yet" or "not built yet" once it lands.
- The issue text's `ros-manifest` paths are stale; the plan uses `repos-manifest`.

### Recommendations

- Settle with the owner whether the script-readable form (including role and distros the directory was set up for) and the exit status for a missing repo are built here; if yes, the plan writes them into the design first.
- Build `status` read-only on the `update.py` helpers and `state.yaml`, adding no write path; test that nothing on disk changes.
- Cover each state with local git repos: expected, different version, local changes, commits not on `origin`, missing, skipped optional, no longer in manifest, and fetched-from; plus a several-distro system directory and `--distro`.
- Leave the by-hand project11 check to the owner; do not run anything in ~/project11.

### Actions
- [ ] `tools/repos-manifest/docs/design.md#status` does not cover what the issue asks (states, origin-fetched-from, script form, exit status). Owner decision needed: build the script-readable form and exit status in this issue, or only the human form now and a follow-up for the script form. The plan should state the answer and the design update lands in the same change.
- [ ] Settle with the owner whether the script-readable form (including role and distros the directory was set up for) and the exit status for a missing repo are built here; if yes, the plan writes them into the design first.
- [ ] Build `status` read-only on the `update.py` helpers and `state.yaml`, adding no write path; test that nothing on disk changes.
- [ ] Cover each state with local git repos: expected, different version, local changes, commits not on `origin`, missing, skipped optional, no longer in manifest, and fetched-from; plus a several-distro system directory and `--distro`.
- [ ] Leave the by-hand project11 check to the owner; do not run anything in ~/project11.

## Checkpoint
**Status**: complete
**When**: 2026-11-20 11:27 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

"Build both here (Recommended)"

Asked with the issue review's scope finding in the dialog: the issue lists "a form a script can read, and an exit status for a missing repo" as not in scope unless issue 495 had settled them, and issue 495 did not. The question was whether issue 502 builds the script-readable form and the exit status too, with the plan writing them into the tool's design first. His answer puts both in scope. The other choices offered were the human-readable form only with a follow-up issue, or holding the drive.

## Plan Authored
**Status**: complete
**When**: 2026-11-20 11:31 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-502/plan.md` at `768ed207`

Design text for `status` (states, facts, `--json` form, exit status) is written into the plan to land first in the tool's design; then `update.py` gets an `ask` parameter and shared `standing` and `blocked` helpers so `status` reads the sync ladder offline, then `status.py`, the CLI block, tests and the ADR-0017 doc updates. Ten decisions are listed for veto.
