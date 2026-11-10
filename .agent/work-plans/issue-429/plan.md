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

## Part 2 (detailed; revised twice on 2026-11-10: after part 1 merged as pull request 445, then after the plan review and the host's revise checkpoint)

**Status of part 1: merged** (pull request 445, 2026-11-10). Its text above stays as the record of what
was done. Part 1 already made `merge_pr.sh` pass the gate's timeline path through `records_path`, so
inside a package worktree today `_gate_wt` is the top folder C, the records gate refuses it, and every
package pull request records "carries no issue timeline" as a pull-request comment. Part 2 closes the
rest of the issue: the base branch, the gate, the end-to-end test and the texts. Cut as **two pull
requests that can be built in parallel**: **2a the base branch** (with its own texts) and **2b the gate,
the end-to-end test and the Scope text**. 2a is the larger (about 16 files, 600 lines, of which the verb
is about 5 files); 2b is about 8 files and 300 lines. If review finds 2a heavy, the verb (steps 1 to 2)
can be its own pull request ahead of the rest; the cut line is already there.

**The goal this serves besides `easy-to-use`:** `README.md#flexibility` (Workspace goals, Flexibility):
"When practical, preference should go to open source and open standards to minimize vendor lock-in. Have an
exit strategy for anything that depends on a vendor's closed product or infrastructure." (The earlier
statement on this timeline's merge checkpoint that no such goal was recorded was wrong; it is withdrawn.)
Part 2 adds no GitHub call, and the table at the end gives, for every place part 2 touches a forge
notion, whether plain git or the adapter answers and the exit for the rest.

### What I found when reading the merged code (the facts the steps rest on)

- **A package branch is cut from the repository's default branch.** `_wt_add_repo` starts a new branch at
  `_wt_default_start_point` (origin/HEAD, plain git) unless a parent branch is given. For a repository
  pinned at one branch whose default is another, the branch itself holds the wrong history, not only the
  pull request's target. The base must decide the start point too.
- **The parent-branch path is not strict enough to reuse for the base.** In `_wt_add_repo` a local
  `refs/heads/<parent>` is used as is, with no fetch (a vcs-imported checkout sitting on the pinned branch
  can hold local or stale commits that would enter the new branch and the pull request); a parent absent
  on origin prints a WARNING and starts from the default branch; with `--allow-unverified-branch` an
  unknown parent also starts from the default branch; and the parent add omits `--no-track`. It is also
  global to all entries. The base needs its own path, owning entry only (step 4).
- **Worktree creation's draft-pull-request path does not run for a package worktree**:
  `worktree_create.sh` prints "--plan-file draft PR creation is not supported for package worktrees ...
  Create PRs per package repo by hand" when `--layer` is set. So the draft path needs no base logic; its
  message gets one sentence pointing at publish.
- **The pin is not exposed today.** `_rc_repos_entries` (the `.repos` parser, `name<TAB>version`) is
  internal to the ROS adapter: `sync` and `validate` use it; `adapter repos` prints `name:path`; the
  dispatcher dispatches only `REQUIRED_VERBS`. A generic script reading `.repos` would break ADR-0011. The
  verb is therefore added here (step 1), as the host directed; issue 436 planned it as its own pull
  request (c), which moves here (the host records that on issue 436).
- **The manifest header's `layer=` reader is end-anchored.** `wt_read_manifest` reads `layer` with
  `sed 's/.* layer=\([^ ]*\)$/\1/p'`; on `... layer=l1 base=pinned` it prints nothing. Latent (nothing reads
  `WT_MANIFEST_LAYER` today), but "older readers ignore a new field" is false for it. Fixed in 2a before
  `base=` is written (step 5). The `issue=` and `project=` readers are not anchored.
