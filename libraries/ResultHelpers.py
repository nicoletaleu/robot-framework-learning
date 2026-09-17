"""Day 20 - reading output.xml back as data.

report.html is for humans. output.xml is the same run in a form a program can
query, and Robot ships the parser: robot.api.ExecutionResult. Everything the
`rebot` command does - merging, re-reporting, filtering by tag - it does through
this object, so anything rebot can do is also something I can do.

Imported with:  Library    ../libraries/ResultHelpers.py
"""

from robot.api import ExecutionResult
from robot.api.deco import keyword, library


@library(scope="GLOBAL", version="1.0.0")
class ResultHelpers:
    """Turns an output.xml into plain dicts and lists that a suite can assert on."""

    @keyword
    def tests_in_output(self, path: str) -> list:
        """Every test in an output.xml, as a list of dicts.

        Keys: name, suite, tags, doc, status, message. `message` is where a
        merged run explains itself - rebot writes the old status into it when a
        test was re-executed. `doc` is what Day 27 reads to check that a
        quarantined test says why it is in there.

        Day 23 reads this from a --dryrun output.xml, where nothing was executed
        but every test and every tag is already there.
        """
        suite = ExecutionResult(path).suite
        return [
            {
                "name": test.name,
                "suite": test.parent.name,
                "tags": list(test.tags),
                "doc": test.doc,
                "status": test.status,
                "message": test.message,
            }
            for test in self._walk(suite)
        ]

    @keyword
    def test_names_in_output(self, path: str) -> list:
        """Just the names, in the order they were executed."""
        return [test["name"] for test in self.tests_in_output(path)]

    @keyword
    def status_counts_in_output(self, path: str) -> dict:
        """How many passed, failed and skipped - the numbers on top of report.html."""
        total = ExecutionResult(path).statistics.total
        return {
            "passed": total.passed,
            "failed": total.failed,
            "skipped": total.skipped,
            "total": total.total,
        }

    def _walk(self, suite):
        """Tests live on nested suites, so flatten them first."""
        yield from suite.tests
        for child in suite.suites:
            yield from self._walk(child)
