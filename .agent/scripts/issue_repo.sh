#!/usr/bin/env bash
# .agent/scripts/issue_repo.sh
# The GitHub repository of an issue of this checkout, for skills that call
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
# Exit 0 also means: the issue is this checkout's, so its local records
# (the plan, the progress timeline) are the ones in this checkout. This is
# the session-root rule (a session changes only the root it was started
# in), decided here once for every skill: an issue of another repository is
# worked from a checkout of that repository, and named here it is refused
# (exit 6) before any skill reads or writes a record or posts anything.
#
# What a bare number means: issue N of this checkout's repository. A
# qualified owner/repo#N is accepted when owner/repo is this checkout's
# repository, and the repository is printed as this checkout names it
# (its casing, not the caller's). The ref grammar is dispatch_phase.sh's
# parse_issue_ref, with no leading zeros (issue_checkout_of and the
# records paths compare the number as text).
#
# This checkout's repository, in order:
#   a. Inside a package worktree (ADR-0012; the .worktree-repos manifest
#      found by _wpd_enclosing_manifest) whose header is issue=<H>#<N> for
#      this number, and only in the manifest's issue checkout
#      (issue_checkout_of), it is <H>: the repository dispatch_phase.sh's
#      resolve_issue_dir checks gh against, so the two cannot disagree. That
#      checkout's origin may be a fork of <H>. In a sibling repository's
#      checkout of that worktree the header says nothing about this
#      checkout and is ignored. Otherwise it is origin's slug
#      (extract_gh_slug: only a github.com remote names a GitHub
#      repository).
#   b. A qualified ref is compared with it (case ignored), with no gh call:
#      the same, exit 0; another, exit 6. When no GitHub repository is read
#      from this checkout (no origin, an origin on another host, an SSH
#      host alias such as git@<alias>:owner/repo.git, ssh.github.com:443),
#      a qualified ref cannot be shown to be this checkout's: exit 6. gh is
#      not asked: it answers with the remote it prefers, not the checkout's.
#   c. A bare number is decided locally, no gh call and no network, when
#      the repository is origin's slug, GH_REPO is unset, no other remote
#      names a different GitHub repository and no remote.*.gh-resolved is
#      set (gh repo set-default writes it): gh could only mean origin.
#   d. Otherwise gh is asked once, the call project_integration_audit.sh
#      makes (GH_HOST pinned, no prompt, stdin closed); stdout alone is
#      the answer, as in resolve_issue_dir. The same repository (case
#      ignored): exit 0. Another: exit 2.
#
# Exit codes:
#   0  the repository is on stdout, and it is this checkout's
#   1  usage: no argument, or not <N> / <owner/repo#N> (a number with
#      leading zeros, or 0, included)
#   2  a bare number, and gh, run here, resolves another repository than
#      this checkout's (an upstream remote gh prefers, a set default,
#      GH_REPO); the message names both and the fix. It never advises
#      `gh repo set-default` toward a repository that is not this
#      checkout's own (in a package worktree's issue checkout, the
#      header's repository), and with GH_REPO set it says to unset it.
#   3  this is no checkout an issue can be worked from: not inside a git
#      repository; inside a package worktree but in none of its checkouts
#      (its top folder, whatever its header says, even when the folder
#      sits inside some other repository); or a package worktree whose
#      header names this number but whose issue checkout cannot be found
#      (issue_checkout_of's message quoted; the dispatcher refuses it too)
#   4  a bare number, and no GitHub repository can be read here: no origin,
#      or an origin not on github.com, and no header repository. An
#      ordinary case, not an error: the caller makes no gh call. An origin
#      through an SSH host alias or ssh.github.com:443 lands here too,
#      although gh resolves it: only a github.com origin URL is read as a
#      GitHub repository (owner/repo#N is refused there, case b).
#   5  a bare number, gh had to be asked and could not answer (missing,
#      not logged in, offline, silent); its message is quoted
#   6  a qualified owner/repo#N that is not this checkout's repository, or
#      in a checkout from which no GitHub repository is read (so it cannot
#      be shown to be this checkout's): the message says why and what works
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
    [[ -n "${1:-}" ]] && echo "  $1" >&2
    exit 1
}

