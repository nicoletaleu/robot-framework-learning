*** Settings ***
Documentation    Day 19 - listeners: code Robot calls around every suite and test,
...              without the suites knowing. Attached with --listener, so one file
...              covers the whole repo: timing, a screenshot on failure, an extra tag.
...              Tested here by starting a CHILD robot run over data/listener_demo.robot
...              and reading back what the listener wrote.
...              Run:  robot --outputdir results tests/19_listeners.robot
...              Add --listener libraries/RunListener.py:0.5 to un-skip the last two.
Library          Process
Library          OperatingSystem
Library          Collections
Library          ../libraries/DataHelpers.py
Suite Setup      Run The Demo Suite Under The Listener
Test Tags        listeners


*** Variables ***
${DEMO SUITE}      ${CURDIR}/../data/listener_demo.robot
${LISTENER}        ${CURDIR}/../libraries/RunListener.py
# Below the demo suite's 0.4s sleep, above the other two tests.
${SLOW SECONDS}    0.2


*** Test Cases ***
The Listener Sees Every Test In The Run
    [Documentation]    Three tests, three records - nothing opted in.
    [Tags]    smoke
    Length Should Be    ${RECORDS}    3
    ${names}=    Evaluate    [r["name"] for r in $RECORDS]
    Should Contain    ${names}    A Demo Test That Passes
    Should Contain    ${names}    A Demo Test That Fails On Purpose
    Should Contain    ${names}    A Demo Test That Is Slow Enough To Be Tagged

The Listener Records What Happened, Not What Was Planned
    [Documentation]    end_test fires after the teardown, so the status is final.
    [Tags]    smoke
    ${passed}=    Record For    A Demo Test That Passes
    ${failed}=    Record For    A Demo Test That Fails On Purpose
    Should Be Equal    ${passed}[status]    PASS
    Should Be Equal    ${failed}[status]    FAIL

The Listener Changes The Report While It Is Being Written
    [Documentation]    "slow" appears nowhere in the demo suite - v3 wrote it into `result`.
    [Tags]    smoke
    ${slow}=    Record For    A Demo Test That Is Slow Enough To Be Tagged
    Should Contain    ${slow}[tags]    slow
    Should Be True    ${slow}[seconds] > ${SLOW SECONDS}

Fast Tests Are Left Alone
    [Documentation]    A tag applied to everything is useless.
    ${fast}=    Record For    A Demo Test That Passes
    Should Not Contain    ${fast}[tags]    slow

The Watched Suite Never Imports The Listener
    [Documentation]    No import, no setting - which is why one listener covers suites
    ...                written before it existed. Checks the settings, not the prose.
    ${source}=    Get File    ${DEMO SUITE}
    # A setting starts at column 0 and is not a section header or a ... continuation.
    @{settings}=    Evaluate
    ...    [l for l in $source.splitlines() if l and not l[0].isspace() and not l.startswith(("*", "..."))]
    Should Not Contain Match    ${settings}    Library*
    Should Not Contain Match    ${settings}    *RunListener*

Every Record Carries The Process That Wrote It
    [Documentation]    Day 18: one listener instance per pabot worker, kept apart by pid.
    ${pids}=    Evaluate    {r["pid"] for r in $RECORDS}
    Length Should Be    ${pids}    1
    Should Not Be Equal As Integers    ${pids.pop()}    ${{ __import__("os").getpid() }}

The Summary Is Written After The Last Test
    [Documentation]    close() is the final callback - no context left, so it writes to disk.
    Should Be Equal As Integers    ${SUMMARY}[total]     3
    Should Be Equal As Integers    ${SUMMARY}[passed]    2
    Should Be Equal As Integers    ${SUMMARY}[failed]    1
    Length Should Be               ${SUMMARY}[slow]      1

A Listener Does Not Change Whether The Run Passed
    [Documentation]    One failing test, exit code 1 - watching a run must not rescue it.
    Should Be Equal As Integers    ${DEMO RC}    1

The Suite Can Tell Whether A Listener Is Attached
    [Documentation]    A global variable set in start_suite is the only channel in.
    Skip If    not ${LISTENER ATTACHED HERE}    Run with --listener libraries/RunListener.py to exercise this.
    Should Be True    ${LISTENER ACTIVE}
    File Should Exist    ${LISTENER RECORD FILE}

The Listener Knows Which Test Is Running Right Now
    [Documentation]    start_test fires before the test's own setup, so the value is ready.
    Skip If    not ${LISTENER ATTACHED HERE}    Run with --listener libraries/RunListener.py to exercise this.
    Should Be Equal    ${LISTENER LAST STARTED}    ${TEST NAME}


*** Keywords ***
Run The Demo Suite Under The Listener
    [Documentation]    Runs the demo suite in a child robot process, reads back the
    ...                records, the summary and the exit code.
    # NOT under ${OUTPUT DIR}: the child writes its own output.xml, and under pabot
    # that folder is a worker's, so the final merge picks it up and reports
    # "Suite '' contains no tests" for the whole run.
    ${dir name}=     Unique Artifact Name    day19_listener_demo    # Day 18: pid in the name
    ${child out}=    Set Variable    ${TEMPDIR}/${dir name}
    # Wiped first - pids get reused, so an old listener_*.jsonl could be read as ours.
    Remove Directory    ${child out}    recursive=${True}
    # Run Process will not create the folder it redirects stdout into.
    Create Directory    ${child out}
    ${python}=       Evaluate    sys.executable    modules=sys
    ${result}=       Run Process    ${python}    -m    robot
    ...    --listener      ${LISTENER}:${SLOW SECONDS}
    ...    --outputdir     ${child out}
    ...    ${DEMO SUITE}
    ...    stdout=${child out}/child_stdout.txt    stderr=STDOUT
    # rc 1 is expected (one failing test by design); above 250 means robot never started.
    ${log}=    Get File    ${child out}/child_stdout.txt
    Should Be True    ${result.rc} < 250    Child run never started:\n${log}
    Set Suite Variable    ${DEMO RC}    ${result.rc}

    ${records file}=    Find The Only File    ${child out}    listener_*.jsonl
    ${content}=         Get File    ${records file}
    ${records}=         Evaluate    [json.loads(line) for line in $content.splitlines() if line.strip()]
    ...    modules=json
    Set Suite Variable    ${RECORDS}    ${records}

    ${summary file}=    Find The Only File    ${child out}    listener_summary_*.json
    ${summary text}=    Get File    ${summary file}
    ${summary}=         Evaluate    json.loads($summary_text)    modules=json
    Set Suite Variable    ${SUMMARY}    ${summary}

    # True only when THIS run was started with --listener, so the last two skip.
    ${attached}=    Get Variable Value    ${LISTENER ACTIVE}    ${False}
    Set Suite Variable    ${LISTENER ATTACHED HERE}    ${attached}

Find The Only File
    [Documentation]    Fails loudly on zero matches or more than one.
    [Arguments]    ${directory}    ${pattern}
    ${names}=    List Files In Directory    ${directory}    ${pattern}
    Length Should Be    ${names}    1    Expected exactly one ${pattern} in ${directory}, got ${names}
    RETURN    ${directory}/${names}[0]

Record For
    [Documentation]    Looks a record up by name, not by position - the order is not ours to assume.
    [Arguments]    ${test name}
    ${matches}=    Evaluate    [r for r in $RECORDS if r["name"] == $test_name]
    Length Should Be    ${matches}    1    No single record for '${test name}' in ${RECORDS}
    RETURN    ${matches}[0]
