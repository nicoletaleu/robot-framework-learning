*** Settings ***
Documentation    Day 23 - tags as a strategy, and what CI runs on a pull request.
...              Tags accumulate on their own: before today this repo had 44 of them,
...              most used exactly once, and 23 tests with none at all. That is not a
...              strategy, it is debris - `--include` is only useful if the tags mean
...              something consistent.
...              The scheme: every test carries exactly ONE layer tag (unit, api, web),
...              plus `smoke` if it belongs in the set that runs on every pull request.
...              Feature tags stay free-form on top of that.
...              This suite enforces it. `robot --dryrun` lists every test and every tag
...              without executing anything, so the whole repo can be inspected in two
...              seconds - including this suite, which obeys its own rules.
...              Run:  robot --outputdir results tests/23_tag_strategy.robot
Library          Process
Library          OperatingSystem
Library          Collections
Library          ../libraries/DataHelpers.py
Library          ../libraries/ResultHelpers.py
Suite Setup      Take Stock Of Every Tag In The Repo
Test Tags        unit    tags


*** Variables ***
@{LAYER TAGS}       unit    api    web
# Above this, "smoke" stops meaning "the fast subset" and starts meaning "the suite".
${SMOKE CEILING}    40
${WORKFLOW}         ${CURDIR}/../.github/workflows/tests.yml


*** Test Cases ***
Every Test Carries Exactly One Layer Tag
    [Documentation]    The backbone of the scheme. Not "at least one" - exactly one,
    ...                so `--include unit` and `--include api` never overlap and the
    ...                three of them add up to the whole repo.
    [Tags]    smoke
    ${offenders}=    Evaluate
    ...    [(t["suite"], t["name"], t["tags"]) for t in $ALL_TESTS if len(set(t["tags"]) & set($LAYER_TAGS)) != 1]
    Should Be Empty    ${offenders}    Tests without exactly one of ${LAYER TAGS}: ${offenders}

Every Suite Contributes At Least One Smoke Test
    [Documentation]    What stops smoke from drifting into "whatever was tagged first".
    ...                A suite with no smoke test is a part of the repo a pull request
    ...                never touches.
    [Tags]    smoke
    ${suites}=    Evaluate    sorted({t["suite"] for t in $ALL_TESTS})
    ${with smoke}=    Evaluate    sorted({t["suite"] for t in $ALL_TESTS if "smoke" in t["tags"]})
    ${missing}=    Evaluate    [s for s in $suites if s not in $with_smoke]
    Should Be Empty    ${missing}    Suites with no smoke test: ${missing}

The Smoke Set Stays A Minority
    [Documentation]    A smoke set that grows to cover everything is just the suite with
    ...                extra steps. The number is arbitrary; having one is not.
    ${smoke}=    Evaluate    len([t for t in $ALL_TESTS if "smoke" in t["tags"]])
    ${total}=    Get Length    ${ALL TESTS}
    ${percent}=    Evaluate    round(100 * $smoke / $total)
    Log    ${smoke} of ${total} tests are smoke (${percent}%).
    Should Be True    ${percent} <= ${SMOKE CEILING}
    ...    Smoke is ${percent}% of the suite, over the ${SMOKE CEILING}% ceiling.

Nothing Is Both Smoke And Slow
    [Documentation]    Smoke is the set that has to come back fast. A slow test in it
    ...                defeats the point of having the set at all.
    ${both}=    Evaluate
    ...    [t["name"] for t in $ALL_TESTS if "smoke" in t["tags"] and "slow" in t["tags"]]
    Should Be Empty    ${both}    Tagged both smoke and slow: ${both}

Include Selects Exactly The Tests That Carry The Tag
    [Documentation]    The mechanism the whole scheme rests on, checked rather than
    ...                assumed: --include smoke returns the smoke tests and nothing else.
    [Tags]    smoke
    ${expected}=    Evaluate    sorted(t["name"] for t in $ALL_TESTS if "smoke" in t["tags"])
    ${selected}=    Evaluate    sorted(t["name"] for t in $SMOKE_TESTS)
    Lists Should Be Equal    ${selected}    ${expected}

Tag Patterns Combine Two Conditions
    [Documentation]    smokeANDapi is one argument, not two - Robot has a small pattern
    ...                language (AND, OR, NOT) so a selection does not need a script.
    ${expected}=    Evaluate
    ...    sorted(t["name"] for t in $ALL_TESTS if "smoke" in t["tags"] and "api" in t["tags"])
    ${selected}=    Evaluate    sorted(t["name"] for t in $SMOKE_API_TESTS)
    Lists Should Be Equal    ${selected}    ${expected}
    Should Not Be Empty    ${selected}

The Pull Request Job Runs Smoke Only
    [Documentation]    A strategy nobody runs is a paragraph in a README. This checks
    ...                the workflow file says so - not that GitHub did it, which is
    ...                only visible in the Actions tab.
    ${workflow}=    Get File    ${WORKFLOW}
    Should Contain    ${workflow}    --include smoke
    Should Contain    ${workflow}    github.event_name == 'pull_request'


*** Keywords ***
Take Stock Of Every Tag In The Repo
    [Documentation]    Three dry runs: everything, the smoke selection, and the
    ...                smoke-and-api selection. Two seconds each, nothing executed.
    ${dir name}=    Unique Artifact Name    day23_dryrun    # Day 18: pid in the name
    ${work}=        Set Variable    ${TEMPDIR}/${dir name}
    Remove Directory    ${work}    recursive=${True}
    Create Directory    ${work}
    Set Suite Variable    ${WORK DIR}    ${work}
    ${python}=    Evaluate    sys.executable    modules=sys
    Set Suite Variable    ${PYTHON}    ${python}

    ${all}=          Dry Run    all
    ${smoke}=        Dry Run    smoke        --include    smoke
    ${smoke api}=    Dry Run    smoke_api    --include    smokeANDapi
    Set Suite Variable    ${ALL TESTS}          ${all}
    Set Suite Variable    ${SMOKE TESTS}        ${smoke}
    Set Suite Variable    ${SMOKE API TESTS}    ${smoke api}

Dry Run
    [Documentation]    Lists the tests Robot WOULD run, with their tags. --dryrun walks
    ...                the suites and resolves every keyword without executing one.
    [Arguments]    ${label}    @{selection}
    ${output}=    Set Variable    ${WORK DIR}/${label}.xml
    ${result}=    Run Process    ${PYTHON}    -m    robot    --dryrun
    ...    @{selection}
    ...    --output    ${output}    --report    NONE    --log    NONE
    ...    --outputdir    ${WORK DIR}
    ...    ${CURDIR}
    ...    stdout=${WORK DIR}/${label}_stdout.txt    stderr=STDOUT
    # rc is NOT 0 and that is fine: two tests call a keyword that does not exist on
    # purpose, inside Run Keyword And Expect Error, and a dry run cannot know the
    # error was the point. Only a refusal to start (251+) matters here.
    ${log}=    Get File    ${WORK DIR}/${label}_stdout.txt
    Should Be True    ${result.rc} < 251    Dry run '${label}' never started:\n${log}
    ${tests}=    Tests In Output    ${output}
    Should Not Be Empty    ${tests}    Dry run '${label}' listed no tests at all.
    RETURN    ${tests}
