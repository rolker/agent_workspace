#!/bin/bash
# .agent/scripts/_gh_create_args.sh
# Argument parsing and body-file copying shared by gh_create_issue.sh and
# gh_create_pr.sh (issue #323). Sourced, never executed.
#
# The wrappers sign the body gh will use, so they must read the command
# line exactly as gh does (cobra / pflag):
#   - a value-taking flag consumes its value whatever it looks like:
#     `--title -b` is a title "-b", `--body '--repo=x'` is a body
#     "--repo=x", and a value `--no-signature` is a value, not the
#     wrapper's flag;
#   - long flags take `--flag VALUE` or `--flag=VALUE`;
#   - shorthands take `-b VALUE`, `-bVALUE` and `-b=VALUE` (pflag strips
#     one `=` only when something follows it, so `-b=` is the value "="),
#     and may follow boolean shorthands in one cluster (`-wb VALUE`);
#   - after `--` nothing is a flag.
# The value-taking flags are those of `gh issue create` / `gh pr create`
# in gh 2.103 plus the inherited -R/--repo. A flag outside these tables is
# passed through as one token and its following word is not consumed: a
# flag a later gh adds that takes a value given as a separate word would
# have that value read as an argument of its own. gh rejects the
# positional arguments both commands do not take, so the call fails
# rather than going out with a body the wrapper did not see.
#
# gh_create_parse <issue|pr> <arg>... sets, in the caller's scope:
#   GH_ARGS             the argv for gh: every value-taking flag spelled
#                       `--<long> VALUE` (two words), boolean shorthands
#                       split one per word, the wrapper-only flags
#                       (--no-signature; --body-stdin for pr) removed,
#                       and --body-stdin replaced by `--body-file -`
#   GH_LABELS           every --label / -l value, in order
#   GH_REPO             the last -R / --repo value ("" when none)
#   GH_NO_SIGNATURE     true when --no-signature was given as a flag
#   GH_BODY_INDEX       index in GH_ARGS of the last --body value, or -1
#   GH_BODY_FILE_INDEX  index of the last --body-file value, or -1
#   GH_BODY_FILE_GIVEN  true when --body-file / -F was given (not
#                       counting the pr wrapper's --body-stdin)
#   GH_BODY_STDIN       true when --body-stdin was given (pr only)
#   GH_TITLE_INDEX      index of the last --title value, or -1
# It returns 2, with the error on stderr, when a value-taking flag has no
# value or -R / --repo has an empty one.
#
# gh_body_copy <mktemp template> reads the body file at
# GH_BODY_FILE_INDEX (stdin for "-") once into a temp copy made with
# `mktemp -t`, so under TMPDIR, sets GH_BODY_COPY to it and points the
# argument at it. Any readable path is read, a pipe, a FIFO or a process
# substitution included, and every later check reads the copy, so a body
# that can be read only once is still seen whole. A body file that cannot
# be read returns 2 with the error on stderr. The caller owns removal: set
# `trap 'rm -f "${GH_BODY_COPY:-}"' EXIT` before calling it.
#
# gh_body_is_signed <marker> is true when the body gh will get (the inline
# value or the copy) already contains <marker>.

# The GH_* variables are this file's output, read by the sourcing wrapper.
# shellcheck disable=SC2034

# --<name> takes a value for gh <kind> create.
_gh_long_takes_value() {  # <kind> <name>
    case "$2" in
        assignee|attach|body|body-file|label|milestone|project|recover|template|title|repo)
            return 0 ;;
    esac
    case "$1:$2" in
        issue:blocked-by|issue:blocking|issue:parent|issue:type) return 0 ;;
        pr:base|pr:head|pr:reviewer) return 0 ;;
    esac
    return 1
}

# The long name of a value-taking shorthand, printed; status 1 when -<c>
# takes no value.
_gh_short_value_name() {  # <kind> <char>
    case "$2" in
        a) echo assignee ;;
        b) echo body ;;
        F) echo body-file ;;
        l) echo label ;;
        m) echo milestone ;;
        p) echo project ;;
        T) echo template ;;
        t) echo title ;;
        R) echo repo ;;
        *)
            case "$1:$2" in
                pr:B) echo base ;;
                pr:H) echo head ;;
                pr:r) echo reviewer ;;
                *) return 1 ;;
            esac
            ;;
    esac
}

# -<c> is a boolean shorthand of gh <kind> create.
_gh_short_is_bool() {  # <kind> <char>
    case "$1:$2" in
        *:e|*:w|*:h|pr:d|pr:f) return 0 ;;
    esac
    return 1
}

_gh_missing_value() {  # <long name>
    if [ "$1" = repo ]; then
        echo "❌ Error: -R/--repo requires a value (owner/repo)" >&2
    else
        echo "❌ Error: --$1 requires a value" >&2
    fi
    return 2
}

