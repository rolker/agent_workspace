#!/bin/bash
# .agent/scripts/_settings.sh
# Machine-local settings reader (issue #386).
#
# The settings file is .agent/settings.local (git-ignored; template at
# .agent/settings.local.example). It holds `key=value` lines, one per line;
# `#` lines and anything that is not `key=value` are ignored. Keys in use:
#   inbox       the file capture.sh appends one-line thoughts to
#   run_record  the file the sit-rep skill appends one dated line per run to
#
# The file is READ, never sourced: a value such as `$(cmd)` is returned as
# text and never executed.
#
# Rules:
#   - first match of a key wins;
#   - a trailing CR and trailing spaces are stripped (CRLF files work);
#   - a value starting with `~/` has that prefix replaced by $HOME/;
#   - an empty value counts as absent.
#
# Which file is read (settings_candidates prints them in this order):
#   1. $AGENT_SETTINGS_FILE when set (tests); nothing else is consulted;
#   2. <root>/.agent/settings.local;
#   3. when <root> is a linked git worktree, the same path under the main
#      checkout (the parent of git's common dir), so a worktree copy of a
#      script sees the machine's settings.
# The first that exists is used.
#
# Source this file from other scripts:
#   source "$SCRIPT_DIR/_settings.sh"
# user-tier: inert -- this file only defines functions; it performs no
# repo-affecting action.

# Print the candidate settings files for <root>, one per line, in lookup order.
# Usage: settings_candidates "$root"
settings_candidates() {
    local root="$1" gitdir common main
    if [ -n "${AGENT_SETTINGS_FILE:-}" ]; then
        printf '%s\n' "$AGENT_SETTINGS_FILE"
        return 0
    fi
    printf '%s\n' "$root/.agent/settings.local"
    gitdir="$(cd "$root" 2>/dev/null && cd "$(git rev-parse --git-dir 2>/dev/null)" 2>/dev/null && pwd -P)" || return 0
    common="$(cd "$root" 2>/dev/null && cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd -P)" || return 0
    if [ -n "$gitdir" ] && [ -n "$common" ] && [ "$gitdir" != "$common" ]; then
        main="$(dirname "$common")"
        printf '%s\n' "$main/.agent/settings.local"
    fi
    return 0
}

# Print the settings file in use for <root>. Return 1 (no output) if none exists.
# Usage: file=$(settings_file "$root")
settings_file() {
    local f
    while IFS= read -r f; do
        if [ -f "$f" ]; then
            printf '%s\n' "$f"
            return 0
        fi
    done < <(settings_candidates "$1")
    return 1
}

# Print the value of <key>. Return 1 (no output) when the file or the key
# is absent or the value is empty.
# Usage: v=$(settings_get "$root" inbox)
settings_get() {
    local root="$1" key="$2" file line value
    [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || return 1
    file="$(settings_file "$root")" || return 1
    line="$(grep -m1 -E "^[[:space:]]*${key}[[:space:]]*=" "$file" 2>/dev/null)" || return 1
    value="${line#*=}"
    value="${value%$'\r'}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    [ -n "$value" ] || return 1
    # shellcheck disable=SC2088  # a literal "~/" prefix is what we look for
    if [[ "$value" == "~/"* ]]; then
        value="$HOME/${value#\~/}"
    fi
    printf '%s\n' "$value"
}

# Like settings_get, for a key that names a file: a relative value resolves
# against the directory of the settings file that supplied it (never the
# caller's cwd, so lines cannot scatter across directories).
# Usage: p=$(settings_path "$root" inbox)
settings_path() {
    local root="$1" key="$2" value file
    value="$(settings_get "$root" "$key")" || return 1
    if [[ "$value" != /* ]]; then
        file="$(settings_file "$root")" || return 1
        value="$(dirname "$file")/$value"
    fi
    printf '%s\n' "$value"
}