- **"A run removes only what it made"** is in the tree and concerns undoing a failed creation, not
  merge-time cleanup: `worktree_create.sh` (`undo_new_branch_checkout`, "Only what this run made is
  undone") and `_worktree_helpers.sh` (`wt_add_new_branch`, `_wt_add_repo`'s `made_branch`). 2b's cleanup
  step does not cite it, and 2a step 4 follows it for the new strict path (a failure undoes
  only the branch this run made). The merge-time sweep (`merge_pr.sh` Step 4) safe-deletes every manifest
  entry's local branch whose remote is gone, whichever run made it; that is pinned by tests, not changed.
- **Gate condition (a) takes the newest review entry, whatever pull request number it names**, and only the
  duplicate check keys on the number. Records on A's timeline are the owning pull request's only (siblings
  go to comments), and every reader keeps working on a bare `#M`, which means the timeline's own
  repository. No identity change is needed (the qualified form is dropped; see the Decisions).

### Where the base comes from

`adapter repo_pin <repo>` prints one line `<ref><TAB><kind>` and exits 0, or exits 1 with an error on
stderr. `<kind>` is `branch`, `tag`, `commit` or `unknown`. YAML quoting around the ref is stripped.

| Case | Behaviour |
|---|---|
| kind `branch` | That branch is the base. Checked on origin by the strict path (step 4) before anything is made |
| kind `tag`, `commit`, `unknown` | Refuse, naming it: "<repo> is pinned at <ref> (<kind>); only a branch can be a base. Pass --base <branch>." |
| `--base <branch>` given | An override only: it must name a branch on origin; if the worktree header already records a different `base=`, refuse |
| the adapter cannot answer (exit 1) | Refuse with the adapter's message; nothing is guessed from the forge or from `origin/HEAD` |

**The repository name `<repo>` comes from the adapter's own entry, not from the issue reference.** The
directory name in the layer's `src/` can differ from the forge name in `owner/repo#N`. `dispatch_phase.sh
base` runs `adapter worktree_repos --issue <ref> --layer <l> --package-repos <list>` (before the worktree
exists), takes the line whose branch is `feature/issue-N` (the owning entry, the adapter's own rule) and
uses the last component of its relative path; after the worktree exists it takes the same entry from the
manifest (`issue_checkout_of`). Single-repository and workspace issues have no package base and are
unchanged.

### Pull request 2a: the base branch and the verb

1. **`repo_pin <repo>` as a REQUIRED verb every project type implements.** `adapter`: `REQUIRED_VERBS` gains
   `repo_pin` (13), its header comment and usage. `validate_adapter.sh` then asserts it for every type.
   **ROS type**: the `version:` of `<repo>` in the `.repos` files of its manifest directory, read with
   `_rc_repos_entries` (so it works on any route that fills that directory), quotes stripped here (issue
   436's own change to the parser may strip them too; whichever lands second drops the duplicate). Kind from
   git, in this order: `git ls-remote --heads origin <ref>` hit is `branch`; `--tags` hit is `tag`; a 40 or
   64 hex string is `commit`; else `unknown`. Offline or the repository not cloned: the local fallback
   (`refs/remotes/origin/<ref>`, `refs/tags/<ref>`), `unknown` when neither exists. Branch before tag, since
   a same-named tag does not stop a base. A name not in the files: exit 1 `no repository '<repo>' in the
   manifest (known: ...)`. **Single-repository type**: `<repo>` must be the name `adapter repos` prints;
   prints the default branch from `git symbolic-ref --short refs/remotes/origin/HEAD` (`origin/` removed;
   `git ls-remote --symref origin HEAD` when that ref is absent) with kind `branch`; exit 1 when undetermined
   or a different name.
2. **ADR-0011 amended in 2a** (Status paragraph: now 13 verbs, as ADR-0012 amended it to 12; the verb table
   gains the row). `docs/design.md` verb text and change-log row; `.agent/knowledge/script_reference.md`
   rows; the `adapter` header verb list. Tests in the existing `test_adapter.sh`/`test_ros2_colcon.sh`: both
   types, all four kinds, offline fallback, a branch deleted upstream (a stale remote ref is not enough, so
   not `branch` when online), the quoted ref, the not-found error, `validate_adapter.sh` on a type missing
   the verb.
3. **`_pr_base.sh`** (new, sourced, names no type): `pr_base_for <owning-entry> [--base b]` returns the
   branch or exits 2 with the messages above. It reads the header's `base=` first (a recorded base is the
   answer; a conflicting `--base` is refused), else calls `adapter repo_pin` and applies the table. **Not a
   new suite file.** `dispatch_phase.sh` gains `base --issue <ref> [--base b] [--type] [--project]
   [--layer l --package-repos list]` (prints `base=<branch>`; works before and after the worktree exists),
   and the handoff gains `base=<branch>` for a package issue.
4. **The strict start path** (`_worktree_helpers.sh`, `worktree_create.sh`). `worktree_create.sh --base
   <branch>` (package worktrees only; refused with `--parent-issue`). `_wt_add_repo` gets one more optional
   argument, the base, passed for the owning entry only. When the owning branch is new on this run (not
   local, not on origin), and a base is given: `wt_fetch_named_branch <origin> <base>`; **present** ->
   `wt_add_new_branch <origin> <dest> <branch> origin/<base> --no-track`; **absent or unknown** -> an error
   naming the reason, return 1, **whatever `--allow-unverified-branch` says**, and the manifest loop's
   rollback undoes what this run made. The local `<base>` is never used. A branch that already exists
   locally or on origin (a resume) is checked out as today. Siblings are untouched. When
   `pr_base_for` ran offline ("unverified") and creation then asks origin: **creation wins**; it stops
   with the reason, since a branch started on an unverified base can diverge.
   Tests in `test_worktree_create.sh`: (i) a base absent on origin refuses and rolls back; (ii) an
   unreachable origin refuses, also with `--allow-unverified-branch`; (iii) a local `<base>` carrying an
   unpushed commit: the new branch does not contain it, and has no upstream; (iv) siblings unchanged;
   (v) `--base` with `--parent-issue` refused; (vi) a worktree without `--base` unchanged.
5. **The manifest header carries the base.** `wt_write_manifest` gains an optional fifth value; header
   `# project=P issue=I layer=L base=B`. `wt_read_manifest` un-anchors the `layer=` reader
   (`s/.* layer=\([^ ]*\).*/\1/p`) and sets `WT_MANIFEST_BASE`. Test: the layer reads back with and without
   `base=`. ADR-0012's manifest paragraph and `docs/design.md#worktrees` (the start point and the header
   field) change in 2a.
