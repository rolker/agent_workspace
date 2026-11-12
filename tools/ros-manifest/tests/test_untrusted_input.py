"""A manifest, and every manifest it `extends`, is untrusted input: its names become file paths
and its values become lines of generated files. These tests hold the parse-time rules in
``schema.py`` (names, string types, control characters, credentials in URLs) and the emitter's
refusal of anything that reaches it by another route. Several are the reproductions from the
pre-push review of issue 436."""

import pytest

from ros_manifest.cli import main
from ros_manifest.schema import ManifestError, parse_manifest_text

SECRET = "s3cr3tT0ken"


def _repo_manifest(url: str = "https://example.com/a.git", ref: str = "main") -> str:
    return f"layers: [core]\nrepos:\n  core:\n    a:\n      url: {url}\n      ref: {ref}\n"


# --- names ---------------------------------------------------------------------------------


@pytest.mark.parametrize(
    "layer",
    [
        "'../../escaped'",  # reproduced: wrote two directories above --out
        "/tmp/pwned",  # reproduced: an absolute name writes anywhere
        "'#hidden'",  # listed, then dropped by any reader that skips `#` lines
        "a.b",
        "a/b",
        "''",
    ],
)
def test_bad_layer_name_is_refused(layer):
    with pytest.raises(ManifestError, match=r"t: layers\[0\]: layer name .* is not allowed"):
        parse_manifest_text(f"layers: [{layer}]\n", source="t")


def test_unquoted_numeric_layer_name_is_refused():
    with pytest.raises(ManifestError, match="t: layers must be a list of strings"):
        parse_manifest_text("layers: [1.10]\n", source="t")


@pytest.mark.parametrize("layer", ["core", "under_lay", "sim-2", "UI"])
def test_good_layer_name_is_accepted(layer):
    assert parse_manifest_text(f"layers: [{layer}]\n", source="t").layers == [layer]


@pytest.mark.parametrize("name", ["'../x'", "a/b", ".hidden", "-opt", "'#c'", "'a b'", "1.10"])
def test_bad_repository_name_is_refused(name):
    text = (
        f"layers: [core]\nrepos:\n  core:\n    {name}:\n"
        "      url: https://example.com/a.git\n      ref: main\n"
    )
    with pytest.raises(ManifestError, match=r"t: repos\.core: repository name .* is not allowed"):
        parse_manifest_text(text, source="t")


@pytest.mark.parametrize("name", ["ros2sonic", "geographic_info", "rviz.plugins", "a-b", "_x"])
def test_good_repository_name_is_accepted(name):
    text = (
        f"layers: [core]\nrepos:\n  core:\n    {name}:\n"
        "      url: https://example.com/a.git\n      ref: main\n"
    )
    assert name in parse_manifest_text(text, source="t").repos["core"]


def test_group_name_rule_allows_the_colon_the_fixtures_use():
    text = "layers: [core]\ngroups:\n  hw:deltat:\n    default: include\n"
    assert "hw:deltat" in parse_manifest_text(text, source="t").groups
    for bad in ["a/b", "':x'", "'#g'", "'a b'"]:
        with pytest.raises(ManifestError, match="groups: group name .* is not allowed"):
            parse_manifest_text(f"layers: [core]\ngroups:\n  {bad}:\n    default: include\n", "t")


def test_role_name_rule():
    assert "dev-2" in parse_manifest_text("layers: [core]\nroles:\n  dev-2: {}\n", "t").roles
    for bad in ["a:b", "a/b", "'-x'", "'a b'"]:
        with pytest.raises(ManifestError, match="roles: role name .* is not allowed"):
            parse_manifest_text(f"layers: [core]\nroles:\n  {bad}: {{}}\n", source="t")


def test_distro_name_rule():
    ok = _repo_manifest() + "      distros:\n        rolling:\n          ref: main\n"
    assert "rolling" in parse_manifest_text(ok, "t").repos["core"]["a"].distros
    for bad in ["Jazzy", "a/b", "'#d'", "'a b'"]:
        text = _repo_manifest() + f"      distros:\n        {bad}:\n          ref: main\n"
        with pytest.raises(ManifestError, match="distros: distro name .* is not allowed"):
            parse_manifest_text(text, source="t")


# --- string types --------------------------------------------------------------------------


