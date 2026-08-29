*** Settings ***
Documentation    Day 7 - Data-driven testing with TEST TEMPLATES.
...
...              Idea: run the SAME test logic with MANY sets of data,
...              without copy-pasting the test over and over.
...
...              [Template]    A keyword name. Each data row under the test
...                            becomes ONE call to that keyword. Each row is
...                            reported as a separate check in the log.
...
...              Test Template (in Settings) -> applies a template to EVERY
...                            test in the file (full data-driven suite).
...              [Template]   (on one test)  -> applies only to that test.
...
...              Why it matters: 1 keyword + 10 data rows = 10 scenarios,
...              and if one row fails the others still run.
...
...              Run with:  robot --outputdir results tests/07_data_driven_and_templates.robot
Library          Collections
Test Tags        unit


*** Variables ***
@{VALID_EMAILS}      a@b.com    first.last@mail.co    x_y@sub.domain.org
@{INVALID_EMAILS}    plainaddress    @no-user.com    no-at-sign.com    a@@b.com


*** Keywords ***
Sum Should Be
    [Documentation]    Template keyword: adds two numbers and asserts the result.
    ...                One data row = one (a, b, expected) triple.
    [Arguments]    ${a}    ${b}    ${expected}
    ${result}=    Evaluate    ${a} + ${b}
    Should Be Equal As Numbers    ${result}    ${expected}

Email Should Be Valid
    [Documentation]    Template keyword: passes only if the email looks valid.
    ...                A "valid" email here = has exactly one @ and a dot after it.
    [Arguments]    ${email}
    Should Match Regexp    ${email}    ^[^@]+@[^@]+\\.[^@]+$

Email Should Be Invalid
    [Documentation]    Template keyword: the OPPOSITE check - must NOT match.
    [Arguments]    ${email}
    Should Not Match Regexp    ${email}    ^[^@]+@[^@]+\\.[^@]+$

Classify Age Should Be
    [Documentation]    Template keyword: maps an age to a category and checks it.
    [Arguments]    ${age}    ${expected_group}
    IF    ${age} < 13
        ${group}=    Set Variable    child
    ELSE IF    ${age} < 18
        ${group}=    Set Variable    teen
    ELSE
        ${group}=    Set Variable    adult
    END
    Should Be Equal    ${group}    ${expected_group}


*** Test Cases ***
Addition With Many Inputs
    [Documentation]    [Template] on a SINGLE test. Each line below is one call
    ...                to "Sum Should Be" with: a  b  expected.
    [Tags]    smoke
    [Template]    Sum Should Be
    2     3     5
    0     0     0
    10    5     15
    -4    4     0

Valid Emails Are Accepted
    [Documentation]    Data comes from a list variable. FOR loop builds the
    ...                rows so we don't hardcode each email twice.
    [Tags]    regression
    [Template]    Email Should Be Valid
    FOR    ${email}    IN    @{VALID_EMAILS}
        ${email}
    END

Invalid Emails Are Rejected
    [Documentation]    Same idea, opposite expectation: each bad email must FAIL
    ...                the validity rule (so "Email Should Be Invalid" passes).
    [Tags]    regression
    [Template]    Email Should Be Invalid
    FOR    ${email}    IN    @{INVALID_EMAILS}
        ${email}
    END

Age Classification
    [Documentation]    One template, several boundary values (12/13, 17/18)
    ...                to check the edges of each category.
    [Tags]    regression
    [Template]    Classify Age Should Be
    5      child
    12     child
    13     teen
    17     teen
    18     adult
    40     adult
