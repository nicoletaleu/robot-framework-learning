*** Settings ***
Documentation    Day 19 - listeners: code that watches the run instead of testing it.
...
...              A library waits to be called by a test. A listener is called by
...              Robot, around every suite and every test, and the suite never
...              knows. That is where cross-cutting work belongs: a screenshot on
...              every failure, a timing report, a "slow" tag - written once,
...              applied to every suite in the repo.
...
...              How this suite tests a listener: it starts a CHILD robot run over
...              data/listener_demo.robot with the listener attached, then reads
...              back the file the listener wrote. Deterministic, independent of
...              test order, and safe under pabot - the Day 18 rules still apply.
...
...              Run:  robot --outputdir results tests/19_listeners.robot
...              With the listener on this run too, so nothing here is skipped:
...              robot --listener libraries/RunListener.py:0.5 --outputdir results tests/19_listeners.robot
Library          Process
Library          OperatingSystem
Library          Collections
Library          ../libraries/DataHelpers.py
Suite Setup      Run The Demo Suite Under The Listener
Test Tags        listeners


*** Variables ***
${DEMO SUITE}      ${CURDIR}/../data/listener_demo.robot
${LISTENER}        ${CURDIR}/../libraries/RunListener.py
# Below the demo suite's 0.4s sleep and above the other two tests, so exactly
# one test crosses the line.
${SLOW SECONDS}    0.2


*** Test Cases ***
The Listener Sees Every Test In The Run
    [Documentation]    Three tests in the demo suite, three records - nothing opted in.
    [Tags]    smoke
    Length Should Be    ${RECORDS}    3
    ${names}=    Evaluate    [r["name"] for r in $RECORDS]
    Should Contain    ${names}    A Demo Test That Passes
    Should Contain    ${names}    A Demo Test That Fails On Purpose
    Should Contain    ${names}    A Demo Test That Is Slow Enough To Be Tagged

The Listener Records What Happened, Not What Was Planned
    [Documentation]    end_test fires after the teardown, so the status it reads is final.
    [Tags]    smoke
    ${passed}=    Record For    A Demo Test That Passes
    ${failed}=    Record For    A Demo Test That Fails On Purpose
    Should Be Equal    ${passed}[status]    PASS
    Should Be Equal    ${failed}[status]    FAIL

The Listener Changes The Report While It Is Being Written
    [Documentation]    The "slow" tag exists nowhere in the demo suite. v3 let the
    ...                listener add it to `result` before the report was built.
    [Tags]    smoke
    ${slow}=    Record For    A Demo Test That Is Slow Enough To Be Tagged
    Should Contain    ${slow}[tags]    slow
    Should Be True    ${slow}[seconds] > ${SLOW SECONDS}

Fast Tests Are Left Alone
    [Documentation]    The other half of the rule above - a tag applied to everything is useless.
    ${fast}=    Record For    A Demo Test That Passes
    Should Not Contain    ${fast}[tags]    slow

The Watched Suite Never Imports The Listener
    [Documentation]    No import, no setting. Attaching happens on the command line,
    ...                which is why one listener covers suites written before it existed.
    ...                Only the settings are checked, not the prose - the demo suite's
    ...                own documentation talks about listeners at length.
    ${source}=    Get File    ${DEMO SUITE}
    # A setting has to start at column 0 and is neither a section header (***)
    # nor a documentation continuation (...).
    @{settings}=    Evaluate
    ...    [l for l in $source.splitlines() if l and not l[0].isspace() and not l.startswith(("*", "..."))]
    Should Not Contain Match    ${settings}    Library*
    Should Not Contain Match    ${settings}    *RunListener*

Every Record Carries The Process That Wrote It
    [Documentation]    Day 18 again: under pabot each worker gets its own listener
    ...                instance, so the pid is what keeps their files apart.
    ${pids}=    Evaluate    {r["pid"] for r in $RECORDS}
    Length Should Be    ${pids}    1
    Should Not Be Equal As Integers    ${pids.pop()}    ${{ __import__("os").getpid() }}

