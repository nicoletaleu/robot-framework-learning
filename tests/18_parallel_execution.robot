*** Settings ***
Documentation    Day 18 - running the suites in PARALLEL with pabot.
...              One process per suite, nothing shared: no variables, no library
...              state, no order. Every test here passes under both runners.
...              Run:  robot --outputdir results tests/18_parallel_execution.robot
...              All:  pabot --processes 4 --outputdir results tests/
...              Per test:  pabot --testlevelsplit --processes 4 --outputdir results tests/
Library          ../libraries/DataHelpers.py
Library          Collections
Library          OperatingSystem
Test Tags        parallel


*** Variables ***
${SHARED_COUNTER}    0


*** Test Cases ***
The Suite Can Tell Which Runner Started It
    [Documentation]    pabot sets ${PABOTQUEUEINDEX} in every worker, plain robot does not.
    [Tags]    smoke
    # Escaped as \${...}: unescaped, Robot resolves it first and fails when it is missing.
    ${worker}=    Get Variable Value    \${PABOTQUEUEINDEX}    ${NONE}
    IF    $worker is None
        Log    Single process - started with `robot`.
    ELSE
        Log    Parallel worker number ${worker} - started with `pabot`.
    END
    ${pid}=    Current Process Id
    Log    This test runs in OS process ${pid}.

Each Test Builds Its Own Data
    [Documentation]    No shared fixture user, so no neighbour can break this test.
    [Tags]    smoke
    ${email}=    Random Email    prefix=worker
    Should Match Regexp    ${email}    ^worker_\\d{8}@example[.]com$

A Second Test Builds Its Own Data Too
    [Documentation]    Same keyword, different value - the two can run at the same time.
    ${email}=    Random Email    prefix=worker
    Should Match Regexp    ${email}    ^worker_\\d{8}@example[.]com$

Generated Data Does Not Collide
    [Documentation]    The safety net under the two tests above: 200 emails, 200 distinct.
    @{emails}=    Create List
    FOR    ${i}    IN RANGE    200
        ${email}=    Random Email
        Append To List    ${emails}    ${email}
    END
    ${unique}=    Remove Duplicates    ${emails}
    Length Should Be    ${unique}    200

File Names Carry The Process Id
    [Documentation]    Two workers writing the same file name: the second one silently wins.
    [Tags]    smoke
    ${pid}=      Current Process Id
    ${name}=     Unique Artifact Name    screenshot.png
    Should Be Equal    ${name}    screenshot_${pid}.png
    # Stable inside one process, so a teardown can find what the test wrote.
    ${again}=    Unique Artifact Name    screenshot.png
    Should Be Equal    ${again}    ${name}
    ${plain}=    Unique Artifact Name    report
    Should Be Equal    ${plain}    report_${pid}

Library State Is Per Process, Not Per Run
    [Documentation]    DataHelpers is scope=GLOBAL, but only inside ONE process.
    ...                Assert the change, never the total.
    ${count}=       Emails Generated So Far
    ${email}=       Random Email
    ${after}=       Emails Generated So Far
    ${expected}=    Evaluate    ${count} + 1
    Should Be Equal As Integers    ${after}    ${expected}

Local Changes Do Not Leak Into Other Tests
    [Documentation]    This assignment shadows the suite variable and dies with the test.
    ${SHARED_COUNTER}=    Evaluate    ${SHARED_COUNTER} + 1
    Should Be Equal As Integers    ${SHARED_COUNTER}    1

Every Test Starts From The Declared Value
    [Documentation]    Written after the test above and still sees 0 - order does not matter.
    [Tags]    smoke
    Should Be Equal As Integers    ${SHARED_COUNTER}    0

Each Process Writes Into Its Own Output Directory
    [Documentation]    Every worker gets a private ${OUTPUT DIR}, so never hard-code a path.
    Directory Should Exist    ${OUTPUT DIR}
    Log    Output for this process goes to ${OUTPUT DIR}
