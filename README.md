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
pip install -r requirements.txt

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
- [ ] ... (checked off as I progress)
