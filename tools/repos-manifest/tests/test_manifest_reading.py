"""Reading one manifest in the format of docs/spec.md: keys, types, names, and the checks of
"Reading a manifest before using it"."""

import re
import textwrap

import pytest

from repos_manifest.manifest import load_manifest, parse_manifest
from repos_manifest.yamlload import ManifestError, has_unsafe_char

REPO = "    type: git\n    url: https://example.org/a.git\n"


def _m(text):
    return parse_manifest(textwrap.dedent(text), "m.yaml")


def _refused(text, match):
    with pytest.raises(ManifestError, match=match):
        _m(text)


def _one_repo(extra="", top=""):
    return top + "repositories:\n  a:\n" + REPO + extra


# --- What a manifest is ----------------------------------------------------------------------


def test_a_plain_repos_file_is_a_manifest():
    m = _m(
        """\
        repositories:
          a:
            type: git
            url: https://example.org/a.git
            version: main
          b:
            type: git
            url: https://example.org/b.git
        """
    )
    assert list(m.repositories) == ["a", "b"]
    assert m.repositories["a"].version == "main"
    assert m.repositories["b"].version is None
    assert m.distros is None and m.roles is None and m.layers == [] and m.groups == []


# --- Top-level keys --------------------------------------------------------------------------


def test_repositories_is_required():
    _refused("layers: [a]\n", "has no `repositories:`")


def test_format_absent_is_1_and_1_is_read():
    assert _m(_one_repo()).format == 1
    assert _m(_one_repo(top="format: 1\n")).format == 1


def test_a_higher_format_is_refused():
    _refused(_one_repo(top="format: 2\n"), "format: is 2; this tool reads format 1")


@pytest.mark.parametrize("value", ["'1'", "1.0", "true", "0"])
def test_a_format_that_is_not_a_whole_number_from_1_is_refused(value):
    _refused(_one_repo(top=f"format: {value}\n"), "format: must be a whole number")


def test_an_unknown_top_level_key_is_warned_about_and_ignored():
    m = _m(_one_repo(top="colour: blue\n"))
    assert m.warnings == ["m.yaml: unknown top-level key 'colour' is ignored"]


def test_base_is_refused_for_now():
    _refused(_one_repo(top="base: other.yaml\n"), "base: this version of the tool cannot read")


@pytest.mark.parametrize("value", ["[]", "{}", "a.yaml"])
def test_repositories_must_be_a_mapping(value):
    if value == "{}":
        assert _m("repositories: {}\n").repositories == {}
    else:
        _refused(f"repositories: {value}\n", "repositories: must be a mapping")


# --- Repos -----------------------------------------------------------------------------------


def test_a_repo_key_may_be_a_path():
    m = _m("repositories:\n  drivers/sonar/x:\n" + REPO)
    assert list(m.repositories) == ["drivers/sonar/x"]


@pytest.mark.parametrize(
    "key", ["a//b", "a/./b", "./a", "a/", "/a", "'a\\b'", "a/../b", "..", "x/.git"]
)
def test_an_odd_repo_key_is_refused(key):
    _refused(f"repositories:\n  {key}:\n" + REPO, "a repo key")


@pytest.mark.parametrize("key", ["'#a'", "'#'", "'#a/b'"])
def test_a_repo_key_that_starts_with_a_hash_is_refused(key):
    # optional.txt lists repo keys, one per line, and its readers skip lines starting with '#'.
    _refused(f"repositories:\n  {key}:\n{REPO}", "a repo key does not start with '#'")


def test_a_hash_later_in_a_repo_key_is_accepted():
    assert list(_m(f"repositories:\n  a#b:\n{REPO}").repositories) == ["a#b"]


def test_a_repo_key_that_is_not_a_string_is_refused():
    _refused("repositories:\n  12:\n" + REPO, "a repo key must be a path")


def test_no_key_is_another_key_followed_by_a_slash():
    text = "repositories:\n  a:\n" + REPO + "  a/b:\n" + REPO
    _refused(text, "'a/b'.*is inside repo 'a'")


