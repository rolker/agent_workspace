# Plan: review-issue: make owning-repo resolution cwd-independent

## Issue

https://github.com/rolker/agent_workspace/issues/581 (workspace issue 581; `#` numbers in its body, 445/470/473/260, are the old repository's).

## Context

review-issue, plan-task and review-plan run bare `gh issue view/comment`, `gh pr view/list/edit/create` and a hand-filled `_REPO_SLUG="<owner/repo>"` for the git-bug lookup. A bare call reaches whatever repository `gh` resolves from the cwd: the wrong one from a wrong cwd, and the `upstream` remote's repository when one exists (gh prefers upstream over origin with no default set). `/run-issue` is protected for package issues only (`resolve_issue_dir` in `dispatch_phase.sh` checks `gh repo view`); a standalone `/review-issue 581` is not. A project with no GitHub remote is an ordinary case here, not an error.

## Approach

1. **One script, `.agent/scripts/issue_repo.sh <N | owner/repo#N>`**, prints the repository to name on every `gh issue/pr` call. It sources `_issue_helpers.sh` and reuses `extract_gh_slug`; no second parser. Input: the issue/PR number or the qualified ref (same grammar as `parse_issue_ref` in `dispatch_phase.sh`); works from the cwd, which must be the owning checkout for a bare number. stdout is the single line `owner/repo` and nothing else; every message is on stderr. Exit codes:

   | Case | stdout | Exit |
   |---|---|---|
   | `owner/repo#N` (any cwd, no git, no gh, no network) | `owner/repo` | 0 |
   | bare number; origin is github.com; `gh repo view --json nameWithOwner --jq .nameWithOwner` in the cwd names the same repository (compared without case) | origin's slug | 0 |
   | bad ref (not a number, not `owner/repo#N`) or no argument | none | 1 |
   | bare number; gh resolves another repository than origin (the `upstream` case, or a fork's origin) | none | 2 |
   | bare number; cwd is not inside a git repository | none | 3 |
   | bare number; no `origin`, or origin is not a github.com remote (`extract_gh_slug` gives nothing) | none | 4 |
   | bare number; `gh` missing, not logged in, offline or gave no answer (its stderr quoted, as `dispatch_phase.sh` does) | none | 5 |

   Exit 2 names both repositories and says: set the default with `gh repo set-default <origin slug>`, or, when the issue lives in the other repository, pass `owner/repo#N`. Exit 5 says the same (log in, or pass `owner/repo#N`). Exit 4 is a note ("no GitHub remote: no gh call will be made"), not an error. The helper never writes and never prompts (`GH_PROMPT_DISABLED=1`).
2. **Skill wiring**, one block per skill, placed before the first read: `_REPO=$("$WS_ROOT/.agent/scripts/issue_repo.sh" "<ref>")` with `rc` captured; on 0 the skill prints `Repository: $_REPO` (so a wrong repository is visible), sets `_REPO_SLUG="$_REPO"` (replacing the `<owner/repo>` placeholder) and adds `-R "$_REPO"` to every `gh issue` and `gh pr` call. `<N>` is the number after `#` when a qualified ref was given. On 2, 3, 5 the skill stops and shows the helper's message. On 4 it makes no `gh` call at all, skips the github-url git-bug lookup, reads the issue from git-bug by the id the owner gives or asks the owner for the issue text, and (review-issue) records the review in progress.md without posting a comment.
   - review-issue: new head of step 1 (the resolution), line 90 `gh issue view`, step 7 `gh issue comment` (line 244), `_REPO_SLUG` at 65.
   - plan-task: new head of step 1, lines 67, 91, 182 (`gh issue view <N> --json url`, which picks the worktree type), 201 (issue URL in the plan template), 347-359 (`gh pr list/edit/create`; `--no-pr` skips them as today).
   - review-plan: new `### 0` before step 1 (outside the lines issue 579 rewrites); step 1 only gains `-R "$_REPO"` on its two `gh pr view` lines (72, 75); step 2 line 132 `_REPO_SLUG` and line 156 `gh issue view`. The PR form resolves with the PR number: the repository does not depend on the number.
   - Usage lines of the three skills accept `<N>` or `owner/repo#N`.
3. **Tests** (below), then consequences.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/issue_repo.sh` (new, `chmod +x`) | the helper above, ~50 lines; `set -uo pipefail`, sourcing `_issue_helpers.sh` through its own `SCRIPT_DIR` |
| `.claude/skills/review-issue/SKILL.md` | step 1 head, lines 65-67, 90, 244 |
| `.claude/skills/plan-task/SKILL.md` | lines 67, 91, 182, 201, 347-359, usage |
| `.claude/skills/review-plan/SKILL.md` | new step 0; `-R` on 72, 75, 132, 156; usage |
| `.agent/scripts/tests/test_issue_repo.sh` (new, `chmod +x`) | helper suite |
| `.agent/scripts/tests/test_skill_paths.sh` | pins the skill text (below) |
| `.agent/knowledge/script_reference.md` | one row for `issue_repo.sh` (inputs, stdout, exit codes) |
| `.agent/knowledge/github_cli_patterns.md` | extend "Repo Targeting" with: skills get the repository from `issue_repo.sh`, never from the cwd |

## Tests

`test_issue_repo.sh`, hermetic, no network, in the pattern of `test_package_issue_loop.sh`: a sandbox with `GIT_CONFIG_GLOBAL`, `HOME` and `PATH` pointing at a stub dir. Remotes are local paths ending `fake_remotes/github.com/<owner>/<repo>.git`, which `extract_gh_slug` accepts for fixtures; no clone is needed. A stub `gh` answers only `repo view --json nameWithOwner --jq .nameWithOwner`: it picks the repository the way real gh does (a remote with `gh-resolved=base`, else `upstream`, else `origin`), prints its slug, and logs every call; `GH_STUB=fail` makes it exit 4 with "not logged in". Two sandbox repositories: `own/alpha` (origin only) and `own/beta` (origin `own/beta`, remote `upstream` = `other/beta`). Cases, each asserting stdout, exit code and, where stated, the gh log:
- bare number in alpha: `own/alpha`, 0; same with the host written in upper case in the URL.
- `own/beta#7` run from alpha, from beta, and from a non-git directory: `own/beta`, 0, gh log empty (the cwd is never consulted).
- bare number in beta: exit 2, stderr names `own/beta`, `other/beta` and `gh repo set-default own/beta`; after `git config remote.origin.gh-resolved base`: `own/beta`, 0 (the documented fix works).
- no remote at all, and an origin on another host (`git@gitlab.com:o/r.git`): exit 4, gh log empty.
- bare number in a non-git directory: exit 3, gh log empty.
- `GH_STUB=fail`: exit 5, stderr quotes the stub's message; PATH holding git but no gh: exit 5.
- `abc`, `o/r`, `o/r#`, empty: exit 1.

`test_skill_paths.sh` gains pins on the three SKILL.md files: each calls `issue_repo.sh` through `$WS_ROOT`; none contains `_REPO_SLUG="<owner/repo>"`; every line inside a fenced block that contains `gh issue ` or `gh pr ` also contains `-R "$_REPO"`. Run: `bash .agent/scripts/tests/test_issue_repo.sh`, `bash .agent/scripts/tests/test_skill_paths.sh`, then `bash .agent/scripts/tests/run_script_tests.sh -j 4` once before publishing if that flag exists (check `--help`; otherwise the host's single full pass). The pull request says which cases ran.

## Prior Art

`extract_gh_slug` (`_issue_helpers.sh`) and the `gh repo view` check in `resolve_issue_dir` (`dispatch_phase.sh`, message and `gh repo set-default` fix) are taken as they are; `merge_pr.sh` and `run-issue` already pass `-R`. Rejected: a free-form `--repo` argument on the skills (not needed: the qualified ref covers it); sourcing a function instead of a script (skills run it from a shell snippet and a project session has only `$WS_ROOT`); rewriting `dispatch_phase.sh` to call the new script (its check runs per package worktree directory and stays as it is; folding it in is a possible follow-up, not this change).

## Serves

Quality of the work: `docs/design.md#review-loop-and-timeline`.

## Design Picture

No change to the design picture: that an issue's phase reads and writes in its owning repository is already in `docs/design.md#worktrees` and ADR-0012; this brings three skills in line.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Put each thing at the level it applies to | One script, three callers, no idiom copied into prose three times |
| Only what's needed | Input is `<N>` or `owner/repo#N` only; no new flags; dispatch check left alone |
| A safeguard has to earn its cost | A comment on the wrong repository cannot be undone; the cost is one local call that prints what it chose |
| Verify before claiming | The upstream and no-remote cases are run in a sandbox, listed in the pull request |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0012 | Yes | The owning repository stays the one holding `feature/issue-<N>`; a package issue still goes through `resolve_issue_dir`; the helper only names the repository |
| ADR-0010 | Yes | git-bug stays first; `gh` fallback kept; the slug placeholder is replaced; exit 4 skips the github-url lookup |
| ADR-0013 | No change | Entry shape and persistence unchanged |
| ADR-0016 | Yes | Skills call `$WS_ROOT/.agent/scripts/issue_repo.sh`; the script has no repo-affecting action and no registry guard need (it only reads) |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| a new script | `script_reference.md` | Yes |
| the three skills | the plugin copy: none exists, `.claude-plugin/plugin.json` lists `./.claude/skills/*` in place | Yes (nothing to do) |
| gh targeting rule | `github_cli_patterns.md` | Yes |
| other skills with bare `gh` (address-findings, triage-reviews, review-code) | same fix | No, follow-up: outside the owner's accepted scope; list in the pull request |
| review-plan step 1 | issue 579 rewrites it | Only the two `-R` additions here; whichever merges second takes main in first |

## Open Questions

- Exit 5 refuses when `gh` cannot answer, even though git-bug could serve an offline read; the owner can pass `owner/repo#N` offline. Kept so a fork's wrong-repository case is never guessed.

## Estimated Scope

Single pull request, about 9 files.
