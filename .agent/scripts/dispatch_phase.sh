#!/bin/bash
# .agent/scripts/dispatch_phase.sh
# In-process phase handoff for the run-issue loop (issue #276 PR 2). Replaces
# the fork's dispatch_subagent.sh minus every container clause (issue #276
# decision, 2026-09-17: auto mode replaced containers; in-process only).
#
# Every mode takes --issue as a bare <N> or, for an issue of a package
# repository in a multi-repository project (ADR-0012), as <owner/repo#N>.
# The ref finds the worktree; the directory a phase and the host work in,
# and every timeline path, is that worktree, except for a package worktree
# (a .worktree-repos manifest), where it is the checkout of the repository
# that owns the issue (its entry on feature/issue-<N>). resolve_issue_dir
# below decides it in one place; the handoff names it as worktree= and
# adds package_worktree=<top folder>. Two package worktrees for one bare
# number are refused with their qualified refs listed (issue 429).
#
# Usage:
#   dispatch_phase.sh where --issue <N|owner/repo#N> [--type workspace|project]
#                      [--project <name>]
#     Prints that directory, one line: run-issue step 1 `cd`s there and
#     builds every progress path from it. For a package issue it, like the
#     handoff, first checks that `gh` run there resolves the issue's own
#     repository and refuses on a mismatch (a checkout with an `upstream`
#     remote), naming both and `gh repo set-default <owner/repo>`.
#
#   dispatch_phase.sh base --issue <N|owner/repo#N> [--base <branch>]
#                      [--type workspace|project] [--project <name>]
#                      [--layer <l> --package-repos <a,b>]
#     The base branch of a package issue's pull request (issue 429), one
#     line `base=<branch>`: the branch the owning repository's
#     feature/issue-<N> starts from and its pull request targets. It comes
#     from the project's pin (_pr_base.sh pr_base_for: adapter repo_pin,
#     ADR-0019), or from --base, the owner's override; never from the
#     forge's default branch. Whether there is a package base is decided by
#     the worktree the ref resolves to, not by how the ref is written (a
#     unique bare number can resolve to a package worktree):
#       - a package worktree (a manifest whose issue checkout is not the
#         worktree itself): its header's base= is the answer, and a --base
#         that differs is refused. A header with no base= (a worktree made
#         before the field) gets one: the candidate (--base, else the pin)
#         is written (wt_set_manifest_base) only after the owning branch is
#         checked against origin in the owning checkout
#         (wt_base_foreign_history, one bounded fetch): no commit beyond
#         origin's <base> that another origin branch also has. Commits
#         from another branch (a branch started from origin's default
#         when the pin is another), origin lacking the base, or origin not
#         answering each refuse and write nothing. --layer, when given,
#         must be the header's layer, and --package-repos the set of
#         repositories the manifest holds; a mismatch is refused. The
#         header's project= is passed to the adapter only when it is a
#         registered project (a legacy layout writes project=project).
#       - any other worktree (workspace, single-repository project, a lone
#         "." manifest): no package base. Prints nothing, exit 0; --base,
#         --layer or --package-repos is refused.
#       - no worktree yet: with --layer and --package-repos (a package
#         worktree about to be made, as worktree_create.sh takes them) the
#         owning entry comes from `adapter worktree_repos` (the one on
#         feature/issue-<N>) and its directory name is the repository whose
#         pin is read; run-issue passes the answer to worktree_create.sh
#         --base. A qualified ref without them is refused (nothing says
#         which package worktree); a bare number without them is no package
#         base (prints nothing, exit 0).
#
#   dispatch_phase.sh --issue <N> --skill <phase> [--type workspace|project]
#                      [--project <name>]
#                      [--pr <M>] [--prompt-file <f>] [--entry-type <T>]
#                      [--model <alias>] [--skill-prefix <name>:]
#     Prints the handoff block for a phase the host is about to dispatch
#     via the Agent tool: the worktree, the phase's literal task line (per
#     the plan's per-skill table), the commit identity, the model to stamp
#     in **By**, the expected entry type, the exit contract, and the
#     workspace conventions every dispatched phase must follow. Output is
#     `key=value` lines, one per line, in this order: worktree,
#     package_worktree (only for a package issue), base (only for a package
#     issue whose manifest records base=; `base` above records it), task, agent_name,
#     agent_email, model, entry_type, exit_contract, conventions, and
#     prompt_file (only when --prompt-file was given). agent_email is the
#     AGENT_EMAIL the host exported when it sourced set_git_identity_env.sh
#     (with --agent / --detect, derived from the checkout's git user.email,
#     issue #455); no address is held here. conventions tells
#     the phase to start every command chain with `cd <worktree> &&`.
#     For `implement` and `address-findings` in a workspace handoff,
#     conventions also carries the once-per-pass hook rule (owner-decided
#     2026-10-20, issue #399): SKIP=validate-script-tests on intermediate
#     commits only, one `pre-commit run --files` over the branch's changed
#     files before the entry (it runs the script suites those files reach,
#     issue #410), CI as the backstop; other phases and project handoffs
#     carry none.
#     --skill-prefix (default empty) namespaces every slash command in the
#     task line, e.g. `agent-workspace:` gives `/agent-workspace:review-code`
#     -- for a host whose workspace skills came from the plugin (ADR-0018).
#     A pre-push review-code task line at round 3 or later (as
#     `review_progress.sh round` counts it: complete reviews on the branch
#     after the newest restart checkpoint, the same rule as `next`) ends
#     with its scope and the words "no cross-model reviewers" (issue 321,
#     the round-3 exception).
#
#   dispatch_phase.sh --check-exit --issue <N> --skill <phase>
#                      [--type workspace|project] [--project <name>]
#                      [--pr <M>] --before <count>
#     Compares the entry count of the expected type (same table as above)
#     before and after a dispatch. Prints `status=<OK|PARTIAL|FAILED|MISSING>`
#     and, only for OK, a second line `sha=<short git sha>` (the worktree's
#     HEAD after the phase's own commit). For `--skill implement` and
#     `--skill address-findings`, a complete `## Implementation` entry with no
#     `**PR**` / `**Branch**` correlation line is PARTIAL, not OK, with a
#     `reason=` line saying so — that line is required by both handoffs' exit
#     contracts and by merge_pr.sh's head-vs-review gate.
#
#   dispatch_phase.sh next --issue <N> --pr <none|draft|open|merged>
#                      [--type workspace|project] [--project <name>]
#                      [--progress <file>]
#     The run-issue decision table (28 rows; see the plan for #276 PR 2).
#     Prints `action=<token>`, `reason=<one line>`, then `round=<n>` when
#     the action concerns the pre-push review loop, `phase=<skill>` when a
#     checkpoint:phase-failed / retry / takeover names a failed phase, and
#     `mode=inline` when the action is to be run by the host itself (row 27,
#     a takeover, is the only row that still prints it — `implement` is
#     dispatched like every other phase since issue #314). No
#     `gh` call inside `next`, ever — `--pr` is the only non-timeline input.
#
# Exit codes:
#   next:        0 action decided; 2 usage (including no worktree for
#                --issue, a --progress path that does not exist, or one the
#                records gate refuses); 3 the
#                timeline could not be parsed (progress_read.py's message
#                stays on stderr).
#   handoff /
#   --check-exit: 0 ok; 2 usage (including no worktree, unknown --skill,
#                missing --pr for triage-reviews, or AGENT_NAME/AGENT_EMAIL
#                unset); 3 the timeline could not be parsed.
#   where /
#   handoff:     2 also when the package worktree has no single entry on
#                feature/issue-<N>, or gh resolves another repository there.
#   base:        0 printed the base, or nothing for an issue with no package
#                base; 2 refused (usage, no single owning entry, a pin that
#                is not a branch or cannot be read, a --base that differs
#                from the recorded one, a --layer or --package-repos
#                that does not match the manifest, and on resume: the
#                owning branch carrying another origin branch's commits
#                beyond the base, origin lacking the base or not
#                answering), the reason on stderr.
#
# See docs/decisions/0013-progress-md-entry-type-vocabulary.md for the
# entry-type vocabulary and .agent/work-plans/issue-276/ for the plan.

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    echo "Error: This script should be executed, not sourced." >&2
    return 1
