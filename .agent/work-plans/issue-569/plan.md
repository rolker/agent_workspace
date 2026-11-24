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
`.agent/scripts/tests/test_ros2_colcon.sh`, 5887 lines) has three routes chosen by `_rc_route`: `tool`
(root holds `.repos-manifest/`), `manifest` (settings set `source`), `bootstrap` (neither). The bootstrap
route is separate code (`_rc_bootstrap_manifest`, curl and a clone, no resolver) and stays (see below).

Status: part 1 is delivered (pull request 571, merged 2026-11-24). Parts 2 and 3 are not started.

Line numbers below were re-read on this branch at `df2f5010` (2026-11-24, after part 1 merged and main
moved: the merges since the plan was first written changed `test_ros2_colcon.sh` by two lines near
its start, `worktree_create.sh` and others, and none changed `adapter.sh`). A function or test name
is the reference where one exists; the implementer re-reads numbers, since part 2 moves everything.

## Decision on the bootstrap route

Left out. It calls none of the prototype's code, and removing it needs a fact only the owner has
(`docs/manifest/design.md`, "Retiring the bootstrap route"). Its roadmap line stays untrue after this
issue. Its error message that advises `source=` is changed in part 2 (it points at a removed route).

## Decision on `ros2_colcon/unused_settings` (host, for the owner's veto)

`.agent/project_types/ros2_colcon/unused_settings` does NOT gain `source`, `source_ref` and `source_path`
in this issue. Issue 332's rule (a setting is never stored and silently ignored) would put them there, but
the workspace-side roadmap (`docs/manifest/roadmap.md`) has its own line for removing those keys, and the
tool route's `_rc_tool_validate` already names a leftover one ("a second record of the manifest ... remove it
with: project_setting.sh unset"). After part 2 the keys are accepted by `set` for a `ros2_colcon` project
and refused at use by `_rc_refuse_removed_source` (below), never silently ignored.

## Parts

Each is its own pull request, in order 1, 2, 3 (part 3 needs part 2: until the adapter stops calling
`--layout manifest-dir`, the reader cannot go). PR titles start "#569 part N"; part 1 and 2 say
"Part of #569", part 3 says "Closes #569". After each part every suite named under it passes on its own,
with the other parts not yet landed.

### Part 1: the tool roadmap line (delivered: pull request 571, merged 2026-11-24)

Done: `tools/repos-manifest/docs/roadmap.md` line 29 now reads "The prototype's reader and
`docs/prototype.md` are removed" (read on this branch). No check is possible for it:
`.agent/scripts/sitrep_checks.sh` has `file-exists`, `file-contains`, `adr-status`, `gh-issue` and `script`
and no absence check, so the check cell stays empty until part 3 lands, then the line is true by reading.
No new check kind is invented. Nothing of part 1 is left to do.

### Part 2: cut the adapter's manifest route

**Rule for the lists:** each function was listed with every line that names it; the keep list is what
has a caller after the cut, the delete list what has none. The implementer re-runs
`grep -nw name` per function after the cut and removes any helper left with no caller
(`shellcheck` does not report an unused function).

**Delete (no caller after the cut), `adapter.sh`:**
- The "Manifest route (issue #436)" header comment (from its `# --- Manifest route` line, 701, to just
  before the "Tool route" header; it cites `prototype.md`, which part 3 deletes).
- From `_rc_registry_field_missing` area to `_rc_validate_manifest_route`: `_RC_TRANSPORTS`, `_rc_src_git`,
  `_rc_src_net`, `_rc_net_why`, `_rc_live_commit`, `_rc_source_fetch`, `_rc_resolve_begin`,
  `_rc_manifest_resolve`, `_rc_relabel_provenance`, `_rc_resolve_cleanup`, `_rc_mv_link_form`,
  `_rc_prune_unlocked`, `_rc_resolve_sweep`, `_rc_manifest_prepare`, `_rc_source_lock`,
  `_rc_source_unlock`, `_rc_resolved_from`, `_rc_validate_manifest_route` (lines 1402 to 1979: from
  `_RC_TRANSPORTS` to the end of `_rc_validate_manifest_route`, which ends just above the comment of
  `_rc_source_setup`).
