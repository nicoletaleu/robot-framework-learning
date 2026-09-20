"""Day 29 - the site the web tests drive, served from this repo.

tests/web/ drives https://the-internet.herokuapp.com. Day 28 took the API
suites off the internet; this is the last thing in the repo that depends on
somebody else being up. The web suites are the worse half of the problem: an
API call that fails is one red test, a page that fails to load is a whole
suite, and browser tests are slow enough that a flaky network shows up as
flaky tests.

So the pages live in data/pages/ and this serves them. Same three lessons as
the Day 21 stub server: port 0 so parallel workers cannot collide, a daemon
thread so a forgotten teardown cannot hang the run, and silent logging.

A static file server would not be enough. Logging in, logging out and
uploading a file are the three things the suites do that a page cannot answer
by itself, so those are handled here - and nothing else is. This is a fixture,
not a reimplementation of the site.

Which is worth being honest about: a login test against this server is not
testing authentication, because the password it accepts is the one written
twenty lines below. It tests my locators, my waits and my page object. That is
what suites 11-15 were always testing - the live site just made it look like
more.

Imported with:  Library    ../libraries/PageServer.py
"""

import re
import threading
from http.cookies import SimpleCookie
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, quote, unquote

from robot.api import logger
from robot.api.deco import keyword, library

PAGES = (Path(__file__).resolve().parent.parent / "data" / "pages").resolve()

# The credentials the practice site uses, kept identical so the suites and the
# page object did not have to change to point here.
USERS = {"tomsmith": "SuperSecretPassword!"}

# Pages carry these markers and the server fills them in on the way out. A
# flash message is per-request state, so it cannot live in a static file.
FLASH_MARKER = "<!--FLASH-->"
UPLOAD_MARKER = "<!--UPLOADED-->"


