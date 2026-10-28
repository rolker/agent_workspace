#!/usr/bin/env bash
# .agent/scripts/project_integration_audit.sh
# How a registered project and the workspace fit together (issue #332, PR
# 3): the mechanical half of /onboard-project's integration audit. It
# reports; the skill judges and asks. Read-only.
#
# Usage:
#   project_integration_audit.sh [--dir D | --project N] [--format tsv|text]
#
#   --dir D        audit the registered project whose root contains D
#                  (default: the current directory)
#   --project N    audit registered project N
#   --format tsv   (default) one finding per line:
#                  category<TAB>id<TAB>severity<TAB>subject<TAB>detail
#                  No line at all means no findings.
#   --format text  the same findings grouped under the category names, and
#                  a count at the end
#
# Severity: error (the workspace cannot work with the project as it is),
# warn (worth fixing or deciding), info (for the record; nothing to do
# unless the user wants to). A finding whose fix would add or change a
# tracked file in the project is info, never warn, when the project's
# settings say instructions=none: the workspace offers nothing there.
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
#   4 ignore      ignore rules hiding agent files: an agent file present but
#                 ignored (ignored-agent-file), a path the workspace would
#                 add that an ignore rule would hide (ignore-would-hide)
#   5 conventions rule-like lines in instruction files and project skills,
#                 with no .agents/README.md or .agents/review-context.yaml
#                 for the workspace's review skills to read
#                 (conventions-unread)
#   6 registration registration that does not work: registration_verify.sh
#                 failures and warnings (registration, registration-note),
#                 the user tier not installed or out of date (user-tier),
#                 a session at the root not resolving to the project
#                 (session-root)
# Category 7 of the plan (skills with no session_scope) is not a per-project
# check (#331). A root that is not a git repository gets one info finding
# (not-git) and no git checks.
#
# Exit codes: 0 the audit ran (whatever it found); 2 usage, a directory
# under no registered project root, an unregistered name, or a registry
# that does not parse.
#
# Like registration_verify.sh, from a linked worktree of the workspace it
# reads the main checkout's registry and settings files.
#
# user-tier: inert -- read-only: prints findings and writes nothing. It
# runs registration_verify.sh, user_tier_install.sh --check, session_root.sh
# and read-only git queries (check-ignore, ls-files); no gh call and no
# repo-changing git call. Outside every registered root it exits 2 saying
# so, which is its job.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=_project_registry.sh
source "$SCRIPT_DIR/_project_registry.sh"

usage() {
    sed -n '/^# Usage:/,/^# Severity:/p' "${BASH_SOURCE[0]}" | sed -e '$d' -e 's/^# \{0,1\}//' >&2
}

