"""Day 19 - my first listener: code that watches the run instead of testing it.

A library is called BY the tests. A listener is called BY Robot itself, around
every suite and every test, whether or not a suite knows it exists. That is why
it is attached on the command line and never with a Library import:

    robot --listener libraries/RunListener.py --outputdir results tests/
    robot --listener libraries/RunListener.py:0.5 ...    # argument after the colon

Listener API v3 hands each callback two objects:
  - `data`   what the .robot file says (the plan)
  - `result` what actually happened (the outcome)
`result` is still writable while the callback runs, so a listener can change
what lands in report.html - see end_test, which tags every slow test without a
single suite mentioning tags.
"""

import json
import os
from pathlib import Path

from robot.api import logger
from robot.libraries.BuiltIn import BuiltIn


class RunListener:
    # Without this attribute Robot assumes the old v2 API and the signatures
    # below never match.
    ROBOT_LISTENER_API_VERSION = 3

    def __init__(self, slow_seconds: str = "1.0"):
        # Listener arguments arrive as strings. There is no type conversion
        # here like there is for keyword arguments, so convert by hand.
        self.slow_seconds = float(slow_seconds)
        self.record_file = None
        self.summary_file = None
        self.records = []

    def start_suite(self, data, result):
        """Fires for every suite, including the directory suite wrapping tests/."""
        if self.record_file is not None:
            return  # already set up by the top-level suite
        output_dir = BuiltIn().get_variable_value("${OUTPUT DIR}")
        # Day 18 rule, applied to my own code: under pabot every worker runs
        # its own listener instance and they all write into the same folder,
        # so the pid goes into the file name.
        self.record_file = Path(output_dir) / f"listener_{os.getpid()}.jsonl"
        self.summary_file = Path(output_dir) / f"listener_summary_{os.getpid()}.json"
        self.record_file.write_text("", encoding="utf-8")
        # A suite cannot import a listener, so this is how it finds out one is
        # attached - and how suite 19 skips itself when it is not.
        BuiltIn().set_global_variable("${LISTENER ACTIVE}", True)
        # as_posix(), not str(): a Windows path handed to Robot as a variable
        # goes through escape processing, and C:\Users\... comes out the other
        # side as C:Users... with \U eaten. Forward slashes work on both.
        BuiltIn().set_global_variable(
            "${LISTENER RECORD FILE}", self.record_file.as_posix()
        )

    def start_test(self, data, result):
        """Runs before the test's own setup, so the test can read this."""
        BuiltIn().set_global_variable("${LISTENER LAST STARTED}", result.name)

    def end_test(self, data, result):
        """Runs after the teardown, when the status is final."""
        seconds = result.elapsed_time.total_seconds()
        if seconds > self.slow_seconds:
            # Writing to `result` is the whole point of v3: this tag reaches
            # report.html although no .robot file ever asked for it.
            result.tags.add("slow")
            logger.info(f"{result.name} took {seconds:.2f}s - tagged slow.")
        record = {
            "name": result.name,
            "status": result.status,
            "seconds": round(seconds, 3),
            "tags": list(result.tags),
            "pid": os.getpid(),
        }
        self.records.append(record)
        # Appended as it happens, not at the end: a run that is killed halfway
        # still leaves behind everything it managed to observe.
        with self.record_file.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(record) + "\n")

    def close(self):
        """The last callback of the run.

        There is no execution context left here - BuiltIn() and logger would
        have nowhere to write - so the summary goes straight to disk.
        """
        if self.summary_file is None:
            return
        summary = {
            "total": len(self.records),
            "passed": sum(1 for r in self.records if r["status"] == "PASS"),
            "failed": sum(1 for r in self.records if r["status"] == "FAIL"),
            "skipped": sum(1 for r in self.records if r["status"] == "SKIP"),
            "slow": sorted(r["name"] for r in self.records if "slow" in r["tags"]),
            "slowest_seconds": max((r["seconds"] for r in self.records), default=0.0),
            "pid": os.getpid(),
        }
        self.summary_file.write_text(json.dumps(summary, indent=2), encoding="utf-8")
