# Plan: Loop defects from the GeoZui4D drives (#428)

## Issue

https://github.com/rolker/agent_workspace/issues/428

## Context

Five small loop defects. Main has moved since the issue was written (Issue Review, db67719d; Checkpoint, 6a9d00e4). This is the second revision, after the Plan Review at 21ffdc89 (needs-work, second review); the first revision answered the Plan Review at 7bffcb35. Changes in this revision: the `notice_only` key, the review-wait bound, the project-with-no-slug skip, the narrower `dynamic/` exclusion, the creation-note wording, and the split into two parts. All five items are work; each ends with a test or a recorded reason. Not folded in: #362, #431, #521. The issue body is not edited.

Hard rule for every command written into this plan or run for it: a parallel build or test command always names its job count (for example `run_script_tests.sh -j 4`).

## Approach

Two parts on this one issue and timeline (run-issue step 13): **Part 1** is items 1, 2, 3 and 5; **Part 2** is item 4 alone. Part 1's pull request body says `Part of #428`; only Part 2's says `Closes #428`. Commit per item. An implementer handed Part 1 touches none of the Part 2 files listed in Files to Change (`_issue_helpers.sh`, `worktree_create.sh`, their tests, `test_ros2_colcon.sh`, `test_sitrep_checks.sh`, and the `test_merge_pr_gate.sh` hang-3 fixtures and `serve_shim`). Part 1 and Part 2 both edit `test_merge_pr_gate.sh` (Part 1: workflow fixtures and cases; Part 2: hang-3 fixtures), so Part 2 starts from main after Part 1 merges. Each item heading below is marked with its part.

