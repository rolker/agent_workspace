#!/usr/bin/env bash
# check_design_anchors.sh -- every cited docs/design.md section anchor must
# resolve to a heading in docs/design.md (issue #335, plan Wire-in 6).
#
# Purpose: renaming or dropping a design section must not silently break the
# skills, README, roadmap and knowledge files that cite it by anchor. This is
# a grep/awk check, cheap enough to run on every docs commit through the
# `check-design-anchors` pre-commit hook (also run by `make lint` and CI).
#
# Usage: check_design_anchors.sh [<root>]
#   <root> is the repository root to check. Order of precedence: the argument,
#   then $DESIGN_ANCHORS_ROOT, then the repository this script lives in
#   (<root>/.agent/scripts/check_design_anchors.sh). The test suite passes a
#   fixture root.
#
# Citation forms (one form each way):
#   * From outside design.md: `docs/design.md#<fragment>`; any prefix counts,
#     so `$WS_ROOT/docs/design.md#<fragment>` is a citation. The fragment is
#     the run of [A-Za-z0-9_-] after the '#'.
#       - an empty run (the literal `docs/design.md#<section>` placeholder) is
#         not a citation and is ignored;
#       - any other fragment must match [a-z0-9][a-z0-9-]*, otherwise it is a
#         malformed-anchor error (so `#How-it-works` and `#how_it_works` fail
#         instead of slipping past a lowercase-only match);
#       - a fragment that matches is looked up among the heading slugs.
#   * Inside design.md: a Markdown link `](#<fragment>)` outside fenced code.
#     The fragment is everything up to the ')'. Ignored: an all-digit fragment
#     (an issue reference such as `[x](#12)`; a bare `(#295)` has no `](` and is
#     never seen) and a fragment containing '<' (a `#<slug>` placeholder).
#     Anything else must match the lowercase pattern above and resolve.
#
# Heading slugs (the one place the rule lives is the awk function slug()):
# GitHub style. Take the ATX heading text (`#` to `######`, up to 3 leading
# spaces, optional closing #s dropped); replace `[text](url)` by `text`;
# lowercase ASCII; drop every character that is not a letter, digit, space,
# '_' or '-'; turn each space into '-'. A repeated slug gets '-1', '-2', ...
# (`# How it works` is `how-it-works`). Headings inside fenced code are not
# headings. Setext (underlined) headings are not recognised. Non-ASCII
# characters are dropped, which can differ from GitHub, but no anchor with
# such a character can match the citation pattern anyway.
#
# Scope: every citation in README.md, .agent/AGENT_ONBOARDING.md,
# .claude/skills/*/SKILL.md, .agent/knowledge/*.md and docs/roadmap.md (those
# that exist), plus every in-file link in docs/design.md. Citations in fenced
# code of the citing files still count.
#
# Anti-vacuity guards, conditional on the register: the register section is
# the heading whose slug is `decision-register`. While docs/design.md has no
# such heading, only the resolve check above runs. Once the heading exists
# AND <root>/docs/decisions/ exists, two guards are live:
#   (a) docs/design.md holds at least one `](#` in-file link (outside fences);
#   (b) the register holds at least as many anchored rows as there are
#       docs/decisions/*.md files. A row is a line that begins with '|' (after
#       optional spaces) and contains `](#`, between the register heading and
#       the next heading of the same or higher level, outside fences.
# A register row for an ADR with no carrying section links to
# `#decision-register`, which resolves like any other heading.
#
# Output: each finding as `file:line: message` on stdout, with file relative
# to the root.
# Exit codes:
#   0  no findings
#   1  one or more findings
#   2  usage error, root is not a directory, or <root>/docs/design.md missing

set -uo pipefail
LC_ALL=C
export LC_ALL

usage() {
    echo "usage: check_design_anchors.sh [<root>]" >&2
    echo "  <root> defaults to \$DESIGN_ANCHORS_ROOT, then to this script's repository" >&2
}

case "${1:-}" in
    -h|--help) usage; exit 0 ;;
