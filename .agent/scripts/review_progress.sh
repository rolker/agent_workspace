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
# sources  Integrator input for triage-reviews: local review findings that
#          cover the PR head (recorded at it, or at an ancestor with only
#          bookkeeping changes since -- _bookkeeping.sh, #309), the entries
#          dropped and why, GitHub inline comments, and candidate cross-source
#          confirmations (same file, comment at the head) as JSON. Run it from
#          the PR worktree. See cmd_sources.
#
# plan-sha The plan-commit SHA (last commit touching plan.md) for the
#          **Plan** correlation field of Plan Authored / Plan Review
#          entries; refuses an uncommitted plan. See cmd_plan_sha.
#          persist --soft: any failure becomes a printed notice, exit 0
#          (review-plan's non-fatal step 6).
#
# findings The address-findings source entry (latest Integrated Review or
#          Local Review (Pre-Push)) and its open findings with indexes.
# check    Flip one of that entry's checkboxes to [x], optionally with a
#          "(deferred: <reason>)" annotation. See cmd_findings / cmd_check.
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
                             [--strict] [--no-progress] [--soft] < entry.md
  review_progress.sh plan-sha --plan <path/to/plan.md> [--ref <commit-ish>]
  review_progress.sh sources --head <sha> --reviews <fetch_pr_reviews.json> [--progress <file>]
  review_progress.sh findings --progress <file>
  review_progress.sh check --progress <file> --index <i> [--deferred "<reason>"]
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
# persist wrapper: --soft makes ANY failure (validation, resolver refusal,
# append/commit error) a printed notice with exit 0 — review-plan's step 6,
# whose report has already been produced by the time persistence runs
# (issue #269 PR E). Without --soft the real exit code passes through.
cmd_persist() {
    local soft=0 a
    local -a rest=()
    for a in "$@"; do
        if [[ "$a" == "--soft" ]]; then soft=1; else rest+=("$a"); fi
    done
    if [[ "$soft" -eq 0 ]]; then
        _persist_impl "${rest[@]}"
        return $?
    fi
    # Streams stay separate: stdout is the one line a skill echoes; notes and
    # errors stay on stderr exactly as in non-soft mode.
    local out err rc=0 reason errf
    errf=$(mktemp)
    out=$(_persist_impl "${rest[@]}" 2>"$errf") || rc=$?
    err=$(cat "$errf"); rm -f "$errf"
    if [[ "$rc" -eq 0 ]]; then
        [[ -n "$err" ]] && printf '%s\n' "$err" >&2
        printf '%s\n' "$out"
        return 0
    fi
    # The full diagnostic (e.g. the resolver's remediation lines) still
    # reaches stderr; stdout gets the one-line summary.
    [[ -n "$err" ]] && printf '%s\n' "$err" >&2
    reason=$(printf '%s\n' "$err" | grep -m1 -i 'error' || printf '%s\n%s\n' "$err" "$out" | grep -v '^$' | tail -1)
    reason=$(printf '%s' "$reason" | sed -E 's/^[Ee][Rr][Rr][Oo][Rr]: *//')
    echo "Progress persistence failed: ${reason:-exit $rc} (exit $rc) — the report above is unaffected"
    return 0
}