def test_a_key_that_only_starts_like_another_is_not_inside_it():
    m = _m("repositories:\n  a:\n" + REPO + "  ab/c:\n" + REPO)
    assert list(m.repositories) == ["a", "ab/c"]


def test_a_repeated_repo_key_is_refused():
    _refused("repositories:\n  a:\n" + REPO + "  a:\n" + REPO, "repeats a key")


@pytest.mark.parametrize("missing", ["type", "url"])
def test_type_and_url_are_required(missing):
    entry = {"type": "    type: git\n", "url": "    url: https://example.org/a.git\n"}
    del entry[missing]
    _refused("repositories:\n  a:\n" + "".join(entry.values()), f"has no `{missing}`")


def test_a_repo_entry_must_be_a_mapping():
    _refused("repositories:\n  a:\n", "repositories.a: must be a mapping")


def test_a_type_other_than_git_is_refused():
    text = "repositories:\n  a:\n    type: hg\n    url: https://example.org/a\n"
    _refused(text, "type: is 'hg'; the format takes any type a .repos file takes, and these")


@pytest.mark.parametrize("key,value", [("version", "1.10"), ("url", "12"), ("type", "true")])
def test_url_type_and_version_are_strings(key, value):
    entry = {"type": "git", "url": "https://example.org/a.git", key: value}
    text = "repositories:\n  a:\n" + "".join(f"    {k}: {v}\n" for k, v in entry.items())
    _refused(text, f"repositories.a.{key}: must be a string")


def test_a_quoted_version_is_a_string():
    assert _m(_one_repo("    version: '1.10'\n")).repositories["a"].version == "1.10"


@pytest.mark.parametrize("key", ["absent", "optional"])
def test_absent_and_optional_are_booleans(key):
    _refused(_one_repo(f"    {key}: 'yes'\n"), f"repositories.a.{key}: must be true or false")


def test_absent_and_optional_are_false_if_left_out():
    repo = _m(_one_repo()).repositories["a"]
    assert repo.absent is False and repo.optional is False


def test_an_unknown_repo_key_is_warned_about():
    m = _m(_one_repo("    colour: blue\n"))
    assert m.warnings == [
        "m.yaml: repositories.a: unknown key 'colour' is ignored and left out of the output"
    ]


def test_an_unknown_key_in_a_distro_entry_is_warned_about():
    extra = "    distros:\n      jazzy:\n        version: j\n        colour: blue\n"
    m = _m(_one_repo(extra, top="distros: [jazzy]\n"))
    assert m.warnings == ["m.yaml: repositories.a.distros.jazzy: unknown key 'colour' is ignored"]
    assert m.repositories["a"].distros["jazzy"].version == "j"


def test_an_empty_distro_entry_is_an_entry():
    m = _m(_one_repo("    absent: true\n    distros:\n      jazzy:\n", top="distros: [jazzy]\n"))
    entry = m.repositories["a"].distros["jazzy"]
    assert entry.version is None and entry.absent is False


def test_a_distro_entry_must_be_a_mapping():
    text = _one_repo("    distros:\n      jazzy: main\n", top="distros: [jazzy]\n")
    _refused(text, "distros.jazzy: must be a mapping")


def test_a_distro_entry_with_a_version_and_absent_true_is_refused():
    extra = "    distros:\n      jazzy:\n        version: x\n        absent: true\n"
    _refused(_one_repo(extra, top="distros: [jazzy]\n"), "both a `version` and `absent: true`")


def test_a_distro_entry_version_is_a_string():
    extra = "    distros:\n      jazzy:\n        version: 2\n"
    _refused(_one_repo(extra, top="distros: [jazzy]\n"), "distros.jazzy.version: must be a str")


# --- Distros ---------------------------------------------------------------------------------


def test_without_distros_no_repo_may_have_a_distros_key():
    _refused(_one_repo("    distros:\n      jazzy: {}\n"), "has no top-level `distros:` list")


def test_an_empty_distros_list_is_refused():
    _refused(_one_repo(top="distros: []\n"), "distros: is empty")


def test_a_distro_entry_outside_the_list_is_kept_but_never_used():
    # (It is ignored when resolving: see test_selection.py.)
    m = _m(_one_repo("    distros:\n      humble: {version: h}\n", top="distros: [jazzy]\n"))
    assert "humble" in m.repositories["a"].distros


