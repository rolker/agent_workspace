---
issue: 519
---

# Issue #519 — repos-manifest: fetch_from fetches every repo from another place

## Issue Review
**Status**: complete
**When**: 2026-11-23 12:24 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #519

### Scope Assessment

**Well-scoped?** Mostly, but it needs parts. The acceptance case (a system set up from https URLs pushes over ssh) is reachable by a first pull request; the rest can follow. Suggested split: (1) `fetch_from` in `config.yaml` and `init --fetch-from/--fetch-fallback`, the effective-URL rule (prefix + name + `.git`), `fallback: false` and `origin` set to the place, used by `init`/`sync` clone and by `sync` and `status` on existing clones; this alone serves the real case. (2) `fallback: true`: existence and version probe, `upstream` remote, "same repo by another transport" test, same-name refusal in `resolve`. (3) The manifest-holding repo and a parent manifest in git, which wait on #498 part 2b (open) and #510 (open); the issue already says to state this in the plan.
**Right repo?** Yes — `tools/repos-manifest` is in the workspace repo.
**Serves**: "A safeguard has to earn its cost" is not the point here; the goal is the manifest tool's own roadmap row "A machine can fetch every repo from another place" and the workspace goal of fetching a project's repos from a manifest — `tools/repos-manifest/docs/design.md#where-repos-are-fetched-from`, `docs/manifest/design.md` ("What the tool has to give").
**Design picture?** No change to the design; it is already written. The issue's `upstream`/same-transport questions and the interaction with `sync`'s url rule add detail to that section, which gets updated in the same change.
**Dependencies**: #498 part 2b (manifest readable from git) for the manifest-repo and parent-manifest parts only; #510 (fetch time limits) for the probe's timeouts; #500 and #502 are done as far as this needs (pull requests 535 and 546). Motivated by #521 (`merge_pr.sh` with an origin it cannot push to); #519 removes the cause on that machine, not #521's script behaviour.

