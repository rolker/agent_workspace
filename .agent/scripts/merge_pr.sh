#!/bin/bash
# .agent/scripts/merge_pr.sh
# Merge a PR, remove its worktree, delete the branch, and sync main.
#
# Usage:
#   .agent/scripts/merge_pr.sh --pr <N> [--type workspace|project] [--no-roadmap-update] [--no-wait]
#   .agent/scripts/merge_pr.sh --pr <N> --repo <owner/repo> [--no-roadmap-update] [--no-wait]
#   .agent/scripts/merge_pr.sh --pr <owner/repo#N> [--no-roadmap-update] [--no-wait]
#
# --repo <owner/repo> (or an equivalent qualified --pr owner/repo#N) resolves
# the PR against exactly that repo — no workspace/project auto-detection —
# for a package-repo PR (ADR-0012 package worktree). Without it, behaviour
# is unchanged from before #252 PR 2.
#
# If --type is omitted, the script auto-detects by checking which worktree
# exists for the issue. If neither or both exist, it asks.
#
# Limitations:
#   - Only works for issue-based branches: feature/issue-<N> (owning repo)
#     or feature/<repo>-issue-<N> (package-worktree sibling repo, ADR-0012)
#   - Skill worktree branches are not supported
#   - If run from inside the worktree being removed, your shell's CWD
#     will be invalid after the script completes — cd to the workspace root
#
# Steps:
#   1. Roadmap update (commit + push to feature branch before merge) — skipped
#      for a package-repo PR; the roadmap lives in this repo, not the package repo
#   2. Wait for CI on the (possibly new) HEAD before merging (--no-wait skips)
#   3. Merge the PR (--merge strategy)
#   4. Remove the worktree:
#      - Workspace/project (legacy, single-repo) PR: cd to root first; fails
#        safely if uncommitted changes.
#      - Package-repo PR (ADR-0012): delete the merged branch locally and on
#        origin in its own repo only, and `pull --ff-only` that repo's main
#        checkout. Then check every OTHER repo in the package worktree's
#        manifest for an open PR on its branch; if any is open, keep the
#        worktree and print which package PRs still block cleanup, otherwise
#        remove the worktree.
#   5. Delete local and remote branches (legacy path only — step 4 already
#      did this for a package-repo PR, in its own repo)
#   6. Pull main to sync (workspace and project repos; legacy path only)
#
# Manual verification of the wait step (issue #186):
#   1. On any open PR branch in this repo, push a trivial commit:
#        git commit --allow-empty -m "poke ci"
#        git push
#   2. Immediately run:
#        make merge-pr PR=<N>
#   3. Expected: script prints "Waiting for CI..." and blocks until checks
#      complete, then merges.
#   4. Without the wait step (pre-#186), step 2 would have errored
#      "Pull Request is not mergeable" instantly.
#
#   An automated equivalent would need to mock gh pr checks --watch
#   (drift risk) or spin throwaway PRs (network + auth dependencies);
#   declined as out of scope for #186.
#
# Exit codes:
#   0 — success
#   1 — merge failed or dependency missing
#   2 — invalid arguments

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=_issue_helpers.sh
source "$SCRIPT_DIR/_issue_helpers.sh"
# shellcheck source=_worktree_helpers.sh
source "$SCRIPT_DIR/_worktree_helpers.sh"

PR_NUMBER=""
WORKTREE_TYPE=""
REPO_ARG=""
REPO_KIND=""   # workspace | project | package — derived from --repo when given
PROJECT_ARG="" # registered project name; selects among package worktrees that
               # host the same repo+branch under different instances
NO_ROADMAP_UPDATE=false
NO_WAIT=false
# Review-loop merge gate (issue #269 PR F). Report-only by default: the gate
# prints what it would have refused and records it, but never blocks. The
# flip to enforce-by-default is a separate one-line PR, once the report-only
# output has been watched on real merges.
ENFORCE_MERGE_GATE=false
FORCE_UNREVIEWED=false

USAGE="Usage: $0 --pr <N|owner/repo#N> [--repo owner/repo] [--project <name>] [--type workspace|project] [--no-roadmap-update] [--no-wait] [--enforce] [--force-unreviewed]"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --pr)
            [[ $# -lt 2 ]] && { echo "ERROR: Missing value for --pr" >&2; exit 2; }
            PR_NUMBER="$2"; shift 2 ;;
        --repo)
            [[ $# -lt 2 ]] && { echo "ERROR: Missing value for --repo" >&2; exit 2; }
            REPO_ARG="$2"; shift 2 ;;
        --project)
            [[ $# -lt 2 ]] && { echo "ERROR: Missing value for --project" >&2; exit 2; }
            PROJECT_ARG="$2"; shift 2 ;;
        --type)
            [[ $# -lt 2 ]] && { echo "ERROR: Missing value for --type" >&2; exit 2; }
            WORKTREE_TYPE="$2"; shift 2 ;;
        --no-roadmap-update)
            NO_ROADMAP_UPDATE=true; shift ;;
        --no-wait)
            NO_WAIT=true; shift ;;
        --enforce)
            ENFORCE_MERGE_GATE=true; shift ;;
        --force-unreviewed)
            FORCE_UNREVIEWED=true; shift ;;
        *)
            echo "ERROR: Unknown argument: $1" >&2
            echo "$USAGE" >&2
            exit 2 ;;
    esac
done

if [[ -z "$PR_NUMBER" ]]; then
    echo "ERROR: --pr <N> is required" >&2
    echo "$USAGE" >&2
    exit 2
fi

