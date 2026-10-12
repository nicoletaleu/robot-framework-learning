import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TESTS_DIR = ROOT / "tests"
RESULTS_DIR = ROOT / "results"


def main() -> int:
    RESULTS_DIR.mkdir(exist_ok=True)
    cmd = ["robot", "--dryrun", "--outputdir", str(RESULTS_DIR), str(TESTS_DIR)]
    print("Running:", " ".join(cmd))
    completed = subprocess.run(cmd, cwd=ROOT)
    return completed.returncode


if __name__ == "__main__":
    sys.exit(main())
