#!/usr/bin/env bash
# .agent/scripts/sitrep_root.sh
# The root the sit-rep reports on, and what can be read there (issue #418).
# Read-only. The sit-rep covers the session's own root only (owner,
# 2026-11-09): a session in the workspace gets the workspace's report, one
# in a registered project root gets that project's. Every root decision the
# skill's steps need is made here once, since shell state does not persist
# between the skill's command blocks.
#
#   sitrep_root.sh [--dir <dir>]
#       The root of a session in <dir> (default: the current directory),
#       as session_root.sh decides it, and one key=value line per fact:
#         root=<absolute pwd -P path>
#         type=workspace|project
#         project=<registered name>        (empty for the workspace)
#         record_name=<name>               the run record's second column:
#                                          `workspace` for the workspace, the
#                                          registered name for a project, and
#                                          `project:workspace` for a project
#                                          literally named `workspace`
#         roadmap=<path>                   the first of <root>/docs/roadmap.md
#                                          and <root>/ROADMAP.md that exists
#                                          (the two places onboard-project
#                                          looks), else empty
#         own_repo=yes|no                  yes only when the root is the top
#                                          of its own git repository; a
#                                          hosting directory, or a registered
#                                          root inside another repository,
#                                          would otherwise read the enclosing
#                                          repository's history
#         default_branch=<name>            own_repo=yes only: origin/HEAD's
#                                          target, else `main` or `master`
#                                          when exactly one exists, else empty
#         pr_source=<owner/repo>|none      the GitHub slug of the root's own
#                                          `origin`; none without own_repo
#         check_<name>=run | skipped (<why>)
#                                          one line per check the sit-rep's
#                                          Problems step makes from files a
#                                          root may not have:
#                                            decision_register  docs/design.md
#                                            research_digest    .agent/knowledge/research_digest.md
#                                            design_anchors     docs/design.md
#                                            documentation      docs/design.md
#                                          each also needs own_repo=yes
#                                          (they read the default branch),
#                                          except design_anchors, which
#                                          reads the files as they are.
#       Outside the workspace and every registered root (session_root.sh
#       exits non-zero) nothing is printed on stdout, the reason is on
#       stderr, and the exit status is session_root.sh's: the sit-rep
#       stops; it never falls back to the workspace.
#
#   sitrep_root.sh [--dir <dir>] --worktrees [--rows <file>]
#       worktree_list.sh --json, kept to the worktrees this root reports, in
#       the same shape, {"worktrees": [...]}, each entry with one more field,
#       "own": "yes" or "no". One rule for both root types; an entry is kept
#       when
#         (a) it is the root's own: for the workspace, an entry worktree_list
#             types `workspace` or `main` (worktrees/workspace/, from
#             wt_workspace_base, and the legacy .workspace-worktrees/); for a
#             project root, a `project` entry under the worktree directory of
#             the root or of one of its instances (registry_worktree_dir, or
#             the transition location worktrees/project/<name>/), or
#         (b) one of this root's own Direction lines names it, read from the
#             `line` rows of <file> (the rows the sit-rep's step 1 saved):
#             an `adapter --project <name>` check keeps that project's
#             worktrees (`repo` equal to <name>), a `gh-issue <owner/repo>#N`
#             check keeps the worktree of issue N whose repository is
#             <owner/repo>. Without a readable <file>, only (a) is kept.
#       "own" is "yes" for an (a) entry that is a checkout of the root's own
#       repository, whose bare issue numbers (`(#N)`, `gh-issue N`) the
#       sit-rep matches: every (a) entry of the workspace; for a project
#       root, a plain worktree that shares the root's git directory, or a
#       package worktree (a .worktree-repos manifest) whose repository is
#       pr_source: the one its header names (issue=<owner/repo>#N), else,
#       for a bare issue=<N> header, the one every listed checkout's origin
#       agrees on. Anything else is "no".
#       An error from worktree_list.sh (a non-zero exit, or output that is
#       not its JSON) is passed through on stderr with a non-zero exit;
#       it is never printed as an empty list.
#
# Exit: 0 on success; session_root.sh's status outside every root; the
# status of worktree_list.sh (or 1 for output that is not JSON) under
# --worktrees; 2 on usage.
#
# user-tier: inert -- read-only: prints facts on stdout (or the reason on
# stderr) and writes nothing; no gh call and no repo-changing git call.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The main checkout, resolved as session_root.sh resolves it: the registry
# is the main checkout's (projects.local is not in a worktree).
WS_ROOT="$({ git -C "$SCRIPT_DIR" worktree list --porcelain 2>/dev/null | head -n1 | sed 's/^worktree //'; } || true)"
[[ -n "$WS_ROOT" ]] || WS_ROOT="$SCRIPT_DIR/../.."
WS_ROOT="$(cd "$WS_ROOT" && pwd -P)"
# shellcheck source=_issue_helpers.sh
source "$SCRIPT_DIR/_issue_helpers.sh"
# shellcheck source=_worktree_helpers.sh
source "$SCRIPT_DIR/_worktree_helpers.sh"

