#!/usr/bin/env bash
# .agent/scripts/project_integration_audit.sh
# How a registered project and the workspace fit together (issue #332, PR
# 3): the mechanical half of /onboard-project's integration audit, also
# run by /audit-project. It reports; the skill judges and asks. Read-only.
#
# Usage:
#   project_integration_audit.sh [--dir D | --project N] [--instance I]
#                                [--facts] [--format tsv|text]
#
#   --dir D        audit the registered project whose root contains D
#                  (default: the current directory)
#   --project N    audit registered project N
#   --instance I   at a parent root, the instance audited: instance I
#                  (default: the parent's default_instance, else its only
#                  instance; with several and no default, none is, and the
#                  text format says so). Categories 1 to 5 read that
#                  instance's settings and repository alone: the fix
#                  batch can only write there, and a parent root has no
#                  settings of its own. Its own files are not audited.
#   --format tsv   (default) one finding per line:
#                  category<TAB>id<TAB>severity<TAB>subject<TAB>detail
#                  No line at all means no findings.
#   --format text  the same findings grouped under the category names, and
#                  a count at the end
#   --facts        instead of the findings, the facts /audit-project reads
#                  to skip the hygiene items they make moot (#332 PR 4),
#                  read rather than guessed, one per line in this order:
#                  fact<TAB>value<TAB>evidence (text: "fact: value --
#                  evidence"), value yes, no or unknown:
#                    github           the audited repository's remote
#                                     (origin, else its first) is on
#                                     github.com; the evidence names
#                                     github.com/<owner>/<repo>
#                    issues           it uses GitHub issues: enabled, and
#                                     at least one ever opened (gh repo
#                                     view, then gh issue list --state all
#                                     when none is open)
#                    prs              it uses pull requests: at least one
#                                     ever opened (gh repo view, then gh
#                                     pr list --state all)
#                    windows          this machine runs Windows (uname -s:
#                                     MINGW, MSYS or CYGWIN)
#                    multi_component  component manifests (package.xml,
#                                     Cargo.toml, package.json,
#                                     pyproject.toml, setup.py, go.mod, a
#                                     CMakeLists.txt with project()) in two
#                                     or more directories, tracked files
#                                     only, node_modules/, vendor/ and
#                                     third_party/ left out
#                  issues and prs are no without a GitHub remote, and
#                  unknown when gh or jq is missing or gh fails (not
#                  signed in, offline); the evidence says which.
#
# Severity: error (the workspace cannot work with the project as it is),
# warn (worth fixing or deciding), info (for the record; nothing to do
# unless the user wants to). A finding whose fix would add or change a
# tracked file in the project is info, never warn, when the project's
# settings say instructions=none: the workspace offers nothing there.
# Those ids: skill-same-name, command-same-name, process-branch,
# process-issue, work-plans-ignored, old-work-plans, records-two-places,
# ignored-agent-file, ignore-would-hide, conventions-unread. The rest keep
# their severity: their fix touches no tracked file (a setting, a
# .git/info/exclude line, the registration) or they report what the
# project already loads (settings-hooks, settings-unread).
#
# Categories (ids are stable; the skill and tests key off them):
#   1 overrides   project configuration that overrides or layers over the
#                 workspace's: a project skill or command with a workspace
#                 skill's name (skill-same-name, identical or differing,
#                 with line counts; command-same-name), hooks and allow
#                 rules in .claude/settings*.json (settings-hooks,
#                 settings-allow), .mcp.json servers (mcp-servers), @
#                 imports in CLAUDE.md (claude-md-import)
#   2 process     instruction lines that may disagree with the workspace's
#                 process, candidates only: feature branches rather than
#                 worktrees (process-branch), an issue only "when one
#                 exists" (process-issue), commit or pull request
#                 signatures (process-signature), build or test commands
#                 that are not the project's own (process-build-command)
#   3 written     files the workspace writes into the project: the
#                 worktrees directory not ignored (worktrees-not-ignored),
#                 .agent/work-plans/ against the records settings
#                 (work-plans-ignored, work-plans-not-ignored), the older
#                 docs/work-plans/ (old-work-plans), records in two places
#                 (records-two-places)
#   4 ignore      ignore rules hiding agent files: agent files present but
#                 ignored (ignored-agent-file, one per ignoring rule naming
#                 up to three of its files; Claude Code's own
#                 settings.local.json and .claude/worktrees/ are meant to
#                 be ignored and are not reported), a path the workspace would
#                 add that an ignore rule would hide (ignore-would-hide)
#   5 conventions rule-like lines in instruction files and project skills,
#                 with no .agents/README.md or .agents/review-context.yaml
#                 for the workspace's review skills to read
#                 (conventions-unread)
#   6 registration registration that does not work: registration_verify.sh
#                 failures and warnings (registration, registration-note;
#                 at a parent root for the parent and the audited
#                 instance, each finding's subject naming which),
#                 the user tier not installed or out of date (user-tier),
#                 a session at the root not resolving to the project
#                 (session-root), a parent root with no instance to audit
#                 (parent-instance: error with none registered, info with
#                 several and no default_instance or --instance)
# Category 7 of the plan (skills with no session_scope) is not a per-project
# check (#331). A root that is not a git repository gets one info finding
# (not-git) and no git checks.
#
# Exit codes: 0 the audit ran (whatever it found); 2 usage, a directory
# under no registered project root, an unregistered name, an --instance
# that is not an instance of the audited parent root (or given for a
# project that is no parent root), or a registry that does not parse.
#
# Like registration_verify.sh, from a linked worktree of the workspace it
# reads the main checkout's registry and settings files.
#
# user-tier: inert -- read-only: prints findings and writes nothing. It
# runs registration_verify.sh, user_tier_install.sh --check, session_root.sh
# and read-only git queries (check-ignore, ls-files, remote get-url); no
# repo-changing git call. Only --facts calls gh, and only to read (repo
# view, issue list, pr list), and uname. Outside every registered root it
# exits 2 saying so, which is its job.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=_project_registry.sh
source "$SCRIPT_DIR/_project_registry.sh"