fi
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Resolve the main tree root via `git worktree list`, not $SCRIPT_DIR/../..,
# so this is correct when invoked from inside a worktree (run-issue enters
# the issue's worktree before dispatching phases from it) — same fix as
# merge_pr.sh's ROOT_DIR resolution (issue #146).
ROOT_DIR=$({ git -C "$SCRIPT_DIR" worktree list --porcelain 2>/dev/null \
    | head -n1 | sed 's/^worktree //'; } || true)
if [[ -z "$ROOT_DIR" ]]; then
    echo "error: dispatch_phase.sh must run from within a git repository" >&2
    exit 2
fi

# shellcheck source=_worktree_helpers.sh
source "$SCRIPT_DIR/_worktree_helpers.sh"
# issue_checkout_of: the owning-checkout rule; records_path: the records
# gate every records reader and writer passes (issue 429).
# shellcheck source=_resolve_work_plans_dir.sh
source "$SCRIPT_DIR/_resolve_work_plans_dir.sh"

PROGRESS_READ="$SCRIPT_DIR/progress_read.py"
PYTHON="${PYTHON:-python3}"

usage() {
    cat >&2 <<'EOF'
Usage (--issue takes <N> or <owner/repo#N> in every mode):
  dispatch_phase.sh where --issue <N> [--type workspace|project] [--project <name>]
  dispatch_phase.sh base --issue <N> [--base <branch>] [--type workspace|project]
                     [--project <name>] [--layer <l> --package-repos <a,b>]
  dispatch_phase.sh --issue <N> --skill <phase> [--type workspace|project]
                     [--project <name>] [--pr <M>] [--prompt-file <f>]
                     [--entry-type <T>] [--model <alias>]
                     [--skill-prefix <name>:]
  dispatch_phase.sh --check-exit --issue <N> --skill <phase>
                     [--type workspace|project] [--project <name>]
                     [--pr <M>] --before <count>
  dispatch_phase.sh next --issue <N> --pr <none|draft|open|merged>
                     [--type workspace|project] [--project <name>]
                     [--progress <file>]

--project <name> names the registered project for --type project; when
omitted it is derived from $PWD via the registry (longest-prefix match).
See the header comment of this script for what each mode prints.
Exit codes: 0 ok; 2 usage; 3 the timeline could not be parsed.
EOF
    exit 2
}

# ------------------------------------------------------- project selection ---
# Which registered project a `--type project` dispatch belongs to (#317,
# #265 PR 3). Kept as its own function so resolve_worktree() below stays a
# thin caller.
#
# Precedence:
#   1. an explicit --project <name> (always wins; not validated here — an
#      unknown name simply finds no worktree, same as today's miss path),
#   2. the project owning $PWD, via registry_resolve_from_dir's
#      longest-prefix ancestor match. This is a direct registry call on the
#      real cwd: the SessionStart hook's stdout is context text for the
#      model, never environment in a tool-call shell, so nothing the hook
#      printed is trusted here (ADR-0016, the workspace-root idiom).
#   3. nothing — the caller falls back to the historical "exactly one
#      project is registered" behaviour, so existing callers that pass
#      neither a name nor a resolvable cwd behave exactly as before.
#
# Prints the project name and returns 0, or returns 1 when undetermined.
derive_project_name() {
    local explicit="${1:-}" entry name
    if [[ -n "$explicit" ]]; then
        printf '%s\n' "$explicit"
        return 0
    fi
    entry=$(registry_resolve_from_dir "$ROOT_DIR" "$PWD" 2>/dev/null) || entry=""
    if [[ -n "$entry" ]]; then
        name="${entry%%$'\t'*}"
        if [[ -n "$name" ]]; then
            printf '%s\n' "$name"
            return 0
        fi
    fi

    # NOTE ON SCOPE: this second pass matches the cwd against every REGISTERED
    # project's worktree dir, whatever `worktrees=` points at -- it is not
    # limited to overrides that land under the workspace root. That is
    # deliberate (the default location is matched by the same code, harmlessly,
    # since a cwd there is usually under the hosting dir anyway), but it does
    # mean a project whose `worktrees=` points somewhere surprising is matched
    # too. The hosting-dir pass above still runs first, and an explicit
    # --project still overrides both.
    #
    # registry_resolve_from_dir matches a cwd against each project's HOSTING
    # dir. A project whose registry line carries a `worktrees=` override puts
    # its worktrees somewhere else -- commonly back under the workspace root --
    # and a cwd inside one of those is under no hosting dir at all. Without
    # this second pass a session sitting in its own project worktree derives
    # nothing, falls through to the "exactly one registered" branch, and on a
    # multi-project machine reports "no project worktree found" while standing
    # in the worktree.
    local wt_name wt_dir abs rp best="" best_len=0
    abs="$(cd "$PWD" 2>/dev/null && pwd -P)" || return 1
    while IFS=$'\t' read -r wt_name wt_dir; do
        [[ -z "$wt_dir" ]] && continue
        rp="$(cd "$wt_dir" 2>/dev/null && pwd -P)" || continue
        if [[ "$abs" == "$rp" || "$abs" == "$rp/"* ]]; then
            # Longest match wins, as in registry_resolve_from_dir.
            if [[ "${#rp}" -gt "$best_len" ]]; then
                best="$wt_name"
                best_len=${#rp}
            fi
        fi
    done < <(wt_registry_worktree_dirs "$ROOT_DIR" 2>/dev/null)

    [[ -n "$best" ]] || return 1
    printf '%s\n' "$best"
    return 0
}

# --------------------------------------------------------- worktree lookup ---
# Locates issue <N>'s worktree exactly as worktree_enter.sh --type <type>
# would (new location, then the pre-registration transition location for a
# registered project, then the legacy location).
#
# For `--type project`, <project> (optional) names the project: passed
# explicitly via --project, or derived from $PWD by derive_project_name().
# When neither yields a name, the historical path applies — a project type
# resolves only when exactly one project is registered or a legacy project/
# checkout exists.
resolve_worktree() {
    local issue="$1" type="$2" project="${3:-}"
    local new_base="" legacy_base="" transition_base=""

    if [[ "$type" == "workspace" ]]; then
        new_base=$(wt_workspace_base "$ROOT_DIR")
        legacy_base=$(wt_legacy_workspace_base "$ROOT_DIR")
    else
        local selected=""
        selected=$(derive_project_name "$project") || selected=""
        if [[ -n "$selected" ]]; then
            new_base=$(wt_project_base "$ROOT_DIR" "$selected")
            transition_base=$(wt_transition_project_base "$ROOT_DIR" "$selected" 2>/dev/null || true)
        else
            local -a names=()
            local cname cdir n
            while IFS=$'\t' read -r cname cdir; do
                [[ -z "$cdir" ]] && continue
                n=0
                for existing in "${names[@]:-}"; do
                    [[ "$existing" == "$cname" ]] && { n=1; break; }
                done
                [[ "$n" -eq 0 ]] && names+=("$cname")
            done < <(wt_registry_worktree_dirs "$ROOT_DIR" 2>/dev/null; wt_legacy_worktree_dirs "$ROOT_DIR" 2>/dev/null)
            if [[ "${#names[@]}" -eq 1 ]]; then
                new_base=$(wt_project_base "$ROOT_DIR" "${names[0]}")
                transition_base=$(wt_transition_project_base "$ROOT_DIR" "${names[0]}" 2>/dev/null || true)
            fi
        fi
        legacy_base=$(wt_legacy_project_base "$ROOT_DIR")
    fi

    # find_worktree_by_issue prints the path on success and nothing on
    # stderr, or prints nothing on stdout and its guidance on stderr (two
    # package worktrees for one bare number list their qualified refs), so
    # one capture of both streams tells them apart. That guidance is passed
    # through (return 2) rather than reported as "no worktree found".
    local base out
    for base in "$new_base" "$transition_base" "$legacy_base"; do
        [[ -n "$base" ]] || continue
        if out=$(find_worktree_by_issue "$base" "$issue" "" 2>&1); then
            echo "$out"; return 0
        fi
        if [[ -n "$out" ]]; then
            printf '%s\n' "$out" >&2
            return 2
        fi
    done
    return 1
}

# ------------------------------------------------- the issue's directory ---
# THE one place that decides the directory an issue's work and records
# happen in (issue 429). The worktree resolve_worktree finds is that
# directory, except for a package worktree (a .worktree-repos manifest,
# ADR-0012): there it is the checkout of the repository that owns the
# issue, issue_checkout_of's rule (_resolve_work_plans_dir.sh: the entry on
# feature/issue-<N>). The worktree's top folder is no repository of its
# own, and a sibling checkout carries the same issue number for its own
# repository, so neither is ever handed out. The directory's records path
# passes the records gate (records_path) here too, so every mode below that
# reads or names the timeline (the handoff, `where`, `next`, --check-exit)
# has passed it.
#
# With <check_gh>=1 (handoff and `where`, the two that send someone to work
# there), a package issue also requires that `gh`, run in that checkout,
# resolves the issue's own repository: a checkout with an `upstream`
# remote makes gh pick upstream over origin when no default is set, and
# every bare `gh issue view/comment <N>` a phase runs would then reach the
# upstream project's issue <N>. `next` and --check-exit pass 0: they only
# read the timeline, and `next` never calls gh.
#
# Prints the directory on the first line and, for a package worktree, the
# worktree's top folder on a second line. Returns 1 when no worktree was
# found, 2 when a refusal was already printed on stderr.
resolve_issue_dir() {
    local ref="$1" num="$2" type="$3" project="$4" check_gh="$5"
    local wt rc=0 dir hdr want got
    wt=$(resolve_worktree "$ref" "$type" "$project") || { rc=$?; return "$rc"; }
    dir=$(issue_checkout_of "$wt" "$num") || return 2
    records_path "$dir/.agent/work-plans/issue-$num" "$dir" >/dev/null || return 2
    if [[ "$dir" == "$wt" ]]; then
        echo "$dir"
        return 0
    fi
    hdr=$(head -n1 "$wt/.worktree-repos" | sed -n 's/.* issue=\([^ ]*\).*/\1/p')
    if [[ "$check_gh" == 1 && "$hdr" == */*#* ]]; then
        want="${hdr%#*}"
        # stdout alone is the answer (a notice gh prints on stderr is not a
        # repository name); any failure, or no answer, is a refusal, quoting
        # what gh said on stderr.
        local errf gherr
        errf=$(mktemp) || { echo "error: could not create a temporary file for gh's stderr" >&2; return 2; }
        if ! got=$(cd "$dir" && gh repo view --json nameWithOwner --jq .nameWithOwner 2>"$errf") || [[ -z "$got" ]]; then
            gherr=$(head -c 600 "$errf" | tr '\n' ' ')
            rm -f "$errf"
            echo "error: could not ask gh which repository it resolves from $dir (needed before work on $hdr starts there): ${gherr:-gh gave no answer}" >&2
            return 2
        fi
        rm -f "$errf"
        if [[ "${got,,}" != "${want,,}" ]]; then
            {
                echo "error: in $dir, gh resolves $got, but the issue is $hdr (repository $want)."
                echo "  A phase there would read and comment on $got's issue #$num instead. gh prefers a"
                echo "  remote named upstream over origin when no default is set. Set the default:"
                echo "    (cd $dir && gh repo set-default $want)"
            } >&2
            return 2
        fi
    fi
    echo "$dir"
    echo "$wt"
}

# parse_issue_ref <ref> <mode> -- a bare number, or owner/repo#N (a package
# issue, ADR-0012). Prints the number; refuses anything else.
parse_issue_ref() {
    local ref="$1" mode="$2"
    if [[ "$ref" =~ ^[0-9]+$ ]]; then
        echo "$ref"; return 0
    fi
    if [[ "$ref" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+#([0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]}"; return 0
    fi
    echo "error: $mode: --issue <N> or --issue <owner/repo#N> is required (got '$ref')" >&2
    return 1
}

# report_resolve_failure <mode> <rc> <type> <ref> -- rc 1 is "none found";
# rc 2 was already explained on stderr.
report_resolve_failure() {
    local shown="$4"
    [[ "$shown" =~ ^[0-9]+$ ]] && shown="#$shown"
    [[ "$2" -eq 1 ]] && echo "error: $1: no $3 worktree found for issue $shown" >&2
    exit 2
}

# ------------------------------------------------ per-skill task/entry/model ---
# The literal per-skill task line (verified against each SKILL.md usage
# block), the ADR-0013 entry type the dispatch is expected to write, and the
# model tier (owner decision, 2026-09-17). `review-code` and `triage-reviews`
# are mode-aware on `--pr`; every other skill ignores it.
#
# <prefix> (the --skill-prefix value, default empty) goes between the `/` and
# the skill name of every slash command: `agent-workspace:` when the HOST
# session loaded its workspace skills through the agent-workspace plugin
# (ADR-0018), where the bare name may be a project's own same-named skill.
# It is deliberately a caller-supplied string, not derived from --type or
# $PWD: the issue type says nothing about which skill set the host loaded
# (a workspace-hosted session driving a project issue has bare skills only).
skill_task_line() {
    local skill="$1" issue="$2" pr="$3" prefix="${4:-}"
    case "$skill" in
        review-issue)     echo "/${prefix}review-issue $issue" ;;
        plan-task)        echo "/${prefix}plan-task $issue --no-pr" ;;
        review-plan)      echo "/${prefix}review-plan --issue $issue" ;;
        review-code)
            if [[ -n "$pr" ]]; then echo "/${prefix}review-code $pr"
            else echo "/${prefix}review-code --branch --issue $issue"; fi
            ;;
        triage-reviews)   echo "/${prefix}triage-reviews $pr" ;;
        address-findings) echo "/${prefix}address-findings --issue $issue" ;;
        # No `/implement` slash command exists — the post-plan implementation
        # pass is dispatched with a literal instruction instead (issue #314).
        implement)        echo "implement the plan at .agent/work-plans/issue-$issue/plan.md on this branch" ;;
        *) return 1 ;;
    esac
}

skill_entry_type() {
    local skill="$1" pr="$2"
    case "$skill" in
        review-issue)     echo "Issue Review" ;;
        plan-task)        echo "Plan Authored" ;;
        review-plan)      echo "Plan Review" ;;
        review-code)
            if [[ -n "$pr" ]]; then echo "Local Review"
            else echo "Local Review (Pre-Push)"; fi
            ;;
        triage-reviews)   echo "Integrated Review" ;;
        address-findings) echo "Implementation" ;;
        implement)        echo "Implementation" ;;
        *) return 1 ;;
    esac
}

skill_model() {
    local skill="$1"
    case "$skill" in
        review-issue|plan-task) echo "sonnet" ;;
        review-plan|review-code|triage-reviews|address-findings|implement) echo "opus" ;;
        *) return 1 ;;
    esac
}

# triage-reviews always needs a PR number; every other skill's task line and
# entry type are well-defined without one.
skill_requires_pr() {
    [[ "$1" == "triage-reviews" ]]
}

# --------------------------------------------------------------- handoff ---
cmd_handoff() {
    local issue="" skill="" type="workspace" project="" pr="" prompt_file="" entry_type_override="" model_override="" skill_prefix=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --issue)       [[ $# -ge 2 ]] || usage; issue="$2"; shift 2 ;;
            --skill-prefix) [[ $# -ge 2 ]] || usage; skill_prefix="$2"; shift 2 ;;
            --skill)       [[ $# -ge 2 ]] || usage; skill="$2"; shift 2 ;;
            --type)        [[ $# -ge 2 ]] || usage; type="$2"; shift 2 ;;
            --project)     [[ $# -ge 2 ]] || usage; project="$2"; shift 2 ;;
            --pr)          [[ $# -ge 2 ]] || usage; pr="$2"; shift 2 ;;
            --prompt-file) [[ $# -ge 2 ]] || usage; prompt_file="$2"; shift 2 ;;
            --entry-type)  [[ $# -ge 2 ]] || usage; entry_type_override="$2"; shift 2 ;;
            --model)       [[ $# -ge 2 ]] || usage; model_override="$2"; shift 2 ;;
            *) usage ;;
        esac
    done
    # The qualified ref finds the worktree; the number goes into paths and
    # the task line, because the phase runs in the owning checkout, where
    # `gh issue view <N>` resolves that repository (checked below).
    local ref="$issue"
    issue=$(parse_issue_ref "$ref" dispatch) || exit 2
    [[ -n "$skill" ]] || { echo "error: dispatch: --skill <phase> is required" >&2; exit 2; }
    [[ "$type" == "workspace" || "$type" == "project" ]] || { echo "error: dispatch: --type must be workspace or project" >&2; exit 2; }

    # A plugin namespace is `<name>:`; anything else would print a task line
    # naming no skill at all. Empty (the default) is the bare form.
    if [[ -n "$skill_prefix" && ! "$skill_prefix" =~ ^[a-z0-9][a-z0-9-]*:$ ]]; then
        echo "error: dispatch: --skill-prefix must be empty or a plugin namespace like 'agent-workspace:' (got '$skill_prefix')" >&2
        exit 2
    fi

    if skill_requires_pr "$skill" && [[ -z "$pr" ]]; then
        echo "error: dispatch: --skill $skill requires --pr <M>" >&2
        exit 2
    fi

    local task entry_type model
    task=$(skill_task_line "$skill" "$issue" "$pr" "$skill_prefix") || {
        echo "error: dispatch: unknown --skill '$skill' (expected one of review-issue, plan-task, review-plan, implement, review-code, triage-reviews, address-findings)" >&2
        exit 2
    }
    entry_type=$(skill_entry_type "$skill" "$pr")
    model=$(skill_model "$skill")
    [[ -n "$entry_type_override" ]] && entry_type="$entry_type_override"
    [[ -n "$model_override" ]] && model="$model_override"

    local wt resolved pkg_wt="" pkg_base="" rc=0
    resolved=$(resolve_issue_dir "$ref" "$issue" "$type" "$project" 1) || { rc=$?; report_resolve_failure dispatch "$rc" "$type" "$ref"; }
    wt=$(sed -n 1p <<< "$resolved")
    pkg_wt=$(sed -n 2p <<< "$resolved")
    # The recorded base only: the handoff asks no adapter and no origin.
    # run-issue step 1 (`base`) has recorded it before any phase runs.
    [[ -n "$pkg_wt" ]] && pkg_base=$(head -n1 "$pkg_wt/.worktree-repos" | sed -n 's/.* base=\([^ ]*\).*/\1/p')

    # A pre-push review at round 3 or later is a narrow convergence check
    # with no cross-model reviewers: the owner's standing exception to the
    # fix-round rule (issue 321; review_depth_classification.md, "Round-3
    # convergence check"). The scope goes on the task line, which every host
    # pastes into the dispatch, and review-code step 2 looks for it there.
    # No progress file is round 1. A round that cannot be counted leaves the
    # task line as it is (a full fix-round review) and says so on stderr.
    if [[ "$skill" == "review-code" && -z "$pr" ]]; then
        local progress="$wt/.agent/work-plans/issue-$issue/progress.md" branch="" round_out="" round=""
        if [[ -f "$progress" ]]; then
            if branch=$(git -C "$wt" symbolic-ref --short -q HEAD) \
                && round_out=$("$SCRIPT_DIR/review_progress.sh" round --progress "$progress" --branch "$branch"); then
                round=$(sed -n 's/^round=//p' <<< "$round_out")
            else
                echo "warning: dispatch: could not count the review rounds for issue #$issue (no branch, or an unreadable timeline); the review-code handoff stays a full fix-round review" >&2
            fi
        fi
        if [[ "$round" =~ ^[0-9]+$ && "$round" -ge 3 ]]; then
            task="$task (round $round: a narrow convergence check on the round $((round - 1)) review's findings and the fix diff since it; no cross-model reviewers)"
        fi
    fi

    if [[ -z "${AGENT_NAME:-}" || -z "${AGENT_EMAIL:-}" ]]; then
        echo "error: dispatch: AGENT_NAME/AGENT_EMAIL are not set — source set_git_identity_env.sh first (no fallback to the human's git config)" >&2
        exit 2
    fi

    echo "worktree=$wt"
    # A package worktree's generated env.sh, build.sh and test.sh live in
    # its top folder, not in the owning checkout the phase works in.
    [[ -n "$pkg_wt" ]] && echo "package_worktree=$pkg_wt"
    # The branch the owning repository's pull request targets (issue 429).
    [[ -n "$pkg_base" ]] && echo "base=$pkg_base"
    echo "task=$task"
    echo "agent_name=$AGENT_NAME"
    echo "agent_email=$AGENT_EMAIL"
    echo "model=$model"
    echo "entry_type=$entry_type"
    # `implement` has no SKILL.md of its own (no `/implement` slash command),
    # so its exit contract names the writer and the entry shape outright —
    # otherwise nothing tells the dispatched agent to write the **PR** /
    # **Branch** correlation line ADR-0013 requires of `## Implementation`
    # (issue #314 plan review, finding 1).
    #
    # The script and the skill it names are printed by absolute path, for
    # every issue type: a package issue's phase runs in a package
    # repository's checkout, which has no .agent/scripts or .claude/skills,
    # and a relative path would name a missing file there (issue 429). The
    # workspace is the one this script runs from; %q as for ROOT_DIR below.
    if [[ "$skill" == "implement" ]]; then
        local ws_dir append_q skill_q
        ws_dir="$(cd "$SCRIPT_DIR/../.." && pwd)"
        append_q=$(printf '%q' "$SCRIPT_DIR/progress_append.sh")
        skill_q=$(printf '%q' "$ws_dir/.claude/skills/run-issue/SKILL.md")
        echo "exit_contract=Append exactly one \`## $entry_type\` entry to $wt/.agent/work-plans/issue-$issue/progress.md via \`$append_q $issue --title \"<issue title>\"\` (entry on stdin), in the shape \`$skill_q\` step 4 documents for the dispatched implement pass — the \`**PR**: #<M> at <sha>\` / \`**Branch**: <name> at <sha>\` correlation line included. Commit your work. If you cannot finish, still append it with **Status**: partial or **Status**: failed and say why. Never push — the host owns every push."
    else
        echo "exit_contract=Append exactly one \`## $entry_type\` entry to $wt/.agent/work-plans/issue-$issue/progress.md via the phase's own persistence step. If you cannot finish, still append it with **Status**: partial or **Status**: failed and say why. Never push — the host owns every push."
    fi
    # The once-per-pass hook rule (issue #399, owner-decided 2026-10-20):
    # only the committing passes of a workspace handoff get it. It names a
    # workspace hook and workspace CI, so a project handoff carries none,
    # and no review phase is ever told to skip a hook.
    # ROOT_DIR goes through printf %q because the agent runs the printed
    # command as written: an ordinary path prints unchanged (so the
    # permission allowlist still matches it) and a path with a space or
    # other shell character comes out escaped.
    local pass_rule="" root_q wt_q
    root_q=$(printf '%q' "$ROOT_DIR")
    wt_q=$(printf '%q' "$wt")
    case "$skill" in
        implement|address-findings)
            [[ "$type" == workspace ]] && pass_rule=" Hook rule for this dispatched pass (owner-decided 2026-10-20): set \`SKIP=validate-script-tests\` only on your intermediate atomic commits, never \`--no-verify\`; before writing the entry, run \`$root_q/.venv/bin/pre-commit run --files \$(git diff --name-only main...HEAD)\` once with no SKIP (the main checkout's venv pre-commit: a worktree has no \`.venv\`; the file list is left unquoted because no repo path has a space; in a sub-issue worktree it also covers the parent's files). It runs the script test suites those files reach when a changed file that still exists matches that hook (every suite when the branch deletes an in-scope file or touches a shared helper; a branch whose only in-scope changes are deletions runs none, and CI's all-files run covers that), so run no separate suite; it takes about 2 minutes for a typical fix, about 7 when every suite runs: give the call a long timeout (up to 600000 ms) and wait for its exit, because a run that was backgrounded or cut off has not passed. If it fails, fix it and run the same command again on the final tree. CI (\`make lint\`, every hook on all files) is the backstop."
            ;;
    esac
    # A dispatched sub-agent's shell returns to the session's start folder on
    # every tool call, so a command chain without its own `cd` runs there,
    # not in the worktree, and its commits land in whatever repository that
    # folder is (issue 429 plan review, finding 3).
    echo "conventions=\`**When**\` fields are local time with offset (e.g. \`2026-09-21 14:40 -04:00\`); write scratch files to the session scratchpad, never \`/tmp\` directly, and remove what you create. Start every command chain with \`cd $wt_q &&\`: your shell returns to the session's start folder on each call, so a chain without it runs and commits there.${pass_rule}"
    if [[ -n "$prompt_file" ]]; then
        echo "prompt_file=$prompt_file"
    fi
}

# ------------------------------------------------------------ check-exit ---
cmd_check_exit() {
    local issue="" skill="" type="workspace" project="" pr="" before=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --issue)  [[ $# -ge 2 ]] || usage; issue="$2"; shift 2 ;;
            --skill)  [[ $# -ge 2 ]] || usage; skill="$2"; shift 2 ;;
            --type)   [[ $# -ge 2 ]] || usage; type="$2"; shift 2 ;;
            --project) [[ $# -ge 2 ]] || usage; project="$2"; shift 2 ;;
            --pr)     [[ $# -ge 2 ]] || usage; pr="$2"; shift 2 ;;
            --before) [[ $# -ge 2 ]] || usage; before="$2"; shift 2 ;;
            *) usage ;;
        esac
    done
    local ref="$issue"
    issue=$(parse_issue_ref "$ref" check-exit) || exit 2
    [[ -n "$skill" ]] || { echo "error: check-exit: --skill <phase> is required" >&2; exit 2; }
    [[ "$before" =~ ^[0-9]+$ ]] || { echo "error: check-exit: --before <count> is required (integer)" >&2; exit 2; }
    [[ "$type" == "workspace" || "$type" == "project" ]] || { echo "error: check-exit: --type must be workspace or project" >&2; exit 2; }

    if skill_requires_pr "$skill" && [[ -z "$pr" ]]; then
        echo "error: check-exit: --skill $skill requires --pr <M>" >&2
        exit 2
    fi

    local entry_type
    entry_type=$(skill_entry_type "$skill" "$pr") || {
        echo "error: check-exit: unknown --skill '$skill'" >&2
        exit 2
    }

    local wt resolved rc=0
    resolved=$(resolve_issue_dir "$ref" "$issue" "$type" "$project" 0) || { rc=$?; report_resolve_failure check-exit "$rc" "$type" "$ref"; }
    wt=$(sed -n 1p <<< "$resolved")
    local progress="$wt/.agent/work-plans/issue-$issue/progress.md"

    local json="" count=0
    if [[ -f "$progress" ]]; then
        json=$("$PYTHON" "$PROGRESS_READ" "$progress" --type "$entry_type") || {
            echo "error: check-exit: progress_read.py failed on $progress (malformed file? see message above)" >&2
            exit 3
        }
        # If a single dispatch appends more than one entry of the expected
        # type (a phase that misbehaves and writes twice), only the newest
        # one below is inspected for status=/sha=; the count check above
        # still catches "nothing new appeared" regardless.
        count=$(printf '%s' "$json" | "$PYTHON" -c "import json, sys; print(len(json.load(sys.stdin)[\"entries\"]))")
    fi

    if [[ "$count" -le "$before" ]]; then
        echo "status=MISSING"
        return 0
    fi

    local entry_status entry_corr
    {
        IFS= read -r entry_status
        IFS= read -r entry_corr
    } < <(printf '%s' "$json" | "$PYTHON" -c "import json, sys
e = json.load(sys.stdin)[\"entries\"][-1]
print((e.get(\"status\") or \"\").strip().lower())
print(\"1\" if ((e.get(\"correlation\") or {}).get(\"sha\")) else \"0\")")

    # A `## Implementation` entry is a PR/branch-correlated ADR-0013 type: its
    # `**PR**: #<M> at <sha>` / `**Branch**: <name> at <sha>` line is what the
    # pre-push round counter and merge_pr.sh's head-vs-review gate correlate
    # on, and both handoffs' exit contracts require it. Counting entries and
    # reading **Status** alone would call a correlation-less entry OK and the
    # omission would only surface at the merge gate, so check it here
    # (issue #314 pre-push review, round 1).
    if [[ "$entry_status" == "complete" && "$entry_corr" != "1" ]] \
        && [[ "$skill" == "implement" || "$skill" == "address-findings" ]]; then
        echo "status=PARTIAL"
        echo "reason=the newest ## $entry_type entry has no **PR**/**Branch** correlation line"
        return 0
    fi

    case "$entry_status" in
        complete)
            local sha
            sha=$(git -C "$wt" rev-parse --short HEAD 2>/dev/null || echo "unknown")
            echo "status=OK"
            echo "sha=$sha"
            ;;
        partial) echo "status=PARTIAL" ;;
        failed)  echo "status=FAILED" ;;
        *)       echo "status=MISSING" ;;
    esac
}

# ----------------------------------------------------------------- where ---
# The directory the host works in for this issue (run-issue step 1 `cd`s
# there), and the base of every progress path it builds: the same
# resolve_issue_dir answer the handoff gives a phase as `worktree=`.
cmd_where() {
    local issue="" type="workspace" project=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --issue)   [[ $# -ge 2 ]] || usage; issue="$2"; shift 2 ;;
            --type)    [[ $# -ge 2 ]] || usage; type="$2"; shift 2 ;;
            --project) [[ $# -ge 2 ]] || usage; project="$2"; shift 2 ;;
            *) usage ;;
        esac
    done
    local ref="$issue" num resolved rc=0
    num=$(parse_issue_ref "$ref" where) || exit 2
    [[ "$type" == "workspace" || "$type" == "project" ]] || { echo "error: where: --type must be workspace or project" >&2; exit 2; }
    resolved=$(resolve_issue_dir "$ref" "$num" "$type" "$project" 1) || { rc=$?; report_resolve_failure where "$rc" "$type" "$ref"; }
    # Never print an empty or missing directory with exit 0: run-issue
    # `cd`s into this line and builds every progress path on it.
    local dir
    dir=$(sed -n 1p <<< "$resolved")
    if [[ -z "$dir" || ! -d "$dir" ]]; then
        echo "error: where: no directory for issue $ref (resolved '${dir}')" >&2
        exit 2
    fi
    printf '%s\n' "$dir"
}

# ------------------------------------------------------------------ base ---
# The base branch of a package issue's pull request (issue 429); see the
# header comment for the three cases. Prints `base=<branch>`, or nothing
# for an issue with no package base.
cmd_base() {
    local issue="" type="workspace" project="" layer="" package_repos="" override=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --issue)         [[ $# -ge 2 ]] || usage; issue="$2"; shift 2 ;;
            --type)          [[ $# -ge 2 ]] || usage; type="$2"; shift 2 ;;
            --project)       [[ $# -ge 2 ]] || usage; project="$2"; shift 2 ;;
            --layer)         [[ $# -ge 2 ]] || usage; layer="$2"; shift 2 ;;
            --package-repos) [[ $# -ge 2 ]] || usage; package_repos="$2"; shift 2 ;;
            --base)          [[ $# -ge 2 ]] || usage; override="$2"; shift 2 ;;
            *) usage ;;
        esac
    done
    local ref="$issue" num
    num=$(parse_issue_ref "$ref" base) || exit 2
    [[ "$type" == "workspace" || "$type" == "project" ]] || { echo "error: base: --type must be workspace or project" >&2; exit 2; }
    if [[ -n "$layer" || -n "$package_repos" ]]; then
        [[ "$type" == project ]] || { echo "error: base: --layer/--package-repos are only valid with --type project" >&2; exit 2; }
        [[ -n "$layer" && -n "$package_repos" ]] || { echo "error: base: --layer and --package-repos must be given together" >&2; exit 2; }
    fi
    if [[ -n "$override" ]] && ! git check-ref-format "refs/heads/$override" >/dev/null 2>&1; then
        echo "error: base: --base '$override' is not a valid branch name" >&2
        exit 2
    fi

    local wt="" rc=0
    wt=$(resolve_worktree "$ref" "$type" "$project") || rc=$?
    [[ "$rc" -eq 2 ]] && exit 2

    # pr_base_for is sourced only where a package base is read below.
    local base
    if [[ "$rc" -eq 0 ]]; then
        local dir
        dir=$(issue_checkout_of "$wt" "$num") || exit 2
        if [[ "$dir" == "$wt" ]]; then
            if [[ -n "$override" || -n "$layer" ]]; then
                echo "error: base: issue $ref has the worktree $wt, which is no package worktree (no manifest entry for an owning package repository), so it has no package base; --base, --layer and --package-repos do not apply" >&2
                exit 2
            fi
            return 0
        fi
        # shellcheck source=_pr_base.sh
        source "$SCRIPT_DIR/_pr_base.sh"
        local header hdr_layer hdr_project hdr_base
        header=$(head -n1 "$wt/.worktree-repos")
        hdr_layer=$(sed -n 's/.* layer=\([^ ]*\).*/\1/p' <<< "$header")
        hdr_project=$(sed -n 's/^# project=\([^ ]*\).*/\1/p' <<< "$header")
        hdr_base=$(sed -n 's/.* base=\([^ ]*\).*/\1/p' <<< "$header")
        if [[ -n "$layer" && "$layer" != "$hdr_layer" ]]; then
            echo "error: base: the package worktree $wt for $ref is of layer '${hdr_layer}', not --layer $layer" >&2
            exit 2
        fi
        # --package-repos must name the repositories the worktree was made
        # with (as a set): a different list describes another worktree.
        if [[ -n "$package_repos" ]]; then
            local want have
            want=$(tr ',' '\n' <<< "$package_repos" | sed '/^$/d' | sort -u | paste -sd, -)
            have=$(tail -n +2 "$wt/.worktree-repos" | awk -F'\t' '$2 != "." && $2 != "" { n = split($2, p, "/"); print p[n] }' | sort -u | paste -sd, -)
            if [[ "$want" != "$have" ]]; then
                echo "error: base: the package worktree $wt for $ref was made with the repositories $have, not --package-repos $package_repos; drop --package-repos (the manifest is read), or remove the worktree first to make another" >&2
                exit 2
            fi
        fi
        local -a pargs=(--repo "$(basename "$dir")" --recorded "$hdr_base")
        [[ -n "$hdr_layer" ]] && pargs+=(--layer "$hdr_layer")
        # A legacy layout's header says project=project (worktree_create.sh's
        # fallback when no project is registered): that name is passed only
        # when it is registered, else the adapter finds the project itself.
        if [[ -n "$hdr_project" ]] && registry_lookup "$ROOT_DIR" "$hdr_project" >/dev/null 2>&1; then
            pargs+=(--project "$hdr_project")
        fi
        [[ -n "$override" ]] && pargs+=(--base "$override")
        base=$(pr_base_for "${pargs[@]}") || exit 2
        if [[ -z "$hdr_base" ]]; then
            # A worktree made before base= existed: record the candidate
            # (--base, else the pin) only once the owning branch is known to
            # have started there: no commit beyond origin's <base> that
            # another origin branch has (wt_base_foreign_history; one
            # bounded fetch). Anything else refuses and writes nothing.
            local own="feature/issue-$num" frc=0
            wt_base_foreign_history "$dir" "$own" "$base" || frc=$?
            case "$frc" in
                0) ;;
                1)
                    echo "error: base: $own in $dir carries $WT_FOREIGN_COUNT commit(s) that origin's '$base' does not have and origin's $WT_FOREIGN_FROM has: it did not start from '$base', and a pull request against '$base' would carry them. Nothing was recorded in $wt/.worktree-repos. Recreate the worktree (worktree_create.sh starts the branch from the base), or pass the --base it was started from." >&2
                    exit 2
                    ;;
                2)
                    echo "error: base: origin of $dir has no branch '$base', so it cannot be $ref's base; nothing was recorded in $wt/.worktree-repos. Pass --base with a branch origin has, or push '$base' first." >&2
                    exit 2
                    ;;
                *)
                    echo "error: base: could not check whether $own in $dir started from origin's '$base' ($WT_FOREIGN_REASON); nothing was recorded in $wt/.worktree-repos. Retry when origin answers (for a slow origin, raise WT_FETCH_TIMEOUT, now $(wt_fetch_limit)s)." >&2
                    exit 2
                    ;;
            esac
            wt_set_manifest_base "$wt" "$base" || exit 2
            echo "note: base: recorded base=$base in $wt/.worktree-repos (origin has it, and $own carries no other origin branch's commits beyond it)" >&2
        fi
        echo "base=$base"
        return 0
    fi

    # No worktree yet.
    if [[ -z "$layer" ]]; then
        if [[ "$ref" == */*#* ]]; then
            echo "error: base: issue $ref has no worktree yet, and without --layer and --package-repos nothing says which package worktree would be made (pass them as worktree_create.sh takes them)" >&2
            exit 2
        fi
        if [[ -n "$override" ]]; then
            echo "error: base: --base applies to an issue of a package repository (owner/repo#N, with --layer and --package-repos before its worktree exists); issue $ref has no worktree and names none" >&2
            exit 2
        fi
        return 0
    fi
    if [[ "$ref" != */*#* ]]; then
        echo "error: base: --layer/--package-repos need a qualified --issue owner/repo#N (got '$ref')" >&2
        exit 2
    fi
    local pname="" lines arc=0
    pname=$(derive_project_name "$project") || pname=""
    local -a aargs=()
    [[ -n "$pname" ]] && aargs+=(--project "$pname")
    lines=$("$SCRIPT_DIR/adapter" "${aargs[@]}" worktree_repos --issue "$ref" --layer "$layer" --package-repos "$package_repos") || arc=$?
    if [[ "$arc" -ne 0 ]]; then
        echo "error: base: adapter worktree_repos exited $arc for $ref (its message is above); the owning repository is unknown, so there is no base" >&2
        exit 2
    fi
    local owning n
    owning=$(awk -F'\t' -v b="feature/issue-$num" '$3 == b && $2 != "." { print $2 }' <<< "$lines")
    n=$(grep -c . <<< "$owning" || true)
    if [[ "$n" -ne 1 ]]; then
        echo "error: base: $n of --package-repos $package_repos would be on feature/issue-$num, so the repository of $ref (whose pin is the base) is undecided; name it in --package-repos exactly once" >&2
        exit 2
    fi
    # shellcheck source=_pr_base.sh
    source "$SCRIPT_DIR/_pr_base.sh"
    local -a pargs=(--repo "$(basename "$owning")" --layer "$layer")
    [[ -n "$pname" ]] && pargs+=(--project "$pname")
    [[ -n "$override" ]] && pargs+=(--base "$override")
    base=$(pr_base_for "${pargs[@]}") || exit 2
    echo "base=$base"
}

# ------------------------------------------------------------------ next ---
cmd_next() {
    local issue="" pr="" type="workspace" project="" progress=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --issue)    [[ $# -ge 2 ]] || usage; issue="$2"; shift 2 ;;
            --pr)       [[ $# -ge 2 ]] || usage; pr="$2"; shift 2 ;;
            --type)     [[ $# -ge 2 ]] || usage; type="$2"; shift 2 ;;
            --project)  [[ $# -ge 2 ]] || usage; project="$2"; shift 2 ;;
            --progress) [[ $# -ge 2 ]] || usage; progress="$2"; shift 2 ;;
            *) usage ;;
        esac
    done
    [[ -n "$pr" ]] || { echo "error: next: --pr <none|draft|open|merged> is required" >&2; exit 2; }
    case "$pr" in
        none|draft|open|merged) ;;
        *) echo "error: next: --pr must be one of: none, draft, open, merged" >&2; exit 2 ;;
    esac
    [[ "$type" == "workspace" || "$type" == "project" ]] || { echo "error: next: --type must be workspace or project" >&2; exit 2; }

    # Row 1 — checked before any file is read; the worktree may be gone.
    if [[ "$pr" == "merged" ]]; then
        echo "action=done"
        echo "reason=PR is merged; the worktree is gone, nothing left to resolve"
        return 0
    fi

    if [[ -n "$progress" ]]; then
        records_path "$progress" >/dev/null || { echo "error: next: the records gate refused $progress — see above" >&2; exit 2; }
        [[ -f "$progress" ]] || { echo "error: next: --progress file not found: $progress" >&2; exit 2; }
    else
        [[ -n "$issue" ]] || { echo "error: next: --issue <N> is required (or pass --progress <file>)" >&2; exit 2; }
        local ref="$issue" wt resolved rc=0
        issue=$(parse_issue_ref "$ref" next) || exit 2
        resolved=$(resolve_issue_dir "$ref" "$issue" "$type" "$project" 0) || { rc=$?; report_resolve_failure next "$rc" "$type" "$ref"; }
        wt=$(sed -n 1p <<< "$resolved")
        progress="$wt/.agent/work-plans/issue-$issue/progress.md"
    fi

    local json
    if [[ -f "$progress" ]]; then
        json=$("$PYTHON" "$PROGRESS_READ" "$progress") || {
            echo "error: next: progress_read.py failed on $progress (malformed file? see message above)" >&2
            exit 3
        }
    else
        # Not yet created — the first phases create it (triage-reviews already
        # treats a missing file this way); an empty timeline, not an error.
        json='{"entries": []}'
    fi

    printf '%s' "$json" | PR_STATE="$pr" "$PYTHON" -c '
import json, os, sys

MAX_ROUNDS = 3
PR = os.environ["PR_STATE"]
data = json.load(sys.stdin)
entries = data["entries"]


def emit(action, reason, round_=None, phase=None, mode=None):
    print("action=" + action)
    print("reason=" + reason)
    if round_ is not None:
        print("round=" + str(round_))
    if phase is not None:
        print("phase=" + phase)
    if mode is not None:
        print("mode=" + mode)
    sys.exit(0)


# Row 4 — no entries (including no file).
if not entries:
    emit("review-issue", "no entries on the timeline yet")

E = entries[-1]
base = E.get("base_type")
fields = E.get("fields") or {}
status = (E.get("status") or "").strip().lower()
etype = E.get("type")

# The failed-entry type -> skill mapping used by row 3 and rows 26/27
# ("Implementation" is written by two phases, so skill_for() below
# discriminates them by **Addressed**, the field only address-findings
# writes -- issue #314; **Mode** is no longer read by anything). Checkpoint,
# External Review, and the Merge records have no skill mapping (ADR-0013:
# they are not phases a run-issue table row dispatches).
TYPE_TO_SKILL = {
    "Issue Review": "review-issue",
    "Plan Authored": "plan-task",
    "Plan Review": "review-plan",
    "Local Review (Pre-Push)": "review-code",
    "Local Review": "review-code",
    "Integrated Review": "triage-reviews",
}


def restart_start():
    # Index of the first entry after the newest **Decision**: restart
    # checkpoint (0 when there is none). The owner restated the goal
    # (/orchestrator recipe (a)), so the new work starts here: round_count()
    # counts reviews from it and skill_for() names phases from it.
    start = 0
    for i, e in enumerate(entries):
        if e.get("base_type") == "Checkpoint" \
                and ((e.get("fields") or {}).get("Decision") or "").strip().lower() == "restart":
            start = i + 1
    return start


def skill_for(entry):
    b = entry.get("base_type")
    if b == "Implementation":
        f = entry.get("fields") or {}
        # Positive signal first: **Addressed** is part of address-findings
        # own entry template (its SKILL.md step 5, where only the
        # **Branch**/**PR** line is called required) and the post-plan
        # implement pass never writes it. Nothing validates the field, so a
        # present-but-empty value must NOT count as the signal -- it would
        # route a failed implement pass to address-findings. An empty value
        # falls through to the prior-complete-Implementation test below,
        # which is the same answer an omitted field gets.
        if (f.get("Addressed") or "").strip():
            return "address-findings"
        # Fallback for an entry that never got as far as writing it. A
        # review -- and so an address-findings pass -- can only follow a
        # COMPLETE implementation, so with no prior complete
        # "## Implementation" on the timeline this is still the implement
        # pass. Ordinal position alone ("is this the first one?") would
        # misroute a second consecutive failed implement: retry -> failed
        # again must still name **Phase**: implement (issue #314). Only
        # entries after the newest restart checkpoint count, the same start
        # round_count() uses: a restart begins the new work at its first
        # implement, so a complete Implementation from before it does not
        # make the next failed pass an address-findings pass (issue 321).
        for e in entries[restart_start():]:
            if e is entry:
                break
            if e.get("base_type") == "Implementation" \
                    and (e.get("status") or "").strip().lower() == "complete":
                return "address-findings"
        return "implement"
    return TYPE_TO_SKILL.get(b)


def open_findings(entry, section):
    # PR1 review requirement: progress_read.py tags every checkbox with the
    # ### section that precedes it but does not filter by section itself —
    # callers must. Only the named section counts as "open" here.
    return [f for f in (entry.get("findings") or [])
            if f.get("section") == section and not f.get("checked")]


def round_count():
    # The count of COMPLETED "## Local Review (Pre-Push)" entries sharing the
    # newest such entrys branch correlation (hermetic under --progress). Only
    # status == "complete" counts as a round: a partial/failed review that
    # was retried (row 3 already routed it to checkpoint:phase-failed) must
    # not inflate the round count toward MAX_ROUNDS. Only reviews after the
    # newest **Decision**: restart checkpoint count (the owner restated the
    # goal, /orchestrator recipe (a)): the new work starts at round 1. The
    # same rule as review_progress.sh round, which the round-3 handoff uses.
    branch = (E.get("correlation") or {}).get("branch")
    n = 0
    for e in entries[restart_start():]:
        if e.get("base_type") == "Local Review (Pre-Push)":
            c = e.get("correlation") or {}
            if c.get("kind") == "branch" and c.get("branch") == branch \
                    and (e.get("status") or "").strip().lower() == "complete":
                n += 1
    return n


# Row 2 — a stop checkpoint is absorbing, regardless of entry type.
if base == "Checkpoint" and fields.get("Decision") == "stop":
    after = fields.get("After", "?")
    phase = fields.get("Phase")
    reason = "stopped at checkpoint \"" + str(after) + "\""
    if phase:
        reason += " (phase=" + str(phase) + ")"
    reason += " -- /run-issue <N> --resume re-asks it"
    if phase:
        emit("done", reason, phase=phase)
    emit("done", reason)

# Row 3 — a partial/failed newest entry is always a checkpoint, never a
# silent retry, regardless of entry type. phase= is omitted when the type
# has no skill mapping (Checkpoint, External Review, the Merge records) —
# the checkpoint then has no **Phase**, so a later retry/takeover answer to
# it falls through to row 28 (review finding 9).
if status in ("partial", "failed"):
    phase = skill_for(E)
    reason = "the latest \"" + str(etype) + "\" entry is " + status
    if phase:
        emit("checkpoint:phase-failed", reason, phase=phase)
    emit("checkpoint:phase-failed", reason)

# Rows 5-27, dispatched on the newest entrys base_type (Checkpoint rows
# dispatch again on **After**/**Decision**). Exactly one of these blocks can
# match per entry (an entry has one base_type), so within-block order does
# not affect row precedence; row 28 is the fallthrough at the end.

if base == "Issue Review":
    # PR1 review requirement: only ### Actions boxes count as "open" for
    # Issue Review, never a stray checkbox under ### Consequences or similar.
    if open_findings(E, "Actions"):
        emit("checkpoint:issue-actions", "Issue Review has open Actions")
    emit("plan-task", "Issue Review has no open Actions")

if base == "Checkpoint":
    after = fields.get("After")
    decision = fields.get("Decision")
    phase = fields.get("Phase")
    if after == "issue-actions" and decision == "proceed":
        emit("plan-task", "checkpoint issue-actions answered proceed")
    if after == "plan":
        if decision == "proceed":
            emit("implement", "checkpoint plan answered proceed")
        if decision == "revise":
            emit("plan-task", "checkpoint plan answered revise")
    if after in ("publish", "rounds"):
        if decision == "publish":
            if PR == "none":
                emit("publish", "checkpoint answered publish; no PR yet")
            if PR in ("draft", "open"):
                emit("triage-reviews", "checkpoint answered publish; PR already exists")
        if decision == "address":
            emit("address-findings", "checkpoint answered address")
    if after in ("findings", "merge"):
        if decision == "merge":
            emit("merge", "checkpoint answered merge")
        if decision == "address":
            emit("address-findings", "checkpoint answered address")
    if after == "merge-refused":
        if decision == "retriage":
            emit("triage-reviews", "checkpoint merge-refused answered retriage")
        if decision == "address":
            emit("address-findings", "checkpoint merge-refused answered address")
    if after == "phase-failed" and phase:
        if decision == "retry":
            emit(phase, "checkpoint phase-failed answered retry")
        if decision == "takeover":
            emit(phase, "checkpoint phase-failed answered takeover", mode="inline")
    # anything else under **After**/**Decision** falls through to row 28.

if base == "Plan Authored":
    emit("review-plan", "plan committed -- independent review next")

if base == "Plan Review":
    emit("checkpoint:plan", "plan review complete -- proceed, revise, or stop")

if base == "Implementation":
    mode_note = "pre-push (--branch)" if PR == "none" else "PR mode"
    emit("review-code", "implementation complete -- review (" + mode_note + ")")

if base == "Local Review (Pre-Push)":
    # PR1 review requirement: review-code writes an UNCHECKED LGTM
    # placeholder box even when approved; rows 13-15 route on **Verdict**
    # alone, never on open findings, so that placeholder never misroutes an
    # approved pre-push review.
    verdict = (fields.get("Verdict") or "").strip().lower()
    r = round_count()
    if verdict == "approved":
        emit("checkpoint:publish", "pre-push review approved", round_=r)
    if r >= MAX_ROUNDS:
        emit("checkpoint:rounds",
             "round " + str(r) + " reached MAX_ROUNDS (" + str(MAX_ROUNDS) + ") without approval",
             round_=r)
    emit("address-findings", "round " + str(r) + ": pre-push review needs work", round_=r)

if base == "Local Review":
    # Rows 22a/22b route on **Verdict**, exactly like rows 13-15 -- NOT on
    # open findings (plan defect fixed post-review): review-codes unchecked
    # LGTM placeholder (`- [ ] No issues found. LGTM.`) must never misroute
    # an approved PR-mode re-review into address-findings. Open findings are
    # the routing key only for Integrated Review (rows 19-21) and Issue
    # Review (rows 5/6).
    verdict = (fields.get("Verdict") or "").strip().lower()
    if verdict == "approved":
        emit("triage-reviews", "PR-mode re-review approved -- host waits for reviews first")
    emit("address-findings", "PR-mode re-review not approved")

if base == "Integrated Review":
    if open_findings(E, "Findings"):
        emit("checkpoint:findings", "Integrated Review has open findings")
    emit("checkpoint:merge", "Integrated Review has no open findings")

if base in ("Merge (report-only)", "Merge (unreviewed)"):
    emit("checkpoint:merge-refused",
         "latest merge attempt did not end merged (" + str(base) + ")")

# Row 28 — External Review, and any Checkpoint/entry state no row names.
emit("checkpoint:unexpected", "no row matches this state (type=" + str(etype) + ")")
'
}

case "${1:-}" in
    next)         shift; cmd_next "$@" ;;
    where)        shift; cmd_where "$@" ;;
    base)         shift; cmd_base "$@" ;;
    --check-exit) shift; cmd_check_exit "$@" ;;
    -h|--help|help) usage ;;
    *)            cmd_handoff "$@" ;;
esac
