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
#   find [path] [...]                    → Glob (any non-operational find,
#                                          including bare `find` which defaults to .)
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
# End-of-options (`--`) handling:
#   Flag heuristics scan only tokens before `--`. Tokens after `--` are
#   treated as positional args (files for cat/head/tail/sed, paths for find)
#   regardless of leading `-`. So `cat -- -file` blocks (file read);
#   `sed -- 's/x/y/' -input` falls through (no -i/-n flag before --);
#   `find -- -delete` blocks (`-delete` after `--` is a path, not the op flag).
#
# Side-effects: logs each block to ~/.claude/tool-mapping-blocks.jsonl so we
# can measure how often the hook fires.

set -u
LOG_FILE="${HOME:-/tmp}/.claude/tool-mapping-blocks.jsonl"

INPUT=$(cat)

# jq is required for input parsing; bail gracefully if absent
if ! command -v jq &>/dev/null; then
    exit 0
fi

TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""')
[[ "$TOOL" != "Bash" ]] && exit 0

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
[[ -z "$COMMAND" ]] && exit 0

# Strip quoted regions from a working copy of $COMMAND before the
# compound/redirect early-out so metachars inside quoted sed
# scripts/regexes (e.g. `sed -n '1p;2p' file`, `sed -n "s/<x>//p" file`)
# don't false-trigger an early-out.
#
# Single-quoted regions: always safe to strip (everything inside `'...'`
# is literal in bash).
#
# Double-quoted regions: stripped only when they don't contain `$(` or
# backticks. Inside `"..."` those constructs are still expanded by bash,
# so `"$(cmd)"` must remain visible to the compound check. Plain
# `"file>bar"` is safe to strip because `>`/`<`/`;` inside `"..."` are
# literal characters, not redirections.
COMPOUND_CHECK="$COMMAND"
while [[ "$COMPOUND_CHECK" == *\'*\'* ]]; do
    before="${COMPOUND_CHECK%%\'*}"
    after_first="${COMPOUND_CHECK#*\'}"
    after_second="${after_first#*\'}"
    COMPOUND_CHECK="${before}${after_second}"
done
# Strip "safe" double-quoted regions (no command substitution inside).
COMPOUND_TEMP="$COMPOUND_CHECK"
COMPOUND_CHECK=""
while [[ "$COMPOUND_TEMP" == *\"*\"* ]]; do
    before="${COMPOUND_TEMP%%\"*}"
    after_first="${COMPOUND_TEMP#*\"}"
    dq_content="${after_first%%\"*}"
    after_second="${after_first#*\"}"
    if [[ "$dq_content" == *\$\(* || "$dq_content" == *\`* ]]; then
        # Has command substitution — preserve so early-out can fire
        COMPOUND_CHECK+="${before}\"${dq_content}\""
    else
        COMPOUND_CHECK+="$before"
    fi
    COMPOUND_TEMP="$after_second"
done
COMPOUND_CHECK+="$COMPOUND_TEMP"

# Strip backslash-escape pairs from any remaining (unquoted) content.
# In bash, `\X` outside quotes is always a literal X — `cat file\>bar.txt`
# is `cat` reading one literal-named file, not a redirection. Without
# stripping, `\>` here would false-trigger the early-out below.
COMPOUND_TEMP="$COMPOUND_CHECK"
COMPOUND_CHECK=""
i=0
n=${#COMPOUND_TEMP}
while (( i < n )); do
    ch="${COMPOUND_TEMP:$i:1}"
    if [[ "$ch" == '\' ]]; then
        i=$((i + 2))   # Skip backslash + the escaped char
        continue
    fi
    COMPOUND_CHECK+="$ch"
    i=$((i + 1))
done

# Early-out: any compound/redirect/subshell construct → allow
case "$COMPOUND_CHECK" in
    *\|*|*\>*|*\<*|*\&\&*|*\;*|*\$\(*|*\`*) exit 0 ;;
esac

# Tokenize on whitespace; quoting is approximate (good enough for flag detection)
read -ra TOKENS <<< "$COMMAND"
HEAD="${TOKENS[0]:-}"

case "$HEAD" in
    cat|head|tail|find|sed) ;;
    *) exit 0 ;;
esac

# Split args at the first `--` end-of-options marker.
# FLAG_ARGS: tokens before `--`, scanned by flag heuristics.
# POS_ARGS:  tokens after `--`, always treated as positional (file/path) args
#            even if they start with `-`. When `--` is absent, FLAG_ARGS holds
#            everything past the command name and POS_ARGS is empty.
FLAG_ARGS=()
POS_ARGS=()
saw_dashdash=0
for tok in "${TOKENS[@]:1}"; do
    if [[ "$saw_dashdash" -eq 0 && "$tok" == "--" ]]; then
        saw_dashdash=1
        continue
    fi
    if [[ "$saw_dashdash" -eq 1 ]]; then
        POS_ARGS+=("$tok")
    else
        FLAG_ARGS+=("$tok")
    fi
done

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

    # Log the block (best-effort; never fail the hook). Logging-dir setup
    # is deferred to here so it only runs when we're actually about to
    # write — allowed Bash calls and non-Bash tool calls never touch
    # ~/.claude/.
    {
        umask 077
        mkdir -p "$(dirname "$LOG_FILE")"
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
        for tok in "${FLAG_ARGS[@]}"; do
            [[ "$tok" != -* ]] && \
                emit_block "cat <file> blocked." "Use the Read tool instead."
        done
        # Anything after `--` is a positional file arg, even if it starts with `-`.
        if [[ "${#POS_ARGS[@]}" -gt 0 ]]; then
            emit_block "cat <file> blocked." "Use the Read tool instead."
        fi
        ;;

    head|tail)
        # Allow byte mode (-c) and follow mode (-f/-F for tail). Mode flags
        # only count before `--`.
        for tok in "${FLAG_ARGS[@]}"; do
            case "$tok" in
                -c|-c[0-9]*|--bytes|--bytes=*) exit 0 ;;
            esac
            if [[ "$HEAD" == tail ]]; then
                case "$tok" in
                    -f|-F|--follow|--follow=*|--retry) exit 0 ;;
                esac
            fi
        done
        # Block if any non-flag arg follows (i.e., a file). A bare numeric
        # token is only a count when it follows -n / --lines / -c / --bytes;
        # otherwise coreutils treats it as a filename (`head 123` reads file
        # `123`). The legacy `-N` count form (e.g. `head -5 file`) starts
        # with `-` and is already skipped by the non-flag test.
        prev=""
        for tok in "${FLAG_ARGS[@]}"; do
            if [[ "$tok" =~ ^[0-9]+$ ]]; then
                case "$prev" in
                    -n|--lines|-c|--bytes)
                        prev="$tok"
                        continue
                        ;;
                esac
            fi
            if [[ "$tok" != -* ]]; then
                emit_block "$HEAD <file> blocked." \
                    "Use the Read tool instead (limit/offset for partial reads)."
            fi
            prev="$tok"
        done
        # Anything after `--` is a positional file arg.
        if [[ "${#POS_ARGS[@]}" -gt 0 ]]; then
            emit_block "$HEAD <file> blocked." \
                "Use the Read tool instead (limit/offset for partial reads)."
        fi
        ;;

    find)
        # Allow operational find (commands that do more than enumerate files)
        # and informational flags (`--help`, `--version`). Operational
        # predicates only count before `--`; after `--` they're paths.
        for tok in "${FLAG_ARGS[@]}"; do
            case "$tok" in
                --help|--version|-help|-version|--usage)
                    exit 0
                    ;;
                -exec|-execdir|-ok|-okdir|-delete|-mtime|-mmin|-cmin|-amin| \
                -size|-newer|-newer*|-prune|-print0|-fls|-ls|-fprint|-fprint0| \
                -inum|-empty|-perm|-user|-group|-uid|-gid|-quit)
                    exit 0
                    ;;
            esac
        done
        # Anything else (bare `find PATH`, `find . -name ...`, `find . -type f`,
        # `find -- -delete` where -delete is now a path) is enumeration → Glob.
        emit_block "find for file enumeration blocked." \
            "Use the Glob tool instead."
        ;;

    sed)
        # Block in-place edit (any -i form, including combined short-flag
        # clusters). Flag heuristics only consider tokens before `--`.
        if has_sed_inplace "${FLAG_ARGS[@]}"; then
            emit_block "sed -i (in-place edit) blocked." \
                "Use the Edit tool instead."
        fi
        # Block -n print-mode (sed -n 'SCRIPT' FILE). Count positional args
        # across both halves: non-flag tokens before `--` + every token after
        # `--`. Script + file = 2 positional → block. Script alone means
        # stdin (would have a pipe → already early-outed).
        if has_short_flag_letter n "${FLAG_ARGS[@]}"; then
            non_flag_count=$(count_non_flag_args "${FLAG_ARGS[@]}")
            total_positional=$((non_flag_count + ${#POS_ARGS[@]}))
            if [[ "$total_positional" -ge 2 ]]; then
                emit_block "sed -n 'SCRIPT' <file> blocked." \
                    "Use the Read tool with offset/limit (or Grep for /regex/)."
            fi
        fi
        # Plain sed without -i/-n falls through (stream substitution stage).
        # Note: `sed -- 's/x/y/' -input` falls through here even though `-input`
        # looks flag-like — that's correct: no -i/-n present.
        ;;
esac

exit 0
