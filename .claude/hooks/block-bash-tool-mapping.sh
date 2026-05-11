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
#   tail [-n] N <file>                   → Read (tail-relative not supported; use Read with offset)
#   find <path> [-name|-iname|-type|-path] ...
#                                        → Glob
#   sed -n 'EXPR' <file>                 → Read with offset/limit (or Grep for /regex/)
#   sed -i ... <file>                    → Edit
#
# Pass-through (early-out):
#   anything containing | > < << <<< >> && || ; $( ` (compound/redirect/subshell)
#   head -c ... / head -c                (byte mode)
#   tail -c ... / tail -f / tail -F      (byte/follow modes)
#   find ... -exec/-execdir/-delete/-mtime/-mmin/-cmin/-amin/-size/-newer/-prune/-print0/-fls/-ls
#                                        (operational find)
#   sed without -i and without -n        (often a stream substitution stage; ambiguous)
#   anything not starting with cat/head/tail/find/sed
#
# Side-effects: logs each block to ~/.claude/tool-mapping-blocks.jsonl so we
# can measure how often the hook fires.

set -u
LOG_FILE="${HOME}/.claude/tool-mapping-blocks.jsonl"
umask 077

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
  find PATH [-name PAT]     → Glob
  sed -n 'EXPR' <file>      → Read (with offset/limit) or Grep
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

has_exact_flag() {
    # $1 = exact-match flag (e.g. -n); rest = tokens
    local flag="$1"; shift
    local t
    for t in "$@"; do
        [[ "$t" == "$flag" ]] && return 0
    done
    return 1
}

has_sed_inplace() {
    # sed's in-place flag forms: -i, -i.bak, -iEXT, --in-place, --in-place=EXT
    local t
    for t in "$@"; do
        case "$t" in
            -i|-i.*|-i[!-]*|--in-place|--in-place=*) return 0 ;;
        esac
    done
    return 1
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
        # Allow operational find
        for tok in "${TOKENS[@]:1}"; do
            case "$tok" in
                -exec|-execdir|-ok|-okdir|-delete|-mtime|-mmin|-cmin|-amin| \
                -size|-newer|-newer*|-prune|-print0|-fls|-ls|-fprint|-fprint0| \
                -inum|-empty|-perm|-user|-group|-uid|-gid|-quit)
                    exit 0
                    ;;
            esac
        done
        # Anything else (typical: find . -name '*.ts' or find . -type f -name *.md)
        emit_block "find for file search blocked." \
            "Use the Glob tool instead."
        ;;

    sed)
        # Block in-place edit (any -i / -i.bak / --in-place form)
        if has_sed_inplace "${TOKENS[@]:1}"; then
            emit_block "sed -i (in-place edit) blocked." \
                "Use the Edit tool instead."
        fi
        # Block -n print-mode (sed -n 'EXPR' file) when a file arg is present
        if has_exact_flag -n "${TOKENS[@]:1}"; then
            # Find the last non-flag, non-quoted-script token; if it's a file path, block
            LAST="${TOKENS[-1]:-}"
            # Heuristic: a "file" looks like a path/identifier without sed metachars
            if [[ -n "$LAST" && "$LAST" != -* ]] && \
               ! [[ "$LAST" =~ [pPdDsSyYqQ\;\{\}] ]] && \
               ! [[ "$LAST" =~ ^[\'\"] ]]; then
                emit_block "sed -n 'EXPR' <file> blocked." \
                    "Use the Read tool with offset/limit (or Grep for /regex/)."
            fi
        fi
        # Plain sed without -i/-n falls through (often a stream substitution stage)
        ;;
esac

exit 0
