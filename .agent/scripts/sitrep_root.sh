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
#                                          target when that branch exists
#                                          locally, else `main` or `master`
#                                          when exactly one exists, else empty
#                                          (the Problems step reads the local
#                                          branch)
#         pr_source=<owner/repo>|none      the GitHub repository of the
#                                          root's own `origin`; none without
#                                          own_repo, and none when origin is
#                                          not a github.com repository (see
#                                          "GitHub repositories" below)
#         pr_source_why=<why>              empty with a pr_source, else why
#                                          there is none: "this root is not a
#                                          git repository of its own", "no
#                                          origin remote", or "origin not
#                                          recognised as GitHub" (the URL is
#                                          not printed: it can hold a
#                                          credential)
#         check_<name>=run | skipped (<why>)
#                                          one line per check the sit-rep's
#                                          Problems step makes from files a
#                                          root may not have:
#                                            decision_register  docs/design.md
#                                            research_digest    .agent/knowledge/research_digest.md
#                                            design_anchors     docs/design.md
#                                            documentation      docs/design.md
#                                          design_anchors reads the file as it
#                                          is in the root. The other three
#                                          read it from the default branch, so
#                                          they need own_repo=yes, a default
#                                          branch, and the file committed on
#                                          it (`git cat-file -e`), whatever
#                                          branch the root has checked out;
#                                          a file in neither place is "not in
#                                          this root", one only in the working
#                                          tree is "not on the default branch
#                                          <name>".
#       When no root is decided (session_root.sh exits non-zero: 1 outside
#       the workspace and every registered root, 2 when the project registry
#       cannot be parsed) nothing is printed on stdout, the reason is on
#       stderr, and the exit status is session_root.sh's: the sit-rep
#       stops; it never falls back to the workspace.
#
#   sitrep_root.sh [--dir <dir>] --worktrees [--rows <file>]
#       worktree_list.sh --json, kept to the worktrees this root reports, in
#       the same shape, {"worktrees": [...]}. One rule for both root types;
#       an entry is kept when
#         (a) it is the root's own: for the workspace, an entry worktree_list
#             types `workspace` or `main` (worktrees/workspace/, from
#             wt_workspace_base, and the legacy .workspace-worktrees/); for a
#             project root, a `project` entry under the worktree directory of
#             the root or of one of its instances (registry_worktree_dir, or
#             the transition location worktrees/project/<name>/), or
#         (b) one of this root's own Direction lines names it, read from the
#             `line` rows of <file> (the rows the sit-rep's step 1 saved):
#             an `adapter --project <name>` check keeps that project's
#             worktrees (`repo` equal to <name> as the adapter resolves it,
#             registry_resolve_project_arg: a parent root is its default
#             or only instance, the name worktree_list.sh gives its
#             worktrees; a parent with several instances and no default
#             names nothing, since the adapter fails on it), a `gh-issue <owner/repo>#N`
#             check keeps the worktree of issue N whose repository is
#             <owner/repo>. Without a readable <file>, only (a) is kept.
#       A check is read as sitrep_checks.sh reads it: a cell is split into
#       checks at ` ; `, a check (or the whole cell) may be wrapped in
#       backticks, and only a whole check names something: `gh-issue <ref>
#       <open|closed>` (three words) or `script adapter --project <name>
#       validate`; the same words inside another check (a file-contains
#       argument, say) name nothing. Repository names compare without
#       regard to case, as GitHub's do.
#       Each kept entry gets these fields:
#         "own": "yes" for an (a) entry that is a checkout of the root's own
#             repository, whose bare issue numbers (`(#N)`, `gh-issue N`)
#             the sit-rep matches: every (a) entry of the workspace; for a
#             project root, a plain worktree that shares the root's git
#             directory, or a package worktree (a .worktree-repos manifest)
#             whose "repository" is pr_source. Anything else is "no".
#         "repository": the GitHub <owner/repo> the worktree's issue belongs
#             to, or "": a plain worktree's origin; a package worktree's
#             header (issue=<owner/repo>#N), else, for a bare issue=<N>
#             header, the one every listed checkout's origin agrees on.
#         "repository_dirs": where the issue's timeline and title cache
#             are read: a plain worktree's own path, always (with no GitHub
#             remote too); a package worktree's listed checkouts of
#             "repository", none when it is "".
#         "repository_why": "" when "repository" is set, else why not: "no
#             GitHub remote", or "its checkouts are not all in one GitHub
#             repository" (a package worktree with a bare header whose
#             listed checkouts disagree or lack one).
#         "pr_branch": for an "own" entry, the branch its pull request
#             would have as headRefName: a plain worktree's branch; a
#             package worktree's branch of its "repository" checkouts, as
#             its manifest lists them, when they name exactly one; else "".
#         "named": only with a readable <file>: "yes" when one of this
#             root's own Direction lines names the worktree's work (a bare
#             number, `(#N)` in a line's item or `gh-issue N` in its check,
#             for an "own" entry; `gh-issue <owner/repo>#N` for the entry's
#             "repository" and issue; `adapter --project <name>` for a
#             project entry whose `repo` is <name> as resolved in (b)),
#             else "no".
#       An error from worktree_list.sh (a non-zero exit, or output that is
#       not its JSON) is passed through on stderr with a non-zero exit;
#       it is never printed as an empty list.
#
# Registry: the root is decided from the main checkout's project registry
# (session_root.sh), and the worktrees are listed by the main checkout's
# worktree_list.sh, which reads that same registry; a copy of this script
# in a worktree of the workspace never reads its own checkout's registry
# (projects.local is not in a worktree). Without that copy in the main
# checkout, this script's own copy lists them.
#
# GitHub repositories: an origin is read with `git ls-remote --get-url`
# (git's own insteadOf rewriting, no network) and is a GitHub repository
# only when it is a github.com URL in one of git's forms --
# https://[user@]github.com/<owner>/<repo>, ssh://[user@]github.com[:port]/
# <owner>/<repo>, git://github.com/<owner>/<repo>, or the scp-like
# [user@]github.com:<owner>/<repo> -- with an optional .git. Any other
# host, a local path, or an ssh host alias is "not on GitHub": no
# repository, never a guess.
#
# Exit: 0 on success; session_root.sh's status when no root is decided; the
# status of worktree_list.sh (or 1 for output that is not JSON) under
# --worktrees; 2 on usage.
#
# user-tier: inert -- read-only: prints facts on stdout (or the reason on
# stderr) and writes nothing, no temporary file either; no gh call and no
# repo-changing git call.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The main checkout, resolved as session_root.sh resolves it: the registry
# is the main checkout's (projects.local is not in a worktree).
WS_ROOT="$({ git -C "$SCRIPT_DIR" worktree list --porcelain 2>/dev/null | head -n1 | sed 's/^worktree //'; } || true)"
[[ -n "$WS_ROOT" ]] || WS_ROOT="$SCRIPT_DIR/../.."
WS_ROOT="$(cd "$WS_ROOT" && pwd -P)"
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
    if [[ $rc -eq 1 ]]; then
        echo "sitrep_root: no sit-rep: $DIR is in no root (the reason is above)" >&2
    else
        echo "sitrep_root: no sit-rep: the root of $DIR could not be decided (session_root.sh exit $rc; the reason is above)" >&2
    fi
    exit "$rc"