DIR=""
NAME=""
FORMAT="tsv"
while [ $# -gt 0 ]; do
    case "$1" in
        --dir)     [ $# -ge 2 ] && [ -n "$2" ] || { usage; exit 2; }; DIR="$2"; shift 2 ;;
        --project) [ $# -ge 2 ] && [ -n "$2" ] || { usage; exit 2; }; NAME="$2"; shift 2 ;;
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
    SNAME="$(registry_default_instance "$MAIN_ROOT" "$NAME" 2>/dev/null)" || SNAME=""
fi

# ----------------------------------------------------------- findings ---
FINDINGS=""
# emit <category> <id> <severity> <subject> <detail>: one TSV line; a tab
# or a line break inside a field becomes a space or " | ".
clean() { printf '%s' "$1" | tr '\t' ' ' | sed ':a;N;$!ba;s/\n/ | /g'; }
emit() {
    FINDINGS+="$(clean "$1")"$'\t'"$(clean "$2")"$'\t'"$(clean "$3")"$'\t'"$(clean "$4")"$'\t'"$(clean "$5")"$'\n'
}

# The instructions setting, read once; findings whose fix is a tracked file
# drop to info when it is none.
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

if [ -z "$PROOT_ABS" ]; then
    emit 6 registration error "$PROOT" "the registered root is not on disk, so nothing in it can be audited"
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
            emit 1 skill-same-name warn ".claude/skills/$sk" "identical to the workspace skill '$sk' ($pl lines): a copy that will drift; in a project session the workspace's is /agent-workspace:$sk"
        else
            emit 1 skill-same-name warn ".claude/skills/$sk" "differs from the workspace skill '$sk' (project $pl lines, workspace $wl lines); in a project session the bare /$sk is the project's and /agent-workspace:$sk the workspace's"
        fi
    done
    for c in "$PROOT_ABS"/.claude/commands/*.md; do
        [ -f "$c" ] || continue
        cn="$(basename "$c" .md)"
        [ -f "$MAIN_ROOT/.claude/skills/$cn/SKILL.md" ] || continue
        emit 1 command-same-name warn ".claude/commands/$cn.md" "a project command with the workspace skill's name '$cn' ($(wc -l < "$c" | tr -d ' ') lines); the bare /$cn is the project's"
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
# matching line, at most 10 per file and id.
candidate() {
    local f="$1" id="$2" sev="$3" re="$4" skip="${5:-}" n=0 total ln text
    total="$(grep -ciE "$re" "$PROOT_ABS/$f" 2>/dev/null)" || total=0
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        ln="${line%%:*}"
        text="${line#*:}"
        if [ -n "$skip" ] && grep -qiE "$skip" <<< "$text"; then
            continue
        fi
        n=$((n + 1))
        if [ "$n" -gt 10 ]; then
            emit 2 "$id" "$sev" "$f" "and more lines like these ($total in all)"
            break
        fi
        text="$(sed -e 's/^[[:space:]]*//' <<< "$text" | cut -c1-200)"
        emit 2 "$id" "$sev" "$f:$ln" "$text"
    done < <(grep -niE "$re" "$PROOT_ABS/$f" 2>/dev/null)
}
build_candidates() {  # <file>: build/test command lines that are not the project's own
    local f="$1" n=0 line ln text own hit
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        ln="${line%%:*}"
        text="${line#*:}"
        hit=0
        for own in "${OWN_CMDS[@]}"; do
            [[ "$text" == *"$own"* ]] && hit=1
        done
        [ "$hit" -eq 1 ] && continue
        n=$((n + 1))
        [ "$n" -gt 10 ] && { emit 2 process-build-command info "$f" "and more build or test command lines"; break; }
        text="$(sed -e 's/^[[:space:]]*//' <<< "$text" | cut -c1-200)"
        emit 2 process-build-command info "$f:$ln" "$text ($OWN_DESC)"
    # A command at the start of a line (after blanks, a list marker or a
    # "$ " prompt) or of a code span, so prose such as "make sure" is not one.
    done < <(grep -nE '(^[[:space:]]*([-*][[:space:]]+)?(\$[[:space:]]+)?|`)(make|cmake|cargo|npm|pnpm|yarn|go|pytest|python3? -m pytest|colcon|ctest|ninja|meson)([[:space:]`]|$)' "$PROOT_ABS/$f" 2>/dev/null)
}
for f in "${INSTR_FILES[@]}"; do
    candidate "$f" process-branch warn 'feature[- ]branch|git (checkout|switch) -[bc]|create (a )?(new )?branch' 'worktree'
    candidate "$f" process-issue warn '(if|when|where) (one|an issue|it|there is one) (exists|is open)|issue[^.]{0,40}(if|when) (one|available|applicable)'
    candidate "$f" process-signature info 'co-authored-by|signed-off-by|generated with|authored-by|signature'
    build_candidates "$f"
done

