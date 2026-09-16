#!/usr/bin/env bash
# Tests for the per-machine project registry (issue #227 — #172 step 2):
# .agent/scripts/_project_registry.sh parsing, adapter dispatcher resolution
# (--project, cwd discovery, legacy fallback), per-project command config,
# validate_workspace.py both-shapes support, sync.py --project-root, and
# worktree_create.sh --project wiring.
#
# Tests run against sandbox workspaces (mktemp) with the real scripts copied
# in, so no test touches the real workspace, its registry, or the network
# (a failing `gh` stub shadows the real CLI for worktree tests).
#
# Run: bash .agent/scripts/tests/test_project_registry.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"

PASS=0
FAIL=0

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label"
        echo "    expected: ${expected}"
        echo "    actual:   ${actual}"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local label="$1" needle="$2" haystack="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label"
        echo "    needle:   ${needle}"
        echo "    haystack: ${haystack}"
        FAIL=$((FAIL + 1))
    fi
}

# ---- Sandbox helpers ----

SANDBOXES=()
cleanup() {
    local sb
    for sb in ${SANDBOXES[@]+"${SANDBOXES[@]}"}; do
        rm -rf "$sb"
    done
}
trap cleanup EXIT

make_sandbox() {
    local sb
    sb="$(mktemp -d)"
    SANDBOXES+=("$sb")
    mkdir -p "$sb/.agent/scripts/lib" "$sb/.agent/project_types"
    cp "$REAL_ROOT/.agent/scripts/adapter" "$sb/.agent/scripts/adapter"
    cp "$REAL_ROOT/.agent/scripts/_project_registry.sh" "$sb/.agent/scripts/_project_registry.sh"
    cp "$REAL_ROOT/.agent/scripts/validate_adapter.sh" "$sb/.agent/scripts/validate_adapter.sh"
    cp "$REAL_ROOT/.agent/scripts/lib/"*.py "$sb/.agent/scripts/lib/"
    cp -r "$REAL_ROOT/.agent/project_types/single_project" "$sb/.agent/project_types/"
    echo "$sb"
}

make_git_repo() {
    local dir="$1" url="$2"
    mkdir -p "$dir"
    git -C "$dir" init --quiet
    git -C "$dir" remote add origin "$url"
}

# Write a stub command that proves it ran and where. Echoes the stub path.
make_stub() {
    local sb="$1" name="$2" rc="${3:-0}"
    mkdir -p "$sb/bin"
    cat > "$sb/bin/$name" <<'EOF'
#!/usr/bin/env bash
echo "STUB_${STUB_NAME}_RAN_IN:$(pwd -P) args:$*"
exit ${STUB_RC}
EOF
    sed -i'' -e "s/\${STUB_NAME}/$name/" -e "s/\${STUB_RC}/$rc/" "$sb/bin/$name"
    chmod +x "$sb/bin/$name"
    echo "$sb/bin/$name"
}

# Register a project: make_registered_project <sb> <name> [<path>]
# Creates a git checkout at the hosting dir and appends a registry line.
# The origin URL is a local file:// path that fails fast, so fetch attempts
# (worktree_create's remote-branch probe) never touch the network.
make_registered_project() {
    local sb="$1" name="$2" path="${3:-}"
    local dir="${path:-$sb/projects/$name}"
    make_git_repo "$dir" "file:///nonexistent/${name}.git"
    if [ -n "$path" ]; then
        echo "$name single_project $path" >> "$sb/.agent/projects.local"
    else
        echo "$name single_project" >> "$sb/.agent/projects.local"
    fi
    echo "$dir"
}

# ---- Registry parsing tests ----

test_registry_absent_is_legacy() {
    echo "TEST: no registry → legacy project_root (from a cwd outside projects/)"
    local sb out
    sb="$(make_sandbox)"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" project_root)" || true
    assert_eq "legacy root" "$sb/project" "$out"
}

test_registry_malformed_line_fails() {
    echo "TEST: malformed registry line fails loud"
    local sb out rc=0
    sb="$(make_sandbox)"
    echo "bad name with spaces single_project" > "$sb/.agent/projects.local"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project bad project_root 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "names the malformed line" "projects.local:1" "$out"
}

test_registry_rejects_dotdot_name() {
    echo "TEST: registry name containing '..' is rejected"
    local sb out rc=0
    sb="$(make_sandbox)"
    echo "a..b single_project" > "$sb/.agent/projects.local"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project a..b project_root 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "flags the name" "invalid project name 'a..b'" "$out"
}

test_registry_comments_and_blanks() {
    echo "TEST: comments and blank lines are ignored"
    local sb out
    sb="$(make_sandbox)"
    {
        echo "# a comment"
        echo ""
        echo "alpha single_project   # trailing comment"
    } > "$sb/.agent/projects.local"
    make_git_repo "$sb/projects/alpha" "git@github.com:owner/alpha.git"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project alpha project_root)" || true
    assert_eq "entry parsed despite comments" "$sb/projects/alpha" "$out"
}

# ---- Dispatcher resolution tests ----

test_project_flag_resolves() {
    echo "TEST: --project <name> resolves root and type from the registry"
    local sb out
    sb="$(make_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project alpha project_root)" || true
    assert_eq "default hosting dir" "$sb/projects/alpha" "$out"
}

test_project_flag_after_verb() {
    echo "TEST: --project is accepted after the verb (shim forwarding)"
    local sb out
    sb="$(make_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" project_root --project alpha)" || true
    assert_eq "same resolution" "$sb/projects/alpha" "$out"
}

