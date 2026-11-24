# Plan: repos-manifest: remove the prototype's reader, and drop the roadmap line about moving from its format

## Issue

https://github.com/rolker/agent_workspace/issues/569

## Context

The prototype's reader handles a manifest with no top-level `repositories:` or `base:` key
(`cli.py` `cmd_resolve` and `cmd_validate` fall through to it when `has_repositories_key` is false).
Its only caller outside the tool is the `ros2_colcon` adapter's manifest route, which runs
`resolve --layout manifest-dir --cache-dir` (`_rc_manifest_resolve`). The owner (2026-11-24) says no
old-format manifest exists on any machine.

The adapter (`.agent/project_types/ros2_colcon/adapter.sh`, 2984 lines; the tests are
`.agent/scripts/tests/test_ros2_colcon.sh`) has three routes chosen by `_rc_route`: `tool` (root holds
`.repos-manifest/`), `manifest` (settings set `source`), `bootstrap` (neither). The bootstrap route is
separate code (`_rc_bootstrap_manifest`, curl and a clone, no resolver) and stays (see below).

All line numbers below were read from the files on this branch at `81c647ad`; the implementer
re-reads them, since part 2 moves everything.

## Decision on the bootstrap route

Left out. It calls none of the prototype's code, and removing it needs a fact only the owner has
(`docs/manifest/design.md`, "Retiring the bootstrap route"). Its roadmap line stays untrue after this
issue. Its error message that advises `source=` is changed in part 2 (it points at a removed route).

## Parts

Each is its own pull request, in order 1, 2, 3 (part 3 needs part 2: until the adapter stops calling
`--layout manifest-dir`, the reader cannot go). Part 1 is independent. PR titles start "#569 part N";
part 1 and 2 say "Part of #569", part 3 says "Closes #569". After each part every suite named under it
passes on its own, with the other parts not yet landed.

### Part 1: the tool roadmap line

1. `tools/repos-manifest/docs/roadmap.md` line 29: replace the row "The first resolver that reads the new
   format comes with a note on moving from the prototype's format, command and output layout" with
   "The prototype's reader and `docs/prototype.md` are removed".
2. No check is possible: `.agent/scripts/sitrep_checks.sh` (lines 157 to 178) has `file-exists`,
   `file-contains`, `adr-status`, `gh-issue` and `script`, and no absence check; `file-exists` on
   `prototype.md` is true while the file is there, the opposite. The check cell stays empty until part 3
   lands, then the line is true by reading. No new check kind is invented here.
3. Suites: `pytest tools/repos-manifest/tests/test_documents.py` and the pre-commit hooks on the changed file.

### Part 2: cut the adapter's manifest route

**Rule for the lists:** each function was listed with every line that names it; the keep list is what
has a caller after the cut, the delete list what has none. The implementer re-runs
`grep -n "\bname\b"` per function after the cut and removes any helper left with no caller
(`shellcheck` does not report an unused function).

**Delete (no caller after the cut):**
- The "Manifest route (issue #436)" header comment, lines 703 to 790 (it cites `prototype.md`, which part 3
  deletes).
- Lines 1402 to 1979: `_RC_TRANSPORTS`, `_rc_src_git`, `_rc_src_net`, `_rc_net_why`, `_rc_live_commit`,
  `_rc_source_fetch`, `_rc_resolve_begin`, `_rc_manifest_resolve`, `_rc_relabel_provenance`,
  `_rc_resolve_cleanup`, `_rc_mv_link_form`, `_rc_prune_unlocked`, `_rc_resolve_sweep`,
  `_rc_manifest_prepare`, `_rc_source_lock`, `_rc_source_unlock`, `_rc_resolved_from`,
  `_rc_validate_manifest_route`.
