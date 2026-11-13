#!/bin/bash
# .agent/scripts/merge_pr.sh
# Merge a PR, remove its worktree, delete the branch, and sync main.
#
# Usage:
#   .agent/scripts/merge_pr.sh --pr <N> [--type workspace|project] [--no-roadmap-update] [--no-wait] [--allow-pending-review]
#   .agent/scripts/merge_pr.sh --pr <N> --repo <owner/repo> [--no-roadmap-update] [--no-wait] [--allow-pending-review]
#   .agent/scripts/merge_pr.sh --pr <owner/repo#N> [--no-roadmap-update] [--no-wait] [--allow-pending-review]
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
#   1.5. Review-loop merge gate (records a Merge entry; see below)
#   2. Decide the CI target SHA — the reviewed head (pre-Step-1) when the
#      only diff since then is bookkeeping: paths this run committed itself
#      (the roadmap file, the gate's own progress.md record) or merge-time
#      document files whoever pushed them (any work-plan dir, the roadmap;
#      #323), else the actual current head (issue #284); this decision
#      always runs. Then wait
#      for CI on that target SHA — --no-wait skips only this CI poll — and
#      let mergeability settle, which always runs (#290): this script's own
#      Step 1 / 1.5 pushes make GitHub recompute mergeability whether or
#      not CI is waited on. Copilot's review check-run is never CI (#300):
#      its conclusion is ignored, but while it is still running the wait
#      holds the merge until it completes (or the CI timeout) unless
#      --allow-pending-review (or --no-wait) opts in. Until the review
#      commit's check-runs have been read once, the hold is unresolved:
#      no merge, and a refusal at the CI grace deadline (#323).
#   3. Merge the PR (--merge strategy; one retry on a "not mergeable"
#      refusal, after re-polling mergeability once)
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
# The wait step (issue #186; SHA-targeted poll and mergeability settle
# added by #284/#271) is covered by automated tests, not manual steps:
# see test_merge_pr_gate.sh's "CI wait" and "mergeability" cases, which
# drive a stubbed `gh api`/`gh pr view` through no-CI, not-yet-registered,
# pending, failed, and UNKNOWN-mergeable sequences without any network,
# auth, or throwaway PR dependency.
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
# shellcheck source=_resolve_default_branch.sh
source "$SCRIPT_DIR/_resolve_default_branch.sh"
# shellcheck source=_bookkeeping.sh
source "$SCRIPT_DIR/_bookkeeping.sh"
# records_path: the records gate the gate's timeline lookup passes (issue 429)
# shellcheck source=_resolve_work_plans_dir.sh
source "$SCRIPT_DIR/_resolve_work_plans_dir.sh"

PR_NUMBER=""
WORKTREE_TYPE=""
REPO_ARG=""
REPO_KIND=""   # workspace | project | package — derived from --repo when given
PROJECT_ARG="" # registered project name; selects among package worktrees that
               # host the same repo+branch under different instances
NO_ROADMAP_UPDATE=false
NO_WAIT=false
# Review-loop merge gate (issue #269 PR F). Enforced by default on
# workspace PRs since #300 (owner rule: a merge only happens when everything
# is clean unless he says skip): a gate gap refuses with exit 1 and no
# merge. --report-only restores the earlier behaviour — print what would
# have been refused, record it, proceed. --enforce is kept as an explicit
# alias of the default. Project/package PRs stay report-only in every mode
# until #265 settles where their timelines live.
ENFORCE_MERGE_GATE=true
FORCE_UNREVIEWED=false
# A code-review check-run that is still running (Copilot's, #300) holds the
# merge by default even when CI is green or absent: merging past an
# unfinished review is opt-in (--allow-pending-review). --no-wait skips the
# whole wait and so also opts in.
ALLOW_PENDING_REVIEW=false

USAGE="Usage: $0 --pr <N|owner/repo#N> [--repo owner/repo] [--project <name>] [--type workspace|project] [--no-roadmap-update] [--no-wait] [--allow-pending-review] [--report-only|--enforce] [--force-unreviewed]"

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
        --allow-pending-review)
            ALLOW_PENDING_REVIEW=true; shift ;;
        --enforce)
            ENFORCE_MERGE_GATE=true; shift ;;
        --report-only)
            ENFORCE_MERGE_GATE=false; shift ;;
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

# ---------------------------------------------------- user-tier guard (#265) ---
# This script is promoted to the user tier (.agent/user_tier_scripts.txt), so
# it can be invoked from any cwd on the machine. Refuse outside the workspace
# checkout and outside every registered project root, BEFORE any git/gh call,
# so a stray invocation in an unrelated repo touches nothing. See
# docs/decisions/0016-session-roots-and-the-user-tier.md.
registry_require_root "$ROOT_DIR" || exit 1

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
PJ_REPO_ROOT=""
# The project's checkout root (#265): an explicit --project name, the
# legacy project/ symlink, or the single registered non-parent project —
# same precedence worktree_create.sh applies. Silent when nothing
# resolves (no project configured at all — unchanged pre-#265 behaviour);
# --repo/a qualified --pr skips this whole block, same as before.
if [[ -z "$REPO_ARG" ]]; then
    _pj_root_err="$(mktemp)"
    if PJ_REPO_ROOT="$(wt_resolve_project_repo_root "$ROOT_DIR" "$PROJECT_ARG" 2>"$_pj_root_err")"; then
        :
    else
        PJ_REPO_ROOT=""
        if [[ "$WORKTREE_TYPE" == "project" ]]; then
            # --type project was explicit, so a project root is required —
            # falling through with PJ_REPO_ROOT empty would let later code
            # default to $ROOT_DIR/project (PJ_ROOT_EFFECTIVE, below)
            # regardless of why resolution failed (ambiguous registration,
            # no --project given, or nothing configured at all), silently
            # operating on the wrong (or a nonexistent) checkout instead of
            # failing fast.
            cat "$_pj_root_err" >&2
            rm -f "$_pj_root_err"
            unset _pj_root_err
            exit 1
        fi
    fi
    rm -f "$_pj_root_err"
    unset _pj_root_err
fi
if [[ -n "$PJ_REPO_ROOT" ]] && [[ -e "$PJ_REPO_ROOT/.git" ]]; then
    PJ_REMOTE=$(git -C "$PJ_REPO_ROOT" remote get-url origin 2>/dev/null || echo "")
    if [[ -z "$REPO_ARG" ]] && [[ -z "$PJ_REMOTE" ]] && [[ "$WORKTREE_TYPE" != "workspace" ]]; then
        echo "ERROR: $PJ_REPO_ROOT has no 'origin' remote configured." >&2
        echo "  Cannot resolve project PRs. Configure the remote, or pass" >&2
        echo "  --type workspace if this is intentionally workspace-only." >&2
        exit 1
    fi
fi
# The one project root every later lookup uses (#379): the Step 1 roadmap
# worktree lookup, the review gate's timeline lookup, and the main-tree
# guards in front of the gate's ancestry check and its Step 1.5 record
# commit. One variable, so these can never disagree about where a project
# PR's worktree lives; the legacy project/ fallback covers runs where
# nothing resolved (no project configured, or --repo given).
PJ_ROOT_EFFECTIVE="${PJ_REPO_ROOT:-$ROOT_DIR/project}"

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
# Scan every `.worktree-repos` manifest for an entry whose owning repo
# matches PR_REPO_SLUG and whose recorded branch matches PR_BRANCH:
# under every registered non-parent root's worktree dir (#265), and under
# the legacy fallback worktrees/project/*/*/ for still-unregistered
# projects. Directory names are never parsed for this shape — only the
# manifest's entries (and header) are read. A miss here (no manifest
# matches, e.g. a legacy single-repo project PR or a workspace PR) falls
# back to find_worktree_for_branch below, unchanged from before #252 PR 2.
PKG_WT_DIR=""
PKG_WT_PROJECT=""
PKG_WT_ISSUE=""
# The header's base= (issue 429): the base the owning repository's branch
# started from and its pull request should target. Empty for a worktree
# that records none.
PKG_WT_BASE=""
# The owning checkout's path relative to the worktree (issue 429 part 2):
# the matched entry's own relative path when the PR's branch is the owning
# repository's feature/issue-<N>, else empty (a sibling repository's PR).
# Carried inside the _PKG_MATCHES record, like the base, so a later manifest
# or the --project filter cannot leave it describing another worktree.
PKG_OWN_REL=""
declare -a _PKG_MATCHES=()
if [[ -n "$PR_REPO_SLUG" ]]; then
    declare -a _PKG_MANIFESTS=()
    while IFS=$'\t' read -r _reg_name _reg_dir; do
        [[ -z "$_reg_dir" ]] && continue
        for _m in "$_reg_dir"/*/.worktree-repos; do
            [[ -f "$_m" ]] && _PKG_MANIFESTS+=("$_m")
        done
    done < <(wt_registry_worktree_dirs "$ROOT_DIR" 2>/dev/null; wt_legacy_worktree_dirs "$ROOT_DIR" 2>/dev/null)
    unset _reg_name _reg_dir _m
    for _manifest in "${_PKG_MANIFESTS[@]:-}"; do
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
            _hdr_base="$(sed -n 's/.* base=\([^ ]*\).*/\1/p' <<< "$_header")"
            # --project narrows to one registered instance; otherwise collect
            # every match — the same repo+branch can be worktreed under more
            # than one ros2_colcon instance (each has its own checkout), and
            # glob order must not silently pick one. The manifest header
            # stores the RESOLVED instance name (worktree_create resolves a
            # parent such as demo to demo-rolling before writing it), so the
            # selector is resolved the same way before comparing; the raw
            # --project value stays for user-facing messages.
            if [[ -n "$PROJECT_ARG" ]]; then
                _PROJECT_SEL="$(registry_resolve_project_arg "$ROOT_DIR" "$PROJECT_ARG" 2>/dev/null || echo "$PROJECT_ARG")"
                if [[ "$_hdr_project" != "$_PROJECT_SEL" ]]; then
                    continue
                fi
            fi
            # The owning entry is the one on feature/issue-<N> (the adapter's
            # branch rule, the same one issue_checkout_of applies); a sibling
            # repository's entry (feature/<repo>-issue-<N>) records none.
            _own_rel=""
            [[ "$_m_branch" == "feature/issue-${ISSUE_NUM}" ]] && _own_rel="$_m_rel"
            # One tab-separated record per match, read back below with a
            # tab IFS, which collapses empty fields: an empty value is
            # written as "-" (no project, issue, branch or path is named
            # "-") and mapped back on read, so a later field never shifts left.
            _PKG_MATCHES+=("$_wtdir"$'\t'"${_hdr_project:--}"$'\t'"${_hdr_issue:--}"$'\t'"${_hdr_base:--}"$'\t'"${_own_rel:--}")
        fi
    done
    if [[ "${#_PKG_MATCHES[@]}" -gt 1 ]]; then
        echo "ERROR: $PR_REPO_SLUG branch '$PR_BRANCH' is worktreed under more than one project:" >&2
        for _pm in "${_PKG_MATCHES[@]}"; do
            IFS=$'\t' read -r _pm_dir _pm_project _pm_issue _pm_base _pm_own <<< "$_pm"
            [[ "$_pm_project" == "-" ]] && _pm_project=""
            echo "  --project $_pm_project   ($_pm_dir)" >&2
        done
        echo "  Pass --project <name> to say which one this merge cleans up. Nothing was merged." >&2
        exit 2
    elif [[ "${#_PKG_MATCHES[@]}" -eq 1 ]]; then
        IFS=$'\t' read -r PKG_WT_DIR PKG_WT_PROJECT PKG_WT_ISSUE PKG_WT_BASE PKG_OWN_REL <<< "${_PKG_MATCHES[0]}"
        [[ "$PKG_WT_PROJECT" == "-" ]] && PKG_WT_PROJECT=""
        [[ "$PKG_WT_ISSUE" == "-" ]] && PKG_WT_ISSUE=""
        [[ "$PKG_WT_BASE" == "-" ]] && PKG_WT_BASE=""
        [[ "$PKG_OWN_REL" == "-" ]] && PKG_OWN_REL=""
    fi
    unset _manifest _wtdir _entries _found _m_origin _m_rel _m_branch _m_remote _m_slug _header _hdr_project _hdr_issue _hdr_base _own_rel _pm _pm_dir _pm_project _pm_issue _pm_base _pm_own
fi
IS_PACKAGE_PR=false
[[ -n "$PKG_WT_DIR" ]] && IS_PACKAGE_PR=true

