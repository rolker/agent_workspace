# Plan: run-issue: drive an issue in a package repository of a multi-repository project

## Issue

https://github.com/rolker/agent_workspace/issues/429

## Verdict first

**The small route holds, with five small changes in two pull requests.** The scripts already work from
the checkout of the package repository that owns the issue: records resolve, entries commit there,
rounds count, review sources check coverage, and branch checks and the pull request reads target the
right repository. What breaks is narrow. Today nothing sends a phase or the host to that checkout:
`dispatch_phase.sh` names the package worktree's top folder, which is not that repository. The
dispatcher also refuses `owner/repo#N`. And from the wrong folder, writes go silently into the wrong
repository. No piece needs the records lookup of issue 393 for the default records setting.

This replaces the earlier four-part plan, which folded issue 393's records lookup into this issue.
The owner's answer of 2026-11-10 at the third plan review: "R1, try the small route first".

## Evidence (synthetic sandbox, removed after the run)

The sandbox was a copy of this branch's tracked tree as a workspace. It registered a `ros2_colcon`
project `demo` whose hosting directory lies inside the workspace tree, with no git of its own (the
in-workspace shape). Two package repositories, `pkg_a` and `pkg_b`, used scp-form origins
`git@github.com:owner/<repo>.git`. A `GIT_SSH_COMMAND` stub served them from local bare repositories,
so the adapter's owner/repo parsing and `git push` both worked offline. `gh` was stubbed and logged
every call; its default repository was taken from the origin of the current directory, as real `gh`
does. `pkg_b` already carried its own merged issue-7 records. I created a package worktree for
`owner/pkg_a#7` with both repositories, from the session root with `--layer l1 --package-repos
pkg_a,pkg_b`. `pkg_a` came out on `feature/issue-7` and `pkg_b` on `feature/pkg_a-issue-7`. Later I
added a second package worktree for `owner/pkg_b#7`.

Directories: **H** the session root (the hosting directory); **C** the package worktree's top folder;
**A** the `pkg_a` checkout in it (the owning repository); **B** the `pkg_b` checkout in it (a sibling
with the same number). From C and H, `git rev-parse --show-toplevel` is the workspace main checkout,
on `main`.

