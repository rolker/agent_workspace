#!/usr/bin/env bash
# .agent/scripts/tests/suites_for_files.sh
# Which .agent/scripts/tests/test_*.sh suites a set of changed files can
# affect (issue #410). run_script_tests.sh calls it in `--files` mode, the
# mode the validate-script-tests pre-commit hook uses, so a commit runs
# only the suites its files reach instead of all of them.
#
# Usage:
#   suites_for_files.sh [--tests-dir <dir>] [--deleted <path>]... [--] <file>...
#   suites_for_files.sh [--tests-dir <dir>] --dump
#
#   <file>     repo-relative paths (as pre-commit passes them).
#   --tests-dir  the suites directory; defaults to this script's directory.
#              The repository root is that directory's git toplevel.
#   --deleted  a path deleted (or renamed away) by the change; the runner
#              computes these, since pre-commit never passes them.
#   --dump     print the derived map instead, one `<suite>\t<kind>\t<path>`
#              line per entry; kinds: `ref` (derived closure), `covers`
#              (exact-file declaration), `scans` (scan-prefix declaration),
#              `always` (`# covers: ALL`). Read by
#              test_script_tests_hook_scope.sh's drift checks.
#
# Output (selection mode): either the single line `ALL`, or one suite
# basename per line. Why it chose that goes to stderr. Exit 0 in both
# cases; any internal error prints `ALL` (when in doubt, run everything).
#
# How the map is derived (plan .agent/work-plans/issue-410/plan.md, step 1):
#   - Vocabulary: tracked paths (`git ls-files`) plus the passed files,
#     kept when they match the hook's `files:` and not its `exclude:`
#     regex, parsed from .pre-commit-config.yaml (one-line plain, single-
#     or double-quoted scalars; Python `re.search`, the same matching
#     pre-commit itself does).
#   - A text references a vocabulary file when, after whole-line comments
#     (first non-blank character `#`) are stripped, a path-like token in it
#     is that file's repo-relative path (or ends in `/<path>`), or the
#     token's last `/`-component is the file's basename. An extensionless
#     basename (`adapter`, `agent`) only counts inside a token that has a
#     `/` (`./adapter` included), so the plain English word does not.
#     Python `import X` counts as a reference to `X.py`, and
#     `from X import Y` to `X.py` and `Y.py` (Y may be a module of package X).
#     An import is looked for wherever a Python statement or a string can
#     start: at the start of a line, and after every `;`, `:`, `'` and `"`
#     on it (a `\` just before a quote goes with the quote), so
#     `python3 -c "from X import Y"`, `x = 1; import X` and `try: import X`
#     are all seen. In each such piece a `#` ends the name list. The names
#     of a parenthesised `from X import (...)` are read across its
#     continuation lines, each line's `#` comment dropped first. An import
#     whose names are not a plain list (`a`, `a.b as c`, comma-separated,
#     a `from` list optionally in one pair of parentheses) -- a `\`
#     continuation, an unclosed `(`, `*`, anything else -- may hide a name,
#     and that name can only be a module, so the file then counts every
#     `.py` file as referenced: its suites run whenever any `.py` file
#     changes. A piece whose text after `import` is only words, dots and
#     commas yet not a name list (`import failed for optional layer`) is
#     prose, not Python (two names side by side), and is ignored; other
#     prose that starts a piece with `import ` takes the fallback (it
#     over-selects, never under-selects). What stays invisible is an import
#     that is not a statement: `__import__("x")`,
#     `importlib.import_module(...)` (see Residual risk).
#   - Closure: a suite's own references, expanded only through referenced
#     files that are code (`.sh`, `.py`, or extensionless with a `#!`
#     line). Documents are leaves.
#   - Declarations, for what text cannot show (comment lines in a suite,
#     read before the stripping):
#       `# covers: <file>...`  exact files the suite reads; mapped like a
#                              reference (a code file is expanded too).
#       `# covers: ALL`        the suite joins every scoped run.
#       `# scans: <prefix>...` the suite scans a whole prefix (git grep,
#                              a directory walk); a changed file under it
#                              adds this suite, but does NOT count as a
#                              mapping for the unmapped-file rule or the
#                              tests/ exemption below.
#
# Full run (`ALL`) when any of these holds:
#   - no files were passed;
#   - a deleted in-scope path was passed with --deleted;
#   - a passed file is outside the hook's files:/exclude: scope as this
#     script parses it (pre-commit has already filtered the list, so the
#     parse or the caller disagrees with pre-commit), or no tracked file is
#     in that scope at all;
#   - a changed file is a full-run trigger: run_script_tests.sh, this
#     script, anything else under the tests directory that is not a direct
#     test_*.sh suite and not an exact-file `# covers:` path,
#     .pre-commit-config.yaml, Makefile, .agent/scripts/set_git_identity_env.sh,
#     or any .agent/scripts/_*.sh helper (matched by glob);
#   - an in-scope changed file maps to no suite (by derivation or an
#     exact-file `# covers:`);
#   - an error.
# In a scoped run, test_checkpoint_269.sh always joins (the runner's
# required suite), and so does any suite with `# covers: ALL` or with no
# derived reference at all (test_script_tests_hook_scope.sh fails if one of
# those appears without a declaration).
#
# Residual risk: a path or module name assembled at runtime entirely from
# variables, with no literal name anywhere (including a module loaded with
# `__import__` or `importlib`), is invisible to this derivation; the drift
# check in test_script_tests_hook_scope.sh catches it only for suites that
# read the real repository root (ROOT_READERS).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec python3 - "$SCRIPT_DIR" "$@" <<'PY'
import fnmatch
import os
import re
import subprocess
import sys

