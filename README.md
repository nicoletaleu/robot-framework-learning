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
│                   #   stubbed_api.resource — the two sessions suites 08-10 share
│                   #   local_site.resource  — the page server suites 11-15 share
├── libraries/      # my own keywords + listeners, written in Python (.py)
├── variables/      # environment config as a variable file (.py)
├── data/           # test data kept out of the suites (.csv, .json, .robot)
│   └── pages/      #   the site the web tests drive, served locally (.html)
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

# run only tests with a given tag — this is what a pull request runs
robot --include smoke tests/

# tag patterns: AND, OR, NOT, in one argument
robot --include smokeANDapi tests/
robot --exclude web tests/

# everything that does not need the internet — what a push to main runs
robot --exclude contract tests/

# only the checks against the real API — what the nightly job runs
robot --include contract tests/

# the web tests run headless by default — watch one instead
robot --variable HEADLESS:False tests/web/

# shuffle the order to flush out tests that depend on each other.
# the seed is printed in the report — reuse it to replay the same shuffle
robot --randomize tests tests/
robot --randomize tests:1 tests/

# run against another environment (see variables/config.py)
robot --variablefile variables/config.py:staging tests/

# run in parallel — one process per suite, four at a time
pabot --processes 4 --outputdir results tests/

# split individual tests across processes, not just whole suites
pabot --testlevelsplit --processes 4 --outputdir results tests/

# attach the listeners: one tags anything slower than 0.5s, the other writes
# results/failures/<test>.json for every test that fails. Both are optional
# and neither changes what runs
robot --listener libraries/RunListener.py:0.5       --listener libraries/FailureReporter.py       --outputdir results tests/

# after a red run — rerun only the tests that failed, then fold the result
# back into the original report (rebot writes no output.xml unless asked)
robot --rerunfailed results/output.xml --outputdir results/rerun tests/
rebot --merge --output output.xml --outputdir results/merged \
      results/output.xml results/rerun/output.xml