usage() {
    sed -n '/^# Usage:/,/^# Severity:/p' "${BASH_SOURCE[0]}" | sed -e '$d' -e 's/^# \{0,1\}//' >&2
}

DIR=""
NAME=""
INSTANCE=""
FORMAT="tsv"
FACTS=0
while [ $# -gt 0 ]; do
    case "$1" in
        --facts)   FACTS=1; shift ;;
        --dir)     [ $# -ge 2 ] && [ -n "$2" ] || { usage; exit 2; }; DIR="$2"; shift 2 ;;
        --project) [ $# -ge 2 ] && [ -n "$2" ] || { usage; exit 2; }; NAME="$2"; shift 2 ;;
        --instance) [ $# -ge 2 ] && [ -n "$2" ] || { usage; exit 2; }; INSTANCE="$2"; shift 2 ;;
        --format)  [ $# -ge 2 ] || { usage; exit 2; }; FORMAT="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "ERROR: unknown argument '$1'" >&2; usage; exit 2 ;;
    esac
done
case "$FORMAT" in tsv|text) ;; *) echo "ERROR: --format is tsv or text, not '$FORMAT'" >&2; exit 2 ;; esac
if [ -n "$DIR" ] && [ -n "$NAME" ]; then
    echo "ERROR: --dir and --project are alternatives; give one" >&2
    exit 2
fi

# The main checkout (the parent of git's common dir) when this copy is a
# linked worktree: the registry and settings files live only there.
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
MAIN_ROOT="$ROOT"
_GITDIR="$(cd "$ROOT" && cd "$(git rev-parse --git-dir 2>/dev/null)" 2>/dev/null && pwd -P)" || _GITDIR=""
_COMMON="$(cd "$ROOT" && cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd -P)" || _COMMON=""
if [ -n "$_GITDIR" ] && [ -n "$_COMMON" ] && [ "$_GITDIR" != "$_COMMON" ]; then
    MAIN_ROOT="$(dirname "$_COMMON")"
fi

# ------------------------------------------------------ which project ---
if [ -z "$NAME" ]; then
    DIR="${DIR:-$PWD}"
    if ! _ABS="$(cd "$DIR" 2>/dev/null && pwd -P)"; then
        echo "ERROR: $DIR is not a directory" >&2
        exit 2
    fi
    _RC=0
    _ENTRY="$(registry_resolve_session_dir "$MAIN_ROOT" "$_ABS")" || _RC=$?
    if [ "$_RC" -eq 2 ]; then
        echo "ERROR: the registry $(registry_file "$MAIN_ROOT") does not parse (above); fix it first" >&2
        exit 2
    fi
    if [ "$_RC" -ne 0 ]; then
        echo "ERROR: $_ABS is under no registered project root ($(registry_file "$MAIN_ROOT")): register the project first, from a workspace session: $MAIN_ROOT/.agent/scripts/register_project.sh <path>" >&2
        exit 2
    fi
    NAME="$(cut -f1 <<< "$_ENTRY")"
fi
_RC=0
ENTRY="$(registry_lookup "$MAIN_ROOT" "$NAME")" || _RC=$?
if [ "$_RC" -eq 2 ]; then
    echo "ERROR: the registry $(registry_file "$MAIN_ROOT") does not parse (above); fix it first" >&2
    exit 2
fi
if [ "$_RC" -ne 0 ]; then
    echo "ERROR: project '$NAME' is not registered in $(registry_file "$MAIN_ROOT")" >&2
    exit 2
fi
TYPE="$(cut -f1 <<< "$ENTRY")"
PROOT="$(cut -f2 <<< "$ENTRY")"
PROOT_ABS="$(cd "$PROOT" 2>/dev/null && pwd -P)" || PROOT_ABS=""

# The project whose settings apply: a parent root has none of its own; its
# default (or only) instance carries them.
SNAME="$NAME"
if [ "$TYPE" = "$REGISTRY_PARENT_TYPE" ]; then
    if [ -n "$INSTANCE" ]; then
        if [ "$(registry_field "$MAIN_ROOT" "$INSTANCE" parent 2>/dev/null)" != "$NAME" ]; then
            echo "ERROR: '$INSTANCE' is not a registered instance of the parent root '$NAME' (its instances: $(registry_instances "$MAIN_ROOT" "$NAME" 2>/dev/null | paste -sd' ' -))" >&2
            exit 2
        fi
        SNAME="$INSTANCE"
    else
        SNAME="$(registry_default_instance "$MAIN_ROOT" "$NAME" 2>/dev/null)" || SNAME=""
    fi
elif [ -n "$INSTANCE" ]; then
    echo "ERROR: --instance is for a parent root; '$NAME' is a $TYPE project with settings of its own" >&2
    exit 2
fi

# The one repository categories 1 to 5 read: the project's root, or at a
# parent root the chosen instance's, because the fix batch can only write
# there (its worktree, branch and pull request are the instance's). The
# parent root's own files are not audited. SESSION_ABS stays the registered
# root, where a session starts (category 6's session-root check).
SESSION_ABS="$PROOT_ABS"
SESSION_PATH="$PROOT"
AUD_NAME="$NAME"
if [ "$TYPE" = "$REGISTRY_PARENT_TYPE" ]; then
    PROOT=""; PROOT_ABS=""; AUD_NAME=""
    if [ -n "$SNAME" ]; then
        AUD_NAME="$SNAME"
        PROOT="$(registry_lookup "$MAIN_ROOT" "$SNAME" 2>/dev/null | cut -f2)"
        PROOT_ABS="$(cd "$PROOT" 2>/dev/null && pwd -P)" || PROOT_ABS=""
    fi
fi