6. **`run-issue/SKILL.md`**: usage `--base <branch>` (override); step 1 runs `dispatch_phase.sh base` before
   `start-task` and stops with its message; publish `gh_create_pr.sh -R <owner/repo> --base <base>` for a
   package issue. A part-1 worktree with no `base=` asks the same subcommand when resumed.
7. **The merge cross-check** (moved here from the gate): `_head_json` gains `baseRefName` (the same `gh pr
   view`, no new request); a reason "targets <x>; this worktree's recorded base is <y>" joins the gate
   reasons. Report-only like every package reason; silent without `base=`.
8. **Tests and suites.** `test_package_issue_loop.sh`: the sandbox's pkg_a has default branch `main` and
   pin `pinned`; `base` with and without `--base`; tag, commit and unknown refuse (a stub adapter type in the
   sandbox reports each kind); the repository name comes from the owning entry and differs from the forge
   name; gh log shows `pr create -R owner/pkg_a --base pinned`. Unchanged suites that prove workspace and
   single-repository issues: `test_worktree_create.sh` (existing cases), `test_dispatch_phase.sh`,
   `test_gh_create_pr.sh`, `test_resolve_work_plans_dir.sh`, `test_progress_append.sh`, `test_adapter.sh`,
   `test_ros2_colcon.sh` (existing cases).

### Pull request 2b: the gate, the end-to-end test, the Scope text

Needs nothing from 2a; the end-to-end test's base step is added by whichever of the two merges second.

1. **The gate reads and records in the owning checkout.** The manifest scan in `merge_pr.sh` already
   matches the entry by branch and slug; keep its relative path (`_m_rel`) as `PKG_OWN_REL` instead of
   parsing the slug a second time. When `PR_BRANCH` is `feature/issue-${ISSUE_NUM}`, set `_gate_wt` to
   `$PKG_WT_DIR/$PKG_OWN_REL` (A). That is a value change at the existing assignment: `records_path
   "$_gate_cand" "$_gate_wt"` stays as is, and the guard accepts A. `_ci_wt` and `_gate_record`'s "is a
   repo" test (guarded by `-z "$PKG_WT_DIR"` now) accept this case, so the ancestry check, the CI target and
   the record commit plus `git push origin $PR_BRANCH` run in A through `progress_append.sh -C`. **A sibling
   pull request** (`feature/<repo>-issue-N`) keeps `_gate_wt` = the top folder: its reason reads "a sibling
   repository's pull request: this issue's records are in <A>, and a sibling's gate is not read there", and
   its record is posted as a pull-request comment.