@pytest.mark.parametrize("value, got", [("1.10", "float"), ("yes", "bool"), ("2024-01-01", "date")])
def test_unquoted_ref_is_refused_with_a_quote_hint(value, got):
    # Reproduced: `ref: 1.10` was written `version: 1.1`, the wrong checkout.
    with pytest.raises(ManifestError, match=rf"repos\.core\.a\.ref must be a string, got {got}"):
        parse_manifest_text(_repo_manifest(ref=value), source="t")
    with pytest.raises(ManifestError, match="quote it in the YAML"):
        parse_manifest_text(_repo_manifest(ref=value), source="t")


def test_quoted_numeric_ref_is_kept_exactly():
    assert parse_manifest_text(_repo_manifest(ref="'1.10'"), "t").repos["core"]["a"].ref == "1.10"


def test_unquoted_per_distro_ref_is_refused():
    text = _repo_manifest() + "      distros:\n        rolling:\n          ref: 3.10\n"
    with pytest.raises(ManifestError, match=r"distros\.rolling\.ref must be a string, got float"):
        parse_manifest_text(text, source="t")


def test_non_string_url_and_type_are_refused():
    with pytest.raises(ManifestError, match=r"repos\.core\.a\.url must be a string, got int"):
        parse_manifest_text(_repo_manifest(url="42"), source="t")
    text = _repo_manifest() + "      type: [git]\n"
    with pytest.raises(ManifestError, match=r"repos\.core\.a\.type must be a string, got list"):
        parse_manifest_text(text, source="t")


@pytest.mark.parametrize("key, value", [("path", "7"), ("url", "true"), ("ref", "1.10")])
def test_non_string_extends_field_is_refused(key, value):
    ext = {"path": "base.yaml", "url": "https://example.com/b.git", "ref": "main"}
    ext[key] = value
    body = "".join(f"  {k}: {v}\n" for k, v in ext.items())
    with pytest.raises(ManifestError, match=rf"extends\.{key} must be a string"):
        parse_manifest_text(f"extends:\n{body}layers: [core]\n", source="t")


# --- control characters --------------------------------------------------------------------


def test_newline_in_a_layer_name_is_refused():
    # Reproduced: `core\nevil` became two lines of layers.txt, each passing the adapter's check.
    with pytest.raises(
        ManifestError, match="key|layers\\[0\\] contains a control or invisible character"
    ):
        parse_manifest_text('layers: ["core\\nevil"]\n', source="t")


def test_newline_in_extends_path_is_refused():
    # Reproduced: a base file named `evil\n- injected.yaml` put a line into layers.txt.
    text = 'extends:\n  path: "evil\\n- injected.yaml"\nlayers: [core]\n'
    with pytest.raises(
        ManifestError, match=r"t: extends\.path contains a control or invisible character"
    ):
        parse_manifest_text(text, source="t")


@pytest.mark.parametrize("char", ["\\n", "\\r", "\\t", "\\0", "\\x7f", "\\u2028", "\\x85"])
def test_control_character_in_any_value_is_refused(char):
    text = _repo_manifest(url=f'"https://example.com/a{char}.git"')
    with pytest.raises(
        ManifestError, match=r"repos\.core\.a\.url contains a control or invisible character"
    ):
        parse_manifest_text(text, source="t")


def test_newline_in_a_repository_name_key_is_refused():
    # Reproduced: a newline in a repository name left the `.repos` header as a YAML key.
    text = (
        'layers: [core]\nrepos:\n  core:\n    "a\\nz: 1":\n'
        "      url: https://example.com/a.git\n      ref: main\n"
    )
    with pytest.raises(ManifestError, match=r"a key under repos\.core contains a control"):
        parse_manifest_text(text, source="t")


def test_control_character_message_does_not_echo_the_value():
    text = _repo_manifest(url=f'"https://u:{SECRET}@example.com/a\\n.git"')
    with pytest.raises(ManifestError) as info:
        parse_manifest_text(text, source="t")
    assert SECRET not in str(info.value)


# --- URLs: an allow-list -------------------------------------------------------------------

