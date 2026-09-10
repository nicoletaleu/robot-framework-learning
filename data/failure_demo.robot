*** Settings ***
Documentation    Day 26 - INPUT DATA for tests/26_failure_reports.robot.
...              In data/ because three of its four tests fail on purpose. Suite 26
...              runs this file with the FailureReporter attached and reads the
...              reports it leaves behind.
Library          Collections


*** Test Cases ***
A Demo Test That Passes
    [Documentation]    The control: a passing test must produce no report at all.
    ...                A folder full of reports for tests that were fine is a folder
    ...                nobody reads.
    [Tags]    calm
    Log    Nothing to report.

A Demo Test That Fails Two Keywords Deep
    [Documentation]    The realistic shape. The test calls a keyword, which calls
    ...                another, and the one at the bottom is where it breaks - but the
    ...                error travels up and the test's own message no longer says with
    ...                what arguments.
    [Tags]    nested    checkout
    Check The Order Total    ${42}

A Demo Test That Leaves A Screenshot Behind
    [Documentation]    Any library that captures evidence logs it as an <img> tag.
    ...                Log with html=True is the same thing without a browser.
    [Tags]    evidence
    Log    <img src="fail-screenshot-1.png" width="800">    html=${True}
    Should Be Equal    what the page showed    what the test expected

A Demo Test That Fails Directly
    [Documentation]    No nesting: the failing keyword is the test's own step.
    [Tags]    plain
    Should Contain    a short string    something that is not in it


*** Keywords ***
Check The Order Total
    [Documentation]    Outer keyword. Adds no check of its own - it just calls the
    ...                next one down, which is exactly why its name is useless in a
    ...                failure message.
    [Arguments]    ${expected}
    Compare Against The Basket    ${expected}

Compare Against The Basket
    [Documentation]    Where it actually breaks, and the only place the real numbers
    ...                are still visible.
    [Arguments]    ${expected}
    ${actual}=    Set Variable    ${17}
    Should Be Equal As Integers    ${actual}    ${expected}
