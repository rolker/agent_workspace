# Plan: repos-manifest: the resolver reads the format in the spec

## Issue

https://github.com/rolker/agent_workspace/issues/498 (the issue text says `tools/ros-manifest/`; the directory is `tools/repos-manifest/` since #497).

## Context

Revised 2026-11-24 (third revision). Delivered: part 1 (#506: one manifest in the format of the spec) and part 2a (#511: `base` read from local paths; the merge rules, reading order, cycles, the cap of 64). Issue 569 changed what is left: its parts 1 and 2 (#571, #597) removed the prototype's roadmap note and cut the `ros2_colcon` adapter's manifest route; its part 3 (#603, open, expected to merge 2026-11-24) removes the earlier format's reader (`schema`, `merge`, `selectors`, `validate`, `emit`, `extends`, `--layout`, `--cache-dir`, `docs/prototype.md`). This plan is written against the tool as it is on `origin/feature/issue-569`. **Implementation starts after #603 has merged**; the first step of each part is to branch from `main` and re-read the files named below, since part 1 of this plan ran on the tool before `init` and `sync` existed and the tool has changed since.

The old part 3 (adapter reads the new format, the old reader goes) is done by #569 or no longer applies; the issue's section "The existing user" has no user left (owner, 2026-11-24: pickerel has nothing on the old format). The adapter calling the tool's commands is #503's.

### The issue's "What to build" list, checked against the code on the #569 branch

Built, with tests (test counts are of `def test` in the files named): the superset shape, versions and distros, layers, groups and roles (`manifest.py`, `selection.py`; `test_manifest_reading.py` 83, `test_selection.py` 32 including `absent`, an empty distro entry and "a plain .repos file resolves to itself in one layer"); the merge rules and reading order of `base` for paths on the local disk (`base.py`, `combine.py`; `test_base_merge.py`, `test_base_reading.py`, `test_base_output.py`); the safety checks on the text of a manifest and on every `url`, `version` and `path` of a repo or a location (`manifest.py`, `yamlload.py`; `test_manifest_reading.py`, `test_url_messages.py`); the output (`output.py`; `test_output.py` 53) and `validate` (`cli.py`); the project11 fixture (`tests/fixtures/project11`, `test_project11.py`); everything under "Remove" (grep of `src/` on the branch finds no `packages:`, roots, parent cache, `optional_layers` outside the earlier-format refusal, group defaults or `add`/`subtract`); `docs/prototype.md` removed.

Not built: a location that is an `http`/`https` URL or a file in a git repo, for the manifest itself and for `base` (`manifest.py` refuses both with "reads a location in `base` given as a path only"; `system.py` refuses a URL in `read_manifest` and in `read_config`: `ONLY_A_PATH`). Also not built, and outside this issue but named by the design: `local_manifest` and sync's step 1, a distro's `manifest_version`, a manifest named by a commit (#510), `fetch_from` acting on the manifest's own repo and on a parent manifest (design "Where repos are fetched from"). The issue's "Not in scope" already puts `init`, `sync`, `status` and fetching from another place elsewhere, and those are built; this issue's remaining job is the location forms for every command that reads a manifest.

Closing the gap #597 stated: `init` reads a local file only, so a project whose manifest is in a git repo keeps a clone by hand that the tool never fetches, and it can fall behind silently. Reading the git form afresh at every `sync` closes it. What it does not give is `local_manifest`: a developer editing the manifest in its clone is not read by `sync` until that is built (listed under Open questions).

### The code the parts change (after #603)

`manifest.py` (`Part`, `_Checker.base_locations`, `check_url`), `base.py` (`_Reader`, identity by real path), `combine.py`, `system.py` (`read_manifest`, `read_config`, `config_text`, `is_url`, `ONLY_A_PATH`, `Config.manifest` a `str`), `init.py`, `sync.py` (`resolve_all` reads `config.manifest` once per run; `require_git`, `Env`), `status.py` (`"manifest": mask_url(config.manifest)`), `cli.py` (`_load`, `cmd_show`, `_show_in_system`), `update.py` (the `Git` class and its options).

## Approach

Conventions for every part and every handoff: a parallel build or test command names its job count (`pytest -n 4`, `make -j 4`); the tool's own documents (`tools/repos-manifest/`) do not mention the workspace; document text is plain sentences with no bold slogan lead-ins; tests run on Python 3.10 and 3.14 (CI runs both); nothing needs Python newer than 3.10; no test reaches the network (local git repositories, local files, a server on 127.0.0.1); no test patches an `os` function; a rule is stated once, structurally, in one function; each document sentence is written from the code and tested. A new `test_*.sh` gets `chmod +x`.

Shape shared by all parts. A location becomes a value, not a string: new `location.py` holds `PathLocation`, `UrlLocation` (part 3), `GitLocation(url, version, path)` with `parse(value, where, source)` (a string or a mapping, the spec's rule: a string with `:` before its first `/` is a URL, not a path; the lexists exception in `system.is_url` goes, since the spec says a file with a `:` is written `./a:b`), `join(parent, relative)` (a relative location is taken from where the naming manifest is: beside it on disk; in the same repo at the same version for git; relative to the URL for a URL), `identity()` and `label()` (masked, for messages). The `url`, `version` and `path` of a git location pass the one function that checks a repo's `url` and `version` (`_Checker.url`, `not_an_option`, `url_path`), made callable outside `_Checker` so that `--manifest-ref`, `--manifest-path`, `config.yaml` and `base` all use it ("apply to a repo and to a location alike").

New `fetch.py` reads the text of a location: a path (what `_read_text` does), a git file, an http(s) file (part 3). Git form: a bare shallow clone into a temporary directory, `git clone --bare --depth 1 [--branch V] --no-tags -- URL DIR` (no work tree, nothing checked out, so no hook or filter runs; `--` before the url; `GIT_ALLOW_PROTOCOL=https:http:ssh:file`; the environment of `sync.require_git()`), then `git ls-tree -l -z HEAD -- PATH` to find the file (missing, a directory, a link or a submodule are refused; a blob over 1 MiB is refused) and `git cat-file blob` to read it. Whatever lets a person clone by hand works: ssh keys, agent, `~/.ssh/config`, a credential helper. With a terminal (`/dev/tty` opens) git stays in the tool's process group and may ask for a password; with none (CI) git starts in its own session, so it cannot ask and fails at once, and the 60 second limit applies to the whole call, ending git by its pid. One function runs git for this, so #510 can reuse it for the repos' clones. One clone per (url, version) per run serves every file read from it. The temporary directory is removed in a `finally`, and on a stop signal.

Time limits: the design gives none for reading a manifest; #510 designs settable limits for fetches. This plan uses the answers of the 2026-11-18 Checkpoint (60 s with no terminal, 1 MiB, redirects) as constants in `fetch.py`, written in the design, and left to #510 to make settable (Open question 4).

### Part 2b-1: a manifest in a git repo, for `init` and `sync` ("Part of #498")

The smallest part that lets `init` and `sync` use a manifest in a git repo. Everything that reads the recorded location goes through `read_manifest` and `read_config`, so `status` and `show` (no argument) come with it; leaving them would make them fail on a system `init` just set up.

1. `location.py` (`PathLocation`, `GitLocation`, `parse`, `identity`, `label`) and `fetch.py` (the git reader above); `base.py`'s `_Reader` takes a location and its text instead of a real path (identity of a path stays its real path, a git location's is url, version, path). A git-located manifest that names a parent is refused in this part with the message style `base.py` already has ("this version reads a `base` of a manifest read from git ... "); part 2b-2 lifts it.
2. `config.yaml`: `manifest:` is a string (path) or a mapping `url`, optional `version`, `path`, as "config.yaml" in the design shows; `Config.manifest` becomes a location; `read_config` checks the mapping with the one function and names the key; `config_text` writes the mapping; the "Not read in this part: the git form" text goes. `status`: the `manifest` line and `--json` field print the git form masked (Open question 6).
3. `init`: `--manifest-ref` (once) and `--manifest-path` (once). Rule as the design states it: with `--manifest-path` the positional is the repo's url (any allowed form, an absolute local path included) and the location is the git form; without it, the positional is a path (or an http(s) URL, refused until part 2b-3). The design's refusal row ("`--manifest-ref` or `--manifest-path` is given and the manifest is not given in the git form") is built, in its order, with its next step; `--manifest-ref` and no `--manifest-path` is that row. The refusal rows whose next step names `--manifest-ref` now say it (`init` rows; not `add-distro`, which is not built). `init` needs `git` before it reads (`require_git()` first), not after as now.
4. `sync`, `status`, `show` (in a system): `read_manifest(config.manifest, system)` reads a git location afresh, once per run; sync's errors keep "the manifest is what failed; nothing was changed" and name the location; a failed fetch is a `ManifestError` that names the location (masked) and the exit status, with git's own text printed per Open question 3. `status` reads it the same way (Open question 1: this is where "makes no network call of its own" has to change).
5. Tests (local repos, a stub ssh for the private case), one per rule: reads a file from a branch, from a tag, from the default branch (no `--manifest-ref`); a path in a subdirectory; the file missing, a directory, a symlink, a submodule, over 1 MiB; a `--manifest-ref` that is a commit refused with a message saying a branch or tag is meant (#510); `sync` after the remote's manifest changed gets the new one (the gap), and after the remote is unreachable fails with nothing changed; init then sync reads twice; private over ssh: `GIT_SSH_COMMAND` names a stub that runs `git-upload-pack` on a local repo, and the test shows ssh was used with the person's configuration; no terminal: a local http server answering 401 makes the read fail at once, not wait (and a hanging server ends at the limit, with the limit set small through the constant, not a patched `os` function); a stop signal during the clone leaves no temporary directory; the safety rules for the git form, each its own test, for `--manifest-ref`, `--manifest-path`, `config.yaml` and the url: a `url`, `version` or `path` that starts with `-`; a user, host or port that starts with `-`; `%` in an ssh address; a transport that runs a command (`ext::`, any `name::address`); a relative path as url; `..` in `path`; an empty https host; invisible or direction-changing characters in any of them and in the fetched file (the existing character check runs on the fetched text); the fetched file in the earlier format, with a `base`, with a key `..` (the checks of every manifest apply). `GIT_ALLOW_PROTOCOL` is tested by a `file://` redirect from an http server that git must refuse.
6. Documents, same part. Tool: `docs/design.md` ("Where the manifest comes from" says what is built; "What is built" for `init`, `sync`, `status`, `show`; the config table row and the Refusals note; `status`'s "no network call" sentence per Open question 1), `docs/spec.md` Locations ("The tools here read a path only for now" becomes what the tools read), `README.md`, `docs/roadmap.md`. Workspace, which changes when the gap closes: `docs/manifest/design.md` in "A root that sets `source`" (the paragraph "`init` reads a manifest from a file on the local disk only ... kept by hand" becomes: `init` is given the URL, `--manifest-ref` and `--manifest-path`, the tool records them and reads the file afresh at every `sync`; no clone by hand; a commit is not a `source_ref` until #510), in "What the tool has to give" (the bullet "A manifest read from a git repo" moves to the guarantees the tool gives, and the sentence after the list that says a URL `source` is read from a clone nothing fetches goes), in the settings-key table row for `source` ("`init` takes neither option today ... kept by hand"), and the root `docs/design.md` sentence ("That clone is kept and the tool never fetches it, so it is updated by hand until the tool reads a manifest from a git repo"). `.agent/project_types/ros2_colcon/adapter.sh`: the refusal's clone line in `_rc_refuse_removed_source` (and the comment above it) becomes `init <source> --manifest-ref <source_ref> --manifest-path <source_path>` with the default `manifest.yaml`, keeping the commit warning; `test_ros2_colcon.sh` lines near 2781 and 2816 assert the old text and change with it. `docs/manifest/roadmap.md`: add a line "The tool reads a manifest from a git repo, so a root needs no clone kept by hand" with check `file-exists tools/repos-manifest/src/repos_manifest/fetch.py`.
7. Roadmap lines made true: `tools/repos-manifest/docs/roadmap.md` "A manifest can be read from a private git server" (the adapter's ssh case is tested with the stub; a real private server is the owner's check on pickerel). `docs/manifest/roadmap.md`: the added line.

### Part 2b-2: the other commands and `base` in git form ("Part of #498")

1. `resolve`, `validate` and `show <manifest>` take `--manifest-ref` and `--manifest-path` through one shared helper with `init` (same rule, same refusals); they need `git` only when the git form is given.
2. `base` as a mapping (`url`, `version`, `path`), alone or in a list; `Part.base` holds locations; the message "reads a location in `base` given as a path only" goes for the git form (it stays for a URL until part 2b-3).
3. A relative `base` of a git-located manifest is taken from the same repo and version, from the directory of the naming file: joined and normalised; refused when the result leaves the repo (Open question 5). A relative `base` of a path-located manifest is as part 2a. An absolute path or a git url named by a manifest read from git is read as given (Open question 2).
4. Identity for "read once" and "builds on itself": a path by its real path; a git file by url, version (the default branch spelled out is a second identity: one sentence in the spec, no code), path. The cap of 64 and the diamond order hold across forms. The head comment and `validate`'s `base:` lines name a git parent as `url version path` and the commit read (the 2026-11-18 Checkpoint, answer 8): one commit per clone, `git rev-parse HEAD`.
5. Tests: each part-2a merge test once more with a git base (key-by-key merge, `groups:`/`layers:` add, a role replaces, `distros:` replaces, diamond `C, A, B, leaf` with each file opened once, a manifest that builds on itself through a git parent, a chain over the cap); `base` as a list mixing a path and a git mapping; the relative cases (sibling, subdirectory, `..` that stays inside the repo, one that leaves); two bases in one repo make one clone; the safety rules once more for a mapping under `base` (the rule is one function, so a test per rule on `base` shows it is the same function); an old-format parent is refused by the one per-file check; error messages name which manifest a problem is in.
6. Documents: spec.md Locations and "How manifests combine" sentences on relative locations, identity and the head comment; design.md "What is built", "resolve", "show"; `docs/manifest/design.md` only where it describes `base` (grep first). Roadmap: no line yet; the tool roadmap's "`base` and the manifest itself can be given as a path, a URL, or a file in a git repo" stays false until 2b-3.

### Part 2b-3: an http or https URL, for the manifest and for `base` ("Closes #498")

1. `UrlLocation`; `fetch.py` reads with `urllib` over `http` and `https`: `urlopen(timeout=60)` and `read1` in a loop that checks a deadline between reads (worst case the deadline plus one socket timeout; say so in the design), at most 1 MiB, a redirect only to `http` or `https` and never from `https` to `http` (an `HTTPRedirectHandler` that refuses the others, with the message naming both). The 60 second limit applies with or without a terminal (nothing asks a person there). A server that sends a `Content-Length` over the limit is refused before reading.
2. A relative `base` of a URL-located manifest is joined by the standard URL join, with one rule: the result has the same scheme and host (a reference that names another host, `//host/x`, is refused as a path; a full URL is a URL). `init` and the other commands take an http(s) URL as the file itself when `--manifest-path` is not given; `config.yaml` records it as a string; `read_config`'s "is a URL" refusal and `read_manifest`'s are removed.
3. Tests with a local server on 127.0.0.1 (no network): body, 404, 500, a redirect inside http, a redirect to `file://` and to `ftp://`, `https` to `http` (a second local server cannot do TLS, so the redirect handler is tested by calling it with a constructed request), the size limit by body and by header, a server that drips bytes past the deadline, a connection that never answers, characters in the body (the same text check), a relative `base` (same host; `//other/x` refused), a manifest URL with credentials is used and masked in every message and in `status --json`, `sync` after the served file changed. The part-2b-2 base tests run once with a URL parent.
4. Documents: spec.md Locations ("The tools here read a path only for now" goes entirely; plain `http` sentence stays), design.md ("Where the manifest comes from", "What is built" lose every "path only" sentence; the limits and the redirect rule are written once), `README.md`, both roadmaps. Roadmap lines made true: `tools/repos-manifest/docs/roadmap.md` "`base` and the manifest itself can be given as a path, a URL, or a file in a git repo" (check: `file-contains src/repos_manifest/fetch.py urlopen`); the line "The resolver reads the format in the spec: ..." is true after 2a for what it names and is re-checked here; the two lines about the removed prototype reader and the dropped sections (`The prototype's reader and docs/prototype.md are removed`, `The resolver no longer has the package dependency section ...`) are made true by #603, not by this issue.
5. Before the pull request says "Closes #498": the issue's acceptance list is walked item by item with the command that shows each (project11 fixture resolves for each role and distro; a plain `.repos` file resolves to itself; `docs/prototype.md` is gone; the adapter's manifest route no longer exists), and the roadmap lines above are re-checked.

## Files to Change

| File | Change |
|------|--------|
| `tools/repos-manifest/src/repos_manifest/location.py` (new) | Location values, parsing, joining, identity (2b-1, extended in 2b-2 and 2b-3) |
| `tools/repos-manifest/src/repos_manifest/fetch.py` (new) | Git reader (2b-1), url reader (2b-3), the one git-running function, limits |
| `tools/repos-manifest/src/repos_manifest/{manifest,base,combine,system,init,sync,status,cli}.py` | As named in each part |
| `tools/repos-manifest/tests/test_location.py`, `test_fetch_git.py`, `test_fetch_url.py`, `test_manifest_location_cli.py` (new); `test_base_*.py`, `test_init*.py`, `test_sync*.py`, `test_status*.py`, `test_system.py`, `test_cli.py`, `test_documents.py` | New and changed tests as listed |
| `tools/repos-manifest/{README.md,docs/design.md,docs/spec.md,docs/roadmap.md}` | Per part |
| `docs/manifest/design.md`, `docs/manifest/roadmap.md`, `docs/design.md` | The "kept by hand" text and the roadmap line (2b-1); `base` text if any (2b-2) |
| `.agent/project_types/ros2_colcon/adapter.sh`, `.agent/scripts/tests/test_ros2_colcon.sh` | The refusal's clone line and its assertions (2b-1) |

## Prior Art

The old reader's git code (`extends.py`, removed by #603) is not reused: it checked out, ran with hook and filter guards and kept a cache, all of which the owner's decision of 2026-11-17 and the no-cache rule drop; a bare shallow clone with no checkout needs none of them. Kept from it as ideas: end git by its process, not a group, when it shares the tool's group; a time limit on git calls. `update.py`'s `Git` class runs git in an existing clone with `GIT_OPTIONS`; the manifest read has no clone yet, so it does not share it. `sync.require_git()` supplies the environment. `git archive --remote` is not served by GitHub; a partial clone costs a second round trip. Nothing else new is built.

## Serves

Goal: Modular (`README.md#modular`; the tool is a module the workspace uses, and the owner's aim is to exercise the new design on project11). Design: `tools/repos-manifest/docs/design.md#where-the-manifest-comes-from`, `#what-is-built`, `#status`; the format `tools/repos-manifest/docs/spec.md` (Locations, Reading a manifest before using it); `docs/manifest/design.md#what-the-tool-has-to-give`.

## Design Picture

Yes. The tool's own design (ADR-0022, ADR-0017) changes in each part as listed, in the same part. The workspace design changes in 2b-1: `docs/manifest/design.md` ("A root that sets `source`", "What the tool has to give", the settings table) and the root `docs/design.md` sentence about the clone kept by hand; those are the only places where what crosses the boundary changes.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Keep one current design | Each part rewrites the sentences it makes false; the "path only" sentences go in the last part, not before. |
| Only what's needed | No cache, no hook guards, no settings for the limits (#510). The git reader is one function and one clone per run. |
| A safeguard has to earn its cost | The checks are the spec's list, one function, tested once per rule; git's own refusals (`GIT_ALLOW_PROTOCOL`) are tested rather than reimplemented. |
| Ask about what matters | Open questions below, each with what the design says and a recommendation; the build follows the recommendation until the owner answers. |
| Test what breaks | Every rule in "Reading a manifest before using it" has a test for the git form and, in 2b-3, the URL form; every network behaviour is tested against local repos and a local server. |
| Verify before claiming | Roadmap lines are checked by the commands in their check column; documents are written from the code. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0022 | Yes | The tool's design owns the tool; the root design changes only where the boundary does. |
| ADR-0017 | Yes | Design and spec updated in the part that changes what they describe. |
| ADR-0011 | Yes | 2b-1 changes the adapter's refusal message and its test; the adapter suite passes at the end of each part. |
| ADR-0009 | Yes | Tests run from the repo's venv; no bare `pip install`. |
| ADR-0013 | Yes | Each part gets its own progress entries; this revision has a `## Plan Authored` entry. |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `Config.manifest` from a string to a location | `status` text and `--json`, `sync`'s messages that name `config.manifest`, `recorded_manifest`, `built_note`'s `realpath(system / config.manifest)`, `_show_in_system`'s canonical path | Yes, 2b-1 |
| `read_config` accepts a mapping and a URL | `test_system.py` (the refusal tests become the new rules), `test_init_refusals.py` line near 389 | Yes, 2b-1 and 2b-3 |
| The refusals' next steps name `--manifest-ref` | the design's note in "Refusals" ("left out of the message until it is built") | Yes, 2b-1 |
| `status` reads a manifest at a URL or in git | the sentence "makes no network call of its own" in `status` and in "What is built" | Yes, 2b-1 (Open question 1) |
| The adapter's refusal message | `test_ros2_colcon.sh`, comments in `adapter.sh`, `docs/manifest/design.md`, root `docs/design.md` | Yes, 2b-1 |
| `show` and `init` print a `manifest` line | the form of that line for a git location | Yes, 2b-1 |
| #603 changes files this plan names | re-read each file on `main` first | Yes, first step of 2b-1 |

## Open questions

Each says what the design says today and what the plan does until the owner answers.

1. `status` and a recorded manifest at a URL or in git. The design says `status` "makes no network call of its own" and resolves each distro in memory as `sync` does. Reading that manifest needs the network. Recommendation A: `status` reads it as `sync` does and the design sentence becomes "except reading the manifest when it is recorded at a URL or in a git repo". B: `status` answers from the resolved files `sync` last wrote, which changes what it compares against. The plan builds A.
2. A manifest read from the network that names the local disk (an absolute path, or a `file://` or absolute-path git url). The design is silent. Recommendation: allowed, one sentence in the spec; the file is read on the person's own machine and shown on their own terminal. The alternative refuses a local location from a network manifest.
3. Whether git's error text (and an http error status) is printed in the message. The design says a command with no terminal "fails with a message". Recommendation: print git's stderr with unsafe characters replaced and urls masked, and always say "a branch or tag is meant" when a `version` fails to clone (it cannot be told apart from a missing branch).
4. Limits for reading a manifest (60 s with no terminal for git and always for http, 1 MiB, redirects only to http or https and never https to http). The design and spec give none; the 2026-11-18 Checkpoint chose them; #510 designs settable limits for fetches. The plan uses them as constants and #510 makes them settable.
5. A relative `base` of a git-located manifest. The design says it comes from the same repo; the spec says a location's `path` has no `..`. Recommendation: join and normalise, refuse a result that leaves the repo.
6. The form of `manifest` in `status --json` for a git location (today a masked string). Recommendation: an object with `url`, `version` and `path`, the field stays a string for a path or URL, and the document says so; no script in the workspace reads the field.
7. Settled by the Plan Review's direction 5 (2026-11-24): `GIT_ALLOW_PROTOCOL` is set from the url's own scheme (`https` for https, `http:https` for http, `ssh`, `file`), so git's curl cannot follow a redirect from https to http, and a redirect within the scheme still works.

Not part of this issue, to be opened if the owner agrees: `local_manifest` and `sync`'s step 1 (a developer who edits the manifest in its clone gets the edited one); a distro's `manifest_version` and `add-distro --manifest-ref`; `fetch_from` acting on the manifest's own repo and on a parent manifest (the design says it waits for this issue); a manifest named by a commit (#510).

## Lessons carried from parts 1 and 2a

State a rule once, structurally, and do not follow git's parser case by case. Write each document sentence from the code and test it. Python 3.10 differs from 3.14: do not patch `os` functions, `socket.timeout` is not `TimeoutError` on 3.10, unicode tables differ. Keep the output writer as it is. Do not harden against inputs nobody writes: a manifest is read like a snippet of code from the internet. A failing run says what was left behind and what the next run does.

## Estimated Scope

Three pull requests, each leaving every suite passing; the first is the smallest that lets `init` and `sync` use a manifest in a git repo. 2b-1: about 500 lines of source, 700 of tests, documents and the adapter's message. 2b-2: about 250 lines of source, 500 of tests. 2b-3: about 250 lines of source, 500 of tests. Only 2b-3 says "Closes #498"; 2b-1 and 2b-2 say "Part of #498".
