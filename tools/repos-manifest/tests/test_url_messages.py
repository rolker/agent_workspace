"""The messages the tool builds that hold a url mask it before it is quoted or escaped
(``docs/design.md``, "sync"). The scan here is a guard against accidents, not a proof.

The scan walks the syntax tree of every module of the package and looks at each value that
is formatted into text: each `{...}` of an f-string, each operand of a `+` or `%` on text
(one side a constant or an f-string), each argument of a `.format(...)`, and each positional
argument given directly to `print`, `ManifestError`, `Refusal`, `Done` or `warn`. A value
counts as a url when a name in it (a variable, an attribute, or a constant key such as
`["url"]`) holds "url" or is `origin`, the names the code uses for urls (a module constant in
capitals, such as `_URL_RULE`, is message text). Such a value must be a call of `mask_url`,
`quoted_url`, `mask_urls` or `set_url_command`, or sit on a line marked `# url-text:` with the
reason it is not a message (a git argument, a hash input). Each of those four is safe on a
value that is not a string: `quoted_url` describes it by its kind and shows nothing of it, and
the others refuse it (`TypeError`); a test below holds them to that.

The second test closes part of the name gap: an assignment that takes a url (from an
attribute or key named `url`, or from `self.url(...)`) must give it a name the scan reads. A
third finds no `!r` and no call of `repr` in the two modules that read a manifest
(`manifest.py` and `schema.py`). It does not check their other echoes: `schema.py` still
prints some values from a manifest as they are (a layer name in quotes, whole lists), which
the design's list of limits names.

What the scan cannot see, so a url reaching a message by one of these ways is not caught here:
- a url under a name without "url": by `getattr`, a tuple or annotated assignment, a walrus
  (`:=`), a `for` target, or a parameter with another name (`path`, `value`, `name`) in a
  function it is passed to;
- a url passed to a helper that formats it, or joined (`", ".join(...)`), or put in a list or
  a dict that is then formatted whole;
- `prefix + url` with no constant side, and `text += url`;
- keyword arguments to `Done`, `Refusal` and the other direct calls;
- output that is not one of those calls: `logging`, `sys.stderr.write`;
- an exception formatted as `{exc}` whose text holds a url.
Behind it, `mask_urls` masks every line `sync` prints and every `ERROR:` line of any
command, and the end-to-end tests in `test_masking.py` run each command over passwords that
`repr` escapes.
"""

import ast
import re
from pathlib import Path

import pytest

import repos_manifest

SRC = Path(repos_manifest.__file__).parent
SAFE = {"mask_url", "quoted_url", "mask_urls", "set_url_command"}
DIRECT = {"print", "ManifestError", "Refusal", "Done", "warn"}
URLISH = re.compile(r"url", re.IGNORECASE)


CONSTANT = re.compile(r"_?[A-Z0-9_]+")


def _is_urlish(name: str) -> bool:
    if CONSTANT.fullmatch(name):
        return False  # a module constant (`_URL_RULE`) is message text, not a url
    return bool(URLISH.search(name)) or name == "origin"


def _names(node):
    for sub in ast.walk(node):
        if isinstance(sub, ast.Name):
            yield sub.id
        elif isinstance(sub, ast.Attribute):
            yield sub.attr
        elif isinstance(sub, ast.Subscript) and isinstance(sub.slice, ast.Constant):
            if isinstance(sub.slice.value, str):
                yield sub.slice.value


def _func_name(call: ast.Call) -> str:
    func = call.func
    return func.id if isinstance(func, ast.Name) else getattr(func, "attr", "")


def _unsafe(expr) -> bool:
    if isinstance(expr, ast.Call) and _func_name(expr) in SAFE:
        return False
    if isinstance(expr, (ast.Constant, ast.JoinedStr)):
        return False  # a nested f-string is walked on its own
    return any(_is_urlish(name) for name in _names(expr))


def offenders(source: str):
    """(line, text) of each value formatted into text that names a url and is not masked."""
    tree = ast.parse(source)
    lines = source.splitlines()
    found = []

    def flag(node):
        line = lines[node.lineno - 1]
        if "# url-text:" not in line:
            found.append((node.lineno, line.strip()))

    for node in ast.walk(tree):
        values = []
        if isinstance(node, ast.FormattedValue):
            values = [node.value]
        elif isinstance(node, ast.BinOp) and isinstance(node.op, (ast.Add, ast.Mod)):
            if any(
                isinstance(side, (ast.Constant, ast.JoinedStr)) for side in (node.left, node.right)
            ):
                values = [node.left, node.right]
        elif isinstance(node, ast.Call) and _func_name(node) == "format":
            values = list(node.args) + [k.value for k in node.keywords]
        elif isinstance(node, ast.Call) and _func_name(node) in DIRECT:
            values = list(node.args)
        for value in values:
            if _unsafe(value):
                flag(value)
    return found


