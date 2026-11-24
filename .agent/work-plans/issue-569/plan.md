# Plan: repos-manifest: remove the prototype's reader, and drop the roadmap line about moving from its format

## Issue

https://github.com/rolker/agent_workspace/issues/569

## Context

The prototype's reader handles a manifest with no top-level `repositories:` or `base:` key
(`cli.py` `_load_merged`, `extends.py` `resolve_chain` and its parent cache, `emit.py`
`--layout manifest-dir`, `--cache-dir`). Its only caller is the `ros2_colcon` adapter's manifest
route. The owner (2026-11-24) says no old-format manifest exists on any machine.

What the adapter's routes are, read from `adapter.sh` and `docs/manifest/design.md`: three routes,
chosen by `_rc_route` (line 792): `tool` (root holds `.repos-manifest/`), `manifest` (settings file
sets `source`), `bootstrap` (neither).

- The **manifest route** is the "older route" the host named. It is the only caller of
  `resolve --layout manifest-dir` (`_rc_manifest_resolve`, line 1625). It is about 650 lines of
  adapter code (`_rc_source_*`, `_rc_src_*`, `_rc_live_commit`, `_rc_manifest_resolve`,
  `_rc_resolve_*`, `_rc_manifest_prepare`, `_rc_source_lock`, `_rc_validate_manifest_route`,
  `_rc_source_setup`, roughly lines 1335 to 1990), a 90-line header comment (703 to 790), and its
  branches in `adapter_setup`, `adapter_build`, `adapter_test`, `adapter_sync`, `adapter_validate`.
  Its tests are the section "manifest route (issue #436)" of `.agent/scripts/tests/test_ros2_colcon.sh`,
  lines 2334 to 4024 (about 1700 lines of 5885), plus manifest-route cases in
  `test_project_file.sh`, `test_register_project.sh` and `test_project_registry.sh` to be checked.
- The **bootstrap route** is separate code: `_rc_bootstrap_url`, `_rc_bootstrap_manifest`
  (lines 553 to 700, curl and a clone, no resolver, no `--layout manifest-dir`), tested at
  test_ros2_colcon.sh 1165 to 1414. It does not use the prototype.

## Decision on the bootstrap route

Left out of this issue. It is not a caller of the prototype, so removing it does not serve this
issue's goal. It is the default route for any root with no `.repos-manifest/` and no `source`,
so removing it needs the fact that every instance is on the tool, which only the owner has
(`docs/manifest/design.md`, "Retiring the bootstrap route"). Its roadmap line (`docs/manifest/roadmap.md`,
"The bootstrap route is removed") stays untrue after this issue.

## Parts

Each is its own pull request. A later run tells which are delivered by the PR titles starting
"#569 part N" and by this list.

### Part 1: the tool roadmap line (PR body says "Part of #569")

1. In `tools/repos-manifest/docs/roadmap.md`, replace the row "The first resolver that reads the
   new format comes with a note on moving from the prototype's format, command and output layout"
   with "The prototype's reader and `docs/prototype.md` are removed".
2. Check: none is possible. The vocabulary in `.agent/scripts/sitrep_checks.sh` (lines 157 to 178)
   has `file-exists`, `file-contains`, `adr-status`, `gh-issue` and `script`, and no absence
   check; `file-exists` on `prototype.md` would be true while the file is there, the opposite.
   The cell stays empty until part 3 lands, then the line is true by reading.
   Do not invent a new check kind in this issue.
3. The row is wrongly "true" no sooner than part 3: the line is stated as the goal, and the
   sitrep shows it as not yet true until a check or a read says otherwise. Acceptable.

### Part 2: cut the adapter's manifest route (PR body says "Part of #569")

1. `adapter.sh`: delete the manifest route functions and header comment listed above, and the
   `manifest` branches in the five verbs. `_rc_route` returns `tool` or `bootstrap` only.
   A root with `source` set and no `.repos-manifest/` gets an error naming the reason (the
   manifest route is removed; set the root up with `repos-manifest init`), not a fall-through
   to the bootstrap route's curl. Check which helpers the tool route and registration still use
   (`_rc_source_is_url`, `_rc_name`, `_rc_check_single_source`, `_rc_file_stamp`, `_rc_layer_lines`)
   and keep those. The settings keys `source`, `source_ref`, `source_path` stay: removing them is a
   separate workspace roadmap line.
2. Tests: delete the "manifest route (issue #436)" section of test_ros2_colcon.sh; add tests for
   the `source`-set-without-tool-root error on each verb (`setup`, `sync`, `build`, `test`,
   `validate`) with the message and a non-zero exit; re-point or delete the manifest-route cases in
   the three other test files.
3. Documents: `docs/manifest/design.md`: remove "The manifest route, step by step" and its
   guarantees, rewrite the three-route list and "Which route an instance is on" to two routes,
   and update line 72's resolve call; `docs/manifest/roadmap.md`: the line "The adapter's own
   manifest fetch and generated directories are removed" becomes true (no check is possible for
   absence; a `file-contains` cannot assert absence). The two deferrals "once the adapter's
   fetch code is cut" (#447, #481) become due: note them in the PR for the owner, do not close
   them here.