# ----------------------------------------------------------- findings ---
FINDINGS=""
# emit <category> <id> <severity> <subject> <detail>: one TSV line; a tab
# or a line break inside a field becomes a space or " | " (awk, not GNU
# sed's ':a;N;$!ba' loop, which BSD sed refuses).
clean() { printf '%s' "$1" | tr '\t' ' ' | awk 'NR > 1 { printf " | " } { printf "%s", $0 }'; }
emit() {
    FINDINGS+="$(clean "$1")"$'\t'"$(clean "$2")"$'\t'"$(clean "$3")"$'\t'"$(clean "$4")"$'\t'"$(clean "$5")"$'\n'
}

# The instructions setting, read once; findings whose fix is a tracked file
# (the ids in the header) go through emit_offer and drop to info when it is
# none.
INSTRUCTIONS=""
SETTINGS_OK=1
if [ -n "$SNAME" ]; then
    _RC=0
    INSTRUCTIONS="$(project_file_get "$MAIN_ROOT" "$SNAME" instructions 2>/dev/null)" || _RC=$?
    [ "$_RC" -eq 2 ] && SETTINGS_OK=0
    [ "$_RC" -ne 0 ] && INSTRUCTIONS=""
fi
emit_offer() {  # like emit, for a finding whose fix changes a tracked file
    local sev="$3" detail="$5"
    if [ "$INSTRUCTIONS" = "none" ] && [ "$sev" = "warn" ]; then
        sev="info"
        detail="$detail (instructions=none: nothing is offered)"
    fi
    emit "$1" "$2" "$sev" "$4" "$detail"
}

