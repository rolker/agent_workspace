#!/usr/bin/env bash
# .agent/scripts/user_tier_install.sh
# Install (or check, or remove) the agent_workspace user tier in ~/.claude,
# so a Claude Code session started anywhere under a registered project root
# gets the workspace layer (#317, #265 PR 3).
#
# What the user tier consists of:
#   1. ~/.claude/agent-workspace-root   -- one line, no trailing newline: the
#      absolute path of this workspace checkout. THE way a skill command
#      chain finds a workspace script from a project cwd. A plain file, not
#      an environment variable and not hook output, so it works whether or
#      not the SessionStart hook ran. See ADR-0016.
#   2. ~/.claude/hooks/agent-workspace-session-start.sh -- a symlink to this
#      checkout's .claude/hooks/session_start_project_layer.sh, registered
#      as a SessionStart hook by absolute path.
#   3. One PreToolUse entry, by absolute path, for
#      .claude/hooks/log-tool-use.sh. It carries the registry_require_root
#      guard, so it is inert outside the workspace checkout and outside every
#      registered root. (The tool-mapping hook was promoted alongside it and
#      retired by #328; --check reports a leftover entry for it as drift.)
#   4. Permission allow-rules for the promoted scripts in
#      .agent/user_tier_scripts.txt, by absolute path.
#   5. The agent-workspace Claude Code plugin (ADR-0017), enabled at local
#      scope in every registered session root: the workspace skills whose
#      SKILL.md declares `session_scope: project` or `both`, namespaced as
#      /agent-workspace:<skill> so a project's own same-named skill keeps its
#      bare name (#345). Enabling runs `claude plugin marketplace add` and
#      `claude plugin install --scope local` from the root, which writes the
#      root's gitignored .claude/settings.local.json -- the one scoped
#      exception to ADR-0016 section 2 that ADR-0017 records. Skipped:
#        - a root whose git toplevel IS this workspace checkout (compared as
#          `pwd -P` forms): a session there already sees the bare skills by
#          directory walk-up, and enabling would double every skill and write
#          the workspace's own settings.local.json;
#        - a `parent=` instance inside its parent's directory: its parent
#          root is the session unit, and the parent is what gets enabled.
#          An instance registered OUTSIDE its parent's directory cannot see
#          the parent's settings, so it is enabled as a root of its own;
#        - a root not on disk (a note, not an error);
#        - every enable, with a note, when the `claude` CLI is not on PATH
#          (a Codex-only machine has no plugins to enable). A plugin that
#          must be REMOVED (a doubled root, --uninstall) is an error without
#          the CLI, not a note: it stays enabled.
#      A root that is in no git repository at all is enabled.
#   (Before ADR-0017, item 5 was a symlink per skill in ~/.claude/skills/.
#   Those links were global to the machine and shadowed a project's own
#   same-named skills. Install removes any left behind; --check reports them.)
#
# Every entry this script writes into ~/.claude/settings.json is tagged
# "_agent_workspace": "<this checkout>", which is what makes --check able to
# tell OUR entries from the user's own and from another checkout's.
#
# Modes:
#   (default)            install or repair; idempotent, safe to re-run
#   --check              report drift. Exits 0 with a one-line note when the
#                        user tier is simply not installed -- `make validate`
#                        must stay green on a machine that never installed
#                        it. Exits 1 on drift when it IS installed.
#   --check --require    also exit 1 when it is not installed, for a machine
#                        that expects it.
#   --uninstall          remove every entry tagged with this checkout, and
#                        the plugin from every root where this checkout
#                        declared it (another checkout's is left alone).
#   --list-skills        print the skills the plugin exposes (session_scope
#                        project|both), one per line.
#   --generate-plugin-manifest
#                        rewrite the `skills` array of .claude-plugin/
#                        plugin.json from that list (what `make
#                        generate-user-tier-skills` runs). Touches only the
#                        tracked manifest in this checkout.
#
# Exit codes: 0 ok; 1 drift / failure; 2 usage; 3 missing dependency (jq).
#
# Scope: this script writes inside $HOME/.claude, plus -- only through the
# `claude plugin` CLI, never directly -- each enabled root's gitignored
# .claude/settings.local.json (item 5; the CLI also keeps its own plugin
# bookkeeping under ~/.claude/plugins/). It never edits the tracked
# .claude/settings.json in the checkout, which stays exactly as it is
# (Ask-First).
#
# Test seam: AGENT_WORKSPACE_CLAUDE_BIN names the claude binary (default
# `claude`), so the test suite can point it at a stub that records argv and
# never runs the real CLI.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# The physical form, for every comparison against a path git or the claude
# CLI reports (both resolve symlinks) and for the marketplace source itself.
WS_PHYS="$(cd "$WS_ROOT" && pwd -P)"
MANIFEST="$WS_ROOT/.agent/user_tier_scripts.txt"
PLUGIN_MANIFEST="$WS_ROOT/.claude-plugin/plugin.json"

# shellcheck source=_project_registry.sh
source "$SCRIPT_DIR/_project_registry.sh"

PLUGIN_NAME="agent-workspace"
MARKETPLACE_NAME="agent-workspace"
PLUGIN_ID="$PLUGIN_NAME@$MARKETPLACE_NAME"
CLAUDE_BIN="${AGENT_WORKSPACE_CLAUDE_BIN:-claude}"

CLAUDE_DIR="${HOME}/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
ROOT_FILE="$CLAUDE_DIR/agent-workspace-root"
# The allow-rules the installed generation wrote, so uninstall and --check can
# recognise rules this checkout owns even after the manifest changes.
RULES_FILE="$CLAUDE_DIR/agent-workspace-rules.json"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SKILLS_DIR="$CLAUDE_DIR/skills"
# The claude CLI's own machine-level marketplace records (ADR-0017). Read
# only, never written here; install's `marketplace add` is what repoints it.
KNOWN_MARKETPLACES="$CLAUDE_DIR/plugins/known_marketplaces.json"
SESSION_HOOK_LINK="$HOOKS_DIR/agent-workspace-session-start.sh"
SESSION_HOOK_TARGET="$WS_ROOT/.claude/hooks/session_start_project_layer.sh"

TAG="$WS_ROOT"

