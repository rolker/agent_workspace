#!/usr/bin/env bash
# .agent/scripts/tests/run_script_tests.sh
# Runner for the .agent/scripts/tests/test_*.sh suites (issue #269 PR A):
# every suite, or, in `--files` mode (issue #410), only the suites the
# changed files can affect.
#
# Before this script, .github/workflows/validate.yml explicitly named only
# three of this repo's ten existing test_*.sh scripts by individual `run:`
# steps; the other seven ran nowhere in CI. This runner globs and executes
# every test_*.sh in its directory (auto-discovery for future suites) and
# additionally, separately, asserts by exact filename that
# test_checkpoint_269.sh is present and was executed (in a scoped run too:
# it joins every selection) — see "Protecting the
# checkpoint test from edit/deletion" in .agent/work-plans/issue-269/plan.md:
# if test_checkpoint_269.sh is ever deleted, this runner fails loudly (the
# whole pre-commit hook goes red) rather than the glob silently running one
# fewer suite.
#
# One job (the default): the suites run one after another in the
# foreground, in list order, their output streamed live, and the first
# suite to exit non-zero stops the run — remaining suites are not
# executed. This keeps runtime bounded by the first failure. Ctrl-C at a
# terminal reaches the running suite directly, as it is in the foreground;
# a SIGTERM sent to the runner alone stops the runner, not the suite.
#
# Parallel runs (issue #444), with -j N above 1: every selected suite runs,
# at most N at a time, largest file first (a stand-in for slowest first).
# Each suite's stdout and stderr go to one file of its own, printed whole
# once every suite has finished: the failures first, in list order, each
# under a "===== FAILED: <suite> =====" banner, then (only with
# --show-passed) the passing suites' output, then every suite's time,
# slowest first, then the closing line. Nothing is interleaved and no
# failure hides another. The exit code is what a one-job run gives for the
# first failing suite in list order, whatever order the suites started or
# finished in. Each suite is started under `set -m`: in a process group of
# its own, with SIGINT and SIGQUIT at their defaults as in the foreground
# (a background job started without job control has both ignored, and
# bash cannot trap a signal ignored on entry), stdin from /dev/null.
# SIGINT (Ctrl-C), SIGTERM or SIGHUP to the runner sends the same signal to
# every running suite's whole process group, and to the group of any
# finished suite that left a process running in it, KILL to whatever is
# left in those groups 5 seconds later (a suite that exits sooner does not
# cut short the cleanup of a process it started), and removes the run's
# directory. A process left that ignores the signal waits out the 5
# seconds: a suite's `cmd &` ignores SIGINT, so Ctrl-C can take that long.
# A second signal during those 5 seconds KILLs what is left at once. Any
# other exit while something of the run is still running (an internal
# error, a fatal signal the runner does not trap, or the end of the run
# with a process a suite left running) stops it the same way, with
# SIGTERM, before the run's directory is removed, and says so.
# Needs bash 5.1 (`wait -n -p`); an older bash is refused with a message.
#
# Usage: run_script_tests.sh [options] [tests-dir] [--files <file>...]
#   Options come first, then the tests directory, then --files, which
#   takes every argument after it as a file:
#   -j N, --jobs N   run N suites at a time. Without it RUN_SCRIPT_TESTS_JOBS
#                    sets the count, else the default, 1. A count above 8
#                    runs with 8 and says so; one that is not a whole number
#                    of at least 1 is refused. Every run prints its count;
#                    at the default it also names the count this machine
#                    suits (a quarter of its CPUs, at least 2 and at most
#                    6, never more than it has). Suites do not inherit RUN_SCRIPT_TESTS_JOBS. The hook's
#                    entry ends in --files, so the environment variable is
#                    the hook's only way to set the count.
#   --shuffle[=SEED] start the suites in an order drawn from SEED (a whole
#                    number; drawn at random and printed when not given),
#                    so a failing order can be repeated. At one job the run
#                    still stops at its first failure in the shuffled order.
#   --show-passed    in a parallel run, print the passing suites' output too.
#   tests-dir defaults to this script's own directory. The parameter exists
#   so test_run_script_tests.sh can point the runner at a scratch copy of the
#   tests directory without touching the real one.
#   Without --files every suite runs, as before. With --files (the
#   pre-commit hook passes the commit's in-scope files, repo-relative), the
#   suites to run come from suites_for_files.sh (see its header for the
#   rules): only those the files can reach, plus test_checkpoint_269.sh, or
#   every suite when in doubt (no files, more than $FILES_MAX files, a
#   full-run trigger such as this runner or a .agent/scripts/_*.sh helper,
#   an in-scope file no suite maps other than a Markdown document, which
#   only adds its scanning suites, a deleted in-scope path, or any error).
#   The run prints which suites it chose and why.
#
# Deletions and renames (issue #410): pre-commit passes only files that
# still exist, so a deleted file or a rename's source never reaches
# --files, and the suites that still name the old path would be skipped.
# In --files mode the runner therefore lists them itself and runs every
# suite when one is in the hook's scope. Which deletions depends on the
# context, keyed on GIT_INDEX_FILE, which git sets for every commit hook:
#   - a commit (GIT_INDEX_FILE set): the staged deletions
#     (`git diff --cached -z --no-renames --diff-filter=D`; --no-renames
#     makes a rename show as a deletion of its source, and -z keeps a
#     non-ASCII path unquoted);
#   - any other run (a branch run,
#     `pre-commit run --files $(git diff --name-only main...HEAD)`, staged
#     changes or not): the staged deletions plus the deletions on the
#     branch (`<default-branch>...HEAD`, same flags).
# This check runs before the GIT_* unset below: `git commit -a` and
# `git commit <paths>` give the hook a temporary index through
# GIT_INDEX_FILE, and after the unset the diff would read the real index
# and see nothing. A commit whose only in-scope change is a deletion still
# does not invoke the hook at all; CI's all-files run is the backstop.
# Where no default branch can be resolved (CI's shallow checkout has no
# `main`), a branch run cannot list the branch's deletions, so it runs
# every suite and says so in one plain line.
#
# Exit codes (in a parallel run, those of the first failing suite in list
# order):
#   0  all suites passed
#   1  a suite failed, or a preflight check failed — bad arguments,
#      test_checkpoint_269.sh missing from the discovered set, a required
#      tool missing, or the absolute-/tmp mktemp lint found a violation (the
#      message says which)
#   2  a suite left files behind in its TMPDIR after it ran, or a process it
#      left running wrote there before the run ended (leak detected; the
#      message names the suite that leaked and the leftover paths)
#   130, 143, 129  the run was interrupted by SIGINT, SIGTERM or SIGHUP
#
# Wired into .pre-commit-config.yaml as the `validate-script-tests` local
# hook inside the existing Lint (pre-commit) job — no .github/workflows/
# validate.yml edit. CI's Lint (pre-commit) job runs `pre-commit run
# --all-files`, which always runs this hook regardless of what changed, and
# runs every suite: the file list it passes includes this runner, a
# full-run trigger. The hook passes no job count, so it runs at the
# default (or RUN_SCRIPT_TESTS_JOBS, where set); CI sets none, so CI's job
# count is the default. Locally, since issue #354, the hook is scoped with
# `files:`/`exclude:`
# (see .pre-commit-config.yaml) so a `git commit` only pays this cost when
# the commit touches .agent/, .claude/, AGENTS.md, Makefile,
# .pre-commit-config.yaml itself, or .github/PULL_REQUEST_TEMPLATE.md
# (excluding .agent/work-plans/, since no
# suite reads a branch's working-tree copy of it — see
# .agent/work-plans/issue-354/plan.md and
# test_script_tests_hook_scope.sh, which guards the regex against drift).
# SKIP=validate-script-tests is the sanctioned escape for work-in-progress
# commits (same SKIP= mechanism this repo's other local hooks already
# support); a dispatched workspace implement or address-findings pass uses
# it on its intermediate commits and runs the hooks once over the branch
# before its progress entry (owner-decided 2026-10-20, issue #399), with
# CI's all-files run as the backstop. Since issue #410 that branch run, and
# each commit, runs only the suites the changed files reach (--files mode
# above), not every suite.
#
# Git-hook environment sanitization (found while wiring this into
# .pre-commit-config.yaml for the first time — none of these suites had
# previously run from a `git commit`-triggered hook, only from a bare
# `pre-commit run` or directly in CI): `git commit` sets GIT_DIR /
# GIT_WORK_TREE / GIT_INDEX_FILE (and friends) in the environment it passes
# to pre-commit's hook process and everything that process spawns. Several
# suites build their own sandbox git repos with `git -C <sandbox-dir> ...`;
# with GIT_DIR etc. still set from the outer `git commit`, git prioritizes
# those env vars over `-C`'s directory-based discovery, so `-C <sandbox>`
# operations silently hit the REAL repo's .git instead (reproduced: a
# sandbox `git remote add origin` failed with "remote origin already
# exists" because it had added the remote to the real repo, which already
# has one). Unset the whole GIT_* hook-context family before running any
# suite so every suite's own `-C`/`cd` based git usage resolves the repo it
# actually names.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# More changed files than this runs every suite without asking the mapper.
FILES_MAX=200

