#!/bin/bash
# .agent/scripts/review_progress.sh
# Mechanical helpers for the review-code skill's convergence assessment and
# progress.md persistence (issue #269 PR B). The skill body is prose; these
# subcommands hold the parts that must behave identically every run and
# that the script tests can pin.
#
# Usage:
#   review_progress.sh round   --issue <N> --branch <name> [--progress <file>]
#   review_progress.sh verdict --must-fix <N> --round <R> [--prev-must-fix <P>] [--mechanical]
#   review_progress.sh persist --issue <N|""> [--branch <name>] [--title <t>]
#                              [--strict] [--no-progress] < entry.md
#
# round    Prints two lines: "round=<R>" and "prev_must_fix=<P|->". R is the
#          count of prior "## Local Review (Pre-Push)" entries whose
#          **Branch** correlation names <name>, plus 1. P is the must-fix
#          finding count of the most recent such entry ("-" when none).
#          Reads the file via progress_read.py; a missing file is round 1.
#
# verdict  Prints "ship=<recommended|continue>" and "reason=<one line>",
#          applying the convergence rule from the review-code skill:
#            - must-fix == 0                                   -> recommended
#            - round >= 2, must-fix <= 2, not rising vs prev,
#              and --mechanical (every must-fix is a precise
#              file:line fix)                                  -> recommended
#            - otherwise                                       -> continue
#          The verdict is advisory; the operator decides.
#
# persist  Step-8 persistence with the PROGRESS_PERSISTENCE_STRICT switch
#          (plan revision 4/5). Reads ONE entry on stdin. Prints the report
#          line the skill must echo (notice / skip / committed). Modes:
#            --no-progress            -> "Progress persistence skipped (--no-progress)", exit 0
#            --issue ""               -> skip; message names the reason
#                                        (skill worktree vs no linked issue), exit 0
#            strict (--strict, or PROGRESS_PERSISTENCE_STRICT=1)
#                                     -> resolve_work_plans_dir() (fail-loud, exit 4
#                                        with remediation) then progress_append.sh
#            compatibility (default)  -> evaluates resolve_work_plans_dir(); if it
#                                        WOULD abort, prints the one-line notice and
#                                        proceeds with the pre-PR-B mechanism: the
#                                        current worktree's progress.md, inline
#                                        append + `git add` + `git commit`.
#
# sources  Integrator input for triage-reviews: local review findings at the
#          PR head, GitHub inline comments, and candidate cross-source
#          confirmations (same file, same head SHA) as JSON. See cmd_sources.
#
# Exit codes: 0 ok; 2 usage; 3 append/commit failure; 4 strict-mode resolver
# abort.

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    echo "Error: This script should be executed, not sourced." >&2
    return 1
fi
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRESS_READ="$SCRIPT_DIR/progress_read.py"
PROGRESS_APPEND="$SCRIPT_DIR/progress_append.sh"
PYTHON="${PYTHON:-python3}"

usage() {
    cat >&2 <<'EOF'
Usage:
  review_progress.sh round   --issue <N> --branch <name> [--progress <file>]
  review_progress.sh verdict --must-fix <N> --round <R> [--prev-must-fix <P>] [--mechanical]
  review_progress.sh persist --issue <N|""> [--branch <name>] [--title <t>]
                             [--strict] [--no-progress] < entry.md
  review_progress.sh sources --head <sha> --reviews <fetch_pr_reviews.json> [--progress <file>]
See the header comment of this script for what each subcommand prints.
Exit codes: 0 ok; 2 usage/validation; 3 append/commit failure; 4 strict-mode resolver abort.
EOF
    exit 2
}