# --- Capture the reviewed head, before any push this run makes (#284) ---
# This is the SHA a `## Local Review` / `## Integrated Review` entry
# correlates with, and the SHA CI is already considered verified for.
# Read once here and reuse it for the Step 1.5 gate's own headRefOid /
# comments / body fetch below, instead of a second `gh pr view` call.
_head_json=$(gh pr view "$PR_NUMBER" "${GH_REPO_ARGS[@]}" --json headRefOid,comments,body,baseRefName 2>/dev/null || echo "")
HEAD_REVIEWED=""
[[ -n "$_head_json" ]] && HEAD_REVIEWED=$(jq -r '.headRefOid // empty' <<<"$_head_json" 2>/dev/null || echo "")
# The branch the PR targets, from the same read (issue 429): the gate
# compares it with a package worktree's recorded base, and Step 4 pulls the
# owning repository's own checkout only when it sits on it. Empty when it
# could not be read.
PR_BASE_REF=""
[[ -n "$_head_json" ]] && PR_BASE_REF=$(jq -r '.baseRefName // empty' <<<"$_head_json" 2>/dev/null || echo "")

# Paths this run's own steps commit, so the Step 3 CI-target decision can
# tell "the head moved because this script updated a document it owns" from
# "the head moved for any other reason". Populated only when the commit
# actually lands (not merely staged).
declare -a _STEP1_COMMITTED_PATHS=()
_STEP15_COMMITTED_PATH=""
# The SHA of every commit this run makes on the PR branch (Step 1's roadmap
# commit, Step 1.5's record commit), so the CI wait can find the head
# before this run's own pushes (the review-hold SHA, #323). Added when the
# commit lands, not when its own push does: Step 1's push can fail and
# Step 1.5's push then carries that commit to origin. Removed again only
# when the commit itself is undone (Step 1.5's refused push).
declare -a _RUN_COMMITTED_SHAS=()

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
        [[ "$WORKTREE_TYPE" == "project" ]] && _WT_REPO="$PJ_ROOT_EFFECTIVE"
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
                        declare -a _ROADMAP_STAGED_PATHS=()
                        while IFS= read -r changed_file; do
                            [[ -z "$changed_file" ]] && continue
                            case "$changed_file" in
                                "${_WT_TOPLEVEL}"/*)
                                    _REL="${changed_file#"${_WT_TOPLEVEL}/"}"
                                    git -C "$_WT_ROOT" add -- "$_REL" 2>/dev/null && _ROADMAP_STAGED_PATHS+=("$_REL")
                                    ;;
                                *)
                                    echo "  ⚠️  Skipping non-repo path: $changed_file" >&2
                                    ;;
                            esac
                        done <<< "$_CHANGED_FILES"

                        if git -C "$_WT_ROOT" diff --cached --quiet 2>/dev/null; then
                            echo "  ⚠️  No staged changes — skipping roadmap commit"
                        else
                            if git -C "$_WT_ROOT" commit -m "Update roadmap: mark #${ISSUE_NUM} as done" 2>/dev/null; then
                                echo "  ✅ Roadmap updated"
                                [[ "${#_ROADMAP_STAGED_PATHS[@]}" -gt 0 ]] && _STEP1_COMMITTED_PATHS+=("${_ROADMAP_STAGED_PATHS[@]}")
                                _step1_sha=$(git -C "$_WT_ROOT" rev-parse HEAD 2>/dev/null || echo "")
                                [[ -n "$_step1_sha" ]] && _RUN_COMMITTED_SHAS+=("$_step1_sha")
                            else
                                echo "  ⚠️  Roadmap commit failed — proceeding with merge"
                            fi
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
#       entry correlates with the PR head SHA — equal to it, or an ancestor
#       with only progress.md / roadmap commits in between (#286) — and is
#       not changes-requested
#       (Local Review: **Verdict**: approved; Integrated Review: no open
#       must-fix / cross-confirmed finding);
#   (b) a PR comment carrying the pinned "## Decision summary" heading.
# Modes:
#   default        enforce (#300) — refuses (exit 1, no merge, no entry) —
#                  workspace PRs only (owner's containment measure 2;
#                  project/package PRs stay report-only until #265 settles
#                  where their timelines live). --enforce is an explicit
#                  alias of this default.
#   --report-only  names what it would have refused, proceeds, and records
#                  a `## Merge (report-only)` entry (the pre-#300 default)
#   --force-unreviewed
#                  bypasses both conditions with a banner and records a
#                  `## Merge (unreviewed)` entry (all modes, all scopes)
# The durable record goes to the issue's progress.md in the PR's open
# worktree (via progress_append.sh, then pushed), or, when no worktree is
# open for the PR's repo, as a comment on the PR itself. This push moves
# the PR head — Step 2 below (issue #284) is what actually keeps that push
# from racing the merge: it targets CI at the pre-push reviewed head when
# the only diff is this script's own committed paths (this record among
# them), instead of waiting on "whatever runs exist" for a head that has
# already moved. A pass in report-only mode records nothing.
# Layer 2 (NOT implemented — Ask-First, ADR-0004): this gate is local-only.
# A "Merge" click on GitHub bypasses it entirely. The server-side complement
# would be a required status check on workspace PRs asserting the same two
# conditions from the PR's own data — a workflow step that reads the linked
# issue's progress.md at the head commit and the PR body/comments — and a
# branch-protection rule requiring it. Enabling that changes CI and branch
# protection, so it waits on the owner's explicit decision.

_gate_reasons=()
# One rule for every gate reason (#309): each value it interpolates — a path,
# a SHA, an entry heading, a **Status** / **Verdict** value, a count — goes
# through _bk_display (_bookkeeping.sh), so the joined reasons are safe
# ASCII on one line. They are printed and committed as the `**Conditions**:`
# of a `## Merge (...)` record, and progress_read.py must still parse it.
# Reuse the pre-Step-1 read (#284) instead of a second `gh pr view` call.
# This is also correctness-bearing: the review entry the gate looks for
# correlates with the head as of BEFORE this run's own roadmap push, not
# whatever the head has moved to by the time Step 1.5 runs.
_gate_json="$_head_json"
_gate_head="$HEAD_REVIEWED"
_gate_head_short="${_gate_head:0:7}"
# Which worktree holds the issue's timeline (same resolution Step 1 uses).
# A package PR (issue 429 part 2): the owning repository's PR reads and
# records in the owning checkout (A), the manifest entry it matched; a
# sibling repository's PR keeps the container, which is no checkout, so it
# reads no timeline and its record goes on its own PR. _GATE_PKG_ROLE is
# "owning", "sibling" or empty (not a package PR).
_gate_wt=""
_GATE_PKG_ROLE=""
if [[ -n "$PKG_WT_DIR" ]]; then
    if [[ -n "$PKG_OWN_REL" ]]; then
        _GATE_PKG_ROLE="owning"
        if [[ "$PKG_OWN_REL" == "." ]]; then
            _gate_wt="$PKG_WT_DIR"
        else
            _gate_wt="$PKG_WT_DIR/$PKG_OWN_REL"
        fi
    else
        _GATE_PKG_ROLE="sibling"
        _gate_wt="$PKG_WT_DIR"
    fi
else
    _gate_wt_repo="$ROOT_DIR"
    [[ "$WORKTREE_TYPE" == "project" ]] && _gate_wt_repo="$PJ_ROOT_EFFECTIVE"
    _gate_wt=$(find_worktree_for_branch "$_gate_wt_repo" "$PR_BRANCH" || true)
fi
# The owning checkout must be its repository's top folder (resolved). A
# folder that is gone, or that exists but is no longer a checkout, would
# otherwise resolve through `rev-parse --show-toplevel` to an enclosing
# repository, which would then supply the timeline, the ancestry check, the
# CI target and the record commit. _GATE_OWN_PROBLEM says which, empty when
# the checkout is sound; the gate then reads no timeline there, _ci_wt stays
# empty, and the record goes on the PR.
_GATE_OWN_PROBLEM=""
if [[ "$_GATE_PKG_ROLE" == "owning" ]]; then
    if [[ ! -d "$_gate_wt" ]]; then
        _GATE_OWN_PROBLEM="the owning checkout $_gate_wt does not exist"
    else
        _gate_own_top=$(git -C "$_gate_wt" rev-parse --show-toplevel 2>/dev/null || true)
        if [[ -z "$_gate_own_top" || "$(cd "$_gate_wt" && pwd -P)" != "$(cd "$_gate_own_top" && pwd -P)" ]]; then
            _GATE_OWN_PROBLEM="the owning checkout $_gate_wt is not a git checkout's top folder"
        fi
    fi
fi
# Prints why progress.md in <checkout> is not as committed, or nothing:
# untracked, or changed in the index, the working tree or both (an edit, a
# deletion). The owning checkout's read guard uses it: such a timeline may
# hold entries origin does not have, and a record commit there would take
# the uncommitted text with it.
_gate_rec_dirty() {  # <checkout>
    local wt="$1" rel st x y what=""
    rel=".agent/work-plans/issue-${ISSUE_NUM}/progress.md"
    # A symlink or a non-file there is _gate_rec_unsafe's case (left as
    # found, its own reason), not this one.
    [[ -L "$wt/$rel" || ( -e "$wt/$rel" && ! -f "$wt/$rel" ) ]] && return 0
    # assume-unchanged (tag in lower case) or skip-worktree (S, s): git
    # status hides the file's changes and git add takes none of them, so
    # the record commit would be empty while its append stays behind.
    case "$(git -C "$wt" ls-files -v -- "$rel" 2>/dev/null | cut -c1)" in
        [[:lower:]]|S) echo "$rel in $wt is marked assume-unchanged or skip-worktree in the index, so its changes are not known"; return 0 ;;
    esac
    st=$(git -C "$wt" status --porcelain=v1 --untracked-files=all -- "$rel" 2>/dev/null) || { echo "git status could not be read for $rel in $wt"; return 0; }
    [[ -z "$st" ]] && return 0
    x="${st:0:1}" y="${st:1:1}"
    if [[ "$x$y" == "??" ]]; then
        what="is untracked"
    elif [[ "$x" != " " && "$y" != " " ]]; then
        what="has staged and unstaged changes"
    elif [[ "$x" != " " ]]; then
        what="has staged changes"
    else
        what="has unstaged changes"
    fi
    echo "$rel in $wt $what"
}
# A sound owning checkout's timeline is the PR branch's only when the
# checkout has that branch checked out and its HEAD equals origin's copy of
# it. Otherwise its progress.md may be another branch's, an older one that
# lacks a newer review (behind or diverged), or hold entries origin does not
# have (ahead: unpushed commits; or progress.md itself untracked, staged or
# edited), and none of those may pass the gate.
# _gate_record commits the record there only under the same condition, so
# the record push never carries unpushed commits to the PR branch.
# _GATE_OWN_NOREAD says why the timeline is not read (empty: it is read);
# the repository itself stays usable for the ancestry check and the CI
# target (_ci_wt), and the record goes on the PR. Origin is asked with a
# bounded fetch by explicit refspec; an origin that cannot be asked is a
# reason, never a pass. Workspace and project PRs never reach this: their
# worktree is found by its branch, and their timeline read is unchanged.
_GATE_OWN_NOREAD=""
if [[ "$_GATE_PKG_ROLE" == "owning" && -z "$_GATE_OWN_PROBLEM" ]]; then
    _gate_own_branch=$(git -C "$_gate_wt" symbolic-ref --short -q HEAD 2>/dev/null || true)
    if [[ -z "$_gate_own_branch" ]]; then
        _GATE_OWN_NOREAD="the owning checkout $_gate_wt has a detached HEAD, not $PR_BRANCH"
    elif [[ "$_gate_own_branch" != "$PR_BRANCH" ]]; then
        _GATE_OWN_NOREAD="the owning checkout $_gate_wt is on $_gate_own_branch, not $PR_BRANCH"
    else
        _gate_own_rc=0
        _gate_own_err=$( (cd "$_gate_wt" && wt_bounded_git fetch --quiet origin -- "+refs/heads/$PR_BRANCH:refs/remotes/origin/$PR_BRANCH") 2>&1 >/dev/null ) || _gate_own_rc=$?
        if [[ "$_gate_own_rc" -ne 0 ]]; then
            _GATE_OWN_NOREAD="origin's $PR_BRANCH could not be fetched in the owning checkout $_gate_wt ($(wt_fetch_why "$_gate_own_rc" "$_gate_own_err")), so it is not known to be current"
        else
            _gate_own_origin=$(git -C "$_gate_wt" rev-parse -q --verify "refs/remotes/origin/$PR_BRANCH^{commit}" 2>/dev/null || true)
            if [[ -z "$_gate_own_origin" ]]; then
                _GATE_OWN_NOREAD="the fetch of $PR_BRANCH in the owning checkout $_gate_wt wrote no origin/$PR_BRANCH, so it is not known to be current"
            elif ! git -C "$_gate_wt" merge-base --is-ancestor "$_gate_own_origin" HEAD 2>/dev/null; then
                _GATE_OWN_NOREAD="the owning checkout $_gate_wt does not contain origin's $PR_BRANCH at ${_gate_own_origin:0:7} (local $(git -C "$_gate_wt" rev-parse --short=7 HEAD 2>/dev/null || echo '?'))"
            elif [[ "$(git -C "$_gate_wt" rev-parse -q --verify 'HEAD^{commit}' 2>/dev/null || true)" != "$_gate_own_origin" ]]; then
                # Ahead of origin: unpushed commits. Their timeline may hold
                # entries origin does not have, and a record committed on
                # top would push them to the PR branch with it.
                _gate_own_ahead=$(git -C "$_gate_wt" rev-list --count "$_gate_own_origin..HEAD" 2>/dev/null || echo '?')
                _gate_own_plural="s"
                [[ "$_gate_own_ahead" == 1 ]] && _gate_own_plural=""
                _GATE_OWN_NOREAD="the owning checkout $_gate_wt has $_gate_own_ahead commit${_gate_own_plural} not on origin's $PR_BRANCH at ${_gate_own_origin:0:7} (local $(git -C "$_gate_wt" rev-parse --short=7 HEAD 2>/dev/null || echo '?'))"
            else
                # Equal to origin, but progress.md not as committed: the
                # same rule, an uncommitted entry is one origin does not have.
                _GATE_OWN_NOREAD=$(_gate_rec_dirty "$_gate_wt")
            fi
        fi
    fi
fi
# The path passes the records gate (records_path) like every other records
# read: inside a package worktree only the issue's own checkout is read. A
# refusal leaves no timeline and says why below.
_gate_progress=""
_gate_refusal=""
if [[ -n "$_gate_wt" && -z "$_GATE_OWN_PROBLEM" && -z "$_GATE_OWN_NOREAD" ]]; then
    _gate_cand="$_gate_wt/.agent/work-plans/issue-${ISSUE_NUM}/progress.md"
    if _gate_refusal=$(records_path "$_gate_cand" "$_gate_wt" 2>&1 >/dev/null); then
        _gate_refusal=""
        [[ -f "$_gate_cand" ]] && _gate_progress="$_gate_cand"
    else
        _gate_refusal=$(head -n1 <<< "$_gate_refusal" | sed 's/^ERROR: //')
    fi
fi
# The git repo the ancestry/paths checks run in (gate condition (a) and the
# Step 2 CI target): the PR's own worktree, and never a main tree (the
# workspace's or the project's checkout root) even if it happens to have the
# branch checked out (AGENTS.md forbids feature commits there). Empty means
# "no local history to verify against".
_ci_wt=""
if [[ "$_GATE_PKG_ROLE" != "sibling" && -n "$_gate_wt" && -z "$_GATE_OWN_PROBLEM" ]]; then
    _ci_wt_top=$(git -C "$_gate_wt" rev-parse --show-toplevel 2>/dev/null || true)
    if [[ -n "$_ci_wt_top" ]]; then
        _ci_is_main=false
        for _mt in "$ROOT_DIR" "$ROOT_DIR/project" "$PJ_ROOT_EFFECTIVE"; do
            if [[ -d "$_mt" ]] && [[ "$(cd "$_mt" && pwd -P)" == "$(cd "$_ci_wt_top" && pwd -P)" ]]; then
                _ci_is_main=true
            fi
        done
        [[ "$_ci_is_main" == false ]] && _ci_wt="$_ci_wt_top"
    fi
fi
# (a) latest review entry at the head, approved. The reader's --type filter
# already includes `## External Review` as Integrated Review's recognized
# predecessor (ADR-0013); it is judged by the Integrated Review rule: it
# must be **Status**: complete (#309) and have no open must-fix /
# cross-confirmed finding.
# "At the head" (#286): the entry's SHA equals HEAD_REVIEWED, or is an
# ancestor of it with only merge-time document files changed in between —
# recording the review itself commits progress.md on the branch, so the
# literal head is always one commit past the SHA the entry names.
_gate_review=""
if [[ -z "$_gate_head" ]]; then
    _gate_reasons+=("could not read the PR head SHA")
elif [[ -z "$_gate_progress" ]]; then
    if [[ "$_GATE_PKG_ROLE" == "sibling" ]]; then
        # A sibling's gate is not read in the owning checkout: that timeline
        # is the owning PR's. Name where the issue's records are, when the
        # manifest has an owning entry (the one place: issue_checkout_of).
        if _gate_own_dir=$(issue_checkout_of "$PKG_WT_DIR" "$ISSUE_NUM" 2>/dev/null); then
            _gate_reasons+=("a sibling repository's pull request: this issue's records are in $(_bk_display "$_gate_own_dir"), and a sibling's gate is not read there")
        else
            _gate_reasons+=("a sibling repository's pull request: package worktree $(_bk_display "$PKG_WT_DIR") has no single checkout on feature/issue-$(_bk_display "$ISSUE_NUM"), so no timeline is read for it")
        fi
    elif [[ -n "$_GATE_OWN_PROBLEM" ]]; then
        _gate_reasons+=("$(_bk_display "$_GATE_OWN_PROBLEM"), so no timeline is read for issue #$(_bk_display "$ISSUE_NUM")")
    elif [[ -n "$_GATE_OWN_NOREAD" ]]; then
        _gate_reasons+=("$(_bk_display "$_GATE_OWN_NOREAD"); its timeline is not read for issue #$(_bk_display "$ISSUE_NUM")")
    elif [[ -n "$_gate_refusal" ]]; then
        _gate_reasons+=("the records gate refused the timeline in $(_bk_display "$_gate_wt"): $(_bk_display "$_gate_refusal")")
    else
        _gate_reasons+=("no progress.md for issue #$(_bk_display "$ISSUE_NUM") in an open worktree (looked for $(_bk_display "${_gate_wt:-<no worktree found for $PR_BRANCH>}"))")
    fi
else
    _gate_read_rc=0
    _gate_read_json=$(python3 "$SCRIPT_DIR/progress_read.py" "$_gate_progress" --type "Local Review" --type "Integrated Review" 2>/dev/null) || _gate_read_rc=$?
    if [[ "$_gate_read_rc" -ne 0 ]]; then
        _gate_reasons+=("progress.md at $(_bk_display "$_gate_progress") could not be parsed (progress_read.py exit $_gate_read_rc — malformed file, e.g. an unterminated code fence)")
    else
        _gate_review=$(jq -c --arg head "$_gate_head_short" '
            .entries | map(select(.base_type == "Local Review" or .base_type == "Integrated Review" or .base_type == "External Review")) | last // empty
            | {type, sha: (.correlation.sha // ""), verdict: (.fields.Verdict // ""),
               status: ((.status // "") | gsub("^\\s+|\\s+$"; "")),
               open_mustfix: ([.findings[] | select((.checked | not) and ((.source_hint // "") | test("^(must-fix|cross-confirmed)")))] | length),
               at_head: (((.correlation.sha // "")[0:7]) == $head)}' <<<"$_gate_read_json" 2>/dev/null || echo "")
    fi
    if [[ "$_gate_read_rc" -ne 0 ]]; then
        :
    elif [[ -z "$_gate_review" ]]; then
        _gate_reasons+=("no ## Local Review / ## Integrated Review entry in $(_bk_display "$_gate_progress")")
    else
        _gate_r_type=$(jq -r '.type' <<<"$_gate_review")
        _gate_r_sha=$(jq -r '.sha' <<<"$_gate_review")
        _gate_covered=$(jq -r '.at_head' <<<"$_gate_review")
        _gate_stale_why=""
        # Only a verified difference (helper rc 1) is a "stale review". Every
        # other not-covered outcome was never checked — no worktree, a SHA
        # that does not resolve, helper rc 3 — and must not read as stale
        # (an operator may reach for --force-unreviewed). Both refuse.
        _gate_stale_label="review coverage could not be confirmed"
        if [[ "$_gate_covered" != "true" ]]; then
            if [[ -z "$_ci_wt" ]]; then
                _gate_stale_why="no local worktree to verify ancestry"
            else
                (cd "$_ci_wt" && wt_bounded_git fetch --quiet origin -- "+refs/heads/$PR_BRANCH:refs/remotes/origin/$PR_BRANCH") 2>/dev/null || true
                _gate_r_full=$(git -C "$_ci_wt" rev-parse --verify --quiet "${_gate_r_sha}^{commit}" 2>/dev/null || echo "")
                _gate_h_full=$(git -C "$_ci_wt" rev-parse --verify --quiet "${_gate_head}^{commit}" 2>/dev/null || echo "")
                if [[ -z "$_gate_r_full" ]]; then
                    _gate_stale_why="\`$(_bk_display "${_gate_r_sha:-?}")\` does not resolve to one commit in $(_bk_display "$_ci_wt")"
                elif [[ -z "$_gate_h_full" ]]; then
                    _gate_stale_why="head \`$(_bk_display "$_gate_head_short")\` is not present locally"
                else
                    _gate_bk_rc=0
                    _gate_stale_why=$(_review_bookkeeping_between "$_ci_wt" "$_gate_r_full" "$_gate_h_full" "$ISSUE_NUM") || _gate_bk_rc=$?
                    if [[ "$_gate_bk_rc" -eq 0 ]]; then
                        _gate_covered=true
                        echo "  review at \`${_gate_r_sha:0:7}\` covers head \`${_gate_head_short}\`: only work-plan / progress.md / roadmap changed since"
                    elif [[ "$_gate_bk_rc" -eq 1 ]]; then
                        _gate_stale_label="stale review"
                    fi
                fi
            fi
        fi
        if [[ "$_gate_covered" != "true" ]]; then
            # _gate_stale_why is already display-safe (_bk_display inside
            # the helper, or above); the label is a constant.
            _gate_reasons+=("latest $(_bk_display "$_gate_r_type") entry is at \`$(_bk_display "${_gate_r_sha:-?}")\`, not the PR head \`$(_bk_display "$_gate_head_short")\` (${_gate_stale_label}: ${_gate_stale_why})")
        elif [[ "$_gate_r_type" == "Local Review" && "$(jq -r '.verdict' <<<"$_gate_review")" != "approved" ]]; then
            _gate_reasons+=("latest Local Review at the head has **Verdict**: $(_bk_display "$(jq -r '.verdict' <<<"$_gate_review")"), not approved")
        elif [[ "$_gate_r_type" != "Local Review" \
                && "$(jq -r '.status | ascii_downcase' <<<"$_gate_review")" != "complete" ]]; then
            # A partial or failed triage decided nothing (#309, the rule
            # review_progress.sh sources applies to supersession): its own
            # open-box count says nothing about the findings it never ruled on.
            _gate_reasons+=("latest $(_bk_display "$_gate_r_type") at the head has **Status**: $(_bk_display "$(jq -r '.status | if . == "" then "<missing>" else . end' <<<"$_gate_review")"), not complete — a partial or failed triage decided nothing")
        elif [[ "$_gate_r_type" != "Local Review" && "$(jq -r '.open_mustfix' <<<"$_gate_review")" != "0" ]]; then
            _gate_reasons+=("latest Integrated Review at the head still has $(_bk_display "$(jq -r '.open_mustfix' <<<"$_gate_review")") open must-fix/cross-confirmed finding(s)")
        fi
    fi
fi
# (b) decision summary on the PR: in its body (the PR template's section)
# or in any comment.
if [[ -z "$_gate_json" ]] || ! jq -e '[(.body // ""), (.comments[]? | .body // "")] | map(select(test("(^|\\n)## Decision summary"))) | length > 0' <<<"$_gate_json" >/dev/null 2>&1; then
    _gate_reasons+=("no \"## Decision summary\" heading in the PR body or a PR comment")
fi
# A package PR's base (issue 429): the owning repository's PR (on
# feature/issue-<N>) must target the base its worktree recorded, the branch
# its feature branch started from. base= describes the owning entry only, so
# a sibling repository's PR (feature/<repo>-issue-<N>) is not compared, and a
# worktree that records no base says nothing. Report-only, like every
# package reason.
if [[ -n "$PKG_WT_BASE" && "$PR_BRANCH" == "feature/issue-${ISSUE_NUM}" ]]; then
    if [[ -z "$PR_BASE_REF" ]]; then
        _gate_reasons+=("the PR's base branch could not be read, so it was not compared with this worktree's recorded base $(_bk_display "$PKG_WT_BASE")")
    elif [[ "$PR_BASE_REF" != "$PKG_WT_BASE" ]]; then
        _gate_reasons+=("targets $(_bk_display "$PR_BASE_REF"); this worktree's recorded base is $(_bk_display "$PKG_WT_BASE")")
    fi
fi

# The record's progress.md in the checkout, as it was before the record was
# written: its working-tree copy (or none), its index entry (or none) and
# which of its folders did not exist. _gate_rec_restore puts back exactly
# that, so a refused commit or an undone push leaves the checkout as it was
# whether progress.md was there before the record or not, and a later run's
# duplicate check never reads a leftover entry.
_GS_REL="" _GS_ABS="" _GS_COPY="" _GS_INDEX="" _GS_STATUS=""
declare -a _GS_NEW_DIRS=()
# Prints why the record cannot be written safely in <checkout>, or nothing:
# progress.md, or one of the folders on its way, is a symlink (dangling or
# not) or exists as something other than a regular file or a folder. Such a
# path is never written, snapshotted or restored: it is left exactly as
# found and the record goes on the PR.
_gate_rec_unsafe() {  # <checkout>
    local wt="$1" rel p
    for rel in .agent .agent/work-plans ".agent/work-plans/issue-${ISSUE_NUM}"; do
        p="$wt/$rel"
        if [[ -L "$p" ]]; then
            echo "$rel in $wt is a symlink"; return 0
        elif [[ -e "$p" && ! -d "$p" ]]; then
            echo "$rel in $wt is not a folder"; return 0
        fi
    done
    p="$wt/.agent/work-plans/issue-${ISSUE_NUM}/progress.md"
    if [[ -L "$p" ]]; then
        echo ".agent/work-plans/issue-${ISSUE_NUM}/progress.md in $wt is a symlink"
    elif [[ -e "$p" && ! -f "$p" ]]; then
        echo ".agent/work-plans/issue-${ISSUE_NUM}/progress.md in $wt is not a regular file"
    fi
}
_gate_rec_snapshot() {  # <checkout>
    local wt="$1" d
    _GS_REL=".agent/work-plans/issue-${ISSUE_NUM}/progress.md"
    _GS_ABS="$wt/$_GS_REL"
    _GS_COPY=""
    if [[ -f "$_GS_ABS" ]]; then
        _GS_COPY=$(mktemp)
        cp "$_GS_ABS" "$_GS_COPY"
    fi
    _GS_INDEX=$(git -C "$wt" ls-files -s -- "$_GS_REL" 2>/dev/null || true)
    _GS_STATUS=$(git -C "$wt" status --porcelain -- "$_GS_REL" 2>/dev/null || true)
    _GS_NEW_DIRS=()
    for d in "$wt/.agent/work-plans/issue-${ISSUE_NUM}" "$wt/.agent/work-plans" "$wt/.agent"; do
        [[ -d "$d" ]] || _GS_NEW_DIRS+=("$d")
    done
}
_gate_rec_restore() {  # <checkout>; returns 0 when progress.md is as it was
    local wt="$1" mode sha rest d rc=0
    if [[ -n "$_GS_INDEX" ]]; then
        read -r mode sha rest <<< "$_GS_INDEX"
        git -C "$wt" update-index --cacheinfo "$mode,$sha,$_GS_REL" 2>/dev/null || rc=1
    else
        git -C "$wt" rm -q --cached --ignore-unmatch -- "$_GS_REL" >/dev/null 2>&1 || rc=1
    fi
    if [[ -n "$_GS_COPY" ]]; then
        cp "$_GS_COPY" "$_GS_ABS" || rc=1
    else
        # Only the regular file the record created is removed; anything
        # else found there was not ours and stays.
        if [[ -f "$_GS_ABS" && ! -L "$_GS_ABS" ]]; then
            rm -f "$_GS_ABS"
        fi
        for d in ${_GS_NEW_DIRS[@]+"${_GS_NEW_DIRS[@]}"}; do
            rmdir "$d" 2>/dev/null || true
        done
    fi
    [[ "$(git -C "$wt" status --porcelain -- "$_GS_REL" 2>/dev/null || true)" == "$_GS_STATUS" ]] || rc=1
    return "$rc"
}
_gate_rec_snapshot_drop() {
    if [[ -n "$_GS_COPY" ]]; then
        rm -f "$_GS_COPY"
    fi
    _GS_COPY=""
}

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
    # (a package worktree's container is not a repo; the owning PR's
    # _gate_wt is its owning checkout, which is; a sibling PR keeps the
    # container and always takes the PR-comment path) and an agent identity
    # is set (progress_append.sh refuses to commit without).
    local why_comment="no open worktree for the PR's repo" wt_top="" unsafe=""
    # "Is a repo" must mean the directory IS a repo root, not that some
    # ancestor is one: `git rev-parse --show-toplevel` walks up, and a
    # package worktree container lives under the workspace checkout, so the
    # naive check would resolve to the live main tree and commit there
    # (round-2 review). A sibling package PR never takes this path at all.
    if [[ "$_GATE_PKG_ROLE" != "sibling" && -n "$_gate_wt" && -z "$_GATE_OWN_PROBLEM" && -z "$_GATE_OWN_NOREAD" ]]; then
        wt_top=$(git -C "$_gate_wt" rev-parse --show-toplevel 2>/dev/null || true)
        if [[ -z "$wt_top" || "$(cd "$_gate_wt" && pwd -P)" != "$(cd "$wt_top" && pwd -P)" ]]; then
            wt_top=""
        fi
        # Never a main tree (the workspace's or the project's checkout root,
        # #379), even when it happens to have the PR branch checked out:
        # AGENTS.md forbids feature commits there (round-3 review). The
        # record goes on the PR.
        if [[ -n "$wt_top" ]]; then
            for _mt in "$ROOT_DIR" "$ROOT_DIR/project" "$PJ_ROOT_EFFECTIVE"; do
                [[ -d "$_mt" ]] && [[ "$(cd "$_mt" && pwd -P)" == "$(cd "$wt_top" && pwd -P)" ]] && { wt_top=""; why_comment="the PR branch is checked out in the main tree, which never takes feature commits"; break; }
            done
        fi
        # The record is committed and pushed only from a checkout that has
        # the PR's branch checked out: a commit on another branch would not
        # reach the PR, and `push origin <PR branch>` would then report
        # nothing to push. A workspace or project PR's _gate_wt is found by
        # its branch, so this holds there by construction; an owning
        # package checkout (the manifest's entry) can have moved.
        if [[ -n "$wt_top" ]]; then
            local cur_branch
            cur_branch=$(git -C "$_gate_wt" symbolic-ref --short -q HEAD 2>/dev/null || true)
            if [[ -z "$cur_branch" ]]; then
                wt_top=""
                why_comment="the checkout $_gate_wt has a detached HEAD, not $PR_BRANCH, so the record is not committed there"
            elif [[ "$cur_branch" != "$PR_BRANCH" ]]; then
                wt_top=""
                why_comment="the checkout $_gate_wt is on $cur_branch, not $PR_BRANCH, so the record is not committed there"
            fi
        fi
    fi
    if [[ -n "$wt_top" ]]; then
        if [[ -z "${AGENT_NAME:-}" || -z "${AGENT_EMAIL:-}" ]]; then
            why_comment="no agent identity set (source set_git_identity_env.sh) for a timeline commit"
        elif unsafe=$(_gate_rec_unsafe "$_gate_wt") && [[ -n "$unsafe" ]]; then
            why_comment="${unsafe}, so the record is not written there (left as found)"
        else
            local head_before append_rc=0 rec_sha="" push_rc=0
            head_before=$(git -C "$_gate_wt" rev-parse -q --verify HEAD 2>/dev/null || echo "")
            _gate_rec_snapshot "$_gate_wt"
            printf '%s\n' "$entry" | "$SCRIPT_DIR/progress_append.sh" -C "$_gate_wt" "$ISSUE_NUM" >/dev/null 2>&1 || append_rc=$?
            if [[ "$append_rc" -eq 0 ]]; then
                rec_sha=$(git -C "$_gate_wt" rev-parse HEAD 2>/dev/null || echo "")
                [[ -n "$rec_sha" ]] && _RUN_COMMITTED_SHAS+=("$rec_sha")
                # Bounded like every call to origin. Run from the checkout
                # rather than through -C: the path then never passes through
                # timeout's argv, which may not carry a non-UTF-8 path intact.
                (cd "$_gate_wt" && wt_bounded_git push -q origin "$PR_BRANCH") 2>/dev/null || push_rc=$?
                if [[ "$push_rc" -eq 0 ]]; then
                    _gate_rec_snapshot_drop
                    _STEP15_COMMITTED_PATH=".agent/work-plans/issue-${ISSUE_NUM}/progress.md"
                    echo "  📝 ${etype} entry recorded in ${_gate_wt}/.agent/work-plans/issue-${ISSUE_NUM}/progress.md and pushed"
                    return 0
                fi
                # A push that timed out may have reached origin before it
                # stalled: a bounded fetch of the branch (explicit refspec)
                # decides. Origin's branch contains the record commit (it is
                # the tip, or an ancestor of it when another push landed on
                # top): it was pushed, keep it. Otherwise, whether origin
                # answers without it or cannot be asked at all, undo it and
                # post the record as a PR comment below: the record is then
                # on the PR, at worst twice, and never only in a local commit
                # that nothing would push before the merge.
                local after_why="" dup_note=""
                if [[ "$push_rc" -eq 124 || "$push_rc" -eq 137 ]]; then
                    local fetch_rc=0 fetch_err="" origin_tip=""
                    fetch_err=$( (cd "$_gate_wt" && wt_bounded_git fetch --quiet origin -- "+refs/heads/$PR_BRANCH:refs/remotes/origin/$PR_BRANCH") 2>&1 >/dev/null ) || fetch_rc=$?
                    if [[ "$fetch_rc" -eq 0 ]]; then
                        origin_tip=$(git -C "$_gate_wt" rev-parse -q --verify "refs/remotes/origin/$PR_BRANCH^{commit}" 2>/dev/null || true)
                    fi
                    if [[ -n "$origin_tip" && -n "$rec_sha" ]] && git -C "$_gate_wt" merge-base --is-ancestor "$rec_sha" "$origin_tip" 2>/dev/null; then
                        _gate_rec_snapshot_drop
                        _STEP15_COMMITTED_PATH=".agent/work-plans/issue-${ISSUE_NUM}/progress.md"
                        echo "  📝 ${etype} entry recorded in ${_gate_wt}/.agent/work-plans/issue-${ISSUE_NUM}/progress.md and pushed (the push timed out after $(wt_fetch_limit)s; origin's $PR_BRANCH contains the record commit)"
                        return 0
                    fi
                    if [[ "$fetch_rc" -ne 0 ]]; then
                        after_why="was not known to be pushed: the push timed out after $(wt_fetch_limit)s and origin could not be asked afterwards ($(wt_fetch_why "$fetch_rc" "$fetch_err"))"
                        dup_note="; if origin took it, this comment is a second copy"
                    elif [[ -z "$origin_tip" ]]; then
                        after_why="was not known to be pushed: the push timed out after $(wt_fetch_limit)s and the fetch wrote no origin/$PR_BRANCH"
                        dup_note="; if origin took it, this comment is a second copy"
                    else
                        after_why="was not pushed: the push timed out after $(wt_fetch_limit)s and origin's $PR_BRANCH does not contain it"
                    fi
                fi
                # Push refused, or timed out and origin answers without the
                # record commit: undo exactly that one-file commit and put
                # progress.md back as it was, so nothing is left
                # half-recorded, then fall back to the PR comment (one
                # record, never a stranded commit plus a comment).
                if [[ -n "$rec_sha" && "$rec_sha" != "$head_before" ]]; then
                    git -C "$_gate_wt" reset -q --soft HEAD~1 2>/dev/null || true
                fi
                if [[ -n "$rec_sha" ]]; then
                    local -a kept=()
                    local k
                    for k in ${_RUN_COMMITTED_SHAS[@]+"${_RUN_COMMITTED_SHAS[@]}"}; do
                        [[ "$k" == "$rec_sha" ]] || kept+=("$k")
                    done
                    _RUN_COMMITTED_SHAS=(${kept[@]+"${kept[@]}"})
                fi
                local push_what="could not be pushed to origin"
                [[ -n "$after_why" ]] && push_what="$after_why"
                if [[ "$(git -C "$_gate_wt" rev-parse -q --verify HEAD 2>/dev/null || echo "")" == "$head_before" ]] \
                        && _gate_rec_restore "$_gate_wt"; then
                    why_comment="the timeline commit ${push_what} (undone locally)${dup_note}"
                else
                    why_comment="the timeline commit ${push_what}, and undoing it in $_gate_wt did not leave progress.md as it was${dup_note}"
                fi
            elif [[ "$(git -C "$_gate_wt" rev-parse -q --verify HEAD 2>/dev/null || echo "")" != "$head_before" ]]; then
                # Not expected: progress_append.sh fails before its commit.
                why_comment="progress_append.sh exited $append_rc after HEAD moved in $_gate_wt; the checkout was left as it is"
            elif [[ "$append_rc" -eq 3 ]]; then
                # git add or the commit failed (e.g. a commit hook in the
                # checkout's own repository) after the entry was appended
                # and staged: put progress.md back as it was.
                local took_out="the entry was taken back out"
                _gate_rec_restore "$_gate_wt" || took_out="taking the entry back out did not leave progress.md as it was"
                why_comment="the timeline commit in $_gate_wt was refused (progress_append.sh exit 3: a git failure such as a commit hook), and ${took_out}"
            else
                # Exit 2 or 4: refused before anything was written; nothing
                # to restore, and nothing is touched.
                why_comment="progress_append.sh refused the timeline entry (exit $append_rc)"
            fi
            _gate_rec_snapshot_drop
        fi
    elif [[ "$_GATE_PKG_ROLE" == "sibling" ]]; then
        why_comment="a sibling repository's pull request records on its own PR, not in the owning checkout's timeline"
    elif [[ -n "$_GATE_OWN_PROBLEM" ]]; then
        why_comment="$_GATE_OWN_PROBLEM"
    elif [[ -n "$_GATE_OWN_NOREAD" ]]; then
        why_comment="$_GATE_OWN_NOREAD; the record is not committed there"
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

# --- Idempotent record (issue #284) ---
# A retry after a failed merge (or any second run against the same PR)
# must not append a second Merge entry for the SAME situation: that grows
# the timeline unboundedly and, worse, moves the head again (progress.md
# push) for no new information. "Same situation" means the latest existing
# Merge (report-only)/(unreviewed) entry for this PR carries the identical
# entry type AND the identical **Conditions** text this run just computed
# — an exact match, not "any prior record exists": a run whose reasons
# have genuinely changed (a review landed, a new gap appeared) still gets
# a fresh entry so the timeline reflects what actually happened. Checked
# against progress.md when a worktree is open, else the PR's own comments
# (the same store `_gate_record` itself falls back to).
#
# Deliberate ADR-0013 exception: matching is keyed on PR number + entry
# type + Conditions text, NOT the entry's SHA correlation field, even
# though ADR-0013 otherwise correlates Merge entries by head SHA. The SHA
# in these entries is `HEAD_REVIEWED`, which the CI-target exemption above
# can hold constant across an otherwise-legitimate repeat run (the script's
# own paths-only pushes don't move it) — keying on SHA would make the
# idempotency check trivially always match (nothing to compare) or never
# match (the SHA is identical by construction), neither of which is what
# "same situation" means here. Owner's decision on #284.
# Which of two **When** values is newer: prints "a", "b", or "doubt" for a
# tie (the field has minute resolution) or a value that does not parse.
_gate_newer_when() {  # <when a> <when b>
    python3 - "$1" "$2" <<'PY' 2>/dev/null || echo doubt
import sys
from datetime import datetime
try:
    a, b = (datetime.strptime(v.strip(), "%Y-%m-%d %H:%M %z") for v in sys.argv[1:3])
except ValueError:
    print("doubt")
else:
    print("a" if a > b else "b" if b > a else "doubt")
PY
}
# A PR comment is a record only when its first line, with trailing blanks
# and a carriage return trimmed, is exactly one of the two headings: a
# heading quoted inside a body, or a first line that is a heading plus more
# text, is not one; an empty or null body is not one either. Prints the
# newest such body (jq filter). Anything else that is not a string (a body
# or a comment of another type) makes jq fail, and _gate_rec_comment says
# so: the store is then unread, never "no record".
_GATE_REC_COMMENT_JQ='[.comments[]? | .body // ""]
    | map(select(((split("\n")[0] // "") | sub("\\s+$"; "")) as $h
        | $h == "## Merge (report-only)" or $h == "## Merge (unreviewed)"))
    | last // empty'
# Prints the newest record comment's body in <json> (empty: none). Returns
# 1, after saying so, when the comments could not be read: the caller then
# records rather than skip on a store it never read.
_gate_rec_comment() {  # <json>
    local out rc=0
    out=$(jq -r "$_GATE_REC_COMMENT_JQ" <<<"$1" 2>/dev/null) || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        echo "  ⚠️  the PR's comments could not be read for the duplicate check (jq exit $rc) — recording rather than skipping" >&2
        return 1
    fi
    printf '%s' "$out"
}
# The value of a record field in a comment body, trailing blanks and a
# carriage return trimmed (a body edited into CRLF still matches).
_gate_rec_field() {  # <body> <field name>
    grep -m1 "^\*\*$2\*\*: " <<<"$1" | sed "s/^\*\*$2\*\*: //; s/[[:space:]]*\$//" || true
}
_gate_already_recorded() {  # <entry type> <conditions text>
    local etype="$1" why="$2" read_json rc=0 latest l_cond
    local t_type="" t_cond="" t_when="" t_sha="" c_body="" c_type="" c_cond="" c_when="" newer=""
    if [[ -n "$_gate_progress" ]]; then
        read_json=$(python3 "$SCRIPT_DIR/progress_read.py" "$_gate_progress" --type "Merge (report-only)" --type "Merge (unreviewed)" 2>/dev/null) || rc=$?
        [[ $rc -ne 0 ]] && return 1
        latest=$(jq -c --arg pr "$PR_NUMBER" \
            '.entries | map(select(.correlation.kind == "pr" and (.correlation.pr|tostring) == $pr)) | last // empty' \
            <<<"$read_json" 2>/dev/null || echo "")
        if [[ -n "$latest" && "$latest" != "null" ]]; then
            t_type=$(jq -r '.type' <<<"$latest")
            t_cond=$(jq -r '.fields.Conditions // ""' <<<"$latest")
            t_when=$(jq -r '.fields.When // ""' <<<"$latest")
            t_sha=$(jq -r '.correlation.sha // ""' <<<"$latest")
        fi
        if [[ "$_GATE_PKG_ROLE" != "owning" ]]; then
            # A workspace or project PR: the timeline alone, as before.
            if [[ -n "$t_type" && "$t_type" == "$etype" && "$t_cond" == "$why" ]]; then
                echo "  ℹ️  already recorded at \`${t_sha:0:7}\`, same conditions — skipping a duplicate ${etype} entry"
                return 0
            fi
            return 1
        fi
        # An owning package PR's record can be in either store: its
        # timeline, or the PR's comments when a record fell back there (a
        # commit hook that refused it, an undone push). The newest record
        # across both is the one compared, by the entries' own **When**
        # (both stores carry the same entry text). A tie (the field has
        # minute resolution) or a value that does not parse is doubt, and
        # doubt records again rather than skip.
        local c_json="${_gate_json:-}"
        [[ -n "$c_json" ]] || c_json='{}'
        c_body=$(_gate_rec_comment "$c_json") || return 1
        if [[ -n "$c_body" ]]; then
            c_type=$(head -n1 <<<"$c_body" | sed 's/^## //; s/[[:space:]]*$//')
            c_cond=$(_gate_rec_field "$c_body" Conditions)
            c_when=$(_gate_rec_field "$c_body" When)
        fi
        if [[ -z "$t_type" && -z "$c_type" ]]; then
            return 1
        elif [[ -n "$t_type" && -n "$c_type" ]]; then
            newer=$(_gate_newer_when "$t_when" "$c_when")
            if [[ "$newer" == doubt ]]; then
                echo "  ℹ️  the newest record (timeline \`${t_when:-?}\` against PR comment \`${c_when:-?}\`) cannot be told apart — recording rather than skipping on doubt"
                return 1
            fi
        elif [[ -n "$t_type" ]]; then
            newer=a
        else
            newer=b
        fi
        if [[ "$newer" == a && "$t_type" == "$etype" && "$t_cond" == "$why" ]]; then
            echo "  ℹ️  already recorded at \`${t_sha:0:7}\`, same conditions — skipping a duplicate ${etype} entry"
            return 0
        elif [[ "$newer" == b && "$c_type" == "$etype" && "$c_cond" == "$why" ]]; then
            echo "  ℹ️  already recorded (as a PR comment), same conditions — skipping a duplicate ${etype} entry"
            return 0
        fi
        return 1
    elif [[ -n "$_gate_json" ]]; then
        # No timeline read: the PR's comments are the store. The newest
        # record of either type is the one compared (a body that starts with
        # its heading; a heading quoted inside a body is not a record), and
        # it matches only when it is of the requested type with the same
        # conditions: a report-only record after an unreviewed one is the
        # newest state, and a later --force-unreviewed run records again.
        latest=$(_gate_rec_comment "$_gate_json") || return 1
        [[ -z "$latest" ]] && return 1
        [[ "$(head -n1 <<<"$latest" | sed 's/^## //; s/[[:space:]]*$//')" == "$etype" ]] || return 1
        l_cond=$(_gate_rec_field "$latest" Conditions)
        if [[ "$l_cond" == "$why" ]]; then
            echo "  ℹ️  already recorded (as a PR comment), same conditions — skipping a duplicate ${etype} entry"
            return 0
        fi
        return 1
    fi
    return 1
}

if [[ "${#_gate_reasons[@]}" -eq 0 ]]; then
    echo "  ✅ Review gate: approved review at head \`${_gate_head_short}\` and a decision summary are present"
else
    _gate_why=$(IFS=';'; echo "${_gate_reasons[*]}")
    if [[ "$FORCE_UNREVIEWED" == true ]]; then
        echo "  ⚠️  --force-unreviewed: bypassing the review gate — ${_gate_why}"
        _gate_already_recorded "Merge (unreviewed)" "$_gate_why" || _gate_record "Merge (unreviewed)" "$_gate_why"
    elif [[ "$ENFORCE_MERGE_GATE" == true && "$WORKTREE_TYPE" == "workspace" ]]; then
        {
            echo "ERROR: review gate refused to merge PR #${PR_NUMBER}:"
            for _r in "${_gate_reasons[@]}"; do echo "  - $_r"; done
            echo "  Run the review loop (review-code / triage-reviews, then post the decision summary),"
            echo "  pass --report-only to proceed with a ## Merge (report-only) record,"
            echo "  or pass --force-unreviewed to bypass with a ## Merge (unreviewed) record."
        } >&2
        exit 1
    else
        _gate_mode_note="report-only"
        # Don't name --enforce here: enforcement is the default, so the
        # caller usually passed no flag at all (#300 round 4).
        [[ "$ENFORCE_MERGE_GATE" == true ]] && _gate_mode_note="report-only: gate enforcement applies to workspace PRs only until #265 settles project timelines"
        echo "  ⚠️  Review gate (${_gate_mode_note}): would have refused — ${_gate_why}"
        _gate_already_recorded "Merge (report-only)" "$_gate_why" || _gate_record "Merge (report-only)" "$_gate_why"
    fi
fi

# --- Bookkeeping paths for the CI target (#300, owner rule; #323) ---
# "The exception is for merging after adding an updated progress or related
# doc": a progress.md / work-plan / roadmap commit pushed after a CI-verified
# head needs no new CI round. Any issue's work-plan dir (a CI question, not
# a review one: a document commit needs no new CI round whoever's timeline
# it is), plus the roadmap set shared with the review policy
# (_bookkeeping.sh). One definition, read by Step 2's allowed set and by the
# walk-back below.
MERGE_PR_CI_BOOKKEEPING_PATTERNS=(".agent/work-plans/*" "${BOOKKEEPING_ROADMAP_PATHS[@]}")

# --- Step 2: Decide the CI target (issue #284) ---
# The naive target is "whatever the head is right now", but Step 1.5's own
# record push (and Step 1's roadmap push) may have moved the head past
# HEAD_REVIEWED, and so may a host's bookkeeping push that gh's
# headRefOid has not caught up with (#323: HEAD_REVIEWED then lags behind
# a commit this run did not make). When the ONLY diff between
# HEAD_REVIEWED and the current head is bookkeeping — paths this run
# committed itself, or merge-time document files (MERGE_PR_CI_BOOKKEEPING_PATTERNS)
# whoever committed them — CI on HEAD_REVIEWED already covers the change
# that matters and the new head is exempt from a second CI round. Every
# other case — a concurrent push of anything else, a force-push, a code
# path — targets the actual current head, in full.
CI_TARGET_SHA=""
# (_ci_wt — the PR's own worktree, never the main tree — was resolved
# alongside the gate above, since both use it.)

HEAD_NOW=""
# An explicit refspec, as wt_fetch_named_branch uses: a --single-branch or
# narrowed clone's configured refspec need not cover the PR branch, and a
# plain `fetch origin <b>` there writes FETCH_HEAD only, leaving a stale
# origin/<b> to become the CI target.
if [[ -n "$_ci_wt" ]] && (cd "$_ci_wt" && wt_bounded_git fetch --quiet origin -- "+refs/heads/$PR_BRANCH:refs/remotes/origin/$PR_BRANCH") 2>/dev/null; then
    HEAD_NOW=$(git -C "$_ci_wt" rev-parse "origin/$PR_BRANCH" 2>/dev/null || echo "")
fi
if [[ -z "$HEAD_NOW" ]]; then
    # No local worktree to fetch in (package PR, no open worktree for this
    # branch, or the fetch/rev-parse failed) — fall back to a fresh gh
    # read. No exemption is possible without a local diff to verify.
    _ci_now_json=$(gh pr view "$PR_NUMBER" "${GH_REPO_ARGS[@]}" --json headRefOid 2>/dev/null || echo "")
    HEAD_NOW=$(jq -r '.headRefOid // empty' <<<"${_ci_now_json:-}" 2>/dev/null || echo "")
fi

if [[ -z "$HEAD_NOW" ]]; then
    CI_TARGET_SHA="$HEAD_REVIEWED"
    echo "  ⚠️  could not determine the current PR head — waiting for CI on the reviewed head \`${HEAD_REVIEWED:0:7}\`"
elif [[ -z "$HEAD_REVIEWED" ]] || [[ "$HEAD_NOW" == "$HEAD_REVIEWED" ]]; then
    CI_TARGET_SHA="$HEAD_NOW"
elif [[ -z "$_ci_wt" ]]; then
    CI_TARGET_SHA="$HEAD_NOW"
    echo "  CI target: new head \`${HEAD_NOW:0:7}\` (no local worktree to verify ancestry/paths for an exemption)"
else
    # Allowed set: what THIS run committed (Step 1 roadmap paths, Step 1.5
    # progress.md) plus the CI bookkeeping patterns, the same set the
    # walk-back below uses (#323) — the question is "did anything but
    # bookkeeping land since we captured HEAD_REVIEWED", a CI question, not
    # "is the review still current". A head whose tree equals
    # HEAD_REVIEWED's (empty diff, e.g. an empty commit) is exempt too
    # (#286 review): CI on the reviewed tree already covers it.
    declare -a _ci_committed_paths=()
    [[ "${#_STEP1_COMMITTED_PATHS[@]}" -gt 0 ]] && _ci_committed_paths+=("${_STEP1_COMMITTED_PATHS[@]}")
    [[ -n "$_STEP15_COMMITTED_PATH" ]] && _ci_committed_paths+=("$_STEP15_COMMITTED_PATH")
    _ci_why=""
    if _ci_why=$(_only_bookkeeping_between "$_ci_wt" "$HEAD_REVIEWED" "$HEAD_NOW" ${_ci_committed_paths[@]+"${_ci_committed_paths[@]}"} "${MERGE_PR_CI_BOOKKEEPING_PATTERNS[@]}"); then
        CI_TARGET_SHA="$HEAD_REVIEWED"
        _ci_own_paths="none"
        [[ "${#_ci_committed_paths[@]}" -gt 0 ]] && _ci_own_paths="$(IFS=,; echo "${_ci_committed_paths[*]}")"
        echo "  CI target: reviewed head \`${HEAD_REVIEWED:0:7}\` — new head \`${HEAD_NOW:0:7}\` only touches bookkeeping: merge-time document files (work plans, roadmap) and paths this script committed itself (${_ci_own_paths})"
    else
        CI_TARGET_SHA="$HEAD_NOW"
        echo "  CI target: new head \`${HEAD_NOW:0:7}\` — ${_ci_why}"
    fi
fi

# --- Step 2 (cont.): Wait for CI on the CI target SHA (issue #284, fixes #271) ---
# Replaces `gh pr checks --watch --fail-fast`, which watches whatever runs
# exist for "the current head" at call time — the wrong SHA once Step 1 /
# Step 1.5 have pushed, and indistinguishable-from-failure when a repo has
# no CI at all (#271: "no checks reported" treated as a hard failure).
#
# MERGE_PR_CI_POLL_SECONDS / _GRACE_SECONDS / _TIMEOUT_SECONDS exist so
# tests can run with zero sleeps. --no-wait skips only this CI poll, for
# when the user knows CI is green; the mergeability settle below always
# runs (#290), since it guards against this script's own pushes, not CI.
MERGE_PR_CI_POLL_SECONDS="${MERGE_PR_CI_POLL_SECONDS:-10}"
MERGE_PR_CI_GRACE_SECONDS="${MERGE_PR_CI_GRACE_SECONDS:-120}"
MERGE_PR_CI_TIMEOUT_SECONDS="${MERGE_PR_CI_TIMEOUT_SECONDS:-1800}"
# Copilot's code-review check-run is a review signal, not CI (#300). It
# reports `conclusion: failure` for a "Changes recommended" verdict (already
# consumed by triage-reviews -> ## Integrated Review) and for quota
# exhaustion (PR #308), so it is excluded from CI classification by name,
# for ANY conclusion. One named run, not a list — widen only for a second
# confirmed offender.
readonly MERGE_PR_CI_EXCLUDE_CHECK_RUN="copilot-pull-request-reviewer"
_ci_excluded_noted=false

_ci_poll_state() {  # <sha> -- prints "<state>|<excluded>": state is one of none pending failed success error; excluded is a comma-joined list of the excluded run's verdicts (conclusion=<c>, or status=<s> while it is still running), empty when the excluded run is absent
    # "error" (issue #284 review) is distinct from "none": a nonzero `gh
    # api` exit (rate limit, network, 5xx, auth) or unparseable JSON is a
    # failure to LEARN the CI state, not evidence the repo has no CI — the
    # caller must keep retrying it (bounded by the grace deadline) rather
    # than falling through to the no-CI pass.
    # The excluded-run note is NOT printed here: the caller invokes this
    # function inside `$(...)`, so any flag set in this body mutates a
    # subshell copy and cannot suppress a repeat on the next poll. The
    # once-per-run decision therefore lives in the caller, which reads the
    # second field of the printed "<state>|<excluded>" pair.
    local sha="$1" runs_json status_json runs_rc=0 status_rc=0 registered pending failed excluded="" culprits
    # -X GET is load-bearing (#289): `-f` alone turns the request into a
    # POST, which GitHub answers with 404 on every poll.
    runs_json=$(gh api "repos/${PR_REPO_SLUG}/commits/${sha}/check-runs" -X GET --paginate -f per_page=100 2>/dev/null \
        | jq -c -s '{check_runs: [.[].check_runs[]?]}') || runs_rc=$?
    status_json=$(gh api "repos/${PR_REPO_SLUG}/commits/${sha}/status" 2>/dev/null) || status_rc=$?
    if [[ $runs_rc -ne 0 ]] || [[ $status_rc -ne 0 ]]; then
        echo "error|"
        return
    fi
    [[ -z "$runs_json" ]] && runs_json='{"check_runs":[]}'
    [[ -z "$status_json" ]] && status_json='{"statuses":[]}'
    if ! jq -e . >/dev/null 2>&1 <<<"$runs_json" || ! jq -e . >/dev/null 2>&1 <<<"$status_json"; then
        echo "error|"
        return
    fi
    # Drop the excluded review check-run BEFORE every classification below
    # (registered / failed / pending alike), so a head whose only run is
    # Copilot's counts as "no checks registered", never as success (#300).
    # Pure filter over data already fetched — no extra request.
    # A null conclusion means the run hasn't finished, so report its
    # `status` (queued / in_progress) rather than inventing a
    # `conclusion=pending` the API never returned (#300 review).
    excluded=$(jq -r --arg x "$MERGE_PR_CI_EXCLUDE_CHECK_RUN" \
        '[(.check_runs // [])[] | select(.name == $x)
          | if .conclusion == null then "status=" + (.status // "in_progress") else "conclusion=" + .conclusion end]
         | join(",")' <<<"$runs_json" 2>/dev/null || echo "")
    runs_json=$(jq -c --arg x "$MERGE_PR_CI_EXCLUDE_CHECK_RUN" \
        '{check_runs: [(.check_runs // [])[] | select(.name != $x)]}' <<<"$runs_json" 2>/dev/null || echo '{"check_runs":[]}')
    registered=$(jq -n --argjson r "$runs_json" --argjson s "$status_json" \
        '(($r.check_runs // []) | length) + (($s.statuses // []) | length) > 0' 2>/dev/null || echo false)
    if [[ "$registered" != "true" ]]; then
        echo "none|${excluded}"
        return
    fi
    culprits=$(jq -n -r --argjson r "$runs_json" --argjson s "$status_json" '
        ([($r.check_runs // [])[] | select(.conclusion == "failure" or .conclusion == "cancelled" or .conclusion == "timed_out" or .conclusion == "action_required" or .conclusion == "startup_failure" or .conclusion == "stale") | "\(.name // "<unnamed check-run>") (\(.conclusion))"]
         + [($s.statuses // [])[] | select(.state == "failure" or .state == "error") | "\(.context // "<unnamed status>") (\(.state))"])
        | join(", ")' 2>/dev/null || echo "")
    failed=false; [[ -n "$culprits" ]] && failed=true
    if [[ "$failed" == "true" ]]; then
        # Name what actually failed so the next false positive is
        # diagnosable from the script's own output (#300).
        echo "  CI failed: ${culprits}" >&2
        echo "failed|${excluded}"
        return
    fi
    pending=$(jq -n --argjson r "$runs_json" --argjson s "$status_json" '
        (([($r.check_runs // [])[] | select(.conclusion == null)] | length) > 0)
        or (([($s.statuses // [])[] | select(.state == "pending")] | length) > 0)' 2>/dev/null || echo false)
    if [[ "$pending" == "true" ]]; then
        echo "pending|${excluded}"
    else
        echo "success|${excluded}"
    fi
}

# --- Bookkeeping-only commits and the CI target (#300, owner rule) ---
# The Step 2 exemption above compares the current head with HEAD_REVIEWED,
# the head gh reported: it covers bookkeeping pushed after that head,
# by this run or by the host. This walk covers bookkeeping the host pushed
# BEFORE gh's head (HEAD_REVIEWED itself is a bookkeeping commit with no
# CI verdict). A batch push runs CI only on its tip, so the walk takes the
# newest bookkeeping-only ancestor whose checks actually reached a verdict.
# Its path set is MERGE_PR_CI_BOOKKEEPING_PATTERNS, defined above Step 2.
_is_bookkeeping_path() {  # <path> -- rc 0 when the path is a merge-time document file
    local p="$1" pat
    for pat in "${MERGE_PR_CI_BOOKKEEPING_PATTERNS[@]}"; do
        # shellcheck disable=SC2053  # unquoted RHS on purpose: pattern match
        [[ "$p" == $pat ]] && return 0
    done
    return 1
}
_ci_walk_bookkeeping() {  # <wt> <start-sha> -- prints ancestors of <start>, newest first, reachable through bookkeeping-only single-parent commits; stops at the first other commit, a merge, a root commit, the default branch, or 25 steps
    local wt="$1" cur="$2" base default_branch line parents p n=0
    local -a paths
    # The stop bound is the repo's own default branch, not a hardcoded
    # `origin/main`: where they differ (or origin/main is absent) the
    # merge-base would fail silently and drop this bound entirely.
    default_branch=$(resolve_default_branch "$wt" 2>/dev/null || echo "")
    [[ -n "$default_branch" ]] && base=$(git -C "$wt" merge-base "$cur" "$default_branch" 2>/dev/null || echo "")
    while [[ $n -lt 25 ]]; do
        [[ -n "$base" && "$cur" == "$base" ]] && return 0
        # `rev-list --parents -n 1` prints "<commit> <parent>...", so a root
        # commit yields a single field. Count fields on the WHOLE line: a
        # `cut -d' ' -f2-` on a one-field line returns the line itself, which
        # would make a root look like its own parent and self-diff to empty.
        line=$(git -C "$wt" rev-list --parents -n 1 "$cur" 2>/dev/null)
        [[ $(wc -w <<<"$line") -eq 2 ]] || return 0
        parents="${line#* }"
        # --no-renames: a code file moved into a work-plan dir still lists
        # its old path, and --no-relative / --ignore-submodules=none keep
        # user diff config from filtering paths, as in _bookkeeping.sh (#309).
        # -z: NUL-terminated, unquoted paths, so core.quotePath cannot turn
        # a non-ASCII work-plan file into a quoted string that fails the
        # pattern match. git's exit status arrives as an unterminated
        # "rc=<N>" trailer after the last NUL (left in $p by the final read);
        # a failed diff stops the walk, as before.
        paths=()
        while IFS= read -r -d '' p; do
            paths+=("$p")
        done < <(git -C "$wt" diff --no-renames --no-relative --ignore-submodules=none --name-only -z "$parents" "$cur" 2>/dev/null; printf 'rc=%s' "$?")
        [[ "$p" == "rc=0" ]] || return 0
        for p in ${paths[@]+"${paths[@]}"}; do
            [[ -z "$p" ]] && continue
            _is_bookkeeping_path "$p" || return 0
        done
        cur="$parents"
        echo "$cur"
        n=$((n + 1))
    done
}

_wait_for_mergeable() {  # prints the settled `mergeable` value; rc 1 on timeout (prints UNKNOWN, or LOOKUP_FAILED when the last poll could not reach GitHub), rc 2 on CONFLICTING
    local start deadline now state json lookup_failed
    start=$(date +%s)
    deadline=$((start + MERGE_PR_CI_GRACE_SECONDS))
    while :; do
        lookup_failed=false
        json=$(gh pr view "$PR_NUMBER" "${GH_REPO_ARGS[@]}" --json mergeable,mergeStateStatus 2>/dev/null) || lookup_failed=true
        [[ -z "$json" ]] && json='{}'
        state=$(jq -r '.mergeable // "UNKNOWN"' <<<"$json" 2>/dev/null || echo "UNKNOWN")
        if [[ "$state" == "CONFLICTING" ]]; then
            echo "$state"
            return 2
        fi
        if [[ "$state" != "UNKNOWN" ]]; then
            echo "$state"
            return 0
        fi
        now=$(date +%s)
        if [[ "$now" -ge "$deadline" ]]; then
            # Keep an unreachable GitHub distinguishable from a real UNKNOWN.
            if [[ "$lookup_failed" == true ]]; then echo "LOOKUP_FAILED"; else echo "$state"; fi
            return 1
        fi
        [[ "$MERGE_PR_CI_POLL_SECONDS" -gt 0 ]] && sleep "$MERGE_PR_CI_POLL_SECONDS"
    done
}

if [[ "$NO_WAIT" == false ]]; then
    echo "  Waiting for CI on \`${CI_TARGET_SHA:0:7}\`..."
    # A failed workflows-count lookup must NOT be assumed to mean "zero
    # workflows" (issue #284 review) — that would let a `gh api` outage
    # masquerade as "no CI configured" and merge unverified. "unknown"
    # keeps the `none` branch below from taking the no-ci exit; it waits
    # out the grace window and errors instead, same as a real repo whose
    # checks just haven't registered yet.
    _ci_wf_rc=0
    _ci_wf_json=$(gh api "repos/${PR_REPO_SLUG}/actions/workflows" 2>/dev/null) || _ci_wf_rc=$?
    if [[ $_ci_wf_rc -ne 0 ]]; then
        _ci_wf_count="unknown"
    else
        [[ -z "$_ci_wf_json" ]] && _ci_wf_json='{}'
        if jq -e . >/dev/null 2>&1 <<<"$_ci_wf_json"; then
            _ci_wf_count=$(jq -r '.total_count // 0' <<<"$_ci_wf_json" 2>/dev/null || echo "unknown")
        else
            _ci_wf_count="unknown"
        fi
    fi
    _ci_start=$(date +%s)
    _ci_deadline=$((_ci_start + MERGE_PR_CI_TIMEOUT_SECONDS))
    _ci_grace_deadline=$((_ci_start + MERGE_PR_CI_GRACE_SECONDS))
    _ci_result=""
    _ci_walked=false
    # Which SHA the pending-review hold is read from (#323): the head before
    # this run's own pushes, i.e. the newest commit on the PR branch that
    # this run did not make. Walk back from HEAD_NOW over exactly the SHAs
    # this run committed (_RUN_COMMITTED_SHAS); the first other commit is
    # the one a review runs on. Reading HEAD_NOW itself would wait on a
    # review re-triggered by our own push, deadlocking every merge the
    # script makes; reading the CI target would miss a review running on a
    # host commit the Step 2 exemption covers (gh's headRefOid lagging
    # behind a host push). A host push landing after ours is the head
    # itself and is never walked over. What it must never follow is the
    # bookkeeping WALK-BACK below, which moves CI_TARGET_SHA to an ancestor
    # whose check-runs say nothing about this head's review (#300 rounds
    # 4-5). With no HEAD_NOW, no local worktree to walk in, or a parent
    # that cannot be read, it stays CI_TARGET_SHA as Step 2 decided it.
    _ci_review_sha="$CI_TARGET_SHA"
    if [[ -n "$HEAD_NOW" && -n "$_ci_wt" ]]; then
        _ci_hold="$HEAD_NOW"
        _ci_hold_n=0
        while [[ -n "$_ci_hold" && "$_ci_hold_n" -le "${#_RUN_COMMITTED_SHAS[@]}" ]]; do
            _ci_own=false
            for _ci_k in ${_RUN_COMMITTED_SHAS[@]+"${_RUN_COMMITTED_SHAS[@]}"}; do
                [[ "$_ci_k" == "$_ci_hold" ]] && { _ci_own=true; break; }
            done
            [[ "$_ci_own" == false ]] && break
            _ci_hold=$(git -C "$_ci_wt" rev-parse --verify --quiet "${_ci_hold}^" 2>/dev/null || echo "")
            _ci_hold_n=$((_ci_hold_n + 1))
        done
        [[ -n "$_ci_hold" ]] && _ci_review_sha="$_ci_hold"
    fi
    _ci_head_excluded_last=""
    # Whether the review SHA's check-runs have been read at least once
    # (#323 review). Until they have, "no review running" is unknown, not
    # true: an empty last-seen state must never release the hold. The hold
    # stays unresolved, and at the grace deadline the wait refuses
    # (review-unreadable) rather than merge past a review it never saw.
    _ci_review_read=false
    while :; do
        _ci_poll_out=$(_ci_poll_state "$CI_TARGET_SHA")
        _ci_state="${_ci_poll_out%%|*}"
        _ci_excluded="${_ci_poll_out#*|}"
        if [[ "$_ci_review_sha" == "$CI_TARGET_SHA" && "$_ci_state" != error ]]; then
            _ci_review_read=true
        fi
        # Bookkeeping walk-back (#300, owner rule), once, on the first poll:
        # when the target has no verdict yet (nothing registered, or still
        # running), a bookkeeping-only ancestor that already reached success
        # or failure IS the verdict for this code — switch to it and re-poll.
        if [[ "$_ci_walked" == false ]]; then
            _ci_walked=true
            if [[ "$_ci_state" == none || "$_ci_state" == pending ]] && [[ -n "$_ci_wt" ]]; then
                _ci_switched=false
                _ci_pre_switch_sha="$CI_TARGET_SHA"
                for _ci_cand in $(_ci_walk_bookkeeping "$_ci_wt" "$CI_TARGET_SHA"); do
                    _ci_probe=$(_ci_poll_state "$_ci_cand" 2>/dev/null); _ci_probe="${_ci_probe%%|*}"
                    if [[ "$_ci_probe" == success || "$_ci_probe" == failed ]]; then
                        echo "  CI target: \`${_ci_cand:0:7}\` — \`${CI_TARGET_SHA:0:7}\` differs from it only by bookkeeping commits (progress.md / work plans / roadmap); its checks already reached a verdict (#300)"
                        CI_TARGET_SHA="$_ci_cand"
                        _ci_switched=true
                        break
                    fi
                done
                if [[ "$_ci_switched" == true ]]; then
                    # When this poll read the review SHA itself (the
                    # pre-switch target was the review SHA), its excluded
                    # state is the last one actually seen. Seed the carry-over
                    # before the `continue` drops it: otherwise a failed first
                    # head re-read after the switch falls back to "" and a
                    # green target merges past a running review (#300 round 5).
                    # When it read another commit (#323: the review SHA can
                    # differ from the CI target), that commit's review state
                    # says nothing about the review SHA's, so nothing is seeded
                    # and the hold waits for a read of the review SHA itself.
                    if [[ "$_ci_pre_switch_sha" == "$_ci_review_sha" ]]; then
                        _ci_head_excluded_last="$_ci_excluded"
                    fi
                    continue
                fi
            fi
        fi
        # Review state always comes from the real PR head, even after the
        # walk-back switched CI_TARGET_SHA to a bookkeeping ancestor: the
        # ancestor carries the CI verdict for this code, the head carries
        # the review. Re-read it every poll (not once, before the switch) so
        # a review that finishes mid-wait releases the hold. `2>/dev/null`
        # keeps a head-only CI failure out of the log — the head's CI state
        # is deliberately not this loop's verdict once it has walked back.
        if [[ "$_ci_review_sha" != "$CI_TARGET_SHA" ]]; then
            _ci_head_out=$(_ci_poll_state "$_ci_review_sha" 2>/dev/null)
            if [[ "${_ci_head_out%%|*}" == error ]]; then
                # A failed read must not silently drop a hold an earlier
                # poll established; keep the last state we actually saw.
                _ci_excluded="$_ci_head_excluded_last"
            else
                _ci_excluded="${_ci_head_out#*|}"
                _ci_head_excluded_last="$_ci_excluded"
                _ci_review_read=true
            fi
        fi
        # A review check-run that has not finished (`status=...`, no
        # conclusion) holds the merge unless the caller opted in: its
        # verdict is not CI, but merging under an unfinished review is
        # not the default (#300, owner rule).
        # `_ci_excluded` is a comma-joined list — a re-triggered review adds a
        # second run of the same name — so match anywhere, not anchored.
        _ci_review_pending=false
        if [[ "$_ci_excluded" == *status=* ]] && [[ "$ALLOW_PENDING_REVIEW" == false ]]; then
            _ci_review_pending=true
        fi
        # Never read yet: unresolved, so CI's green cannot merge (#323 review).
        _ci_review_unknown=false
        if [[ "$_ci_review_read" == false ]] && [[ "$ALLOW_PENDING_REVIEW" == false ]]; then
            _ci_review_unknown=true
        fi
        if [[ -n "$_ci_excluded" ]] && [[ "$_ci_excluded_noted" != "$_ci_excluded" ]]; then
            # Once per distinct state (running -> completed), not once per
            # poll — and the flag lives HERE, in the loop's own shell,
            # because `_ci_poll_state` is read through a command
            # substitution and cannot carry state back out of it.
            if [[ "$_ci_review_pending" == true ]]; then
                echo "  (check-run '${MERGE_PR_CI_EXCLUDE_CHECK_RUN}' ${_ci_excluded}: review still in progress — waiting for it before merging; --allow-pending-review merges without it)"
            else
                echo "  (check-run '${MERGE_PR_CI_EXCLUDE_CHECK_RUN}' ${_ci_excluded} is a review signal, excluded from CI — not used to block the merge)"
            fi
            _ci_excluded_noted="$_ci_excluded"
        fi
        _ci_now=$(date +%s)
        case "$_ci_state" in
            success)
                if [[ "$_ci_review_pending" == true ]]; then
                    if [[ "$_ci_now" -ge "$_ci_deadline" ]]; then
                        _ci_result="review-pending"; break
                    fi
                elif [[ "$_ci_review_unknown" == true ]]; then
                    if [[ "$_ci_now" -ge "$_ci_grace_deadline" ]]; then
                        _ci_result="review-unreadable"; break
                    fi
                else
                    _ci_result="success"; break
                fi
                ;;
            failed)  _ci_result="failed"; break ;;
            error)
                if [[ "$_ci_now" -ge "$_ci_grace_deadline" ]]; then
                    _ci_result="api-error"; break
                fi
                ;;
            none)
                if [[ "$_ci_wf_count" != "unknown" ]] && [[ "${_ci_wf_count:-0}" -eq 0 ]]; then
                    # No CI at all — the pending-review rule still holds.
                    if [[ "$_ci_review_pending" == true ]]; then
                        if [[ "$_ci_now" -ge "$_ci_deadline" ]]; then
                            _ci_result="review-pending"; break
                        fi
                    elif [[ "$_ci_review_unknown" == true ]]; then
                        if [[ "$_ci_now" -ge "$_ci_grace_deadline" ]]; then
                            _ci_result="review-unreadable"; break
                        fi
                    else
                        _ci_result="no-ci"; break
                    fi
                elif [[ "$_ci_now" -ge "$_ci_grace_deadline" ]]; then
                    _ci_result="never-registered"; break
                fi
                ;;
            *)  # pending, registered
                if [[ "$_ci_now" -ge "$_ci_deadline" ]]; then
                    _ci_result="timeout"; break
                fi
                ;;
        esac
        [[ "$MERGE_PR_CI_POLL_SECONDS" -gt 0 ]] && sleep "$MERGE_PR_CI_POLL_SECONDS"
    done
    case "$_ci_result" in
        success)
            echo "  ✅ CI checks passed on \`${CI_TARGET_SHA:0:7}\`" ;;
        no-ci)
            echo "  no CI configured for ${PR_REPO_SLUG}; nothing to wait for" ;;
        failed)
            _pr_url=$(gh pr view "$PR_NUMBER" "${GH_REPO_ARGS[@]}" --json url --jq '.url' 2>/dev/null || echo "")
            {
                echo "ERROR: CI checks failed on \`${CI_TARGET_SHA:0:7}\`"
                [[ -n "$_pr_url" ]] && echo "  See: $_pr_url"
                echo "  Fix the failure and re-run, or pass --no-wait to skip the CI wait."
            } >&2
            exit 1 ;;
        api-error)
            {
                echo "ERROR: gh api failed repeatedly while checking CI for \`${CI_TARGET_SHA:0:7}\` (rate limit, network, 5xx, or auth) after ${MERGE_PR_CI_GRACE_SECONDS}s"
                echo "  No merge attempted — re-run once the API is reachable, or pass --no-wait to skip the CI wait."
            } >&2
            exit 1 ;;
        never-registered)
            {
                echo "ERROR: no checks registered for \`${CI_TARGET_SHA:0:7}\` after ${MERGE_PR_CI_GRACE_SECONDS}s"
                echo "  if this commit is excluded by workflow path filters, re-run with --no-wait"
            } >&2
            exit 1 ;;
        timeout)
            _pr_url=$(gh pr view "$PR_NUMBER" "${GH_REPO_ARGS[@]}" --json url --jq '.url' 2>/dev/null || echo "")
            {
                echo "ERROR: CI checks did not complete on \`${CI_TARGET_SHA:0:7}\` within ${MERGE_PR_CI_TIMEOUT_SECONDS}s"
                [[ -n "$_pr_url" ]] && echo "  See: $_pr_url"
            } >&2
            exit 1 ;;
        review-unreadable)
            {
                echo "ERROR: could not read the check-runs of \`${_ci_review_sha:0:7}\`, the commit the review runs on, within ${MERGE_PR_CI_GRACE_SECONDS}s, so whether review check-run '${MERGE_PR_CI_EXCLUDE_CHECK_RUN}' is still in progress is unknown (CI itself is green or absent)"
                echo "  No merge attempted — re-run once the API is reachable, or pass --allow-pending-review to merge without the review state."
            } >&2
            exit 1 ;;
        review-pending)
            _pr_url=$(gh pr view "$PR_NUMBER" "${GH_REPO_ARGS[@]}" --json url --jq '.url' 2>/dev/null || echo "")
            {
                echo "ERROR: review check-run '${MERGE_PR_CI_EXCLUDE_CHECK_RUN}' still in progress on \`${_ci_review_sha:0:7}\` after ${MERGE_PR_CI_TIMEOUT_SECONDS}s (CI itself is green or absent)"
                [[ -n "$_pr_url" ]] && echo "  See: $_pr_url"
                echo "  Re-run once the review completes, or pass --allow-pending-review to merge without waiting for it."
            } >&2
            exit 1 ;;
    esac
else
    echo "  CI wait skipped (--no-wait)"
fi

# --- Step 2 (cont.): Let mergeability settle before merging (#282, #290) ---
# Right after Step 1 / 1.5's own push, GitHub may still report
# `mergeable: UNKNOWN` while it recomputes — `gh pr merge` refuses
# instantly in that window. Poll until it resolves, bounded by the same
# grace window as the "checks never register" case above. This runs with
# or without --no-wait (#290): the recompute is caused by this script's own
# push, not by CI. rc 2 means it settled to `CONFLICTING`: fail fast with a
# clear message instead of letting `gh pr merge` fail on it below.
_mg_state=""
_mg_rc=0
_mg_state=$(_wait_for_mergeable) || _mg_rc=$?
if [[ $_mg_rc -eq 2 ]]; then
    _pr_url=$(gh pr view "$PR_NUMBER" "${GH_REPO_ARGS[@]}" --json url --jq '.url' 2>/dev/null || echo "")
    {
        echo "ERROR: PR #${PR_NUMBER} has merge conflicts (mergeable: CONFLICTING) — resolve them before merging"
        [[ -n "$_pr_url" ]] && echo "  See: $_pr_url"
    } >&2
    exit 1
elif [[ $_mg_rc -ne 0 ]]; then
    _pr_url=$(gh pr view "$PR_NUMBER" "${GH_REPO_ARGS[@]}" --json url --jq '.url' 2>/dev/null || echo "")
    {
        if [[ "$_mg_state" == "LOOKUP_FAILED" ]]; then
            echo "ERROR: mergeability for PR #${PR_NUMBER} never settled after ${MERGE_PR_CI_GRACE_SECONDS}s — the last poll could not reach GitHub (\`gh pr view\` failed), so the state is unknown rather than reported UNKNOWN"
        else
            echo "ERROR: mergeability for PR #${PR_NUMBER} never settled (still UNKNOWN) after ${MERGE_PR_CI_GRACE_SECONDS}s"
        fi
        [[ -n "$_pr_url" ]] && echo "  See: $_pr_url"
    } >&2
    exit 1
fi
echo "  mergeability: $_mg_state"

# --- Step 3: Merge ---
# GH_REPO_ARGS was set during PR resolution above (-R <repo> for a package
# or project PR, empty for a workspace PR). Don't re-resolve.
#
# GitHub's GraphQL merge has been observed refusing right after our own
# push with a mergeability recompute still in flight even after Step 2's
# settle reported `mergeable` — a narrow remaining race. On a "not
# mergeable" refusal, re-poll mergeability once more and retry the merge
# once before giving up. Like the settle, this runs with or without
# --no-wait (#290).
_do_merge_once() {
    local ef rc=0
    ef=$(mktemp)
    gh pr merge "$PR_NUMBER" "${GH_REPO_ARGS[@]}" --merge 2>"$ef" || rc=$?
    _merge_err="$(cat "$ef")"
    [[ -n "$_merge_err" ]] && cat "$ef" >&2
    rm -f "$ef"
    return $rc
}

echo "  Merging PR..."
_merge_rc=0
_merge_err=""
_do_merge_once || _merge_rc=$?
if [[ $_merge_rc -ne 0 ]] && grep -qi "not mergeable" <<<"$_merge_err"; then
    echo "  ⚠️  gh pr merge refused (not mergeable) — re-polling mergeability once and retrying"
    _mg_retry_rc=0
    _wait_for_mergeable >/dev/null || _mg_retry_rc=$?
    if [[ $_mg_retry_rc -eq 2 ]]; then
        echo "ERROR: PR #${PR_NUMBER} now has merge conflicts (mergeable: CONFLICTING) — resolve them before merging" >&2
        exit 1
    fi
    _merge_rc=0
    _do_merge_once || _merge_rc=$?
fi
if [[ $_merge_rc -ne 0 ]]; then
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
        # Fast-forward the owning repository's own checkout (the layer's
        # src/<repo> the worktree was made from) only when it is clean and
        # on the branch this PR merged into; anywhere else a pull would
        # move some other branch, or fail on a detached HEAD (a pin at a
        # tag or a commit) or a dirty tree, for no problem of the merge's.
        # There it fetches only and says why (issue 429), the rule
        # adapter_sync follows. A failed pull or fetch marks the cleanup
        # incomplete. The workspace and project sync (Step 6) is unchanged.
        _own_branch="$(git -C "$_OWN_ORIGIN" symbolic-ref --short -q HEAD 2>/dev/null || true)"
        _own_dirty="$(git -C "$_OWN_ORIGIN" status --porcelain 2>/dev/null || echo "status failed")"
        _OWN_FETCH_ONLY=""
        if [[ -z "$PR_BASE_REF" ]]; then
            _OWN_FETCH_ONLY="no base known (the PR's base branch could not be read)"
        elif [[ -z "$_own_branch" ]]; then
            _OWN_FETCH_ONLY="detached HEAD, not the base $PR_BASE_REF"
        elif [[ "$_own_branch" != "$PR_BASE_REF" ]]; then
            _OWN_FETCH_ONLY="on $_own_branch, not the base $PR_BASE_REF"
        elif [[ -n "$_own_dirty" ]]; then
            _OWN_FETCH_ONLY="not clean"
        fi
        if [[ -z "$_OWN_FETCH_ONLY" ]]; then
            # origin's base, named: never the branch's configured upstream,
            # which can be another remote or branch, or missing.
            if _git_err="$(wt_bounded_git -C "$_OWN_ORIGIN" pull --ff-only --no-rebase origin "$PR_BASE_REF" 2>&1)"; then
                echo "  ✅ $PR_REPO_SLUG synced ($PR_BASE_REF fast-forwarded at $_OWN_ORIGIN)"
            else
                echo "  ⚠️  Could not fast-forward $PR_REPO_SLUG's checkout at $_OWN_ORIGIN:" >&2
                echo "     ${_git_err:-no output}" >&2
                _CLEANUP_INCOMPLETE=true
            fi
        else
            _own_frc=0
            _git_err="$(wt_bounded_git -C "$_OWN_ORIGIN" fetch --quiet origin 2>&1)" || _own_frc=$?
            if [[ "$_own_frc" -eq 0 ]]; then
                echo "  ℹ️  $PR_REPO_SLUG's checkout at $_OWN_ORIGIN fetched only: $_OWN_FETCH_ONLY"
            else
                echo "  ⚠️  Could not fetch origin in $PR_REPO_SLUG's checkout at $_OWN_ORIGIN ($_OWN_FETCH_ONLY, so no pull was due):" >&2
                echo "     $(wt_fetch_why "$_own_frc" "${_git_err:-}")" >&2
                _CLEANUP_INCOMPLETE=true
                _OWN_FETCH_ONLY=""
            fi
        fi
        unset _git_err _own_branch _own_dirty _own_frc
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
    # --- Step 4 (workspace / legacy single-repo project PR) ---
    if [[ -n "$WORKTREE_TYPE" ]]; then
        echo "  Removing worktree..."
        # Must run from root, not from inside the worktree
        cd "$ROOT_DIR"
        _WR_ARGS=(--issue "$ISSUE_NUM" --type "$WORKTREE_TYPE")
        [[ "$WORKTREE_TYPE" == "project" ]] && [[ -n "$PROJECT_ARG" ]] && _WR_ARGS+=(--project "$PROJECT_ARG")
        if "$SCRIPT_DIR/worktree_remove.sh" "${_WR_ARGS[@]}"; then
            echo "  ✅ Worktree removed"
        else
            echo "  ⚠️  Worktree removal failed — check for uncommitted changes" >&2
            _CLEANUP_INCOMPLETE=true
        fi
        unset _WR_ARGS
    fi

    # --- Step 5: Delete branches ---
    echo "  Cleaning up branches..."
    # The project's checkout root (#265): PJ_REPO_ROOT (registered or
    # legacy project/, resolved above) when this is a project PR, else the
    # workspace root.
    if [[ "$WORKTREE_TYPE" == "project" ]] && [[ -n "$PJ_REPO_ROOT" ]]; then
        BRANCH_REPO="$PJ_REPO_ROOT"
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
    if [[ "$WORKTREE_TYPE" == "project" ]] && [[ -n "$PJ_REPO_ROOT" ]] && [[ -e "$PJ_REPO_ROOT/.git" ]]; then
        echo "  Syncing project..."
        git -C "$PJ_REPO_ROOT" pull --ff-only 2>/dev/null && echo "  ✅ Project synced" || true
    fi
fi

echo ""
echo "========================================"
if [[ "${_CLEANUP_INCOMPLETE:-false}" == true ]]; then
    echo "⚠️  Done: PR #${PR_NUMBER} merged, but cleanup incomplete — see warnings above"
elif [[ "${_WORKTREE_KEPT:-false}" == true ]]; then
    echo "✅ Done: PR #${PR_NUMBER} merged; worktree kept until the sibling package PR(s) above are resolved"
elif [[ -n "${_OWN_FETCH_ONLY:-}" ]]; then
    echo "✅ Done: PR #${PR_NUMBER} merged and cleaned up; $PR_REPO_SLUG's checkout was fetched only, not fast-forwarded ($_OWN_FETCH_ONLY)"
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