1. **[Part 1] Item 1: the rule goes into text the host reads when writing a handoff, and into the handoff itself.** (Review finding 7: placement kept; test wording changed.)
   - `dispatch_phase.sh` `cmd_handoff`: add one sentence to the `conventions=` line for every phase: a parallel build or test command always names its job count, for example `-j 4` or `--parallel 4`; this holds for text copied from an issue or plan too. The sentence is worded so the flags appear only with a count.
   - `.claude/skills/run-issue/SKILL.md`: one paragraph in the dispatch handoff section (near the existing `conventions=` paragraph) stating the rule and that the host checks text it copies into a handoff.
   - `.agent/knowledge/host_standing_rules.md`: one row with the reason (an OOM-killed compiler took the session down). The orchestrator skill points at that file, so it needs no edit; cross-reference #431 (its item 11) in the PR text.
   - Test in `test_dispatch_phase.sh`: the handoff of each phase type (implement, plan-task, review-code at least) contains the counted examples `-j 4` and `--parallel 4`. It does not assert the absence of a bare flag, because the rule's own wording would trip that.
   - **Guard in `dispatch_phase.sh`: not added.** The script prints the handoff; the host writes the text that carries the flag and the script never sees it. A guard could only scan `--prompt-file` or the issue body, which is not where the bare flag came from (an implement agent's own command copied from issue text). A check that cannot see the failure catches nothing.
2. **[Part 1] Item 2: count only workflow files that can register a check; no message change.** (Review finding 1.)
   - Verified read-only: `gh api repos/rolker/geozui4d/actions/workflows` returns `total_count: 1` with one workflow, name `Copilot`, path `dynamic/agents/copilot-pull-request-reviewer`, state `active`. The repo has no workflow files, yet the count is 1, so `merge_pr.sh` (~1890-1898, `.total_count // 0`) never reaches `no-ci` and goes to `never-registered` after the 120 s grace: the two GeoZui4D runs (PR 10 on 2026-11-02, PR 14 on 2026-11-09). The earlier plan's route (empty slug, an `unknown` count) is dropped: `PR_REPO_SLUG` was `rolker/geozui4d`, and an empty slug fails earlier (`repos//commits/<sha>/check-runs` is rejected, so the run ends at `api-error`); the sandbox only passed because its stub answered `repos//...`. No real route to the empty-slug message was found, so that message change is dropped.
   - Change in `merge_pr.sh`: request `repos/<slug>/actions/workflows?per_page=100`; the count becomes the number of entries with `.state == "active"` that are not on a fixed leave-out list. The list holds only paths known never to register a check to wait for on a pull request: the hosted reviewer's own two paths, `dynamic/agents/copilot-pull-request-reviewer` and `dynamic/copilot-pull-request-reviewer/copilot-pull-request-reviewer` (the same reviewer `MERGE_PR_CI_EXCLUDE_CHECK_RUN` already excludes), and the known non-pull-request `dynamic/dependabot/` and `dynamic/pages/` prefixes. Every other entry counts: `.github/workflows/` files, and `dynamic/github-code-scanning/codeql` (code scanning's default setup does put check-runs on pull requests, so a merge run before they register keeps its grace wait). A disabled workflow registers no checks, so it is not counted. Known gaps, recorded in the script header and the PR text, not fixed: (1) a workflow file that runs only on other events (tag, schedule) still gives `never-registered` and the `--no-wait` hint after 120 s; parsing `on:` is not worth it; (2) required checks from an outside app with no workflow file already count 0 today and still do. When `total_count` is larger than the number of entries returned (a list past one page), the count is `unknown`, never 0; a missing `workflows` array or non-JSON stays `unknown` (as today). A repo with a real `.github/workflows` file keeps the existing path (`never-registered` text with the path-filter hint is correct there). The `no-ci` branch keeps the pending-review hold unchanged.
   - Fixtures: about 17 `total_count` lines in `test_merge_pr_gate.sh` are bare `{"total_count":N}` with no `workflows` array. They are rewritten through one helper (`workflows_json <n_files> [dynamic]`) that emits the real shape (`workflows` entries with `path`, `state`, and `total_count`). `workflows_path()` gains `?per_page=100` in one place (`api_key` maps the whole string to the fixture file name; check `?` and `=` survive in file names).
   - Tests (`test_merge_pr_gate.sh`): (a) real shape: both reviewer `dynamic/` paths, no checks, expects `no-ci` and no 120 s wait; (b) the same with a pending review check-run still holds (review-pending rule unchanged); (c) one `.github/workflows/ci.yml` entry, no checks, still gives `never-registered`; (d) `total_count: 150` with 100 entries gives `unknown` (waits, then errors), not `no-ci`; (e) a disabled `.github/workflows/` entry only gives `no-ci`; (f) a `dynamic/github-code-scanning/codeql` entry, no checks, still gives `never-registered` (counted).
   - `never-registered` / `failed` / `api-error` wording is unchanged (it is the existing tested text); recorded as the reason not to touch it.
3. **[Part 1] Item 3: make the tree writable before removal, in `worktree_remove.sh`.** (Review finding 5: all four points taken.)
   - In the removal loop (~lines 455-473), before each `git worktree remove` (plain and `--force`), make directories writable with `find -P "$_dest" -type d ! -perm -u+w -exec chmod u+w {} +`, and before the final `rm -rf` the same on `$WORKTREE_DIR` guarded by `[ -d "$WORKTREE_DIR" ]` (a single-entry tree is already gone by then). `-P` and `-type d` mean a symlinked entry (or a symlink met while walking) is never chmodded or followed, so a package entry `$WORKTREE_DIR/<rel>` that is a symlink to elsewhere cannot make the chmod touch another checkout; a symlinked `$_dest` itself is skipped. Only directories are changed, which is what blocks `unlink`; the chmod covers one worktree, never its parent.
   - A failed chmod does not hide the removal error (`|| true` on the chmod only).
   - The dirty-check section above the loop is unchanged: a dirty tree is still refused without `--force`. `u+w` on directories changes nothing `git status` sees.
   - New suite `.agent/scripts/tests/test_worktree_remove.sh`: sandbox worktree with a read-only `install/lib` directory and a read-only file inside. `install/` is gitignored in the sandbox repo (otherwise the non-force run is refused for untracked files and never reaches the code under test). Cases: removal succeeds and the directory is gone; the same with `--force`; a dirty tracked tree is still refused; an entry symlink to a sibling read-only dir leaves the sibling's mode untouched. The suite skips with a printed reason when run as root (root ignores mode bits, so the test would pass without the fix). Reuse sandbox helpers from `test_merge_pr_skill.sh`'s `worktree_remove --path` section.
   - Header comment of the script and the `script_reference.md` row (line 21) say directories are made writable first.
