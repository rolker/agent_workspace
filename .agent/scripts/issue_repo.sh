#!/usr/bin/env bash
# .agent/scripts/issue_repo.sh
# The GitHub repository an issue reference names, for skills that call
# `gh issue` / `gh pr` (issue 581). They pass it on every call as
# `-R "github.com/<owner/repo>"`, so the repository never depends on the
# directory gh happens to run in or on which remote gh prefers.
#
#   issue_repo.sh <N>
#   issue_repo.sh <owner/repo#N>
#
# stdout is the single line <owner/repo> on exit 0 and nothing otherwise;
# every message goes to stderr. Reads only: it never writes and never
# prompts, and gh is asked at most once, read-only (`gh repo view`).
#
# What a bare number means: the issue of the repository of the checkout it
# is run in (the session-root rule). An issue of another repository is
# written owner/repo#N, which is printed as given, from anywhere, with no
# git or gh call. The ref grammar is dispatch_phase.sh's parse_issue_ref.
#
# A bare number, in order:
#   a. The expected repository. Inside a package worktree (ADR-0012; the
#      .worktree-repos manifest found by _wpd_enclosing_manifest) whose
#      header is issue=<H>#<N> for this number, and only in the manifest's
#      issue checkout (issue_checkout_of), it is <H>: the repository
#      dispatch_phase.sh's resolve_issue_dir checks gh against, so the two
#      cannot disagree. In a sibling repository's checkout of that
#      worktree the header says nothing about this checkout and is
#      ignored. Otherwise it is origin's slug (extract_gh_slug: only a
#      github.com remote names a GitHub repository).
#   b. Decided locally, no gh call and no network, when the expected
#      repository is origin's slug, GH_REPO is unset, no other remote names
#      a different GitHub repository and no remote.*.gh-resolved is set
#      (gh repo set-default writes it): gh could only mean origin.
#   c. Otherwise gh is asked once, the call project_integration_audit.sh
#      makes (GH_HOST pinned, no prompt, stdin closed); stdout alone is
#      the answer, as in resolve_issue_dir. The same repository as
#      expected (case ignored): exit 0. Another: exit 2.
#
# Exit codes:
#   0  the repository is on stdout
#   1  usage: no argument, or not <N> / <owner/repo#N>
#   2  gh, run here, resolves another repository than the expected one
#      (an upstream remote gh prefers, a set default, GH_REPO); the message
#      names both and the fix. It never advises `gh repo set-default`
#      toward a repository that is not this checkout's own (in a package
#      worktree's issue checkout, the header's repository).
#   3  not inside a git repository (a package worktree's top folder
#      included: the message names the header's owner/repo#N)
#   4  no GitHub repository here: no origin, or an origin not on
#      github.com, and no header repository. An ordinary case, not an
#      error: the caller makes no gh call.
#   5  gh had to be asked and could not answer (missing, not logged in,
#      offline, silent); its message is quoted
#
# user-tier: inert -- read-only: prints a repository on stdout (or the
# reason on stderr) and writes nothing; its one gh call is `gh repo view`.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_issue_helpers.sh
source "$SCRIPT_DIR/_issue_helpers.sh"
# shellcheck source=_resolve_work_plans_dir.sh
source "$SCRIPT_DIR/_resolve_work_plans_dir.sh"

usage() {
    echo "usage: issue_repo.sh <N> | <owner/repo#N>" >&2
    exit 1
}