IS_GIT=0
if [ -n "$PROOT_ABS" ] && git -C "$PROOT_ABS" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
        && [ "$(cd "$(git -C "$PROOT_ABS" rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null && pwd -P)" = "$PROOT_ABS" ]; then
    IS_GIT=1
fi
g() { git -C "$PROOT_ABS" "$@"; }

# -------------------------------------------------------------- facts ---
# --facts: what the audited repository (at a parent root, the chosen
# instance's) and this machine are, so /audit-project skips the hygiene
# items a fact makes moot and says why. Printed instead of the findings.
if [ "$FACTS" -eq 1 ]; then
    FACT_LINES=""
    fact() { FACT_LINES+="$1"$'\t'"$2"$'\t'"$(clean "$3")"$'\n'; }

    # Why the repository cannot be read, if it cannot.
    REPO_WHY=""
    if [ -z "$PROOT_ABS" ]; then
        if [ "$TYPE" = "$REGISTRY_PARENT_TYPE" ] && [ -z "$AUD_NAME" ]; then
            if [ -z "$(registry_instances "$MAIN_ROOT" "$NAME" 2>/dev/null)" ]; then
                REPO_WHY="the parent root '$NAME' has no instance registered, so there is no repository to read"
            else
                REPO_WHY="several instances of the parent root '$NAME' and no default_instance: pass --instance <name>"
            fi
        else
            REPO_WHY="the registered root $PROOT is not on disk"
        fi
    fi

    # github: the remote's host. origin, else the first remote.
    GH_REPO=""
    GH_STATE="unknown"
    if [ -n "$REPO_WHY" ]; then
        fact github unknown "$REPO_WHY"
    elif [ "$IS_GIT" -eq 0 ]; then
        GH_STATE="no"
        fact github no "the root is not the top of a git repository, so it has no remote of its own"
    else
        REMOTE="origin"
        g remote get-url origin >/dev/null 2>&1 || REMOTE="$(g remote 2>/dev/null | head -n1)"
        URL=""
        [ -n "$REMOTE" ] && URL="$(g remote get-url "$REMOTE" 2>/dev/null)"
        GH_STATE="no"
        if [ -z "$URL" ]; then
            fact github no "the repository has no remote"
        elif _records_local_remote_path "$PROOT_ABS" "$URL" >/dev/null; then
            fact github no "remote '$REMOTE' is a local path: $URL"
        else
            _N="$(_records_norm_url "$URL")"
            _HOST="${_N%%/*}"
            _PATH="${_N#*/}"
            if [ "$_HOST" = "github.com" ] && [[ "$_PATH" =~ ^[^/]+/[^/]+$ ]]; then
                GH_REPO="$_PATH"
                GH_STATE="yes"
                fact github yes "remote '$REMOTE' is github.com/$GH_REPO"
            else
                fact github no "remote '$REMOTE' is on $_HOST, not github.com: $URL"
            fi
        fi
    fi

    # issues and prs: gh repo view counts only open ones, so when none is
    # open, one list call over every state says whether any ever was.
    # ever_opened <issue|pr>: 0 yes, 1 no, 2 unknown (the reason on stdout)
    ever_opened() {
        local out rc=0 n what
        # Each call written out, so the read-only check in
        # test_user_tier_guard.sh sees exactly which gh commands run.
        case "$1" in
            issue) what="gh issue list"; out="$(gh issue list -R "$GH_REPO" --state all --limit 1 --json number 2>&1)" || rc=$? ;;
            *)     what="gh pr list"; out="$(gh pr list -R "$GH_REPO" --state all --limit 1 --json number 2>&1)" || rc=$? ;;
        esac
        if [ "$rc" -ne 0 ] || ! n="$(jq -er 'length' <<< "$out" 2>/dev/null)"; then
            if [ "$rc" -ne 0 ]; then
                echo "$what -R $GH_REPO failed (exit $rc): $(head -n1 <<< "$out")"
            else
                echo "$what -R $GH_REPO gave no JSON list: $(head -c 200 <<< "$out")"
            fi
            return 2
        fi
        [ "$n" -gt 0 ] 2>/dev/null && return 0
        return 1
    }
    if [ "$GH_STATE" = "unknown" ]; then
        fact issues unknown "github is unknown: $REPO_WHY"
        fact prs unknown "github is unknown: $REPO_WHY"
    elif [ "$GH_STATE" = "no" ]; then
        fact issues no "no GitHub remote, so gh can neither read nor open its issues"
        fact prs no "no GitHub remote, so gh can neither read nor open its pull requests"
    elif ! command -v gh >/dev/null 2>&1; then
        fact issues unknown "gh is not installed"
        fact prs unknown "gh is not installed"
    elif ! command -v jq >/dev/null 2>&1; then
        fact issues unknown "jq is not installed, so gh's answer was not read"
        fact prs unknown "jq is not installed, so gh's answer was not read"
    else
        _RC=0
        RV="$(gh repo view "$GH_REPO" --json hasIssuesEnabled,issues,pullRequests 2>&1)" || _RC=$?
        RV_TSV=""
        [ "$_RC" -eq 0 ] && RV_TSV="$(jq -r '[.hasIssuesEnabled, .issues.totalCount, .pullRequests.totalCount] | @tsv' <<< "$RV" 2>/dev/null)"
        if ! [[ "$RV_TSV" =~ ^(true|false)$'\t'[0-9]+$'\t'[0-9]+$ ]]; then
            _WHY="gh repo view $GH_REPO failed (exit $_RC): $(head -n1 <<< "$RV")"
            [ "$_RC" -eq 0 ] && _WHY="gh repo view $GH_REPO gave no hasIssuesEnabled, issues and pullRequests counts: $(head -c 200 <<< "$RV")"
            fact issues unknown "$_WHY"
            fact prs unknown "$_WHY"
        else
            IFS=$'\t' read -r _EN _OI _OP <<< "$RV_TSV"
            if [ "$_EN" = "false" ]; then
                fact issues no "issues are disabled on github.com/$GH_REPO"
            elif [ "$_OI" -gt 0 ]; then
                fact issues yes "$_OI open on github.com/$GH_REPO"
            else
                _RC=0
                _WHY="$(ever_opened issue)" || _RC=$?
                case "$_RC" in
                    0) fact issues yes "none open on github.com/$GH_REPO, but some were opened before" ;;
                    1) fact issues no "enabled on github.com/$GH_REPO, but none was ever opened" ;;
                    *) fact issues unknown "$_WHY" ;;
                esac
            fi
            if [ "$_OP" -gt 0 ]; then
                fact prs yes "$_OP open on github.com/$GH_REPO"
            else
                _RC=0
                _WHY="$(ever_opened pr)" || _RC=$?
                case "$_RC" in
                    0) fact prs yes "none open on github.com/$GH_REPO, but some were opened before" ;;
                    1) fact prs no "none was ever opened on github.com/$GH_REPO" ;;
                    *) fact prs unknown "$_WHY" ;;
                esac
            fi
        fi
    fi

    # windows: this machine, not the repository.
    _OS=""
    command -v uname >/dev/null 2>&1 && _OS="$(uname -s 2>/dev/null)"
    case "$_OS" in
        "") fact windows unknown "uname -s gave nothing on this machine" ;;
        MINGW*|MSYS*|CYGWIN*|Windows*) fact windows yes "this machine: uname -s is $_OS" ;;
        *) fact windows no "this machine: uname -s is $_OS" ;;
    esac

    # multi_component: the directories holding a component manifest.
    if [ -n "$REPO_WHY" ]; then
        fact multi_component unknown "$REPO_WHY"
    else
        MANIFESTS=(package.xml Cargo.toml package.json pyproject.toml setup.py go.mod CMakeLists.txt)
        _FILES=()
        if [ "$IS_GIT" -eq 1 ]; then
            _SPECS=()
            for m in "${MANIFESTS[@]}"; do _SPECS+=(":(glob)**/$m"); done
            while IFS= read -r -d '' p; do _FILES+=("$p"); done \
                < <(g ls-files -z -- "${_SPECS[@]}" 2>/dev/null)
        else
            _NAMES=()
            for m in "${MANIFESTS[@]}"; do _NAMES+=(-o -name "$m"); done
            while IFS= read -r -d '' p; do _FILES+=("${p#"$PROOT_ABS"/}"); done \
                < <(find "$PROOT_ABS" -maxdepth 4 \( -name .git -o -name node_modules -o -name vendor -o -name third_party \) -prune \
                        -o -type f \( -false "${_NAMES[@]}" \) -print0 2>/dev/null)
        fi
        declare -A _SEEN=()
        _DIRS=()
        for p in "${_FILES[@]+"${_FILES[@]}"}"; do
            case "/$p" in */node_modules/*|*/vendor/*|*/third_party/*) continue ;; esac
            if [ "$(basename "$p")" = "CMakeLists.txt" ]; then
                grep -qiE '^[[:space:]]*project[[:space:]]*\(' "$PROOT_ABS/$p" 2>/dev/null || continue
            fi
            d="$(dirname "$p")"
            [ -n "${_SEEN[$d]+set}" ] && continue
            _SEEN["$d"]=1
            _DIRS+=("$d")
        done
        _ND="${#_DIRS[@]}"
        _LIST="$(printf '%s\n' "${_DIRS[@]+"${_DIRS[@]}"}" | sort | head -n5 | paste -sd, - | sed 's/,/, /g')"
        [ "$_ND" -gt 5 ] && _LIST="$_LIST and $((_ND - 5)) more"
        if [ "$_ND" -ge 2 ]; then
            fact multi_component yes "component manifests in $_ND directories: $_LIST"
        elif [ "$_ND" -eq 1 ]; then
            fact multi_component no "component manifests in one directory: $_LIST"
        else
            fact multi_component no "no component manifest (${MANIFESTS[*]}) found"
        fi
    fi

    if [ "$FORMAT" = "tsv" ]; then
        printf '%s' "$FACT_LINES"
    else
        echo "Facts: ${AUD_NAME:-$NAME}${PROOT:+ at $PROOT}"
        printf '%s' "$FACT_LINES" | awk -F'\t' 'NF { printf "%s: %s -- %s\n", $1, $2, $3 }'
    fi
    exit 0
fi

if [ "$TYPE" = "$REGISTRY_PARENT_TYPE" ] && [ -z "$AUD_NAME" ]; then
    _INST="$(registry_instances "$MAIN_ROOT" "$NAME" 2>/dev/null | paste -sd' ' -)"
    if [ -z "$_INST" ]; then
        emit 6 parent-instance error "$NAME" "a parent root with no instances registered: its settings, worktrees and repository content are an instance's, so there is nothing to audit or onboard yet; register an instance first, from a workspace session: register_project.sh <path> --parent $NAME"
    else
        emit 6 parent-instance info "$NAME" "several instances ($_INST) and no default_instance: categories 1 to 5 audit one instance's repository and were not run; pass --instance <name>"
    fi
fi
if [ "$AUD_NAME" != "$NAME" ] && [ -z "$SESSION_ABS" ]; then
    emit 6 registration error "$SESSION_PATH" "the parent root is not on disk, so no session can start there"
fi
if [ -n "$AUD_NAME" ] && [ -z "$PROOT_ABS" ]; then
    emit 6 registration error "$PROOT" "the registered root$([ "$AUD_NAME" != "$NAME" ] && echo " of the instance $AUD_NAME") is not on disk, so nothing in it can be audited"
fi
if [ -n "$PROOT_ABS" ] && [ "$IS_GIT" -eq 0 ]; then
    emit 3 not-git info "$PROOT" "the root is not the top of a git repository: the ignore-rule checks (categories 3 and 4) are skipped"
fi

# The project's instruction files, relative to the root.
INSTR_FILES=()
if [ -n "$PROOT_ABS" ]; then
    for f in CLAUDE.md CLAUDE.local.md .claude/CLAUDE.md AGENTS.md GEMINI.md CODEX.md \
             .github/copilot-instructions.md .agents/README.md; do
        [ -f "$PROOT_ABS/$f" ] && INSTR_FILES+=("$f")
    done
fi

# ------------------------------------------------- 1. overrides --------
if [ -n "$PROOT_ABS" ]; then
    for d in "$PROOT_ABS"/.claude/skills/*/; do
        [ -f "$d/SKILL.md" ] || continue
        sk="$(basename "$d")"
        ws="$MAIN_ROOT/.claude/skills/$sk/SKILL.md"
        [ -f "$ws" ] || continue
        pl="$(wc -l < "$d/SKILL.md" | tr -d ' ')"
        wl="$(wc -l < "$ws" | tr -d ' ')"
        if cmp -s "$d/SKILL.md" "$ws"; then
            emit_offer 1 skill-same-name warn ".claude/skills/$sk" "identical to the workspace skill '$sk' ($pl lines): a copy that will drift; in a project session the workspace's is /agent-workspace:$sk"
        else
            emit_offer 1 skill-same-name warn ".claude/skills/$sk" "differs from the workspace skill '$sk' (project $pl lines, workspace $wl lines); in a project session the bare /$sk is the project's and /agent-workspace:$sk the workspace's"
        fi
    done
    for c in "$PROOT_ABS"/.claude/commands/*.md; do
        [ -f "$c" ] || continue
        cn="$(basename "$c" .md)"
        [ -f "$MAIN_ROOT/.claude/skills/$cn/SKILL.md" ] || continue
        emit_offer 1 command-same-name warn ".claude/commands/$cn.md" "a project command with the workspace skill's name '$cn' ($(wc -l < "$c" | tr -d ' ') lines); the bare /$cn is the project's"
    done
    for s in .claude/settings.json .claude/settings.local.json; do
        sf="$PROOT_ABS/$s"
        [ -f "$sf" ] || continue
        if ! command -v jq >/dev/null 2>&1; then
            emit 1 settings-unread info "$s" "jq is not installed, so its hooks and allow rules were not read"
            continue
        fi
        if ! jq -e . "$sf" >/dev/null 2>&1; then
            emit 1 settings-unread warn "$s" "not valid JSON, so Claude Code ignores it"
            continue
        fi
        hooks="$(jq -r '(.hooks // {}) | to_entries[] | "\(.key) (\(.value | length))"' "$sf" 2>/dev/null | paste -sd, - | sed 's/,/, /g')"
        [ -n "$hooks" ] && emit 1 settings-hooks warn "$s" "hooks: $hooks; they run beside the user tier's hooks in a project session"
        nallow="$(jq -r '(.permissions.allow // []) | length' "$sf" 2>/dev/null)"
        [ "${nallow:-0}" -gt 0 ] 2>/dev/null && emit 1 settings-allow info "$s" "$nallow permission allow rule(s), added to the user tier's"
    done
    if [ -f "$PROOT_ABS/.mcp.json" ]; then
        servers=""
        command -v jq >/dev/null 2>&1 && servers="$(jq -r '(.mcpServers // {}) | keys[]' "$PROOT_ABS/.mcp.json" 2>/dev/null | paste -sd, - | sed 's/,/, /g')"
        emit 1 mcp-servers info ".mcp.json" "MCP servers: ${servers:-unread}"
    fi
    for f in CLAUDE.md .claude/CLAUDE.md CLAUDE.local.md; do
        [ -f "$PROOT_ABS/$f" ] || continue
        # An @ word, its trailing punctuation dropped, that is a path (a
        # '/' or a '.' before a letter or digit); "@someone" is a mention.
        imports="$(grep -oE '(^|[[:space:]])@[A-Za-z0-9_~./-]+' "$PROOT_ABS/$f" 2>/dev/null \
            | sed -e 's/^[[:space:]]*//' -e 's/[.,;:-]*$//' | grep -E '/|\.[A-Za-z0-9]' | sort -u | paste -sd' ' -)"
        [ -n "$imports" ] && emit 1 claude-md-import info "$f" "imports $imports into every session at the root"
    done