def misnamed(source: str):
    """(line, text) of each assignment that takes a url into a name the scan does not read."""
    tree = ast.parse(source)
    lines = source.splitlines()
    found = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Assign):
            continue
        value = node.value
        takes_url = (
            (isinstance(value, ast.Attribute) and value.attr == "url")
            or (
                isinstance(value, ast.Subscript)
                and isinstance(value.slice, ast.Constant)
                and value.slice.value == "url"
            )
            or (isinstance(value, ast.Call) and _func_name(value) == "url")
        )
        if not takes_url:
            continue
        for target in node.targets:
            for name in _names(target):
                if not _is_urlish(name) and name not in ("given", "entry", "data", "kwargs"):
                    found.append((node.lineno, lines[node.lineno - 1].strip()))
    return found


MODULES = sorted(p for p in SRC.glob("*.py") if p.name != "masking.py")


@pytest.mark.parametrize("module", MODULES, ids=lambda p: p.name)
def test_every_message_that_formats_a_url_masks_it(module):
    assert offenders(module.read_text()) == []


@pytest.mark.parametrize("module", MODULES, ids=lambda p: p.name)
def test_a_url_keeps_a_name_the_scan_reads(module):
    assert misnamed(module.read_text()) == []


@pytest.mark.parametrize(
    "source, caught",
    [
        ('raise E(f"{url!r} is refused")\n', True),
        ('raise E(f"{repo.url}")\n', True),
        ('x = f"origin is {origin}"\n', True),
        ("x = f\"{entry['url']}\"\n", True),
        ('msg = "url: " + url\n', True),
        ('msg = "url: %s" % url\n', True),
        ('msg = "url: {}".format(record.url)\n', True),
        ("print(repo.url)\n", True),
        ('raise E(f"{quoted_url(url)} is refused")\n', False),
        ('x = f"origin is {mask_url(origin)}"\n', False),
        ('x = f"{url}@{ref}"  # url-text: a hash input\n', False),
        ('x = f"{origins[:12]}"\n', False),  # commits, not a url
        ('x = f"{_URL_RULE}"\n', False),
        ('x = f"{layer}: {key}"\n', False),
    ],
)
def test_the_scan_catches_each_shape(source, caught):
    assert bool(offenders(source)) == caught, offenders(source)


def test_a_url_under_another_name_is_caught_where_it_is_taken():
    assert misnamed("address = repo.url\n")
    assert misnamed("a = self.url(value, where)\n")
    assert not misnamed("url = repo.url\nremote_url = entry['url']\n")


def echoes(source: str):
    """(line, text) of each value echoed with `!r` or `repr(...)`."""
    tree = ast.parse(source)
    lines = source.splitlines()
    found = []
    for node in ast.walk(tree):
        if (isinstance(node, ast.FormattedValue) and node.conversion == ord("r")) or (
            isinstance(node, ast.Call) and _func_name(node) == "repr"
        ):
            found.append((node.lineno, lines[node.lineno - 1].strip()))
    return found


@pytest.mark.parametrize("name", ["manifest.py", "schema.py"])
def test_a_module_that_reads_a_manifest_echoes_only_through_quoted_url(name):
    """No `!r` and no `repr(...)` in the two readers: a key, a name, a path or a value of the
    wrong type need not be named like a url to hold one (round 5: a `base:` url, a list given
    as a url). Other ways these modules echo a value are not checked here."""
    assert echoes((SRC / name).read_text()) == []


def test_the_echo_scan_catches_each_shape():
    assert echoes('x = f"{path!r}"\n')
    assert echoes("x = repr(location)\n")
    assert not echoes('x = f"{quoted_url(path)}"\n')


def test_each_safe_function_shows_nothing_of_a_value_that_is_not_a_string():
    """The scan counts these as safe whatever they are given, so none may show the content of
    a list, a mapping or a number: `quoted_url` describes its kind, the others refuse it."""
    from repos_manifest import masking, update

    secret = "https://aliceQ:pw zQ@127.0.0.1:9/x.git"
    for value in ([secret], {"u": secret}, 5):
        assert masking.quoted_url(value) in ("a list", "a mapping", "a int")
        for function in (masking.mask_url, masking.mask_urls):
            with pytest.raises(TypeError):
                function(value)
        with pytest.raises(TypeError):
            update.set_url_command(Path("/srv/a"), value, "a")
    assert SAFE == {"mask_url", "quoted_url", "mask_urls", "set_url_command"}
