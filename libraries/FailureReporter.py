"""Day 26 - what a failure report should contain.

The Browser library already screenshots on failure - run_on_failure is set to
"Take Screenshot" out of the box. So the picture is not the missing piece. What
is missing is everything around it, and it is missing at exactly the moment it
is needed: a red run at 3am, on a machine that is not mine, that I would rather
not have to reproduce before I can start thinking.

This listener writes one JSON file per failed test, containing the four things
a console line does not give me:

  which keyword broke   not the outer one that reported it - the deepest one,
                        with the arguments it was actually called with
  where it was          suite, tags, and the process id, so a pabot failure can
                        be told apart from a plain one
  what was captured     any image logged during the test, screenshots included,
                        found generically rather than by naming a library
  what the machine was  robot, python and platform - the "works on my machine"
                        question, answered before it is asked

Attached like any listener, and it can sit alongside another:
    robot --listener libraries/RunListener.py --listener libraries/FailureReporter.py tests/

Imported as a listener, never with `Library`.
"""

import json
import os
import platform
import re
import sys
from pathlib import Path

import robot
from robot.libraries.BuiltIn import BuiltIn

IMAGE_SOURCE = re.compile(r'src="([^"]+)"')


class FailureReporter:
    ROBOT_LISTENER_API_VERSION = 3

    def __init__(self, report_dir: str = ""):
        self.report_dir = Path(report_dir) if report_dir else None
        self._images = []
        self._failures = []
        self._written = []

    def start_suite(self, data, result):
        if self.report_dir is not None:
            return
        output_dir = BuiltIn().get_variable_value("${OUTPUT DIR}")
        self.report_dir = Path(output_dir) / "failures"

    def start_test(self, data, result):
        """A report describes one test, so the evidence resets with each one."""
        self._images = []
        self._failures = []

    def log_message(self, message):
        """Collects images from anything that logs one.

        A screenshot reaches the log as an <img> tag, whoever took it. Reading
        it out of the message rather than asking the Browser library keeps this
        working for a library that has not been written yet.
        """
        if message.html and "<img" in message.message:
            self._images.extend(IMAGE_SOURCE.findall(message.message))

    def end_keyword(self, data, result):
        """Fires innermost first, which is the whole trick.

        A failure propagates outward: the user keyword reports the same error
        its last step raised, and by the time it reaches the test the message
        has lost the arguments. The FIRST failure seen here is the deepest one.
        """
        if result.status != "FAIL":
            return
        arguments = [str(arg) for arg in result.args]
        self._failures.append(
            {
                "keyword": result.full_name,
                "arguments": arguments,
                "resolved": [self._resolve(arg) for arg in arguments],
                "message": result.message,
            }
        )

    def _resolve(self, argument: str) -> str:
        """Best effort at what an argument actually held.

        Robot stores arguments as they were WRITTEN - output.xml and log.html
        both show ${expected}, not 42 - so a report built from the result model
        alone tells you the shape of the call and none of its values. The values
        are still in scope here, because end_keyword fires the instant the
        keyword finished, so they can be asked for.

        Best effort on purpose: a variable can be out of scope, or the string
        can be something Robot refuses to look at, and neither is worth losing
        the rest of the report over.
        """
        try:
            return str(BuiltIn().replace_variables(argument))
        except Exception:
            return argument

    def end_test(self, data, result):
        """Writes the report - only for tests that actually failed."""
        if result.status != "FAIL":
            return
        report = {
            "test": result.name,
            "suite": result.parent.name if result.parent else "",
            "tags": list(result.tags),
            "message": result.message,
            "seconds": round(result.elapsed_time.total_seconds(), 3),
            # Innermost first: failures[0] is the keyword that actually broke.
            "failures": self._failures,
            "images": self._images,
            "environment": {
                "robot": robot.version.VERSION,
                "python": sys.version.split()[0],
                "platform": platform.platform(),
                "pid": os.getpid(),
            },
        }
        self.report_dir.mkdir(parents=True, exist_ok=True)
        # Day 18: the pid keeps two pabot workers from writing the same name.
        name = f"{self._slug(result.name)}_{os.getpid()}.json"
        path = self.report_dir / name
        path.write_text(json.dumps(report, indent=2), encoding="utf-8")
        self._written.append(str(path))

    def close(self):
        """One index listing every report, so a CI artefact has an entry point."""
        if not self._written:
            return
        index = self.report_dir / f"index_{os.getpid()}.json"
        index.write_text(
            json.dumps({"failures": len(self._written), "reports": self._written}, indent=2),
            encoding="utf-8",
        )

    def _slug(self, text: str) -> str:
        return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")[:60]
