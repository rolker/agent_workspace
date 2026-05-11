#!/bin/bash
# Block Bash patterns that should use dedicated tools per CLAUDE.md tool mapping.
#
# Configured as a PreToolUse hook. Blocks the call (exit 2 + stderr message)
# when the agent reaches for cat/head/tail/find/sed against a file in a
# context where Read/Glob/Edit would do the same job. Pipes, redirects,
# heredocs, and special-mode flags pass through.
#
# Patterns blocked:
#   cat <file> ...                       → Read
#   head [-n] N <file>                   → Read with limit
#   tail [-n] N <file>                   → Read with offset
#   find <path> [...]                    → Glob (any non-operational find)
#   sed -n 'SCRIPT' <file>               → Read with offset/limit (or Grep)
#   sed -i ... <file>                    → Edit
#                                          (incl. combined-cluster forms: -ni, -in, --in-place)
#
# Pass-through (early-out):
#   anything containing | > < << <<< >> && || ; $( ` (compound/redirect/subshell)
#   head -c ... / head -c                (byte mode)
#   tail -c ... / tail -f / tail -F      (byte/follow modes)
#   find ... -exec/-execdir/-delete/-mtime/-mmin/-cmin/-amin/-size/-newer/-prune/-print0/-fls/-ls
#                                        (operational find)
#   sed without -i and without -n        (stream substitution stage)
#   anything not starting with cat/head/tail/find/sed
#
# Side-effects: logs each block to ~/.claude/tool-mapping-blocks.jsonl so we
# can measure how often the hook fires.

set -u
LOG_FILE="${HOME}/.claude/tool-mapping-blocks.jsonl"
umask 077
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

INPUT=$(cat)

# jq is required for input parsing; bail gracefully if absent
if ! command -v jq &>/dev/null; then
    exit 0
fi

TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""')
[[ "$TOOL" != "Bash" ]] && exit 0

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
[[ -z "$COMMAND" ]] && exit 0

# Early-out: any compound/redirect/subshell construct → allow
case "$COMMAND" in
    *\|*|*\>*|*\<*|*\&\&*|*\;*|*\$\(*|*\`*) exit 0 ;;
esac

# Tokenize on whitespace; quoting is approximate (good enough for flag detection)
read -ra TOKENS <<< "$COMMAND"
HEAD="${TOKENS[0]:-}"

case "$HEAD" in
    cat|head|tail|find|sed) ;;
    *) exit 0 ;;
esac

# ---- helpers ----------------------------------------------------------------

emit_block() {
    # $1 = headline ; $2 = suggestion
    cat >&2 <<EOF
[tool-mapping] $1
$2

CLAUDE.md tool mapping:
  cat / head / tail <file>  → Read
  find PATH [...]           → Glob
  sed -n 'SCRIPT' <file>    → Read (with offset/limit) or Grep
  sed -i ... <file>         → Edit

Pipes, redirects, heredocs, and operational flags (head -c, tail -f,
find -exec/-delete/-mtime, etc.) pass through. To bypass intentionally,
add a pipe or redirect — or just use the dedicated tool.
EOF

    # Log the block (best-effort; never fail the hook)
    {
        jq -n -c \
            --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            --arg head "$HEAD" \
            --arg cmd "$COMMAND" \
            --arg reason "$1" \
            '{ts:$ts, head:$head, command:$cmd, reason:$reason}' \
            >> "$LOG_FILE"
    } 2>/dev/null || true

    exit 2
}

has_short_flag_letter() {
    # Returns 0 if any single-dash short-flag cluster contains $1.
    # Examples for letter 'n': -n, -ne, -ni, -nE all match. --inplace does not.
    local letter="$1"; shift
    local t
    for t in "$@"; do
        case "$t" in
            --*) ;;
            -*"$letter"*) return 0 ;;
        esac
    done
    return 1
}

has_sed_inplace() {
    # sed's in-place flag: -i, -i.bak, -iEXT, combined-cluster forms (-ni, -in, -niE),
    # and long form --in-place / --in-place=EXT.
    local t
    for t in "$@"; do
        case "$t" in
            --in-place|--in-place=*) return 0 ;;
            --*) ;;
            -*i*) return 0 ;;
        esac
    done
    return 1
}

count_non_flag_args() {
    # Counts tokens that don't start with '-'. Used to detect "script + file"
    # in `sed -n SCRIPT FILE` (two non-flag tokens past `sed`).
    local count=0 t
    for t in "$@"; do
        [[ "$t" != -* ]] && count=$((count + 1))
    done
    echo "$count"
}

# ---- per-command rules ------------------------------------------------------

case "$HEAD" in
    cat)
        # Block if any non-flag arg follows; cat can be used to emit a literal
        # without args (cat with stdin would pipe — already early-outed).
        for tok in "${TOKENS[@]:1}"; do
            [[ "$tok" != -* ]] && \
                emit_block "cat <file> blocked." "Use the Read tool instead."
        done
        ;;

    head|tail)
        # Allow byte mode (-c) and follow mode (-f/-F for tail)
        for tok in "${TOKENS[@]:1}"; do
            case "$tok" in
                -c|-c[0-9]*|--bytes|--bytes=*) exit 0 ;;
            esac
            if [[ "$HEAD" == tail ]]; then
                case "$tok" in
                    -f|-F|--follow|--follow=*|--retry) exit 0 ;;
                esac
            fi
        done
        # Block if any non-flag, non-numeric arg follows (i.e., a file)
        for tok in "${TOKENS[@]:1}"; do
            if [[ "$tok" != -* && ! "$tok" =~ ^[0-9]+$ ]]; then
                emit_block "$HEAD <file> blocked." \
                    "Use the Read tool instead (limit/offset for partial reads)."
            fi
        done
        ;;

    find)
        # Allow operational find (commands that do more than enumerate files)
        for tok in "${TOKENS[@]:1}"; do
            case "$tok" in
                -exec|-execdir|-ok|-okdir|-delete|-mtime|-mmin|-cmin|-amin| \
                -size|-newer|-newer*|-prune|-print0|-fls|-ls|-fprint|-fprint0| \
                -inum|-empty|-perm|-user|-group|-uid|-gid|-quit)
                    exit 0
                    ;;
            esac
        done
        # Anything else (bare `find PATH`, `find . -name ...`, `find . -type f`)
        # is filesystem enumeration → Glob.
        emit_block "find for file enumeration blocked." \
            "Use the Glob tool instead."
        ;;

    sed)
        # Block in-place edit (any -i form, including combined short-flag clusters)
        if has_sed_inplace "${TOKENS[@]:1}"; then
            emit_block "sed -i (in-place edit) blocked." \
                "Use the Edit tool instead."
        fi
        # Block -n print-mode (sed -n 'SCRIPT' FILE) by counting non-flag tokens
        # past sed. Script + file = 2 non-flag tokens; script alone (1) means
        # stdin (which would have a pipe → already early-outed) and we allow.
        # Combined-cluster forms like `sed -ne SCRIPT FILE` are caught because
        # the cluster matches has_short_flag_letter 'n' and SCRIPT/FILE both
        # don't start with '-'.
        if has_short_flag_letter n "${TOKENS[@]:1}"; then
            if [[ "$(count_non_flag_args "${TOKENS[@]:1}")" -ge 2 ]]; then
                emit_block "sed -n 'SCRIPT' <file> blocked." \
                    "Use the Read tool with offset/limit (or Grep for /regex/)."
            fi
        fi
        # Plain sed without -i/-n falls through (often a stream substitution stage)
        ;;
esac

exit 0
