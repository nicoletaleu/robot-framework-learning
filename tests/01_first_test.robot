*** Settings ***
Documentation    My first test in Robot Framework.
...              Run with:  robot --outputdir results tests/01_first_test.robot
Test Tags        unit


*** Variables ***
${MESSAGE}      Hello, Robot Framework!
${NUMBER_A}     5
${NUMBER_B}     3


*** Test Cases ***
First Test Says Hello
    [Documentation]    Verifies a simple message.
    [Tags]    smoke
    Log    ${MESSAGE}
    Should Contain    ${MESSAGE}    Robot Framework

Add Two Numbers
    [Documentation]    Verifies that 5 + 3 = 8.
    ${sum} =    Evaluate    ${NUMBER_A} + ${NUMBER_B}
    Log    Sum is: ${sum}
    Should Be Equal As Integers    ${sum}    8

Verify A Text
    [Documentation]    Example of text assertions.
    ${name} =    Set Variable    Nicoleta
    Should Be Equal    ${name}    Nicoleta
    Should Not Be Equal    ${name}    Maria