# --- Layers ----------------------------------------------------------------------------------


def test_a_repo_with_no_layer_is_in_the_unnamed_layer():
    assert _m(_one_repo(top="layers: [core]\n")).repositories["a"].layer is None


def test_a_layer_not_in_the_list_is_an_error():
    _refused(_one_repo("    layer: ui\n", top="layers: [core]\n"), "'ui' is not in the top")


def test_a_layer_without_a_layers_list_is_an_error():
    _refused(_one_repo("    layer: core\n"), "'core' is not in the top-level `layers:` list")


@pytest.mark.parametrize("name", ["src", "build", "install", "log"])
def test_a_layer_cannot_have_a_reserved_name(name):
    _refused(_one_repo(top=f"layers: [{name}]\n"), f"a layer cannot be named '{name}'")


@pytest.mark.parametrize("name", ["Src", "BUILD", "Install", "lOg"])
def test_a_reserved_layer_name_is_compared_without_case(name):
    _refused(_one_repo(top=f"layers: [{name}]\n"), f"a layer cannot be named '{name}'")


def test_layer_names_that_differ_only_in_case_are_refused():
    _refused(
        _one_repo(top="layers: [core, Core]\n"), "layers 'core' and 'Core' differ only in case"
    )


def test_a_layer_named_twice_is_refused():
    _refused(_one_repo(top="layers: [core, core]\n"), "names layer 'core' twice")


# --- Groups and roles ------------------------------------------------------------------------


def test_an_undeclared_group_on_a_repo_is_an_error():
    _refused(_one_repo("    groups: [sim]\n", top="groups: [ui]\n"), "group 'sim' is not in")


def test_an_undeclared_group_in_a_role_is_an_error():
    _refused(_one_repo(top="groups: [ui]\nroles:\n  dev: [sim]\n"), "roles.dev.*'sim' is not in")


def test_a_role_given_as_a_string_is_refused():
    _refused(_one_repo(top="groups: [ui]\nroles:\n  dev: ui\n"), "roles.dev: must be a list")


def test_a_role_with_nothing_is_refused():
    _refused(_one_repo(top="roles:\n  robot:\n"), r"roles.robot: must be a list .*\[\] for none")


def test_groups_on_a_repo_given_as_a_string_is_refused():
    _refused(_one_repo("    groups: ui\n", top="groups: [ui]\n"), "groups: must be a list")


def test_an_empty_roles_mapping_is_refused():
    _refused(_one_repo(top="roles: {}\n"), "roles: is empty; leave it out for a manifest with no")


def test_roles_must_be_a_mapping():
    _refused(_one_repo(top="roles: [robot]\n"), "roles: must be a mapping")


# --- Reading a manifest before using it ------------------------------------------------------


def test_the_file_is_loaded_as_data():
    _refused("repositories: !!python/object:os.system {}\n", "invalid YAML")


@pytest.mark.parametrize(
    "top",
    [
        "layers: [Core.x]\n",
        "layers: [1core]\n",
        "distros: [jaz zy]\n",
        "groups: [hw:deltat]\n",
        "groups: [_x]\n",
        "roles:\n  -dev: []\n",
    ],
)
def test_a_name_that_is_not_a_single_word_is_refused(top):
    _refused(_one_repo(top=top), "name .* is not allowed; a name is a single word")


def test_names_with_capitals_digits_underscores_and_dashes_are_allowed():
    top = "layers: [Core_2]\ngroups: [ben-hw]\nroles:\n  R-1: [ben-hw]\ndistros: [Jazzy]\n"
    m = _m(_one_repo(top=top))
    assert m.layers == ["Core_2"] and m.roles == {"R-1": ["ben-hw"]}


@pytest.mark.parametrize("line", ["    url: -oProxyCommand=x\n", "    version: --upload-pack=x\n"])
def test_a_url_or_version_starting_with_a_dash_is_refused(line):
    entry = {"type": "    type: git\n", "url": "    url: https://example.org/a.git\n"}
    key = line.split(":")[0].strip()
    entry[key] = line
    _refused("repositories:\n  a:\n" + "".join(entry.values()), "starts with '-'")