```
After a run, open `results/report.html` in your browser. `pabot` writes each
process into `results/pabot_results/` and merges them into the same
`report.html`, so the reports look identical either way.

On this repo four processes take the full run from ~44s to ~32s. It does not
get much better than that: the slowest single suite is ~16s, and no number of
processes can finish the run sooner than its longest suite. Splitting that suite
up — or `--testlevelsplit` — is what buys the next step. The gap narrowed after
Day 30 for a reason worth noticing: parallelism hides waiting, and most of what
this suite used to wait for was the network. Take the waiting away and there is
less left for the processes to overlap.

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

A response is a claim, not a receipt. `tests/api/22_database_checks.robot` runs a
small service (`libraries/OrderService.py`) with a SQLite database behind it and
faults that can be switched on: a POST that answers `201` and stores nothing, a
`DELETE` that answers `204` and deletes nothing, a row written with the wrong
values in it. Every assertion an API-only test would make passes in all three
cases. Checking the other end is what turns a test of the conversation into a
test of the system — and, symmetrically, a row the test planted itself proves
nothing about the API, so neither end is worth much alone.

Flakiness is not randomness — the code is identical every run, and what changes
is the world it meets. `tests/24_flaky_tests.robot` runs a deliberately unstable
suite seven ways and pins down two causes: a test that only passes after its
neighbour, and one that reads state a previous run left on disk. Both are made
reproducible, because a cause you can trigger on demand is a cause you can fix.
`--randomize tests:1` is the tool worth remembering: it turns "fails sometimes"
into a command someone else can run. The last two tests are the counterweight to
Day 20 — `--rerunfailed` plus `rebot --merge` produce a green report with zero
failures in it, and the cause is still sitting on disk, one run from doing it
again.

Which leaves the hole Day 21 admitted to: a stub returns whatever it was told
to, including a shape the real service stopped sending months ago. A **contract**
closes it. `data/contracts/post.json` is written once and two different things
are held to it — the stub, offline on every run, and the live API, on a nightly
schedule. Green stubbed tests then carry two claims instead of one: my client
handles this shape, *and* this shape is still what arrives. The contract is
deliberately loose about fields it does not use, because a consumer that breaks
when a provider adds a field is a consumer nobody can ship around.

When something does go red, the console gives a message and little else.
`libraries/FailureReporter.py` writes one JSON file per failed test instead:
the keyword that actually broke — the innermost one, not the wrapper that
reported it — with the values it was called with, the tags and process it ran
under, any image the run captured, and the versions of the machine it ran on.
The Browser library already screenshots on failure, so the picture was never
the missing piece; the context around it was. One thing worth knowing came out
of building it: Robot stores arguments exactly as they were *written*, so
`output.xml` and `log.html` both show `${expected}` and never `42`. The values
only survive in the failure message, or if something asks for them while they
are still in scope.

Day 24 said find the cause rather than retry it away, and left an honest gap:
sometimes the cause is real, understood, and not fixable this week. Deleting the
test loses the coverage. Leaving it red teaches everyone to ignore a red build,
which costs more than the test was worth. `--exclude` stops it running, so nobody
ever finds out it recovered. **Quarantine** is the fourth answer —
`--skiponfailure quarantine` reports a tagged failure as a skip *with the original
failure written into the skip message*, so the build gates honestly while the test
keeps reporting. `tests/27_quarantine.robot` proves each of those claims, and
keeps the repo's own quarantine list short and explained, so the practice cannot
rot into a place tests go to die.

Day 28 finally paid off the oldest debt in the repo: suites 08-10 had called
jsonplaceholder on every push since Day 8. Moving them behind the Day 21 stub
made a push independent of anyone else's uptime — but the interesting part was
not the speed. Rewriting each test forced the question *what was this actually
checking?*, and several turned out to be checking the service rather than my
client. "The list has 100 items" was an assertion about somebody else's fixture
data. The header tests sent a header and asserted `200`, which would have passed
with the header removed. Those are now assertions about the **request** — what
left this machine — which is both the half I am responsible for and the half no
live API can show me. Each suite keeps one live call, tagged `contract`, held to
the same written shape as the nightly checks. 39 API tests now run offline in
about four seconds.

That left the web suites, which were the same problem and the worse version of
it: a failed API call is one red test, a page that will not load takes the whole
browser suite with it, and browser tests are slow enough that a slow network
reads as flakiness. So the pages live in `data/pages/` now and
`libraries/PageServer.py` serves them — port 0 and a daemon thread, the same
lessons as the stub. A static file server would not have been enough: logging
in, logging out and uploading a file are the three things the suites do that a
page cannot answer by itself, so the server handles exactly those and nothing
else. It is a fixture, not a copy of the site.

Which is worth saying plainly, because it is the same trap Day 25 found on the
API side: a login test against this server is not testing authentication — the
password it accepts is written twenty lines above the code that checks it. It
tests my locators, my waits and my page object. That is what suites 11-15 were
always testing; the live site only made it look like more. A fixture does not
announce when it breaks, it just makes the suite using it look broken, so
`tests/web/29_local_pages.robot` tests the fixture itself: every page the suites
open answers 200, the two login failures stay distinguishable, a flash message is
shown once and then cleared, and the hidden element really is hidden until its
own script reveals it.

Day 30 moved suites 11-15 onto it, and the move was cheap in the places the
design was good and expensive exactly where it was not. Suite 13 changed by
nothing at all — every edit landed in the page object, which is what page
objects are for — except that the page object had been holding the site's
address, and a page object has no business owning the environment. That came
out. The base URL is now runtime data, because a server on a free port has no
address anyone can write down in advance.

Then the same question as Day 28, asked of the UI: *what was this really
testing?* Two answers were uncomfortable. The table test asserted the first cell
said "Smith" — an assertion about fixture data, and worse once the fixture is a
file in this repo, because it looks like a test and cannot fail for any
interesting reason. What is mine to get wrong in a table is the **locator**, and
the way to get it wrong is off by one, so it now checks the first data row is not
the header. The screenshot test had no assertion at all: it took a picture and
ended, so a silent no-op would have passed it every time.

The sharpest one was suite 15. Its delays now live in `data/pages/`, which means
I choose them — and a wait test whose page answers instantly passes with the
wait, without the wait, and with the wait deleted. So the suite opens with a test
that clicks and looks *immediately*, and requires the element to still be
unfinished. If that ever goes green-by-accident, every wait in the file has
quietly stopped being load-bearing.

`--dryrun` earned its keep here too: it resolves every keyword without executing
anything, and it found an `Append To List` in the Day 29 suite with no
`Collections` import — called only inside an `IF` that never ran while every page
was being served, so the first missing page would have crashed the test whose job
is to name it. It is a command to run, not a gate to add: two of suite 16's
negative tests fail under `--dryrun` by design.

## Tags
Tags accumulate on their own. Before Day 23 this repo had 44 of them, most used
exactly once, and 23 tests carrying none at all — which makes `--include` a
guess rather than a tool. The scheme now is deliberately small:

| Tag | Rule |
|---|---|
| `unit`, `api`, `web` | **layer** — every test carries exactly one, so the three add up to the repo and never overlap |
| `smoke` | the subset that runs on every pull request: at least one per suite, and a minority overall |
| `quarantine` | a known failure with a cause nobody can fix this week. `--skiponfailure quarantine` turns its failure into a SKIP, so the build stops gating on it while it keeps running and keeps reporting. Must say why, in its documentation |
| `contract` | needs the real API. Kept off every push and given a nightly schedule of its own — a network check on the fast loop is a flaky test waiting to happen |
| anything else | free-form feature tags (`login`, `iframe`, `database`) — useful for finding things, never for selecting a run |

`tests/23_tag_strategy.robot` enforces all of that. It runs `robot --dryrun` over
the repo, which lists every test and every tag in about two seconds without
executing anything, and fails if a test slips through untagged or if `smoke`
grows past a ceiling. A scheme nobody checks goes back to being debris.

CI follows it: a pull request runs `--include smoke` — 60 tests, ~23s. A push to
`main` runs `--exclude contract` — 189 tests in 45–60s, and since Day 30 not one
of them touches the network. That was ~116s before the web suites came off the
internet; most of the run was waiting on somebody else's server. It is a range
rather than a number now because what is left is mostly browser startup, and
that varies with whatever else the machine is doing.
The 6 `contract` tests, one or two per API suite, run at 06:00 UTC on a schedule
of their own, where a red run means the stubs have gone stale rather than that
the change is broken.
All three carry the failure reporter, so a red run uploads its own explanation.

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
- [x] Day 22 — checking the database behind the API: a POST that returns 201 and writes nothing
- [x] Day 23 — tags as a strategy: one layer tag per test, smoke on every pull request
- [x] Day 24 — a flaky test on purpose: finding the cause instead of retrying it away
- [x] Day 25 — contract tests: one written shape, held against both the stub and the real API
- [x] Day 26 — what a failure report should contain, and why the screenshot was never the hard part
- [x] Day 27 — quarantine: a build that gates honestly while a known-flaky test keeps reporting
- [x] Day 28 — suites 08-10 off the internet and behind the stub, one contract test each
- [x] Day 29 — the site the web suites drive, served from `data/pages/` — and a suite that tests the fixture
- [x] Day 30 — suites 11-15 onto the local site, and what each of them was really testing

## Next up
The Robot track is done: 30 days, 189 tests, none of which need the internet.
What remains is not more Robot Framework — it is the parts of the craft this
repo cannot teach, and those live in [`LEARNING-PLAN.md`](LEARNING-PLAN.md),
numbered `P1…` so they never get confused with the days above.
- [ ] P1 — a Postman collection over the same API the suites here use
- [ ] P2 — `newman` running it in GitHub Actions
- [ ] P8–P10 — test design on paper: the gap that matters most, because
      everything in this repo answers *does this work* and none of it answers
      *what should be tested, and why that and not something else*