usage() {
    echo "usage: sitrep_root.sh [--dir <dir>] [--worktrees [--rows <file>]]" >&2
    exit 2
}

DIR="$PWD"
WORKTREES=false
ROWS=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dir)       [[ $# -ge 2 && -n "$2" ]] || usage; DIR="$2"; shift 2 ;;
        --worktrees) WORKTREES=true; shift ;;
        --rows)      [[ $# -ge 2 ]] || usage; ROWS="$2"; shift 2 ;;
        -h|--help)
            sed -n '2,/^set -uo pipefail/p' "${BASH_SOURCE[0]}" | sed '$d'
            exit 0 ;;
        *) usage ;;
    esac
done
[[ -n "$ROWS" && "$WORKTREES" != true ]] && usage

rc=0
SR="$(bash "$SCRIPT_DIR/session_root.sh" --dir "$DIR")" || rc=$?
if [[ $rc -ne 0 ]]; then
    echo "sitrep_root: no sit-rep: $DIR is in no root (the reason is above)" >&2
    exit "$rc"
fi
ROOT="$(sed -n 's/^root=//p' <<< "$SR")"
TYPE="$(sed -n 's/^type=//p' <<< "$SR")"
PROJECT="$(sed -n 's/^project=//p' <<< "$SR")"

phys() { (cd "$1" 2>/dev/null && pwd -P); }

# --- own repository, default branch, pull-request source -------------------
OWN_REPO=no
top="$(git -C "$ROOT" rev-parse --show-toplevel 2>/dev/null)" || top=""
[[ -n "$top" && "$(phys "$top")" == "$ROOT" ]] && OWN_REPO=yes

DEFAULT_BRANCH=""
PR_SOURCE=none
if [[ "$OWN_REPO" == yes ]]; then
    head_ref="$(git -C "$ROOT" symbolic-ref -q refs/remotes/origin/HEAD 2>/dev/null)" || head_ref=""
    if [[ -n "$head_ref" ]]; then
        DEFAULT_BRANCH="${head_ref#refs/remotes/origin/}"
    else
        found=""
        for b in main master; do
            git -C "$ROOT" rev-parse -q --verify "refs/heads/$b" >/dev/null 2>&1 && found="$found $b"
        done
        found="${found# }"
        [[ -n "$found" && "$found" != *" "* ]] && DEFAULT_BRANCH="$found"
    fi
    slug="$(extract_gh_slug "$(git -C "$ROOT" remote get-url origin 2>/dev/null)")"
    [[ -n "$slug" ]] && PR_SOURCE="$slug"
fi

if [[ "$WORKTREES" != true ]]; then
    record_name="workspace"
    if [[ "$TYPE" == project ]]; then
        record_name="$PROJECT"
        [[ "$PROJECT" == workspace ]] && record_name="project:workspace"
    fi
    roadmap=""
    for f in docs/roadmap.md ROADMAP.md; do
        [[ -e "$ROOT/$f" ]] && { roadmap="$ROOT/$f"; break; }
    done
    # check <name> <file> <needs own repo: yes|no>
    check() {
        if [[ ! -e "$ROOT/$2" ]]; then
            echo "check_$1=skipped ($2 not in this root)"
        elif [[ "$3" == yes && "$OWN_REPO" != yes ]]; then
            echo "check_$1=skipped (this root is not a git repository of its own)"
        else
            echo "check_$1=run"
        fi
    }
    echo "root=$ROOT"
    echo "type=$TYPE"
    echo "project=$PROJECT"
    echo "record_name=$record_name"
    echo "roadmap=$roadmap"
    echo "own_repo=$OWN_REPO"
    echo "default_branch=$DEFAULT_BRANCH"
    echo "pr_source=$PR_SOURCE"
    check decision_register docs/design.md yes
    check research_digest .agent/knowledge/research_digest.md yes
    check design_anchors docs/design.md no
    check documentation docs/design.md yes
    exit 0
fi

# --- --worktrees -------------------------------------------------------------
# The worktree directories that are the root's own, part (a) for a project
# root: the root's and each instance's registered directory, and the
# transition location under the workspace.
OWN_DIRS=""
if [[ "$TYPE" == project ]]; then
    names="$PROJECT"$'\n'"$(registry_instances "$WS_ROOT" "$PROJECT" 2>/dev/null)"
    while IFS= read -r n; do
        [[ -n "$n" ]] || continue
        for d in "$(registry_worktree_dir "$WS_ROOT" "$n" 2>/dev/null)" \
                 "$(wt_transition_project_base "$WS_ROOT" "$n" 2>/dev/null)"; do
            [[ -n "$d" ]] && p="$(phys "$d")" && OWN_DIRS="$OWN_DIRS$p"$'\n'
        done
    done <<< "$names"
fi
ROOT_GIT=""
[[ "$OWN_REPO" == yes ]] && ROOT_GIT="$(phys "$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)")"

