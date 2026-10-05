"""
Runs inside the container for one team. Builds /work from the official
template plus only the team's own files, then scores it the way CI does
(.github/submit.py writes score.txt).

Prints status=, score= and edited= lines for run.sh. Everything the team's
code prints goes to stderr, which run.sh saves as that team's log.
"""

import filecmp
import os
import shutil
import subprocess
import sys
from pathlib import Path

OFFICIAL = Path("/official")
SUBMISSION = Path("/submission")
# a folder inside the /work mount, since we can't change the mount's own permissions
WORK = Path("/work/team")

student_files = set(os.environ["STUDENT_FILES"].split())
timeout = int(os.environ.get("TIMEOUT", "3600"))


def files(root):
    return {p.relative_to(root) for p in root.rglob("*") if p.is_file()}


official = files(OFFICIAL)
submitted = files(SUBMISSION)

# The official template wins for every file it has, except the ones students
# are meant to edit. Files the team added are kept, so their helper modules work
shutil.copytree(OFFICIAL, WORK)
for rel in submitted:
    if str(rel) in student_files or rel not in official:
        (WORK / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(SUBMISSION / rel, WORK / rel)

# Template files the team changed, which were replaced with the official ones
edited = sorted(
    str(rel)
    for rel in submitted & official
    if str(rel) not in student_files
    and not filecmp.cmp(SUBMISSION / rel, OFFICIAL / rel, shallow=False)
)
print("edited=" + ";".join(edited))

try:
    result = subprocess.run(
        [sys.executable, ".github/submit.py"],
        cwd=WORK,
        env={**os.environ, "PYTHONPATH": str(WORK)},
        stdout=sys.stderr,
        timeout=timeout,
    )
except subprocess.TimeoutExpired:
    print("status=timeout")
    sys.exit()

score_file = WORK / "score.txt"
if result.returncode != 0 or not score_file.exists():
    print(f"status=error (exit {result.returncode})")
    sys.exit()

print("status=ok")
print(score_file.read_text().strip())
