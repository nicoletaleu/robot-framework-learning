"""Day 16 - my first custom Robot Framework library.

Robot = the test (what is checked). Python = the plumbing (how a value is
produced or cleaned up). Assertions stay in the .robot file, so they show up
in the report.

Imported with:  Library    ../libraries/DataHelpers.py
  - method names become keywords: random_email -> "Random Email"
  - @library sets auto_keywords=False: only @keyword methods are exposed
  - type hints convert arguments: length: int gets the string "12" as 12
"""

import random
import re
import string
from datetime import date

from robot.api import logger
from robot.api.deco import keyword, library


@library(scope="GLOBAL", version="1.0.0")
class DataHelpers:
    """Helpers that produce or clean up test data.

    scope="GLOBAL" = one instance for the whole run, so state below survives
    across tests. Alternatives: "TEST SUITE", "TEST".
    """

    def __init__(self):
        self._emails_generated = 0

    @keyword
    def random_email(self, prefix: str = "user", domain: str = "example.com") -> str:
        """Returns an email not used before in this run."""
        suffix = "".join(random.choices(string.digits, k=8))
        email = f"{prefix}_{suffix}@{domain}"
        self._emails_generated += 1
        logger.info(f"Generated email: {email}")  # lands in log.html
        return email

    @keyword("Random String Of Length")
    def random_string(self, length: int = 10) -> str:
        """Returns `length` random lowercase letters.

        @keyword renames it, so the call reads as a sentence in Robot.
        """
        return "".join(random.choices(string.ascii_lowercase, k=length))

    @keyword
    def build_user(self, name: str, age: int, email: str = "") -> dict:
        """Returns a user dict - any Python object can be returned, not just text."""
        return {
            "name": name,
            "age": age,
            "email": email or self.random_email(),
            "is_adult": age >= 18,
        }

    @keyword
    def age_on(self, birthdate: date, reference_date: date) -> int:
        """Age in whole years on a given day.

        The reference date is an argument on purpose: reading today() here would
        make the test change its own result every birthday.
        """
        had_birthday = (reference_date.month, reference_date.day) >= (
            birthdate.month,
            birthdate.day,
        )
        return reference_date.year - birthdate.year - (0 if had_birthday else 1)

    @keyword
    def normalize_phone_number(self, raw: str) -> str:
        """Strips spaces, dots, dashes, brackets. Keeps a leading +.

        Raises on anything implausible - a keyword that raises is a failed test.
        """
        cleaned = re.sub(r"[^\d+]", "", raw)
        digits = cleaned.lstrip("+")
        if not digits.isdigit() or not 9 <= len(digits) <= 15:
            raise ValueError(f"Not a valid phone number: {raw!r}")
        return ("+" if cleaned.startswith("+") else "") + digits

    @keyword
    def emails_generated_so_far(self) -> int:
        """Emails handed out since the run started. Only meaningful because scope is GLOBAL."""
        return self._emails_generated

    @keyword
    def log_users_as_a_table(self, users: list) -> None:
        """Writes the users into log.html as an HTML table."""
        rows = "".join(
            f"<tr><td>{u['name']}</td><td>{u['age']}</td><td>{u['email']}</td></tr>"
            for u in users
        )
        logger.info(
            "<table border='1'><tr><th>name</th><th>age</th><th>email</th></tr>"
            f"{rows}</table>",
            html=True,
        )

    # No @keyword -> not callable from a suite, despite the ordinary name.
    def slugify(self, text: str) -> str:
        return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