fi

# ------------------------------------------------- 2. process ----------
# The project's own build and test commands, for comparison.
OWN_CMDS=()
if [ -n "$SNAME" ] && [ "$SETTINGS_OK" -eq 1 ]; then
    for k in build test; do
        src="$(project_command_source "$MAIN_ROOT" "$SNAME" "$k" 2>/dev/null)" || continue
        from="$(cut -f1 <<< "$src")"
        val="$(cut -f2- <<< "$src")"
        case "$from" in file|legacy) [ -n "$val" ] && [ "$val" != "none" ] && OWN_CMDS+=("$val") ;; esac
    done
fi
OWN_DESC="the project's own: ${OWN_CMDS[*]:-none set}"
[ "${#OWN_CMDS[@]}" -gt 1 ] && OWN_DESC="the project's own: $(printf '%s; ' "${OWN_CMDS[@]}" | sed 's/; $//')"

# candidate <file> <id> <severity> <ERE> [<skip ERE>]: one finding per
# matching line the skip ERE does not drop, at most 10 per file and id, then
# one line with the count of them all.
candidate() {
    local f="$1" id="$2" sev="$3" re="$4" skip="${5:-}" n=0 total line ln text
    local hits=()
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        if [ -n "$skip" ] && grep -qiE "$skip" <<< "${line#*:}"; then
            continue
        fi
        hits+=("$line")
    done < <(grep -niE "$re" "$PROOT_ABS/$f" 2>/dev/null)
    total="${#hits[@]}"
    for line in "${hits[@]+"${hits[@]}"}"; do
        n=$((n + 1))
        if [ "$n" -gt 10 ]; then
            emit_offer 2 "$id" "$sev" "$f" "and more lines like these ($total in all)"
            break
        fi
        ln="${line%%:*}"
        text="$(sed -e 's/^[[:space:]]*//' <<< "${line#*:}" | cut -c1-200)"
        emit_offer 2 "$id" "$sev" "$f:$ln" "$text"
    done
}
BUILD_TOOLS='make|cmake|cargo|npm|pnpm|yarn|go|pytest|python3? -m pytest|colcon|ctest|ninja|meson'
# commands <text> [tools]: the commands a line names, one per line: each
# code span, or on a line with none, the line itself (blanks, a list marker
# -- "-", "*", "+", "1." or "1)" -- and a "$ " prompt dropped; the prose around a code span, as in "make sure
# `pytest` passes", is no command), split at &&, ||, ; and |, trimmed, a
# trailing comment and
# trailing punctuation dropped. With "tools", only the ones that start with
# a build or test tool. Plain awk ([ \t], not [[:space:]]), so mawk and BSD
# awk read it the same.
commands() {
    printf '%s\n' "$1" | awk -v tools="${2:+$BUILD_TOOLS}" '
    {
        lead = $0
        sub(/^[ \t]*(([-*+]|[0-9]+[.)])[ \t]+)?(\$[ \t]+)?/, "", lead)
        n = 0
        if (index(lead, "`") == 0) seg[++n] = lead
        rest = $0
        while ((p = index(rest, "`")) > 0) {
            rest = substr(rest, p + 1)
            q = index(rest, "`")
            if (!q) break
            seg[++n] = substr(rest, 1, q - 1)
            rest = substr(rest, q + 1)
        }
        for (i = 1; i <= n; i++) {
            m = split(seg[i], parts, /&&|[|][|]|;|[|]/)
            for (j = 1; j <= m; j++) {
                c = parts[j]
                sub(/^[ \t]+/, "", c)
                sub(/^\$[ \t]+/, "", c)
                sub(/[ \t]+#.*$/, "", c)
                sub(/[ \t]+$/, "", c)
                sub(/[.,:]+$/, "", c)
                if (c == "") continue
                if (tools == "" || c ~ ("^(" tools ")([ \t]|$)")) print c
            }
        }
    }'
}
# The parts of the project's own commands ("cmake -S . -B build && cmake
# --build build" is two), against which a line's commands are compared.
OWN_PARTS=()
for own in "${OWN_CMDS[@]+"${OWN_CMDS[@]}"}"; do
    while IFS= read -r part; do
        [ -n "$part" ] && OWN_PARTS+=("$part")
    done < <(commands "$own")
done
is_own() {  # <command>: one of the project's own, or one with more arguments
    local part
    for part in "${OWN_PARTS[@]+"${OWN_PARTS[@]}"}"; do
        [ "$1" = "$part" ] && return 0
        [[ "$1" == "$part "* ]] && return 0
    done
    return 1
}
build_candidates() {  # <file>: build/test command lines that are not the project's own
    local f="$1" n=0 line ln text cmd foreign
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        ln="${line%%:*}"
        text="${line#*:}"
        # Each command on the line on its own: "make" being the project's
        # own neither hides "cmake --build build" nor a second command.
        foreign=0
        while IFS= read -r cmd; do
            [ -n "$cmd" ] || continue
            is_own "$cmd" || foreign=1
        done < <(commands "$text" tools)
        [ "$foreign" -eq 1 ] || continue
        n=$((n + 1))
        [ "$n" -gt 10 ] && { emit 2 process-build-command info "$f" "and more build or test command lines"; break; }
        text="$(sed -e 's/^[[:space:]]*//' <<< "$text" | cut -c1-200)"
        emit 2 process-build-command info "$f:$ln" "$text ($OWN_DESC)"
    # A command at the start of a line (after blanks, a list marker -- "-",
    # "*", "+", "1." or "1)" -- or a "$ " prompt) or of a code span, so
    # prose such as "make sure" is not one.
    done < <(grep -nE "(^[[:space:]]*(([-*+]|[0-9]+[.)])[[:space:]]+)?(\\\$[[:space:]]+)?|\`)($BUILD_TOOLS)([[:space:]\`]|\$)" "$PROOT_ABS/$f" 2>/dev/null)
}
for f in "${INSTR_FILES[@]+"${INSTR_FILES[@]}"}"; do
    candidate "$f" process-branch warn 'feature[- ]branch|git (checkout|switch) -[bc]|create (a )?(new )?branch' 'worktree'
    candidate "$f" process-issue warn '(if|when|where) (one|an issue|it|there is one) (exists|is open)|issue[^.]{0,40}(if|when) (one|available|applicable)'
    candidate "$f" process-signature info 'co-authored-by|signed-off-by|generated with|authored-by|signature'
    build_candidates "$f"
done

# ------------------------------------------------- 3. written files ----
if [ "$IS_GIT" -eq 1 ]; then
    WTDIR="$(registry_worktree_dir "$MAIN_ROOT" "$AUD_NAME" 2>/dev/null)" || WTDIR=""
    # Canonical, like PROOT_ABS, although the directory usually does not
    # exist yet: the deepest existing ancestor resolved (a root registered
    # through a symlink), the rest appended.
    WTABS=""
    if [ -n "$WTDIR" ]; then
        _head="$WTDIR"; _tail=""
        while [ ! -d "$_head" ] && [ "$_head" != "/" ] && [ "$_head" != "." ]; do
            _tail="/$(basename "$_head")$_tail"
            _head="$(dirname "$_head")"
        done
        WTABS="$(cd "$_head" 2>/dev/null && pwd -P)$_tail" || WTABS="$WTDIR"
        WTABS="${WTABS/#\/\//\/}"
    fi
    if [ -n "$WTABS" ] && [[ "$WTABS" == "$PROOT_ABS/"* ]]; then
        rel="${WTABS#"$PROOT_ABS"/}"
        if ! g check-ignore -q -- "$rel/probe" 2>/dev/null; then
            emit 3 worktrees-not-ignored warn "$rel/" "the worktrees directory is inside the project and no ignore rule covers it, so git status there shows it; worktree_create.sh adds '$rel/' to .git/info/exclude (untracked) when it creates the first worktree, and it can be added now the same way"
        fi
    fi

    REC_LOC="project"; REC_TRACK="project"
    if [ -n "$SNAME" ] && [ "$SETTINGS_OK" -eq 1 ]; then
        _REC="$(project_records_check "$MAIN_ROOT" "$SNAME" 2>/dev/null)" || true
        [ -n "$_REC" ] && IFS=$'\t' read -r REC_LOC REC_TRACK _ <<< "$_REC"
    fi
    WP_PROBE=".agent/work-plans/issue-1/progress.md"
    WP_IGN=0
    g check-ignore -q -- "$WP_PROBE" 2>/dev/null && WP_IGN=1
    case "$REC_LOC/$REC_TRACK" in
        project/project)
            if [ "$WP_IGN" -eq 1 ]; then
                emit_offer 3 work-plans-ignored warn ".agent/work-plans/" "records are committed in the project (location=project tracking=project) but an ignore rule hides them: $(g check-ignore -v -- "$WP_PROBE" 2>/dev/null | cut -f1)"
            fi ;;
        project/untracked)
            if [ "$WP_IGN" -eq 0 ]; then
                emit 3 work-plans-not-ignored warn ".agent/work-plans/" "records are kept untracked in the project (tracking=untracked), but no ignore rule covers .agent/work-plans/; it belongs in .git/info/exclude"
            fi ;;
    esac
    has_files() { [ -d "$1" ] && [ -n "$(find "$1" -type f -print -quit 2>/dev/null)" ]; }
    if has_files "$PROOT_ABS/docs/work-plans"; then
        emit_offer 3 old-work-plans warn "docs/work-plans/" "the older records location; records now live under .agent/work-plans/issue-N/ (or where the records settings say)"
        if has_files "$PROOT_ABS/.agent/work-plans"; then
            emit_offer 3 records-two-places warn "docs/work-plans/ and .agent/work-plans/" "records exist in two places; the records settings (location=$REC_LOC) name .agent/work-plans/ as the source of truth"
        fi
    fi
    if [ "$REC_LOC" = "outside" ] && has_files "$PROOT_ABS/.agent/work-plans"; then
        emit_offer 3 records-two-places warn ".agent/work-plans/" "records exist in the project although the records settings say location=outside; the setting names the outside location as the source of truth"
    fi
