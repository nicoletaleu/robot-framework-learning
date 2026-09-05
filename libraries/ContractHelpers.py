"""Day 25 - checking a payload against a written contract.

Day 21 ended on an uncomfortable note: a stub will happily return a shape the
real service never returns, and every test stays green. A contract closes that
hole. The shape lives in one file, in data/contracts/, and two different things
are held to it:

  - the stub's canned responses, offline, on every run
  - the real API, over the network, on a schedule

Green stubbed tests then mean something. They mean "my client handles this
shape correctly" AND "this shape is still what the service sends" - two claims
that no single test can make on its own.

JSON Schema rather than a hand-rolled checker: it is the format the rest of the
industry writes these in, and jsonschema reports every violation at once
instead of stopping at the first.

Imported with:  Library    ../libraries/ContractHelpers.py
"""

import json
from pathlib import Path

from jsonschema import Draft202012Validator
from robot.api import logger
from robot.api.deco import keyword, library

CONTRACT_DIR = Path(__file__).parent.parent / "data" / "contracts"


@library(scope="GLOBAL", version="1.0.0")
class ContractHelpers:
    """Loads contracts from data/contracts and validates payloads against them."""

    def __init__(self):
        self._cache = {}

    @keyword
    def load_contract(self, name: str) -> dict:
        """Reads data/contracts/<name>.json and checks the schema itself is legal.

        A typo in a contract would otherwise pass everything silently, which is
        the one failure mode a contract must not have.
        """
        if name not in self._cache:
            path = CONTRACT_DIR / f"{name}.json"
            if not path.exists():
                raise ValueError(f"No contract named {name!r} in {CONTRACT_DIR}")
            schema = json.loads(path.read_text(encoding="utf-8"))
            Draft202012Validator.check_schema(schema)
            self._cache[name] = schema
        return self._cache[name]

    @keyword
    def contract_violations(self, payload, name: str) -> list:
        """Every way `payload` breaks the contract, as readable strings.

        A list, not the first error: when a response has drifted it has usually
        drifted in several places, and fixing them one run at a time is slow.
        """
        validator = Draft202012Validator(self.load_contract(name))
        return [
            f"{self._where(error)}: {error.message}"
            for error in sorted(validator.iter_errors(payload), key=str)
        ]

    @keyword
    def payload_should_match_contract(self, payload, name: str) -> None:
        """Fails the test, listing every violation, if the payload breaks the contract."""
        violations = self.contract_violations(payload, name)
        if violations:
            listed = "\n  - ".join(violations)
            raise AssertionError(
                f"Payload does not match the '{name}' contract:\n  - {listed}"
            )
        logger.info(f"Payload matches the '{name}' contract.")

    @keyword
    def every_item_should_match_contract(self, items: list, name: str) -> None:
        """Same check across a list, reporting the index of each bad item.

        A list endpoint that is right about the first item and wrong about the
        fortieth is exactly the drift a spot check misses.
        """
        problems = []
        for index, item in enumerate(items):
            for violation in self.contract_violations(item, name):
                problems.append(f"item {index} {violation}")
        if problems:
            listed = "\n  - ".join(problems)
            raise AssertionError(
                f"{len(problems)} violation(s) of the '{name}' contract "
                f"across {len(items)} items:\n  - {listed}"
            )
        logger.info(f"All {len(items)} items match the '{name}' contract.")

    def _where(self, error) -> str:
        """'root' or 'root.title' - where in the payload the violation is."""
        path = ".".join(str(part) for part in error.absolute_path)
        return f"root.{path}" if path else "root"
