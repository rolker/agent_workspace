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

## Checkpoint
**Status**: complete
**When**: 2026-11-23 12:24 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the Issue Review finds the issue sound; its actions are for the plan and none changes what the work is for)
**After**: issue-actions
**Decision**: proceed

Read: the Issue Review at 2a2498ff (sound, ready to plan, two pull requests). The owner started this drive on 2026-11-23: "yes, drive 519 as the second issue", for the case of a system cloned over https that has to push over ssh. The review's six actions go to the plan. Its two questions marked owner-level are answered by what is already recorded, so neither is asked: (1) per system directory or per user: the tool's design, "Where repos are fetched from", puts fetch_from in the system directory's config.yaml, and the tool's roadmap lists "A per-user settings file, so where to fetch from is set once for all systems" as a deferral; the plan follows the design. (2) whether the first pull request may stop at the same repos over ssh: that is the order of parts, a mechanism choice, listed below.

### Decisions made (owner may veto)
- Two pull requests: the first builds fetch_from with fallback off (the same repos from another place, origin set to it, sync and status acting on clones that already exist), which is the case the drive was started for; the second adds fallback on (a developer's forks where they exist, the upstream remote, the same-repo-by-another-transport rule) — undoing it: plan both as one pull request; nothing is built yet.
- fetch_from is set per system directory, as the tool's design says; the per-user settings file stays a deferral on the tool's roadmap — undoing it: a design change to the tool, asked on its own.

## Plan Authored
**Status**: complete
**When**: 2026-11-23 12:29 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-519/plan.md` at `9101667d`

Two pull requests. Part 1 builds fetch_from with fallback off: the effective url becomes Selected.url, so the existing url rule and _repoint move origin of clones that exist, and status and sync agree through one resolve step; an existing system gets the key by hand-editing config.yaml. Part 2 (outlined) adds fallback, the probe, upstream and the same-repo rule.

## Plan Review
**Status**: complete
**When**: 2026-11-23 12:34 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #519 — repos-manifest: fetch_from fetches every repo from another place, such as the same repos over ssh
**Plan**: `.agent/work-plans/issue-519/plan.md` at `9101667d`
**Branch**: `feature/issue-519`

### What was run

- A system made with the installed tool (`.venv/bin/repos-manifest`, from main) from seven local bare repos in `placeA` (`file://` urls), then the manifest's urls changed to second copies in `placeB` (the stand-in for `E`), then `status`, `sync`, `status`, `sync`. Outcomes, each as the plan's table says: clean clone repointed ("origin repointed from A to B"), record B at once; uncommitted changes repointed, then "left alone: has uncommitted changes"; local commit not on B "left alone: url changed to B but 1 local commit (branch main) is not on it; origin stays A", record stays A, and after pushing the commit to B the next `sync` repointed it; origin set by hand to B: no line, `status` expected with no note, record became B; origin set by hand to a third place: "left as set", but the record became B (the wanted url) while origin stays X; B missing: `failed`, exit 1, "fetching from it failed (origin stays A)", "run sync again" advised; record with no url: "set by hand", left as set, and the record was then given B while origin stays A (so without the plan's step 7b it stays "set by hand" for good). An optional repo is `skipped` (`sync.py:259,465`). The plan's description of today's url rule is right in every row.
- `_Checker("config.yaml").url(prefix + name)` on prefixes: `git@github.com:rolker/`, `git@github.com:`, `ssh://git@github.com/rolker/`, `ssh://git@host:2222/owner/`, `https://…/`, `file:///srv/mirror/`, `/srv/mirror/` pass; `relative/`, `-x/`, `ext::…`, `git://`, `ftp://`, `%2d` host, `-host`, `:-o/` are refused; credentials in an https prefix are masked (`https://***@…`). It also passes `https://host:` + name (`https://host:name.git`, a "port") and a prefix with a newline (`git@host:o/\n…`), which the plan's own control-character check in `read_config` has to catch.
- `git -c url.<B>.pushInsteadOf=<A> push origin main` in a clone whose origin is A: `remote -v` shows fetch A, push B, and the push landed in B; no per-clone setting is needed (the setting can be `--global`).
- Counted the owners of the repo urls in the tool's own fixtures `tests/fixtures/p11/manifest.yaml` and `project11/project11.manifest.yaml` (not the real project11 checkout, which this review did not read): 42 `https://github.com/rolker/…`, 1 `https://github.com/ros-geographic-info/geographic_info.git`, and 1 `git@github.com:CCOMJHC/…` (or `example/…`).

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One pull request of about 15 files (about 250 lines of source, 500 of tests, 150 of docs): large but one mechanism, reviewable. Part 2 is honestly outlined with its waits. |
| Issue alignment | Concern | Serves: "Workspace goal "Flexibility" (a published manifest fetched from other places without editing it); `tools/repos-manifest/docs/design.md#where-repos-are-fetched-from` and the tool's goal …(`tools/repos-manifest/README.md#goals`)". Anchors checked, they exist. But part 1 (fallback off, one prefix) does not reach the drive's own acceptance case when the manifest names repos of more than one owner (finding 1). |
| File targeting | Good | Every consumer of `Selected.url` is named or is unaffected (list below). `Selected` is built in two places only (`selection.py:157`, `tests/test_update.py:511`). |
| Consequences | Needs work | Design text that names the recorded url as the manifest's is wider than the plan lists (finding 4); `show`'s "from <manifest>" sentence (finding 6); the agreement test needs a `CLAIMS_DIFFER` entry, not only `DIFFER` (finding 2). |
| Principle alignment | Needs work | "Look for prior art": the reason given for rejecting `pushInsteadOf` is wrong (finding 1). "No silent failures" and "Test what breaks" are otherwise well covered. |
| ADR compliance | Good | ADR-0022 (the tool's own design, the root design unchanged), ADR-0017 (design in the same pull request), ADR-0013 (timeline). |
| ROS conventions | N/A | Workspace tool. |

Every consumer of a repo's url in `src/repos_manifest/` under the plan's rewrite: `output.output_files` (resolved `.repos` in a system: `E`, right, `vcs import` clones from it; the `resolve` command has no config and is unchanged); `sync.py:509`, `update.py:908,915` (`state.yaml`: `E`, right, see decision 1); `update.py:1037` and `status.py:181` (`remember_url`: `E` is registered, the published url no longer is at that point, but it was registered when the manifest was read and each message that names it goes through `mask_url`; register `published` too to keep the rule "every url read is registered" literal); `update.py` by-hand and repoint messages and `set_url_command` (`E`, with the wording the plan gives); `status.py:194` JSON `url` (the plan picks `published or url`, consistent because it is an explicit choice, but the design's `status` text should then say `url` is the manifest's and that the wanted url is only in the text); `show.py:101` (`E`, as the design says); `emit.py`, `schema.py`, `validate.py`, `extends.py` (earlier format, parent manifests: not `Selected`, unchanged). Nothing that should keep the published url changes silently, apart from the `show` sentence in finding 6.

### Findings

1. **[Issue alignment / prior art] High** — Part 1 does not serve the first real use the drive was started for when a manifest names repos of more than one owner. With `prefix: git@github.com:rolker/` and fallback off, `geographic_info` (owner `ros-geographic-info`) and `ccomjhc_project11` (owner `CCOMJHC`) in the tool's p11 fixtures would be fetched from `rolker/<name>`: a repo that is not there fails on every `sync`, exit 1, and a fork that is there is a different repo, silently. One prefix can say "the same repos over ssh" only when every repo has one owner; the issue's own example uses `fallback: true` for that reason. The plan's rejection of `url.<base>.pushInsteadOf` ("needs a per-clone git setting on every clone") is wrong: run above, one setting, which can be global, sends every push over ssh and keeps fetching from the manifest's urls, which is what the tool's design already says to do ("To push over ssh while fetching from the url the manifest names, set `remote.origin.pushurl`, or `url.<base>.pushInsteadOf`."). Resolution: check the real manifest's owners; correct the prior-art paragraph; and take the question below to the owner before part 1 is built.
2. **[Tests] Medium** — The planned agreement case "fetch_from set, commits only here" fails `test_status_agrees_with_sync.py` as planned: `status` says "sync tries to repoint origin to it" (seen above for the `ahead` clone), whose `CLAIMS` row requires "origin repointed from" in `sync`'s output, and `sync` refuses instead. `status` cannot know offline whether `E` has the commits, so the case belongs in `CLAIMS_DIFFER` (with its reason), or a new claim pattern for the refusal, not only in `DIFFER`.
3. **[Validation] Low** — The "ends in `/` or `:`" rule lets `https://host:` through, and `check_url(prefix + "x")` accepts the result (`https://host:x`, a port). Allow a trailing `:` only for the scp-like form, and add that to the prefix-refusal tests. The newline case passes `_Checker.url` (run above), so the control-character check in `read_config` is the one that refuses it; keep that test.
4. **[Design text] Medium** — Decision 1 is right (below), but the design names the recorded url as the manifest's in more places than the plan's list ("the url rule's `R`"): the `state.yaml` example comment (`url: … # the manifest's url, when recorded`), the url rule's "`U` is recorded" (three sentences after the rule) and "the url `sync` recorded" in "Where repos are fetched from". Each changes to the url `sync` wants (`E` with `fetch_from`), and the state of a hand-set origin should say that the record holds the wanted url, not origin (seen above for the third-place clone).
5. **[Design text] Low** — "Where repos are fetched from" says that when `fetch_from` is edited "`sync` changes the clone's remotes to match … the working files and local branches stay as they are", unconditionally; the plan, rightly, applies the url rule's refusal for commits not on `E`. The plan's design list says "existing-directory path, change and removal"; it should say in words that the url rule's refusal applies, so the design does not promise a repoint the tool refuses.
6. **[Design text / show] Low** — `show`'s design says the manifest named for an entry "is the one that gave the URL printed". With `E` printed that is no longer true; the planned `fetch from <prefix>` head line helps, and the sentence should be reworded (and the resolved files' head comment could carry the same line, since they now hold urls `repos-manifest resolve` does not give for the same manifest).
7. **[Credentials] Low** — A prefix with a user and password (`https://user:token@…/`) is masked in every message and the JSON (`url` is the published one, `fetched_from` is masked), but `E` holding it is written to `state.yaml`, the resolved `.repos` files and origin, as a manifest url with a password is today. Say so in the design's `fetch_from` text (the credential belongs in a helper or key), and register the prefix before any message, as planned.
8. **[Tests] Low** — The plan leaves "use `-n` only if xdist is configured; I did not check": `pyproject.toml` has no xdist `addopts`; the implementer runs the named files plainly or with an explicit job count.

### Judgement on the plan's decisions

- **Decision 1 (record `E` in `state.yaml`)**: right. The url rule decides by `W == R`; with `R` kept as the manifest's url, a later prefix change (`W = E_A`, `R = U`) and the removal of `fetch_from` (`W = E`, `R = U`, wanted `U`) would both read as "set by hand" and never move. `freeze` needs the published url, and it reads the manifest anyway, so it can rebuild it; nothing needs `U` in the record. The cost is the design edits in finding 4.
- **Decision 3 (refuse `fallback: true`)**: honest and right: a config that says fallback and a tool that silently does not would be a silent failure. The design's example config (and the issue's) keeps `fallback: true` as the design's intent; the `config.yaml` table row has to say "not read in this part: `fallback: true`", as other rows do, in part 1. That is in the plan's list. Defaulting a missing `fallback` to false is the safe default, and the design text should state the default.
- **Decision 4 (same-name refusal in `apply`)**: right, since `resolve` does not read `config.yaml` and cannot know a prefix; the design's "`resolve` says so" has to change in part 1 to the commands that read the system's config (`init`, `sync`, `status`, `show` in a system). The plan's design list has "the same-name refusal where it lives"; part 2's open choice about `resolve --fetch-from` can stay open.