# Modes are mutually exclusive. Previously they were last-one-wins, so
# `--uninstall --check` silently ran check only -- the caller believed they
# had uninstalled.
MODE=""
REQUIRE=false
FORCE=false
set_mode() {
    if [[ -n "$MODE" && "$MODE" != "$1" ]]; then
        echo "ERROR: --$1 and --$MODE are mutually exclusive; pick one" >&2
        exit 2
    fi
    MODE="$1"
}
for arg in "$@"; do
    case "$arg" in
        --check)       set_mode check ;;
        --require)     REQUIRE=true ;;
        --force)       FORCE=true ;;
        --uninstall)   set_mode uninstall ;;
        --list-skills) set_mode list-skills ;;
        --generate-plugin-manifest) set_mode generate-plugin-manifest ;;
        -h|--help)
            sed -n '2,/^set -uo pipefail/p' "${BASH_SOURCE[0]}" | sed '$d'
            exit 0
            ;;
        *)
            echo "usage: user_tier_install.sh [--force] | --check [--require] | --uninstall | --list-skills | --generate-plugin-manifest" >&2
            exit 2
            ;;
    esac
done

[[ -n "$MODE" ]] || MODE="install"
if [[ "$REQUIRE" == true && "$MODE" != "check" ]]; then
    echo "ERROR: --require is only meaningful with --check" >&2
    exit 2
fi

# jq is needed only by the modes that read or merge settings.json. Checking
# it up front made `make validate` exit 3 on a jq-less machine -- the exact
# case this script's --check is supposed to keep green.
case "$MODE" in
    install|check|uninstall|generate-plugin-manifest)
        if ! command -v jq >/dev/null 2>&1; then
            if [[ "$MODE" == "check" ]]; then
                echo "agent_workspace user tier: jq not installed -- cannot check (install jq to enable this check)"
                exit 0
            fi
            echo "ERROR: jq is required (settings.json merge, plugin manifest)" >&2
            exit 3
        fi
        ;;
esac