# Job count (issue #444): the default, and the cap no request goes past.
JOBS_DEFAULT=1
JOBS_MAX=8
# The count this machine suits for a parallel run: a quarter of its CPUs,
# at least 2 and at most 6, and never more than it has. Only printed while
# the default is 1; empty when the CPU count cannot be read.
jobs_suited=""
cpus=$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null) || cpus=""
if [[ "$cpus" =~ ^[0-9]+$ ]] && (( 10#$cpus >= 1 )); then
    cpus=$(( 10#$cpus ))
    jobs_suited=$(( cpus / 4 ))
    (( jobs_suited >= 2 )) || jobs_suited=2
    (( jobs_suited <= 6 )) || jobs_suited=6
    (( jobs_suited <= cpus )) || jobs_suited=$cpus
fi

# --- Arguments: [options] [tests-dir] [--files <file>...] ---
USAGE="usage: run_script_tests.sh [-j N] [--shuffle[=SEED]] [--show-passed] [tests-dir] [--files <file>...]"
TESTS_DIR="$SCRIPT_DIR"
files_mode=0
changed_files=()
jobs_opt=""
jobs_opt_given=0
show_passed=0
shuffle=0
shuffle_seed=""
shuffle_seed_given=0
while [[ $# -gt 0 && "$1" == -* && "$1" != "--files" ]]; do
    case "$1" in
        -j | --jobs)
            if [[ $# -lt 2 ]]; then
                echo "error: $1 needs a job count ($USAGE)" >&2
                exit 1
            fi
            jobs_opt="$2"
            jobs_opt_given=1
            shift 2
            ;;
        -j?*) jobs_opt="${1#-j}"; jobs_opt_given=1; shift ;;
        --jobs=*) jobs_opt="${1#--jobs=}"; jobs_opt_given=1; shift ;;
        --show-passed) show_passed=1; shift ;;
        --shuffle) shuffle=1; shift ;;
        --shuffle=*) shuffle=1; shuffle_seed="${1#--shuffle=}"; shuffle_seed_given=1; shift ;;
        *)
            echo "error: unknown option '$1' ($USAGE)" >&2
            exit 1
            ;;
    esac
done
if [[ $# -gt 0 && "$1" != "--files" ]]; then
    TESTS_DIR="$1"
    shift
fi
if [[ $# -gt 0 ]]; then
    if [[ "$1" != "--files" ]]; then
        echo "error: unexpected argument '$1': options go before the tests directory, --files last ($USAGE)" >&2
        exit 1
    fi
    files_mode=1
    shift
    changed_files=("$@")
fi

# --- Job count: -j, else RUN_SCRIPT_TESTS_JOBS, else the default ---
# A -j given empty (`-j ""`, `--jobs=`) is refused below like `-j 0`, not
# taken for no -j. An empty RUN_SCRIPT_TESTS_JOBS counts as unset.
if (( jobs_opt_given )); then
    jobs_asked="$jobs_opt"
    jobs_from="-j"
elif [[ -n "${RUN_SCRIPT_TESTS_JOBS:-}" ]]; then
    jobs_asked="$RUN_SCRIPT_TESTS_JOBS"
    jobs_from="RUN_SCRIPT_TESTS_JOBS"
else
    jobs_asked="$JOBS_DEFAULT"
    jobs_from="default"
fi
if [[ ! "$jobs_asked" =~ ^[0-9]+$ ]] || (( 10#$jobs_asked < 1 )); then
    echo "error: the job count from $jobs_from must be a whole number of at least 1, not '$jobs_asked' ($USAGE)" >&2
    exit 1
fi
jobs=$(( 10#$jobs_asked ))
jobs_note="$jobs_from"
if [[ "$jobs_from" == default && -n "$jobs_suited" ]]; then
    jobs_note="default; -j $jobs_suited suits this machine's $cpus CPUs"
fi
if (( jobs > JOBS_MAX )); then
    jobs_note="$jobs_from asked for $jobs; the cap is $JOBS_MAX"
    jobs=$JOBS_MAX
fi
# The count is this run's; a runner a suite starts takes its own default.
unset RUN_SCRIPT_TESTS_JOBS
if (( jobs > 1 )) && (( BASH_VERSINFO[0] < 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] < 1) )); then
    echo "error: running suites in parallel needs bash 5.1 or newer (wait -n -p); this is bash $BASH_VERSION — run with -j 1" >&2
    exit 1
fi
if (( shuffle )); then
    if (( ! shuffle_seed_given )); then
        shuffle_seed=$RANDOM
    elif [[ ! "$shuffle_seed" =~ ^[0-9]+$ ]]; then
        echo "error: the --shuffle seed must be a whole number, not '$shuffle_seed' ($USAGE)" >&2
        exit 1
    fi
fi

# --- Deleted and renamed-away paths (see "Deletions and renames" above) ---
# Must run before the GIT_* unset below, while GIT_INDEX_FILE still names
# the index the commit is building.
deleted_paths=()
deletion_check_error=""
no_default_branch=0
# git_paths_z <array-name> <git args>...: read a `git diff -z` path list
# into the named array (appending), NUL-delimited so a non-ASCII or
# otherwise unusual path arrives as itself, not C-quoted; returns git's
# exit status.
git_paths_z() {
    local -n _paths="$1"
    shift
    local _got=()
    mapfile -d '' -t _got < <(git "$@" 2>/dev/null)
    wait "$!" || return 1
    _paths+=("${_got[@]}")
}
if [[ $files_mode -eq 1 ]]; then
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        deletion_check_error="not inside a git repository ($(pwd))"
    elif ! git_paths_z deleted_paths diff --cached --name-only -z --no-renames --diff-filter=D; then
        deletion_check_error="git diff --cached --diff-filter=D failed"
    elif [[ -z "${GIT_INDEX_FILE:-}" ]]; then
        # Not a commit: a branch run also sees the branch's deletions.
        # shellcheck source=../_resolve_default_branch.sh
        source "$SCRIPT_DIR/../_resolve_default_branch.sh"
        if ! default_ref=$(resolve_default_branch 2>/dev/null); then
            no_default_branch=1
        elif ! git_paths_z deleted_paths diff --name-only -z --no-renames --diff-filter=D "$default_ref...HEAD"; then
            deletion_check_error="git diff $default_ref...HEAD failed"
        fi
    fi
fi

# See "Git-hook environment sanitization" above.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR \
      GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_PREFIX

REQUIRED_SUITE="test_checkpoint_269.sh"
# Cap on how many leaked paths the exit-2 message prints (see the leak sweep).
LEAK_LIST_MAX=200

if [[ ! -d "$TESTS_DIR" ]]; then
    echo "error: tests directory not found: $TESTS_DIR" >&2
    exit 1
fi

shopt -s nullglob
suites=("$TESTS_DIR"/test_*.sh)
shopt -u nullglob

if [[ ${#suites[@]} -eq 0 ]]; then
    echo "error: no test_*.sh suites found in $TESTS_DIR" >&2
    exit 1
fi

found_required=0
for s in "${suites[@]}"; do
    if [[ "$(basename "$s")" == "$REQUIRED_SUITE" ]]; then
        found_required=1
        break
    fi
done
if [[ "$found_required" -ne 1 ]]; then
    echo "error: required suite '$REQUIRED_SUITE' not found in $TESTS_DIR — the checkpoint gate would silently stop running" >&2
    exit 1
fi

# Tool preflight: several suites shell out to these; name the missing tool
# up front instead of letting a suite fail opaquely. jq is installed by
# bootstrap.sh and present on GitHub's runners.
for tool in jq python3; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "error: '$tool' not found on PATH — required by the script test suites (see .agent/scripts/bootstrap.sh)" >&2
        exit 1
    fi
done

# Preflight lint: no absolute-/tmp mktemp destinations in the suites under
# $TESTS_DIR (issue #304, #297 PR 2). A suite that writes to a hardcoded
# /tmp path bypasses TMPDIR entirely, so the per-run guard below can
# neither contain nor see what it leaves behind. Issue #297 PR 1 normalised
# every such site in this directory; this lint is the regression guard that
# keeps it that way. It scans $TESTS_DIR (the caller-supplied [tests-dir]),
# not a hardcoded path, so test_run_script_tests.sh can exercise it against
# a scratch fixture directory.
#
# Scope is "$TESTS_DIR"/test_*.sh — the suites the runner actually executes.
# That glob is also what exempts this file: the runner's own guard mktemp
# below legitimately hardcodes /tmp (see below) and is excluded because
# run_script_tests.sh is not a test_*.sh suite, not because of any pattern
# contortion. test_run_script_tests.sh *is* in scope, so its lint fixtures
# assemble their templates at runtime rather than spelling them inline.
#
# The pattern covers these mktemp spellings that escape TMPDIR:
#   mktemp [-d] /tmp/<template>      bare absolute template
#   mktemp -d -p /tmp <template>     -p / --tmpdir root
#   mktemp -d -p/tmp <template>      attached-argument -p, incl. clustered
#   mktemp -dp/tmp <template>        short flags (`-dp`, `-up`, ...)
#   mktemp -d --tmpdir=/tmp <t>      (and the space-separated --tmpdir /tmp)
# It is not claimed to be exhaustive — see the coverage boundary below for
# the spellings that are knowingly out of reach.
# `/tmp` must be preceded by a whitespace/quote/`=`/`(` boundary — optionally
# followed by an attached short-flag cluster ending in `p` — so a path that
# merely ends in .../tmp/... (e.g. "$HOME/local/tmp/x.XXXXXX", or
# "$HOME/opt-p/tmp/x") is not a hit, and must be followed by `/`, whitespace,
# a quote, `)` or end of line so `/tmpfile.XXXXXX` is not one either.
# `[^|]*` keeps the match inside one command rather than spanning a pipeline.
# This is a heuristic over file text, not a shell parse: it reads literals
# only, so a /tmp root that arrives through a variable is invisible to it.
lint_hits=$(grep -rnE 'mktemp[^|]*[[:space:]"'"'"'=(](-[[:alpha:]]*p)?/tmp(/|$|[[:space:]"'"'"')])' "$TESTS_DIR"/test_*.sh 2>/dev/null) || true
if [[ -n "$lint_hits" ]]; then
    echo "error: absolute /tmp mktemp destination(s) found in $TESTS_DIR — suites must honor TMPDIR (use \`mktemp -d\` or \`mktemp -d -p \"\$SANDBOX\"\`, never a /tmp template, \`-p /tmp\` or \`--tmpdir=/tmp\`) so the per-run leak guard can see their temp files:" >&2
    echo "$lint_hits" >&2
    exit 1
fi

# --- Suite selection (issue #410; see Usage above) ---
# run_suites is what the loop below runs. Every reason for a full run is
# printed; a scoped run prints the mapper's suite <- file lines.
run_suites=("${suites[@]}")
selection="full"
full_reason=""
if [[ $files_mode -eq 0 ]]; then
    full_reason="no --files given"
elif [[ -n "$deletion_check_error" ]]; then
    full_reason="the deletion check failed ($deletion_check_error)"
elif [[ $no_default_branch -eq 1 ]]; then
    full_reason="no default branch available here (shallow checkout?), so the branch's deletions cannot be listed"
elif [[ ${#changed_files[@]} -gt $FILES_MAX ]]; then
    full_reason="${#changed_files[@]} changed files (more than $FILES_MAX)"
else
    mapper_args=(--tests-dir "$TESTS_DIR")
    for d in "${deleted_paths[@]}"; do
        [[ -n "$d" ]] && mapper_args+=(--deleted "$d")
    done
    if ! chosen=$(bash "$SCRIPT_DIR/suites_for_files.sh" "${mapper_args[@]}" -- "${changed_files[@]}"); then
        full_reason="suites_for_files.sh failed"
    elif [[ -z "$chosen" ]]; then
        full_reason="suites_for_files.sh chose nothing"
    elif [[ "$chosen" == "ALL" ]]; then
        full_reason="suites_for_files.sh chose ALL (reason above)"
    else
        mapfile -t chosen_names <<<"$chosen"
        scoped=()
        unknown=""
        for n in "${chosen_names[@]}"; do
            if [[ -f "$TESTS_DIR/$n" ]]; then
                scoped+=("$TESTS_DIR/$n")
            else
                unknown="$n"
                break
            fi
        done
        if [[ -n "$unknown" ]]; then
            full_reason="suites_for_files.sh named '$unknown', which is not in $TESTS_DIR"
        else
            # The required suite joins every scoped run, whatever the mapper said.
            have_required=0
            for s in "${scoped[@]}"; do
                [[ "$(basename "$s")" == "$REQUIRED_SUITE" ]] && have_required=1
            done
            [[ $have_required -eq 1 ]] || scoped+=("$TESTS_DIR/$REQUIRED_SUITE")
            run_suites=("${scoped[@]}")
            selection="scoped"
        fi
    fi
fi
if [[ "$selection" == "full" ]]; then
    echo "run_script_tests: full run, all ${#suites[@]} suites: $full_reason"
else
    names=""
    for s in "${run_suites[@]}"; do names+="${names:+ }$(basename "$s")"; done
    echo "run_script_tests: scoped run, ${#run_suites[@]} of ${#suites[@]} suites for ${#changed_files[@]} changed file(s): $names"
fi
if (( jobs == 1 )); then
    echo "run_script_tests: running with 1 job ($jobs_note)"
else
    echo "run_script_tests: running with $jobs jobs ($jobs_note)"
fi

# --- Per-suite TMPDIR guard (issue #304, #297 PR 2; per suite since #444) ---
#
# Give the whole run one private root, $RUN_ROOT, and every suite its own
# directory in it, $RUN_ROOT/tmp/<suite>, pointed at by the suite's
# TMPDIR/TMP/TEMP. After a suite returns successfully its own directory is
# swept: anything still in it means that suite leaked, and the run fails
# with exit 2 naming that suite. One directory per suite is what keeps the
# charge on the suite that caused it, also when suites run at the same time.
#
# No directory is removed when its suite ends. After every suite has
# finished, every passing suite's directory is swept once more: a process a
# suite left running that wrote into its TMPDIR after the suite exited is
# caught there and charged to the suite whose directory it is in (exit 2).
# The runner's own temporary files go to $RUN_ROOT/runner, and the captured
# output of a run with more than one job to $RUN_ROOT/out; neither is swept.
#
# The sweep sees *everything* left in TMPDIR, not just a suite's own
# sandbox — including residue from tools a suite shells out to (git, gh,
# pre-commit, python3). That is deliberate: such residue is a leak too. The
# full real-suite run is the empirical check that no false positive exists
# today; if this ever fires on tool residue, investigate the attribution
# rather than assuming the guard is broken.
#
# The guard directory hardcodes /tmp and deliberately ignores the caller's
# own TMPDIR: a nested run — this repo's test_run_script_tests.sh drives
# this runner against scratch tests directories — must not have its guard
# redirected into the outer run's temp root or into the scratch tests
# directory itself. The preflight lint above does not object, because it
# scans "$TESTS_DIR"/test_*.sh and this file is the runner, not a suite.
#
# Coverage boundary: the sweep only sees what lands in TMPDIR while a suite
# runs, and the lint only covers "$TESTS_DIR"/test_*.sh.
#
# Three mktemp spellings are knowingly out of the lint's reach, each verified
# to leave a real directory behind with the run still exiting 0:
#   - a backslash line-continuation splitting the command across lines
#     (`mktemp -d \` / `    -p /tmp t.XXXXXX`). The lint is a line-oriented
#     grep; no single-line pattern can see it.
#   - a /tmp root that arrives through a variable — the lint reads literals,
#     not shell semantics.
#   - a bare *relative* template (`mktemp -d leak.XXXXXX`), which ignores
#     TMPDIR and lands in the runner's cwd — the repo root under pre-commit —
#     so it is invisible to both the lint and the sweep. No such site exists
#     in this directory today.
# Five absolute-/tmp
# mktemp sites remain in production scripts that suites may invoke —
# worktree_create.sh:1245,1286, pr_status.sh:321,336,
# fetch_pr_reviews.sh:158 (cited as file:line only;
# reproducing one of those templates here would trip the lint above).
# Temp files those calls create bypass both TMPDIR and this sweep. Fixing
# them is out of scope for #304.
#
# One-time cleanup of the historical leak (#297 measured 320 dirs/run before
# PR 1): this is a manual step for a human, not something this script does.
# Review the dry run first —
#   find /tmp -maxdepth 1 -type d -name 'tmp.*' -mtime +1 \
#       -exec sh -c '[ -d "$1/.git" ] && echo "$1"' _ {} \;
# and only then the deleting form —
#   find /tmp -maxdepth 1 -type d -name 'tmp.*' -mtime +1 \
#       -exec sh -c '[ -d "$1/.git" ] && rm -rf "$1"' _ {} \;
# Caveat: the .git filter only matches when .git sits directly at depth 1 of
# the sandbox root (the root itself was `git init`'d). Suites that nest their
# fixture repos deeper are not matched, and test_adapter.sh,
# test_project_registry.sh and test_dispatch_phase.sh create no git repos at
# all — none of their leftovers match. The backlog this leaves behind was
# measured on 2026-09-21; see the #297 timeline for the figures rather than
# trusting a number frozen into this comment. For the rest, an age-based
# sweep a human eyeballs first:
#   find /tmp -maxdepth 1 -type d -name 'tmp.*' -mtime +7
RUN_ROOT=$(mktemp -d --tmpdir=/tmp run-script-tests.XXXXXX) || {
    echo "error: could not create the per-run TMPDIR guard directory under /tmp" >&2
    exit 1
}
# Unconditional cleanup on every exit path after this point — all suites
# passed, a suite failed, a leak was detected, or an interrupt. In a
# parallel run it first stops whatever of the run is still running: a
# suite, or a process a suite left running in its group (stop_suites,
# below, with SIGTERM). An exit from the parallel section other than
# through on_interrupt (an internal error, a `set -u` abort, a fatal signal
# the runner does not trap) would otherwise remove $RUN_ROOT from under
# suites still writing to it, and leave them running. When a stop is
# already under way, the exit is a second signal cutting it short (or the
# end of on_interrupt, with nothing left): KILL at once (kill_now), not a
# second 5-second stop.
parallel=0
# A stop is under way (on_interrupt or stop_suites has begun); its KILL
# watchdog.
stop_underway=0
stop_watchdog=""
# The runner's own stderr, for the messages of cleanup_run and kill_now: a
# signal that ends the runner during a builtin such as `wait ... 2>/dev/null`
# runs the EXIT trap with that redirection still in place. A parallel run
# keeps a copy of it on a descriptor of its own (closed in the suites).
runner_err=2
cleanup_run() {
    local live=()
    if (( parallel && stop_underway )); then
        kill_now
    elif (( parallel )); then
        live_groups
        if (( ${#live[@]} )); then
            echo "run_script_tests: stopping ${#live[@]} process group(s) of this run still running at exit" >&"$runner_err"
            stop_suites TERM
        fi
    fi
    rm -rf "$RUN_ROOT"
}
trap cleanup_run EXIT
mkdir -p "$RUN_ROOT/tmp" "$RUN_ROOT/out" "$RUN_ROOT/runner" || {
    echo "error: could not create the guard's directories under $RUN_ROOT" >&2
    exit 1
}
export TMPDIR="$RUN_ROOT/runner" TMP="$RUN_ROOT/runner" TEMP="$RUN_ROOT/runner"

# suite_tmp <name>: the suite's own TMPDIR.
suite_tmp() { printf '%s/tmp/%s' "$RUN_ROOT" "$1"; }

# sweep <dir> <list-file>: list what is left in <dir> into <list-file>;
# true when something is. The listing is recursive, not -maxdepth 1: the
# EXIT trap deletes $RUN_ROOT on the way out, so the leak message is the
# only chance anyone gets to see what was left behind. A top-level name
# alone ("tmp.AbC123") says nothing about which suite or which tool created
# it; the contents usually do.
sweep() {
    find "$1" -mindepth 1 > "$2" 2>/dev/null
    [[ -s "$2" ]]
}

# leak_message <name> <k> <n> <seconds> <dir> <list-file> [late]: the
# exit-2 message, on stderr. Capped at $LEAK_LIST_MAX lines so a suite that
# leaks a whole source tree does not bury its own failure message — the
# tail is summarised as a count. With "late", the entries were found by the
# sweep after every suite had finished.
leak_message() {
    local name="$1" k="$2" n="$3" secs="$4" dir="$5" list="$6" late="${7:-}"
    local leaked=() word
    mapfile -t leaked < "$list"
    if [[ ${#leaked[@]} -eq 1 ]]; then word=entry; else word=entries; fi
    echo "" >&2
    if [[ -z "$late" ]]; then
        echo "run_script_tests: FAILED at $name (suite $k of $n) after ${secs}s — it left ${#leaked[@]} $word behind in TMPDIR ($dir):" >&2
    else
        echo "run_script_tests: FAILED at $name (suite $k of $n) — after every suite had finished, its TMPDIR ($dir) held ${#leaked[@]} $word, written after it exited by a process it left running:" >&2
    fi
    printf '%s\n' "${leaked[@]:0:$LEAK_LIST_MAX}" >&2
    if [[ ${#leaked[@]} -gt $LEAK_LIST_MAX ]]; then
        echo "... and $(( ${#leaked[@]} - LEAK_LIST_MAX )) more entries (listing truncated)" >&2
    fi
    echo "Every suite must clean up what it creates — one top-level sandbox plus an EXIT trap (see issue #297)." >&2
}

# --- Start order, as indices into run_suites ---
# List order at one job. With more than one job, largest file first: a
# free stand-in for slowest first, so the longest suite does not start
# last; ties in list order. --shuffle replaces either with an order drawn
# from the seed (the checksum of "<seed>:<suite name>"), the same for the
# same seed and suites, and prints the seed so the order can be repeated.
# The order a suite starts in never changes which suite's failure sets the
# exit code of a parallel run: that is always by list order.
order=()
if (( shuffle )); then
    echo "run_script_tests: shuffle seed $shuffle_seed (this order again: --shuffle=$shuffle_seed)"
    mapfile -t order < <(
        for i in "${!run_suites[@]}"; do
            printf '%s %d\n' "$(printf '%s:%s' "$shuffle_seed" "$(basename "${run_suites[$i]}")" | cksum | cut -d' ' -f1)" "$i"
        done | sort -k1,1n -k2,2n | cut -d' ' -f2
    )
elif (( jobs > 1 )); then
    mapfile -t order < <(
        for i in "${!run_suites[@]}"; do
            printf '%d %d\n' "$(( $(wc -c < "${run_suites[$i]}") ))" "$i"
        done | sort -k1,1nr -k2,2n | cut -d' ' -f2
    )
else
    order=("${!run_suites[@]}")
fi

start_ts=$(date +%s)

# --- More than one job (issue #444): see "Parallel runs" in the header ---
if (( jobs > 1 )); then
    n=${#run_suites[@]}
    declare -A job_of=()   # pid of a running job (its process group) -> suite index
    started=() secs=() rcs=() status=()   # by suite index; status: pass, fail, leak, late
    running=0
    next=0
    finished=0

    # now_us: the time in microseconds (EPOCHREALTIME without its point,
    # whatever the locale's decimal separator).
    now_us() { printf '%s' "${EPOCHREALTIME//[!0-9]/}"; }

    # The process groups of suites that have exited but left a process
    # running in their group: pid -> suite index. A group joins when its
    # suite is reaped with something still in it, and leaves once it is
    # empty (pruned on every reap and read by live_groups), so a stop also
    # reaches what an earlier suite left behind. An empty group is dropped
    # rather than kept, because its number can then be reused.
    declare -A lingering=()

    # live_groups: set `live` to every process group of this run that still
    # has a process in it: the running suites (job_of), the groups suites
    # left behind (lingering), and any background job bash still lists
    # (`jobs -p`), since a signal can land between a suite's `&` and its
    # job_of entry.
    live_groups() {
        local p
        live=()
        # shellcheck disable=SC2046  # pids: one word each
        for p in "${!job_of[@]}" "${!lingering[@]}" $(jobs -p); do
            [[ " ${live[*]} " != *" $p "* && "$p" != "$stop_watchdog" ]] || continue
            if kill -0 -- "-$p" 2>/dev/null; then
                live+=("$p")
            else
                unset 'lingering[$p]'
            fi
        done
    }

    # stop_suites <sig>: stop every live process group of this run
    # (live_groups). <sig> first, so a suite's own trap, and those of the
    # processes it started, can clean up; they have until 5 seconds after
    # <sig> was sent. KILL goes to whatever is left in those groups then,
    # and not before: a suite that has exited may leave a child still
    # cleaning up in its group, and that child is given the same 5 seconds.
    # A watchdog sends the KILL while the runner waits for a suite that
    # ignores <sig>.
    stop_suites() {
        local sig="$1" pids=() p t_end left live=()
        stop_underway=1
        live_groups
        pids=("${live[@]}")
        (( ${#pids[@]} )) || return 0
        for p in "${pids[@]}"; do kill -s "$sig" -- "-$p" 2>/dev/null; done
        t_end=$(( $(now_us) + 5000000 ))
        set -m
        (
            sleep 5
            for p in "${pids[@]}"; do kill -s KILL -- "-$p" 2>/dev/null; done
        ) </dev/null >/dev/null 2>&1 {runner_err}>&- &
        stop_watchdog=$!
        set +m
        # A lingering group's leader is already reaped: wait returns at once
        # for it, and the loop below waits for the rest of its group.
        wait "${pids[@]}" 2>/dev/null
        # The suites have exited; what they started may still be in their
        # groups, cleaning up. Wait for it, up to the same deadline.
        while (( $(now_us) < t_end )); do
            left=0
            for p in "${pids[@]}"; do
                kill -0 -- "-$p" 2>/dev/null && { left=1; break; }
            done
            (( left )) || break
            sleep 0.1
        done
        kill -s KILL -- "-$stop_watchdog" 2>/dev/null
        # The deadline has passed for whatever is still there.
        for p in "${pids[@]}"; do kill -s KILL -- "-$p" 2>/dev/null; done
    }

    # kill_now: KILL every live process group of this run, and the watchdog
    # of a stop under way, at once. For a stop cut short (see cleanup_run).
    kill_now() {
        local p live=()
        live_groups
        if (( ${#live[@]} )); then
            echo "run_script_tests: stop cut short; KILLing ${#live[@]} process group(s) at once" >&"$runner_err"
        fi
        for p in "${live[@]}"; do kill -s KILL -- "-$p" 2>/dev/null; done
        [[ -z "$stop_watchdog" ]] || kill -s KILL -- "-$stop_watchdog" 2>/dev/null
    }

    # A signal stops every running suite (stop_suites) with that signal;
    # the EXIT trap then removes $RUN_ROOT. The traps are reset first, so a
    # second signal ends the runner, and the EXIT trap then KILLs at once.
    on_interrupt() {
        local sig="$1" code="$2"
        trap - INT TERM HUP
        stop_underway=1
        echo "" >&2
        echo "run_script_tests: interrupted (SIG$sig); stopping ${#job_of[@]} running suite(s)" >&2
        stop_suites "$sig"
        exit "$code"
    }
    # From here the EXIT trap stops any suite still running.
    exec {runner_err}>&2
    parallel=1
    trap 'on_interrupt INT 130' INT
    trap 'on_interrupt TERM 143' TERM
    trap 'on_interrupt HUP 129' HUP

    # start_job <index>: start a suite in the background, in a process
    # group of its own. `set -m` is what gives it the group, and it also
    # keeps SIGINT and SIGQUIT at their defaults: without job control bash
    # starts a background job with both ignored, and a suite could then
    # never trap them, as it can when it runs in the foreground at -j 1.
    # stdin is /dev/null, so a suite cannot block on reading it.
    start_job() {
        local i="$1" name dir
        name="$(basename "${run_suites[$i]}")"
        dir="$(suite_tmp "$name")"
        mkdir -p "$dir"
        echo "=== run_script_tests: running $name ==="
        started[i]=$EPOCHSECONDS
        set -m
        TMPDIR="$dir" TMP="$dir" TEMP="$dir" bash "${run_suites[$i]}" \
            > "$RUN_ROOT/out/$i.log" 2>&1 < /dev/null {runner_err}>&- &
        set +m
        job_of[$!]=$i
        running=$((running + 1))
    }

    while (( next < n || running > 0 )); do
        while (( running < jobs && next < n )); do
            start_job "${order[$next]}"
            next=$((next + 1))
        done
        done_pid=""
        wait -n -p done_pid "${!job_of[@]}"
        rc=$?
        if [[ -z "$done_pid" || -z "${job_of[$done_pid]+set}" ]]; then
            echo "error: lost track of the running suites (wait returned $rc)" >&2
            exit 1
        fi
        i=${job_of[$done_pid]}
        unset 'job_of[$done_pid]'
        # A process the suite left running in its group keeps the group;
        # remember it for stop_suites (see lingering), and drop the
        # groups that have emptied since.
        for p in "${!lingering[@]}"; do
            kill -0 -- "-$p" 2>/dev/null || unset 'lingering[$p]'
        done
        if kill -0 -- "-$done_pid" 2>/dev/null; then lingering[$done_pid]=$i; fi
        running=$((running - 1))
        finished=$((finished + 1))
        secs[i]=$(( EPOCHSECONDS - started[i] ))
        name="$(basename "${run_suites[$i]}")"
        if (( rc != 0 )); then
            status[i]=fail
            rcs[i]=$rc
            verdict="FAILED, exit $rc,"
        elif sweep "$(suite_tmp "$name")" "$RUN_ROOT/out/$i.leak"; then
            status[i]=leak
            verdict="FAILED, left files in its TMPDIR,"
        else
            status[i]=pass
            verdict="passed"
        fi
        echo "--- run_script_tests: $name $verdict in ${secs[i]}s ($finished of $n done)"
    done
    trap - INT TERM HUP

    # The second sweep, after every suite has finished.
    for i in "${!run_suites[@]}"; do
        if [[ "${status[i]}" == pass ]] \
                && sweep "$(suite_tmp "$(basename "${run_suites[$i]}")")" "$RUN_ROOT/out/$i.late"; then
            status[i]=late
        fi
    done

    # print_log <index>: a suite's captured output, whole.
    print_log() {
        local log="$RUN_ROOT/out/$1.log"
        cat "$log"
        [[ ! -s "$log" || -z "$(tail -c 1 "$log")" ]] || echo
    }

    # Failures first, in list order, each suite's output whole; the exit
    # code is the one a one-job run gives for the first of them.
    exit_code=0
    late_seen=0
    failed_names=()
    for i in "${!run_suites[@]}"; do
        [[ "${status[i]}" == pass ]] && continue
        k=$((i + 1))
        name="$(basename "${run_suites[$i]}")"
        dir="$(suite_tmp "$name")"
        failed_names+=("$name")
        echo ""
        echo "===== FAILED: $name ====="
        print_log "$i"
        echo "===== end of $name ====="
        case "${status[i]}" in
            fail)
                echo "run_script_tests: FAILED at $name (suite $k of $n) after ${secs[i]}s, exit ${rcs[i]}" >&2
                (( exit_code != 0 )) || exit_code=1
                ;;
            leak)
                leak_message "$name" "$k" "$n" "${secs[i]}" "$dir" "$RUN_ROOT/out/$i.leak"
                (( exit_code != 0 )) || exit_code=2
                ;;
            late)
                leak_message "$name" "$k" "$n" "" "$dir" "$RUN_ROOT/out/$i.late" late
                late_seen=1
                ;;
        esac
    done
    (( exit_code != 0 || late_seen == 0 )) || exit_code=2

    if (( show_passed )); then
        for i in "${!run_suites[@]}"; do
            [[ "${status[i]}" == pass ]] || continue
            echo ""
            echo "===== passed: $(basename "${run_suites[$i]}") ====="
            print_log "$i"
        done
    fi

    echo ""
    echo "run_script_tests: suite times, slowest first:"
    for i in "${!run_suites[@]}"; do
        printf '%d %d\n' "${secs[i]}" "$i"
    done | sort -k1,1nr -k2,2n | while read -r t i; do
        printf '  %4ss  %-6s %s\n' "$t" "${status[i]}" "$(basename "${run_suites[$i]}")"
    done

    elapsed=$(( $(date +%s) - start_ts ))
    echo ""
    if (( exit_code != 0 )); then
        list=""
        for name in "${failed_names[@]}"; do list+="${list:+, }$name"; done
        echo "run_script_tests: ${#failed_names[@]} of $n suites failed in ${elapsed}s: $list" >&2
        exit "$exit_code"
    fi
    if [[ "$selection" == "scoped" ]]; then
        echo "run_script_tests: all $n suites passed in ${elapsed}s (scoped run, $n of ${#suites[@]})"
    else
        echo "run_script_tests: all $n suites passed in ${elapsed}s"
    fi
    exit 0
fi

# --- One job: every suite in the foreground, in list order (or the
#     shuffled order), its output live; the first failure or leak stops the
#     run. "suite k of n" is the suite's place in list order. ---
total=0
for i in "${order[@]}"; do
    s="${run_suites[$i]}"
    k=$((i + 1))
    name="$(basename "$s")"
    total=$((total + 1))
    dir="$(suite_tmp "$name")"
    mkdir -p "$dir"
    echo "=== run_script_tests: running $name ==="
    if ! TMPDIR="$dir" TMP="$dir" TEMP="$dir" bash "$s"; then
        end_ts=$(date +%s)
        elapsed=$((end_ts - start_ts))
        echo "" >&2
        echo "run_script_tests: FAILED at $name (suite $k of ${#run_suites[@]}) after ${elapsed}s — stopping, remaining suites not run" >&2
        exit 1
    fi

    # Leak sweep — see "Per-suite TMPDIR guard" above. Runs only on the
    # path that would otherwise advance to the next suite.
    if sweep "$dir" "$RUN_ROOT/out/$i.leak"; then
        end_ts=$(date +%s)
        elapsed=$((end_ts - start_ts))
        leak_message "$name" "$k" "${#run_suites[@]}" "$elapsed" "$dir" "$RUN_ROOT/out/$i.leak"
        exit 2
    fi
done

# The second sweep, after every suite has finished (see the guard above).
late=0
k=0
for s in "${run_suites[@]}"; do
    name="$(basename "$s")"
    k=$((k + 1))
    dir="$(suite_tmp "$name")"
    if sweep "$dir" "$RUN_ROOT/out/$k.late"; then
        leak_message "$name" "$k" "${#run_suites[@]}" "" "$dir" "$RUN_ROOT/out/$k.late" late
        late=1
    fi
done
[[ $late -eq 0 ]] || exit 2

end_ts=$(date +%s)
elapsed=$((end_ts - start_ts))
echo ""
if [[ "$selection" == "scoped" ]]; then
    echo "run_script_tests: all $total suites passed in ${elapsed}s (scoped run, $total of ${#suites[@]})"
else
    echo "run_script_tests: all $total suites passed in ${elapsed}s"
fi
exit 0