ALLOWED_URLS = [
    "https://github.com/rolker/camp.git",  # the p11 fixture's form
    "https://github.com/ros-geographic-info/geographic_info.git",
    "https://git.example.com:8443/group/sub/a.git",
    "https://example.com/a",
    "ssh://git@github.com/rolker/camp.git",
    "ssh://git@example.com:2222/a.git",
    "git@github.com:CCOMJHC/ccomjhc_project11.git",  # in the p11 fixture
    "file:///srv/git/a.git",  # local and test use
]


@pytest.mark.parametrize("url", ALLOWED_URLS)
def test_allowed_url_shape_is_accepted(url):
    assert parse_manifest_text(_repo_manifest(url=url), "t").repos["core"]["a"].url == url


@pytest.mark.parametrize("url", ALLOWED_URLS)
def test_allowed_url_shape_is_accepted_for_extends(url):
    text = f"extends:\n  path: m.yaml\n  url: {url}\n  ref: main\nlayers: [core]\n"
    assert parse_manifest_text(text, "t").extends.url == url


# Credentials in every form either review tried. None fits a shape, so each is refused without
# a credential-specific rule.
CREDENTIAL_URLS = [
    f"https://user:{SECRET}@github.com/rolker/camp.git",
    f"https://{SECRET}@github.com/rolker/camp.git",  # a token as the user name
    f"https://x-access-token:{SECRET}@github.com/rolker/camp.git",
    f"http://user:{SECRET}@example.com/a.git",
    "https://user:@example.com/a.git",
    f"ssh://git:{SECRET}@example.com/a.git",
    f"ssh://{SECRET}%3Ax@example.com/a.git",
    f"user:{SECRET}@example.com:a.git",  # scp-style with a password
    f"user:{SECRET}@example.com/a.git",
    f"https://user:{SECRET}#x@example.com/a.git",
    f"user#x:{SECRET}@example.com:a.git",
    f"https:/user:{SECRET}@example.com/a.git",  # round 2: no `://`
    f"//user:{SECRET}@example.com/a.git",
    f"{SECRET}@example.com/a.git",
    f"user:s3/{SECRET}@host:org/a.git",
    f"https://user%3A{SECRET}@example.com/a.git",  # percent-encoded userinfo
    f"https://user:{SECRET}@[::1]/a.git",  # IPv6 literal
    f"https://user:{SECRET}@example.com\\a.git",  # backslash
    f"HTTPS://user:{SECRET}@example.com/a.git",  # upper-case scheme
    f" https://user:{SECRET}@example.com/a.git",  # leading space
    f"https://user:{SECRET}@x@example.com/a.git",  # double @
    f"https://user:{SECRET}?x@example.com/a.git",
    f"https:{SECRET}@example.com/a.git",
    f"file://{SECRET}@/srv/git/a.git",
    f"https://example.com/a.git?private_token={SECRET}",  # a query
]

# Forms that run a command or are read as a git option, and shapes outside the list.
OTHER_REFUSED_URLS = [
    "--upload-pack=touch PWNED;",  # round 2: ran a command through `vcs import`
    "-https://example.com/a.git",
    "ext::sh -c touch% PWNED",  # git's `<transport>::` form
    "fd::3",
    "https://example.com/a::b",
    "ssh://-oProxyCommand=touch@example.com/a.git",
    "git@-oProxyCommand=touch:a.git",
    "https://-example.com/a.git",
    "https://example.com/-a.git",
    "https://exa mple.com/a.git",
    "https://example.com/a.git#frag",
    "https://example.com",
    "http://example.com/a.git",  # plain http: nothing needs it
    "git://example.com/a.git",
    "ssh://example.com/a.git",  # no user
    "example.com:a.git",  # scp-style with no user
    "/srv/git/a.git",  # a plain local path
    "../a.git",
    "file://relative/a.git",
    "",
]


@pytest.mark.parametrize("url", CREDENTIAL_URLS + OTHER_REFUSED_URLS)
def test_url_outside_the_allow_list_is_refused_without_echoing_it(url):
    with pytest.raises(ManifestError) as info:
        parse_manifest_text(_repo_manifest(url=f"'{url}'"), source="t")
    message = str(info.value)
    assert message.startswith("t: repos.core.a.url is not one of the accepted URL shapes: ")
    assert "https://<host>[:port]/<path>" in message
    assert "credential helper or an ssh remote" in message
    assert SECRET not in message
    if url:
        assert url not in message