REQUIRED_SUITE = "test_checkpoint_269.sh"
HOOK_ID = "validate-script-tests"


def note(msg):
    print(f"suites_for_files: {msg}", file=sys.stderr)


def run_all(reason):
    note(f"ALL: {reason}")
    print("ALL")
    sys.exit(0)


def parse_args(argv):
    script_dir = argv[0]
    tests_dir = script_dir
    deleted, files, dump = [], [], False
    args = argv[1:]
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--tests-dir" and i + 1 < len(args):
            tests_dir = args[i + 1]
            i += 2
        elif a == "--deleted" and i + 1 < len(args):
            deleted.append(args[i + 1])
            i += 2
        elif a == "--dump":
            dump = True
            i += 1
        elif a == "--":
            files.extend(args[i + 1:])
            break
        elif a.startswith("--"):
            raise ValueError(f"unknown option or missing value: {a}")
        else:
            files.append(a)
            i += 1
    return tests_dir, deleted, files, dump


def hook_regexes(root):
    path = os.path.join(root, ".pre-commit-config.yaml")
    with open(path, encoding="utf-8") as fh:
        lines = fh.read().splitlines()
    files_re = exclude_re = None
    in_block = False
    for line in lines:
        if re.match(r"^\s*-\s+id:\s*", line):
            if in_block:
                break
            in_block = re.match(rf"^\s*-\s+id:\s*{re.escape(HOOK_ID)}\s*$", line) is not None
            continue
        if not in_block:
            continue
        m = re.match(r"^\s*files:\s*(.+?)\s*$", line)
        if m and files_re is None:
            files_re = yaml_scalar(m.group(1))
        m = re.match(r"^\s*exclude:\s*(.+?)\s*$", line)
        if m and exclude_re is None:
            exclude_re = yaml_scalar(m.group(1))
    if files_re is None:
        raise ValueError(f"no files: regex for {HOOK_ID} in {path}")
    return re.compile(files_re), (re.compile(exclude_re) if exclude_re else None)


def yaml_scalar(raw):
    """The string a one-line YAML scalar holds, as pre-commit reads it.

    Single quotes: strip them, `''` is one quote. Double quotes: strip
    them and undo the escapes a regex needs (`\\\\`, `\\"`); any other
    escape is refused. Plain: cut a ` #` comment. A block scalar (`|`,
    `>`) or an unclosed quote is refused: the caller's error path runs
    every suite rather than guess.
    """
    if raw[0] == "'":
        m = re.match(r"^'((?:[^']|'')*)'\s*(?:#.*)?$", raw)
        if not m:
            raise ValueError(f"cannot read the single-quoted YAML scalar {raw!r}")
        return m.group(1).replace("''", "'")
    if raw[0] == '"':
        m = re.match(r'^"((?:[^"\\]|\\.)*)"\s*(?:#.*)?$', raw)
        if not m:
            raise ValueError(f"cannot read the double-quoted YAML scalar {raw!r}")

        def unescape(e):
            if e.group(1) not in '\\"':
                raise ValueError(f"unsupported escape {e.group(0)!r} in {raw!r}")
            return e.group(1)

        return re.sub(r"\\(.)", unescape, m.group(1))
    if raw[0] in "|>":
        raise ValueError(f"block scalar {raw!r} is not supported")
    return re.split(r"\s+#", raw, maxsplit=1)[0]


