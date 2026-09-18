#!/bin/bash
# .agent/scripts/dispatch_phase.sh
# In-process phase handoff for the run-issue loop (issue #276 PR 2). Replaces
# the fork's dispatch_subagent.sh minus every container clause (issue #276
# decision, 2026-09-17: auto mode replaced containers; in-process only).
#
# Usage:
#   dispatch_phase.sh --issue <N> --skill <phase> [--type workspace|project]
#                      [--pr <M>] [--prompt-file <f>] [--entry-type <T>]
#                      [--model <alias>]
#     Prints the handoff block for a phase the host is about to dispatch
#     via the Agent tool: the worktree, the phase's literal task line (per
#     the plan's per-skill table), the commit identity, the model to stamp
#     in **By**, the expected entry type, and the exit contract. Output is
#     `key=value` lines, one per line, in this order: worktree, task,
#     agent_name, agent_email, model, entry_type, exit_contract, and
#     prompt_file (only when --prompt-file was given).
#
#   dispatch_phase.sh --check-exit --issue <N> --skill <phase>
#                      [--type workspace|project] [--pr <M>] --before <count>
#     Compares the entry count of the expected type (same table as above)
#     before and after a dispatch. Prints `status=<OK|PARTIAL|FAILED|MISSING>`
#     and, only for OK, a second line `sha=<short git sha>` (the worktree's
#     HEAD after the phase's own commit).
#
#   dispatch_phase.sh next --issue <N> --pr <none|draft|open|merged>
#                      [--type workspace|project] [--progress <file>]
#     The run-issue decision table (28 rows; see the plan for #276 PR 2).
#     Prints `action=<token>`, `reason=<one line>`, then `round=<n>` when
#     the action concerns the pre-push review loop, `phase=<skill>` when a
#     checkpoint:phase-failed / retry / takeover names a failed phase, and
#     `mode=inline` when the action is to be run by the host itself. No
#     `gh` call inside `next`, ever — `--pr` is the only non-timeline input.
#
# Exit codes:
#   next:        0 action decided; 2 usage (including no worktree for
#                --issue, or a --progress path that does not exist); 3 the
#                timeline could not be parsed (progress_read.py's message
#                stays on stderr).
#   handoff /
#   --check-exit: 0 ok; 2 usage (including no worktree, unknown --skill,
#                missing --pr for triage-reviews, or AGENT_NAME/AGENT_EMAIL
#                unset); 3 the timeline could not be parsed.
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

PROGRESS_READ="$SCRIPT_DIR/progress_read.py"
PYTHON="${PYTHON:-python3}"

usage() {
    cat >&2 <<'EOF'
Usage:
  dispatch_phase.sh --issue <N> --skill <phase> [--type workspace|project]
                     [--pr <M>] [--prompt-file <f>] [--entry-type <T>]
                     [--model <alias>]
  dispatch_phase.sh --check-exit --issue <N> --skill <phase>
                     [--type workspace|project] [--pr <M>] --before <count>
  dispatch_phase.sh next --issue <N> --pr <none|draft|open|merged>
                     [--type workspace|project] [--progress <file>]
See the header comment of this script for what each mode prints.
Exit codes: 0 ok; 2 usage; 3 the timeline could not be parsed.
EOF
    exit 2
}

# --------------------------------------------------------- worktree lookup ---
# Locates issue <N>'s worktree exactly as worktree_enter.sh --type <type>
# would (new location, then the pre-registration transition location for a
# registered project, then the legacy location). No --project disambiguation
# flag here (out of scope for this port; #265's --type project path is
# inherited as-is, per the plan's Consequences table): a project type
# resolves only when exactly one project is registered or a legacy project/
# checkout exists.
resolve_worktree() {
    local issue="$1" type="$2"
    local new_base="" legacy_base="" transition_base=""

    if [[ "$type" == "workspace" ]]; then
        new_base=$(wt_workspace_base "$ROOT_DIR")
        legacy_base=$(wt_legacy_workspace_base "$ROOT_DIR")
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
        legacy_base=$(wt_legacy_project_base "$ROOT_DIR")
    fi

    local path
    if [[ -n "$new_base" ]] && path=$(find_worktree_by_issue "$new_base" "$issue" "" 2>/dev/null); then
        echo "$path"; return 0
    fi
    if [[ -n "$transition_base" ]] && path=$(find_worktree_by_issue "$transition_base" "$issue" "" 2>/dev/null); then
        echo "$path"; return 0
    fi
    if [[ -n "$legacy_base" ]] && path=$(find_worktree_by_issue "$legacy_base" "$issue" "" 2>/dev/null); then
        echo "$path"; return 0
    fi
    return 1
}