The Summary Is Written After The Last Test
    [Documentation]    close() is the final callback. No execution context left there,
    ...                so it writes to disk instead of logging.
    Should Be Equal As Integers    ${SUMMARY}[total]     3
    Should Be Equal As Integers    ${SUMMARY}[passed]    2
    Should Be Equal As Integers    ${SUMMARY}[failed]    1
    Length Should Be               ${SUMMARY}[slow]      1

A Listener Does Not Change Whether The Run Passed
    [Documentation]    One failing test, exit code 1 - watching a run must not rescue it.
    Should Be Equal As Integers    ${DEMO RC}    1

The Suite Can Tell Whether A Listener Is Attached
    [Documentation]    start_suite sets a global variable, which is the only channel
    ...                a listener has into the suites it watches.
    ...                Skipped unless this run was started with --listener.
    Skip If    not ${LISTENER ATTACHED HERE}    Run with --listener libraries/RunListener.py to exercise this.
    Should Be True    ${LISTENER ACTIVE}
    File Should Exist    ${LISTENER RECORD FILE}

The Listener Knows Which Test Is Running Right Now
    [Documentation]    start_test fires before the test's own setup, so the value is
    ...                already there by the time the first keyword runs.
    Skip If    not ${LISTENER ATTACHED HERE}    Run with --listener libraries/RunListener.py to exercise this.
    Should Be Equal    ${LISTENER LAST STARTED}    ${TEST NAME}


*** Keywords ***
Run The Demo Suite Under The Listener
    [Documentation]    Starts a child robot process over data/listener_demo.robot and
    ...                reads back what the listener left behind.
    # NOT under ${OUTPUT DIR}. The child writes its own output.xml, and under
    # pabot ${OUTPUT DIR} is a worker folder inside results/pabot_results/ -
    # the merge at the end of the run then finds an output.xml it never
    # produced and reports "Suite '' contains no tests" for the whole run.
    # ${TEMPDIR} is Robot's built-in system temp folder.
    ${dir name}=     Unique Artifact Name    day19_listener_demo    # Day 18: pid in the name
    ${child out}=    Set Variable    ${TEMPDIR}/${dir name}
    # Wiped first: the file names carry a pid, and a pid gets reused eventually,
    # so an old listener_*.jsonl could be read as if this run had written it.
    Remove Directory    ${child out}    recursive=${True}
    # Run Process will not create the folder it is told to redirect stdout into.
    Create Directory    ${child out}
    ${python}=       Evaluate    sys.executable    modules=sys
    ${result}=       Run Process    ${python}    -m    robot
    ...    --listener      ${LISTENER}:${SLOW SECONDS}
    ...    --outputdir     ${child out}
    ...    ${DEMO SUITE}
    ...    stdout=${child out}/child_stdout.txt    stderr=STDOUT
    # rc 1 is expected: the demo suite has one failing test by design. Anything
    # above 250 means robot itself could not start, and then the log below is
    # the only place the reason shows up.
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

    # Is a listener attached to THIS run as well? Only true when robot was
    # started with --listener, so the last two tests skip instead of failing.
    ${attached}=    Get Variable Value    ${LISTENER ACTIVE}    ${False}
    Set Suite Variable    ${LISTENER ATTACHED HERE}    ${attached}

Find The Only File
    [Documentation]    Fails loudly when the pattern matches nothing or more than one file.
    [Arguments]    ${directory}    ${pattern}
    ${names}=    List Files In Directory    ${directory}    ${pattern}
    Length Should Be    ${names}    1    Expected exactly one ${pattern} in ${directory}, got ${names}
    RETURN    ${directory}/${names}[0]

Record For
    [Documentation]    Looks a record up by test name instead of by position - the order
    ...                the listener saw them in is not something to depend on.
    [Arguments]    ${test name}
    ${matches}=    Evaluate    [r for r in $RECORDS if r["name"] == $test_name]
    Length Should Be    ${matches}    1    No single record for '${test name}' in ${RECORDS}
    RETURN    ${matches}[0]
