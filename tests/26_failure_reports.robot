*** Settings ***
Documentation    Day 26 - what a failure report should contain.
...              The Browser library already screenshots on failure, so the picture
...              is not the missing piece. What is missing is everything around it,
...              at the moment it is needed: a red run overnight, on a machine that
...              is not mine, that I would rather not reproduce before I can start
...              thinking.
...              libraries/FailureReporter.py is a listener that writes one JSON file
...              per failed test. This suite runs a deliberately broken suite under
...              it and reads back what it produced.
...              Run:  robot --outputdir results tests/26_failure_reports.robot
Library          Process
Library          OperatingSystem
Library          Collections
Library          ../libraries/DataHelpers.py
Suite Setup      Run The Broken Suite Under The Reporter
Test Tags        unit    reporting


*** Variables ***
${DEMO SUITE}    ${CURDIR}/../data/failure_demo.robot
${REPORTER}      ${CURDIR}/../libraries/FailureReporter.py
${PASSES}        A Demo Test That Passes
${NESTED}        A Demo Test That Fails Two Keywords Deep
${SCREENSHOT}    A Demo Test That Leaves A Screenshot Behind
${DIRECT}        A Demo Test That Fails Directly


*** Test Cases ***
Only Failed Tests Get A Report
    [Documentation]    Three failures, three reports. A folder that also describes the
    ...                tests that were fine is a folder nobody opens.
    [Tags]    smoke
    Length Should Be    ${REPORTS}    3
    ${names}=    Evaluate    sorted($REPORTS.keys())
    Should Contain       ${names}    ${NESTED}
    Should Contain       ${names}    ${SCREENSHOT}
    Should Contain       ${names}    ${DIRECT}
    Should Not Contain   ${names}    ${PASSES}

The Report Names The Keyword That Actually Broke
    [Documentation]    Not the one the test called - the one at the bottom. The
    ...                message travels up unchanged, so by the time it reaches the
    ...                test, "17 != 42" could have come from anywhere.
    [Tags]    smoke
    ${report}=    Report For    ${NESTED}
    Should Be Equal    ${report}[failures][0][keyword]    BuiltIn.Should Be Equal As Integers
    # The outer keyword reports the identical message and explains nothing.
    Should Be Equal    ${report}[failures][2][keyword]    Check The Order Total
    Should Be Equal    ${report}[failures][0][message]    ${report}[failures][2][message]

The Chain Is Recorded Innermost First
    [Documentation]    end_keyword fires from the inside out, so index 0 is where it
    ...                broke and the last entry is the test's own step. Reading the
    ...                chain tells you the route without opening log.html.
    ${report}=    Report For    ${NESTED}
    ${chain}=    Evaluate    [f["keyword"] for f in $report["failures"]]
    Should Be Equal    ${chain}[0]    BuiltIn.Should Be Equal As Integers
    Should Be Equal    ${chain}[1]    Compare Against The Basket
    Should Be Equal    ${chain}[2]    Check The Order Total

The Report Holds The Values, Not Only The Variable Names
    [Documentation]    The part that surprised me. Robot stores arguments as they were
    ...                WRITTEN - output.xml and log.html both show ${expected}, never
    ...                42 - so a report built from the result model alone describes
    ...                the shape of the call and none of its values. The listener asks
    ...                for them while they are still in scope.
    [Tags]    smoke
    ${report}=    Report For    ${NESTED}
    ${step}=    Set Variable    ${report}[failures][0]
    # Escaped as \${...}: unescaped, Robot resolves them HERE, in this suite,
    # where neither exists. Same trick as Day 18's ${PABOTQUEUEINDEX}.
    ${as written}=    Create List    \${actual}    \${expected}
    ${as run}=        Create List    17    42
    Lists Should Be Equal    ${step}[arguments]    ${as written}
    Lists Should Be Equal    ${step}[resolved]     ${as run}

Evidence Logged During The Test Is Picked Up
    [Documentation]    A screenshot reaches the log as an <img> tag whoever took it, so
    ...                the listener reads it out of the message instead of asking a
    ...                library by name. That keeps it working for one not written yet.
    ${report}=    Report For    ${SCREENSHOT}
    Should Contain    ${report}[images]    fail-screenshot-1.png
    # And it does not invent evidence for a test that captured none.
    ${plain}=    Report For    ${DIRECT}
    Should Be Empty    ${plain}[images]

The Report Says Where The Failure Happened
    [Documentation]    Suite, tags and process. The tags answer "was this in the smoke
    ...                set", and the pid tells a pabot failure apart from a plain one -
    ...                two questions a console line cannot.
    ${report}=    Report For    ${NESTED}
    Should Be Equal    ${report}[suite]    Failure Demo
    Should Contain    ${report}[tags]    checkout
    Should Contain    ${report}[tags]    nested
    Should Be True    ${report}[environment][pid] > 0

The Report Says What The Machine Was
    [Documentation]    "Works on my machine" answered before it is asked. Robot and
    ...                Python versions and the platform, captured at the moment of
    ...                failure rather than guessed at afterwards.
    ${report}=    Report For    ${DIRECT}
    ${env}=    Set Variable    ${report}[environment]
    Should Match Regexp    ${env}[robot]     ^\\d+\\.\\d+
    Should Match Regexp    ${env}[python]    ^3\\.\\d+
    Should Not Be Empty    ${env}[platform]

An Index Points At Every Report
    [Documentation]    close() writes it once the run is over. A CI artefact full of
    ...                JSON needs a front door, or nobody finds the one that matters.
    ${index}=    Evaluate    json.loads($INDEX_TEXT)    modules=json
    Should Be Equal As Integers    ${index}[failures]    3
    Length Should Be    ${index}[reports]    3


*** Keywords ***
Run The Broken Suite Under The Reporter
    [Documentation]    One child run of data/failure_demo.robot with the listener
    ...                attached, then every report it wrote is read back.
    ${dir name}=    Unique Artifact Name    day26_failures    # Day 18: pid in the name
    ${work}=        Set Variable    ${TEMPDIR}/${dir name}
    Remove Directory    ${work}    recursive=${True}
    Create Directory    ${work}
    ${python}=    Evaluate    sys.executable    modules=sys

    ${result}=    Run Process    ${python}    -m    robot
    ...    --listener    ${REPORTER}
    ...    --outputdir    ${work}
    ...    ${DEMO SUITE}
    ...    stdout=${work}/child_stdout.txt    stderr=STDOUT
    ${log}=    Get File    ${work}/child_stdout.txt
    # Three failing tests by design, so rc is 3. Only a refusal to start matters.
    Should Be True    ${result.rc} < 251    Child run never started:\n${log}

    ${files}=    List Files In Directory    ${work}/failures    *.json
    ${reports}=    Create Dictionary
    FOR    ${name}    IN    @{files}
        ${text}=    Get File    ${work}/failures/${name}
        IF    "${name}".startswith("index_")
            Set Suite Variable    ${INDEX TEXT}    ${text}
        ELSE
            ${report}=    Evaluate    json.loads($text)    modules=json
            Set To Dictionary    ${reports}    ${report}[test]    ${report}
        END
    END
    Set Suite Variable    ${REPORTS}    ${reports}

Report For
    [Documentation]    One report by test name, failing clearly when there is none.
    [Arguments]    ${test name}
    Dictionary Should Contain Key    ${REPORTS}    ${test name}
    ...    No report for '${test name}'. Reports written: ${REPORTS.keys()}
    RETURN    ${REPORTS}[${test name}]
