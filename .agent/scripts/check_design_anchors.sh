#!/usr/bin/env bash
# check_design_anchors.sh -- every cited docs/design.md section anchor must
# resolve to a heading in docs/design.md (issue #335, plan Wire-in 6), and
# every cited section of a part's design to a heading in that design
# (issue #488).
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
# Citation forms. From outside design.md, a citation is a run of path
# characters ending in `design.md#<fragment>`; the fragment is the run of
# [A-Za-z0-9_-] after the '#'.
#       - an empty run (the literal `docs/design.md#<section>` placeholder) is
#         not a citation and is ignored;
#       - a path with a scheme and `://` (`https://...`) or starting with
#         `//` is a URL, never a citation of a local file: not checked, not
#         an error. A `word:` prefix without `//` (`main:docs/design.md#x`)
#         is not a URL; the path is resolved like any other, so it fails
#         as a missing file;
#       - a path whose last step is not exactly `design.md` (`other-design.md`)
#         is not a citation;
#       - any other fragment must match [a-z0-9][a-z0-9_-]*, otherwise it is a
#         malformed-anchor error (so `#How-it-works` fails instead of slipping
#         past a lowercase-only match). '_' is allowed because slug() keeps it,
#         as GitHub does, so a heading with an underscore can be cited;
#       - a fragment that matches is looked up among the headings of the file
#         the path resolves to.
#     How the path resolves (issue #488), one rule per form:
#       - a leading `$VAR/` or `${VAR}/` (`$WS_ROOT/docs/design.md#x`) or `/`
#         anchors it at the root;
#       - a Markdown link target, `[..](<path>#x)` or `[..](<<path>#x>)`,
#         resolves from the directory of the file that holds it, as GitHub
#         resolves it. In the angle-bracket form the path may hold spaces
#         (`[..](<my part/design.md#x>)` is `my part/design.md`); the
#         other forms end the path at a space
#         (`manifest/design.md#x` in docs/roadmap.md is docs/manifest/...;
#         `../../tools/t/docs/design.md#x` in docs/manifest/design.md);
#       - any other citation (in backticks or prose) is tried from the
#         citing file's directory first and, when no file is there, from the
#         root. So in a file under docs/ a backtick path and a link with the
#         same text name the same file whenever that file exists
#         (`design.md#x` and `manifest/design.md#x` in docs/roadmap.md).
#         The citing file's directory wins whenever the file is there, for
#         `docs/design.md#x` too: it means the root's design from a citer
#         whose directory has no docs/design.md of its own, and the part's
#         design from one that has (`tools/t/ROADMAP.md` beside
#         `tools/t/docs/design.md`), as a part's own files would cite it.
#         Such a citer names the root's design with an anchored path
#         (`/docs/design.md#x`, `$WS_ROOT/docs/design.md#x`).
#         When the file exists from neither base, the citation is an error
#         naming both paths.
#     A path that resolves to docs/design.md is a citation of the root's
#     design. One that resolves to any other file named `design.md`,
#     wherever it is (`tools/repos-manifest/docs/design.md`,
#     `docs/manifest/design.md`, `tools/x/design.md`, a root-level
#     `design.md`), cites a part's design (ADR-0022 decision 6: `<path>` is
#     the design file's directory) and is checked against that file's
#     headings, by the same slug() rule; a missing file is an error, as is a
#     path whose `..` leaves the root.
#   * Inside design.md: a Markdown link `](#<fragment>)` outside fenced code.
#     The fragment is everything up to the ')'. Ignored: an all-digit fragment
#     (an issue reference such as `[x](#12)`; a bare `(#295)` has no `](` and is
#     never seen) and a fragment containing '<' (a `#<slug>` placeholder).
#     Anything else must match the lowercase pattern above and resolve. This
#     holds for links inside headings too (`## [See](#gone)` is checked).
#
# Heading slugs (the one place the rule lives is the awk function slug()):
# GitHub style. Take the ATX heading text (`#` to `######`, up to 3 leading
# spaces, optional closing #s dropped); replace `[text](url)` by `text`;
# lowercase ASCII; drop every character that is not a letter, digit, space,
# '_' or '-'; turn each space into '-' (`# How it works` is `how-it-works`).
# A slug already taken gets '-1', '-2', ..., the first whose result is not
# taken either, as GitHub's slugger does: headings `A`, `A`, `A-1` are `a`,
# `a-1`, `a-1-1`. A heading whose slug is empty (`## !!!`) has no anchor and
# is skipped. Headings inside fenced code are not headings.
# A fence opens on ``` or ~~~ (3+, optional info string) indented at most 3
# spaces past the content column of the list item it sits in (0 outside a
# list; an item's column is its marker's indent, the marker and the spaces
# after it, and a non-blank line indented less ends the item). Deeper is
# indented code, not a fence. It closes only on a line of the same character,
# at least as long, indented no deeper than the opener could be, with nothing
# after it but spaces; a line such as ```bash inside an open fence does not
# close it. A fence still open at end of file is a finding: it would hide
# every later heading and link. Setext (underlined) headings are not
# recognised. Non-ASCII characters are dropped, which can differ from GitHub,
# but no anchor with such a character can match the citation pattern anyway.
#
# Scope: every citation in README.md, .agent/AGENT_ONBOARDING.md,
# docs/roadmap.md, docs/design.md (its citations of a part's design; its
# own anchors are checked as in-file links), .claude/skills/*/SKILL.md and
# .agent/knowledge/*.md (those that exist); every tracked (`git ls-files`)
# design.md or roadmap.md under a docs/ directory, so a part's design and
# roadmap; and each sub-roadmap docs/roadmap.md (else ROADMAP.md) names in
# its `## Direction` section's `| Sub-roadmap | Root |` table, with the
# design.md beside it, in any directory. The table is read by
# `sitrep_checks.sh --list-pointers` (beside this script), so the pointers
# taken here are the ones the sit-rep follows. Other files git does not
# track are never read: the main checkout's git-ignored worktrees/ folder
# holds other branches' drafts.
# Outside a git repository only the pointer table finds part files. Every
# in-file link in docs/design.md is checked, and every in-file link of each
# part design found this way (or cited), against that part's headings.
# Citations in fenced code of the citing files still count.
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
# A pointer table that sitrep_checks.sh cannot read (the script missing or
# failing) is a finding on the roadmap, never a silent skip; so is a citer
# that cannot be read, and the citers after it are still checked. A part's
# design that cannot be read is one finding, however many files cite it,
# and nothing is printed to stderr for it but the closing count.
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