4. **[Part 2] Item 4: github.com-only slug, same grammar as `sitrep_root.sh`; do not let `gh` name the repository.** (Review findings 3 and 6.)
   - Choice and reason (unchanged, listed for the owner's veto): the callers are offline or pre-network (`merge_pr.sh` compares with `--repo` text and builds API paths; `worktree_create.sh` / `worktree_enter.sh` derive it at creation when `gh` may be unauthenticated; `sitrep_checks.sh` `check_gh_issue` must work offline; `_issue_helpers.sh` is offline-first). A `gh repo view` call would fail exactly where an empty slug is the safe answer. The onboarding precedent ("let gh resolve") was for an already-online step. ADR-0016: no `gh` call, the file stays inert.
   - Prior art: `sitrep_root.sh` `gh_slug` (#418, lines ~229-238) already holds the grammar: `https?://[user[:token]@]github.com/`, `ssh://[user@]github.com[:port]/`, `git://github.com/`, and scp-like `[user@]github.com:`, then an anchored `owner/repo` with owner `[A-Za-z0-9][A-Za-z0-9-]*`, repo `[A-Za-z0-9_.][A-Za-z0-9_.-]*`, optional `.git`, optional trailing `/`, host case-insensitive. `extract_gh_slug` is rewritten in bash with the same grammar (bash regex, because the callers are bash and a Python start-up per call is not wanted). Differences from `gh_slug`, each recorded in the function header:
     1. `www.github.com` is not accepted (matches `gh_slug`; the earlier plan accepted it).
     2. `ssh.github.com` (the port-443 form) is not supported, as in `gh_slug`; noted in the header.
     3. Kept difference, narrowed: an absolute local path is accepted only when its last three segments are exactly `github.com/<owner>/<repo>[.git]` (`(^|/)github\.com/<o>/<r>(\.git)?/?$`), because the test sandboxes use a local bare clone at `.../fake_remotes/github.com/<owner>/<name>.git` as origin (`make_origin_repo`, `test_merge_pr.sh` ~207). `gh_slug` says such a path is not on GitHub; here it is a test-fixture form only, and the header says so. A path segment such as `notgithub.com` or `/x/github.com.evil/o/r` does not match. The alternative, removing the exception by moving every fixture to a real URL form, would need an ssh/https shim for each local bare clone in every suite that uses `make_origin_repo`; that is much larger than the exception and tests the shim, not the code.
     4. A bare `owner/repo` input (no host) returns empty, as `gh_slug` does; the implement step first greps every caller to confirm none passes a bare slug (the callers read are all `remote get-url` output).
   - A parity test in `test_issue_helpers.sh` runs one table of URLs through `extract_gh_slug`, and where practical through `sitrep_root.sh`'s `gh_slug` (sourced or invoked as the suite allows), so the two grammars cannot drift; where `gh_slug` cannot be called, the table's comment names `sitrep_root.sh` and the suite lists the intended differences above.
   - **Stale copy:** `test_ros2_colcon.sh` (~line 845) holds a verbatim copy of the old `extract_gh_slug` inside `stub_issue_lookup_recorder`, commented as "the real implementation". Replace the copy by sourcing the real function (`source "$SB/.agent/scripts/_issue_helpers.sh"` before the stub overrides only `issue_lookup`), or, if the sandbox copy of that file is the stub itself, define the stub's `extract_gh_slug` by extracting the real function body with `sed` so the two cannot differ. Implement picks whichever sources without side effects, and the test gives a non-GitHub origin for a project package so the stale copy would have shown.
   - **`test_merge_pr_gate.sh` hang-3 fixtures (~1585, ~1616):** origin is `ssh://git@github.com$sb/fake_remotes/github.com/owner/pkg_a.git`, host github.com with an absolute path behind it; the strict parse returns empty and `merge_pr.sh` (~622) would stop finding the package worktree. Fix the fixture, not the parser: origin becomes `ssh://git@github.com/owner/pkg_a.git`, and `serve_shim` rewrites the path in the received command (`git-upload-pack '/owner/pkg_a.git'`, `git-receive-pack`) to `$HANG_BARE` before `sh -c`. The same fix applies to any other `ssh://...github.com$sb` fixture found by grep (`grep -n 'github.com\$sb'` across the suites).
   - **`worktree_create.sh` project with no GitHub slug (~638-725):** today, with `GH_REPO_SLUG` empty, `_LOOKUP_REPO` falls back to the workspace remote's slug, so after this change a project issue N would be looked up in the workspace repository. The pull-request check (~716-725) runs when `_LOOKUP_REPO` is non-empty or `ROOT_NOT_GIT=false`, and its `gh pr view N` has no `--repo` and resolves against the current folder (the `cd "$ROOT_DIR"` comes later, ~857), so from a workspace-folder session a workspace pull request with the same number would refuse creation ("is a pull request, not an issue"). Change: the workspace-slug fallback applies only to `--type workspace`; for `--type project` with no GitHub slug (a non-GitHub origin, or no `origin` at all) the code takes the same branch the existing project-folder-is-not-a-git-repository case (`ROOT_NOT_GIT`) already takes: no issue lookup, no `issue view` fallback (~710) and no `gh pr view` check. The worktree is still created and the title is left empty.
   - **Creation note (replaces the "Could not fetch issue title (offline or issue does not exist)" line for this case; never printed beside it; no warning sign):** for a non-GitHub origin: `Issue #N not looked up: issue titles are read from GitHub, and this project's origin is hosted elsewhere.` For no `origin` at all, its own wording: `Issue #N not looked up: issue titles are read from GitHub, and this project has no origin.` ("Light touch on projects" is the README goal this serves.)
   - **Test in `test_worktree_create.sh`**, from a workspace-folder session with a stub `gh` that records every call and answers any slug or number (including a workspace pull request with the same number N): (i) project origin `git@gitlab.com:acme/w.git`; (ii) project with no `origin`. In both: no `gh issue view` and no `gh pr view` call is recorded, creation succeeds, the matching note is printed, and the "offline or issue does not exist" line is not. Plus the unchanged workspace-type case (lookup happens).
   - Tests: new `test_issue_helpers.sh` (none exists). Accepted: `git@github.com:o/r.git`, `https://github.com/o/r`, `https://github.com/o/r/`, `https://user:token@github.com/o/r.git`, `http://github.com/o/r`, `ssh://git@github.com/o/r.git`, `ssh://git@github.com:22/o/r.git`, `git://github.com/o/r.git`, `GIT@GITHUB.COM:o/r`, and the local fixture form `/tmp/x/fake_remotes/github.com/o/r.git`. Empty: `git@gitlab.com:o/r.git`, `https://example.com/o/r`, `https://notgithub.com/o/r`, `git@github.com.evil.example:o/r`, `https://www.github.com/o/r`, `https://ssh.github.com/o/r`, `/x/notgithub.com/o/r.git`, `/x/github.com.evil/o/r.git`, `ssh://git@github.com/tmp/x/github.com/o/r.git`, three-segment paths, empty input. One `test_sitrep_checks.sh` case: a bare `gh-issue N` with the scp-form non-GitHub origin `git@gitlab.com:acme/w.git` reports `unknown` (an https non-GitHub origin already reports `unknown` today and would pass without the fix; with the scp form, today's garbage slug reaches the stub `gh`, which answers for any slug, giving `true`).
   - Listed for the owner's veto: github.com only; GitHub Enterprise hosts are not supported and give an empty slug.
5. **[Part 1] Item 5: correct the skill text, add a script flag keyed on the notice phrase, and bound the "never starts" case.** (Review finding 2; "no change" withdrawn.)
   - Observed shape (read-only, `gh api repos/rolker/geozui4d/pulls/14/reviews` and PR 400 of this repo): the quota notice is a **review** by `copilot-pull-request-reviewer[bot]`, state `COMMENTED`, zero inline comments, body `Copilot was unable to review this pull request because the user who requested the review has insufficient remaining quota.` (119-122 characters). A real Copilot review by the same account is long (3897 characters on the GeoZui4D PR 14 sample, a `<!-- ccr-overview-v2 -->` overview).
   - Text fix in `.claude/skills/run-issue/SKILL.md` section 9 (~line 924): replace "posts a plain issue comment saying so instead of a review" by the real shape (a review by the hosted reviewer's account, state COMMENTED, no inline comments, short body saying it could not review). It is a review source in form only: it holds no findings, so the host notes it and moves on.
   - Script check in `fetch_pr_reviews.sh` (read-only, no new API calls): add `notice_only: true` to a review only when the author login is `copilot-pull-request-reviewer` or `copilot-pull-request-reviewer[bot]`, `state == "COMMENTED"`, it has zero inline comments, **and the body contains the phrase "unable to review this pull request"**. The key is the phrase, not length or shape: over the last 60 pull requests of this repository (Plan Review 21ffdc89) all 168 notices carry it in three wordings (two quota texts of 119 and 122 characters, and "Copilot encountered an error and was unable to review this pull request", 117 characters), and short real reviews (204 to 296 characters, PR 416, one carrying a finding in its body) do not. A wording the script does not know is simply not flagged and is read like any review, which is today's behaviour. The header records the key and that reason. The `run-issue` section 9 and `triage-reviews` text (one line each) say only this: a review flagged `notice_only` is the hosted reviewer saying it could not review and holds no findings; an unflagged short review is read like any review.
   - Tests: a new `test_fetch_pr_reviews.sh` (or the existing suite if one exists; implement greps first) with a stub `gh`: positives are the three notice wordings (both quota texts and the error wording); negatives are a long Copilot review (`<!-- ccr-overview-v2 -->`), the short real Copilot review with a finding and no inline comments (the shape of review 5741265646 on PR 416, "Human assessment is needed because an unpublished finding ..."), a short human review, a Copilot review with inline comments, and a notice-phrase body from a non-reviewer author. Only the positives flag.
   - "A review that never starts": what bounds the wait today is recorded and made explicit. (a) `merge_pr.sh` holds only on a review check-run that exists and is unfinished, and that hold ends at `MERGE_PR_CI_TIMEOUT_SECONDS` (default 1800 s) with the `review-pending` error; a check-run that never appears holds nothing. (b) The host's own polling in `run-issue` section 9 has no stated bound: text added there says the host polls `fetch_pr_reviews.sh` at most about 900 s after publish, then records "review never arrived" in the hand-back and proceeds to triage with the sources that exist, the same as when the quota notice appears. The 900 s value comes from the standing rule in `host_standing_rules.md` line 31 ("no waits on things that will not arrive, a timeout of about twice the expected duration") and the measured review time (pull requests 416, 417, 420: reviews arrive 0 to 9 minutes after the reviewed commit, most within 1 to 6, two outliers at 17 and 30; committer time precedes push time, so these are upper bounds); the section 9 text cites both where the host reads it while waiting. `merge_pr.sh`'s 1800 s review-pending hold is a different wait and is unchanged. A script cannot do more here: the notice case was a quick answer, the never-started case is an absence, and an absence is bounded by time only.
6. **Consequence checks (each row belongs to the part of its item):** `script_reference.md` rows for `dispatch_phase.sh` (conventions rule), `worktree_remove.sh`, `merge_pr.sh` (workflow counting rule), `fetch_pr_reviews.sh` (`notice_only`), `_issue_helpers.sh` (host rule), and a mention of the new suites if the reference lists suites; `triage-reviews` one line for `notice_only`. Run only touched suites per the hook rule (Part 1: `test_dispatch_phase.sh`, `test_merge_pr_gate.sh`, `test_merge_pr.sh`, `test_merge_pr_skill.sh`, `test_worktree_remove.sh`, `test_fetch_pr_reviews.sh`, `test_skill_paths.sh`; Part 2: `test_issue_helpers.sh`, `test_sitrep_checks.sh`, `test_sitrep_root.sh`, `test_worktree_create.sh`, `test_worktree_enter_stderr.sh`, `test_ros2_colcon.sh`, plus `test_merge_pr_gate.sh` for the fixtures), full list: each on its own with `bash`: `test_dispatch_phase.sh`, `test_merge_pr_gate.sh`, `test_merge_pr.sh`, `test_merge_pr_skill.sh`, `test_worktree_remove.sh`, `test_issue_helpers.sh`, `test_sitrep_checks.sh`, `test_sitrep_root.sh`, `test_worktree_create.sh`, `test_worktree_enter_stderr.sh`, `test_ros2_colcon.sh`, `test_fetch_pr_reviews.sh`, `test_skill_paths.sh`. Any parallel command in this work names its count, for example `run_script_tests.sh -j 4`.

## Files to Change

**Part 1 (items 1, 2, 3, 5; `Part of #428`)**

| File | Change |
|------|--------|
| `.agent/scripts/dispatch_phase.sh` | job-count rule added to `conventions=` for every phase |
| `.agent/scripts/tests/test_dispatch_phase.sh` | handoff carries the counted examples |
| `.claude/skills/run-issue/SKILL.md` | rule in the handoff section; quota-notice shape corrected; about 900 s wait bound with its reason; `notice_only` line |
| `.claude/skills/triage-reviews/SKILL.md` | one line: `notice_only` holds no findings |
| `.agent/knowledge/host_standing_rules.md` | standing-rule row with its reason |
| `.agent/scripts/merge_pr.sh` | workflow count: active entries minus the leave-out list, `per_page=100`, long list is `unknown`; header records the two known gaps |
| `.agent/scripts/tests/test_merge_pr_gate.sh` | real-shape workflow fixtures (helper), cases (a)-(f) |
| `.agent/scripts/worktree_remove.sh` | `find -P ... chmod u+w` on directories before removal, guarded final one; header comment |
| `.agent/scripts/tests/test_worktree_remove.sh` | new: read-only tree, `--force`, dirty refused, symlink untouched, skip as root |
| `.agent/scripts/fetch_pr_reviews.sh` | `notice_only` flag keyed on the phrase |
| `.agent/scripts/tests/test_fetch_pr_reviews.sh` | three notice wordings positive; real short reviews and others negative |
| `.agent/knowledge/script_reference.md` | rows for `dispatch_phase.sh`, `worktree_remove.sh`, `merge_pr.sh`, `fetch_pr_reviews.sh` |

**Part 2 (item 4 alone; `Closes #428`)**

| File | Change |
|------|--------|
| `.agent/scripts/_issue_helpers.sh` | `extract_gh_slug` with `gh_slug`'s grammar, narrowed local-path form, header |
| `.agent/scripts/tests/test_issue_helpers.sh` | new: accepted and refused forms, parity table |
| `.agent/scripts/tests/test_ros2_colcon.sh` | stale `extract_gh_slug` copy replaced |
| `.agent/scripts/tests/test_merge_pr_gate.sh` | hang-3 fixture and `serve_shim` path rewrite only |
| `.agent/scripts/worktree_create.sh` | workspace-slug fallback only for workspace type; project with no slug (non-GitHub or no origin) skips issue lookup and PR check; new notes |
| `.agent/scripts/tests/test_worktree_create.sh` | non-GitHub origin and no-origin cases from a workspace-folder session |
| `.agent/scripts/tests/test_sitrep_checks.sh` | scp-form non-GitHub origin case |
| `.agent/knowledge/script_reference.md` | `_issue_helpers.sh` row (host rule) and `worktree_create.sh` row |

## Prior Art

`sitrep_root.sh` `gh_slug` (#418) is the grammar item 4 reuses; the differences are recorded above. The workflow-count check in `merge_pr.sh` (#271, #284) is kept and corrected, not replaced. The `test_merge_pr_gate.sh` fixture helpers and the `worktree_remove --path` tests in `test_merge_pr_skill.sh` are reused. The `gh` name-the-repository route (onboarding, 2026-10-30) was weighed for item 4 and rejected for the offline callers.

## Serves

README "Workspace goals", "Quality of the work": "A safeguard has to earn its cost: one that finds no problems, or makes the user wait for nothing, is lightened or removed" (item 2's wait, item 5's wait), and "Trust, control and information" (the host and owner see a quota notice or a missing review for what it is). Under `docs/design.md#rules`. (That bullet is a README goal line, not a heading in `docs/principles.md`.)

## Design Picture

No change to the design picture.

## Principles Self-Check

Names are the headings of `docs/principles.md`.

| Principle | Consideration |
|---|---|
| Test what breaks | Every item has a test that fails without the fix: item 2 with the real workflow shape (the earlier test passed only against a stub), item 3 with a gitignored read-only `install/` (skipped as root), item 4 with the scp-form non-GitHub origin, item 5 with the observed quota review; the item 1 guard has a recorded reason. |
| Look for prior art before building | Item 4 reuses `sitrep_root.sh`'s grammar and records each difference; item 2 keeps the existing count check. |
| Enforce what matters, as simply as possible | No dispatch guard (cannot see the failure); `notice_only` is one jq expression on fields already fetched, keyed on the notice phrase. |
| A change includes its consequences | The stale copy in `test_ros2_colcon.sh`, the hang-3 fixtures, the `worktree_create.sh` fallback and the bare `total_count` fixtures are all in the plan. |
| Put each thing at the level it applies to | Item 1 sits in the handoff text and the standing rules, where it is read when writing a handoff. |
| Only what's needed | The empty-slug message change and the `failed`/`api-error` wording are dropped. |
| Ask about what matters, and show how much | Decisions of mechanism (no guard, github.com only, the notice phrase as the key, the 900 s host bound, the `dynamic/` leave-out list) are listed for veto, not asked. |
| Verify before claiming | The workflow shape, the quota review shape and the real clean-review length were read with `gh api` (read-only) before the plan relied on them. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0013 | Yes | Plan Authored entry. |
| ADR-0016 | Yes | `_issue_helpers.sh` stays inert: no `gh` call, no repo-affecting action. All new outward reads (`fetch_pr_reviews.sh` flag) add no API call. |
| ADR-0022 | No | No part-level design. |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `dispatch_phase.sh` `conventions=` | handoff text in `run-issue`, `script_reference.md` | Yes |
| `extract_gh_slug` | `test_ros2_colcon.sh` copy, hang-3 `ssh://...github.com$sb` fixtures, local-path fixtures (`make_origin_repo`), `worktree_create.sh` empty-slug fallback | Yes |
| workflow count in `merge_pr.sh` | about 17 bare `total_count` fixtures, `workflows_path()` | Yes |
| `worktree_remove.sh` | `script_reference.md` row, header comment | Yes |
| `fetch_pr_reviews.sh` output | `run-issue` and `triage-reviews` text that reads the JSON | Yes (Part 1) |

## Open Questions

- None about the goal. Listed for veto: no `dispatch_phase.sh` guard; item 4 github.com-only (no GitHub Enterprise, no `www.` or `ssh.github.com`); the `notice_only` key (the phrase, hosted reviewer's account only) and its consequence that an unknown wording is not flagged; the 900 s bound on the host's review wait; the `dynamic/` leave-out list and the two recorded gaps.
- The GeoZui4D cause is now confirmed from the API (count 1, a `dynamic/` workflow), not inferred.

## Estimated Scope

Two pull requests on this one issue and timeline. Part 1 (items 1, 2, 3, 5): about 12 files, five of them tests; `Part of #428`. Part 2 (item 4 alone, the widest reach: about 21 call sites outside tests in four suites): about 8 files; `Closes #428`. A must-fix in item 4 does not send items 1, 2, 3 and 5 through another review round.
