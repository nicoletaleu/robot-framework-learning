"""Day 21 - a fake HTTP server the tests control completely.

tests/api/ talks to jsonplaceholder.typicode.com. That is fine for learning the
requests, and wrong as a foundation: the suite fails when the internet is down,
when the service is slow, or when someone else changes the data. And it can only
ever answer the way it feels like - I cannot ask it for a 500.

A stub is a real HTTP server, started inside the test run, that answers exactly
what the test told it to. Two things follow, and the second one is the reason to
bother:
  1. the response is mine to choose - 500, a malformed body, a slow reply
  2. the REQUEST is visible - I can assert what my client actually sent

Port 0 means "any free port": under pabot several workers run this at once, and
a hard-coded 8080 would have them fighting over it (Day 18).

Imported with:  Library    ../libraries/StubServer.py
"""

import json
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

from robot.api import logger
from robot.api.deco import keyword, library


@library(scope="TEST SUITE", version="1.0.0")
class StubServer:
    """One stub server per suite, started and stopped by the suite itself."""

    def __init__(self):
        self._server = None
        self._thread = None
        self._stubs = {}
        self._requests = []
        self._lock = threading.Lock()

    @keyword
    def start_stub_server(self) -> str:
        """Starts the server on a free port and returns its base URL."""
        if self._server is not None:
            raise RuntimeError("The stub server is already running.")
        handler = self._build_handler()
        # Port 0: the OS hands out a free one, so parallel workers cannot collide.
        self._server = self._QuietServer(("127.0.0.1", 0), handler)
        # daemon=True so a forgotten Stop Stub Server cannot hang the whole run.
        self._thread = threading.Thread(target=self._server.serve_forever, daemon=True)
        self._thread.start()
        base_url = f"http://127.0.0.1:{self._server.server_address[1]}"
        logger.info(f"Stub server listening on {base_url}")
        return base_url

    @keyword
    def stop_stub_server(self) -> None:
        """Shuts the server down. Safe to call when it is not running."""
        if self._server is None:
            return
        self._server.shutdown()
        self._server.server_close()
        self._thread.join(timeout=5)
        self._server = None
        self._thread = None

    @keyword
    def stub_request(
        self,
        method: str,
        path: str,
        status: int = 200,
        json_body=None,
        delay: float = 0.0,
        echo: bool = False,
    ) -> None:
        """Teaches the server one answer.

        `delay` holds the response back, which is how a client timeout gets
        tested without waiting on a real slow service.

        `echo` sends the request body back as the response, the way an API that
        accepted a write usually does. Day 28: without it, a test that asserts
        on a canned PUT response is only asserting what it typed two lines
        earlier.
        """
        with self._lock:
            self._stubs[(method.upper(), path)] = {
                "status": status,
                "json_body": json_body,
                "delay": delay,
                "echo": echo,
            }

    @keyword
    def requests_received(self, method: str = "", path: str = "") -> list:
        """Every request the server has seen, newest last, optionally filtered.

        A dict per request: method, path, query, headers, body. This is what a
        live API cannot give me - proof of what the client actually sent.
        """
        with self._lock:
            received = list(self._requests)
        if method:
            received = [r for r in received if r["method"] == method.upper()]
        if path:
            received = [r for r in received if r["path"] == path]
        return received

    @keyword
    def clear_stub_requests(self) -> None:
        """Forgets the recorded requests. The stubbed answers stay."""
        with self._lock:
            self._requests.clear()

    class _QuietServer(ThreadingHTTPServer):
        """Same server, without the traceback when a client hangs up.

        The timeout test does exactly that on purpose: it stops waiting while
        the stub is still writing the response. socketserver treats a dropped
        connection as an unhandled error and prints a stack trace that looks
        like a broken test. Everything else is still reported.
        """

        def handle_error(self, request, client_address):
            import sys

            if not issubclass(sys.exc_info()[0], ConnectionError):
                super().handle_error(request, client_address)

    def _build_handler(self):
        """The handler class needs a way back to this instance - a closure gives it one."""
        stub = self

        class Handler(BaseHTTPRequestHandler):
            protocol_version = "HTTP/1.1"  # so keep-alive connections behave

            def do_GET(self):
                self._answer("GET")

            def do_POST(self):
                self._answer("POST")

            def do_PUT(self):
                self._answer("PUT")

            def do_PATCH(self):
                self._answer("PATCH")

            def do_DELETE(self):
                self._answer("DELETE")

            def _answer(self, method):
                parsed = urlparse(self.path)
                length = int(self.headers.get("Content-Length") or 0)
                raw = self.rfile.read(length) if length else b""
                stub._record(method, parsed.path, parsed.query, self.headers, raw)
                rule = stub._match(method, parsed.path)
                if rule is None:
                    # An unstubbed call is a mistake in the test, and it should
                    # look like one rather than quietly returning 200.
                    self._send(404, {"error": f"No stub for {method} {parsed.path}"})
                    return
                if rule["delay"]:
                    time.sleep(rule["delay"])
                body = rule["json_body"]
                if rule["echo"]:
                    sent = json.loads(raw) if raw else {}
                    # Anything the stub was also told to return wins over the
                    # echo, so a server-assigned id can be layered on top.
                    body = {**sent, **(body or {})}
                self._send(rule["status"], body)

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
                    # The client gave up before the answer arrived. That is the
                    # timeout test doing its job, not a failure of the stub.
                    pass

            def log_message(self, *args):
                """Silenced - otherwise every request prints to the console."""

        return Handler

    def _record(self, method, path, query, headers, raw):
        body = raw.decode("utf-8", errors="replace")
        try:
            parsed_body = json.loads(body) if body else None
        except json.JSONDecodeError:
            parsed_body = None
        with self._lock:
            self._requests.append(
                {
                    "method": method,
                    "path": path,
                    "query": parse_qs(query),
                    "headers": {k.lower(): v for k, v in headers.items()},
                    "body": body,
                    "json": parsed_body,
                }
            )

    def _match(self, method, path):
        with self._lock:
            return self._stubs.get((method.upper(), path))