fi
ROOT="$(sed -n 's/^root=//p' <<< "$SR")"
TYPE="$(sed -n 's/^type=//p' <<< "$SR")"
PROJECT="$(sed -n 's/^project=//p' <<< "$SR")"

phys() { (cd "$1" 2>/dev/null && pwd -P); }

# The Python both parts share: which GitHub repository a directory's origin
# is (the header's "GitHub repositories" rule), and which Direction-line
# checks name what (sitrep_checks.sh's grammar).
read -r -d '' PYLIB <<'PY'
import os, re, subprocess

def git(d, *args):
    try:
        r = subprocess.run(["git", "-C", d] + list(args), capture_output=True, text=True)
    except OSError:
        return ""
    return r.stdout.strip() if r.returncode == 0 else ""

# sitrep_checks.sh's owner/repo grammar for gh-issue references.
SLUG = r"[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9_.][A-Za-z0-9_.-]*?"
GH_URL = re.compile(
    r"(?:https?://(?:[^@/\s]+@)?(?i:github\.com)/"
    r"|ssh://(?:[^@/\s]+@)?(?i:github\.com)(?::[0-9]+)?/"
    r"|git://(?i:github\.com)/"
    r"|(?:[^@/:\s]+@)?(?i:github\.com):)"
    r"(" + SLUG + r")(?:\.git)?/?")

