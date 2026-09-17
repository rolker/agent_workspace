#!/usr/bin/env bash
# .agent/scripts/tests/test_precommit_hook_path.sh
# Issue #272: the pre-commit hook is shared by every worktree and pins the
# interpreter that installed it. Three layers keep it valid:
#   1. Makefile: VENV_DIR / STAMP / PRE_COMMIT resolve to the checkout that
#      owns .git (git's common dir), never to a worktree — so `make setup` or
#      `make repair` from a worktree cannot install a hook pointing at a
#      worktree venv that later disappears.
#   2. validate_workspace.py: finds the hook via the common dir (works from a
#      worktree, where .git is a file) and fails loudly when INSTALL_PYTHON no
#      longer exists.
#   3. worktree_create.sh: warns at creation time when the shared hook is
#      broken, naming the repair command.
# Hermetic: mktemp -d sandboxes only.
# Run: bash .agent/scripts/tests/test_precommit_hook_path.sh

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
SANDBOXES=()
cleanup() { local s; for s in ${SANDBOXES[@]+"${SANDBOXES[@]}"}; do rm -rf "$s"; done; }
trap cleanup EXIT

mk_ws() {  # a workspace-shaped repo with a worktree
    local sb
    sb="$(mktemp -d)"; SANDBOXES+=("$sb")
    mkdir -p "$sb/.agent/scripts/lib" "$sb/.agent/project_types" "$sb/worktrees/workspace"
    cp "$REAL_ROOT/Makefile" "$sb/Makefile"
    cp "$REAL_ROOT/.agent/scripts/validate_workspace.py" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/lib/"*.py "$sb/.agent/scripts/lib/"
    cp "$REAL_ROOT/.agent/scripts/adapter" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/_project_registry.sh" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/validate_adapter.sh" "$sb/.agent/scripts/"
    cp -r "$REAL_ROOT/.agent/project_types/single_project" "$sb/.agent/project_types/"
    for f in worktree_create.sh worktree_enter.sh _worktree_helpers.sh _issue_helpers.sh; do
        cp "$REAL_ROOT/.agent/scripts/$f" "$sb/.agent/scripts/"
    done
    mkdir -p "$sb/stubbin"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$sb/stubbin/gh"; printf '#!/usr/bin/env bash\nexit 1\n' > "$sb/stubbin/git-bug"
    chmod +x "$sb/stubbin/gh" "$sb/stubbin/git-bug"
    touch "$sb/requirements.txt"
    git -C "$sb" init --quiet -b main
    git -C "$sb" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m init
    git -C "$sb" worktree add --quiet "$sb/worktrees/workspace/issue-workspace-5" -b feature/issue-5 >/dev/null 2>&1
    echo "$sb"
}
write_hook() {  # <sb> <install_python>
    printf '#!/usr/bin/env bash\n# start templated\nINSTALL_PYTHON=%s\nARGS=(hook-impl)\n# end templated\nexit 0\n' "$2" > "$1/.git/hooks/pre-commit"
    chmod +x "$1/.git/hooks/pre-commit"
}