test_project_flag_unknown() {
    echo "TEST: --project with an unregistered name fails and lists projects"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project nope project_root 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "names the unknown project" "'nope' is not registered" "$out"
    assert_contains "lists registered projects" "alpha" "$out"
}

test_registry_type_resolution() {
    echo "TEST: registry project type selects the adapter (not workspace config)"
    local sb out
    sb="$(make_sandbox)"
    mkdir -p "$sb/.agent/project_types/other_type"
    cat > "$sb/.agent/project_types/other_type/adapter.sh" <<'EOF'
adapter_setup() { :; }
adapter_sync() { :; }
adapter_validate() { :; }
adapter_build() { :; }
adapter_test() { :; }
adapter_install() { :; }
adapter_env() { :; }
adapter_project_root() { echo "OTHER_TYPE_ROOT"; }
adapter_repos() { :; }
adapter_scope_for_pr() { :; }
EOF
    echo "beta other_type" > "$sb/.agent/projects.local"
    mkdir -p "$sb/projects/beta"
    # Workspace config says single_project; the registry entry must win.
    echo 'PROJECT_TYPE=single_project' > "$sb/.agent/project_config.sh"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project beta project_root)" || true
    assert_eq "registry type dispatched" "OTHER_TYPE_ROOT" "$out"
}

test_cwd_discovery() {
    echo "TEST: cwd inside a hosting dir resolves that project"
    local sb out
    sb="$(make_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    mkdir -p "$sb/projects/alpha/src/deep"
    out="$(cd "$sb/projects/alpha/src/deep" && "$sb/.agent/scripts/adapter" project_root)" || true
    assert_eq "resolved from cwd" "$sb/projects/alpha" "$out"
}

test_from_flag_discovery() {
    echo "TEST: --from <dir> resolves like cwd discovery"
    local sb out
    sb="$(make_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    mkdir -p "$sb/projects/alpha/src"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --from "$sb/projects/alpha/src" project_root)" || true
    assert_eq "resolved from --from dir" "$sb/projects/alpha" "$out"
}

test_custom_path_entry() {
    echo "TEST: registry path field overrides the default hosting dir"
    local sb out custom
    sb="$(make_sandbox)"
    custom="$sb/elsewhere/alpha_checkout"
    make_registered_project "$sb" alpha "$custom" >/dev/null
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project alpha project_root)" || true
    assert_eq "custom path used" "$custom" "$out"
    out="$(cd "$custom" && "$sb/.agent/scripts/adapter" project_root)" || true
    assert_eq "cwd discovery works on custom path" "$custom" "$out"
}

test_unregistered_under_projects_fails() {
    echo "TEST: cwd under projects/ without a matching entry fails loud"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    mkdir -p "$sb/projects/orphan"
    out="$(cd "$sb/projects/orphan" && "$sb/.agent/scripts/adapter" project_root 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "explains the problem" "no registered project owns it" "$out"
}

test_legacy_unaffected_by_registry() {
    echo "TEST: registry present + cwd outside projects/ still resolves legacy"
    local sb out
    sb="$(make_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" project_root)" || true
    assert_eq "legacy root wins outside projects/" "$sb/project" "$out"
}

# ---- Per-project command config tests ----

test_build_uses_projects_d_config() {
    echo "TEST: build --project uses .agent/projects.d/<name>.sh in the project root"
    local sb out stub
    sb="$(make_sandbox)"
    stub="$(make_stub "$sb" alphabuild)"
    make_registered_project "$sb" alpha >/dev/null
    mkdir -p "$sb/.agent/projects.d"
    echo "BUILD_CMD=\"$stub\"" > "$sb/.agent/projects.d/alpha.sh"
    # Workspace config would run something else — must not be used.
    echo 'BUILD_CMD="false"' > "$sb/.agent/project_config.sh"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project alpha build)" || true
    assert_contains "per-project stub ran in project root" \
        "STUB_alphabuild_RAN_IN:$(cd "$sb/projects/alpha" && pwd -P)" "$out"
}

test_build_falls_back_to_workspace_config() {
    echo "TEST: build --project falls back to project_config.sh without projects.d file"
    local sb out stub
    sb="$(make_sandbox)"
    stub="$(make_stub "$sb" sharedbuild)"
    make_registered_project "$sb" alpha >/dev/null
    echo "BUILD_CMD=\"$stub\"" > "$sb/.agent/project_config.sh"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project alpha build)" || true
    assert_contains "shared stub ran in project root" \
        "STUB_sharedbuild_RAN_IN:$(cd "$sb/projects/alpha" && pwd -P)" "$out"
}

# ---- sync.py --project-root ----

test_sync_project_root() {
    echo "TEST: adapter --project sync targets the registry checkout (--dry-run)"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project alpha sync --dry-run 2>&1)" || rc=$?
    assert_eq "sync exits 0" "0" "$rc"
    assert_contains "project checkout targeted" "project (alpha)" "$out"
}

# ---- validate_workspace.py tests ----

run_validate() {
    local sb="$1"
    python3 "$sb/.agent/scripts/validate_workspace.py" 2>&1
}

make_validate_sandbox() {
    local sb
    sb="$(make_sandbox)"
    cp "$REAL_ROOT/.agent/scripts/validate_workspace.py" "$sb/.agent/scripts/"
    echo "$sb"
}

test_validate_registry_only() {
    echo "TEST: validate passes on a registry-only machine (no legacy project/)"
    local sb out rc=0
    sb="$(make_validate_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    out="$(run_validate "$sb")" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "passes" "PASSED" "$out"
}

