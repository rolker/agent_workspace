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
    text = f"layers: [core]\nrepos:\n  core:\n    {name}:\n      url: u\n      ref: main\n"
    with pytest.raises(ManifestError, match=r"t: repos\.core: repository name .* is not allowed"):
        parse_manifest_text(text, source="t")


@pytest.mark.parametrize("name", ["ros2sonic", "geographic_info", "rviz.plugins", "a-b", "_x"])
def test_good_repository_name_is_accepted(name):
    text = f"layers: [core]\nrepos:\n  core:\n    {name}:\n      url: u\n      ref: main\n"
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
    with pytest.raises(ManifestError, match="key|layers\\[0\\] contains a control character"):
        parse_manifest_text('layers: ["core\\nevil"]\n', source="t")


def test_newline_in_extends_path_is_refused():
    # Reproduced: a base file named `evil\n- injected.yaml` put a line into layers.txt.
    text = 'extends:\n  path: "evil\\n- injected.yaml"\nlayers: [core]\n'
    with pytest.raises(ManifestError, match=r"t: extends\.path contains a control character"):
        parse_manifest_text(text, source="t")


@pytest.mark.parametrize("char", ["\\n", "\\r", "\\t", "\\0", "\\x7f", "\\u2028", "\\x85"])
def test_control_character_in_any_value_is_refused(char):
    text = _repo_manifest(url=f'"https://example.com/a{char}.git"')
    with pytest.raises(ManifestError, match=r"repos\.core\.a\.url contains a control character"):
        parse_manifest_text(text, source="t")


def test_newline_in_a_repository_name_key_is_refused():
    # Reproduced: a newline in a repository name left the `.repos` header as a YAML key.
    text = 'layers: [core]\nrepos:\n  core:\n    "a\\nz: 1":\n      url: u\n      ref: main\n'
    with pytest.raises(ManifestError, match=r"a key under repos\.core contains a control"):
        parse_manifest_text(text, source="t")


def test_control_character_message_does_not_echo_the_value():
    text = _repo_manifest(url=f'"https://u:{SECRET}@example.com/a\\n.git"')
    with pytest.raises(ManifestError) as info:
        parse_manifest_text(text, source="t")
    assert SECRET not in str(info.value)


# --- credentials in URLs -------------------------------------------------------------------


@pytest.mark.parametrize(
    "url",
    [
        "https://github.com/rolker/camp.git",
        "http://example.com/a.git",
        "file:///srv/git/a.git",
        "/srv/git/a.git",
        "../a.git",
        "git://example.com/a.git",
        "ssh://git@github.com/rolker/camp.git",
        "ssh://git@example.com:2222/a.git",
        "ssh://example.com/a.git",
        "git+ssh://git@example.com/a.git",
        "git@github.com:CCOMJHC/ccomjhc_project11.git",  # in the p11 fixture
        "example.com:a.git",
    ],
)
def test_url_without_secret_is_accepted(url):
    assert parse_manifest_text(_repo_manifest(url=url), "t").repos["core"]["a"].url == url


@pytest.mark.parametrize(
    "url",
    [
        f"https://user:{SECRET}@github.com/rolker/camp.git",
        f"https://{SECRET}@github.com/rolker/camp.git",  # a token as the user name
        f"https://x-access-token:{SECRET}@github.com/rolker/camp.git",
        f"http://user:{SECRET}@example.com/a.git",
        "https://user:@example.com/a.git",
        f"ssh://git:{SECRET}@example.com/a.git",
        f"ssh://{SECRET}%3Ax@example.com/a.git",
        f"user:{SECRET}@example.com:a.git",  # scp-style with a password
        f"user:{SECRET}@example.com/a.git",
        f"https://user:{SECRET}#x@example.com/a.git",  # `#` hides the rest from urlsplit
        f"user#x:{SECRET}@example.com:a.git",
        f"-https://user:{SECRET}@example.com/a.git",
    ],
)
def test_url_with_credentials_is_refused_without_echoing_it(url):
    with pytest.raises(ManifestError) as info:
        parse_manifest_text(_repo_manifest(url=f"'{url}'"), source="t")
    message = str(info.value)
    assert message.startswith("t: repos.core.a.url")
    assert SECRET not in message
    assert url not in message


def test_extends_url_with_credentials_is_refused():
    text = (
        f"extends:\n  path: m.yaml\n  url: https://user:{SECRET}@example.com/b.git\n"
        "  ref: main\nlayers: [core]\n"
    )
    with pytest.raises(ManifestError, match="t: extends.url: credentials do not belong") as info:
        parse_manifest_text(text, source="t")
    assert SECRET not in str(info.value)


def test_credentialed_url_never_reaches_output_or_stderr(tmp_path, capsys):
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
    assert "credentials do not belong in a manifest" in captured.err
    assert SECRET not in captured.err + captured.out
    assert not out.exists()


def test_invalid_yaml_message_does_not_quote_the_document():
    text = f"layers: [core]\nrepos:\n  core:\n    a: {{url: https://u:{SECRET}@h/a.git, ref: [}}\n"
    with pytest.raises(ManifestError, match=r"t: invalid YAML at line \d+, column \d+") as info:
        parse_manifest_text(text, source="t")
    assert SECRET not in str(info.value)