[[ $# -ge 1 ]] || usage
SUB="$1"; shift

# ---------------------------------------------------------------- round ---
cmd_round() {
    local issue="" branch="" progress=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --issue)    [[ $# -ge 2 ]] || usage; issue="$2"; shift 2 ;;
            --branch)   [[ $# -ge 2 ]] || usage; branch="$2"; shift 2 ;;
            --progress) [[ $# -ge 2 ]] || usage; progress="$2"; shift 2 ;;
            *) usage ;;
        esac
    done
    [[ -n "$branch" ]] || { echo "error: round: --branch required" >&2; exit 2; }
    if [[ -z "$progress" ]]; then
        [[ "$issue" =~ ^[0-9]+$ ]] || { echo "error: round: --issue <N> or --progress <file> required" >&2; exit 2; }
        local top
        top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "error: round: not in a git repository" >&2; exit 2; }
        progress="$top/.agent/work-plans/issue-$issue/progress.md"
    fi
    if [[ ! -f "$progress" ]]; then
        echo "round=1"; echo "prev_must_fix=-"; return 0
    fi
    local json
    json=$("$PYTHON" "$PROGRESS_READ" "$progress" --type "Local Review (Pre-Push)") || {
        echo "error: round: progress_read.py failed on $progress (malformed file?)" >&2; exit 2; }
    # Prior entries for THIS branch only; the newest is the last in file order.
    printf '%s' "$json" | BRANCH="$branch" "$PYTHON" -c '
import json, os, sys
data = json.load(sys.stdin)
mine = [e for e in data["entries"]
        if (e.get("correlation") or {}).get("kind") == "branch"
        and (e.get("correlation") or {}).get("branch") == os.environ["BRANCH"]]
print(f"round={len(mine) + 1}")
if mine:
    last = mine[-1]
    n = sum(1 for f in last["findings"] if (f.get("source_hint") or "").startswith("must-fix"))
    print(f"prev_must_fix={n}")
else:
    print("prev_must_fix=-")
'
}

# -------------------------------------------------------------- verdict ---
cmd_verdict() {
    local must_fix="" round="" prev="-" mechanical=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --must-fix)      [[ $# -ge 2 ]] || usage; must_fix="$2"; shift 2 ;;
            --round)         [[ $# -ge 2 ]] || usage; round="$2"; shift 2 ;;
            --prev-must-fix) [[ $# -ge 2 ]] || usage; prev="$2"; shift 2 ;;
            --mechanical)    mechanical=1; shift ;;
            *) usage ;;
        esac
    done
    [[ "$must_fix" =~ ^[0-9]+$ && "$round" =~ ^[0-9]+$ ]] || { echo "error: verdict: --must-fix <N> and --round <R> required (integers)" >&2; exit 2; }
    if [[ "$must_fix" -eq 0 ]]; then
        echo "ship=recommended"; echo "reason=no must-fix findings; remaining suggestions can be applied or tracked"; return 0
    fi
    if [[ "$round" -ge 2 && "$must_fix" -le 2 && "$mechanical" -eq 1 ]]; then
        if [[ "$prev" == "-" || ! "$prev" =~ ^[0-9]+$ || "$must_fix" -le "$prev" ]]; then
            echo "ship=recommended"
            echo "reason=round $round: $must_fix mechanical must-fix (prev ${prev}), not rising — fix and ship rather than another full round"
            return 0
        fi
        echo "ship=continue"; echo "reason=round $round: must-fix rising ($prev -> $must_fix)"; return 0
    fi
    echo "ship=continue"
    if [[ "$round" -lt 2 ]]; then
        echo "reason=round $round: $must_fix must-fix; first round always re-reviews after fixes"
    elif [[ "$must_fix" -gt 2 ]]; then
        echo "reason=round $round: $must_fix must-fix is high; another independent read warranted"
    else
        echo "reason=round $round: $must_fix must-fix include a design/correctness concern (not mechanical)"
    fi
}

# -------------------------------------------------------------- persist ---
cmd_persist() {
    local issue="" branch="" title="" strict="${PROGRESS_PERSISTENCE_STRICT:-0}" no_progress=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --issue)       [[ $# -ge 2 ]] || usage; issue="$2"; shift 2 ;;
            --branch)      [[ $# -ge 2 ]] || usage; branch="$2"; shift 2 ;;
            --title)       [[ $# -ge 2 ]] || usage; title="$2"; shift 2 ;;
            --strict)      strict=1; shift ;;
            --no-progress) no_progress=1; shift ;;
            *) usage ;;
        esac
    done
    if [[ "$no_progress" -eq 1 ]]; then
        echo "Progress persistence skipped (--no-progress)"; return 0
    fi
    if [[ -z "$issue" ]]; then
        # Degradation (owner's containment measure 4): no issue is derivable,
        # so resolve_work_plans_dir() is never called — it cannot abort on a
        # branch that has nothing to track against.
        [[ -n "$branch" ]] || branch=$(git branch --show-current 2>/dev/null || true)
        if [[ "$branch" == skill/* ]]; then
            echo "Progress persistence skipped (no linked issue — skill worktree)"
        else
            echo "Progress persistence skipped (no linked issue)"
        fi
        return 0
    fi
    [[ "$issue" =~ ^[0-9]+$ ]] || { echo "error: persist: --issue must be numeric or empty" >&2; exit 2; }
    local entry
    entry=$(cat)
    # Same guards as progress_append.sh (one entry, writable type, balanced
    # fences, single-line title) — the compatibility path below writes the
    # file itself, so it must not be the one writer without them.
    # shellcheck source=_progress_entry.sh
    source "$SCRIPT_DIR/_progress_entry.sh"
    local entry_type type_msg
    entry_type=$(progress_entry_validate "$entry" "$title") || exit 2
    # Same fixed-message shape progress_append.sh uses, so both persistence
    # paths leave the same commit subject (PR C: triage-reviews shares this).
    type_msg=$(printf '%s' "$entry_type" | tr '[:upper:]' '[:lower:]')

    # shellcheck source=_resolve_work_plans_dir.sh
    source "$SCRIPT_DIR/_resolve_work_plans_dir.sh"

    if [[ "$strict" == "1" ]]; then
        local dir root expected
        dir=$(resolve_work_plans_dir "$issue") || {
            echo "error: progress persistence aborted (strict mode): resolve_work_plans_dir refused — see remediation above" >&2
            exit 4
        }
        # progress_append.sh only writes <repo-root>/.agent/work-plans/issue-<N>/,
        # so the resolved directory must be exactly that shape inside some
        # repo (true for rules 2/2b; a WORK_PLANS_DIR_OVERRIDE may point
        # anywhere). Refuse rather than silently write elsewhere and claim
        # the override was honored.
        # No mkdir here: an abort must leave nothing behind. The target dir
        # may not exist yet (first entry for an issue), so find the repo from
        # its nearest existing ancestor.
        local probe
        probe=$(realpath -m "$dir")
        while [[ ! -d "$probe" && "$probe" != "/" ]]; do probe=$(dirname "$probe"); done
        root=$(git -C "$probe" rev-parse --show-toplevel 2>/dev/null) || root=""
        expected="$root/.agent/work-plans/issue-$issue"
        if [[ -z "$root" || "$(realpath -m "$dir")" != "$(realpath -m "$expected")" ]]; then
            echo "error: progress persistence aborted (strict mode): resolved work-plans dir '$dir' is not <repo-root>/.agent/work-plans/issue-$issue, which is the only target progress_append.sh writes (WORK_PLANS_DIR_OVERRIDE set?)" >&2
            exit 4
        fi
        local args=(-C "$root" "$issue")
        [[ -n "$title" ]] && args+=(--title "$title")
        printf '%s\n' "$entry" | "$PROGRESS_APPEND" "${args[@]}" || exit 3
        echo "Progress persisted (strict: resolve_work_plans_dir + progress_append.sh) to $dir/progress.md"
        return 0
    fi

    # Compatibility mode (PROGRESS_PERSISTENCE_STRICT=0, the PR B default):
    # evaluate the strict path's abort condition, report it, then do what
    # the skill did before PR B — current worktree, inline append + commit.
    local reason
    if ! reason=$(resolve_work_plans_dir "$issue" 2>&1 >/dev/null); then
        reason=$(printf '%s' "$reason" | head -1 | sed 's/^ERROR: //')
        echo "Progress persistence notice: would have aborted (resolve_work_plans_dir: $reason) — running in compatibility mode (PROGRESS_PERSISTENCE_STRICT=0)"
    fi
    local root file_rel file
    root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "error: persist: not in a git repository" >&2; exit 3; }
    file_rel=".agent/work-plans/issue-$issue/progress.md"
    file="$root/$file_rel"
    mkdir -p "$(dirname "$file")"
    if [[ ! -f "$file" ]]; then
        { printf -- '---\nissue: %s\n---\n\n' "$issue"
          if [[ -n "$title" ]]; then printf '# Issue #%s — %s\n' "$issue" "$title"; else printf '# Issue #%s\n' "$issue"; fi
        } > "$file" || exit 3
    fi
    # Idempotency: a re-run after a failed commit must re-attempt the commit,
    # not append the same entry twice (same guard as progress_append.sh).
    if progress_entry_is_tail "$file" "$entry"; then
        echo "note: identical entry already present as file tail (uncommitted from a prior run?) — skipping re-append, re-attempting commit" >&2
    else
        printf '\n%s\n' "$entry" >> "$file" || { echo "error: persist: could not append to $file_rel" >&2; exit 3; }
    fi
    git -C "$root" add -- "$file_rel" || exit 3
    if git -C "$root" diff --cached --quiet -- "$file_rel"; then
        echo "Progress already persisted (compatibility mode): identical entry committed earlier to $file_rel"
        return 0
    fi
    # Identity: the agent identity when set_git_identity_env.sh exported it
    # (same as progress_append.sh), otherwise whatever git config provides —
    # the pre-PR-B inline commit behaved the same way. A host with neither
    # (a bare CI runner) fails here with git's own "Author identity unknown".
    local -a ident=()
    if [[ -n "${AGENT_NAME:-}" && -n "${AGENT_EMAIL:-}" ]]; then
        ident=(-c "user.name=$AGENT_NAME" -c "user.email=$AGENT_EMAIL")
        export GIT_AUTHOR_NAME="$AGENT_NAME" GIT_AUTHOR_EMAIL="$AGENT_EMAIL" \
               GIT_COMMITTER_NAME="$AGENT_NAME" GIT_COMMITTER_EMAIL="$AGENT_EMAIL"
    fi
    git -C "$root" "${ident[@]}" commit -q -m "progress: $type_msg for #$issue" -- "$file_rel" || {
        echo "error: persist: commit failed — $file_rel is appended and staged; fix and re-commit" >&2; exit 3; }
    echo "Progress persisted (compatibility mode) to $file_rel"
}

# -------------------------------------------------------------- sources ---
# sources --progress <file> --head <sha> --reviews <fetch_pr_reviews json>
# Integrator input for triage-reviews (PR C): the local review findings at
# the PR head plus the GitHub-side inline comments, and the CANDIDATE
# cross-source confirmations — a local finding and a GitHub comment that
# name the same file at the same head SHA. The skill confirms each
# candidate semantically; this only does the mechanical correlation
# (ADR-0013: review entries correlate by head SHA).
cmd_sources() {
    local progress="" head="" reviews=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --progress) [[ $# -ge 2 ]] || usage; progress="$2"; shift 2 ;;
            --head)     [[ $# -ge 2 ]] || usage; head="$2"; shift 2 ;;
            --reviews)  [[ $# -ge 2 ]] || usage; reviews="$2"; shift 2 ;;
            *) usage ;;
        esac
    done
    [[ -n "$head" && -n "$reviews" ]] || { echo "error: sources: --head <sha> and --reviews <json> required" >&2; exit 2; }
    [[ -f "$reviews" ]] || { echo "error: sources: reviews file not found: $reviews" >&2; exit 2; }
    local json="{\"entries\": []}"
    if [[ -n "$progress" && -f "$progress" ]]; then
        json=$("$PYTHON" "$PROGRESS_READ" "$progress" --type "Local Review" --type "Local Review (Pre-Push)" --type "Integrated Review") || {
            echo "error: sources: progress_read.py failed on $progress (malformed file?)" >&2; exit 2; }
    fi
    printf '%s' "$json" | HEAD="$head" REVIEWS="$reviews" "$PYTHON" -c '
import json, os, re, sys
head = os.environ["HEAD"]
data = json.load(sys.stdin)
reviews = json.load(open(os.environ["REVIEWS"], encoding="utf-8"))
short = lambda s: (s or "")[:7]
# Local findings at this head (entries correlate by head SHA, short or full).
local = []
loc_re = re.compile(r"`([\w./-]+?)(?::(\d+)(?:-\d+)?)?`")
for e in data.get("entries", []):
    c = e.get("correlation") or {}
    if c.get("kind") not in ("pr", "branch") or short(c.get("sha")) != short(head):
        continue
    for f in e.get("findings", []):
        if f.get("section") == "False positives":
            continue
        paths = [(m.group(1), m.group(2)) for m in loc_re.finditer(f.get("text", "")) if "/" in m.group(1) or "." in m.group(1)]
        local.append({"entry_type": e["type"], "sha": short(c.get("sha")), "text": f.get("text"),
                      "source_hint": f.get("source_hint"), "checked": f.get("checked"),
                      "file": paths[-1][0] if paths else None,
                      "line": int(paths[-1][1]) if paths and paths[-1][1] else None})
github = []
for r in reviews.get("reviews", []):
    src = "{} ({})".format(r.get("user_login"), r.get("user_type"))
    for cm in r.get("comments", []):
        github.append({"source": src, "review_id": r.get("review_id"), "commit_id": short(r.get("commit_id")),
                       "at_head": short(r.get("commit_id")) == short(head),
                       "path": cm.get("path"), "line": cm.get("line"), "body": cm.get("body")})
def same_file(a, b):
    if not a or not b: return False
    return a == b or a.endswith("/" + b) or b.endswith("/" + a)
candidates = []
for lf in local:
    for gc in github:
        if gc["at_head"] and same_file(lf["file"], gc["path"]):
            candidates.append({"file": gc["path"], "local": lf["text"], "local_entry": lf["entry_type"],
                               "github": gc["body"], "github_source": gc["source"],
                               "local_line": lf["line"], "github_line": gc["line"]})
json.dump({"head": short(head), "local_findings": local, "github_comments": github,
           "candidates": candidates}, sys.stdout, indent=2)
print()
'
}

case "$SUB" in
    round)   cmd_round "$@" ;;
    verdict) cmd_verdict "$@" ;;
    persist) cmd_persist "$@" ;;
    sources) cmd_sources "$@" ;;
    -h|--help|help) usage ;;
    *) echo "error: unknown subcommand '$SUB'" >&2; usage ;;
esac
