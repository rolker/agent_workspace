# Plan: run-issue: drive an issue in a package repository of a multi-repository project

## Issue

https://github.com/rolker/agent_workspace/issues/429

## Verdict first

**Part 1 is merged (pull request 445, 2026-11-10); its text below is the record of what was done. Part 2 is in "Part 2 (detailed)" below.**

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
lone `.` entry (a legacy one-entry manifest) means the worktree itself. Single-repo project worktrees
write no manifest at all (`worktree_create.sh` skips a lone `.` entry), and neither do workspace
worktrees, so the rule leaves both as they are. Any other case refuses, naming the entries. Everything downstream follows from
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

**Pull request 2 (revised after part 1 merged): see "Part 2 (detailed)" below.** The earlier outline of
this paragraph (gate reads the owning checkout's timeline, report-only kept, flip
`test_merge_pr_gate.sh:483-509`) is carried into steps 6 and 9 there; the base branch (issue comment of
2026-11-10) is added as pull request 2a.

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

## Part 2 (detailed; revised 2026-11-10 after part 1 merged as pull request 445)

**Status of part 1: merged** (pull request 445, 2026-11-10). Its text above stays as the record of what
was done. Part 1 already made `merge_pr.sh` pass the gate's timeline path through `records_path`, so
inside a package worktree today `_gate_wt` is the top folder C, the records gate refuses it, and every
package pull request records "carries no issue timeline" as a pull-request comment. Part 2 closes the
rest of the issue: the base branch, the gate, the end-to-end test and the texts. Cut as **two pull
requests** (about 16 files and 700 lines in all; one would not review well): **2a the base branch**,
**2b the gate, the end-to-end test and the texts**. 2b builds on 2a; each is merged on its own.

### What I found when reading the merged code (the facts the steps rest on)

- **A package branch is cut from the repository's default branch.** `_wt_add_repo` starts a new branch at
  `_wt_default_start_point` (origin/HEAD, plain git) unless `--parent-issue` gives a parent. So for a
  repository pinned at one branch whose default is another, the branch itself holds the wrong history,
  not only the pull request's target. Setting `--base` at publish alone would open a pull request carrying
  the difference between the two branches. The base must decide the start point too.
- **The parent-branch mechanism is the existing "start here and target here" path** (`PARENT_BRANCH`,
  `PARENT_BRANCH_FOUND`, `wt_fetch_named_branch`, `create_draft_pr ... --base`). It is global to all
  entries of a manifest. For `--base` it must apply to the owning entry only.
- **Worktree creation's draft-pull-request path does not run for a package worktree**:
  `worktree_create.sh` prints "--plan-file draft PR creation is not supported for package worktrees ...
  Create PRs per package repo by hand" when `--layer` is set. So the draft path needs no base logic; its
  message gets one sentence pointing at the publish step.
- **The pin is not exposed today.** `_rc_repos_entries` (the `.repos` parser, `name<TAB>version`) is
  internal to `adapter.sh`: `sync` and `validate` use it and print the pin only in a "(pinned: X)" line;
  `adapter repos` prints `name:path` and nothing else; `adapter` dispatches only `REQUIRED_VERBS`. A generic
  script reading `.repos` itself would break ADR-0011. So today the pin has no legal reader.
- **Gate condition (a) takes the newest review entry, whatever pull request number it names**; only the
  duplicate check keys on the number (`correlation.pr`). `progress_read.py` already accepts the text
  `owner/repo#12 at <sha>` (it uses `re.search`) but drops the repository, so it cannot tell pull request 12
  of one repository from pull request 12 of another.
- **Main's "a run removes only what it made" rule is not in the tree** (searched `docs/`, `.agent/`,
  `.claude/` at `3486edba`, and `origin/main`). I read it as: cleanup removes only the package worktree
  and the branches that worktree made; the plan states how below, and the host should say if the rule
  lives on a branch I have not seen.

### Where the base comes from