test_validate_missing_checkout() {
    echo "TEST: validate flags a registered project without a checkout"
    local sb out rc=0
    sb="$(make_validate_sandbox)"
    echo "ghost single_project" > "$sb/.agent/projects.local"
    out="$(run_validate "$sb")" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_contains "names the project" "project 'ghost'" "$out"
}

test_validate_unknown_type() {
    echo "TEST: validate flags a registry entry with an unknown project type"
    local sb out rc=0
    sb="$(make_validate_sandbox)"
    make_git_repo "$sb/projects/alpha" "git@github.com:owner/alpha.git"
    echo "alpha no_such_type" > "$sb/.agent/projects.local"
    out="$(run_validate "$sb")" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_contains "names the type" "unknown project type 'no_such_type'" "$out"
}

test_validate_malformed_registry() {
    echo "TEST: validate flags malformed registry lines"
    local sb out rc=0
    sb="$(make_validate_sandbox)"
    make_git_repo "$sb/project" "git@github.com:owner/legacy.git"
    echo "alpha single_project extra junk" > "$sb/.agent/projects.local"
    out="$(run_validate "$sb")" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_contains "reports the parse error" "expected key=value, got 'junk'" "$out"
}

test_validate_legacy_still_works() {
    echo "TEST: validate on a legacy-only machine behaves as before"
    local sb out rc=0
    sb="$(make_validate_sandbox)"
    make_git_repo "$sb/project" "git@github.com:owner/legacy.git"
    out="$(run_validate "$sb")" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "passes" "PASSED" "$out"
}

test_validate_neither_shape() {
    echo "TEST: validate still fails when neither shape is configured"
    local sb out rc=0
    sb="$(make_validate_sandbox)"
    out="$(run_validate "$sb")" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_contains "legacy guidance kept" "project/ directory does not exist" "$out"
}

# ---- worktree_create.sh --project wiring ----

# Worktree sandboxes get the worktree scripts, their helpers, and a failing
# gh stub so issue lookups degrade gracefully offline.
make_worktree_sandbox() {
    local sb
    sb="$(make_sandbox)"
    cp "$REAL_ROOT/.agent/scripts/worktree_create.sh" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/worktree_enter.sh" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/_worktree_helpers.sh" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/_issue_helpers.sh" "$sb/.agent/scripts/"
    mkdir -p "$sb/stubbin"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$sb/stubbin/gh"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$sb/stubbin/git-bug"
    chmod +x "$sb/stubbin/gh" "$sb/stubbin/git-bug"
    # The sandbox root itself must be a git repo (workspace repo stand-in).
    git -C "$sb" init --quiet
    echo "$sb"
}

# Seed a commit so worktree add has a HEAD to branch from.
seed_commit() {
    local dir="$1"
    (cd "$dir" \
        && git -c user.name=t -c user.email=t@t commit --allow-empty -m init --quiet)
}

test_worktree_create_unknown_repo() {
    echo "TEST: worktree_create --project with unregistered name fails and lists projects"
    local sb out rc=0
    sb="$(make_worktree_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --issue 999 --type project --project nope 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "names the unknown project" "'nope' is not registered" "$out"
    assert_contains "lists registered projects" "alpha" "$out"
}

test_worktree_create_registry_repo() {
    echo "TEST: worktree_create --project <name> creates the worktree from the registry checkout"
    local sb out rc=0
    sb="$(make_worktree_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    seed_commit "$sb/projects/alpha"
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --issue 999 --type project --project alpha 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_eq "worktree exists under the registry name" \
        "yes" "$([ -d "$sb/worktrees/project/alpha/issue-alpha-999" ] && echo yes || echo no)"
    assert_eq "worktree is a checkout of the alpha repo" \
        "feature/issue-999" \
        "$(git -C "$sb/worktrees/project/alpha/issue-alpha-999" branch --show-current 2>/dev/null)"
}

test_worktree_create_single_registry_autoselect() {
    echo "TEST: worktree_create without --project auto-selects the single registered project"
    local sb out rc=0
    sb="$(make_worktree_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    seed_commit "$sb/projects/alpha"
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --issue 998 --type project 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "announces the auto-selection" "Using registered project 'alpha'" "$out"
    assert_eq "worktree created" \
        "yes" "$([ -d "$sb/worktrees/project/alpha/issue-alpha-998" ] && echo yes || echo no)"
}

test_worktree_create_dashed_name_roundtrip() {
    echo "TEST: dashed registry name survives create → enter --project round-trip"
    local sb out rc=0
    sb="$(make_worktree_sandbox)"
    make_registered_project "$sb" my-proj >/dev/null
    seed_commit "$sb/projects/my-proj"
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --issue 996 --type project --project my-proj 2>&1)" || rc=$?
    assert_eq "create exit 0" "0" "$rc"
    assert_eq "worktree dir uses the raw name" \
        "yes" "$([ -d "$sb/worktrees/project/my-proj/issue-my-proj-996" ] && echo yes || echo no)"
    rc=0
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_enter.sh" --issue 996 --type project --project my-proj --print-path 2>&1)" || rc=$?
    assert_eq "enter --project finds it" "0" "$rc"
    assert_eq "enter resolves the same path" \
        "$sb/worktrees/project/my-proj/issue-my-proj-996" "$out"
}

test_worktree_create_repo_alias() {
    echo "TEST: worktree_create --repo alpha still succeeds (alias for --project)"
    local sb out rc=0
    sb="$(make_worktree_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    seed_commit "$sb/projects/alpha"
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --issue 995 --type project --repo alpha 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_eq "worktree exists under the registry name" \
        "yes" "$([ -d "$sb/worktrees/project/alpha/issue-alpha-995" ] && echo yes || echo no)"
}