| Piece | Result |
|---|---|
| `session_root.sh`, `skill_prefix.sh` | **Works as is**, read once at H before step 1, as `run-issue` already says: H gives `type=project project=demo`, bare prefix. Both refuse A and B ("a session there does not read that root's local settings"), so they must never be re-read after the host moves into A. Nothing in the phase skills calls them |
| `worktree_create.sh` / `worktree_enter.sh` from H | **Works as is** with `--layer` and `--package-repos`. Without them it refuses ("ros2_colcon requires both"). Re-entry by the qualified ref and by the bare number both print C |
| `dispatch_phase.sh --issue 7 --skill <phase>` | **Breaks**, because it prints `worktree=C` and an exit contract of `C/.agent/work-plans/issue-7/progress.md`. Nothing commits there, and no reader looks there |
| `dispatch_phase.sh next --issue 7` | **Breaks**, because it reads the timeline under C. After an Issue Review was committed in A it still said `action=review-issue`. With `--progress <A path>` it said `action=plan-task`, which is right |
| `dispatch_phase.sh --check-exit` | **Breaks**, because it printed `status=MISSING` for an entry present in A, which would end the run at the phase-failed checkpoint. By the code, `sha=` and the review-code round branch would be read from C, which is the workspace main checkout |
| `dispatch_phase.sh ... --issue owner/pkg_a#7` | **Breaks**, because the `^[0-9]+$` gates refuse it. With two package worktrees for issue 7, bare `7` is refused as "no project worktree found", which hides the ambiguity message |
| `_resolve_work_plans_dir.sh` | **Works as is** from A: rule 2b, branch `feature/issue-7`. It refuses B, C and H when `WORKTREE_ISSUE` is unset. With `WORKTREE_ISSUE=7` it **silently** returns B's own `issue-7` directory, and from C the workspace main checkout's |
| `review_progress.sh persist` | **Works as is** from A. From B and C, compatibility mode (the default) prints "would have aborted" and then **commits anyway**: in B, into `pkg_b`'s own issue-7 timeline; in C, into the workspace main checkout on `main`. Strict mode refuses both |
| `progress_append.sh` | **Works as is** from A. From C it **silently** committed `progress: checkpoint for #7` on the workspace's `main`. It has no guard at all |
| `review_progress.sh round`, `findings`, `verdict`, `plan-sha` | **Works as is** from A, with no `--progress` (`round=2` after one complete pre-push review) |
| `review_progress.sh sources` (`_bookkeeping.sh`) | **Works as is** from A: the review one progress commit behind the head counts as `bookkeeping`. From C it is dropped as `unverifiable` |
| `check_branch_updates.sh` | **Works as is** from A and B. From C it would report "on default branch" (the workspace's `main`) |
| `gh_create_pr.sh` | **Works with a small change.** From A without `-R` it refuses ("gh would target 'owner/pkg_a', which is not the workspace or project repo"). With `-R owner/pkg_a` it creates the pull request in `owner/pkg_a` |
| `fetch_pr_reviews.sh --pr 12` | **Works as is** from A (`repos/owner/pkg_a/...`). From C it would read the workspace's pull request #12, **silently** |
| `merge_pr.sh` | **Works with a small change.** `--pr 12 --type project` refuses ("not open in project repo"). `--pr owner/pkg_a#12` targets `owner/pkg_a` and finds the package worktree. Its gate stays report-only and says "would have refused — package worktree C carries no issue timeline", then posts its record as a pull-request comment and goes on to the merge call (stubbed to fail, so nothing was removed) |
| `review-plan` skill, plan lookup block (102-107, literal) | **Breaks**: from A it looks under `A/worktrees/...`, and from H the glob reaches C. Neither finds `A/.agent/work-plans/issue-7/plan.md` |
| `address-findings` skill line 91 (literal) | **Breaks**: `--progress $WS_ROOT/.agent/work-plans/issue-<N>/progress.md` names the workspace main checkout, which is wrong for any worktree once the user tier is installed |
| `triage-reviews` 138, `plan-task` step 4, `review-code` persist, `cross_model_review.sh` | **Works as is** from A, since all of them anchor on the current repository or the resolver |

**Prototype.** I applied about 15 lines to the sandbox copy of `dispatch_phase.sh`: accept the
qualified ref, and map a worktree that has a manifest to its entry on `feature/issue-N`. From H,
`next --issue owner/pkg_a#7` then read A's timeline (`action=address-findings`, `round=1`). The
handoff named `worktree=A` and an exit contract under A. `--check-exit` printed `status=OK sha=` A's
head. `owner/pkg_b#7` reached the second worktree's `pkg_b`. Bare `7` was refused.

**Same number, second repository.** Today identity is confused only when something runs in B or C. The
compatibility write lands in `pkg_b`'s own timeline, and `WORKTREE_ISSUE=7` resolves to it. In A,
identity comes from the repository itself (`gh` and git both resolve `owner/pkg_a`). So the small route
rests on two things: always work in A, and refuse B and C.

## Where the working directory is decided

In one place: **`dispatch_phase.sh`'s `resolve_worktree`**. It maps a worktree that has a `.worktree-repos`
manifest to the checkout of the repository that owns the issue. The manifest's entry recorded on
`feature/issue-N` is that checkout: the adapter's owning rule, ros2_colcon `adapter.sh` 769-773. A
single-entry manifest gives its one entry, and `.` means the worktree itself, which is what single-repo
project worktrees write. Any other case refuses, naming the entries. Everything downstream follows from
`wt` without further change: `worktree=`, the exit contract, the implement task line, `next`'s and
`check-exit`'s timeline, the round branch and `sha=`.

- **Phases** get it as `worktree=` in the handoff, as today. For a mapped worktree, the handoff adds one
  line, `package_worktree=<C>`, because the generated `env.sh`, `build.sh` and `test.sh` live there.
- **The host** gets it from a new `dispatch_phase.sh where --issue <ref> [--type] [--project]`, which
  prints the same path. `run-issue` step 1 `cd`s there after `start-task`. For a workspace or
  single-repo issue the path is the worktree itself, so there is one code path. From then on, the host's
  own commands run in A: the pull-request probe, `git push`, `check_branch_updates.sh`,
  `gh_create_pr.sh`, `fetch_pr_reviews.sh`, and `progress_append.sh` for checkpoints.

**A wrong directory is refused, not used.** A guard in `_resolve_work_plans_dir.sh` runs when a
`.worktree-repos` manifest encloses the current directory or the target repository's toplevel. In that
case the repository that would commit the issue's records must be the issue's checkout (the rule above).
Otherwise the guard refuses and names the right directory: "this is the package worktree for
owner/pkg_a#7; its records go in <A>". It is called from `resolve_work_plans_dir` (rules 2 and 2b),
from `review_progress.sh persist` in both modes (before the compatibility write), and from
`progress_append.sh`. The guard is a no-op outside a manifest worktree, so workspace issues and every
existing fixture behave as today. It closes the B and C cases above.

The case it does not close: a sub-agent that forgets to `cd` and writes from H, whose toplevel is the
workspace main checkout. That hole exists for workspace issues today as well (compatibility mode
commits into a main checkout). It is not package-specific, and closing it changes compatibility-mode
behaviour that three existing tests assert. It goes to a follow-up issue (below) and is not stretched
into this one.

## Changes

**Pull request 1: the loop runs in the owning checkout.**

1. `dispatch_phase.sh`:
   - `dispatch`, `check-exit` and `next` accept `--issue owner/repo#N`. The qualified ref goes to
     `resolve_worktree`, and the number goes into paths and the task line, because the phase runs in A,
     where `gh issue view N` resolves to that repository.
   - `resolve_worktree` maps a worktree with a manifest to its issue checkout, applied once after
     whichever base found it (new, transition or legacy).
   - `find_worktree_by_issue`'s ambiguity message is passed through instead of being swallowed as
     "no worktree found".
   - New `where` subcommand.
   - The `package_worktree=` handoff line when mapped.
   - Header comment updated.
2. `_resolve_work_plans_dir.sh`: the manifest guard as a function (`issue_checkout_guard <dir> <N>`),
   called inside rules 2 and 2b.
   - `progress_append.sh` and `review_progress.sh persist` (strict and compatibility, before writing)
     call it.
   - A refusal exits non-zero with the right directory named. Compatibility mode no longer writes in
     that case.
3. `run-issue/SKILL.md`:
   - Usage takes `owner/repo#N`, with `--layer` and `--package-repos` passed through to `start-task`.
     They are needed only when the worktree does not exist yet; without them, creation refuses with
     `worktree_create.sh`'s own message.
   - Step 1: `cd "$(dispatch_phase.sh where ...)"`.
   - Every `dispatch_phase.sh` call passes the qualified ref.
   - Publish passes `gh_create_pr.sh -R <owner/repo>` for a package issue.
   - Step 11 `cd`s to the session root printed by `session_root.sh` (`root=`). `git rev-parse
     --show-toplevel` there is the worktree that `merge_pr.sh` removes. Step 11 then calls `merge_pr.sh
     --pr <owner/repo#M>` for a package issue.
   - Rewrite the two Scope entries: `--type project` end to end, and ADR-0012 package worktrees. State
     that one owning repository per run is supported, and that sibling repositories are for building
     against, not committing. Rewrite the line-68 paragraph so it says the prefix is read at the root,
     never re-read inside a package checkout.
4. Skill lines a dispatched phase runs literally:
   - `review-plan`: the issue-number form tries `$(git rev-parse --show-toplevel)/.agent/work-plans/issue-<N>/plan.md`
     first. Change the same in the `plan-sha --plan` line at 307.
   - `address-findings` 91: `--progress "$(git rev-parse --show-toplevel)/.agent/work-plans/issue-<N>/progress.md"`.
   - These lines are wrong today for any worktree once the user tier exists. The prose mentions stay
     for issue 393.
5. Tests: new `.agent/scripts/tests/test_package_issue_loop.sh` (`chmod +x`), built on the sandbox
   recipe above. It names no project or machine: project `demo`, packages `pkg_a` and `pkg_b`, owner
   `owner`. Cases:
   1. `where`, `dispatch`, `next` and `check-exit` from H with `owner/pkg_a#7` name A: path, exit
      contract, `sha=`, round branch.
   2. The same with `owner/pkg_b#7` names the second worktree's `pkg_b`. Bare `7` is refused with the
      qualified refs listed.
   3. A single-repo project worktree (`.` entry) still maps to itself.
   4. `persist` (both modes) and `progress_append.sh` from A commit in A. From B and C they refuse,
      naming A, and commit nothing anywhere, including `pkg_b`'s own issue-7 timeline and the
      workspace `main`.
   5. `resolve_work_plans_dir 7` with `WORKTREE_ISSUE=7` from B and C refuses.
   6. A manifest with no entry on `feature/issue-N` refuses.

   Existing suites: run `test_dispatch_phase.sh`, `test_resolve_work_plans_dir.sh`,
   `test_progress_append.sh`, `test_review_code_convergence.sh`, `test_plan_correlation.sh` and
   `test_triage_reviews_integration.sh` unchanged. Expected: no expectation changes, since none has a
   manifest. Any parallel run names its job count (`-j 4`).
6. Same-change text:
   - `docs/design.md#worktrees`, Records bullet. Replace "has no timeline" with: a package issue's
     records are committed in the owning repository's checkout inside the package worktree, under the
     default records setting; `dispatch_phase.sh` decides that directory; and the guard refuses the
     others.
   - `.agent/knowledge/script_reference.md` rows: `dispatch_phase.sh` `where`, and the guard.
   - A change-log row.

**Pull request 2: the merge gate reads the owning checkout's timeline (still report-only).**
`merge_pr.sh`'s manifest scan keeps the matching entry's relative path. For a pull request on the owning
repository's `feature/issue-N`, `_gate_wt` and `_ci_wt` become `<C>/<rel>`, and `_gate_record` commits
and pushes the record there through `progress_append.sh` (the guard accepts A). A sibling pull request
(`feature/<repo>-issue-N`) keeps today's path: "carries no issue timeline", posted as a pull-request
comment. Multi-repository issues are out of the issue's scope. Changes:

- Tests: flip the package expectation at `test_merge_pr_gate.sh:483-509`. Add a case where an approved
  review at the head in A's timeline leaves the gate with nothing to report, and one where the record
  lands in A, never in C or the workspace tree.
- Design: the Merge gate and Records sentences, and refresh the cited `merge_pr.sh` line numbers.

Reaching the merge checkpoint does not need pull request 2: the gate is report-only and passes either
way. The issue asks for it ("the merge gate finds them there"), and without it every package merge
posts a "would have refused" comment that is false. **The gate stays report-only for package pull
requests.** Turning it blocking stays with the "until #265 settles project timelines" condition and is
not this issue's.

## Out of scope

- **Issue 393:**
  - the records lookup over the records settings (`location=outside`, `tracking=untracked` and `repo`);
  - routing every caller and skill through it;
  - the hand-built-path audit and the prose `$WS_ROOT/.agent/work-plans` mentions;
  - `sitrep`'s records listing;
  - `worktree_create.sh --workflow` for a package worktree (it writes into C; `run-issue` does not
    use it).
- **Later:**
  - inferring `--layer` and `--package-repos` from the issue ref. The adapter can find the layer that
    holds `src/<repo>`, about 10 lines; until then the first run of an issue names them once;
  - pull-request identity in a shared timeline, with sibling pull requests at the gate;
  - issues spanning several package repositories (also out of the issue's scope).
- **Follow-up issue for the host to file:** compatibility-mode persistence and `progress_append.sh`
  commit into a main checkout when run from outside any worktree (case H). This is pre-existing and
  hits workspace issues too.

**How issue 393 later serves the second half without undoing this.** The owner, 2026-11-10: "It's
configurable so that projects that want to keep it in the repo can and projects where we don't want to
leave a footprint, we can pick a different location." This plan settles where the work happens: the
owning checkout, chosen in one place. The default setting puts the records there as well. Issue 393's
lookup answers a different question: where this issue's records go under this project's settings. When
it lands, the dispatcher's exit contract, `next`, `check-exit`, and the persistence writers take the
records directory and the committing repository (or none) from the lookup instead of
`<checkout>/.agent/work-plans/issue-N`. The working directory stays the owning checkout, because the
code is still there. The guard's rule, "only the issue's checkout commits its records", becomes "only
the lookup's committing repository", the same function with a different source. Nothing built here is
removed.

## Files to Change

| File | Change | PR |
|---|---|---|
| `.agent/scripts/dispatch_phase.sh` | Qualified ref, owning-checkout mapping, `where`, `package_worktree=`, ambiguity message | 1 |
| `.agent/scripts/_resolve_work_plans_dir.sh` | `issue_checkout_guard`; called in rules 2 and 2b | 1 |
| `.agent/scripts/progress_append.sh`, `.agent/scripts/review_progress.sh` | Call the guard before writing (persist: both modes) | 1 |
| `.claude/skills/run-issue/SKILL.md` | Qualified ref, step 1 `cd`, publish `-R`, step 11 root and `--pr owner/repo#M`, Scope, line 68 | 1 |
| `.claude/skills/review-plan/SKILL.md`, `.claude/skills/address-findings/SKILL.md` | Literal records lines anchored on the current repository | 1 |
| `.agent/scripts/tests/test_package_issue_loop.sh` (new, `chmod +x`) | Synthetic sandbox cases 1-6 | 1 |
| `docs/design.md`, `.agent/knowledge/script_reference.md` | Records bullet, script rows, change log | 1 |
| `.agent/scripts/merge_pr.sh`, `.agent/scripts/tests/test_merge_pr_gate.sh`, `docs/design.md` | Gate reads and records in the owning checkout; report-only kept | 2 |

## Prior Art

Reused as is:

- `find_worktree_by_issue`'s qualified-ref matching;
- the manifest's owning-entry rule (the adapter's `feature/issue-N`);
- `merge_pr.sh`'s manifest scan;
- `_resolve_work_plans_dir.sh` rule 2b, which already resolves correctly in the owning checkout;
- the `sources` and `_bookkeeping.sh` coverage check, which runs in the current repository;
- `gh_create_pr.sh -R`;
- `merge_pr.sh --pr owner/repo#N`.

For the test fixture I took `test_ros2_colcon.sh`'s worktree sandbox and `test_merge_pr_gate.sh`'s gh
stub, and added the `GIT_SSH_COMMAND` stub so scp-form origins push offline.

Rejected: building issue 393's lookup here (the first three revisions; the owner chose this route), and
`cd`ing the session into the package worktree's top folder (C is not a repository, and its toplevel
is the workspace main checkout).