def test_a_distro_version_starting_with_a_dash_is_refused():
    extra = "    distros:\n      jazzy:\n        version: -x\n"
    _refused(_one_repo(extra, top="distros: [jazzy]\n"), "starts with '-'")


@pytest.mark.parametrize(
    "url",
    [
        "https://example.org/a.git",
        "http://example.org/a.git",
        "ssh://git@example.org/a.git",
        "file:///srv/git/a.git",
        "git@github.com:example/a.git",
        "/srv/git/a.git",
        # An '@' after the host is part of the path, not a user.
        "https://example.org/repo@-v1.git",
        "ssh://git@example.org/a@-b.git",
        # IPv6 hosts: their '::' is not the <transport>::<address> form.
        "ssh://user@[::1]/repo",
        "ssh://[::1]:22/repo",
        "https://[2001:db8::1]/a.git",
        "git@[::1]:repo",
        "ssh://git@example.org:22/a.git",
        # The scp form with no user: an ssh host alias.
        "example.org:a.git",
        "myrobot:repos/a.git",
        "[::1]:a.git",
        "[git@example.org:22]:a.git",
        # A '?' or '#' in the path is the path's business; so are a '%', a '[' and a ']' in
        # the path of a url not handed to ssh.
        "https://example.org/a%20b.git",
        "https://example.org/a%20b/repo@-v1.git",
        "https://h/x@[y",
        "file:///abs/p%20q",
        "https://example.org/a.git?x=1#y",
        "ssh://git@example.org/a?b@-c#d.git",
        "git@example.org:a?c#d.git",
        "ssh://git@host:2222/owner/repo.git",
        "host:path",
        "[::1]:repo",
    ],
)
def test_the_transports_that_only_fetch_are_accepted(url):
    assert (
        _m(f"repositories:\n  a:\n    type: git\n    url: '{url}'\n").repositories["a"].url == url
    )


