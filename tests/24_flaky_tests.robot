*** Settings ***
Documentation    Day 24 - a flaky test on purpose, and how to find its cause.
...              Day 20 taught --rerunfailed, which is the right tool after a fix and
...              a trap before one: rerunning until green turns a broken suite into a
...              slow green one. This is the other half.
...              Flakiness is not randomness. The code is the same every run; what
...              changes is the world it meets - the order it ran in, the state left
...              behind, a resource that was not ready. Both causes here are
...              reproducible on demand, which is exactly what makes them fixable.
...              data/flaky_demo.robot is run seven different ways below and the
...              results compared.
...              Run:  robot --outputdir results tests/24_flaky_tests.robot
Library          Process
Library          OperatingSystem
Library          Collections
Library          ../libraries/DataHelpers.py
Library          ../libraries/ResultHelpers.py
Suite Setup      Run The Flaky Suite Every Which Way
Test Tags        unit    flaky


*** Variables ***
${DEMO SUITE}     ${CURDIR}/../data/flaky_demo.robot
${FILLS}          A Demo Test That Fills The Cart
${TRUSTS}         A Demo Test That Trusts The Cart
${ALTERNATES}     A Demo Test That Alternates Between Runs
${BUILDS OWN}     A Demo Test That Builds Its Own Cart
# Found by trying, then written down - which is the whole point of a seed:
# 1 puts the dependent test first, 5 leaves it second.
${BAD SEED}       1
${GOOD SEED}      5


*** Test Cases ***
The Same Tests Pass In Order And Fail Reordered
    [Documentation]    Nothing about the tests changed between these two runs. Only the
    ...                order did, and the order is not something a test declares.
    [Tags]    smoke
    Status Of    ${IN ORDER}     ${TRUSTS}    PASS
    Status Of    ${BAD ORDER}    ${TRUSTS}    FAIL

Running The Test On Its Own Is The Fastest Diagnosis
    [Documentation]    The first move on any flaky test, and it costs two seconds: run
    ...                it alone. Green in the suite and red by itself means the test is
    ...                reading state it never set up.
    [Tags]    smoke
    ${names}=    Test Names In Output    ${ALONE}
    Length Should Be    ${names}    1
    Status Of    ${ALONE}    ${TRUSTS}    FAIL

A Seed Turns Sometimes Into Every Time
    [Documentation]    --randomize shuffles the order and the seed makes one particular
    ...                shuffle repeatable. That is the difference between a bug report
    ...                saying it fails sometimes and one that can be handed to someone.
    Status Of    ${BAD ORDER}     ${TRUSTS}    FAIL
    Status Of    ${GOOD ORDER}    ${TRUSTS}    PASS

A Test That Builds Its Own State Does Not Care About Order
    [Documentation]    The fix, and the rule behind it: depend on nothing you did not
    ...                set up yourself. Same three runs, this one is green in all.
    Status Of    ${IN ORDER}      ${BUILDS OWN}    PASS
    Status Of    ${BAD ORDER}     ${BUILDS OWN}    PASS
    Status Of    ${GOOD ORDER}    ${BUILDS OWN}    PASS

The Same Command Twice Gives Two Different Answers
    [Documentation]    The second cause: state that outlives the run. Identical command,
    ...                identical files - the first run leaves something behind and the
    ...                second one reads it.
    [Tags]    smoke
    Status Of    ${FIRST TRY}    ${ALTERNATES}    FAIL
    Status Of    ${RETRY}        ${ALTERNATES}    PASS

Rerunning Turns The Report Green And Fixes Nothing
    [Documentation]    The trap. --rerunfailed and rebot --merge, straight out of Day 20,
    ...                and the merged report has no failures in it. Not one line of the
    ...                cause was touched.
    [Tags]    smoke
    ${counts}=    Status Counts In Output    ${MERGED}
    Should Be Equal As Integers    ${counts}[failed]    0
    Should Be Equal As Integers    ${counts}[passed]    1
    Should Be Equal As Integers    ${MERGE RC}          0
    # Day 20's consolation: the report does at least admit it was retried.
    ${test}=    Test From    ${MERGED}    ${ALTERNATES}
    Should Contain    ${test}[message]    re-executed