## Serves

Workspace goal "A project can be worked from its own root". Design: `docs/design.md#worktrees`
(Records) and `docs/design.md#review-loop-and-timeline` (pull request 2: `docs/design.md#merge-gate`).

## Design Picture

Changes the Records bullet of `docs/design.md#worktrees`: a package issue has a timeline, in the owning
checkout, with its directory chosen by `dispatch_phase.sh`. Pull request 2 changes
`docs/design.md#merge-gate`, where the package gate reads that timeline and stays report-only.
`docs/design.md#sessions-and-roots` needs no change: the session stays at the root, the work happens
under it, and the root checks are read once there.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Only what's needed / small steps | Five changes, two pull requests; the lookup stays issue 393's |
| Enforcement over documentation | The wrong-directory guard refuses in code; the gate's report-only status is stated, not changed |
| Test what breaks | Each silent failure seen in the sandbox (sibling timeline, workspace `main`, two worktrees with one number) has a case |
| Put each thing at the level it applies to | Manifest-driven, no project or machine named; fixture names are made up |
| A change includes its consequences | `run-issue` Scope, design Records, script reference, change log in pull request 1; gate text in pull request 2 |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0003 | Yes | Synthetic sandbox; no project named in scripts or tests |
| 0011 / 0012 | Yes | Reads `.worktree-repos` and the adapter's branch rule; no branching on project type |
| 0013 | Yes | Unchanged: key is the number, per owning repository, under the default setting |
| 0014 | Yes | The handoff's `worktree=` is the owning checkout; one driver per issue unchanged |
| 0016 / 0018 | Yes | The session stays at the root; `session_root.sh` and `skill_prefix.sh` are read there once (they refuse a package checkout, shown) |
| 0017 | Yes | Design edited in the same pull request |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| `dispatch_phase.sh` handoff and subcommands | `run-issue` step 1 and dispatch calls, its header, script reference | Yes, PR 1 |
| Guard in persistence writers | Error text names the right directory; existing suites run unchanged | Yes, PR 1 |
| Package records exist | Design Records bullet ("has no timeline" reversed); issue 393's "stay so" line is reversed in PR 1's text, not by editing 393 | Yes, PR 1 |
| Gate reads the owning timeline | `test_merge_pr_gate.sh:483-509` flips; Merge gate text and line numbers | Yes, PR 2 |