# The pointer table is read by sitrep_checks.sh beside this script, so the
# two share one parser (-P: as below, through the `scripts/` symlink).
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

if [[ $# -eq 1 ]]; then
    ROOT="$1"
elif [[ -n "${DESIGN_ANCHORS_ROOT:-}" ]]; then
    ROOT="$DESIGN_ANCHORS_ROOT"
else
    # -P: through the repo-root `scripts/` symlink, a logical path's `../..`
    # would be the checkout's parent (as in capture.sh).
    ROOT="$(cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/../.." && pwd -P)"
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

ANCHOR_RE='^[a-z0-9][a-z0-9_-]*$'
FINDINGS=0

finding() {  # <file> <line> <message>
    printf '%s:%s: %s\n' "$1" "$2" "$3"
    FINDINGS=$((FINDINGS + 1))
}

# One pass over design.md. Emits tab-separated records:
#   HEAD <line> <level> <slug>   every heading outside fenced code
#   LINK <line> <fragment>       every `](#fragment)` outside fenced code
#   ROW  <line>                  every anchored table row inside the register
#   OPEN <line>                  a fence still open at end of file (its opener)
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
    BEGIN { fence = ""; reg_level = 0; depth = 0; OFS = "\t" }
    {
        line = $0
        # fenced code: ``` or ~~~ (3+), indented at most 3 spaces past the
        # content column of the list item it sits in (0 outside a list); more
        # is indented code, not a fence. It closes only on the same char, at
        # least as long, indented no deeper than the opener could be, with
        # nothing after it but spaces (no info string).
        if (fence != "") {
            if (match(line, /^ *(```+|~~~+) *$/)) {
                m = line; gsub(/ /, "", m)
                match(line, /^ */); ind = RLENGTH
                if (substr(m, 1, 1) == fence && length(m) >= fence_len && ind <= fence_max) fence = ""
            }
            next
        }

        # list context: a stack of the content columns of the open list items.
        # A non-blank line indented less than the content column of an item
        # ends that item; a list marker line opens a new one.
        if (line !~ /^[ \t]*$/) {
            match(line, /^ */); ind = RLENGTH
            while (depth > 0 && col[depth] > ind) depth--
            if (match(line, /^ *([-*+]|[0-9]+[.)])( +|$)/)) {
                mlen = RLENGTH
                mk = substr(line, ind + 1, mlen - ind); sub(/ +$/, "", mk)
                sp = mlen - ind - length(mk)
                if (sp < 1 || sp > 4) sp = 1
                col[++depth] = ind + length(mk) + sp
            }
        }

        if (match(line, /^ *(```+|~~~+)/)) {
            match(line, /^ */); ind = RLENGTH
            base = (depth > 0) ? col[depth] : 0
            if (ind <= base + 3) {
                m = line; sub(/^ */, "", m); match(m, /^(```+|~~~+)/); m = substr(m, 1, RLENGTH)
                fence = substr(m, 1, 1); fence_len = length(m)
                fence_max = base + 3; fence_line = NR
                next
            }
        }

        if (match(line, /^ *#+/)) {
            lead = index(substr(line, 1, RLENGTH), "#") - 1
            level = RLENGTH - lead
            rest = substr(line, RLENGTH + 1)
            if (lead <= 3 && level <= 6 && (rest == "" || rest ~ /^[ \t]/)) {
                sub(/^[ \t]+/, "", rest)
                if (rest != "") {
                    sl = slug(rest)
                    if (reg_level > 0 && level <= reg_level) reg_level = 0
                    if (sl != "") {          # an empty slug has no anchor
                        # GitHub slugger: a taken slug gets the next -N
                        # whose result is not taken either.
                        if (sl in used) {
                            base_sl = sl
                            do { cnt[base_sl]++; sl = base_sl "-" cnt[base_sl] } while (sl in used)
                        }
                        used[sl] = 1
                        print "HEAD", NR, level, sl
                        if (sl == "decision-register") reg_level = level
                    }
                    # no next: a heading line may hold links, which are checked
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
    END { if (fence != "") print "OPEN", fence_line }
    ' <"${1:-$DESIGN}"
}

# Run awk first so its failure is seen: a failing process substitution would
# otherwise leave the tables half-filled and the checker exiting 0.
if ! RECORDS="$(design_records)"; then
    echo "error: could not read headings and links from $DESIGN" >&2
    exit 2
fi

declare -A SLUGS=()
declare -a LINKS=()
REG_LINE=""
ROWS=0
LINK_COUNT=0
while IFS=$'\t' read -r kind a b c; do
    case "$kind" in
        HEAD)
            [[ -n "$c" ]] || continue
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
        OPEN)
            finding "$DESIGN" "$a" "fenced code opened here is never closed, so no heading or link after it is checked"
            ;;
    esac
done <<<"$RECORDS"

# check_anchor <file> <line> <fragment> <design file> -- resolve or report
# one citation against the headings of <design file>.
check_anchor() {
    local file="$1" line="$2" frag="$3" target="$4"
    if [[ ! "$frag" =~ $ANCHOR_RE ]]; then
        finding "$file" "$line" "malformed anchor '#$frag' (must match [a-z0-9][a-z0-9_-]*)"
    elif [[ "$target" == "$DESIGN" ]]; then
        [[ -n "${SLUGS[$frag]+x}" ]] || finding "$file" "$line" "broken anchor '#$frag' (no such heading in $DESIGN)"
    elif [[ -z "${PSLUGS["$target"$'\t'"$frag"]+x}" ]]; then
        finding "$file" "$line" "broken anchor '#$frag' (no such heading in $target)"
    fi
}

# check_fragment <file> <line> <fragment> -- a citation of the root's design.
check_fragment() { check_anchor "$1" "$2" "$3" "$DESIGN"; }

# In-file links in design.md.
for rec in ${LINKS[@]+"${LINKS[@]}"}; do
    line="${rec%%$'\t'*}"
    frag="${rec#*$'\t'}"
    if [[ -z "$frag" || "$frag" =~ ^[0-9]+$ || "$frag" == *'<'* ]]; then
        continue
    fi
    check_fragment "$DESIGN" "$line" "$frag"
done

# A part's design (issue #488, ADR-0022): any file named design.md other
# than the root's own, wherever it is (ADR-0022 decision 6: `<path>` is the
# design file's directory). Its headings are read with the same slug()
# rule, once, and its own in-file links are checked then.
is_part_design() { [[ "$1" != "$DESIGN" && ( "$1" == design.md || "$1" == */design.md ) ]]; }
declare -A PSLUGS=()
declare -A LOADED=()
# A part's design that cannot be read is reported once, here: the citer
# scan skips it, and a citation of it is not also reported as a broken
# anchor. stderr is dropped (the shell's own "Permission denied" line)
# because the finding says it.
declare -A UNREADABLE=()
load_design() {  # <file relative to the root>
    local f="$1" recs kind a b c rec frag
    local -a plinks=()
    [[ -z "${LOADED[$f]+x}" ]] || return 0
    LOADED["$f"]=1
    if ! recs="$(design_records "$f" 2>/dev/null)"; then
        UNREADABLE["$f"]=1
        finding "$f" 1 "could not read headings and links from $f"
        return 0
    fi
    while IFS=$'\t' read -r kind a b c; do
        case "$kind" in
            HEAD) [[ -n "$c" ]] && PSLUGS["$f"$'\t'"$c"]=1 ;;
            LINK) plinks+=("$a"$'\t'"$b") ;;
            OPEN) finding "$f" "$a" "fenced code opened here is never closed, so no heading or link after it is checked" ;;
        esac
    done <<<"$recs"
    for rec in ${plinks[@]+"${plinks[@]}"}; do
        frag="${rec#*$'\t'}"
        [[ -z "$frag" || "$frag" =~ ^[0-9]+$ || "$frag" == *'<'* ]] && continue
        check_anchor "$f" "${rec%%$'\t'*}" "$frag" "$f"
    done
}

# norm <path>: sets NORM to <path> with `.` and `..` steps folded; returns 1
# when a `..` would leave the root.
norm() {
    local IFS=/ part
    local -a parts out=()
    read -ra parts <<<"$1"
    for part in ${parts[@]+"${parts[@]}"}; do
        case "$part" in
            ''|.) ;;
            ..) [[ ${#out[@]} -gt 0 ]] || return 1; unset 'out[${#out[@]}-1]' ;;
            *) out+=("$part") ;;
        esac
    done
    NORM="${out[*]}"
}

# Citers: the scoped files that exist, the root's own design (for its
# citations of a part's design), every tracked design.md or roadmap.md
# under a docs/ directory (git ls-files: an untracked copy, such as another
# branch's draft in a git-ignored worktrees/ folder, is never read), and
# each sub-roadmap the root's roadmap points at, with the design.md beside
# it.
declare -A SEEN=()
CITERS=()
# A path is kept in its folded form (`./design.md` is `design.md`), so one
# file is never read, and its findings printed, twice.
add_citer() {
    norm "$1" || return 0
    [[ -n "$NORM" && -f "$NORM" && -z "${SEEN[$NORM]+x}" ]] || return 0
    SEEN["$NORM"]=1
    CITERS+=("$NORM")
}
shopt -s nullglob
for f in README.md .agent/AGENT_ONBOARDING.md docs/roadmap.md "$DESIGN" \
         .claude/skills/*/SKILL.md .agent/knowledge/*.md; do
    add_citer "$f"
done
shopt -u nullglob
while IFS= read -r -d '' f; do
    [[ "$f" =~ ^(.*/)?docs/(.*/)?(design|roadmap)\.md$ ]] && add_citer "$f"
done < <(git ls-files -z 2>/dev/null)
# The pointer table: `| Sub-roadmap | Root |` in docs/roadmap.md's (else
# ROADMAP.md's) `## Direction` section, read by sitrep_checks.sh
# --list-pointers, so the pointers followed here are exactly the ones the
# sit-rep follows (same parser, same rules: inside the root through links,
# inside its Root, the same repository, no repeat). Each sub-roadmap and
# the design.md beside it, wherever it is, are citers.
for rm_file in docs/roadmap.md ROADMAP.md; do
    [[ -e "$rm_file" ]] || continue
    if ! PTRS="$(bash "$SELF_DIR/sitrep_checks.sh" --root . --roadmap "$rm_file" --list-pointers 2>/dev/null)"; then
        finding "$rm_file" 1 "could not read the Sub-roadmap | Root table (sitrep_checks.sh --list-pointers failed)"
        break
    fi
    while IFS= read -r f; do
        [[ -n "$f" ]] || continue
        add_citer "$f"
        add_citer "$(dirname -- "$f")/design.md"
    done <<<"$PTRS"
    break
done
for f in ${CITERS[@]+"${CITERS[@]}"}; do
    is_part_design "$f" && load_design "$f"
done

# Citation forms (see the header): every `<path>design.md#<fragment>` run in
# the citer on stdin, with whether it is a Markdown link target (`](` or
# `](<` before it). An angle-bracket destination, `](<...>)`, is taken
# whole first, so a path in it may hold spaces (`](<my part/design.md#x>)`
# is `my part/design.md#x`, a link); it is then blanked so the run scan
# below does not read a piece of it again. The file is read through a
# redirect, never as an awk operand, so a path holding `=` is not taken for
# an awk assignment.
citations() {
    awk 'BEGIN { re = "[-A-Za-z0-9_.$:{}~%+/]*design\\.md#[A-Za-z0-9_-]*"; OFS = "\t" }
    {
        line = $0; off = 0
        while (match(substr(line, off + 1), /\]\(<[^<>]*>/)) {
            s = off + RSTART
            dest = substr(line, s + 3, RLENGTH - 4)
            if (match(dest, /design\.md#[A-Za-z0-9_-]*/))
                print FNR, 1, substr(dest, 1, RSTART + RLENGTH - 1)
            len = length(dest)
            blank = ""; for (i = 0; i < len; i++) blank = blank " "
            line = substr(line, 1, s + 2) blank substr(line, s + 3 + len)
            off = s + 3 + len
        }
        off = 0
        while (match(substr(line, off + 1), re)) {
            s = off + RSTART
            tok = substr(line, s, RLENGTH)
            islink = (s > 2 && substr(line, s - 2, 2) == "](") \
                     || (s > 3 && substr(line, s - 3, 3) == "](<")
            print FNR, islink ? 1 : 0, tok
            off = s + RLENGTH - 1
        }
    }'
}

# Each citer is scanned on its own, and a citer that cannot be read is a
# finding: one failed read must not end the scan of the citers after it,
# nor leave the hook exiting 0 (never a silent skip).
for file in ${CITERS[@]+"${CITERS[@]}"}; do
    [[ -z "${UNREADABLE[$file]+x}" ]] || continue              # reported once
    if ! CITES="$(citations 2>/dev/null <"$file")"; then
        finding "$file" 1 "could not read $file, so its citations are not checked"
        continue
    fi
    while IFS=$'\t' read -r line islink tok; do
        [[ -n "$tok" ]] || continue                               # no citation
        frag="${tok##*#}"
        path="${tok%#*}"
        [[ -n "$frag" ]] || continue                              # placeholder
        [[ "$path" =~ ^[A-Za-z][A-Za-z0-9+.-]*:// || "$path" == //* ]] && continue   # a URL
        [[ "$path" == design.md || "$path" == */design.md ]] || continue
        anchored=false
        if [[ "$path" =~ ^\$(\{[A-Za-z_][A-Za-z0-9_]*\}|[A-Za-z_][A-Za-z0-9_]*)/(.*)$ ]]; then
            path="${BASH_REMATCH[2]}"; anchored=true
        elif [[ "$path" == /* ]]; then
            anchored=true
        fi
        dir="$(dirname -- "$file")"
        target=""
        if [[ "$anchored" == true ]]; then
            norm "$path" && target="$NORM"
        elif [[ "$islink" == 1 ]]; then
            norm "$dir/$path" && target="$NORM"
        else
            # From the citing file's directory, then from the root; when
            # neither file exists the citation is an error naming both,
            # never a silent pass.
            from_dir=""; from_root=""
            norm "$dir/$path" && from_dir="$NORM"
            norm "$path" && from_root="$NORM"
            if [[ -n "$from_dir" && -f "$from_dir" ]]; then
                target="$from_dir"
            elif [[ -n "$from_root" && -f "$from_root" ]]; then
                target="$from_root"
            elif [[ -n "$from_dir$from_root" ]]; then
                if [[ -z "$from_dir" || -z "$from_root" || "$from_dir" == "$from_root" ]]; then
                    finding "$file" "$line" "no such design file '${from_dir:-$from_root}' for '#$frag'"
                else
                    finding "$file" "$line" "no such design file '$from_dir' or '$from_root' for '#$frag'"
                fi
                continue
            fi
        fi
        if [[ -z "$target" ]]; then
            finding "$file" "$line" "'$tok' leaves the root"
            continue
        fi
        if [[ "$target" == "$DESIGN" ]]; then
            check_fragment "$file" "$line" "$frag"
        else
            if [[ ! -f "$target" ]]; then
                finding "$file" "$line" "no such design file '$target' for '#$frag'"
                continue
            fi
            load_design "$target"
            [[ -z "${UNREADABLE[$target]+x}" ]] || continue       # reported once
            check_anchor "$file" "$line" "$frag" "$target"
        fi
    done <<<"$CITES"
done

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
