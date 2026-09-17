*** Settings ***
Documentation    Day 27 - quarantining a known-flaky test without hiding it.
...              Day 24 said find the cause rather than retry it away. This is the
...              honest gap in that advice: sometimes the cause is real, understood,
...              and not fixable this week. Three bad answers and one workable one.
...              Delete it and the coverage goes with it. Leave it red and everyone
...              learns to ignore a red build, which costs more than the test was
...              worth. Exclude it and it stops running, so nobody ever finds out it
...              got better.
...              Quarantine is the fourth: --skiponfailure turns a failure on a tagged
...              test into a SKIP, so the build stays honest about what is green while
...              the test keeps running and keeps reporting. The original failure is
...              written into the skip message, not swallowed.
...              Run:  robot --outputdir results tests/27_quarantine.robot
Library          Process
Library          OperatingSystem
Library          Collections
Library          ../libraries/DataHelpers.py
Library          ../libraries/ResultHelpers.py
Suite Setup      Run The Demo Suite Three Ways
Test Tags        unit    quarantine-policy


*** Variables ***
${DEMO SUITE}      ${CURDIR}/../data/quarantine_demo.robot
${STILL FAILS}     A Demo Test In Quarantine That Still Fails
${NOW PASSES}      A Demo Test In Quarantine That Has Started Passing
${BROKEN}          A Demo Test That Is Simply Broken
${HEALTHY}         A Demo Test That Is Healthy
# How many quarantined tests this repo tolerates before the practice has become
# a habit. The number is arbitrary; having one is not.
${QUARANTINE CEILING}    3


*** Test Cases ***
A Quarantined Failure Is Reported As Skipped
    [Documentation]    The mechanism. The test ran, the test failed, and the run
    ...                records it as skipped rather than failed.
    [Tags]    smoke
    Status Of    ${QUARANTINED}    ${STILL FAILS}    SKIP

The Original Failure Is Still In The Report
    [Documentation]    The "without hiding it" half, and the reason this is not just
    ...                a nicer way of ignoring things. Robot writes the failure it
    ...                would have reported into the skip message, so the cause is one
    ...                click away rather than gone.
    [Tags]    smoke
    ${test}=    Test From    ${QUARANTINED}    ${STILL FAILS}
    Should Contain    ${test}[message]    quarantine
    Should Contain    ${test}[message]    the underlying race is still there

A Test That Is Not Quarantined Still Fails The Run
    [Documentation]    The gate has to keep working, or quarantine has replaced the
    ...                build rather than made room in it.
    [Tags]    smoke
    Status Of    ${QUARANTINED}    ${BROKEN}     FAIL
    Status Of    ${QUARANTINED}    ${HEALTHY}    PASS

The Tag On Its Own Changes Nothing
    [Documentation]    Worth knowing before trusting it. Without --skiponfailure the
    ...                tag is a note to a human and the test fails normally - so the
    ...                policy lives in the run command, and a run that forgets the
    ...                flag is simply a red run, never a silently green one.
    [Tags]    smoke
    Status Of    ${UNFLAGGED}    ${STILL FAILS}    FAIL

A Quarantined Test That Has Recovered Is Reported As Passing
    [Documentation]    The half people forget. Quarantine is not a bin: the point of
    ...                still running these is to find out when one goes quiet, so it
    ...                can come back out.
    Status Of    ${QUARANTINED}    ${NOW PASSES}    PASS

Excluding Them Instead Would Throw The Signal Away
    [Documentation]    Why not --exclude quarantine, which also keeps the build green.
    ...                Because the tests never run: no skip, no message, no way to
    ...                notice the recovered one. A quiet build and a working build
    ...                stop being distinguishable.
    ${names}=    Test Names In Output    ${EXCLUDED}
    Length Should Be    ${names}    2
    Should Not Contain    ${names}    ${STILL FAILS}
    Should Not Contain    ${names}    ${NOW PASSES}
    # The quarantined run knows about all four, which is the whole difference.
    ${all}=    Test Names In Output    ${QUARANTINED}
    Length Should Be    ${all}    4

The Exit Code Counts Only The Real Failures
    [Documentation]    One genuinely broken test, so rc is 1 - not 2. That is what
    ...                lets a build gate on it without lying about what is green.
    Should Be Equal As Integers    ${QUARANTINED RC}    1
    # Without the flag the same suite reports both, which is the state being escaped.
    Should Be Equal As Integers    ${UNFLAGGED RC}      2