## Decisions for the owner's veto

1. Records for a package issue live in the owning package repository on its feature branch: the
   default `(project, project)`, a footprint in that repository. Undo is low before the first run;
   after runs, the `.agent/work-plans/issue-N/` directories stay in those repositories' history.
2. The working directory is decided once, in `dispatch_phase.sh`, and the host follows it through
   `where`. Undo is low.
3. A manifest-scoped guard refuses writes from a sibling or the top folder. The main-checkout hole is
   left to a follow-up issue rather than changing compatibility mode here. Undo is low.
4. Two pull requests; the gate stays report-only. Undo is low.

## Open Questions

None for the owner.

## Estimated Scope

Two pull requests. PR 1 touches about 11 files: 4 scripts, 3 skills, 1 new test suite, 2 text files,
and possibly 1 existing suite. PR 2 touches 3 files. PR 2 can follow PR 1 directly, since it needs the
guard and the `.worktree-repos` handling of PR 1.

Not tested, and why:

- The Agent tool's sub-agent working directory, and how phases follow the handoff: no Agent tool in a
  sandbox.
- How phases read skill prose: model behaviour, not script behaviour.
- Real `gh` choosing a default repository when a checkout has an `upstream` remote: the `gh` stub
  modelled only the single-origin rule.
- `cross_model_review.sh` end to end: it needs external reviewer tools; only its resolver call was
  covered.
- `start-task` as a slash command: Claude Code only. Its scripts, `worktree_create.sh` and
  `worktree_enter.sh`, were run.