@pytest.mark.parametrize("url", CREDENTIAL_URLS + OTHER_REFUSED_URLS)
def test_extends_url_outside_the_allow_list_is_refused(url):
    text = f"extends:\n  path: m.yaml\n  url: '{url}'\n  ref: main\nlayers: [core]\n"
    with pytest.raises(ManifestError, match="t: extends.url is not one of the accepted") as info:
        parse_manifest_text(text, source="t")
    assert SECRET not in str(info.value)


def test_refused_url_never_reaches_output_or_stderr(tmp_path, capsys):
    leaf = tmp_path / "leaf.yaml"
    leaf.write_text(
        f"extends:\n  path: m.yaml\n  url: https://user:{SECRET}@example.com/b.git\n"
        "  ref: main\nlayers: [core]\nroles:\n  dev: {}\n"
    )
    out = tmp_path / "out"
    argv = ["resolve", "--manifest", str(leaf), "--role", "dev", "--distro", "jazzy"]
    rc = main(argv + ["--out", str(out), "--layout", "manifest-dir"])
    captured = capsys.readouterr()
    assert rc == 1
    assert "is not one of the accepted URL shapes" in captured.err
    assert SECRET not in captured.err + captured.out
    assert not out.exists()


def test_every_url_and_ref_in_the_p11_fixture_is_on_the_allow_list(fixtures_dir):
    # The patterns were checked against the real manifest before they were fixed.
    import yaml

    from ros_manifest.schema import _REF, _URL_SHAPES

    raw = yaml.safe_load((fixtures_dir / "p11" / "manifest.yaml").read_text())
    entries = [entry for layer in raw["repos"].values() for entry in layer.values()]
    refs = [e["ref"] for e in entries]
    refs += [d["ref"] for e in entries for d in e.get("distros", {}).values() if "ref" in d]
    for entry in entries:
        assert any(p.fullmatch(entry["url"]) for _, p in _URL_SHAPES), entry["url"]
    for ref in refs:
        assert _REF.fullmatch(ref), ref
    parse_manifest_text((fixtures_dir / "p11" / "manifest.yaml").read_text(), "p11")


# --- refs ----------------------------------------------------------------------------------

ALLOWED_REFS = ["main", "jazzy", "release/2", "v1.0", "'2.0'", "add-santorini-seafloor", "a1b2c3d"]
REFUSED_REFS = [
    "-b",  # round 2: read as an option by `git checkout <version> --`
    "--orphan=x",
    "a..b",
    "main.lock",
    "feature/",
    ".hidden",
    "/x",
    "_x",
    "ext::x",
    "'a b'",
    "'@{-1}'",
    "main~1",
    "'main^'",
    "''",
]


@pytest.mark.parametrize("ref", ALLOWED_REFS)
def test_allowed_ref_is_accepted_in_every_place(ref):
    text = _repo_manifest(ref=ref) + f"      distros:\n        rolling:\n          ref: {ref}\n"
    parse_manifest_text(text, source="t")
    ext = f"extends:\n  path: m.yaml\n  url: https://example.com/b.git\n  ref: {ref}\n"
    parse_manifest_text(ext + "layers: [core]\n", source="t")


@pytest.mark.parametrize("ref", REFUSED_REFS)
def test_refused_ref_in_every_place(ref):
    with pytest.raises(ManifestError, match=r"t: repos\.core\.a\.ref is not an accepted ref"):
        parse_manifest_text(_repo_manifest(ref=ref), source="t")
    text = _repo_manifest() + f"      distros:\n        rolling:\n          ref: {ref}\n"
    with pytest.raises(ManifestError, match=r"distros\.rolling\.ref is not an accepted ref"):
        parse_manifest_text(text, source="t")
    ext = f"extends:\n  path: m.yaml\n  url: https://example.com/b.git\n  ref: {ref}\n"
    with pytest.raises(ManifestError, match=r"t: extends\.ref is not an accepted ref"):
        parse_manifest_text(ext + "layers: [core]\n", source="t")


def test_option_like_url_and_ref_never_reach_the_repos_file(tmp_path, capsys):
    # Round 2's reproduction: the url was written into repos/core.repos and `vcs import` ran it.
    leaf = tmp_path / "leaf.yaml"
    leaf.write_text(
        "layers: [core]\nrepos:\n  core:\n    a:\n"
        f"      url: '--upload-pack=touch {tmp_path}/PWNED;'\n      ref: main\n"
        "roles:\n  dev: {}\n"
    )
    out = tmp_path / "out"
    argv = ["resolve", "--manifest", str(leaf), "--role", "dev", "--distro", "jazzy"]
    assert main(argv + ["--out", str(out), "--layout", "manifest-dir"]) == 1
    assert not out.exists()