# ---------------------------------------------------------------- inputs ---
# The promoted scripts (not the hooks -- those get hook entries, not
# permission rules), as absolute paths.
promoted_scripts() {
    [[ -f "$MANIFEST" ]] || return 0
    local line
    while IFS= read -r line; do
        line="${line%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -z "$line" ]] && continue
        [[ "$line" == .claude/hooks/* ]] && continue
        echo "$WS_ROOT/$line"
    done < "$MANIFEST"
}

# Skills whose SKILL.md declares session_scope: project | both. Skills with
# no field are `workspace` (the documented default) and are excluded.
selected_skills() {
    local d name scope
    for d in "$WS_ROOT"/.claude/skills/*/; do
        [[ -f "$d/SKILL.md" ]] || continue
        name="$(basename "$d")"
        scope="$(awk '
            NR == 1 && $0 == "---" { fm = 1; next }
            fm && $0 == "---" { exit }
            fm && /^session_scope:/ { sub(/^session_scope:[[:space:]]*/, ""); gsub(/["'"'"']/, ""); print; exit }
        ' "$d/SKILL.md")"
        case "$scope" in
            project|both) echo "$name" ;;
        esac
    done | LC_ALL=C sort
}

# The permission rules this checkout owns, as a JSON array.
allow_rules_json() {
    local s
    { while IFS= read -r s; do
        [[ -z "$s" ]] && continue
        printf '%s\n' "Bash($s:*)"
        printf '%s\n' "Bash($s)"
      done < <(promoted_scripts)
    } | jq -R . | jq -s .
}

# Every allow-rule this checkout may have written: the generation recorded at
# install time, unioned with what the current manifest would generate. The
# union matters because the manifest can change between install and uninstall,
# and a rule named by neither side would be orphaned in settings.json.
installed_rules_json() {
    local recorded='[]'
    if [[ -f "$RULES_FILE" ]] && jq -e . "$RULES_FILE" >/dev/null 2>&1; then
        recorded="$(cat "$RULES_FILE")"
    fi
    jq -n --argjson a "$recorded" --argjson b "$(allow_rules_json)" '($a + $b) | unique'
}

hook_commands() {
    echo "$WS_ROOT/.claude/hooks/log-tool-use.sh"
}

# --------------------------------------------------------------- helpers ---
installed() {
    [[ -f "$ROOT_FILE" ]] && [[ "$(cat "$ROOT_FILE" 2>/dev/null)" == "$WS_ROOT" ]]
}

# The user tier is singular: ~/.claude/agent-workspace-root names exactly one
# checkout, and every skill's $WS_ROOT follows it. Prints the OTHER checkout's
# path when the file exists and points somewhere else; empty otherwise.
installed_elsewhere() {
    local other
    [[ -f "$ROOT_FILE" ]] || return 1
    other="$(cat "$ROOT_FILE" 2>/dev/null)"
    [[ -n "$other" && "$other" != "$WS_ROOT" ]] || return 1
    printf '%s\n' "$other"
}

# Is settings.json present but unparseable? That is a state of its own, not
# an empty file: treating it as {} would silently drop every key the user
# has (model, their own allow-rules, their own hooks) on the next write.
settings_unparseable() {
    [[ -f "$SETTINGS" ]] && ! jq -e . "$SETTINGS" >/dev/null 2>&1
}

# Refuse rather than guess. Callers that may WRITE must call this first.
require_parseable_settings() {
    settings_unparseable || return 0
    cat >&2 <<EOF
ERROR: $SETTINGS exists but is not valid JSON.

Refusing to touch it: rewriting it would discard every setting in it. Fix
the file (jq . "$SETTINGS" will point at the syntax error), or move it
aside, then re-run this script.
EOF
    return 1
}

read_settings() {
    if [[ -f "$SETTINGS" ]]; then
        # Parse errors are the caller's to handle via require_parseable_settings
        # / settings_unparseable -- never silently downgraded to {} here.
        jq '.' "$SETTINGS" 2>/dev/null || echo '{}'
    else
        echo '{}'
    fi
}

# A timestamped copy beside the original, before any rewrite. Cheap, and the
# difference between a bad merge being an annoyance and being a data loss.
BACKUP_KEEP=5
backup_settings() {
    local stamp dest n=0
    [[ -f "$SETTINGS" ]] || return 0
    # Nanoseconds, so two runs in the same second do not collide and silently
    # overwrite the older of the two backups. A counter suffix covers the
    # coreutils builds where %N is not expanded.
    stamp="$(date +%Y%m%d-%H%M%S-%N)"
    [[ "$stamp" == *N ]] && stamp="$(date +%Y%m%d-%H%M%S)-$$"
    dest="$SETTINGS.agent-workspace-backup.$stamp"
    while [[ -e "$dest" ]]; do
        n=$((n + 1))
        dest="$SETTINGS.agent-workspace-backup.$stamp-$n"
    done
    cp -p "$SETTINGS" "$dest" || return 1
    echo "  backed up $SETTINGS -> $dest"

    # Keep only the newest few: these accumulate on every install, and an
    # unbounded pile of them in ~/.claude is its own small mess.
    local -a old=()
    while IFS= read -r f; do old+=("$f"); done < <(
        ls -1t "$SETTINGS".agent-workspace-backup.* 2>/dev/null | tail -n +$((BACKUP_KEEP + 1))
    )
    if [[ "${#old[@]}" -gt 0 ]]; then
        rm -f "${old[@]}"
        echo "  pruned ${#old[@]} old backup(s), keeping the newest $BACKUP_KEEP"
    fi
}

write_settings() {  # <json on stdin>
    local tmp
    mkdir -p "$CLAUDE_DIR"
    tmp="$(mktemp "$CLAUDE_DIR/.settings.json.XXXXXX")" || return 1
    cat > "$tmp" || { rm -f "$tmp"; return 1; }
    if ! jq -e . "$tmp" >/dev/null 2>&1; then
        echo "ERROR: refusing to write malformed settings.json" >&2
        rm -f "$tmp"
        return 1
    fi
    if [[ -L "$SETTINGS" ]]; then
        # settings.json is a symlink -- commonly into a dotfiles repo. `mv`
        # onto the LINK would replace it with a regular file and silently
        # detach the user's dotfiles, so resolve it and rename onto the real
        # file instead. `cat > "$SETTINGS"` would write through the link but
        # truncates first: an interrupted write leaves a half-file where a
        # valid settings.json was. Rename is atomic.
        local real
        real="$(readlink -f "$SETTINGS" 2>/dev/null)"
        if [[ -z "$real" ]]; then
            echo "ERROR: $SETTINGS is a symlink that does not resolve" >&2
            rm -f "$tmp"
            return 1
        fi
        # The rename must land on the same filesystem as $tmp to be atomic;
        # stage beside the real file when the dotfiles repo is elsewhere.
        local staged="$real.agent-workspace.$$"
        cp "$tmp" "$staged" || { rm -f "$tmp" "$staged"; return 1; }
        rm -f "$tmp"
        mv "$staged" "$real"
        return 0
    fi
    mv "$tmp" "$SETTINGS"
}

# ------------------------------------------------------------- list mode ---
if [[ "$MODE" == "list-skills" ]]; then
    selected_skills
    exit 0
fi

# The plugin's `skills` array, generated from session_scope frontmatter so
# the manifest is never hand-maintained. An array of per-skill paths, not the
# whole .claude/skills directory: workspace-scoped skills call workspace
# scripts cwd-relative and would fail (or run a project's same-named script)
# from a project cwd, and the generated /make_* skills are gitignored
# per-machine files that must not ship.
if [[ "$MODE" == "generate-plugin-manifest" ]]; then
    if [[ ! -f "$PLUGIN_MANIFEST" ]] || ! jq -e . "$PLUGIN_MANIFEST" >/dev/null 2>&1; then
        echo "ERROR: $PLUGIN_MANIFEST is missing or not valid JSON" >&2
        exit 1
    fi
    skills_json="$(selected_skills | sed 's|^|./.claude/skills/|' | jq -R . | jq -s .)"
    tmp="$(mktemp "$PLUGIN_MANIFEST.XXXXXX")" || exit 1
    # Copied back over the original rather than renamed onto it: mktemp's
    # 0600 mode would otherwise replace the tracked file's.
    if jq --argjson s "$skills_json" '.skills = $s' "$PLUGIN_MANIFEST" > "$tmp" \
       && cat "$tmp" > "$PLUGIN_MANIFEST"; then
        rm -f "$tmp"
    else
        rm -f "$tmp"
        echo "ERROR: could not rewrite $PLUGIN_MANIFEST" >&2
        exit 1
    fi
    echo "Wrote $(jq length <<< "$skills_json") skill path(s) to $PLUGIN_MANIFEST"
    exit 0
fi

# ------------------------------------------------- legacy skill symlinks ---
# Before ADR-0017 the user tier shipped skills as symlinks in
# ~/.claude/skills/. They are global to the machine and shadow a project's
# own same-named skills (#345), so the mechanism is retired: install removes
# every such link, --check reports any left behind, and nothing creates them.
#
# Does <link> resolve into an agent_workspace checkout OTHER than this one?
# Recognised by the manifest file that only a workspace checkout has.
foreign_skill_link() {  # <link path>
    local tgt root
    tgt="$(readlink -f "$1" 2>/dev/null)" || return 1
    [[ -n "$tgt" ]] || return 1
    # <checkout>/.claude/skills/<name>: lexical, so a dangling link whose
    # skill was since deleted is still recognised.
    [[ "$(basename "$(dirname "$tgt")")" == "skills" ]] || return 1
    root="$(dirname "$(dirname "$(dirname "$tgt")")")"
    [[ -f "$root/.agent/user_tier_scripts.txt" ]] || return 1
    [[ "$root" != "$WS_PHYS" && "$root" != "$WS_ROOT" ]] || return 1
    return 0
}

# Does <link> point into THIS checkout's skills?
own_skill_link() {  # <link path>
    local raw tgt
    raw="$(readlink "$1" 2>/dev/null)" || return 1
    [[ "$raw" == "$WS_ROOT/.claude/skills/"* || "$raw" == "$WS_PHYS/.claude/skills/"* ]] && return 0
    tgt="$(readlink -f "$1" 2>/dev/null)" || return 1
    [[ "$tgt" == "$WS_PHYS/.claude/skills/"* ]]
}

# Every legacy workspace skill symlink, this checkout's or another's.
legacy_skill_links() {
    local link
    for link in "$SKILLS_DIR"/*; do
        [[ -L "$link" ]] || continue
        if own_skill_link "$link" || foreign_skill_link "$link"; then
            printf '%s\n' "$link"
        fi
    done
}

# ---------------------------------------------------- plugin, per root ---
have_claude() { command -v "$CLAUDE_BIN" >/dev/null 2>&1; }

# Every `claude plugin` call, stdin closed: a CLI version that stops to ask
# (a trust or confirmation prompt) then fails instead of hanging the
# installer on a read nobody will answer.
claude_plugin() { "$CLAUDE_BIN" plugin "$@" </dev/null; }

# Does <path> lie strictly inside <dir>? Both in `pwd -P` form; false when
# either is not on disk.
path_inside() {  # <path> <dir>
    local p d
    p="$(cd "$1" 2>/dev/null && pwd -P)" || return 1
    d="$(cd "$2" 2>/dev/null && pwd -P)" || return 1
    [[ "$p" == "$d/"* ]]
}

# One line per registered entry: <name>\t<path>\t<verdict>[\t<detail>], where
# verdict is
#   enable          a session root that gets the plugin
#   enable-outside-parent
#                   a parent= instance whose path is NOT inside its parent's:
#                   the parent's settings cannot reach it, so it is enabled
#                   as a session root of its own (a note says so; <detail>
#                   is its wording: why the instance is not inside)
#   skip-workspace  its git toplevel is this workspace checkout
#   skip-instance   a parent= instance inside its parent's directory (the
#                   parent root is enabled instead)
#   missing         the path does not exist on disk
# A malformed registry line is reported by the registry parser on stderr and
# dropped; the valid lines are still returned.
plugin_roots() {
    local entries name _type path fields top top_phys parent parent_path
    local outside detail
    entries="$(registry_entries_full "$WS_ROOT")" || true
    [[ -n "$entries" ]] || return 0
    while IFS=$'\t' read -r name _type path fields; do
        [[ -z "$name" ]] && continue
        outside=false
        detail=""
        if parent="$(_registry_field_of "$fields" parent)" && [[ -n "$parent" ]]; then
            # Skipping an instance is right only while the parent's
            # .claude/settings.local.json can reach its sessions, which
            # needs the instance to lie inside the parent's directory. The
            # registry does not require that, so check it here.
            parent_path="$(awk -F'\t' -v n="$parent" '$1 == n { print $3; exit }' <<< "$entries")"
            if [[ -n "$parent_path" ]] && path_inside "$path" "$parent_path"; then
                printf '%s\t%s\t%s\n' "$name" "$path" skip-instance
                continue
            fi
            outside=true
            # The registry parser already drops an instance whose parent is
            # unregistered or at the instance's own path, so a parent not on
            # disk is the one other way to land here.
            if [[ ! -d "$parent_path" ]]; then
                detail="whose parent's directory ($parent_path) is not on disk"
            else
                detail="outside its parent's directory ($parent_path), which the parent's plugin enable cannot reach"
            fi
        fi
        if [[ ! -d "$path" ]]; then
            printf '%s\t%s\t%s\n' "$name" "$path" missing
        elif top="$(git -C "$path" rev-parse --show-toplevel 2>/dev/null)" \
             && top_phys="$(cd "$top" 2>/dev/null && pwd -P)" \
             && [[ "$top_phys" == "$WS_PHYS" ]]; then
            printf '%s\t%s\t%s\n' "$name" "$path" skip-workspace
        elif [[ "$outside" == true ]]; then
            printf '%s\t%s\t%s\t%s\n' "$name" "$path" enable-outside-parent "$detail"
        else
            # Includes a root in no git repository at all: nothing there
            # sees the workspace's skills, so it is a session root like any.
            printf '%s\t%s\t%s\n' "$name" "$path" enable
        fi
    done <<< "$entries"
}

# Is <path> this checkout, lexically or as its `pwd -P` form?
is_this_checkout() {  # <path>
    local phys
    [[ "$1" == "$WS_ROOT" || "$1" == "$WS_PHYS" ]] && return 0
    phys="$(cd "$1" 2>/dev/null && pwd -P)" || return 1
    [[ "$phys" == "$WS_PHYS" ]]
}

# The plugin's state in <root>'s .claude/settings.local.json:
#   enabled      enabled, and the marketplace source is this checkout
#   foreign      the marketplace is declared from ANOTHER checkout (enabled
#                or not): that checkout's, not this one's, to remove
#   stale        enabled with no declaration, declared from this checkout
#                but not enabled, or declared from a source no longer on
#                disk (no checkout is left to remove it, so this one may)
#   absent       neither
#   unparseable  the file exists and is not JSON
plugin_state() {  # <root>
    local f="$1/.claude/settings.local.json" enabled src
    [[ -f "$f" ]] || { echo absent; return 0; }
    jq -e . "$f" >/dev/null 2>&1 || { echo unparseable; return 0; }
    enabled="$(jq -r --arg id "$PLUGIN_ID" '.enabledPlugins[$id] // false' "$f")"
    src="$(jq -r --arg m "$MARKETPLACE_NAME" '.extraKnownMarketplaces[$m].source.path // ""' "$f")"
    if [[ -n "$src" ]] && ! is_this_checkout "$src"; then
        if [[ -d "$src" ]]; then echo foreign; else echo stale; fi
    elif [[ "$enabled" == true && -n "$src" ]]; then
        echo enabled
    elif [[ "$enabled" == true || -n "$src" ]]; then
        echo stale
    else
        echo absent
    fi
}

# Is the plugin enabled in <root> (whatever declares it)? A root where it
# must not be can hold only a leftover declaration, which doubles nothing.
plugin_enabled_flag() {  # <root>
    jq -e --arg id "$PLUGIN_ID" '.enabledPlugins[$id] == true' "$1/.claude/settings.local.json" >/dev/null 2>&1
}

# The marketplace source <root> currently declares, or empty.
plugin_source() {  # <root>
    local f="$1/.claude/settings.local.json"
    [[ -f "$f" ]] || return 0
    jq -r --arg m "$MARKETPLACE_NAME" '.extraKnownMarketplaces[$m].source.path // ""' "$f" 2>/dev/null
}

# Does the claude CLI's machine-level record of the marketplace positively
# name another checkout? The CLI keys it by name, so a machine holds ONE
# source. A missing file, entry or `path` field (the format is the CLI's,
# not ours) says nothing either way, and is not "another checkout".
machine_record_foreign() {
    local src
    [[ -f "$KNOWN_MARKETPLACES" ]] || return 1
    src="$(jq -r --arg m "$MARKETPLACE_NAME" '.[$m].source.path? // empty' "$KNOWN_MARKETPLACES" 2>/dev/null)" || return 1
    [[ -n "$src" ]] && ! is_this_checkout "$src"
}

# The report for a root whose settings.local.json cannot be read: whether
# the plugin is there is unknowable, so the caller fails rather than guess,
# and the file is left exactly as it is.
unparseable_root() {  # <root> <what was not done>
    echo "  ERROR: $1/.claude/settings.local.json is not valid JSON -- $2 (fix it: jq . \"$1/.claude/settings.local.json\")" >&2
}

# Enable the plugin in one root. Idempotent: an already-enabled root is left
# alone, without running the CLI at all -- unless the machine-level record
# names another checkout: then that root is enabled afresh, which repoints
# the record here (last install wins, ADR-0017), and every later root is
# left alone again because the record now names this checkout. Also the
# entry point the registration flow (#332) re-runs for a newly registered
# root, by re-running this installer. Returns 1 on a CLI failure, an
# unparseable settings file, or a machine record the CLI left elsewhere.
enable_plugin_in_root() {  # <root>
    local root="$1" state
    state="$(plugin_state "$root")"
    case "$state" in
        enabled)
            if ! machine_record_foreign; then
                echo "  plugin already enabled: $root"
                return 0
            fi ;;
        unparseable)
            unparseable_root "$root" "not enabling the plugin there"
            return 1 ;;
    esac
    if ! have_claude; then
        echo "  NOTE: the claude CLI is not on PATH -- not enabling the $PLUGIN_NAME plugin in $root"
        return 0
    fi
    [[ "$state" == enabled ]] \
        && echo "  the claude CLI's machine-level record of the $MARKETPLACE_NAME marketplace names another checkout -- re-enabling in $root to take it over (last install wins)"
    # A leftover declaration -- another checkout's, this one's without the
    # enable, or this one's complete one being re-added to repoint the
    # machine record -- would make `marketplace add` refuse the name; drop
    # it first so this source takes its place. A registered root is this
    # checkout's registry's to repoint (uninstall, by contrast, leaves
    # another checkout's declaration alone).
    if [[ -n "$(plugin_source "$root")" ]]; then
        (cd "$root" && claude_plugin marketplace remove "$MARKETPLACE_NAME" --scope local >/dev/null 2>&1) || true
    fi
    if ! (cd "$root" && claude_plugin marketplace add "$WS_PHYS" --scope local >/dev/null) \
       || ! (cd "$root" && claude_plugin install "$PLUGIN_ID" --scope local >/dev/null); then
        echo "  ERROR: enabling the $PLUGIN_NAME plugin in $root failed (claude plugin exited non-zero)" >&2
        return 1
    fi
    if [[ "$(plugin_state "$root")" != enabled ]]; then
        echo "  ERROR: the claude CLI reported success, but $root/.claude/settings.local.json does not show $PLUGIN_ID enabled from $WS_PHYS" >&2
        return 1
    fi
    if machine_record_foreign; then
        echo "  ERROR: enabled the $PLUGIN_NAME plugin in $root, but the claude CLI's machine-level record ($KNOWN_MARKETPLACES) still names another checkout, so sessions may load that checkout's skills" >&2
        return 1
    fi
    echo "  enabled the $PLUGIN_NAME plugin in $root"
}

# Disable and undeclare the plugin in one root (best-effort CLI calls; the
# resulting file state is what decides success). Only called for a root
# where the plugin is present, so without the CLI it cannot succeed: the
# plugin stays enabled, and saying "removed" (or letting install report
# success over a doubled root) would be a lie.
disable_plugin_in_root() {  # <root>
    local root="$1"
    if ! have_claude; then
        echo "  ERROR: the claude CLI is not on PATH -- cannot remove the $PLUGIN_NAME plugin from $root; run \`claude plugin uninstall $PLUGIN_ID --scope local\` and \`claude plugin marketplace remove $MARKETPLACE_NAME --scope local\` there" >&2
        return 1
    fi
    (cd "$root" && claude_plugin uninstall "$PLUGIN_ID" --scope local >/dev/null 2>&1) || true
    (cd "$root" && claude_plugin marketplace remove "$MARKETPLACE_NAME" --scope local >/dev/null 2>&1) || true
    if [[ "$(plugin_state "$root")" == absent ]]; then
        echo "  removed the $PLUGIN_NAME plugin from $root"
        return 0
    fi
    echo "  ERROR: could not remove the $PLUGIN_NAME plugin from $root (see its .claude/settings.local.json)" >&2
    return 1
}

# ------------------------------------------------------------- uninstall ---
# Remove the plugin from one root, if it is this checkout's there. A
# declaration from another checkout is left alone with a note: a second
# checkout's uninstall must not take away the first's plugin. Sets
# uninstall_rc=1 on a failure.
uninstall_plugin_from() {  # <root>
    local root="$1"
    case "$(plugin_state "$root")" in
        enabled|stale) disable_plugin_in_root "$root" || uninstall_rc=1 ;;
        foreign) echo "  NOTE: the $PLUGIN_NAME plugin in $root is declared from another checkout ($(plugin_source "$root")) -- left for that checkout's --uninstall" ;;
        unparseable) unparseable_root "$root" "cannot tell whether the plugin is there; not removing it"; uninstall_rc=1 ;;
    esac
}

if [[ "$MODE" == "uninstall" ]]; then
    if [[ ! -e "$ROOT_FILE" && ! -e "$SESSION_HOOK_LINK" && ! -f "$SETTINGS" ]]; then
        echo "agent_workspace user tier: nothing installed at $CLAUDE_DIR"
        exit 0
    fi
    [[ -f "$ROOT_FILE" ]] && [[ "$(cat "$ROOT_FILE")" == "$WS_ROOT" ]] && rm -f "$ROOT_FILE" \
        && echo "  removed $ROOT_FILE"
    [[ -L "$SESSION_HOOK_LINK" ]] && rm -f "$SESSION_HOOK_LINK" \
        && echo "  removed $SESSION_HOOK_LINK"
    # Legacy skill symlinks into THIS checkout only; another checkout's are
    # that checkout's to remove.
    for link in "$SKILLS_DIR"/*; do
        [[ -L "$link" ]] || continue
        own_skill_link "$link" || continue
        rm -f "$link"
        echo "  removed legacy skill symlink: $(basename "$link")"
    done
    # The plugin, from every registered root that has it enabled or
    # declared -- skipped roots included, so a stale enable goes too.
    uninstall_rc=0
    while IFS=$'\t' read -r _name root _verdict; do
        [[ -z "$root" ]] && continue
        if [[ ! -d "$root" ]]; then
            echo "  NOTE: registered root $root is not on disk -- nothing to remove there"
            continue
        fi
        uninstall_plugin_from "$root"
    done < <(plugin_roots)
    uninstall_plugin_from "$WS_ROOT"
    if [[ -f "$SETTINGS" ]]; then
        require_parseable_settings || exit 1
        backup_settings || { echo "ERROR: could not back up $SETTINGS -- not proceeding" >&2; exit 1; }
        read_settings | jq --arg tag "$TAG" --argjson rules "$(installed_rules_json)" '
            .hooks //= {} |
            .hooks |= with_entries(
                .value |= map(select((._agent_workspace // "") != $tag))
            ) |
            .hooks |= with_entries(select(.value | length > 0)) |
            if (.permissions.allow? // null) != null then
                .permissions.allow |= map(select(. as $a | ($rules | index($a)) == null))
            else . end
        ' | write_settings && echo "  removed settings entries tagged $TAG"
    fi
    # Only now: the rewrite above reads this file to find rules written by an
    # earlier manifest generation, so removing it first would orphan them.
    [[ -f "$RULES_FILE" ]] && rm -f "$RULES_FILE" && echo "  removed $RULES_FILE"
    if [[ "$uninstall_rc" -ne 0 ]]; then
        echo "agent_workspace user tier removed, except the plugin in the root(s) above." >&2
        exit 1
    fi
    echo "agent_workspace user tier removed."
    exit 0
fi

# ----------------------------------------------------------------- check ---
if [[ "$MODE" == "check" ]]; then
    # An unparseable settings.json is reported as itself, not as drift. The
    # old behaviour read it as {}, reported every entry missing, and told the
    # user to re-run the installer -- which would then have overwritten it.
    if settings_unparseable; then
        echo "agent_workspace user tier: $SETTINGS is not valid JSON -- cannot check. Fix it (jq . \"$SETTINGS\") or move it aside." >&2
        exit 1
    fi

    # Installed, but for a DIFFERENT checkout. Previously this fell through
    # installed() to "not installed (optional)" and exited 0, so the one state
    # that actually breaks every skill's $WS_ROOT was the quietest one.
    if other_root="$(installed_elsewhere)"; then
        echo "agent_workspace user tier: installed for a different checkout: $other_root" >&2
        echo "  (this checkout is $WS_ROOT; every skill's \$WS_ROOT currently resolves to the other one)" >&2
        echo "  Re-run the installer with --force from whichever checkout should own the user tier." >&2
        exit 1
    fi

    if ! installed; then
        if [[ "$REQUIRE" == true ]]; then
            echo "agent_workspace user tier: NOT INSTALLED (--require) -- run .agent/scripts/user_tier_install.sh" >&2
            exit 1
        fi
        echo "agent_workspace user tier: not installed (optional; run .agent/scripts/user_tier_install.sh to enable project sessions)"
        exit 0
    fi

    drift=0
    note() { echo "  DRIFT: $1"; drift=1; }

    [[ -L "$SESSION_HOOK_LINK" ]] || note "missing SessionStart hook symlink at $SESSION_HOOK_LINK"
    if [[ -L "$SESSION_HOOK_LINK" && "$(readlink "$SESSION_HOOK_LINK")" != "$SESSION_HOOK_TARGET" ]]; then
        note "stale SessionStart hook symlink: points at $(readlink "$SESSION_HOOK_LINK"), expected $SESSION_HOOK_TARGET"
    fi
    [[ -e "$SESSION_HOOK_TARGET" ]] || note "SessionStart hook target does not exist: $SESSION_HOOK_TARGET"

    settings="$(read_settings)"
    export WS_ROOT_PREFIX="$WS_ROOT/"

    # Our hook entries, present and pointing at this checkout.
    # while-read, not `for cmd in $(...)`: a checkout path containing a space
    # or a glob character would otherwise word-split into permanent drift.
    while IFS= read -r cmd; do
        if ! jq -e --arg c "$cmd" --arg tag "$TAG" '
            [.hooks // {} | to_entries[] | .value[]
             | select((._agent_workspace // "") == $tag)
             | .hooks[]? | .command] | index($c) != null
        ' <<< "$settings" >/dev/null; then
            note "missing hook entry for $cmd"
        fi
    done < <(hook_commands; printf '%s\n' "$SESSION_HOOK_LINK")

    # Entries tagged as ours but naming a path outside this checkout, or
    # tagged for a DIFFERENT checkout (a second clone installed over us).
    foreign="$(jq -r --arg tag "$TAG" '
        [.hooks // {} | to_entries[] | .value[]
         | select((._agent_workspace // "") != "" and (._agent_workspace != $tag))
         | ._agent_workspace] | unique | .[]
    ' <<< "$settings")"
    if [[ -n "$foreign" ]]; then
        while IFS= read -r f; do
            note "settings.json has hook entries from another workspace checkout: $f"
        done <<< "$foreign"
    fi

    # The SessionStart entry deliberately names the ~/.claude symlink, not
    # the checkout path -- that indirection is what lets the hook be found
    # without the user tier hard-coding a checkout into every session. Every
    # OTHER command tagged as ours must live in this checkout.
    stale="$(jq -r --arg tag "$TAG" --arg ws "$WS_ROOT/" --arg link "$SESSION_HOOK_LINK" '
        [.hooks // {} | to_entries[] | .value[]
         | select((._agent_workspace // "") == $tag)
         | .hooks[]? | .command
         | select(. != $link)
         | select(startswith($ws) | not)] | .[]
    ' <<< "$settings")"
    if [[ -n "$stale" ]]; then
        while IFS= read -r st; do
            note "hook entry tagged as ours points outside this checkout: $st"
        done <<< "$stale"
    fi

    # Entries tagged as ours, inside this checkout, that the current
    # generation no longer produces -- a hook retired from the user tier
    # (#328). None of the checks above fire for it: it is tagged with this
    # checkout and names a path inside it, so without this case --check says
    # "installed and current" while settings.json still runs a hook the
    # checkout no longer ships (or no longer has on disk). Re-running the
    # installer clears it: install replaces our whole tagged generation.
    wanted_json="$( { hook_commands; printf '%s\n' "$SESSION_HOOK_LINK"; } \
        | jq -R . | jq -s . )"
    retired="$(jq -r --arg tag "$TAG" --arg ws "$WS_ROOT/" --argjson want "$wanted_json" '
        [.hooks // {} | to_entries[] | .value[]
         | select((._agent_workspace // "") == $tag)
         | .hooks[]? | .command
         | select(startswith($ws))
         | . as $c | select(($want | index($c)) == null)] | unique | .[]
    ' <<< "$settings")"
    if [[ -n "$retired" ]]; then
        while IFS= read -r rt; do
            note "hook entry tagged as ours is no longer generated: $rt (re-run the installer)"
        done <<< "$retired"
    fi

    # Permission rules.
    # `. as $w` matters: inside `$have | index(...)` a bare `.` would refer
    # to $have, not to the rule being tested, and every rule would look
    # present.
    missing_rules="$(jq -r --argjson want "$(allow_rules_json)" '
        (.permissions.allow // []) as $have
        | [$want[] | . as $w | select(($have | index($w)) == null)] | .[]
    ' <<< "$settings")"
    if [[ -n "$missing_rules" ]]; then
        n=$(grep -c . <<< "$missing_rules")
        note "$n permission allow-rule(s) missing (manifest changed? re-run the installer)"
    fi

    # Rules recorded by an earlier generation that the current manifest no
    # longer names: still in settings.json, no longer wanted.
    orphan_rules="$(jq -r --argjson want "$(allow_rules_json)" '
        (.permissions.allow // []) as $have
        | [$want[]] as $w
        | [$have[] | . as $r | select(($w | index($r)) == null)
           | select(startswith("Bash(" + $ENV.WS_ROOT_PREFIX))] | .[]
    ' <<< "$settings" 2>/dev/null)"
    if [[ -n "$orphan_rules" ]]; then
        n=$(grep -c . <<< "$orphan_rules")
        note "$n allow-rule(s) for this checkout are no longer in the manifest (re-run the installer, or --uninstall to clear them)"
    fi

    # Legacy skill symlinks: any link left in ~/.claude/skills/ that resolves
    # into an agent_workspace checkout (this one or another) is drift -- the
    # mechanism ADR-0017 retired, which shadows a project's own skills.
    while IFS= read -r link; do
        [[ -z "$link" ]] && continue
        note "legacy skill symlink (retired by ADR-0017; re-run the installer to remove it): $link -> $(readlink "$link")"
    done < <(legacy_skill_links)

    # The plugin, per registered root. JSON reads only -- no CLI call.
    own_enabled=false
    while IFS=$'\t' read -r name root verdict detail; do
        [[ -z "$name" ]] && continue
        state=""
        [[ -d "$root" ]] && state="$(plugin_state "$root")"
        case "$verdict" in
            enable|enable-outside-parent)
                if [[ "$verdict" == enable-outside-parent ]]; then
                    echo "  note: $name is a parent= instance $detail -- checked as a session root of its own ($root)"
                fi
                case "$state" in
                    enabled) own_enabled=true ;;
                    unparseable) note "$root/.claude/settings.local.json is not valid JSON -- cannot check the $PLUGIN_NAME plugin there" ;;
                    foreign) note "$PLUGIN_NAME plugin in registered root $name ($root) is declared from another checkout, $(plugin_source "$root"), not from this one (re-run the installer to repoint it)" ;;
                    *)
                        if have_claude; then
                            note "$PLUGIN_NAME plugin not enabled from this checkout in registered root $name ($root)"
                        else
                            echo "  note: $PLUGIN_NAME plugin not enabled in $name ($root); the claude CLI is not on PATH, so there is nothing to enable it with"
                        fi ;;
                esac ;;
            skip-workspace)
                case "$state" in
                    enabled|stale|foreign)
                        if plugin_enabled_flag "$root"; then
                            note "$PLUGIN_NAME plugin is enabled in $name ($root), whose git toplevel is this workspace checkout -- it already sees the bare skills, so every skill loads twice (re-run the installer to remove it)"
                        else
                            note "$PLUGIN_NAME marketplace is declared, with the plugin not enabled, in $name ($root), whose git toplevel is this workspace checkout -- a leftover (re-run the installer to remove it)"
                        fi ;;
                    unparseable) note "$root/.claude/settings.local.json is not valid JSON -- cannot check that the $PLUGIN_NAME plugin is NOT enabled there (a doubled root)" ;;
                esac ;;
            skip-instance)
                [[ "$state" == unparseable ]] \
                    && note "$root/.claude/settings.local.json is not valid JSON -- cannot check the $PLUGIN_NAME plugin in parent= instance $name" ;;
            missing)
                echo "  note: registered root $name is not on disk ($root) -- plugin not checked there" ;;
        esac
    done < <(plugin_roots)

    # The workspace checkout itself: its sessions see the bare skills by
    # directory walk-up, so the plugin there doubles every one of them. The
    # installer never enables it there; a `claude plugin install` run by hand
    # (or from a p11-shape root, whose local scope may resolve here) would.
    case "$(plugin_state "$WS_ROOT")" in
        enabled|stale|foreign)
            if plugin_enabled_flag "$WS_ROOT"; then
                note "$PLUGIN_NAME plugin is enabled in the workspace checkout itself ($WS_ROOT/.claude/settings.local.json) -- its sessions already see the bare skills, so every skill loads twice (re-run the installer to remove it)"
            else
                note "$PLUGIN_NAME marketplace is declared, with the plugin not enabled, in the workspace checkout itself ($WS_ROOT/.claude/settings.local.json) -- a leftover (re-run the installer to remove it)"
            fi ;;
        unparseable) note "$WS_ROOT/.claude/settings.local.json is not valid JSON -- cannot check the $PLUGIN_NAME plugin there" ;;
    esac

    # The machine-level marketplace record. The CLI keys it by marketplace
    # name, so a machine holds ONE `agent-workspace` source: when it names
    # another checkout, sessions may load that checkout's skills even where
    # every settings.local.json above declares this one, and nothing else
    # here would notice. Read-only, and only a record that positively names
    # a different directory is drift -- a missing file, entry or `path`
    # field (the format is the CLI's, not ours) says nothing either way.
    # Only while some root has the plugin enabled from this checkout: with
    # none, no session of this checkout's loads the record, and install
    # (which repoints it from an enabled root) would have nowhere to do it.
    if [[ "$own_enabled" == true ]] && machine_record_foreign; then
        note "the claude CLI's machine-level record of the $MARKETPLACE_NAME marketplace ($KNOWN_MARKETPLACES) names another checkout, $(jq -r --arg m "$MARKETPLACE_NAME" '.[$m].source.path' "$KNOWN_MARKETPLACES") -- one source per machine, so sessions may load that checkout's skills (re-run this installer to take it over: last install wins)"
    fi

    if [[ "$drift" -eq 0 ]]; then
        echo "agent_workspace user tier: installed and current ($WS_ROOT)"
        exit 0
    fi
    echo "agent_workspace user tier: DRIFT detected -- re-run .agent/scripts/user_tier_install.sh" >&2
    exit 1
fi

# --------------------------------------------------------------- install ---
# Never rewrite a settings.json we cannot parse -- that is how every user key
# in it would be lost.
require_parseable_settings || exit 1

# The user tier is singular. If another checkout owns it, say so and stop:
# taking it over silently repoints every skill's $WS_ROOT, and the losing
# checkout's --check used to report a cheerful "not installed (optional)".
if other_root="$(installed_elsewhere)" && [[ "$FORCE" != true ]]; then
    cat >&2 <<EOF
ERROR: the user tier is already installed for a different workspace checkout.

  currently installed: $other_root
  this checkout:       $WS_ROOT

Only one checkout can own ~/.claude at a time -- every skill's \$WS_ROOT
follows $ROOT_FILE. Re-run with --force to take it over, or run the
installer from $other_root instead.
EOF
    exit 1
fi
if [[ -n "${other_root:-}" && "$FORCE" == true ]]; then
    echo "  --force: taking the user tier over from $other_root"
fi

mkdir -p "$CLAUDE_DIR" "$HOOKS_DIR"

backup_settings || { echo "ERROR: could not back up $SETTINGS -- not proceeding" >&2; exit 1; }

# 1. the workspace-root file (no trailing newline -- callers do a bare `cat`)
printf '%s' "$WS_ROOT" > "$ROOT_FILE"
echo "  wrote $ROOT_FILE"

# 1b. and a record of exactly which allow-rules this generation wrote.
# Without it, uninstall could only match the CURRENT manifest, so rules from
# an earlier generation -- a script since renamed or dropped from the
# manifest -- stayed in settings.json forever with nothing able to name them.
allow_rules_json > "$RULES_FILE"
echo "  recorded $(jq 'length' < "$RULES_FILE") generated allow-rule(s) in $RULES_FILE"

# 2. the SessionStart hook symlink
if [[ ! -e "$SESSION_HOOK_TARGET" ]]; then
    echo "ERROR: hook target missing: $SESSION_HOOK_TARGET" >&2
    exit 1
fi
if [[ -e "$SESSION_HOOK_LINK" && ! -L "$SESSION_HOOK_LINK" ]]; then
    echo "ERROR: $SESSION_HOOK_LINK exists and is not a symlink -- not overwriting" >&2
    exit 1
fi
ln -sfn "$SESSION_HOOK_TARGET" "$SESSION_HOOK_LINK"
echo "  linked $SESSION_HOOK_LINK -> $SESSION_HOOK_TARGET"

# 3+4. settings.json: our hook entries and allow-rules, replacing any
# previous generation of ours (that is what makes this idempotent) and
# leaving everything else in the file untouched.
PRE_HOOKS_JSON="$(jq -n --arg tag "$TAG" \
    --arg log "$WS_ROOT/.claude/hooks/log-tool-use.sh" '
    {
      _agent_workspace: $tag,
      hooks: [
        {type: "command", command: $log, timeout: 5}
      ]
    }')"

SESSION_HOOKS_JSON="$(jq -n --arg tag "$TAG" --arg cmd "$SESSION_HOOK_LINK" '
    {
      _agent_workspace: $tag,
      hooks: [{type: "command", command: $cmd, timeout: 10}]
    }')"

read_settings | jq \
    --arg tag "$TAG" \
    --argjson force "$([[ "$FORCE" == true ]] && echo true || echo false)" \
    --argjson pre "$PRE_HOOKS_JSON" \
    --argjson ses "$SESSION_HOOKS_JSON" \
    --argjson rules "$(allow_rules_json)" '
    .hooks //= {}
    | .hooks.PreToolUse //= []
    | .hooks.SessionStart //= []
    # Drop the previous generation of agent_workspace entries, keeping the
    # user'"'"'s own (which carry no marker at all).
    #
    # Normally that means entries tagged with THIS checkout. Under --force we
    # are deliberately taking the tier over from another checkout, so every
    # marker-carrying entry goes regardless of which checkout tagged it --
    # otherwise the takeover leaves the old checkout'"'"'s SessionStart and
    # PreToolUse entries in place beside ours, both layers get injected into
    # every session, and --check reports drift immediately after a --force
    # that exited 0 claiming success.
    | .hooks.PreToolUse   |= map(select(($force and (._agent_workspace // "") != "") | not) | select((._agent_workspace // "") != $tag))
    | .hooks.SessionStart |= map(select(($force and (._agent_workspace // "") != "") | not) | select((._agent_workspace // "") != $tag))
    | .hooks.PreToolUse   += [$pre]
    | .hooks.SessionStart += [$ses]
    | .permissions //= {}
    | .permissions.allow //= []
    | .permissions.allow = ((.permissions.allow + $rules) | unique)
' | write_settings || { echo "ERROR: failed to write $SETTINGS" >&2; exit 1; }
echo "  merged hook entries and $(allow_rules_json | jq 'length') allow-rules into $SETTINGS"

# 5. retire legacy skill symlinks (ADR-0017), this checkout's or another's
while IFS= read -r link; do
    [[ -z "$link" ]] && continue
    rm -f "$link"
    echo "  removed legacy skill symlink: $(basename "$link")"
done < <(legacy_skill_links)

# 6. the plugin, per registered root
plugin_rc=0
while IFS=$'\t' read -r name root verdict detail; do
    [[ -z "$name" ]] && continue
    case "$verdict" in
        enable)
            enable_plugin_in_root "$root" || plugin_rc=1 ;;
        enable-outside-parent)
            echo "  NOTE: $name is a parent= instance $detail -- enabled as a session root of its own ($root)"
            enable_plugin_in_root "$root" || plugin_rc=1 ;;
        skip-workspace)
            echo "  skipped $name: its git toplevel is this workspace checkout, which already provides the skills"
            case "$(plugin_state "$root")" in
                enabled|stale|foreign) disable_plugin_in_root "$root" || plugin_rc=1 ;;
                unparseable) unparseable_root "$root" "cannot tell whether the plugin doubles its skills there"; plugin_rc=1 ;;
            esac ;;
        skip-instance)
            echo "  skipped $name: a parent= instance; its parent root gets the plugin"
            if [[ "$(plugin_state "$root")" == unparseable ]]; then
                unparseable_root "$root" "cannot tell whether the plugin is there"
                plugin_rc=1
            fi ;;
        missing)
            echo "  NOTE: registered root $name is not on disk ($root) -- plugin not enabled there" ;;
    esac
done < <(plugin_roots)
# ...and never in the workspace checkout itself (see --check).
case "$(plugin_state "$WS_ROOT")" in
    enabled|stale|foreign)
        if plugin_enabled_flag "$WS_ROOT"; then
            echo "  the $PLUGIN_NAME plugin is enabled in the workspace checkout itself, where every skill would load twice -- removing it"
        else
            echo "  the $PLUGIN_NAME marketplace is declared, with the plugin not enabled, in the workspace checkout itself -- removing the leftover"
        fi
        disable_plugin_in_root "$WS_ROOT" || plugin_rc=1 ;;
    unparseable)
        unparseable_root "$WS_ROOT" "cannot tell whether the plugin doubles every skill in the workspace checkout itself"
        plugin_rc=1 ;;
esac
if [[ "$plugin_rc" -ne 0 ]]; then
    echo "" >&2
    echo "agent_workspace user tier installed from $WS_ROOT, but the plugin step failed in the root(s) above." >&2
    exit 1
fi

echo ""
echo "agent_workspace user tier installed from $WS_ROOT"
echo "Verify with: .agent/scripts/user_tier_install.sh --check"
exit 0
