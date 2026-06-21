# Robot Framework — Test Automation Learning

A repository where I learn test automation with **Robot Framework** (Python).

## Stack
- Robot Framework
- Browser library (Playwright) — web testing
- requests library — API testing
- GitHub Actions — CI

## Structure
```
robot-framework/
├── tests/          # test suites (.robot)
│   ├── web/        # UI tests
│   └── api/        # API tests
├── resources/      # reusable keywords and variables (.resource)
├── results/        # generated reports (log.html, report.html) — git-ignored
└── README.md
```

## How to run the tests
```bash
# install (once)
pip install robotframework

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
- [ ] Day 2 — variables and assertions
- [ ] ... (checked off as I progress)