2. **Report-only stays; enforcement is not this issue's.** The design says so in terms: "The gate enforces
   by default on workspace pull requests: a gap refuses with exit 1 and no entry. Project and package pull
   requests are report-only: the gap is printed and recorded as a `## Merge (report-only)` entry and the
   merge goes ahead" (`docs/design.md#merge-gate`), and the script's note is "gate enforcement applies to
   workspace PRs only until #265 settles project timelines". Nothing in part 2 settles that. What changes is
   that the record now lands on the right timeline, so a package merge no longer posts a false "would have
   refused" comment.
3. **Cleanup across the repositories** (`merge_pr.sh` Step 4, package branch; code unchanged, behaviour
   pinned by tests). Merged owning pull request with: (a) no sibling work: C removed, A's branch deleted;
   (b) a sibling with unmerged commits and no remote: C removed, the sibling's branch kept and named;
   (c) a sibling with an open pull request: C kept; (d) the owning repository's own checkout (the layer's
   `src/<repo>` that the worktree was made from) on a branch other than the base: `git branch -d` keeps
   the merged branch as "not fully merged" and says so; nothing is force-deleted. The merge runs from the
   session root (run-issue step 11, part 1).
4. **The made-up project name.** In `test_merge_pr_gate.sh` the package fixtures use a real project's short
   name as project name and in the worktree folder name (4 lines: two part 1 added, two it copied from);
   rename to `demo`. Mechanism comments that name it in files this part touches (`merge_pr.sh` and the
   run-issue prefix text) too. The other six suites and two script comments go to the follow-up issue
   drafted below. `test_package_issue_loop.sh` names no project; its sandbox project is `demo`.
5. **End-to-end test** in `test_package_issue_loop.sh`, from the session root with a stubbed `gh`: create
   the worktree with `--layer` and `--package-repos`, `where`, a commit in A, the handoff and `check-exit`
   for an Implementation entry, publish through `gh_create_pr.sh -R`, a review entry and a checkpoint in A's
   timeline, then `merge_pr.sh --pr owner/pkg_a#M` up to its merge call (stubbed to succeed): the gate finds
   the review at the head, the record (if any) is committed in A and nowhere else (workspace `main`, C, B),
   cleanup runs per step 3; a sibling `pkg_b#M` with the same number leaves A's timeline untouched. The base
   step (`--base`, `base=`) is added by the later-merging pull request.
6. **Texts, same pull request.** `run-issue/SKILL.md`: the Scope entry "More than one owning repository"
   says what is supported after part 2 (one owning repository per run, base from the pin or `--base`, the
   gate reads and records in the owning checkout, report-only); step 11's "until the merge gate reads ..."
   sentence is removed; the "publish and merge are GitHub-only" bullet stays. `docs/design.md`: Records
   bullet and Merge gate bullets, change-log row, `merge_pr.sh` line citations refreshed.
   `.agent/knowledge/script_reference.md`: the `merge_pr.sh` row.

### Follow-up issue to draft (not opened; for the owner to allow)

Title: `Rename the real project's short name used as a fixture name in six test suites`