@pytest.mark.parametrize(
    "url,match",
    [
        ("ftp://example.org/a.git", "is refused"),
        ("git://example.org/a.git", "is refused"),
        ("ext::sh -c touch% /tmp/x", "<transport>::<address> form is refused"),
        ("fd::17", "<transport>::<address> form is refused"),
        ("https::example.org/a.git", "<transport>::<address> form is refused"),
        ("relative/path.git", "is refused"),
        # A relative path on the local disk is not the scp form, even with a ':' after a '/'.
        ("./a:b", "is refused"),
        ("dir/a:b", "is refused"),
        ("a.git", "is refused"),
        (":a.git", "is refused"),
        ("host::a.git", "<transport>::<address> form is refused"),
        ("[-oProxyCommand=x]:p", "the host starts with '-'"),
        ("ssh://-oProxyCommand=x/a", "the host starts with '-'"),
        ("git@-oProxyCommand=x:a", "the host starts with '-'"),
        # The host is what follows the last '@' of the part before the first '/', brackets
        # taken off.
        ("ssh://a@b@-oProxyCommand=x/p", "the host starts with '-'"),
        ("ssh://[-oProxyCommand=x]/p", "the host starts with '-'"),
        ("https://[-oProxyCommand=x]:443/p", "the host starts with '-'"),
        ("git@[-oProxyCommand=x]:p", "the host starts with '-'"),
        ("a@b@-oProxyCommand=x:p", "the host starts with '-'"),
        ("ssh://[::1/p", "in an ssh address, '\\[' and '\\]' are allowed only around the host"),
        ("ssh://[::1]x/p", "is refused"),
        # A user or a port that starts with '-'.
        ("ssh://-oProxyCommand=x@host/p", "the user starts with '-'"),
        ("-oProxyCommand=x@host:p", "starts with '-'"),
        ("ssh://host:-oProxyCommand=x/p", "the port starts with '-'"),
        # Only a leading <word>:: is the transport form.
        ("ext+x.y-z::cmd", "<transport>::<address> form is refused"),
        # git decodes a '%' in a url with '://', so a '%' in the user, host or port is refused.
        ("ssh://%2doProxyCommand=x/p", "a '%' in an ssh address is refused"),
        ("ssh://h:%2d1/p", "a '%' in an ssh address is refused"),
        ("ssh://%2do@h/p", "a '%' in an ssh address is refused"),
        ("https://%2dh/a.git", "a '%' in the user, host or port is refused"),
        ("file://%2dh/a.git", "a '%' in the user, host or port is refused"),
        ("%2dh:a.git", "a '%' in an ssh address is refused"),
        ("u%40v@h:a.git", "a '%' in an ssh address is refused"),
        # For git, the host runs to the first '/', not to a '?' or a '#'.
        ("ssh://h?x@-oProxyCommand=y/p", "the host starts with '-'"),
        ("ssh://h#x@-oProxyCommand=y/p", "the host starts with '-'"),
        ("https://h?x@-y/p", "the host starts with '-'"),
        ("h?x@-oProxyCommand=y:p", "the host starts with '-'"),
        # git decodes an ssh address and looks for a host in brackets anywhere in it, so a '%'
        # is refused anywhere in one, and a '[' or a ']' anywhere but around the host.
        (
            "ssh://x/@[-oProxyCommand=y]/p",
            "in an ssh address, '\\[' and '\\]' are allowed only around the host",
        ),
        (
            "h:p@[-oProxyCommand=y]:q",
            "in an ssh address, '\\[' and '\\]' are allowed only around the host",
        ),
        ("ssh://host/x%40[-oProxyCommand=y]/p", "a '%' in an ssh address is refused"),
        ("ssh://host/x@%5b-oProxyCommand=y]/p", "a '%' in an ssh address is refused"),
        ("ssh://host/x%40%5b-oProxyCommand=y%5d/p", "a '%' in an ssh address is refused"),
        ("ssh://git@example.org/%2da.git", "a '%' in an ssh address is refused"),
        ("git@example.org:a%2db.git", "a '%' in an ssh address is refused"),
        ("ssh://h/p@[x", "in an ssh address, '\\[' and '\\]' are allowed only around the host"),
        ("git@h:p@[x", "in an ssh address, '\\[' and '\\]' are allowed only around the host"),
        ("ssh://h/p]", "in an ssh address, '\\[' and '\\]' are allowed only around the host"),
        ("ssh://[::1]/p[x]", "in an ssh address, '\\[' and '\\]' are allowed only around the host"),
        ("[::1]:p]", "in an ssh address, '\\[' and '\\]' are allowed only around the host"),
        ("ssh://h[x]/p", "in an ssh address, '\\[' and '\\]' are allowed only around the host"),
        # In brackets, ssh still reads a user before the last '@', and git a port after a ':'.
        ("[a@-oProxyCommand=x]:p", "the host starts with '-'"),
        ("[-oProxyCommand=x@h]:p", "the user starts with '-'"),
        ("[h:-p]:path", "the port starts with '-'"),
        ("ssh://a@[h:-p]/p", "the port starts with '-'"),
        ("ssh://[h]:-p/p", "the port starts with '-'"),
        ("[h]x:p", "is refused"),
        ("h:", "is refused"),
    ],
)
def test_other_transports_are_refused(url, match):
    _refused(f"repositories:\n  a:\n    type: git\n    url: '{url}'\n", match)


@pytest.mark.parametrize(
    "char,name",
    [("\u202e", "U+202E"), ("\u200b", "U+200B"), ("\x07", "U+0007"), ("\u00a0", "U+00A0")],
)
def test_an_invisible_or_direction_changing_character_is_refused(char, name):
    _refused(
        _one_repo(f"    version: a{char}b\n"),
        "line 5, column 15: the file holds " + re.escape(name),
    )


@pytest.mark.parametrize("char", ["\u202e", "\u200b"])
def test_such_a_character_inside_a_comment_is_refused(char):
    _refused("# a comment " + char + "\n" + _one_repo(), "line 1, column 13: the file holds")