# --- YAML loading --------------------------------------------------------------------------


def test_invalid_yaml_is_a_fixed_message_with_position_only():
    text = f"layers: [core]\nrepos: !https://u:{SECRET}@host/a {{}}\n"
    with pytest.raises(ManifestError) as info:
        parse_manifest_text(text, source="t")
    assert str(info.value) == "t: invalid YAML at line 2, column 8"


# Round 3: PyYAML's constructor raises ValueError or KeyError, not a YAMLError, for these, and
# both the exception's text and its traceback quote the value.
CONSTRUCTOR_FAILURES = [f"!!float {SECRET}", f"!!int 0x{SECRET}", f"!!bool {SECRET}", "2024-13-45"]


@pytest.mark.parametrize("value", CONSTRUCTOR_FAILURES)
def test_a_value_yaml_cannot_construct_is_a_fixed_message(value, tmp_path, capsys):
    text = f"layers: [core]\nroles:\n  dev: {{}}\nx: {value}\n"
    shown = value.split()[-1]
    with pytest.raises(ManifestError) as info:
        parse_manifest_text(text, source="t")
    assert str(info.value) == "t: invalid YAML"
    leaf = tmp_path / "leaf.yaml"
    leaf.write_text(text)
    rc = main(["validate", "--manifest", str(leaf), "--role", "dev", "--distro", "jazzy"])
    captured = capsys.readouterr()
    assert rc == 1
    assert captured.err == f"ERROR: {leaf}: invalid YAML\n"
    assert shown not in captured.err + captured.out
    assert "Traceback" not in captured.err


def _cli_validate(tmp_path, text):
    leaf = tmp_path / "leaf.yaml"
    leaf.write_text(text)
    rc = main(["validate", "--manifest", str(leaf), "--role", "dev", "--distro", "jazzy"])
    return rc, leaf


# Round 4: PyYAML builds a hex integer of any length; turning one past Python's 4300-digit limit
# into text later (a repr, a key path) raised ValueError as a traceback.
HUGE_INT = "0x" + "f" * 4000


@pytest.mark.parametrize(
    "body, line, column",
    [
        (f"groups:\n  g:\n    default: {HUGE_INT}\n", 4, 14),
        (
            f"repos:\n  core:\n    ? {HUGE_INT}\n    : {{url: https://e.com/a.git, ref: main}}\n",
            4,
            7,
        ),
        (f"packages:\n  ? {HUGE_INT}\n  : {{repo: a}}\n", 3, 5),
    ],
)
def test_an_integer_too_large_is_refused_with_its_position(body, line, column, tmp_path, capsys):
    rc, leaf = _cli_validate(tmp_path, "layers: [core]\n" + body)
    captured = capsys.readouterr()
    assert rc == 1
    assert captured.err == (
        f"ERROR: {leaf}: invalid YAML at line {line}, column {column}: a number too large\n"
    )


def test_the_integer_bound_is_64_bits():
    text = "layers: [core]\ngroups:\n  g:\n    default: 0x{}\n"
    with pytest.raises(ManifestError, match="got int$"):
        parse_manifest_text(text.format("f" * 16), source="t")
    with pytest.raises(ManifestError, match="a number too large$"):
        parse_manifest_text(text.format("1" + "0" * 16), source="t")


def test_a_bad_group_default_is_named_by_type_only():
    for value, got in [(f"'https://u:{SECRET}@h'", "another string"), ("1", "int")]:
        text = f"layers: [core]\ngroups:\n  g:\n    default: {value}\n"
        with pytest.raises(ManifestError) as info:
            parse_manifest_text(text, source="t")
        assert str(info.value) == (
            f"t: groups.g: 'default' must be 'include' or 'exclude', got {got}"
        )