TOKEN_RE = re.compile(r"[A-Za-z0-9_./-]+")
# Applied to each piece of a line (see import_pieces), not to whole lines.
IMPORT_RE = re.compile(r"^\s*import\s+(.*)$")
FROM_RE = re.compile(r"^\s*from\s+([A-Za-z0-9_.]+)\s+import\b(.*)$")
FROM_OPEN_RE = re.compile(r"^\s*from\s+[A-Za-z0-9_.]+\s+import\s*\([^)]*$")
# Where a Python statement or a string can start inside a line. A `\"` (a
# quote escaped for the shell around a `python3 -c`) is one boundary.
PIECE_SPLIT_RE = re.compile(r"""\\?["']|[;:]""")
# A fully readable import name list: `a`, `a.b as c`, comma-separated; a
# `from` list may also sit in one pair of parentheses with a trailing comma.
_NAME = r"[A-Za-z0-9_.]+(?:\s+as\s+[A-Za-z0-9_]+)?"
_LIST = rf"{_NAME}(?:\s*,\s*{_NAME})*"
IMPORT_NAMES_RE = re.compile(rf"^\s*({_LIST})\s*$")
FROM_NAMES_RE = re.compile(rf"^\s*(?:\(\s*({_LIST})\s*,?\s*\)|({_LIST}))\s*$")
# What follows `import` in prose: words, dots, commas and blanks only, and
# (checked first) not a name list. No Python import has that shape.
PROSE_RE = re.compile(r"^[A-Za-z0-9_.,\s]*$")
DECL_RE = re.compile(r"^#\s*(covers|scans):\s*(.*?)\s*$")


