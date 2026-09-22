---
issue: 267
---

# Issue #267 — Prototype a general ROS 2 manifest resolver (west-based) with a temporary home in the workspace (#172 step 4 re-scope)

## Plan
**Status**: complete
**When**: 2026-09-16 00:00
**By**: Claude Code Agent (claude-sonnet-5)

Plan file: `.agent/work-plans/issue-267/plan.md`.

Dual prototype: own resolver (Python, PyYAML-only, in `tools/ros-manifest/`) built and tested
this milestone against the real p11-jazzy manifest fixture; west-based variant specified in
`tools/ros-manifest/docs/west-variant.md` for the next milestone, not implemented yet. Role
model (groups vs. dependency closure) left open by design — both are built into the resolver so
the comparison is evidence-based.

## Plan Review

**Status**: complete
**When**: 2026-09-16
**By**: independent reviewer (claude-sonnet-5), fresh context
**Verdict**: needs-work
**Plan**: `.agent/work-plans/issue-267/plan.md` at `4af0d501c5ce1a334245478708464a671b8fae59`

### Findings

- [x] (must-fix) `tools/ros-manifest/src/ros_manifest/extends.py:40-52` — `_resolve_one` joins a manifest's `extends.path` to `declaring_dir`/`clone_dir` and `.resolve()`s it with no containment check, so a path like `../../../../etc/passwd` in an extends-chain entry is read as a manifest file (path traversal). Since `extends` is designed to accept arbitrary `url+ref+path`, this is reachable by design, not hypothetical. Add an `is_relative_to()` check after `.resolve()` and raise `ManifestError` on escape.
- [x] (must-fix) `tools/ros-manifest/src/ros_manifest/extends.py:25-37` — `_clone_or_reuse` passes the manifest-declared `url` to `git clone` as a bare positional argument with no check that it doesn't start with `-`, allowing git option/argument injection (e.g. `--upload-pack=<command>`) from a manifest-controlled value. Reject leading-dash `url`/`ref` values or insert a literal `--` separator before positional args.
- [x] (must-fix, before the west milestone starts) `tools/ros-manifest/docs/west-variant.md:92-97` — the conformance-matrix pass criterion judges the west variant by exact match against the **own resolver's** output, not against the real `.repos` fixtures already used as ground truth by `test_acceptance_p11.py`. This makes it structurally impossible for west to be judged "correct" where it disagrees with the own resolver, and drops the compromise list's non-functional criteria (checkout-ownership conflict, stale transitive deps, community fit) from the eventual decision — undermining the "own-vs-west is genuinely open" framing in issue #267. Judge both prototypes against the real fixtures independently and carry the non-functional criteria into the recorded decision.
- [x] (suggestion) `docs/ROADMAP.md` — not updated by this PR (confirmed via `git diff main..feature/issue-267 -- docs/ROADMAP.md`, empty) and not listed in the plan's Files to Change; the step-4 row (line 102) still reads "planned" with no note that milestone 1 landed. Add a one-line status update.
- [ ] (suggestion) Process: the plan-task gate ("draft PR stays draft until the owner reviews the plan") was not honored — milestone-1's full implementation (14 files, ~1,400 lines, new CI job) landed in the same PR as the plan, ahead of this review. Not a code defect (tests pass, scope is otherwise sound), but worth an explicit owner call on whether build-ahead-of-plan-review is accepted practice going forward.

### What checked out clean

- Six owner design decisions (2026-09-16 issue comment) match the plan and the code exactly: extends by url+ref+path with override-refusal; fixed ordered layers with roles only subtracting; distro as a selector with `absent`; both role-model candidates built for comparison; generated `.repos` with provenance + vcs2l deferred correctly; validation table + dependency check.
- `pytest tools/ros-manifest/tests` — 40/40 passing, run from this worktree via `.venv/bin/pytest`.
- Acceptance test is a real second resolution, not a copied fixture: `test_acceptance_p11.py` resolves the same merged manifest through the actual resolver for both `jazzy` and `rolling`, asserts byte-identical output (`strip_provenance_header`) against separately-recorded expected `.repos` files, and separately asserts the diff is exactly the one `unh_marine_autonomy` ref.
- Extraction constraints honored: `grep -rn '\.agent\|workspace' tools/ros-manifest/src` finds only doc/comment references, no imports; own `pyproject.toml` with PyYAML as the only runtime dependency; own CI job (`validate-ros-manifest` in `.github/workflows/validate.yml`); extraction-candidate marker in `__init__.py` and README.
- No project-repo writes: `git -C /home/roland/agent_workspace/projects/p11-jazzy/layers/main/core_ws/src/unh_marine_autonomy status --short` and a workspace-level `projects/` status check are both clean.
- ADR-0009: `.venv/bin/pip install -e tools/ros-manifest[test]` documented for local use; CI job uses `actions/setup-python` (not system Python), so no PEP 668 conflict.
- ADR-0011: adapter integration is designed (not wired) as a CLI-only subprocess call inserted into `adapter_setup`; no new adapter verb.

## Implementation

**Status**: complete
**When**: 2026-09-16 17:31 +00:00
**By**: Claude Code Agent (claude-sonnet-5)

**PR**: #268 at `60af7ed`
**Addressed**: `## Plan Review` above (independent reviewer, 2026-09-16)
**Commits**: `357703f`, `e46a612`, `23bf384`, `60af7ed`

### Actions
- [x] `extends.py:40-52` path-containment check on both the local-path and git-clone branches of `_resolve_one` — `357703f`
- [x] `extends.py:25-37` reject option-like `url`/`ref` in `_clone_or_reuse` and insert `--` before positional args to `git clone` — `e46a612`
- [x] `west-variant.md:92-97` judge own resolver and west variant independently against the real p11 `.repos` fixtures, plus a Decision record section carrying the compromise-list non-functional criteria as explicit rows — `23bf384`
- [x] `docs/ROADMAP.md` step-4 row and cutover-sequence row 3 note that #267 milestone 1 landed on PR #268 — `60af7ed`

### Not actioned

- (owner's call, out of scope for this pass) Process finding on the plan-task gate /
  build-ahead-of-plan-review — its checkbox in `## Plan Review` above is intentionally left
  unchecked pending an explicit owner decision.

---
**Authored-By**: `Claude Code Agent`
**Model**: `claude-sonnet-5`

## Merge (report-only)
**Status**: complete
**When**: 2026-09-22 12:16 -04:00
**By**: merge_pr.sh (Claude Code Agent)

**PR**: #268 at `e1755a5`
**Mode**: report-only
**Scope**: workspace
**Conditions**: no ## Local Review / ## Integrated Review entry in /home/roland/agent_workspace/worktrees/workspace/issue-workspace-267/.agent/work-plans/issue-267/progress.md
