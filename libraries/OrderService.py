"""Day 22 - a small service that actually stores something, and can be broken on demand.

Day 21's StubServer answers whatever the test told it to and remembers nothing.
This one is a different animal: it has a database behind it, so a request has a
consequence that outlives the response. That is what makes it useful here -
the interesting bugs are the ones where the response is fine and the
consequence is missing.

Three faults can be switched on, all of them real things services do:
  drop_writes    POST answers 201 with an id, and stores nothing
  drop_deletes   DELETE answers 204, and the row is still there
  mangle_data    the row is stored, with the wrong values in it

SQLite because it needs no server and no dependency. A connection per request:
sqlite3 objects are not meant to be shared between threads, and every request
here is handled in its own.

Imported with:  Library    ../libraries/OrderService.py
"""

import json
import sqlite3
import threading
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

from robot.api import logger
from robot.api.deco import keyword, library

SCHEMA = """
CREATE TABLE IF NOT EXISTS orders (
    id       INTEGER PRIMARY KEY AUTOINCREMENT,
    item     TEXT    NOT NULL,
    quantity INTEGER NOT NULL
)
"""


@library(scope="TEST SUITE", version="1.0.0")
class OrderService:
    """A fake orders API with a real SQLite database behind it."""

    def __init__(self):
        self._server = None
        self._thread = None
        self._db_path = None
        self._faults = set()

    @keyword
    def start_order_service(self, db_path: str) -> str:
        """Creates the schema if needed, starts the service, returns its base URL."""
        if self._server is not None:
            raise RuntimeError("The order service is already running.")
        self._db_path = db_path
        with self._connect() as connection:
            connection.execute(SCHEMA)
        # Port 0 for the same reason as Day 21: no port is safe to hard-code.
        self._server = _QuietServer(("127.0.0.1", 0), self._build_handler())
        self._thread = threading.Thread(target=self._server.serve_forever, daemon=True)
        self._thread.start()
        base_url = f"http://127.0.0.1:{self._server.server_address[1]}"
        logger.info(f"Order service on {base_url}, database at {db_path}")
        return base_url

    @keyword
    def stop_order_service(self) -> None:
        """Shuts the service down. Safe to call when it is not running."""
        if self._server is None:
            return
        self._server.shutdown()
        self._server.server_close()
        self._thread.join(timeout=5)
        self._server = None
        self._thread = None

    @keyword
    def break_the_service(self, fault: str) -> None:
        """Switches a fault on: drop_writes, drop_deletes or mangle_data."""
        known = {"drop_writes", "drop_deletes", "mangle_data"}
        if fault not in known:
            raise ValueError(f"Unknown fault {fault!r}. Known: {sorted(known)}")
        self._faults.add(fault)
        logger.info(f"Fault enabled: {fault}")

    @keyword
    def repair_the_service(self) -> None:
        """Switches every fault back off."""
        self._faults.clear()

    @contextmanager
    def _connect(self):
        """Commits on success and always closes.

        `with sqlite3.connect(...) as connection:` looks like it does this and
        does not: it commits, and leaves the connection open. The leaked handles
        keep the file locked, and on Windows the suite teardown then cannot
        delete it.
        """
        connection = sqlite3.connect(self._db_path, timeout=5)
        try:
            yield connection
            connection.commit()
        finally:
            connection.close()

    def _build_handler(self):
        service = self

        class Handler(BaseHTTPRequestHandler):
            protocol_version = "HTTP/1.1"

            def do_POST(self):
                if urlparse(self.path).path != "/orders":
                    return self._send(404, {"error": "unknown path"})
                payload = self._read_json()
                if not payload or "item" not in payload:
                    return self._send(400, {"error": "item is required"})
                quantity = payload.get("quantity", 1)
                if "mangle_data" in service._faults:
                    # The subtle one: the row is written, just not with the
                    # values that were sent.
                    quantity = 1
                if "drop_writes" in service._faults:
                    # The loud-looking one: a perfectly convincing 201, and
                    # nothing reaches the database.
                    return self._send(201, {"id": 999, "item": payload["item"]})
                with service._connect() as connection:
                    cursor = connection.execute(
                        "INSERT INTO orders (item, quantity) VALUES (?, ?)",
                        (payload["item"], quantity),
                    )
                    new_id = cursor.lastrowid
                self._send(201, {"id": new_id, "item": payload["item"]})

            def do_GET(self):
                order_id = self._order_id()
                if order_id is None:
                    return self._send(404, {"error": "unknown path"})
                with service._connect() as connection:
                    row = connection.execute(
                        "SELECT id, item, quantity FROM orders WHERE id = ?",
                        (order_id,),
                    ).fetchone()
                if row is None:
                    return self._send(404, {"error": "no such order"})
                self._send(200, {"id": row[0], "item": row[1], "quantity": row[2]})

            def do_DELETE(self):
                order_id = self._order_id()
                if order_id is None:
                    return self._send(404, {"error": "unknown path"})
                if "drop_deletes" not in service._faults:
                    with service._connect() as connection:
                        connection.execute(
                            "DELETE FROM orders WHERE id = ?", (order_id,)
                        )
                # 204 either way - which is exactly the problem.
                self._send(204, None)

            def _order_id(self):
                parts = urlparse(self.path).path.strip("/").split("/")
                if len(parts) != 2 or parts[0] != "orders" or not parts[1].isdigit():
                    return None
                return int(parts[1])

            def _read_json(self):
                length = int(self.headers.get("Content-Length") or 0)
                if not length:
                    return None
                try:
                    return json.loads(self.rfile.read(length))
                except json.JSONDecodeError:
                    return None

            def _send(self, status, body):
                payload = b"" if body is None else json.dumps(body).encode()
                try:
                    self.send_response(status)
                    self.send_header("Content-Type", "application/json")
                    self.send_header("Content-Length", str(len(payload)))
                    self.end_headers()
                    if payload:
                        self.wfile.write(payload)
                except ConnectionError:
                    pass  # client hung up; not this server's problem

            def log_message(self, *args):
                """Silenced - one line per request would drown the console."""

        return Handler


class _QuietServer(ThreadingHTTPServer):
    """No stack trace when a client drops the connection. Same as Day 21."""

    def handle_error(self, request, client_address):
        import sys

        if not issubclass(sys.exc_info()[0], ConnectionError):
            super().handle_error(request, client_address)