# The same class, found while there: values the schema let through that later raised a
# TypeError (sorting keys of mixed types; a list used as a dict key) and printed a traceback.
@pytest.mark.parametrize(
    "body, message",
    [
        (
            "repos:\n  core:\n    a:\n      url: https://e.com/a.git\n      ref: main\n"
            "      1: x\n      zz: y\n",
            "repos.core.a: unknown key(s) ['zz', 1]",
        ),
        ("groups:\n  g:\n    default: include\n    1: x\n    zz: y\n", "unknown key(s) ['zz', 1]"),
        ("roles:\n  r:\n    1: x\n    zz: y\n", "roles.r: unknown key(s) ['zz', 1]"),
        ("packages:\n  p:\n    repo: a\n    1: x\n    zz: y\n", "unknown key(s) ['zz', 1]"),
        ("packages:\n  p:\n    repo: [a]\n", "packages.p.repo must be a string"),
        ("packages:\n  p:\n    repo: {a: 1}\n", "packages.p.repo must be a string"),
    ],
)
def test_a_value_of_the_wrong_type_is_a_message_not_a_traceback(body, message, tmp_path, capsys):
    rc, _ = _cli_validate(tmp_path, "layers: [core]\n" + body)
    captured = capsys.readouterr()
    assert rc == 1
    assert message in captured.err
    assert "Traceback" not in captured.err


# And the file system: reading the file and following `extends` raised UnicodeDecodeError,
# PermissionError, OSError (a name too long, quoting the manifest's extends path) and, before
# Python 3.13, RuntimeError (a symlink loop), each a traceback.
def _cli_error(leaf, capsys):
    rc = main(["validate", "--manifest", str(leaf), "--role", "dev", "--distro", "jazzy"])
    captured = capsys.readouterr()
    assert rc == 1
    assert "Traceback" not in captured.err
    return captured.err + captured.out


def test_a_manifest_that_is_not_text_is_a_message(tmp_path, capsys):
    leaf = tmp_path / "leaf.yaml"
    leaf.write_bytes(b"layers: [core]\nx: \xff" + SECRET.encode() + b"\n")
    out = _cli_error(leaf, capsys)
    assert out == f"ERROR: {leaf}: cannot be read as text\n"


def test_an_unreadable_manifest_is_a_message(tmp_path, capsys):
    import os

    if os.geteuid() == 0:
        pytest.skip("root reads any file")
    leaf = tmp_path / "leaf.yaml"
    leaf.write_text("layers: [core]\n")
    leaf.chmod(0)
    try:
        assert _cli_error(leaf, capsys) == f"ERROR: {leaf}: cannot be read (Permission denied)\n"
    finally:
        leaf.chmod(0o600)


@pytest.mark.parametrize("ext_path", [SECRET + "a" * 5000, (SECRET + "a" * 300 + "/") * 2 + "m"])
def test_an_extends_path_too_long_is_a_message_without_the_path(ext_path, tmp_path, capsys):
    leaf = tmp_path / "leaf.yaml"
    leaf.write_text(f"extends:\n  path: {ext_path}\nlayers: [core]\n")
    out = _cli_error(leaf, capsys)
    assert out == f"ERROR: {leaf}: its extends cannot be followed (File name too long)\n"
    assert SECRET not in out


def test_a_symlink_loop_is_a_message(tmp_path, capsys):
    (tmp_path / "l1").symlink_to(tmp_path / "l2")
    (tmp_path / "l2").symlink_to(tmp_path / "l1")
    leaf = tmp_path / "leaf.yaml"
    leaf.write_text("extends:\n  path: l1\nlayers: [core]\n")
    # Which message depends on the Python version (3.13's resolve() no longer raises); either
    # way it is one ERROR line.
    for manifest in (leaf, tmp_path / "l1"):
        out = _cli_error(manifest, capsys)
        assert out.startswith("ERROR: ") and out.count("\n") == 1


def test_aliases_are_refused():
    with pytest.raises(ManifestError, match="line 1, column 19: aliases .* are not allowed"):
        parse_manifest_text("layers: &a [core, *a]\n", source="t")  # was a RecursionError
    bomb = "a: &a [x, x, x, x, x, x, x, x, x, x]\n" + "".join(
        f"{chr(98 + i)}: &{chr(98 + i)} [{', '.join(['*' + chr(97 + i)] * 10)}]\n" for i in range(8)
    )
    with pytest.raises(ManifestError, match="aliases .* are not allowed"):
        parse_manifest_text(bomb + "layers: [core]\n", source="t")  # was a hang
    assert parse_manifest_text("layers: &a [core]\n", source="t").layers == ["core"]