- Before them: `_rc_source_is_url` (1335; callers all inside the deleted range), `_rc_registry_field_missing`
  (1345; callers 422 in `_rc_distro`'s manifest branch, 1844, 1945), `_rc_file_stamp` (1361; callers 1637, 1956),
  `_rc_check_single_source` (1368; callers 1842, 1918).
- Outside those ranges: `_rc_pin_manifest_dir` (198), `_rc_unpin_manifest_dir` (232) and
  `_rc_remove_generated` (269; callers 1725, 1815, 1827, all deleted). Their variables `_RC_MDIR_PIN`,
  `_RC_MDIR_FD`, `_RC_WARNED_DIRLOCK`, and `ACTIVE_PROJECT_SOURCE_REF` / `_SOURCE_PATH` reads in the adapter go.

**Keep, with the caller that keeps it:**
- `_rc_source_setup` (1986): `_rc_tool_build` (2116), `adapter_build` (2189), `adapter_test` (2208, 2268, 2273).
  It sources a ROS setup file; every route uses it. It sits inside the old 1335-1990 range, so the deletion
  is by function, not by that range.
- `_rc_resolver_bin` (1390): tool route (835, 850, 1016, 1154, 2109) and the bootstrap error message (605).
- `_rc_name` (1340): the tool route (1286) and the new refusal. `_rc_layer_lines` (1354): tool route (868, 1024, 1029).
- `_rc_nofd`, `_rc_git_local_vars`: bootstrap route and tool route; only the comment about fds 8 and 9
  (the pin and the source lock) is trimmed.
- `_rc_bootstrap_url` (via 593), `_rc_yaml_scalar`, `_rc_bootstrap_manifest` (via `adapter_setup`).

**Shared helpers, and what changes in each:**
- `_rc_route` (792): returns `tool` or `bootstrap`; comment lines 788 to 791 rewritten. It stays pure (it
  is called inside `$(...)` about 20 times, so it cannot print or fail).
- `_rc_manifest_dir` (168): drop the `ACTIVE_PROJECT_SOURCE` branch and `_RC_MDIR_PIN`; tool route
  `resolved/<distro>`, else `configs/manifest`. Comment rewritten.
- `_rc_require_manifest` (283): drops its call to `_rc_pin_manifest_dir` (via `_rc_check_manifest`) and
  gains the refusal as its first line (below).
- `_rc_check_manifest` (295): drop `_rc_pin_manifest_dir` and the `elif ... ACTIVE_PROJECT_SOURCE` branch
  (303 to 307).
- `_rc_distro` (405): drop the manifest-route branch (419 to 431).
- `_rc_repos_file` (389): its comment says "the other two routes"; now "the bootstrap route".
- `adapter_setup` (2028), `adapter_sync` (2307), `adapter_validate` (2376): drop the `manifest` branches
  (2036 to 2046; 2310 and 2321; 2392 to 2396), the `route` variables where only that branch used them.
  `adapter_build` and `adapter_test` have no manifest branch today; they get the refusal through
  `_rc_require_manifest`.
- File header comments (lines 13, 18, 27, 126, 160 to 162, 372) and the comment at 2310 say "manifest route".

**The refusal (finding 6).** One function, `_rc_refuse_removed_source`: when `ACTIVE_PROJECT_SOURCE` is
set and `_rc_route` is not `tool`, print an error and return 1. It names the project, says `source` no
longer selects a route, and gives the way on: in the root run `<resolver> init <manifest> --distro-dirs
--distro <d> [--role <r>]`, register the root, and `project_setting.sh unset <name> source source_ref
source_path`. Callers: first line of `_rc_require_manifest` (reached by `env`, `build` off the tool route,
`test`, `validate`, `repos`, `worktree_repos`, `worktree_env`, `repo_pin`), and the first line of
`adapter_setup` and `adapter_sync`, which would otherwise reach `_rc_bootstrap_manifest`'s curl or the
bootstrap route first. `install`, `project_root` and `scope_for_pr` never read the manifest and are
unchanged (the test says so). A root with `source` set and `.repos-manifest/` still takes the tool route.
The settings keys `source`, `source_ref`, `source_path` stay in `_project_registry.sh`, `project_setting.sh`
and their tests: removing them is a separate workspace roadmap line.

**Tests (`test_ros2_colcon.sh`; 5885 lines).**
- Delete lines 2397 to 4012 (every `make_mr_*`, `write_mr_*`, `mr_*` helper and every `test_mr_*` function,
  which are 2524 to 3963) and their `mr_test test_mr_*` calls at 5815 to 5848.
- Keep lines 2334 to 2396 (renamed "toolchain for the tool-route tests"): `MR_SRC`, `MR_PY`, `MR_SKIPPED`,
  `mr_pick_python` and `mr_test`; the tool-route tests and the real-tool tests use them (4176, 4230, 4300,
  4807, 5463, 5582, 5652, and `mr_test` at 5849 to 5872). The "manifest-route tests" wording in their
  messages and the SKIPPED line at 5881 becomes "tool-route tests".
- Rewrite `test_bootstrap_no_url_names_source` (4013, called at 5812): the no-URL error must not advise
  `source=` and must name `init` and registering the root. Remove the `if` block at adapter.sh 602 to 604 and
  keep the manifest tool line at 605, so the message survives the cut and is tested.
- Add `test_source_without_tool_root_refused`: a project with `source=` set, no `.repos-manifest/`, for
  each of `setup sync build test validate env repos worktree_repos worktree_env repo_pin`: exit 1, the
  message above, and no `vcs`, `curl` or `git` call logged (the stubs' logs are empty). Add the control
  that the same settings with `.repos-manifest/` present reach the tool route, and that `install`,
  `project_root` and `scope_for_pr` are not refused.
- `test_register_project.sh` (700 to 740, "ros2_colcon from a source (#436)"): replace with registering a
  root where `repos-manifest init` ran (the test already builds the `$WS/.venv/bin/repos-manifest`
  wrapper), asserting setup runs and the gate passes; the check at 733 (`manifest-resolved` link) goes.
  Lines 683 to 690 ("--set source= does not choose the type"): re-read; if the refusal text points at
  `ros2_colcon` with `source` as a way forward, update the text and the test. `test_project_file.sh`,
  `test_project_registry.sh`, `test_adapter.sh` test the settings keys, which stay.

**Documents.**
- `docs/design.md` (root) changes in this PR (ADR-0017, ADR-0022): the Registry and adapters bullet, lines
  484 to 496 and the tail of 473 (`configs/manifest-resolved`): two routes; the manifest route text,
  the one-source rule and "`register_project.sh ... --set source=` runs `setup`" go; "`source` does not choose
  the type" goes with them; the change log rows at 1178 to 1185 stay as history, one new row says the
  route was cut, #569 part 2. `docs/design.md#registry-and-adapters` is the section.
- `docs/manifest/design.md`: lines 51 and 60 to 110 (the route list, "The manifest route, step by step", its
  guarantees and the lock at 107), 72, 270 ("bootstrap and manifest routes"), 361 ("Which route"), 403
  (`source_ref` as a commit), 439 to 446 (the settings keys and how they map), 459 (generated
  directories and the link); then re-grep the file for "manifest route", `source` and `manifest-resolved`.
- `docs/manifest/roadmap.md`: the line "The adapter's own manifest fetch and generated directories are
  removed" becomes true (no absence check exists); the deferrals at 48 (#481) and the one citing #447 are
  now due: named in the PR for the owner, not closed here.
- `.agent/projects.local.example` lines 44 to 52 and 76 to 94: register a manifest-built instance by running
  `repos-manifest init` in the root, then registering the root; the `source*` key notes say the keys are no
  longer read by any route (still accepted, to be removed).
- `.agent/scripts/register_project.sh`: header lines 33 to 37 (`--set source=` text) and the setup-failure
  hint at 1135 ("its bootstrap_url or source" becomes "its bootstrap_url").
- Registration from a manifest, as documented everywhere above: run `repos-manifest init` in the root, then
  register the root (`register_project.sh` detects `.repos-manifest`, line 626).

**Suites that prove part 2** (run as the repo's `make test` names them; pre-commit and the full suite pass
are left to CI, per the standing rule): `.agent/scripts/tests/test_ros2_colcon.sh`, `test_register_project.sh`,
`test_adapter.sh`, `test_project_file.sh`, `test_project_registry.sh`, `test_design_anchors.sh`,
`.agent/scripts/validate_adapter.sh`, and `pytest tools/repos-manifest/tests` (unchanged, still green
because the reader is still there). `shellcheck` on `adapter.sh` through pre-commit.

### Part 3: remove the reader (closes #569)

**Source modules in `tools/repos-manifest/src/repos_manifest/`, from the imports:**
- Delete `schema.py` (435 lines; importers: `selectors`, `emit`, `extends`, `merge`, `cli`), `merge.py`
  (importers: `emit`, `cli`, `validate`, `selectors`), `selectors.py` (`cli`, `validate`, `emit`),
  `validate.py` (`cli` only), `emit.py` (`cli` only; the new reader writes through `output.py`) and
  `extends.py` (`cli` only; `base.py` imports nothing from it, so nothing in it is shared).
- `cli.py`: remove the imports of `emit`, `extends`, `merge`, `schema`, `selectors`, `validate`;
  `ManifestError` is imported from `.yamlload` (where `schema.py` took it from). Remove `_load_merged`,
  `_require_old_flags`, the old halves of `cmd_resolve` and `cmd_validate` (so `cmd_resolve_new` and
  `cmd_validate_new` become `cmd_resolve` and `cmd_validate`), the `--layout` and `--cache-dir` options
  and their two "earlier format" refusals and the "not available yet" refusal. `read_problem` and
  `has_repositories_key` in `manifest.py` have no caller left once these go (grep: only `cli.py` calls
  them); remove both. The docstring at the top and `__init__.py` ("prototype") are rewritten.
- A manifest with no `repositories:` or `base:` key then goes to the new reader, which already refuses the
  earlier keys (`manifest.py` 433 to 440: "is in the earlier format (it has `repos:` ... and no
  `repositories:`); this tool reads it only in the format of the specification"). The test below asserts it
  for `resolve`, `show` and `validate`; if the message lacks a pointer to `docs/spec.md`, add the phrase.

**Tests (every file read for what it imports and what it calls):**
- Delete whole files: `test_extends.py`, `test_extends_safety.py`, `test_acceptance_p11.py`,
  `test_schema.py`, `test_selectors.py`, `test_validate.py`, `test_layout.py`.
- `test_untrusted_input.py` (imports `schema.parse_manifest_text`; its tests are about `extends` and the
  p11 manifest's URLs): delete; before that, for each property it checks (control characters, URL allow
  list, secrets not printed) confirm `test_manifest_reading.py`, `test_masking.py` or `test_fetch_from.py`
  covers it for the new reader, and port the missing ones.
- `test_cli.py`: the cases at 8, 30, 50, 86 to 103 (p11 manifest, the `resolve_chain` monkeypatch,
  `--cache-dir`) go; the `show` and distro cases (135 to 192) stay.
- `test_masking.py` 286 to 304: the earlier-format `extends` URL test goes (its `--cache-dir` argument);
  the rest stays.
- `test_output.py`: the `--layout manifest-dir` test (772 to 774) and the p11 case (842) go; the rest uses the
  new reader.
- `test_documents.py` lines 13 to 15: the `prototype.md` exclusion goes.
- `test_project11.py` reads `fixtures/p11/expected` (lines 15, 22, 57): keep `fixtures/p11/expected` where it
  is (the new reader's output is compared with it); only `fixtures/p11/manifest.yaml` is deleted.
- `test_base_reading.py` 296 to 301 uses `fixtures/p11/manifest.yaml` as a base the new reader must refuse:
  rewrite it with a small earlier-format manifest written in the test (`roles:`, `layers:`, `repos:`), same
  assertion.
- Add the acceptance test in `test_manifest_reading.py` or `test_cli.py`: a manifest with no `repositories:`
  or `base:` key and the earlier keys (taken from the old p11 manifest's shape, written inline) makes `resolve`,
  `show` and `validate` exit non-zero with the message naming the earlier format, and no file under `--out`.
  Also: `--layout` and `--cache-dir` are no longer accepted (argparse exits 2).

**Documents:** delete `tools/repos-manifest/docs/prototype.md`; update `README.md` (3: status line; 216 to
217), `docs/spec.md` (5), `docs/design.md` (634, 1059, 1085, and the section at 2185 to 2192 about the
prototype, each re-read against what it says now; this is the tool's own design, ADR-0022),
`docs/fork_parity.md` and `docs/roadmap.md` (check each hit). Root `docs/roadmap.md:273` is history ("The
resolver prototype landed on PR #268"); it stays unless it reads as current. Before closing:
`grep -rniI "prototype\|manifest-dir\|earlier format\|resolve_chain" tools/repos-manifest .agent docs`
outside `work-plans/`; each remaining hit is history or unrelated and is named in the PR.

**Suites that prove part 3:** `pytest tools/repos-manifest/tests` (no parallel flag needed), plus
`.agent/scripts/tests/test_ros2_colcon.sh` (its tool-route tests run `repos_manifest.cli resolve` with the
new format) and `test_register_project.sh`.

## Waits for the owner's yes (not made without one)

- `.github/workflows/validate.yml:67`, the job name "repos-manifest tests (#267 prototype)". CI
  configuration, Ask First. Checked: `main` has no required status checks (the only ruleset, `require_pr`,
  has the rules deletion, non_fast_forward and pull_request), so branch protection does not name the job; the
  rename to "repos-manifest tests" is only a label, and still waits for his yes.
- Step 4 of the issue: issue #498's "existing user" section. It is another issue's text; a proposed
  replacement is shown to the owner in the part 3 PR, and the implementer does not edit it. Proposed: one
  sentence, "No manifest in the earlier format exists (owner, 2026-11-24, #569), so nothing needs to be kept
  working for an existing user." after reading #498 to see what the section says today.

## Prior Art

Nothing new is built. The new reader (`base.py`, `manifest.py`) stays as the one reader and already refuses
the earlier keys. The roadmap's check vocabulary has no absence check; none is added. The tool route's
refusal of a root it cannot use (`_rc_tool_unusable`) is the model for the new refusal's message: it names
the way out with the tool's own commands.

## Serves

Workspace goal "Light touch on projects" (`README.md#workspace-goals`; less for a project to keep working,
no document describing what is gone), `docs/design.md#registry-and-adapters` (part 2) and
`tools/repos-manifest/docs/design.md#where-the-manifest-comes-from` (part 3).

## Design Picture

The design picture changes. Part 2 changes how the adapter's routes fit (three become two), so the root
design document, `docs/design.md#registry-and-adapters`, changes in the same PR (ADR-0017), and so does
`docs/manifest/design.md`; the root text is the boundary text that names `source` and the resolver call
(ADR-0022). Part 3 changes the tool's own design (`tools/repos-manifest/docs/design.md`, the prototype
sections) in its PR; the root design is not touched again there.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Only what's needed | Removes a reader and a route with no user; the bootstrap route stays, as it is not part of this goal |
| Keep one current design | Each part updates every document that describes what it removes, in the same PR |
| Fail loudly | A root with `source` and no tool root is refused at one shared point for every manifest-reading verb, with a test over ten verbs; an earlier-format manifest is refused naming the format, tested |
| Consequences checked | Delete lists are from callers and imports; re-grep before closing; tests and fixtures go with the code, and the fixtures the new reader's tests use are kept or re-pointed |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0017 | Yes | Root design changes in part 2, the tool's design in part 3 |
| ADR-0022 | Yes | The root design keeps only what crosses the boundary; the tool's inside goes in its own design |
| ADR-0013 | Yes | Plan recorded as a Plan Authored entry |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| Adapter's manifest route | root `docs/design.md`, `docs/manifest/design.md`, `docs/manifest/roadmap.md`, `projects.local.example`, `register_project.sh`, the bootstrap error, tests | Yes, part 2 |
| `--layout manifest-dir` | adapter first (part 2), then tool, its tests and spec | Yes, order matters |
| The reader's modules | `cli.py` imports, nine test files, `p11` fixture, `__init__.py` | Yes, part 3 |
| `prototype.md` | README, spec, design, `test_documents.py` | Yes, part 3 |
| CI job name | `validate.yml` | Waits for the owner's yes |
| Issue #498 text | the issue | Proposed to the owner |

## Open Questions

- Owner: yes to renaming the CI job (branch protection does not name it)?
- Owner: the proposed trim of #498.
- Owner: is the bootstrap route's removal wanted next, as its own issue, once every instance is on the tool?

## Estimated Scope

Three PRs. Part 1 is one line. Part 2 removes about 650 lines of adapter and about 1700 lines of tests and
edits five documents. Part 3 removes six modules and seven test files, one document, and edits about eight.
