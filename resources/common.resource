*** Settings ***
Documentation    Reusable keywords shared across test suites.
...              A .resource file holds keywords/variables but has NO test cases.
...              Import it in a suite with:  Resource    ../resources/common.resource
Library          Collections


*** Variables ***
${DEFAULT_TAX}    19


*** Keywords ***
Add Two Numbers
    [Documentation]    Takes two arguments and RETURNS their sum.
    ...                The caller grabs the result with:  ${x}=    Add Two Numbers    2    3
    [Arguments]    ${a}    ${b}
    ${sum}=    Evaluate    ${a} + ${b}
    RETURN    ${sum}

Build Full Name
    [Documentation]    Two arguments, the second has a DEFAULT value.
    ...                If you don't pass a last name, it uses "Unknown".
    [Arguments]    ${first}    ${last}=Unknown
    ${full}=    Set Variable    ${first} ${last}
    RETURN    ${full}

Apply Tax
    [Documentation]    Adds a tax percentage to a price and returns the total.
    ...                The tax rate has a default, so it's optional.
    [Arguments]    ${price}    ${rate}=${DEFAULT_TAX}
    ${total}=    Evaluate    ${price} * (1 + ${rate} / 100)
    RETURN    ${total}

Classify Number
    [Documentation]    Returns "positive", "negative" or "zero".
    ...                Shows a keyword that combines IF/ELSE with a return value.
    [Arguments]    ${number}
    IF    ${number} > 0
        RETURN    positive
    ELSE IF    ${number} < 0
        RETURN    negative
    ELSE
        RETURN    zero
    END