# ------------------------------------------------- 3. written files ----
if [ "$IS_GIT" -eq 1 ]; then
    WTDIR="$(registry_worktree_dir "$MAIN_ROOT" "$NAME" 2>/dev/null)" || WTDIR=""
    WTABS="$WTDIR"
    [ -d "$WTDIR" ] && WTABS="$(cd "$WTDIR" && pwd -P)"
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
                emit 3 work-plans-ignored warn ".agent/work-plans/" "records are committed in the project (location=project tracking=project) but an ignore rule hides them: $(g check-ignore -v -- "$WP_PROBE" 2>/dev/null | cut -f1)"
            fi ;;
        project/untracked)
            if [ "$WP_IGN" -eq 0 ]; then
                emit 3 work-plans-not-ignored warn ".agent/work-plans/" "records are kept untracked in the project (tracking=untracked), but no ignore rule covers .agent/work-plans/; it belongs in .git/info/exclude"
            fi ;;
    esac
    has_files() { [ -d "$1" ] && [ -n "$(find "$1" -type f -print -quit 2>/dev/null)" ]; }
    if has_files "$PROOT_ABS/docs/work-plans"; then
        emit 3 old-work-plans warn "docs/work-plans/" "the older records location; records now live under .agent/work-plans/issue-N/ (or where the records settings say)"
        if has_files "$PROOT_ABS/.agent/work-plans"; then
            emit 3 records-two-places warn "docs/work-plans/ and .agent/work-plans/" "records exist in two places; the records settings (location=$REC_LOC) name .agent/work-plans/ as the source of truth"
        fi
    fi
    if [ "$REC_LOC" = "outside" ] && has_files "$PROOT_ABS/.agent/work-plans"; then
        emit 3 records-two-places warn ".agent/work-plans/" "records exist in the project although the records settings say location=outside; the setting names the outside location as the source of truth"
    fi
fi

# ------------------------------------------------- 4. ignore rules -----
declare -A REPORTED=()
if [ "$IS_GIT" -eq 1 ]; then
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        case "$p" in .claude/settings.local.json) continue ;; esac
        rule="$(g check-ignore -v -- "$p" 2>/dev/null | cut -f1)"
        emit_offer 4 ignored-agent-file warn "$p" "present but ignored, so it is never committed and no other clone or worktree has it; the rule: ${rule:-unknown}"
        REPORTED["$p"]=1
    done < <(g ls-files --others --ignored --exclude-standard -- .claude .agents AGENTS.md CLAUDE.md 2>/dev/null)
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
    RULE_FILES=("${INSTR_FILES[@]}")
    for f in "$PROOT_ABS"/.claude/skills/*/SKILL.md "$PROOT_ABS"/.claude/commands/*.md; do
        [ -f "$f" ] && RULE_FILES+=("${f#"$PROOT_ABS"/}")
    done
    total=0
    where=()
    for f in "${RULE_FILES[@]}"; do
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
indent_out() { sed -e 's/^/  /'; }
_RC=0
VOUT="$("$MAIN_ROOT/.agent/scripts/registration_verify.sh" "$NAME" 2>&1)" || _RC=$?
while IFS= read -r line; do
    case "$line" in
        FAIL:*) emit 6 registration error "$NAME" "${line#FAIL: }" ;;
        WARN:*) emit 6 registration-note warn "$NAME" "${line#WARN: }" ;;
    esac
done <<< "$VOUT"
if [ "$_RC" -ne 0 ] && ! grep -q '^FAIL:' <<< "$VOUT"; then
    emit 6 registration error "$NAME" "registration_verify.sh exited $_RC: $(tail -n3 <<< "$VOUT")"
fi
_RC=0
UOUT="$("$MAIN_ROOT/.agent/scripts/user_tier_install.sh" --check --require 2>&1)" || _RC=$?
if [ "$_RC" -ne 0 ]; then
    emit 6 user-tier error "user tier" "user_tier_install.sh --check --require failed (exit $_RC), so a session at the root may not get the workspace plugin or scripts: $(grep -vE '^[[:space:]]*$' <<< "$UOUT" | head -n4)"
fi
if [ -n "$PROOT_ABS" ]; then
    _RC=0
    SOUT="$("$MAIN_ROOT/.agent/scripts/session_root.sh" --dir "$PROOT_ABS" 2>&1)" || _RC=$?
    _PROJ="$(sed -n 's/^project=//p' <<< "$SOUT")"
    if [ "$_RC" -ne 0 ] || [ "$_PROJ" != "$NAME" ]; then
        emit 6 session-root error "$PROOT_ABS" "a session started here does not resolve to '$NAME' (session_root.sh exit $_RC): $(head -n3 <<< "$SOUT")"
    fi
fi

# ------------------------------------------------------------ output ---
if [ "$FORMAT" = "tsv" ]; then
    printf '%s' "$FINDINGS"
    exit 0
fi

echo "Integration audit: $NAME ($TYPE) at $PROOT"
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