def read_text(root, rel):
    try:
        with open(os.path.join(root, rel), encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except (FileNotFoundError, IsADirectoryError):
        return None


def strip_comment_lines(text):
    return "\n".join(l for l in text.splitlines() if not l.lstrip().startswith("#"))


def is_code(root, rel):
    base = os.path.basename(rel)
    if base.endswith((".sh", ".py")):
        return True
    if "." in base:
        return False
    text = read_text(root, rel)
    return text is not None and text.startswith("#!")


class Index:
    def __init__(self, vocab):
        self.by_path = set(vocab)
        self.by_base = {}
        for v in vocab:
            self.by_base.setdefault(os.path.basename(v), set()).add(v)
        self.py_files = {v for v in vocab if v.endswith(".py")}

    def refs(self, text, self_path=None):
        found = set()
        body = strip_comment_lines(text)
        for tok in TOKEN_RE.findall(body):
            tok = tok.rstrip(".")
            if not tok:
                continue
            t = tok[2:] if tok.startswith("./") else tok
            # `./adapter` names the extensionless script as surely as
            # `scripts/adapter` does, so the slash test reads the raw token.
            slashed = "/" in tok
            if t in self.by_path:
                found.add(t)
            if "/" in t:
                # `$ROOT/.agent/scripts/x.sh` tokenises as `/.agent/scripts/x.sh`.
                parts = t.split("/")
                for k in range(1, len(parts)):
                    tail = "/".join(parts[k:])
                    if tail in self.by_path:
                        found.add(tail)
            last = t.rsplit("/", 1)[-1]
            if last in self.by_base and ("." in last or slashed):
                found |= self.by_base[last]
        # Python imports, looked for in every piece of every line.
        unreadable = False
        for piece in import_pieces(body):
            names = rest = None
            m = FROM_RE.match(piece)
            if m:
                rest = m.group(2)
                n = FROM_NAMES_RE.match(rest)
                if n:
                    # `from pkg import mod` may import the module mod.py.
                    names = [m.group(1)] + split_names(n.group(1) or n.group(2))
            else:
                m = IMPORT_RE.match(piece)
                if m:
                    rest = m.group(1)
                    n = IMPORT_NAMES_RE.match(rest)
                    if n:
                        names = split_names(n.group(1))
            if m and names is None:
                if PROSE_RE.match(rest):
                    # Only words, dots and commas, yet not a name list:
                    # two names side by side or a dangling comma, which
                    # Python refuses, so this is prose ("import failed
                    # for ...") and imports nothing.
                    continue
                # An import this parser cannot fully read (a `\`
                # continuation, an unclosed `(`, `*`, an escaped newline,
                # ...): a name in it may be lost, and it can only be a
                # module, so count every .py file as referenced.
                unreadable = True
                continue
            for name in names or []:
                for comp in name.split("."):
                    if comp:
                        found |= self.by_base.get(comp + ".py", set())
        if unreadable:
            found |= self.py_files
        found.discard(self_path)
        return found


def import_pieces(body):
    """Each place in `body` a Python import statement could start, as text.

    A line is cut at every `;`, `:`, `'` and `"` (PIECE_SPLIT_RE); each
    piece runs to the next cut, with a `#` and what follows it dropped (a
    name list never holds a `#`). Cutting more often than Python would only
    adds pieces, and a piece that does not start with `import`/`from` is
    ignored, so no import that starts a piece is lost. A piece that opens a
    parenthesised `from X import (` without closing it is joined with the
    following lines (each line's `#` comment dropped first) up to the first
    line holding a `)`, and the rest of its first line is part of it; with
    no `)` before the end, the joined text is unreadable, which the caller
    treats as the every-.py fallback.
    """
    lines = body.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        i += 1
        cuts = list(PIECE_SPLIT_RE.finditer(line))
        starts = [0] + [c.end() for c in cuts]
        ends = [c.start() for c in cuts] + [len(line)]
        for start, end in zip(starts, ends):
            rest = line[start:].split("#", 1)[0]
            if FROM_OPEN_RE.match(rest):
                parts = [rest]
                while i < len(lines) and ")" not in parts[-1]:
                    parts.append(lines[i].split("#", 1)[0])
                    i += 1
                yield " ".join(" ".join(parts).split())
                break
            yield line[start:end].split("#", 1)[0]


def split_names(names):
    """`a.b as c, d` -> ['a.b', 'd']: the imported names, aliases dropped."""
    return [n.split()[0] for n in names.split(",") if n.strip()]


def main():
    tests_dir, deleted, files, dump = parse_args(sys.argv[1:])
    tests_dir = os.path.abspath(tests_dir)
    try:
        root = subprocess.run(
            ["git", "-C", tests_dir, "rev-parse", "--show-toplevel"],
            check=True, capture_output=True, text=True,
        ).stdout.strip()
    except (subprocess.CalledProcessError, OSError) as exc:
        raise ValueError(f"{tests_dir} is not inside a git repository ({exc})")
    root = os.path.realpath(root)
    tests_rel = os.path.relpath(os.path.realpath(tests_dir), root)
    if tests_rel.startswith(".."):
        raise ValueError(f"{tests_dir} is outside the repository root {root}")

    files_re, exclude_re = hook_regexes(root)

    def in_scope(p):
        return files_re.search(p) is not None and not (exclude_re and exclude_re.search(p))

    tracked = subprocess.run(
        ["git", "-C", root, "ls-files", "-z"],
        check=True, capture_output=True, text=True,
    ).stdout.split("\0")
    if not any(p and in_scope(p) for p in tracked):
        raise ValueError(f"no tracked file matches the {HOOK_ID} files:/exclude: regexes as parsed; the parse is wrong")
    vocab = sorted({p for p in tracked + files if p and in_scope(p)})
    index = Index(vocab)

    suites = sorted(
        f for f in os.listdir(tests_dir)
        if fnmatch.fnmatch(f, "test_*.sh") and os.path.isfile(os.path.join(tests_dir, f))
    )
    if not suites:
        raise ValueError(f"no test_*.sh suites in {tests_dir}")

    code_cache = {}
    refs_cache = {}

    def code(rel):
        if rel not in code_cache:
            code_cache[rel] = is_code(root, rel)
        return code_cache[rel]

    def refs_of(rel):
        if rel not in refs_cache:
            text = read_text(root, rel)
            refs_cache[rel] = index.refs(text, rel) if text is not None else set()
        return refs_cache[rel]

    closure, covers, scans, always = {}, {}, {}, set()
    for s in suites:
        rel = os.path.normpath(os.path.join(tests_rel, s))
        text = read_text(root, rel) or ""
        cov, scn = set(), set()
        for line in text.splitlines():
            m = DECL_RE.match(line)
            if not m:
                continue
            values = m.group(2).split()
            if m.group(1) == "covers":
                for v in values:
                    if v == "ALL":
                        always.add(s)
                    else:
                        cov.add(v)
            else:
                scn |= {v.rstrip("/") for v in values}
        covers[s], scans[s] = cov, scn
        seen = set()
        todo = list(index.refs(text, rel) | cov)
        while todo:
            f = todo.pop()
            if f in seen:
                continue
            seen.add(f)
            if code(f):
                todo.extend(refs_of(f) - seen)
        seen.discard(rel)
        closure[s] = seen

    if dump:
        for s in suites:
            for f in sorted(closure[s]):
                print(f"{s}\tref\t{f}")
            for f in sorted(covers[s]):
                print(f"{s}\tcovers\t{f}")
            for f in sorted(scans[s]):
                print(f"{s}\tscans\t{f}")
            if s in always:
                print(f"{s}\talways\tALL")
        return

    if not files:
        run_all("no files were passed")

    for d in deleted:
        if in_scope(d):
            run_all(f"'{d}' is deleted or renamed away and in the hook's scope (pre-commit never passes it, and suites may still name it)")

    exact_declared = set().union(*covers.values())
    suite_paths = {os.path.normpath(os.path.join(tests_rel, s)): s for s in suites}
    fixed_triggers = {
        os.path.normpath(os.path.join(tests_rel, "run_script_tests.sh")),
        os.path.normpath(os.path.join(tests_rel, "suites_for_files.sh")),
        ".pre-commit-config.yaml",
        "Makefile",
        ".agent/scripts/set_git_identity_env.sh",
    }

    def under(path, prefix):
        return path == prefix or path.startswith(prefix + "/")

    selected = {}
    for f in files:
        f = os.path.normpath(f[2:] if f.startswith("./") else f)
        if not in_scope(f):
            # pre-commit passes only files its own files:/exclude: match, so
            # a passed file this parse rejects means the parse (or the
            # caller) disagrees with pre-commit: run everything.
            run_all(f"'{f}' was passed but is outside the hook's files:/exclude: scope as parsed here")
        if f in fixed_triggers:
            run_all(f"'{f}' is a full-run trigger")
        if os.path.dirname(f) == ".agent/scripts" and fnmatch.fnmatch(os.path.basename(f), "_*.sh"):
            run_all(f"'{f}' is a shared helper (.agent/scripts/_*.sh)")
        if under(f, tests_rel) and f not in suite_paths and f not in exact_declared:
            run_all(f"'{f}' is under {tests_rel}/ but is not a test_*.sh suite or a declared '# covers:' file")
        hits = set()
        if f in suite_paths:
            hits.add(suite_paths[f])
        hits |= {s for s in suites if f in closure[s]}
        if not hits:
            run_all(f"'{f}' maps to no suite")
        for s in hits:
            selected.setdefault(s, f)
        for s in suites:
            if any(under(f, p) for p in scans[s]):
                selected.setdefault(s, f"{f} (scans)")

    for s in suites:
        if s == REQUIRED_SUITE:
            selected.setdefault(s, "always (required suite)")
        elif s in always:
            selected.setdefault(s, "always (# covers: ALL)")
        elif not closure[s] and not covers[s] and not scans[s]:
            selected.setdefault(s, "always (no derived references)")

    for s in sorted(selected):
        note(f"{s} <- {selected[s]}")
    for s in sorted(selected):
        print(s)


try:
    main()
except SystemExit:
    raise
except Exception as exc:  # any error: run everything
    run_all(f"error: {exc}")
PY
