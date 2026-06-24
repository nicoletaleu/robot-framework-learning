*** Settings ***
Documentation    Day 3 - User keywords, lists and FOR loops.
...              Run with:  robot --outputdir results tests/03_keywords_and_loops.robot
Library          Collections


*** Variables ***
# A list uses @{...} instead of ${...}
@{FRUITS}       apple    banana    cherry
${GREETING}     Hello


*** Test Cases ***
Greet A Person
    [Documentation]    Calls a keyword we wrote ourselves.
    Greet    Nicoleta

Count The Fruits
    [Documentation]    Checks how many items are in the list.
    Log    ${FRUITS}
    Length Should Be  ${FRUITS}    3

Find A Fruit
    [Documentation]    Verifies the list contains a value.
    List Should Contain Value    ${FRUITS}    banana

Print Every Fruit
    [Documentation]    Loops through the list and logs each item.
    # TODO 4: complete the FOR loop below so it logs every fruit
    FOR    ${fruit}    IN    @{FRUITS}
        Log    ${fruit}
    END

Add A Fruit To The List
    [Documentation]    Practice changing a list at runtime.
    Append To List    ${FRUITS}    orange
    Length Should Be  ${FRUITS}    4


*** Keywords ***
Greet
    [Documentation]    A custom keyword that takes one argument and logs a greeting.
    [Arguments]    ${person}
    Log    ${GREETING}, ${person}!