def gh_slug(url):
    m = GH_URL.fullmatch(url or "")
    return m.group(1) if m else ""

def origin_slug(d):
    return gh_slug(git(d, "ls-remote", "--get-url", "origin"))

# sitrep_checks.sh trims [:space:] (ASCII: space, tab, newline, CR, VT,
# FF) and splits words with read -ra (space, tab, newline); Python's own
# strip() and split() also take NBSP and other Unicode spaces, so they are
# not used here.
TRIM = " \t\n\r\v\f"
def words_of(p):
    return [w for w in re.split(r"[ \t\n]+", p) if w]

def checks_of(cell):
    """The checks of a cell, each as its words, split as sitrep_checks.sh does."""
    c = cell.strip(TRIM)
    m = re.fullmatch(r"`([^`]*)`", c)
    if m:
        c = m.group(1)
    out = []
    for part in c.split(" ; "):
        p = part.strip(TRIM)
        if len(p) >= 2 and p.startswith("`") and p.endswith("`"):
            p = p[1:-1].strip(TRIM)
        out.append(words_of(p))
    return out

def names_of(item, check):
    """(bare issue numbers, owner/repo#N lowercased, project names) a line names."""
    bare, issues, projects = set(), set(), set()
    for lst in re.findall(r"\(#[0-9]+(?:,[ \t]*#[0-9]+)*[,)]", item):
        bare.update(re.findall(r"[0-9]+", lst))
    for w in checks_of(check):
        if len(w) == 3 and w[0] == "gh-issue" and w[2].lower() in ("open", "closed"):
            if re.fullmatch(r"[0-9]+", w[1]):
                bare.add(str(int(w[1])))
            else:
                m = re.fullmatch(r"(" + SLUG + r")#([0-9]+)", w[1])
                if m:
                    issues.add("%s#%d" % (m.group(1).lower(), int(m.group(2))))
        elif len(w) == 5 and w[:3] == ["script", "adapter", "--project"] and w[4] == "validate" \
                and re.fullmatch(r"[A-Za-z0-9._-]+", w[3]):
            projects.add(w[3])
    return {str(int(n)) for n in bare}, issues, projects
PY

# --- own repository, default branch, pull-request source -------------------
OWN_REPO=no
top="$(git -C "$ROOT" rev-parse --show-toplevel 2>/dev/null)" || top=""
[[ -n "$top" && "$(phys "$top")" == "$ROOT" ]] && OWN_REPO=yes