4. Validate: `.agent/scripts/tests/test_ros2_colcon.sh`, and the other three test files, run as
   the repo's `make test` names them; the pre-commit suites run by CI (memory: dispatched agents
   skip the full local pass).

### Part 3: remove the reader (PR body says "Closes #569")

1. `cli.py`: a manifest with no `repositories:` or `base:` key exits non-zero with a message that
   names the unread format (the earlier shape: `repos:`, `extends:`, `optional_layers:` or
   `packages:` keys) and points at `docs/spec.md`. Remove `_load_merged`, the `--cache-dir`
   option and its two "earlier format" refusals, the prototype dispatch.
2. `extends.py`: remove `resolve_chain`, the parent cache (`_clone_or_reuse`, `_cache_key`) and
   whatever only they use; keep what the new `base:` reader shares (check by test run and grep).
   `emit.py`: remove `LAYOUT_MANIFEST_DIR` and its writer. `__init__.py` docstring: drop
   "prototype".
3. Tests: delete `test_layout.py` cases, `test_output.py` and `test_untrusted_input.py` cases
   that only cover the removed code, `tests/fixtures/p11/manifest.yaml` (the only old-format
   manifest) and any fixture only they use; keep or re-point what also covers the new reader.
   Add the acceptance test: a manifest with no `repositories:` or `base:` key exits non-zero and
   the message names the unread format (in `test_cli.py` or `test_manifest_reading.py`), for
   `resolve`, `show` and `validate`.
4. Documents: delete `tools/repos-manifest/docs/prototype.md`; update `README.md` (line 3 status
   and lines 216 to 217), `docs/spec.md` (line 5), `docs/design.md` (lines 634, 1059, 1085 and the
   section about the prototype at 2185 and after, each re-read against what it says now),
   `tests/test_documents.py` (lines 13 to 15, the prototype.md exclusion), `adapter.sh` comment
   citing `prototype.md` (goes with part 2's deleted block; confirm), `docs/roadmap.md:273`
   (history; stays unless it reads as current), `docs/fork_parity.md` (check line 83 against
   what it says), `host_standing_rules.md` (matches only "prototypes" as a word; no change).
5. Before closing: `grep -rniI "prototype\|manifest-dir"` over the repo outside `work-plans/`;
   each remaining hit is history or unrelated and is named in the PR.
6. The tool's own tests and the adapter's pass (name the commands in the PR).

## Waits for the owner's yes (not made without one)

- `.github/workflows/validate.yml:67`: the job name "repos-manifest tests (#267 prototype)". CI
  configuration, Ask First. The label is only a name; propose "repos-manifest tests". If it is
  renamed, branch protection required-check names may refer to it; check that with the owner.
- Step 4 of the issue: issue #498's "existing user" section. It is another issue's text, so a
  proposed replacement is shown to the owner in the part 3 PR and the issue; the implementer does
  not edit it. Proposed text: replace the section with one sentence, "No manifest in the earlier
  format exists (owner, 2026-11-24, #569), so nothing needs to be kept working for an existing user."
  after reading #498 to see what the section says today.

## Prior Art

Nothing new is built. The new reader (`base.py`, `manifest.py`) stays as the one reader. Checked:
the roadmap's check vocabulary has no absence check; none added.

## Serves

Workspace goals: projects and quality of the work (less to keep working, no document describing
what is gone); `docs/design.md#registry-and-adapters` and
`tools/repos-manifest/docs/design.md#where-the-manifest-comes-from`.

## Design Picture

Part 2 changes the workspace's picture of the adapter (three routes become two):
`docs/manifest/design.md`, in the same PR. Part 3 changes the tool's own design
(`tools/repos-manifest/docs/design.md`, the prototype sections), in the same PR. The root
`docs/design.md` does not change: what crosses the boundary (the adapter calls the tool's
`sync`, `build`, `status`) is the same.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Only what's needed | Removes a reader and a route with no user; the bootstrap route is kept because it is not part of this goal |
| Keep one current design | Each part updates its documents in the same PR |
| Fail loudly | Old-format manifest and `source` with no tool root both error with a named reason, tested |
| Consequences checked | Re-grep before closing; tests and fixtures go with the code |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0017 | Yes | Design documents updated per part |
| ADR-0022 | Yes | Tool changes go in the tool's design; the root design is untouched |
| ADR-0013 | Yes | Plan recorded as a Plan Authored entry |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| Adapter's manifest route | `docs/manifest/design.md`, `docs/manifest/roadmap.md`, its tests | Yes, part 2 |
| `--layout manifest-dir` | adapter (part 2 first), tool tests, spec | Yes, order matters: part 2 before part 3 |
| `prototype.md` | README, spec, design, test_documents.py | Yes, part 3 |
| CI job name | validate.yml | Waits for the owner's yes |
| Issue #498 text | the issue | Proposed to the owner |

## Open Questions

- Owner: yes to renaming the CI job (and does branch protection name it)?
- Owner: the proposed trim of #498.
- Owner: is the bootstrap route's removal wanted next (a separate issue), once every instance is on the tool?

## Estimated Scope

Three PRs. Part 1 is one line. Part 2 is about 650 lines of adapter and 1700 lines of tests
removed. Part 3 is a few hundred lines of tool code and tests removed, one document deleted.
