"""Every message the tool builds that holds a url masks it before it is quoted or escaped
(``docs/design.md``, "sync": a url's user name and password are never printed).

The scan walks the syntax tree of every module of the package and looks at each value that
is formatted into text: each `{...}` of an f-string, each operand of a `+` or `%` on text,
each argument of a `.format(...)`, and each argument given directly to `print`,
`ManifestError`, `Refusal`, `Done` or `warn`. A value counts as a url when a name in it (a
variable, an attribute, or a constant key such as `["url"]`) holds "url" or is `origin`, the
names the code uses for urls (a module constant in capitals, such as `_URL_RULE`, is message
text). Such a value must be a call of `mask_url`, `quoted_url`,
`mask_urls` or `set_url_command`, or sit on a line marked `# url-text:` with the reason it is
not a message (a git argument, a hash input).

What it cannot see: a url held under another name. The second test closes most of that: every
assignment that takes a url (from an attribute or key named `url`, or from `self.url(...)`)
must give it a name the scan reads, so a url cannot change its name on the way to a message.
A url passed as an argument to a function whose parameter has another name (`value` in
`manifest.py`'s checks) is not followed; those functions quote with `quoted_url` whatever
they are given, the end-to-end tests in `test_masking.py` run each refusal with a password
that `repr` escapes, and `mask_urls` on everything printed stays behind it.
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
