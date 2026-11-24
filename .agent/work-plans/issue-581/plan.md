# Plan: review-issue: make owning-repo resolution cwd-independent

## Issue

https://github.com/rolker/agent_workspace/issues/581 (workspace issue 581; `#` numbers in its body, 445/470/473/260, are the old repository's).

## Context

review-issue, plan-task and review-plan run bare `gh issue view/comment`, `gh pr view/list/edit/create` and a hand-filled `_REPO_SLUG="<owner/repo>"` for the git-bug lookup. A bare call reaches whatever repository `gh` resolves from the cwd: the wrong one from a wrong cwd, and the `upstream` remote's repository when one exists (gh prefers upstream over origin with no default set). `/run-issue` is protected for package issues only (`resolve_issue_dir` in `dispatch_phase.sh` asks `gh repo view` in the owning checkout and compares it with the `.worktree-repos` header's repository); a standalone `/review-issue 581` is not. A project with no GitHub remote is an ordinary case here, not an error, and offline runs that work today (`/review-plan --issue <N>`, `/plan-task <N> --no-pr`) must keep working.

What a bare number means (answers the issue's fourth row): the issue of the repository of the checkout the skill is run in (the session-root rule). An issue of another repository is written `owner/repo#N`. The helper prints the repository it chose, and the skills show it as a `Repository:` line, so a wrong guess is visible before anything is posted.

## Approach

1. **One script, `.agent/scripts/issue_repo.sh <N | owner/repo#N>`**, prints the repository to name on every `gh issue/pr` call. It sources `_issue_helpers.sh` and reuses `extract_gh_slug` (a github.com remote names a GitHub repository, nothing else does); no second parser. Grammar of the argument is that of `parse_issue_ref` in `dispatch_phase.sh`. stdout is the single line `owner/repo` and nothing else; every message is on stderr. The helper never writes and never prompts.

   **Decision order for a bare number** (the helper runs in the owning checkout):

   a. *Expected repository.* Walk up from the cwd's git top-level to the first `.worktree-repos` file (the manifest of a package worktree sits in the worktree's top folder, above the checkouts). When its header `issue=` is `owner/repo#<N>` for this number, the expected repository is that `owner/repo`: exactly the source `resolve_issue_dir` takes (`sed -n 's/.* issue=\([^ ]*\).*/\1/p'` on the first line, `_wt_manifest_issue_field` does the same; the helper reuses it). The header counts only when the cwd's checkout is the manifest's issue checkout (`issue_checkout_of`); the manifest is found with `_wpd_enclosing_manifest` (from the checkout's top-level, else the cwd, as `issue_checkout_guard` looks). In a sibling repository's checkout the header is ignored and that checkout's origin decides. A header with a bare `issue=<N>`, no manifest, or another number gives no header repository. Without a header repository the expected repository is origin's slug (`extract_gh_slug` on `remote.origin.url`).
   b. *Decide locally, no `gh` call.* When the expected repository equals origin's slug, `GH_REPO` is unset, no other remote has a github.com slug, and no `remote.*.gh-resolved` is set, gh can only mean origin: print the expected repository, exit 0, no network.
   c. *Otherwise ask gh once*, the invocation `project_integration_audit.sh` already uses: `(cd <checkout> && GH_HOST=github.com GH_PROMPT_DISABLED=1 gh repo view --json nameWithOwner --jq .nameWithOwner 2>"$errf" </dev/null)`, stdout alone is the answer (as in `resolve_issue_dir`). Equal to the expected repository (compared without case): print the expected repository, exit 0. Different: exit 2. gh missing, failing or silent: exit 5, gh's stderr quoted.
   d. The cases that stop before a-c: not a git repository and no manifest above (exit 3); a git repository with no github.com origin and no header repository (exit 4).

   **Contract:**

   | # | Case | stdout | Exit |
   |---|---|---|---|
   | 1 | `owner/repo#N` naming this checkout's repository (origin's slug, or the header's in a package issue checkout): no gh call | `owner/repo` | 0 |
   | 1b | `owner/repo#N` naming another repository (the session-root rule: an issue of another repository is worked from a checkout of it; the skills stop before any record is read or written); or, when origin names no GitHub repository read locally (an SSH host alias, `ssh.github.com:443`), one that `gh repo view` in the checkout, `GH_REPO` unset, does not confirm | none | 6 |
   | 2 | bare number; origin is github.com and the only github.com remote, no `gh-resolved`, `GH_REPO` unset: decided locally, no `gh` call (works offline) | origin's slug | 0 |
   | 3 | bare number; another github.com remote (`upstream`) or a `gh-resolved` setting or `GH_REPO` set, gh asked and names origin's repository | origin's slug | 0 |
   | 4 | bare number, as 3, but gh names another repository (the `upstream` case, a fork's origin, `GH_REPO` pointing elsewhere) | none | 2 |
   | 5 | bare number inside a package worktree whose header names `H#N`; origin is `H` itself and the local facts of case 2 hold: no `gh` call | `H` | 0 |
   | 6 | as 5, but origin is a fork of `H` (origin slug differs from `H`) and gh, run in the checkout, names `H` through `upstream` (header and gh agree) | `H` | 0 |
   | 7 | as 6, but gh names the fork or anything other than `H` | none | 2 |
   | 8 | bare number; gh asked (cases 3, 4, 6, 7 conditions) and missing, not logged in, offline or silent (its stderr quoted) | none | 5 |
   | 9 | bare number; cwd is not inside a git repository and no manifest above | none | 3 |
   | 10 | bare number; a git repository with no `origin`, or origin not github.com, and no header repository (`extract_gh_slug` gives nothing) | none | 4 |
   | 11 | bad ref (not a number, not `owner/repo#N`, a number with leading zeros or 0) or no argument | none | 1 |
| 12 | any ref in a package worktree's top folder, or a folder of it that is no checkout (no repository of its own, git or not), whatever the header says | none (message names the header's ref and the issue checkout when it can) | 3 |
| 12b | a package worktree whose header names `H#N` but whose issue checkout cannot be found (`issue_checkout_of` refuses, as the dispatcher does) | none (its message quoted) | 3 |
| 13 | bare number in a sibling repository's checkout of a package worktree: the header is ignored, the checkout's own origin decides as in cases 2-4, 8, 10 | as those | as those |

   Messages. Exit 2 outside a package worktree names both repositories and says: either set the default with `gh repo set-default <origin slug>`, or pass this checkout's `owner/repo#N`; an issue of the other repository is worked from a checkout of it. With `GH_REPO` set (in a package issue checkout too) it says that variable is what gh used and to unset it. Exit 2 inside a package worktree (case 7) names the header's repository `H` and says: gh run here resolves `<got>`, not `H`; the dispatcher expects `H`, so set the default to `H` (`gh repo set-default H`, the fix `dispatch_phase.sh` itself prints) or pass `H#N`; it never offers origin's slug as the default, which would make the dispatcher refuse the next phase. Exit 3 says where to run from. Exit 4 is a note ("no GitHub remote: no gh call will be made"), not an error, and names the SSH host alias case, where `owner/repo#N` names the repository explicitly. Exit 6 names both repositories and says to run from a checkout of the named one. Exit 5 says gh could not answer, quotes its message, and says: log in, or pass `owner/repo#N`.

   The helper never calls `dispatch_phase.sh` and `dispatch_phase.sh` is not edited: both read the same header and compare with the same gh invocation, so they cannot disagree about a package checkout.

2. **Skill wiring.** The repository is asked for again at the head of every code block that calls `gh` or needs the slug, because every block is a new shell (the skills' own "Workspace root" section says so). The head is one line plus the guard, the same in all three skills:

   ```bash
   WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
   _REPO=$("$WS_ROOT/.agent/scripts/issue_repo.sh" "<ref>") || { _rc=$?; echo "issue_repo.sh exit $_rc: this block makes no gh call; see the Repository by exit code table"; exit "$_rc"; }
   echo "Repository: $_REPO"
   gh issue view <N> -R "github.com/$_REPO" ...
   ```

   `<ref>` is the bare number or the qualified ref as the owner typed it; `<N>` is the number after `#` for a qualified ref. Run locally (cases 1, 2, 5, 9, 10, 11) the helper costs no network, so repeating it per block is cheap. `_REPO_SLUG` in the git-bug lookup is set from `$_REPO` instead of the hand-filled placeholder.

   **What each skill does per exit code** (the first block of the skill decides; later blocks that get a non-zero stop the same way):

   | Exit | review-issue | plan-task | review-plan |
   |---|---|---|---|
   | 0 | proceeds; prints `Repository:`; `-R "github.com/$_REPO"` on every `gh issue/pr` call and the slug from `$_REPO` | same | same |
   | 1 | stops: usage | stops: usage | stops: usage |
   | 2, 3 | stops, shows the helper's message (it names `owner/repo#N` or the header's repository) | same | same |
   | 4 (no GitHub remote) | makes no `gh` call, skips the github-url git-bug lookup, asks the owner for the issue's text (or where the project keeps its issues, in hosting-service-neutral words); runs steps 2-6 on that text; step 7 posts nothing and step 8 records the review in progress.md with the Issue Review entry's own text (step 8's "The posted comment **is** the entry" gets a no-comment wording: the entry then holds the full Review text it would have posted, and the entry says no comment was posted) | asks the owner for the issue's text; the worktree type (step 4) comes from the session's root (the root the skill is run in), not from `gh`; the plan's `## Issue` line carries the issue ref as typed, no URL; step 8 (draft PR) is skipped as with `--no-pr`, and the report says why | no `gh` call; reads the plan from the branch (`--issue`) or the PR is unavailable; step 2 "Issue context unavailable", review on the plan alone |
   | 5 (gh could not answer) | says which read it could not make, asks the owner for the issue's text, records the review with no posted comment as for exit 4 | same as exit 4 for the issue text and type (type from the session's root); draft PR skipped (step 8 already skips when `gh` is unavailable) | goes on with the plan content only, as step 2 already allows ("Issue context unavailable"), with `--issue <N>` the plan is read from the branch; no `gh pr` call |
   | any other non-zero (127: the script is missing, a project session with no user tier or an older workspace checkout; others) | stops and shows stderr | same | same |

   Per skill:
   - review-issue: new head of step 1 (the resolution), lines 65-67 (`_REPO_SLUG`), line 90 `gh issue view`, step 7 `gh issue comment` (line 244, in its own block, so it repeats the head), step 8's no-comment wording.
   - plan-task: new head of step 1, lines 67, 91; the step 4 type check at line 182 stops being `gh issue view <N> --json url` in prose and becomes a local comparison: the type is `workspace` when `$_REPO` equals the workspace origin's slug (`extract_gh_slug` on the workspace checkout's origin, read in step 4's own block), else `project`; line 201 (issue URL in the plan template, `https://github.com/$_REPO/issues/<N>` when the helper exited 0, the ref as typed on exit 4/5); lines 347-359 (`gh pr list/edit/create` with `-R "github.com/$_REPO"`, repeating the head; `--no-pr` skips them as today).
   - review-plan: new `### 0` before step 1 (outside the lines issue 579 rewrites); step 1 only gains `-R "github.com/$_REPO"` and the head on its two `gh pr view` lines (72, 75); step 2 line 132 `_REPO_SLUG` and line 156 `gh issue view` (the head repeated in step 2's block). The PR form passes the issue number from the current branch's name (`feature/issue-<N>`), else the PR number (the PR's own issue reference cannot be read before the repository is known); a bare number means the checkout's repository either way, and the number matters only in a package worktree.
   - Usage lines and Overview of the three skills accept `<N>` or `owner/repo#N` and say a bare number means the repository of the checkout the skill is run in.

3. **Acceptance of the issue, box by box** (reported in the pull request): (a) review-issue resolves the repository in step 1 and uses it in steps 1, 7 and 8: done (the helper, the three blocks). (b) "The Overview precondition paragraph added in #473 is removed": that paragraph was never ported into this repository's review-issue (Overview has none, checked), so the box is retired, not done. (c) plan-task and review-plan audited: done and refactored; address-findings, triage-reviews and review-code carry the same bare `gh` pattern and are named in the pull request as not covered (whether they get an issue is the owner's call, put to him at the merge). (d) Test scenario: a bare number from the other root means that root's repository, so the scenario is run in the qualified form: `owner/repo#N` for a workspace issue from a project checkout and for a project issue from the workspace checkout are each refused (exit 6) before any record is read or written, naming both repositories (contract case 1b, tests below; host decision at the round-1 code review); the bare-number-from-the-wrong-root row is answered by the session-root rule and the printed `Repository:` line, not by a probe.

4. **Tests** (below), then consequences.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/issue_repo.sh` (new, `chmod +x`) | the helper above, ~90 lines; `set -uo pipefail`, sourcing `_issue_helpers.sh` and `_worktree_helpers.sh` (`_wt_manifest_issue_field`) through its own `SCRIPT_DIR` |
| `.claude/skills/review-issue/SKILL.md` | step 1 head, lines 65-67, 90, 244, step 8 wording, usage/Overview |
| `.claude/skills/plan-task/SKILL.md` | step 1 head, lines 67, 91, 182, 201, 347-359, usage |
| `.claude/skills/review-plan/SKILL.md` | new step 0; head and `-R` on 72, 75, 132, 156; usage |
| `.agent/scripts/tests/test_issue_repo.sh` (new, `chmod +x`) | helper suite |
| `.agent/scripts/tests/test_skill_paths.sh` | pins the skill text (below) |
| `.agent/knowledge/script_reference.md` | one row for `issue_repo.sh` (inputs, stdout, exit codes) |
| `.agent/knowledge/github_cli_patterns.md` | extend "Repo Targeting": skills get the repository from `issue_repo.sh` in every block, never from the cwd |

`dispatch_phase.sh` and `_worktree_helpers.sh` are not edited.

## Tests

`test_issue_repo.sh`, hermetic, no network, in the pattern of `test_package_issue_loop.sh`: a sandbox with `GIT_CONFIG_GLOBAL`, `HOME` and `PATH` pointing at a stub dir. Remotes are local paths ending `fake_remotes/github.com/<owner>/<repo>.git`, which `extract_gh_slug` accepts for fixtures. A stub `gh` answers only `repo view --json nameWithOwner --jq .nameWithOwner`: it picks the repository the way real gh does (`GH_REPO`, else a remote with `gh-resolved=base`, else `upstream`, else `origin`), prints its slug, and logs every call (the log also records `GH_HOST`, `GH_PROMPT_DISABLED` and whether stdin was closed); `GH_STUB=fail` makes it exit 4 with "not logged in". Sandbox repositories: `own/alpha` (origin only); `own/beta` (origin `own/beta`, remote `upstream` = `other/beta`); a package worktree top folder with a `.worktree-repos` manifest whose header is `# project=p issue=up/pkg#7 layer=main` and a checkout under it whose origin is `fork/pkg` and `upstream` is `up/pkg`. Each case asserts stdout, exit code and the gh log:
- case 2: bare number in alpha: `own/alpha`, exit 0, **gh log empty** (works with `PATH` holding git but no gh at all); same with the host written in upper case in the URL.
- case 1: `own/beta#7` from beta: `own/beta`, 0, gh log empty; from alpha: exit 6, gh log empty; from a non-git directory or a package worktree's top folder: exit 3; `up/pkg#7` in its fork-origin issue checkout: `up/pkg`, 0; an SSH-alias origin: `gh` confirms `own/alias#7` (0) and refuses another (6).
- cases 3 and 4: bare number in beta: gh asked once (log shows the pinned invocation), exit 2, stderr names `own/beta`, `other/beta` and `gh repo set-default own/beta`; after `git config remote.origin.gh-resolved base`: `own/beta`, 0. `GH_REPO=own/alpha` set in alpha: gh asked, exit 2, stderr names `GH_REPO`; `GH_REPO=own/alpha` in alpha equals origin: 0 (gh asked, since the local facts leave a choice).
- case 6: package checkout, origin `fork/pkg`, gh names `up/pkg`: stdout `up/pkg`, exit 0.
- case 7: package checkout with the stub made to name `fork/pkg` (a `gh-resolved=base` on origin): exit 2; stderr names `up/pkg`, offers `gh repo set-default up/pkg` and never `gh repo set-default fork/pkg`. A package checkout whose origin is `up/pkg` itself (case 5): `up/pkg`, 0, gh log empty. A manifest whose header names another number, or a bare `issue=7`: the header is ignored and origin decides (case 2).
- case 8: `GH_STUB=fail` with `upstream` present: exit 5, stderr quotes the stub's message; PATH holding git but no gh with `upstream` present: exit 5.
- case 9: bare number in a non-git directory: exit 3, gh log empty, stderr names `owner/repo#N`.
- case 10: no remote at all, and an origin on another host (`git@gitlab.com:o/r.git`): exit 4, gh log empty.
- case 11: `abc`, `o/r`, `o/r#`, empty: exit 1.

`test_skill_paths.sh` gains pins on the three SKILL.md files: each calls `issue_repo.sh` through `$WS_ROOT`; none contains `_REPO_SLUG="<owner/repo>"` or the prose `gh issue view <N> --json url`; every fenced block that contains a `gh issue ` or `gh pr ` line also contains the `issue_repo.sh` call (the repository is asked for again in that block, so `-R` never gets an unset variable from an earlier shell) and every such `gh` line contains `-R "github.com/$_REPO"`; plan-task's step 4 type text names the local comparison. A mutation case: a copy of a skill with the head removed from one block fails the pin. Run: `bash .agent/scripts/tests/test_issue_repo.sh`, `bash .agent/scripts/tests/test_skill_paths.sh`, then `bash .agent/scripts/tests/run_script_tests.sh -j 4` once before publishing if that flag exists (check `--help`; otherwise the host's single full pass). The pull request says which cases ran.

## Prior Art

`extract_gh_slug` (`_issue_helpers.sh`); `_wt_manifest_issue_field` and the `resolve_issue_dir` check in `dispatch_phase.sh` (the header as the expected repository, the stderr-quoting `gh repo view` call); the `GH_HOST=github.com GH_PROMPT_DISABLED=1 gh repo view ... </dev/null` line in `project_integration_audit.sh`; `gh_create_issue.sh` has a similar repository safeguard (it checks the target repository before creating). `merge_pr.sh` and `run-issue` already pass `-R`. Rejected: a free-form `--repo` argument on the skills (the qualified ref covers it); sourcing a function instead of a script (skills run it from a shell snippet and a project session has only `$WS_ROOT`); putting the qualified ref on the dispatched task lines (changes `skill_task_line`, a larger edit than reading the header); rewriting `dispatch_phase.sh` to call the new script (its check runs per package worktree directory and stays as it is; folding it in is a possible follow-up).

## Serves

Quality of the work: `docs/design.md#review-loop-and-timeline`.

## Design Picture

No change to the design picture: that an issue's phase reads and writes in its owning repository is already in `docs/design.md#worktrees` and ADR-0012; this brings three skills in line.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Put each thing at the level it applies to | One script, three callers, no idiom copied into prose three times |
| Only what's needed | Input is `<N>` or `owner/repo#N` only; no new flags; dispatch check left alone; the network is asked only when local facts leave a choice |
| A safeguard has to earn its cost | A comment on the wrong repository cannot be undone; the ordinary case costs no call, and the safeguard prints what it chose |
| Verify before claiming | The upstream, fork-in-package-worktree, offline and no-remote cases are run in a sandbox, listed in the pull request |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0012 | Yes | The owning repository stays the one holding `feature/issue-<N>`; in a package worktree the header's repository is the expected one, as `resolve_issue_dir` takes it; the helper only names the repository |
| ADR-0010 | Yes | No new git-bug path: with no GitHub remote the owner gives the issue text; the existing git-bug-first read stays where a GitHub remote exists, with the slug placeholder replaced |
| ADR-0013 | No change | Entry shape and persistence unchanged; review-issue's no-comment case writes the same Issue Review entry |
| ADR-0016 | Yes | Skills call `$WS_ROOT/.agent/scripts/issue_repo.sh` and stop on any non-zero exit including 127; the script only reads |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| a new script | `script_reference.md` | Yes |
| the three skills | the plugin copy: none exists, `.claude-plugin/plugin.json` lists `./.claude/skills/*` in place | Yes (nothing to do) |
| gh targeting rule | `github_cli_patterns.md` | Yes |
| row 2 of `docs/fork_parity.md` (package-repository loop; lists these three skills) | its Notes describe what the fork's skills do and what is missing here, not cwd handling | Checked: no line needed; row 27 likewise |
| other skills with bare gh (address-findings, triage-reviews, review-code) | same fix | No: named in the pull request text as not covered; whether they get an issue is the owner's, put to him at the merge |
| review-plan step 1 | issue 579 rewrites it | Only the head and the two `-R` additions here; whichever merges second takes main in first |

## Open Questions

- None for the owner. Offline use (no `gh` answer) carries on as far as the skill can without the issue's text from GitHub: exit 5 never blocks review-plan, and plan-task and review-issue stop only for text the owner can type.

## Estimated Scope

Single pull request, about 9 files.
