# Robot Framework — Test Automation Learning

[![robot tests](https://github.com/nicoletalucia/robot-framework-learning/actions/workflows/tests.yml/badge.svg)](https://github.com/nicoletalucia/robot-framework-learning/actions/workflows/tests.yml)

A repository where I learn test automation with **Robot Framework** (Python).

## Stack
- Robot Framework
- Browser library (Playwright) — web testing
- requests library — API testing
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
```
After a run, open `results/report.html` in your browser.

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
- [ ] ... (checked off as I progress)