test_worktree_create_single_repo_no_manifest_file() {
    echo "TEST: a single_project worktree gets no .worktree-repos and no untracked files"
    local sb out rc=0 wt
    sb="$(make_worktree_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    seed_commit "$sb/projects/alpha"
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --issue 994 --type project --project alpha 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    wt="$sb/worktrees/project/alpha/issue-alpha-994"
    assert_eq "no .worktree-repos file written" \
        "false" "$([ -e "$wt/.worktree-repos" ] && echo true || echo false)"
    assert_eq "worktree checkout has no untracked/uncommitted files" \
        "" "$(git -C "$wt" status --porcelain)"
}

test_worktree_create_multiple_requires_repo() {
    echo "TEST: worktree_create without --project fails when multiple projects are registered"
    local sb out rc=0
    sb="$(make_worktree_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    make_registered_project "$sb" beta >/dev/null
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --issue 997 --type project 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "asks for --project" "Use --project to specify" "$out"
    assert_contains "lists alpha" "--project alpha" "$out"
    assert_contains "lists beta" "--project beta" "$out"
}


# ---- Trailing fields, parent roots, worktree dirs, root guard (#265) ----

# Source the registry helper in a subshell and run a function against a
# sandbox. Usage: reg <sb> <function> [args...]
reg() {
    local sb="$1"; shift
    (
        # shellcheck source=/dev/null
        source "$sb/.agent/scripts/_project_registry.sh"
        "$@"
    )
}

# Two-instance parent layout at <sb>/p11-ng. Usage: make_parent_layout <sb> [default_instance]
make_parent_layout() {
    local sb="$1" dflt="${2:-}"
    mkdir -p "$sb/p11-ng"
    make_git_repo "$sb/p11-ng/jazzy" "file:///nonexistent/p11.git"
    make_git_repo "$sb/p11-ng/rolling" "file:///nonexistent/p11.git"
    {
        if [ -n "$dflt" ]; then
            echo "p11 project $sb/p11-ng default_instance=$dflt"
        else
            echo "p11 project $sb/p11-ng"
        fi
        echo "p11-jazzy single_project $sb/p11-ng/jazzy parent=p11 distro=jazzy role=dev"
        echo "p11-rolling single_project $sb/p11-ng/rolling parent=p11 distro=rolling"
    } >> "$sb/.agent/projects.local"
}

test_registry_fields_parse() {
    echo "TEST: trailing key=value fields parse; three-column output unchanged"
    local sb out
    sb="$(make_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    echo "beta single_project $sb/beta distro=jazzy role=dev worktrees=wt/beta" >> "$sb/.agent/projects.local"
    mkdir -p "$sb/beta"
    out="$(reg "$sb" registry_entries "$sb")"
    assert_eq "three columns for a field-bearing line" \
        "$(printf 'beta\tsingle_project\t%s/beta' "$sb")" "$(grep '^beta' <<< "$out")"
    out="$(reg "$sb" registry_entries_full "$sb")"
    assert_eq "full form carries the fields" \
        "$(printf 'beta\tsingle_project\t%s/beta\tdistro=jazzy role=dev worktrees=%s/wt/beta' "$sb" "$sb")" \
        "$(grep '^beta' <<< "$out")"
    assert_eq "registry_field reads a field" "jazzy" "$(reg "$sb" registry_field "$sb" beta distro)"
    assert_eq "registry_field on a missing field returns 1" "1" \
        "$(reg "$sb" registry_field "$sb" alpha distro >/dev/null 2>&1; echo $?)"
    assert_eq "fields without a path: path defaults" \
        "$(printf 'gamma\tsingle_project\t%s/projects/gamma\trole=ops' "$sb")" \
        "$(echo "gamma single_project role=ops" >> "$sb/.agent/projects.local"; reg "$sb" registry_entries_full "$sb" | grep '^gamma')"
}