# --- Repo-qualified PR ref: --pr owner/repo#N is equivalent to --repo
#     owner/repo --pr N. Both may be given as long as they agree. ---
if [[ "$PR_NUMBER" == */*#* ]]; then
    if [[ "$PR_NUMBER" =~ ^([^/#[:space:]]+/[^/#[:space:]]+)#([0-9]+)$ ]]; then
        _QUALIFIED_REPO="${BASH_REMATCH[1]}"
        if [[ -n "$REPO_ARG" ]] && [[ "$REPO_ARG" != "$_QUALIFIED_REPO" ]]; then
            echo "ERROR: --repo $REPO_ARG conflicts with qualified --pr $PR_NUMBER" >&2
            exit 2
        fi
        REPO_ARG="$_QUALIFIED_REPO"
        PR_NUMBER="${BASH_REMATCH[2]}"
        unset _QUALIFIED_REPO
    else
        echo "ERROR: qualified --pr must be owner/repo#N, got '$PR_NUMBER'" >&2
        exit 2
    fi
elif [[ "$PR_NUMBER" == *#* ]]; then
    echo "ERROR: qualified --pr must be owner/repo#N, got '$PR_NUMBER'" >&2
    exit 2
fi

if [[ -n "$WORKTREE_TYPE" ]] && [[ "$WORKTREE_TYPE" != "workspace" && "$WORKTREE_TYPE" != "project" ]]; then
    echo "ERROR: --type must be 'workspace' or 'project'" >&2
    exit 2
fi

# --- Resolve workspace root (main tree) ---
# Use `git worktree list --porcelain` instead of $SCRIPT_DIR/../.. so the
# resolution is correct when the script is invoked from inside a
# worktree (e.g. `make merge-pr` from a feature worktree). With the
# relative-path approach, ROOT_DIR resolved to the worktree root, not
# the main tree, so downstream worktree detection and cleanup silently
# skipped. See issue #146.
#
# git worktree list always prints the main worktree first, in absolute
# form, regardless of invocation cwd.
# `|| true` so invocation outside any repo (git fails, pipefail would
# otherwise trip set -e) falls through to the explicit empty-string
# check below with a clearer error.
ROOT_DIR=$({ git -C "$SCRIPT_DIR" worktree list --porcelain 2>/dev/null \
    | head -n1 | sed 's/^worktree //'; } || true)
if [[ -z "$ROOT_DIR" ]]; then
    echo "ERROR: merge_pr.sh must run from within a git repository" >&2
    exit 1
fi

# --- Helper: find a worktree for a given branch ---
# Issue #173: previous logic globbed `worktrees/project/issue-project-<N>`,
# which never matched the actual multi-project layout
# (`worktrees/project/<repo>/issue-<repo>-<N>`). Asking git for the
# authoritative location side-steps that whole class of path-encoding bug
# AND naturally covers legacy `.workspace-worktrees/` paths — anything git
# tracks as a worktree shows up here regardless of where it lives on disk.
# Note: this awk parser assumes worktree paths do not contain newlines.
# git's own docs flag that pathological case and recommend `--porcelain -z`
# with NUL-aware parsing for true robustness. We don't bother — newlines in
# worktree paths would break a lot more than this script.
#
# This path covers legacy/single-repo project worktrees and workspace
# worktrees. ADR-0012 package worktrees (multi-repo, `.worktree-repos`
# manifest) are resolved separately below by scanning manifests, since
# they are not a single `git worktree add` against $repo.
find_worktree_for_branch() {
    local repo="$1"
    local branch="$2"
    git -C "$repo" worktree list --porcelain 2>/dev/null \
        | awk -v target="refs/heads/$branch" '
            /^worktree / { wt = substr($0, 10); next }
            /^branch /   { if ($2 == target) { print wt; exit } }
        '
}

# --- Discover the workspace and (optional) project remotes ---
# Workspace remote always exists (we just resolved ROOT_DIR via git).
# Project remote is only resolved when project/ is configured. Empty
# project remote with project/ present is a misconfiguration — surface
# it now rather than letting it manifest as a silent "PR not found"
# (issue #173 root cause).
#
# Skipped when --repo (or a qualified --pr) was given: that names the PR's
# repo explicitly, so the workspace/project two-remote auto-detection below
# is irrelevant (deliverable 1, #252 PR 2).
WS_REMOTE=$(git -C "$ROOT_DIR" remote get-url origin 2>/dev/null || echo "")
PJ_REMOTE=""
if [[ -e "$ROOT_DIR/project/.git" ]]; then
    PJ_REMOTE=$(git -C "$ROOT_DIR/project" remote get-url origin 2>/dev/null || echo "")
    if [[ -z "$REPO_ARG" ]] && [[ -z "$PJ_REMOTE" ]] && [[ "$WORKTREE_TYPE" != "workspace" ]]; then
        echo "ERROR: $ROOT_DIR/project has no 'origin' remote configured." >&2
        echo "  Cannot resolve project PRs. Configure the remote, or pass" >&2
        echo "  --type workspace if this is intentionally workspace-only." >&2
        exit 1
    fi
fi

# --- Resolve which repo owns the PR (collision-safe) ---
# PR numbers are repo-local: workspace #84 ≠ project #84. Trying repos
# in sequence and taking the first hit (the original design) silently
# picks the wrong one when both repos have an open PR with the same
# number. Query both, filter to OPEN, then:
#   0 hits → error
#   1 hit  → use it (and implicitly determine WORKTREE_TYPE if --type
#            was not supplied)
#   2 hits → error and require --type to disambiguate
# When --type IS supplied, query only the matching repo.
# When --repo (or a qualified --pr) IS supplied, query only that repo —
# this whole workspace/project disambiguation is skipped entirely.

# Query a single repo. On OPEN PR, populates QUERY_BRANCH/QUERY_TITLE
# and returns 0. On not-found OR not-OPEN, returns 1 silently. On other
# errors (auth, network), prints the error and returns 2.
QUERY_BRANCH=""
QUERY_TITLE=""
query_pr() {
    local remote="$1"
    local out err rc=0
    local err_file
    err_file=$(mktemp)
    out=$(gh pr view "$PR_NUMBER" -R "$remote" \
            --json state,headRefName,title 2>"$err_file") || rc=$?
    err=$(<"$err_file")
    rm -f "$err_file"

    if [[ $rc -eq 0 ]] && [[ -n "$out" ]]; then
        local state
        state=$(echo "$out" | jq -r '.state // empty')
        if [[ "$state" == "OPEN" ]]; then
            QUERY_BRANCH=$(echo "$out" | jq -r '.headRefName // empty')
            QUERY_TITLE=$(echo "$out" | jq -r '.title // empty')
            return 0
        fi
        return 1   # exists but not OPEN — irrelevant for merge
    fi

    # Distinguish "PR not found" from auth/network errors. Silently
    # picking the only authed repo would be the same class of bug
    # we're fixing — propagate other errors and require --type.
    # Match gh's current "GraphQL: Could not resolve to a PullRequest" wording
    # plus a few likely future variants. If gh ever rephrases not-found, an
    # unmatched not-found error would surface as rc=2 (auth/network), forcing
    # the user to pass --type — annoying but not unsafe (the alternative,
    # silently picking the only authed match, is the bug class we're fixing).
    case "$err" in
        *"Could not resolve to"*|*"GraphQL: Could not"*|*"no pull"*|*"404"* \
        |*"not found"*|*"Not Found"*|*"could not find"*|*"Could not find"*)
            return 1 ;;
        *)
            echo "ERROR: gh failed against $remote:" >&2
            echo "  $err" >&2
            return 2 ;;
    esac
}

GH_REPO_ARGS=()
PR_BRANCH=""
PR_REPO_SLUG=""

if [[ -n "$REPO_ARG" ]]; then
    # --- Explicit repo — no workspace/project auto-detection ---
    if query_pr "$REPO_ARG"; then
        PR_BRANCH="$QUERY_BRANCH"
        GH_REPO_ARGS=("-R" "$REPO_ARG")
        PR_REPO_SLUG="$REPO_ARG"
        # Derive what kind of repo this is from the remotes we know about,
        # and refuse a --type that contradicts it: a wrong --type would send
        # cleanup at the wrong checkout (e.g. --repo <workspace> --type
        # project would remove a project worktree after merging a workspace
        # PR). Anything that is neither the workspace nor the legacy
        # project/ remote is a package repo (REPO_KIND=package): it is only
        # ever cleaned up through a matching .worktree-repos manifest, never
        # through the legacy single-repo path.
        if [[ -n "$WS_REMOTE" ]] && [[ "$(extract_gh_slug "$WS_REMOTE")" == "$REPO_ARG" ]]; then
            REPO_KIND="workspace"
        elif [[ -n "$PJ_REMOTE" ]] && [[ "$(extract_gh_slug "$PJ_REMOTE")" == "$REPO_ARG" ]]; then
            REPO_KIND="project"
        else
            REPO_KIND="package"
        fi
        if [[ -n "$WORKTREE_TYPE" ]] && [[ "$WORKTREE_TYPE" != "$REPO_KIND" ]]; then
            echo "ERROR: --type $WORKTREE_TYPE conflicts with --repo $REPO_ARG (which is the $REPO_KIND repo)." >&2
            echo "  Drop --type; it is derived from --repo." >&2
            exit 2
        fi
        if [[ "$REPO_KIND" == "package" ]]; then
            WORKTREE_TYPE=""   # never the legacy single-repo cleanup path
        else
            WORKTREE_TYPE="$REPO_KIND"
        fi
    else
        _rc=$?
        if [[ $_rc -eq 2 ]]; then
            exit 1
        fi
        echo "ERROR: PR #${PR_NUMBER} not open in repo $REPO_ARG." >&2
        exit 1
    fi
else
    WS_HIT=false; WS_BRANCH=""; WS_TITLE=""
    PJ_HIT=false; PJ_BRANCH=""; PJ_TITLE=""

    if [[ -z "$WORKTREE_TYPE" || "$WORKTREE_TYPE" == "workspace" ]] && [[ -n "$WS_REMOTE" ]]; then
        if query_pr "$WS_REMOTE"; then
            WS_HIT=true
            WS_BRANCH="$QUERY_BRANCH"
            WS_TITLE="$QUERY_TITLE"
        elif [[ $? -eq 2 ]]; then
            echo "  Pass --type to bypass auto-detection." >&2
            exit 1
        fi
    fi

    if [[ -z "$WORKTREE_TYPE" || "$WORKTREE_TYPE" == "project" ]] && [[ -n "$PJ_REMOTE" ]]; then
        if query_pr "$PJ_REMOTE"; then
            PJ_HIT=true
            PJ_BRANCH="$QUERY_BRANCH"
            PJ_TITLE="$QUERY_TITLE"
        elif [[ $? -eq 2 ]]; then
            echo "  Pass --type to bypass auto-detection." >&2
            exit 1
        fi
    fi

    if $WS_HIT && $PJ_HIT; then
        echo "ERROR: PR #${PR_NUMBER} is open in BOTH repos:" >&2
        echo "  workspace: $WS_TITLE" >&2
        echo "  project:   $PJ_TITLE" >&2
        echo "  Pass --type workspace or --type project to disambiguate." >&2
        exit 2
    elif $WS_HIT; then
        WORKTREE_TYPE="workspace"
        PR_BRANCH="$WS_BRANCH"
        # Set -R for the workspace too — `gh pr merge` without -R falls back to
        # the CWD's git remote, which is the project repo when the script is
        # invoked from a project worktree (or anywhere else not under the
        # workspace tree). Without this, query_pr could correctly identify the
        # workspace PR while the actual merge step targets the wrong repo.
        GH_REPO_ARGS=("-R" "$WS_REMOTE")
        PR_REPO_SLUG="$(extract_gh_slug "$WS_REMOTE")"
    elif $PJ_HIT; then
        WORKTREE_TYPE="project"
        PR_BRANCH="$PJ_BRANCH"
        GH_REPO_ARGS=("-R" "$PJ_REMOTE")
        PR_REPO_SLUG="$(extract_gh_slug "$PJ_REMOTE")"
    else
        if [[ -n "$WORKTREE_TYPE" ]]; then
            echo "ERROR: PR #${PR_NUMBER} not open in $WORKTREE_TYPE repo." >&2
        else
            echo "ERROR: PR #${PR_NUMBER} not open in either workspace or project." >&2
        fi
        exit 1
    fi
fi

# Issue number extraction accepts both branch shapes: the owning repo's
# feature/issue-<N>, and a package-worktree sibling repo's
# feature/<repo>-issue-<N> (ADR-0012; repo name only, no owner).
ISSUE_NUM=$(echo "$PR_BRANCH" | sed -nE 's#^feature/([A-Za-z0-9_.-]+-)?[Ii]ssue-([0-9]+).*#\2#p')
if [[ -z "$ISSUE_NUM" ]]; then
    echo "ERROR: Could not extract issue number from branch '$PR_BRANCH'" >&2
    echo "Expected pattern: feature/issue-<N>, feature/ISSUE-<N>-<desc>," >&2
    echo "or feature/<repo>-issue-<N> (package-worktree sibling repo)" >&2
    echo "Note: skill worktree branches are not supported by this script" >&2
    exit 1
fi

echo "========================================"
echo "Merging PR #${PR_NUMBER} (issue #${ISSUE_NUM})"
echo "========================================"

# --- Manifest-driven worktree lookup (ADR-0012 package worktrees) ---
# Scan every `.worktree-repos` manifest under worktrees/project/*/*/ for an
# entry whose owning repo matches PR_REPO_SLUG and whose recorded branch
# matches PR_BRANCH. Directory names are never parsed for this shape — only
# the manifest's entries (and header) are read. A miss here (no manifest
# matches, e.g. a legacy single-repo project PR or a workspace PR) falls
# back to find_worktree_for_branch below, unchanged from before #252 PR 2.
PKG_WT_DIR=""
PKG_WT_PROJECT=""
PKG_WT_ISSUE=""
declare -a _PKG_MATCHES=()
if [[ -n "$PR_REPO_SLUG" ]]; then
    for _manifest in "$ROOT_DIR"/worktrees/project/*/*/.worktree-repos; do
        [[ -f "$_manifest" ]] || continue
        _wtdir="$(dirname "$_manifest")"
        _entries="$(wt_read_manifest "$_wtdir")"
        _found=false
        while IFS=$'\t' read -r _m_origin _m_rel _m_branch; do
            [[ -z "$_m_origin" ]] && continue
            [[ "$_m_branch" != "$PR_BRANCH" ]] && continue
            _m_remote="$(git -C "$_m_origin" remote get-url origin 2>/dev/null || echo "")"
            _m_slug="$(extract_gh_slug "$_m_remote")"
            if [[ -n "$_m_slug" ]] && [[ "$_m_slug" == "$PR_REPO_SLUG" ]]; then
                _found=true
                break
            fi
        done <<< "$_entries"
        if [[ "$_found" == true ]]; then
            # Header fields read directly (not via wt_read_manifest's own
            # side-effect globals, which a `$(...)` call above would discard —
            # see the worktree_list.sh fix in PR 1's post-review pass).
            _header="$(head -n1 "$_manifest")"
            _hdr_project="$(sed -n 's/^# project=\([^ ]*\).*/\1/p' <<< "$_header")"
            _hdr_issue="$(sed -n 's/.* issue=\([^ ]*\).*/\1/p' <<< "$_header")"
            # --project narrows to one registered instance; otherwise collect
            # every match — the same repo+branch can be worktreed under more
            # than one ros2_colcon instance (each has its own checkout), and
            # glob order must not silently pick one.
            if [[ -n "$PROJECT_ARG" ]] && [[ "$_hdr_project" != "$PROJECT_ARG" ]]; then
                continue
            fi
            _PKG_MATCHES+=("$_wtdir"$'\t'"$_hdr_project"$'\t'"$_hdr_issue")
        fi
    done
    if [[ "${#_PKG_MATCHES[@]}" -gt 1 ]]; then
        echo "ERROR: $PR_REPO_SLUG branch '$PR_BRANCH' is worktreed under more than one project:" >&2
        for _pm in "${_PKG_MATCHES[@]}"; do
            IFS=$'\t' read -r _pm_dir _pm_project _pm_issue <<< "$_pm"
            echo "  --project $_pm_project   ($_pm_dir)" >&2
        done
        echo "  Pass --project <name> to say which one this merge cleans up. Nothing was merged." >&2
        exit 2
    elif [[ "${#_PKG_MATCHES[@]}" -eq 1 ]]; then
        IFS=$'\t' read -r PKG_WT_DIR PKG_WT_PROJECT PKG_WT_ISSUE <<< "${_PKG_MATCHES[0]}"
    fi
    unset _manifest _wtdir _entries _found _m_origin _m_rel _m_branch _m_remote _m_slug _header _hdr_project _hdr_issue _pm _pm_dir _pm_project _pm_issue
fi
IS_PACKAGE_PR=false
[[ -n "$PKG_WT_DIR" ]] && IS_PACKAGE_PR=true

# --- Step 1: Roadmap update (pre-merge) ---
if [[ "$NO_ROADMAP_UPDATE" == false ]]; then
    if [[ "$IS_PACKAGE_PR" == true ]] || [[ "${REPO_KIND:-}" == "package" ]]; then
        echo "  Package PR (repo: $PR_REPO_SLUG) — skipping roadmap update"
        echo "  (the roadmap lives in this repo, not the package repo)"
    else
        echo "  Checking roadmap for #${ISSUE_NUM}..."

        # Resolve the worktree that has the feature branch checked out via
        # find_worktree_for_branch (issue #173) — git is the authority on
        # where worktrees live, so we don't have to re-encode path
        # conventions here. For project worktrees, list against the project
        # repo since project worktrees are tracked there.
        _WT_REPO="$ROOT_DIR"
        [[ "$WORKTREE_TYPE" == "project" ]] && _WT_REPO="$ROOT_DIR/project"
        _WT_ROOT=$(find_worktree_for_branch "$_WT_REPO" "$PR_BRANCH")

        if [[ -z "$_WT_ROOT" ]]; then
            echo "  ⚠️  No worktree found for issue #${ISSUE_NUM} — skipping roadmap update"
        else
            # Belt-and-braces: confirm git's worktree-list output really is on
            # the expected branch (handles a detached-HEAD edge case where the
            # `branch ` line was present but transient).
            _WT_BRANCH=$(git -C "$_WT_ROOT" branch --show-current 2>/dev/null || echo "")
            if [[ "$_WT_BRANCH" != "$PR_BRANCH" ]]; then
                echo "  ⚠️  Worktree is on '${_WT_BRANCH:-unknown}', expected '$PR_BRANCH' — skipping roadmap update"
            else
                # Run update_roadmap.sh in the worktree (stdout = changed file paths, stderr = status)
                _CHANGED_FILES=$("$SCRIPT_DIR/update_roadmap.sh" --issue "$ISSUE_NUM" --root "$_WT_ROOT" || true)

                if [[ -n "$_CHANGED_FILES" ]]; then
                    echo "  Committing roadmap update to feature branch..."
                    _WT_TOPLEVEL=$(git -C "$_WT_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "")

                    if [[ -z "$_WT_TOPLEVEL" ]]; then
                        echo "  ⚠️  Unable to resolve worktree root — skipping roadmap commit"
                    else
                        # Stage changed files using paths relative to the worktree root
                        while IFS= read -r changed_file; do
                            [[ -z "$changed_file" ]] && continue
                            case "$changed_file" in
                                "${_WT_TOPLEVEL}"/*)
                                    _REL="${changed_file#"${_WT_TOPLEVEL}/"}"
                                    git -C "$_WT_ROOT" add -- "$_REL" 2>/dev/null || true
                                    ;;
                                *)
                                    echo "  ⚠️  Skipping non-repo path: $changed_file" >&2
                                    ;;
                            esac
                        done <<< "$_CHANGED_FILES"

                        if git -C "$_WT_ROOT" diff --cached --quiet 2>/dev/null; then
                            echo "  ⚠️  No staged changes — skipping roadmap commit"
                        else
                            git -C "$_WT_ROOT" commit -m "Update roadmap: mark #${ISSUE_NUM} as done" 2>/dev/null \
                                && echo "  ✅ Roadmap updated" \
                                || echo "  ⚠️  Roadmap commit failed — proceeding with merge"
                            git -C "$_WT_ROOT" push origin "$PR_BRANCH" 2>/dev/null \
                                && echo "  ✅ Roadmap commit pushed" \
                                || echo "  ⚠️  Roadmap push failed — proceeding with merge"
                        fi
                    fi
                fi
            fi
        fi
    fi
else
    echo "  Roadmap update skipped (--no-roadmap-update)"
fi

# --- Step 1.5: Review-loop merge gate (issue #269 PR F, Layer 1) ---
# Two preconditions from issue #269:
#   (a) the linked issue's latest `## Local Review` / `## Integrated Review`
#       entry correlates with the PR head SHA and is not changes-requested
#       (Local Review: **Verdict**: approved; Integrated Review: no open
#       must-fix / cross-confirmed finding);
#   (b) a PR comment carrying the pinned "## Decision summary" heading.
# Modes:
#   default        report-only — names what it would have refused, proceeds,
#                  and records a `## Merge (report-only)` entry
#   --enforce      refuses (exit 1, no merge) — workspace PRs only (owner's
#                  containment measure 2; project/package PRs stay
#                  report-only until #265 settles where their timelines live)
#   --force-unreviewed
#                  bypasses both conditions with a banner and records a
#                  `## Merge (unreviewed)` entry (all modes, all scopes)
# The durable record goes to the issue's progress.md in the PR's open
# worktree (via progress_append.sh, then pushed — this runs BEFORE the CI
# wait so the push is covered by it and never races the merge), or, when
# no worktree is open for the PR's repo, as a comment on the PR itself.
# A pass in report-only mode records nothing.
# Layer 2 (NOT implemented — Ask-First, ADR-0004): this gate is local-only.
# A "Merge" click on GitHub bypasses it entirely. The server-side complement
# would be a required status check on workspace PRs asserting the same two
# conditions from the PR's own data — a workflow step that reads the linked
# issue's progress.md at the head commit and the PR body/comments — and a
# branch-protection rule requiring it. Enabling that changes CI and branch
# protection, so it waits on the owner's explicit decision.
_gate_reasons=()
_gate_head=""
_gate_json=$(gh pr view "$PR_NUMBER" "${GH_REPO_ARGS[@]}" --json headRefOid,comments,body 2>/dev/null || echo "")
if [[ -n "$_gate_json" ]]; then
    _gate_head=$(jq -r '.headRefOid // empty' <<<"$_gate_json" 2>/dev/null || echo "")
fi
_gate_head_short="${_gate_head:0:7}"
# Which worktree holds the issue's timeline (same resolution Step 1 uses).
_gate_wt=""
if [[ -n "$PKG_WT_DIR" ]]; then
    _gate_wt="$PKG_WT_DIR"
else
    _gate_wt_repo="$ROOT_DIR"
    [[ "$WORKTREE_TYPE" == "project" ]] && _gate_wt_repo="$ROOT_DIR/project"
    _gate_wt=$(find_worktree_for_branch "$_gate_wt_repo" "$PR_BRANCH" || true)
fi
_gate_progress=""
[[ -n "$_gate_wt" && -f "$_gate_wt/.agent/work-plans/issue-${ISSUE_NUM}/progress.md" ]] \
    && _gate_progress="$_gate_wt/.agent/work-plans/issue-${ISSUE_NUM}/progress.md"
# (a) latest review entry at the head, approved. The reader's --type filter
# already includes `## External Review` as Integrated Review's recognized
# predecessor (ADR-0013); it is judged by the Integrated Review rule.
_gate_review=""
if [[ -z "$_gate_head" ]]; then
    _gate_reasons+=("could not read the PR head SHA")
elif [[ -z "$_gate_progress" ]]; then
    if [[ -n "$PKG_WT_DIR" ]]; then
        _gate_reasons+=("package worktree ${PKG_WT_DIR} carries no issue timeline (no progress.md for issue #${ISSUE_NUM})")
    else
        _gate_reasons+=("no progress.md for issue #${ISSUE_NUM} in an open worktree (looked for ${_gate_wt:-<no worktree found for $PR_BRANCH>})")
    fi
else
    _gate_read_rc=0
    _gate_read_json=$(python3 "$SCRIPT_DIR/progress_read.py" "$_gate_progress" --type "Local Review" --type "Integrated Review" 2>/dev/null) || _gate_read_rc=$?
    if [[ "$_gate_read_rc" -ne 0 ]]; then
        _gate_reasons+=("progress.md at $_gate_progress could not be parsed (progress_read.py exit $_gate_read_rc — malformed file, e.g. an unterminated code fence)")
    else
        _gate_review=$(jq -c --arg head "$_gate_head_short" '
            .entries | map(select(.base_type == "Local Review" or .base_type == "Integrated Review" or .base_type == "External Review")) | last // empty
            | {type, sha: (.correlation.sha // ""), verdict: (.fields.Verdict // ""),
               open_mustfix: ([.findings[] | select((.checked | not) and ((.source_hint // "") | test("^(must-fix|cross-confirmed)")))] | length),
               at_head: (((.correlation.sha // "")[0:7]) == $head)}' <<<"$_gate_read_json" 2>/dev/null || echo "")
    fi
    if [[ "$_gate_read_rc" -ne 0 ]]; then
        :
    elif [[ -z "$_gate_review" ]]; then
        _gate_reasons+=("no ## Local Review / ## Integrated Review entry in $_gate_progress")
    else
        _gate_r_type=$(jq -r '.type' <<<"$_gate_review")
        _gate_r_sha=$(jq -r '.sha' <<<"$_gate_review")
        if [[ "$(jq -r '.at_head' <<<"$_gate_review")" != "true" ]]; then
            _gate_reasons+=("latest ${_gate_r_type} entry is at \`${_gate_r_sha:-?}\`, not the PR head \`${_gate_head_short}\` (stale review)")
        elif [[ "$_gate_r_type" == "Local Review" && "$(jq -r '.verdict' <<<"$_gate_review")" != "approved" ]]; then
            _gate_reasons+=("latest Local Review at the head has **Verdict**: $(jq -r '.verdict' <<<"$_gate_review"), not approved")
        elif [[ "$_gate_r_type" != "Local Review" && "$(jq -r '.open_mustfix' <<<"$_gate_review")" != "0" ]]; then
            _gate_reasons+=("latest Integrated Review at the head still has $(jq -r '.open_mustfix' <<<"$_gate_review") open must-fix/cross-confirmed finding(s)")
        fi
    fi
fi
# (b) decision summary on the PR: in its body (the PR template's section)
# or in any comment.
if [[ -z "$_gate_json" ]] || ! jq -e '[(.body // ""), (.comments[]? | .body // "")] | map(select(test("(^|\\n)## Decision summary"))) | length > 0' <<<"$_gate_json" >/dev/null 2>&1; then
    _gate_reasons+=("no \"## Decision summary\" heading in the PR body or a PR comment")
fi

_gate_record() {  # <entry type> <one-line why>
    local etype="$1" why="$2" entry body_file mode
    # Plain string assembly, not `$([[ ... ]] && ...)`: under `set -e` a
    # false test as the last command of a substitution aborts the script.
    mode="report-only"
    [[ "$ENFORCE_MERGE_GATE" == true ]] && mode="enforce"
    [[ "$FORCE_UNREVIEWED" == true ]] && mode="${mode}, --force-unreviewed"
    entry="## ${etype}
**Status**: complete
**When**: $(date '+%Y-%m-%d %H:%M %:z')
**By**: merge_pr.sh (${AGENT_NAME:-unknown agent})

**PR**: #${PR_NUMBER} at \`${_gate_head_short:-unknown}\`
**Mode**: ${mode}
**Scope**: ${WORKTREE_TYPE:-package}
**Conditions**: ${why}"
    # Timeline path: only when the resolved worktree is itself a git repo
    # (a package worktree is a container of sibling repos, not a repo — it
    # has no issue timeline, so it always takes the PR-comment path) and an
    # agent identity is set (progress_append.sh refuses to commit without).
    local why_comment="no open worktree for the PR's repo" wt_top=""
    # "Is a repo" must mean the directory IS a repo root, not that some
    # ancestor is one: `git rev-parse --show-toplevel` walks up, and a
    # package worktree container lives under the workspace checkout, so the
    # naive check would resolve to the live main tree and commit there
    # (round-2 review). Package worktrees never take this path at all.
    if [[ -z "$PKG_WT_DIR" && -n "$_gate_wt" ]]; then
        wt_top=$(git -C "$_gate_wt" rev-parse --show-toplevel 2>/dev/null || true)
        if [[ -z "$wt_top" || "$(cd "$_gate_wt" && pwd -P)" != "$(cd "$wt_top" && pwd -P)" ]]; then
            wt_top=""
        fi
    fi
    if [[ -n "$wt_top" ]]; then
        if [[ -z "${AGENT_NAME:-}" || -z "${AGENT_EMAIL:-}" ]]; then
            why_comment="no agent identity set (source set_git_identity_env.sh) for a timeline commit"
        elif printf '%s\n' "$entry" | "$SCRIPT_DIR/progress_append.sh" -C "$_gate_wt" "$ISSUE_NUM" >/dev/null 2>&1; then
            if git -C "$_gate_wt" push -q origin "$PR_BRANCH" 2>/dev/null; then
                echo "  📝 ${etype} entry recorded in ${_gate_wt}/.agent/work-plans/issue-${ISSUE_NUM}/progress.md and pushed"
                return 0
            fi
            # Push refused: undo exactly that one-file commit so nothing is
            # left half-recorded, then fall back to the PR comment (one record,
            # never a stranded commit plus a comment).
            git -C "$_gate_wt" reset -q --soft HEAD~1 2>/dev/null || true
            git -C "$_gate_wt" restore --staged --worktree -- ".agent/work-plans/issue-${ISSUE_NUM}/progress.md" 2>/dev/null || true
            why_comment="the timeline commit could not be pushed to origin (undone locally)"
        else
            why_comment="progress_append.sh refused the timeline entry"
        fi
    elif [[ -n "$PKG_WT_DIR" ]]; then
        why_comment="package worktrees carry no issue timeline"
    fi
    body_file=$(mktemp)
    printf '%s\n\n---\n**Authored-By**: `%s`\n**Model**: `%s`\n' "$entry" "${AGENT_NAME:-merge_pr.sh}" "${AGENT_MODEL:-unknown}" > "$body_file"
    if gh pr comment "$PR_NUMBER" "${GH_REPO_ARGS[@]}" --body-file "$body_file" >/dev/null 2>&1; then
        echo "  📝 ${why_comment} — ${etype} record posted as a comment on ${PR_REPO_SLUG:-the PR}#${PR_NUMBER}"
    else
        echo "  ⚠️  ${etype} record could not be written anywhere (${why_comment}; PR comment failed)" >&2
    fi
    rm -f "$body_file"
}

if [[ "${#_gate_reasons[@]}" -eq 0 ]]; then
    echo "  ✅ Review gate: approved review at head \`${_gate_head_short}\` and a decision summary are present"
else
    _gate_why=$(IFS=';'; echo "${_gate_reasons[*]}")
    if [[ "$FORCE_UNREVIEWED" == true ]]; then
        echo "  ⚠️  --force-unreviewed: bypassing the review gate — ${_gate_why}"
        _gate_record "Merge (unreviewed)" "$_gate_why"
    elif [[ "$ENFORCE_MERGE_GATE" == true && "$WORKTREE_TYPE" == "workspace" ]]; then
        {
            echo "ERROR: review gate refused to merge PR #${PR_NUMBER}:"
            for _r in "${_gate_reasons[@]}"; do echo "  - $_r"; done
            echo "  Run the review loop (review-code / triage-reviews, then post the decision summary),"
            echo "  or pass --force-unreviewed to bypass with an audit record."
        } >&2
        exit 1
    else
        _gate_mode_note="report-only"
        [[ "$ENFORCE_MERGE_GATE" == true ]] && _gate_mode_note="report-only: --enforce applies to workspace PRs only until #265 settles project timelines"
        echo "  ⚠️  Review gate (${_gate_mode_note}): would have refused — ${_gate_why}"
        _gate_record "Merge (report-only)" "$_gate_why"
    fi
fi

# --- Step 2: Wait for CI ---
# When the roadmap-update step pushes a fresh commit, the new commit's
# CI hasn't started yet — `gh pr merge` below would fail with
# "Pull Request is not mergeable" until checks complete. Avoid the
# manual `gh pr checks --watch` round-trip by waiting here. --no-wait
# skips when the user knows CI is already green.
#
# `--fail-fast` exits as soon as any check fails (gh exit 8) so we
# don't waste time waiting for the rest. The error path captures gh's
# exit code, surfaces the PR URL, and aborts the merge with context.
if [[ "$NO_WAIT" == false ]]; then
    echo "  Waiting for CI..."
    if gh pr checks "$PR_NUMBER" "${GH_REPO_ARGS[@]}" --watch --fail-fast; then
        echo "  ✅ CI checks passed"
    else
        _wait_rc=$?
        _pr_url=$(gh pr view "$PR_NUMBER" "${GH_REPO_ARGS[@]}" --json url --jq '.url' 2>/dev/null || echo "")
        {
            echo "ERROR: CI checks failed (gh exit $_wait_rc)"
            [[ -n "$_pr_url" ]] && echo "  See: $_pr_url"
            echo "  Fix the failure and re-run, or pass --no-wait to skip the CI wait."
        } >&2
        exit 1
    fi
else
    echo "  CI wait skipped (--no-wait)"
fi

# --- Step 3: Merge ---
# GH_REPO_ARGS was set during PR resolution above (-R <repo> for a package
# or project PR, empty for a workspace PR). Don't re-resolve.
echo "  Merging PR..."
if ! gh pr merge "$PR_NUMBER" "${GH_REPO_ARGS[@]}" --merge; then
    echo "ERROR: Merge failed for PR #${PR_NUMBER}" >&2
    exit 1
fi
echo "  ✅ PR merged"

if [[ "$IS_PACKAGE_PR" == true ]]; then
    # --- Step 4 (package PR): sibling-PR cleanup rule (ADR-0012) ---
    # Delete the merged branch and sync in its own repo; check every OTHER
    # manifest entry for an open PR on its branch; if any is open — OR if
    # the check itself could not be completed (gh failure: network, auth,
    # rate limit) — keep the worktree and name why, otherwise remove it via
    # worktree_remove.sh (which itself preflights every entry for
    # uncommitted changes). Failing the check open (treating "couldn't ask
    # gh" as "no open PR") would let an outage remove a worktree whose
    # sibling PR is still open — nothing would be lost (branches survive in
    # the origin repos), but it's a silent failure, so this fails closed
    # instead.
    echo "  Package PR merged — checking sibling package PRs before cleanup..."
    _entries="$(wt_read_manifest "$PKG_WT_DIR")"
    declare -a _SIBLING_BLOCKERS=()
    declare -a _SIBLING_CHECK_FAILURES=()
    _OWN_ORIGIN=""
    while IFS=$'\t' read -r _m_origin _m_rel _m_branch; do
        [[ -z "$_m_origin" ]] && continue
        _m_remote="$(git -C "$_m_origin" remote get-url origin 2>/dev/null || echo "")"
        _m_slug="$(extract_gh_slug "$_m_remote")"
        if [[ "$_m_slug" == "$PR_REPO_SLUG" ]] && [[ "$_m_branch" == "$PR_BRANCH" ]]; then
            _OWN_ORIGIN="$_m_origin"
            continue
        fi
        if [[ -z "$_m_slug" ]]; then
            # Unverifiable sibling: fail closed, same as a gh failure below.
            _SIBLING_CHECK_FAILURES+=("${_m_origin} (branch: ${_m_branch}): no resolvable GitHub remote (origin='${_m_remote:-unset}')")
            continue
        fi
        _pr_list_err_file="$(mktemp)"
        _pr_list_rc=0
        _open_count="$(gh pr list -R "$_m_slug" --head "$_m_branch" --state open --json number --jq 'length' 2>"$_pr_list_err_file")" || _pr_list_rc=$?
        _pr_list_err="$(<"$_pr_list_err_file")"
        rm -f "$_pr_list_err_file"
        if [[ $_pr_list_rc -ne 0 ]]; then
            _SIBLING_CHECK_FAILURES+=("${_m_slug} (branch: ${_m_branch}): ${_pr_list_err:-gh pr list failed with no output}")
            continue
        fi
        if [[ "${_open_count:-0}" -gt 0 ]]; then
            _SIBLING_BLOCKERS+=("${_m_slug} (branch: ${_m_branch})")
        fi
    done <<< "$_entries"
    unset _m_origin _m_rel _m_branch _m_remote _m_slug _open_count _pr_list_err_file _pr_list_rc _pr_list_err

    # Delete the REMOTE branch and fast-forward the own repo's main checkout
    # now — neither needs the branch to be free of a local checkout. The
    # LOCAL branch is still checked out in this (not-yet-removed) package
    # worktree entry, so `git branch -d` would just fail every time (git
    # refuses to delete a branch checked out in any worktree, linked or
    # main) — deferred to the post-removal sweep below, reached only when
    # no sibling PR blocks cleanup. If a sibling keeps the worktree around,
    # the local branch stays too, correctly, since that entry's checkout is
    # still live.
    # Neither step is allowed to fail silently: a network, permission, or
    # non-fast-forward failure is reported with git's own stderr and marks
    # the cleanup incomplete (final summary below), rather than letting the
    # script go on to report an unqualified success.
    _CLEANUP_INCOMPLETE=false
    _WORKTREE_KEPT=false
    if [[ -n "$_OWN_ORIGIN" ]]; then
        _git_err=""
        # GitHub may auto-delete the head branch on merge; an absent ref is
        # the desired end state, not a failure. Only a ref that is still
        # there (or an unreachable remote) goes through push --delete.
        _lsr_rc=0
        git -C "$_OWN_ORIGIN" ls-remote --exit-code --heads origin "$PR_BRANCH" >/dev/null 2>&1 || _lsr_rc=$?
        if [[ $_lsr_rc -eq 2 ]]; then
            echo "  ✅ Remote branch already gone ($PR_REPO_SLUG, auto-deleted on merge)"
        elif _git_err="$(git -C "$_OWN_ORIGIN" push origin --delete "$PR_BRANCH" 2>&1)"; then
            echo "  ✅ Remote branch deleted ($PR_REPO_SLUG)"
        else
            echo "  ⚠️  Could not delete remote branch '$PR_BRANCH' in $PR_REPO_SLUG:" >&2
            echo "     ${_git_err:-no output}" >&2
            _CLEANUP_INCOMPLETE=true
        fi
        unset _lsr_rc
        if _git_err="$(git -C "$_OWN_ORIGIN" pull --ff-only 2>&1)"; then
            echo "  ✅ $PR_REPO_SLUG synced"
        else
            echo "  ⚠️  Could not fast-forward $PR_REPO_SLUG's checkout at $_OWN_ORIGIN:" >&2
            echo "     ${_git_err:-no output}" >&2
            _CLEANUP_INCOMPLETE=true
        fi
        unset _git_err
    else
        echo "  ⚠️  Could not resolve $PR_REPO_SLUG's own manifest entry — remote branch/sync left untouched" >&2
        _CLEANUP_INCOMPLETE=true
    fi

    if [[ "${#_SIBLING_BLOCKERS[@]}" -gt 0 ]] || [[ "${#_SIBLING_CHECK_FAILURES[@]}" -gt 0 ]]; then
        _WORKTREE_KEPT=true
        echo "  ⚠️  Keeping worktree $PKG_WT_DIR — sibling package PR(s) still open or unchecked:"
        for _b in "${_SIBLING_BLOCKERS[@]}"; do
            echo "     - $_b"
        done
        for _b in "${_SIBLING_CHECK_FAILURES[@]}"; do
            echo "     - $_b — COULD NOT CHECK for an open PR (gh failed)"
        done
        if [[ "${#_SIBLING_CHECK_FAILURES[@]}" -gt 0 ]]; then
            echo "  Once you've confirmed those repos have no open PR, rerun:"
            echo "    $SCRIPT_DIR/worktree_remove.sh --issue $PKG_WT_ISSUE --type project --project $PKG_WT_PROJECT"
            echo "  then delete the local branches it lists (it prints one 'git -C <repo> branch -d' per repo)."
        fi
    else
        echo "  Removing worktree..."
        cd "$ROOT_DIR"
        if "$SCRIPT_DIR/worktree_remove.sh" --issue "$PKG_WT_ISSUE" --type project --project "$PKG_WT_PROJECT"; then
            echo "  ✅ Worktree removed"
            # Sweep every manifest entry (not just the one just merged) for
            # a local branch whose remote counterpart is already gone. A PR
            # that merged earlier, while a sibling PR was still open, only
            # got its remote branch deleted at the time (the local one was
            # deferred, above) — now that the whole worktree is gone, every
            # entry's checkout is free, so finish deleting whichever local
            # branches the remote has already dropped. Anything still on
            # its origin is left alone and named.
            while IFS=$'\t' read -r _cm_origin _cm_rel _cm_branch; do
                [[ -z "$_cm_origin" ]] && continue
                [[ -z "$_cm_branch" ]] && continue
                git -C "$_cm_origin" show-ref --verify --quiet "refs/heads/$_cm_branch" || continue
                _cm_remote="$(git -C "$_cm_origin" remote get-url origin 2>/dev/null || echo "")"
                _cm_slug="$(extract_gh_slug "$_cm_remote")"
                _cm_lsremote_rc=0
                git -C "$_cm_origin" ls-remote --exit-code --heads origin "$_cm_branch" >/dev/null 2>&1 || _cm_lsremote_rc=$?
                case $_cm_lsremote_rc in
                    0)
                        echo "  ℹ️  Branch '$_cm_branch' still exists on origin (${_cm_slug:-$_cm_origin}) — leaving the local branch in place"
                        ;;
                    2)
                        # Safe delete on purpose: a branch with unmerged work
                        # (a sibling PR closed without merging, say) is kept
                        # and the reason surfaced, never silently skipped.
                        if _cm_err="$(git -C "$_cm_origin" branch -d "$_cm_branch" 2>&1)"; then
                            echo "  ✅ Local branch deleted ($_cm_branch, ${_cm_slug:-$_cm_origin})"
                        else
                            echo "  ⚠️  Kept local branch '$_cm_branch' in ${_cm_slug:-$_cm_origin} — remote is gone but:" >&2
                            echo "     ${_cm_err:-git branch -d failed with no output}" >&2
                            echo "     Delete it with: git -C $_cm_origin branch -D $_cm_branch   (if that work is truly abandoned)" >&2
                        fi
                        ;;
                    *)
                        echo "  ⚠️  Could not check whether '$_cm_branch' still exists on origin (${_cm_slug:-$_cm_origin}) — leaving the local branch in place" >&2
                        ;;
                esac
            done <<< "$_entries"
            unset _cm_origin _cm_rel _cm_branch _cm_remote _cm_slug _cm_lsremote_rc
        else
            echo "  ⚠️  Worktree removal failed — check for uncommitted changes" >&2
            _CLEANUP_INCOMPLETE=true
        fi
    fi
    unset _entries
elif [[ "${REPO_KIND:-}" == "package" ]]; then
    # --- Step 4 (package repo, no matching package worktree) ---
    # An explicit --repo that is neither the workspace nor project/ and has
    # no .worktree-repos entry on this branch: nothing local belongs to this
    # PR, so there is nothing to remove. Never fall through to the legacy
    # path — worktree_remove.sh --issue N --type project would match some
    # OTHER repo's issue-N worktree.
    echo "  No local package worktree has $PR_REPO_SLUG on branch '$PR_BRANCH' — nothing local to clean up."
    echo "  (Remote branch left as-is; delete it on GitHub if the merge did not.)"
else
    # --- Step 4 (workspace / legacy single-repo project PR): unchanged ---
    if [[ -n "$WORKTREE_TYPE" ]]; then
        echo "  Removing worktree..."
        # Must run from root, not from inside the worktree
        cd "$ROOT_DIR"
        if "$SCRIPT_DIR/worktree_remove.sh" --issue "$ISSUE_NUM" --type "$WORKTREE_TYPE"; then
            echo "  ✅ Worktree removed"
        else
            echo "  ⚠️  Worktree removal failed — check for uncommitted changes" >&2
            _CLEANUP_INCOMPLETE=true
        fi
    fi

    # --- Step 5: Delete branches ---
    echo "  Cleaning up branches..."
    # Use [[ -e ]] (not [[ -d ]]) to handle submodule layouts where project/.git
    # is a file containing `gitdir:` rather than a directory.
    if [[ "$WORKTREE_TYPE" == "project" ]] && [[ -e "$ROOT_DIR/project/.git" ]]; then
        BRANCH_REPO="$ROOT_DIR/project"
    else
        BRANCH_REPO="$ROOT_DIR"
    fi
    git -C "$BRANCH_REPO" branch -d "$PR_BRANCH" 2>/dev/null && echo "  ✅ Local branch deleted" || true
    git -C "$BRANCH_REPO" push origin --delete "$PR_BRANCH" 2>/dev/null && echo "  ✅ Remote branch deleted" || true

    # --- Step 6: Sync ---
    echo "  Syncing main..."
    git pull --ff-only
    echo "  ✅ Workspace synced"

    # Also sync project repo for project-type merges
    if [[ "$WORKTREE_TYPE" == "project" ]] && [[ -e "$ROOT_DIR/project/.git" ]]; then
        echo "  Syncing project..."
        git -C "$ROOT_DIR/project" pull --ff-only 2>/dev/null && echo "  ✅ Project synced" || true
    fi
fi

echo ""
echo "========================================"
if [[ "${_CLEANUP_INCOMPLETE:-false}" == true ]]; then
    echo "⚠️  Done: PR #${PR_NUMBER} merged, but cleanup incomplete — see warnings above"
elif [[ "${_WORKTREE_KEPT:-false}" == true ]]; then
    echo "✅ Done: PR #${PR_NUMBER} merged; worktree kept until the sibling package PR(s) above are resolved"
else
    echo "✅ Done: PR #${PR_NUMBER} merged, cleaned up, and synced"
fi
echo "========================================"

# Warn if the caller's shell may be in a deleted directory
if [[ -n "$WORKTREE_TYPE" ]]; then
    echo ""
    echo "NOTE: If you ran this from inside the worktree, run:"
    echo "  cd $ROOT_DIR"
fi
