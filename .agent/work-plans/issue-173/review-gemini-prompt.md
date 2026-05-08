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