test_registry_fields_rejected() {
    echo "TEST: unknown, malformed and duplicate fields fail loud"
    local sb out rc
    sb="$(make_sandbox)"
    for line in \
        "a single_project $sb/a colour=red" \
        "b single_project $sb/b distro=" \
        "c single_project $sb/c junk" \
        "d single_project $sb/d distro=jazzy distro=rolling" \
        "e single_project $sb/e distro=Jazzy!" \
        "f single_project $sb/f parent=x..y"; do
        echo "$line" > "$sb/.agent/projects.local"
        rc=0
        out="$(reg "$sb" registry_entries "$sb" 2>&1)" || rc=$?
        assert_eq "rc 2 for: $line" "2" "$rc"
        assert_contains "line reported for: $line" "projects.local:1" "$out"
    done
    echo "a single_project $sb/a colour=red" > "$sb/.agent/projects.local"
    out="$(reg "$sb" registry_entries "$sb" 2>&1)" || true
    assert_contains "unknown field names the known keys" "known: parent worktrees role distro default_instance" "$out"
    # '=' is forbidden in paths (a third token with '=' is a field), so this
    # is rejected as an unknown field rather than silently misparsed.
    echo "eq single_project /srv/project=blue" > "$sb/.agent/projects.local"
    rc=0; out="$(reg "$sb" registry_entries "$sb" 2>&1)" || rc=$?
    assert_eq "'=' in a path is rejected" "2" "$rc"
    # A value containing '=' (e.g. a worktrees path) is not a duplicate key.
    mkdir -p "$sb/w"
    echo "w single_project $sb/w worktrees=$sb/w/role=foo role=dev" > "$sb/.agent/projects.local"
    assert_eq "value with '=' is not a duplicate key" "dev" "$(reg "$sb" registry_field "$sb" w role 2>&1)"
    assert_eq "worktrees value keeps its '='" "$sb/w/role=foo" "$(reg "$sb" registry_field "$sb" w worktrees 2>&1)"
    # Field tokens are never glob-expanded against the caller's cwd.
    mkdir -p "$sb/globdir/worktrees=wt-secret-evil" "$sb/g"
    echo "g single_project $sb/g worktrees=wt-*" > "$sb/.agent/projects.local"
    assert_eq "no pathname expansion of field tokens" "$sb/wt-*" "$(cd "$sb/globdir" && reg "$sb" registry_field "$sb" g worktrees 2>&1)"
    # The getter itself must not glob either: a file whose name matches a
    # serialized field must not change what registry_field returns.
    mkdir -p "$sb/globdir2" && touch "$sb/globdir2/role=x" "$sb/globdir2/role=y"
    echo "g2 single_project $sb/g2 role=* distro=jazzy" > "$sb/.agent/projects.local"
    rc=0; out="$(cd "$sb/globdir2" && reg "$sb" registry_field "$sb" g2 distro 2>&1)" || rc=$?
    assert_eq "role=* is rejected by the role regex, not expanded" "2" "$rc"
    echo "g2 single_project $sb/g2 worktrees=$sb/g2/role=* distro=jazzy" > "$sb/.agent/projects.local"
    assert_eq "getter does not expand a value that looks like a glob" "$sb/g2/role=*" "$(cd "$sb/globdir2" && reg "$sb" registry_field "$sb" g2 worktrees 2>&1)"
    # CRLF line endings are tolerated and never leak '\r' into paths.
    printf 'crlf single_project %s/crlf distro=jazzy\r\n' "$sb" > "$sb/.agent/projects.local"
    mkdir -p "$sb/crlf"
    assert_eq "CRLF path clean" "$(printf 'crlf\tsingle_project\t%s/crlf' "$sb")" "$(reg "$sb" registry_entries "$sb" 2>&1)"
    assert_eq "CRLF field clean" "jazzy" "$(reg "$sb" registry_field "$sb" crlf distro 2>&1 | od -c | grep -c '\\r' | sed 's/^0$/jazzy/')"
    # distro follows the ros2_colcon rule (no hyphens); role may have them.
    echo "h single_project $sb/h distro=my-distro" > "$sb/.agent/projects.local"
    rc=0; out="$(reg "$sb" registry_entries "$sb" 2>&1)" || rc=$?
    assert_eq "hyphenated distro rejected" "2" "$rc"
    echo "h single_project $sb/h role=my-role distro=jazzy" > "$sb/.agent/projects.local"
    assert_eq "hyphenated role accepted" "my-role" "$(reg "$sb" registry_field "$sb" h role 2>&1)"
    # Two entries resolving to one directory (literal or symlink alias).
    mkdir -p "$sb/real" && ln -s "$sb/real" "$sb/alias"
    printf 'r1 single_project %s/real\nr2 single_project %s/alias\n' "$sb" "$sb" > "$sb/.agent/projects.local"
    rc=0; out="$(reg "$sb" registry_entries "$sb" 2>&1)" || rc=$?
    assert_eq "aliased path → rc 2" "2" "$rc"
    assert_contains "names the collision" "'r2' resolves to $sb/real, already registered" "$out"
    assert_eq "first entry kept" "r1" "$(reg "$sb" registry_names "$sb" 2>/dev/null)"
    # Duplicate names are rejected (first definition wins for lookups).
    printf 'dup single_project %s/a\ndup single_project %s/b\n' "$sb" "$sb" > "$sb/.agent/projects.local"
    rc=0; out="$(reg "$sb" registry_entries "$sb" 2>&1)" || rc=$?
    assert_eq "duplicate name → rc 2" "2" "$rc"
    assert_contains "names the duplicate" "projects.local:2: duplicate project name 'dup'" "$out"
    assert_eq "first definition kept" "$(printf 'dup\tsingle_project\t%s/a' "$sb")" "$(reg "$sb" registry_entries "$sb" 2>/dev/null)"
}

test_registry_parent_rules() {
    echo "TEST: parent= and default_instance= cross-line rules"
    local sb out rc
    sb="$(make_sandbox)"
    echo "inst single_project $sb/inst parent=ghost" > "$sb/.agent/projects.local"
    rc=0; out="$(reg "$sb" registry_entries "$sb" 2>&1)" || rc=$?
    assert_eq "unregistered parent → rc 2" "2" "$rc"
    assert_contains "names the missing parent" "parent 'ghost' of 'inst' is not registered" "$out"
    printf 'notparent single_project %s/np\ninst single_project %s/inst parent=notparent\n' "$sb" "$sb" > "$sb/.agent/projects.local"
    rc=0; out="$(reg "$sb" registry_entries "$sb" 2>&1)" || rc=$?
    assert_eq "non-project parent → rc 2" "2" "$rc"
    assert_contains "names the wrong type" "is type 'single_project', not 'project'" "$out"
    assert_eq "valid line still printed" "notparent" "$(reg "$sb" registry_names "$sb" 2>/dev/null)"
    echo "solo single_project $sb/solo default_instance=solo" > "$sb/.agent/projects.local"
    rc=0; out="$(reg "$sb" registry_entries "$sb" 2>&1)" || rc=$?
    assert_contains "default_instance on non-parent rejected" "only valid on a 'project' line" "$out"
    printf 'p project %s/p default_instance=other\nother single_project %s/o\n' "$sb" "$sb" > "$sb/.agent/projects.local"
    rc=0; out="$(reg "$sb" registry_entries "$sb" 2>&1)" || rc=$?
    assert_contains "default_instance must be an instance" "default_instance 'other' is not an instance of 'p'" "$out"
    printf 'outer project %s/o\ninner project %s/o/i parent=outer\nleaf single_project %s/o/i/l parent=inner\n' "$sb" "$sb" "$sb" > "$sb/.agent/projects.local"
    rc=0; out="$(reg "$sb" registry_entries "$sb" 2>&1)" || rc=$?
    assert_eq "nested parent → rc 2" "2" "$rc"
    assert_contains "no nesting" "parent root 'inner' may not itself have a parent" "$out"
}