# ------------------------------------------------ per-skill task/entry/model ---
# The literal per-skill task line (verified against each SKILL.md usage
# block), the ADR-0013 entry type the dispatch is expected to write, and the
# model tier (owner decision, 2026-09-17). `review-code` and `triage-reviews`
# are mode-aware on `--pr`; every other skill ignores it.
skill_task_line() {
    local skill="$1" issue="$2" pr="$3"
    case "$skill" in
        review-issue)     echo "/review-issue $issue" ;;
        plan-task)        echo "/plan-task $issue --no-pr" ;;
        review-plan)      echo "/review-plan --issue $issue" ;;
        review-code)
            if [[ -n "$pr" ]]; then echo "/review-code $pr"
            else echo "/review-code --branch --issue $issue"; fi
            ;;
        triage-reviews)   echo "/triage-reviews $pr" ;;
        address-findings) echo "/address-findings --issue $issue" ;;
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
    local issue="" skill="" type="workspace" pr="" prompt_file="" entry_type_override="" model_override=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --issue)       [[ $# -ge 2 ]] || usage; issue="$2"; shift 2 ;;
            --skill)       [[ $# -ge 2 ]] || usage; skill="$2"; shift 2 ;;
            --type)        [[ $# -ge 2 ]] || usage; type="$2"; shift 2 ;;
            --pr)          [[ $# -ge 2 ]] || usage; pr="$2"; shift 2 ;;
            --prompt-file) [[ $# -ge 2 ]] || usage; prompt_file="$2"; shift 2 ;;
            --entry-type)  [[ $# -ge 2 ]] || usage; entry_type_override="$2"; shift 2 ;;
            --model)       [[ $# -ge 2 ]] || usage; model_override="$2"; shift 2 ;;
            *) usage ;;
        esac
    done
    [[ "$issue" =~ ^[0-9]+$ ]] || { echo "error: dispatch: --issue <N> is required" >&2; exit 2; }
    [[ -n "$skill" ]] || { echo "error: dispatch: --skill <phase> is required" >&2; exit 2; }
    [[ "$type" == "workspace" || "$type" == "project" ]] || { echo "error: dispatch: --type must be workspace or project" >&2; exit 2; }

    if skill_requires_pr "$skill" && [[ -z "$pr" ]]; then
        echo "error: dispatch: --skill $skill requires --pr <M>" >&2
        exit 2
    fi

    local task entry_type model
    task=$(skill_task_line "$skill" "$issue" "$pr") || {
        echo "error: dispatch: unknown --skill '$skill' (expected one of review-issue, plan-task, review-plan, review-code, triage-reviews, address-findings)" >&2
        exit 2
    }
    entry_type=$(skill_entry_type "$skill" "$pr")
    model=$(skill_model "$skill")
    [[ -n "$entry_type_override" ]] && entry_type="$entry_type_override"
    [[ -n "$model_override" ]] && model="$model_override"

    local wt
    wt=$(resolve_worktree "$issue" "$type") || {
        echo "error: dispatch: no $type worktree found for issue #$issue" >&2
        exit 2
    }

    if [[ -z "${AGENT_NAME:-}" || -z "${AGENT_EMAIL:-}" ]]; then
        echo "error: dispatch: AGENT_NAME/AGENT_EMAIL are not set — source set_git_identity_env.sh first (no fallback to the human's git config)" >&2
        exit 2
    fi

    echo "worktree=$wt"
    echo "task=$task"
    echo "agent_name=$AGENT_NAME"
    echo "agent_email=$AGENT_EMAIL"
    echo "model=$model"
    echo "entry_type=$entry_type"
    echo "exit_contract=Append exactly one \`## $entry_type\` entry to $wt/.agent/work-plans/issue-$issue/progress.md via the phase's own persistence step. If you cannot finish, still append it with **Status**: partial or **Status**: failed and say why. Never push — the host owns every push."
    if [[ -n "$prompt_file" ]]; then
        echo "prompt_file=$prompt_file"
    fi
}

# ------------------------------------------------------------ check-exit ---
cmd_check_exit() {
    local issue="" skill="" type="workspace" pr="" before=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --issue)  [[ $# -ge 2 ]] || usage; issue="$2"; shift 2 ;;
            --skill)  [[ $# -ge 2 ]] || usage; skill="$2"; shift 2 ;;
            --type)   [[ $# -ge 2 ]] || usage; type="$2"; shift 2 ;;
            --pr)     [[ $# -ge 2 ]] || usage; pr="$2"; shift 2 ;;
            --before) [[ $# -ge 2 ]] || usage; before="$2"; shift 2 ;;
            *) usage ;;
        esac
    done
    [[ "$issue" =~ ^[0-9]+$ ]] || { echo "error: check-exit: --issue <N> is required" >&2; exit 2; }
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

    local wt
    wt=$(resolve_worktree "$issue" "$type") || {
        echo "error: check-exit: no $type worktree found for issue #$issue" >&2
        exit 2
    }
    local progress="$wt/.agent/work-plans/issue-$issue/progress.md"

    local json="" count=0
    if [[ -f "$progress" ]]; then
        json=$("$PYTHON" "$PROGRESS_READ" "$progress" --type "$entry_type") || {
            echo "error: check-exit: progress_read.py failed on $progress (malformed file? see message above)" >&2
            exit 3
        }
        count=$(printf '%s' "$json" | "$PYTHON" -c "import json, sys; print(len(json.load(sys.stdin)[\"entries\"]))")
    fi

    if [[ "$count" -le "$before" ]]; then
        echo "status=MISSING"
        return 0
    fi

    local entry_status
    entry_status=$(printf '%s' "$json" | "$PYTHON" -c "import json, sys
d = json.load(sys.stdin)
print((d[\"entries\"][-1].get(\"status\") or \"\").strip().lower())")

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

# ------------------------------------------------------------------ next ---
cmd_next() {
    local issue="" pr="" type="workspace" progress=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --issue)    [[ $# -ge 2 ]] || usage; issue="$2"; shift 2 ;;
            --pr)       [[ $# -ge 2 ]] || usage; pr="$2"; shift 2 ;;
            --type)     [[ $# -ge 2 ]] || usage; type="$2"; shift 2 ;;
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
        [[ -f "$progress" ]] || { echo "error: next: --progress file not found: $progress" >&2; exit 2; }
    else
        [[ "$issue" =~ ^[0-9]+$ ]] || { echo "error: next: --issue <N> is required (or pass --progress <file>)" >&2; exit 2; }
        local wt
        wt=$(resolve_worktree "$issue" "$type") || {
            echo "error: next: no $type worktree found for issue #$issue" >&2
            exit 2
        }
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
# ("Implementation" is mode-aware: **Mode**: inline names the inline
# implementation pass, everything else names address-findings). Checkpoint,
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


def skill_for(entry):
    b = entry.get("base_type")
    if b == "Implementation":
        f = entry.get("fields") or {}
        return "implement" if f.get("Mode") == "inline" else "address-findings"
    return TYPE_TO_SKILL.get(b)


def open_findings(entry, section):
    # PR1 review requirement: progress_read.py tags every checkbox with the
    # ### section that precedes it but does not filter by section itself —
    # callers must. Only the named section counts as "open" here.
    return [f for f in (entry.get("findings") or [])
            if f.get("section") == section and not f.get("checked")]


def round_count():
    # The count of completed "## Local Review (Pre-Push)" entries sharing the
    # newest such entrys branch correlation (hermetic under --progress).
    branch = (E.get("correlation") or {}).get("branch")
    n = 0
    for e in entries:
        if e.get("base_type") == "Local Review (Pre-Push)":
            c = e.get("correlation") or {}
            if c.get("kind") == "branch" and c.get("branch") == branch:
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
            emit("implement", "checkpoint plan answered proceed", mode="inline")
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
            if phase == "implement":
                emit(phase, "checkpoint phase-failed answered retry", mode="inline")
            emit(phase, "checkpoint phase-failed answered retry")
        if decision == "takeover":
            emit(phase, "checkpoint phase-failed answered takeover", mode="inline")
    # anything else under **After**/**Decision** falls through to row 28.

if base == "Plan Authored":
    emit("review-plan", "plan committed -- independent review next")

if base == "Plan Review":
    emit("checkpoint:plan", "plan review complete -- owner decides proceed, revise, or stop")

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
    if open_findings(E, "Findings"):
        emit("address-findings", "PR-mode re-review has open findings")
    emit("triage-reviews", "PR-mode re-review has no open findings -- host waits for reviews first")

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
    --check-exit) shift; cmd_check_exit "$@" ;;
    -h|--help|help) usage ;;
    *)            cmd_handoff "$@" ;;
esac
