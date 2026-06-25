*** Settings ***
Documentation    Day 4 - Dictionaries and conditions (IF / ELSE).
...              Run with:  robot --outputdir results tests/04_dictionaries_and_conditions.robot
Library          Collections


*** Variables ***
# A dictionary uses &{...} and stores key=value pairs.
&{USER}         name=Nicoleta    age=33    city=Suceava
${SCORE}        75


*** Test Cases ***
Show User Details
    [Documentation]    Reads values from a dictionary using ${dict}[key].
    Log    ${USER}[name]
    Log    ${USER}[city]
    Should Be Equal    ${USER}[name]    Nicoleta

Check A Dictionary Has A Key
    [Documentation]    Verifies a key exists in the dictionary.
    Dictionary Should Contain Key    ${USER}    age
    Dictionary Should Contain Value    ${USER}    Suceava

Add A Field To The Dictionary
    [Documentation]    Adds a new key=value at runtime, then checks it.
    Set To Dictionary    ${USER}    job    QA Tester
    Should Be Equal    ${USER}[job]    QA Tester

Decide If The Score Passed
    [Documentation]    Uses IF / ELSE to choose a result based on the score.
    IF    ${SCORE} >= 50
        Log    Passed!
        ${result}=    Set Variable    PASS
    ELSE
        Log    Failed.
        ${result}=    Set Variable    FAIL
    END
    Should Be Equal    ${result}    PASS

Grade The Score
    [Documentation]    Practice IF / ELSE IF / ELSE.
    # Rules:
    #   score >= 90            -> grade = A
    #   score >= 70 (else)     -> grade = B
    #   otherwise (else)       -> grade = C
    IF    ${SCORE} >= 90
        ${grade}=    Set Variable    A
    ELSE IF    ${SCORE} >= 70
        ${grade}=    Set Variable    B
    ELSE
        ${grade}=    Set Variable    C
    END
    Should Be Equal    ${grade}    B