test_registry_instances_and_default() {
    echo "TEST: registry_instances / registry_default_instance"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_parent_layout "$sb"
    assert_eq "instances listed" "$(printf 'p11-jazzy\np11-rolling')" "$(reg "$sb" registry_instances "$sb" p11)"
    out="$(reg "$sb" registry_default_instance "$sb" p11 2>&1)" || rc=$?
    assert_eq "two instances, no default → rc 1" "1" "$rc"
    assert_contains "lists the instances" "--project p11-jazzy" "$out"
    assert_contains "hints at default_instance" "default_instance=" "$out"
    assert_eq "non-parent name passes through" "p11-jazzy" "$(reg "$sb" registry_default_instance "$sb" p11-jazzy)"
    sb="$(make_sandbox)"
    make_parent_layout "$sb" p11-rolling
    assert_eq "default_instance honoured" "p11-rolling" "$(reg "$sb" registry_default_instance "$sb" p11)"
    sb="$(make_sandbox)"
    mkdir -p "$sb/one"
    printf 'p project %s/one\nonly single_project %s/one/a parent=p\n' "$sb" "$sb" > "$sb/.agent/projects.local"
    mkdir -p "$sb/one/a"
    assert_eq "single instance used without a default" "only" "$(reg "$sb" registry_default_instance "$sb" p)"
}

test_registry_worktree_dir() {
    echo "TEST: registry_worktree_dir: default, override, legacy fallback"
    local sb
    sb="$(make_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    echo "beta single_project $sb/beta worktrees=$sb/beta/.wt" >> "$sb/.agent/projects.local"
    echo "gamma single_project $sb/gamma worktrees=wt/gamma" >> "$sb/.agent/projects.local"
    assert_eq "default under the hosting dir" "$sb/projects/alpha/worktrees" "$(reg "$sb" registry_worktree_dir "$sb" alpha)"
    assert_eq "absolute override under the entry's path" "$sb/beta/.wt" "$(reg "$sb" registry_worktree_dir "$sb" beta)"
    assert_eq "relative override resolves against the workspace" "$sb/wt/gamma" "$(reg "$sb" registry_worktree_dir "$sb" gamma)"
    assert_eq "unregistered name → legacy location" "$sb/worktrees/project/legacy" "$(reg "$sb" registry_worktree_dir "$sb" legacy)"
    assert_eq "legacy fallback rejects a traversal name" "1" "$(reg "$sb" registry_worktree_dir "$sb" "../../outside" >/dev/null 2>&1; echo $?)"
    assert_eq "legacy fallback rejects a slash" "1" "$(reg "$sb" registry_worktree_dir "$sb" "a/b" >/dev/null 2>&1; echo $?)"
    # An override outside both the entry's path and the workspace would be
    # refused by registry_require_root, so the parser rejects it up front.
    echo "delta single_project $sb/delta worktrees=/tmp/elsewhere" > "$sb/.agent/projects.local"
    local rc=0 out
    out="$(reg "$sb" registry_entries "$sb" 2>&1)" || rc=$?
    assert_eq "worktrees outside root → rc 2" "2" "$rc"
    assert_contains "says where it must lie" "must lie under $sb/delta or under the workspace root" "$out"
    # A relative override that climbs out with '..' is normalized before the
    # containment check, so it is rejected too.
    echo "eps single_project $sb/eps worktrees=../outside" > "$sb/.agent/projects.local"
    rc=0; out="$(reg "$sb" registry_entries "$sb" 2>&1)" || rc=$?
    assert_eq "worktrees=../outside → rc 2" "2" "$rc"
    echo "zeta single_project $sb/zeta worktrees=$sb/zeta/../zeta/wt" > "$sb/.agent/projects.local"
    assert_eq "'..' that stays inside is normalized and kept" "$sb/zeta/wt" "$(reg "$sb" registry_worktree_dir "$sb" zeta 2>&1)"
    echo "eta single_project $sb/eta/../eta" > "$sb/.agent/projects.local"
    assert_eq "entry path itself is normalized" "$(printf 'eta\tsingle_project\t%s/eta' "$sb")" "$(reg "$sb" registry_entries "$sb" 2>&1)"
    echo "a..b single_project" > "$sb/.agent/projects.local"
    assert_eq "parse error → rc 2" "2" "$(reg "$sb" registry_worktree_dir "$sb" alpha >/dev/null 2>&1; echo $?)"
}