errf="$(mktemp -t sitrep-root.XXXXXX)" || { echo "sitrep_root: could not create a temporary file" >&2; exit 1; }
trap 'rm -f -- "$errf"' EXIT
rc=0
json="$(cd "$DIR" && bash "$SCRIPT_DIR/worktree_list.sh" --json 2>"$errf")" || rc=$?
if [[ $rc -ne 0 ]]; then
    cat "$errf" >&2
    echo "sitrep_root: worktree_list.sh --json failed (exit $rc)" >&2
    exit "$rc"
fi
# Its warnings (a malformed registry, say) are passed on.
cat "$errf" >&2

[[ -n "$ROWS" && -f "$ROWS" && -r "$ROWS" ]] || ROWS=""
JSON="$json" ROOT="$ROOT" TYPE="$TYPE" PR_SOURCE="$PR_SOURCE" OWN_DIRS="$OWN_DIRS" \
    ROOT_GIT="$ROOT_GIT" ROWS="$ROWS" python3 -c '
import json, os, re, subprocess, sys

try:
    doc = json.loads(os.environ["JSON"])
    entries = doc["worktrees"]
    if not isinstance(entries, list):
        raise ValueError
except (ValueError, KeyError, TypeError):
    sys.stderr.write("sitrep_root: worktree_list.sh --json printed no worktree list\n")
    sys.exit(1)

root_type = os.environ["TYPE"]
pr_source = os.environ["PR_SOURCE"]
own_dirs = [d for d in os.environ["OWN_DIRS"].splitlines() if d]
root_git = os.environ["ROOT_GIT"]

# (b): what this root'"'"'s Direction lines name, from step 1'"'"'s line rows.
named_projects, named_issues = set(), set()
if os.environ["ROWS"]:
    with open(os.environ["ROWS"], encoding="utf-8", errors="replace") as fh:
        for row in fh:
            f = row.rstrip("\n").split("\t")
            if len(f) < 4 or f[0] != "line":
                continue
            named_projects.update(re.findall(r"adapter --project ([A-Za-z0-9._-]+)", f[3]))
            named_issues.update("%s#%s" % m for m in
                                re.findall(r"gh-issue ([A-Za-z0-9._-]+/[A-Za-z0-9._-]+)#([0-9]+)", f[3]))

def git(d, *args):
    try:
        r = subprocess.run(["git", "-C", d] + list(args), capture_output=True, text=True)
    except OSError:
        return ""
    return r.stdout.strip() if r.returncode == 0 else ""

def gh_slug(url):
    # extract_gh_slug, in _issue_helpers.sh.
    s = re.sub(r".*github\.com[:/]", "", url) if "github.com" in url else url
    s = re.sub(r"\.git$", "", s)
    return s if re.fullmatch(r"[^/\s]+/[^/\s]+", s) else ""

def slug_of(path):
    """The GitHub repository a worktree belongs to, or empty."""
    m = os.path.join(path, ".worktree-repos")
    if os.path.isfile(m):
        with open(m, encoding="utf-8", errors="replace") as fh:
            lines = fh.read().splitlines()
        hdr = re.search(r" issue=(\S+)", lines[0]) if lines else None
        if hdr and re.fullmatch(r"[^/#\s]+/[^/#\s]+#[0-9]+", hdr.group(1)):
            return hdr.group(1).rsplit("#", 1)[0]
        agree = None
        for l in lines[1:]:
            cols = l.split("\t")
            if len(cols) < 2 or not cols[1]:
                continue
            d = path if cols[1] == "." else os.path.join(path, cols[1])
            s = gh_slug(git(d, "remote", "get-url", "origin"))
            if not s or (agree is not None and agree != s):
                return ""
            agree = s
        return agree or ""
    return gh_slug(git(path, "remote", "get-url", "origin"))

def under(path, dirs):
    p = os.path.realpath(path)
    return any(p == d or p.startswith(d.rstrip("/") + "/") for d in dirs)

kept = []
for w in entries:
    t, path = w.get("type"), w.get("path") or ""
    if root_type == "workspace":
        part_a = t in ("workspace", "main")
        own = part_a
    else:
        part_a = t == "project" and under(path, own_dirs)
        own = False
        if part_a:
            if os.path.isfile(os.path.join(path, ".worktree-repos")):
                own = pr_source != "none" and slug_of(path) == pr_source
            elif root_git:
                c = git(path, "rev-parse", "--path-format=absolute", "--git-common-dir")
                own = bool(c) and os.path.realpath(c) == root_git
    keep = part_a
    if not keep and t == "project" and (w.get("repo") or "") in named_projects:
        keep = True
    if not keep and w.get("issue") is not None and named_issues:
        s = slug_of(path)
        keep = bool(s) and ("%s#%s" % (s, w.get("issue"))) in named_issues
    if keep:
        w["own"] = "yes" if own else "no"
        kept.append(w)
print(json.dumps({"worktrees": kept}))
'
