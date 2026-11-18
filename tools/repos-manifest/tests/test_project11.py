"""The project11 fixture: three roles on two distros, against outputs checked by hand."""

from pathlib import Path

import pytest

import yaml

from repos_manifest.cli import main
from repos_manifest.output import strip_head_comment

FIXTURE = Path(__file__).parent / "fixtures" / "project11"
MANIFEST = FIXTURE / "project11.manifest.yaml"
EXPECTED = FIXTURE / "expected"
OLD_EXPECTED = Path(__file__).parent / "fixtures" / "p11" / "expected"
COMBINATIONS = [(r, d) for r in ("robot", "operator", "developer") for d in ("jazzy", "rolling")]


def _private_repo():
    """The key and url of the one private repo, as the earlier fixture names it: read from
    there, so that no file this fixture adds spells its name."""
    repos = yaml.safe_load((OLD_EXPECTED / "jazzy" / "site.repos").read_text())["repositories"]
    ((key, entry),) = repos.items()
    return key, entry["url"]


def _made_up_repo():
    """The key and url this fixture gives that repo instead."""
    repos = yaml.safe_load(MANIFEST.read_text())["repositories"]
    entry = repos["site_config"]
    return "site_config", entry["url"]


def _resolve(tmp_path, role, distro):
    out = tmp_path / f"{role}-{distro}"
    argv = ["resolve", "--manifest", str(MANIFEST), "--role", role, "--distro", distro]
    assert main(argv + ["--out", str(out)]) == 0
    return out


def _files(directory):
    return {p.name: p.read_text() for p in sorted(directory.iterdir()) if p.name[0] != "."}


@pytest.mark.parametrize("role,distro", COMBINATIONS)
def test_project11_resolves_to_the_expected_files(role, distro, tmp_path):
    out = _resolve(tmp_path, role, distro)
    got = {name: strip_head_comment(text) for name, text in _files(out).items()}
    assert got == _files(EXPECTED / f"{role}-{distro}")


@pytest.mark.parametrize("distro", ["jazzy", "rolling"])
def test_developer_gets_the_44_repos_of_the_earlier_fixture(distro, tmp_path):
    # The draft was made from the same layer files the earlier fixture was. The one private
    # repo has a made-up name in this fixture.
    out = _resolve(tmp_path, "developer", distro)
    old = _files(OLD_EXPECTED / distro)
    new = {n: strip_head_comment(t) for n, t in _files(out).items() if n.endswith(".repos")}
    assert set(new) == set(old)
    (private_key, private_url), (made_up_key, made_up_url) = _private_repo(), _made_up_repo()
    for name, text in old.items():
        text = text.replace(private_url, made_up_url).replace(f"{private_key}:", f"{made_up_key}:")
        assert new[name] == text, name
    assert sum(t.count("type: git") for t in new.values()) == 44


def test_rolling_differs_from_jazzy_only_in_one_version():
    for role in ("robot", "operator", "developer"):
        jazzy, rolling = _files(EXPECTED / f"{role}-jazzy"), _files(EXPECTED / f"{role}-rolling")
        assert set(jazzy) == set(rolling)
        changed = [n for n in jazzy if jazzy[n] != rolling[n]]
        assert changed == ["core.repos"]
        assert rolling["core.repos"] == jazzy["core.repos"].replace(
            "unh_marine_autonomy.git\n    version: jazzy",
            "unh_marine_autonomy.git\n    version: rolling",
        )


def test_the_private_repo_is_not_named_in_the_fixture_or_this_test():
    private_key, private_url = _private_repo()
    paths = [Path(__file__), MANIFEST] + [p for p in EXPECTED.rglob("*") if p.is_file()]
    for path in paths:
        text = path.read_text()
        assert private_key not in text, path
        assert private_url not in text, path


def test_validate_checks_every_role_and_distro(capsys):
    assert main(["validate", "--manifest", str(MANIFEST)]) == 0
    out = capsys.readouterr().out
    assert "role developer, distro jazzy: 44 repos in 7 layers" in out
    assert "role robot, distro rolling: 20 repos in 5 layers" in out
    assert "role operator, distro jazzy: 30 repos in 6 layers" in out
    assert out.endswith("valid\n")