# Characters that show nothing, or look like a space, and are not in the categories above:
# variation selectors, the Hangul fillers, the combining grapheme joiner, the blank Braille
# pattern, other default-ignorable code points, private-use and unassigned code points.
_INVISIBLE = [
    "\ufe0f",
    "\U000e0100",
    "\u115f",
    "\u1160",
    "\u3164",
    "\uffa0",
    "\u034f",
    "\u2800",
    "\u180b",
    "\u17b4",
    "\U0001d173",
    "\U000e0041",
    "\ue000",
    "\U000f0000",
    "\U0010fffd",
    "\U000e0fff",
    "\U0003fffe",
    "\ufdd0",
]


@pytest.mark.parametrize("char", _INVISIBLE)
def test_an_invisible_character_in_a_value_is_refused(char):
    _refused(_one_repo(f"    version: a{char}b\n"), "line 5, column 15: the file holds U\\+")


@pytest.mark.parametrize("char", _INVISIBLE)
def test_an_invisible_character_in_a_comment_is_refused(char):
    _refused("# a comment " + char + "\n" + _one_repo(), "line 1, column 13: the file holds")


@pytest.mark.parametrize("char", _INVISIBLE)
def test_an_invisible_character_in_a_key_is_refused(char):
    text = f"repositories:\n  ok:\n{REPO}  'ok{char}':\n{REPO}"
    _refused(text, "line 5, column 6: the file holds U\\+")


@pytest.mark.parametrize("char", _INVISIBLE)
def test_the_walk_over_parsed_values_also_refuses_them(char):
    # The check on the parsed values, which the earlier reader uses, holds the same rule.
    assert has_unsafe_char(f"a{char}b")


def test_two_keys_that_look_the_same_are_not_two_repos():
    _refused(f'repositories:\n  ok:\n{REPO}  "ok\u3164":\n{REPO}', "U\\+3164")


def test_a_byte_order_mark_is_refused():
    _refused("\ufeff" + _one_repo(), "line 1, column 1: the file holds U\\+FEFF")


@pytest.mark.parametrize(
    "text",
    [
        "\u00e9 \u00fc \u00df",
        "\u65e5\u672c\u8a9e",
        "\u03a9\u03bc\u03ad\u03b3\u03b1",
        "\u2192 \u2713",
    ],
)
def test_visible_text_outside_ascii_is_accepted_in_a_comment(text):
    assert list(_m("# " + text + "\n" + _one_repo()).repositories) == ["a"]


def test_a_tab_and_crlf_line_ends_are_accepted():
    text = "#\ta comment\r\n" + _one_repo().replace("\n", "\r\n")
    assert list(_m(text).repositories) == ["a"]


@pytest.mark.parametrize("text", ["# a\r# url: b\n", "# a\r", "# a\r\r\n"])
def test_a_carriage_return_is_allowed_only_before_a_newline(text):
    # At a lone carriage return a terminal goes back to the start of the line, so what
    # follows can hide what came before.
    _refused(text + _one_repo(), "line 1, column 4: the file holds U\\+000D")


def test_a_lone_carriage_return_in_a_file_is_refused(tmp_path):
    # Read from the disk, the text is checked before a carriage return becomes a newline.
    path = tmp_path / "m.yaml"
    path.write_bytes(_one_repo().replace("type: git", "type: git\r# x").encode())
    with pytest.raises(ManifestError, match="line 3, column 14: the file holds U\\+000D"):
        load_manifest(path)


def test_a_file_with_crlf_line_ends_is_accepted(tmp_path):
    path = tmp_path / "m.yaml"
    path.write_bytes(_one_repo().replace("\n", "\r\n").encode())
    assert load_manifest(path).repositories["a"].type == "git"


@pytest.mark.parametrize(
    "comment,code,column",
    [
        ("# \u26a0\ufe0f\n", "U+FE0F", 4),
        ("# \U0001f468\u200d\U0001f4bb\n", "U+200D", 4),
        ("# \u0645\u06cc\u200c\u062e\u0648\u0627\u0647\u0645\n", "U+200C", 5),
    ],
)
def test_an_emoji_with_a_selector_or_a_joiner_is_refused_and_the_message_finds_it(
    comment, code, column
):
    # The rule holds in comments too; the message names the code point, the line and the
    # column, so a person can find a character they cannot see.
    _refused(_one_repo() + comment, f"line 5, column {column}: the file holds {re.escape(code)},")
