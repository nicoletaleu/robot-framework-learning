# Robot Framework — Test Automation Learning

[![robot tests](https://github.com/nicoletalucia/robot-framework-learning/actions/workflows/tests.yml/badge.svg)](https://github.com/nicoletalucia/robot-framework-learning/actions/workflows/tests.yml)

A repository where I learn test automation with **Robot Framework** (Python).

## Stack
- Robot Framework
- Browser library (Playwright) — web testing
- requests library — API testing
- pabot — parallel execution
- GitHub Actions — CI

## Structure
```
robot-framework/
├── .github/workflows/  # CI — runs the suites on every push
├── tests/          # test suites (.robot)
│   ├── web/        # UI tests
│   └── api/        # API tests
├── resources/      # reusable keywords and variables (.resource)
├── libraries/      # my own keywords + listeners, written in Python (.py)
├── variables/      # environment config as a variable file (.py)
├── data/           # test data kept out of the suites (.csv, .json, .robot)
├── results/        # generated reports (log.html, report.html) — git-ignored
└── README.md
```

## How to run the tests
```bash
# install (once)
pip install -r requirements.txt
rfbrowser init          # downloads the browsers used by the web tests

# run all tests
robot --outputdir results tests/

# run a single suite
robot --outputdir results tests/01_first_test.robot

# run only tests with a given tag
robot --include smoke tests/

# run against another environment (see variables/config.py)
robot --variablefile variables/config.py:staging tests/

# run in parallel — one process per suite, four at a time
pabot --processes 4 --outputdir results tests/

# split individual tests across processes, not just whole suites
pabot --testlevelsplit --processes 4 --outputdir results tests/

# attach the listener: tags every test slower than 0.5s and writes a
# per-process listener_summary_*.json next to the report
robot --listener libraries/RunListener.py:0.5 --outputdir results tests/

# after a red run — rerun only the tests that failed, then fold the result
# back into the original report (rebot writes no output.xml unless asked)
robot --rerunfailed results/output.xml --outputdir results/rerun tests/
rebot --merge --output output.xml --outputdir results/merged \
      results/output.xml results/rerun/output.xml
```
After a run, open `results/report.html` in your browser. `pabot` writes each
process into `results/pabot_results/` and merges them into the same
`report.html`, so the reports look identical either way.

On this repo four processes take the full run from ~104s to ~54s. It does not
get much better than that: the slowest single suite is ~48s, and no number of
processes can finish the run sooner than its longest suite. Splitting that suite
up — or `--testlevelsplit` — is what buys the next step.

A **listener** is the other half of that picture: a library waits to be called by
a test, a listener is called by Robot around every suite and every test, and the
suites never know. It attaches on the command line, so one file applies to every
suite in the repo — including the ones written before it existed. That is where
cross-cutting work belongs: timing, a screenshot on failure, an extra tag.
`libraries/RunListener.py` is mine; `tests/19_listeners.robot` tests it by
starting a child run and reading back what it recorded.

`output.xml` is the third thing worth knowing about. `report.html` is for people;
`output.xml` is the same run as data, and Robot ships the parser
(`robot.api.ExecutionResult`, wrapped in `libraries/ResultHelpers.py`). That is
what makes `--rerunfailed` possible — it reads the previous `output.xml` and
picks the failed tests out of it, so nobody has to list them. The rerun alone is
a partial report, though: it never saw the tests that passed. `rebot --merge`
folds it back in, matching on test name, and writes into the merged test *why* it
is green — old status, old message. A test that passed on the second attempt
never reads as a test that passed.

The API suites talk to a real service over the internet, which is fine for
learning the requests and wrong as a foundation — they break when the internet
does, and a live service will not return a 500 because a test asked politely.
`libraries/StubServer.py` starts a real HTTP server inside the run that answers
what the test told it to. The response being mine is the obvious half; the useful
half is that the **request** becomes visible, so a test can assert what the client
actually sent rather than only what came back. What a stub cannot do is tell me
the real service still behaves that way, which is why a few tests against the
live API stay.

## Progress
- [x] Day 1 — first test running
- [x] Day 2 — variables and assertions
- [x] Day 3 — keywords, lists and FOR loops
- [x] Day 4 — dictionaries and IF/ELSE conditions
- [x] Day 5 — reusable keywords (resource file), arguments, defaults, return values
- [x] Day 6 — setup/teardown (suite & test) and tags
- [x] Day 7 — data-driven testing with test templates
- [x] Day 8 — API testing with RequestsLibrary (GET/POST, status codes, JSON)
- [x] Day 9 — API CRUD (PUT/PATCH/DELETE) and custom headers
- [x] Day 10 — chaining requests, passing data between tests, validating response shape
- [x] Day 11 — first web UI test with the Browser library (open, click, fill, assert)
- [x] Day 12 — web interactions: dropdowns, checkboxes, dynamic waits, tables, screenshots
- [x] Day 13 — page objects: login page resource + data-driven login tests
- [x] Day 14 — alerts, iframes, new tabs, file upload
- [x] Day 15 — CI with GitHub Actions + explicit waits (wait for a state, never a fixed time)
- [x] Day 16 — my own Python library: custom keywords, type conversion, test data
- [x] Day 17 — test data outside the suites: variable files, JSON and CSV
- [x] Day 18 — parallel execution with pabot: writing tests that share nothing
- [x] Day 19 — listeners: watching the run from outside the suites (Listener API v3)
- [x] Day 20 — rerunning only what failed: `--rerunfailed`, `rebot --merge`, `output.xml` as data
- [x] Day 21 — stubbing the service under test: a fake HTTP server the tests control

## Next up
A working list, not a contract — it gets reordered as I go, but it lives here so
the next day is never a guess.
- [ ] Day 22 — checking the database behind the API: a POST that returns 201 and writes nothing
- [ ] Day 23 — tags as a strategy: smoke vs regression, and what CI runs on a pull request
- [ ] Day 24 — a flaky test on purpose: finding the cause instead of retrying it away
- [ ] Day 25 — contract tests: keeping the stub honest about what the real API returns
