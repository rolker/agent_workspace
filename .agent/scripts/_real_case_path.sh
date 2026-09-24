#!/bin/bash
# _real_case_path.sh — resolve the on-disk spelling of an existing path.
#
# Source this file; it defines one function:
#
#   real_case_relpath <base> <rel>
#       Prints <rel> with each component replaced by the name the directory
#       actually holds. On a case-sensitive filesystem an existing path
#       already is its own spelling and comes back unchanged. On a
#       case-insensitive one (macOS default) `docs/principles.md` also opens
#       a file stored as `docs/PRINCIPLES.md`; this prints the stored name,
#       so callers report — and write back to — the file under the name its
#       owner gave it, whichever candidate spelling found it (issue #334).
#
#       Resolution per component: the exact spelling if the directory lists
#       it, else the listed entry that differs only in case. A component
#       with no match (the path does not exist) is kept as given, as is
#       everything after it. Only components below <base> are resolved.
#
# Bash 3.2 compatible (macOS /bin/bash): nocasematch, not ${x,,}. Runs in a
# subshell so the caller's shopt state is untouched.

real_case_relpath() {
    local base="$1" rel="$2"
    (
        shopt -s nullglob
        shopt -u nocasematch
        cur="$base"
        out=""
        resolved=true
        IFS='/' read -r -a comps <<< "$rel"
        for comp in "${comps[@]+"${comps[@]}"}"; do
            [[ -z "$comp" ]] && continue
            name="$comp"
            if $resolved; then
                entries=()
                for entry in "$cur"/* "$cur"/.[!.]* "$cur"/..?*; do
                    entries+=("${entry##*/}")
                done
                match=""
                # Exact spelling first (case-sensitive compare) ...
                for entry in "${entries[@]+"${entries[@]}"}"; do
                    [[ "$entry" == "$comp" ]] && { match="$entry"; break; }
                done
                # ... else the entry that differs only in case.
                if [[ -z "$match" ]]; then
                    shopt -s nocasematch
                    for entry in "${entries[@]+"${entries[@]}"}"; do
                        [[ "$entry" == "$comp" ]] && { match="$entry"; break; }
                    done
                    shopt -u nocasematch
                fi
                if [[ -n "$match" ]]; then
                    name="$match"
                else
                    resolved=false
                fi
            fi
            out="${out:+$out/}$name"
            cur="$cur/$name"
        done
        printf '%s\n' "$out"
    )
}