fi

# ------------------------------------------------- 4. ignore rules -----
declare -A REPORTED=()
if [ "$IS_GIT" -eq 1 ]; then
    # One finding per ignoring rule, naming up to three of its files: a
    # rule such as build/ or *.local.md can hide many. Claude Code's own
    # per-machine files are meant to be ignored: settings.local.json and
    # its worktrees directory .claude/worktrees/.
    declare -A IGN_BY_RULE=()
    IGN_RULES=()
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        case "$p" in .claude/settings.local.json|.claude/worktrees/*) continue ;; esac
        rule="$(g check-ignore -v -- "$p" 2>/dev/null | cut -f1)"
        rule="${rule:-unknown}"
        if [ -z "${IGN_BY_RULE[$rule]+set}" ]; then
            IGN_RULES+=("$rule")
            IGN_BY_RULE["$rule"]="$p"
        else
            IGN_BY_RULE["$rule"]+=$'\n'"$p"
        fi
        REPORTED["$p"]=1
    done < <(g ls-files --others --ignored --exclude-standard -- .claude .agents AGENTS.md CLAUDE.md \
                 ':(exclude).claude/worktrees' 2>/dev/null)
    for rule in "${IGN_RULES[@]+"${IGN_RULES[@]}"}"; do
        files="${IGN_BY_RULE[$rule]}"
        n="$(wc -l <<< "$files" | tr -d ' ')"
        if [ "$n" -eq 1 ]; then
            emit_offer 4 ignored-agent-file warn "$files" "present but ignored, so it is never committed and no other clone or worktree has it; the rule: $rule"
        else
            subj="$(head -n3 <<< "$files" | paste -sd, - | sed 's/,/, /g')"
            [ "$n" -gt 3 ] && subj="$subj and $((n - 3)) more"
            emit_offer 4 ignored-agent-file warn "$subj" "$n files present but ignored by one rule, so they are never committed and no other clone or worktree has them; the rule: $rule"
        fi
    done
    for p in AGENTS.md CLAUDE.md .agents/README.md .agents/review-context.yaml docs/roadmap.md \
             .pre-commit-config.yaml .github/workflows/ci.yml; do
        [ -n "${REPORTED[$p]:-}" ] && continue
        g ls-files --error-unmatch -- "$p" >/dev/null 2>&1 && continue
        # -q decides: with -v, check-ignore also prints a negated ("!")
        # rule that un-ignores the path, and exits 0 for it.
        g check-ignore -q --no-index -- "$p" 2>/dev/null || continue
        rule="$(g check-ignore -v --no-index -- "$p" 2>/dev/null | cut -f1)" || rule=""
        emit_offer 4 ignore-would-hide warn "$p" "a file the workspace may offer here would be ignored; the rule: $rule"
    done
fi

# ------------------------------------------------- 5. conventions ------
if [ -n "$PROOT_ABS" ] && [ ! -f "$PROOT_ABS/.agents/README.md" ] && [ ! -f "$PROOT_ABS/.agents/review-context.yaml" ]; then
    RULE_FILES=("${INSTR_FILES[@]+"${INSTR_FILES[@]}"}")
    for f in "$PROOT_ABS"/.claude/skills/*/SKILL.md "$PROOT_ABS"/.claude/commands/*.md; do
        [ -f "$f" ] && RULE_FILES+=("${f#"$PROOT_ABS"/}")
    done
    total=0
    where=()
    for f in "${RULE_FILES[@]+"${RULE_FILES[@]}"}"; do
        n="$(grep -ciE "\\b(must|never|always|do not|don't|should)\\b" "$PROOT_ABS/$f" 2>/dev/null)" || n=0
        if [ "$n" -gt 0 ]; then
            total=$((total + n))
            where+=("$f ($n)")
        fi
    done
    if [ "$total" -gt 0 ]; then
        emit_offer 5 conventions-unread warn "$(printf '%s, ' "${where[@]}" | sed 's/, $//')" "$total rule-like lines, but no .agents/README.md or .agents/review-context.yaml, where the workspace's review-plan and review-code skills read a project's conventions"
    fi
fi

# ------------------------------------------------- 6. registration -----
# verify_registration <name>: registration_verify.sh's failures and
# warnings, each with <name> as its subject.
verify_registration() {
    local n="$1" rc=0 out line
    out="$("$MAIN_ROOT/.agent/scripts/registration_verify.sh" "$n" 2>&1)" || rc=$?
    while IFS= read -r line; do
        case "$line" in
            FAIL:*) emit 6 registration error "$n" "${line#FAIL: }" ;;
            WARN:*) emit 6 registration-note warn "$n" "${line#WARN: }" ;;
        esac
    done <<< "$out"
    if [ "$rc" -ne 0 ] && ! grep -q '^FAIL:' <<< "$out"; then
        emit 6 registration error "$n" "registration_verify.sh exited $rc: $(tail -n3 <<< "$out")"
    fi
}
# The registered root, and at a parent root the audited instance too: the
# parent's own check reads no settings, commands or adapter, which are the
# instance's.
verify_registration "$NAME"
if [ -n "$AUD_NAME" ] && [ "$AUD_NAME" != "$NAME" ]; then
    verify_registration "$AUD_NAME"
fi
_RC=0
UOUT="$("$MAIN_ROOT/.agent/scripts/user_tier_install.sh" --check --require 2>&1)" || _RC=$?
if [ "$_RC" -ne 0 ]; then
    emit 6 user-tier error "user tier" "user_tier_install.sh --check --require failed (exit $_RC), so a session at the root may not get the workspace plugin or scripts: $(grep -vE '^[[:space:]]*$' <<< "$UOUT" | head -n4)"
fi
if [ -n "$SESSION_ABS" ]; then
    _RC=0
    SOUT="$("$MAIN_ROOT/.agent/scripts/session_root.sh" --dir "$SESSION_ABS" 2>&1)" || _RC=$?
    _PROJ="$(sed -n 's/^project=//p' <<< "$SOUT")"
    if [ "$_RC" -ne 0 ] || [ "$_PROJ" != "$NAME" ]; then
        emit 6 session-root error "$SESSION_ABS" "a session started here does not resolve to '$NAME' (session_root.sh exit $_RC): $(head -n3 <<< "$SOUT")"
    fi
fi

# ------------------------------------------------------------ output ---
if [ "$FORMAT" = "tsv" ]; then
    printf '%s' "$FINDINGS"
    exit 0
fi

if [ "$TYPE" = "$REGISTRY_PARENT_TYPE" ]; then
    echo "Integration audit: $NAME ($TYPE) at $SESSION_ABS"
    if [ -n "$SNAME" ]; then
        echo "audited: instance $SNAME at $PROOT, its settings and its repository (a parent root has no settings of its own, and its own files are not audited)"
    else
        if [ -z "$(registry_instances "$MAIN_ROOT" "$NAME" 2>/dev/null)" ]; then
            echo "audited: no instance (none registered; register one first)"
        else
            echo "audited: no instance (several instances and no default_instance; pass --instance <name>)"
        fi
    fi
else
    echo "Integration audit: $NAME ($TYPE) at $PROOT"
fi
echo "instructions: ${INSTRUCTIONS:-not set}"
declare -A CAT_NAME=(
    [1]="Project configuration that overrides or layers over the workspace's"
    [2]="Instruction lines that may disagree with the workspace's process (candidates)"
    [3]="Files the workspace writes into the project"
    [4]="Ignore rules hiding agent files"
    [5]="Conventions where the workspace's tools do not read them"
    [6]="Registration that does not work"
)
n_err=0; n_warn=0; n_info=0
for cat in 1 2 3 4 5 6; do
    block="$(awk -F'\t' -v c="$cat" '$1 == c { printf "  [%s] %s: %s -- %s\n", $3, $2, $4, $5 }' <<< "$FINDINGS")"
    [ -n "$block" ] || continue
    echo ""
    echo "$cat. ${CAT_NAME[$cat]}"
    printf '%s\n' "$block"
done
while IFS=$'\t' read -r _c _i sev _s _d; do
    case "$sev" in error) n_err=$((n_err + 1)) ;; warn) n_warn=$((n_warn + 1)) ;; info) n_info=$((n_info + 1)) ;; esac
done <<< "$FINDINGS"
echo ""
if [ $((n_err + n_warn + n_info)) -eq 0 ]; then
    echo "No findings."
else
    echo "$((n_err + n_warn + n_info)) finding(s): $n_err error, $n_warn warn, $n_info info"
fi
exit 0