Body: "Several script test suites use a real hosted project's short name as the name of their made-up
project, in project names, folder names and comments (about 170 lines: `test_ros2_colcon.sh` 71,
`test_project_registry.sh` 47, `test_merge_pr.sh` 40, `test_session_root.sh` 6, `test_skill_prefix.sh` 3,
`test_session_start_layer.sh` 1; comments in `skill_prefix.sh` and `user_tier_install.sh`). Workspace
mechanism and tests name no project (ADR-0003; the 'Put each thing at the level it applies to'
principle), so rename the fixtures to a neutral name such as `demo`, mechanically, one suite per commit,
each suite green before and after. No behaviour change. Found while reviewing issue 429 part 1. This
workspace, agent_workspace (https://github.com/rolker/agent_workspace), is optional tooling; the change
touches only its own tests." Signed with the AI signature on opening.

### Same lines as issue 437, and who merges second

Issue 437 adds `--write` to `records_path` / `records_dir` in `_resolve_work_plans_dir.sh`. **Part 2 does
not edit that file**, and in `merge_pr.sh` it leaves the `records_path "$_gate_cand" "$_gate_wt"` call
as it is; it only changes the value `_gate_wt` takes. Shared ground: (1) `progress_append.sh -C "$_gate_wt"`
in `_gate_record` is a write, so 437's rule applies to it, and the owning checkout A is on `feature/issue-N`,
which 437's rule accepts (its step 3 says no package carve-out is needed); the end-to-end test proves it
once both are in; (2) textual overlaps only: `test_package_issue_loop.sh` (437 changes one assertion block;
2a and 2b append cases), `docs/design.md`'s Records bullet and change log, and
`.agent/knowledge/script_reference.md` (437 adds rows; 2a and 2b add rows). **437 merges first** (smaller,
further along); the part 2 pull requests rebase onto it, 2b re-running the end-to-end test. 2a is not free
of 437 either: it edits `test_package_issue_loop.sh` too. Issue 444 changes `run_script_tests.sh`; part 2
adds no suite file and cites no line of it.

### What stays GitHub-bound in part 2, and the exit for each

The goal is `README.md#flexibility`. For each place part 2 touches a forge notion: whether plain git or
the adapter answers, and how the work would continue without GitHub. Where no exit exists today the cell
says "none today" and what one would take. No exit is built here.

| Place | Without GitHub? | Exit |
|---|---|---|
| Base branch value | Yes: adapter pin or `--base` | Not GitHub-bound; the forge's default branch is never read |
| Start point, "is it a branch" | Yes: `git fetch`, `git ls-remote --heads` | Not GitHub-bound |
| Gate record for the owning pull request | Yes: timeline commit and `git push` | Not GitHub-bound; this part moves these records off `gh pr comment` |
| Sibling pull request's record (`gh pr comment`) | No | None today: a sibling has no timeline here; one would take the multi-repository design (a record in each sibling's own checkout), outside this issue |
| Push-refused and no-identity fallbacks (`gh pr comment`) | No | None today: would take a local fallback that prints the record for the owner and leaves it in the scratchpad (small, but a behaviour choice) |
| Duplicate check against the comment store (`_gate_already_recorded`) | No | Same as the row above: goes with the comment fallback |
| Owner/repo of the pull request (`extract_gh_slug`, GitHub remotes only) | Partly: the manifest scan's match (reused in 2b step 1, no second parse) | None today for non-GitHub hosts: would take a forge-neutral repository key (the origin URL) in the scan, `worktree_repos` ownership and `gh_create_pr.sh`'s safety check |
| `**PR**: #M at <sha>` correlation | Partly | `**Branch**: <name> at <sha>` is already an allowed correlation (ADR-0013); a forge with no pull requests uses it |
| Gate condition (b), `## Decision summary` in the pull request | No | None today: would take reading the owner's Checkpoint entry on the timeline instead of a pull-request comment |
| CI wait (`gh api` check runs) | No | None today: would take a local CI run (`make test`) recorded on the timeline |
| Merge (`gh pr merge`) | No | `git merge` of the branch into the base and `git push`, the gate read from the timeline; not coded |
| Publish (`gh_create_pr.sh -R --base`) | No | Push the branch and hand the owner the branch and base; run-issue's Scope names field mode as a separate change |
| Open sibling pull request check at cleanup (`gh pr list`) | Partly | A sibling branch with no commits beyond its start and not on origin has nothing to lose and needs no question to the forge; a branch with work still needs one. Not changed (fails closed; tested) |
| Base cross-check at merge (`baseRefName`) | Uses a field of a call already made | With no pull request there is nothing to cross-check; the push names the base |
| The `gh repo view` check from part 1 | No | Not needed once origin names the repository; none today |

