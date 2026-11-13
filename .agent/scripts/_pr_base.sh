#!/bin/bash
# .agent/scripts/_pr_base.sh
# The base branch of a package repository's pull request (issue 429): the
# branch the owning repository's feature/issue-<N> branch starts from and
# its pull request targets. The owner's rule (issue 429, 2026-11-10): it
# comes from the project's pin of that repository, never from the forge's
# default branch. Sourced by dispatch_phase.sh (`base`).
#
# Source it from bash:
#   source "$SCRIPT_DIR/_pr_base.sh"
#
#   pr_base_for --repo <name> [--layer <l>] [--project <p>]
#               [--recorded <branch>] [--base <branch>]
#     Prints the base branch on one line and returns 0, or prints why not
#     on stderr and returns 2. In this order:
#       1. --recorded (the base= of the worktree's manifest header) is the
#          answer; a --base that differs from it is refused, since the
#          branch already started from the recorded one.
#       2. --base (the owner's override) is the answer. Whether origin has
#          it is decided where something is made from it: worktree
#          creation's strict start path, or the resume write-back in
#          dispatch_phase.sh base.
#       3. Otherwise `adapter repo_pin <name> [--layer <l>]` (ADR-0019), the
#          type's own reading of its pin, prints "<ref>\t<kind>":
#            branch                 -> <ref> is the base;
#            tag, commit, unknown   -> refused, naming it: only a branch
#                                      can be a base;
#            exit 1                 -> refused; the adapter's own message
#                                      (on stderr already) says why.
#          Nothing is guessed: not the forge's default branch, not
#          origin/HEAD. The adapter's NOTE that it answered from local refs
#          (offline, "unverified") passes through on stderr unparsed;
#          creation, which asks origin again, decides then.
#     <name> is the owning repository's directory name in the layer (the
#     last part of its manifest entry's path), which can differ from the
#     forge name in owner/repo#N. --layer is passed whenever it is known:
#     a repository pinned at different refs in several layers needs it.
#     This file names no project type; the type answers in its adapter.
#
# user-tier: inert -- this file only defines a function; the one command
# it runs is the adapter's read-only repo_pin verb.

_PR_BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pr_base_for() {
    local repo="" layer="" project="" recorded="" override=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --repo)     repo="${2:-}"; shift 2 || return 2 ;;
            --layer)    layer="${2:-}"; shift 2 || return 2 ;;
            --project)  project="${2:-}"; shift 2 || return 2 ;;
            --recorded) recorded="${2:-}"; shift 2 || return 2 ;;
            --base)     override="${2:-}"; shift 2 || return 2 ;;
            *) echo "error: pr_base_for: unknown argument '$1'" >&2; return 2 ;;
        esac
    done
    if [ -z "$repo" ]; then
        echo "error: pr_base_for: --repo <name> is required" >&2
        return 2
    fi
    if [ -n "$override" ] && ! git check-ref-format "refs/heads/$override" >/dev/null 2>&1; then
        echo "error: --base '$override' is not a valid branch name" >&2
        return 2
    fi
    if [ -n "$recorded" ]; then
        if [ -n "$override" ] && [ "$override" != "$recorded" ]; then
            echo "error: the worktree records base=$recorded for $repo, and its branch started there; --base $override differs. Drop --base, or start a new worktree for another base." >&2
            return 2
        fi
        printf '%s\n' "$recorded"
        return 0
    fi
    if [ -n "$override" ]; then
        printf '%s\n' "$override"
        return 0
    fi
    local -a args=()
    [ -n "$project" ] && args+=(--project "$project")
    args+=(repo_pin "$repo")
    [ -n "$layer" ] && args+=(--layer "$layer")
    local out rc=0
    out="$("$_PR_BASE_DIR/adapter" "${args[@]}")" || rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "error: the project's pin of $repo could not be read (adapter repo_pin exited $rc; its message is above), so there is no base; none is guessed. Fix the pin, or pass --base <branch>." >&2
        return 2
    fi
    local ref kind
    if [[ "$out" != *$'\t'* ]] || [ "$(printf '%s\n' "$out" | wc -l)" -ne 1 ]; then
        echo "error: adapter repo_pin $repo printed '$out', not one '<ref><TAB><kind>' line, so there is no base; none is guessed. Pass --base <branch>." >&2
        return 2
    fi
    ref="${out%%$'\t'*}"
    kind="${out#*$'\t'}"
    case "$kind" in
        branch)
            if [ -z "$ref" ] || ! git check-ref-format "refs/heads/$ref" >/dev/null 2>&1; then
                echo "error: adapter repo_pin $repo named the branch '$ref', which is not a valid branch name; no base is guessed. Pass --base <branch>." >&2
                return 2
            fi
            printf '%s\n' "$ref"
            return 0
            ;;
        tag|commit|unknown)
            echo "error: $repo is pinned at $ref ($kind); only a branch can be a base. Pass --base <branch>." >&2
            return 2
            ;;
        *)
            echo "error: adapter repo_pin $repo gave the kind '$kind' for '$ref', not branch, tag, commit or unknown; no base is guessed. Pass --base <branch>." >&2
            return 2
            ;;
    esac
}
