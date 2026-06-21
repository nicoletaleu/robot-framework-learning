*** Settings ***
Documentation    Day 2 - Variables and assertions.
...              Run with:  robot --outputdir results tests/02_variables.robot


*** Variables ***
${NAME}     Nicoleta
${AGE}      33
${CITY}     Suceava


*** Test Cases ***
Show My Data
    [Documentation]    Logs the variables so they appear in the report.
    Log    ${NAME}
    Log    ${AGE}
    Log    ${CITY}

Check My Name
    [Documentation]    Verifies the name is correct.
    Should Be Equal    ${NAME}    Nicoleta


Check My City
    [Documentation]    Verifies the city contains a piece of text.
    Should Contain    ${CITY}    Suceava


Create A Variable Inside The Test
    [Documentation]    Practice Set Variable.
    ${hobby}=    Set Variable    reading
    Log    ${hobby}
    Should Be Equal    ${hobby}    reading