# ---- layer 1: Makefile dev-tools root from inside a worktree ----
echo "TEST: from a worktree, make resolves VENV_DIR / STAMP / PRE_COMMIT to the main checkout, not the worktree"
sb="$(mk_ws)"
wt="$sb/worktrees/workspace/issue-workspace-5"
vars="$(cd "$wt" && make -pn -f "$sb/Makefile" 2>/dev/null | grep -E '^(WS_ROOT|VENV_DIR|STAMP|PRE_COMMIT|MAIN_ROOT) ' )"
[[ "$vars" == *"VENV_DIR := $sb/.venv"* ]] && pass "VENV_DIR is <main>/.venv" || fail "VENV_DIR (got: $vars)"
[[ "$vars" == *"STAMP := $sb/.make"* ]] && pass "STAMP is <main>/.make" || fail "STAMP (got: $vars)"
[[ "$vars" == *"PRE_COMMIT := $sb/.venv/bin/pre-commit"* ]] && pass "PRE_COMMIT is <main>/.venv/bin/pre-commit" || fail "PRE_COMMIT (got: $vars)"
[[ "$vars" == *"MAIN_ROOT := $wt"* ]] && pass "MAIN_ROOT unchanged (still the worktree — issue #239's scope, not this fix)" || fail "MAIN_ROOT (got: $vars)"
# and from the main checkout the same values hold
vars_main="$(cd "$sb" && make -pn -f "$sb/Makefile" 2>/dev/null | grep -E '^(VENV_DIR|WS_ROOT) ')"
[[ "$vars_main" == *"VENV_DIR := $sb/.venv"* ]] && pass "from the main checkout VENV_DIR is <main>/.venv" || fail "main VENV_DIR (got: $vars_main)"
# outside any git repo the fallback keeps make usable
nogit="$(mktemp -d)"; SANDBOXES+=("$nogit"); cp "$sb/Makefile" "$nogit/"
vars_nogit="$(cd "$nogit" && make -pn -f "$nogit/Makefile" 2>/dev/null | grep -E '^VENV_DIR ')"
[[ "$vars_nogit" == *"VENV_DIR := $nogit/.venv"* ]] && pass "outside a repo WS_ROOT falls back to MAIN_ROOT" || fail "no-git fallback (got: $vars_nogit)"
# the repair / setup recipes cd to the common root before `pre-commit install`
recipe="$(cd "$wt" && make -n -f "$sb/Makefile" repair 2>/dev/null | grep 'pre-commit install')"
[[ "$recipe" == *"cd $sb && "*"pre-commit install"* ]] && pass "make repair installs the hook from the main checkout" || fail "repair recipe (got: $recipe)"
# and the shared venv is fed by the SHARED requirements.txt, not the worktree's copy
recipe="$(cd "$wt" && make -n -f "$sb/Makefile" repair 2>/dev/null | grep 'pip install')"
[[ "$recipe" == *"-r $sb/requirements.txt"* && "$recipe" != *"-r $wt/requirements.txt"* ]] \
    && pass "make repair installs from <main>/requirements.txt" || fail "repair requirements source (got: $recipe)"
recipe="$(cd "$wt" && rm -rf "$sb/.make" && make -n -f "$sb/Makefile" "$sb/.make/setup-dev.done" 2>/dev/null | grep 'pip install -r\|pip install --quiet -r')"
[[ "$recipe" == *"-r $sb/requirements.txt"* ]] && pass "setup-dev installs from <main>/requirements.txt" || fail "setup-dev requirements source (got: $recipe)"

# the shared-state recipes run under one lock (Copilot round 1: two agents on a fresh machine)
for tgt in repair clean "$sb/.make/setup-dev.done"; do
    recipe="$(cd "$wt" && rm -rf "$sb/.make" && make -n -f "$sb/Makefile" "$tgt" 2>/dev/null | grep -c "flock $sb/.make/.lock")"
    [[ "$recipe" -ge 1 ]] && pass "make $tgt runs its shared-state mutation under flock on <main>/.make/.lock" || fail "lock on $tgt (matches=$recipe)"
done

# ---- layer 2: validate_workspace.py from a worktree ----
echo "TEST: validate_workspace.py finds the shared hook from a worktree and flags a vanished interpreter"
write_hook "$sb" "$sb/worktrees/workspace/issue-workspace-99/.venv/bin/python3"   # a removed worktree's venv
out="$(cd "$wt" && python3 "$wt/.agent/scripts/validate_workspace.py" 2>&1)" || rc=$?; rc=${rc:-0}
# (the worktree has its own copy of the scripts, as real worktrees do)
mkdir -p "$wt/.agent/scripts/lib" "$wt/.agent/project_types"
cp "$sb/.agent/scripts/validate_workspace.py" "$wt/.agent/scripts/"; cp "$sb/.agent/scripts/lib/"*.py "$wt/.agent/scripts/lib/"
cp "$sb/.agent/scripts/adapter" "$sb/.agent/scripts/_project_registry.sh" "$sb/.agent/scripts/validate_adapter.sh" "$wt/.agent/scripts/"
cp -r "$sb/.agent/project_types/single_project" "$wt/.agent/project_types/"
rc=0; out="$(cd "$wt" && python3 "$wt/.agent/scripts/validate_workspace.py" 2>&1)" || rc=$?
if [[ "$rc" -ne 0 && "$out" == *"points to a Python that no longer exists"*"make repair"* ]]; then
    pass "vanished INSTALL_PYTHON is reported from a worktree with the repair command"
else
    fail "vanished interpreter (rc=$rc out=${out:0:300})"