test_registry_require_root() {
    echo "TEST: registry_require_root accepts workspace and registered roots, refuses elsewhere"
    local sb out rc outside
    sb="$(make_sandbox)"
    outside="$(mktemp -d)"
    SANDBOXES+=("$outside")
    make_registered_project "$sb" alpha "$outside/alpha" >/dev/null
    mkdir -p "$outside/alpha/deep" "$outside/unrelated"
    assert_eq "workspace root ok" "0" "$(reg "$sb" registry_require_root "$sb" "$sb"; echo $?)"
    assert_eq "inside workspace ok" "0" "$(reg "$sb" registry_require_root "$sb" "$sb/.agent"; echo $?)"
    assert_eq "registered root ok" "0" "$(reg "$sb" registry_require_root "$sb" "$outside/alpha/deep"; echo $?)"
    rc=0; out="$(reg "$sb" registry_require_root "$sb" "$outside/unrelated" 2>&1)" || rc=$?
    assert_eq "unrelated dir refused" "1" "$rc"
    assert_contains "says why" "refusing to run" "$out"
    assert_contains "names the registry" "projects.local" "$out"
    rc=0; out="$(reg "$sb" registry_require_root "$sb" "$sb/nope" 2>&1)" || rc=$?
    assert_eq "missing dir refused" "1" "$rc"
    echo "a..b single_project" > "$sb/.agent/projects.local"
    assert_eq "parse error → rc 2 (never guess)" "2" "$(reg "$sb" registry_require_root "$sb" "$outside/unrelated" >/dev/null 2>&1; echo $?)"
}

test_adapter_parent_resolves_instance() {
    echo "TEST: adapter resolves a parent root to its default_instance / only instance"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_parent_layout "$sb" p11-rolling
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project p11 project_root)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_eq "--project parent → default instance root" "$sb/p11-ng/rolling" "$out"
    out="$(cd "$sb/p11-ng" && "$sb/.agent/scripts/adapter" project_root)" || true
    assert_eq "cwd at parent → default instance root" "$sb/p11-ng/rolling" "$out"
    out="$(cd "$sb/p11-ng/jazzy" && "$sb/.agent/scripts/adapter" project_root)" || true
    assert_eq "cwd inside an instance → that instance (longest match)" "$sb/p11-ng/jazzy" "$out"
}

test_adapter_parent_ambiguous_fails() {
    echo "TEST: adapter on a parent with several instances and no default fails and lists them"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_parent_layout "$sb"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project p11 project_root 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "lists jazzy" "--project p11-jazzy" "$out"
    assert_contains "lists rolling" "--project p11-rolling" "$out"
}

test_adapter_registry_distro_and_role_exported() {
    echo "TEST: adapter exposes registry role/distro fields to the adapter type"
    local sb out
    sb="$(make_sandbox)"
    mkdir -p "$sb/.agent/project_types/probe"
    cat > "$sb/.agent/project_types/probe/adapter.sh" <<'EOF'
adapter_setup() { :; }
adapter_sync() { :; }
adapter_validate() { :; }
adapter_build() { :; }
adapter_test() { :; }
adapter_install() { :; }
adapter_env() { :; }
adapter_project_root() { echo "role=${ACTIVE_PROJECT_ROLE:-} distro=${ACTIVE_PROJECT_DISTRO:-}"; }
adapter_repos() { :; }
adapter_scope_for_pr() { :; }
adapter_worktree_repos() { :; }
adapter_worktree_env() { :; }
EOF
    mkdir -p "$sb/x"
    echo "x probe $sb/x role=operator distro=jazzy" > "$sb/.agent/projects.local"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project x project_root)" || true
    assert_eq "fields reach the adapter" "role=operator distro=jazzy" "$out"
    echo "x probe $sb/x" > "$sb/.agent/projects.local"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project x project_root)" || true
    assert_eq "absent fields are empty" "role= distro=" "$out"
}

test_validate_parent_root() {
    echo "TEST: validate accepts a parent root with instances; flags missing dir / no instances"
    local sb out rc=0
    sb="$(make_validate_sandbox)"
    make_parent_layout "$sb" p11-rolling
    out="$(run_validate "$sb")" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    rc=0
    echo "lonely project $sb/lonely" >> "$sb/.agent/projects.local"
    mkdir -p "$sb/lonely"
    out="$(run_validate "$sb")" || rc=$?
    assert_eq "parent without instances → exit 1" "1" "$rc"
    assert_contains "names it" "parent root 'lonely': no instances registered" "$out"
    rc=0
    sb="$(make_validate_sandbox)"
    printf 'p project %s/missing\ni single_project %s/i parent=p\n' "$sb" "$sb" > "$sb/.agent/projects.local"
    make_git_repo "$sb/i" "file:///nonexistent/i.git"
    out="$(run_validate "$sb")" || rc=$?
    assert_eq "parent dir missing → exit 1" "1" "$rc"
    assert_contains "names the dir" "parent root 'p': directory does not exist" "$out"
}

