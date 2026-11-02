"""
Runs inside the image before scoring, with every snapshot at /snapshots. CI
installs each team's own pyproject.toml, but the image only has the template's
dependencies and EXTRA_PACKAGES, so this lists the packages teams declared
that it doesn't have, one "package: team, ..." line each, for run.sh.
"""

import re
import tomllib
from importlib.metadata import PackageNotFoundError, distribution
from pathlib import Path

missing = {}
for pyproject in sorted(Path("/snapshots").glob("*/pyproject.toml")):
    try:
        dependencies = tomllib.loads(pyproject.read_text())["project"]["dependencies"]
    except (OSError, ValueError, KeyError, TypeError):
        continue  # CI couldn't have installed it either
    for dependency in dependencies:
        # the name before any version, extras or markers, e.g. "torch>=2.4"
        name = re.match(r"[A-Za-z0-9._-]*", str(dependency)).group()
        if not name:
            continue
        try:
            distribution(name)
        except PackageNotFoundError:
            missing.setdefault(name, []).append(pyproject.parent.name)

for name, teams in sorted(missing.items()):
    print(f"{name}: {', '.join(teams)}")