esac
if [[ $# -gt 1 ]]; then
    usage
    exit 2
fi

if [[ $# -eq 1 ]]; then
    ROOT="$1"
elif [[ -n "${DESIGN_ANCHORS_ROOT:-}" ]]; then
    ROOT="$DESIGN_ANCHORS_ROOT"
else
    ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

if [[ ! -d "$ROOT" ]]; then
    echo "error: root is not a directory: $ROOT" >&2
    exit 2
fi
cd "$ROOT" || exit 2

DESIGN="docs/design.md"
if [[ ! -f "$DESIGN" ]]; then
    echo "error: $DESIGN not found under $ROOT" >&2
    exit 2
fi

ANCHOR_RE='^[a-z0-9][a-z0-9-]*$'
FINDINGS=0

finding() {  # <file> <line> <message>
    printf '%s:%s: %s\n' "$1" "$2" "$3"
    FINDINGS=$((FINDINGS + 1))
}

# One pass over design.md. Emits tab-separated records:
#   HEAD <line> <level> <slug>   every heading outside fenced code
#   LINK <line> <fragment>       every `](#fragment)` outside fenced code
#   ROW  <line>                  every anchored table row inside the register
# slug() is the single definition of the slug rule (see the header).
design_records() {
    awk '
    function slug(text,    s) {
        s = text
        sub(/[ \t]+#+[ \t]*$/, "", s)          # closing #s
        sub(/[ \t]+$/, "", s)
        while (match(s, /\[[^]]*\]\([^)]*\)/)) { # [text](url) -> text
            s = substr(s, 1, RSTART - 1) \
                substr(s, RSTART + 1, index(substr(s, RSTART), "](") - 2) \
                substr(s, RSTART + RLENGTH)
        }
        s = tolower(s)
        gsub(/[^a-z0-9 _-]/, "", s)
        gsub(/ /, "-", s)
        return s
    }
    BEGIN { fence = ""; reg_level = 0; OFS = "\t" }
    {
        line = $0
        # fenced code: ``` or ~~~ (3+), closed by the same char, at least as long
        if (match(line, /^ *(```+|~~~+)/)) {
            m = substr(line, 1, RLENGTH); gsub(/ /, "", m)
            ch = substr(m, 1, 1); n = length(m)
            if (fence == "") { fence = ch; fence_len = n; next }
            if (ch == fence && n >= fence_len) { fence = ""; next }
        }
        if (fence != "") next

        if (match(line, /^ *#+/)) {
            lead = index(substr(line, 1, RLENGTH), "#") - 1
            level = RLENGTH - lead
            rest = substr(line, RLENGTH + 1)
            if (lead <= 3 && level <= 6 && (rest == "" || rest ~ /^[ \t]/)) {
                sub(/^[ \t]+/, "", rest)
                if (rest != "") {
                    sl = slug(rest)
                    seen[sl]++
                    if (seen[sl] > 1) sl = sl "-" (seen[sl] - 1)
                    print "HEAD", NR, level, sl
                    if (reg_level > 0 && level <= reg_level) reg_level = 0
                    if (sl == "decision-register") reg_level = level
                    next
                }
            }
        }

        rest = line
        has_link = 0
        while (match(rest, /\]\(#[^)]*\)/)) {
            frag = substr(rest, RSTART + 3, RLENGTH - 4)
            print "LINK", NR, frag
            has_link = 1
            rest = substr(rest, RSTART + RLENGTH)
        }
        if (has_link && reg_level > 0 && line ~ /^ *\|/) print "ROW", NR
    }
    ' "$DESIGN"
}

declare -A SLUGS=()
declare -a LINKS=()
REG_LINE=""
ROWS=0
LINK_COUNT=0
while IFS=$'\t' read -r kind a b c; do
    case "$kind" in
        HEAD)
            SLUGS["$c"]=1
            if [[ "$c" == "decision-register" ]]; then REG_LINE="$a"; fi
            ;;
        LINK)
            LINKS+=("$a"$'\t'"$b")
            LINK_COUNT=$((LINK_COUNT + 1))
            ;;
        ROW)
            ROWS=$((ROWS + 1))
            ;;
    esac
done < <(design_records)

# check_fragment <file> <line> <fragment> -- resolve or report one citation.
check_fragment() {
    local file="$1" line="$2" frag="$3"
    if [[ ! "$frag" =~ $ANCHOR_RE ]]; then
        finding "$file" "$line" "malformed anchor '#$frag' (must match [a-z0-9][a-z0-9-]*)"
    elif [[ -z "${SLUGS[$frag]+x}" ]]; then
        finding "$file" "$line" "broken anchor '#$frag' (no such heading in $DESIGN)"
    fi
}

# In-file links in design.md.
for rec in "${LINKS[@]}"; do
    line="${rec%%$'\t'*}"
    frag="${rec#*$'\t'}"
    if [[ -z "$frag" || "$frag" =~ ^[0-9]+$ || "$frag" == *'<'* ]]; then
        continue
    fi
    check_fragment "$DESIGN" "$line" "$frag"
done

# Citations from outside design.md.
shopt -s nullglob
CITERS=()
for f in README.md .agent/AGENT_ONBOARDING.md docs/roadmap.md \
         .claude/skills/*/SKILL.md .agent/knowledge/*.md; do
    [[ -f "$f" ]] && CITERS+=("$f")
done
shopt -u nullglob

if [[ ${#CITERS[@]} -gt 0 ]]; then
    while IFS=: read -r file line match; do
        frag="${match#*design.md#}"
        [[ -z "$frag" ]] && continue
        check_fragment "$file" "$line" "$frag"
    done < <(grep -HnoE -- 'docs/design\.md#[A-Za-z0-9_-]*' "${CITERS[@]}" 2>/dev/null)
fi

# Anti-vacuity guards, live only once the register heading exists and
# docs/decisions/ exists.
if [[ -n "$REG_LINE" && -d docs/decisions ]]; then
    shopt -s nullglob
    ADRS=(docs/decisions/*.md)
    shopt -u nullglob
    if [[ $LINK_COUNT -eq 0 ]]; then
        finding "$DESIGN" "$REG_LINE" "the decision register exists but $DESIGN holds no in-file '](#' link"
    fi
    if [[ $ROWS -lt ${#ADRS[@]} ]]; then
        finding "$DESIGN" "$REG_LINE" "decision register has $ROWS anchored rows, fewer than the ${#ADRS[@]} files in docs/decisions/ (each ADR needs a row linking its section, or '(#decision-register)')"
    fi
fi

if [[ $FINDINGS -gt 0 ]]; then
    echo "check_design_anchors: $FINDINGS finding(s)" >&2
    exit 1
fi
exit 0
