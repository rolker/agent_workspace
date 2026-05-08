Reading prompt from stdin...
OpenAI Codex v0.121.0 (research preview)
--------
workdir: /home/roland/daddy_camp/worktrees/workspace/issue-workspace-173
model: gpt-5.4
provider: openai
approval: never
sandbox: workspace-write [workdir, /tmp, $TMPDIR, /home/roland/.codex/memories]
reasoning effort: medium
reasoning summaries: none
session id: 019e05c5-7327-7b31-8b8f-bae40c935c57
--------
user
# Adversarial Code Review

## Your Role

You are an independent adversarial reviewer. Your job is to find issues that
other reviewers missed: edge cases, security implications, incorrect
assumptions, subtle bugs, and logic errors.

Review the diff below with fresh eyes. Do not assume previous reviewers caught
everything. Focus on:

- **Edge cases**: What inputs or states could break this code?
- **Security**: Are there injection, auth, or data exposure risks?
- **Assumptions**: What does the code assume that might not hold?
- **Subtle bugs**: Off-by-one, race conditions, resource leaks, null/undefined
- **Logic errors**: Does the code actually do what the PR title claims?

## PR Under Review

**Title**: fix(#173): make --type optional + collision-safe PR lookup
**URL**: https://github.com/rolker/agent_workspace/pull/177
**PR Number**: #177

## Diff

```diff
diff --git a/.agent/scripts/merge_pr.sh b/.agent/scripts/merge_pr.sh
index e374d76..9e4cc52 100755
--- a/.agent/scripts/merge_pr.sh
+++ b/.agent/scripts/merge_pr.sh
@@ -85,27 +85,136 @@ if [[ -z "$ROOT_DIR" ]]; then
     exit 1
 fi
 
-# --- Resolve target repo for gh commands ---
-# For project PRs, gh must target the project repo, not the workspace repo.
-GH_REPO_ARGS=()
-resolve_gh_repo_args() {
-    GH_REPO_ARGS=()
-    if [[ "$WORKTREE_TYPE" == "project" ]]; then
-        local project_remote
-        project_remote=$(git -C "$ROOT_DIR/project" remote get-url origin 2>/dev/null || echo "")
-        if [[ -n "$project_remote" ]]; then
-            GH_REPO_ARGS=("-R" "$project_remote")
+# --- Helper: find a worktree for a given branch ---
+# Issue #173: previous logic globbed `worktrees/project/issue-project-<N>`,
+# which never matched the actual multi-project layout
+# (`worktrees/project/<repo>/issue-<repo>-<N>`). Asking git for the
+# authoritative location side-steps that whole class of path-encoding bug
+# AND naturally covers legacy `.workspace-worktrees/` paths — anything git
+# tracks as a worktree shows up here regardless of where it lives on disk.
+find_worktree_for_branch() {
+    local repo="$1"
+    local branch="$2"
+    git -C "$repo" worktree list --porcelain 2>/dev/null \
+        | awk -v target="refs/heads/$branch" '
+            /^worktree / { wt = substr($0, 10); next }
+            /^branch /   { if ($2 == target) { print wt; exit } }
+        '
+}
+
+# --- Discover the workspace and (optional) project remotes ---
+# Workspace remote always exists (we just resolved ROOT_DIR via git).
+# Project remote is only resolved when project/ is configured. Empty
+# project remote with project/ present is a misconfiguration — surface
+# it now rather than letting it manifest as a silent "PR not found"
+# (issue #173 root cause).
+WS_REMOTE=$(git -C "$ROOT_DIR" remote get-url origin 2>/dev/null || echo "")
+PJ_REMOTE=""
+if [[ -e "$ROOT_DIR/project/.git" ]]; then
+    PJ_REMOTE=$(git -C "$ROOT_DIR/project" remote get-url origin 2>/dev/null || echo "")
+    if [[ -z "$PJ_REMOTE" ]]; then
+        echo "ERROR: $ROOT_DIR/project has no 'origin' remote configured." >&2
+        echo "  Cannot resolve project PRs. Configure the remote, or pass" >&2
+        echo "  --type workspace if this is intentionally workspace-only." >&2
+        exit 1
+    fi
+fi
+
+# --- Resolve which repo owns the PR (collision-safe) ---
+# PR numbers are repo-local: workspace #84 ≠ project #84. Trying repos
+# in sequence and taking the first hit (the original design) silently
+# picks the wrong one when both repos have an open PR with the same
+# number. Query both, filter to OPEN, then:
+#   0 hits → error
+#   1 hit  → use it (and implicitly determine WORKTREE_TYPE if --type
+#            was not supplied)
+#   2 hits → error and require --type to disambiguate
+# When --type IS supplied, query only the matching repo.
+
+# Query a single repo. On OPEN PR, populates QUERY_BRANCH/QUERY_TITLE
+# and returns 0. On not-found OR not-OPEN, returns 1 silently. On other
+# errors (auth, network), prints the error and returns 2.
+QUERY_BRANCH=""
+QUERY_TITLE=""
+query_pr() {
+    local remote="$1"
+    local out err rc=0
+    local err_file
+    err_file=$(mktemp)
+    out=$(gh pr view "$PR_NUMBER" -R "$remote" \
+            --json state,headRefName,title 2>"$err_file") || rc=$?
+    err=$(<"$err_file")
+    rm -f "$err_file"
+
+    if [[ $rc -eq 0 ]] && [[ -n "$out" ]]; then
+        local state
+        state=$(echo "$out" | jq -r '.state // empty')
+        if [[ "$state" == "OPEN" ]]; then
+            QUERY_BRANCH=$(echo "$out" | jq -r '.headRefName // empty')
+            QUERY_TITLE=$(echo "$out" | jq -r '.title // empty')
+            return 0
         fi
+        return 1   # exists but not OPEN — irrelevant for merge
     fi
+
+    # Distinguish "PR not found" from auth/network errors. Silently
+    # picking the only authed repo would be the same class of bug
+    # we're fixing — propagate other errors and require --type.
+    case "$err" in
+        *"Could not resolve to"*|*"GraphQL: Could not"*|*"no pull"*|*"404"*)
+            return 1 ;;
+        *)
+            echo "ERROR: gh failed against $remote:" >&2
+            echo "  $err" >&2
+            return 2 ;;
+    esac
 }
 
-# --- Extract issue number from PR branch ---
-# Note: GH_REPO_ARGS may be empty at this point (type not yet known).
-# We try without -R first; if --type project was specified, we resolve after.
-resolve_gh_repo_args
-PR_BRANCH=$(gh pr view "$PR_NUMBER" "${GH_REPO_ARGS[@]}" --json headRefName --jq '.headRefName' 2>/dev/null)
-if [[ -z "$PR_BRANCH" ]]; then
-    echo "ERROR: Could not fetch PR #${PR_NUMBER}" >&2
+WS_HIT=false; WS_BRANCH=""; WS_TITLE=""
+PJ_HIT=false; PJ_BRANCH=""; PJ_TITLE=""
+
+if [[ -z "$WORKTREE_TYPE" || "$WORKTREE_TYPE" == "workspace" ]] && [[ -n "$WS_REMOTE" ]]; then
+    if query_pr "$WS_REMOTE"; then
+        WS_HIT=true
+        WS_BRANCH="$QUERY_BRANCH"
+        WS_TITLE="$QUERY_TITLE"
+    elif [[ $? -eq 2 ]]; then
+        echo "  Pass --type to bypass auto-detection." >&2
+        exit 1
+    fi
+fi
+
+if [[ -z "$WORKTREE_TYPE" || "$WORKTREE_TYPE" == "project" ]] && [[ -n "$PJ_REMOTE" ]]; then
+    if query_pr "$PJ_REMOTE"; then
+        PJ_HIT=true
+        PJ_BRANCH="$QUERY_BRANCH"
+        PJ_TITLE="$QUERY_TITLE"
+    elif [[ $? -eq 2 ]]; then
+        echo "  Pass --type to bypass auto-detection." >&2
+        exit 1
+    fi
+fi
+
+GH_REPO_ARGS=()
+if $WS_HIT && $PJ_HIT; then
+    echo "ERROR: PR #${PR_NUMBER} is open in BOTH repos:" >&2
+    echo "  workspace: $WS_TITLE" >&2
+    echo "  project:   $PJ_TITLE" >&2
+    echo "  Pass --type workspace or --type project to disambiguate." >&2
+    exit 2
+elif $WS_HIT; then
+    WORKTREE_TYPE="workspace"
+    PR_BRANCH="$WS_BRANCH"
+elif $PJ_HIT; then
+    WORKTREE_TYPE="project"
+    PR_BRANCH="$PJ_BRANCH"
+    GH_REPO_ARGS=("-R" "$PJ_REMOTE")
+else
+    if [[ -n "$WORKTREE_TYPE" ]]; then
+        echo "ERROR: PR #${PR_NUMBER} not open in $WORKTREE_TYPE repo." >&2
+    else
+        echo "ERROR: PR #${PR_NUMBER} not open in either workspace or project." >&2
+    fi
     exit 1
 fi
 
@@ -117,31 +226,6 @@ if [[ -z "$ISSUE_NUM" ]]; then
     exit 1
 fi
 
-# --- Auto-detect worktree type if not specified ---
-if [[ -z "$WORKTREE_TYPE" ]]; then
-    WS_PATH="$ROOT_DIR/worktrees/workspace/issue-workspace-${ISSUE_NUM}"
-    PJ_PATH="$ROOT_DIR/worktrees/project/issue-project-${ISSUE_NUM}"
-    # Also check legacy path
-    WS_LEGACY="$ROOT_DIR/.workspace-worktrees/issue-workspace-${ISSUE_NUM}"
-
-    WS_EXISTS=false
-    PJ_EXISTS=false
-    [[ -d "$WS_PATH" || -d "$WS_LEGACY" ]] && WS_EXISTS=true
-    [[ -d "$PJ_PATH" ]] && PJ_EXISTS=true
-
-    if $WS_EXISTS && ! $PJ_EXISTS; then
-        WORKTREE_TYPE="workspace"
-    elif $PJ_EXISTS && ! $WS_EXISTS; then
-        WORKTREE_TYPE="project"
-    elif $WS_EXISTS && $PJ_EXISTS; then
-        echo "ERROR: Both workspace and project worktrees exist for issue #${ISSUE_NUM}" >&2
-        echo "  Specify --type workspace or --type project" >&2
-        exit 2
-    else
-        echo "WARNING: No worktree found for issue #${ISSUE_NUM} — will merge and sync only" >&2
-    fi
-fi
-
 echo "========================================"
 echo "Merging PR #${PR_NUMBER} (issue #${ISSUE_NUM})"
 echo "========================================"
@@ -150,21 +234,21 @@ echo "========================================"
 if [[ "$NO_ROADMAP_UPDATE" == false ]]; then
     echo "  Checking roadmap for #${ISSUE_NUM}..."
 
-    # Resolve the worktree that has the feature branch checked out.
-    # The roadmap must be updated there (not in ROOT_DIR, which is on main).
-    _WT_ROOT=""
-    if [[ "$WORKTREE_TYPE" == "workspace" ]]; then
-        _WT_PATH="$ROOT_DIR/worktrees/workspace/issue-workspace-${ISSUE_NUM}"
-        [[ -d "$_WT_PATH" ]] && _WT_ROOT="$_WT_PATH"
-    elif [[ "$WORKTREE_TYPE" == "project" ]]; then
-        _WT_PATH="$ROOT_DIR/worktrees/project/issue-project-${ISSUE_NUM}"
-        [[ -d "$_WT_PATH" ]] && _WT_ROOT="$_WT_PATH"
-    fi
+    # Resolve the worktree that has the feature branch checked out via
+    # find_worktree_for_branch (issue #173) — git is the authority on
+    # where worktrees live, so we don't have to re-encode path
+    # conventions here. For project worktrees, list against the project
+    # repo since project worktrees are tracked there.
+    _WT_REPO="$ROOT_DIR"
+    [[ "$WORKTREE_TYPE" == "project" ]] && _WT_REPO="$ROOT_DIR/project"
+    _WT_ROOT=$(find_worktree_for_branch "$_WT_REPO" "$PR_BRANCH")
 
     if [[ -z "$_WT_ROOT" ]]; then
         echo "  ⚠️  No worktree found for issue #${ISSUE_NUM} — skipping roadmap update"
     else
-        # Verify the worktree is on the expected feature branch
+        # Belt-and-braces: confirm git's worktree-list output really is on
+        # the expected branch (handles a detached-HEAD edge case where the
+        # `branch ` line was present but transient).
         _WT_BRANCH=$(git -C "$_WT_ROOT" branch --show-current 2>/dev/null || echo "")
         if [[ "$_WT_BRANCH" != "$PR_BRANCH" ]]; then
             echo "  ⚠️  Worktree is on '${_WT_BRANCH:-unknown}', expected '$PR_BRANCH' — skipping roadmap update"
@@ -212,8 +296,9 @@ else
 fi
 
 # --- Step 2: Merge ---
+# GH_REPO_ARGS was set during PR resolution above (-R <project-remote> for
+# project PRs, empty for workspace PRs). Don't re-resolve.
 echo "  Merging PR..."
-resolve_gh_repo_args
 if ! gh pr merge "$PR_NUMBER" "${GH_REPO_ARGS[@]}" --merge; then
     echo "ERROR: Merge failed for PR #${PR_NUMBER}" >&2
     exit 1
diff --git a/.agent/work-plans/issue-173/plan.md b/.agent/work-plans/issue-173/plan.md
new file mode 100644
index 0000000..88ac31a
--- /dev/null
+++ b/.agent/work-plans/issue-173/plan.md
@@ -0,0 +1,162 @@
+# Plan: merge_pr.sh — project PRs fail silently when `--type` is omitted
+
+## Issue
+
+https://github.com/rolker/agent_workspace/issues/173
+
+## Context
+
+`make merge-pr PR=<N>` and `merge_pr.sh --pr <N>` (without `--type`) silently
+exit 1 on every project PR. The issue body identifies two bugs in
+`.agent/scripts/merge_pr.sh`:
+
+1. **Auto-detect runs after the lookup that needs it.** Lines 105–110 call
+   `gh pr view` against the workspace remote (because `WORKTREE_TYPE` is
+   still empty, so `resolve_gh_repo_args` returns no `-R`). For project
+   PRs this returns empty, the script bails with `ERROR: Could not fetch
+   PR #<N>` and exits 1 — *before* line 121's auto-detect block ever
+   runs.
+
+2. **Path globs don't match the actual worktree layout.** Lines 122–123
+   (and 157, 161 in the roadmap-update path) check
+   `worktrees/project/issue-project-<N>`, but `worktree_create.sh:15`
+   documents the layout as `worktrees/project/<repo>/issue-<slug>-<N>`
+   (e.g. `worktrees/project/daddy_camp/issue-daddy_camp-66`). The
+   project path will never resolve, so even if Bug 1 were fixed,
+   auto-detect would still silently fall through to the "no worktree
+   found" branch.
+
+3. **Bonus:** `make merge-pr` doesn't forward extra args, so even
+   knowing the workaround, you can't `make merge-pr PR=<N> --type project`.
+
+## Approach
+
+Fix both root causes; make `--type` optional in practice. Order matters:
+Bug 1's fix needs the path glob from Bug 2 to be correct.
+
+1. **Replace path-based auto-detect with `git worktree list` enumeration.**
+   For each repo (workspace at `$ROOT_DIR`, project at `$ROOT_DIR/project`
+   if present), parse `git worktree list --porcelain` and find the
+   worktree whose `branch` line matches `refs/heads/feature/issue-<N>`.
+   Sidesteps both the multi-project path layout *and* any future path
+   convention drift — git is the authority on where worktrees live.
+   Also covers legacy `.workspace-worktrees/` paths naturally: any
+   directory `git` knows about as a worktree shows up here regardless
+   of where it sits on disk, so the existing `WS_LEGACY` check at
+   line 125 becomes unnecessary rather than dropped.
+
+2. **Try both repos for the PR lookup, with collision-safe disambiguation.**
+   Replace lines 105–110 with a query loop that calls
+   `gh pr view -R <remote> --json state,headRefName,title` against
+   *both* the workspace remote and the project remote (if
+   `$ROOT_DIR/project` exists), filtering to `state == "OPEN"`. PR
+   numbers are repo-local — workspace #84 ≠ project #84 — so "first
+   match wins" would silently pick the wrong PR when both repos have
+   an open PR with the same number. Behavior:
+   - **0 open hits** → error "PR #<N> not open in either workspace or
+     project."
+   - **exactly 1 hit** → use that repo; this implicitly determines
+     `WORKTREE_TYPE` (project if matched against project remote,
+     workspace otherwise) when `--type` was not supplied.
+   - **2 hits** → error with both titles and require `--type` to
+     disambiguate. (Already-merged/closed PRs are filtered out, so
+     stale numbers don't pollute the collision check.)
+   When `--type` *is* supplied, skip the disambiguation: query only
+   the matching repo and short-circuit on its result.
+
+   **Edge cases the loop must surface explicitly (not silently skip):**
+   - `$ROOT_DIR/project/.git` exists but `git -C project remote get-url origin`
+     returns empty → error "Project repo has no `origin` remote
+     configured; cannot resolve project PRs." (The current
+     `resolve_gh_repo_args` silently produces no `-R` here, which is
+     exactly how Bug 1 manifested — must not regress.)
+   - `gh` returns a non-empty error other than not-found (typical:
+     "HTTP 401: Bad credentials" when unauthed against one repo but
+     authed against the other) → propagate the error from that repo
+     verbatim, treat the lookup as inconclusive, and require `--type`
+     rather than falling back to the working repo. Silently picking
+     the only authed match would be the same class of bug we're fixing.
+
+3. **Use the worktree-list helper everywhere a path is needed.** Lines
+   157–161 currently rebuild paths by string concatenation for the
+   roadmap-update step. Replace with the same git-worktree-list lookup
+   so the path is whatever git actually has, not what the script
+   assumes.
+
+4. **Make `make merge-pr` forward extra args via `MERGE_PR_ARGS`.** Add a
+   passthrough variable to the Makefile rule. Resolved in favor of
+   `MERGE_PR_ARGS` over argument-style (`make merge-pr -- --type project`)
+   for consistency with how every other Make passthrough in this workspace
+   is exposed. Mostly defensive — once auto-detect works, `--type` should
+   rarely be needed; but `--no-roadmap-update` and the both-worktrees-exist
+   case still want an escape hatch.
+
+   Literal Makefile edit (one line, line 122):
+
+   ```diff
+   -	@$(MAIN_ROOT)/.agent/scripts/merge_pr.sh --pr $(PR)
+   +	@$(MAIN_ROOT)/.agent/scripts/merge_pr.sh --pr $(PR) $(MERGE_PR_ARGS)
+   ```
+
+   `$(MERGE_PR_ARGS)` defaults to empty (no `?=` initialization needed —
+   undefined Make variables expand to nothing). Invocation example:
+   `make merge-pr PR=84 MERGE_PR_ARGS="--type project"`.
+
+5. **Smoke-test manually** — committed path. The workspace has no shell-test
+   scaffold (no bats, no shunit2), and adding one for a one-off bug fix is
+   exactly the kind of speculative tooling "Only what's needed" warns
+   against. The PR description will document a deterministic reproduction:
+   (a) confirm the original failure on `main` (`make merge-pr PR=<some
+   project PR>` → silent exit 1), (b) confirm the fix on the branch (same
+   command → succeeds, OR errors with a clear diagnostic when both repos
+   have an open PR with the same number). If shell tests become useful
+   beyond this fix, that's a separate follow-up issue, not in-scope here.
+
+## Files to Change
+
+| File | Change |
+|------|--------|
+| `.agent/scripts/merge_pr.sh` | Replace `resolve_gh_repo_args` + lines 102–143 with: (a) repo-trying loop that determines target repo and `PR_BRANCH` together, (b) git-worktree-list-based worktree detection that also yields the path. Replace lines 156–162's path-building with the same helper. |
+| `Makefile` | Add `$(MERGE_PR_ARGS)` passthrough on the `merge-pr:` rule (line 122) — see step 4 for the literal diff. |
+| `.agent/work-plans/issue-173/progress.md` | Plan + implementation steps as work proceeds. |
+
+No changes to AGENTS.md / docs needed: documented usage today is `make
+merge-pr PR=<N>` with no type flag. The fix makes that command actually
+work as documented.
+
+## Principles Self-Check
+
+| Principle | Consideration |
+|---|---|
+| Test what breaks | Failure mode is silent and bites every project PR merge — exactly the kind of "concrete pain" justifying the fix. The bug was filed *because* I tripped over it during a real merge. |
+| A change includes its consequences | The script's external interface stays the same (`--type` becomes optional but still respected); no caller changes are needed. AGENTS.md script-reference table already lists `merge_pr.sh`; no entry update required. |
+| Only what's needed | Resist the urge to refactor the whole script. Fix only the two bugs and the Makefile passthrough; leave the rest of the merge → cleanup → sync flow untouched. |
+| Capture decisions, not just implementations | The choice of `git worktree list --porcelain` over path globbing is the load-bearing design decision — note it in a code comment so the next agent who edits this script doesn't reintroduce path assumptions. |
+| Improve incrementally | Single PR, small diff (~30–50 LOC of changes plus shell helper). |
+
+## ADR Compliance
+
+| ADR | Triggered | How addressed |
+|---|---|---|
+| 0001 — ADRs | No | Bug fix; no new architectural decision worth recording. |
+| 0007 — Retain Make with dependency tracking | Watch | Adding `MERGE_PR_ARGS` is a passthrough variable, not a new target or dependency edge. No stamp-file impact. |
+| 0010 — git-bug optional | No | Script already sources `_issue_helpers.sh`; this fix doesn't touch the issue-lookup path. |
+| Others (0002–0006, 0008–0009) | No | Worktree-isolation, AGENTS.md, enforcement layering, Python — none triggered. |
+
+## Consequences
+
+| If we change... | Also update... | Included in plan? |
+|---|---|---|
+| `merge_pr.sh` interface (here: behavior, not signature) | Documentation that references it (`AGENTS.md` "Script Reference") | **No update needed** — the doc says "Merge PR (auto-updates roadmap), remove worktree, delete branch, sync main" without mentioning `--type`. The fix makes that line accurate. |
+| Makefile rule | `AGENTS.md` Build & Test section if user-facing | **No update needed** — `MERGE_PR_ARGS` is a power-user escape hatch, not part of the documented happy path. |
+| Auto-detection helper | Other scripts that detect worktrees by path | **None found** — `worktree_remove.sh` and `worktree_list.sh` use their own helpers; this fix only changes `merge_pr.sh`. |
+
+## Open Questions
+
+None — `MERGE_PR_ARGS` resolved in step 4; testing approach committed in step 5.
+
+## Estimated Scope
+
+Single PR, single commit (or two: shell change + Makefile change). ~30–50
+lines of script change, 2 lines of Makefile change. Manual smoke test
+required since no automated test scaffold exists for `merge_pr.sh`.
diff --git a/.agent/work-plans/issue-173/progress.md b/.agent/work-plans/issue-173/progress.md
new file mode 100644
index 0000000..16723b3
--- /dev/null
+++ b/.agent/work-plans/issue-173/progress.md
@@ -0,0 +1,70 @@
+---
+issue: 173
+---
+
+# Issue #173 — merge_pr.sh: project PRs fail silently when --type is omitted
+
+## Plan
+**Status**: complete
+**When**: 2026-05-07 21:30
+**By**: Claude Code Agent (claude-opus-4-7)
+
+Plan file: `.agent/work-plans/issue-173/plan.md`.
+
+Replace path-based auto-detect with `git worktree list --porcelain`
+enumeration; try both workspace and project remotes for the PR lookup so
+type can be determined from the first repo that returns a hit; add
+`MERGE_PR_ARGS` passthrough on the Makefile rule.
+
+## Plan Review
+**Status**: complete
+**When**: 2026-05-07 22:00
+**By**: Independent reviewer (general-purpose subagent)
+**Verdict**: changes-requested (minor)
+
+Findings 1, 2, 4, 5 applied to the plan; finding 3 (test scaffold)
+declined per "Only what's needed" — manual smoke test committed in
+the plan with deterministic reproduction documented in PR description.
+
+## Implementation
+**Status**: complete
+**When**: 2026-05-07 22:30
+**By**: Claude Code Agent (claude-opus-4-7)
+
+- Added `find_worktree_for_branch` helper near top of script — wraps
+  `git worktree list --porcelain` so paths come from git rather than
+  string concatenation.
+- Replaced lines 88–143 (resolve_gh_repo_args + initial gh pr view +
+  old auto-detect) with: workspace/project remote discovery (with
+  explicit "missing project remote" error), `query_pr` helper that
+  distinguishes not-found from auth/network errors, two-repo collision-
+  safe lookup with 0/1/2-hit semantics.
+- Replaced lines 156–162 path-building in roadmap-update step with the
+  same `find_worktree_for_branch` helper.
+- Removed redundant `resolve_gh_repo_args` call before `gh pr merge`
+  (GH_REPO_ARGS now set during PR resolution).
+- Added `$(MERGE_PR_ARGS)` passthrough on Makefile `merge-pr:` rule.
+- Diff size: +141/-56 in merge_pr.sh, +1/-1 in Makefile.
+
+### Smoke tests (pre-PR)
+
+- [x] `bash -n` — syntax clean.
+- [x] `shellcheck --severity=warning` — no new findings; three pre-
+      existing SC2015 infos in untouched lines remain.
+- [x] Helper sanity check — `find_worktree_for_branch` correctly
+      finds workspace worktrees, project worktrees in multi-project
+      layout (`worktrees/project/<repo>/...`), and returns empty for
+      non-existent branches and wrong-repo queries.
+- [x] **End-to-end auto-detect verified**: `merge_pr.sh --pr 72` (open
+      project PR, no `--type`) resolved to project repo, extracted
+      issue #71, ran roadmap update, and reached the merge step where
+      gh correctly refused due to unrelated merge conflicts on #72.
+      **This is the bug being fixed** — pre-fix this exited silently
+      with `Error 1`.
+- [x] Closed-PR error path: `merge_pr.sh --pr 84` errors cleanly with
+      "PR #84 not open in either workspace or project."
+- [x] Type-aware not-found: `merge_pr.sh --pr 99999 --type project`
+      errors with "PR #99999 not open in project repo."
+- [x] Workspace PR auto-detect: `merge_pr.sh --pr 177` (own draft PR)
+      correctly resolved to workspace; gh refused merge of draft as
+      expected.
diff --git a/Makefile b/Makefile
index 6719322..d5f8c12 100644
--- a/Makefile
+++ b/Makefile
@@ -118,8 +118,8 @@ revert-feature:
 	@$(MAIN_ROOT)/.agent/scripts/revert_feature.sh --issue $(ISSUE)
 
 merge-pr:
-	@if [ -z "$(PR)" ]; then echo "Usage: make merge-pr PR=<N>"; exit 1; fi
-	@$(MAIN_ROOT)/.agent/scripts/merge_pr.sh --pr $(PR)
+	@if [ -z "$(PR)" ]; then echo "Usage: make merge-pr PR=<N> [MERGE_PR_ARGS=...]"; exit 1; fi
+	@$(MAIN_ROOT)/.agent/scripts/merge_pr.sh --pr $(PR) $(MERGE_PR_ARGS)
 
 generate-skills:
 	@$(MAIN_ROOT)/.agent/scripts/generate_make_skills.sh
```

## Output Format

Write your findings to this exact format so they can be parsed:

### Findings

| # | Severity | File | Line | Finding |
|---|----------|------|------|---------|
| 1 | must-fix / suggestion | `path/to/file` | line number | Description of the issue |

If you find no issues, write:

### Findings

No issues found.

### Summary

Write a 1-3 sentence overall assessment after the findings table.

codex
Reviewing the diff against the surrounding script now. I’m checking the PR-resolution logic, worktree lookup behavior, and merge-path assumptions for cases where the new auto-detection can still select the wrong repo or fail non-obviously.
exec
/bin/bash -lc "nl -ba .agent/scripts/merge_pr.sh | sed -n '1,360p'" in /home/roland/daddy_camp/worktrees/workspace/issue-workspace-173
 succeeded in 0ms:
     1	#!/bin/bash
     2	# .agent/scripts/merge_pr.sh
     3	# Merge a PR, remove its worktree, delete the branch, and sync main.
     4	#
     5	# Usage:
     6	#   .agent/scripts/merge_pr.sh --pr <N> [--type workspace|project] [--no-roadmap-update]
     7	#
     8	# If --type is omitted, the script auto-detects by checking which worktree
     9	# exists for the issue. If neither or both exist, it asks.
    10	#
    11	# Limitations:
    12	#   - Only works for issue-based branches (feature/issue-<N> pattern)
    13	#   - Skill worktree branches are not supported
    14	#   - If run from inside the worktree being removed, your shell's CWD
    15	#     will be invalid after the script completes — cd to the workspace root
    16	#
    17	# Steps:
    18	#   1. Roadmap update (commit + push to feature branch before merge)
    19	#   2. Merge the PR (--merge strategy)
    20	#   3. Remove the worktree (cd to root first; fails safely if uncommitted changes)
    21	#   4. Delete local and remote branches
    22	#   5. Pull main to sync (workspace and project repos)
    23	#
    24	# Exit codes:
    25	#   0 — success
    26	#   1 — merge failed or dependency missing
    27	#   2 — invalid arguments
    28	
    29	set -eo pipefail
    30	
    31	SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    32	
    33	# shellcheck source=_issue_helpers.sh
    34	source "$SCRIPT_DIR/_issue_helpers.sh"
    35	
    36	PR_NUMBER=""
    37	WORKTREE_TYPE=""
    38	NO_ROADMAP_UPDATE=false
    39	
    40	while [[ $# -gt 0 ]]; do
    41	    case "$1" in
    42	        --pr)
    43	            [[ $# -lt 2 ]] && { echo "ERROR: Missing value for --pr" >&2; exit 2; }
    44	            PR_NUMBER="$2"; shift 2 ;;
    45	        --type)
    46	            [[ $# -lt 2 ]] && { echo "ERROR: Missing value for --type" >&2; exit 2; }
    47	            WORKTREE_TYPE="$2"; shift 2 ;;
    48	        --no-roadmap-update)
    49	            NO_ROADMAP_UPDATE=true; shift ;;
    50	        *)
    51	            echo "ERROR: Unknown argument: $1" >&2
    52	            echo "Usage: $0 --pr <N> [--type workspace|project] [--no-roadmap-update]" >&2
    53	            exit 2 ;;
    54	    esac
    55	done
    56	
    57	if [[ -z "$PR_NUMBER" ]]; then
    58	    echo "ERROR: --pr <N> is required" >&2
    59	    echo "Usage: $0 --pr <N> [--type workspace|project] [--no-roadmap-update]" >&2
    60	    exit 2
    61	fi
    62	
    63	if [[ -n "$WORKTREE_TYPE" ]] && [[ "$WORKTREE_TYPE" != "workspace" && "$WORKTREE_TYPE" != "project" ]]; then
    64	    echo "ERROR: --type must be 'workspace' or 'project'" >&2
    65	    exit 2
    66	fi
    67	
    68	# --- Resolve workspace root (main tree) ---
    69	# Use `git worktree list --porcelain` instead of $SCRIPT_DIR/../.. so the
    70	# resolution is correct when the script is invoked from inside a
    71	# worktree (e.g. `make merge-pr` from a feature worktree). With the
    72	# relative-path approach, ROOT_DIR resolved to the worktree root, not
    73	# the main tree, so downstream worktree detection and cleanup silently
    74	# skipped. See issue #146.
    75	#
    76	# git worktree list always prints the main worktree first, in absolute
    77	# form, regardless of invocation cwd.
    78	# `|| true` so invocation outside any repo (git fails, pipefail would
    79	# otherwise trip set -e) falls through to the explicit empty-string
    80	# check below with a clearer error.
    81	ROOT_DIR=$({ git -C "$SCRIPT_DIR" worktree list --porcelain 2>/dev/null \
    82	    | head -n1 | sed 's/^worktree //'; } || true)
    83	if [[ -z "$ROOT_DIR" ]]; then
    84	    echo "ERROR: merge_pr.sh must run from within a git repository" >&2
    85	    exit 1
    86	fi
    87	
    88	# --- Helper: find a worktree for a given branch ---
    89	# Issue #173: previous logic globbed `worktrees/project/issue-project-<N>`,
    90	# which never matched the actual multi-project layout
    91	# (`worktrees/project/<repo>/issue-<repo>-<N>`). Asking git for the
    92	# authoritative location side-steps that whole class of path-encoding bug
    93	# AND naturally covers legacy `.workspace-worktrees/` paths — anything git
    94	# tracks as a worktree shows up here regardless of where it lives on disk.
    95	find_worktree_for_branch() {
    96	    local repo="$1"
    97	    local branch="$2"
    98	    git -C "$repo" worktree list --porcelain 2>/dev/null \
    99	        | awk -v target="refs/heads/$branch" '
   100	            /^worktree / { wt = substr($0, 10); next }
   101	            /^branch /   { if ($2 == target) { print wt; exit } }
   102	        '
   103	}
   104	
   105	# --- Discover the workspace and (optional) project remotes ---
   106	# Workspace remote always exists (we just resolved ROOT_DIR via git).
   107	# Project remote is only resolved when project/ is configured. Empty
   108	# project remote with project/ present is a misconfiguration — surface
   109	# it now rather than letting it manifest as a silent "PR not found"
   110	# (issue #173 root cause).
   111	WS_REMOTE=$(git -C "$ROOT_DIR" remote get-url origin 2>/dev/null || echo "")
   112	PJ_REMOTE=""
   113	if [[ -e "$ROOT_DIR/project/.git" ]]; then
   114	    PJ_REMOTE=$(git -C "$ROOT_DIR/project" remote get-url origin 2>/dev/null || echo "")
   115	    if [[ -z "$PJ_REMOTE" ]]; then
   116	        echo "ERROR: $ROOT_DIR/project has no 'origin' remote configured." >&2
   117	        echo "  Cannot resolve project PRs. Configure the remote, or pass" >&2
   118	        echo "  --type workspace if this is intentionally workspace-only." >&2
   119	        exit 1
   120	    fi
   121	fi
   122	
   123	# --- Resolve which repo owns the PR (collision-safe) ---
   124	# PR numbers are repo-local: workspace #84 ≠ project #84. Trying repos
   125	# in sequence and taking the first hit (the original design) silently
   126	# picks the wrong one when both repos have an open PR with the same
   127	# number. Query both, filter to OPEN, then:
   128	#   0 hits → error
   129	#   1 hit  → use it (and implicitly determine WORKTREE_TYPE if --type
   130	#            was not supplied)
   131	#   2 hits → error and require --type to disambiguate
   132	# When --type IS supplied, query only the matching repo.
   133	
   134	# Query a single repo. On OPEN PR, populates QUERY_BRANCH/QUERY_TITLE
   135	# and returns 0. On not-found OR not-OPEN, returns 1 silently. On other
   136	# errors (auth, network), prints the error and returns 2.
   137	QUERY_BRANCH=""
   138	QUERY_TITLE=""
   139	query_pr() {
   140	    local remote="$1"
   141	    local out err rc=0
   142	    local err_file
   143	    err_file=$(mktemp)
   144	    out=$(gh pr view "$PR_NUMBER" -R "$remote" \
   145	            --json state,headRefName,title 2>"$err_file") || rc=$?
   146	    err=$(<"$err_file")
   147	    rm -f "$err_file"
   148	
   149	    if [[ $rc -eq 0 ]] && [[ -n "$out" ]]; then
   150	        local state
   151	        state=$(echo "$out" | jq -r '.state // empty')
   152	        if [[ "$state" == "OPEN" ]]; then
   153	            QUERY_BRANCH=$(echo "$out" | jq -r '.headRefName // empty')
   154	            QUERY_TITLE=$(echo "$out" | jq -r '.title // empty')
   155	            return 0
   156	        fi
   157	        return 1   # exists but not OPEN — irrelevant for merge
   158	    fi
   159	
   160	    # Distinguish "PR not found" from auth/network errors. Silently
   161	    # picking the only authed repo would be the same class of bug
   162	    # we're fixing — propagate other errors and require --type.
   163	    case "$err" in
   164	        *"Could not resolve to"*|*"GraphQL: Could not"*|*"no pull"*|*"404"*)
   165	            return 1 ;;
   166	        *)
   167	            echo "ERROR: gh failed against $remote:" >&2
   168	            echo "  $err" >&2
   169	            return 2 ;;
   170	    esac
   171	}
   172	
   173	WS_HIT=false; WS_BRANCH=""; WS_TITLE=""
   174	PJ_HIT=false; PJ_BRANCH=""; PJ_TITLE=""
   175	
   176	if [[ -z "$WORKTREE_TYPE" || "$WORKTREE_TYPE" == "workspace" ]] && [[ -n "$WS_REMOTE" ]]; then
   177	    if query_pr "$WS_REMOTE"; then
   178	        WS_HIT=true
   179	        WS_BRANCH="$QUERY_BRANCH"
   180	        WS_TITLE="$QUERY_TITLE"
   181	    elif [[ $? -eq 2 ]]; then
   182	        echo "  Pass --type to bypass auto-detection." >&2
   183	        exit 1
   184	    fi
   185	fi
   186	
   187	if [[ -z "$WORKTREE_TYPE" || "$WORKTREE_TYPE" == "project" ]] && [[ -n "$PJ_REMOTE" ]]; then
   188	    if query_pr "$PJ_REMOTE"; then
   189	        PJ_HIT=true
   190	        PJ_BRANCH="$QUERY_BRANCH"
   191	        PJ_TITLE="$QUERY_TITLE"
   192	    elif [[ $? -eq 2 ]]; then
   193	        echo "  Pass --type to bypass auto-detection." >&2
   194	        exit 1
   195	    fi
   196	fi
   197	
   198	GH_REPO_ARGS=()
   199	if $WS_HIT && $PJ_HIT; then
   200	    echo "ERROR: PR #${PR_NUMBER} is open in BOTH repos:" >&2
   201	    echo "  workspace: $WS_TITLE" >&2
   202	    echo "  project:   $PJ_TITLE" >&2
   203	    echo "  Pass --type workspace or --type project to disambiguate." >&2
   204	    exit 2
   205	elif $WS_HIT; then
   206	    WORKTREE_TYPE="workspace"
   207	    PR_BRANCH="$WS_BRANCH"
   208	elif $PJ_HIT; then
   209	    WORKTREE_TYPE="project"
   210	    PR_BRANCH="$PJ_BRANCH"
   211	    GH_REPO_ARGS=("-R" "$PJ_REMOTE")
   212	else
   213	    if [[ -n "$WORKTREE_TYPE" ]]; then
   214	        echo "ERROR: PR #${PR_NUMBER} not open in $WORKTREE_TYPE repo." >&2
   215	    else
   216	        echo "ERROR: PR #${PR_NUMBER} not open in either workspace or project." >&2
   217	    fi
   218	    exit 1
   219	fi
   220	
   221	ISSUE_NUM=$(echo "$PR_BRANCH" | sed -nE 's/^feature\/[iI]ssue-([0-9]+).*/\1/p')
   222	if [[ -z "$ISSUE_NUM" ]]; then
   223	    echo "ERROR: Could not extract issue number from branch '$PR_BRANCH'" >&2
   224	    echo "Expected pattern: feature/issue-<N> or feature/ISSUE-<N>-<desc>" >&2
   225	    echo "Note: skill worktree branches are not supported by this script" >&2
   226	    exit 1
   227	fi
   228	
   229	echo "========================================"
   230	echo "Merging PR #${PR_NUMBER} (issue #${ISSUE_NUM})"
   231	echo "========================================"
   232	
   233	# --- Step 1: Roadmap update (pre-merge) ---
   234	if [[ "$NO_ROADMAP_UPDATE" == false ]]; then
   235	    echo "  Checking roadmap for #${ISSUE_NUM}..."
   236	
   237	    # Resolve the worktree that has the feature branch checked out via
   238	    # find_worktree_for_branch (issue #173) — git is the authority on
   239	    # where worktrees live, so we don't have to re-encode path
   240	    # conventions here. For project worktrees, list against the project
   241	    # repo since project worktrees are tracked there.
   242	    _WT_REPO="$ROOT_DIR"
   243	    [[ "$WORKTREE_TYPE" == "project" ]] && _WT_REPO="$ROOT_DIR/project"
   244	    _WT_ROOT=$(find_worktree_for_branch "$_WT_REPO" "$PR_BRANCH")
   245	
   246	    if [[ -z "$_WT_ROOT" ]]; then
   247	        echo "  ⚠️  No worktree found for issue #${ISSUE_NUM} — skipping roadmap update"
   248	    else
   249	        # Belt-and-braces: confirm git's worktree-list output really is on
   250	        # the expected branch (handles a detached-HEAD edge case where the
   251	        # `branch ` line was present but transient).
   252	        _WT_BRANCH=$(git -C "$_WT_ROOT" branch --show-current 2>/dev/null || echo "")
   253	        if [[ "$_WT_BRANCH" != "$PR_BRANCH" ]]; then
   254	            echo "  ⚠️  Worktree is on '${_WT_BRANCH:-unknown}', expected '$PR_BRANCH' — skipping roadmap update"
   255	        else
   256	            # Run update_roadmap.sh in the worktree (stdout = changed file paths, stderr = status)
   257	            _CHANGED_FILES=$("$SCRIPT_DIR/update_roadmap.sh" --issue "$ISSUE_NUM" --root "$_WT_ROOT" || true)
   258	
   259	            if [[ -n "$_CHANGED_FILES" ]]; then
   260	                echo "  Committing roadmap update to feature branch..."
   261	                _WT_TOPLEVEL=$(git -C "$_WT_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "")
   262	
   263	                if [[ -z "$_WT_TOPLEVEL" ]]; then
   264	                    echo "  ⚠️  Unable to resolve worktree root — skipping roadmap commit"
   265	                else
   266	                    # Stage changed files using paths relative to the worktree root
   267	                    while IFS= read -r changed_file; do
   268	                        [[ -z "$changed_file" ]] && continue
   269	                        case "$changed_file" in
   270	                            "${_WT_TOPLEVEL}"/*)
   271	                                _REL="${changed_file#"${_WT_TOPLEVEL}/"}"
   272	                                git -C "$_WT_ROOT" add -- "$_REL" 2>/dev/null || true
   273	                                ;;
   274	                            *)
   275	                                echo "  ⚠️  Skipping non-repo path: $changed_file" >&2
   276	                                ;;
   277	                        esac
   278	                    done <<< "$_CHANGED_FILES"
   279	
   280	                    if git -C "$_WT_ROOT" diff --cached --quiet 2>/dev/null; then
   281	                        echo "  ⚠️  No staged changes — skipping roadmap commit"
   282	                    else
   283	                        git -C "$_WT_ROOT" commit -m "Update roadmap: mark #${ISSUE_NUM} as done" 2>/dev/null \
   284	                            && echo "  ✅ Roadmap updated" \
   285	                            || echo "  ⚠️  Roadmap commit failed — proceeding with merge"
   286	                        git -C "$_WT_ROOT" push origin "$PR_BRANCH" 2>/dev/null \
   287	                            && echo "  ✅ Roadmap commit pushed" \
   288	                            || echo "  ⚠️  Roadmap push failed — proceeding with merge"
   289	                    fi
   290	                fi
   291	            fi
   292	        fi
   293	    fi
   294	else
   295	    echo "  Roadmap update skipped (--no-roadmap-update)"
   296	fi
   297	
   298	# --- Step 2: Merge ---
   299	# GH_REPO_ARGS was set during PR resolution above (-R <project-remote> for
   300	# project PRs, empty for workspace PRs). Don't re-resolve.
   301	echo "  Merging PR..."
   302	if ! gh pr merge "$PR_NUMBER" "${GH_REPO_ARGS[@]}" --merge; then
   303	    echo "ERROR: Merge failed for PR #${PR_NUMBER}" >&2
   304	    exit 1
   305	fi
   306	echo "  ✅ PR merged"
   307	
   308	# --- Step 3: Remove worktree ---
   309	if [[ -n "$WORKTREE_TYPE" ]]; then
   310	    echo "  Removing worktree..."
   311	    # Must run from root, not from inside the worktree
   312	    cd "$ROOT_DIR"
   313	    if "$SCRIPT_DIR/worktree_remove.sh" --issue "$ISSUE_NUM" --type "$WORKTREE_TYPE"; then
   314	        echo "  ✅ Worktree removed"
   315	    else
   316	        echo "  ⚠️  Worktree removal failed — check for uncommitted changes" >&2
   317	    fi
   318	fi
   319	
   320	# --- Step 4: Delete branches ---
   321	echo "  Cleaning up branches..."
   322	if [[ "$WORKTREE_TYPE" == "project" ]] && [[ -d "$ROOT_DIR/project/.git" ]]; then
   323	    BRANCH_REPO="$ROOT_DIR/project"
   324	else
   325	    BRANCH_REPO="$ROOT_DIR"
   326	fi
   327	git -C "$BRANCH_REPO" branch -d "$PR_BRANCH" 2>/dev/null && echo "  ✅ Local branch deleted" || true
   328	git -C "$BRANCH_REPO" push origin --delete "$PR_BRANCH" 2>/dev/null && echo "  ✅ Remote branch deleted" || true
   329	
   330	# --- Step 5: Sync ---
   331	echo "  Syncing main..."
   332	git pull --ff-only
   333	echo "  ✅ Workspace synced"
   334	
   335	# Also sync project repo for project-type merges
   336	if [[ "$WORKTREE_TYPE" == "project" ]] && [[ -d "$ROOT_DIR/project/.git" ]]; then
   337	    echo "  Syncing project..."
   338	    git -C "$ROOT_DIR/project" pull --ff-only 2>/dev/null && echo "  ✅ Project synced" || true
   339	fi
   340	
   341	echo ""
   342	echo "========================================"
   343	echo "✅ Done: PR #${PR_NUMBER} merged, cleaned up, and synced"
   344	echo "========================================"
   345	
   346	# Warn if the caller's shell may be in a deleted directory
   347	if [[ -n "$WORKTREE_TYPE" ]]; then
   348	    echo ""
   349	    echo "NOTE: If you ran this from inside the worktree, run:"
   350	    echo "  cd $ROOT_DIR"
   351	fi

exec
/bin/bash -lc "nl -ba Makefile | sed -n '110,130p'" in /home/roland/daddy_camp/worktrees/workspace/issue-workspace-173
 succeeded in 0ms:
   110	unlock:
   111		@$(MAIN_ROOT)/.agent/scripts/unlock.sh
   112	
   113	pr-triage:
   114		@$(MAIN_ROOT)/.agent/scripts/pr_status.sh --all-repos
   115	
   116	revert-feature:
   117		@if [ -z "$(ISSUE)" ]; then echo "Usage: make revert-feature ISSUE=<N>"; exit 1; fi
   118		@$(MAIN_ROOT)/.agent/scripts/revert_feature.sh --issue $(ISSUE)
   119	
   120	merge-pr:
   121		@if [ -z "$(PR)" ]; then echo "Usage: make merge-pr PR=<N> [MERGE_PR_ARGS=...]"; exit 1; fi
   122		@$(MAIN_ROOT)/.agent/scripts/merge_pr.sh --pr $(PR) $(MERGE_PR_ARGS)
   123	
   124	generate-skills:
   125		@$(MAIN_ROOT)/.agent/scripts/generate_make_skills.sh
   126	
   127	skip-git-bug:
   128		@mkdir -p $(STAMP)
   129		@touch $(STAMP)/git-bug.done
   130		@echo "git-bug setup marked as done. Run 'make clean' to reset."

exec
/bin/bash -lc 'rg -n "find_worktree_for_branch|query_pr|GH_REPO_ARGS|gh pr merge|WORKTREE_TYPE|PR_BRANCH|ISSUE_NUM|NO_ROADMAP_UPDATE" .agent/scripts/merge_pr.sh' in /home/roland/daddy_camp/worktrees/workspace/issue-workspace-173
 succeeded in 0ms:
37:WORKTREE_TYPE=""
38:NO_ROADMAP_UPDATE=false
47:            WORKTREE_TYPE="$2"; shift 2 ;;
49:            NO_ROADMAP_UPDATE=true; shift ;;
63:if [[ -n "$WORKTREE_TYPE" ]] && [[ "$WORKTREE_TYPE" != "workspace" && "$WORKTREE_TYPE" != "project" ]]; then
95:find_worktree_for_branch() {
129:#   1 hit  → use it (and implicitly determine WORKTREE_TYPE if --type
139:query_pr() {
176:if [[ -z "$WORKTREE_TYPE" || "$WORKTREE_TYPE" == "workspace" ]] && [[ -n "$WS_REMOTE" ]]; then
177:    if query_pr "$WS_REMOTE"; then
187:if [[ -z "$WORKTREE_TYPE" || "$WORKTREE_TYPE" == "project" ]] && [[ -n "$PJ_REMOTE" ]]; then
188:    if query_pr "$PJ_REMOTE"; then
198:GH_REPO_ARGS=()
206:    WORKTREE_TYPE="workspace"
207:    PR_BRANCH="$WS_BRANCH"
209:    WORKTREE_TYPE="project"
210:    PR_BRANCH="$PJ_BRANCH"
211:    GH_REPO_ARGS=("-R" "$PJ_REMOTE")
213:    if [[ -n "$WORKTREE_TYPE" ]]; then
214:        echo "ERROR: PR #${PR_NUMBER} not open in $WORKTREE_TYPE repo." >&2
221:ISSUE_NUM=$(echo "$PR_BRANCH" | sed -nE 's/^feature\/[iI]ssue-([0-9]+).*/\1/p')
222:if [[ -z "$ISSUE_NUM" ]]; then
223:    echo "ERROR: Could not extract issue number from branch '$PR_BRANCH'" >&2
230:echo "Merging PR #${PR_NUMBER} (issue #${ISSUE_NUM})"
234:if [[ "$NO_ROADMAP_UPDATE" == false ]]; then
235:    echo "  Checking roadmap for #${ISSUE_NUM}..."
238:    # find_worktree_for_branch (issue #173) — git is the authority on
243:    [[ "$WORKTREE_TYPE" == "project" ]] && _WT_REPO="$ROOT_DIR/project"
244:    _WT_ROOT=$(find_worktree_for_branch "$_WT_REPO" "$PR_BRANCH")
247:        echo "  ⚠️  No worktree found for issue #${ISSUE_NUM} — skipping roadmap update"
253:        if [[ "$_WT_BRANCH" != "$PR_BRANCH" ]]; then
254:            echo "  ⚠️  Worktree is on '${_WT_BRANCH:-unknown}', expected '$PR_BRANCH' — skipping roadmap update"
257:            _CHANGED_FILES=$("$SCRIPT_DIR/update_roadmap.sh" --issue "$ISSUE_NUM" --root "$_WT_ROOT" || true)
283:                        git -C "$_WT_ROOT" commit -m "Update roadmap: mark #${ISSUE_NUM} as done" 2>/dev/null \
286:                        git -C "$_WT_ROOT" push origin "$PR_BRANCH" 2>/dev/null \
299:# GH_REPO_ARGS was set during PR resolution above (-R <project-remote> for
302:if ! gh pr merge "$PR_NUMBER" "${GH_REPO_ARGS[@]}" --merge; then
309:if [[ -n "$WORKTREE_TYPE" ]]; then
313:    if "$SCRIPT_DIR/worktree_remove.sh" --issue "$ISSUE_NUM" --type "$WORKTREE_TYPE"; then
322:if [[ "$WORKTREE_TYPE" == "project" ]] && [[ -d "$ROOT_DIR/project/.git" ]]; then
327:git -C "$BRANCH_REPO" branch -d "$PR_BRANCH" 2>/dev/null && echo "  ✅ Local branch deleted" || true
328:git -C "$BRANCH_REPO" push origin --delete "$PR_BRANCH" 2>/dev/null && echo "  ✅ Remote branch deleted" || true
336:if [[ "$WORKTREE_TYPE" == "project" ]] && [[ -d "$ROOT_DIR/project/.git" ]]; then
347:if [[ -n "$WORKTREE_TYPE" ]]; then

codex
### Findings

| # | Severity | File | Line | Finding |
|---|----------|------|------|---------|
| 1 | must-fix | `.agent/scripts/merge_pr.sh` | 113 | The new project-remote validation runs unconditionally whenever `project/.git` exists, even if the caller explicitly passed `--type workspace`. In a workspace that has a checked-out `project/` repo but no `origin` configured there, every workspace PR merge now fails before repo resolution. The error text says “pass `--type workspace`”, but this code path exits before that can help. |
| 2 | must-fix | `.agent/scripts/merge_pr.sh` | 198 | Repo disambiguation is only carried through to `gh pr merge` for project PRs. For workspace PRs, `GH_REPO_ARGS` is left empty, so the actual merge still depends on the caller’s current directory. If this script is invoked from a project worktree or any non-workspace clone, `query_pr` can correctly identify the workspace PR, then `gh pr merge` can still target the wrong repo. That breaks the “collision-safe PR lookup” claim and can merge/fail against the wrong repository. |

### Summary

The PR fixes the original lookup-path problem, but two control-flow gaps remain in repo targeting. One causes false failures for workspace merges in partially configured environments; the other means the final merge step can still hit the wrong repo even after the new lookup logic identified the right one.
tokens used
27,796
### Findings

| # | Severity | File | Line | Finding |
|---|----------|------|------|---------|
| 1 | must-fix | `.agent/scripts/merge_pr.sh` | 113 | The new project-remote validation runs unconditionally whenever `project/.git` exists, even if the caller explicitly passed `--type workspace`. In a workspace that has a checked-out `project/` repo but no `origin` configured there, every workspace PR merge now fails before repo resolution. The error text says “pass `--type workspace`”, but this code path exits before that can help. |
| 2 | must-fix | `.agent/scripts/merge_pr.sh` | 198 | Repo disambiguation is only carried through to `gh pr merge` for project PRs. For workspace PRs, `GH_REPO_ARGS` is left empty, so the actual merge still depends on the caller’s current directory. If this script is invoked from a project worktree or any non-workspace clone, `query_pr` can correctly identify the workspace PR, then `gh pr merge` can still target the wrong repo. That breaks the “collision-safe PR lookup” claim and can merge/fail against the wrong repository. |

### Summary

The PR fixes the original lookup-path problem, but two control-flow gaps remain in repo targeting. One causes false failures for workspace merges in partially configured environments; the other means the final merge step can still hit the wrong repo even after the new lookup logic identified the right one.
--- Review complete ---