[[ $# -eq 1 ]] || usage
REF="$1"
REF_REPO=""     # owner/repo of a qualified ref
if [[ "$REF" =~ ^([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)#([0-9]+)$ ]]; then
    REF_REPO="${BASH_REMATCH[1]}"
    N="${BASH_REMATCH[2]}"
elif [[ "$REF" =~ ^[0-9]+$ ]]; then
    N="$REF"
else
    usage
fi
[[ "$N" =~ ^[1-9][0-9]*$ ]] || usage "an issue number is written without leading zeros and is not 0 (got '$REF')"

phys() { (cd "$1" 2>/dev/null && pwd -P); }

TOP=$(git rev-parse --show-toplevel 2>/dev/null) || TOP=""
[[ -n "$TOP" ]] && TOP=$(phys "$TOP")
WHERE="${REF_REPO:+a checkout of $REF_REPO}"
WHERE="${WHERE:-the checkout of the repository that owns issue $N}"

# --- a. the package worktree's header, if this is its issue checkout ---
# The manifest enclosing this checkout; else the one enclosing the cwd,
# which puts the cwd inside a package worktree but in none of its
# checkouts (its top folder, which may sit inside some other repository).
WT=""
IN_CHECKOUT=0
if [[ -n "$TOP" ]] && WT=$(_wpd_enclosing_manifest "$TOP"); then
    IN_CHECKOUT=1
else
    WT=$(_wpd_enclosing_manifest "$PWD") || WT=""
fi

HDR_REPO=""     # set only when the header counts for this checkout
HDR_REF=""      # owner/repo#N when the manifest's header names this number
own=""
if [[ -n "$WT" ]]; then
    # The read resolve_issue_dir and _wt_manifest_issue_field make.
    hdr=$(head -n1 "$WT/.worktree-repos" | sed -n 's/.* issue=\([^ ]*\).*/\1/p')
    if [[ "$hdr" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+#${N}$ ]]; then
        HDR_REF="$hdr"
        if own=$(issue_checkout_of "$WT" "$N" 2>/dev/null); then
            own=$(phys "$own")
        else
            own=""
            if [[ $IN_CHECKOUT -eq 1 ]]; then
                why=$(issue_checkout_of "$WT" "$N" 2>&1 >/dev/null | tr '\n' ' ')
                {
                    echo "error: $WT is the package worktree for $HDR_REF, but its issue checkout cannot be found: ${why:-issue_checkout_of gave no answer}"
                    echo "  dispatch_phase.sh refuses this worktree for issue $N too. Put the issue's checkout on feature/issue-$N (one entry of .worktree-repos), then run from it."
                } >&2
                exit 3
            fi
        fi
    fi
    if [[ $IN_CHECKOUT -eq 0 ]]; then
        {
            echo "error: $PWD is inside the package worktree $WT but in none of its checkouts; its top folder is no repository of its own."
            if [[ -n "$own" ]]; then
                echo "  Issue $HDR_REF is worked from its checkout: run from $own."
            elif [[ "$hdr" == */*#* ]]; then
                echo "  The worktree is for $hdr: run from its issue checkout."
            else
                echo "  Run from $WHERE."
            fi
        } >&2
        exit 3
    fi
    if [[ -n "$own" && "$TOP" == "$own" ]]; then
        HDR_REPO="${HDR_REF%#*}"
    fi
    # A sibling repository's checkout: the header is not about this
    # checkout, so its own origin decides (below).
fi

if [[ -z "$TOP" ]]; then
    {
        echo "error: $PWD is not inside a git repository, so it is no checkout of the repository that owns issue ${REF_REPO:+$REF_REPO}#$N."
        echo "  Run from $WHERE."
    } >&2
    exit 3
fi

ORIGIN_SLUG=$(extract_gh_slug "$(git -C "$TOP" remote get-url origin 2>/dev/null)")
EXPECTED="${HDR_REPO:-$ORIGIN_SLUG}"

ERRF=""
trap '[[ -n "$ERRF" ]] && rm -f "$ERRF"' EXIT
# ask_gh: GOT and GHERR from one `gh repo view` in this checkout; returns
# non-zero when gh is missing, fails or is silent.
ask_gh() {
    GOT=""
    GHERR=""
    if ! command -v gh >/dev/null 2>&1; then
        GHERR="gh is not installed"
        return 1
    fi
    ERRF=$(mktemp) || { GHERR="could not create a temporary file for gh's stderr"; return 1; }
    local rc
    GOT=$(cd "$TOP" && GH_HOST=github.com GH_PROMPT_DISABLED=1 gh repo view --json nameWithOwner --jq .nameWithOwner 2>"$ERRF" </dev/null); rc=$?
    GHERR=$(head -c 600 "$ERRF" | tr '\n' ' ')
    [[ $rc -eq 0 && -n "$GOT" ]] || { GHERR="${GHERR:-gh gave no answer}"; return 1; }
}

# --- b. a qualified ref: is it this checkout's repository? ---
if [[ -n "$REF_REPO" ]]; then
    if [[ -n "$EXPECTED" ]]; then
        if [[ "${REF_REPO,,}" == "${EXPECTED,,}" ]]; then
            echo "$EXPECTED"
            exit 0
        fi
        from=""
        [[ -n "$HDR_REPO" ]] && from=" (from the package worktree's manifest)"
        {
            echo "error: $REF is an issue of $REF_REPO, but this checkout ($TOP) is $EXPECTED's$from."
            echo "  A session works only on the issues of the repository it was started in: run this from a checkout of $REF_REPO."
        } >&2
        exit 6
    fi
    # No GitHub repository is read from this checkout, so nothing here can
    # show the ref to be its own (gh would answer with the remote it
    # prefers, not the checkout's).
    {
        echo "error: $REF names $REF_REPO, but this checkout ($TOP) has no origin on github.com,"
        echo "  so $REF_REPO cannot be shown to be its repository (an SSH host alias or ssh.github.com:443 origin is not read as one)."
        echo "  Run from a checkout whose origin is on github.com, or pass the bare number $N here: this checkout then takes"
        echo "  the no-GitHub-remote path (exit 4: no gh call, the issue's text from the owner)."
    } >&2
    exit 6
fi

if [[ -z "$EXPECTED" ]]; then
    {
        echo "note: $TOP has no GitHub repository (no origin on github.com), so issue $N is not a GitHub issue here: no gh call will be made."
        echo "  An origin through an SSH host alias (git@<alias>:owner/repo.git) or ssh.github.com:443 lands here too although gh resolves it:"
        echo "  only an origin URL on github.com is read as a GitHub repository, and owner/repo#$N is refused here (exit 6)."
    } >&2
    exit 4
fi

# --- c. decide locally when gh could only mean origin ---
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

# --- d. ask gh once ---
if ! ask_gh; then
    {
        if [[ "$GHERR" == "gh is not installed" ]]; then
            echo "error: gh is not installed, and in $TOP it must be asked which repository issue $N is in"
            echo "  (another GitHub remote, a gh default or GH_REPO leaves a choice). Install and log in to gh, or pass ${EXPECTED}#$N."
        else
            echo "error: could not ask gh which repository it resolves in $TOP: $GHERR"
            echo "  Log in to gh (gh auth login), or pass ${EXPECTED}#$N."
        fi
    } >&2
    exit 5
fi

if [[ "${GOT,,}" == "${EXPECTED,,}" ]]; then
    echo "$EXPECTED"
    exit 0
fi

if [[ -n "${GH_REPO:-}" ]]; then
    from=""
    [[ -n "$HDR_REPO" ]] && from=" (from the package worktree's manifest, issue $HDR_REF)"
    {
        echo "error: GH_REPO is set to '$GH_REPO', and gh uses it over every remote: gh resolves $GOT,"
        echo "  but this checkout's repository ($TOP) is $EXPECTED$from. A bare issue number means $EXPECTED."
        echo "  Unset GH_REPO (a gh default does not override it), or pass ${EXPECTED}#$N."
    } >&2
elif [[ -n "$HDR_REPO" ]]; then
    {
        echo "error: in $TOP, gh resolves $GOT, but the issue is $HDR_REF (repository $HDR_REPO, from the package worktree's manifest)."
        echo "  The dispatcher (dispatch_phase.sh) expects $HDR_REPO here too. Set gh's default:"
        echo "    (cd $TOP && gh repo set-default $HDR_REPO)"
        echo "  or pass $HDR_REF."
    } >&2
else
    {
        echo "error: in $TOP, gh resolves $GOT, but this checkout's repository (origin) is $EXPECTED."
        echo "  gh prefers a remote named upstream over origin when no default is set. A bare issue number"
        echo "  means $EXPECTED. Either set gh's default:"
        echo "    (cd $TOP && gh repo set-default $EXPECTED)"
        echo "  or pass ${EXPECTED}#$N. An issue of $GOT is worked from a checkout of $GOT."
    } >&2
fi
exit 2
