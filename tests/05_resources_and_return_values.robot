*** Settings ***
Documentation    Day 5 - Reusable keywords from a resource file:
...              multiple arguments, default values and RETURN values.
...              Run with:  robot --outputdir results tests/05_resources_and_return_values.robot
Resource         ../resources/common.resource


*** Test Cases ***
Add Numbers And Use The Result
    [Documentation]    Calls a keyword that returns a value and stores it.
    ${result}=    Add Two Numbers    2    3
    Should Be Equal As Numbers    ${result}    5

Build A Full Name
    [Documentation]    Passes both arguments to the keyword.
    ${name}=    Build Full Name    Nicoleta    Toma
    Should Be Equal    ${name}    Nicoleta Toma

Build A Name Using The Default
    [Documentation]    Omits the second argument, so the default is used.
    ${name}=    Build Full Name    Nicoleta
    Should Be Equal    ${name}    Nicoleta Unknown

Apply The Default Tax
    [Documentation]    Uses the default tax rate (19%).  100 -> 119
    ${total}=    Apply Tax    100
    Should Be Equal As Numbers    ${total}    119

Apply A Custom Tax
    [Documentation]    Overrides the default tax rate with 10%.  200 -> 220
    ${total}=    Apply Tax    200    10
    Should Be Equal As Numbers    ${total}    220

Classify Some Numbers
    [Documentation]    A keyword that returns different values based on input.
    ${a}=    Classify Number    5
    ${b}=    Classify Number    -3
    ${c}=    Classify Number    0
    Should Be Equal    ${a}    positive
    Should Be Equal    ${b}    negative
    Should Be Equal    ${c}    zero