fi
# a hook pointing at the main venv (existing) is OK
mkdir -p "$sb/.venv/bin"; printf '#!/bin/sh\n' > "$sb/.venv/bin/python3"; chmod +x "$sb/.venv/bin/python3"
write_hook "$sb" "$sb/.venv/bin/python3"
rc=0; out="$(cd "$wt" && python3 "$wt/.agent/scripts/validate_workspace.py" --verbose 2>&1)" || rc=$?
[[ "$out" == *"pre-commit hook: OK"* ]] && pass "a hook pinned to the main venv is OK, checked from the worktree" || fail "ok hook (out=${out:0:300})"
# a present but non-executable interpreter is what the hook's own `-x` test rejects
chmod -x "$sb/.venv/bin/python3"
rc=0; out="$(cd "$wt" && python3 "$wt/.agent/scripts/validate_workspace.py" 2>&1)" || rc=$?
[[ "$rc" -ne 0 && "$out" == *"no longer exists"* ]] && pass "a present but non-executable interpreter is flagged (mirrors the hook's -x test)" || fail "non-executable (rc=$rc out=${out:0:200})"
chmod +x "$sb/.venv/bin/python3"
# an existing but foreign interpreter is still "wrong path"
write_hook "$sb" "/bin/sh"
rc=0; out="$(cd "$wt" && python3 "$wt/.agent/scripts/validate_workspace.py" 2>&1)" || rc=$?
[[ "$rc" -ne 0 && "$out" == *"wrong path"* ]] && pass "an existing but foreign interpreter is still flagged as the wrong path" || fail "wrong path (out=${out:0:200})"

# ---- layer 3: worktree_create.sh warns at creation ----
echo "TEST: worktree_create.sh warns when the shared hook's interpreter is gone, and stays silent when it is fine"
sb2="$(mk_ws)"
write_hook "$sb2" "$sb2/worktrees/workspace/issue-workspace-99/.venv/bin/python3"
rc=0; out="$(cd "$sb2" && PATH="$sb2/stubbin:$PATH" "$sb2/.agent/scripts/worktree_create.sh" --issue 6 --type workspace 2>&1)" || rc=$?
if [[ "$rc" -eq 0 && "$out" == *"shared pre-commit hook points to a Python that no longer exists"*"make -C \"$sb2\" repair"* ]] \
    && [[ -d "$sb2/worktrees/workspace/issue-workspace-6" ]]; then
    pass "broken hook: worktree still created, warning names the interpreter and the repair command"
else
    fail "broken hook warning (rc=$rc out=${out:0:400})"
fi
mkdir -p "$sb2/.venv/bin"; printf '#!/bin/sh\n' > "$sb2/.venv/bin/python3"; chmod +x "$sb2/.venv/bin/python3"
write_hook "$sb2" "$sb2/.venv/bin/python3"
rc=0; out="$(cd "$sb2" && PATH="$sb2/stubbin:$PATH" "$sb2/.agent/scripts/worktree_create.sh" --issue 7 --type workspace 2>&1)" || rc=$?
[[ "$rc" -eq 0 && "$out" != *"pre-commit hook points"* ]] && pass "healthy hook: no warning" || fail "healthy hook (rc=$rc out=${out:0:300})"

# a PROJECT worktree is checked against the project repo's hook, not the workspace's (Copilot round 1)
sb3="$(mk_ws)"
mkdir -p "$sb3/.venv/bin"; printf '#!/bin/sh\n' > "$sb3/.venv/bin/python3"; chmod +x "$sb3/.venv/bin/python3"
write_hook "$sb3" "$sb3/.venv/bin/python3"                       # workspace hook healthy
mkdir -p "$sb3/project"; git -C "$sb3/project" init --quiet -b main
git -C "$sb3/project" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m init
git -C "$sb3/project" remote add origin "file:///nonexistent/legacyrepo.git"
printf '#!/usr/bin/env bash\n# start templated\nINSTALL_PYTHON=%s\n# end templated\nexit 0\n' "$sb3/gone/.venv/bin/python3" > "$sb3/project/.git/hooks/pre-commit"
chmod +x "$sb3/project/.git/hooks/pre-commit"                     # project hook broken
rc=0; out="$(cd "$sb3" && PATH="$sb3/stubbin:$PATH" "$sb3/.agent/scripts/worktree_create.sh" --issue 8 --type project 2>&1)" || rc=$?
if [[ "$rc" -eq 0 && "$out" == *"shared pre-commit hook points to a Python that no longer exists"*"$sb3/gone/.venv/bin/python3"*"make -C \"$sb3/project\" repair"* ]]; then
    pass "project worktree: the warning names the PROJECT repo's broken hook and its repair root"
else
    fail "project worktree hook (rc=$rc out=${out:0:400})"
fi

echo ""
echo "test_precommit_hook_path: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