- Before them: `_rc_source_is_url` (1335; callers all inside the deleted range), `_rc_registry_field_missing`
  (1345; callers in `_rc_distro`'s manifest branch and inside the deleted range), `_rc_file_stamp` (1361;
  callers inside the deleted range), `_rc_check_single_source` (1368; callers inside the deleted range).
- Outside those ranges: `_rc_pin_manifest_dir` (198), `_rc_unpin_manifest_dir` (232) and
  `_rc_remove_generated` (269; callers all in deleted functions). Their variables `_RC_MDIR_PIN`,
  `_RC_MDIR_FD`, `_RC_WARNED_DIRLOCK` go.
- The reads of `ACTIVE_PROJECT_SOURCE_REF` / `ACTIVE_PROJECT_SOURCE_PATH` go only where they sit inside the
  deleted functions (1473 to 1474 in `_rc_source_fetch`, 1661 to 1674 in `_rc_manifest_resolve`, 1931 to
  1932 in `_rc_validate_manifest_route`). **They stay in `_rc_tool_validate` (1292 to 1294: `source`,
  `source_ref`, `source_path` and `bootstrap_url` as the "second record" keys; the tool route's check).**
  `test_tool_route_order` asserts this check and keeps asserting it.

**Keep, with the caller that keeps it:**
- `_rc_source_setup` (1986): `_rc_tool_build`, `adapter_build`, `adapter_test`. It sources a ROS setup
  file; every route uses it. It sits inside the old 1335 to 1990 range, so the deletion is by function, not
  by that range.
- `_rc_resolver_bin` (1390): tool route (`_rc_tool_sync_step`, `_rc_tool_unusable`, `_rc_tool_sync`,
  `_rc_tool_status`, `_rc_tool_build`) and the bootstrap error message (line 605).
- `_rc_name` (1340): the tool route (`_rc_tool_validate`) and the new refusal. `_rc_layer_lines` (1354): tool
  route.
- `_rc_nofd`, `_rc_git_local_vars`: bootstrap route and tool route; only the comment about fds 8 and 9
  (the pin and the source lock) is trimmed.
- `_rc_bootstrap_url`, `_rc_yaml_scalar`, `_rc_bootstrap_manifest` (via `adapter_setup`).

**Shared helpers, and what changes in each:**
- `_rc_route` (792): returns `tool` or `bootstrap`; the comment above it (lines 788 to 791) rewritten. It
  stays pure (it is called inside `$(...)` about 20 times, so it cannot print or fail).
- `_rc_manifest_dir` (168): drop the `ACTIVE_PROJECT_SOURCE` branch and `_RC_MDIR_PIN`; tool route
  `resolved/<distro>`, else `configs/manifest`. Comment rewritten.
- `_rc_require_manifest` (283): gains the refusal as its first line (below); its call chain no longer pins.
- `_rc_check_manifest` (295): drop `_rc_pin_manifest_dir` and the `elif ... ACTIVE_PROJECT_SOURCE` branch
  (303 to 307).
- `_rc_distro` (405): drop the manifest-route branch (the `if [ -n "${ACTIVE_PROJECT_SOURCE:-}" ]` block at
  419 to 431).
- `_rc_repos_file` (389): its comment says "the other two routes"; now "the bootstrap route".
- `adapter_setup` (2028), `adapter_sync` (2307), `adapter_validate` (2376): drop the `manifest` branches
  (`adapter_setup` 2037 to 2046; `adapter_sync` the `route = manifest` block at 2321 and the comment at
  2310; `adapter_validate` 2392 to 2396), and the `route` variables where only that branch used them.
  `adapter_build` and `adapter_test` have no manifest branch today; they get the refusal through
  `_rc_require_manifest`.
- The comments that say "manifest route" outside the deleted ranges (`grep -n 'manifest route'` gave lines
  13, 27, 126, 161, 162, 189, 372, 416 and 2310) are rewritten.
- Line 603 to 604 of `_rc_bootstrap_manifest`: remove the `if [ -n "${ACTIVE_PROJECT_NAME:-}" ]` block
  that advises `source=`, and keep the manifest tool line (605), so the no-URL message survives the cut.

**The refusal.** One function, `_rc_refuse_removed_source`: when `ACTIVE_PROJECT_SOURCE` is set and
`_rc_route` is not `tool`, print an error and return 1. It names the project, says `source` no longer
selects a route, and gives the way on: in the root run `<resolver> init <manifest> --distro-dirs --distro <d>
[--role <r>]`, register the root, and `project_setting.sh unset <name> source source_ref source_path`.
Callers: first line of `_rc_require_manifest` (reached by `env`, `build` off the tool route, `test`,
`validate`, `repos`, `worktree_repos`, `worktree_env`, `repo_pin`), and the first line of `adapter_setup`
and `adapter_sync`, which would otherwise reach `_rc_bootstrap_manifest`'s curl or the bootstrap route
first. `install`, `project_root` and `scope_for_pr` never read the manifest and are unchanged (the test says
so). A root with `source` set and `.repos-manifest/` still takes the tool route. The settings keys
`source`, `source_ref`, `source_path` stay in `_project_registry.sh`, `project_setting.sh` and their tests:
removing them is a separate workspace roadmap line (and see the decision on `ros2_colcon/unused_settings`).

**`single_project/unused_settings`** (the reason text for `source`, `source_ref`, `source_path` ends "only a
`ros2_colcon` project reads it ...: register it as type ros2_colcon", false after this part). New text, lines
9 to 11 of the file:
```
source a single_project checkout is cloned by hand and nothing resolves a source for it (a source for every type is issue #473); no project type reads it as a manifest now, and a ros2_colcon root gets its manifest from the manifest tool's init, run in the root
source_ref a single_project checkout is cloned by hand and nothing resolves a source for it (a source for every type is issue #473); no project type reads it now, and a ros2_colcon root gets its manifest from the manifest tool's init, run in the root
source_path a single_project checkout is cloned by hand and nothing resolves a source for it (a source for every type is issue #473); no project type reads it now, and a ros2_colcon root gets its manifest from the manifest tool's init, run in the root
```
The assertions follow: `test_project_file.sh` (in the loop "single_project refuses the three", line 1894:
`assert_contains "... names the type to use" "register it as type ros2_colcon"`) becomes
`assert_contains "single_project set ${v%%=*}: names the manifest tool's init" "gets its manifest from the manifest tool's init" "$out"`,
with the `assert_not_contains ... "give the type ros2_colcon"` line kept; the comment above it ("saying to
register as ros2_colcon") is reworded. `test_register_project.sh` (the "--set source=... does not choose the
type" test, line 688, and its echo at 683 and comment at 682) checks `*"nothing resolves a source for it"*`
and now `*"gets its manifest from the manifest tool's init"*` instead of `*"register it as type ros2_colcon"*`;
the echo says "is refused, naming the manifest tool". `validate_adapter.sh` checks each entry has a reason: the
new lines have one.

**Tests (`test_ros2_colcon.sh`).**
- Delete from `make_mr_resolver` (line 2399; the block starts after `mr_test`, which ends at 2396) through the
  end of `test_mr_one_source_only` (just above the `test_bootstrap_no_url_names_source` function, 4015): every
  `make_mr_*`, `write_mr_*`, `mr_*` helper and `test_mr_*` function (the `test_mr_*` functions run from 2526).
  Delete their `mr_test test_mr_*` calls (5817 to 5850, `test_mr_wrapper_runs_this_checkouts_resolver`
  through `test_mr_one_source_only`) and the call `test_bootstrap_no_url_names_source` (5814).
- Keep lines 2336 to 2396 (renamed "toolchain for the tool-route tests"): the header comment, `MR_SRC`, `MR_PY`,
  `MR_SKIPPED`, `mr_pick_python` and `mr_test`; the tool-route tests and the real-tool tests use them
  (`MR_SRC`/`MR_PY` at 4178, 4232, 4302, 4809, 5465, 5584, 5654, and `mr_test` for every tool test at 5851 to 5874).
  The "manifest-route tests" wording in their messages and the SKIPPED line at 5881 becomes "tool-route tests".
- Delete `test_bootstrap_no_url_names_source` (4015). The error text it checked is covered by the existing
  `test_bootstrap_no_url_names_the_tool` (5526), which already asserts `init <manifest> --distro-dirs
  --distro <distro>` for the no-URL error; add to it `assert_not_contains "does not advise source=" "source="`
  on the same output (the no-URL message after the cut has no `source=` text; check that the output has no
  other `source=` before writing the assertion).
- Fold the refusal's tests into `test_tool_route_order` (4346), not a new function where that works:
  - Keep its `source` plus `.repos-manifest/` cases and its assertion that validate names `source` and how to
    remove it ("project_setting.sh unset toolsys source"): that is the control, "the same settings with
    `.repos-manifest/` present reach the tool route".
  - Drop `assert_not_contains "validate does not take the manifest route" "resolved-from"` (4360): after the
    cut there is no manifest route to take, so it is vacuous.
  - Add `test_source_without_tool_root_refused` only for the part that cannot be folded: a project with
    `source=` set, no `.repos-manifest/`, for each of `setup sync build test validate env repos worktree_repos
    worktree_env repo_pin`: exit 1, the message above, and **nothing fetched or imported**: an empty
    `$sb/vcs.log` and no `$sb/curl.log` (the stubs `make_toolchain_stubs` makes: `vcs`, `curl`; there is no
    git stub, and a refusal that names the resolver through `_rc_resolver_bin` itself runs `git rev-parse`,
    so a "no git call" assertion would be wrong). `install`, `project_root` and `scope_for_pr` are not
    refused (exit 0 or their own result, no refusal text).
- `test_register_project.sh`, the "ros2_colcon from a source (#436)" test (echo at 692): **no replacement
  test is added.** `register_project.sh` runs setup only when the root does not exist (its
  `adapter --project <name> setup (<root> does not exist)` step, line 1133), so a root where `init` ran gets
  no setup, and the tool-route registration test ("a root the manifest tool set up, in no git repository",
  line 1058) already covers it. Delete only the test: from the `echo "TEST: ros2_colcon from a source"` line and
  the `MW=` fixture through `out="$(reg "$WS" --remove tau)"` (inside the `if [ -n "$MR_PY" ]` body). **Keep**
  the `MR_SRC` / `MR_PY` finder (the `_common=` loop, lines 698 to 706), the `.venv/bin/repos-manifest` wrapper
  and the `python3` link (708 to 713, which line 1141 uses), the `if [ -n "$MR_PY" ]` guard and its
  fail-or-skip `else` branch (735 to 742); the tool-route test at 1063 depends on `MR_PY`. Re-point the
  finder's comment ("the tool route's ... tests"). The comment above the #436 echo (692 to 697) says what the
  finder is for; reword it, not the logic.
- `test_project_file.sh`, `test_project_registry.sh`, `test_adapter.sh` test the settings keys, which stay;
  `test_project_file.sh` also changes at 1894 (above).

**Documents.**
- `docs/design.md` (root) changes in this PR (ADR-0017, ADR-0022): the Registry and adapters bullet, lines
  473 (the tail, `configs/manifest-resolved`) and 484 to 496: two routes; the manifest route text, the
  one-source rule and "`register_project.sh ... --set source=` runs `setup`" go; "`source` does not choose
  the type" goes with them; the change log rows at 1178 to 1185 stay as history, one new row says the route
  was cut, #569 part 2. `docs/design.md#registry-and-adapters` is the section.
- `docs/manifest/design.md`: lines 39 (`source_ref`), 51, 60 to 110 (the route list, "The manifest route,
  step by step", its guarantees and the lock), 72, 206, 270 ("bootstrap and manifest routes"), 361 ("Which
  route"), 403 (`source_ref` as a commit), 439 to 446 (the settings keys and how they map), 459 (generated
  directories and the link); then re-grep the file for "manifest route", `source` and `manifest-resolved`.
- `docs/manifest/roadmap.md`: the line "The adapter's own manifest fetch and generated directories are removed"
  (line 33) becomes true (no absence check exists); the deferrals at 47 (#447) and 48 (#481), "once the
  adapter's fetch code is cut", are now due: named in the PR for the owner, not closed here.
- Root `docs/roadmap.md` line 273 (row 4, Manifest support): "the adapter's manifest route with #436, whose
  acceptance is still open" is a present-tense claim about a route that is gone. Reword to what stands (the
  resolver prototype landed on PR #268; the adapter's tool route is what calls the resolver; acceptance is the
  manifest sub-roadmap's), leaving the history clause as history. Only present-tense claims change.
- Root `docs/fork_parity.md` (not under `tools/repos-manifest/docs/`), line 83: "the resolver is a tested
  prototype nothing calls (#267, closed)" is already stale (the tool route calls the tool). Edit the claim in
  part 2 where it concerns what the adapter calls; the "new-format manifest is only a test fixture" half
  refers to `fixtures/p11/manifest.yaml`, which part 3 deletes (that edit is in part 3).
- `.agent/projects.local.example` lines 44 to 52 and 76 to 94: register a manifest-built instance by running
  `repos-manifest init` in the root, then registering the root; the `source*` key notes say the keys are no
  longer read by any route (still accepted, to be removed).
- `.agent/scripts/register_project.sh`: header lines 33 to 37 (`--set source=` text) and the setup-failure
  hint at 1135 ("its bootstrap_url or source" becomes "its bootstrap_url").
- `.agent/project_types/single_project/unused_settings` lines 9 to 11 (text above).
- Registration from a manifest, as documented everywhere above: run `repos-manifest init` in the root, then
  register the root (`register_project.sh` detects `.repos-manifest`, line 626).

**Suites that prove part 2** (run as the repo's `make test` names them; pre-commit and the full suite pass
are left to CI, per the standing rule): `.agent/scripts/tests/test_ros2_colcon.sh`, `test_register_project.sh`,
`test_adapter.sh`, `test_project_file.sh`, `test_project_registry.sh`, `test_design_anchors.sh`,
`.agent/scripts/validate_adapter.sh`, and `pytest tools/repos-manifest/tests` (unchanged, still green
because the reader is still there). `shellcheck` on `adapter.sh` through pre-commit.

### Part 3: remove the reader (closes #569)

**Source modules in `tools/repos-manifest/src/repos_manifest/`, from the imports:**
- Delete `schema.py` (importers: `selectors`, `emit`, `extends`, `merge`, `cli`), `merge.py` (importers:
  `emit`, `cli`, `validate`, `selectors`), `selectors.py` (`cli`, `validate`, `emit`), `validate.py` (`cli`
  only), `emit.py` (`cli` only; the new reader writes through `output.py`) and `extends.py` (`cli` only;
  `base.py` imports nothing from it, so nothing in it is shared).
- `cli.py`: remove the imports of `emit`, `extends`, `merge`, `schema`, `selectors`, `validate` (lines 21 to
  22, 25, 27 to 28, 43); `ManifestError` is imported from `.yamlload` (where `schema.py` took it from). Remove
  `_load_merged`, `_require_old_flags`, the old halves of `cmd_resolve` and `cmd_validate` (so
  `cmd_resolve_new` and `cmd_validate_new` become `cmd_resolve` and `cmd_validate`), the `--layout` and
  `--cache-dir` options (parser, lines 302 to 311 and 325) and the refusals that name them in
  `cmd_resolve_new` and `cmd_validate_new` ("not available yet", "--cache-dir is for a manifest in the
  earlier format"). `read_problem` and `has_repositories_key` in `manifest.py` have no caller left once these
  go (grep: only `cli.py` calls them); remove both. The docstring at the top of `cli.py` and `__init__.py`
  ("prototype") are rewritten.
- A manifest with no `repositories:` or `base:` key then goes to the new reader, which already refuses the
  earlier keys (`manifest.py`, the message "is in the earlier format (it has `repos:` ... and no
  `repositories:`); this tool reads it only in the format of the specification"). The test below asserts it
  for `resolve`, `show` and `validate`; if the message lacks a pointer to `docs/spec.md`, add the phrase.

**Tests (every file read for what it imports and what it calls):**
- Delete whole files: `test_extends.py`, `test_extends_safety.py`, `test_acceptance_p11.py`,
  `test_schema.py`, `test_selectors.py`, `test_validate.py`, `test_layout.py`.
- `test_untrusted_input.py` (imports `schema.parse_manifest_text`; its tests are about `extends` and the
  p11 manifest's URLs): delete; before that, for each property it checks (control characters, URL allow
  list, secrets not printed) confirm `test_manifest_reading.py`, `test_masking.py` or `test_fetch_from.py`
  covers it for the new reader, and port the missing ones.
- `test_cli.py`: the cases that use the p11 manifest (`test_cli_resolve_writes_files`,
  `test_cli_resolve_unknown_role_errors`, `test_cli_validate_clean`) and
  `test_cli_resolve_out_that_cannot_be_created_is_one_line` (the `--out` case is covered for the new reader by
  `test_output.py`'s own `--out` test) go; the `show` and distro cases stay.
  **`test_cli_any_other_exception_is_one_fixed_line` is ported, not deleted**: it is the only test of
  `cli.main`'s internal-error backstop (the `except Exception` arm that prints `ERROR: internal error
  (<type>)`). Change its monkeypatch from `cli.resolve_chain` to `cli.read_manifest` (the new reader's
  entry that `_load_new` calls, which both new commands call first, so the patch is reached before any file is read), keep the five error types, the two commands, the exact-line assertion and the
  `marker not in out` assertion; the argv carries a manifest path that need not exist.
- `test_masking.py` (the earlier-format `extends` URL test, with `--cache-dir` at line 304; read 286 to 304):
  goes; the rest stays.
- `test_output.py`: the `--layout manifest-dir` test (772 to 774), **the `--cache-dir` refusal test (776 to
  780, "--cache-dir is for a manifest in the earlier format"; argparse then exits 2, so the case goes or
  becomes the "no longer accepted" case below)** and the p11 case (842) go; the rest uses the new reader.
- `test_documents.py` lines 13 to 16 (the comment and the `prototype.md` exclusion in `DOCUMENTS`) go.
- `test_project11.py` reads `fixtures/p11/expected` (line 15): keep `fixtures/p11/expected` where it is (the
  new reader's output is compared with it); only `fixtures/p11/manifest.yaml` is deleted.
- `test_base_reading.py` (line 298 uses `fixtures/p11/manifest.yaml` as a base the new reader must refuse):
  rewrite it with a small earlier-format manifest written in the test (`roles:`, `layers:`, `repos:`), same
  assertion.
- Add the acceptance test in `test_manifest_reading.py` or `test_cli.py`: a manifest with no `repositories:`
  or `base:` key and the earlier keys (taken from the old p11 manifest's shape, written inline) makes `resolve`,
  `show` and `validate` exit non-zero with the message naming the earlier format, and no file under `--out`.
  Also: `--layout` and `--cache-dir` are no longer accepted (argparse exits 2).

**Documents:** delete `tools/repos-manifest/docs/prototype.md`; update `README.md` (3: status line; 216 to
217), `docs/spec.md` (5), `docs/design.md` (634, 1059, 1085, and the section at 2185 to 2192 about the
prototype, each re-read against what it says now; this is the tool's own design, ADR-0022) and
`docs/roadmap.md`: **the row at line 31 ("The resolver no longer has the package dependency section, roles
defined by starting packages, or the cache of parents kept between runs") becomes true in this part**; the check cell stays empty (no absence check), and the PR names it. The root `docs/` files
(not the tool's): `docs/fork_parity.md:83` ("the new-format manifest is only a test fixture here
(`tools/repos-manifest/tests/fixtures/p11/manifest.yaml`)") loses the path of the deleted fixture;
root `docs/roadmap.md:273` is history ("The resolver prototype landed on PR #268") and stays unless it reads
as current. Before closing: `grep -rniI "prototype\|manifest-dir\|earlier format\|resolve_chain" tools/repos-manifest .agent docs`
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
the way out with the tool's own commands. The existing tool-route tests (`test_tool_route_order`,
`test_bootstrap_no_url_names_the_tool`, the tool-route registration test) are extended rather than
duplicated.

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
| Only what's needed | Removes a reader and a route with no user; the bootstrap route stays, as it is not part of this goal; `ros2_colcon/unused_settings` is not widened (the roadmap has its own line for the keys) |
| Keep one current design | Each part updates every document that describes what it removes, in the same PR, including the reason text a refusal shows |
| Fail loudly | A root with `source` and no tool root is refused at one shared point for every manifest-reading verb, with a test over ten verbs; an earlier-format manifest is refused naming the format, tested; the CLI's internal-error backstop keeps its test |
| Consequences checked | Delete lists are from callers and imports; re-grep before closing; tests and fixtures go with the code, and the helpers and fixtures the kept tests use (`MR_SRC`/`MR_PY`, `fixtures/p11/expected`) are kept |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0017 | Yes | Root design changes in part 2, the tool's design in part 3 |
| ADR-0022 | Yes | The root design keeps only what crosses the boundary; the tool's inside goes in its own design |
| ADR-0013 | Yes | Plan recorded as a Plan Authored entry |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| Adapter's manifest route | root `docs/design.md`, root `docs/roadmap.md` (273), root `docs/fork_parity.md`, `docs/manifest/design.md`, `docs/manifest/roadmap.md`, `projects.local.example`, `register_project.sh`, `single_project/unused_settings` and its two test files, the bootstrap error, tests | Yes, part 2 |
| `--layout manifest-dir` | adapter first (part 2), then tool, its tests and spec | Yes, order matters |
| The reader's modules | `cli.py` imports, nine test files (one ported), `p11` manifest fixture, `__init__.py`, tool roadmap row 31 | Yes, part 3 |
| `prototype.md` | README, spec, design, `test_documents.py`, root `fork_parity.md` | Yes, part 3 |
| CI job name | `validate.yml` | Waits for the owner's yes |
| Issue #498 text | the issue | Proposed to the owner |

## Open Questions

- Owner: yes to renaming the CI job (branch protection does not name it)?
- Owner: the proposed trim of #498.
- Owner: is the bootstrap route's removal wanted next, as its own issue, once every instance is on the tool?
- Owner's veto, decided by the host: `ros2_colcon/unused_settings` does not gain the `source*` keys here.

## Estimated Scope

Three PRs; part 1 is delivered (PR 571). Part 2 removes about 650 lines of adapter and about 1700 lines of
tests and edits about nine documents and files. Part 3 removes six modules and seven or eight test files,
one document, and edits about eight.