| When | Source | Behaviour |
|---|---|---|
| Today (`repo_pin` not merged) | The base is given by hand: `--base <branch>` on `/run-issue` and `worktree_create.sh`, recorded in the manifest header | Without it, step 1 of a package run stops with: "the base branch of <repo> cannot be read from the adapter yet (needs `repo_pin`, issue 436); pass --base <branch>, normally the branch the manifest pins." Nothing is guessed from the forge or from `origin/HEAD` |
| After issue 436 pull request (c) | `adapter repo_pin <name>`, one line `<ref><TAB><kind>`; `<name>` is the owning entry's directory name, the last component of its manifest path, which is what `adapter repos` prints before the colon | `kind=branch`: that branch is the base. `tag`, `commit`, `unknown`: refuse with "<repo> is pinned at <ref> (<kind>); only a branch can be a base. Pass --base <branch>." `--base` still overrides (and must name a branch on origin) |

How the code tells which row it is in: `dispatch_phase.sh base` does `( source adapter; printf '%s\n'
"${REQUIRED_VERBS[@]}" ) | grep -qx repo_pin` (the dispatcher is sourceable and defines the list), never
by reading an error message. When (c) lands the "no verb" row is dead code: delete that branch in
whichever pull request is open then, or in a one-line follow-up. Nothing else changes.

"Is it a branch" is always checked by plain git on the owning repository's origin:
`git ls-remote --exit-code --heads origin <b>` (offline: `refs/remotes/origin/<b>` locally, with the word
"unverified" in the message). The forge's default branch (`gh repo view`) is never read.

### Pull request 2a: the base branch

1. `_pr_base.sh` (new, sourced; no project or type named): `pr_base_for <owning-checkout> [--base b]`
   prints the branch or exits 2 with the messages above; it reads the manifest header first (`base=`), so a
   recorded base is the answer and a conflicting `--base` is refused. It holds the verb check and the
   branch check. **Not a new suite file**: tests go in existing files (below).
2. `dispatch_phase.sh`: new subcommand `base --issue <ref> [--base b] [--type] [--project]` (one line,
   `base=<branch>`; works before the worktree exists, using the adapter and the layer given, and after it,
   from the header). The handoff gains `base=<branch>` for a package issue. Header comment updated.
3. `worktree_create.sh`: `--base <branch>` (package worktrees only; refused with `--parent-issue` and with
   a non-package type). In the manifest loop only the owning entry gets it as the `_wt_add_repo` parent,
   so the new `feature/issue-N` starts at `origin/<base>` and a missing or unreachable base is an error,
   never a silent fall back to the default. `wt_write_manifest` gains an optional fifth value and the
   header becomes `# project=P issue=I layer=L base=B` (readers use `sed` on named fields, so older
   readers ignore it; `wt_read_manifest` sets `WT_MANIFEST_BASE`). The "draft PR not supported" message
   adds: "publish with run-issue, which passes -R and --base".
4. `run-issue/SKILL.md`: usage takes `--base <branch>` (package issue); step 1 runs `dispatch_phase.sh
   base` before `start-task` and stops with its message; publish becomes `gh_create_pr.sh -R <owner/repo>
   --base <base>` for a package issue (the same one-line `base=` read at the root, after `cd` into the
   checkout). The step that resumes an older part-1 worktree (no `base=` in the header) asks the same
   subcommand.
5. Tests, existing files only: `test_worktree_create.sh` (a package worktree with `--base`: owning branch
   starts at the base commit not the default's; siblings unchanged; header carries `base=`; a base absent
   from origin is an error and rolls back; `--base` with `--parent-issue` refused; a worktree without
   `--base` is unchanged), and `test_package_issue_loop.sh` (the sandbox gets a pkg_a whose default branch
   is `main` and whose pin is `pinned`; `base` with and without `--base`; tag, commit and unknown refuse
   when a stub dispatcher reports each kind; the verb-absent message; gh log shows `pr create -R
   owner/pkg_a --base pinned`). Until (c) exists the verb cases use a stub adapter type in the sandbox
   (the same trick the sandbox already uses for `ros2_colcon`); the real verb is covered by issue 436's
   own tests. Suites that prove workspace and single-repository issues unchanged, run unchanged:
   `test_worktree_create.sh`, `test_dispatch_phase.sh`, `test_gh_create_pr.sh`,
   `test_resolve_work_plans_dir.sh`, `test_progress_append.sh`.