def test_deep_nesting_is_an_error_not_a_crash():
    with pytest.raises(ManifestError, match="t: invalid YAML"):
        parse_manifest_text("layers: " + "[" * 5000 + "]" * 5000 + "\n", source="t")


def test_duplicate_keys_are_refused():
    with pytest.raises(ManifestError, match="line 2, column 1: a mapping repeats a key"):
        parse_manifest_text("layers: [core]\nlayers: [site]\n", source="t")
    text = _repo_manifest() + "      ref: other\n"
    with pytest.raises(ManifestError, match="a mapping repeats a key"):
        parse_manifest_text(text, source="t")


def test_absent_must_be_a_boolean():
    for value in ["'no'", "'yes'", "1", "'true'"]:
        text = _repo_manifest() + f"      distros:\n        rolling:\n          absent: {value}\n"
        with pytest.raises(ManifestError, match=r"distros\.rolling\.absent must be true or false"):
            parse_manifest_text(text, source="t")
    text = _repo_manifest() + "      distros:\n        rolling:\n          absent: true\n"
    assert parse_manifest_text(text, "t").repos["core"]["a"].distros == {
        "rolling": {"absent": True}
    }


# --- names: length and case ----------------------------------------------------------------


def test_name_length_is_capped():
    assert parse_manifest_text(f"layers: [{'a' * 64}]\n", "t").layers == ["a" * 64]
    with pytest.raises(ManifestError, match=r"layer name \(too long\) .* at most 64") as info:
        parse_manifest_text(f"layers: [{'a' * 300}]\n", source="t")  # was an OSError mid-write
    assert "a" * 65 not in str(info.value)


def test_names_differing_only_in_case_are_refused():
    with pytest.raises(ManifestError, match="layer names 'core' and 'Core' differ only in case"):
        parse_manifest_text("layers: [core, Core]\n", source="t")
    text = (
        "layers: [core, site]\nrepos:\n  core:\n    a: {url: 'https://e.com/a', ref: main}\n"
        "  site:\n    A: {url: 'https://e.com/b', ref: main}\n"
    )
    with pytest.raises(ManifestError, match="repository names 'a' and 'A' differ only in case"):
        parse_manifest_text(text, source="t")
    with pytest.raises(ManifestError, match="group names"):
        parse_manifest_text(
            "layers: [c]\ngroups:\n  g: {default: include}\n  G: {default: include}\n", "t"
        )
    with pytest.raises(ManifestError, match="role names"):
        parse_manifest_text("layers: [c]\nroles:\n  dev: {}\n  Dev: {}\n", source="t")


def test_names_differing_only_in_case_are_refused_across_the_chain(tmp_path):
    from ros_manifest.extends import resolve_chain
    from ros_manifest.merge import merge_chain

    (tmp_path / "base.yaml").write_text("layers: [core]\n")
    (tmp_path / "leaf.yaml").write_text("extends:\n  path: base.yaml\nlayers: [Core]\n")
    chain = resolve_chain(tmp_path / "leaf.yaml")
    with pytest.raises(ManifestError, match="composed extends chain: layer names 'core' and"):
        merge_chain(chain)


# --- invisible and bidirectional characters ------------------------------------------------


@pytest.mark.parametrize("char", ["\\u202e", "\\u200b", "\\u00a0", "\\ufeff", "\\u2066"])
def test_invisible_or_bidirectional_character_is_refused(char):
    text = _repo_manifest() + f'      type: "git{char}"\n'
    with pytest.raises(
        ManifestError, match=r"repos\.core\.a\.type contains a control or invisible"
    ):
        parse_manifest_text(text, source="t")


# --- the emitter's second line -------------------------------------------------------------
#
# These build output from a merged manifest whose names or labels did not come through the
# parser (or, for the symlink, came through it clean), to show the emitter refuses on its own.

_VALID = _repo_manifest() + "roles:\n  dev: {}\n"


def _merged(layer: str = "core", source: str = "t"):
    from ros_manifest.merge import merge_chain

    merged = merge_chain([parse_manifest_text(_VALID, source=source)])
    merged.layers = [layer]
    merged.layer_repos = {layer: merged.layer_repos["core"]}
    return merged


