*** Settings ***
Documentation    Day 20 - rerunning only what failed, and putting the run back together.
...              A red run does not mean rerunning everything: --rerunfailed reads the
...              previous output.xml and picks up exactly the tests that failed. The
...              catch is that the rerun on its own is a partial truth - it never saw
...              the tests that passed - so rebot --merge folds it back into the
...              original. Same child-run trick as Day 19 to observe all of it.
...              Run:  robot --outputdir results tests/20_rerun_and_merge.robot
Library          Process
Library          OperatingSystem
Library          Collections
Library          ../libraries/DataHelpers.py
Library          ../libraries/ResultHelpers.py
Suite Setup      Run The Demo Suite, Then Rerun And Merge
Test Tags        rerun    unit


*** Variables ***
${DEMO SUITE}     ${CURDIR}/../data/rerun_demo.robot
${ALWAYS PASSES}    A Demo Test That Always Passes
${GETS FIXED}       A Demo Test That Fails Until The Fix Is In Place
${STAYS BROKEN}     A Demo Test That Stays Broken


*** Test Cases ***
The First Run Is Red, And The Exit Code Says How Red
    [Documentation]    rc is the number of failed tests, not just 0 or 1.
    [Tags]    smoke
    Should Be Equal As Integers    ${FIRST RUN RC}    2
    ${counts}=    Status Counts In Output    ${FIRST OUTPUT}
    Should Be Equal As Integers    ${counts}[total]     3
    Should Be Equal As Integers    ${counts}[passed]    1
    Should Be Equal As Integers    ${counts}[failed]    2

Rerunfailed Picks Up Exactly The Tests That Failed
    [Documentation]    Two of three, chosen from the previous output.xml - I never
    ...                listed them by hand.
    [Tags]    smoke
    ${names}=    Test Names In Output    ${RERUN OUTPUT}
    Length Should Be    ${names}    2
    Should Contain       ${names}    ${GETS FIXED}
    Should Contain       ${names}    ${STAYS BROKEN}
    Should Not Contain   ${names}    ${ALWAYS PASSES}

The Rerun On Its Own Is A Partial Truth
    [Documentation]    Why the merge exists: on its own this report claims the suite
    ...                has two tests, and a green one is missing entirely.
    [Tags]    smoke
    ${counts}=    Status Counts In Output    ${RERUN OUTPUT}
    Should Be Equal As Integers    ${counts}[total]    2

Merging Replaces Results Instead Of Adding Them
    [Documentation]    3 + 2 runs, still 3 tests. rebot matches on name and overwrites.
    ${names}=    Test Names In Output    ${MERGED OUTPUT}
    Length Should Be    ${names}    3

A Fixed Test Is Green In The Merged Report
    ${test}=    Merged Test    ${GETS FIXED}
    Should Be Equal    ${test}[status]    PASS

But The Report Still Says It Was Retried
    [Documentation]    The honest part: a merged test carries its own history, so
    ...                "green on the second attempt" never reads as "green".
    [Tags]    smoke
    ${test}=    Merged Test    ${GETS FIXED}
    Should Contain    ${test}[message]    Test has been re-executed and results merged.
    Should Contain    ${test}[message]    Old status:
    Should Contain    ${test}[message]    The fix is not in place yet.

A Test That Was Never Rerun Is Left Untouched
    [Documentation]    No merge note on it - it was carried over from the first run as it was.
    ${test}=    Merged Test    ${ALWAYS PASSES}
    Should Be Equal    ${test}[status]     PASS
    Should Be Equal    ${test}[message]    ${EMPTY}

Merging Does Not Launder A Failure
    [Documentation]    Rerunning until it goes green is not a strategy, and rebot
    ...                does not help with it: still red, still counted.
    [Tags]    smoke
    ${test}=      Merged Test    ${STAYS BROKEN}
    Should Be Equal    ${test}[status]    FAIL
    ${counts}=    Status Counts In Output    ${MERGED OUTPUT}
    Should Be Equal As Integers    ${counts}[passed]    2
    Should Be Equal As Integers    ${counts}[failed]    1
    Should Be Equal As Integers    ${MERGE RC}          1


*** Keywords ***
Run The Demo Suite, Then Rerun And Merge
    [Documentation]    First run, fix, rerun of the failures only, merge. All three
    ...                outputs are kept so the tests can compare them.
    # Same reasoning as Day 19: child runs write their own output.xml, which must
    # not land inside a pabot worker's folder. Pid in the name, per Day 18.
    ${dir name}=    Unique Artifact Name    day20_rerun_demo
    ${work}=        Set Variable    ${TEMPDIR}/${dir name}
    Remove Directory    ${work}    recursive=${True}
    Create Directory    ${work}

    ${python}=    Evaluate    sys.executable    modules=sys
    Set Suite Variable    ${PYTHON}    ${python}
    Set Suite Variable    ${WORK DIR}    ${work}

    ${first}=    Run Robot    first_run    --outputdir    ${work}/run1    ${DEMO SUITE}
    Set Suite Variable    ${FIRST RUN RC}    ${first.rc}
    Set Suite Variable    ${FIRST OUTPUT}    ${work}/run1/output.xml

    # The "fix": the gated test looks for this file and only passes once it exists.
    Create File    ${work}/fix_marker    applied

    # --rerunfailed reads the previous output.xml and selects the failed tests.
    # The suite is still passed as the source - rerunfailed filters it, it does
    # not replace it.
    ${rerun}=    Run Robot    rerun
    ...    --rerunfailed    ${FIRST OUTPUT}
    ...    --variable       FIX_MARKER:${work}/fix_marker
    ...    --outputdir      ${work}/run2
    ...    ${DEMO SUITE}
    Set Suite Variable    ${RERUN OUTPUT}    ${work}/run2/output.xml

    # rebot writes log.html and report.html by default and NO output.xml, so a
    # merged run that has to be merged again later needs --output spelled out.
    ${merge}=    Run Process    ${PYTHON}    -m    robot.rebot
    ...    --merge
    ...    --output       output.xml
    ...    --outputdir    ${work}/merged
    ...    ${FIRST OUTPUT}    ${RERUN OUTPUT}
    ...    stdout=${work}/merge_stdout.txt    stderr=STDOUT
    Set Suite Variable    ${MERGE RC}        ${merge.rc}
    Set Suite Variable    ${MERGED OUTPUT}    ${work}/merged/output.xml

    ${merged}=    Tests In Output    ${MERGED OUTPUT}
    Set Suite Variable    ${MERGED TESTS}    ${merged}

Run Robot
    [Documentation]    Starts robot in a child process. A non-zero rc is expected here -
    ...                the demo suite fails on purpose - so only a crash is reported.
    [Arguments]    ${label}    @{arguments}
    ${log file}=    Set Variable    ${WORK DIR}/${label}_stdout.txt
    ${result}=      Run Process    ${PYTHON}    -m    robot    @{arguments}
    ...    stdout=${log file}    stderr=STDOUT
    ${log}=    Get File    ${log file}
    # rc 251-255 is robot refusing to start; 1-250 is just failed tests.
    Should Be True    ${result.rc} < 251    Child run never started:\n${log}
    RETURN    ${result}

Merged Test
    [Documentation]    One test out of the merged report, looked up by name.
    [Arguments]    ${test name}
    ${matches}=    Evaluate    [t for t in $MERGED_TESTS if t["name"] == $test_name]
    Length Should Be    ${matches}    1    No single '${test name}' in ${MERGED TESTS}
    RETURN    ${matches}[0]
