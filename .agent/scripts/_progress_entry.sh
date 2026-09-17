#!/bin/bash
# .agent/scripts/_progress_entry.sh
# Shared validation for ONE progress.md entry (ADR-0013). Sourced by every
# writer — progress_append.sh and review_progress.sh's compatibility path —
# so the guards live in exactly one place (issue #269 PR B review: the
# compatibility path had re-implemented file creation without them).
#
#   source "$SCRIPT_DIR/_progress_entry.sh"
#
# progress_entry_validate <entry> [<title>]
#   Echoes the trimmed entry type on stdout and returns 0 when:
#     - the first non-blank line is an ADR-0013 "## <Entry Type>" heading
#     - the type is on the writable whitelist (External Review excluded)
#     - no further top-level "## " line exists outside a code fence
#     - every ``` / ~~~ fence is closed (an open fence hides later entries
#       from every reader)
#     - <title>, if given, is a single line (it lands on the file's
#       "# Issue #N — <title>" line, where a newline would forge entries)
#   Otherwise prints the reason to stderr and returns 2.
#
# progress_entry_is_tail <file> <entry>
#   Returns 0 when <file> already ends with exactly <entry> — the
#   append-succeeded-but-commit-failed replay case — so a writer can skip
#   the re-append and just re-attempt the commit (idempotency guard).

PROGRESS_WRITABLE_TYPES=(
    "Issue Review"
    "Plan Authored"
    "Plan Review"
    "Local Review"
    "Local Review (Pre-Push)"
    "Integrated Review"
    "Implementation"
    "Checkpoint"
    "Merge (report-only)"
    "Merge (unreviewed)"
)

progress_entry_validate() {
    local entry="${1:-}" title="${2:-}" first type extra t ok=0
    first=$(printf '%s\n' "$entry" | sed -n '/[^[:space:]]/{p;q;}')
    if [[ -z "$first" ]]; then
        echo "error: empty entry on stdin" >&2; return 2
    fi
    if [[ ! "$first" =~ ^##\ [A-Za-z] ]]; then
        echo "error: entry must start with an ADR-0013 '## <Entry Type>' heading (got: $first)" >&2; return 2
    fi
    type="${first#\#\# }"
    # Trim a trailing whitespace run (CR from CRLF, padding) so it cannot
    # leak into a commit subject.
    type="${type%"${type##*[![:space:]]}"}"
    for t in "${PROGRESS_WRITABLE_TYPES[@]}"; do
        [[ "$type" == "$t" ]] && { ok=1; break; }
    done
    if [[ "$ok" -ne 1 ]]; then
        echo "error: '$type' is not a writable ADR-0013 entry type." >&2
        { printf '       allowed:'; printf ' "%s";' "${PROGRESS_WRITABLE_TYPES[@]}"; printf '\n'; } >&2
        return 2
    fi
    # Exactly one entry per call: a second top-level heading outside a fence
    # would be appended verbatim and parsed as a separate, unvalidated entry.
    extra=$(printf '%s\n' "$entry" | awk '
        /^[ \t]*(```|~~~)/ { fence = !fence; next }
        fence { next }
        /^## / { n++; if (n > 1) print }
    ')
    if [[ -n "$extra" ]]; then
        echo "error: entry contains more than one top-level '## ' heading; one entry per call." >&2
        echo "       extra heading(s): $(printf '%s' "$extra" | tr '\n' '|')" >&2
        return 2
    fi
    if ! printf '%s\n' "$entry" | awk '
        /^[ \t]*(```|~~~)/ { fence = !fence }
        END { exit fence ? 1 : 0 }
    '; then
        echo "error: entry has an unterminated code fence (\`\`\` or ~~~); it would hide every later entry from readers" >&2
        return 2
    fi
    if [[ "$title" == *$'\n'* || "$title" == *$'\r'* ]]; then
        echo "error: --title must be a single line (contains a newline)" >&2
        return 2
    fi
    printf '%s\n' "$type"
    return 0
}

progress_entry_is_tail() {
    local file="${1:-}" entry="${2:-}" current
    [[ -f "$file" ]] || return 1
    current=$(cat "$file")   # $(…) strips trailing newlines: ends at the last non-blank line
    [[ "$current" == *$'\n'"$entry" ]]
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ERROR: _progress_entry.sh must be sourced, not executed directly." >&2
    exit 1
fi