The loop as a whole (publish, review reading, merge) is GitHub-bound. Part 2 adds none and removes one
fallback to a pull-request comment. Rows with "none today" are the input to the owner's discussion.

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
| `.agent/scripts/adapter`, `.agent/scripts/validate_adapter.sh`, both adapters' `adapter.sh`, `docs/decisions/0011-*.md` | `repo_pin` as the 13th required verb; ADR-0011 amended | 2a |
| `.agent/scripts/_pr_base.sh` (new, sourced), `.agent/scripts/dispatch_phase.sh` | `pr_base_for`; `base` subcommand; `base=` in the handoff | 2a |
| `.agent/scripts/worktree_create.sh`, `.agent/scripts/_worktree_helpers.sh` | `--base`; strict start path in `_wt_add_repo`; `base=` header; un-anchored `layer=` reader; `WT_MANIFEST_BASE` | 2a |
| `.agent/scripts/merge_pr.sh` | Base cross-check reason (`baseRefName`) | 2a |
| `.claude/skills/run-issue/SKILL.md` | `--base`, step 1 `base`, publish `--base` | 2a |
| `.agent/scripts/tests/test_adapter.sh`, `test_ros2_colcon.sh`, `test_worktree_create.sh`, `test_package_issue_loop.sh` | Verb, strict path, header and base cases (no new suite file) | 2a |
| `docs/design.md`, `docs/decisions/0012-*.md`, `.agent/knowledge/script_reference.md` | Verb text, start point and header, rows, change log | 2a |
| `.agent/scripts/merge_pr.sh` | Gate reads and records in the owning checkout (`PKG_OWN_REL` from the scan); sibling reason | 2b |
| `.agent/scripts/tests/test_merge_pr_gate.sh` | Flip the package expectation; owning, sibling and cleanup cases (a to d); rename the fixture project to `demo` | 2b |
| `.agent/scripts/tests/test_package_issue_loop.sh` | End-to-end case from creation to the merge call | 2b |
| `.claude/skills/run-issue/SKILL.md`, `docs/design.md`, `.agent/knowledge/script_reference.md` | Scope, step 11, Records and Merge gate text, `merge_pr.sh` row, change log | 2b |

## Serves