@library(scope="TEST SUITE", version="1.0.0")
class PageServer:
    """One page server per suite, started and stopped by the suite itself."""

    def __init__(self):
        self._server = None
        self._thread = None

    @keyword
    def start_page_server(self) -> str:
        """Starts the server on a free port and returns its base URL."""
        if self._server is not None:
            raise RuntimeError("The page server is already running.")
        self._server = self._QuietServer(("127.0.0.1", 0), self._build_handler())
        self._thread = threading.Thread(target=self._server.serve_forever, daemon=True)
        self._thread.start()
        base_url = f"http://127.0.0.1:{self._server.server_address[1]}"
        logger.info(f"Page server serving {PAGES} on {base_url}")
        return base_url

    @keyword
    def stop_page_server(self) -> None:
        """Shuts the server down. Safe to call when it is not running."""
        if self._server is None:
            return
        self._server.shutdown()
        self._server.server_close()
        self._thread.join(timeout=5)
        self._server = None
        self._thread = None

    @keyword
    def pages_directory(self) -> str:
        """Where the pages are served from - handy in a failure message."""
        return str(PAGES)

    class _QuietServer(ThreadingHTTPServer):
        """Same server, without a traceback when a browser hangs up mid-response.

        Chromium does that routinely: it abandons an image or a favicon the
        moment the test navigates away. socketserver treats a dropped
        connection as an unhandled error and prints a stack trace that looks
        like a broken test.
        """

        def handle_error(self, request, client_address):
            import sys

            if not issubclass(sys.exc_info()[0], ConnectionError):
                super().handle_error(request, client_address)

    def _build_handler(self):
        class Handler(BaseHTTPRequestHandler):
            protocol_version = "HTTP/1.1"  # so keep-alive connections behave

            # --- the three things a static file cannot do --------------------

            def do_GET(self):
                path = self._path()
                if path == "/secure" and not self._session():
                    self._redirect(
                        "/login", flash="You must login to view the secure area!"
                    )
                elif path == "/logout":
                    self._redirect(
                        "/login",
                        flash="You logged out of the secure area!",
                        session="",
                    )
                else:
                    self._serve(path)

            def do_POST(self):
                path = self._path()
                if path == "/login":
                    self._log_in()
                elif path == "/upload":
                    self._upload()
                else:
                    self._send(405, "<h1>Method Not Allowed</h1>")

            def _log_in(self):
                fields = self._form_fields()
                username = fields.get("username", "")
                password = fields.get("password", "")
                # Two different failures, and the site tells them apart - which
                # suite 13 has a test for, so this has to as well.
                if username not in USERS:
                    self._redirect("/login", flash="Your username is invalid!")
                elif USERS[username] != password:
                    self._redirect("/login", flash="Your password is invalid!")
                else:
                    self._redirect(
                        "/secure",
                        flash="You logged into a secure area!",
                        session=username,
                    )

            def _upload(self):
                raw = self._body()
                # Enough multipart parsing to find the filename, and no more:
                # that is the only part of the upload any test looks at.
                match = re.search(rb'filename="([^"]*)"', raw)
                filename = match.group(1).decode("utf-8") if match else ""
                if not filename:
                    self._redirect("/upload", flash="File not successfully uploaded")
                    return
                self._serve("/upload_done", extra={UPLOAD_MARKER: filename})

            # --- serving -----------------------------------------------------

            def _serve(self, path, extra=None):
                target = self._file_for(path)
                if target is None:
                    self._send(404, "<h1>Not Found</h1>")
                    return
                html = target.read_text(encoding="utf-8")
                flash = self._flash()
                html = html.replace(FLASH_MARKER, self._flash_html(flash))
                for marker, value in (extra or {}).items():
                    html = html.replace(marker, value)
                # A flash is shown once. Clearing it here is what stops the
                # message from following the browser onto the next page.
                cookies = ["flash=; Path=/; Max-Age=0"] if flash else []
                self._send(200, html, cookies=cookies)

            def _file_for(self, path):
                relative = path.strip("/") or "index"
                candidate = (PAGES / f"{relative}.html").resolve()
                # unquote() in _path() means "/%2e%2e%2f..." arrives here as
                # "../", so this check is doing real work: a URL must not be
                # able to walk out of data/pages/ and serve the rest of the repo.
                if PAGES not in candidate.parents:
                    logger.warn(f"Refused a path outside {PAGES}: {path}")
                    return None
                return candidate if candidate.is_file() else None

            # --- request helpers ---------------------------------------------

            def _path(self):
                return unquote(self.path.split("?", 1)[0])

            def _body(self):
                length = int(self.headers.get("Content-Length") or 0)
                return self.rfile.read(length) if length else b""

            def _form_fields(self):
                decoded = self._body().decode("utf-8", errors="replace")
                return {k: v[0] for k, v in parse_qs(decoded).items()}

            def _cookies(self):
                return SimpleCookie(self.headers.get("Cookie", ""))

            def _session(self):
                cookie = self._cookies().get("session")
                return cookie.value if cookie else ""

            def _flash(self):
                cookie = self._cookies().get("flash")
                return unquote(cookie.value) if cookie else ""

            @staticmethod
            def _flash_html(flash):
                if not flash:
                    return ""
                return f'<div id="flash" class="flash">{flash}</div>'

            # --- responses ----------------------------------------------------

            def _redirect(self, location, flash="", session=None):
                cookies = []
                if flash:
                    cookies.append(f"flash={quote(flash)}; Path=/")
                if session is not None:
                    age = "" if session else "; Max-Age=0"
                    cookies.append(f"session={session}; Path=/{age}")
                # 303, not 302: it tells the browser to follow up with a GET,
                # which is what turns a form POST into a normal page load.
                self._send(303, "", location=location, cookies=cookies)

            def _send(self, status, html, location=None, cookies=()):
                payload = html.encode("utf-8")
                try:
                    self.send_response(status)
                    self.send_header("Content-Type", "text/html; charset=utf-8")
                    self.send_header("Content-Length", str(len(payload)))
                    if location:
                        self.send_header("Location", location)
                    for cookie in cookies:
                        self.send_header("Set-Cookie", cookie)
                    self.end_headers()
                    if payload:
                        self.wfile.write(payload)
                except ConnectionError:
                    pass  # the browser navigated away; not a failure

            def log_message(self, *args):
                """Silenced - otherwise every request prints to the console."""

        return Handler