### Question only the owner can answer

How an existing directory gets the key is not one: the design says the place changes "because a fork appeared or `fetch_from` was edited" and puts the key in `config.yaml`; a hand edit is that. The one that is the owner's is finding 1, because it changes what part 1 is for: the drive was started for "a system cloned over https that has to push over ssh", and the design already answers that case with git's own setting ("To push over ssh while fetching from the url the manifest names, set `remote.origin.pushurl`, or `url.<base>.pushInsteadOf`."), while `fetch_from` with fallback off is, in the design's words, for a machine where "every repo is cloned from the other place, and a repo that is missing there is an error". Should part 1 still be fallback off (serving the field machine and single-owner manifests, with the ssh case met by `pushInsteadOf` today), or should the first pull request include fallback so the issue's own example works?

### Summary

The mechanism is sound and checked by running: today's url rule does exactly what the plan's table says when handed the effective url, and rewriting `Selected.url` reaches every consumer that should see it. The plan is not ready because part 1 does not meet the case the drive was started for on a manifest with repos of several owners, and the prior-art reason for setting `pushInsteadOf` aside is wrong; that goes to the owner. The agreement-test case and the design text need small corrections.

### Recommended Actions

- [ ] Take the question above (finding 1) to the owner, with the owners counted in the real manifest; correct the prior-art paragraph on `pushInsteadOf`.
- [ ] Put "fetch_from set, commits only here" in `CLAIMS_DIFFER` (or add a claim for the refusal) as well as `DIFFER`.
- [ ] Allow a trailing `:` in the prefix only for the scp-like form; test `https://host:`.
- [ ] Add to the design edits: the `state.yaml` comment, "`U` is recorded" in the url rule, "the url `sync` recorded", the conditional repoint in "Where repos are fetched from", `show`'s "gave the URL printed" sentence, `status` JSON `url` as the manifest's, `fallback`'s default, the same-name refusal's commands.
- [ ] Register `published` with `remember_url` beside `E` in `update.py` and `status.py`.