_persist_impl() {
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
# Integrator input for triage-reviews (PR C): the local review findings that
# cover the PR head plus the GitHub-side inline comments, and the CANDIDATE
# cross-source confirmations — a local finding covering the head and a
# GitHub comment submitted at the head that name the same file. The skill
# confirms each candidate semantically; this only does the mechanical
# correlation (ADR-0013: review entries correlate by head SHA; #309: an
# entry at an ancestor with only bookkeeping changes since still covers it,
# and keeps its own SHA). Local coverage is checked in the repository of
# the current directory, so run it from the PR worktree; entries with open
# findings that do not cover the head are listed in dropped_entries with
# reason "stale" (verified) or "unverifiable" (could not check, including an
# entry with no parseable PR/Branch correlation SHA; also warned on stderr). A covering entry with a NEWER covering Integrated Review is
# dropped with reason "superseded" (owner decision "Only triage supersedes",
# #309); newer Local Reviews supersede nothing. Nothing is fetched.
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
    if [[ -n "$progress" && -e "$progress" && ! -f "$progress" ]]; then
        echo "error: sources: --progress '$progress' exists but is not a regular file (pass the progress.md path, not its directory)" >&2; exit 2
    fi
    if [[ -n "$progress" && -f "$progress" ]]; then
        json=$("$PYTHON" "$PROGRESS_READ" "$progress" --type "Local Review" --type "Local Review (Pre-Push)" --type "Integrated Review") || {
            echo "error: sources: progress_read.py failed on $progress (malformed file?)" >&2; exit 2; }
    fi
    if ! "$PYTHON" -c 'import json,sys; json.load(open(sys.argv[1], encoding="utf-8"))' "$reviews" 2>/dev/null; then
        echo "error: sources: reviews file is not valid JSON: $reviews (truncated fetch_pr_reviews.sh output?)" >&2; exit 2
    fi
    printf '%s' "$json" | HEAD="$head" REVIEWS="$reviews" PROGRESS="$progress" \
        BOOKKEEPING="$SCRIPT_DIR/_bookkeeping.sh" "$PYTHON" -c '
import json, os, re, subprocess, sys
head = os.environ["HEAD"]
data = json.load(sys.stdin)
reviews = json.load(open(os.environ["REVIEWS"], encoding="utf-8"))
short = lambda s: (s or "")[:7]
# Coverage (#309): an entry recorded at review SHA R still speaks for head H
# when R == H (short-SHA match, the pre-#309 rule) or when the shared merge
# gate rule (_bookkeeping.sh) verifies, in the repository of the CURRENT
# directory, that R is an ancestor of H and only the work-plan dir of this
# issue and the roadmap files differ. The timeline file may live outside that
# repository; its canonical path supplies only the issue number.
issue = re.search(r"(?:^|/)\.agent/work-plans/issue-([0-9]+)/progress\.md$",
                  os.path.abspath(os.environ["PROGRESS"])) if os.environ["PROGRESS"] else None
coverage_cache = {}
def coverage(sha):
    """(kind, why): kind is "exact" | "bookkeeping" | "stale" | "unverifiable"."""
    if sha and short(sha) == short(head):
        return ("exact", "")
    if sha not in coverage_cache:
        if not issue:
            coverage_cache[sha] = ("unverifiable", "--progress is not a .agent/work-plans/issue-<N>/progress.md path, so only an exact head-SHA match counts")
        else:
            try:
                r = subprocess.run(
                    ["bash", os.environ["BOOKKEEPING"], "--review", os.getcwd(),
                     sha or "", head, issue.group(1)],
                    stdin=subprocess.DEVNULL, capture_output=True, text=True, check=False)
                why = (r.stdout.strip().splitlines() or [""])[-1]
                if r.returncode == 0:
                    coverage_cache[sha] = ("bookkeeping", "")
                elif r.returncode == 1:
                    coverage_cache[sha] = ("stale", why)
                elif r.returncode == 3:
                    coverage_cache[sha] = ("unverifiable", why)
                else:
                    coverage_cache[sha] = ("unverifiable", "coverage check failed (exit {}): {}".format(
                        r.returncode, (r.stderr.strip().splitlines() or [why])[-1]))
            except OSError as exc:
                coverage_cache[sha] = ("unverifiable", "coverage check could not run: {}".format(exc))
    return coverage_cache[sha]
warned = set()
def warn_unverifiable(sha, why):
    """Once per SHA, and only for an entry whose open findings are dropped."""
    if sha not in warned:
        warned.add(sha)
        print("warning: sources: review at `{}` not verified against head `{}`: {}".format(
            short(sha) or "?", short(head), why), file=sys.stderr)

# OPEN local findings covering this head. Checked boxes are resolved;
# False-positives bullets are dismissals.
# Every repo-relative path cited in backticks counts, not only the last.
local = []
# Entries with open findings that do NOT cover this head, and why — so a
# caller can tell "no open findings" from "open findings, but stale" and,
# above all, from "open findings the helper could not check" (#309).
dropped = []
loc_re = re.compile(r"`(?:\./)?([\w./-]+?)(?::(\d+)(?:-\d+)?)?`")
# Supersession (#309, owner decision "Only triage supersedes"): only a
# newer covering Integrated Review with **Status**: complete drops the open
# findings of older covering review entries, which are listed as
# "superseded". That entry is a triage decision over them (triage and
# address-findings never tick the boxes of the older entry). A legacy
# External Review does not qualify (owner decision): ADR-0013 defines it as
# a single-source GitHub findings table that never ruled on local findings. A newer Local Review / Local Review (Pre-Push) supersedes nothing:
# it re-reads the code independently, so every covering entry without a
# newer covering Integrated Review feeds local_findings. Nothing vanishes
# without a decision. "Review entry" = every entry read above with a
# PR/branch correlation; file order is chronological. An entry whose
# **PR**/**Branch** line does not parse (no "#", no "at <sha>") has no SHA
# to check: its open findings are listed as "unverifiable" below and
# warned about, never silently skipped.
open_of = lambda e: [f for f in e.get("findings", [])
                     if f.get("section") != "False positives" and not f.get("checked")]
reviews_in = [e for e in data.get("entries", [])
              if (e.get("correlation") or {}).get("kind") in ("pr", "branch")]
uncorrelated = [e for e in data.get("entries", [])
                if (e.get("correlation") or {}).get("kind") not in ("pr", "branch") and open_of(e)]
classified = [(e, coverage((e.get("correlation") or {}).get("sha"))) for e in reviews_in]
is_triage = lambda e: e.get("base_type") == "Integrated Review"
# A partial or failed triage decided nothing, so only a complete one counts.
triage_covering = [i for i, (e, (kind, _w)) in enumerate(classified)
                   if kind in ("exact", "bookkeeping") and is_triage(e)
                   and (e.get("status") or "").strip().lower() == "complete"]
for i, (e, (kind, why)) in enumerate(classified):
    c = e.get("correlation") or {}
    open_f = open_of(e)
    if not open_f:
        continue
    later_triage = [j for j in triage_covering if j > i]
    if kind in ("exact", "bookkeeping") and later_triage:
        w = classified[later_triage[-1]][0]
        kind, why = "superseded", "a newer {} at `{}` covers the head".format(
            w["type"], short((w.get("correlation") or {}).get("sha")) or "?")
    if kind not in ("exact", "bookkeeping"):
        if kind == "unverifiable":
            warn_unverifiable(c.get("sha"), why)
        dropped.append({"entry_type": e["type"], "sha": short(c.get("sha")),
                        "open_findings": len(open_f), "reason": kind, "why": why})
        continue
    for f in open_f:
        cited = [(m.group(1), int(m.group(2)) if m.group(2) else None)
                 for m in loc_re.finditer(f.get("text", "")) if "/" in m.group(1) or "." in m.group(1)]
        local.append({"entry_type": e["type"], "sha": short(c.get("sha")), "text": f.get("text"),
                      "covers_head": True, "coverage": kind,
                      "source_hint": f.get("source_hint"),
                      "files": [p for p, _ in cited],
                      "lines": {p: ln for p, ln in cited if ln is not None}})
NO_SHA = "no PR/Branch correlation SHA (the **PR** / **Branch** line is missing or does not parse as `#<N> at <sha>` / `<branch> at <sha>`)"
for e in uncorrelated:
    n = len(open_of(e))
    print("warning: sources: `## {}` entry ({}) has {} open finding(s) but {}; not checked against head `{}`".format(
        e["type"], e.get("when") or "no When", n, NO_SHA, short(head)), file=sys.stderr)
    dropped.append({"entry_type": e["type"], "sha": "", "open_findings": n,
                    "reason": "unverifiable", "why": NO_SHA})
github = []
for r in reviews.get("reviews", []):
    src = "{} ({})".format(r.get("user_login"), r.get("user_type"))
    for cm in r.get("comments", []):
        github.append({"source": src, "review_id": r.get("review_id"), "commit_id": short(r.get("commit_id")),
                       "at_head": short(r.get("commit_id")) == short(head),
                       "path": cm.get("path"), "line": cm.get("line"), "body": cm.get("body")})
# Same file means the same repo-relative path (GitHub comment paths are
# repo-relative; findings cite repo-relative paths). No suffix matching:
# scripts/x.sh and vendor/scripts/x.sh are different files.
norm = lambda p: re.sub(r"^\./", "", p or "")
candidates = []
for lf in local:
    for gc in github:
        if not gc["at_head"]:
            continue
        hit = [p for p in lf["files"] if norm(p) == norm(gc["path"])]
        if hit:
            candidates.append({"file": gc["path"], "local": lf["text"], "local_entry": lf["entry_type"],
                               "github": gc["body"], "github_source": gc["source"],
                               "local_line": lf["lines"].get(hit[0]), "github_line": gc["line"]})
json.dump({"head": short(head), "local_findings": local, "dropped_entries": dropped,
           "github_comments": github, "candidates": candidates}, sys.stdout, indent=2)
print()
'
}