has_branch() { git -C "$ROOT" rev-parse -q --verify "refs/heads/$1" >/dev/null 2>&1; }
DEFAULT_BRANCH=""
PR_SOURCE=none
PR_SOURCE_WHY="this root is not a git repository of its own"
if [[ "$OWN_REPO" == yes ]]; then
    head_ref="$(git -C "$ROOT" symbolic-ref -q refs/remotes/origin/HEAD 2>/dev/null)" || head_ref=""
    head_ref="${head_ref#refs/remotes/origin/}"
    if [[ -n "$head_ref" ]] && has_branch "$head_ref"; then
        DEFAULT_BRANCH="$head_ref"
    else
        found=""
        for b in main master; do
            has_branch "$b" && found="$found $b"
        done
        found="${found# }"
        [[ -n "$found" && "$found" != *" "* ]] && DEFAULT_BRANCH="$found"
    fi
    slug="$(python3 -c "$PYLIB"$'\nimport sys\nprint(origin_slug(sys.argv[1]))' "$ROOT")" || slug=""
    if [[ -n "$slug" ]]; then
        PR_SOURCE="$slug"; PR_SOURCE_WHY=""
    elif git -C "$ROOT" remote get-url origin >/dev/null 2>&1; then
        PR_SOURCE_WHY="origin not recognised as GitHub"
    else
        PR_SOURCE_WHY="no origin remote"
    fi
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
    # check <name> <file> <reads the default branch: yes|no>
    check() {
        local on_db=no
        [[ -n "$DEFAULT_BRANCH" ]] && git -C "$ROOT" cat-file -e "$DEFAULT_BRANCH:$2" 2>/dev/null && on_db=yes
        if [[ "$3" != yes ]]; then
            if [[ -e "$ROOT/$2" ]]; then echo "check_$1=run"; else echo "check_$1=skipped ($2 not in this root)"; fi
        elif [[ "$on_db" == yes ]]; then
            echo "check_$1=run"
        elif [[ ! -e "$ROOT/$2" ]]; then
            echo "check_$1=skipped ($2 not in this root)"
        elif [[ "$OWN_REPO" != yes ]]; then
            echo "check_$1=skipped (this root is not a git repository of its own)"
        elif [[ -z "$DEFAULT_BRANCH" ]]; then
            echo "check_$1=skipped (no default branch)"
        else
            echo "check_$1=skipped ($2 not on the default branch $DEFAULT_BRANCH)"
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
    echo "pr_source_why=$PR_SOURCE_WHY"
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

# The main checkout's worktree_list.sh, which reads the registry the root
# was decided from (the header's "Registry"). Its stderr (its warnings, a
# malformed registry say, or the reason it failed) goes straight to ours.
WL="$WS_ROOT/.agent/scripts/worktree_list.sh"
[[ -f "$WL" ]] || WL="$SCRIPT_DIR/worktree_list.sh"
rc=0
json="$(cd "$DIR" && bash "$WL" --json)" || rc=$?
if [[ $rc -ne 0 ]]; then
    echo "sitrep_root: worktree_list.sh --json failed (exit $rc)" >&2
    exit "$rc"
fi

[[ -n "$ROWS" && -f "$ROWS" && -r "$ROWS" ]] || ROWS=""
# The projects an `adapter --project <name>` check names, as the adapter
# resolves <name> (registry_resolve_project_arg): a parent root is its
# default or only instance, the name worktree_list.sh gives its worktrees;
# a parent with several instances and no default names nothing, since the
# adapter fails on it. One "<name><TAB><resolved>" line each.
PROJECT_MAP=""
if [[ -n "$ROWS" ]]; then
    while IFS= read -r n; do
        [[ -n "$n" ]] || continue
        res="$(registry_resolve_project_arg "$WS_ROOT" "$n" 2>/dev/null)" || continue
        [[ -n "$res" ]] && PROJECT_MAP="$PROJECT_MAP$n"$'\t'"$res"$'\n'
    done < <(python3 -c "$PYLIB"$'\n''import sys
out = set()
for row in open(sys.argv[1], encoding="utf-8", errors="replace"):
    f = row.rstrip("\n").split("\t")
    if len(f) >= 4 and f[0] == "line":
        out |= names_of(f[1], f[3])[2]
print("\n".join(sorted(out)))' "$ROWS")
fi
JSON="$json" TYPE="$TYPE" PR_SOURCE="$PR_SOURCE" OWN_DIRS="$OWN_DIRS" PROJECT_MAP="$PROJECT_MAP" \
    ROOT_GIT="$ROOT_GIT" ROWS="$ROWS" python3 -c "$PYLIB"$'\n'"$(cat <<'PY'
import json, sys

try:
    doc = json.loads(os.environ["JSON"])
    entries = doc["worktrees"]
    if not isinstance(entries, list):
        raise ValueError
except (ValueError, KeyError, TypeError):
    sys.stderr.write("sitrep_root: worktree_list.sh --json printed no worktree list\n")
    sys.exit(1)

root_type = os.environ["TYPE"]
pr_source = os.environ["PR_SOURCE"].lower()
own_dirs = [d for d in os.environ["OWN_DIRS"].splitlines() if d]
root_git = os.environ["ROOT_GIT"]

# (b) and "named": what this root's Direction lines name, from step 1's
# line rows (kind, item, result, check, date).
have_rows = bool(os.environ["ROWS"])
named_bare, named_issues, named_projects = set(), set(), set()
if have_rows:
    with open(os.environ["ROWS"], encoding="utf-8", errors="replace") as fh:
        for row in fh:
            f = row.rstrip("\n").split("\t")
            if len(f) < 4 or f[0] != "line":
                continue
            b, i, p = names_of(f[1], f[3])
            named_bare |= b
            named_issues |= i
            named_projects |= p
# Each through the registry, as the adapter resolves it (PROJECT_MAP).
resolved = dict(l.split("\t", 1) for l in os.environ["PROJECT_MAP"].splitlines() if "\t" in l)
named_projects = {resolved[p] for p in named_projects if p in resolved}

memo = {}
def repository(path):
    """(repository, its directories, why not, the manifest branch of each directory)."""
    if path in memo:
        return memo[path]
    m = os.path.join(path, ".worktree-repos")
    if not os.path.isfile(m):
        s = origin_slug(path)
        res = (s, [path], "" if s else "no GitHub remote", {})
    else:
        with open(m, encoding="utf-8", errors="replace") as fh:
            lines = fh.read().splitlines()
        hdr = re.search(r" issue=(\S+)", lines[0]) if lines else None
        named = ""
        if hdr:
            mh = re.fullmatch(r"(" + SLUG + r")#[0-9]+", hdr.group(1))
            named = mh.group(1) if mh else ""
        listed, branch = [], {}
        for l in lines[1:]:
            cols = l.split("\t")
            if len(cols) < 2 or not cols[1]:
                continue
            d = path if cols[1] == "." else os.path.join(path, cols[1])
            listed.append((origin_slug(d), d))
            branch[d] = cols[2] if len(cols) > 2 else ""
        s, why = named, ""
        if not s:
            agree = {x.lower() for x, _ in listed}
            if len(agree) == 1 and "" not in agree:
                s = listed[0][0]
            elif listed:
                why = "its checkouts are not all in one GitHub repository"
            else:
                why = "no GitHub remote"
        dirs = [d for x, d in listed if s and x.lower() == s.lower()]
        res = (s, dirs, why, branch)
    memo[path] = res
    return res

def under(path, dirs):
    p = os.path.realpath(path)
    return any(p == d or p.startswith(d.rstrip("/") + "/") for d in dirs)

kept = []
for w in entries:
    t, path = w.get("type"), w.get("path") or ""
    manifest = bool(path) and os.path.isfile(os.path.join(path, ".worktree-repos"))
    if root_type == "workspace":
        part_a = t in ("workspace", "main")
        own = part_a
    else:
        part_a = t == "project" and under(path, own_dirs)
        own = False
        if part_a:
            if manifest:
                own = pr_source != "none" and repository(path)[0].lower() == pr_source
            elif root_git:
                c = git(path, "rev-parse", "--path-format=absolute", "--git-common-dir")
                own = bool(c) and os.path.realpath(c) == root_git
    issue = w.get("issue")
    keep = part_a
    if not keep and t == "project" and (w.get("repo") or "") in named_projects:
        keep = True
    if not keep and issue is not None and named_issues:
        s = repository(path)[0]
        keep = bool(s) and ("%s#%s" % (s.lower(), issue)) in named_issues
    if not keep:
        continue
    s, dirs, why, branch = repository(path)
    pr_branch = ""
    if own:
        if manifest:
            bs = {branch.get(d, "") for d in dirs}
            pr_branch = bs.pop() if len(bs) == 1 else ""
        else:
            pr_branch = w.get("branch") or ""
    w["own"] = "yes" if own else "no"
    w["repository"] = s
    w["repository_dirs"] = dirs
    w["repository_why"] = why
    w["pr_branch"] = pr_branch
    if have_rows:
        named = issue is not None and (
            (own and str(issue) in named_bare)
            or (bool(s) and ("%s#%s" % (s.lower(), issue)) in named_issues))
        named = named or (t == "project" and (w.get("repo") or "") in named_projects)
        w["named"] = "yes" if named else "no"
    kept.append(w)
print(json.dumps({"worktrees": kept}))
PY
)"