test_validate_python_parser_matches_shell() {
    echo "TEST: python and shell parsers produce the same entries and the same errors"
    local sb shell_out py_out
    sb="$(make_sandbox)"
    make_parent_layout "$sb" p11-rolling
    echo "bad single_project $sb/bad colour=red" >> "$sb/.agent/projects.local"
    echo "p11 single_project $sb/dup" >> "$sb/.agent/projects.local"
    echo "nest project $sb/nest parent=p11" >> "$sb/.agent/projects.local"
    printf 'crlf single_project %s/crlf distro=jazzy\r\n' "$sb" >> "$sb/.agent/projects.local"
    echo "far single_project $sb/far worktrees=/tmp/elsewhere" >> "$sb/.agent/projects.local"
    echo "climb single_project $sb/climb worktrees=../outside" >> "$sb/.agent/projects.local"
    mkdir -p "$sb/real2" "$sb/crlf" && ln -s "$sb/real2" "$sb/alias2"
    echo "r1 single_project $sb/real2" >> "$sb/.agent/projects.local"
    echo "r2 single_project $sb/alias2" >> "$sb/.agent/projects.local"
    echo "h single_project $sb/h distro=my-distro" >> "$sb/.agent/projects.local"
    echo "w single_project $sb/w worktrees=$sb/w/../w/x" >> "$sb/.agent/projects.local"
    # Shell: entries as name|type|path|fields, then errors without the file prefix.
    shell_out="$( { reg "$sb" registry_entries_full "$sb" 2>/dev/null | tr '\t' '|' || true; echo "--errors--"; reg "$sb" registry_entries_full "$sb" 2>&1 >/dev/null | sed -E 's/^ERROR: [^:]+:([0-9]+): /\1: /' || true; } )"
    # Python: the same shape from read_projects_registry.
    py_out="$(cd "$sb/.agent/scripts/lib" && python3 -c "
import workspace
entries, errors = workspace.read_projects_registry('$sb')
for e in entries:
    fields = ' '.join(f'{k}={v}' for k, v in e['fields'].items())
    print(f\"{e['name']}|{e['type']}|{e['path']}|{fields}\")
print('--errors--')
for err in errors:
    print(err.split(':', 1)[1].lstrip() if err.startswith('$sb') else err)
")"
    if [[ "$shell_out" != "$py_out" ]]; then
        echo "  --- parser diff (shell < > python) ---"
        diff <(printf '%s\n' "$shell_out") <(printf '%s\n' "$py_out") | sed 's/^/    /' || true
    fi
    assert_eq "identical entries and errors from both parsers" "$shell_out" "$py_out"
    assert_contains "the comparison covered the '..' escape" "for 'climb' must lie under" "$shell_out"
    assert_contains "the comparison covered the alias collision" "'r2' resolves to $sb/real2" "$shell_out"
    assert_contains "the comparison kept the in-root '..' override" "w|single_project|$sb/w|worktrees=$sb/w/x" "$shell_out"
}

test_worktree_create_parent_default_instance() {
    echo "TEST: worktree_create --project <parent> uses the default instance"
    local sb out rc=0
    sb="$(make_worktree_sandbox)"
    make_parent_layout "$sb" p11-rolling
    seed_commit "$sb/p11-ng/rolling"
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --issue 996 --type project --project p11 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "announces the instance" "Using instance 'p11-rolling' of 'p11'" "$out"
    assert_eq "worktree keyed by the instance name" \
        "yes" "$([ -d "$sb/worktrees/project/p11-rolling/issue-p11-rolling-996" ] && echo yes || echo no)"
}

test_worktree_parent_round_trip() {
    echo "TEST: create/enter/remove --project <parent> all resolve to the same instance"
    local sb out rc=0
    sb="$(make_worktree_sandbox)"
    cp "$REAL_ROOT/.agent/scripts/worktree_remove.sh" "$sb/.agent/scripts/"
    make_parent_layout "$sb" p11-rolling
    seed_commit "$sb/p11-ng/rolling"
    (cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --issue 994 --type project --project p11 >/dev/null 2>&1) || rc=$?
    assert_eq "create exit 0" "0" "$rc"
    rc=0
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_enter.sh" --issue 994 --type project --project p11 --print-path 2>&1)" || rc=$?
    assert_eq "enter --project parent finds the instance worktree" "$sb/worktrees/project/p11-rolling/issue-p11-rolling-994" "$out"
    rc=0
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_remove.sh" --issue 994 --type project --project p11 --force 2>&1)" || rc=$?
    assert_eq "remove --project parent exit 0" "0" "$rc"
    assert_eq "worktree gone" "no" "$([ -d "$sb/worktrees/project/p11-rolling/issue-p11-rolling-994" ] && echo yes || echo no)"
}

test_worktree_create_parent_not_autoselected() {
    echo "TEST: worktree_create without --project never auto-selects a parent root"
    local sb out rc=0
    sb="$(make_worktree_sandbox)"
    mkdir -p "$sb/one"
    printf 'p project %s/one\nonly single_project %s/one/a parent=p\n' "$sb" "$sb" > "$sb/.agent/projects.local"
    make_git_repo "$sb/one/a" "file:///nonexistent/a.git"
    seed_commit "$sb/one/a"
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --issue 995 --type project 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "auto-selects the instance, not the parent" "Using registered project 'only'" "$out"
}

# ---- Run all tests ----
echo "=== project registry / multi-tenant hosting tests ==="
echo ""

test_registry_absent_is_legacy
test_registry_malformed_line_fails
test_registry_rejects_dotdot_name
test_registry_comments_and_blanks
test_project_flag_resolves
test_project_flag_after_verb
test_project_flag_unknown
test_registry_type_resolution
test_cwd_discovery
test_from_flag_discovery
test_custom_path_entry
test_unregistered_under_projects_fails
test_legacy_unaffected_by_registry
test_build_uses_projects_d_config
test_build_falls_back_to_workspace_config
test_sync_project_root
test_validate_registry_only
test_validate_missing_checkout
test_validate_unknown_type
test_validate_malformed_registry
test_validate_legacy_still_works
test_validate_neither_shape
test_worktree_create_unknown_repo
test_worktree_create_registry_repo
test_worktree_create_single_registry_autoselect
test_worktree_create_dashed_name_roundtrip
test_worktree_create_repo_alias
test_worktree_create_single_repo_no_manifest_file
test_worktree_create_multiple_requires_repo
test_registry_fields_parse
test_registry_fields_rejected
test_registry_parent_rules
test_registry_instances_and_default
test_registry_worktree_dir
test_registry_require_root
test_adapter_parent_resolves_instance
test_adapter_parent_ambiguous_fails
test_adapter_registry_distro_and_role_exported
test_validate_parent_root
test_validate_python_parser_matches_shell
test_worktree_create_parent_default_instance
test_worktree_parent_round_trip
test_worktree_create_parent_not_autoselected

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -eq 0 ]]
