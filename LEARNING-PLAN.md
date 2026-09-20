# Learning Plan — beyond Robot Framework

The Robot repo covers one tool deeply. This plan covers the rest of the craft:
the tools I have not touched yet, and the half of testing that never shows up
in a test suite at all.

Numbered `P1, P2, …` so the days here never get confused with the Robot days in
the README. Once P3 starts, this file moves to a new `qa-portfolio` repo.

## Where I am

| Area | Where it stands |
|---|---|
| Framework design & maintenance | done — resources, page objects, listeners, pabot |
| API testing | done — RequestsLibrary, stub server, contracts, DB checks |
| Python | done — eight modules: two listeners, two servers, four helper libraries |
| CI | done — GitHub Actions, three run paths, a nightly job |
| Test isolation | done — Day 30: 189 tests, none of them touching the network |
| **Test design on paper** | missing — everything so far is automation, nothing is a written test |
| **A second automation stack** | missing — one tool deeply is not the same as knowing the trade-offs |
| Performance testing | missing |
| Security testing | missing |
| Containers | missing |

The first two are the ones that change how I think. The rest is breadth.

## P1–P2 — Postman + Newman

The cheapest thing on the list: the practice already exists in `tests/api/`,
only the tool is new. Worth doing because a GUI client makes different mistakes
easy than a code client does.

- P1 — a collection over the same public API the Robot suites use: environments,
  variables, assertions in the Tests tab, pre-request scripts
- P2 — `newman` running in GitHub Actions, collection committed to the repo

## P3–P7 — Selenium + pytest

Python is already known, so only the tool changes - which is exactly what makes
it useful: the same test, written twice, shows what belongs to the tool and what
belongs to testing. pytest comes along for free.

- P3 — driver setup, explicit waits, first test
- P4 — locators and a Page Object as a Python class
- P5 — `conftest.py`, fixtures, parametrize (setup/teardown and templates again,
  in a different dialect)
- P6 — screenshot on failure, pytest-html, parallel runs with `pytest-xdist`
- P7 — port three existing web tests from the Browser library and write up where
  the two approaches differ

## P8–P10 — test design on paper

The gap that matters most. Everything built so far answers "does this work"; none
of it answers "what should be tested, and why that and not something else". Kept
early on purpose — last in the list means first to be dropped.

- P8 — a test plan for one of the applications under test: scope, risk, entry
  and exit criteria
- P9 — formal test cases, and one good bug report: steps, expected, actual,
  severity
- P10 — traceability matrix, and a smoke/regression tag strategy (pairs directly
  with Robot Day 23)

## P11–P16 — JavaScript + Cypress

Breadth. Start only after P1–P10 are done.

- P11–P12 — the JavaScript that is actually needed: `const/let`, arrow
  functions, promises/async, npm
- P13 — first Cypress test, commands and assertions
- P14 — `cy.intercept()` and fixtures (stubbing again — same idea as Robot Day 21)
- P15 — custom commands, page objects in Cypress
- P16 — Cypress in CI, with video and screenshot artefacts

## P17–P20 — nice-to-have

- P17–P18 — k6: a first load test, thresholds, a report
- P19 — OWASP ZAP baseline scan against a demo application
- P20 — the test suites running in Docker, so they do not depend on my machine

## Resources

In English, because that is where the material is.

Not endorsements of the whole runtime: the rule is watch the first hour, then
build. This repo was not learned by watching.

**Postman (P1–P2)**
- [Postman Beginner's Course — API Testing](https://www.youtube.com/watch?v=VywxIQ2ZXw4) — freeCodeCamp, the main one
- [Learn Postman for API Testing (Step-by-Step)](https://www.youtube.com/watch?v=wEOLZq-7DYs) — shorter alternative
- [API Testing Using Postman — Full Course in 5 hours](https://www.youtube.com/watch?v=CGX6DRNfS-E) — reference, not a sitting

**Selenium + pytest (P3–P7)**
- [PyTest Tutorial — Learn PyTest in 90 minutes](https://www.youtube.com/watch?v=UzkuOACmBpA) — start here, pytest alone
- [Pytest Selenium Python Hybrid Framework with Page Object Model](https://www.youtube.com/watch?v=8V3uP77o7kQ) — the POM part, for P4–P6
- [Selenium With Python and PyTest — Free Full Course](https://www.youtube.com/playlist?list=PL63jFO_mmwQ0u6iiEN56JsgjTLRuEa30D) — playlist, dip in as needed

**Process and writing (P8–P10)**
- [Manual QA: Testing for Beginners — How to file a bug report](https://www.youtube.com/watch?v=7cDzjS6z5ks)
- [Manual QA: Testing for Beginners — Managing Test Cases and QA Docs](https://www.youtube.com/watch?v=tS5vq4DqJgE)
- [How to Write a Good Defect Report](https://www.youtube.com/watch?v=rTmEUiWwgLs)

**Cypress (P11–P16, later)**
- [Learn Cypress End-to-End Testing From Scratch — 2.5h](https://www.youtube.com/watch?v=AnyKTiC3P1M)
- [Testing JavaScript with Cypress — Full Course](https://www.youtube.com/watch?v=u8vMu7viCm8) — freeCodeCamp