The Cause Is Still Sitting On Disk Afterwards
    [Documentation]    What the green report does not say. The counter that made the test
    ...                fail is still there, one run away from doing it again - which is
    ...                why "just rerun it" is an answer to a symptom.
    File Should Exist    ${COUNTER FILE}
    ${runs}=    Get File    ${COUNTER FILE}
    Should Be Equal As Integers    ${runs}    2


*** Keywords ***
Run The Flaky Suite Every Which Way
    [Documentation]    Seven child runs: four to show order dependence, three to show
    ...                state that survives a run and how a rerun paints over it.
    ${dir name}=    Unique Artifact Name    day24_flaky    # Day 18: pid in the name
    ${work}=        Set Variable    ${TEMPDIR}/${dir name}
    Remove Directory    ${work}    recursive=${True}
    Create Directory    ${work}
    Set Suite Variable    ${WORK DIR}    ${work}
    ${python}=    Evaluate    sys.executable    modules=sys
    Set Suite Variable    ${PYTHON}    ${python}

    # Cause 1: order dependence. No counter involved, so these four are repeatable.
    @{cart}=    Create List
    ...    --test    ${FILLS}    --test    ${TRUSTS}    --test    ${BUILDS OWN}
    ${in order}=      Flaky Run    in_order      @{cart}
    ${alone}=         Flaky Run    alone         --test    ${TRUSTS}
    ${bad order}=     Flaky Run    bad_order     --randomize    tests:${BAD SEED}     @{cart}
    ${good order}=    Flaky Run    good_order    --randomize    tests:${GOOD SEED}    @{cart}
    Set Suite Variable    ${IN ORDER}      ${in order}
    Set Suite Variable    ${ALONE}         ${alone}
    Set Suite Variable    ${BAD ORDER}     ${bad order}
    Set Suite Variable    ${GOOD ORDER}    ${good order}

    # Cause 2: state that outlives the run, and the rerun that hides it.
    ${counter}=    Set Variable    ${work}/counter
    Set Suite Variable    ${COUNTER FILE}    ${counter}
    ${first try}=    Flaky Run    first_try
    ...    --test    ${ALTERNATES}    --variable    COUNTER_FILE:${counter}
    # Not a fix and not a change - the same suite, filtered by what failed last time.
    ${retry}=        Flaky Run    retry
    ...    --rerunfailed    ${first try}    --variable    COUNTER_FILE:${counter}
    Set Suite Variable    ${FIRST TRY}    ${first try}
    Set Suite Variable    ${RETRY}        ${retry}

    ${merge}=    Run Process    ${PYTHON}    -m    robot.rebot
    ...    --merge    --output    output.xml    --outputdir    ${work}/merged
    ...    ${first try}    ${retry}
    ...    stdout=${work}/merge_stdout.txt    stderr=STDOUT
    Set Suite Variable    ${MERGE RC}    ${merge.rc}
    Set Suite Variable    ${MERGED}      ${work}/merged/output.xml

Flaky Run
    [Documentation]    One child run of the demo suite. Returns the path to its
    ...                output.xml. A non-zero rc is the point here, so only a refusal
    ...                to start (251+) is reported.
    [Arguments]    ${label}    @{arguments}
    ${output}=    Set Variable    ${WORK DIR}/${label}.xml
    ${result}=    Run Process    ${PYTHON}    -m    robot    @{arguments}
    ...    --output    ${output}    --report    NONE    --log    NONE
    ...    --outputdir    ${WORK DIR}
    ...    ${DEMO SUITE}
    ...    stdout=${WORK DIR}/${label}_stdout.txt    stderr=STDOUT
    ${log}=    Get File    ${WORK DIR}/${label}_stdout.txt
    Should Be True    ${result.rc} < 251    Run '${label}' never started:\n${log}
    RETURN    ${output}

Test From
    [Documentation]    One test out of an output.xml, by name.
    [Arguments]    ${output}    ${test name}
    ${tests}=      Tests In Output    ${output}
    ${matches}=    Evaluate    [t for t in $tests if t["name"] == $test_name]
    Length Should Be    ${matches}    1    No single '${test name}' in ${output}
    RETURN    ${matches}[0]

Status Of
    [Documentation]    Asserts one test's status in one run, naming both in the failure.
    [Arguments]    ${output}    ${test name}    ${expected}
    ${test}=    Test From    ${output}    ${test name}
    Should Be Equal    ${test}[status]    ${expected}
    ...    '${test name}' was ${test}[status], expected ${expected}, in ${output}
