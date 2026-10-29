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
#     `from X import Y` to `X.py` and `Y.py` (Y may be a module of package X),
#     each found by basename, and a component that names a package
#     directory also maps that package's init file (`import lib` ->
#     `lib/__init__.py`). Imports are read on one of two paths:
#     A `.py` file is parsed with Python's `ast`, which reads every import
#     statement exactly, wherever and however it is written (`try:` blocks,
#     parenthesised lists, `from .import a`). A relative import resolves
#     against the file's own directory instead of by basename: `from . import
#     x` maps `x.py` beside the file (and the package's init file), each
#     further dot one directory up. A file `ast` cannot parse (a syntax
#     error, Python 2) or a star import takes the every-`.py` fallback below.
#     Every string literal in it (docstrings, the literal parts of
#     f-strings and bytes literals included) is also read by the piece
#     parser, so Python run from a `.py` file (`subprocess.run([sys.executable,
#     "-c", "import a"])`, or `input=b"import a\n"` on stdin) is mapped or
#     falls back like Python in a shell file.
#     Any other file (shell, with Python in `python3 -c`, heredocs,
#     `$'...'`) is read by the piece parser below.
#     The piece parser's promise: every `import` word that could be Python
#     is either the keyword of a statement whose names are mapped exactly,
#     or it makes the file count every `.py` file as referenced (its suites
#     then run whenever any `.py` file changes); a name that is lost can
#     only be a module, so every `.py` is exactly the set it could denote.
#     How:
#       * Each line is cut into pieces at every `;`, `:`, `'`, `"` (a `\`
#         just before a quote goes with it) and escaped `\n`, `\r`, `\t`;
#         a comment (a `#` at the start of a piece or after a blank) is
#         dropped. So `python3 -c "from X import Y"`, `x = 1; import X`,
#         `try: import X` and `$'x = 1\nimport X'` are all seen.
#       * A piece is a clean statement when it is `import <list>` or
#         `from X import <list>`, the list plain (`a`, `a.b as c`,
#         comma-separated, a `from` list optionally in one pair of
#         parentheses, read across its continuation lines), it holds no
#         other `import` word, and no string is glued onto its closing
#         quote (`"import a"", b"`, `"import a"'b'`, Python's `"a" "b"`).
#         Its names are mapped.
#       * Any other piece holding an `import` word takes the fallback: a
#         `\` continuation, an unclosed `(`, `*`, a dangling comma, a
#         glued string, an `import` mid-piece (`echo import x | python3`),
#         an `import` whose `from X` header is the piece before it. So does
#         a `from` header with no `import` yet (`from`, then at most a
#         module name) that ends in `\` or has a string glued on.
#       * An `import` word is not Python, and ignored, only when no Python
#         statement can hold what follows it: a `-` (`vcs import --x`), or
#         a plain name (letters, digits, `_`, inner dots: no `$`, quote or
#         other shell expansion), a blank, and a second name that is not
#         `as` (`import failed for layer`). Python is then handed a syntax
#         error whatever the shell makes of the rest, and imports nothing.
#         `importlib`, `import_module`, `-import-` and `x.import` are not
#         the word; a dots-only module may touch it (`from .import a`).
#     What stays invisible is an import that is not a statement:
#     `__import__("x")`, `importlib.import_module(...)` (see Residual risk).
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
import ast
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
# The keyword is spelled `\x69mport` in these patterns so that this file's
# own text holds no import word the parser cannot read: one would send every
# suite that reaches this file into the every-.py fallback.
IMPORT_RE = re.compile(r"^\s*\x69mport\s+(.*)$")
# A `from` module is a dotted name before a blank, or dots alone, which
# Python lets touch the keyword (`from .import a`, `from ..import(a)`).
FROM_RE = re.compile(r"^\s*from(?:\s+([A-Za-z0-9_.]+)\s+|\s*(\.+)\s*)\x69mport\b(.*)$")
FROM_OPEN_RE = re.compile(r"^\s*from(?:\s+[A-Za-z0-9_.]+\s+|\s*\.+\s*)\x69mport\s*\([^)]*$")
# Where a Python statement or a string can start inside a line. A `\"` (a
# quote escaped for the shell around a `python3 -c`) is one boundary.
PIECE_SPLIT_RE = re.compile(r"""\\?["']|[;:]|\\[nrt]""")
# A fully readable import name list: `a`, `a.b as c`, comma-separated; a
# `from` list may also sit in one pair of parentheses with a trailing comma.
_NAME = r"[A-Za-z0-9_.]+(?:\s+as\s+[A-Za-z0-9_]+)?"
_LIST = rf"{_NAME}(?:\s*,\s*{_NAME})*"
IMPORT_NAMES_RE = re.compile(rf"^\s*({_LIST})\s*$")
FROM_NAMES_RE = re.compile(rf"^\s*(?:\(\s*({_LIST})\s*,?\s*\)|({_LIST}))\s*$")
# The keyword itself: every one in a piece must be the keyword of a clean
# statement, or the file takes the fallback. `importlib`, `import_module`
# and `__import__` are not this word.
IMPORT_WORD_RE = re.compile(r"(?<![\w=/-])(?<!\w\.)\x69mport(?![\w.=/-])")
# What may follow an `import` word that no Python statement can hold, so
# the word is prose or a command (`vcs import --skip-existing`, `import
# failed for layer`): a `-`, or a plain name, a blank and a second name
# that is not `as`. Plain means no `$`, quote or other shell expansion, so
# what Python is handed starts with exactly this text; the name may not end
# in `.`, since `import a. b` is Python (it imports a.b).
NOT_PYTHON_RE = re.compile(
    r"\s*-|\s+[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*\s+(?!as\b)[A-Za-z_]"
)
# After a quote that ends a piece: another string literal (Python implicit
# concatenation, or the shell's `"a"'b'`) or a character glued to the quote
# (the shell's `"a"b`) may continue the statement. A blank, a shell
# operator, or a closing `)`, `]` or `}` does not: glued on, a closer is a
# Python syntax error (`import a]`), and it is how a string ends inside a
# call or a list (`run([sys.executable, "-c", "..."])`).
CONCAT_RE = re.compile(r"""^\\?["'](?:\s*\\?["']|[^\s;|&)\]}<>])""")
# A `from` header with no `import` yet: `from`, then at most a module name.
FROM_HEAD_RE = re.compile(r"^\s*from(?:\s+[A-Za-z0-9_.]+|\s*\.+)?\s*(\\?)\s*$")
# A comment: a `#` at the start of a piece or after a blank (a `#` glued to
# a word, as in `${#a[@]}`, starts none in either bash or Python).
COMMENT_RE = re.compile(r"(?:^|\s)#.*$")
# A package's init file, spelled in two parts so this file's own text does
# not reference every such file in the repository by basename.
PKG_INIT = "__init__" + ".py"
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
        # Package init files by their directory's name: `lib` -> lib's.
        self.by_pkg = {}
        for v in vocab:
            if os.path.basename(v) == PKG_INIT:
                pkg = os.path.basename(os.path.dirname(v))
                self.by_pkg.setdefault(pkg, set()).add(v)

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
        # Python imports: a .py file's own statements through `ast`, Python
        # embedded in any other file through the piece parser.
        if self_path is not None and self_path.endswith(".py"):
            unreadable = self._py_imports(text, self_path, found)
        else:
            unreadable = self._embedded_imports(body, found)
        if unreadable:
            found |= self.py_files
        found.discard(self_path)
        return found

    def _add_module(self, comp, found):
        """One dotted-name component: its `.py` by basename, and the init
        file of any package directory of that name, which runs too."""
        found |= self.by_base.get(comp + ".py", set())
        found |= self.by_pkg.get(comp, set())

    def _py_imports(self, text, self_path, found):
        """Map a .py file's own statements, read with `ast`. An absolute
        name maps each dotted component's `.py` by basename, as the piece
        parser does; a relative one resolves against the file's own
        directory: level 1 is that directory, each further dot one up; the
        module, if any, is `<dir>/<module>.py` or its package init file, and
        each imported name may be a submodule `<dir>/<module>/<name>.py`
        (or its package). Returns True (fall back to every .py) when `ast`
        cannot parse the file, or for a star statement, whose names
        `__all__` may extend to any submodule. Every str literal
        (docstrings and f-string parts are str constants too) and every
        bytes literal (decoded, `errors="replace"`) also goes through the
        piece parser, and its fallback is this file's.
        """
        try:
            tree = ast.parse(text, filename=self_path)
        except (SyntaxError, ValueError):
            return True
        here = os.path.dirname(self_path)
        unreadable = False
        for node in ast.walk(tree):
            if isinstance(node, ast.Constant) and isinstance(node.value, (str, bytes)):
                lit = node.value
                if isinstance(lit, bytes):
                    lit = lit.decode("utf-8", errors="replace")
                if self._embedded_imports(strip_comment_lines(lit), found):
                    unreadable = True
            elif isinstance(node, ast.Import):
                for alias in node.names:
                    for comp in alias.name.split("."):
                        self._add_module(comp, found)
            elif isinstance(node, ast.ImportFrom):
                names = [a.name for a in node.names]
                if "*" in names:
                    return True
                if node.level == 0:
                    for comp in (node.module or "").split(".") + names:
                        if comp:
                            self._add_module(comp, found)
                    continue
                base = here
                for _ in range(node.level - 1):
                    base = os.path.dirname(base)
                if node.module:
                    base = os.path.join(base, *node.module.split("."))
                    cands = [base + ".py", os.path.join(base, PKG_INIT)]
                else:
                    cands = [os.path.join(base, PKG_INIT)]
                for n in names:
                    cands += [os.path.join(base, n + ".py"), os.path.join(base, n, PKG_INIT)]
                found |= {os.path.normpath(c) for c in cands} & self.by_path
        return unreadable

    def _embedded_imports(self, body, found):
        # Python imports, looked for in every piece of every line. Every
        # `import` word that could be Python is either the keyword of a
        # clean statement, whose names are mapped, or it makes the file
        # take the fallback.
        unreadable = False
        after_from_head = False
        for piece, tail in import_pieces(body):
            if not piece.strip():
                continue
            names = None
            m = FROM_RE.match(piece)
            if m:
                n = FROM_NAMES_RE.match(m.group(3))
                if n:
                    # `from pkg import mod` may import the module mod.py.
                    names = [m.group(1) or m.group(2)] + split_names(n.group(1) or n.group(2))
            else:
                m = IMPORT_RE.match(piece)
                if m:
                    n = IMPORT_NAMES_RE.match(m.group(1))
                    if n:
                        names = split_names(n.group(1))
            words = [w for w in IMPORT_WORD_RE.finditer(piece)
                     if not NOT_PYTHON_RE.match(piece, w.end())]
            head = FROM_HEAD_RE.match(piece)
            clean = (
                names is not None
                and len(words) == 1
                and not (after_from_head and m.re is IMPORT_RE)
                and not CONCAT_RE.match(tail)
            )
            if clean:
                for name in names:
                    for comp in name.split("."):
                        if comp:
                            self._add_module(comp, found)
            elif words or (head and (head.group(1) or CONCAT_RE.match(tail))):
                # An `import` this parser cannot fully read (a `\`
                # continuation, an unclosed `(`, `*`, a dangling comma, a
                # string glued on after it, an `import` whose `from X`
                # header sits in the piece before), or a `from X` header
                # continued by a `\` or a glued string: a name in it may
                # be lost, and it can only be a module, so count every .py
                # file as referenced.
                unreadable = True
            after_from_head = head is not None
        return unreadable


def import_pieces(body):
    """Each place in `body` a Python import statement could start, as
    (text, tail): tail is the rest of the line from the cut that ends the
    piece ("" for a joined parenthesised list).

    A line is cut at every `;`, `:`, `'`, `"` and escaped `\\n`, `\\r`,
    `\\t` (PIECE_SPLIT_RE); each piece runs to the next cut, with a
    comment (COMMENT_RE) dropped. Every
    character of the line outside a comment is in exactly one piece, so the
    caller sees every keyword. A piece that opens a parenthesised from-list
    (FROM_OPEN_RE) without closing it is joined with the following lines
    (each line's comment dropped first) up to the first line holding a `)`,
    and the rest of its first line is part of it; with no `)` before the
    end, the joined text is unreadable, which the caller treats as the
    every-.py fallback.
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
            rest = COMMENT_RE.sub("", line[start:])
            if FROM_OPEN_RE.match(rest):
                parts = [rest]
                while i < len(lines) and ")" not in parts[-1]:
                    parts.append(COMMENT_RE.sub("", lines[i]))
                    i += 1
                yield " ".join(" ".join(parts).split()), ""
                break
            yield COMMENT_RE.sub("", line[start:end]), line[end:]


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