[[ $# -eq 1 ]] || usage
REF="$1"

if [[ "$REF" =~ ^([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)#[0-9]+$ ]]; then
    echo "${BASH_REMATCH[1]}"
    exit 0
fi
[[ "$REF" =~ ^[0-9]+$ ]] || usage
N="$REF"

phys() { (cd "$1" 2>/dev/null && pwd -P); }

TOP=$(git rev-parse --show-toplevel 2>/dev/null) || TOP=""
[[ -n "$TOP" ]] && TOP=$(phys "$TOP")

# --- a. the package worktree's header, if this is its issue checkout ---
# The manifest enclosing this checkout, else the one enclosing the cwd (a
# package worktree's top folder may sit inside some other repository), as
# issue_checkout_guard looks for it.
WT=""
[[ -n "$TOP" ]] && WT=$(_wpd_enclosing_manifest "$TOP") || WT=""
[[ -z "$WT" ]] && { WT=$(_wpd_enclosing_manifest "$PWD") || WT=""; }

HDR_REPO=""     # set only when the header counts for this checkout
HDR_REF=""      # owner/repo#N when the manifest's header names this number
if [[ -n "$WT" ]]; then
    # The read resolve_issue_dir and _wt_manifest_issue_field make.
    hdr=$(head -n1 "$WT/.worktree-repos" | sed -n 's/.* issue=\([^ ]*\).*/\1/p')
    if [[ "$hdr" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+#${N}$ ]]; then
        HDR_REF="$hdr"
        own=$(issue_checkout_of "$WT" "$N" 2>/dev/null) && own=$(phys "$own") || own=""
        if [[ -n "$TOP" && -n "$own" && "$TOP" == "$own" ]]; then
            HDR_REPO="${hdr%#*}"
        elif [[ -z "$TOP" || ( "$TOP" != "$WT" && "$TOP" != "$WT"/* ) ]]; then
            # Not in any checkout of this worktree: its top folder, which is
            # no repository of its own.
            {
                echo "error: $PWD is the top folder of the package worktree for $HDR_REF, not a repository of its own."
                echo "  Run from the issue's checkout${own:+ ($own)}, or pass $HDR_REF."
            } >&2
            exit 3
        fi
        # A sibling repository's checkout: the header is not about this
        # checkout, so its own origin decides (below).
    fi
fi

if [[ -z "$TOP" ]]; then
    {
        echo "error: $PWD is not inside a git repository, so a bare issue number names no repository."
        echo "  Run from the checkout of the repository that owns issue $N, or pass owner/repo#$N."
    } >&2
    exit 3
fi

ORIGIN_SLUG=$(extract_gh_slug "$(git -C "$TOP" remote get-url origin 2>/dev/null)")
EXPECTED="${HDR_REPO:-$ORIGIN_SLUG}"

if [[ -z "$EXPECTED" ]]; then
    echo "note: $TOP has no GitHub repository (no origin on github.com), so issue $N is not a GitHub issue here: no gh call will be made. Pass owner/repo#$N if it is one." >&2
    exit 4
fi

# --- b. decide locally when gh could only mean origin ---
local_ok=1
[[ -n "${GH_REPO:-}" ]] && local_ok=0
[[ "${EXPECTED,,}" != "${ORIGIN_SLUG,,}" ]] && local_ok=0
if git -C "$TOP" config --get-regexp '^remote\..*\.gh-resolved$' >/dev/null 2>&1; then
    local_ok=0
fi
if [[ $local_ok -eq 1 ]]; then
    while IFS= read -r r; do
        [[ "$r" == origin ]] && continue
        s=$(extract_gh_slug "$(git -C "$TOP" remote get-url "$r" 2>/dev/null)")
        if [[ -n "$s" && "${s,,}" != "${ORIGIN_SLUG,,}" ]]; then
            local_ok=0
            break
        fi
    done < <(git -C "$TOP" remote 2>/dev/null)
fi
if [[ $local_ok -eq 1 ]]; then
    echo "$EXPECTED"
    exit 0
fi

# --- c. ask gh once ---
if ! command -v gh >/dev/null 2>&1; then
    {
        echo "error: gh is not installed, and in $TOP it must be asked which repository issue $N is in"
        echo "  (another GitHub remote, a gh default or GH_REPO leaves a choice). Install and log in to gh, or pass ${EXPECTED}#$N."
    } >&2
    exit 5
fi
ERRF=$(mktemp) || { echo "error: could not create a temporary file for gh's stderr" >&2; exit 5; }
trap 'rm -f "$ERRF"' EXIT
GOT=$(cd "$TOP" && GH_HOST=github.com GH_PROMPT_DISABLED=1 gh repo view --json nameWithOwner --jq .nameWithOwner 2>"$ERRF" </dev/null); rc=$?
if [[ $rc -ne 0 || -z "$GOT" ]]; then
    gherr=$(head -c 600 "$ERRF" | tr '\n' ' ')
    {
        echo "error: could not ask gh which repository it resolves in $TOP: ${gherr:-gh gave no answer}"
        echo "  Log in to gh (gh auth login), or pass ${EXPECTED}#$N."
    } >&2
    exit 5
fi

if [[ "${GOT,,}" == "${EXPECTED,,}" ]]; then
    echo "$EXPECTED"
    exit 0
fi

if [[ -n "$HDR_REPO" ]]; then
    {
        echo "error: in $TOP, gh resolves $GOT, but the issue is $HDR_REF (repository $HDR_REPO, from the package worktree's manifest)."
        echo "  The dispatcher (dispatch_phase.sh) expects $HDR_REPO here too. Set gh's default:"
        echo "    (cd $TOP && gh repo set-default $HDR_REPO)"
        echo "  or pass $HDR_REF."
    } >&2
elif [[ -n "${GH_REPO:-}" ]]; then
    {
        echo "error: GH_REPO is set to '$GH_REPO', and gh uses it over every remote: gh resolves $GOT,"
        echo "  but this checkout's repository ($TOP, origin) is $EXPECTED. A bare issue number means $EXPECTED."
        echo "  Unset GH_REPO, or pass ${GOT}#$N if the issue is $GOT's."
    } >&2
else
    {
        echo "error: in $TOP, gh resolves $GOT, but this checkout's repository (origin) is $EXPECTED."
        echo "  gh prefers a remote named upstream over origin when no default is set. A bare issue number"
        echo "  means $EXPECTED. Either set gh's default:"
        echo "    (cd $TOP && gh repo set-default $EXPECTED)"
        echo "  or, if the issue is $GOT's, pass ${GOT}#$N."
    } >&2
fi
exit 2