**What an existing system directory needs (the real case).** Verified in `update.py` and `status.py`:
- `Config` (`system.py`) has no `fetch_from`, and `config_text` writes only known keys, so an existing `config.yaml` needs the key added by hand (or a new command); `init` is not rerun on an existing directory.
- `sync` compares `origin` with the manifest's url (`same_url`, which only ignores a trailing `/` and `.git`, so https and ssh differ). For an https clone with `fetch_from` set, origin equals both the manifest url and the recorded `RepoRecord.url`. If the code passes the manifest url, sync sees nothing to do. If it passes the effective (ssh) url, the existing branch "origin equals the recorded url, the wanted url differs" applies, and `_repoint` fetches from the new url first, refuses when a local branch or work-tree HEAD has commits not on it, and then runs `remote set-url origin`. So the existing rule already does what the issue wants, provided `update` is given the effective url as `repo.url` and `RepoRecord.url` is understood as "the url fetched from". Without that, sync takes the other branch and reports "origin is X, the manifest says Y; left as set".
- The recorded url must therefore stay the manifest's url or become the effective one, and one of the two has to be chosen: keep the manifest's url in the record (so `upstream` can be derived and a `fetch_from` edit is a change of the place, not of the manifest) and record the place as well. A hand-set ssh `origin` (today's workaround) matches the effective url and needs nothing.
- The probe fetch needs the ssh key; with a locked key `_repoint` fails and leaves origin, which is the safe outcome and should be tested.
- `status` today (`_repoints`, `_remote_note`) prints "fetched from X, set by hand; the manifest says Y, and sync leaves origin as it is" for an origin that differs from the manifest. With `fetch_from` that note is wrong for every repo, so `status` has to compare against the effective url and say where the url came from.
- The `config.yaml` is in the same file as role/groups, shared by all distros; the edit applies to every distro's clones, including repos already marked "moving".

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Keep one current design | OK | The design section exists; `design.md`, `roadmap.md`, `README.md` of the tool are in the acceptance list. The design's url rule paragraph (pushurl / pushInsteadOf) is the alternative for a one-machine case and should be named in the plan as considered. |
| Only what's needed | Watch | The first real use is ssh vs https on one machine; `fallback: true` and `upstream` are not needed for it. Part 2 may be a follow-up. |
| Fail loudly, no silent failures | Action needed | Fallback probe: a refused host, a locked or missing key, and a missing repo must be told apart; only "repo or version missing" falls back, the rest stop with an error naming the host. The issue asks this as a plan question; the plan has to answer it with tests. |
| Tests with the change | OK | Acceptance lists local file remotes; add a test that an existing https clone with local commits is not repointed to an url that lacks them. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0022 (parts with their own design) | Yes | Work is inside the tool's part; the root design changes only where the manifest adapter's contract is touched (`docs/manifest/design.md`), which it is not. |
| ADR-0017 (design doc updated with the change) | Yes | Tool `design.md`, `roadmap.md`, `README.md`. |
| ADR-0013 (progress timeline) | Yes | This entry. |

### Consequences

- `tools/repos-manifest/docs/design.md`, `roadmap.md`, `README.md`, `docs/spec.md` (if `config.yaml` keys are listed there).
- `status` and `sync` messages and tests in `tests/` that assert "set by hand" for a differing origin.
- Workspace `docs/manifest/roadmap.md` if a row mentions fetch settings at registration ("Registration passes the manifest's location, role, distro and fetch settings to `init`").
- The ros2_colcon adapter's registration (#503) passes `--fetch-from` once it exists.

### Recommendations

- Split into two pull requests: the effective url and `fallback: false` first (reaches the acceptance case), then `fallback: true` with `upstream` and the same-name refusal; leave the manifest-repo and parent-manifest parts for after #498 part 2b.
- Plan the existing-directory path explicitly: pass the effective url into `update` as the wanted url, keep the manifest's url and the place in `state.yaml`, and cover the https-clone-with-local-commits and locked-key cases in tests.
- Decide how an existing directory gets `fetch_from` (hand edit of `config.yaml` read on the next `sync`, or a flag on `sync`/a small command) and say so in the plan; `init` is not rerun.
- Change `status`'s "set by hand" note so a differing origin that matches `fetch_from` is shown as fetched from the place the config names.
- For "same repo by another transport", compare host and path after normalizing `git@host:path` and `https://host/path`, drop `upstream` when they match, and put the rule in `design.md`.

### Questions only the owner can answer

- Should `fetch_from` be settable only per system directory (as designed), or does the first use already call for the roadmap's "per-user settings file" (set once for all systems)? It changes the tool's design and the scope; the issue and design say per system.
- Is the first pull request allowed to stop at ssh-for-https (fallback off, no `upstream`) with the fork case following, or does the owner want the fork use at once?

Mechanism choices (not for the owner; I would decide them in the plan): where the place is recorded in `state.yaml`, the same-transport normalization, how an existing `config.yaml` gets the key, which probe errors fall back.

### Actions
- [ ] Fail loudly: the fallback probe tells a refused host, a locked or missing key and a missing repo apart; only a missing repo or version falls back; tests cover it.
- [ ] Split into two pull requests: the effective url and `fallback: false` first, then `fallback: true` with `upstream` and the same-name refusal; manifest-repo and parent-manifest parts wait for #498 part 2b.
- [ ] Plan the existing-directory path explicitly: pass the effective url into `update` as the wanted url, keep the manifest url and the place in `state.yaml`, test an https clone with local commits and a locked key.
- [ ] Decide how an existing directory gets `fetch_from` (hand edit of `config.yaml`, a flag on `sync`, or a small command) and say so in the plan.
- [ ] Change the `status` "set by hand" note so a differing origin that matches `fetch_from` is shown as fetched from the configured place.
- [ ] For "same repo by another transport", compare host and path after normalizing `git@host:path` and `https://host/path`, drop `upstream` when they match, and document the rule in `design.md`.