# Record one value-taking flag and its value.
_gh_take() {  # <long name> <value>
    if [ "$1" = repo ] && [ -z "$2" ]; then
        _gh_missing_value repo
        return 2
    fi
    GH_ARGS+=("--$1" "$2")
    local idx=$(( ${#GH_ARGS[@]} - 1 ))
    case "$1" in
        body)      GH_BODY_INDEX=$idx ;;
        body-file) GH_BODY_FILE_INDEX=$idx ;;
        title)     GH_TITLE_INDEX=$idx ;;
        label)     GH_LABELS+=("$2") ;;
        repo)      GH_REPO="$2" ;;
    esac
    return 0
}

gh_create_parse() {  # <issue|pr> <arg>...
    local kind="$1"
    shift
    GH_ARGS=()
    GH_LABELS=()
    GH_REPO=""
    GH_NO_SIGNATURE=false
    GH_BODY_INDEX=-1
    GH_BODY_FILE_INDEX=-1
    GH_BODY_FILE_GIVEN=false
    GH_BODY_STDIN=false
    GH_TITLE_INDEX=-1

    local arg name value rest c long
    while [ $# -gt 0 ]; do
        arg="$1"
        shift
        case "$arg" in
            --)
                GH_ARGS+=("--" "$@")
                break
                ;;
            --no-signature)
                GH_NO_SIGNATURE=true
                ;;
            --body-stdin)
                if [ "$kind" = pr ]; then
                    GH_BODY_STDIN=true
                    _gh_take body-file - || return 2
                else
                    GH_ARGS+=("$arg")
                fi
                ;;
            --?*)
                name="${arg#--}"
                name="${name%%=*}"
                if _gh_long_takes_value "$kind" "$name"; then
                    if [[ "$arg" == *=* ]]; then
                        value="${arg#*=}"
                    elif [ $# -gt 0 ]; then
                        value="$1"
                        shift
                    else
                        _gh_missing_value "$name"
                        return 2
                    fi
                    [ "$name" = body-file ] && GH_BODY_FILE_GIVEN=true
                    _gh_take "$name" "$value" || return 2
                else
                    GH_ARGS+=("$arg")
                fi
                ;;
            -?*)
                rest="${arg#-}"
                while [ -n "$rest" ]; do
                    c="${rest:0:1}"
                    rest="${rest:1}"
                    if long=$(_gh_short_value_name "$kind" "$c"); then
                        if [ ${#rest} -ge 2 ] && [ "${rest:0:1}" = "=" ]; then
                            value="${rest:1}"
                        elif [ -n "$rest" ]; then
                            value="$rest"
                        elif [ $# -gt 0 ]; then
                            value="$1"
                            shift
                        else
                            _gh_missing_value "$long"
                            return 2
                        fi
                        rest=""
                        [ "$long" = body-file ] && GH_BODY_FILE_GIVEN=true
                        _gh_take "$long" "$value" || return 2
                    elif _gh_short_is_bool "$kind" "$c"; then
                        if [ ${#rest} -ge 2 ] && [ "${rest:0:1}" = "=" ]; then
                            GH_ARGS+=("-$c$rest")
                            rest=""
                        else
                            GH_ARGS+=("-$c")
                        fi
                    else
                        # Unknown shorthand: gh rejects it; pass the rest
                        # of the cluster through untouched.
                        GH_ARGS+=("-$c$rest")
                        rest=""
                    fi
                done
                ;;
            *)
                GH_ARGS+=("$arg")
                ;;
        esac
    done
    return 0
}

gh_body_copy() {  # <mktemp template>
    [ "$GH_BODY_FILE_INDEX" -ge 0 ] || return 0
    local src="${GH_ARGS[$GH_BODY_FILE_INDEX]}"
    GH_BODY_COPY=$(mktemp -t "$1")
    if [ "$src" = "-" ]; then
        if ! cat > "$GH_BODY_COPY"; then
            echo "❌ Error: could not read the body from standard input" >&2
            return 2
        fi
    elif [ -d "$src" ] || ! cat -- "$src" > "$GH_BODY_COPY" 2>/dev/null; then
        echo "❌ Error: cannot read --body-file '$src'" >&2
        return 2
    fi
    GH_ARGS[$GH_BODY_FILE_INDEX]="$GH_BODY_COPY"
    return 0
}

# No pipe: a `printf | grep -q` under pipefail can lose the match when
# grep exits early and printf takes SIGPIPE on a long body.
gh_body_is_signed() {  # <marker>
    if [ "$GH_BODY_INDEX" -ge 0 ]; then
        [[ "${GH_ARGS[$GH_BODY_INDEX]}" == *"$1"* ]]
    elif [ "$GH_BODY_FILE_INDEX" -ge 0 ]; then
        grep -Fq -- "$1" "${GH_ARGS[$GH_BODY_FILE_INDEX]}"
    else
        return 1
    fi
}