def _emit(merged, out, layout, distro="jazzy"):
    from ros_manifest.emit import emit_manifest
    from ros_manifest.selectors import select_repos

    return emit_manifest(merged, select_repos(merged, "dev"), "dev", distro, out, layout=layout)


def _all_files(root):
    return sorted(p.relative_to(root).as_posix() for p in root.rglob("*") if p.is_file())


@pytest.mark.parametrize("layout", ["flat", "manifest-dir"])
@pytest.mark.parametrize("layer", ["../../escaped", "ABSOLUTE"])
def test_emitter_refuses_a_path_outside_out(tmp_path, layout, layer):
    # Reproduced: `../../escaped` wrote two directories above --out in both layouts (the flat
    # layout on main too); an absolute name wrote anywhere.
    if layer == "ABSOLUTE":
        layer = str(tmp_path / "pwned")
    out = tmp_path / "a" / "b" / "out"
    with pytest.raises(ManifestError, match="is outside the output directory"):
        _emit(_merged(layer), out, layout)
    assert _all_files(tmp_path) == []


@pytest.mark.parametrize("layout", ["flat", "manifest-dir"])
def test_emitter_refuses_a_symlink_that_leads_outside_out(tmp_path, layout):
    out = tmp_path / "out"
    repos_dir = out / "repos" if layout == "manifest-dir" else out
    repos_dir.mkdir(parents=True)
    (repos_dir / "core.repos").symlink_to(tmp_path / "victim")
    with pytest.raises(ManifestError, match="is outside the output directory"):
        _emit(_merged(), out, layout)
    assert not (tmp_path / "victim").exists()


@pytest.mark.parametrize("layout", ["flat", "manifest-dir"])
def test_emitter_refuses_a_header_value_that_would_split_a_line(tmp_path, layout):
    out = tmp_path / "out"
    with pytest.raises(ManifestError, match="contains a control or invisible character"):
        _emit(_merged(source="base\n- injected"), out, layout)
    assert _all_files(tmp_path) == []
    with pytest.raises(ManifestError, match="contains a control or invisible character"):
        _emit(_merged(), out, layout, distro="jazzy\nevil")
    assert _all_files(tmp_path) == []


def test_emitter_refuses_a_layer_line_that_would_split(tmp_path):
    # `core\nevil` would be two entries of layers.txt, each passing the adapter's line check.
    with pytest.raises(ManifestError):
        _emit(_merged("core\nevil"), tmp_path / "out", "manifest-dir")
    assert _all_files(tmp_path) == []


def _git(cwd, *args):
    import subprocess

    subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True)


def test_base_reached_through_a_symlink_with_a_newline_in_its_name(tmp_path, capsys):
    # The parser sees `extends.path: manifest.yaml`, which is clean; in the base repository it
    # is a symlink to a file named `evil\n- injected.yaml`, so the provenance label, built from
    # the resolved path, holds a newline. The emitter refuses it; nothing is written.
    import shutil

    if shutil.which("git") is None:
        pytest.skip("git not available")
    remote = tmp_path / "base_repo"
    remote.mkdir()
    _git(remote, "init", "-q", "-b", "main")
    (remote / "evil\n- injected.yaml").write_text(_VALID.replace("core", "underlay"))
    (remote / "manifest.yaml").symlink_to("evil\n- injected.yaml")
    _git(remote, "add", "-A")
    _git(remote, "-c", "user.email=t@example.com", "-c", "user.name=t", "commit", "-q", "-m", "x")
    leaf = tmp_path / "leaf.yaml"
    leaf.write_text(
        f"extends:\n  path: manifest.yaml\n  url: {remote.as_uri()}\n  ref: main\n"
        "layers: [core]\noptional_layers: [core]\n"
    )
    out = tmp_path / "out"
    argv = ["resolve", "--manifest", str(leaf), "--role", "dev", "--distro", "jazzy"]
    rc = main(
        argv + ["--out", str(out), "--layout", "manifest-dir", "--cache-dir", str(tmp_path / "c")]
    )
    assert rc == 1
    err = capsys.readouterr().err
    assert "refusing to write the header of the 'underlay' .repos file" in err
    assert "contains a control or invisible character" in err
    assert not out.exists() or _all_files(out) == []