Workspace goal `README.md#easy-to-use` ("start an agent in the project's own directory and the
workspace is there": an issue of a package repository is driven from the project's root like any
other). Decision 1 (records in the package repository) also touches `README.md#light-touch-on-projects`,
which the veto list covers. Part 2 also falls under `README.md#flexibility` ("preference should go to open
source and open standards to minimize vendor lock-in. Have an exit strategy for anything that depends on a
vendor's closed product or infrastructure"). Design: `docs/design.md#worktrees` (Records) and
`docs/design.md#review-loop-and-timeline` (pull request 2: `docs/design.md#merge-gate`).

## Design Picture

Changes the Records bullet of `docs/design.md#worktrees`: a package issue has a timeline, in the owning
checkout, with its directory chosen by `dispatch_phase.sh`. Part 2 changes `docs/design.md#merge-gate`
(the package gate reads that timeline and stays report-only) and `docs/design.md#worktrees` again (a
package worktree records its base branch; the branch starts there).
`docs/design.md#sessions-and-roots` needs no change: the session stays at the root, the work happens
under it, and the root checks are read once there.

## Principles Self-Check

The sixteen headings of `docs/principles.md`:

| Principle | Consideration |
|---|---|
| Leave a trail; start limits strict | Package gate records go to the owning timeline; a run with no resolvable base refuses |
| Enforce what matters, as simply as possible | The start point is enforced in code (fetch, no tracking, refuse when absent or unknown, even with `--allow-unverified-branch`); the merge cross-check reports a wrong target; the gate stays report-only as the design says |
| Keep one current design | The base texts (design, ADR-0011, ADR-0012, script rows) are in 2a with the code; gate text in 2b |
| A change includes its consequences | Consequences table; `script_reference.md`, design and change log in the same pull requests |
| Only what's needed | No stopgap for a missing verb, no qualified identity in records; `--base` only as an override |
| Small steps; step back when they stop converging | 2a and 2b built in parallel; the verb can be cut out of 2a if review finds it heavy |
| Test what breaks | Both start-path refusals, unpushed local commits on the base, the `layer=` reader after `base=`, cleanup cases (a) to (d), the end-to-end test |
| Put each thing at the level it applies to | `_pr_base.sh` and `repo_pin` callers name no type; the type answers in its adapter; the repository name comes from the adapter's owning entry |
| Use the main tool fully; keep the work tool-neutral | Goal `README.md#flexibility`: the table gives the exit for every GitHub-bound row; no `gh` call added; none built |
| Ask about what matters, and show how much | Eleven decisions listed with undo cost; the GitHub rows marked "none today" are for the owner's discussion |
| Verify before claiming | The `layer=` reader and the cleanup rule checked against the code; the claims here trace to files read |
| Look for prior art before building | The parent-branch path was read and rejected for the base (local copy, default-branch fallback, tracking); `wt_fetch_named_branch` and `wt_add_new_branch` are reused |
| Leave in a project only what it chose to carry | `base=` lives in the workspace manifest; records follow part 1's decision 1 |
| Name the rule before bending it | The tests-name-no-project rule is named; the partial rename is put to veto 8 |
| Give the user what they need now | The owner types nothing for the Rolling-like case once the pin answers; `--base` is only an override |
| Know whether it works | The cross-check at merge and the end-to-end test show the base mechanism worked |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0003 | Yes | Synthetic sandbox; no project named in scripts or tests |
| 0011 / 0012 | Yes | Reads `.worktree-repos` and the adapter's branch rule; no branching on project type. Part 2: `repo_pin` becomes the 13th required verb and ADR-0011 is amended in 2a (as ADR-0012 amended it to 12); the manifest header gains `base=` and ADR-0012's manifest paragraph says so |
| 0013 | Yes | Unchanged: `**PR**: #M` stays bare, meaning the timeline's own repository |
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
| `repo_pin` is a required verb | `adapter` header and usage, `validate_adapter.sh`, both adapters, ADR-0011, design verb text, script rows | Yes, 2a |
| The manifest header gains `base=` | The `layer=` reader, ADR-0012 manifest paragraph, design Worktrees | Yes, 2a |

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

5. **The base comes from the adapter: `repo_pin` is added in 2a as a required verb**, with ADR-0011
   amended; `--base` is an override only; a pinned tag, commit or unknown refuses and names it. Issue 436
   planned this verb as its own pull request (c); it moves here and the host records that on issue 436.
   [Moderate: removing a required verb needs another ADR amendment.]
6. **The base also decides the branch's start point**, by its own strict path (fetch origin's base,
   `--no-track`, refuse when absent or unknown even with `--allow-unverified-branch`, never the local copy),
   owning entry only, and is recorded in the manifest header as `base=`. [Moderate: a header field and a
   `worktree_create.sh` flag; the `layer=` reader is un-anchored first.]
7. **No qualified pull-request identity in records**: a bare `#M` means the timeline's own repository and
   ADR-0013 stays as it is. [None.]
8. **Fixture rename scope**: `demo` in `test_merge_pr_gate.sh` and mechanism text in files part 2 touches
   only; the other six suites and two comments go to a follow-up issue, drafted above for you to allow, not
   opened. [Low.]
9. **Part 2 is two pull requests built in parallel (2a, 2b)**; 437 merges before both, and the verb can be
   cut out of 2a if review finds it heavy. [Low.]
10. **Cleanup behaviour is pinned by tests, not changed**, including a package checkout not on the base. [None.]
11. **Draft pull requests at worktree creation stay unsupported for a package worktree**; the message
    points at publish. [None.]

## Open Questions

None. The "run removes only what it made" rule is found (it concerns undoing a failed creation) and the
follow-up issue text is drafted above for the owner to allow. The rows marked "none today" in the
GitHub-bound table are the owner's discussion, not a question about this plan.

## Estimated Scope

Three pull requests in all. PR 1 (part 1) is merged (pull request 445; about 17 files). Part 2 is 2a
(about 16 files, 600 lines: the verb and ADR, the base resolver, the strict start path, the header, the
cross-check, run-issue, tests, base texts) and 2b (about 8 files, 300 lines: gate, cleanup tests,
end-to-end test, Scope and gate texts). They are built in parallel; both merge after issue 437.

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