### Pull request 2b: the gate, the end-to-end test, the texts

6. **The gate reads and records in the owning checkout.** In `merge_pr.sh`, after the manifest scan finds
   `PKG_WT_DIR`: when `PR_BRANCH` is `feature/issue-${ISSUE_NUM}` and `issue_checkout_of "$PKG_WT_DIR"
   "$ISSUE_NUM"` names a checkout whose origin slug is `PR_REPO_SLUG`, set `_gate_wt` to that checkout (A).
   That is a value change at the existing `_gate_wt=` assignment: `records_path "$_gate_cand" "$_gate_wt"`
   stays as it is, and the guard accepts A. `_ci_wt` and `_gate_record`'s "is a repo" test (both guarded by
   `-z "$PKG_WT_DIR"` now) accept this case, so the ancestry check, the CI target and the record commit
   plus `git push origin $PR_BRANCH` run in A through `progress_append.sh -C`. **A sibling pull request**
   (`feature/<repo>-issue-N`) keeps `_gate_wt` = the top folder: its reason text changes to "a sibling
   repository's pull request: this issue's records are in <A>, and a sibling's gate is not read there",
   and its record is posted as a pull-request comment.
7. **Pull request identity is repository plus number.** (i) `progress_read.py` adds `repo` to a `pr`
   correlation when the line is `owner/repo#M at <sha>`; an unqualified `#M` means the repository whose
   checkout holds the timeline. (ii) `merge_pr.sh` writes `**PR**: ${PR_REPO_SLUG}#${PR_NUMBER} at ...` for
   package pull requests and `#M` as today for workspace and project ones (ADR-0013's line 107 gains "an
   optional `owner/repo` before the `#`"; nothing else in the vocabulary changes). (iii) gate condition (a)
   skips an entry whose `repo` is set and differs from `PR_REPO_SLUG`; (iv) `_gate_already_recorded` compares
   `repo` as well as the number. Sibling records stay in comments, so on today's flows the qualifier only
   guards the case where two repositories' entries meet; it is tested by a timeline holding `pkg_a#12` and
   `pkg_b#12` reviews and records.
8. **A pull request whose base is not the recorded base** adds a gate reason: `_head_json` gains
   `baseRefName` (the same `gh pr view` call, no new request) and the reason reads "targets <x>; this
   worktree's recorded base is <y>". Report-only like every package reason. Silent when the header has no
   `base=` (a part-1 worktree).
9. **Report-only stays; enforcement is not this issue's.** The design says so in terms: "The gate enforces
   by default on workspace pull requests: a gap refuses with exit 1 and no entry. Project and package pull
   requests are report-only: the gap is printed and recorded as a `## Merge (report-only)` entry and the
   merge goes ahead" (`docs/design.md#merge-gate`), and the script's own note is "gate enforcement applies to
   workspace PRs only until #265 settles project timelines". Nothing in part 2 settles that. What changes is
   that the record now lands on the right timeline, so a package merge no longer posts a "would have
   refused" comment that is false.
10. **Cleanup across the repositories** (`merge_pr.sh` Step 4, package branch; code unchanged, behaviour
    pinned by tests). A run removes only what it made: the package worktree (via `worktree_remove.sh`, which
    refuses uncommitted changes in any entry), the merged branch on its remote, and local branches by safe
    delete (`git branch -d`) only where the remote has dropped them. A sibling branch with commits that
    were never merged is kept with git's own message; a sibling with an open pull request keeps the whole
    worktree. Tests: merged owning pull request with (a) no sibling work: C removed, A's branch deleted;
    (b) sibling with unmerged commits and no remote: C removed, sibling branch kept and named; (c) sibling
    with an open pull request: C kept. The merge is run from the session root (step 11, part 1).
11. **The made-up project name.** In `test_merge_pr_gate.sh` the package fixtures use `p11` as the project
    name and in the worktree folder name (4 lines: the two part 1 added and the two it copied from); rename
    to `demo`. Also the mechanism comments that name it in files this part touches (`merge_pr.sh` and the
    run-issue Scope/prefix text). Other suites that use the same name as a fixture (`test_merge_pr.sh`,
    `test_ros2_colcon.sh`, `test_project_registry.sh`, `test_session_root.sh`, `test_skill_prefix.sh`,
    `test_session_start_layer.sh`, about 170 lines) and comments in `skill_prefix.sh` and
    `user_tier_install.sh` are not in part 2; a follow-up issue renames them (veto 8).
    `test_package_issue_loop.sh` names no project (`grep -i` for the real project's short name finds
    nothing); the sandbox project there is `demo`.
12. **End-to-end test** in `test_package_issue_loop.sh`: from the session root with a stubbed `gh` and
    the stub dispatcher: `base`, create the worktree with `--layer` `--package-repos` and the base, `where`,
    a commit in A, `dispatch_phase.sh` handoff and `check-exit` for an Implementation entry, publish through
    `gh_create_pr.sh -R --base` (gh log asserts both), a review entry and checkpoint in A's timeline, then
    `merge_pr.sh --pr owner/pkg_a#M` stopping at its merge call (stubbed to succeed): the gate finds the
    review at the head, records nothing wrong, the record (if any) is committed in A and nowhere else
    (workspace `main`, C, B), cleanup runs per step 10. Add the same-number sibling (`pkg_b#M`) to prove step 7.
13. **Texts, same pull request.** `run-issue/SKILL.md`: the Scope entry "More than one owning repository"
    says what is supported after part 2 (one owning repository per run, base from the pin or `--base`, the
    gate reads and records in the owning checkout, report-only); step 11's "until the merge gate reads ..."
    sentence is removed; the line that says GitHub-only publish and merge stays. `docs/design.md`: Records
    bullet (Worktrees), Merge gate bullets, the verb text for the base, a change-log row, `merge_pr.sh` line
    citations refreshed. `.agent/knowledge/script_reference.md`: `dispatch_phase.sh base`, `_pr_base.sh`,
    `worktree_create.sh --base`. ADR-0013 line 107 (the optional qualifier). Same-change text for the
    manifest header (`base=`) in ADR-0012's manifest paragraph.

### Same lines as issue 437, and who merges second

Issue 437 adds `--write` to `records_path` / `records_dir` in `_resolve_work_plans_dir.sh`. **Part 2 does
not edit that file**, and in `merge_pr.sh` it leaves the `records_path "$_gate_cand" "$_gate_wt"` call
exactly as it is; it only changes the value `_gate_wt` takes. Shared ground is then: (1) `progress_append.sh -C
"$_gate_wt"` in `_gate_record` is a write, so 437's rule applies to it, and the owning checkout A is on
`feature/issue-N`, which 437's rule accepts (its step 3 says no package carve-out is needed); the end-to-end
test proves it once both are in; (2) `test_package_issue_loop.sh` (437 flips one assertion, part 2 appends
cases) and `docs/design.md`'s Records bullet and change log (both add a sentence or a row): textual
conflicts only. **437 merges first** (it is the smaller change, further along, and 2b depends on nothing in
it); part 2 rebases onto it and re-runs the end-to-end test. 2a does not touch either file's contested
parts, so it may merge in either order. Issue 444 changes `run_script_tests.sh`; part 2 adds no suite
file, so it does not touch the runner or the presence assertion that names every suite.

### What stays GitHub-bound in part 2 (for the owner's discussion)

For each place part 2 touches a forge notion, whether plain git or the adapter could answer:

| Place | Answerable without GitHub? | In part 2 |
|---|---|---|
| Base branch value | **Yes**: the adapter's pin, or `--base`; never the forge's default branch | Plain git and adapter only; no `gh` call is added |
| Start point of the package branch | **Yes**: `origin/<base>` by git | Plain git |
| Is the base a branch | **Yes**: `git ls-remote --heads` | Plain git |
| Owning-repository identity (`owner/repo`) | Partly: today from the origin URL by `extract_gh_slug`, which accepts GitHub remotes only; the adapter could say it for any host | Stays; `gh`-shaped, listed |
| Gate record location | **Yes**: the timeline commit and push are plain git; this part moves package records out of `gh pr comment` onto the timeline | Less GitHub than before |
| `**PR**: owner/repo#M` | No: a pull request is a forge notion | Stays |
| Gate condition (b), the decision summary in the pull request | No | Stays |
| CI wait (`gh api` check runs), the merge itself (`gh pr merge`) | No | Stays |
| Publish (`gh_create_pr.sh -R --base`) | No: opening a request is the forge | Stays |
| Sibling open-pull-request check at cleanup (`gh pr list`) | Partly: a sibling branch with no commits beyond its start point and not on origin has nothing to lose and needs no question to the forge; a branch with work still needs one | Stays, not changed (it fails closed and is tested; the shortcut is a possible follow-up) |
| Base cross-check at merge | Uses a field of a call already made | No new call |
| The `gh repo view` check from part 1 | No | Already in |

The loop as a whole (publish, review reading, merge) is GitHub-bound; part 2 adds none and removes one
fallback to a pull-request comment. This list is the input to the owner's discussion; no goal is recorded.

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
| `.agent/scripts/_pr_base.sh` (new, sourced), `.agent/scripts/dispatch_phase.sh` | `pr_base_for`; `base` subcommand; `base=` in the handoff | 2a |
| `.agent/scripts/worktree_create.sh`, `.agent/scripts/_worktree_helpers.sh` | `--base` (owning entry's start point); `base=` in the manifest header; `WT_MANIFEST_BASE` | 2a |
| `.claude/skills/run-issue/SKILL.md` | `--base`, step 1 `base`, publish `--base` | 2a |
| `.agent/scripts/tests/test_worktree_create.sh`, `.agent/scripts/tests/test_package_issue_loop.sh` | Base cases (no new suite file) | 2a |
| `.agent/scripts/merge_pr.sh` | Gate reads and records in the owning checkout; qualified `**PR**`; base cross-check; sibling reason | 2b |
| `.agent/scripts/progress_read.py`, `.agent/scripts/tests/test_progress_read.sh` | `repo` in a `pr` correlation | 2b |
| `.agent/scripts/tests/test_merge_pr_gate.sh` | Flip the package expectation; owning-checkout, sibling, same-number and cleanup cases; rename the fixture project to `demo` | 2b |
| `.agent/scripts/tests/test_package_issue_loop.sh` | End-to-end case from creation to the merge call | 2b |
| `.claude/skills/run-issue/SKILL.md`, `docs/design.md`, `.agent/knowledge/script_reference.md`, `docs/decisions/0013-*.md`, `docs/decisions/0012-*.md` | Scope, step 11, Records and Merge gate text, rows, change log, `**PR**` qualifier, `base=` header | 2b |

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

Workspace goal `README.md#easy-to-use` ("start an agent in the project's own directory and the
workspace is there": an issue of a package repository is driven from the project's root like any
other). Decision 1 (records in the package repository) also touches `README.md#light-touch-on-projects`,
which the veto list covers. Design: `docs/design.md#worktrees` (Records) and
`docs/design.md#review-loop-and-timeline` (pull request 2: `docs/design.md#merge-gate`).

## Design Picture

Changes the Records bullet of `docs/design.md#worktrees`: a package issue has a timeline, in the owning
checkout, with its directory chosen by `dispatch_phase.sh`. Part 2 changes `docs/design.md#merge-gate`
(the package gate reads that timeline and stays report-only) and `docs/design.md#worktrees` again (a
package worktree records its base branch; the branch starts there).
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
| 0011 / 0012 | Yes | Reads `.worktree-repos` and the adapter's branch rule; no branching on project type. Part 2: the pin is read only through `adapter repo_pin` (issue 436 owns the verb); the manifest header gains an optional `base=` field |
| 0013 | Yes | Part 1 unchanged. Part 2 amends line 107 additively: `**PR**` may carry `owner/repo` before the `#`; unqualified means the timeline's own repository |
| 0014 | Yes | The handoff's `worktree=` is the owning checkout; one driver per issue unchanged |
| 0016 / 0018 | Yes | The session stays at the root; `session_root.sh` and `skill_prefix.sh` are read there once (they refuse a package checkout, shown) |
| 0017 | Yes | Design edited in the same pull request |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| `dispatch_phase.sh` handoff and subcommands | `run-issue` step 1 and dispatch calls, its header, script reference | Yes, PR 1 |
| Guard in persistence writers | Error text names the right directory; existing suites run unchanged | Yes, PR 1 |
| Package records exist | Design Records bullet ("has no timeline" reversed); issue 393's "stay so" line is reversed in PR 1's text, not by editing 393 | Yes, PR 1 |
| Gate reads the owning timeline | The package expectation in `test_merge_pr_gate.sh` flips; Merge gate text and line citations; run-issue step 11 sentence | Yes, 2b |
| A base branch exists | Branch start point, manifest header, handoff, publish, merge cross-check, run-issue usage | Yes, 2a and 2b |
| `**PR**` may be qualified | `progress_read.py`, ADR-0013, the duplicate check, gate (a) | Yes, 2b |

## Decisions for the owner's veto

1. Records for a package issue live in the owning package repository on its feature branch: the
   default `(project, project)`, a footprint in that repository. Undo is low before the first run;
   after runs, the `.agent/work-plans/issue-N/` directories stay in those repositories' history.
2. The working directory is decided once, in `dispatch_phase.sh`, and the host follows it through
   `where`. Undo is low.
3. A manifest-scoped guard refuses writes from a sibling or the top folder. The main-checkout hole is
   left to a follow-up issue rather than changing compatibility mode here. Undo is low.
4. Two pull requests; the gate stays report-only. Undo is low.

Part 2 (decided from `docs/principles.md` and `docs/design.md`; undo cost in brackets):

5. **The base is given by hand until `repo_pin` exists, and the run refuses without it** rather than
   reading the pin in a generic script (ADR-0011) or taking the forge's default. Owner types
   `--base <branch>` once per run for a project whose pin differs from the default. [Low: delete the
   no-verb branch when issue 436 (c) lands.]
6. **The base also decides the branch's start point**, owning entry only, and is recorded in the
   manifest header as `base=`. [Moderate: a header field and a worktree_create flag; both ignored by old
   readers.]
7. **`**PR**: owner/repo#M` for package records, unqualified means the timeline's own repository.**
   Additive amendment to ADR-0013's line. [Low.]
8. **Fixture rename scope**: `demo` in `test_merge_pr_gate.sh` and mechanism text in files part 2 touches
   only; about 170 lines in six other suites and two script comments go to a follow-up issue. [Low;
   say if you want it all in 2a.]
9. **Part 2 is two pull requests, 2a then 2b**, 437 merging before 2b. [Low.]
10. **Cleanup behaviour is pinned by tests, not changed.** [None.] I could not find main's "a run removes
    only what it made" text; if it is on a branch, point me at it and step 10 aligns to its wording.
11. **Draft pull requests at worktree creation stay unsupported for a package worktree**; the message
    points at publish. [None.]

## Open Questions

None on meaning. One for the host: where is main's "a run removes only what it made" rule (not found in
`3486edba`)? Everything else is decided above for the owner's veto.

## Estimated Scope

Three pull requests in all. PR 1 (part 1) is merged (pull request 445; about 17 files). Part 2 is 2a
(about 8 files, 300 lines: base resolver, `worktree_create.sh --base`, dispatcher, run-issue, tests) and 2b
(about 11 files, 450 lines: gate, identity, end-to-end test, texts). 2b needs 2a, and merges after issue 437.

Not tested, and why:

- The Agent tool's sub-agent working directory, and how phases follow the handoff: no Agent tool in a
  sandbox.
- How phases read skill prose: model behaviour, not script behaviour.
- Real `gh` choosing a default repository when a checkout has an `upstream` remote. Real `gh`
  prefers `upstream` over `origin` (plan review, 2026-11-10), so `where` and the handoff check `gh repo
  view` against the issue's repository in the owning checkout and refuse a mismatch; the suite's stub
  ranks remotes the same way.
- `cross_model_review.sh` end to end: it needs external reviewer tools; only its resolver call was
  covered.
- `start-task` as a slash command: Claude Code only. Its scripts, `worktree_create.sh` and
  `worktree_enter.sh`, were run.