## Checkpoint
**Status**: complete
**When**: 2026-11-23 13:01 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: plan
**Decision**: revise

The Plan Review at cb1e933a said needs-work; its first finding (part 1 with fallback off does not fit a manifest whose repos have several owners, and the case the drive was started for, pushing over ssh from https clones, is already answered by git's pushInsteadOf, as the tool's design says) was put to the owner as a question about what the work is for. His answers, in the session, 2026-11-23:

"The goal is that a public user can pull project11 via https, but if I want to work on it, I need to use ssh. I would rather not maintain two versions of the manifest to support this as they could easily drift."

"The other scenario is field machine interacting with gitcloud, our internal git server for that purpose. The machine do have ssh keys setup so a switch to ssh, and different server and user (for example git@gitcloud/field/repo.git) works."

To "Shall I continue #519 on that basis?" (part 1, fallback off, aimed at the field machine's server; the fork part with fallback on later; the development machine's ssh pushes handled by a git setting, not by the tool): "yes, continue 519, and use the combination setting".

What this settles for the plan: part 1 stays fallback off and its first real use is a field machine that fetches every repo, whatever its published owner, from one prefix on a private server (for example git@gitcloud:field/<repo>.git), with no second copy of the manifest. Finding 1's objection does not apply to that case. The development machine's case is met outside the tool by git's own url rules, set on this machine the same day (pushInsteadOf for the public host, insteadOf for the one owner with a private repo); the tool's documents say so where they describe pushing over ssh. The plan is revised for the review's findings 2 to 8 and for this aim; part 2 (fallback on, a developer's forks) stays outlined.