The Repo Keeps Its Own Quarantine List Short And Explained
    [Documentation]    The governance, and the part that stops quarantine from rotting
    ...                into a place tests go to die. Same --dryrun sweep as Day 23.
    ...                Empty today, so this passes trivially - it is a tripwire for
    ...                later, not a measurement of now. Anything put in quarantine has
    ...                to say why, in its documentation, next to the tag.
    ${quarantined}=    Evaluate    [t for t in $REPO_TESTS if "quarantine" in t["tags"]]
    ${count}=    Get Length    ${quarantined}
    Log    ${count} test(s) currently in quarantine.
    Should Be True    ${count} <= ${QUARANTINE CEILING}
    ...    ${count} tests in quarantine, over the ceiling of ${QUARANTINE CEILING}: ${quarantined}
    FOR    ${test}    IN    @{quarantined}
        Should Not Be Empty    ${test}[doc]
        ...    '${test}[name]' is quarantined and says nothing about why.
    END


*** Keywords ***
Run The Demo Suite Three Ways
    [Documentation]    The same four tests, run under three different policies, plus a
    ...                dry run over this repo for the governance check.
    ${dir name}=    Unique Artifact Name    day27_quarantine    # Day 18: pid in the name
    ${work}=        Set Variable    ${TEMPDIR}/${dir name}
    Remove Directory    ${work}    recursive=${True}
    Create Directory    ${work}
    Set Suite Variable    ${WORK DIR}    ${work}
    ${python}=    Evaluate    sys.executable    modules=sys
    Set Suite Variable    ${PYTHON}    ${python}

    ${quarantined}    ${quarantined rc}=    Demo Run    quarantined
    ...    --skiponfailure    quarantine
    ${unflagged}      ${unflagged rc}=      Demo Run    unflagged
    ${excluded}       ${excluded rc}=       Demo Run    excluded
    ...    --exclude    quarantine
    Set Suite Variable    ${QUARANTINED}       ${quarantined}
    Set Suite Variable    ${QUARANTINED RC}    ${quarantined rc}
    Set Suite Variable    ${UNFLAGGED}         ${unflagged}
    Set Suite Variable    ${UNFLAGGED RC}      ${unflagged rc}
    Set Suite Variable    ${EXCLUDED}          ${excluded}

    ${repo}=    Dry Run This Repo
    Set Suite Variable    ${REPO TESTS}    ${repo}

Demo Run
    [Documentation]    One child run of the demo suite. Returns the output.xml path
    ...                and the exit code, both of which the tests compare.
    [Arguments]    ${label}    @{policy}
    ${output}=    Set Variable    ${WORK DIR}/${label}.xml
    ${result}=    Run Process    ${PYTHON}    -m    robot    @{policy}
    ...    --output    ${output}    --report    NONE    --log    NONE
    ...    --outputdir    ${WORK DIR}
    ...    ${DEMO SUITE}
    ...    stdout=${WORK DIR}/${label}_stdout.txt    stderr=STDOUT
    ${log}=    Get File    ${WORK DIR}/${label}_stdout.txt
    Should Be True    ${result.rc} < 251    Run '${label}' never started:\n${log}
    RETURN    ${output}    ${result.rc}

Dry Run This Repo
    [Documentation]    Lists every test in tests/ with its tags and documentation,
    ...                without executing anything. Day 23's sweep, reused.
    ${output}=    Set Variable    ${WORK DIR}/repo.xml
    ${result}=    Run Process    ${PYTHON}    -m    robot    --dryrun
    ...    --output    ${output}    --report    NONE    --log    NONE
    ...    --outputdir    ${WORK DIR}
    ...    ${CURDIR}
    ...    stdout=${WORK DIR}/repo_stdout.txt    stderr=STDOUT
    # rc is not 0 here and that is expected - two tests call a keyword that does
    # not exist on purpose, and a dry run cannot know the error was the point.
    ${log}=    Get File    ${WORK DIR}/repo_stdout.txt
    Should Be True    ${result.rc} < 251    Dry run never started:\n${log}
    ${tests}=    Tests In Output    ${output}
    Should Not Be Empty    ${tests}
    RETURN    ${tests}

Test From
    [Documentation]    One test out of an output.xml, by name.
    [Arguments]    ${output}    ${test name}
    ${tests}=      Tests In Output    ${output}
    ${matches}=    Evaluate    [t for t in $tests if t["name"] == $test_name]
    Length Should Be    ${matches}    1    No single '${test name}' in ${output}
    RETURN    ${matches}[0]

Status Of
    [Documentation]    Asserts one test's status in one run, naming both on failure.
    [Arguments]    ${output}    ${test name}    ${expected}
    ${test}=    Test From    ${output}    ${test name}
    Should Be Equal    ${test}[status]    ${expected}
    ...    '${test name}' was ${test}[status], expected ${expected}, in ${output}