# ------------------------------------------------------------- findings ---
# findings --progress <file>
# The address-findings source: the SINGLE latest `## Integrated Review` or
# `## Local Review (Pre-Push)` entry (by base_type, so a legacy External
# Review never qualifies), with its open (unchecked) findings and their
# index among the entry's checkbox lines — the index `check` flips.
# Exit 0 with "source": null when no qualifying entry exists.
cmd_findings() {
    local progress=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --progress) [[ $# -ge 2 ]] || usage; progress="$2"; shift 2 ;;
            *) usage ;;
        esac
    done
    [[ -f "$progress" ]] || { echo "error: findings: progress file not found: $progress" >&2; exit 2; }
    local json
    json=$("$PYTHON" "$PROGRESS_READ" "$progress" --type "Integrated Review" --type "Local Review (Pre-Push)") || {
        echo "error: findings: progress_read.py failed on $progress (malformed file?)" >&2; exit 2; }
    printf '%s' "$json" | "$PYTHON" -c '
import json, sys
data = json.load(sys.stdin)
ok = [e for e in data["entries"] if e.get("base_type") in ("Integrated Review", "Local Review (Pre-Push)")]
if not ok:
    json.dump({"source": None, "open": []}, sys.stdout, indent=2); print(); sys.exit(0)
src = ok[-1]  # file order is chronological; the last one is the latest review
opens = [dict(f, index=i) for i, f in enumerate(src["findings"]) if not f.get("checked")]
json.dump({"source": {"type": src["type"], "when": src.get("when"), "correlation": src.get("correlation"),
                      "ordinal": len(ok) - 1, "total_findings": len(src["findings"])},
           "open": opens}, sys.stdout, indent=2)
print()
'
}

