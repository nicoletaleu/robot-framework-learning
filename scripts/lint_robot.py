"""robot --dryrun over the whole suite: the cheapest check this repo has.

A dry run parses every suite and resolves every keyword and variable without
executing anything, so it catches the mistakes that only show up when a line
finally runs - a keyword that does not exist, a missing library import, a
typo in a variable name. Day 29 found exactly that: an `Append To List` with
no `Collections` imported, inside an `IF` branch that had never executed
because every page it checked was being served. The first missing page would
have crashed the test whose only job was to name that page.

Seconds to run, needs no browser and no network, so it belongs in front of
the suite both locally and in CI.

Two tests are excluded. A dry run resolves keyword names and converts
arguments, and those two assert that a bad name and a bad argument fail -
so the dry run hits the very error they expect and calls it a failure. They
carry the tag `no-dryrun`, with the reasoning in the suite.

Taken from an outside review. One change: robot is started as
`python -m robot` rather than as the `robot` executable. Spawning robot.exe
from a script is blocked by the Application Control policy on the machine
this repo is developed on, and `python -m robot` is the same entry point
without a second binary on PATH.

Run:  python scripts/lint_robot.py
"""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TESTS_DIR = ROOT / "tests"
# Straight into results/, which is git-ignored: a dry run still writes
# output.xml and log.html, and they are not worth keeping.
RESULTS_DIR = ROOT / "results"


def main() -> int:
    RESULTS_DIR.mkdir(exist_ok=True)
    cmd = [sys.executable, "-m", "robot", "--dryrun", "--exclude", "no-dryrun", "--outputdir", str(RESULTS_DIR), str(TESTS_DIR)]
    print("Running:", " ".join(cmd))
    completed = subprocess.run(cmd, cwd=ROOT)
    return completed.returncode


if __name__ == "__main__":
    sys.exit(main())
