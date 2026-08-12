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
├── libraries/      # my own keywords, written in Python (.py)
├── variables/      # environment config as a variable file (.py)
├── data/           # test data kept out of the suites (.csv, .json)
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
```
After a run, open `results/report.html` in your browser. `pabot` writes each
process into `results/pabot_results/` and merges them into the same
`report.html`, so the reports look identical either way.

On this repo four processes take the full run from ~104s to ~54s. It does not
get much better than that: the slowest single suite is ~48s, and no number of
processes can finish the run sooner than its longest suite. Splitting that suite
up — or `--testlevelsplit` — is what buys the next step.

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
- [ ] ... (checked off as I progress)