# ---------------------------------------------------------------- check ---
# check --progress <file> --index <i> [--deferred "<reason>"]
# Flip the i-th checkbox (0-based, in file order) of the latest source
# review entry from `- [ ]` to `- [x]`, appending " (deferred: <reason>)"
# when --deferred is given. Refuses (exit 2) if the box is already checked
# or the index is out of range. Rewrites only that one line.
cmd_check() {
    local progress="" index="" deferred="" deferred_given=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --progress) [[ $# -ge 2 ]] || usage; progress="$2"; shift 2 ;;
            --index)    [[ $# -ge 2 ]] || usage; index="$2"; shift 2 ;;
            --deferred) [[ $# -ge 2 ]] || usage; deferred="$2"; deferred_given=1; shift 2 ;;
            *) usage ;;
        esac
    done
    [[ -f "$progress" && "$index" =~ ^[0-9]+$ ]] || { echo "error: check: --progress <file> and --index <i> required" >&2; exit 2; }
    [[ "$deferred" == *$'\n'* ]] && { echo "error: check: --deferred reason must be a single line" >&2; exit 2; }
    if [[ "$deferred_given" == 1 && -z "$deferred" ]]; then
        echo "error: check: --deferred needs a non-empty reason" >&2; exit 2
    fi
    # The reader is the ONE parser: it reports each finding's file line
    # (round-1 review found a second checkbox scanner here diverging from it
    # on fenced, indented, and header-area lines). check only rewrites the
    # line the reader named, after confirming it is still an unchecked box.
    local json
    json=$("$PYTHON" "$PROGRESS_READ" "$progress" --type "Integrated Review" --type "Local Review (Pre-Push)") || {
        echo "error: check: progress_read.py failed on $progress (malformed file?)" >&2; exit 2; }
    printf '%s' "$json" | PROGRESS="$progress" INDEX="$index" DEFERRED="$deferred" "$PYTHON" -c '
import json, os, re, sys
path, index, deferred = os.environ["PROGRESS"], int(os.environ["INDEX"]), os.environ["DEFERRED"]
data = json.load(sys.stdin)
ok = [e for e in data["entries"] if e.get("base_type") in ("Integrated Review", "Local Review (Pre-Push)")]
if not ok:
    print("error: check: no Integrated Review / Local Review (Pre-Push) entry to check a box in", file=sys.stderr); sys.exit(2)
src = ok[-1]
if index >= len(src["findings"]):
    print("error: check: index %d out of range (%d findings in the latest %s entry)" % (index, len(src["findings"]), src["type"]), file=sys.stderr); sys.exit(2)
f = src["findings"][index]
if f.get("checked"):
    print("error: check: finding %d is already checked: %s" % (index, f["text"]), file=sys.stderr); sys.exit(2)
# newline="" keeps CRLF files CRLF; only the one line changes.
with open(path, encoding="utf-8", newline="") as fh:
    lines = fh.read().splitlines(keepends=True)
i = f["line"] - 1
m = re.match(r"^(- \[)( )(\] .*?)(\r?\n?)$", lines[i])
if not m:
    print("error: check: line %d is not the unchecked box the reader reported (%r); file changed underneath?" % (f["line"], lines[i]), file=sys.stderr); sys.exit(2)
new = m.group(1) + "x" + m.group(3) + ((" (deferred: %s)" % deferred) if deferred else "")
lines[i] = new + m.group(4)
with open(path, "w", encoding="utf-8", newline="") as fh:
    fh.write("".join(lines))
print(new)
'
}

# ------------------------------------------------------------- plan-sha ---
# plan-sha --plan <path>
# The plan-commit SHA ADR-0013 requires on `## Plan Authored` / `## Plan
# Review`: the last commit that touched plan.md — not the branch head and
# not a blob SHA. Refuses (exit 2) a missing, untracked, or uncommitted
# plan file, so the entry can never cite a SHA that does not contain the
# plan text it describes.
cmd_plan_sha() {
    local plan="" ref="" dir base sha top
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --plan) [[ $# -ge 2 ]] || usage; plan="$2"; shift 2 ;;
            --ref)  [[ $# -ge 2 ]] || usage; ref="$2"; shift 2 ;;
            *) usage ;;
        esac
    done
    [[ -n "$plan" ]] || usage
    if [[ -n "$ref" ]]; then
        # --ref <commit-ish>: the plan as committed on that ref (a fetched PR
        # head, a branch) — no local checkout of the file needed. <plan> is
        # repo-relative here; the ref must resolve and must contain the file.
        top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "error: plan-sha: not in a git repository" >&2; exit 2; }
        git -C "$top" rev-parse --verify -q "${ref}^{commit}" >/dev/null || { echo "error: plan-sha: ref '$ref' does not resolve (fetch it first?)" >&2; exit 2; }
        git -C "$top" cat-file -e "${ref}:${plan}" 2>/dev/null || { echo "error: plan-sha: '$plan' does not exist at ref '$ref'" >&2; exit 2; }
        sha=$(git -C "$top" log -1 --format=%h "$ref" -- "$plan") && [[ -n "$sha" ]] || {
            echo "error: plan-sha: no commit on '$ref' touches $plan" >&2; exit 2; }
        echo "$sha"
        return 0
    fi
    [[ -f "$plan" ]] || { echo "error: plan-sha: plan file not found: $plan (reviewing a PR from another tree? pass --ref <head>)" >&2; exit 2; }
    dir=$(dirname "$plan"); base=$(basename "$plan")
    git -C "$dir" ls-files --error-unmatch -- "$base" >/dev/null 2>&1 || {
        echo "error: plan-sha: $plan is not tracked by git — commit the plan first" >&2; exit 2; }
    if ! git -C "$dir" diff --quiet -- "$base" || ! git -C "$dir" diff --cached --quiet -- "$base"; then
        echo "error: plan-sha: $plan has uncommitted changes — commit the plan first so the SHA contains it" >&2; exit 2
    fi
    sha=$(git -C "$dir" log -1 --format=%h -- "$base") && [[ -n "$sha" ]] || {
        echo "error: plan-sha: no commit touches $plan" >&2; exit 2; }
    echo "$sha"
}

case "$SUB" in
    plan-sha) cmd_plan_sha "$@" ;;
    round)    cmd_round "$@" ;;
    verdict)  cmd_verdict "$@" ;;
    persist)  cmd_persist "$@" ;;
    sources)  cmd_sources "$@" ;;
    findings) cmd_findings "$@" ;;
    check)    cmd_check "$@" ;;
    -h|--help|help) usage ;;
    *) echo "error: unknown subcommand '$SUB'" >&2; usage ;;
esac
